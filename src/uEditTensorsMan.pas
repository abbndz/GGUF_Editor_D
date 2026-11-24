unit uEditTensorsMan;

interface

uses
  Windows, Messages, SysUtils, StrUtils, Classes, Controls, System.UITypes,
  Forms, Dialogs, StdCtrls, ComCtrls, System.Actions, ExtCtrls, Graphics,
  Contnrs, CommCtrl, Vcl.Menus, Vcl.ActnList, Generics.Collections, SyncObjs,
  ShellAPI, VCLTee.TeCanvas, uGGUFModel, uGGUFReader, uGGUFWriter, uGgmlQuants,
  uGGMLTypes, uAppConfig, uSafeTensors, uTensorTranspose, uStrUtils,
  uGGMLConstants, uLangManager, uTensorsNamesMan,uQuantPresetConfig;

type
  TOnModelUpdate = reference to procedure(const Msg: string);

function GetActiveTensor: TGGUFTensorInfo;

procedure frmEditTensorsFillDTypes;

// Filtrage de couches
function MatchesLayerFilter(LayerIdx: Integer; const FromCombo, ToCombo, ModCombo: string; AllLayers: Boolean): Boolean;

procedure frmEditTensorsSyncKeepFromList(OutList: TListView);

procedure TransferSelectedTensorToOut(SourceId: Integer; const FromCombo, ToCombo, ModCombo: TComboBox;
  AllLayers: Boolean);

function DoQuantTypeOutChange(SelectedT: TGGUFTensorInfo; NewType, UseImpl, RmseType: Integer; AllLayers: Boolean;
  FromOut, ToOut, ModOut: string) : Boolean;

procedure frmEditTensorsRefreshEditorsForItem(It: TListItem);

procedure frmEditTensorsUpdateTransposeUI(T: TGGUFTensorInfo);

procedure frmEditTensorsDoTransposeActiveTensor;
procedure frmEditTensorsDoClearTransposeActiveTensor();

// Restaure la sélection sur le même tenseur après un rebuild
procedure RestoreListViewSelection(AListView: TListView; const SelectedName: String);

implementation

uses uEditTensors, uEditTensorsIO, uEditTensorsView, uViewTensors, uEditKVsGGUF, uMappedNamesManager,
  uGGUFTypes, uEditKVsGGUFNewKey, uEditStringDlg, uEditArrayDlg, uFrmAbout, uAppSetting, uLog;

function GetActiveTensor: TGGUFTensorInfo;
var
  I: Integer;
  CurName: string;
begin
  Result := nil;
  if not Assigned(frmEditTensors.FCurrentSourceList) then
    Exit;

  // 1. Priorité à l'élément visuellement sélectionné
  if Assigned(frmEditTensors.FCurrentSourceList.Selected) and Assigned(frmEditTensors.FCurrentSourceList.Selected.Data)
  then
  begin
    Result := TGGUFTensorInfo(frmEditTensors.FCurrentSourceList.Selected.Data);
    Exit;
  end;

  // 2. Fallback robuste : recherche par nom dans le ListView actif
  CurName := Trim(frmEditTensors.FCurrentETName.Text);
  if CurName = '' then
    Exit;

  for I := 0 to frmEditTensors.FCurrentSourceList.Items.Count - 1 do
  begin
    if Assigned(frmEditTensors.FCurrentSourceList.Items[I].Data) and
      SameText(string(TGGUFTensorInfo(frmEditTensors.FCurrentSourceList.Items[I].Data).Name), CurName) then
    begin
      Result := TGGUFTensorInfo(frmEditTensors.FCurrentSourceList.Items[I].Data);
      Break;
    end;
  end;
end;

procedure RestoreListViewSelection(AListView: TListView; const SelectedName: string);
var
  I: Integer;
  Item: TListItem;
  T: TGGUFTensorInfo;
  FUpdatingOutList: Boolean;
begin
  if not Assigned(AListView) or (SelectedName = '') then
    Exit;
  if frmEditTensors.FUpdatingOutList then
    exit;
  for I := 0 to AListView.Items.Count - 1 do
  begin
    Item := AListView.Items[I]; // Force l'accès (déclenche OnData si virtuel)
    if Item.Data = nil then
      Continue;
    T := TGGUFTensorInfo(Item.Data);
    if string(T.Name) = SelectedName then
    begin
      FUpdatingOutList := frmEditTensors.FUpdatingOutList;
      frmEditTensors.FUpdatingOutList := True;
      AListView.Selected := Item;
      Item.MakeVisible(true);
      // SendMessage(AListView.Handle, LVM_ENSUREVISIBLE, Item.Index, 0);
      // SendMessage(hwndLV, LVM_ENSUREVISIBLE, I, MakeLong(Word(fPartialOK), 0));
      // AListView.SetFocus;
      AListView.Invalidate;
      frmEditTensors.FUpdatingOutList := FUpdatingOutList;
      Exit;
    end;
  end;
end;

procedure frmEditTensorsFillDTypes;
var
  I: Integer;
  MI: TMenuItem;
  ll: TStrings;
begin
  ll := GGMLTypeGetListAllDType;
  try
    frmEditTensors.cbDType1.Items.Clear;

    frmEditTensors.cbDType1.Items.AddStrings(ll);
    frmEditTensors.cbDType1.ItemIndex := 0;

    frmEditTensors.cbDType2.Items.Clear;

    frmEditTensors.cbDType2.Items.AddStrings(ll);
    frmEditTensors.cbDType2.ItemIndex := 0;

    frmEditTensors.cbDType3.Items.Clear;
    frmEditTensors.cbDType3.Items.AddStrings(ll);
    frmEditTensors.cbDType3.ItemIndex := 0;
  finally
    ll.Free;
  end;
  frmEditTensors.cbDTypeOut.Items.Clear;
  // frmViewTensors.cbDTypeOut.Items.Clear;


  ll := GGMLTypeGetListDType;
  try
    frmEditTensors.cbDTypeOut.Items.AddStrings(ll);
    frmEditTensors.cbDTypeOut.ItemIndex := 0;
  // frmViewTensors.cbDTypeOut.ItemIndex := 0;
  finally
    ll.Free;
  end;

  frmEditTensors.mnuQuant.Clear;
  for I := 0 to frmEditTensors.cbDTypeOut.Items.Count - 1 do
  begin
    MI := TMenuItem.Create(frmEditTensors.mnuQuant);
    MI.Caption := frmEditTensors.cbDTypeOut.Items[I];
    MI.Tag := I;
    MI.OnClick := frmEditTensors.MenuQuantClick;
    frmEditTensors.mnuQuant.Add(MI);
  end;
  // frmEditTensors.MmLangue1.AutoCheck := true;
end;


function MatchesLayerFilter(LayerIdx: Integer; const FromCombo, ToCombo, ModCombo: String; AllLayers: Boolean): Boolean;
var
  SMod, sFrom, sTo: string;
  IFrom, ITo, IMod,R,P: Integer;
begin
 // Result := true;
  // Si AllLayers est False, cette fonction ne doit pas être appelée pour filtrer.
  // On retourne True par sécurité, mais la logique principale gérera le switch.
  if not AllLayers then
    Exit(true);

  // Les tenseurs sans couche (bias, embedding, norm) passent automatiquement.
  if LayerIdx < 0 then
    Exit(true);

  // 1. Filtre par Mode (All, Odd, Even, ModN, ou nombre exact)
  SMod := UpperCase(Trim(ModCombo));
  if SMod <> 'ALL' then
  begin
    if SMod = 'ODD' then
    begin
      if LayerIdx mod 2 = 0 then
        Exit(False);
    end
    else if SMod = 'EVEN' then
    begin
      if LayerIdx mod 2 <> 0 then
        Exit(False);
    end
    else if Copy(SMod, 1, 3) = 'MOD' then
    begin
      {// Ex: "Mod3" -> extrait 3
      IMod := StrToIntDef(Copy(SMod, 4, Length(SMod) - 3), 0);
      if (IMod > 0) and (LayerIdx mod IMod <> 0) then
        Exit(False);    }
      R := 0;
      P := Pos('+', SMod);
      if P > 0 then
        R := StrToIntDef(Copy(SMod, P + 1, MaxInt), 0);
      IMod := StrToIntDef(Copy(SMod, 4, P - 4), 0);
      if (IMod > 0) and (((LayerIdx - R) mod IMod) <> 0) then
        Exit(False);
    end
    else
    begin
      // Cas numérique direct (ex: le combo contient "0", "5", etc.)
      if LayerIdx <> StrToIntDef(SMod, -1) then
        Exit(False);
    end;
  end;

  // 2. Filtre par Plage (From -> To)
  // On considère que '0' est la valeur par défaut. Si l'utilisateur change un des deux, on applique le filtre.
  sFrom := Trim(FromCombo);
  sTo := Trim(ToCombo);
  if (sFrom <> '0') or (sTo <> '0') then
  begin
    IFrom := StrToIntDef(sFrom, 0);
    ITo := StrToIntDef(sTo, 999999);
    if (LayerIdx < IFrom) or (LayerIdx > ITo) then
      Exit(False);
  end;

  Exit(true);
end;

procedure frmEditTensorsSyncKeepFromList(OutList: TListView);
var
  I: Integer;
  It: TListItem;
  T: TGGUFTensorInfo;
begin
  if not Assigned(OutList) then
    Exit;
  for I := 0 to OutList.Items.Count - 1 do
  begin
    It := OutList.Items[I];
    // T := TGGUFTensorInfo(FModelOut.Tensors[I]);
    if Assigned(It.Data) then
    begin
      T := TGGUFTensorInfo(It.Data);
      T.Keep := It.Checked;
    end;
  end;
end;

// Procédure centralisée pour transférer un tenseur sélectionné vers la sortie
procedure TransferSelectedTensorToOut(SourceId: Integer; const FromCombo, ToCombo, ModCombo: TComboBox;
  AllLayers: Boolean);
var
  SrcMod: TGGUFFile;
  TSrc, TCurrent: TGGUFTensorInfo;
  I, J: Integer;
  TargetPattern, TargetName: string;
  Found: Boolean;
  CloneT: TGGUFTensorInfo;
  MatchPattern, MatchLayers: Boolean;
begin
  if SourceId = SRC_MODEL1 then
  begin
    SrcMod := frmEditTensors.FModelInp1;
  end
  else if SourceId = SRC_MODEL2 then
  begin
    SrcMod := frmEditTensors.FModelInp2;
  end
  else if SourceId = SRC_MODEL3 then
  begin
    SrcMod := frmEditTensors.FModelInp3;
  end
  else if SourceId = SRC_MODELS then
  begin
    SrcMod := frmEditTensors.FModelInpS;
  end
  else
    Exit;
  if not Assigned(SrcMod) then
    Exit;

  TSrc := GetActiveTensor;
  if not Assigned(TSrc) then
    Exit;

  TargetName := string(TSrc.Name);
  TargetPattern := GetTensorPatternName(TargetName);

  for I := 0 to SrcMod.Tensors.Count - 1 do
  begin
   // MatchPattern := False;
   //  MatchLayers := False;
    TCurrent := TGGUFTensorInfo(SrcMod.Tensors[I]);

    // LOGIQUE SWITCH
    if AllLayers then
      // On cherche TOUT le pattern (ex: blk.*.attn_norm.weight)
      MatchPattern := SameText(GetTensorPatternName(string(TCurrent.Name)), TargetPattern)
    else
      // On cherche LE tenseur exact cliqué
      MatchPattern := SameText(string(TCurrent.Name), TargetName);

    if not MatchPattern then
      Continue;

    // APPLICATION DES FILTRES DE COUCHES
    if AllLayers then
      MatchLayers := MatchesLayerFilter(TCurrent.LayerIndex, FromCombo.Text, ToCombo.Text, ModCombo.Text, true)
    else
      MatchLayers := true; // En mode exact, les filtres sont ignorés

    if MatchLayers then
    begin
      CloneT := TCurrent.Clone;
      CloneT.SourceId := SourceId;

      // Ajout ou mise à jour dans ModelOut
      Found := False;
      for J := 0 to frmEditTensors.FModelOut.Tensors.Count - 1 do
      begin
        if SameText(string(TGGUFTensorInfo(frmEditTensors.FModelOut.Tensors[J]).Name), string(TCurrent.Name)) then
        begin
          frmEditTensors.FModelOut.Tensors[J] := CloneT;
          // TObjectList(True) libère l'ancien
          Found := true;
          Break;
        end;
      end;
      if not Found then
        frmEditTensors.FModelOut.Tensors.Add(CloneT);
    end;
  end;
  CalculateAllPatternSizes(frmEditTensors.FModelOut);
  frmEditTensorsRebuildViewOut;

  //frmViewTensors.FSelectionOrder.Clear;
  //frmViewTensors.ChListBoxTensors.Items.Clear;
  frmViewTensors.PubPopulateTensorList;
  // eLogMsg(Format('Tenseur(s) "%s" transféré(s) vers Model Out.', [TargetName]));
  eLogMsg(mLang.gMsgFmt('FTE.TensorTransferred', [TargetName]));
end;

procedure UpdatefrmViewTensorsChListBoxTensorsName(SelectedT: TGGUFTensorInfo);
var
  i, j, TargetType: Integer;
  T: TGGUFTensorInfo;
  Found: Boolean;
begin
  for i := 0 to frmViewTensors.ChListBoxTensors.Items.Count - 1 do
  begin
    T := TGGUFTensorInfo(frmViewTensors.ChListBoxTensors.Items.Objects[i]);
    if T = SelectedT then
    begin
      frmViewTensors.ChListBoxTensors.Items[i] := GetFormatTensorNameList(T);
      if frmViewTensors.FSelOutTensor = SelectedT then
      begin
        frmViewTensors.UpdateRmseControlsState;
        {TargetType := SelectedT.TensorType;
        Found := False;
        for j := 0 to frmViewTensors.cbDTypeOut.Items.Count - 1 do
          if SameText(frmViewTensors.cbDTypeOut.Items[j], GGMLTypeToStr(TargetType)) then
          begin
            QP_SetComboSel(frmViewTensors.cbDTypeOut, j);
            Found := True;
            Break;
          end;
        if not Found then
          QP_SetComboSel(frmViewTensors.cbDTypeOut, 0);  }
      end;
      Break;
    end;
  end;
end;

function DoQuantTypeOutChange(SelectedT: TGGUFTensorInfo; NewType, UseImpl, RmseType: Integer; AllLayers: Boolean;
  FromOut, ToOut, ModOut: string) : Boolean;
var
  i, j, TargetType: Integer;
  Found: Boolean;
  Cols, QK: Int64;
  bIsQuant: Boolean;
  T: TGGUFTensorInfo;
  TargetPattern, CurrentPattern, strErr: string;
  MatchPattern, MatchLayers: Boolean;
begin
  Result := False;
  if not Assigned(SelectedT) then
    Exit();
  if NewType < 0 then
    Exit;

  bIsQuant := GGML_TypeIsQuant(NewType);
  QK := 1;
  if bIsQuant then
  begin
    if Length(SelectedT.Dims) = 0 then
    begin
      eLogMsg(mLang.gMsgFmt('FTE.UnsupportedBlock', [SelectedT.Name, 0]), -1, -1, lvWarn);
      Exit(False);
    end;
    Cols := SelectedT.Dims[0];
    QK := GGML_BlockElems(NewType);
    if Cols mod QK <> 0 then
    begin
      strErr := mLang.gMsgFmt('FTE.UnsupportedBlock', [SelectedT.Name, SelectedT.Cols]);
      eLogMsg(strErr, -1, -1, lvWarn);
      //raise Exception.Create(strErr);
      Exit(False);
    end;
  end;
    frmViewTensors.ChListBoxTensors.Items.BeginUpdate;
  try
  if (UseImpl < QP_USEIMPL_DLL_REF) or (UseImpl > QP_USEIMPL_PAS_IMPL5) then
    UseImpl := QP_USEIMPL_DLL_IMPL0;
  if (RmseType < 0) or (RmseType > 4) then
    RmseType := 2;
  // eLogMsg('Application du type DType (conversion différée)...');
  eLogMsg(mLang.gMsg('FTE.DTypeConversionApplied'));
  Result := True;

  TargetPattern := GetTensorPatternName(string(SelectedT.Name));

  // for I := 0 to frmEditTensors.lvTensorsOut.Items.Count - 1 do
  // begin T := TGGUFTensorInfo(frmEditTensors.lvTensorsOut.Items[I].Data);
  for I := 0 to frmEditTensors.FModelOut.Tensors.Count - 1 do
  begin
    T := TGGUFTensorInfo(frmEditTensors.FModelOut.Tensors[I]);
    if not Assigned(T) then Continue;
    CurrentPattern := GetTensorPatternName(string(T.Name));
  //  MatchPattern := False;
    MatchLayers := False;

    // if chkAllLayersOut.Checked then
    if AllLayers then

    begin
      MatchPattern := SameText(CurrentPattern, TargetPattern);
      if MatchPattern then
        // MatchLayers := MatchesLayerFilter(T.LayerIndex, cbLayersFromOut.Text, cbLayersToOut.Text, cbLayersModOut.Text, true);
        MatchLayers := MatchesLayerFilter(T.LayerIndex, FromOut, ToOut, ModOut, true);
    end
    else
    begin
      MatchPattern := (T = SelectedT);
      MatchLayers := true;
    end;

    if MatchPattern and MatchLayers then
    begin
      if bIsQuant then
      begin
        if Length(T.Dims) = 0 then
          Continue;
        Cols := T.Dims[0];
        if Cols mod QK <> 0 then
        begin
          eLogMsg(String(T.Name) + ' : unsupported block size for ' + GGMLTypeToStr(NewType), -1, -1, lvWarn);
          Continue
          // raise Exception.Create('GGML_RowSize: unsupported block size for ' + GGMLTypeToStr(NewType));
        end;
      end;
      T.TensorType := NewType;
      T.IsConverted := true;
      T.UseImpl := UseImpl; // cfg.UseImpl;
      T.RmseType := RmseType; // cfg.RmseType;
      T.ByteSize := GGML_TensorDataSize(NewType, T.Dims);
      UpdatefrmViewTensorsChListBoxTensorsName(T);
      // T.ByteSizeOrg := T.ByteSize1; Attension pas ici
      // eLogMsg(Format('Marqué conversion : %s -> %s', [string(T.Name), GGMLTypeToStr(NewType)]));
      eLogMsg(mLang.gMsgFmt('FTE.ConversionMarked', [string(T.Name), GGMLTypeToStr(NewType)]));
    end;
  end;
  finally
    frmViewTensors.ChListBoxTensors.Items.EndUpdate;
  end;
  frmEditTensorsRebuildViewOut;
  RestoreListViewSelection(frmEditTensors.lvTensorsOut, String(SelectedT.Name));

  TargetType := SelectedT.TensorType;
  Found := False;
  for j := 0 to frmEditTensors.cbDTypeOut.Items.Count - 1 do
    if SameText(frmEditTensors.cbDTypeOut.Items[j], GGMLTypeToStr(TargetType)) then
    begin
      TCombo_SetSel(frmEditTensors.cbDTypeOut, j);
      Found := True;
      Break;
    end;
  if not Found then
    TCombo_SetSel(frmEditTensors.cbDTypeOut, 0);

  //if frmViewTensors.FSelOutTensor = SelectedT then
   // frmViewTensors.UpdateRmseControlsState;

  // LogMsg('Application terminée.');
  eLogMsg(mLang.gMsg('FTE.ApplicationFinished'));
end;

procedure frmEditTensorsRefreshEditorsForItem(It: TListItem);
var
  T: TGGUFTensorInfo;
  I: Integer;
begin
  if (It = nil) or (not Assigned(It.Data)) then
    Exit;
  T := TGGUFTensorInfo(It.Data);
  if not Assigned(T) then
    Exit;

  frmEditTensors.FCurrentETName.Text := string(T.Name);
  frmEditTensors.FCurrentcbDType.ItemIndex := frmEditTensors.FCurrentcbDType.Items.IndexOf(GGMLTypeToStr(T.TensorType));

  if frmEditTensors.FCurrentcbDType.ItemIndex < 0 then
    frmEditTensors.FCurrentcbDType.ItemIndex := 0;

  if frmEditTensors.FCurrentSourceList = frmEditTensors.lvTensorsS then
    frmEditTensorsUpdateTransposeUI(T);

  if frmEditTensors.FCurrentSourceList = frmEditTensors.lvTensorsOut then
  begin
    TCombo_SetSel(frmEditTensors.cbRmseType, T.RmseType);
    TCombo_SetSel(frmEditTensors.cbUseImpl,  T.UseImpl);
    frmEditTensors.cbRmseType.Enabled :=  QP_HasPreset(T.UseImpl); ;//T.RmseType >=2;

    for I := 0 to frmEditTensors.FCurrentcbDType.Items.Count - 1 do
      frmEditTensors.mnuQuant.Items[I].Checked := I = frmEditTensors.FCurrentcbDType.ItemIndex;
  end;

end;

procedure frmEditTensorsUpdateTransposeUI(T: TGGUFTensorInfo);
begin
  // 1. Activer/Désactiver le bouton Transpose selon la sélection
  // T := GetActiveTensor;
  if (not Assigned(T)) then
    Exit;
  if Assigned(T) and T.IsSafetensors and (T.NDims = 2) and (T.TotElems > 1) and (not T.IsTransposed) then
    frmEditTensors.btnTranspose.Enabled := true
  else
    frmEditTensors.btnTranspose.Enabled := False;
  frmEditTensors.btnClearTransposition.Enabled := (not frmEditTensors.btnTranspose.Enabled) and (T.NDims = 2) and
    (T.TotElems > 1);
end;

procedure frmEditTensorsDoTransposeActiveTensor;
var
  SrcStreams: TDictionary<string, TFileStream>;
  I: Integer;
  TSrc, TCurrent: TGGUFTensorInfo;
  TargetName, TargetPattern: string;
  DoAll, DoOne: Boolean;
begin
  TSrc := GetActiveTensor;
  if not Assigned(TSrc) then
    Exit;

  SrcStreams := TDictionary<string, TFileStream>.Create;
  try
    DoAll := frmEditTensors.chkAllLayersS.Checked;
    DoOne := not DoAll;

    if DoAll then
    begin
      // if MessageDlg('Appliquer la transposition à TOUTES les couches correspondant au pattern ?', mtConfirmation,
      // [mbYes, mbNo], 0) <> mrYes then
      if MessageDlg(mLang.gMsg('FTE.ConfirmTransposeAll'), mtConfirmation, [mbYes, mbNo], 0) <> mrYes then
        Exit;
    end;

    frmEditTensors.ProgressBar1.Visible := true;
    frmEditTensors.ProgressBar1.Position := 0;
    Application.ProcessMessages;

    TargetName := string(TSrc.Name);
    TargetPattern := GetTensorPatternName(TargetName);

    for I := 0 to frmEditTensors.FModelInpS.Tensors.Count - 1 do
    begin
      TCurrent := TGGUFTensorInfo(frmEditTensors.FModelInpS.Tensors[I]);
      // Filtre : soit exact, soit pattern + filtre de couches
      if DoOne and not SameText(string(TCurrent.Name), string(TargetName)) then
        Continue;
      if (TCurrent.NDims <> 2) or (TCurrent.TotElems = 0) then
        Continue;
      if DoAll and not SameText(GetTensorPatternName(string(TCurrent.Name)), TargetPattern) then
        Continue;

      if not TCurrent.IsSafetensors then
        Continue;

      if TCurrent.IsTransposed then
        Continue; // Sécurité supplémentaire

      // Gestion du flux source (mise en cache)
      if not SrcStreams.ContainsKey(TCurrent.SourceFile) then
        SrcStreams.Add(TCurrent.SourceFile, TFileStream.Create(TCurrent.SourceFile, fmOpenRead or fmShareDenyWrite));

      frmEditTensors.ProgressBar1.Max := frmEditTensors.FModelInpS.Tensors.Count;
      frmEditTensors.ProgressBar1.Position := I;
      Application.ProcessMessages;

      try
        TTransposeEngine.ExecuteTransposition2(TCurrent, SrcStreams[TCurrent.SourceFile], TCurrent.SourceFile,
          procedure(AProgress: Integer)
          begin
            frmEditTensors.ProgressBar1.Position := I; // + (AProgress div 100)
            Application.ProcessMessages;
          end);
        TCurrent.TransposFile := TTransposeEngine.GetModelTmpFileName(TCurrent.SourceFile, string(TCurrent.NameOrg));
        if FileExists(TCurrent.TransposFile) then
        begin
          TTransposeEngine.SetTransposDims(TCurrent);
          eLogMsg(mLang.gMsgFmt('FTE.TensorTransposed', [string(TCurrent.Name)]), -1, -1, lvNotice);
        end
        else
        begin
          TCurrent.IsTransposed := False;
          TCurrent.TransposFile := '';
        end;
      except
        on e: Exception do
          // eLogMsg('Erreur transposition "' + string(TCurrent.Name) + '": ' + e.Message);
          eLogMsg(mLang.gMsgFmt('FTE.TranspositionError', [e.Message]), -1, -1, lvError);
      end;
    end;
    frmEditTensorsRebuildViewS;
    frmEditTensorsUpdateTransposeUI(TSrc);
    // eLogMsg('Transposition terminée.');
    eLogMsg(mLang.gMsg('FTE.TranspositionDone'));

  finally
    for var Stream in SrcStreams.Values do
      Stream.Free;
    SrcStreams.Free;
    frmEditTensors.ProgressBar1.Visible := False;
    frmEditTensors.lvTensorsS.Invalidate; // Force le rafraîchissement visuel
  end;
end;

procedure frmEditTensorsDoClearTransposeActiveTensor();
var
  TSrc: TGGUFTensorInfo;
  I: Integer;
  T: TGGUFTensorInfo;
  TargetPattern, TargetName, ss1, ss2: string;
  IsPatternMode: Boolean;
begin
  if not Assigned(frmEditTensors.FModelInpS) then
    Exit;

  TSrc := GetActiveTensor;
  // if not Assigned(TSrc) then  exit;

  if not Assigned(TSrc) then
  begin
    // MessageDlg('Veuillez sélectionner un tenseur transposé dans la liste.', mtInformation, [mbOK], 0);
    MessageDlg(mLang.gMsg('FTE.SelectTransposedTensor'), mtInformation, [mbOK], 0);
    Exit;
  end;

  if (Not TSrc.IsSafetensors) or (TSrc.NDims <> 2) or (TSrc.TotElems = 0) then
    Exit;

  // Préparation des critères selon le mode d'application
  IsPatternMode := frmEditTensors.chkAllLayersS.Checked;
  if IsPatternMode then
    TargetPattern := GetTensorPatternName(string(TSrc.NameOrg))
  else
    TargetName := string(TSrc.NameOrg);

  // Confirmation utilisateur précise
  // if MessageDlg(Format('Supprimer les fichiers temporaires pour "%s"' + IfThen(IsPatternMode,
  // ' et ses similaires (pattern: %s) ?', ', nom exact ?'), [string(TSelected.NameOrg), TargetPattern]), mtConfirmation,
  // [mbYes, mbNo], 0) <> mrYes then
  ss1 := string(TSrc.NameOrg);
  If IsPatternMode Then
    ss2 := ', pattern: ' + TargetPattern + '?'
  else
    ss2 := ' exact name ?';
  if MessageDlg(mLang.gMsgFmt('FTE.ConfirmClearTranspose', [ss1, ss2]), mtConfirmation, [mbYes, mbNo], 0) <> mrYes then
    Exit;

  // Parcours et suppression ciblée
  for I := 0 to frmEditTensors.FModelInpS.Tensors.Count - 1 do
  begin
    T := TGGUFTensorInfo(frmEditTensors.FModelInpS.Tensors[I]);

    // Skip si pas transposé ou fichier introuvable
    if not T.IsTransposed or (T.TransposFile = '') or not FileExists(T.TransposFile) then
      Continue;

    // Détermination du critère de correspondance
    if IsPatternMode then
    begin
      // Mode Pattern : on compare le suffixe après l'index de couche
      if SameText(GetTensorPatternName(string(T.NameOrg)), TargetPattern) then
      begin
        DeleteFile(T.TransposFile);
        TTransposeEngine.SetTransposDims(T);
        // T.IsTransposed := False;
        T.TransposFile := '';
        // LogMsg(Format('Fichier temporaire supprimé : %s', [string(T.NameOrg)]));
        // eLogMsg(Format(mLang.gMsg('FTE.TempFileRemoved'), [string(T.NameOrg)]));
        eLogMsg(mLang.gMsgFmt('FTE.TempFileRemoved', [string(T.NameOrg)]), -1, -1, lvNotice);
      end;
    end
    else
    begin
      // Mode Exact : comparaison par nom
      if SameText(string(T.NameOrg), TargetName) then
      begin
        DeleteFile(T.TransposFile);
        TTransposeEngine.SetTransposDims(T);
        // T.IsTransposed := False;
        T.TransposFile := '';
        // LogMsg(Format('Fichier temporaire supprimé : %s', [string(T.NameOrg)]));
        // eLogMsg(Format(mLang.gMsg('FTE.TempFileRemoved'), [string(T.NameOrg)]));
        eLogMsg(mLang.gMsgFmt('FTE.TempFileRemoved', [string(T.NameOrg)]), -1, -1, lvNotice);
      end;
    end;
  end;

  // Rafraîchissement UI
  frmEditTensorsRebuildViewS;
  frmEditTensorsUpdateTransposeUI(TSrc);
  // LogMsg('Traitement de suppression terminé.');
  eLogMsg(mLang.gMsg('FTE.ClearOperationFinished'));
  frmEditTensors.lvTensorsS.Invalidate; // Force le rafraîchissement visuel
end;

end.
