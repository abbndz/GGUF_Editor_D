unit uSplitMerge;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms, Dialogs, StdCtrls, ExtCtrls,
  uGGUFWriter, uAppConfig, uGGUFModel, ComCtrls, uLangManager;

type
  TfrmSplitMerge = class(TForm)
    grpSplit: TGroupBox;
    lblSrc: TLabel;
    edtSrc: TEdit;
    btnBrowseSrc: TButton;
    lblBaseOut: TLabel;
    edtSplitOut: TEdit;
    btnSplit: TButton;
    grpMerge: TGroupBox;
    lblParts: TLabel;
    lbParts: TListBox;
    btnAddParts: TButton;
    btnClearParts: TButton;
    lblOut: TLabel;
    edtMergeOut: TEdit;
    btnBrowseOut: TButton;
    btnMerge: TButton;
    OpenDialog1: TOpenDialog;
    OpenDialogParts: TOpenDialog;
    SaveDialog1: TSaveDialog;
    pnlBottom: TPanel;
    btnClose: TButton;
    edtPrefixSplit: TEdit;
    edtPrefixMerge: TEdit;
    StatusBar1: TStatusBar;
    ProgressBar2: TProgressBar;
    ProgressBar1: TProgressBar;
    procedure FormCreate(Sender: TObject);
    procedure btnBrowseSrcClick(Sender: TObject);
    procedure btnSplitClick(Sender: TObject);
    procedure btnAddPartsClick(Sender: TObject);
    procedure btnClearPartsClick(Sender: TObject);
    procedure btnBrowseOutClick(Sender: TObject);
    procedure btnMergeClick(Sender: TObject);
    procedure btnCloseClick(Sender: TObject);
  private
    function CollectPartFiles: TStringList;
    procedure SplitProgress(const Msg: string; ATensorIdx, ATensorTotal, AByteIdx, AByteTotal: Int64);
    procedure MergeProgress(const Msg: string; ATensorIdx, ATensorTotal, AByteIdx, AByteTotal: Int64);
  public
  end;

procedure smLogMsg(const S: string);

var
  frmSplitMerge: TfrmSplitMerge;

implementation

uses uGGUFReader, uGGUFParts, uLog;

{$R *.dfm}

procedure smLogMsg(const S: string);
begin
  TThread.Queue(nil,
    procedure
    begin
      frmSplitMerge.StatusBar1.Panels[0].Text := S;
    end);

  // Logging fichier/debug
  if Assigned(frmLogs) then
    LogMsg('[SplitMerge]  ' + S)
  else
    OutputDebugString(PChar('[SplitMerge]  ' + S));
end;

procedure TfrmSplitMerge.FormCreate(Sender: TObject);
begin
  Caption := 'Split / Merge GGUF';

  OpenDialog1.Filter := 'GGUF (*.gguf)|*.gguf|All (*.*)|*.*';
  OpenDialogParts.Filter := 'GGUF parts (*.gguf)|*.gguf|All (*.*)|*.*';
  OpenDialogParts.Options := OpenDialogParts.Options + [ofAllowMultiSelect];

  SaveDialog1.Filter := 'GGUF (*.gguf)|*.gguf|All (*.*)|*.*';
end;

procedure TfrmSplitMerge.SplitProgress(const Msg: string; ATensorIdx, ATensorTotal, AByteIdx, AByteTotal: Int64);
begin
  TThread.Queue(nil,
    procedure
    begin
      ProgressBar1.Position := ATensorIdx;
      ProgressBar1.Max := ATensorTotal;
      ProgressBar2.Position := AByteIdx;
      ProgressBar2.Max := AByteTotal;
      // smLogMsg(Format('Split %s | %.2f/%.2f MiB', [Msg, AByteIdx / 1024 / 1024, AByteTotal / 1024 / 1024]));
      smLogMsg(mLang.gMsgFmt('FSM.SplitProgress', [Msg, AByteIdx / 1024 / 1024, AByteTotal / 1024 / 1024]));
      Application.ProcessMessages;
    end);
end;

procedure TfrmSplitMerge.MergeProgress(const Msg: string; ATensorIdx, ATensorTotal, AByteIdx, AByteTotal: Int64);
var
  pct: Integer;
begin
  TThread.Queue(nil,
    procedure
    begin
      if ATensorTotal > 0 then
        pct := Round((ATensorIdx / ATensorTotal) * 100)
      else
        pct := 0;
      if pct < 0 then
        pct := 0
      else if pct > 100 then
        pct := 100;
      ProgressBar1.Position := pct;

      ProgressBar2.Position := AByteIdx;
      ProgressBar2.Max := AByteTotal;

      if AByteTotal > 0 then
        smLogMsg(Format('Merge %s | %.2f/%.2f MiB', [Msg, AByteIdx / 1024 / 1024, AByteTotal / 1024 / 1024]))
        // smLogMsg(mLang.gMsgFmt('FSM.MergeProgress', [Msg, AByteIdx / 1024 / 1024, AByteTotal / 1024 / 1024]))

      else
        smLogMsg(Format('Merge %s', [Msg]));
      // smLogMsg(mLang.gMsgFmt('FSM.MergeProgress', [Msg]));

      Application.ProcessMessages;
    end);
end;

procedure TfrmSplitMerge.btnBrowseSrcClick(Sender: TObject);
var
  ssfn, ssfn0, ssPrefix: String;
  I: Integer;
begin
  if OpenDialog1.Execute then
  begin
    if (edtSrc.Text <> OpenDialog1.FileName) and FileExists(OpenDialog1.FileName) then
    begin
      edtSrc.Text := OpenDialog1.FileName;
      ssPrefix := edtPrefixSplit.Text;
      I := 1;
      ssfn0 := ChangeFileExt(OpenDialog1.FileName, '') + ssPrefix;
      ssfn := ssfn0 + IntToStr(I) + '.gguf';
      While FileExists(ssfn) do
      begin
        Inc(I);
        if I > 100 then
          Break;
        ssfn := ssfn0 + IntToStr(I) + '.gguf';
      end;
      edtSplitOut.Text := ssfn;
      // smLogMsg('Source sélectionnée: ' + edtSrc.Text);
      smLogMsg(mLang.gMsgFmt('FSM.SourceSelected', [edtSrc.Text]));

      ssPrefix := edtPrefixMerge.Text;
      I := 1;
      ssfn0 := ChangeFileExt(OpenDialog1.FileName, '') + ssPrefix;
      ssfn := ssfn0 + IntToStr(I) + '.gguf';
      While FileExists(ssfn) do
      begin
        Inc(I);
        if I > 100 then
          Break;
        ssfn := ssfn0 + IntToStr(I) + '.gguf';
      end;
      edtMergeOut.Text := ssfn;

    end;
  end;
end;

procedure TfrmSplitMerge.btnSplitClick(Sender: TObject);
var
  Model: TGGUFFile;
  Src, sSplitOu: string;
  MaxB: Int64;
begin
  Src := Trim(edtSrc.Text);
  sSplitOu := Trim(edtSplitOut.Text);
  if (Src = '') or (not FileExists(Src)) then
  begin
    // MessageDlg('Source invalide.', mtWarning, [mbOK], 0);
    MessageDlg(mLang.gMsg('FSM.InvalidSource'), mtWarning, [mbOK], 0);
    Exit;
  end;
  if sSplitOu = '' then
  begin
    // MessageDlg('BaseOut vide.', mtWarning, [mbOK], 0);
    MessageDlg(mLang.gMsg('FSM.EmptyBaseOut'), mtWarning, [mbOK], 0);
    Exit;
  end;

  try
    MaxB := cfg.SplitSizeMBytes;
    // smLogMsg(Format('Split démarré: %s | Max=%d MB', [Src, MaxB div (1024 * 1024)]));
    smLogMsg(mLang.gMsgFmt('FSM.SplitStarted', [Src, MaxB div (1024 * 1024)]));
    Model := TGGUFReader.LoadFromFile(Src);
    try
      TGGUFWriter.SaveAs(Model, sSplitOu, MaxB, cfg.SaveMetaSeparate, True, SplitProgress);
      // smLogMsg('Split terminé. Fichiers: ' + sSplitOu + '-00001-of-0000N.gguf');
      smLogMsg(mLang.gMsgFmt('FSM.SplitFinishedFiles', [sSplitOu + '-00001-of-0000N.gguf']));
      // MessageDlg('Split terminé.', mtInformation, [mbOK], 0);
      MessageDlg(mLang.gMsg('FSM.SplitFinished'), mtInformation, [mbOK], 0);
    finally
      Model.Free;
    end;
  except
    on E: Exception do
    begin
      // smLogMsg('ERREUR Split: ' + E.Message);
      smLogMsg(mLang.gMsgFmt('FSM.SplitError', [E.Message]));
      // MessageDlg('Erreur: ' + E.Message, mtError, [mbOK], 0);
      MessageDlg(mLang.gMsgFmt('FSM.SplitError', [E.Message]), mtError, [mbOK], 0);
    end;
  end;
end;

procedure TfrmSplitMerge.btnAddPartsClick(Sender: TObject);
var
  I: Integer;
begin
  if OpenDialogParts.Execute then
  begin
    for I := 0 to OpenDialogParts.Files.Count - 1 do
    begin
      if lbParts.Items.IndexOf(OpenDialogParts.Files[I]) < 0 then
        lbParts.Items.Add(OpenDialogParts.Files[I]);
    end;
    // smLogMsg(Format('%d part(s) ajoutée(s). Total=%d', [OpenDialogParts.Files.Count, lbParts.Items.Count]));
    smLogMsg(mLang.gMsgFmt('FSM.PartsAdded', [OpenDialogParts.Files.Count, lbParts.Items.Count]));
  end;
end;

procedure TfrmSplitMerge.btnClearPartsClick(Sender: TObject);
begin
  lbParts.Items.Clear;
  // smLogMsg('Liste des parts vidée.');
  smLogMsg(mLang.gMsg('FSM.PartsListCleared'));
end;

procedure TfrmSplitMerge.btnBrowseOutClick(Sender: TObject);
begin
  if SaveDialog1.Execute then
  begin
    edtMergeOut.Text := SaveDialog1.FileName;
    // smLogMsg('Sortie merge: ' + edtMergeOut.Text);
    smLogMsg(mLang.gMsgFmt('FSM.MergeOutput', [edtMergeOut.Text]));
  end;
end;

function TfrmSplitMerge.CollectPartFiles: TStringList;
var
  I: Integer;
begin
  Result := TStringList.Create;
  for I := 0 to lbParts.Items.Count - 1 do
    Result.Add(lbParts.Items[I]);
end;

procedure TfrmSplitMerge.btnMergeClick(Sender: TObject);
var
  Parts: TStringList;
  OutFile: string;
begin
  OutFile := Trim(edtMergeOut.Text);
  if OutFile = '' then
  begin
    // MessageDlg('Définissez un fichier de sortie merge.', mtWarning, [mbOK], 0);
    MessageDlg(mLang.gMsg('FSM.SetMergeOutput'), mtWarning, [mbOK], 0);
    Exit;
  end;

  if lbParts.Items.Count = 0 then
  begin
    // MessageDlg('Ajoutez au moins un fichier part à merger.', mtWarning, [mbOK], 0);
    MessageDlg(mLang.gMsg('FSM.AddParts'), mtWarning, [mbOK], 0);
    Exit;
  end;

  Parts := CollectPartFiles;
  try
    // smLogMsg(Format('Merge démarré: parts=%d | out=%s', [Parts.Count, OutFile]));
    smLogMsg(mLang.gMsgFmt('FSM.MergeStarted', [Parts.Count, OutFile]));
    TGGUFWriter.MergeParts(Parts, OutFile, MergeProgress);
    // smLogMsg('Merge terminé.');
    smLogMsg(mLang.gMsg('FSM.MergeFinished'));
    // MessageDlg('Merge terminé: ' + OutFile, mtInformation, [mbOK], 0);
    MessageDlg(mLang.gMsgFmt('FSM.MergeFinishedFile', [OutFile]), mtInformation, [mbOK], 0);
  except
    on E: Exception do
    begin
      // smLogMsg('ERREUR Merge: ' + E.Message);
      smLogMsg(mLang.gMsgFmt('FSM.MergeError', [E.Message]));
      // MessageDlg('Erreur Merge: ' + E.Message, mtError, [mbOK], 0);
      MessageDlg(mLang.gMsgFmt('FSM.MergeError', [E.Message]), mtError, [mbOK], 0);
    end;
  end;
  Parts.Free;
end;

procedure TfrmSplitMerge.btnCloseClick(Sender: TObject);
begin
  Close;
end;

end.
