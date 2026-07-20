unit uLog;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ComCtrls, Vcl.ExtCtrls, Vcl.Menus,
  System.SyncObjs, System.IOUtils;

type
  TfrmLogs = class(TForm)
    pnlLogTop: TPanel;
    lblInfoLogs: TLabel;
    btnClearLog: TButton;
    StatusBar1: TStatusBar;
    MemoLogs: TMemo;
    chkLogToFile: TCheckBox;
    chkLogToMemo: TCheckBox;
    procedure btnClearLogClick(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure chkLogToMemoClick(Sender: TObject);
    procedure chkLogToFileClick(Sender: TObject);
  end;

var
  frmLogs: TfrmLogs;
  LogFilePath: string = ''; // Chemin auto-généré
  FLastUILogUpdateTick: Int64;

procedure LogMsg(const Msg: string);
procedure InitLogFile;
procedure CloseLogFile;

implementation

uses ShellAPI, uAppConfig;

{$R *.dfm}

var
  FLogStream: TStreamWriter;
  FLogMutex: TCriticalSection;

procedure InitLogFile;
begin
  if LogFilePath = '' then
  begin
    LogFilePath := IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0))) + 'Logs\';
    if not DirectoryExists(LogFilePath) then
      ForceDirectories(LogFilePath);
    LogFilePath := LogFilePath + 'Logs_' + FormatDateTime('yyyy-mm-dd', Now) + '.txt';
  end;

  if FLogStream = nil then
  begin
    FLogMutex := TCriticalSection.Create;
    FLogStream := TStreamWriter.Create(LogFilePath, True, TEncoding.UTF8);
  end;
end;

procedure CloseLogFile;
begin
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
  if Assigned(FLogMutex) then
  begin
    FLogMutex.Free;
    FLogMutex := nil;
  end;
end;

procedure LogMsg(const Msg: string);
var
  FullMsg: string;
  CurrentUIUpdateTick: Int64;
begin
  if (not Assigned(frmLogs) or not Assigned(frmLogs.MemoLogs)) and not cfg.LogToMemo and not cfg.LogToFile then
  begin
    // OutputDebugString(PChar('[LOGS]  ' + Msg));
    exit;
  end;
  CurrentUIUpdateTick := GetTickCount64;
  if (CurrentUIUpdateTick - FLastUILogUpdateTick < 50) then
    exit;
  FLastUILogUpdateTick := CurrentUIUpdateTick;
  FullMsg := FormatDateTime('[yyyy-mm-dd hh:nn:ss.zzz] ', Now) + Msg;

  TThread.Queue(nil,
    procedure
    begin
      // UI
      if cfg.LogToMemo and Assigned(frmLogs) and Assigned(frmLogs.MemoLogs) then
      begin
        frmLogs.MemoLogs.Lines.Add(FullMsg);
        SendMessage(frmLogs.MemoLogs.Handle, EM_LINESCROLL, 0, frmLogs.MemoLogs.Lines.Count);
      end;

      // Fichier (Thread-safe)
      if cfg.LogToFile then
      begin
        if not Assigned(FLogStream) then
          InitLogFile;
        FLogMutex.Enter;
        try
          FLogStream.WriteLine(FullMsg);
        finally
          FLogMutex.Leave;
        end;
      end;
    end);
end;

procedure TfrmLogs.btnClearLogClick(Sender: TObject);
begin
  MemoLogs.Lines.Clear;
end;

procedure TfrmLogs.chkLogToFileClick(Sender: TObject);
begin
  cfg.LogToFile := chkLogToFile.Checked;
end;

procedure TfrmLogs.chkLogToMemoClick(Sender: TObject);
begin
  cfg.LogToMemo := chkLogToMemo.Checked;
end;

procedure TfrmLogs.FormShow(Sender: TObject);
begin
  chkLogToMemo.Checked := cfg.LogToMemo;
  chkLogToFile.Checked := cfg.LogToFile;
end;

end.
