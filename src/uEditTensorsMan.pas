unit uEditTensorsMan;

interface

uses
  Windows, Messages, SysUtils, StrUtils, Classes, Controls, Forms, Dialogs, StdCtrls, ComCtrls, ExtCtrls, Graphics,
  Contnrs, uGGUFModel, uGGUFReader, uGGUFWriter, uGgmlQuants, uGGMLTypes, Generics.Collections, SyncObjs, ShellAPI,
  VCLTee.TeCanvas, uAppConfig, uSafeTensors, uTensorTranspose, uGgufStrUtils, uGGMLConstants, uLangManager,
  Vcl.Menus, System.Actions, Vcl.ActnList, uTensorsNamesMan;

type
  TOnModelUpdate = reference to procedure(const Msg: string);

procedure UpdateMenusLangs;

procedure TranslateForms(ISOCode: string);

function GetActiveTensor: TGGUFTensorInfo;

procedure frmEditTensorsFillDTypes;

procedure frmEditTensorsEnableComboBoxFilter(var FromCombo, ToCombo, ModCombo: TComboBox; e: Boolean);

// Filtrage de couches
function MatchesLayerFilter(LayerIdx: Integer; const FromCombo, ToCombo, ModCombo: string; AllLayers: Boolean): Boolean;

// Comparateur pour tri des tenseurs par Name
function CompareTensorsByName(Item1, Item2: Pointer): Integer;
// Comparateur pour tri des tenseurs par offset
function CompareTensorByOffset(Item1, Item2: Pointer): Integer;

// Formattage de la forme du tenseur
function TensorShapeText(T: TGGUFTensorInfo): string;

function frmEditTensorsSelectedTensor: TGGUFTensorInfo;

// Transfère des tenseurs du modèle source vers le modèle de sortie (logique pure)
procedure UpdateModelFromSource(var OutModel: TGGUFFile; SrcModel: TGGUFFile; TargetName, TargetPattern: string;
  AllLayers, MatchExact: Boolean; sFrom, sTo, SMod: string; SourceId: Integer);

// Met à jour l'état Keep d'une liste de tenseurs (utile pour synchronisation UI/Données)
procedure SyncTensorKeepState(List: TObjectList);

procedure frmEditTensorsSyncKeepFromList(OutList: TListView);

procedure frmEditTensorsUpdateRow(It: TListItem; T: TGGUFTensorInfo; GlobalSize: Int64);

procedure TransferSelectedTensorToOut(SourceId: Integer; const FromCombo, ToCombo, ModCombo: TComboBox;
  AllLayers: Boolean);

procedure frmEditTensorsRefreshEditorsForItem(It: TListItem);

procedure frmEditTensorsUpdateOutTensorFromSource(SourceId: Integer; AllLayers: Boolean);

procedure frmEditTensorsUpdateTransposeUI(T: TGGUFTensorInfo);

procedure frmEditTensorsDoTransposeActiveTensor;
procedure frmEditTensorsDoClearTransposeActiveTensor();

implementation

uses uEditTensors, uEditTensorsIO, uViewTensors, uEditKVsGGUF, uSplitMerge, uMappedNamesManager,
  uGGUFTypes, uEditKVsGGUFNewKey, uEditStringDlg, uEditArrayDlg, uFrmAbout, uAppSetting, uLog;

procedure TranslateForms(ISOCode: string);
begin
  cfg.sLang := ISOCode;
  mLang.SetLanguage(cfg.sLang);
  mLang.Translate(frmEditTensors);
  mLang.Translate(frmViewTensors);
  mLang.Translate(frmEditKVsGGUF);
  mLang.Translate(frmEditStringDlg);
  mLang.Translate(frmEditArrayDlg);
  mLang.Translate(frmEditNewKV);
  mLang.Translate(frmMappedNamesManager);
  mLang.Translate(frmSplitMerge);
  mLang.Translate(frmSettings);
  mLang.Translate(frmAbout);
  mLang.Translate(frmLogs);

  // mLang.GenerateFile(frmAbout, 'xx');
end;

procedure UpdateMenusLangs;
var
  I: Integer;
  MI: TMenuItem;
  ll: TStrings;
begin
  ll := mLang.GetListLangues;
  try
    frmEditTensors.MmLangue11.Clear;
    for I := 0 to ll.Count - 1 do
    begin
      MI := TMenuItem.Create(frmEditTensors.MmLangue11);
      MI.Caption := ll[I]; // Affiche le nom natif (ex: Français, العربية)
      MI.Tag := I; // Stocke l'index pour retrouver l'ISO code
      MI.OnClick := frmEditTensors.MenuLangueItemClick;
      MI.Checked := cfg.sLang = mLang.GetISOCodeByNativeLanguageName(MI.Caption);
      frmEditTensors.MmLangue11.Add(MI);
    end;
    // frmEditTensors.MmLangue1.AutoCheck := true;
  finally
    ll.Free;
  end;
end;

procedure MenuLangueItemClick(Sender: TObject);
var
  sCaption: String;
  ISOCode: string;
begin
  if Sender is TMenuItem then
  begin
    sCaption := TMenuItem(Sender).Caption;
    if Pos('&', sCaption) > 0 then
      sCaption := StringReplace(sCaption, '&', '', [rfReplaceAll]);
    ISOCode := mLang.GetISOCodeByNativeLanguageName(sCaption);
    TranslateForms(ISOCode);
  end;
end;

function CompareTensorsByName(Item1, Item2: Pointer): Integer;
var
  T1, T2: TGGUFTensorInfo;
begin
  T1 := TGGUFTensorInfo(Item1);
  T2 := TGGUFTensorInfo(Item2);
  Result := CompareText(string(T1.Name), string(T2.Name));
end;

function CompareTensorByOffset(Item1, Item2: Pointer): Integer;
var
  A, B: TGGUFTensorInfo;
begin
  A := TGGUFTensorInfo(Item1);
  B := TGGUFTensorInfo(Item2);
  if A.Offset < B.Offset then
    Result := -1
  else if A.Offset > B.Offset then
    Result := 1
  else
    Result := 0;
end;

function GetActiveTensor: TGGUFTensorInfo;
var
  I: Integer;
  CurName: string;
begin
  Result := nil;
  if not Assigned(frmEditTensors.FCurrentSourceList) then
    exit;

  // 1. Priorité à l'élément visuellement sélectionné
  if Assigned(frmEditTensors.FCurrentSourceList.Selected) and Assigned(frmEditTensors.FCurrentSourceList.Selected.Data)
  then
  begin
    Result := TGGUFTensorInfo(frmEditTensors.FCurrentSourceList.Selected.Data);
    exit;
  end;

  // 2. Fallback robuste : recherche par nom dans le ListView actif
  CurName := Trim(frmEditTensors.FCurrentETName.Text);
  if CurName = '' then
    exit;

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

procedure frmEditTensorsFillDTypes;
var
  I: Integer;
  MI: TMenuItem;
  ll: TStrings;
begin
  frmEditTensors.cbDType1.Items.Clear;
  for I := 0 to GGMLTypeCount() do
    frmEditTensors.cbDType1.Items.Add(GGMLTypeToStr(I));
  frmEditTensors.cbDType1.ItemIndex := 0;
  frmEditTensors.cbDType2.Items.Clear;
  for I := 0 to GGMLTypeCount() do
    frmEditTensors.cbDType2.Items.Add(GGMLTypeToStr(I));
  frmEditTensors.cbDType2.ItemIndex := 0;
  frmEditTensors.cbDTypeOut.Items.Clear;
  for I := 0 to GGMLTypeCount() do
    if Assigned(GetQuantProc(I)) then // and Assigned(GetDequantProc(I))
      frmEditTensors.cbDTypeOut.Items.Add(GGMLTypeToStr(I));
  frmEditTensors.cbDTypeOut.ItemIndex := 0;

  frmEditTensors.mnuQuant.Clear;
  for I := 0 to frmEditTensors.cbDTypeOut.Items.Count - 1 do
  begin
    MI := TMenuItem.Create(frmEditTensors.mnuQuant);
    MI.Caption := frmEditTensors.cbDTypeOut.Items[I]; // Affiche le nom natif (ex: Français, العربية)
    MI.Tag := I; // Stocke l'index pour retrouver l'ISO code
    MI.OnClick := frmEditTensors.MenuQuantClick;
    // MI.Checked := cfg.sLang = mLang.GetISOCodeByNativeLanguageName(MI.Caption);
    frmEditTensors.mnuQuant.Add(MI);
  end;
  // frmEditTensors.MmLangue1.AutoCheck := true;
end;

// Calcul de la taille globale du modèle
function CalculateGlobalSizeOld(M: TGGUFFile): Int64;
var
  I: Integer;
  T: TGGUFTensorInfo;
begin
  Result := 0;
  if not Assigned(M) then
    exit;
  for I := 0 to M.Tensors.Count - 1 do
  begin
    T := TGGUFTensorInfo(M.Tensors[I]);
    if T.IsConverted then
      Result := Result + T.ByteSize
    else
      Result := Result + T.ByteSizeOrg;
  end;
end;

procedure frmEditTensorsEnableComboBoxFilter(var FromCombo, ToCombo, ModCombo: TComboBox; e: Boolean);
begin
  FromCombo.Enabled := e;
  ToCombo.Enabled := e;
  ModCombo.Enabled := e;
end;

function MatchesLayerFilter(LayerIdx: Integer; const FromCombo, ToCombo, ModCombo: String; AllLayers: Boolean): Boolean;
var
  SMod, sFrom, sTo: string;
  IFrom, ITo, IMod: Integer;
begin
  Result := true;
  // Si AllLayers est False, cette fonction ne doit pas être appelée pour filtrer.
  // On retourne True par sécurité, mais la logique principale gérera le switch.
  if not AllLayers then
    exit(true);

  // Les tenseurs sans couche (bias, embedding, norm) passent automatiquement.
  if LayerIdx < 0 then
    exit(true);

  // 1. Filtre par Mode (All, Odd, Even, ModN, ou nombre exact)
  SMod := UpperCase(Trim(ModCombo));
  if SMod <> 'ALL' then
  begin
    if SMod = 'ODD' then
    begin
      if LayerIdx mod 2 = 0 then
        exit(False);
    end
    else if SMod = 'EVEN' then
    begin
      if LayerIdx mod 2 <> 0 then
        exit(False);
    end
    else if Copy(SMod, 1, 3) = 'MOD' then
    begin
      // Ex: "Mod3" -> extrait 3
      IMod := StrToIntDef(Copy(SMod, 4, Length(SMod) - 3), 0);
      if (IMod > 0) and (LayerIdx mod IMod <> 0) then
        exit(False);
    end
    else
    begin
      // Cas numérique direct (ex: le combo contient "0", "5", etc.)
      if LayerIdx <> StrToIntDef(SMod, -1) then
        exit(False);
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
      exit(False);
  end;

  exit(true);
end;

function TensorShapeText(T: TGGUFTensorInfo): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to Length(T.Dims) - 1 do
  begin
    if I > 0 then
      Result := Result + 'x';
    Result := Result + IntToStr(Integer(T.Dims[I]));
  end;
end;

function frmEditTensorsSelectedTensor: TGGUFTensorInfo;
begin
  Result := nil;
  if Assigned(frmEditTensors.FCurrentSourceList.Selected) then
    Result := TGGUFTensorInfo(frmEditTensors.FCurrentSourceList.Selected.Data);
end;

procedure UpdateModelFromSource(var OutModel: TGGUFFile; SrcModel: TGGUFFile; TargetName, TargetPattern: string;
  AllLayers, MatchExact: Boolean; sFrom, sTo, SMod: string; SourceId: Integer);
var
  I, J: Integer;
  TCurrent, CloneT: TGGUFTensorInfo;
  MatchPattern, MatchLayers, Found: Boolean;
  CurSMod, CurSFrom, CurSTo: string;
begin
  if not Assigned(SrcModel) or not Assigned(OutModel) then
    exit;

  for I := 0 to SrcModel.Tensors.Count - 1 do
  begin
    TCurrent := TGGUFTensorInfo(SrcModel.Tensors[I]);
    MatchPattern := False;
    MatchLayers := False;

    if AllLayers then
      MatchPattern := SameText(GetTensorPatternName(string(TCurrent.Name)), TargetPattern)
    else
      MatchPattern := SameText(string(TCurrent.Name), TargetName);

    if not MatchPattern then
      Continue;

    if AllLayers then
      MatchLayers := MatchesLayerFilter(TCurrent.LayerIndex, SMod, sFrom, sTo, true)
    else
      MatchLayers := true;

    if MatchLayers then
    begin
      CloneT := TCurrent.Clone;
      CloneT.SourceId := SourceId;
      CloneT.Keep := true;

      Found := False;
      for J := 0 to OutModel.Tensors.Count - 1 do
      begin
        if SameText(string(TGGUFTensorInfo(OutModel.Tensors[J]).Name), string(TCurrent.Name)) then
        begin
          OutModel.Tensors[J] := CloneT;
          Found := true;
          Break;
        end;
      end;
      if not Found then
        OutModel.Tensors.Add(CloneT);
    end;
  end;
  CalculateAllPatternSizes(OutModel);
end;

procedure SyncTensorKeepState(List: TObjectList);
var
  I: Integer;
  T: TGGUFTensorInfo;
begin
  if not Assigned(List) then
    exit;
  for I := 0 to List.Count - 1 do
  begin
    T := TGGUFTensorInfo(List[I]);
    T.Keep := T.Keep; // Placeholder: UI sync is handled externally
  end;
end;

procedure frmEditTensorsSyncKeepFromList(OutList: TListView);
var
  I: Integer;
  It: TListItem;
  T: TGGUFTensorInfo;
begin
  if not Assigned(OutList) then
    exit;
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

procedure frmEditTensorsUpdateRow(It: TListItem; T: TGGUFTensorInfo; GlobalSize: Int64);

var
  SizeP: Double;
  DisplaySize: Int64;
  DTypeStr: string;
  DisplayName: string;
begin
  It.SubItems.Clear;
  DTypeStr := GGMLTypeToStr(T.TensorType);
  It.SubItems.Add(DTypeStr);
  It.SubItems.Add(TensorShapeText(T));
  if T.LayerIndex >= 0 then
    It.SubItems.Add(IntToStr(T.LayerIndex))
  else
    It.SubItems.Add('-');
  if T.IsConverted then
    DisplaySize := T.ByteSize
  else
    DisplaySize := T.ByteSizeOrg;
  It.SubItems.Add(FormatBytes(DisplaySize));
  if GlobalSize > 0 then
  begin
    SizeP := (DisplaySize / GlobalSize) * 100;
    It.SubItems.Add(Format('%.2f%%', [SizeP]));
  end
  else
    It.SubItems.Add('0.00%');

  if T.LayerIndex >= 0 then
  begin
    It.SubItems.Add(FormatBytes(T.PatternGlobalSize));
    if GlobalSize > 0 then
    begin
      SizeP := (T.PatternGlobalSize / GlobalSize) * 100;
      It.SubItems.Add(Format('%.2f%%', [SizeP]));
    end
    else
      It.SubItems.Add('0.00%');
  end
  else
  begin
    It.SubItems.Add('-');
    It.SubItems.Add('-');
  end;

  It.SubItems.Add(IntToStr(T.Offset));
  It.SubItems.Add(IntToStr(T.SourceId));
  It.SubItems.Add(GGMLTypeToStr(T.TensorTypeOrg));
end;

// Procédure centralisée pour transférer un tenseur sélectionné vers la sortie
procedure TransferSelectedTensorToOut(SourceId: Integer; const FromCombo, ToCombo, ModCombo: TComboBox;
  AllLayers: Boolean);
var
  SrcMod: TGGUFFile;
  SrcLV: TListView;
  TSrc, TCurrent: TGGUFTensorInfo;
  I, J: Integer;
  TargetPattern, TargetName, CurrentName: string;
  Found: Boolean;
  CloneT: TGGUFTensorInfo;
  MatchPattern, MatchLayers: Boolean;
begin
  if SourceId = 1 then
  begin
    SrcMod := frmEditTensors.FModelInp1;
    SrcLV := frmEditTensors.lvTensors1;
  end
  else if SourceId = 2 then
  begin
    SrcMod := frmEditTensors.FModelInp2;
    SrcLV := frmEditTensors.lvTensors2;
  end
  else if SourceId = 3 then
  begin
    SrcMod := frmEditTensors.FModelInpS;
    SrcLV := frmEditTensors.lvTensorsS;
  end
  else
    exit;
  if not Assigned(SrcMod) then
    exit;

  TSrc := GetActiveTensor;
  if not Assigned(TSrc) then
    exit;

  TargetName := string(TSrc.Name);
  TargetPattern := GetTensorPatternName(TargetName);

  for I := 0 to SrcMod.Tensors.Count - 1 do
  begin
    MatchPattern := False;
    MatchLayers := False;
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
  // eLogMsg(Format('Tenseur(s) "%s" transféré(s) vers Model Out.', [TargetName]));
  eLogMsg(mLang.gMsgFmt('FTE.TensorTransferred', [TargetName]));
end;

procedure frmEditTensorsRefreshEditorsForItem(It: TListItem);
var
  T: TGGUFTensorInfo;
  I: Integer;
begin
  if (It = nil) or (not Assigned(It.Data)) then
    exit;
  T := TGGUFTensorInfo(It.Data);
  if not Assigned(T) then
    exit;

  frmEditTensors.FCurrentETName.Text := string(T.Name);
  frmEditTensors.FCurrentcbDType.ItemIndex := frmEditTensors.FCurrentcbDType.Items.IndexOf(GGMLTypeToStr(T.TensorType));

  if frmEditTensors.FCurrentcbDType.ItemIndex < 0 then
    frmEditTensors.FCurrentcbDType.ItemIndex := 0;

  if frmEditTensors.FCurrentSourceList = frmEditTensors.lvTensorsS then
    frmEditTensorsUpdateTransposeUI(T);

  if frmEditTensors.FCurrentSourceList = frmEditTensors.lvTensorsOut then
  begin
    for I := 0 to frmEditTensors.FCurrentcbDType.Items.Count - 1 do
      frmEditTensors.mnuQuant.Items[I].Checked := I = frmEditTensors.FCurrentcbDType.ItemIndex;
  end;
end;

procedure frmEditTensorsUpdateOutTensorFromSource(SourceId: Integer; AllLayers: Boolean);
var
  SrcMod: TGGUFFile;
  TOut, TSrc: TGGUFTensorInfo;
  I, J: Integer;
  Found: Boolean;
  CloneT: TGGUFTensorInfo;
  TargetName, TargetPattern: string;
begin
  if not Assigned(frmEditTensors.FModelInp1) and not Assigned(frmEditTensors.FModelInp2) then
    exit;

  if frmEditTensors.cbSrcModelOut1.ItemIndex = 0 then
    SrcMod := frmEditTensors.FModelInp1
  else if frmEditTensors.cbSrcModelOut1.ItemIndex = 1 then
    SrcMod := frmEditTensors.FModelInp2
  else if frmEditTensors.cbSrcModelOut1.ItemIndex = 2 then
    SrcMod := frmEditTensors.FModelInpS
  else
    exit;

  if not Assigned(SrcMod) then
    exit;

  // Recherche robuste du tenseur cible dans lvTensorsOut par son nom
  TargetName := Trim(frmEditTensors.edtNameOut.Text);
  TOut := nil;
  for I := 0 to frmEditTensors.lvTensorsOut.Items.Count - 1 do
  begin
    if Assigned(frmEditTensors.lvTensorsOut.Items[I].Data) and
      SameText(string(TGGUFTensorInfo(frmEditTensors.lvTensorsOut.Items[I].Data).Name), TargetName) then
    begin
      TOut := TGGUFTensorInfo(frmEditTensors.lvTensorsOut.Items[I].Data);
      Break;
    end;
  end;

  if not Assigned(TOut) then
  begin
    // eLogMsg('Aucun tenseur cible valide trouvé dans la liste de sortie.');
    MessageDlg(mLang.gMsg('FTE.TensorNotFound'), mtError, [mbOK], 0);
    exit;
  end;

  // Calcul du pattern pour le mode "AllLayers" (ex: attn_norm.weight)
  TargetPattern := GetTensorPatternName(TargetName);

  // Parcours du modèle source pour trouver les correspondances
  for I := 0 to SrcMod.Tensors.Count - 1 do
  begin
    TSrc := TGGUFTensorInfo(SrcMod.Tensors[I]);
    // Correspondance exacte OU (AllLayers + même pattern de suffixe)
    if (SameText(string(TSrc.Name), TargetName)) or
    // (AllLayers and SameText(GetTensorPatternName(string(TSrc.Name)), TargetPattern)) then
      (AllLayers and SameText(string(TSrc.TensorPatternName), TargetPattern)) then
    begin
      Found := False;
      // Vérifier si le tenseur existe déjà dans ModelOut
      for J := 0 to frmEditTensors.FModelOut.Tensors.Count - 1 do
      begin
        if SameText(string(TGGUFTensorInfo(frmEditTensors.FModelOut.Tensors[J]).Name), string(TSrc.Name)) then
        begin
          CloneT := TSrc.Clone;
          CloneT.SourceId := SourceId;
          CloneT.Keep := true;
          frmEditTensors.FModelOut.Tensors[J] := CloneT;
          // TObjectList(True) libère automatiquement l'ancien objet
          Found := true;
          Break;
        end;
      end;

      if not Found then
      begin
        CloneT := TSrc.Clone;
        CloneT.SourceId := SourceId;
        CloneT.Keep := true;
        frmEditTensors.FModelOut.Tensors.Add(CloneT);
      end;
      // eLogMsg(Format('Mise à jour du tenseur "%s" depuis le Modèle %d.', [string(TSrc.Name), SourceId]));
      eLogMsg(mLang.gMsgFmt('FTE.TensorUpdatedFromSource', [string(TSrc.Name), SourceId]));
    end;
  end;
  CalculateAllPatternSizes(frmEditTensors.FModelOut);
  frmEditTensorsRebuildViewOut;
end;

procedure frmEditTensorsUpdateTransposeUI(T: TGGUFTensorInfo);
begin
  // 1. Activer/Désactiver le bouton Transpose selon la sélection
  // T := GetActiveTensor;
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
  ProgressStep: Integer;
  CurProgress: Integer;
  TempR: Int64;
begin
  TSrc := GetActiveTensor;
  if not Assigned(TSrc) then
    exit;

  SrcStreams := TDictionary<string, TFileStream>.Create;
  try
    DoAll := frmEditTensors.chkAllLayersS.Checked;
    DoOne := not DoAll;

    if DoAll then
    begin
      // if MessageDlg('Appliquer la transposition à TOUTES les couches correspondant au pattern ?', mtConfirmation,
      // [mbYes, mbNo], 0) <> mrYes then
      if MessageDlg(mLang.gMsg('FTE.ConfirmTransposeAll'), mtConfirmation, [mbYes, mbNo], 0) <> mrYes then
        exit;
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
          cfg.UseFDLL,
          procedure(AProgress: Integer)
          begin
            frmEditTensors.ProgressBar1.Position := I; // + (AProgress div 100)
            Application.ProcessMessages;
          end);
        TCurrent.TransposFile := TTransposeEngine.GetModelTmpDir(TCurrent.SourceFile, string(TCurrent.NameOrg));
        if FileExists(TCurrent.TransposFile) then
        begin
          TTransposeEngine.SetTransposDims(TCurrent);
          eLogMsg(mLang.gMsgFmt('FTE.TensorTransposed', [string(TCurrent.Name)]));
        end
        else
        begin
          TCurrent.IsTransposed := False;
          TCurrent.TransposFile := '';
        end;
      except
        on e: Exception do
          // eLogMsg('Erreur transposition "' + string(TCurrent.Name) + '": ' + e.Message);
          eLogMsg(mLang.gMsgFmt('FTE.TranspositionError', [e.Message]));
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
    exit;

  TSrc := GetActiveTensor;
  // if not Assigned(TSrc) then  exit;

  if not Assigned(TSrc) then
  begin
    // MessageDlg('Veuillez sélectionner un tenseur transposé dans la liste.', mtInformation, [mbOK], 0);
    MessageDlg(mLang.gMsg('FTE.SelectTransposedTensor'), mtInformation, [mbOK], 0);
    exit;
  end;

  if (Not TSrc.IsSafetensors) or (TSrc.NDims <> 2) or (TSrc.TotElems = 0) then
    exit;

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
    exit;

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
        eLogMsg(mLang.gMsgFmt('FTE.TempFileRemoved', [string(T.NameOrg)]));
      end;
    end
    else
    begin
      // Mode Exact : comparaison par nom (plus fiable que l'adresse mémoire)
      if SameText(string(T.NameOrg), TargetName) then
      begin
        DeleteFile(T.TransposFile);
        TTransposeEngine.SetTransposDims(T);
        // T.IsTransposed := False;
        T.TransposFile := '';
        // LogMsg(Format('Fichier temporaire supprimé : %s', [string(T.NameOrg)]));
        // eLogMsg(Format(mLang.gMsg('FTE.TempFileRemoved'), [string(T.NameOrg)]));
        eLogMsg(mLang.gMsgFmt('FTE.TempFileRemoved', [string(T.NameOrg)]));
      end;
    end;
  end;

  // Rafraîchissement UI cohérent
  frmEditTensorsRebuildViewS;
  frmEditTensorsUpdateTransposeUI(TSrc);
  // LogMsg('Traitement de suppression terminé.');
  eLogMsg(mLang.gMsg('FTE.ClearOperationFinished'));
  frmEditTensors.lvTensorsS.Invalidate; // Force le rafraîchissement visuel
end;

end.
