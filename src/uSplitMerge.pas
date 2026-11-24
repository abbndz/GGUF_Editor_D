unit uSplitMerge;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, ExtCtrls, ComCtrls, System.UITypes, uGGUFWriter, uAppConfig,
  uGGUFModel, uLangManager, uSaveProgress, uLog, uStrUtils;

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
    FBusy: Boolean;

    function CollectPartFiles: TStringList;
    procedure SetBusy(B: Boolean);

    // Version "thread-safe" : appelée depuis le worker, elle poste sur la VCL
    procedure SplitProgress(const Info: TProgressInfo);
    procedure MergeProgress(const Msg: string; ATensorIdx, ATensorTotal, AByteIdx, AByteTotal: Int64; Level: TLogLevel = lvTrace);

    // Version "UI" : exécutée dans le thread principal
    procedure ApplySplitProgress(const Info: TProgressInfo);
    procedure ApplyMergeProgress(const Msg: string; ATensorIdx, ATensorTotal, AByteIdx, AByteTotal: Int64; Level: TLogLevel = lvTrace);

    procedure LogProgress(const S: string; Level: TLogLevel = lvTrace);
  public
  end;

procedure smLogMsg(const S: string);

var
  frmSplitMerge: TfrmSplitMerge;

implementation

uses
  Math,
  uGGUFReader, uGGUFParts;

{$R *.dfm}

procedure smLogMsg(const S: string);
begin
  LogMsg('[SplitMerge] ' + S);
  if not Assigned(frmSplitMerge) then
    Exit;
  TThread.Queue(nil,
    procedure
    begin
      if not Assigned(frmSplitMerge) then
        Exit;
      frmSplitMerge.StatusBar1.Panels[0].Text := S;
    end);
end;

procedure TfrmSplitMerge.FormCreate(Sender: TObject);
begin
  Caption := 'Split / Merge GGUF';

  OpenDialog1.Filter := 'GGUF (*.gguf)|*.gguf|All (*.*)|*.*';
  OpenDialogParts.Filter := 'GGUF parts (*.gguf)|*.gguf|All (*.*)|*.*';
  OpenDialogParts.Options := OpenDialogParts.Options + [ofAllowMultiSelect];

  SaveDialog1.Filter := 'GGUF (*.gguf)|*.gguf|All (*.*)|*.*';

  ProgressBar1.Min := 0;
  ProgressBar1.Max := 100;
  ProgressBar1.Position := 0;

  ProgressBar2.Min := 0;
  ProgressBar2.Max := 100;
  ProgressBar2.Position := 0;

  FBusy := false;

  SetBusy(false);
end;

procedure TfrmSplitMerge.SetBusy(B: Boolean);
begin
  FBusy := B;

  btnSplit.Enabled := not B;
  btnMerge.Enabled := not B;

  btnBrowseSrc.Enabled := not B;
  btnAddParts.Enabled := not B;
  btnClearParts.Enabled := not B;
  btnBrowseOut.Enabled := not B;
  btnClose.Enabled := not B;
end;

procedure TfrmSplitMerge.LogProgress(const S: string; Level: TLogLevel = lvTrace);
begin
  if S = '' then
    Exit;
  LogMsg('[SplitMerge] ' + S, Level);
end;

procedure TfrmSplitMerge.ApplySplitProgress(const Info: TProgressInfo);
var
  PctGlobal, PctTensor: Integer;
  S: string;
begin
  // ProgressBar1 = progression globale
  ProgressBar1.Max := 100;
  PctGlobal := PctD(Info.GlobalBytesDone, Info.GlobalBytesTotal);
  if Info.Kind = pkDone then
    PctGlobal := 100
  else if PctGlobal > 99 then
    PctGlobal := 99;
  ProgressBar1.Position := PctGlobal;

  // ProgressBar2 = progression du tenseur courant
  ProgressBar2.Max := 100;
  PctTensor := PctD(Info.TensorBytesDone, Info.TensorBytesTotal);
  if PctTensor > 100 then
    PctTensor := 100;
  ProgressBar2.Position := PctTensor;

  case Info.Kind of
    pkHeader:
      if Info.IsMetaPart then
        S := Format('Part %d/%d : metadata (header-only file)', [Info.PartNo, Info.PartTot])
      else
        S := Format('Part %d/%d : %s', [Info.PartNo, Info.PartTot, ExtractFileName(Info.SourceFile)]);

    pkTensorStart:
      S := Format('Tensor %d/%d : %s', [Info.TensorIdx, Info.TensorTotal, Info.Msg]);

    pkTensorProg:
      S := Format('Tensor %d/%d : %s  %s/%s', [Info.TensorIdx, Info.TensorTotal, Info.Msg,
        FormatBytes2f(Info.TensorBytesDone), FormatBytes2f(Info.TensorBytesTotal)]);

    pkPartDone:
      S := Format('Part %d/%d written : %s | global %d%%', [Info.PartNo, Info.PartTot, FormatBytes2f(Info.PartBytes),
        PctD(Info.GlobalBytesDone, Info.GlobalBytesTotal)]);

    pkDone:
      S := 'Split completed';

    pkCancelled:
      S := 'Split cancelled';
  else
    if Info.Msg <> '' then
      S := Info.Msg
    else
      S := 'Split...';
  end;

  StatusBar1.Panels[0].Text := S;

  // Log fichier sans trop polluer
  case Info.Kind of
    pkHeader, pkTensorStart, pkPartDone, pkDone, pkCancelled:
      LogProgress(S, lvNotice);
    pkTensorProg:
      LogProgress(S, lvTrace);
  else
    if Info.Msg <> '' then
      LogProgress(S, lvInfo);
  end;
end;

procedure TfrmSplitMerge.ApplyMergeProgress(const Msg: string; ATensorIdx, ATensorTotal, AByteIdx, AByteTotal: Int64; Level: TLogLevel = lvTrace);
var
  Pct1, Pct2: Integer;
  S: string;
begin
  // Important : forcer Max=100 pour la barre 1, sinon Merge hérite parfois du Max du Split
  ProgressBar1.Max := 100;

  if ATensorTotal > 0 then
    Pct1 := PctD(ATensorIdx, ATensorTotal)
  else
    Pct1 := 0;

  if Pct1 > 100 then
    Pct1 := 100;

  ProgressBar1.Position := Pct1;

  ProgressBar2.Max := 100;

  if AByteTotal > 0 then
    Pct2 := PctD(AByteIdx, AByteTotal)
  else
    Pct2 := 0;

  if Pct2 > 100 then
    Pct2 := 100;

  ProgressBar2.Position := Pct2;

  if AByteTotal > 0 then
    S := Format('Merge %s | %s / %s', [Msg, FormatBytes2f(AByteIdx), FormatBytes2f(AByteTotal)])
  else
    S := Format('Merge %s', [Msg]);

  StatusBar1.Panels[0].Text := S;
  LogProgress(S, Level);
end;

procedure TfrmSplitMerge.SplitProgress(const Info: TProgressInfo);
var
  LInfo: TProgressInfo;
begin
  // Copie locale pour éviter tout souci de capture/threading
  LInfo := Info;

  TThread.Queue(nil,
    procedure
    begin
      if not Assigned(frmSplitMerge) then
        Exit;
      frmSplitMerge.ApplySplitProgress(LInfo);
    end);
end;

procedure TfrmSplitMerge.MergeProgress(const Msg: string; ATensorIdx, ATensorTotal, AByteIdx, AByteTotal: Int64;
 Level: TLogLevel = lvTrace);
var
  LMsg: string;
  LT1, LT2, LA, LB: Int64;
begin
  LMsg := Msg;
  LT1 := ATensorIdx;
  LT2 := ATensorTotal;
  LA := AByteIdx;
  LB := AByteTotal;

  TThread.Queue(nil,
    procedure
    begin
      if not Assigned(frmSplitMerge) then
        Exit;
      frmSplitMerge.ApplyMergeProgress(LMsg, LT1, LT2, LA, LB);
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

      // Split default output
      ssPrefix := edtPrefixSplit.Text;
      I := 1;
      ssfn0 := ChangeFileExt(OpenDialog1.FileName, '') + ssPrefix;
      ssfn := ssfn0 + IntToStr(I) + '.gguf';
      while FileExists(ssfn) do
      begin
        Inc(I);
        if I > 100 then
          Break;
        ssfn := ssfn0 + IntToStr(I) + '.gguf';
      end;
      edtSplitOut.Text := ssfn;

      // Merge default output
      ssPrefix := edtPrefixMerge.Text;
      I := 1;
      ssfn0 := ChangeFileExt(OpenDialog1.FileName, '') + ssPrefix;
      ssfn := ssfn0 + IntToStr(I) + '.gguf';
      while FileExists(ssfn) do
      begin
        Inc(I);
        if I > 100 then
          Break;
        ssfn := ssfn0 + IntToStr(I) + '.gguf';
      end;
      edtMergeOut.Text := ssfn;

      smLogMsg(mLang.gMsgFmt('FSM.SourceSelected', [edtSrc.Text]));
    end;
  end;
end;

procedure TfrmSplitMerge.btnSplitClick(Sender: TObject);
var
  Src, OutFile: string;
  MaxB: Int64;
  SaveMetaSeparate: Boolean;
begin
  if FBusy then
    Exit;

  Src := Trim(edtSrc.Text);
  OutFile := Trim(edtSplitOut.Text);

  if (Src = '') or (not FileExists(Src)) then
  begin
    MessageDlg(mLang.gMsg('FSM.InvalidSource'), mtWarning, [mbOK], 0);
    Exit;
  end;

  if OutFile = '' then
  begin
    MessageDlg(mLang.gMsg('FSM.EmptyBaseOut'), mtWarning, [mbOK], 0);
    Exit;
  end;

  MaxB := cfg.SplitSizeMBytes;
  SaveMetaSeparate := cfg.SaveMetaSeparate;

  SetBusy(True);

  ProgressBar1.Max := 100;
  ProgressBar1.Position := 0;
  ProgressBar2.Max := 100;
  ProgressBar2.Position := 0;

  smLogMsg(mLang.gMsgFmt('FSM.SplitStarted', [Src, MaxB div (1024 * 1024)]));

  TThread.CreateAnonymousThread(
    procedure
    var
      Model: TGGUFFile;
      ErrMsg: string;
    begin
      Model := nil;
      ErrMsg := '';
      try
        try
          Model := TGGUFReader.LoadFromFile(Src);

          TGGUFWriter.SaveAs(Model, OutFile, MaxB, SaveMetaSeparate,
            procedure(const Info: TProgressInfo)
            begin
              if not Assigned(frmSplitMerge) then
                Exit;
              frmSplitMerge.SplitProgress(Info);
            end, nil);
        except
          on E: Exception do
            ErrMsg := E.Message;
        end;
      finally
        if Model <> nil then
          Model.Free;
      end;

      TThread.Queue(nil,
        procedure
        begin
          if not Assigned(frmSplitMerge) then
            Exit;

          frmSplitMerge.SetBusy(false);

          if ErrMsg <> '' then
          begin
            frmSplitMerge.StatusBar1.Panels[0].Text := mLang.gMsgFmt('FSM.SplitError', [ErrMsg]);
            LogMsg('[SplitMerge] ' + mLang.gMsgFmt('FSM.SplitError', [ErrMsg]));
            MessageDlg(mLang.gMsgFmt('FSM.SplitError', [ErrMsg]), mtError, [mbOK], 0);
          end
          else
          begin
            frmSplitMerge.StatusBar1.Panels[0].Text := mLang.gMsgFmt('FSM.SplitFinishedFiles',
              [OutFile + '-00001-of-0000N.gguf']);
            LogMsg('[SplitMerge] ' + mLang.gMsgFmt('FSM.SplitFinishedFiles', [OutFile + '-00001-of-0000N.gguf']));
            MessageDlg(mLang.gMsg('FSM.SplitFinished'), mtInformation, [mbOK], 0);
          end;

          frmSplitMerge.ProgressBar1.Position := 0;
          frmSplitMerge.ProgressBar2.Position := 0;
        end);
    end).Start;
end;

procedure TfrmSplitMerge.btnAddPartsClick(Sender: TObject);
var
  I: Integer;
begin
  if FBusy then
    Exit;

  if OpenDialogParts.Execute then
  begin
    for I := 0 to OpenDialogParts.Files.Count - 1 do
    begin
      if lbParts.Items.IndexOf(OpenDialogParts.Files[I]) < 0 then
        lbParts.Items.Add(OpenDialogParts.Files[I]);
    end;
    smLogMsg(mLang.gMsgFmt('FSM.PartsAdded', [OpenDialogParts.Files.Count, lbParts.Items.Count]));
  end;
end;

procedure TfrmSplitMerge.btnClearPartsClick(Sender: TObject);
begin
  if FBusy then
    Exit;

  lbParts.Items.Clear;
  smLogMsg(mLang.gMsg('FSM.PartsListCleared'));
end;

procedure TfrmSplitMerge.btnBrowseOutClick(Sender: TObject);
begin
  if FBusy then
    Exit;

  if SaveDialog1.Execute then
  begin
    edtMergeOut.Text := SaveDialog1.FileName;
    smLogMsg(mLang.gMsgFmt('FSM.MergeOutput', [edtMergeOut.Text]));
  end;
end;

function TfrmSplitMerge.CollectPartFiles: TStringList;
var
  I: Integer;
begin
  try
    Result := TStringList.Create;
    for I := 0 to lbParts.Items.Count - 1 do
      Result.Add(lbParts.Items[I]);
  finally

  end;
end;

procedure TfrmSplitMerge.btnMergeClick(Sender: TObject);
var
  Parts: TStringList;
  OutFile: string;
begin
  if FBusy then
    Exit;

  OutFile := Trim(edtMergeOut.Text);
  if OutFile = '' then
  begin
    MessageDlg(mLang.gMsg('FSM.SetMergeOutput'), mtWarning, [mbOK], 0);
    Exit;
  end;

  if lbParts.Items.Count = 0 then
  begin
    MessageDlg(mLang.gMsg('FSM.AddParts'), mtWarning, [mbOK], 0);
    Exit;
  end;

  Parts := CollectPartFiles;

  SetBusy(True);

  ProgressBar1.Max := 100;
  ProgressBar1.Position := 0;
  ProgressBar2.Max := 100;
  ProgressBar2.Position := 0;

  smLogMsg(mLang.gMsgFmt('FSM.MergeStarted', [Parts.Count, OutFile]));

  TThread.CreateAnonymousThread(
    procedure
    var
      ErrMsg: string;
    begin
      ErrMsg := '';
      try
        TGGUFWriter.MergeParts(Parts, OutFile, frmSplitMerge.MergeProgress);
      except
        on E: Exception do
          ErrMsg := E.Message;
      end;

      TThread.Queue(nil,
        procedure
        begin
          if not Assigned(frmSplitMerge) then
            Exit;

          frmSplitMerge.SetBusy(false);

          if ErrMsg <> '' then
          begin
            frmSplitMerge.StatusBar1.Panels[0].Text := mLang.gMsgFmt('FSM.MergeError', [ErrMsg]);
            LogMsg('[SplitMerge] ' + mLang.gMsgFmt('FSM.MergeError', [ErrMsg]));
            MessageDlg(mLang.gMsgFmt('FSM.MergeError', [ErrMsg]), mtError, [mbOK], 0);
          end
          else
          begin
            frmSplitMerge.StatusBar1.Panels[0].Text := mLang.gMsgFmt('FSM.MergeFinishedFile', [OutFile]);
            LogMsg('[SplitMerge] ' + mLang.gMsgFmt('FSM.MergeFinishedFile', [OutFile]));
            MessageDlg(mLang.gMsgFmt('FSM.MergeFinishedFile', [OutFile]), mtInformation, [mbOK], 0);
          end;

          frmSplitMerge.ProgressBar1.Position := 0;
          frmSplitMerge.ProgressBar2.Position := 0;
        end);
    end).Start;
end;

procedure TfrmSplitMerge.btnCloseClick(Sender: TObject);
begin
  if FBusy then
  begin
    MessageDlg('Operation in progress...', mtWarning, [mbOK], 0);
    Exit;
  end;
  Close;
end;

end.
