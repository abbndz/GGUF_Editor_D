unit uEditTensorsView;

interface

uses
  Windows, Messages, SysUtils, StrUtils, Classes, Controls, Forms, Dialogs, StdCtrls, ComCtrls, ExtCtrls, Graphics,
  Contnrs, CommCtrl, uGGUFModel, uGGUFReader, uGGUFWriter, uGgmlQuants, uGGMLTypes, Generics.Collections, SyncObjs,
  ShellAPI, VCLTee.TeCanvas, uAppConfig, uSafeTensors, uTensorTranspose, uStrUtils, uGGMLConstants, uLangManager,
  Vcl.Menus, System.Actions, Vcl.ActnList, uTensorsNamesMan;

procedure TranslateForms(ISOCode: string);
procedure UpdateMenusLangs;
procedure frmEditTensorsEnableComboBoxFilter(var FromCombo, ToCombo, ModCombo: TComboBox; e: Boolean);

// procedure frmEditTensorsUpdateRow(It: TListItem; T: TGGUFTensorInfo; GlobalSize: Int64);

// Comparateur pour tri des tenseurs par Name
function CompareTensorsByName(Item1, Item2: Pointer): Integer;

function CompareTensorsByColumn(Item1, Item2: Pointer): Integer;

procedure frmEditTensorsRebuildView1;
procedure frmEditTensorsRebuildView2;
procedure frmEditTensorsRebuildView3;
procedure frmEditTensorsRebuildViewS;
procedure frmEditTensorsRebuildViewOut;
procedure frmEditTensorsUpdateDiffBFromA;
procedure frmEditTensorsUpdateDiffCFromA;

implementation

uses uEditTensors, uEditTensorsIO, uViewTensors, uEditKVsGGUF, uSplitMerge, uMappedNamesManager,
  uGGUFTypes, uEditKVsGGUFNewKey, uEditStringDlg, uEditArrayDlg, uFrmAbout, uAppSetting, uLog;

function CompareTensorsByName(Item1, Item2: Pointer): Integer;
var
  T1, T2: TGGUFTensorInfo;
begin
  T1 := TGGUFTensorInfo(Item1);
  T2 := TGGUFTensorInfo(Item2);
  if not Assigned(T1) and not Assigned(T2) then
    Result := 0
  else if not Assigned(T1) then
    Result := -1
  else if not Assigned(T2) then
    Result := 1
  else if (T1.LayerIndex = -1) and (T2.LayerIndex = -1) then
  begin // les deux T1 et T2 sont des métadonnée
    Result := CompareText(string(T1.Name), string(T2.Name))
  end
  else if (T1.LayerIndex = -1) then
  begin // T1 est une métadonnée, il passe devant
    Result := -1;
  end
  else if (T2.LayerIndex = -1) then
  begin // T2 est une métadonnée, il passe devant
    Result := 1
  end
  else
  begin // les deux ont des couches, tri croissant (0, 1, 2...)
    Result := 1;
    if (T1.LayerIndex = T2.LayerIndex) then // même couche
      Result := CompareText(string(T1.TensorPatternName), string(T2.TensorPatternName))
    else if (T1.LayerIndex < T2.LayerIndex) then
      Result := -1;
  end;
end;

function CompareTensorsByColumn(Item1, Item2: Pointer): Integer;
var
  T1, T2: TGGUFTensorInfo;
  Res: Integer;
begin
  T1 := TGGUFTensorInfo(Item1);
  T2 := TGGUFTensorInfo(Item2);
  // Res := 0;

  case frmEditTensors.FSortColumn of
    0: // Colonne : Tensor (Nom - String)
      Res := CompareTensorsByName(Item1, Item2); // CompareText(string(T1.Name), string(T2.Name));
    1: // Colonne : DType (Integer)
      if T1.TensorType < T2.TensorType then
        Res := -1
      else if T1.TensorType > T2.TensorType then
        Res := 1
      else
        Res := 0;
    2: // Colonne : Shape (String)
      Res := CompareText(TensorShapeText(T1.Dims), TensorShapeText(T2.Dims));
    3: // Colonne : Layer (Integer)
      if T1.LayerIndex < T2.LayerIndex then
        Res := -1
      else if T1.LayerIndex > T2.LayerIndex then
        Res := 1
      else
        Res := 0;
    4, 5: // Colonne : Size (UInt64) // Colonne : Size % (Double/Float)
      if T1.ByteSize < T2.ByteSize then
        Res := -1
      else if T1.ByteSize > T2.ByteSize then
        Res := 1
      else
        Res := 0;
    6, 7: // Colonne : TSize (Int64) et TSize %
      if T1.PatternGlobalSize < T2.PatternGlobalSize then
        Res := -1
      else if T1.PatternGlobalSize > T2.PatternGlobalSize then
        Res := 1
      else
        Res := 0;
    8: // Colonne : Off (Int64)
      if T1.Offset < T2.Offset then
        Res := -1
      else if T1.Offset > T2.Offset then
        Res := 1
      else
        Res := 0;
    9: // Colonne : Src (Word/Integer)
      if T1.SourceId < T2.SourceId then
        Res := -1
      else if T1.SourceId > T2.SourceId then
        Res := 1
      else
        Res := 0;
    10: // Colonne : SrcDType (Integer)
      if T1.TensorTypeOrg < T2.TensorTypeOrg then
        Res := -1
      else if T1.TensorTypeOrg > T2.TensorTypeOrg then
        Res := 1
      else
        Res := 0;
  else
    // Par défaut, tri par nom
    Res := CompareText(string(T1.Name), string(T2.Name));
  end;

  // Inversion du résultat si le tri est décroissant
  if frmEditTensors.FSortDirection then
    Result := Res
  else
    Result := -Res;
end;

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
    frmEditTensors.MmLangue1.Clear;
    for I := 0 to ll.Count - 1 do
    begin
      MI := TMenuItem.Create(frmEditTensors.MmLangue1);
      MI.Caption := ll[I]; // Affiche le nom natif (ex: Français, العربية)
      MI.Tag := I; // Stocke l'index pour retrouver l'ISO code
      MI.OnClick := frmEditTensors.MenuLangueItemClick;
      MI.Checked := cfg.sLang = mLang.GetISOCodeByNativeLanguageName(MI.Caption);
      frmEditTensors.MmLangue1.Add(MI);
    end;
    // frmEditTensors.MmLangue1.AutoCheck := true;
  finally
    ll.Free;
  end;
end;

procedure frmEditTensorsEnableComboBoxFilter(var FromCombo, ToCombo, ModCombo: TComboBox; e: Boolean);
begin
  FromCombo.Enabled := e;
  ToCombo.Enabled := e;
  ModCombo.Enabled := e;
end;

procedure frmEditTensorsUpdateRow(It: TListItem; T: TGGUFTensorInfo; GlobalSize: Int64);
var
 // SizeP: Double;
  DisplaySize: Int64;
  DTypeStr: string;
begin
  It.SubItems.Clear;
  DTypeStr := GGMLTypeToStr(T.TensorType);
  It.SubItems.Add(DTypeStr);
  It.SubItems.Add(TensorShapeText(T.Dims));
  if T.LayerIndex >= 0 then
    It.SubItems.Add(IntToStr(T.LayerIndex))
  else
    It.SubItems.Add('-');
  if T.IsConverted then
    DisplaySize := T.ByteSize
  else
    DisplaySize := T.ByteSizeOrg;
  It.SubItems.Add(FormatBytes2f(DisplaySize));
  if GlobalSize > 0 then
  begin
    //SizeP := (DisplaySize / GlobalSize) * 100;
    //It.SubItems.Add(Format('%.2f%%', [SizeP]));
    It.SubItems.Add(FormatPctF(DisplaySize,GlobalSize));
  end
  else
    It.SubItems.Add('0.00%');

  if T.LayerIndex >= 0 then
  begin
    It.SubItems.Add(FormatBytes2f(T.PatternGlobalSize));
    if GlobalSize > 0 then
    begin
      //SizeP := (T.PatternGlobalSize / GlobalSize) * 100;
      //It.SubItems.Add(Format('%.2f%%', [SizeP]));
      It.SubItems.Add(FormatPctF(T.PatternGlobalSize,GlobalSize));

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
  It.SubItems.Add(IntToStr(T.UseImpl));
  It.SubItems.Add(IntToStr(T.RmseType));
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
  // todo if FSortType then
  // frmEditTensors.FViewTensors1.Sort(@CompareTensorsByName);
  if frmEditTensors.FSortColumn >= 0 then
    frmEditTensors.FViewTensors1.Sort(@CompareTensorsByColumn);
  // frmEditTensors.FViewTensors1.Sort(@CompareTensorsGeneric);

  frmEditTensors.lvTensors1.Items.BeginUpdate;
  try
    frmEditTensors.lvTensors1.Items.Clear;
    for I := 0 to frmEditTensors.FViewTensors1.Count - 1 do
    begin
      T := TGGUFTensorInfo(frmEditTensors.FViewTensors1[I]);
      ssf := Trim(LowerCase(frmEditTensors.edtFilter1.Text));
      if not((ssf = '') or (Pos(ssf, LowerCase(string(T.Name))) > 0)) then
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
    frmEditTensors.lvTensors1.Invalidate;
    if frmEditTensors.PageControl1.ActivePage = frmEditTensors.TabSheetModInA then
       eLogMsg(mLang.gMsgFmt('FTE.TensorsFound', [iCount]),-1,-1,lvInfo);
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

  // frmEditTensors.FViewTensors2.Sort(@CompareTensorsByName);
  frmEditTensors.FViewTensors2.Sort(@CompareTensorsByColumn);

  frmEditTensors.lvTensors2.Items.BeginUpdate;
  try
    frmEditTensors.lvTensors2.Items.Clear;
    for I := 0 to frmEditTensors.FViewTensors2.Count - 1 do
    begin
      T := TGGUFTensorInfo(frmEditTensors.FViewTensors2[I]);
      ssf := Trim(LowerCase(frmEditTensors.edtFilter2.Text));
      if not((ssf = '') or (Pos(ssf, LowerCase(string(T.Name))) > 0)) then
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
    frmEditTensors.lvTensors2.Invalidate;
    if frmEditTensors.PageControl1.ActivePage = frmEditTensors.TabSheetModInB then
       eLogMsg(mLang.gMsgFmt('FTE.TensorsFound', [iCount]),-1,-1,lvInfo);
  end;
end;

procedure frmEditTensorsRebuildView3;
var
  I, iCount: Integer;
  T: TGGUFTensorInfo;
  It: TListItem;
  ssf: string;
begin
  if not Assigned(frmEditTensors.FModelInp3) then
    exit;
  iCount := 0;
  frmEditTensors.FViewTensors3.Clear;
  for I := 0 to frmEditTensors.FModelInp3.Tensors.Count - 1 do
  begin
    frmEditTensors.FViewTensors3.Add(frmEditTensors.FModelInp3.Tensors[I]);
  end;

  // frmEditTensors.FViewTensors2.Sort(@CompareTensorsByName);
  frmEditTensors.FViewTensors3.Sort(@CompareTensorsByColumn);

  frmEditTensors.lvTensors3.Items.BeginUpdate;
  try
    frmEditTensors.lvTensors3.Items.Clear;
    for I := 0 to frmEditTensors.FViewTensors3.Count - 1 do
    begin
      T := TGGUFTensorInfo(frmEditTensors.FViewTensors3[I]);
      ssf := Trim(LowerCase(frmEditTensors.edtFilter3.Text));
      if not((ssf = '') or (Pos(ssf, LowerCase(string(T.Name))) > 0)) then
        Continue;
      It := frmEditTensors.lvTensors3.Items.Add;
      It.Data := T;
      ssf := string(T.Name);
      if T.IsNameMapped then
        ssf := ssf + ' * ';
      It.Caption := ssf;
      // It.Checked := GetKeep(It.Caption); // ou T.Keep
      iCount := iCount + 1;
      frmEditTensorsUpdateRow(It, T, frmEditTensors.FGlobalSize3);
    end;
  finally
    frmEditTensors.lvTensors3.Items.EndUpdate;
    frmEditTensors.lvTensors3.Invalidate;
    if frmEditTensors.PageControl1.ActivePage = frmEditTensors.TabSheetModInC then
       eLogMsg(mLang.gMsgFmt('FTE.TensorsFound', [iCount]),-1,-1,lvInfo);
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
    if (ssf = '') or (Pos(ssf, LowerCase(string(T.NameOrg))) > 0) or (Pos(ssf, LowerCase(string(T.Name))) > 0) then
    begin
      frmEditTensors.FViewTensorsS.Add(T);
      iCount := iCount + 1;
    end;
  end;

  frmEditTensors.FViewTensorsS.Sort(@CompareTensorsByColumn);

  frmEditTensors.lvTensorsS.Items.BeginUpdate;
  try
    frmEditTensors.lvTensorsS.Items.Count := frmEditTensors.FViewTensorsS.Count;
  finally
    frmEditTensors.lvTensorsS.Items.EndUpdate;
    frmEditTensors.lvTensorsS.Invalidate;
  end;
  if frmEditTensors.PageControl1.ActivePage = frmEditTensors.TabSheetModInS then
     eLogMsg(mLang.gMsgFmt('FTE.TensorsFound', [iCount]),-1,-1,lvInfo);
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
  if frmEditTensors.FUpdatingOutList then
    exit;

  frmEditTensors.FUpdatingOutList := True;

  // Recalculer les tailles globales avant d'afficher pour avoir les bons %
  frmEditTensors.FGlobalSizeOut := CalculateAllPatternSizes(frmEditTensors.FModelOut);
  // frmEditTensors.edtSizeOut.Text
  frmEditTensors.stBar1.Panels[SB_MO].Text := FormatBytes2f(frmEditTensors.FGlobalSizeOut);
  iCount := 0;
  frmEditTensors.FViewTensorsOut.Clear;
  for I := 0 to frmEditTensors.FModelOut.Tensors.Count - 1 do
    frmEditTensors.FViewTensorsOut.Add(frmEditTensors.FModelOut.Tensors[I]);

  // frmEditTensors.FViewTensorsOut.Sort(@CompareTensorsByName);
  frmEditTensors.FViewTensorsOut.Sort(@CompareTensorsByColumn);

  frmEditTensors.lvTensorsOut.Items.BeginUpdate;
  try
    frmEditTensors.lvTensorsOut.Items.Clear;
    for I := 0 to frmEditTensors.FViewTensorsOut.Count - 1 do
    begin
      T := TGGUFTensorInfo(frmEditTensors.FViewTensorsOut[I]);
      ssf := Trim(LowerCase(frmEditTensors.edtFilterO.Text));
      if not((ssf = '') or (Pos(ssf, LowerCase(string(T.Name))) > 0)) then
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
    frmEditTensors.lvTensorsOut.Invalidate;
    frmEditTensors.FUpdatingOutList := False;
    // frmEditTensors.StatusBar1.Panels[0].Text := IntToStr(iCount) + ' Tensors found';
    if frmEditTensors.PageControl1.ActivePage = frmEditTensors.TabSheetModOut then
       eLogMsg(mLang.gMsgFmt('FTE.TensorsFound', [iCount]),-1,-1,lvInfo);
  end;
end;

procedure frmEditTensorsUpdateDiffBFromA;
var
  I: Integer;
  T_A, T_B: TGGUFTensorInfo;
  MapA: TDictionary<string, TGGUFTensorInfo>;
  MapB: TDictionary<string, TGGUFTensorInfo>;
begin
  frmEditTensors.FDiffShapeAvsB.Clear;
  frmEditTensors.FDiffQuantAvsB.Clear;
  frmEditTensors.FAbsentAvsB.Clear;

  if not Assigned(frmEditTensors.FModelInp1) or not Assigned(frmEditTensors.FModelInp2) then
    exit;
  MapA := TDictionary<string, TGGUFTensorInfo>.Create;
  MapB := TDictionary<string, TGGUFTensorInfo>.Create;
  try
    for I := 0 to frmEditTensors.FModelInp1.Tensors.Count - 1 do
    begin
      T_A := TGGUFTensorInfo(frmEditTensors.FModelInp1.Tensors[I]);
      MapA.AddOrSetValue(string(T_A.Name), T_A);
    end;
    for I := 0 to frmEditTensors.FModelInp2.Tensors.Count - 1 do
    begin
      T_B := TGGUFTensorInfo(frmEditTensors.FModelInp2.Tensors[I]);
      MapB.AddOrSetValue(string(T_B.Name), T_B);
    end;
    // On compare le modèle B avec la map de A
    for I := 0 to frmEditTensors.FModelInp2.Tensors.Count - 1 do
    begin
      T_B := TGGUFTensorInfo(frmEditTensors.FModelInp2.Tensors[I]);
      if not MapA.TryGetValue(string(T_B.Name), T_A) then
      begin
        // Cas 1 : Le tenseur n'existe pas dans A
        frmEditTensors.FAbsentAvsB.AddOrSetValue(string(T_B.Name), True);
      end
      else if (T_A.Cols <> T_B.Cols) or (T_A.Rows <> T_B.Rows) then
      begin
        // Cas 2 : Le tenseur existe mais la quantification (DType) ou la taille est différente
        frmEditTensors.FDiffShapeAvsB.AddOrSetValue(string(T_B.Name), True);
      end
      else if (T_A.TensorType <> T_B.TensorType) or (T_A.ByteSize <> T_B.ByteSize) then
      begin
        // Cas 2 : Le tenseur existe mais la quantification (DType) ou la taille est différente
        frmEditTensors.FDiffQuantAvsB.AddOrSetValue(string(T_B.Name), True);
      end;
    end;
    for I := 0 to frmEditTensors.FModelInp1.Tensors.Count - 1 do
    begin
      T_A := TGGUFTensorInfo(frmEditTensors.FModelInp1.Tensors[I]);
      if not MapB.TryGetValue(string(T_A.Name), T_B) then
      begin
        // Le tenseur n'existe pas dans B
        frmEditTensors.FAbsentAvsB.AddOrSetValue(string(T_A.Name), True);
      end;
    end;
  finally
    MapA.Free;
    MapB.Free;
  end;
end;

procedure frmEditTensorsUpdateDiffCFromA;
var
  I: Integer;
  T_A, T_C: TGGUFTensorInfo;
  MapA: TDictionary<string, TGGUFTensorInfo>;
  MapC: TDictionary<string, TGGUFTensorInfo>;
begin
  frmEditTensors.FDiffShapeAvsC.Clear;
  frmEditTensors.FDiffQuantAvsC.Clear;
  frmEditTensors.FAbsentAvsC.Clear;

  if not Assigned(frmEditTensors.FModelInp1) or not Assigned(frmEditTensors.FModelInp3) then
    exit;
  MapA := TDictionary<string, TGGUFTensorInfo>.Create;
  MapC := TDictionary<string, TGGUFTensorInfo>.Create;
  try
    for I := 0 to frmEditTensors.FModelInp1.Tensors.Count - 1 do
    begin
      T_A := TGGUFTensorInfo(frmEditTensors.FModelInp1.Tensors[I]);
      MapA.AddOrSetValue(string(T_A.Name), T_A);
    end;
    for I := 0 to frmEditTensors.FModelInp3.Tensors.Count - 1 do
    begin
      T_C := TGGUFTensorInfo(frmEditTensors.FModelInp3.Tensors[I]);
      MapC.AddOrSetValue(string(T_C.Name), T_C);
    end;
    // On compare le modèle B avec la map de A
    for I := 0 to frmEditTensors.FModelInp3.Tensors.Count - 1 do
    begin
      T_C := TGGUFTensorInfo(frmEditTensors.FModelInp3.Tensors[I]);
      if not MapA.TryGetValue(string(T_C.Name), T_A) then
      begin
        // Cas 1 : Le tenseur n'existe pas dans A
        frmEditTensors.FAbsentAvsC.AddOrSetValue(string(T_C.Name), True);
      end
      else if (T_A.Cols <> T_C.Cols) or (T_A.Rows <> T_C.Rows) then
      begin
        // Cas 2 : Le tenseur existe mais la quantification (DType) ou la taille est différente
        frmEditTensors.FDiffShapeAvsC.AddOrSetValue(string(T_C.Name), True);
      end
      else if (T_A.TensorType <> T_C.TensorType) or (T_A.ByteSize <> T_C.ByteSize) then
      begin
        // Cas 2 : Le tenseur existe mais la quantification (DType) ou la taille est différente
        frmEditTensors.FDiffQuantAvsC.AddOrSetValue(string(T_C.Name), True);
      end;
    end;
    for I := 0 to frmEditTensors.FModelInp1.Tensors.Count - 1 do
    begin
      T_A := TGGUFTensorInfo(frmEditTensors.FModelInp1.Tensors[I]);
      if not MapC.TryGetValue(string(T_A.Name), T_C) then
      begin
        // Le tenseur n'existe pas dans C
        frmEditTensors.FAbsentAvsC.AddOrSetValue(string(T_A.Name), True);
      end;
    end;
  finally
    MapA.Free;
    MapC.Free;
  end;
end;

end.
