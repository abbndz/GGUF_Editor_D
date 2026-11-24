unit uEditTensors;

interface

uses
  Windows, Messages, SysUtils, StrUtils, Classes, Controls, System.UITypes,
  Forms, Dialogs, StdCtrls, ComCtrls, ExtCtrls, Graphics, Contnrs,
  Generics.Collections, SyncObjs, ShellAPI, VCLTee.TeCanvas, Vcl.ClipBrd,
  Vcl.Menus, System.Actions, Vcl.ActnList, System.Types, uSaveProgress, uMath,
  uAppConfig, uSafeTensors, uTensorTranspose, uStrUtils, uTensorsNamesMan,
  uGGMLConstants, uGGUFModel, uGGUFReader, uGGUFWriter, uGgmlQuants, uGGMLTypes,
  uLangManager, uLog;

type
  TfrmEditTensors = class(TForm)
    pnlTopInp0: TPanel;
    PanBotSize: TPanel;
    PanBotEdit1: TPanel;
    PanBotEdit2: TPanel;
    PanBotEdit3: TPanel;
    PanBotEditOut: TPanel;
    pnlTopInp1: TPanel;
    pnlTopInp2: TPanel;
    pnlTopInp3: TPanel;
    pnlTopInpS: TPanel;
    PanBotEditS: TPanel;
    pnlTopOut: TPanel;
    OpenDialog1: TOpenDialog;
    SaveDialog1: TSaveDialog;
    PageControl1: TPageControl;
    TabSheetModInA: TTabSheet;
    TabSheetModInB: TTabSheet;
    TabSheetModInC: TTabSheet;
    TabSheetModInS: TTabSheet;
    TabSheetModOut: TTabSheet;
    stBar1: TStatusBar;
    lvTensors1: TListView;
    lvTensors2: TListView;
    lvTensors3: TListView;
    lvTensorsS: TListView;
    lvTensorsOut: TListView;
    ProgressBar1: TProgressBar;
    ProgressBar2: TProgressBar;
    edtName1: TEdit;
    edtName2: TEdit;
    edtName3: TEdit;

    btnLoad1: TButton;
    btnLoad2: TButton;
    btnLoad3: TButton;
    btnLoadS: TButton;
    btnBrowseSrc1: TButton;
    btnBrowseSrc2: TButton;
    btnBrowseSrc3: TButton;
    btnBrowseSrcS: TButton;
    btnBrowseOut: TButton;
    btnSave: TButton;
    lblSrc1: TLabel;
    lblSrc2: TLabel;
    lblSrc3: TLabel;
    lblSrcS: TLabel;
    lblOut: TLabel;
    edtSrc1: TEdit;
    edtSrc2: TEdit;
    edtSrc3: TEdit;
    edtSrcS: TEdit;
    edtNameS: TEdit;
    edtOut: TEdit;
    cbDType1: TComboBox;
    cbDType2: TComboBox;
    cbDType3: TComboBox;
    cbDTypeOut: TComboBox;
    chkAllLayers1: TCheckBox;
    chkAllLayers2: TCheckBox;
    chkAllLayers3: TCheckBox;
    chkAllLayersS: TCheckBox;
    chkAllLayersOut: TCheckBox;
    cbSrcModelOut1: TComboBox;

    cbLayersFrom1: TComboBox;
    cbLayersFrom2: TComboBox;
    cbLayersFrom3: TComboBox;
    cbLayersTo1: TComboBox;
    cbLayersTo2: TComboBox;
    cbLayersTo3: TComboBox;
    cbLayersMod1: TComboBox;
    cbLayersMod2: TComboBox;
    cbLayersMod3: TComboBox;

    cbLayersModOut: TComboBox;
    cbLayersToOut: TComboBox;
    cbLayersFromOut: TComboBox;
    cbDTypeS: TComboBox;

    cbLayersModS: TComboBox;
    cbLayersToS: TComboBox;
    cbLayersFromS: TComboBox;

    btnTranspose: TButton;
    btnClearTransposition: TButton;

    btnTransferAll1: TButton;
    btnTransferAll2: TButton;
    btnTransferAll3: TButton;
    btnTransferAllS: TButton;
    btnTransferToOut1: TButton;
    btnTransferToOut2: TButton;
    btnTransferToOut3: TButton;
    btnTransferToOutS: TButton;

    btnViewTensor: TButton;
    btnViewMetaData: TButton;
    btnShowSetting: TButton;
    btnShowLogs: TButton;
    btnCancel: TButton;
    ActionList1: TActionList;
    ActBrowseSrcA1: TAction;
    ActBrowseSrcB2: TAction;
    ActBrowseSrcC3: TAction;
    ActViewKVs: TAction;
    ActSettings: TAction;
    ActSaveOut: TAction;
    ActViewTensors: TAction;
    ActBrowseSrcS: TAction;
    MainMenu1: TMainMenu;
    mnuFile: TMenuItem;
    mnuModelA: TMenuItem;
    mnuModelB: TMenuItem;
    mnuModelS: TMenuItem;
    mnuSep1: TMenuItem;
    mnuModelOut: TMenuItem;
    mnuSep2: TMenuItem;
    mnuExit: TMenuItem;
    mnuView: TMenuItem;
    mnuKVs: TMenuItem;
    mnuTensorVisu: TMenuItem;
    mnuTools: TMenuItem;
    mnuSettings: TMenuItem;
    ActSplitMerge: TAction;
    ActShowLogs: TAction;
    ActAbout: TAction;
    ActHelp: TAction;
    mnuSep4: TMenuItem;
    mnuSplitMerge: TMenuItem;
    mnuSep3: TMenuItem;
    mnuLogs: TMenuItem;
    mnuHelpDoc: TMenuItem;
    mnuDocs: TMenuItem;
    mnuSep5: TMenuItem;
    mnuAbout: TMenuItem;
    mmParcourir1: TMenuItem;
    ActLoadSrcA1: TAction;
    ActLoadSrcB2: TAction;
    ActLoadSrcC3: TAction;
    ActLoadSrcS: TAction;
    ActBrowseOut: TAction;
    mmCharger1: TMenuItem;
    mmParcourir2: TMenuItem;
    mmCharger2: TMenuItem;
    mmParcourirS: TMenuItem;
    mmChargerS: TMenuItem;
    mmParcourirO: TMenuItem;
    mmSaveO: TMenuItem;
    MmLangue1: TMenuItem;

    cbMappedNames1: TComboBox;
    cbMappedNames2: TComboBox;
    cbMappedNames3: TComboBox;
    cbMappedNamesS: TComboBox;
    chkUseIgnoredPrefixes1: TCheckBox;
    chkUseIgnoredPrefixes2: TCheckBox;
    chkUseIgnoredPrefixes3: TCheckBox;
    chkUseIgnoredPrefixesS: TCheckBox;
    btnClearFText1: TButton;
    btnClearFText2: TButton;
    btnClearFText3: TButton;
    btnClearFTextS: TButton;
    btnClearFTextO: TButton;
    lbFilter1: TLabel;
    lbFilter2: TLabel;
    lbFilter3: TLabel;
    lbFilterS: TLabel;
    lbFilterOut: TLabel;
    edtFilter1: TEdit;
    edtFilter2: TEdit;
    edtFilter3: TEdit;
    edtFilterS: TEdit;
    edtFilterO: TEdit;
    btnShowMappedNames1: TButton;
    btnShowMappedNames2: TButton;
    btnShowMappedNames3: TButton;
    btnShowMappedNamesS: TButton;

    pmOutTensor: TPopupMenu;
    mnuSourceOut: TMenuItem;
    mnuQuant: TMenuItem;
    pmInputTensor: TPopupMenu;
    miTransferSelected: TMenuItem;
    miTransferAll: TMenuItem;
    mnuSourceOutM1: TMenuItem;
    mnuSourceOutM2: TMenuItem;
    mnuSourceOutM3: TMenuItem;
    mnuSourceOutMS: TMenuItem;
    edtNameOut: TEdit;
    cbUseImpl: TComboBox;
    cbRmseType: TComboBox;
    N1: TMenuItem;
    mnuShowToolbar: TMenuItem;
    mnuModelC: TMenuItem;
    mmParcourir3: TMenuItem;
    mmCharger3: TMenuItem;

    procedure FormCreate(Sender: TObject);
    procedure lvTensorSelectItem(Sender: TObject; Item: TListItem; Selected: Boolean);
    procedure cbSrcModelOut1Change(Sender: TObject);
    procedure btnTransferToOut1Click(Sender: TObject);
    procedure PageControl1Change(Sender: TObject);
    procedure btnTransferToOut2Click(Sender: TObject);
    procedure lvTensorsOutItemChecked(Sender: TObject; Item: TListItem);
    procedure edtFilter1Change(Sender: TObject);
    procedure edtFilter2Change(Sender: TObject);
    procedure edtFilterOChange(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure lvTensorsOutAdvancedCustomDrawSubItem(Sender: TCustomListView; Item: TListItem; SubItem: Integer; State: TCustomDrawState; Stage: TCustomDrawStage; var DefaultDraw: Boolean);
    procedure chkAllLayers2Click(Sender: TObject);
    procedure chkAllLayersOutClick(Sender: TObject);
    procedure chkAllLayers1Click(Sender: TObject);
    procedure btnClearFTextOClick(Sender: TObject);
    procedure btnTransferToOutSClick(Sender: TObject);
    procedure edtFilterSChange(Sender: TObject);
    procedure chkAllLayersSClick(Sender: TObject);
    procedure btnClearFTextSClick(Sender: TObject);
    procedure chkUseIgnoredPrefixesSClick(Sender: TObject);
    procedure btnTransposeClick(Sender: TObject);
    procedure btnClearTranspositionClick(Sender: TObject);
    procedure lvTensorsSCustomDrawSubItem(Sender: TCustomListView; Item: TListItem; SubItem: Integer; State: TCustomDrawState; var DefaultDraw: Boolean);
    procedure btnClearFText2Click(Sender: TObject);
    procedure btnClearFText1Click(Sender: TObject);
    procedure btnShowMappedNamesSClick(Sender: TObject);
    procedure chkUseIgnoredPrefixes2Click(Sender: TObject);
    procedure btnShowMappedNames2Click(Sender: TObject);
    procedure btnShowMappedNames1Click(Sender: TObject);
    procedure chkUseIgnoredPrefixes1Click(Sender: TObject);
    procedure btnTransferAll1Click(Sender: TObject);
    procedure btnTransferAll2Click(Sender: TObject);
    procedure btnCancelClick(Sender: TObject);
    procedure ActViewTensorsExecute(Sender: TObject);
    procedure ActViewKVsExecute(Sender: TObject);
    procedure ActSettingsExecute(Sender: TObject);
    procedure ActShowLogsExecute(Sender: TObject);
    procedure ActSplitMergeExecute(Sender: TObject);
    procedure ActAboutExecute(Sender: TObject);
    procedure ActHelpExecute(Sender: TObject);
    procedure mnuExitClick(Sender: TObject);
    procedure ActBrowseSrcA1Execute(Sender: TObject);
    procedure ActBrowseSrcB2Execute(Sender: TObject);
    procedure ActBrowseSrcSExecute(Sender: TObject);
    procedure ActLoadSrcA1Execute(Sender: TObject);
    procedure ActLoadSrcB2Execute(Sender: TObject);
    procedure ActLoadSrcSExecute(Sender: TObject);
    procedure ActBrowseOutExecute(Sender: TObject);
    procedure ActSaveOutExecute(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure lvTensorsSData(Sender: TObject; Item: TListItem);
    procedure btnTransferAllSClick(Sender: TObject);
    procedure miTransferSelectedClick(Sender: TObject);
    procedure miTransferAllClick(Sender: TObject);
    procedure mnuSourceOutClick(Sender: TObject);
    procedure MenuQuantClick(Sender: TObject);
    procedure lvTensors1AdvancedCustomDrawSubItem(Sender: TCustomListView; Item: TListItem; SubItem: Integer; State: TCustomDrawState; Stage: TCustomDrawStage; var DefaultDraw: Boolean);
    procedure lvTensors1AdvancedCustomDrawItem(Sender: TCustomListView; Item: TListItem; State: TCustomDrawState; Stage: TCustomDrawStage; var DefaultDraw: Boolean);
    procedure HandleColumnClick(Sender: TObject; Column: TListColumn; RebuildProc: TProc);
    procedure lvTensors1ColumnClick(Sender: TObject; Column: TListColumn);
    procedure lvTensors2ColumnClick(Sender: TObject; Column: TListColumn);
    procedure lvTensorsOutColumnClick(Sender: TObject; Column: TListColumn);
    procedure lvTensorsSColumnClick(Sender: TObject; Column: TListColumn);
    procedure cbUseImplClick(Sender: TObject);
    procedure cbRmseTypeClick(Sender: TObject);
    procedure mnuShowToolbarClick(Sender: TObject);
    procedure ActBrowseSrcC3Execute(Sender: TObject);
    procedure ActLoadSrcC3Execute(Sender: TObject);
    procedure lvTensors3ColumnClick(Sender: TObject; Column: TListColumn);
    procedure lvTensors2AdvancedCustomDrawSubItem(Sender: TCustomListView; Item: TListItem; SubItem: Integer; State: TCustomDrawState; Stage: TCustomDrawStage; var DefaultDraw: Boolean);
    procedure lvTensors3AdvancedCustomDrawSubItem(Sender: TCustomListView; Item: TListItem; SubItem: Integer; State: TCustomDrawState; Stage: TCustomDrawStage; var DefaultDraw: Boolean);
    procedure edtFilter3Change(Sender: TObject);
    procedure btnClearFText3Click(Sender: TObject);
    procedure chkAllLayers3Click(Sender: TObject);
    procedure chkUseIgnoredPrefixes3Click(Sender: TObject);
    procedure btnTransferToOut3Click(Sender: TObject);
    procedure btnTransferAll3Click(Sender: TObject);
    procedure btnShowMappedNames3Click(Sender: TObject);
    procedure cbDTypeOutClick(Sender: TObject);
    procedure cbMappedNames1Click(Sender: TObject);
    procedure cbMappedNames2Click(Sender: TObject);
    procedure cbMappedNames3Click(Sender: TObject);
    procedure cbMappedNamesSClick(Sender: TObject);
    procedure FormResize(Sender: TObject);

  private
    procedure WMDropFiles(var Msg: TWMDropFiles); message WM_DROPFILES;

  public
    FModelInp1: TGGUFFile;
    FModelInp2: TGGUFFile;
    FModelInp3: TGGUFFile;
    FModelInpS: TGGUFFile;
    FModelOut: TGGUFFile;
    // preserve checkbox state even when filtering
    FViewTensors1: TObjectList;
    FViewTensors2: TObjectList;
    FViewTensors3: TObjectList;
    FViewTensorsS: TObjectList;
    FViewTensorsOut: TObjectList;
    FUpdatingOutList: Boolean; // Garde-fou pour éviter les boucles récursives
    FDiffShapeAvsB: TDictionary<string, Boolean>; // True si Shape différent
    FDiffQuantAvsB: TDictionary<string, Boolean>; // True si DType différent
    FAbsentAvsB: TDictionary<string, Boolean>; // True si absent de A vs B  ou B vs A

    // Diff A<->C (affichee dans lvTensors3)
    FDiffShapeAvsC: TDictionary<string, Boolean>;
    FDiffQuantAvsC: TDictionary<string, Boolean>;
    FAbsentAvsC: TDictionary<string, Boolean>;

    FCurrentSourceList: TListView; // Pointe vers lvTensors1 ou lvTensors2
    FCurrentETName: TEdit;
    FCurrentcbDType: TComboBox;

    // Cache pour éviter de recalculer la taille totale à chaque ligne
    FGlobalSize1: Int64;
    FGlobalSize2: Int64;
    FGlobalSize3: Int64;
    FGlobalSizeS: Int64;
    FGlobalSizeOut: Int64;

    FSortColumn: Integer; // Index de la colonne triée (0 à 10)
    FSortDirection: Boolean; // True = Croissant, False = Décroissant
    FOriginalColumnCaptions: array of string;

    // Gestion d'annulation, progression & métriques
    FCancelSave: Boolean;
    FCancelMutex: TCriticalSection;
    FLastUIProgressUpdateTick: Int64;

    // ===== Sauvegarde : machine à phases =====
    FSaveRunning: Boolean;
    FSaveStartedTick: UInt64; // début de la sauvegarde (temps global)

    // Champs UI (lus/écrits uniquement par la VCL thread)
    FLogLastLine: string; // anti-doublon de lignes de log

    // état du thread writer (lu/écrit uniquement par lui)
    FSaveCtx: TSaveCtx;
    FLastSaveUIUpdateTick: Int64;

    function IsCancelled: Boolean;
    procedure SetCancelled(B: Boolean);
    procedure SetModelsToFrmViewAndFrmEditKVs();

    procedure ResetSaveCtx;
    procedure EndSave;
    function BeginSave: Boolean;

    // Gestionnaire du message de dépôt de fichier
    procedure OnProgressEventLoad(const Msg: string; AIdx, ATotal: Int64; Level: TLogLevel = lvTrace);
    procedure OnProgressEventSave(const Info: TProgressInfo);

    procedure DrawTensorDiff(Sender: TCustomListView; Item: TListItem; SubItem: Integer; State: TCustomDrawState; DiffShape, DiffQuant, Absent: TDictionary<string, Boolean>);

    procedure MenuLangueItemClick(Sender: TObject);

    destructor Destroy; override;

    procedure ApplyOutSelPreset(T: TGGUFTensorInfo; NewType, UseImpl, RmseType: Integer);
    function QP_ProfileRmse(AType, UseImpl, ACur: Integer): Integer;
    procedure SetUiFromCfg(var c: TGlobalConfig);
    procedure SetCfgFromUi(var c: TGlobalConfig);

  end;

function SourceIdToOutComboIdx(Id: Integer): Integer;

function OutComboIdxToSourceId(Idx: Integer): Integer;

procedure eLogMsg(const S: string; AIdx: Int64 = -1; ATotal: Int64 = -1; Level: TLogLevel = lvInfo);

var
  frmEditTensors: TfrmEditTensors;

implementation

uses
  uEditTensorsMan, uEditTensorsIO, uEditTensorsView,uQuantPresetConfig, uViewTensors, uEditKVsGGUF,
  uSplitMerge, uMappedNamesManager, uAppSetting, uEditArrayDlg, uFrmAbout;

{$R *.dfm}

function SourceIdToOutComboIdx(Id: Integer): Integer;
var
  i: Integer;
begin
  Result := -1;
  for i := Low(CSourceIds) to High(CSourceIds) do
    if CSourceIds[i] = Id then
      Exit(i);
end;

function OutComboIdxToSourceId(Idx: Integer): Integer;
begin
  if (Idx < Low(CSourceIds)) or (Idx > High(CSourceIds)) then
    Result := SRC_MODEL1
  else
    Result := CSourceIds[Idx];
end;

procedure eLogMsg(const S: string; AIdx: Int64 = -1; ATotal: Int64 = -1; Level: TLogLevel = lvInfo);
begin
  if (Level >= cfg.LogLevel) then
    TThread.Queue(nil,
      procedure
      begin
        if Assigned(frmEditTensors) then
        begin
          frmEditTensors.stBar1.Panels[0].Text := S;
          if (ATotal > -1) then
          begin
            frmEditTensors.ProgressBar1.Max := ATotal;
            frmEditTensors.ProgressBar1.Position := AIdx;
          end;
        end;
      end);
    // Logging fichier/debug
  if Assigned(frmLogs) then
    LogMsg('[EDIT]  ' + S, level)
  else
    OutputDebugString(PChar('[EDIT]  ' + S));
end;

procedure TfrmEditTensors.WMDropFiles(var Msg: TWMDropFiles);
var
  FileCount: Integer;
  FileName: array[0..MAX_PATH] of Char;
begin
  // Obtenir le nombre de fichiers déposés
  FileCount := DragQueryFile(Msg.Drop, $FFFFFFFF, nil, 0);
  if FileCount = 1 then
  begin
    DragQueryFile(Msg.Drop, 0, FileName, MAX_PATH);
    if TabSheetModOut = PageControl1.ActivePage then
    begin
      if ActLoadSrcA1.Enabled then
        frmEditTensorsActLoadSrcA1Execute(FileName);
    end
    else if TabSheetModInA = PageControl1.ActivePage then
    begin
      if ActLoadSrcA1.Enabled then
        frmEditTensorsActLoadSrcA1Execute(FileName);
    end
    else if TabSheetModInB = PageControl1.ActivePage then
    begin
      if ActLoadSrcB2.Enabled then
        frmEditTensorsActLoadSrcB2Execute(FileName);
    end
    else if TabSheetModInC = PageControl1.ActivePage then
    begin
      if ActLoadSrcC3.Enabled then
        frmEditTensorsActLoadSrcC3Execute(FileName);
    end
    else if TabSheetModInS = PageControl1.ActivePage then
    begin
      if ActLoadSrcS.Enabled then
        frmEditTensorsActLoadSrcSExecute(FileName);
    end;
  end;
  DragFinish(Msg.Drop);
end;

procedure TfrmEditTensors.miTransferAllClick(Sender: TObject);
begin
  if FCurrentSourceList = lvTensors1 then
    btnTransferAll1Click(btnTransferAll1)
  else if FCurrentSourceList = lvTensors2 then
    btnTransferAll2Click(btnTransferAll2)
  else if FCurrentSourceList = lvTensors3 then
    btnTransferAll3Click(btnTransferAll3)
  else if FCurrentSourceList = lvTensorsS then
    btnTransferAllSClick(btnTransferAllS);
end;

procedure TfrmEditTensors.miTransferSelectedClick(Sender: TObject);
begin
  if FCurrentSourceList = lvTensors1 then
    btnTransferToOut1Click(btnTransferToOut1)
  else if FCurrentSourceList = lvTensors2 then
    btnTransferToOut2Click(btnTransferToOut2)
  else if FCurrentSourceList = lvTensors3 then
    btnTransferToOut3Click(btnTransferToOut3)
  else if FCurrentSourceList = lvTensorsS then
    btnTransferToOutSClick(btnTransferToOutS);
end;

procedure TfrmEditTensors.mnuExitClick(Sender: TObject);
begin
  Close;
end;

procedure TfrmEditTensors.mnuShowToolbarClick(Sender: TObject);
begin
  mnuShowToolbar.Checked := not mnuShowToolbar.Checked;
  pnlTopInp0.Visible := mnuShowToolbar.Checked;
end;

procedure TfrmEditTensors.mnuSourceOutClick(Sender: TObject);
var
  Idx: Integer;
begin
  Idx := TMenuItem(Sender).Tag;
  // On simule le changement de combo
  cbSrcModelOut1.ItemIndex := Idx;
  cbSrcModelOut1Change(cbSrcModelOut1);
end;

procedure TfrmEditTensors.MenuQuantClick(Sender: TObject);
var
  Idx: Integer;
begin
  Idx := TMenuItem(Sender).Tag;
  cbDTypeOut.ItemIndex := Idx;
  cbDTypeOutClick(cbDTypeOut);
end;

procedure TfrmEditTensors.MenuLangueItemClick(Sender: TObject);
var
  SItem: TMenuItem;
  sCaption: string;
  ISOCode: string;
  i: Integer;
begin
  if Sender is TMenuItem then
  begin
    SItem := TMenuItem(Sender);
    // Met à jour les coches : décoche tout, coche l'élément cliqué
    //for i := 0 to MmLangue1.Items.Count - 1 do
    // MmLangue11.Items.Count => [dcc64 Erreur] uEditTensors.pas(593): E2029 '[' attendu(e) mais '.' trouvé(e)
    for i := 0 to mLang.GetLangCount - 1 do
    begin
      MmLangue1.Items[i].Checked := (MmLangue1.Items[i] = SItem);
    end;
    // Applique la traduction
    sCaption := SItem.Caption;
    if Pos('&', sCaption) > 0 then
      sCaption := StringReplace(sCaption, '&', '', [rfReplaceAll]);
    ISOCode := mLang.GetISOCodeByNativeLanguageName(sCaption);
    TranslateForms(ISOCode);
  end;
end;

procedure TfrmEditTensors.edtFilter1Change(Sender: TObject);
begin
  frmEditTensorsRebuildView1;
end;

procedure TfrmEditTensors.edtFilter2Change(Sender: TObject);
begin
  frmEditTensorsRebuildView2;
end;

procedure TfrmEditTensors.edtFilter3Change(Sender: TObject);
begin
  frmEditTensorsRebuildView3;
end;

procedure TfrmEditTensors.edtFilterOChange(Sender: TObject);
begin
  frmEditTensorsRebuildViewOut;
end;

procedure TfrmEditTensors.edtFilterSChange(Sender: TObject);
begin
  frmEditTensorsRebuildViewS;
  lvTensorsS.Invalidate; // Force le rafraîchissement visuel
end;

procedure TfrmEditTensors.SetUiFromCfg(var c: TGlobalConfig);
begin
  edtSrc1.Text := c.edtSrc1;
  edtSrc2.Text := c.edtSrc2;
  edtSrc3.Text := c.edtSrc3;
  edtSrcS.Text := c.edtSrcS;
  edtOut.Text := c.edtOut;

  edtFilter1.Text := c.edtFilter1;
  edtFilter2.Text := c.edtFilter2;
  edtFilter3.Text := c.edtFilter3;
  edtFilterS.Text := c.edtFilterS;
  edtFilterO.Text := c.edtFilterO;

  chkUseIgnoredPrefixes1.Checked := c.UseIgnoredPrefixes1;
  chkUseIgnoredPrefixes2.Checked := c.UseIgnoredPrefixes2;
  chkUseIgnoredPrefixes3.Checked := c.UseIgnoredPrefixes3;
  chkUseIgnoredPrefixesS.Checked := c.UseIgnoredPrefixesS;

  cbMappedNames1.Text := c.MappingFile1;
  cbMappedNames2.Text := c.MappingFile2;
  cbMappedNames3.Text := c.MappingFile3;
  cbMappedNamesS.Text := c.MappingFileS;
  mnuShowToolbar.Checked := c.ShowToolbar;
  pnlTopInp0.Visible := c.ShowToolbar;

  TCombo_SetSel(cbUseImpl, c.UseImpl);
  TCombo_SetSel(cbRmseType, c.RmseType);
end;

procedure TfrmEditTensors.SetCfgFromUi(var c: TGlobalConfig);
begin
  c.edtSrc1 := edtSrc1.Text;
  c.edtSrc2 := edtSrc2.Text;
  c.edtSrc3 := edtSrc3.Text;
  c.edtSrcS := edtSrcS.Text;
  c.edtOut := edtOut.Text;

  c.edtFilter1 := edtFilter1.Text;
  c.edtFilter2 := edtFilter2.Text;
  c.edtFilter3 := edtFilter3.Text;
  c.edtFilterS := edtFilterS.Text;
  c.edtFilterO := edtFilterO.Text;

  c.UseIgnoredPrefixes1 := chkUseIgnoredPrefixes1.Checked;
  c.UseIgnoredPrefixes2 := chkUseIgnoredPrefixes2.Checked;
  c.UseIgnoredPrefixes3 := chkUseIgnoredPrefixes3.Checked;
  c.UseIgnoredPrefixesS := chkUseIgnoredPrefixesS.Checked;

  c.MappingFile1 := cbMappedNames1.Text;
  c.MappingFile2 := cbMappedNames2.Text;
  c.MappingFile3 := cbMappedNames3.Text;
  c.MappingFileS := cbMappedNamesS.Text;
  c.ShowToolbar := mnuShowToolbar.Checked;
end;

procedure TfrmEditTensors.FormClose(Sender: TObject; var Action: TCloseAction);
var t0 : Int64;
begin
  if FSaveRunning then
  begin
    Action := caNone;
    MessageDlg(mLang.gMsg('FTE.SavingInProgress'), mtWarning, [mbOK], 0);
    Exit;
  end;
  FfrmEditTensorsFormClose := True;
  // Sauvegarde de la position/taille avant fermeture
  cfg.FrmEditTensors_Left := Left;
  cfg.FrmEditTensors_Top := Top;
  cfg.FrmEditTensors_Width := Width;
  cfg.FrmEditTensors_Height := Height;

  if FrmEditKVsGGUF.Showing then
  begin
    cfg.FrmEditKVsGGUF_Left := FrmEditKVsGGUF.Left;
    cfg.FrmEditKVsGGUF_Top := FrmEditKVsGGUF.Top;
    cfg.FrmEditKVsGGUF_Width := FrmEditKVsGGUF.Width;
    cfg.FrmEditKVsGGUF_Height := FrmEditKVsGGUF.Height;
  end;
  if frmViewTensors.Showing then
  begin
    cfg.FrmViewTensors_Left := frmViewTensors.Left;
    cfg.FrmViewTensors_Top := frmViewTensors.Top;
    cfg.FrmViewTensors_Width := frmViewTensors.Width;
    cfg.FrmViewTensors_Height := frmViewTensors.Height;
  end;
  if frmLogs.Showing then
  begin
    cfg.Frmlogs_Left := frmLogs.Left;
    cfg.Frmlogs_Top := frmLogs.Top;
    cfg.Frmlogs_Width := frmLogs.Width;
    cfg.Frmlogs_Height := frmLogs.Height;
  end;
  SetCfgFromUi(cfg);
  cfgSaveSettings(cfg);
  cfg.ggmlReg.SavePresetsToIni;
  CloseLogFile;
  t0 := GetTickCount64;
  while FIsInIQxxInit and (GetTickCount64 - t0 < 15000) do
  begin
    CheckSynchronize;   // draine ChartApplyJob / HistoApplyJob
    Sleep(10);
  end;
end;

procedure TfrmEditTensors.FormCreate(Sender: TObject);
var
  CommandLineArg: string;
  i: Integer;
begin
  mLang := TLangManager.Create();
  FModelInp1 := nil;
  FModelInp2 := nil;
  FModelInp3 := nil;
  FModelOut := TGGUFFile.Create;

  FViewTensors1 := TObjectList.Create(false);
  FViewTensors2 := TObjectList.Create(false);
  FViewTensors3 := TObjectList.Create(false);
  FViewTensorsS := TObjectList.Create(false);
  FViewTensorsOut := TObjectList.Create(false);

  // Configuration ListView 1
  // lvTensors1.ViewStyle := vsReport;
  // lvTensors1.Checkboxes := False;
  // lvTensors1.RowSelect := True;
  lvTensors1.OnSelectItem := lvTensorSelectItem;
  // lvTensors1.Columns.Clear;

  SetLength(FOriginalColumnCaptions, lvTensors1.Columns.Count);
  for i := 0 to lvTensors1.Columns.Count - 1 do
    FOriginalColumnCaptions[i] := lvTensors1.Columns[i].Caption;

  // Configuration ListView 2 (Héritage)
  // lvTensors2.ViewStyle := vsReport;
  // lvTensors2.Checkboxes := False;
  // lvTensors2.RowSelect := True;
  // lvTensors2.ReadOnly := True;
  lvTensors2.OnSelectItem := lvTensorSelectItem;
  lvTensors3.OnSelectItem := lvTensorSelectItem;
  // lvTensors2.Columns.Assign(lvTensors1.Columns); // Reprend les mêmes colonnes

  // lvTensorsS.ViewStyle := vsReport;
  // lvTensorsS.Checkboxes := False;
  // lvTensorsS.RowSelect := True;
  // lvTensorsS.ReadOnly := False;
  lvTensorsS.OnSelectItem := lvTensorSelectItem;
  // lvTensorsS.Columns.Assign(lvTensors1.Columns);
  // lvTensorsS.VirtualMode := True;
  // lvTensorsS.DoubleBuffered := True; // Élimine le flickering
  lvTensorsS.OnData := lvTensorsSData;

  // Configuration ListView Out
  // lvTensorsOut.ViewStyle := vsReport;
  // lvTensorsOut.Checkboxes := True;
  // lvTensorsOut.RowSelect := True;
  // lvTensorsOut.ReadOnly := True;
  lvTensorsOut.OnSelectItem := lvTensorSelectItem;
  // lvTensorsOut.Columns.Assign(lvTensors1.Columns);

  FSortColumn := 0; // Tri par défaut par nom (colonne 0)
  FSortDirection := True; // Tri croissant par défaut

  FUpdatingOutList := false;


  frmEditTensorsFillDTypes;
  edtName1.ReadOnly := True;
  edtName2.ReadOnly := True;
  edtName3.ReadOnly := True;
  edtNameOut.ReadOnly := True;

  FCurrentSourceList := lvTensors1;
  FCurrentETName := edtName1;
  FCurrentcbDType := cbDType1;

  cbSrcModelOut1.ItemIndex := 0;
  // edtSizeIn1.Text
   stBar1.Panels[SB_M1].Text := '0 B';
   stBar1.Panels[SB_M2].Text := '0 B';
   stBar1.Panels[SB_M3].Text := '0 B';
   stBar1.Panels[SB_MS].Text := '0 B';
   stBar1.Panels[SB_MO].Text := '0 B';

  cbMappedNames1.Items.Assign(GetAvailableMappedNames);
  cbMappedNames2.Items.Assign(cbMappedNames1.Items);
  cbMappedNames3.Items.Assign(cbMappedNames1.Items);
  cbMappedNamesS.Items.Assign(cbMappedNames1.Items);

  cbMappedNames1.Text := 'NoMappedNames';
  cbMappedNames2.Text := 'NoMappedNames';
  cbMappedNames3.Text := 'NoMappedNames';
  cbMappedNamesS.Text := 'NoMappedNames';

  FLastUIProgressUpdateTick := 0;

  FfrmEditTensorsFormClose := False;
  FCancelSave := false;
  FCancelMutex := TCriticalSection.Create;
  FSaveRunning := false;
  FSaveStartedTick := 0;
  //
  FLogLastLine := '';
  ///

  //cfgLoadSettings(cfg); // charge LogToFile / LogToMemo
  InitLogFile; // ouvre le fichier ET verse les lignes de boot dedans
  SetUiFromCfg(cfg);
  UpdateMenusLangs;

  // Application de la position/taille sauvegardée
  ValidateFormBounds(cfg.FrmEditTensors_Left, cfg.FrmEditTensors_Top, cfg.FrmEditTensors_Width, cfg.FrmEditTensors_Height);

  Left := cfg.FrmEditTensors_Left;
  Top := cfg.FrmEditTensors_Top;
  Width := cfg.FrmEditTensors_Width;
  Height := cfg.FrmEditTensors_Height;
  // WindowState := wsNormal; // Évite les conflits avec wsMaximized/wsMinimized

  FDiffShapeAvsB := TDictionary<string, Boolean>.Create;
  FDiffQuantAvsB := TDictionary<string, Boolean>.Create;
  FAbsentAvsB := TDictionary<string, Boolean>.Create;

  FDiffShapeAvsC := TDictionary<string, Boolean>.Create;
  FDiffQuantAvsC := TDictionary<string, Boolean>.Create;
  FAbsentAvsC := TDictionary<string, Boolean>.Create;

  CommandLineArg := ParamStr(1); // Récupère le chemin du fichier passé par Windows
  if (CommandLineArg <> '') and (FileExists(CommandLineArg)) then
  begin
    frmEditTensorsActLoadSrcA1Execute(CommandLineArg);
  end;
  DragAcceptFiles(Handle, True);
  GgmlWarmUpIQxx;
end;

destructor TfrmEditTensors.Destroy;
begin
  if Assigned(frmEditKVsGGUF) then
    frmEditKVsGGUF.DetachModels;

  if Assigned(frmViewTensors) then
    frmViewTensors.DetachModels;

  FreeAndNil(FViewTensors1);
  FreeAndNil(FViewTensors2);
  FreeAndNil(FViewTensors3);
  FreeAndNil(FModelInp1);
  FreeAndNil(FModelInp2);
  FreeAndNil(FModelInp3);
  FreeAndNil(FViewTensorsS);
  FreeAndNil(FViewTensorsOut);
  FreeAndNil(FModelInpS);
  FreeAndNil(FModelOut);
  inherited;
end;

procedure TfrmEditTensors.FormDestroy(Sender: TObject);
begin
  FreeAndNil(FCancelMutex);
  FDiffShapeAvsB.Free;
  FDiffQuantAvsB.Free;
  FAbsentAvsB.Free;
  FDiffShapeAvsC.Free;
  FDiffQuantAvsC.Free;
  FAbsentAvsC.Free;
end;

procedure TfrmEditTensors.FormResize(Sender: TObject);
begin
  if Width < 800 then
    stBar1.Panels[0].Width := ClampInt(Round(Width * 0.48), 180, 800)
  else
    stBar1.Panels[0].Width := ClampInt(Round(Width * 0.6), 180, 800)
end;

procedure TfrmEditTensors.FormShow(Sender: TObject);
begin
  { mLang.GenerateFile(frmEditTensors, 'xx');
    mLang.GenerateFile(frmViewTensors, 'xx');
    mLang.GenerateFile(frmEditKVsGGUF, 'xx');
    mLang.GenerateFile(frmEditArrayDlg, 'xx');
    mLang.GenerateFile(frmMappedNames, 'xx');
    mLang.GenerateFile(frmSplitMerge, 'xx');
    mLang.GenerateFile(frmSettings, 'xx');
    mLang.GenerateFile(frmAbout, 'xx');
    mLang.GenerateFile(frmLogs, 'xx'); }
  TranslateForms(cfg.sLang);
end;

procedure TfrmEditTensors.PageControl1Change(Sender: TObject);
begin
  if TabSheetModOut = PageControl1.ActivePage then
  begin
    FCurrentSourceList := lvTensorsOut;
    FCurrentETName := edtNameOut;
    FCurrentcbDType := cbDTypeOut;
    btnTransferToOut1.Enabled := false;
    btnTransferToOut2.Enabled := false;
    btnTransferToOut3.Enabled := false;
    btnTransferToOutS.Enabled := false;
    cbDTypeOut.Enabled := True;
  end
  else if TabSheetModInA = PageControl1.ActivePage then
  begin
    cbDTypeOut.Enabled := false;
    btnTransferToOut1.Enabled := True;
    btnTransferToOut2.Enabled := false;
    btnTransferToOut3.Enabled := false;
    btnTransferToOutS.Enabled := false;
    FCurrentSourceList := lvTensors1;
    FCurrentETName := edtName1;
    FCurrentcbDType := cbDType1;
  end
  else if TabSheetModInB = PageControl1.ActivePage then
  begin
    cbDTypeOut.Enabled := false;
    btnTransferToOut1.Enabled := false;
    btnTransferToOut2.Enabled := True;
    btnTransferToOut3.Enabled := false;
    btnTransferToOutS.Enabled := false;
    FCurrentSourceList := lvTensors2;
    FCurrentETName := edtName2;
    FCurrentcbDType := cbDType2;
  end
  else if TabSheetModInC = PageControl1.ActivePage then
  begin
    cbDTypeOut.Enabled := false;
    btnTransferToOut1.Enabled := false;
    btnTransferToOut2.Enabled := false;
    btnTransferToOut3.Enabled := True;
    btnTransferToOutS.Enabled := false;
    FCurrentSourceList := lvTensors3;
    FCurrentETName := edtName3;
    FCurrentcbDType := cbDType3;
  end
  else if TabSheetModInS = PageControl1.ActivePage then
  begin
    cbDTypeOut.Enabled := false;
    btnTransferToOut1.Enabled := false;
    btnTransferToOut2.Enabled := false;
    btnTransferToOut3.Enabled := false;
    btnTransferToOutS.Enabled := True;
    FCurrentSourceList := lvTensorsS;
    FCurrentETName := edtNameS;
    FCurrentcbDType := cbDTypeS;
  end;
end;

procedure TfrmEditTensors.lvTensors1AdvancedCustomDrawItem(Sender: TCustomListView; Item: TListItem; State: TCustomDrawState; Stage: TCustomDrawStage; var DefaultDraw: Boolean);
begin
  if Item.Index mod 2 = 0 then
    Sender.Canvas.Brush.Color := $00F5F5F5
  else
    Sender.Canvas.Brush.Color := clWhite;
end;

procedure TfrmEditTensors.DrawTensorDiff(Sender: TCustomListView; Item: TListItem; SubItem: Integer; State: TCustomDrawState; DiffShape, DiffQuant, Absent: TDictionary<string, Boolean>);
var
  T: TGGUFTensorInfo;
  Nm: string;
begin
  if not Assigned(Item.Data) then
    Exit;
  T := TGGUFTensorInfo(Item.Data);
  Nm := string(T.Name);

  if DiffShape.ContainsKey(Nm) then
  begin
    if SubItem = 2 then
    begin
      Sender.Canvas.Font.Color := $0000FF; // Rouge
      Sender.Canvas.Font.Style := [fsBold];
    end;
  end
  else if DiffQuant.ContainsKey(Nm) then
  begin
    if SubItem = 1 then
    begin
      Sender.Canvas.Font.Color := $0000FF;
      Sender.Canvas.Font.Style := [fsBold];
    end;
  end
  else if Absent.ContainsKey(Nm) then
  begin
    Sender.Canvas.Font.Color := $0000FF;
    Sender.Canvas.Font.Style := [fsBold];
  end;

  if not (cdsSelected in State) then
  //if not (cdsSelected in State) then
  begin
    if Item.Index mod 2 = 0 then
      Sender.Canvas.Brush.Color := $00F5F5F5
    else
      Sender.Canvas.Brush.Color := clWhite;
  end;
end;

procedure TfrmEditTensors.lvTensors1AdvancedCustomDrawSubItem(Sender: TCustomListView; Item: TListItem; SubItem: Integer; State: TCustomDrawState; Stage: TCustomDrawStage; var DefaultDraw: Boolean);
begin
  if not Assigned(Item.Data) then
    Exit;
  DrawTensorDiff(Sender, Item, SubItem, State, FDiffShapeAvsB, FDiffQuantAvsB, FAbsentAvsB);
end;

procedure TfrmEditTensors.HandleColumnClick(Sender: TObject; Column: TListColumn; RebuildProc: TProc);
var
  LVs: array[0..4] of TListView;
  i, ColIdx: Integer;
  Arrow: string;
begin
  // 1. Gestion de la direction
  if Column.Index = FSortColumn then
    FSortDirection := not FSortDirection
  else
  begin
    FSortColumn := Column.Index;
    FSortDirection := True;
  end;

  // Mise à jour des titres des colonnes pour afficher la flèche

  // 1. Préparation de la flèche selon la direction
  if FSortDirection then
    Arrow := '▲ '
  else
    Arrow := '▼ ';

  // 2. Liste de tous les ListViews à mettre à jour
  LVs[0] := lvTensors1;
  LVs[1] := lvTensors2;
  LVs[2] := lvTensors3;
  LVs[3] := lvTensorsS;
  LVs[4] := lvTensorsOut;

  for i := 0 to 4 do
  begin
    if Assigned(LVs[i]) then
    begin
      for ColIdx := 0 to LVs[i].Columns.Count - 1 do
      begin
        // LVs[I].Columns[ColIdx].Caption := StringReplace(LVs[I].Columns[ColIdx].Caption, '▲', '', [rfReplaceAll, rfIgnoreCase]);
        //LVs[i].Columns[ColIdx].Caption := StringReplace(LVs[i].Columns[ColIdx].Caption, '▼', '', [rfReplaceAll, rfIgnoreCase]);
        // Si c'est la colonne triée, on ajoute la flèche
        if ColIdx <= High(FOriginalColumnCaptions) then
          LVs[i].Columns[ColIdx].Caption := FOriginalColumnCaptions[ColIdx];

        if ColIdx = FSortColumn then
        begin
          LVs[i].Columns[ColIdx].Caption := Arrow + LVs[i].Columns[ColIdx].Caption;
        end;
      end;
    end;
  end;

  // Exécuter la procédure de reconstruction qui contient le .Sort
  RebuildProc();
end;

procedure TfrmEditTensors.lvTensors1ColumnClick(Sender: TObject; Column: TListColumn);
begin
  HandleColumnClick(Sender, Column,
    procedure
    begin
      frmEditTensorsRebuildView1;
    end);
end;

procedure TfrmEditTensors.lvTensors2AdvancedCustomDrawSubItem(Sender: TCustomListView; Item: TListItem; SubItem: Integer; State: TCustomDrawState; Stage: TCustomDrawStage; var DefaultDraw: Boolean);
begin
  if not Assigned(Item.Data) then
    Exit;
  DrawTensorDiff(Sender, Item, SubItem, State, FDiffShapeAvsB, FDiffQuantAvsB, FAbsentAvsB);
end;

procedure TfrmEditTensors.lvTensors2ColumnClick(Sender: TObject; Column: TListColumn);
begin
  HandleColumnClick(Sender, Column,
    procedure
    begin
      frmEditTensorsRebuildView2;
    end);
end;

procedure TfrmEditTensors.lvTensors3AdvancedCustomDrawSubItem(Sender: TCustomListView; Item: TListItem; SubItem: Integer; State: TCustomDrawState; Stage: TCustomDrawStage; var DefaultDraw: Boolean);
begin
  if not Assigned(Item.Data) then
    Exit;
  DrawTensorDiff(Sender, Item, SubItem, State, FDiffShapeAvsC, FDiffQuantAvsC, FAbsentAvsC);
end;

procedure TfrmEditTensors.lvTensors3ColumnClick(Sender: TObject; Column: TListColumn);
begin
  HandleColumnClick(Sender, Column,
    procedure
    begin
      frmEditTensorsRebuildView3;
    end);
end;

procedure TfrmEditTensors.lvTensorSelectItem(Sender: TObject; Item: TListItem; Selected: Boolean);
var
  T: TGGUFTensorInfo;
  i: Integer;
begin
  if not Selected or (Item = nil) then
    Exit;
  if frmEditTensors.FUpdatingOutList then
    Exit;
  if Sender = lvTensors1 then
  begin
    FCurrentSourceList := lvTensors1;
    FCurrentETName := edtName1;
    FCurrentcbDType := cbDType1;
  end
  else if Sender = lvTensors2 then
  begin
    FCurrentSourceList := lvTensors2;
    FCurrentETName := edtName2;
    FCurrentcbDType := cbDType2;
  end
  else if Sender = lvTensors3 then
  begin
    FCurrentSourceList := lvTensors3;
    FCurrentETName := edtName3;
    FCurrentcbDType := cbDType3;
  end
  else if Sender = lvTensorsS then
  begin
    FCurrentSourceList := lvTensorsS;
    FCurrentETName := edtNameS;
    FCurrentcbDType := cbDTypeS;
  end
  else if Sender = lvTensorsOut then
  begin
    FCurrentSourceList := lvTensorsOut;
    FCurrentETName := edtNameOut;
    FCurrentcbDType := cbDTypeOut;
    T := TGGUFTensorInfo(Item.Data);
    // if Assigned(T) and (T.SourceId in [1, 2, 3, 4]) then
    if Assigned(T) and (SourceIdToOutComboIdx(T.SourceId) >= 0) then
    begin
      cbSrcModelOut1.OnChange := nil;
      cbSrcModelOut1.ItemIndex := SourceIdToOutComboIdx(T.SourceId); // T.SourceId - 1;
      for i := 0 to frmEditTensors.cbSrcModelOut1.Items.Count - 1 do
        // for i := 0 to (Min(cbSrcModelOut1.Items.Count, mnuSourceOut.Items.Count) - 1) do
         mnuSourceOut.Items[i].Checked := i = frmEditTensors.cbSrcModelOut1.ItemIndex;
      cbSrcModelOut1.OnChange := cbSrcModelOut1Change;
    end;
  end;
  frmEditTensorsRefreshEditorsForItem(Item);
end;

procedure TfrmEditTensors.lvTensorsOutAdvancedCustomDrawSubItem(Sender: TCustomListView; Item: TListItem; SubItem: Integer; State: TCustomDrawState; Stage: TCustomDrawStage; var DefaultDraw: Boolean);
var
  T: TGGUFTensorInfo;
begin
  if not Assigned(Item.Data) then
    Exit;

  T := TGGUFTensorInfo(Item.Data);
  // SubItem = 1 correspond à la colonne "DType"
  if (SubItem = 1) and T.IsConverted then
  begin
    Sender.Canvas.Font.Color := clRed;
    // Optionnel : graisser le texte pour plus de visibilité
    Sender.Canvas.Font.Style := [fsBold];
  end
  else if (SubItem = 10) and (T.SourceId = SRC_MODEL2) then
  begin
    Sender.Canvas.Font.Color := clBlue;
    Sender.Canvas.Font.Style := [fsBold];
  end
  else if (SubItem = 10) and (T.SourceId = SRC_MODEL3) then
  begin
    Sender.Canvas.Font.Color := clNavy;
    Sender.Canvas.Font.Style := [fsBold];
  end
  else if (SubItem = 10) and (T.SourceId = SRC_MODELS) then
  begin
    Sender.Canvas.Font.Color := clGreen;
    Sender.Canvas.Font.Style := [fsBold];
  end
  else
  begin
    // Réinitialisation normale
    Sender.Canvas.Font.Color := clWindowText;
    Sender.Canvas.Font.Style := [];
  end;
end;

procedure TfrmEditTensors.lvTensorsOutColumnClick(Sender: TObject; Column: TListColumn);
begin
  HandleColumnClick(Sender, Column,
    procedure
    begin
      frmEditTensorsRebuildViewOut;
    end);
end;

procedure TfrmEditTensors.lvTensorsOutItemChecked(Sender: TObject; Item: TListItem);
var
  TSrc, TCurrent: TGGUFTensorInfo;
  TargetPattern, TargetName: string;
  i: Integer;
  It: TListItem;
  AllLayers, MatchPattern, MatchLayers: Boolean;
  Select: Boolean;
begin
  if Item = nil then
    Exit;
  if Item.Data = nil then
    Exit;
  if frmEditTensors.FUpdatingOutList then
    Exit;

  TSrc := TGGUFTensorInfo(Item.Data);
  if not Assigned(TSrc) then
    Exit;

  // Verrouillage UI pour éviter les appels récursifs de lvTensorsOutItemChecked
   FUpdatingOutList := True;

  Select := Item.Checked;

  TargetName := string(TSrc.Name);
  TargetPattern := GetTensorPatternName(TargetName);
  AllLayers := frmEditTensors.chkAllLayersOut.Checked;

  try
    for i := 0 to frmEditTensors.lvTensorsOut.Items.Count - 1 do
    begin
      // for I := 0 to SrcMod.Tensors.Count - 1 do begin
      // TCurrent := TGGUFTensorInfo(SrcMod.Tensors[I]);
      It := frmEditTensors.lvTensorsOut.Items[i];
      if not Assigned(It.Data) then
        Continue;
      TCurrent := TGGUFTensorInfo(It.Data);

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
        MatchLayers := MatchesLayerFilter(TCurrent.LayerIndex, frmEditTensors.cbLayersFromOut.Text, frmEditTensors.cbLayersToOut.Text, frmEditTensors.cbLayersModOut.Text, True)
      else
        MatchLayers := True; // En mode exact (MatchPattern = True)

      if MatchLayers then
      begin
        TCurrent.Keep := Select;
        It.Checked := Select;
        if TCurrent.Keep then
          eLogMsg(mLang.gMsgFmt('FTE.TensorChecked', [string(TCurrent.Name)]))
        else
          eLogMsg(mLang.gMsgFmt('FTE.TensorUnchecked', [string(TCurrent.Name)]));
      end;
    end;
    // 4. Recalcul des tailles globales et rafraîchissement des métriques
     FGlobalSizeOut := CalculateAllPatternSizes(frmEditTensors.FModelOut);
     stBar1.Panels[SB_MO].Text := FormatBytes2f(frmEditTensors.FGlobalSizeOut);
  finally
     FUpdatingOutList := false;
  end;
end;

procedure TfrmEditTensors.lvTensorsSColumnClick(Sender: TObject; Column: TListColumn);
begin
  HandleColumnClick(Sender, Column,
    procedure
    begin
      frmEditTensorsRebuildViewS;
    end);
end;

procedure TfrmEditTensors.lvTensorsSCustomDrawSubItem(Sender: TCustomListView; Item: TListItem; SubItem: Integer; State: TCustomDrawState; var DefaultDraw: Boolean);
var
  T: TGGUFTensorInfo;
begin
  if not Assigned(Item.Data) then
    Exit;
  T := TGGUFTensorInfo(Item.Data);
  // Coloration spéciale pour les tenseurs TRANSPOSÉS (en Violet/Magenta)
  if T.IsTransposed then
  begin
    Sender.Canvas.Font.Color := clPurple;
    Sender.Canvas.Font.Style := [fsBold];
  end
    { else if (SubItem = 1) and (T.NameMap <> '') and (T.IsNameMapped) then
    begin
    Sender.Canvas.Font.Color := clRed;
    end }
  else
  begin
    Sender.Canvas.Font.Color := clWindowText;
    Sender.Canvas.Font.Style := [];
  end;
end;

procedure TfrmEditTensors.lvTensorsSData(Sender: TObject; Item: TListItem);
var
  T: TGGUFTensorInfo;
  GlobalSize: Int64;
  DisplaySize: Int64;
  SizeP: Double;
begin
  if not Assigned(FViewTensorsS) or (Item.Index >= FViewTensorsS.Count) then
    Exit;
  // Récupération de l'objet via l'index
  T := TGGUFTensorInfo(FViewTensorsS[Item.Index]);

  Item.Data := T; // Requis pour OnSelectItem, OnAdvancedCustomDrawSubItem, etc.
  Item.Checked := T.Keep; // Synchronise la checkbox
  GlobalSize := FGlobalSizeS; // CalculateGlobalSize(FModelInpS);
  // Remplissage du Caption
  Item.Caption := string(T.Name);
  if T.IsNameMapped then
    Item.Caption := Item.Caption + ' * ';
  // Remplissage des SubItems (Colonnes)
  Item.SubItems.Clear;
  Item.SubItems.Add(GGMLTypeToStr(T.TensorType));
  Item.SubItems.Add(TensorShapeText(T.Dims));

  if T.LayerIndex >= 0 then
    Item.SubItems.Add(IntToStr(T.LayerIndex))
  else
    Item.SubItems.Add('-');

  if T.IsConverted then
    DisplaySize := T.ByteSize
  else
    DisplaySize := T.ByteSizeOrg;
  Item.SubItems.Add(FormatBytes2f(DisplaySize));

  if GlobalSize > 0 then
  begin
    SizeP := (DisplaySize / GlobalSize) * 100;
    Item.SubItems.Add(Format('%.2f%%', [SizeP]));
  end
  else
    Item.SubItems.Add('0.00%');

  if T.LayerIndex >= 0 then
  begin
    Item.SubItems.Add(FormatBytes2f(T.PatternGlobalSize));
    if GlobalSize > 0 then
    begin
      SizeP := (T.PatternGlobalSize / GlobalSize) * 100;
      Item.SubItems.Add(Format('%.2f%%', [SizeP]));
    end
    else
      Item.SubItems.Add('0.00%');
  end
  else
  begin
    Item.SubItems.Add('-');
    Item.SubItems.Add('-');
  end;

  Item.SubItems.Add(IntToStr(T.Offset));
  Item.SubItems.Add(IntToStr(T.SourceId));
  Item.SubItems.Add(GGMLTypeToStr(T.TensorTypeOrg));

  Item.SubItems.Add(IntToStr(T.UseImpl));
  Item.SubItems.Add(IntToStr(T.RmseType));
end;

procedure TfrmEditTensors.cbDTypeOutClick(Sender: TObject);
var
  SelectedT: TGGUFTensorInfo;
  NewType, UseImpl, RmseType: Integer;
begin
  if FCurrentSourceList <> lvTensorsOut then
    Exit;
  SelectedT := GetActiveTensor;
  if not Assigned(SelectedT) then
    Exit;
  NewType := StrToGGMLType(cbDTypeOut.Text);
  if NewType < 0 then
    Exit;

  UseImpl := TCombo_GetSel(cbUseImpl, cfg.UseImpl);
  RmseType := TCombo_GetSel(cbRmseType, cfg.RmseType);
  if QP_HasPreset(UseImpl) then
  begin
    cbRmseType.Enabled := True;
    if Assigned(cfg.ggmlReg.GetPPreset(NewType, QP_ProfileOfUseImpl(UseImpl))) then
      RmseType := QP_ProfileRmse(NewType, UseImpl, RmseType);
  end
  else
  begin
    cbRmseType.Enabled := False;
    RmseType := 0;
  end;
  TCombo_SetSel(cbRmseType, RmseType);

  ApplyOutSelPreset(SelectedT, NewType, UseImpl, RmseType);
end;


procedure TfrmEditTensors.cbMappedNames1Click(Sender: TObject);
begin
  frmEditTensorsApplyMappedNames1(cbMappedNames1.Text);
end;

procedure TfrmEditTensors.cbMappedNames2Click(Sender: TObject);
begin
  frmEditTensorsApplyMappedNames2(cbMappedNames2.Text);
end;

procedure TfrmEditTensors.cbMappedNames3Click(Sender: TObject);
begin
  frmEditTensorsApplyMappedNames3(cbMappedNames3.Text);
end;

procedure TfrmEditTensors.cbMappedNamesSClick(Sender: TObject);
begin
  frmEditTensorsApplyMappedNamesS(cbMappedNamesS.Text);
end;

procedure TfrmEditTensors.cbSrcModelOut1Change(Sender: TObject);
var
  SelectedT: TGGUFTensorInfo;
  SelectedName: string;
begin
  SelectedT := GetActiveTensor;
  if not Assigned(SelectedT) then
    Exit;
  SelectedName := string(SelectedT.Name);
  if Sender = cbSrcModelOut1 then
  begin
    // TransferSelectedTensorToOut(cbSrcModelOut1.ItemIndex + 1, cbLayersFromOut, cbLayersToOut, cbLayersModOut, chkAllLayersOut.Checked);
    TransferSelectedTensorToOut(OutComboIdxToSourceId(cbSrcModelOut1.ItemIndex), cbLayersFromOut, cbLayersToOut, cbLayersModOut, chkAllLayersOut.Checked);
    RestoreListViewSelection(lvTensorsOut, SelectedName);
    frmViewTensors.FSelectionOrder.Clear;
    //frmViewTensors.ChListBoxTensors.Items.Clear;
  end;
end;

procedure TfrmEditTensors.ApplyOutSelPreset(T: TGGUFTensorInfo; NewType, UseImpl, RmseType: Integer);
begin
  if not DoQuantTypeOutChange(T, NewType, UseImpl, RmseType, chkAllLayersOut.Checked, cbLayersFromOut.Text, cbLayersToOut.Text, cbLayersModOut.Text) then
    Exit;
    //SetUseImplClickUi(UseImpl, RmseType);       // -> frmViewTensors : edt* + Enabled + combos
  if Assigned(frmViewTensors) then
    frmViewTensors.ApplyRmseFromEdit(NewType, UseImpl, RmseType, T); // resynchronise l'identité affichée dans la vue
end;

function TfrmEditTensors.QP_ProfileRmse(AType, UseImpl, ACur: Integer): Integer;
var
  P: PQuantPreset;
begin
  Result := ACur;
  if not QP_HasPreset(UseImpl) then
    Exit;
  P := cfg.ggmlReg.GetPPreset(AType, QP_ProfileOfUseImpl(UseImpl));
  if Assigned(P) then
    Result := P.RmseType;      // le preset fait foi sur changement d'identité
end;


procedure TfrmEditTensors.cbUseImplClick(Sender: TObject);
var
  SelectedT: TGGUFTensorInfo;
  NewType, UseImpl, RmseType: Integer;
begin
  if FCurrentSourceList <> lvTensorsOut then
    Exit;
  SelectedT := GetActiveTensor;
  if not Assigned(SelectedT) then
    Exit;

  NewType := SelectedT.TensorType;
  if NewType < 0 then
    Exit;

  UseImpl := TCombo_GetSel(cbUseImpl, cfg.UseImpl);

  frmViewTensors.LoadPresetToUI(NewType, UseImpl);

  RmseType := TCombo_GetSel(cbRmseType, cfg.RmseType);

  SelectedT.UseImpl := UseImpl;
  SelectedT.RmseType := RmseType;

  ApplyOutSelPreset(SelectedT, NewType, UseImpl, RmseType);
end;


procedure TfrmEditTensors.cbRmseTypeClick(Sender: TObject);
var
  SelectedT: TGGUFTensorInfo;
  NewType, UseImpl, RmseType: Integer;
begin
  if FCurrentSourceList <> lvTensorsOut then
    Exit;
  SelectedT := GetActiveTensor;
  if not Assigned(SelectedT) then
    Exit;

  NewType := SelectedT.TensorType;                 // <<< (correction bug NewType non init)
  UseImpl := TCombo_GetSel(cbUseImpl, cfg.UseImpl);
  RmseType := TCombo_GetSel(cbRmseType, cfg.RmseType);
  //cbRmseType.Enabled := QP_HasPreset(UseImpl);

  ApplyOutSelPreset(SelectedT, NewType, UseImpl, RmseType);   // écrit preset + synchro conditionnelle
  TCombo_SetSel(cbRmseType, RmseType);// RestoreListViewSelection et AListView.Selected := Item; le change ! corriger par FUpdatingOutList
  lvTensorsOut.Invalidate;
end;


procedure TfrmEditTensors.chkAllLayers1Click(Sender: TObject);
begin
  frmEditTensorsEnableComboBoxFilter(cbLayersFrom1, cbLayersTo1, cbLayersMod1, chkAllLayers1.Checked);
end;

procedure TfrmEditTensors.chkAllLayers2Click(Sender: TObject);
begin
  frmEditTensorsEnableComboBoxFilter(cbLayersFrom2, cbLayersTo2, cbLayersMod2, chkAllLayers2.Checked);
end;

procedure TfrmEditTensors.chkAllLayers3Click(Sender: TObject);
begin
  frmEditTensorsEnableComboBoxFilter(cbLayersFrom3, cbLayersTo3, cbLayersMod3, chkAllLayers3.Checked);
end;

procedure TfrmEditTensors.chkAllLayersOutClick(Sender: TObject);
var
  T: TGGUFTensorInfo;
begin
  frmEditTensorsEnableComboBoxFilter(cbLayersFromOut, cbLayersToOut, cbLayersModOut, chkAllLayersOut.Checked);
  // le filtre sélectionne les cibles : on resynchronise simplement l'UI du tenseur actif
  T := GetActiveTensor;
  if Assigned(T) then
    frmEditTensorsRefreshEditorsForItem(lvTensorsOut.Selected);
end;




procedure TfrmEditTensors.chkAllLayersSClick(Sender: TObject);
begin
  frmEditTensorsEnableComboBoxFilter(cbLayersFromS, cbLayersToS, cbLayersModS, chkAllLayersS.Checked);
end;

procedure TfrmEditTensors.chkUseIgnoredPrefixes1Click(Sender: TObject);
begin
  cfg.UseIgnoredPrefixes1 := chkUseIgnoredPrefixes1.Checked;
  // cfgSaveSettings(cfg);
  if Assigned(FModelInp1) then
  begin
    // frmEditTensorsRebuildView1; to do
    // frmEditTensorsRebuildViewOut;
    // eLogMsg(mLang.gMsgFmt('PrefixFilterChanged', [IfThen(cfg.UseIgnoredPrefixes1, 'Activé', 'Désactivé')]));
    eLogMsg(mLang.gMsgFmt('FTE.PrefixFilterChanged', [IfThen(cfg.UseIgnoredPrefixes1, mLang.gMsg('FTE.Enabled'), mLang.gMsg('FTE.Disabled'))]));
  end;
end;

procedure TfrmEditTensors.chkUseIgnoredPrefixes2Click(Sender: TObject);
begin
  cfg.UseIgnoredPrefixes2 := chkUseIgnoredPrefixes2.Checked;
  // cfgSaveSettings(cfg);
  if Assigned(FModelInp2) then
  begin
    // frmEditTensorsRebuildView2;
    // frmEditTensorsRebuildViewOut;
    // eLogMsg(mLang.gMsgFmt('FTE.PrefixFilterChanged', [IfThen(cfg.UseIgnoredPrefixes2, 'Activé', 'Désactivé')]));
    eLogMsg(mLang.gMsgFmt('FTE.PrefixFilterChanged', [IfThen(cfg.UseIgnoredPrefixes2, mLang.gMsg('FTE.Enabled'), mLang.gMsg('FTE.Disabled'))]));
  end;
end;

procedure TfrmEditTensors.chkUseIgnoredPrefixes3Click(Sender: TObject);
begin
  cfg.UseIgnoredPrefixes3 := chkUseIgnoredPrefixes3.Checked;
  if Assigned(FModelInp3) then
    // eLogMsg(mLang.gMsgFmt('FTE.PrefixFilterChanged', [IfThen(cfg.UseIgnoredPrefixes3, 'Activé', 'Désactivé')]));
    eLogMsg(mLang.gMsgFmt('FTE.PrefixFilterChanged', [IfThen(cfg.UseIgnoredPrefixes3, mLang.gMsg('FTE.Enabled'), mLang.gMsg('FTE.Disabled'))]));
end;

procedure TfrmEditTensors.chkUseIgnoredPrefixesSClick(Sender: TObject);
begin
  cfg.UseIgnoredPrefixesS := chkUseIgnoredPrefixesS.Checked;
  // cfgSaveSettings(cfg);
  if Assigned(FModelInpS) then
  begin
    // todo Le filtrage SafeTensors s'applique au chargement, pas en temps réel sur modèle déjà chargé
    // frmEditTensorsRebuildViewS;
    // frmEditTensorsRebuildViewOut;
    // eLogMsg(mLang.gMsgFmt('FTE.PrefixFilterChanged', [IfThen(cfg.UseIgnoredPrefixesS, 'Activé', 'Désactivé')]));
    eLogMsg(mLang.gMsgFmt('FTE.PrefixFilterChanged', [IfThen(cfg.UseIgnoredPrefixesS, mLang.gMsg('FTE.Enabled'), mLang.gMsg('FTE.Disabled'))]));
  end;
end;

function TfrmEditTensors.IsCancelled: Boolean;
begin
  FCancelMutex.Enter;
  try
    Result := FCancelSave;
  finally
    FCancelMutex.Leave;
  end;
end;

procedure TfrmEditTensors.SetCancelled(B: Boolean);
begin
  FCancelMutex.Enter;
  try
    FCancelSave := B;
  finally
    FCancelMutex.Leave;
  end;
end;

procedure TfrmEditTensors.ResetSaveCtx;
begin
  FSaveCtx.CurActive := false;
  FSaveCtx.CurIdx := 0;
  FSaveCtx.CurTot := 0;
  FSaveCtx.CurName := '';
  FSaveCtx.CurStartTick := 0;
  FSaveCtx.CurSize := 0;
  FSaveCtx.CurDone := 0;
  FSaveCtx.LiveTick := 0;

  FSaveCtx.PartNo := 1;
  FSaveCtx.PartTot := 1;
  FSaveCtx.IsMetaPart := false;

  FSaveCtx.LastGlobalBytes := 0;
  FSaveCtx.LastPartBytes := 0;
  FSaveCtx.LastLog := '';
end;

procedure TfrmEditTensors.EndSave;
begin
  FCancelMutex.Enter;
  try
    FSaveRunning := false;
  finally
    FCancelMutex.Leave;
  end;

  ProgressBar1.Visible := false;
  ProgressBar2.Visible := false;
  ProgressBar1.Position := 0;
  ProgressBar2.Position := 0;

  ActSaveOut.Enabled := True;
  btnCancel.Enabled := false;

  ResetSaveCtx;
end;

function TfrmEditTensors.BeginSave: Boolean;
begin
  Result := false;

  FCancelMutex.Enter;
  try
    if FSaveRunning then
      Exit;
    FSaveRunning := True;
    FCancelSave := false;
  finally
    FCancelMutex.Leave;
  end;

  FSaveStartedTick := GetTickCount64;

  FLastSaveUIUpdateTick := 0;
  ResetSaveCtx;

  ProgressBar1.Visible := True;
  ProgressBar2.Visible := True;
  ProgressBar1.Max := 100;
  ProgressBar1.Position := 0;
  ProgressBar2.Max := 100;
  ProgressBar2.Position := 0;

  ActSaveOut.Enabled := false;
  btnCancel.Enabled := True;

  stBar1.Panels[0].Text := mLang.gMsg('FTE.SavingInProgress');

  Result := True;
end;

procedure TfrmEditTensors.btnCancelClick(Sender: TObject);
begin
  btnCancel.Enabled := false; // verrouiller le bouton
  if not FSaveRunning then
    Exit; // d'abord vérifier l'état

      // if MessageDlg('⚠️ Annuler la sauvegarde ?' + #13#10 + 'Le fichier en cours de création sera immédiatement supprimé.',
  // mtConfirmation, [mbYes, mbNo], 0) = mrNo then
  if MessageDlg(mLang.gMsg('FTE.ConfirmCancelSave'), mtConfirmation, [mbYes, mbNo], 0) = mrNo then
    Exit;
  SetCancelled(True);
  // StatusBar1.Panels[0].Text := 'Interruption du writer...';
  eLogMsg(mLang.gMsg('FTE.OperationCancelled'), -1, -1, lvWarn);
end;

procedure TfrmEditTensors.btnClearFText1Click(Sender: TObject);
begin
  edtFilter1.Text := '';
  frmEditTensorsRebuildView1
end;

procedure TfrmEditTensors.btnClearFText2Click(Sender: TObject);
begin
  edtFilter2.Text := '';
  frmEditTensorsRebuildView2;
end;

procedure TfrmEditTensors.btnClearFText3Click(Sender: TObject);
begin
  edtFilter3.Text := '';
  frmEditTensorsRebuildView3;
end;

procedure TfrmEditTensors.btnClearFTextOClick(Sender: TObject);
begin
  edtFilterO.Text := '';
end;

procedure TfrmEditTensors.btnClearFTextSClick(Sender: TObject);
begin
  edtFilterS.Text := '';
  frmEditTensorsRebuildViewS;
end;

procedure TfrmEditTensors.btnClearTranspositionClick(Sender: TObject);
begin
  frmEditTensorsDoClearTransposeActiveTensor();
end;

procedure TfrmEditTensors.ActAboutExecute(Sender: TObject);
begin
  frmAbout.ShowModal;
end;

procedure TfrmEditTensors.ActBrowseOutExecute(Sender: TObject);
var
  Dir, NameOnly: string;
begin
  Get_Dit_NameOnly(edtOut.Text, Dir, NameOnly);
  SaveDialog1.FileName := edtOut.Text;//NameOnly;
  SaveDialog1.InitialDir := Dir;
  SaveDialog1.Filter := 'GGUF (*.gguf)|*.gguf|All (*.*)|*.*';
  if SaveDialog1.Execute then
    edtOut.Text := SaveDialog1.FileName;
end;

procedure TfrmEditTensors.ActBrowseSrcA1Execute(Sender: TObject);
var
  ssfn, ssfn0: string;
  i: Integer;
  Dir, NameOnly: string;
begin
  Get_Dit_NameOnly(edtSrc1.Text, Dir, NameOnly);
  OpenDialog1.FileName   := NameOnly;
  OpenDialog1.InitialDir := Dir;
  OpenDialog1.Filter := 'GGUF (*.gguf)|*.gguf|All (*.*)|*.*';
  if OpenDialog1.Execute then
  begin
    if (edtSrc1.Text <> OpenDialog1.FileName) and FileExists(OpenDialog1.FileName) then
    begin
      edtSrc1.Text := OpenDialog1.FileName;
      i := 1;
      ssfn0 := ChangeFileExt(OpenDialog1.FileName, '') + '_edited';
      ssfn := ssfn0 + IntToStr(i) + '.gguf';
      while FileExists(ssfn) do
      begin
        Inc(i);
        if i > 100 then
          Break;
        ssfn := ssfn0 + IntToStr(i) + '.gguf';
      end;
      edtOut.Text := ssfn;
      ActLoadSrcA1Execute(Sender);
    end;
  end;
end;

procedure TfrmEditTensors.ActBrowseSrcB2Execute(Sender: TObject);
var
  Dir, NameOnly: string;
begin
  Get_Dit_NameOnly(edtSrc2.Text, Dir, NameOnly);
  OpenDialog1.FileName   := NameOnly;
  OpenDialog1.InitialDir := Dir;
  OpenDialog1.Filter := 'GGUF (*.gguf)|*.gguf|All (*.*)|*.*';
  if OpenDialog1.Execute then
    if (edtSrc2.Text <> OpenDialog1.FileName) and FileExists(OpenDialog1.FileName) then
    begin
      edtSrc2.Text := OpenDialog1.FileName;
      ActLoadSrcB2Execute(Sender);
    end;
end;

procedure TfrmEditTensors.ActBrowseSrcC3Execute(Sender: TObject);
var
  Dir, NameOnly: string;
begin
  Get_Dit_NameOnly(edtSrc3.Text, Dir, NameOnly);
  OpenDialog1.FileName   := NameOnly;
  OpenDialog1.InitialDir := Dir;
  OpenDialog1.Filter := 'GGUF (*.gguf)|*.gguf|All (*.*)|*.*';
  if OpenDialog1.Execute then
    if (edtSrc3.Text <> OpenDialog1.FileName) and FileExists(OpenDialog1.FileName) then
    begin
      edtSrc3.Text := OpenDialog1.FileName;
      ActLoadSrcC3Execute(Sender);
    end;
end;

procedure TfrmEditTensors.ActBrowseSrcSExecute(Sender: TObject);
var
  Dir, NameOnly: string;
begin
  Get_Dit_NameOnly(edtSrcS.Text, Dir, NameOnly);
  OpenDialog1.FileName   := NameOnly;
  OpenDialog1.InitialDir := Dir;
  OpenDialog1.Filter := 'PyTorch Safetensors (*.safetensors)|*.safetensors|All (*.*)|*.*';
  if OpenDialog1.Execute then
    if (edtSrcS.Text <> OpenDialog1.FileName) and FileExists(OpenDialog1.FileName) then
    begin
      edtSrcS.Text := OpenDialog1.FileName;
      ActLoadSrcSExecute(Sender);
    end;
end;

procedure TfrmEditTensors.ActHelpExecute(Sender: TObject);
var
  DocFN: string;
begin
  DocFN := ExtractFilePath(ParamStr(0)) + 'Doc\' + cfg.sLang + '\index.html';
  // Winapi.ShellAPI.ShellExecute(0, 'open', 'https://github.com/abbndz/ggufeditplus', nil, nil, SW_SHOWNORMAL);
  if not FileExists(DocFN) then
    DocFN := ExtractFilePath(ParamStr(0)) + 'Doc\index.html';
  ShellExecute(0, 'open', PChar(DocFN), nil, nil, SW_SHOWNORMAL);
end;

procedure TfrmEditTensors.ActLoadSrcA1Execute(Sender: TObject);
begin
  frmEditTensorsActLoadSrcA1Execute(frmEditTensors.edtSrc1.Text);
end;

procedure TfrmEditTensors.ActLoadSrcB2Execute(Sender: TObject);
begin
  frmEditTensorsActLoadSrcB2Execute(frmEditTensors.edtSrc2.Text);
end;

procedure TfrmEditTensors.ActLoadSrcC3Execute(Sender: TObject);
begin
  frmEditTensorsActLoadSrcC3Execute(frmEditTensors.edtSrc3.Text);
end;

procedure TfrmEditTensors.ActLoadSrcSExecute(Sender: TObject);
begin
  frmEditTensorsActLoadSrcSExecute(frmEditTensors.edtSrcS.Text);
end;

procedure TfrmEditTensors.ActSaveOutExecute(Sender: TObject);
var
  sOutFile: string;
  Existing: TStringList;
  Msg: string;
  i: Integer;
begin
  //if not Assigned(frmEditTensors.FModelInp1) then
  if (not Assigned(frmEditTensors.FModelOut)) {or (frmEditTensors.FModelOut.Tensors.Count = 0)} then
  begin
    MessageDlg(mLang.gMsg('FTE.ModelNotLoaded'), mtWarning, [mbOK], 0);
    Exit;
  end;
  sOutFile := Trim(edtOut.Text);
  if sOutFile = '' then
  begin
    MessageDlg(mLang.gMsg('FTE.InvalidOutputPath'), mtWarning, [mbOK], 0);
    Exit;
  end;
  if not DirectoryExists(ExtractFilePath(sOutFile)) then
  begin
    MessageDlg(mLang.gMsg('FTE.InvalidDirectory'), mtError, [mbOK], 0);
    Exit;
  end;
  // Gestion de l'existence du fichier (Écrasement vs Confirmation simple)
  if FileExists(sOutFile) then
  begin
    // Le fichier existe : On demande s'il faut écraser
    if MessageDlg(mLang.gMsg('FTE.OverwriteWarning'), mtWarning, [mbYes, mbNo], 0) <> mrYes then
      Exit;
  end;
  if cfg.SplitSizeMBytes > 0 then
  try
    Existing := TStringList.Create;
    if CheckExistingOutFiles(sOutFile, Existing) then
    begin
      Msg := mLang.gMsg('FTE.OverwritesWarning') + sLineBreak + sLineBreak;
      if Existing.Count = 1 then
        Msg := Msg + ExtractFileName(Existing[0])
      else
      begin
        Msg := Msg + Format('(%d file(s) will be overwritten/deleted:', [Existing.Count]);
        for i := 0 to Existing.Count - 1 do
        begin
          Msg := Msg + sLineBreak + '  • ' + ExtractFileName(Existing[i]);
          if i >= 9 then
          begin
            Msg := Msg + sLineBreak + Format('  … (+%d autres)', [Existing.Count - 10]);
            Break;
          end;
        end;
        Msg := Msg + ')';
      end;
      Msg := Msg + sLineBreak + sLineBreak + mLang.gMsg('FTE.OverwriteConfirm');
      if MessageDlg(Msg, mtWarning, [mbYes, mbNo], 0) <> mrYes then
        Exit;
    end;
  finally
    Existing.Free;
  end;

  // On demande une confirmation générale de sauvegarde
  if MessageDlg(mLang.gMsg('FTE.ConfirmSaveProcess'), mtConfirmation, [mbYes, mbNo], 0) <> mrYes then
    Exit;
  // Si on arrive ici, l'utilisateur a dit "Oui"
  frmEditTensorsActSaveOutExecute();
end;

procedure TfrmEditTensors.ActSettingsExecute(Sender: TObject);
begin
  if not Assigned(frmSettings) then
    Application.CreateForm(TfrmSettings, frmSettings);
  frmSettings.Show;
end;

procedure TfrmEditTensors.ActShowLogsExecute(Sender: TObject);
begin
  if not Assigned(frmLogs) then
    Application.CreateForm(TfrmLogs, frmLogs);
  frmLogs.Show;
end;

procedure TfrmEditTensors.ActSplitMergeExecute(Sender: TObject);
begin
  if frmSplitMerge = nil then
    Application.CreateForm(TfrmSplitMerge, frmSplitMerge);
  try
    frmSplitMerge.Show;
  finally
  end;
end;

procedure TfrmEditTensors.ActViewKVsExecute(Sender: TObject);
begin
  if FrmEditKVsGGUF = nil then
    Application.CreateForm(TfrmEditKVsGGUF, FrmEditKVsGGUF);
  try
    SetModelsToFrmViewAndFrmEditKVs;
    FrmEditKVsGGUF.Show;
  finally
  end;
end;

procedure TfrmEditTensors.SetModelsToFrmViewAndFrmEditKVs();
begin
  if Assigned(frmViewTensors) then
  begin
    frmViewTensors.FModel1 := FModelInp1;
    frmViewTensors.FModel2 := FModelInp2;
    frmViewTensors.FModel3 := FModelInp3;
    frmViewTensors.FModelS := FModelInpS;
    frmViewTensors.FModelOut := FModelOut;
    frmViewTensors.FSelectionOrder.Clear;
    //if frmViewTensors.Visible then
    frmViewTensors.PubPopulateTensorList;
  end;
  if Assigned(FrmEditKVsGGUF) then
  begin
    FrmEditKVsGGUF.ModelA := FModelInp1;
    FrmEditKVsGGUF.ModelB := FModelInp2;
    FrmEditKVsGGUF.ModelC := FModelInp3;
    FrmEditKVsGGUF.ModelOut := FModelOut;
    if FrmEditKVsGGUF.Visible then
       FrmEditKVsGGUF.RefreshAll;
  end;
end;

procedure TfrmEditTensors.ActViewTensorsExecute(Sender: TObject);
begin
  if frmViewTensors = nil then
    Application.CreateForm(TfrmViewTensors, frmViewTensors);
  try
    SetModelsToFrmViewAndFrmEditKVs;
    if not frmViewTensors.Visible then
    begin
      frmViewTensors.PubPopulateTensorList;
      frmViewTensors.Show;
    end;
  finally
  end;
end;

procedure TfrmEditTensors.OnProgressEventLoad(const Msg: string; AIdx, ATotal: Int64; Level: TLogLevel = lvTrace);
var
  T: Int64;
begin
  T := GetTickCount64;
  if (T - FLastUIProgressUpdateTick < 10) and not ((ATotal > 0) and (AIdx >= ATotal)) then
    Exit;
  FLastUIProgressUpdateTick := T;
  eLogMsg(Msg, AIdx, ATotal, Level);
end;

procedure TfrmEditTensors.OnProgressEventSave(const Info: TProgressInfo);
const
  UI_REFRESH_MS = 65;
  LIVE_LOG_MS = 5000;
  BIG_TENSOR = 32 * 1024 * 1024;

  procedure LogLine(const S: string);
  begin
    if S = FSaveCtx.LastLog then
      Exit;
    FSaveCtx.LastLog := S;
    LogMsg('[SAVE] ' + S, lvNotice);
  end;

  procedure CloseCurTensor(const Reason: string);
  var
    El: Int64;
    Spd: string;
  begin
    if not FSaveCtx.CurActive then
      Exit;

    El := ElapsedSince(FSaveCtx.CurStartTick);
    Spd := FormatSpeedMBs(FSaveCtx.CurSize, El);//SpeedMBs(FSaveCtx.CurSize, El);

    // LogLine(Format('✅ Tensor %d/%d %s | done in %s | %.4f MB/s%s',
    //   [FSaveCtx.CurIdx, FSaveCtx.CurTot, FSaveCtx.CurName, FormatDurationMs(El),
    //   Spd, IfThen(Reason <> '', ' | ' + Reason, '')]));

    LogLine(Format('✅ Tensor %d/%d %s | done in %s | %s%s', //
      [FSaveCtx.CurIdx, FSaveCtx.CurTot, FSaveCtx.CurName, FormatDurationMs(El), //
      Spd, IfThen(Reason <> '', ' | ' + Reason, '')]));

    FSaveCtx.CurActive := false;
  end;

var
  NowTick: UInt64;
  GlobalPct, TensorPct: Integer;
  Status: string;
begin
  // ---------------------------------------------------------------
  // 1) Mise à jour du contexte interne
  // ---------------------------------------------------------------
  FSaveCtx.PartNo := Info.PartNo;
  FSaveCtx.PartTot := Info.PartTot;
  FSaveCtx.IsMetaPart := Info.IsMetaPart;
  FSaveCtx.LastGlobalBytes := Info.GlobalBytesDone;
  FSaveCtx.LastPartBytes := Info.PartBytes;

  NowTick := GetTickCount64;

  // Ligne "en cours" pour les gros tenseurs, même si PROG arrive lentement
  if FSaveCtx.CurActive and (FSaveCtx.CurSize > BIG_TENSOR) then
  begin
    if (NowTick - FSaveCtx.LiveTick >= LIVE_LOG_MS) and (FSaveCtx.CurDone > 0) then
    begin
      FSaveCtx.LiveTick := NowTick;
      LogLine(Format('   … Tensor %d/%d %s  %s/%s (%s)', [FSaveCtx.CurIdx, FSaveCtx.CurTot, FSaveCtx.CurName, FormatBytes2f(FSaveCtx.CurDone), FormatBytes2f(FSaveCtx.CurSize), FormatDurationMs(NowTick - FSaveCtx.CurStartTick)]));
    end;
  end;

  case Info.Kind of
    pkHeader:
      begin
        CloseCurTensor('');

        if Info.IsMetaPart then
          LogLine(Format('--- Part %d/%d : metadata (header-only file) ---', [Info.PartNo, Info.PartTot]))
        else
          LogLine(Format('--- Part %d/%d : %s ---', [Info.PartNo, Info.PartTot, ExtractFileName(Info.SourceFile)]));
      end;
    pkTensorStart:
      begin
        CloseCurTensor('');

        FSaveCtx.CurIdx := Info.TensorIdx;
        FSaveCtx.CurTot := Info.TensorTotal;
        FSaveCtx.CurName := Info.Msg;
        FSaveCtx.CurSize := Info.TensorBytesTotal;
        FSaveCtx.CurDone := 0;
        FSaveCtx.CurStartTick := NowTick;
        FSaveCtx.LiveTick := NowTick;
        FSaveCtx.CurActive := True;
      end;
    pkTensorProg:
      begin
        if FSaveCtx.CurActive and (Info.TensorIdx = FSaveCtx.CurIdx) then
        begin
          FSaveCtx.CurDone := Info.TensorBytesDone;

          if Info.TensorBytesTotal > 0 then
            FSaveCtx.CurSize := Info.TensorBytesTotal;

          if (FSaveCtx.CurSize > 0) and (Info.TensorBytesDone >= FSaveCtx.CurSize) then
          begin
            CloseCurTensor(FormatBytes2f(Info.TensorBytesDone));
            FSaveCtx.CurActive := false;
          end;
        end;
      end;
    pkPartDone:
      begin
        CloseCurTensor('');
        LogLine(Format('--- Part %d/%d written : %s | global %d%% ---',//
         [Info.PartNo, Info.PartTot, FormatBytes2f(Info.PartBytes),//
         PctD(Info.GlobalBytesDone, Info.GlobalBytesTotal)]));
      end;
    pkInfo:
      begin
        if Info.Msg <> '' then
          LogLine(Info.Msg);
      end;
    pkDone:
      begin
        CloseCurTensor('');
      end;
    pkCancelled:
      begin
        CloseCurTensor('cancelled');
      end;
  end;

  // ---------------------------------------------------------------
  // 2) Mise à jour UI throttlée, sans accès direct depuis le thread
  // ---------------------------------------------------------------
  if not (Info.Kind in [pkDone, pkCancelled]) then
  begin
    if (NowTick - FLastSaveUIUpdateTick) < UI_REFRESH_MS then
      Exit;
  end;

  FLastSaveUIUpdateTick := NowTick;

  GlobalPct := PctD(Info.GlobalBytesDone, Info.GlobalBytesTotal);
  if GlobalPct > 99 then
    GlobalPct := 99;

  TensorPct := PctD(Info.TensorBytesDone, Info.TensorBytesTotal);
  if TensorPct > 99 then
    TensorPct := 99;

  if FSaveCtx.CurActive then
    Status := Format('Part %d/%d — %s (%d/%d)', [FSaveCtx.PartNo, FSaveCtx.PartTot, FSaveCtx.CurName, FSaveCtx.CurIdx, FSaveCtx.CurTot])
  else if Info.Msg <> '' then
    Status := Info.Msg
  else
    Status := mLang.gMsg('FTE.SavingInProgress');

  TThread.Queue(nil,
    procedure
    var
      LGlobalPct, LTensorPct: Integer;
      LStatus: string;
    begin
      if not Assigned(frmEditTensors) then
        Exit;

      LGlobalPct := GlobalPct;
      LTensorPct := TensorPct;
      LStatus := Status;

       ProgressBar1.Max := 100;
       ProgressBar1.Position := LGlobalPct;

       ProgressBar2.Max := 100;
       ProgressBar2.Position := LTensorPct;

       stBar1.Panels[0].Text := LStatus;
    end);
end;

procedure TfrmEditTensors.btnTransferAll1Click(Sender: TObject);
var
  i: Integer;
begin
  if not Assigned(FModelInp1) then
    Exit;
  if Assigned(FModelOut) then
    FreeAndNil(FModelOut);
  FModelOut := FModelInp1.Clone;
  // Mise à jour des infos SourceId pour le modèle de sortie
  for i := 0 to FModelOut.Tensors.Count - 1 do
  begin
    TGGUFTensorInfo(FModelOut.Tensors[i]).SourceId := SRC_MODEL1;
  end;
  frmEditTensorsRebuildViewOut;
  frmEditTensors.SetModelsToFrmViewAndFrmEditKVs;
end;

procedure TfrmEditTensors.btnTransferToOut1Click(Sender: TObject);
begin
  TransferSelectedTensorToOut(SRC_MODEL1, cbLayersFrom1, cbLayersTo1, cbLayersMod1, chkAllLayers1.Checked);
end;

procedure TfrmEditTensors.btnTransferToOut2Click(Sender: TObject);
begin
  TransferSelectedTensorToOut(SRC_MODEL2, cbLayersFrom2, cbLayersTo2, cbLayersMod2, chkAllLayers2.Checked);
end;

procedure TfrmEditTensors.btnTransferToOut3Click(Sender: TObject);
begin
  TransferSelectedTensorToOut(SRC_MODEL3, cbLayersFrom3, cbLayersTo3, cbLayersMod3, chkAllLayers3.Checked);
end;

procedure TfrmEditTensors.btnTransferToOutSClick(Sender: TObject);
begin
  TransferSelectedTensorToOut(SRC_MODELS, cbLayersFromS, cbLayersToS, cbLayersModS, chkAllLayersS.Checked);
end;

procedure TfrmEditTensors.btnTransposeClick(Sender: TObject);
begin
  frmEditTensorsDoTransposeActiveTensor;
end;

procedure TfrmEditTensors.btnTransferAll2Click(Sender: TObject);
var
  i: Integer;
begin
  if not Assigned(FModelInp2) then
    Exit;

  if Assigned(FModelOut) then
    FreeAndNil(FModelOut);

  FModelOut := FModelInp2.Clone;
  // Mise à jour des infos SourceId pour le modèle de sortie
  for i := 0 to FModelOut.Tensors.Count - 1 do
  begin
    TGGUFTensorInfo(FModelOut.Tensors[i]).SourceId := SRC_MODEL2;
  end;
  frmEditTensorsRebuildViewOut;
  frmEditTensors.SetModelsToFrmViewAndFrmEditKVs;
end;

procedure TfrmEditTensors.btnTransferAll3Click(Sender: TObject);
var
  i: Integer;
begin
  if not Assigned(FModelInp3) then
    Exit;

  if Assigned(FModelOut) then
    FreeAndNil(FModelOut);

  FModelOut := FModelInp3.Clone;
  // Mise à jour des infos SourceId pour le modèle de sortie
  for i := 0 to FModelOut.Tensors.Count - 1 do
  begin
    TGGUFTensorInfo(FModelOut.Tensors[i]).SourceId := SRC_MODEL3;
  end;
  frmEditTensorsRebuildViewOut;
  frmEditTensors.SetModelsToFrmViewAndFrmEditKVs;
end;

procedure TfrmEditTensors.btnTransferAllSClick(Sender: TObject);
var
  SrcMod: TGGUFFile;
  TCurrent: TGGUFTensorInfo;
  i, J: Integer;
  Found: Boolean;
begin
  SrcMod := frmEditTensors.FModelInpS;

  if not Assigned(SrcMod) then
    Exit;

  for i := 0 to SrcMod.Tensors.Count - 1 do
  begin
    TCurrent := TGGUFTensorInfo(SrcMod.Tensors[i]).Clone;
    TCurrent.SourceId := SRC_MODELS;
    // Ajout ou mise à jour dans ModelOut
    Found := false;
    for J := 0 to frmEditTensors.FModelOut.Tensors.Count - 1 do
    begin
      if SameText(string(TGGUFTensorInfo(frmEditTensors.FModelOut.Tensors[J]).Name), string(TCurrent.Name)) then
      begin
         FModelOut.Tensors[J] := TCurrent;
        Found := True;
        Break;
      end;
    end;
    if not Found then
       FModelOut.Tensors.Add(TCurrent);
  end;
  CalculateAllPatternSizes(frmEditTensors.FModelOut);
  frmEditTensorsRebuildViewOut;
  frmEditTensors.SetModelsToFrmViewAndFrmEditKVs;
end;

procedure TfrmEditTensors.btnShowMappedNames1Click(Sender: TObject);
begin
  FrmMappedNamesManager.cmbMappingFile.Text := cbMappedNames1.Text;
  FrmMappedNamesManager.Show;
end;

procedure TfrmEditTensors.btnShowMappedNames2Click(Sender: TObject);
begin
  FrmMappedNamesManager.cmbMappingFile.Text := cbMappedNames2.Text;
  FrmMappedNamesManager.Show;
end;

procedure TfrmEditTensors.btnShowMappedNames3Click(Sender: TObject);
begin
  FrmMappedNamesManager.cmbMappingFile.Text := cbMappedNames3.Text;
  FrmMappedNamesManager.Show;
end;

procedure TfrmEditTensors.btnShowMappedNamesSClick(Sender: TObject);
begin
  FrmMappedNamesManager.cmbMappingFile.Text := cbMappedNamesS.Text;
  FrmMappedNamesManager.Show;
end;

end.

