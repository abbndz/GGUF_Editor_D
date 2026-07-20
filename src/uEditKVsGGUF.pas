unit uEditKVsGGUF;

interface

uses
  Windows, Messages, SysUtils, IOUtils, Classes, Controls, Forms, Dialogs, StdCtrls, ComCtrls, ExtCtrls, Graphics,
  System.StrUtils, Generics.Collections,
  uGGUFModel, uGGUFReader, uGGUFWriter, uGGUFTypes, uGGMLTypes, uGgufStrUtils, uMath, uKVsGGUFConst;

type
  TfrmEditKVsGGUF = class(TForm)
    PageControl1: TPageControl;
    TabSheetModel1: TTabSheet;
    TabSheetModel2: TTabSheet;
    TabSheetModelOut: TTabSheet;
    grpFilter1: TGroupBox;
    grpFilter2: TGroupBox;
    grpFilterOut: TGroupBox;
    lblFilter1: TLabel;
    lblFilter2: TLabel;
    lblFilterOut: TLabel;
    edtFilter1: TEdit;
    edtFilter2: TEdit;
    edtFilterOut: TEdit;
    pnlTransfer1: TPanel;
    pnlTransfer2: TPanel;
    btnTransferAll1: TButton;
    btnTransferAll2: TButton;
    btnTransferSel1: TButton;
    btnTransferSel2: TButton;
    grpEdit: TGroupBox;
    lblKey: TLabel;
    lblType: TLabel;
    memoValue: TMemo;
    btnUpsert: TButton;
    btnEditStrArray: TButton;
    btnAdd: TButton;
    btnUncheck: TButton;
    StatusBar1: TStatusBar;
    cbType: TComboBox;
    lvKVs1: TListView;
    lvKVs2: TListView;
    lvKVsOut: TListView;
    btnImportKVs: TButton;
    btnExportKVs: TButton;
    OpenDialog1: TOpenDialog;
    SaveDialog1: TSaveDialog;
    btnClearFText1: TButton;
    btnClearFText2: TButton;
    btnClearFTextO: TButton;
    Splitter1: TSplitter;
    edtKey: TEdit;
    ProgressBar1: TProgressBar;

    procedure FormCreate(Sender: TObject);
    procedure PageControl1Change(Sender: TObject);
    procedure edtFilterChange(Sender: TObject);
    procedure lvKVsSelectItem(Sender: TObject; Item: TListItem; Selected: Boolean);
    procedure btnTransferAllClick(Sender: TObject);
    procedure btnTransferSelClick(Sender: TObject);
    procedure btnUpsertClick(Sender: TObject);
    procedure btnUncheckClick(Sender: TObject);
    procedure btnEditStrArrayClick(Sender: TObject);
    procedure btnAddClick(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure lvKVsOutItemChecked(Sender: TObject; Item: TListItem);
    procedure btnClearFTextOClick(Sender: TObject);
    procedure btnClearFText2Click(Sender: TObject);
    procedure btnClearFText1Click(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure lvKVs1CustomDrawItem(Sender: TCustomListView; Item: TListItem; State: TCustomDrawState;
      var DefaultDraw: Boolean);
    procedure lvKVsOutCustomDrawItem(Sender: TCustomListView; Item: TListItem; State: TCustomDrawState;
      var DefaultDraw: Boolean);
    procedure lvKVsOutAdvancedCustomDrawSubItem(Sender: TCustomListView; Item: TListItem; SubItem: Integer;
      State: TCustomDrawState; Stage: TCustomDrawStage; var DefaultDraw: Boolean);
    procedure lvKVs2CustomDrawSubItem(Sender: TCustomListView; Item: TListItem; SubItem: Integer;
      State: TCustomDrawState; var DefaultDraw: Boolean);
    procedure lvKVs1CustomDrawSubItem(Sender: TCustomListView; Item: TListItem; SubItem: Integer;
      State: TCustomDrawState; var DefaultDraw: Boolean);
    procedure btnExportKVsClick(Sender: TObject);
    procedure btnImportKVsClick(Sender: TObject);
  private
    FModelA, FModelB, FModelOut: TGGUFFile;
    FCurrentTab: Integer;
    FMaxArrayItems1: Integer;

    FDiffOutCache: TDictionary<string, Boolean>; // Cache pour les clés différentes
    FDiffACache: TDictionary<string, Boolean>; // Cache pour les clés différentes entre 1 et 2
    FDiffBCache: TDictionary<string, Boolean>; // Cache pour les clés différentes entre 1 et 2
    FDiffOutCacheDirty: Boolean;
    FDiffABCacheDirty: Boolean;

    FLastUIUpdateTick: Int64;

    procedure EnabledBtns(e: Boolean);

    procedure UpsertToOut(KV: TGGUFKeyValue);
    procedure UpdateDiffABOutCache;
    procedure UpdateDiffABCache;
    procedure Log(const S: string);
    procedure RebuildList(AList: TListView; AModel: TGGUFFile; const Filter: string);
    procedure TransferToOut(ASourceId: Integer; AAll: Boolean);
    function PassFilter(const Key, FilterText: string): Boolean;
    procedure LoadSelectedToEditors(KV: TGGUFKeyValue);
    procedure UpdateOutEditors;
  public
    property ModelA: TGGUFFile read FModelA write FModelA;
    property ModelB: TGGUFFile read FModelB write FModelB;
    property ModelOut: TGGUFFile read FModelOut write FModelOut;
    procedure AddNewKeyValue(NewKV: TGGUFKeyValue);
    procedure RefreshAll;
    procedure OnProgressEventLoad(const Msg: string; AIdx, ATotal: Int64);
    procedure OnProgressEventSave(const Msg: string; ATensorIdx, ATensorTotal, AByteIdx, AByteTotal: Int64);
  end;

var
  frmEditKVsGGUF: TfrmEditKVsGGUF;

implementation

uses uEditArrayDlg, uEditStringDlg, uEditKVsGGUFNewKey, uLangManager, uLog;

{$R *.dfm}

procedure TfrmEditKVsGGUF.OnProgressEventLoad(const Msg: string; AIdx, ATotal: Int64);
var
  CurrentUIUpdateTick: Int64;
begin
  CurrentUIUpdateTick := GetTickCount64;
  if (CurrentUIUpdateTick - FLastUIUpdateTick < 50) then
    exit;
  FLastUIUpdateTick := CurrentUIUpdateTick;
  TThread.Queue(nil,
    procedure
    begin
      if Assigned(frmEditKVsGGUF) then
      begin
        ProgressBar1.Max := ATotal;
        ProgressBar1.Position := AIdx;
        StatusBar1.Panels[0].Text := Msg;
        // Application.ProcessMessages;
      end;
    end);
end;

procedure TfrmEditKVsGGUF.OnProgressEventSave(const Msg: string; ATensorIdx, ATensorTotal, AByteIdx, AByteTotal: Int64);
var
  ElapsedMs: Int64;
  SpeedMBs: Double;
  aPerc: Integer;
  CurrentUIUpdateTick: Int64;
begin
  // Throttle UI (~20Hz) pour éviter la surcharge de la file VCL
  CurrentUIUpdateTick := GetTickCount64;
  if (CurrentUIUpdateTick - FLastUIUpdateTick < 50) then
    exit;
  FLastUIUpdateTick := CurrentUIUpdateTick;
  TThread.Queue(nil,
    procedure
    begin
      if Assigned(frmEditKVsGGUF) then
      begin
        // UI Fluide
        aPerc := 0;
        if AByteTotal > 0 then
          aPerc := Trunc(AByteIdx / AByteTotal * 100);
        StatusBar1.Panels[0].Text := Format('%s | %d ', [Msg, aPerc]) + '%';

        ProgressBar1.Max := ATensorTotal;
        ProgressBar1.Position := ATensorIdx;
      end;
    end);
end;

{ INITIALISATION }
procedure TfrmEditKVsGGUF.FormCreate(Sender: TObject);
var
  aLVs: array [1 .. 3] of TListView;
  LV: TListView;
  i, VT: Integer;
  Arch: string;
  aKV: TGGUFKeyValue;

  KeysArray: TArray<string>;
  StringList: TStringList;
  SL: TStringList;
begin
  Caption := 'Edit GGUF KVs';
  FModelA := nil;
  FModelB := nil;
  FModelOut := nil;
  FCurrentTab := 2; // Default to Out
  aLVs[1] := lvKVs1;
  aLVs[2] := lvKVs2;
  aLVs[3] := lvKVsOut;

  // Configure ListViews
  // for LV in [lvKVs1, lvKVs2, lvKVsOut] do
  for i := 1 to 3 do
  begin
    LV := aLVs[i];
    LV.ViewStyle := vsReport;
    LV.Checkboxes := True;
    LV.RowSelect := True;
    LV.ReadOnly := True;
    LV.Columns.Clear;
    with LV.Columns.Add do
    begin
      Caption := 'Keep';
      Width := 40;
    end;
    with LV.Columns.Add do
    begin
      Caption := 'Key';
      Width := 180;
    end;
    with LV.Columns.Add do
    begin
      Caption := 'Type';
      Width := 80;
    end;
    with LV.Columns.Add do
    begin
      Caption := 'Value (preview)';
      Width := 350;
    end;
  end;

  cbType.Items.Clear;
  { TGGUFValueType = (gvt_None = -1, gvt_UINT8 = 0, gvt_INT8 = 1, gvt_UINT16 = 2, gvt_INT16 = 3, gvt_UINT32 = 4,
    gvt_INT32 = 5, gvt_FLOAT32 = 6, gvt_BOOL = 7, gvt_STRING = 8, gvt_ARRAY = 9, gvt_UINT64 = 10, gvt_INT64 = 11,
    gvt_FLOAT64 = 12); }
  for VT := Integer(Low(TGGUFValueType)) to Integer(High(TGGUFValueType)) do
    cbType.Items.Add(GGUFTypeToStr(TGGUFValueType(VT)));
  cbType.ItemIndex := cbType.Items.IndexOf('STRING');

  Arch := '';
  // if Assigned(FModelOut) and FModelOut.HasKV('general.architecture') then
  if Assigned(FModelOut) then
  begin
    aKV := TGGUFKeyValue(FModelOut.FindKV('general.architecture'));
    if Assigned(aKV) then
      Arch := string(TGGUFKeyValue(FModelOut.FindKV('general.architecture').Val.VStr));
  end;

  // frmEditNewKV.cbKey.Items.Assign(TGGUFKeyManager.GetKeysForFamily(kfGeneral, Arch));
  SL := TGGUFKeyManager.GetKeysForFamily(kfGeneral, Arch);
  try
    frmEditNewKV.cbKey.Items.Assign(SL);
  finally
    SL.Free;
  end;
  if frmEditNewKV.cbKey.Items.Count > 0 then // edtKey
    frmEditNewKV.cbKey.ItemIndex := 0;
  frmEditNewKV.cbKey.ItemIndex := 0;

  frmEditNewKV.cbKeyFamily.Items.Clear;
  frmEditNewKV.cbKeyFamily.Items.Assign(TGGUFKeyManager.GetFamilyNames);
  frmEditNewKV.cbKeyFamily.ItemIndex := 1; // Par défaut sur "General" (index 1 car index 0 est "Autre")
  frmEditNewKV.cbKeyFamily.ItemIndex := 1;

  memoValue.ScrollBars := ssBoth;
  memoValue.WordWrap := False;
  btnEditStrArray.Enabled := False;

  FDiffOutCache := TDictionary<string, Boolean>.Create;
  FDiffACache := TDictionary<string, Boolean>.Create;
  FDiffBCache := TDictionary<string, Boolean>.Create;
end;

procedure TfrmEditKVsGGUF.FormDestroy(Sender: TObject);
begin
  FDiffOutCache.Free;
  FDiffACache.Free;
  FDiffBCache.Free;
  inherited;
end;

procedure TfrmEditKVsGGUF.FormShow(Sender: TObject);
begin
  FDiffABCacheDirty := True;
  FDiffOutCacheDirty := True;
  RefreshAll;
end;

// Méthode pour mettre à jour cbKey basé sur cbKeyFamilly ---

procedure TfrmEditKVsGGUF.RefreshAll;
begin
  RebuildList(lvKVs1, FModelA, edtFilter1.Text);
  RebuildList(lvKVs2, FModelB, edtFilter2.Text);
  RebuildList(lvKVsOut, FModelOut, edtFilterOut.Text);
  UpdateOutEditors;
end;

{ UI & NAVIGATION }
procedure TfrmEditKVsGGUF.PageControl1Change(Sender: TObject);
begin
  if PageControl1.ActivePage = TabSheetModel1 then
    FCurrentTab := 0
  else if PageControl1.ActivePage = TabSheetModel2 then
    FCurrentTab := 1
  else if PageControl1.ActivePage = TabSheetModelOut then
  begin
    FCurrentTab := 2;
    UpdateOutEditors;
  end;
end;

procedure TfrmEditKVsGGUF.edtFilterChange(Sender: TObject);
begin
  if PageControl1.ActivePage = TabSheetModel1 then
    RebuildList(lvKVs1, FModelA, edtFilter1.Text)
  else if PageControl1.ActivePage = TabSheetModel2 then
    RebuildList(lvKVs2, FModelB, edtFilter2.Text)
  else if PageControl1.ActivePage = TabSheetModelOut then
    RebuildList(lvKVsOut, FModelOut, edtFilterOut.Text);
end;

{ LOGIQUE METIER }
procedure TfrmEditKVsGGUF.Log(const S: string);
begin
  if Assigned(frmLogs) then
    LogMsg('EdKVs] ' + S);
  StatusBar1.Panels[0].Text := S;
end;

function TfrmEditKVsGGUF.PassFilter(const Key, FilterText: string): Boolean;
var
  ssf: string;
begin
  ssf := Trim(LowerCase(FilterText));
  if ssf = '' then
    Result := True
  else
    Result := (pos(ssf, LowerCase(Key)) > 0);
end;

procedure TfrmEditKVsGGUF.RebuildList(AList: TListView; AModel: TGGUFFile; const Filter: string);
var
  i: Integer;
  KV: TGGUFKeyValue;
  It: TListItem;
  k: string;
begin
  if not Assigned(AModel) then
    exit;

  // MISE À JOUR DU CACHE DES DIFFÉRENCES (uniquement pour lvKVsOut)
  if (AList = lvKVsOut) and FDiffOutCacheDirty then
    UpdateDiffABOutCache;

  if ((AList = lvKVs1) or (AList = lvKVs2)) and FDiffABCacheDirty then
    UpdateDiffABCache;

  AList.Items.BeginUpdate;
  try
    AList.Items.Clear;
    for i := 0 to AModel.KVs.Count - 1 do
    begin
      KV := TGGUFKeyValue(AModel.KVs[i]);
      k := string(KV.Key);
      if not PassFilter(k, Filter) then
        Continue;

      It := AList.Items.Add;
      It.SubItems.Add(k);
      It.SubItems.Add(GGUFTypeToStr(KV.Val.ValueType));
      It.SubItems.Add(KV.Val.AsStrPrev);
      It.Data := KV;

      // Pour ModelOut, on utilise l'état de l'objet KV.Keep
      if AList = lvKVsOut then
        It.Checked := KV.Keep
      else
        It.Checked := True;
    end;
  finally
    AList.Items.EndUpdate;
  end;
end;

procedure TfrmEditKVsGGUF.TransferToOut(ASourceId: Integer; AAll: Boolean);
var
  SrcMod: TGGUFFile;
  SrcLV: TListView;
  i, J: Integer;
  KVSrc, KVOut: TGGUFKeyValue;
  Found: Boolean;
begin
  if ASourceId = 1 then
  begin
    SrcMod := FModelA;
    SrcLV := lvKVs1;
  end
  else if ASourceId = 2 then
  begin
    SrcMod := FModelB;
    SrcLV := lvKVs2;
  end
  else
    exit;

  if not Assigned(SrcMod) then
  begin
    // Log('Modèle source non chargé.');
    Log(mLang.gMsg('FKV.TransferSourceNotLoaded'));
    exit;
  end;

  if AAll then
  begin
    for i := 0 to SrcMod.KVs.Count - 1 do
    begin
      KVSrc := TGGUFKeyValue(SrcMod.KVs[i]);
      KVOut := KVSrc.Clone;
      KVOut.Keep := True;
      Found := False;
      for J := 0 to FModelOut.KVs.Count - 1 do
        if SameStr(string(TGGUFKeyValue(FModelOut.KVs[J]).Key), string(KVSrc.Key)) then
        begin
          FModelOut.KVs[J] := KVOut;
          Found := True;
          Break;
        end;
      if not Found then
        FModelOut.KVs.Add(KVOut);
    end;
    // Log('Transfer All from Model ' + IntToStr(ASourceId) + ' to Out.');
    Log(mLang.gMsgFmt('FKV.TransferAllDone', [ASourceId]));
  end
  else
  begin
    if not Assigned(SrcLV.Selected) then
    begin
      // MessageDlg('Sélectionnez un KV à transférer.', mtWarning, [mbOK], 0);
      MessageDlg(mLang.gMsg('FKV.SelectKVToTransfer'), mtWarning, [mbOK], 0);
      exit;
    end;
    KVSrc := TGGUFKeyValue(SrcLV.Selected.Data);
    KVOut := KVSrc.Clone;
    KVOut.Keep := True;
    Found := False;
    for J := 0 to FModelOut.KVs.Count - 1 do
      if SameText(string(TGGUFKeyValue(FModelOut.KVs[J]).Key), string(KVSrc.Key)) then
      begin
        FModelOut.KVs[J] := KVOut;
        Found := True;
        Break;
      end;
    if not Found then
      FModelOut.KVs.Add(KVOut);
    // Log('KV "' + string(KVSrc.Key) + '" transferred to Out.');
    Log(mLang.gMsgFmt('FKV.TransferSelDone', [string(KVSrc.Key)]));
  end;
  RebuildList(lvKVsOut, FModelOut, edtFilterOut.Text);
  UpdateOutEditors;
end;

procedure TfrmEditKVsGGUF.btnTransferAllClick(Sender: TObject);
begin
  if PageControl1.ActivePage = TabSheetModel1 then
    TransferToOut(1, True)
  else if PageControl1.ActivePage = TabSheetModel2 then
    TransferToOut(2, True);
end;

procedure TfrmEditKVsGGUF.btnTransferSelClick(Sender: TObject);
begin
  if PageControl1.ActivePage = TabSheetModel1 then
    TransferToOut(1, False)
  else if PageControl1.ActivePage = TabSheetModel2 then
    TransferToOut(2, False);
end;

procedure TfrmEditKVsGGUF.lvKVsOutItemChecked(Sender: TObject; Item: TListItem);
var
  KV: TGGUFKeyValue;
begin
  if (Item = nil) or (Item.Data = nil) then
    exit;
  KV := TGGUFKeyValue(Item.Data);
  KV.Keep := Item.Checked;
  if KV.Keep then
    // Log('KV "' + string(KV.Key) + '" marked to KEEP.')
    Log(mLang.gMsgFmt('FKV.KVKeep', [string(KV.Key)]))
  else
    // Log('KV "' + string(KV.Key) + ' marked for REMOVAL.');
    Log(mLang.gMsgFmt('FKV.KVRemove', [string(KV.Key)]));
end;

procedure TfrmEditKVsGGUF.lvKVsSelectItem(Sender: TObject; Item: TListItem; Selected: Boolean);
begin
  if not Selected or (Item = nil) then
    exit;
  if Sender = lvKVsOut then
    LoadSelectedToEditors(TGGUFKeyValue(Item.Data));
end;

procedure TfrmEditKVsGGUF.LoadSelectedToEditors(KV: TGGUFKeyValue);
begin
  if not Assigned(KV) then
    exit;
  edtKey.Text := string(KV.Key);

  cbType.ItemIndex := cbType.Items.IndexOf(GGUFTypeToStr(KV.Val.ValueType));
  if cbType.ItemIndex < 0 then
  begin
    cbType.ItemIndex := cbType.Items.IndexOf('STRING'); // Fallback
    btnUpsert.Enabled := False;
    exit;
  end;

  btnUpsert.Enabled := True;
  memoValue.Lines.BeginUpdate;
  try
    memoValue.Clear;
    if (KV.Val.ValueType = gvt_ARRAY) then
      memoValue.Lines.Text := KV.Val.AsStrPrev()
    else
      memoValue.Lines.Text := KV.Val.AsStrFull;
  finally
    memoValue.Lines.EndUpdate;
  end;

  // Désactiver l'édition directe du memo pour les ARRAY et pas les String
  memoValue.ReadOnly := (KV.Val.ValueType = gvt_ARRAY); // or (KV.Val.ValueType = gvt_STRING);
  btnEditStrArray.Enabled := (KV.Val.ValueType = gvt_ARRAY) or (KV.Val.ValueType = gvt_STRING);
end;

procedure TfrmEditKVsGGUF.UpdateOutEditors;
begin
  if not Assigned(lvKVsOut.Selected) then
  begin
    edtKey.Text := '';
    cbType.ItemIndex := cbType.Items.IndexOf('STRING');
    memoValue.Lines.Clear;
    btnEditStrArray.Enabled := False;
  end;
end;

procedure TfrmEditKVsGGUF.btnUpsertClick(Sender: TObject);
var
  Key: string;
  KV: TGGUFKeyValue;
begin
  if not Assigned(FModelOut) then
    // raise Exception.Create('ModelOut non chargé.');
    raise Exception.Create(mLang.gMsg('FKV.ModelNotLoaded'));
  Key := Trim(edtKey.Text);
  if Key = '' then
  begin
    // MessageDlg('Key vide.', mtWarning, [mbOK], 0);
    MessageDlg(mLang.gMsg('FKV.KeyEmpty'), mtWarning, [mbOK], 0);
    exit;
  end;

  KV := FModelOut.FindKV(Key);
  if not Assigned(KV) then
  begin
    if Assigned(lvKVsOut.Selected) then
      KV := TGGUFKeyValue(lvKVsOut.Selected.Data)
    else
    begin
      // MessageDlg('Key non trouvée.', mtWarning, [mbOK], 0);
      MessageDlg(mLang.gMsg('FKV.KeyNotFound'), mtWarning, [mbOK], 0);
      exit;
    end;
  end;

  if (KV.Val.ValueType = gvt_ARRAY) then
  begin
    // MessageDlg('Utilisez "Edit ARRAY..." pour les tableaux.', mtInformation, [mbOK], 0);
    MessageDlg(mLang.gMsg('FKV.EditArrayMsg'), mtInformation, [mbOK], 0);
    exit;
  end;

  try
    UpsertToOut(KV);
    FDiffOutCacheDirty := True;
    RebuildList(lvKVsOut, FModelOut, edtFilterOut.Text);
    // Log('KV upserted/updated.');
    Log(mLang.gMsg('FKV.UpsertDone'));
  except
    on e: Exception do
      // MessageDlg('Erreur : ' + e.Message, mtError, [mbOK], 0);
      MessageDlg(mLang.gMsgFmt('FKV.UpsertError', [e.Message]), mtError, [mbOK], 0);
  end;
end;

procedure TfrmEditKVsGGUF.UpsertToOut(KV: TGGUFKeyValue);
var
  Key: AnsiString;
  NewV: TGGUFValue;
begin
  Key := AnsiString(Trim(edtKey.Text));
  if Key = '' then
    // raise Exception.Create('Key vide.');
    raise Exception.Create(mLang.gMsg('FKV.KeyEmpty'));

  if not ParseStringValue(Trim(memoValue.Text), StrToGGUFType(cbType.Text), NewV) then
    // raise Exception.Create('Format de valeur invalide pour le type sélectionné.');
    raise Exception.Create(mLang.gMsg('FKV.InvalidValueFormat'));

  KV.Val.Free;
  KV.Val := NewV;
  KV.Keep := True;
end;

{ Mise à jour du cache des différences }
procedure TfrmEditKVsGGUF.UpdateDiffABOutCache;
var
  i: Integer;
  OutKV, AKey, BKey: TGGUFKeyValue;
  Diff: Boolean;
begin
  FDiffOutCacheDirty := False;
  FDiffOutCache.Clear;
  if not Assigned(FModelOut) then
    exit;
  for i := 0 to FModelOut.KVs.Count - 1 do
  begin
    OutKV := TGGUFKeyValue(FModelOut.KVs[i]);
    Diff := False;
    // 1. Vérifier dans ModelA
    if Assigned(FModelA) then
    begin
      AKey := FModelA.FindKV(OutKV.Key);
      if Assigned(AKey) then
      begin
        if not GGUFValuesEqual(AKey.Val, OutKV.Val) then
          Diff := True;
      end
      else
      begin
        // 2. Clé absente de A, vérifier dans ModelB
        if Assigned(FModelB) then
        begin
          BKey := FModelB.FindKV(OutKV.Key);
          if Assigned(BKey) then
          begin
            if not GGUFValuesEqual(BKey.Val, OutKV.Val) then
              Diff := True;
          end
          else
            Diff := True; // Absente de A et B -> Nouvelle clé
        end
        else
          Diff := True;
      end;
    end
    else
    begin
      // ModelA non chargé, vérifier uniquement dans ModelB
      if Assigned(FModelB) then
      begin
        BKey := FModelB.FindKV(OutKV.Key);
        if Assigned(BKey) then
        begin
          if not GGUFValuesEqual(BKey.Val, OutKV.Val) then
            Diff := True;
        end
        else
          Diff := True;
      end
      else
        Diff := True;
    end;

    if Diff then
      FDiffOutCache.Add(string(OutKV.Key), True);
  end;
end;

procedure TfrmEditKVsGGUF.UpdateDiffABCache;
var
  i: Integer;
  AKey, BKey: TGGUFKeyValue;
  Diff: Boolean;
begin
  FDiffACache.Clear;
  FDiffBCache.Clear;
  if not Assigned(FModelA) then
    exit;
  if not Assigned(FModelB) then
    exit;

  for i := 0 to FModelA.KVs.Count - 1 do
  begin
    AKey := TGGUFKeyValue(FModelA.KVs[i]);
    Diff := False;
    // 1. Vérifier dans ModelA
    BKey := FModelB.FindKV(AKey.Key);
    if Assigned(BKey) then
    begin
      if not GGUFValuesEqual(BKey.Val, AKey.Val) then
        Diff := True;
    end
    else
      Diff := True;
    if Diff then
      FDiffACache.Add(string(AKey.Key), True);
  end;

  for i := 0 to FModelB.KVs.Count - 1 do
  begin
    BKey := TGGUFKeyValue(FModelB.KVs[i]);
    Diff := False;
    // 1. Vérifier dans ModelA
    AKey := FModelA.FindKV(BKey.Key);
    if Assigned(AKey) then
    begin
      if not GGUFValuesEqual(AKey.Val, BKey.Val) then
        Diff := True;
    end
    else
      Diff := True;

    if Diff then
      FDiffBCache.Add(string(BKey.Key), True);
  end;
end;

{ Dessin du fond de ligne (couleur de fond conditionnelle) }
procedure TfrmEditKVsGGUF.lvKVs1CustomDrawItem(Sender: TCustomListView; Item: TListItem; State: TCustomDrawState;
var DefaultDraw: Boolean);
begin
  if Item.Index mod 2 = 0 then
    Sender.Canvas.Brush.Color := $00F5F5F5
  else
    Sender.Canvas.Brush.Color := clWhite;
end;

procedure TfrmEditKVsGGUF.lvKVs1CustomDrawSubItem(Sender: TCustomListView; Item: TListItem; SubItem: Integer;
State: TCustomDrawState; var DefaultDraw: Boolean);
var
  KV: TGGUFKeyValue;
  IsDiff: Boolean;
begin
  if not Assigned(Item.Data) then
    exit;

  KV := TGGUFKeyValue(Item.Data);

  // Vérifier si la clé est dans notre cache de différences
  IsDiff := FDiffACache.ContainsKey(string(KV.Key));

  if IsDiff then
  begin
    // Option A : Colorer le fond de toute la ligne (plus visible)
    // Sender.Canvas.Brush.Color := $00FFF0F0; // Rouge très clair

    // Option B : colorer uniquement la colonne "Value" (plus élégant)
    if SubItem = 3 then
    begin
      Sender.Canvas.Brush.Color := $00FFF0F0;
      // On applique aussi la couleur du texte pour le contraste
      Sender.Canvas.Font.Color := clRed;
      Sender.Canvas.Font.Style := [fsBold];
    end
    else if Item.Index mod 2 = 0 then
      Sender.Canvas.Brush.Color := $00F5F5F5
    else
      Sender.Canvas.Brush.Color := clWhite;
  end
  else
  begin
    // Réinitialisation pour les lignes normales (alternance de gris/blanc)
    if Item.Index mod 2 = 0 then
      Sender.Canvas.Brush.Color := $00F5F5F5
    else
      Sender.Canvas.Brush.Color := clWhite;

    Sender.Canvas.Font.Color := clWindowText;
    Sender.Canvas.Font.Style := [];
  end;
end;

procedure TfrmEditKVsGGUF.lvKVs2CustomDrawSubItem(Sender: TCustomListView; Item: TListItem; SubItem: Integer;
State: TCustomDrawState; var DefaultDraw: Boolean);
var
  KV: TGGUFKeyValue;
  IsDiff: Boolean;
begin
  if not Assigned(Item.Data) then
    exit;

  KV := TGGUFKeyValue(Item.Data);

  // Vérifier si la clé est dans notre cache de différences
  IsDiff := FDiffBCache.ContainsKey(string(KV.Key));

  if IsDiff then
  begin
    Sender.Canvas.Font.Color := clWindowText;
    Sender.Canvas.Font.Style := [];

    if SubItem = 3 then
    begin
      Sender.Canvas.Brush.Color := $00FFF0F0;
      Sender.Canvas.Font.Color := clRed;
      Sender.Canvas.Font.Style := [fsBold];
    end
    else if Item.Index mod 2 = 0 then
      Sender.Canvas.Brush.Color := $00F5F5F5
    else
      Sender.Canvas.Brush.Color := clWhite;
  end
  else
  begin
    if Item.Index mod 2 = 0 then
      Sender.Canvas.Brush.Color := $00F5F5F5
    else
      Sender.Canvas.Brush.Color := clWhite;

    Sender.Canvas.Font.Color := clWindowText;
    Sender.Canvas.Font.Style := [];
  end;

end;

procedure TfrmEditKVsGGUF.lvKVsOutAdvancedCustomDrawSubItem(Sender: TCustomListView; Item: TListItem; SubItem: Integer;
State: TCustomDrawState; Stage: TCustomDrawStage; var DefaultDraw: Boolean);
var
  KV: TGGUFKeyValue;
  IsDiff: Boolean;
begin
  if not Assigned(Item.Data) then
    exit;
  KV := TGGUFKeyValue(Item.Data);
  IsDiff := FDiffOutCache.ContainsKey(string(KV.Key)) and FDiffOutCache[string(KV.Key)];

  // Appliquer le rouge
  if (SubItem = 3) and IsDiff then
  begin
    Sender.Canvas.Brush.Color := $00FFF0F0; // Rouge clair pour fond
    Sender.Canvas.Font.Color := clRed;
    Sender.Canvas.Font.Style := [fsBold];
  end
  else
  begin
    Sender.Canvas.Font.Color := clWindowText;
    Sender.Canvas.Font.Style := [];
    if Item.Index mod 2 = 0 then
      Sender.Canvas.Brush.Color := $00F5F5F5
    else
      Sender.Canvas.Brush.Color := clWhite;
  end;
end;

procedure TfrmEditKVsGGUF.lvKVsOutCustomDrawItem(Sender: TCustomListView; Item: TListItem; State: TCustomDrawState;
var DefaultDraw: Boolean);
var
  KV: TGGUFKeyValue;
  IsDiff: Boolean;
begin
  if not Assigned(Item.Data) then
    exit;
  KV := TGGUFKeyValue(Item.Data);
  IsDiff := FDiffOutCache.ContainsKey(string(KV.Key)) and FDiffOutCache[string(KV.Key)];

  if IsDiff then
    Sender.Canvas.Brush.Color := $00FFF0F0 // Rouge clair pour fond
  else
  begin
    if Item.Index mod 2 = 0 then
      Sender.Canvas.Brush.Color := $00F5F5F5
    else
      Sender.Canvas.Brush.Color := clWhite;
  end;
  // DefaultDraw := False;
  // Sender.Canvas.FillRect(Item.DisplayRect(drBounds));
end;

procedure TfrmEditKVsGGUF.btnAddClick(Sender: TObject);
var
  NewKey: AnsiString;
  NewVal: TGGUFValue;
  NewKV: TGGUFKeyValue;
  ExistingKV: TGGUFKeyValue;
  i: Integer;
  Overwrite: Boolean;
begin
  frmEditNewKV.cbKey.Text := '';
  if cbType.ItemIndex >= 0 then
    frmEditNewKV.cbType.ItemIndex := cbType.ItemIndex;

  frmEditNewKV.memoValue.Lines.Clear;

  // frmEditNewKV.SetKewValue(NewKey, NewVal);
  frmEditNewKV.Show;

end;

procedure TfrmEditKVsGGUF.AddNewKeyValue(NewKV: TGGUFKeyValue);
var
  ExistingKV: TGGUFKeyValue;
  i: Integer;
  Overwrite: Boolean;
begin
  ExistingKV := FModelOut.FindKV(NewKV.Key);
  if Assigned(ExistingKV) then
  begin
    // Overwrite := MessageDlg
    // (Format('La clé "%s" existe déjà dans le modèle de sortie avec la valeur "%s". Voulez-vous l''écraser ?',
    // [string(NewKV.Key), string(ExistingKV.Val.AsStrPrev)]), mtConfirmation, [mbYes, mbNo], 0) = mrYes;
    Overwrite := MessageDlg(mLang.gMsgFmt('FKV.ConflictOverwriteQuestion',
      [string(NewKV.Key), string(ExistingKV.Val.AsStrPrev)]), mtConfirmation, [mbYes, mbNo], 0) = mrYes;
    if not Overwrite then
    begin
      NewKV.Val.Free;
      // Log('Ajout annulé : clé en conflit non écrasée.');
      Log(mLang.gMsg('FKV.ConflictCancel'));
      exit;
    end
    else
    begin
      // FModelOut.KVs.Delete(i);
      FModelOut.KVs.Delete(FModelOut.KVs.IndexOf(ExistingKV));
      // Log('Ancienne clé supprimée pour écrasement, clé :' + string(NewKV.Key));
      Log(mLang.gMsg('FKV.ConflictOverwrite'));
    end;
  end;

  try
    NewKV.Keep := True;
    FModelOut.KVs.Add(NewKV);
    FDiffOutCacheDirty := True;
    RebuildList(lvKVsOut, FModelOut, edtFilterOut.Text);
    // Sélectionner automatiquement le nouvel élément ajouté
    for i := 0 to lvKVsOut.Items.Count - 1 do
    begin
      if SameText(lvKVsOut.Items[i].SubItems[0], string(NewKV.Key)) then
      begin
        lvKVsOut.Items[i].Selected := True;
        Break;
      end;
    end;
    // Log('Nouvelle clé ajoutée/mise à jour : ' + string(NewKV.Key));
    Log(mLang.gMsgFmt('FKV.AddUpdatedDone', [string(NewKV.Key)]));
  except
    on e: Exception do
    begin
      // MessageDlg('Erreur lors de l''ajout de la clé : ' + e.Message, mtError, [mbOK], 0);
      MessageDlg(mLang.gMsgFmt('FKV.AddError', [e.Message]), mtError, [mbOK], 0);
    end;
  end;
end;

procedure TfrmEditKVsGGUF.btnUncheckClick(Sender: TObject);
var
  It: TListItem;
  KV: TGGUFKeyValue;
  k: string;
begin

  It := lvKVsOut.Selected;
  if (It = nil) or (It.Data = nil) then
    exit;

  KV := TGGUFKeyValue(It.Data);
  KV.Keep := False;
  It.Checked := False;
  k := It.SubItems[0];
  // Log('KV "' + k + '" marked for removal.');
  Log(mLang.gMsgFmt('FKV.RemoveMarked', [k]));
end;

procedure TfrmEditKVsGGUF.btnClearFText1Click(Sender: TObject);
begin
  edtFilter1.Text := '';
end;

procedure TfrmEditKVsGGUF.btnClearFText2Click(Sender: TObject);
begin
  edtFilter2.Text := '';
end;

procedure TfrmEditKVsGGUF.btnClearFTextOClick(Sender: TObject);
begin
  edtFilterOut.Text := '';
end;

procedure TfrmEditKVsGGUF.btnEditStrArrayClick(Sender: TObject);
var
  Key: string;
  KV: TGGUFKeyValue;
begin
  Key := Trim(edtKey.Text);
  if Key = '' then
  begin
    // MessageDlg('Clé vide.', mtWarning, [mbOK], 0);
    MessageDlg(mLang.gMsg('FKV.KeyEmpty'), mtWarning, [mbOK], 0);
    exit;
  end;
  KV := FModelOut.FindKV(Key);
  if not Assigned(KV) then
  begin
    if Assigned(lvKVsOut.Selected) then
      KV := TGGUFKeyValue(lvKVsOut.Selected.Data)
    else
    begin
      // MessageDlg('Clé non trouvée.', mtWarning, [mbOK], 0);
      MessageDlg(mLang.gMsg('FKV.KeyNotFound'), mtWarning, [mbOK], 0);
      exit;
    end;
  end;
  if (KV.Val.ValueType <> gvt_STRING) and (KV.Val.ValueType <> gvt_ARRAY) then
  begin
    // MessageDlg('Type non éditable ici.', mtWarning, [mbOK], 0);
    MessageDlg(mLang.gMsg('FKV.TypeNotEditable'), mtWarning, [mbOK], 0);
    exit;
  end;
  if (KV.Val.ValueType = gvt_STRING) then
  begin
    if frmEditStringDlg.Execute(KV.Val, KV.Key) then
    begin
      FDiffOutCacheDirty := True;
      RebuildList(lvKVsOut, FModelOut, edtFilterOut.Text);
      UpdateOutEditors;
      // Log('KV "' + Key + '" mis à jour avec succès.');
      Log(mLang.gMsgFmt('FKV.KVUpdated', [Key]));
      FDiffOutCacheDirty := True;
    end;
  end
  else if (KV.Val.ValueType = gvt_ARRAY) then
  begin
    if frmEditArrayDlg.Execute(KV.Val, KV.Key) then
    begin
      FDiffOutCacheDirty := True;
      RebuildList(lvKVsOut, FModelOut, edtFilterOut.Text);
      UpdateOutEditors;
      // Log('KV "' + Key + '" mis à jour avec succès.');
      Log(mLang.gMsgFmt('FKV.KVUpdated', [Key]));
      FDiffOutCacheDirty := True;
    end;
  end;

end;

procedure TfrmEditKVsGGUF.btnExportKVsClick(Sender: TObject);
var
  SavePath: string;
begin
  if not Assigned(FModelOut) then
  begin
    // MessageDlg('Aucun modèle de sortie chargé.', mtWarning, [mbOK], 0);
    MessageDlg(mLang.gMsg('FKV.NoModelOut'), mtWarning, [mbOK], 0);
    exit;
  end;

  if not SaveDialog1.Execute then
    exit;
  SavePath := SaveDialog1.FileName;

  EnabledBtns(False);
  ProgressBar1.Position := 0;
  ProgressBar1.Visible := True;

  TThread.CreateAnonymousThread(
    procedure
    var
      TempMetaModel: TGGUFFile;
      i: Integer;
    begin
      TempMetaModel := TGGUFFile.Create;
      try
        try
          // Préparation d'un modèle minimal (Metadata Only)
          TempMetaModel.Version := FModelOut.Version;
          TempMetaModel.Alignment := FModelOut.Alignment;

          // On ne copie que les KVs marquées "Keep"
          for i := 0 to FModelOut.KVs.Count - 1 do
          begin
            if TGGUFKeyValue(FModelOut.KVs[i]).Keep then
              TempMetaModel.KVs.Add(TGGUFKeyValue(FModelOut.KVs[i]).Clone);
          end;

          // On force le nombre de tenseurs à 0 pour que le writer ne cherche pas de données
          TempMetaModel.TensorCount := 0;
          TempMetaModel.Tensors.Clear;

          // Appel du writer (MaxBytesPerPart = 0 pour un fichier unique)
          // On passe nil pour OnProgress car on est dans un thread dédié à l'export
          TGGUFWriter.SaveAs(TempMetaModel, SavePath, 0, True, True, nil, nil);

          TThread.Queue(nil,
            procedure
            begin
              // Log('Exportation des métadonnées réussie.');
              Log(mLang.gMsg('FKV.ExportSuccess'));
              // MessageDlg('Exportation réussie !', mtInformation, [mbOK], 0);
              MessageDlg(mLang.gMsg('FKV.ExportDoneMsg'), mtInformation, [mbOK], 0);
              ProgressBar1.Visible := False;
              EnabledBtns(True);
            end);
        except
          on e: Exception do
          begin
            TThread.Queue(nil,
              procedure
              begin
                // Log('Erreur export : ' + e.Message);
                Log(mLang.gMsgFmt('FKV.ExportError', [e.Message]));
                // MessageDlg('Erreur : ' + e.Message, mtError, [mbOK], 0);
                MessageDlg(mLang.gMsgFmt('FKV.UpsertError', [e.Message]), mtError, [mbOK], 0);
                ProgressBar1.Visible := False;
                EnabledBtns(True);
              end);
          end;
        end;
      finally
        TempMetaModel.Free;
      end;
    end).Start;
end;

procedure TfrmEditKVsGGUF.EnabledBtns(e: Boolean);
begin
  btnImportKVs.Enabled := e;
  btnExportKVs.Enabled := e;
  btnEditStrArray.Enabled := e;
  btnUncheck.Enabled := e;
  btnAdd.Enabled := e;
  btnUpsert.Enabled := e;
  lvKVsOut.Enabled := e;
end;

procedure TfrmEditKVsGGUF.btnImportKVsClick(Sender: TObject);
var
  ImportModel: TGGUFFile;
  TempKVs: TObjectList<TGGUFKeyValue>;
begin
  if not Assigned(FModelOut) then
  begin
    MessageDlg(mLang.gMsg('ModelNotLoaded'), mtWarning, [mbOK], 0);
    exit;
  end;

  if not OpenDialog1.Execute then
    exit;

  EnabledBtns(False);
  ProgressBar1.Position := 0;
  ProgressBar1.Visible := True;
  // Log(mLang.gMsg('LoadingHeader'));
  Log(mLang.gMsg('FKV.LoadingHeader'));

  TThread.CreateAnonymousThread(
    procedure
    var
      i: Integer;
      InKV, OutKV: TGGUFKeyValue;
    begin
      TempKVs := TObjectList<TGGUFKeyValue>.Create(True);
      try
        try
          ImportModel := TGGUFReader.LoadFromFile(OpenDialog1.FileName, nil);
          if Assigned(ImportModel) then
          begin
            for i := 0 to ImportModel.KVs.Count - 1 do
            begin
              // On clone pour la liste temporaire
              TempKVs.Add(TGGUFKeyValue(ImportModel.KVs[i]).Clone);
            end;
            ImportModel.Free;
          end;

          // Retour au thread principal pour la fusion et les Dialogs
          TThread.Synchronize(nil,
            procedure
            var
              OverwriteAll: Boolean;
              rMsg, i: Integer;
            begin
              OverwriteAll := False;
              try
                if TempKVs.Count = 0 then
                begin
                  // Log('Aucune KV trouvée dans le fichier.');
                  Log(mLang.gMsg('FKV.ImportNoKV'));
                  exit;
                end;

                for i := 0 to TempKVs.Count - 1 do
                begin
                  InKV := TempKVs[i];
                  OutKV := FModelOut.FindKV(InKV.Key);

                  if Assigned(OutKV) then
                  begin
                    // Gérer l'écrasement avec une seule demande si possible
                    if not OverwriteAll then
                    begin
                      // rMsg := MessageDlg(Format('La clé "%s" existe déjà. Écraser ?', [string(InKV.Key)]),
                      // mtConfirmation, [mbYes, mbYesToAll, mbNo], 0);
                      rMsg := MessageDlg(mLang.gMsgFmt('FKV.ImportConflictQuestion', [string(InKV.Key)]),
                        mtConfirmation, [mbYes, mbYesToAll, mbNo], 0);
                      if rMsg = mrNo then
                        Continue;
                      if rMsg = mrYesToAll then
                        OverwriteAll := True;
                    end;
                    // Écrasement
                    OutKV.Val.Free;
                    OutKV.Val := InKV.Val.Clone;
                    OutKV.Keep := True;
                  end
                  else
                  begin
                    // Ajout nouveau
                    FModelOut.KVs.Add(InKV.Clone);
                  end;
                end;
                // Log(Format('Importation terminée : %d clés traitées.', [TempKVs.Count]));
                Log(mLang.gMsgFmt('FKV.ImportDone', [TempKVs.Count]));
              except
                on e: Exception do
                  // MessageDlg('Erreur lors de la fusion : ' + e.Message, mtError, [mbOK], 0);
                  MessageDlg(mLang.gMsgFmt('FKV.ImportMergeError', [e.Message]), mtError, [mbOK], 0);
              end;
            end);

        except
          on e: Exception do
          begin
            TThread.Queue(nil,
              procedure
              begin
                // MessageDlg('Erreur lecture : ' + e.Message, mtError, [mbOK], 0);
                MessageDlg(mLang.gMsgFmt('FKV.ImportReadError', [e.Message]), mtError, [mbOK], 0);
              end);
          end;
        end;
      finally
        // Nettoyage
        TThread.Queue(nil,
          procedure
          begin
            TempKVs.Free;
            EnabledBtns(True);
            ProgressBar1.Visible := False;
            RebuildList(lvKVsOut, FModelOut, edtFilterOut.Text);
            UpdateOutEditors;
            // Log('Importation terminée.');
            Log(mLang.gMsg('FKV.ImportDoneFinal'));
          end);
      end;
    end).Start;
end;

end.
