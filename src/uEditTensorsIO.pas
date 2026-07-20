unit uEditTensorsIO;

interface

uses
  Windows, Messages, SysUtils, StrUtils, Classes, Controls, Forms, Dialogs, StdCtrls, ComCtrls, ExtCtrls, Graphics,
  Contnrs, uGGUFModel, uGGUFReader, uGGUFWriter, uGgmlQuants, uGGMLTypes, Generics.Collections, SyncObjs, ShellAPI,
  VCLTee.TeCanvas, uAppConfig, uSafeTensors, uTensorTranspose, uGGMLConstants, uLangManager, uFrmAbout,
  Vcl.Menus, System.Actions, Vcl.ActnList, uTensorsNamesMan;

procedure frmEditTensorsActLoadSrcA1Execute(SrcFile: String);
procedure frmEditTensorsActLoadSrcB2Execute(SrcFile: String);
procedure frmEditTensorsActLoadSrcS3Execute(SrcFile: String);
procedure frmEditTensorsActSaveOutExecute();

procedure frmEditTensorsRebuildView1;
procedure frmEditTensorsRebuildView2;
procedure frmEditTensorsRebuildViewS;
procedure frmEditTensorsRebuildViewOut;

implementation

uses
  uEditTensors, uEditTensorsMan, uMappedNamesManager, uGgufStrUtils;

procedure UpdateTensorInput(var T: TGGUFTensorInfo; SourceId: Integer; UseMap: Boolean);
begin
  T.NameOrg := T.Name;
  if SourceId = 1 then
    T.NameMap := gMapping1.MapName(string(T.Name))
  else if SourceId = 2 then
    T.NameMap := gMapping2.MapName(string(T.Name))
  else if SourceId = 3 then
    T.NameMap := gMappingS.MapName(string(T.Name));
  if UseMap then
  begin
    T.Name := T.NameMap;
    T.IsNameMapped := T.NameOrg <> T.NameMap;
  end
  else
  begin
    T.IsNameMapped := False;
  end;
  T.TensorPatternName := GetTensorPatternName(string(T.Name));
  GetLayerPrefixIndx(string(T.Name), T.LayerIndex);
  T.SourceId := SourceId;
  T.Keep := True;
  T.ByteSizeOrg := T.ByteSize;
  T.TensorTypeOrg := T.TensorType;
end;

procedure frmEditTensorsActLoadSrcA1Execute(SrcFile: String);
begin
  SrcFile := Trim(SrcFile);
  if (SrcFile = '') or (not FileExists(SrcFile)) then
  begin
    // MessageDlg('Sélectionnez un fichier GGUF source valide.', mtWarning, [mbOK], 0);
    MessageDlg(mLang.gMsg('FTE.NoFileSelected'), mtWarning, [mbOK], 0);
    exit;
  end;

  if not frmEditTensors.ActLoadSrcA1.Enabled then
    exit;

  frmEditTensors.ActLoadSrcA1.Enabled := False;
  frmEditTensors.edtSrc1.Text := SrcFile;
  frmEditTensors.ProgressBar1.Position := 0;
  frmEditTensors.ProgressBar1.Visible := True;
  // frmEditTensors.StatusBar1.Panels[0].Text := 'Lecture de l''en-tête GGUF...';
  eLogMsg(mLang.gMsg('FTE.LoadingHeader'));
  Application.ProcessMessages;
  FreeAndNil(frmEditTensors.FModelInp1);
  frmEditTensors.lvTensors1.Items.Clear;
  frmEditTensors.FViewTensors1.Clear;
  // Lancement ASYNCHRONE
  TThread.CreateAnonymousThread(
    procedure
    var
      I, J: Integer;
      T: TGGUFTensorInfo;
    begin
      try
        frmEditTensors.FModelInp1 := TGGUFReader.LoadFromFile(SrcFile, frmEditTensors.OnProgressEventLoad);
        cfg.edtSrc1 := SrcFile;
        // Calcul des infos de couche et Pattern
        for I := 0 to frmEditTensors.FModelInp1.Tensors.Count - 1 do
        begin
          T := TGGUFTensorInfo(frmEditTensors.FModelInp1.Tensors[I]);
          // if cfg.UseIgnoredPrefixes1 and IsIgnoredPrefix(T.Name) then
          // Continue; // Ou supprimez du TObjectList
          UpdateTensorInput(T, 1, cfg.MappingFile1 <> 'NoMappedNames');
        end;
        // Calcule les tailles totales par pattern
        frmEditTensors.FGlobalSize1 := CalculateAllPatternSizes(frmEditTensors.FModelInp1);
        ApplyMappingToModel(frmEditTensors.FModelInp1, gMapping1, cfg.MappingFile1 <> 'NoMappedNames');
        // Initialiser ModelOut avec ModelInp1 par défaut
        frmEditTensors.FModelOut := frmEditTensors.FModelInp1.Clone;
        for I := 0 to frmEditTensors.FModelOut.Tensors.Count - 1 do
        begin
          TGGUFTensorInfo(frmEditTensors.FModelOut.Tensors[I]).SourceId := 1;
        end;
      except
        on e: Exception do
        begin
          TThread.Queue(nil,
            procedure
            begin
              if Assigned(frmEditTensors) then
              begin
                eLogMsg(mLang.gMsgFmt('FileLoadError', [e.Message]));
                MessageDlg(mLang.gMsgFmt('FileLoadError', [e.Message]), mtError, [mbOK], 0);
                FreeAndNil(frmEditTensors.FModelInp1);
              end;
            end)
        end;
      end;
      TThread.Queue(nil,
        procedure
        begin
          if Assigned(frmEditTensors) then
          begin
            frmEditTensors.edtSizeIn1.Text := FormatBytes(frmEditTensors.FGlobalSize1);
            eLogMsg(mLang.gMsg('FTE.Ready'));
            frmEditTensorsRebuildView1;
            frmEditTensorsRebuildViewOut;
            frmEditTensors.ActLoadSrcA1.Enabled := True;
            frmEditTensors.ProgressBar1.Visible := False;
          end;
        end)
    end).Start
end;

procedure frmEditTensorsActLoadSrcB2Execute(SrcFile: String);
var
  I: Integer;
  T: TGGUFTensorInfo;
begin
  SrcFile := Trim(SrcFile);
  if (SrcFile = '') or (not FileExists(SrcFile)) then
  begin
    // MessageDlg('Sélectionnez un fichier GGUF source valide.', mtWarning, [mbOK], 0);
    MessageDlg(mLang.gMsg('FTE.NoFileSelected'), mtWarning, [mbOK], 0);
    exit;
  end;

  if not frmEditTensors.ActLoadSrcB2.Enabled then
    exit;

  frmEditTensors.ActLoadSrcB2.Enabled := False;
  frmEditTensors.edtSrc2.Text := SrcFile;
  frmEditTensors.ProgressBar1.Visible := True;
  frmEditTensors.ProgressBar1.Position := 0;
  // frmEditTensors.StatusBar1.Panels[0].Text := 'Lecture de l''en-tête GGUF...';
  eLogMsg(mLang.gMsg('FTE.LoadingHeader'));
  Application.ProcessMessages;
  FreeAndNil(frmEditTensors.FModelInp2);
  frmEditTensors.lvTensors2.Items.Clear;
  frmEditTensors.FViewTensors2.Clear;
  // Lancement ASYNCHRONE
  TThread.CreateAnonymousThread(
    procedure
    var
      I, J: Integer;
      T: TGGUFTensorInfo;
    begin
      try
        frmEditTensors.FModelInp2 := TGGUFReader.LoadFromFile(SrcFile, frmEditTensors.OnProgressEventLoad);
        cfg.edtSrc2 := SrcFile;
        // Calcul des infos de couche et Pattern
        for I := 0 to frmEditTensors.FModelInp2.Tensors.Count - 1 do
        begin
          T := TGGUFTensorInfo(frmEditTensors.FModelInp2.Tensors[I]);
          // if cfg.UseIgnoredPrefixes2 and IsIgnoredPrefix(T.Name) then
          // Continue;
          UpdateTensorInput(T, 2, cfg.MappingFile2 <> 'NoMappedNames');
        end;
        // Calcule les tailles totales par pattern
        frmEditTensors.FGlobalSize2 := CalculateAllPatternSizes(frmEditTensors.FModelInp2);

        // ApplyMappingToModel(frmEditTensors.FModelInp2, gMapping2, cfg.UseMappedNames2);
        // Initialiser ModelOut avec ModelInp2 par défaut si pas de ModelInp1
        if not Assigned(frmEditTensors.FModelOut) then
        begin
          frmEditTensors.FModelOut := frmEditTensors.FModelInp2.Clone;
          // Mise à jour des infos SourceId pour le modèle de sortie initial
          for I := 0 to frmEditTensors.FModelOut.Tensors.Count - 1 do
          begin
            TGGUFTensorInfo(frmEditTensors.FModelOut.Tensors[I]).SourceId := 2;
          end;
        end;
      except
        on e: Exception do
        begin
          TThread.Queue(nil,
            procedure
            begin
              // eLogMsg('ERREUR Load : ' + e.Message);
              eLogMsg(mLang.gMsg('FTE.LoadError') + e.Message);
              // MessageDlg('Erreur chargement (source2): ' + e.Message, mtError, [mbOK], 0);
              MessageDlg(mLang.gMsgFmt('FileLoadError', [e.Message]), mtError, [mbOK], 0);
              FreeAndNil(frmEditTensors.FModelInp2);
            end)
        end;
      end;
      TThread.Queue(nil,
        procedure
        begin
          frmEditTensors.edtSizeIn2.Text := FormatBytes(frmEditTensors.FGlobalSize2);
          eLogMsg(mLang.gMsg('FTE.Ready'));
          frmEditTensorsRebuildView2;
          // eLogMsg('GGUF chargé (source2): ' + SrcFile);
          // eLogMsg(mLang.gMsgFmt('GGUFLoaded', [2, SrcFile]));
          frmEditTensors.ProgressBar1.Visible := False;
          frmEditTensors.ActLoadSrcB2.Enabled := True;
        end)
    end).Start
end;

procedure frmEditTensorsActLoadSrcS3Execute(SrcFile: String);
begin
  SrcFile := Trim(SrcFile);
  if (SrcFile = '') or (not FileExists(SrcFile)) then
  begin
    // MessageDlg('Sélectionnez un fichier Safetensors valide.', mtWarning, [mbOK], 0);
    MessageDlg(mLang.gMsg('FTE.InvalidSafetensorsFile'), mtWarning, [mbOK], 0);
    exit;
  end;

  if not frmEditTensors.ActLoadSrcS.Enabled then
    exit;

  FreeAndNil(frmEditTensors.FModelInpS);
  // frmEditTensors.lvTensorsS.Items.Clear;
  frmEditTensors.FViewTensorsS.Clear;
  frmEditTensors.ActLoadSrcS.Enabled := False;
  frmEditTensors.edtSrcS.Text := SrcFile;
  frmEditTensors.ProgressBar1.Visible := True;
  frmEditTensors.ProgressBar1.Position := 0;

  // frmEditTensors.StatusBar1.Panels[0].Text := 'Chargement Safetensors (Model S)...';

  eLogMsg(mLang.gMsg('FTE.LoadingSafetensors'));
  // Lancement ASYNCHRONE
  TThread.CreateAnonymousThread(
    procedure
    var
      M: TSafeTensorsMeta;
      I, J: Integer;
      e: TSafeTensorEntry;
      T: TGGUFTensorInfo;
    begin
      try
        eLogMsg('Star LoadSafeTensorsMeta');
        M := LoadSafeTensorsMeta(SrcFile);
        eLogMsg('End LoadSafeTensorsMeta');
        cfg.edtSrcS := SrcFile;
        // frmEditTensors.FGlobalSizeS := M.TotalFileSize; // CalculateGlobalSize(frmEditTensors.FModelInpS);
        // frmEditTensors.edtSizeInS.Text := FormatBytes(frmEditTensors.FGlobalSizeS);
        try
          frmEditTensors.FModelInpS := TGGUFFile.Create;
          frmEditTensors.FModelInpS.Version := 1;
          frmEditTensors.FModelInpS.Alignment := 32;
          frmEditTensors.FModelInpS.TensorCount := M.Entries.Count;
          for I := 0 to M.Entries.Count - 1 do
          begin
            e := M.Entries[I];
            T := TGGUFTensorInfo.Create;
            T.Name := AnsiString(e.Name);
            if cfg.UseIgnoredPrefixesS and IsIgnoredPrefix(T.Name) then
              Continue;
            T.NDims := Length(e.ShapeArray);
            T.TotElems := 1;
            T.Rows := 1;
            T.Cols := 1;
            if T.NDims > 0 then
            begin
              SetLength(T.Dims, T.NDims);
              { for J := 0 to High(e.ShapeArray) do
                begin
                T.Dims[J] := e.ShapeArray[J];
                if J > 0 then
                T.Rows := T.Rows * T.Dims[J];
                end; }
              // INVERSION DES DIMENSIONS
              // On remplit T.Dims en lisant l'array de Safetensors à l'envers
              // Safetensors [A, B] -> GGUF [B, A]
              for J := 0 to T.NDims - 1 do
              begin
                T.Dims[J] := e.ShapeArray[(T.NDims - 1) - J];
                T.TotElems := T.TotElems * T.Dims[J];
              end;
              T.Cols := T.Dims[0];
              T.Rows := T.TotElems div T.Cols;
            end;
            T.TotElems := T.Cols * T.Rows;

            T.TensorTypeOrg := SafeTensorsDTypeToGGML(e.DType);
            T.TensorType := T.TensorTypeOrg;
            T.IsSafetensors := True;
            T.TensorDataFilePos := e.HeaderDataStart; // Début des données = 8 (taille LE) + HeaderSize
            T.Offset := e.OffsetStart; // Offset relatif aux données
            T.SourceOffset := e.OffsetStart;
            T.ByteSize := e.ByteSize;
            T.ByteSizeOrg := e.ByteSize;
            T.SourceFile := e.SourceFile;
            UpdateTensorInput(T, 3, cfg.MappingFileS <> 'NoMappedNames');
            T.TransposFile := TTransposeEngine.GetModelTmpDir(T.SourceFile, string(T.NameOrg));
            if FileExists(T.TransposFile) then
            begin
              TTransposeEngine.SetTransposDims(T);
              // eLogMsg(Format('Tenseur déjà transposé détecté : %s', [string(T.Name)]));
              eLogMsg(mLang.gMsgFmt('TransposeAlreadyDetected', [string(T.Name)]));
            end
            else
            begin
              T.IsTransposed := False;
              T.TransposFile := '';
            end;
            T.Keep := True;
            frmEditTensors.FModelInpS.Tensors.Add(T);
          end;
          frmEditTensors.FGlobalSizeS := CalculateAllPatternSizes(frmEditTensors.FModelInpS);
          eLogMsg('End CalculateAllPatternSizes');
          eLogMsg(mLang.gMsgFmt('SafetensorsLoaded', [SrcFile]));
          eLogMsg(mLang.gMsg('FTE.Ready'));
        finally
          M.Free;
        end;
      except
        on e: Exception do
        begin
          TThread.Queue(nil,
            procedure
            begin
              // eLogMsg('ERREUR Load S: ' + e.Message);
              eLogMsg(mLang.gMsg('FTE.LoadError') + e.Message);
              // MessageDlg('Erreur chargement Safetensors: ' + e.Message, mtError, [mbOK], 0);
              MessageDlg(mLang.gMsgFmt('FileLoadError', [e.Message]), mtError, [mbOK], 0);
              FreeAndNil(frmEditTensors.FModelInpS);
            end)
        end;
      end;
      TThread.Queue(nil,
        procedure
        begin
          frmEditTensors.edtSizeInS.Text := FormatBytes(frmEditTensors.FGlobalSizeS);
          frmEditTensors.ActLoadSrcS.Enabled := True;
          frmEditTensors.ProgressBar1.Visible := False;
          frmEditTensorsRebuildViewS;
          frmEditTensors.lvTensorsS.Invalidate; // Force le rafraîchissement visuel
          // frmEditTensors.StatusBar1.Panels[0].Text := 'Prêt';
        end)
    end).Start
end;

procedure frmEditTensorsActSaveOutExecute();
var
  OutFile, SaveErr: string;
  NewModel: TGGUFFile;
  SigVal: string;
  I: Integer;
begin
  if not Assigned(frmEditTensors.FModelInp1) then
  begin
    // MessageDlg('Chargez un GGUF d''abord.', mtWarning, [mbOK], 0);
    MessageDlg(mLang.gMsg('FTE.ModelNotLoaded'), mtWarning, [mbOK], 0);
    exit;
  end;
  OutFile := Trim(frmEditTensors.edtOut.Text);
  if OutFile = '' then
  begin
    // MessageDlg('Spécifiez un fichier de sortie.', mtWarning, [mbOK], 0);
    MessageDlg(mLang.gMsg('FTE.InvalidOutputPath'), mtWarning, [mbOK], 0);
    exit;
  end;

  frmEditTensorsSyncKeepFromList(frmEditTensors.lvTensorsOut);
  NewModel := frmEditTensors.FModelOut.CloneMetaOnly;
  // 1. Ajout de la signature automatique si activée
  if cfg.UseAutoSignature then
  begin
    // Génération du texte : "Edited by GGUF Editor ++ 2026-07-18 18-30-05"
    SigVal := cfg.AutoSignatureTemplate + ' ' + FormatDateTime('yyyy-mm-dd hh-nn-ss', Now);
    NewModel.SetKV_String('general.edited_by', SigVal);
    // eLogMsg('Signature ajoutée au modèle de sortie.');
    eLogMsg(mLang.gMsg('FTE.SignatureAdded'));
  end;

  try
    for I := 0 to frmEditTensors.FModelOut.Tensors.Count - 1 do
      if TGGUFTensorInfo(frmEditTensors.FModelOut.Tensors[I]).Keep then
        NewModel.Tensors.Add(TGGUFTensorInfo(frmEditTensors.FModelOut.Tensors[I]).Clone);
  except
    NewModel.Free;
    exit;
  end;

  frmEditTensors.FCancelSave := False;
  // Lancement ASYNCHRONE
  TThread.CreateAnonymousThread(
    procedure
    begin
      try
        TGGUFWriter.SaveAs(NewModel, OutFile, cfg.SplitSizeMBytes, cfg.SaveMetaSeparate, cfg.UseFDLL,
          frmEditTensors.OnProgressEventSave, @frmEditTensors.FCancelSave);
      except
        on e: Exception do
          SaveErr := e.Message;
      end;

      TThread.Queue(nil,
        procedure
        begin
          NewModel.Free;
          frmEditTensors.ProgressBar1.Visible := False;
          frmEditTensors.ProgressBar2.Visible := False;
          frmEditTensors.ActSaveOut.Enabled := True;
          frmEditTensors.btnCancel.Enabled := False;
          frmEditTensors.FSaveRunning := False;

          frmEditTensors.FCancelMutex.Enter;
          try
            if frmEditTensors.FCancelSave then
            begin
              // eLogMsg('🧹 Opération annulée. Suppression du fichier incomplet...');
              eLogMsg(mLang.gMsg('FTE.SaveCancelledCleanup'));
              if FileExists(OutFile) then
                DeleteFile(OutFile);
              eLogMsg(mLang.gMsg('FTE.OperationCancelled') + ' | ' + mLang.gMsg('FTE.Ready'));
            end
            else if SaveErr <> '' then
            begin
              eLogMsg(mLang.gMsgFmt('SaveError', [SaveErr]));
              MessageDlg(mLang.gMsgFmt('FileSaveError', [SaveErr]), mtError, [mbOK], 0);
              frmEditTensors.StatusBar1.Panels[0].Text := mLang.gMsg('FTE.Error');
            end
            else
            begin
              eLogMsg(mLang.gMsg('FTE.SaveFinished'));
              MessageDlg(mLang.gMsg('FTE.SaveSuccess'), mtInformation, [mbOK], 0);
              frmEditTensors.StatusBar1.Panels[0].Text := mLang.gMsg('FTE.Ready');
            end;
          finally
            frmEditTensors.FCancelMutex.Leave;
          end;
        end);
    end).Start;
  // UI Setup
  frmEditTensors.ProgressBar1.Visible := True;
  frmEditTensors.ProgressBar2.Visible := True;
  frmEditTensors.ActSaveOut.Enabled := False;
  frmEditTensors.btnCancel.Enabled := True;
  frmEditTensors.FSaveRunning := True;
  // frmEditTensors.StatusBar1.Panels[0].Text := 'Sauvegarde en cours...';
  eLogMsg(mLang.gMsg('FTE.SavingInProgress'));
end;

procedure frmEditTensorsRebuildView1;
var
  I, iCount: Integer;
  T: TGGUFTensorInfo;
  It: TListItem;
  ssf: string;
begin
  if not Assigned(frmEditTensors.FModelInp1) then
    exit;

  iCount := 0;
  frmEditTensors.FViewTensors1.Clear;
  for I := 0 to frmEditTensors.FModelInp1.Tensors.Count - 1 do
  begin
    // ToDo : traitement des T Ignored avec Flag Ignored et pas de save   et ...
    // T := TGGUFTensorInfo(frmEditTensors.FModelInp1.Tensors[I]);
    // T.Keep := False;
    // if cfg.UseIgnoredPrefixes1 and IsIgnoredPrefix(T.Name) then
    // Continue;
    // T.Keep := True;
    // UpadateTensotInput(T, 1, cfg.MappingFile1 <> 'NoMappedNames');
    frmEditTensors.FViewTensors1.Add(frmEditTensors.FModelInp1.Tensors[I]);
  end;
  frmEditTensors.FViewTensors1.Sort(@CompareTensorsByName);

  frmEditTensors.lvTensors1.Items.BeginUpdate;
  try
    frmEditTensors.lvTensors1.Items.Clear;
    for I := 0 to frmEditTensors.FViewTensors1.Count - 1 do
    begin
      T := TGGUFTensorInfo(frmEditTensors.FViewTensors1[I]);
      ssf := Trim(LowerCase(frmEditTensors.edtFilter1.Text));
      if not((ssf = '') or (Pos(ssf, LowerCase(T.Name)) > 0)) then
        Continue;
      It := frmEditTensors.lvTensors1.Items.Add;
      It.Data := T;
      ssf := string(T.Name);
      if T.IsNameMapped then
        ssf := ssf + ' * ';
      It.Caption := ssf;
      // It.Checked := GetKeep(It.Caption); // ou T.Keep
      iCount := iCount + 1;
      frmEditTensorsUpdateRow(It, T, frmEditTensors.FGlobalSize1);
    end;
  finally
    frmEditTensors.lvTensors1.Items.EndUpdate;
    eLogMsg(mLang.gMsgFmt('FTE.TensorsFound', [IntToStr(iCount)]));
  end;
end;

procedure frmEditTensorsRebuildView2;
var
  I, iCount: Integer;
  T: TGGUFTensorInfo;
  It: TListItem;
  ssf: string;
begin
  if not Assigned(frmEditTensors.FModelInp2) then
    exit;
  iCount := 0;
  frmEditTensors.FViewTensors2.Clear;
  for I := 0 to frmEditTensors.FModelInp2.Tensors.Count - 1 do
  begin
    frmEditTensors.FViewTensors2.Add(frmEditTensors.FModelInp2.Tensors[I]);
  end;
  frmEditTensors.FViewTensors2.Sort(@CompareTensorsByName);

  frmEditTensors.lvTensors2.Items.BeginUpdate;
  try
    frmEditTensors.lvTensors2.Items.Clear;
    for I := 0 to frmEditTensors.FViewTensors2.Count - 1 do
    begin
      T := TGGUFTensorInfo(frmEditTensors.FViewTensors2[I]);
      ssf := Trim(LowerCase(frmEditTensors.edtFilter2.Text));
      if not((ssf = '') or (Pos(ssf, LowerCase(T.Name)) > 0)) then
        Continue;
      It := frmEditTensors.lvTensors2.Items.Add;
      It.Data := T;
      ssf := string(T.Name);
      if T.IsNameMapped then
        ssf := ssf + ' * ';
      It.Caption := ssf;
      // It.Checked := GetKeep(It.Caption); // ou T.Keep
      iCount := iCount + 1;
      frmEditTensorsUpdateRow(It, T, frmEditTensors.FGlobalSize2);
    end;
  finally
    frmEditTensors.lvTensors2.Items.EndUpdate;
    eLogMsg(mLang.gMsgFmt('FTE.TensorsFound', [IntToStr(iCount)]));
  end;
end;

procedure frmEditTensorsRebuildViewS_old_No_OnData;
var
  I, iCount: Integer;
  T: TGGUFTensorInfo;
  It: TListItem;
  ssf: string;
begin
  if not Assigned(frmEditTensors.FModelInpS) then
    exit;

  iCount := 0;
  frmEditTensors.FViewTensorsS.Clear;
  for I := 0 to frmEditTensors.FModelInpS.Tensors.Count - 1 do
    frmEditTensors.FViewTensorsS.Add(frmEditTensors.FModelInpS.Tensors[I]);
  frmEditTensors.FViewTensorsS.Sort(@CompareTensorsByName);

  frmEditTensors.lvTensorsS.Items.BeginUpdate;
  try
    frmEditTensors.lvTensorsS.Items.Clear;
    for I := 0 to frmEditTensors.FViewTensorsS.Count - 1 do
    begin
      T := TGGUFTensorInfo(frmEditTensors.FViewTensorsS[I]);
      ssf := Trim(LowerCase(frmEditTensors.edtFilterS.Text));
      if not((ssf = '') or (Pos(ssf, LowerCase(T.Name)) > 0)) then
        Continue;
      It := frmEditTensors.lvTensorsS.Items.Add;
      It.Data := T;
      ssf := string(T.Name);
      if T.IsNameMapped then
        ssf := ssf + ' * ';
      It.Caption := ssf;
      iCount := iCount + 1;
      frmEditTensorsUpdateRow(It, T, frmEditTensors.FGlobalSize1);
    end;
  finally
    frmEditTensors.lvTensorsS.Items.EndUpdate;
    // frmEditTensors.StatusBar1.Panels[0].Text := IntToStr(iCount) + ' Tensors found';
    eLogMsg(mLang.gMsgFmt('FTE.TensorsFound', [IntToStr(iCount)]));
  end;
end;

procedure frmEditTensorsRebuildViewS;
var
  I, iCount: Integer;
  T: TGGUFTensorInfo;
  ssf: string;
begin
  if not Assigned(frmEditTensors.FModelInpS) then
    exit;

  frmEditTensors.FViewTensorsS.Clear;
  iCount := 0;
  for I := 0 to frmEditTensors.FModelInpS.Tensors.Count - 1 do
  begin
    T := TGGUFTensorInfo(frmEditTensors.FModelInpS.Tensors[I]);
    ssf := Trim(LowerCase(frmEditTensors.edtFilterS.Text));
    if (ssf = '') or (Pos(ssf, LowerCase(string(T.NameOrg))) > 0) or (Pos(ssf, LowerCase(string(T.NameMap))) > 0) then
    begin
      frmEditTensors.FViewTensorsS.Add(T);
      iCount := iCount + 1;
    end;
  end;

  frmEditTensors.lvTensorsS.Items.BeginUpdate;
  try
    frmEditTensors.lvTensorsS.Items.Count := frmEditTensors.FViewTensorsS.Count;
  finally
    frmEditTensors.lvTensorsS.Items.EndUpdate;
  end;
  eLogMsg(mLang.gMsgFmt('FTE.TensorsFound', [iCount]));
end;

procedure frmEditTensorsRebuildViewOut;
var
  I, iCount: Integer;
  T: TGGUFTensorInfo;
  It: TListItem;
  ssf: string;
begin
  if not Assigned(frmEditTensors.FModelOut) then
    exit;

  // Recalculer les tailles globales avant d'afficher pour avoir les bons %
  frmEditTensors.FGlobalSizeOut := CalculateAllPatternSizes(frmEditTensors.FModelOut);;
  frmEditTensors.edtSizeOut.Text := FormatBytes(frmEditTensors.FGlobalSizeOut);
  iCount := 0;
  frmEditTensors.FViewTensorsOut.Clear;
  for I := 0 to frmEditTensors.FModelOut.Tensors.Count - 1 do
    frmEditTensors.FViewTensorsOut.Add(frmEditTensors.FModelOut.Tensors[I]);
  frmEditTensors.FViewTensorsOut.Sort(@CompareTensorsByName);

  frmEditTensors.lvTensorsOut.Items.BeginUpdate;
  try
    frmEditTensors.lvTensorsOut.Items.Clear;
    for I := 0 to frmEditTensors.FViewTensorsOut.Count - 1 do
    begin
      T := TGGUFTensorInfo(frmEditTensors.FViewTensorsOut[I]);
      ssf := Trim(LowerCase(frmEditTensors.edtFilterO.Text));
      if not((ssf = '') or (Pos(ssf, LowerCase(T.Name)) > 0)) then
        Continue;

      It := frmEditTensors.lvTensorsOut.Items.Add;
      It.Data := T;
      ssf := string(T.Name);
      if T.IsNameMapped then
        ssf := ssf + ' * ';
      It.Caption := ssf;
      // It.Checked := GetKeep(It.Caption); // ou T.Keep
      It.Checked := T.Keep;
      iCount := iCount + 1;
      frmEditTensorsUpdateRow(It, T, frmEditTensors.FGlobalSizeOut);
    end;
  finally
    frmEditTensors.lvTensorsOut.Items.EndUpdate;
    // frmEditTensors.StatusBar1.Panels[0].Text := IntToStr(iCount) + ' Tensors found';
    eLogMsg(mLang.gMsgFmt('FTE.TensorsFound', [iCount]));
  end;
end;

end.
