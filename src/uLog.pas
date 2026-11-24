unit uLog;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes, Vcl.Forms,
  Vcl.StdCtrls, Vcl.ComCtrls, Vcl.ExtCtrls, System.SyncObjs, System.IOUtils,
  Generics.Collections, System.Types, Vcl.Controls;

type
  TLogLevel = (lvTrace, lvDebug, lvInfo, lvWarn, lvNotice, lvError);
  //TarrayOfConst = array of const;

const
  CLogLevelNames: array[TLogLevel] of string = ('trace', 'debug', 'info', 'warn', 'notice', 'error');
  CLogLevelPrefix: array[TLogLevel] of string = ('[trace] ', '[debug] ', '', '[WARN] ', '', '[ERROR] ');

type
  TfrmLogs = class(TForm)
    pnlLogTop: TPanel;
    lblInfoLogs: TLabel;
    btnClearLog: TButton;
    StatusBar1: TStatusBar;
    MemoLogs: TMemo;
    chkLogToFile: TCheckBox;
    chkLogToMemo: TCheckBox;
    cbLogLevel: TComboBox;
    chkThrottle: TCheckBox;
    chkTimestamp: TCheckBox;
    procedure btnClearLogClick(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure chkLogToMemoClick(Sender: TObject);
    procedure chkLogToFileClick(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure cbLogLevelClick(Sender: TObject);
    procedure chkTimestampClick(Sender: TObject);
    procedure chkThrottleClick(Sender: TObject);
  end;

function LogLevelToStr(L: TLogLevel): string;
function LogLevelFromStr(const S: string; Default: TLogLevel = lvInfo): TLogLevel;

// API principale
procedure LogMsg(const Msg: string; Level: TLogLevel = lvInfo); overload;

function SafeFmt(const AFmt: string; const AArgs: array of const): string;

function Lv(DoLog: Boolean): TLogLevel; inline; // ancien sémantique -> niveau

// Level test: use before any expensive Format() in hot paths
function LogIsOn(Level: TLogLevel): Boolean; //inline;

// One-liner formatters (Format() evaluated only if level is on)
procedure LogT(const Fmt: string; const Args: array of const); overload; // trace
procedure LogT(const sLog: string); overload; inline; // trace
procedure LogD(const Fmt: string; const Args: array of const); overload; // debug
procedure LogD(const sLog: string); overload; inline; // debug
procedure LogI(const Fmt: string; const Args: array of const); overload; // info
procedure LogI(const sLog: string); overload; inline; // info
procedure LogN(const Fmt: string; const Args: array of const); overload; // notice
procedure LogN(const sLog: string); overload; inline; // notice
procedure LogW(const Fmt: string; const Args: array of const); overload; // warn
procedure LogW(const sLog: string); overload; inline; // warn
procedure LogE(const Fmt: string; const Args: array of const); overload; // error
procedure LogE(const sLog: string); overload; inline// error
function LogOnce(var Seen: TStrings; const Key: string): Boolean;
// LogE : inline; => [dcc64 Erreur] uLog.pas(57): E2439 La fonction inline ne doit pas comporter d'argument tableau ouvert

procedure InitLogFile;
procedure CloseLogFile;

var
  frmLogs: TfrmLogs;
  FOnceDeq: TStrings = nil;

implementation

uses ShellAPI, uAppConfig;

{$R *.dfm}
const
  // ms between two messages of the same level; 0 = never throttled
  CThrottleMs: array[TLogLevel] of Int64 = (20, 10, 5, 0, 0, 0);

  BOOT_MAX_LINES = 4000; // tampon de demarrage (fenetre glissante, ~400 Ko max)
  MEMO_MAX_LINES = 20000; // plafonnement du memo (conserve la memoire sur les gros runs)
var
  FLogStream: TStreamWriter;
  FLogMutex: TCriticalSection; // cree a la volee (nil-checked) -> insensible a l'ordre d'init
  FOnceLock: TCriticalSection;
  FBootLines: TStringList; // logs emises avant l'existence des sinks
  FBootCapture: Boolean = True;
  FBootToFileDone: Boolean = false;
  FBootToMemoDone: Boolean = false;

  LogFilePath: string = ''; // Chemin auto-généré
  FLastTickByLevel: array[TLogLevel] of Int64;
  FSuppressed: array[TLogLevel] of Int64;

procedure MemoTrim(M: TMemo);
var
  N, i, M0: Integer;
begin
  if (M = nil) or (M.Lines.Count <= MEMO_MAX_LINES) then
    Exit;

  M0 := MEMO_MAX_LINES + MEMO_MAX_LINES div 4;
  if (M.Lines.Count <= M0) then
    Exit;

  M0 := MEMO_MAX_LINES div 2;
  N := M.Lines.Count - M0;

  M.Lines.BeginUpdate;
  try
    for i := 1 to N do
      M.Lines.Delete(0);
  finally
    M.Lines.EndUpdate;
  end;
end;

procedure MemoScrollToEnd(M: TMemo);
begin
  if (M = nil) or not M.Visible then
    Exit; // evite le cout O(n) de Length(Text) quand cache
  M.SelStart := Length(M.Text);
end;

function Lv(DoLog: Boolean): TLogLevel;
begin
  // DoLog=True  signifiait « événement important, non throttlé » -> lvNotice
  // DoLog=False (défaut) = journal normal throttlé            -> lvInfo
  if DoLog then
    Result := lvNotice
  else
    Result := lvInfo;
end;

function LogLevelToStr(L: TLogLevel): string;
begin
  Result := CLogLevelNames[L];
end;

function LogLevelFromStr(const S: string; Default: TLogLevel): TLogLevel;
var
  i: Integer;
begin
  Result := Default;
  for i := Integer(Low(TLogLevel)) to Integer(High(TLogLevel)) do
    if SameText(Trim(S), CLogLevelNames[TLogLevel(i)]) then
      Exit(TLogLevel(i));
end;

procedure EnsureLogMutex;
begin
  // Les globales sont zero-lees avant TOUTE section initialization : ce test est fiable
  // meme si uAppConfig.initialization nous appelle avant uLog.initialization.
  if FLogMutex = nil then
    FLogMutex := TCriticalSection.Create;
end;

procedure LogStopBootIfDone;
begin
  if FBootCapture and FBootToMemoDone and (FBootToFileDone or (not cfg.LogToFile)) then
    begin
      FBootCapture := false;
      FreeAndNil(FBootLines);
    end;
end;

procedure InitLogFile;
var
  sDir: string;
  W: TStreamWriter;
  i: Integer;
begin
  if not cfg.LogToFile then
    Exit;
  EnsureLogMutex;
  FLogMutex.Enter;
  try
    if Assigned(FLogStream) then
      Exit; // déjà ouvert
    if LogFilePath = '' then
      begin
        sDir := IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0))) + 'Logs';
        if not ForceDirectories(sDir) then
          Exit;
        LogFilePath := IncludeTrailingPathDelimiter(sDir) + 'Logs_' + FormatDateTime('yyyy-mm-dd', Now) + '.txt';
      end;
    W := nil;
    try
      W := TStreamWriter.Create(LogFilePath, True, TEncoding.UTF8);
    except
      W := nil;
    end;

    if W = nil then
    begin
      FBootToFileDone := True;   // rien a verser : desarme
      LogStopBootIfDone;
      Exit;
    end;

    W.AutoFlush := True;
    FLogStream := W;

    // verse le passif du demarrage (une seule fois, dans l'ordre chronologique)
    if not FBootToFileDone then
      begin
        FBootToFileDone := True;
        if FBootLines <> nil then
          for i := 0 to FBootLines.Count - 1 do
            FLogStream.WriteLine(FBootLines[i]);
        LogStopBootIfDone;
      end;
  finally
    FLogMutex.Leave;
  end;
end;

procedure CloseLogFile;
begin
  if not Assigned(FLogMutex) then
    Exit;
  FLogMutex.Enter;
  try
    if Assigned(FLogStream) then
      begin
        FLogStream.Flush;
        FLogStream.Free;
        FLogStream := nil;
      end;
  finally
    FLogMutex.Leave;
  end;
  { if Assigned(FLogMutex) then
    begin
    FLogMutex.Free;
    FLogMutex := nil;
    end; }
end;

// Format jamais levant : renvoie un texte d'erreur si le format est invalide
function SafeFmt(const AFmt: string; const AArgs: array of const): string;
begin
  try
    Result := Format(AFmt, AArgs);
  except
    on E: Exception do
      Result := '[FMT] ' + E.Message + ' | ' + AFmt;
  end;
end;

procedure LogMsg(const Msg: string; Level: TLogLevel);
var
  FullMsg, Supp: string;
  T: Int64;
  DoFile, DoMemo, Boot: Boolean;
begin
  // 1) Filtrage par niveau (cfg.LogLevel = lvInfo par défaut -> comportement d'aujourd'hui)
  if Level < cfg.LogLevel then
    Exit;

  EnsureLogMutex;

  DoFile := cfg.LogToFile;
  DoMemo := cfg.LogToMemo and Assigned(frmLogs) and Assigned(frmLogs.MemoLogs) and (not FBootCapture);
  Boot := FBootCapture;

  // per-level throttle: WARN/ERROR/NOTICE always pass (CThrottleMs = 0)
  if cfg.LogThrottle and (CThrottleMs[Level] > 0) and (DoFile or DoMemo or Boot) then
    begin
      T := GetTickCount64;
      if (T - FLastTickByLevel[Level]) < CThrottleMs[Level] then
        begin
          Inc(FSuppressed[Level]);
          DoMemo := False;
          DoFile := False;
        end
      else
        FLastTickByLevel[Level] := T;
    end;

  if not(DoFile or DoMemo or Boot) then
    Exit;

  Supp := '';
  if FSuppressed[Level] > 0 then
    begin
      Supp := Format(' [+%d %s suppressed]', [FSuppressed[Level], CLogLevelNames[Level]]);
      FSuppressed[Level] := 0;
    end;

  FullMsg := '';
  if cfg.LogTimestamp then
    FullMsg := FormatDateTime('[hh:nn:ss.zzz] ', Now);

  FullMsg := FullMsg + CLogLevelPrefix[Level] + Msg + Supp;

  FLogMutex.Enter;
  try
    if Boot then
      begin
        if (FBootLines = nil) then
          FBootLines := TStringList.Create;
        FBootLines.Add(FullMsg);
        while FBootLines.Count >= BOOT_MAX_LINES do
          FBootLines.Delete(0);
      end;
    if DoFile then
      begin
        if not Assigned(FLogStream) then
          InitLogFile; // ré-entrant (CS Windows)
        if Assigned(FLogStream) then
          FLogStream.WriteLine(FullMsg);
      end;
  finally
    FLogMutex.Leave;
  end;

  if Boot and not DoFile and not DoMemo then
    OutputDebugString(PChar(FullMsg));

  if DoMemo then
    TThread.Queue(nil,
      procedure
      begin
        if not cfg.LogToMemo then Exit;
        if not Assigned(frmLogs) or not Assigned(frmLogs.MemoLogs) then Exit;
        frmLogs.MemoLogs.Lines.Add(FullMsg);
        MemoTrim(frmLogs.MemoLogs);
        MemoScrollToEnd(frmLogs.MemoLogs);
      end);
end;

procedure FlushBootLogToMemo;
var
  i: Integer;
begin
  if FBootToMemoDone then
    Exit;
  if not(Assigned(frmLogs) and Assigned(frmLogs.MemoLogs)) then
    Exit;
  FBootToMemoDone := True;
  if FBootLines <> nil then
    begin
      EnsureLogMutex;
      FLogMutex.Enter;
      try
        frmLogs.MemoLogs.Lines.BeginUpdate;
        try
          for i := 0 to FBootLines.Count - 1 do
            frmLogs.MemoLogs.Lines.Add(FBootLines[i]);
        finally
          frmLogs.MemoLogs.Lines.EndUpdate;
        end;
      finally
        FLogMutex.Leave;
      end;
      MemoTrim(frmLogs.MemoLogs);
    end;
  MemoScrollToEnd(frmLogs.MemoLogs);
  LogStopBootIfDone;
end;

procedure TfrmLogs.btnClearLogClick(Sender: TObject);
begin
  MemoLogs.Lines.Clear;
end;

procedure TfrmLogs.cbLogLevelClick(Sender: TObject);
begin
  cfg.LogLevel := TLogLevel(cbLogLevel.ItemIndex); // les items suivent CLogLevelNames
  LogMsg('Niveau de log = ' + LogLevelToStr(cfg.LogLevel), lvNotice);
  cfgSaveSettings(cfg);
end;

procedure TfrmLogs.chkLogToFileClick(Sender: TObject);
begin
  cfg.LogToFile := chkLogToFile.Checked;
  if cfg.LogToFile then
    InitLogFile
  else
    CloseLogFile; // lache/rend le handle du fichier
  cfgSaveSettings(cfg);
end;

procedure TfrmLogs.chkLogToMemoClick(Sender: TObject);
begin
  cfg.LogToMemo := chkLogToMemo.Checked;
  cfgSaveSettings(cfg);
end;

procedure TfrmLogs.chkTimestampClick(Sender: TObject);
begin
  cfg.LogTimestamp := chkTimestamp.Checked;
  cfgSaveSettings(cfg);
end;

procedure TfrmLogs.chkThrottleClick(Sender: TObject);
begin
  cfg.LogThrottle := chkThrottle.Checked;
  cfgSaveSettings(cfg);
end;

procedure TfrmLogs.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  cfg.Frmlogs_Left := frmLogs.Left;
  cfg.Frmlogs_Top := frmLogs.Top;
  cfg.Frmlogs_Width := frmLogs.Width;
  cfg.Frmlogs_Height := frmLogs.Height;
end;

procedure TfrmLogs.FormShow(Sender: TObject);
begin
  ValidateFormBounds(cfg.Frmlogs_Left, cfg.Frmlogs_Top, cfg.Frmlogs_Width, cfg.Frmlogs_Height);
  Left := cfg.Frmlogs_Left;
  Top := cfg.Frmlogs_Top;
  Width := cfg.Frmlogs_Width;
  Height := cfg.Frmlogs_Height;

  chkLogToMemo.Checked := cfg.LogToMemo;
  chkLogToFile.Checked := cfg.LogToFile;
  cbLogLevel.ItemIndex := Integer(cfg.LogLevel);
  chkThrottle.Checked := cfg.LogThrottle;
  chkTimestamp.Checked := cfg.LogTimestamp;
  FlushBootLogToMemo; // le demarrage apparait retroactivement dans le memo
end;

function LogIsOn(Level: TLogLevel): Boolean;
begin
  Result := (Level >= cfg.LogLevel) and (cfg.LogToFile or cfg.LogToMemo);
end;

procedure LogT(const Fmt: string; const Args: array of const);
begin
  if lvTrace >= cfg.LogLevel then
    LogMsg(SafeFmt(Fmt, Args), lvTrace);
end;

procedure LogT(const sLog: string);
begin
  if lvTrace >= cfg.LogLevel then
    LogMsg(sLog, lvTrace);
end;

procedure LogD(const Fmt: string; const Args: array of const);
begin
  if lvDebug >= cfg.LogLevel then
    LogMsg(SafeFmt(Fmt, Args), lvDebug);
end;

procedure LogD(const sLog: string);
begin
  if lvDebug >= cfg.LogLevel then
    LogMsg(sLog, lvDebug);
end;

procedure LogI(const Fmt: string; const Args: array of const);
begin
  if lvInfo >= cfg.LogLevel then
    LogMsg(SafeFmt(Fmt, Args), lvInfo);
end;

procedure LogI(const sLog: string);
begin
  if lvInfo >= cfg.LogLevel then
    LogMsg(sLog, lvInfo);
end;

procedure LogN(const Fmt: string; const Args: array of const);
begin
  if lvNotice >= cfg.LogLevel then
    LogMsg(SafeFmt(Fmt, Args), lvNotice);
end;

procedure LogN(const sLog: string);
begin
  if lvNotice >= cfg.LogLevel then
    LogMsg(sLog, lvNotice);
end;

procedure LogW(const Fmt: string; const Args: array of const);
begin
  if lvWarn >= cfg.LogLevel then
    LogMsg(SafeFmt(Fmt, Args), lvWarn);
end;

procedure LogW(const sLog: string);
begin
  if lvWarn >= cfg.LogLevel then
    LogMsg(sLog, lvWarn);
end;

procedure LogE(const Fmt: string; const Args: array of const);
begin
  if lvError >= cfg.LogLevel then
    LogMsg(SafeFmt(Fmt, Args), lvError);
end;

procedure LogE(const sLog: string);
begin
  if lvError >= cfg.LogLevel then
    LogMsg(sLog, lvError);
end;

//if LogIsOn(lvWarn) and LogOnce(FOnceDeq, 'DQ'+IntToStr(SrcType)) then
//  LogW('[DEQUANT] pas de routine DLL pour %s -> Delphi natif (plus lent)', [GGMLTypeToStr(SrcType)]);

function LogOnce(var Seen: TStrings; const Key: string): Boolean;
begin
  EnsureLogMutex;
  FOnceLock.Enter;
  try
    if Seen = nil then
      Seen := TStringList.Create;
    Result := Seen.IndexOf(Key) < 0;
    if Result then
      Seen.Add(Key);
  finally
    FOnceLock.Leave;
  end;
end;

initialization
  // FLogMutex := TCriticalSection.Create;
  if (FBootLines = nil) then
    FBootLines := TStringList.Create;
  EnsureLogMutex;
  FOnceLock := TCriticalSection.Create;

finalization
  CloseLogFile;
  FreeAndNil(FBootLines);
  if Assigned(FOnceDeq) then
    FreeAndNil(FOnceDeq);
  FreeAndNil(FLogMutex);
  FreeAndNil(FOnceLock);


end.
