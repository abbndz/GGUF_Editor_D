unit uEditTensorsIO;

interface

uses
  Windows, Messages, SysUtils, System.IOUtils, System.UITypes, StrUtils, Classes,
  Controls, Forms, Dialogs, StdCtrls, ComCtrls, ExtCtrls, Graphics, Contnrs,
  System.Diagnostics, System.RegularExpressions, System.Types, uSaveProgress,
  uMath, uGGUFModel, uGGUFReader, uGGUFWriter, uGgmlQuants, uGGMLTypes,
  Generics.Collections, SyncObjs, ShellAPI, VCLTee.TeCanvas, uAppConfig,
  uSafeTensors, uTensorTranspose, uGGMLConstants, uLangManager, uFrmAbout,
  Vcl.Menus, System.Actions, Vcl.ActnList, uTensorsNamesMan, uLog;

procedure Get_Dit_NameOnly(const ACurrentFile: string ; out Dir, NameOnly: string);

procedure frmEditTensorsActLoadSrcA1Execute(SrcFile: string);

procedure frmEditTensorsActLoadSrcB2Execute(SrcFile: string);

procedure frmEditTensorsActLoadSrcC3Execute(SrcFile: string);

procedure frmEditTensorsActLoadSrcSExecute(SrcFile: string);

function CheckExistingOutFiles(const OutFile: string; out OverwriteList: TStringList; MaxPartsGuess: Integer = 64): Boolean;

function DeleteOwnSplitFiles(const OutFile: string; ATotal: Integer): Integer;

procedure frmEditTensorsActSaveOutExecute();


implementation

uses
  uEditTensors, uEditTensorsMan, uEditTensorsView, uMappedNamesManager,
  uStrUtils, uViewTensors, uEditKVsGGUF;

procedure Get_Dit_NameOnly(const ACurrentFile: string ; out Dir, NameOnly: string);
begin
  Dir := ''; NameOnly := '';
  if ACurrentFile <> '' then
  begin
    Dir := ExtractFilePath(ACurrentFile);
    if FileExists(ACurrentFile) then
      NameOnly := ExtractFileName(ACurrentFile)
    else if not DirectoryExists(Dir) then
      Dir := '';
  end;
  if (Dir = '') or not DirectoryExists(Dir) then
    Dir := IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0)));

  //Dlg.FileName   := NameOnly;
  //Dlg.InitialDir := Dir;
end;

function UpdateTensorInput(var T: TGGUFTensorInfo; SourceId: Integer; UseMap: Boolean): Boolean;
var NameMap :  UTF8String;
begin
  Result := False;
  NameMap := '';
  T.NameOrg := T.Name;
  if UseMap then
  begin
    if SourceId = SRC_MODEL1 then
      NameMap := U8ToA(gMapping1.MapName(string(T.Name)))
    else if SourceId = SRC_MODEL2 then
      NameMap := U8ToA(gMapping2.MapName(string(T.Name)))
    else if SourceId = SRC_MODEL3 then
      NameMap := U8ToA(gMapping3.MapName(string(T.Name)))
    else if SourceId = SRC_MODELS then
      NameMap := U8ToA(gMappingS.MapName(string(T.Name)));
    T.Name := NameMap;
    T.IsNameMapped := T.NameOrg <> T.Name;
    if T.IsNameMapped then
    begin
      LogI('[MAP] : ' + T.NameOrg + ' -> ' + NameMap);
      Result := True;
    end;
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
  T.UseImpl := cfg.UseImpl; // 2
  T.RmseType := cfg.RmseType; // 3
end;

procedure frmEditTensorsActLoadSrcA1Execute(SrcFile: string);
var
  MInp, MOut: TGGUFFile;
  iGSz, MappedN : Int64;
  ErrMsg : String;
  OK: Boolean;
  SW: TStopwatch;
begin
  SW := TStopwatch.StartNew;
  SrcFile := Trim(SrcFile);
  if (SrcFile = '') or (not FileExists(SrcFile)) then
  begin
    // MessageDlg('Sélectionnez un fichier GGUF source valide.', mtWarning, [mbOK], 0);
    MessageDlg(mLang.gMsg('FTE.NoFileSelected'), mtWarning, [mbOK], 0);
    exit;
  end;

  if not frmEditTensors.ActLoadSrcA1.Enabled then
    exit;

  LogD('[IO] async load A: "%s"', [SrcFile]);

  frmEditTensors.ActLoadSrcA1.Enabled := False;
  frmEditTensors.edtSrc1.Text := SrcFile;
  frmEditTensors.ProgressBar1.Position := 0;
  frmEditTensors.ProgressBar1.Visible := True;
  // frmEditTensors.StatusBar1.Panels[0].Text := 'Lecture de l''en-tête GGUF...';
  eLogMsg(mLang.gMsg('FTE.LoadingHeader'));
  frmEditTensors.lvTensors1.Items.Clear;
  frmEditTensors.FViewTensors1.Clear;
  // Lancement ASYNCHRONE
  MInp := nil;
  MOut := nil;
  iGSz := 0;
  OK := False;
  TThread.CreateAnonymousThread(
    procedure
    var
      I: Integer;
      T: TGGUFTensorInfo;
    begin
      try
        //frmEditTensors.FModelInp1 := TGGUFReader.LoadFromFile(SrcFile, frmEditTensors.OnProgressEventLoad);
        MInp := TGGUFReader.LoadFromFile(SrcFile, frmEditTensors.OnProgressEventLoad);
        LogD('[IO] A: %d tensors in %s | mapping="%s" useMap=%s', //
          [MInp.Tensors.Count, FormatDurationMs(SW.ElapsedMilliseconds), cfg.MappingFile1, //
          sStrBool(cfg.MappingFile1 <> 'NoMappedNames')]);
        cfg.edtSrc1 := SrcFile;
        MappedN := 0;
        // Calcul des infos de couche et Pattern
        for I := 0 to MInp.Tensors.Count - 1 do
        begin
          T := TGGUFTensorInfo(MInp.Tensors[I]);
          if UpdateTensorInput(T, SRC_MODEL1, cfg.MappingFile1 <> 'NoMappedNames') then
            MappedN := MappedN + 1;
        end;

        //MappedN := ApplyMappingToModel(MInp, gMapping1, cfg.MappingFile1 <> 'NoMappedNames');
        if (cfg.MappingFile1 <> 'NoMappedNames') and (MappedN = 0) then
          LogW('[MAP] mapping "%s" renamed 0 of %d tensors in model A (check the pattern file)',  //
            [cfg.MappingFile1, MInp.Tensors.Count]);

        // Calcule les tailles totales par pattern
        iGSz := CalculateAllPatternSizes(MInp);

        // Initialiser ModelOut avec ModelInp1 par défaut
        MOut := MInp.Clone;
        LogN('[IO] model A ready: %d tensors, %d mapped, %s, out cloned (%d tensors)',
          [MInp.Tensors.Count, MappedN, FormatBytes2f(iGSz), MOut.Tensors.Count]);
        for I := 0 to MOut.Tensors.Count - 1 do
        begin
          T := TGGUFTensorInfo(MOut.Tensors[I]);
          T.SourceId := SRC_MODEL1;
          T.UseImpl := cfg.UseImpl;
          T.RmseType := cfg.RmseType;
        end;
        OK := True;
      except
        on e: Exception do
        begin
          ErrMsg := E.Message;
          LogE('[IO] load A failed after %s : %s', [FormatDurationMs(SW.ElapsedMilliseconds), ErrMsg]);
          TThread.Queue(nil,
            procedure
            begin
              FreeAndNil(MInp);
              if Assigned(MOut) then
                FreeAndNil(MOut);
              if Assigned(frmEditTensors) then
              begin
                eLogMsg(mLang.gMsgFmt('FTE.FileLoadError', [ErrMsg]), -1, -1, lvError);
                MessageDlg(mLang.gMsgFmt('FTE.FileLoadError', [ErrMsg]), mtError, [mbOK], 0);
                FreeAndNil(frmEditTensors.FModelInp1);
              end;
            end)
        end;
      end;
      TThread.Queue(nil,
        procedure
        begin
          if not Assigned(frmEditTensors) then
            Exit;
          if OK then
          begin
            FreeAndNil(frmEditTensors.FModelInp1);
            frmEditTensors.FModelInp1 := MInp;
            FreeAndNil(frmEditTensors.FModelOut);
            frmEditTensors.FModelOut := MOut;
            frmEditTensors.FGlobalSize1 := iGSz;
            frmEditTensorsUpdateDiffBFromA;
            frmEditTensorsUpdateDiffCFromA;
            // frmEditTensors.edtSizeIn1.Text
            frmEditTensors.stBar1.Panels[SB_M1].Text := FormatBytes2f(frmEditTensors.FGlobalSize1);
            eLogMsg(mLang.gMsg('FTE.Ready'));
            frmEditTensorsRebuildView1;
            frmEditTensorsRebuildViewOut;
            frmEditTensors.SetModelsToFrmViewAndFrmEditKVs;
          end;
          frmEditTensors.ActLoadSrcA1.Enabled := True;
          frmEditTensors.ProgressBar1.Visible := False;
        end)
    end).Start
end;

procedure frmEditTensorsActLoadSrcB2Execute(SrcFile: string);
var
  MInp, MOut: TGGUFFile;
  iGSz, MappedN: Int64;
  OK: Boolean;
  ErrMsg :String;
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
  frmEditTensors.lvTensors2.Items.Clear;
  frmEditTensors.FViewTensors2.Clear;
  // Lancement ASYNCHRONE
  MInp := nil;
  MOut := nil;
  iGSz := 0;
  OK := False;
  TThread.CreateAnonymousThread(
    procedure
    var
      I: Integer;
      T: TGGUFTensorInfo;
    begin
      try
        MInp:= TGGUFReader.LoadFromFile(SrcFile, frmEditTensors.OnProgressEventLoad);
        cfg.edtSrc2 := SrcFile;
        // Calcul des infos de couche et Pattern
        MappedN := 0;
        for I := 0 to MInp.Tensors.Count - 1 do
        begin
          T := TGGUFTensorInfo(MInp.Tensors[I]);
          // if cfg.UseIgnoredPrefixes2 and IsIgnoredPrefix(T.Name) then
          // Continue;
          if UpdateTensorInput(T, SRC_MODEL2, cfg.MappingFile2 <> 'NoMappedNames') then
            MappedN := MappedN + 1;
        end;

        //ApplyMappingToModel(MInp, gMapping2, cfg.MappingFile2 <> 'NoMappedNames');
        if (cfg.MappingFile2 <> 'NoMappedNames') and (MappedN = 0) then
          LogW('[MAP] mapping "%s" renamed 0 of %d tensors in model B (check the pattern file)',  //
            [cfg.MappingFile2, MInp.Tensors.Count]);

        // Calcule les tailles totales par pattern
        iGSz := CalculateAllPatternSizes(MInp);

        // Initialiser ModelOut avec ModelInp2 par défaut si pas de ModelInp1
        if not Assigned(frmEditTensors.FModelOut) then
        begin
          MOut := MInp.Clone;
          LogN('[IO] model B ready: %d tensors, %d mapped, %s, out cloned (%d tensors)',
          [MInp.Tensors.Count, MappedN, FormatBytes2f(iGSz), MOut.Tensors.Count]);
          // Mise à jour des infos SourceId pour le modèle de sortie initial
          for I := 0 to MOut.Tensors.Count - 1 do
          begin
            T := TGGUFTensorInfo(MOut.Tensors[I]);
            T.SourceId := SRC_MODEL2;
            T.UseImpl := cfg.UseImpl;
            T.RmseType := cfg.RmseType;
          end;
        end;
        OK := True;
      except
        on e: Exception do
        begin
          ErrMsg := E.Message;
          FreeAndNil(MInp);
          if Assigned(MOut) then
            FreeAndNil(MOut);
          TThread.Queue(nil,
            procedure
            begin
              // eLogMsg('ERREUR Load : ' + e.Message);
              eLogMsg(mLang.gMsg('FTE.LoadError') + ErrMsg, -1, -1, lvError);
              // MessageDlg('Erreur chargement (source2): ' + e.Message, mtError, [mbOK], 0);
              MessageDlg(mLang.gMsgFmt('FTE.FileLoadError', [ErrMsg]), mtError, [mbOK], 0);
            end)
        end;
      end;
      TThread.Queue(nil,
        procedure
        begin
          if not Assigned(frmEditTensors) then
            Exit;
          if OK then
          begin
            FreeAndNil(frmEditTensors.FModelInp2);
            frmEditTensors.FModelInp2 := MInp;
            if not Assigned(frmEditTensors.FModelOut) then
            begin
              FreeAndNil(frmEditTensors.FModelOut);
              frmEditTensors.FModelOut := MOut;
            end;
            frmEditTensors.FGlobalSize2 := iGSz;
            frmEditTensorsUpdateDiffBFromA;
            //frmEditTensorsUpdateDiffCFromA;
            // frmEditTensors.edtSizeIn2.Text
            frmEditTensors.stBar1.Panels[SB_M2].Text := FormatBytes2f(frmEditTensors.FGlobalSize2);
            eLogMsg(mLang.gMsg('FTE.Ready'));
            frmEditTensorsRebuildView2;
            // eLogMsg('GGUF chargé (source2): ' + SrcFile);
            // eLogMsg(mLang.gMsgFmt('GGUFLoaded', [2, SrcFile]));
            frmEditTensors.SetModelsToFrmViewAndFrmEditKVs;
          end;
          frmEditTensors.ProgressBar1.Visible := False;
          frmEditTensors.ActLoadSrcB2.Enabled := True;
        end)
    end).Start
end;

procedure frmEditTensorsActLoadSrcC3Execute(SrcFile: string);
var
  MInp, MOut: TGGUFFile;
  iGSz , MappedN : Int64;
  OK: Boolean;
  ErrMsg : String;
begin
  SrcFile := Trim(SrcFile);
  if (SrcFile = '') or (not FileExists(SrcFile)) then
  begin
    // MessageDlg('Sélectionnez un fichier GGUF source valide.', mtWarning, [mbOK], 0);
    MessageDlg(mLang.gMsg('FTE.NoFileSelected'), mtWarning, [mbOK], 0);
    exit;
  end;

  if not frmEditTensors.ActLoadSrcC3.Enabled then
    exit;

  frmEditTensors.ActLoadSrcC3.Enabled := False;
  frmEditTensors.edtSrc3.Text := SrcFile;
  frmEditTensors.ProgressBar1.Visible := True;
  frmEditTensors.ProgressBar1.Position := 0;
  // frmEditTensors.StatusBar1.Panels[0].Text := 'Lecture de l''en-tête GGUF...';
  eLogMsg(mLang.gMsg('FTE.LoadingHeader'));
  frmEditTensors.lvTensors3.Items.Clear;
  frmEditTensors.FViewTensors3.Clear;
  // Lancement ASYNCHRONE
  MInp := nil;
  MOut := nil;
  iGSz := 0;
  OK := False;
  TThread.CreateAnonymousThread(
    procedure
    var
      I: Integer;
      T: TGGUFTensorInfo;
    begin
      try
        MInp := TGGUFReader.LoadFromFile(SrcFile, frmEditTensors.OnProgressEventLoad);
        cfg.edtSrc3 := SrcFile;
        MappedN := 0;
        // Calcul des infos de couche et Pattern
        for I := 0 to MInp.Tensors.Count - 1 do
        begin
          T := TGGUFTensorInfo(MInp.Tensors[I]);
          // if cfg.UseIgnoredPrefixes2 and IsIgnoredPrefix(T.Name) then
          // Continue;
          if UpdateTensorInput(T, SRC_MODEL3, cfg.MappingFile3 <> 'NoMappedNames') then
             MappedN := MappedN + 1;
        end;
        // ApplyMappingToModel(frmEditTensors.FModelInp2, gMapping2, cfg.UseMappedNames2);
        //ApplyMappingToModel(MInp, gMapping3, cfg.MappingFile3 <> 'NoMappedNames');
        if (cfg.MappingFile3 <> 'NoMappedNames') and (MappedN = 0) then
          LogW('[MAP] mapping "%s" renamed 0 of %d tensors in model C (check the pattern file)',  //
            [cfg.MappingFile3, MInp.Tensors.Count]);


        // Calcule les tailles totales par pattern
        iGSz := CalculateAllPatternSizes(MInp);

        // Initialiser ModelOut avec ModelInp2 par défaut si pas de ModelInp1
        if not Assigned(frmEditTensors.FModelOut) then
        begin
          MOut := MInp.Clone;
          LogN('[IO] model C ready: %d tensors, %d mapped, %s, out cloned (%d tensors)',
          [MInp.Tensors.Count, MappedN, FormatBytes2f(iGSz), MOut.Tensors.Count]);
          // Mise à jour des infos SourceId pour le modèle de sortie initial
          for I := 0 to MOut.Tensors.Count - 1 do
          begin
            T := TGGUFTensorInfo(MOut.Tensors[I]);
            T.SourceId := SRC_MODEL3;
            T.UseImpl := cfg.UseImpl;
            T.RmseType := cfg.RmseType;
          end;
        end;
        OK := True;
      except
        on e: Exception do
        begin
          ErrMsg := E.Message;
          FreeAndNil(MInp);
          if Assigned(MOut) then
            FreeAndNil(MOut);
          TThread.Queue(nil,
            procedure
            begin
              // eLogMsg('ERREUR Load : ' + e.Message);
              eLogMsg(mLang.gMsg('FTE.LoadError') + ErrMsg, -1, -1, lvError);
              // MessageDlg('Erreur chargement (source2): ' + e.Message, mtError, [mbOK], 0);
              MessageDlg(mLang.gMsgFmt('FTE.FileLoadError', [ErrMsg]), mtError, [mbOK], 0);
            end)
        end;
      end;
      TThread.Queue(nil,
        procedure
        begin
          if not Assigned(frmEditTensors) then
            Exit;
          if OK then
          begin
            FreeAndNil(frmEditTensors.FModelInp3);
            frmEditTensors.FModelInp3 := MInp;
            if not Assigned(frmEditTensors.FModelOut) then
            begin
              FreeAndNil(frmEditTensors.FModelOut);
              frmEditTensors.FModelOut := MOut;
            end;
            frmEditTensors.FGlobalSize3 := iGSz;
            //frmEditTensorsUpdateDiffBFromA;
            frmEditTensorsUpdateDiffCFromA;

            frmEditTensors.stBar1.Panels[SB_M3].Text := FormatBytes2f(frmEditTensors.FGlobalSize3);
            eLogMsg(mLang.gMsg('FTE.Ready'));
            frmEditTensorsRebuildView3;
            // eLogMsg('GGUF chargé (source3): ' + SrcFile);
            // eLogMsg(mLang.gMsgFmt('GGUFLoaded', [3, SrcFile]));
            frmEditTensors.SetModelsToFrmViewAndFrmEditKVs;
          end;
          frmEditTensors.ProgressBar1.Visible := False;
          frmEditTensors.ActLoadSrcC3.Enabled := True;
        end)
    end).Start
end;

procedure frmEditTensorsActLoadSrcSExecute(SrcFile: string);
var
  MInp: TGGUFFile;
  iGSz  , MappedN: Int64;
  OK: Boolean;
  ErrMsg : String;
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
  // frmEditTensors.lvTensorsS.Items.Clear;
  frmEditTensors.FViewTensorsS.Clear;
  frmEditTensors.ActLoadSrcS.Enabled := False;
  frmEditTensors.edtSrcS.Text := SrcFile;
  frmEditTensors.ProgressBar1.Visible := True;
  frmEditTensors.ProgressBar1.Position := 0;

  // frmEditTensors.StatusBar1.Panels[0].Text := 'Chargement Safetensors (Model S)...';

  eLogMsg(mLang.gMsg('FTE.LoadingSafetensors'));
  // Lancement ASYNCHRONE
  MInp := nil;
  iGSz := 0;
  OK := False;
  TThread.CreateAnonymousThread(
    procedure
    var
      M: TSafeTensorsMeta;
      I, J: Integer;
      e: TSafeTensorEntry;
      T: TGGUFTensorInfo;
    begin
      M := nil;
      try
        eLogMsg('Star LoadSafeTensorsMeta');
        M := LoadSafeTensorsMeta(SrcFile);
        eLogMsg('End LoadSafeTensorsMeta');
        cfg.edtSrcS := SrcFile;
        // frmEditTensors.FGlobalSizeS := M.TotalFileSize; // CalculateGlobalSize(frmEditTensors.FModelInpS);
        // frmEditTensors.edtSizeInS.Text := FormatBytes(frmEditTensors.FGlobalSizeS);
        try
          //frmEditTensors.FModelInpS := TGGUFFile.Create;
          //frmEditTensors.FModelInpS.Version := 3;
          //frmEditTensors.FModelInpS.Alignment := 32;
          //frmEditTensors.FModelInpS.TensorCount := M.Entries.Count;
          MInp := TGGUFFile.Create;
          MInp.Version := 3;
          MInp.Alignment := 32;
          MInp.TensorCount := M.Entries.Count;
          MInp.InitHeaderPartSizeBytes := 64;
          MappedN := 0;
          for I := 0 to M.Entries.Count - 1 do
          begin
            e := M.Entries[I];
            T := TGGUFTensorInfo.Create;
            T.Name := U8ToA(e.Name);
            if cfg.UseIgnoredPrefixesS and IsIgnoredPrefix(T.Name) then
            begin
              T.Free;
              Continue;
            end;
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

            // T := TGGUFTensorInfo(frmEditTensors.FModelOut.Tensors[I]);
            T.SourceId := SRC_MODELS;
            T.UseImpl := cfg.UseImpl;
            T.RmseType := cfg.RmseType;
            if UpdateTensorInput(T, SRC_MODELS, cfg.MappingFileS <> 'NoMappedNames') then
              MappedN := MappedN + 1;
            T.TransposFile := TTransposeEngine.GetModelTmpFileName(T.SourceFile, string(T.NameOrg));
            if FileExists(T.TransposFile) then
            begin
              TTransposeEngine.SetTransposDims(T);
              // eLogMsg(Format('Tenseur déjà transposé détecté : %s', [string(T.Name)]));
              eLogMsg(mLang.gMsgFmt('FTE.TransposeAlreadyDetected', [string(T.Name)]), -1, -1, lvWarn);
            end
            else
            begin
              T.IsTransposed := False;
              T.TransposFile := '';
            end;
            T.Keep := True;
            MInp.Tensors.Add(T);
          end;
          iGSz:= CalculateAllPatternSizes(MInp);
          // eLogMsg('End CalculateAllPatternSizes');
          eLogMsg(mLang.gMsgFmt('FTE.SafetensorsLoaded', [SrcFile]));
          eLogMsg(mLang.gMsg('FTE.Ready'));
        finally
          M.Free;
        end;
        OK := True;
      except
        on e: Exception do
        begin
          ErrMsg := e.Message;
          FreeAndNil(MInp);
          if Assigned(M) then
            FreeAndNil(M);
          TThread.Queue(nil,
            procedure
            begin
              // eLogMsg('ERREUR Load S: ' + e.Message);
              eLogMsg(mLang.gMsg('FTE.LoadError') + ErrMsg, -1, -1, lvError);
              // MessageDlg('Erreur chargement Safetensors: ' + e.Message, mtError, [mbOK], 0);
              MessageDlg(mLang.gMsgFmt('FTE.FileLoadError', [ErrMsg]), mtError, [mbOK], 0);
              //FreeAndNil(frmEditTensors.FModelInpS);
            end)
        end;
      end;
      TThread.Queue(nil,
        procedure
        begin
          if not Assigned(frmEditTensors) then
            Exit;
          if OK then
          begin
            FreeAndNil(frmEditTensors.FModelInpS);
            frmEditTensors.FModelInpS := MInp;
            {if not Assigned(frmEditTensors.FModelOut) then
            begin
              FreeAndNil(frmEditTensors.FModelOut);
              frmEditTensors.FModelOut := MOut;
            end;   }
            frmEditTensors.FGlobalSizeS := iGSz;
            if (cfg.MappingFileS <> 'NoMappedNames') and (MappedN = 0) then
               LogW('[MAP] mapping "%s" renamed 0 of %d tensors in model S (check the pattern file)',  //
               [cfg.MappingFileS, MInp.Tensors.Count]);

            LogN('[IO] model S ready: %d tensors, %d mapped, %s', //
              [MInp.Tensors.Count, MappedN, FormatBytes2f(iGSz), MInp.Tensors.Count]);
                                                // frmEditTensors.edtSizeInS.Text
            frmEditTensors.stBar1.Panels[SB_MS].Text := FormatBytes2f(frmEditTensors.FGlobalSizeS);
            frmEditTensorsRebuildViewS;
            frmEditTensors.lvTensorsS.Invalidate; // Force le rafraîchissement visuel
            // frmEditTensors.StatusBar1.Panels[0].Text := mLang.gMsg('FTE.Ready'); 'Prêt';
            frmEditTensors.SetModelsToFrmViewAndFrmEditKVs;
          end;
          frmEditTensors.ActLoadSrcS.Enabled := True;
          frmEditTensors.ProgressBar1.Visible := False;
        end)
    end).Start
end;

const
  CANCEL_ERR = 'CANCELLED';

function EstimateModelBytes(M: TGGUFFile): Int64;
var
  I: Integer;
  T: TGGUFTensorInfo;
begin
  Result := M.InitHeaderPartSizeBytes;
  for I := 0 to M.Tensors.Count - 1 do
  begin
    T := TGGUFTensorInfo(M.Tensors[I]);
    if T.IsConverted then
      Inc(Result, T.ByteSize)
    else
      Inc(Result, T.ByteSizeOrg);
  end;
end;

// Reconstruit le nom d'un shard EXACTEMENT comme TGGUFWriter.SaveAs le crée.
function BuildShardName(const OutFile: string; ANo, ATotal: Integer): string;
begin
  // doit être IDENTIQUE à la ligne dans SaveAs :
  // OutName := Format('%s-%0.5d-of-%0.5d.gguf', [BaseNoExt, i + 1, PartCount]);
  Result := Format('%s-%0.5d-of-%0.5d.gguf', [ChangeFileExt(Trim(OutFile), ''), ANo, ATotal]);
end;

// Remplit OverwriteList avec les fichiers déjà présents qui seront écrasés.
// Retourne True s'il y a au moins un fichier à écraser.
// MaxPartsGuess : nombre max de shards à tester (64 = largement suffisant,
// car les 5 chiffres limitent à 99999, mais on évite 99999 appels FileExists).
function CheckExistingOutFiles(const OutFile: string; out OverwriteList: TStringList; MaxPartsGuess: Integer = 64): Boolean;
var
  sF, sOutFile: string;
  SR: TSearchRec;
  Dir, Mask: string;

  procedure AddFound(const AName: string);
  begin
    if OverwriteList.IndexOf(AName) < 0 then
      OverwriteList.Add(AName);
  end;

begin
  Result := False;
  OverwriteList.Clear;
  sOutFile := Trim(OutFile);
  if sOutFile = '' then
    exit;
  // 1) Le fichier cible lui-même (mode single, ou part méta en mode split)
  if FileExists(sOutFile) then
  begin
    AddFound(sOutFile);
    Result := True;
  end;
  // 2) Détection par MASQUE : n'importe quel shard "Base-?????-of-?????.gguf"
  // (couvre aussi les anciens splits avec un total différent !)
  // Implémentation sans System.IOUtils, avec FindFirst/FindNext de SysUtils :
  Dir := ExtractFilePath(sOutFile);
  if Dir = '' then
    Dir := '.\';
  Mask := ChangeFileExt(ExtractFileName(sOutFile), '') + '-?????-of-?????.gguf';

  if FindFirst(Dir + Mask, faAnyFile, SR) = 0 then
  try
    repeat
      if (SR.Attr and faDirectory) = 0 then
      begin
        sF := Dir + SR.Name;
        AddFound(sF);
        Result := True;
          // mémorise le total du shard pour l'avertissement
          // nom = Base-00003-of-00008.gguf  ->  on extrait les chiffres après "-of-"
          // (extraction simple, sans regex)
      end;
    until FindNext(SR) <> 0;
  finally
    FindClose(SR);
  end;
end;

// Supprime le fichier cible + les shards [0..ATotal-1] que NOUS avons pu créer.
// ATotal <= 0 => mode fichier unique : seul OutFile est concerné.
function DeleteOwnSplitFiles(const OutFile: string; ATotal: Integer): Integer;
var
  I: Integer;
  sF, sOutFile: string;
begin
  Result := 0;
  sOutFile := Trim(OutFile);
  if sOutFile = '' then
    exit;

  if FileExists(sOutFile) then
    if DeleteFile(sOutFile) then
      Inc(Result);

  if ATotal > 0 then
    for I := 1 to ATotal do // <-- fichiers numérotés 1..N comme dans SaveAs
    begin
      sF := BuildShardName(sOutFile, I, ATotal);
      if FileExists(sF) then
        if DeleteFile(sF) then
          Inc(Result);
    end;
end;

procedure frmEditTensorsActSaveOutExecute();
var
  sOutFile: string;
  NewModel: TGGUFFile;
  SigVal: string;
  I: Integer;
  worker: TThread;
  localPartTot: Integer;
  lastGlobalDone: Int64;
  wasCancelled: Boolean;
begin
//  if not Assigned(frmEditTensors.FModelInp1) then
  if not Assigned(frmEditTensors.FModelOut) then
  begin
    MessageDlg(mLang.gMsg('FTE.ModelNotLoaded'), mtWarning, [mbOK], 0);
    exit;
  end;
  sOutFile := Trim(frmEditTensors.edtOut.Text);
  if sOutFile = '' then
  begin
    MessageDlg(mLang.gMsg('FTE.InvalidOutputPath'), mtWarning, [mbOK], 0);
    exit;
  end;

  frmEditTensorsSyncKeepFromList(frmEditTensors.lvTensorsOut);
  NewModel := frmEditTensors.FModelOut.CloneMetaOnly;

  if cfg.UseAutoSignature then
  begin
    SigVal := cfg.AutoSignatureTemplate + ' ' + FormatDateTime('yyyy-mm-dd hh-nn-ss', Now);
    NewModel.SetKV_String('general.edited_by', U8ToA(SigVal));
    eLogMsg(mLang.gMsg('FTE.SignatureAdded'));
  end;

  try
    for I := 0 to frmEditTensors.FModelOut.Tensors.Count - 1 do
    begin
      if TGGUFTensorInfo(frmEditTensors.FModelOut.Tensors[I]).Keep then
        NewModel.Tensors.Add(TGGUFTensorInfo(frmEditTensors.FModelOut.Tensors[I]).Clone)
      else
        LogI('[IO] tensor not selected for output : %s' , [TGGUFTensorInfo(frmEditTensors.FModelOut.Tensors[I]).Name]);
    end;
  except
    on e: Exception do
    begin
      LogMsg('[SaveOut] Exception : ' + e.Message, lvWarn);
      NewModel.Free;
      exit;
    end;
  end;

  if not frmEditTensors.BeginSave then
  begin
    NewModel.Free;
    Exit;
  end;

  LogN('[IO] save requested -> "%s" | kept %d/%d tensors | split=%s | metaSeparate=%s | autoSig=%s', //
    [sOutFile, NewModel.Tensors.Count, frmEditTensors.FModelOut.Tensors.Count, //
    IfThen((cfg.SplitSizeMBytes > 0), FormatBytes2f(cfg.SplitSizeMBytes), 'single'), //
    sStrBool(cfg.SaveMetaSeparate), sStrBool(cfg.UseAutoSignature)]);

  localPartTot := 1;
  lastGlobalDone := 0;
  wasCancelled := False;

  eLogMsg(Format('%s | %d tensors | ~%s | split=%s', [mLang.gMsg('FTE.SavingInProgress'),
          NewModel.Tensors.Count, FormatBytes2f(EstimateModelBytes(NewModel)),
          IfThen(cfg.SplitSizeMBytes > 0, 'parts ~ ' + FormatBytes2f(cfg.SplitSizeMBytes), 'single')]), -1, -1, lvNotice);

  worker := TThread.CreateAnonymousThread(
    procedure
    var
      ErrMsg,sSpd : string;
      Elapsed: Int64;
    begin
      ErrMsg := '';
      try
        TGGUFWriter.SaveAs(NewModel, sOutFile, cfg.SplitSizeMBytes, cfg.SaveMetaSeparate,
          procedure(const Info: TProgressInfo)
          begin
            if Info.PartTot > 0 then
              localPartTot := Info.PartTot;

            if Info.GlobalBytesDone > lastGlobalDone then
              lastGlobalDone := Info.GlobalBytesDone;

            if Info.Kind = pkCancelled then
              wasCancelled := True;

            if Assigned(frmEditTensors) then
              frmEditTensors.OnProgressEventSave(Info);
          end, @frmEditTensors.FCancelSave);
      except
        on e: Exception do
        begin
          ErrMsg := e.Message;
          LogE('[IO] writer exception : %s', [ErrMsg]);
        end;
      end;

      TThread.Queue(nil,
        procedure
        var
          LWasCancelled: Boolean;
          LPartTot: Integer;
          LGlobalsDone: Int64;
          LDeleted: Integer;
          LErr: string;
        begin
          try
            NewModel.Free;
          finally
            frmEditTensors.EndSave;
          end;

          if not Assigned(frmEditTensors) then
            exit;
          LWasCancelled := frmEditTensors.IsCancelled or wasCancelled or SameText(Trim(ErrMsg), CANCEL_ERR);
          LPartTot := localPartTot;
          LGlobalsDone := lastGlobalDone;
          LErr := ErrMsg;

          Elapsed := ElapsedSince(frmEditTensors.FSaveStartedTick);
          sSpd := FormatSpeedMBs(LGlobalsDone, Elapsed);



          if LWasCancelled then
          begin
            TThread.CreateAnonymousThread(
              procedure
              var
                n: Integer;
              begin
                n := DeleteOwnSplitFiles(sOutFile, Max(1, LPartTot));
                TThread.Queue(nil,
                  procedure
                  begin
                    if not Assigned(frmEditTensors) then
                      exit;
                    eLogMsg(Format('[SAVE] Cleaned %d file(s). Ready.', [n]), -1, -1, lvNotice);
                    frmEditTensors.stBar1.Panels[0].Text := mLang.gMsg('FTE.OperationCancelled');
                  end);
              end).Start;
          end
          else if LErr <> '' then
          begin
            LDeleted := DeleteOwnSplitFiles(sOutFile, Max(1, LPartTot));
            eLogMsg(mLang.gMsgFmt('FTE.SaveError', [LErr]) + Format(' (cleaned %d file(s))',//
             [LDeleted]), -1, -1, lvError);
            MessageDlg(mLang.gMsgFmt('FTE.FileSaveError', [LErr]), mtError, [mbOK], 0);
            frmEditTensors.stBar1.Panels[0].Text := mLang.gMsg('FTE.Error');
            LogE('[IO] writer exception after %s written : %s', [FormatBytes2f(LGlobalsDone), LErr]);
          end
          else
          begin
             // ✅ Save completed in 1 h 07 min 12 s | 240 MiB/s | 38.72 GB written
             eLogMsg(Format('[SAVE] ✅ Save completed in %s | avg %s | %s written%s',//
              [FormatDurationMs(Elapsed), sSpd, FormatBytes2f(LGlobalsDone),
              IfThen(LPartTot > 1, Format(' in %d parts', [LPartTot]), '')]), -1, -1, lvNotice);
            MessageDlg(mLang.gMsg('FTE.SaveSuccess'), mtInformation, [mbOK], 0);
            frmEditTensors.stBar1.Panels[0].Text := mLang.gMsg('FTE.Ready');
          end;
        end);
    end);
  // worker.FreeOnTerminate := False;
  worker.Start;
end;

end.

