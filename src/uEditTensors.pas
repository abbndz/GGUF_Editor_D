unit uEditTensors;

interface

uses
  Windows, Messages, SysUtils, StrUtils, Classes, Controls, Forms, Dialogs, StdCtrls, ComCtrls, ExtCtrls, Graphics,
  Contnrs, uGGUFModel, uGGUFReader, uGGUFWriter, uGgmlQuants, uGGMLTypes, Generics.Collections, SyncObjs, ShellAPI,
  VCLTee.TeCanvas, uAppConfig, uSafeTensors, uTensorTranspose, uGgufStrUtils, uTensorsNamesMan, uGGMLConstants,
  uLangManager, uFrmAbout,
  Vcl.Menus, System.Actions, Vcl.ActnList;

type
  TfrmEditTensors = class(TForm)
    pnlTopInp0: TPanel;

    OpenDialog1: TOpenDialog;
    SaveDialog1: TSaveDialog;

    PageControl1: TPageControl;
    TabSheetModInA: TTabSheet;
    TabSheetModInB: TTabSheet;
    TabSheetModInS: TTabSheet;
    TabSheetModOut: TTabSheet;
    StatusBar1: TStatusBar;
    lvTensors1: TListView;
    lvTensors2: TListView;
    lvTensorsS: TListView;
    lvTensorsOut: TListView;
    ProgressBar1: TProgressBar;
    PanBotSize: TPanel;
    edtSizeOut: TEdit;
    edtSizeIn2: TEdit;
    edtSizeIn1: TEdit;
    PanBotEdit1: TPanel;
    PanBotEdit2: TPanel;
    PanBotEditOut: TPanel;

    lblName1: TLabel;
    lblName2: TLabel;
    lblNameOut: TLabel;
    edtName1: TEdit;
    edtName2: TEdit;
    edtNameOut: TEdit;

    cbDType1: TComboBox;
    cbDType2: TComboBox;
    cbDTypeOut: TComboBox;

    chkAllLayers1: TCheckBox;

    btnTransferToOut1: TButton;
    btnTransferToOut2: TButton;
    cbSrcModelOut1: TComboBox;
    pnlTopInp1: TPanel;
    pnlTopInp2: TPanel;
    pnlTopOut: TPanel;
    btnLoad1: TButton;
    btnBrowseSrc1: TButton;
    edtSrc1: TEdit;
    lblSrc1: TLabel;
    edtSrc2: TEdit;
    lblSrc2: TLabel;
    btnBrowseSrc2: TButton;
    btnLoad2: TButton;
    edtOut: TEdit;
    lblOut: TLabel;
    btnBrowseOut: TButton;
    chkUseDLL: TCheckBox;
    ProgressBar2: TProgressBar;
    btnSave: TButton;
    cbLayersFrom1: TComboBox;
    cbLayersTo1: TComboBox;
    cbLayersMod1: TComboBox;
    cbLayersMod2: TComboBox;
    cbLayersTo2: TComboBox;
    cbLayersFrom2: TComboBox;
    chkAllLayers2: TCheckBox;
    cbLayersModOut: TComboBox;
    cbLayersToOut: TComboBox;
    cbLayersFromOut: TComboBox;
    chkAllLayersOut: TCheckBox;

    PanBotEditS: TPanel;
    lblNameS: TLabel;
    edtNameS: TEdit;
    cbDTypeS: TComboBox;
    btnTransferToOutS: TButton;
    cbLayersModS: TComboBox;
    cbLayersToS: TComboBox;
    cbLayersFromS: TComboBox;
    chkAllLayersS: TCheckBox;
    pnlTopInpS: TPanel;
    lblSrcS: TLabel;
    edtSrcS: TEdit;
    btnBrowseSrcS: TButton;
    btnLoadS: TButton;
    btnTranspose: TButton;
    btnClearTransposition: TButton;
    edtSizeInS: TEdit;
    btnTransferAll1: TButton;
    btnTransferAll2: TButton;
    chkUseImpl: TCheckBox;
    btnViewTensor: TButton;
    btnViewMetaData: TButton;
    btnShowSetting: TButton;
    btnShowLogs: TButton;
    btnCancel: TButton;
    ActionList1: TActionList;
    ActBrowseSrcA1: TAction;
    ActBrowseSrcB2: TAction;
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
    Parcourir1: TMenuItem;
    ActLoadSrcA1: TAction;
    ActLoadSrcB2: TAction;
    ActLoadSrcS: TAction;
    ActBrowseOut: TAction;
    Charger1: TMenuItem;
    Parcourir2: TMenuItem;
    Charger2: TMenuItem;
    Parcourir3: TMenuItem;
    Charger3: TMenuItem;
    Parcourir4: TMenuItem;
    Save1: TMenuItem;
    MmLangue11: TMenuItem;
    btnClearFTextS: TButton;
    edtFilterS: TEdit;
    lbFilterS: TLabel;
    btnShowMappedNamesS: TButton;
    cbMappedNamesS: TComboBox;
    chkUseIgnoredPrefixesS: TCheckBox;
    btnClearFText1: TButton;
    edtFilter1: TEdit;
    lbFilter1: TLabel;
    btnShowMappedNames1: TButton;
    cbMappedNames1: TComboBox;
    chkUseIgnoredPrefixes1: TCheckBox;
    btnClearFText2: TButton;
    edtFilter2: TEdit;
    lbFilter2: TLabel;
    btnShowMappedNames2: TButton;
    cbMappedNames2: TComboBox;
    chkUseIgnoredPrefixes2: TCheckBox;
    btnClearFTextO: TButton;
    edtFilterO: TEdit;
    lbFilterOut: TLabel;
    btnTransferAllS: TButton;
    pmOutTensor: TPopupMenu;
    mnuSourceOut: TMenuItem;
    mnuQuant: TMenuItem;
    pmInputTensor: TPopupMenu;
    miTransferSelected: TMenuItem;
    miTransferAll: TMenuItem;
    mnuSourceOutM1: TMenuItem;
    mnuSourceOutM2: TMenuItem;
    mnuSourceOutM3: TMenuItem;

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
    procedure chkUseDLLClick(Sender: TObject);
    procedure cbDTypeOutChange(Sender: TObject);
    procedure lvTensorsOutAdvancedCustomDrawSubItem(Sender: TCustomListView; Item: TListItem; SubItem: Integer;
      State: TCustomDrawState; Stage: TCustomDrawStage; var DefaultDraw: Boolean);
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
    procedure lvTensorsSCustomDrawSubItem(Sender: TCustomListView; Item: TListItem; SubItem: Integer;
      State: TCustomDrawState; var DefaultDraw: Boolean);
    procedure btnClearFText2Click(Sender: TObject);
    procedure btnClearFText1Click(Sender: TObject);
    procedure btnShowMappedNamesSClick(Sender: TObject);
    procedure cbMappedNames2Change(Sender: TObject);
    procedure cbMappedNamesSChange(Sender: TObject);
    procedure chkUseIgnoredPrefixes2Click(Sender: TObject);
    procedure btnShowMappedNames2Click(Sender: TObject);
    procedure btnShowMappedNames1Click(Sender: TObject);
    procedure cbMappedNames1Change(Sender: TObject);
    procedure chkUseIgnoredPrefixes1Click(Sender: TObject);
    procedure btnTransferAll1Click(Sender: TObject);
    procedure btnTransferAll2Click(Sender: TObject);
    procedure chkUseImplClick(Sender: TObject);
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
    procedure lvTensors1AdvancedCustomDrawItem(Sender: TCustomListView; Item: TListItem; State: TCustomDrawState;
      Stage: TCustomDrawStage; var DefaultDraw: Boolean);
    procedure miTransferSelectedClick(Sender: TObject);
    procedure miTransferAllClick(Sender: TObject);
    procedure mnuSourceOutClick(Sender: TObject);
    procedure MenuQuantClick(Sender: TObject);

  private
    procedure WMDropFiles(var Msg: TWMDropFiles); message WM_DROPFILES;

  public

    FModelInp1: TGGUFFile;
    FModelInp2: TGGUFFile;
    FModelInpS: TGGUFFile;
    FModelOut: TGGUFFile;
    // preserve checkbox state even when filtering
    FViewTensors1: TObjectList;
    FViewTensors2: TObjectList;
    FViewTensorsS: TObjectList;
    FViewTensorsOut: TObjectList;

    FCurrentSourceList: TListView; // Pointe vers lvTensors1 ou lvTensors2
    FCurrentETName: TEdit;
    FCurrentcbDType: TComboBox;
    // Gestion d'annulation, progression & métriques
    FCancelSave: Boolean;
    FCancelMutex: TCriticalSection;
    FLastUIUpdateTick: Int64;
    FLastTensorIdx: Integer;
    FTensorStartTick: Int64;
    FCurBytesTensor: Int64;
    FLastTensorSize: Int64;
    FSaveRunning: Boolean;

    // Cache pour éviter de recalculer la taille totale à chaque ligne
    FGlobalSize1: Int64;
    FGlobalSize2: Int64;
    FGlobalSizeS: Int64;
    FGlobalSizeOut: Int64;

    // Gestionnaire du message de dépôt de fichier
    procedure OnProgressEventLoad(const Msg: string; AIdx, ATotal: Int64);
    procedure OnProgressEventSave(const Msg: string; ATensorIdx, ATensorTotal, AByteIdx, AByteTotal: Int64);

    procedure MenuLangueItemClick(Sender: TObject);

    destructor Destroy; override;
    procedure SetUiUseDLLImplFromCfg(var c: TGlobalConfig);
    procedure SetUseDLLCfgFromUi(e: Boolean);
    procedure SetUseImplCfgFromUi(e: Boolean);
    procedure SetUiFromCfg(var c: TGlobalConfig);
    procedure SetCfgFromUi(var c: TGlobalConfig);

  end;

procedure eLogMsg(const S: string; AIdx: Int64 = -1; ATotal: Int64 = -1);

var
  frmEditTensors: TfrmEditTensors;

implementation

uses uEditTensorsMan, uEditTensorsIO, uViewTensors, uEditKVsGGUF, uSplitMerge, uMappedNamesManager, uAppSetting, uLog,
  uEditArrayDlg;

{$R *.dfm}

procedure eLogMsg(const S: string; AIdx: Int64 = -1; ATotal: Int64 = -1);
begin
  TThread.Queue(nil,
    procedure
    begin
      if Assigned(frmEditTensors) then
      begin
        frmEditTensors.StatusBar1.Panels[0].Text := S;
        if (ATotal > -1) then
        begin
          frmEditTensors.ProgressBar1.Max := ATotal;
          frmEditTensors.ProgressBar1.Position := AIdx;
        end;
      end;
    end);
  // Logging fichier/debug
  if Assigned(frmLogs) then
    LogMsg('[EDIT]  ' + S)
  else
    OutputDebugString(PChar('[EDIT]  ' + S));
end;

procedure TfrmEditTensors.WMDropFiles(var Msg: TWMDropFiles);
var
  FileCount: Integer;
  FileName: array [0 .. MAX_PATH] of Char;
begin
  // Obtenir le nombre de fichiers déposés
  FileCount := DragQueryFile(Msg.Drop, $FFFFFFFF, nil, 0);
  if FileCount = 1 then
  begin
    DragQueryFile(Msg.Drop, 0, FileName, MAX_PATH);
    if TabSheetModOut = PageControl1.ActivePage then
    begin
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
    else if TabSheetModInS = PageControl1.ActivePage then
    begin
    if ActLoadSrcS.Enabled then
        frmEditTensorsActLoadSrcS3Execute(FileName);
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
  else if FCurrentSourceList = lvTensorsS then
    btnTransferAllSClick(btnTransferAllS);
end;

procedure TfrmEditTensors.miTransferSelectedClick(Sender: TObject);
begin
  if FCurrentSourceList = lvTensors1 then
    btnTransferToOut1Click(btnTransferToOut1)
  else if FCurrentSourceList = lvTensors2 then
    btnTransferToOut2Click(btnTransferToOut2)
  else if FCurrentSourceList = lvTensorsS then
    btnTransferToOutSClick(btnTransferToOutS);
end;

procedure TfrmEditTensors.mnuExitClick(Sender: TObject);
begin
  Close;
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
  cbDTypeOutChange(cbDTypeOut);
end;

procedure TfrmEditTensors.MenuLangueItemClick(Sender: TObject);

var
  SItem: TMenuItem;
  sCaption: String;
  ISOCode: string;
  i: Integer;
begin
  if Sender is TMenuItem then
  begin
    { sCaption := TMenuItem(Sender).Caption;
      if Pos('&', sCaption) > 0 then
      sCaption := StringReplace(sCaption, '&', '', [rfReplaceAll]);
      ISOCode := mLang.GetISOCodeByNativeLanguageName(sCaption);
      TranslateForms(ISOCode); }

    // TMenuItem(Sender).Checked := True;
    SItem := TMenuItem(Sender);
    // Met à jour les coches : décoche tout, coche l'élément cliqué
    // for i := 0 to MmLangue1.Items.Count - 1 do
    for i := 0 to mLang.GetLangCount - 1 do
    begin
      MmLangue11.Items[i].Checked := (MmLangue11.Items[i] = SItem);
    end;
    // Applique la traduction
    sCaption := SItem.Caption;
    if Pos('&', sCaption) > 0 then
      sCaption := StringReplace(sCaption, '&', '', [rfReplaceAll]);
    ISOCode := mLang.GetISOCodeByNativeLanguageName(sCaption);
    TranslateForms(ISOCode);
  end;
end;

destructor TfrmEditTensors.Destroy;
begin
  FreeAndNil(FViewTensors1);
  FreeAndNil(FViewTensors2);
  FreeAndNil(FViewTensorsS);
  FreeAndNil(FViewTensorsOut);
  FreeAndNil(FModelInp1);
  FreeAndNil(FModelInp2);
  FreeAndNil(FModelInpS);
  FreeAndNil(FModelOut);
  inherited;
end;

procedure TfrmEditTensors.edtFilter1Change(Sender: TObject);
begin
  frmEditTensorsRebuildView1;
end;

procedure TfrmEditTensors.edtFilter2Change(Sender: TObject);
begin
  frmEditTensorsRebuildView2;
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

procedure TfrmEditTensors.SetUiUseDLLImplFromCfg(var c: TGlobalConfig);
begin
  chkUseDLL.Checked := c.UseFDLL;
  chkUseImpl.Checked := c.UseFImpl;
  if Assigned(frmSettings) then
  begin
    frmSettings.chkUseDLL.Checked := c.UseFDLL;
    frmSettings.chkUseImpl.Checked := c.UseFImpl;
  end;
  if Assigned(frmViewTensors) then
  begin
    frmViewTensors.chkUseDLL.Checked := c.UseFDLL;
    frmViewTensors.chkUseImpl.Checked := c.UseFImpl;
  end;
end;

procedure TfrmEditTensors.SetUseDLLCfgFromUi(e: Boolean);
begin
  cfg.UseFDLL := e;
  chkUseDLL.Checked := cfg.UseFDLL;
  chkUseImpl.Enabled := not cfg.UseFDLL;
  if Assigned(frmSettings) then
  begin
    frmSettings.chkUseDLL.Checked := cfg.UseFDLL;
    frmSettings.chkUseImpl.Enabled := not cfg.UseFDLL;
  end;
  if Assigned(frmViewTensors) then
  begin
    frmViewTensors.chkUseDLL.Checked := cfg.UseFDLL;
    frmViewTensors.chkUseImpl.Enabled := not cfg.UseFDLL;
  end;
end;

procedure TfrmEditTensors.SetUseImplCfgFromUi(e: Boolean);
begin
  cfg.UseFImpl := e;
  chkUseImpl.Checked := cfg.UseFImpl;
  if Assigned(frmSettings) then
  begin
    frmSettings.chkUseImpl.Checked := cfg.UseFImpl;
  end;
  if Assigned(frmViewTensors) then
  begin
    frmViewTensors.chkUseImpl.Checked := cfg.UseFImpl;
  end;
end;

procedure TfrmEditTensors.SetUiFromCfg(var c: TGlobalConfig);
begin
  SetUiUseDLLImplFromCfg(c);
  edtSrc1.Text := c.edtSrc1;
  edtSrc2.Text := c.edtSrc2;
  edtSrcS.Text := c.edtSrcS;
  edtOut.Text := c.edtOut;

  edtFilter1.Text := c.edtFilter1;
  edtFilter2.Text := c.edtFilter2;
  edtFilterS.Text := c.edtFilterS;
  edtFilterO.Text := c.edtFilterO;

  chkUseIgnoredPrefixes1.Checked := c.UseIgnoredPrefixes1;
  chkUseIgnoredPrefixes2.Checked := c.UseIgnoredPrefixes2;
  chkUseIgnoredPrefixesS.Checked := c.UseIgnoredPrefixesS;

  cbMappedNames1.Text := c.MappingFile1;
  cbMappedNames2.Text := c.MappingFile2;
  cbMappedNamesS.Text := c.MappingFileS;
end;

procedure TfrmEditTensors.SetCfgFromUi(var c: TGlobalConfig);
begin
  c.edtSrc1 := edtSrc1.Text;
  c.edtSrc2 := edtSrc2.Text;
  c.edtSrcS := edtSrcS.Text;
  c.edtOut := edtOut.Text;

  c.edtFilter1 := edtFilter1.Text;
  c.edtFilter2 := edtFilter2.Text;
  c.edtFilterS := edtFilterS.Text;
  c.edtFilterO := edtFilterO.Text;

  c.UseIgnoredPrefixes1 := chkUseIgnoredPrefixes1.Checked;
  c.UseIgnoredPrefixes2 := chkUseIgnoredPrefixes2.Checked;
  c.UseIgnoredPrefixesS := chkUseIgnoredPrefixesS.Checked;

  c.MappingFile1 := cbMappedNames1.Text;
  c.MappingFile2 := cbMappedNames2.Text;
  c.MappingFileS := cbMappedNamesS.Text;
end;

procedure TfrmEditTensors.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  SetCfgFromUi(cfg);
  cfgSaveSettings(cfg);
  FreeAndNil(mLang);
  CloseLogFile;
end;

procedure TfrmEditTensors.FormCreate(Sender: TObject);
var
  CommandLineArg: string;
begin
  mLang := TLangManager.Create();
  InitLogFile;
  FModelInp1 := nil;
  FModelInp2 := nil;
  FModelOut := TGGUFFile.Create;

  FViewTensors1 := TObjectList.Create(False);
  FViewTensors2 := TObjectList.Create(False);
  FViewTensorsS := TObjectList.Create(False);
  FViewTensorsOut := TObjectList.Create(False);

  // Configuration ListView 1
  lvTensors1.ViewStyle := vsReport;
  lvTensors1.Checkboxes := False;
  lvTensors1.RowSelect := True;
  lvTensors1.ReadOnly := False;
  lvTensors1.OnSelectItem := lvTensorSelectItem;
  lvTensors1.Columns.Clear;

  with lvTensors1.Columns.Add do
  begin
    Caption := 'Tensor';
    Width := 160;
  end;
  with lvTensors1.Columns.Add do
  begin
    Caption := 'DType'; // 1
    Width := 48;
  end;
  with lvTensors1.Columns.Add do
  begin
    Caption := 'Shape'; // 2
    Width := 85;
  end;

  with lvTensors1.Columns.Add do
  begin
    Caption := 'Layer'; // 3
    Width := 26; // Affiche juste le numéro de couche (0, 1, 2...)
  end;
  with lvTensors1.Columns.Add do
  begin
    Caption := 'Size'; // 4
    Width := 64; // Taille du tenseur individuel
  end;
  with lvTensors1.Columns.Add do
  begin
    Caption := 'Size %'; // 5
    Width := 54; // Pourcentage par rapport au modèle total
  end;
  with lvTensors1.Columns.Add do
  begin
    Caption := 'TSize'; // 6 Total Size : taille cumulée sur toutes les couches
    Width := 64;
  end;
  with lvTensors1.Columns.Add do
  begin
    Caption := 'TSize %'; // 7
    Width := 55; // Pourcentage Total Size tenseur par rapport au modèle total
  end;
  with lvTensors1.Columns.Add do
  begin
    Caption := 'Off'; // 8
    Width := 0;
  end;
  with lvTensors1.Columns.Add do
  begin
    Caption := 'Src'; // 9
    Width := 25;
  end;
  with lvTensors1.Columns.Add do
  begin
    Caption := 'SrcDType'; // 10
    Width := 50;
  end;

  // Configuration ListView 2 (Héritage)
  lvTensors2.ViewStyle := vsReport;
  lvTensors2.Checkboxes := False;
  lvTensors2.RowSelect := True;
  lvTensors2.ReadOnly := True;
  lvTensors2.OnSelectItem := lvTensorSelectItem;
  lvTensors2.Columns.Assign(lvTensors1.Columns); // Reprend les mêmes colonnes

  lvTensorsS.ViewStyle := vsReport;
  lvTensorsS.Checkboxes := False;
  lvTensorsS.RowSelect := True;
  lvTensorsS.ReadOnly := False;
  lvTensorsS.OnSelectItem := lvTensorSelectItem;
  lvTensorsS.Columns.Assign(lvTensors1.Columns);

  // lvTensorsS.VirtualMode := True;
  // lvTensorsS.DoubleBuffered := True; // Élimine le flickering
  lvTensorsS.OnData := lvTensorsSData;

  // Configuration ListView Out
  lvTensorsOut.ViewStyle := vsReport;
  lvTensorsOut.Checkboxes := True;
  lvTensorsOut.RowSelect := True;
  lvTensorsOut.ReadOnly := True;
  lvTensorsOut.OnSelectItem := lvTensorSelectItem;
  lvTensorsOut.Columns.Assign(lvTensors1.Columns);

  frmEditTensorsFillDTypes;
  edtName1.ReadOnly := True;
  edtName2.ReadOnly := True;
  edtNameOut.ReadOnly := True;
  edtSizeIn1.ReadOnly := True;
  edtSizeIn2.ReadOnly := True;
  edtSizeInS.ReadOnly := True;
  edtSizeOut.ReadOnly := True;

  FCurrentSourceList := lvTensors1;
  FCurrentETName := edtName1;
  FCurrentcbDType := cbDType1;

  cbSrcModelOut1.ItemIndex := 0;
  edtSizeIn1.Text := '0 B';
  edtSizeIn2.Text := '0 B';
  edtSizeInS.Text := '0 B';
  edtSizeOut.Text := '0 B';

  cbMappedNames1.Items.Assign(GetAvailableMappedNames);
  cbMappedNames2.Items.Assign(cbMappedNames1.Items);
  cbMappedNamesS.Items.Assign(cbMappedNames1.Items);

  cbMappedNames1.Text := 'NoMappedNames';
  cbMappedNames2.Text := 'NoMappedNames';
  cbMappedNamesS.Text := 'NoMappedNames';

  FCancelSave := False;
  FCancelMutex := TCriticalSection.Create;
  FLastUIUpdateTick := 0;
  FLastTensorIdx := 0;
  FSaveRunning := False;
  FLastTensorSize := 0;
  FCurBytesTensor := 0;

  cfgLoadSettings(cfg);
  SetUiFromCfg(cfg);
  UpdateMenusLangs;
  CommandLineArg := ParamStr(1); // Récupère le chemin du fichier passé par Windows
  if (CommandLineArg <> '') and (FileExists(CommandLineArg)) then
  begin
    frmEditTensorsActLoadSrcA1Execute(CommandLineArg);
  end;
  DragAcceptFiles(Handle, True);
end;

procedure TfrmEditTensors.FormDestroy(Sender: TObject);
begin
  FreeAndNil(FCancelMutex);
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
    btnTransferToOut1.Enabled := False;
    btnTransferToOut2.Enabled := False;
    btnTransferToOutS.Enabled := False;
    cbDTypeOut.Enabled := True;
  end
  else if TabSheetModInA = PageControl1.ActivePage then
  begin
    cbDTypeOut.Enabled := False;
    btnTransferToOut1.Enabled := True;
    btnTransferToOut2.Enabled := False;
    btnTransferToOutS.Enabled := False;
    FCurrentSourceList := lvTensors1;
    FCurrentETName := edtName1;
    FCurrentcbDType := cbDType1;
  end
  else if TabSheetModInB = PageControl1.ActivePage then
  begin
    cbDTypeOut.Enabled := False;
    btnTransferToOut1.Enabled := False;
    btnTransferToOut2.Enabled := True;
    btnTransferToOutS.Enabled := False;
    FCurrentSourceList := lvTensors2;
    FCurrentETName := edtName2;
    FCurrentcbDType := cbDType2;
  end
  else if TabSheetModInS = PageControl1.ActivePage then
  begin
    cbDTypeOut.Enabled := False;
    btnTransferToOut1.Enabled := False;
    btnTransferToOut2.Enabled := False;
    btnTransferToOutS.Enabled := True;
    FCurrentSourceList := lvTensorsS;
    FCurrentETName := edtNameS;
    FCurrentcbDType := cbDTypeS;
  end;
end;

procedure TfrmEditTensors.lvTensors1AdvancedCustomDrawItem(Sender: TCustomListView; Item: TListItem;
State: TCustomDrawState; Stage: TCustomDrawStage; var DefaultDraw: Boolean);
begin
  if Item.Index mod 2 = 0 then
    Sender.Canvas.Brush.Color := $00F5F5F5
  else
    Sender.Canvas.Brush.Color := clWhite;
end;



procedure TfrmEditTensors.lvTensorSelectItem(Sender: TObject; Item: TListItem; Selected: Boolean);
var
  T: TGGUFTensorInfo;
  i: Integer;
begin
  if not Selected or (Item = nil) then
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
    if Assigned(T) and (T.SourceId in [1, 2, 3]) then
    begin
      cbSrcModelOut1.OnChange := nil;
      cbSrcModelOut1.ItemIndex := T.SourceId - 1;
      for i := 0 to frmEditTensors.cbSrcModelOut1.Items.Count - 1 do
        frmEditTensors.mnuSourceOut.Items[i].Checked := i = frmEditTensors.cbSrcModelOut1.ItemIndex;
      cbSrcModelOut1.OnChange := cbSrcModelOut1Change;
    end;
  end;
  frmEditTensorsRefreshEditorsForItem(Item);
end;

procedure TfrmEditTensors.lvTensorsOutAdvancedCustomDrawSubItem(Sender: TCustomListView; Item: TListItem;
SubItem: Integer; State: TCustomDrawState; Stage: TCustomDrawStage; var DefaultDraw: Boolean);

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
  else if (SubItem = 10) and (T.SourceId = 2) then
  begin
    Sender.Canvas.Font.Color := clBlue;
    Sender.Canvas.Font.Style := [fsBold];
  end
  else if (SubItem = 10) and (T.SourceId = 3) then
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

procedure TfrmEditTensors.lvTensorsOutItemChecked(Sender: TObject; Item: TListItem);

var
  T: TGGUFTensorInfo;
begin
  if Item = nil then
    Exit;
  if Item.Data = nil then
    Exit;
  lvTensorsOut.OnItemChecked := nil;
  T := Item.Data;
  // Item.Caption := string(T.Name);
  T.Keep := Item.Checked;
  if T.Keep then
    eLogMsg(mLang.gMsgFmt('FTE.TensorChecked', [string(T.Name)]))
  else
    eLogMsg(mLang.gMsgFmt('FTE.TensorUnchecked', [string(T.Name)]));
end;

{
  procedure TfrmEditTensors.lvTensorsSAdvancedCustomDrawItem(Sender: TCustomListView; Item: TListItem;
  State: TCustomDrawState; Stage: TCustomDrawStage; var DefaultDraw: Boolean);
  var
  T: TGGUFTensorInfo;
  R: TRect;
  begin
  // Si c'est un mode virtuel, l'item n'existe pas, on utilise l'index
  T := TGGUFTensorInfo(FViewTensorsS[Item.Index]);

  // On dessine la checkbox dans la première colonne (Col 0)
  R := Item.DisplayRect(drBounds);
  // R.Left := Item.BoundsRect.Left;
  R.Right := R.Left + 15; // Largeur de la checkbox

  // Dessin du cadre
  //DrawFrameControl(Sender.Canvas.Handle, R, DFC_BUTTON, DFCS_BUTTONPUSH or DFCS_MONO);

  // Dessin de la coche si T.Keep est True
  if T.Keep then
  begin
  R.Inflate(-1, -1);
  DrawFrameControl(Sender.Canvas.Handle, R, DFC_BUTTON, DFCS_CHECKED); //  or DFCS_MONO
  //Sender.Canvas.Font.Color := clWindowText;
  end;
  //DefaultDraw := True; // Laisse la VCL dessiner le texte
  end;

  procedure TfrmEditTensors.lvTensorsSClick(Sender: TObject);
  var
  T: TGGUFTensorInfo;

  Item: TListItem;
  begin
  Item := lvTensorsS.Selected;
  if (Item = nil) or (Item.Index < 0) then
  exit;
  T := TGGUFTensorInfo(FViewTensorsS[Item.Index]);
  T.Keep := not T.Keep; // Inverse l'état

  // Force le rafraîchissement visuel (redessine la coche)
  lvTensorsS.Invalidate;
  end;
}
procedure TfrmEditTensors.lvTensorsSCustomDrawSubItem(Sender: TCustomListView; Item: TListItem; SubItem: Integer;
State: TCustomDrawState; var DefaultDraw: Boolean);
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
  Item.SubItems.Add(TensorShapeText(T));

  if T.LayerIndex >= 0 then
    Item.SubItems.Add(IntToStr(T.LayerIndex))
  else
    Item.SubItems.Add('-');

  if T.IsConverted then
    DisplaySize := T.ByteSize
  else
    DisplaySize := T.ByteSizeOrg;
  Item.SubItems.Add(FormatBytes(DisplaySize));

  if GlobalSize > 0 then
  begin
    SizeP := (DisplaySize / GlobalSize) * 100;
    Item.SubItems.Add(Format('%.2f%%', [SizeP]));
  end
  else
    Item.SubItems.Add('0.00%');

  if T.LayerIndex >= 0 then
  begin
    Item.SubItems.Add(FormatBytes(T.PatternGlobalSize));
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
end;

procedure TfrmEditTensors.cbDTypeOutChange(Sender: TObject);

var
  i: Integer;
  SelectedT, T: TGGUFTensorInfo;
  TargetPattern, CurrentPattern: string;
  NewType: Integer;
  MatchPattern, MatchLayers: Boolean;
begin
  if FCurrentSourceList <> lvTensorsOut then
    Exit;
  SelectedT := GetActiveTensor;
  if not Assigned(SelectedT) then
    Exit;

  NewType := StrToGGMLType(cbDTypeOut.Text);
  if NewType < 0 then
    Exit;

  // eLogMsg('Application du type DType (conversion différée)...');
  eLogMsg(mLang.gMsg('FTE.DTypeConversionApplied'));

  TargetPattern := GetTensorPatternName(string(SelectedT.Name));

  for i := 0 to lvTensorsOut.Items.Count - 1 do
  begin
    T := TGGUFTensorInfo(lvTensorsOut.Items[i].Data);
    CurrentPattern := GetTensorPatternName(string(T.Name));
    MatchPattern := False;
    MatchLayers := False;

    if chkAllLayersOut.Checked then
    begin
      MatchPattern := SameText(CurrentPattern, TargetPattern);
      if MatchPattern then
        MatchLayers := MatchesLayerFilter(T.LayerIndex, cbLayersFromOut.Text, cbLayersToOut.Text,
          cbLayersModOut.Text, True);
    end
    else
    begin
      MatchPattern := (T = SelectedT);
      MatchLayers := True;
    end;

    if MatchPattern and MatchLayers then
    begin
      T.TensorType := NewType;
      T.IsConverted := True;
      T.ByteSize := GGML_TensorDataSize1(NewType, T.Dims);
      // T.ByteSizeOrg := T.ByteSize1; Attension pas ici
      // eLogMsg(Format('Marqué conversion : %s -> %s', [string(T.Name), GGMLTypeToStr(NewType)]));
      eLogMsg(mLang.gMsgFmt('FTE.ConversionMarked', [string(T.Name), GGMLTypeToStr(NewType)]));
    end;
  end;

  frmEditTensorsRebuildViewOut;
  // LogMsg('Application terminée.');
  eLogMsg(mLang.gMsg('FTE.ApplicationFinished'));
end;

procedure TfrmEditTensors.cbMappedNames1Change(Sender: TObject);
begin
  frmEditTensorsApplyMappedNames1(cbMappedNames1.Text);
end;

procedure TfrmEditTensors.cbMappedNames2Change(Sender: TObject);
begin
  frmEditTensorsApplyMappedNames2(cbMappedNames2.Text);
end;

procedure TfrmEditTensors.cbMappedNamesSChange(Sender: TObject);
begin
  frmEditTensorsApplyMappedNamesS(cbMappedNamesS.Text);
end;

procedure TfrmEditTensors.cbSrcModelOut1Change(Sender: TObject);
begin
  if Sender = cbSrcModelOut1 then
    frmEditTensorsUpdateOutTensorFromSource(cbSrcModelOut1.ItemIndex + 1, chkAllLayersOut.Checked);
  // 0 -> Modèle 1, 1 -> Modèle 2
end;

procedure TfrmEditTensors.chkAllLayers1Click(Sender: TObject);
begin
  frmEditTensorsEnableComboBoxFilter(cbLayersFrom1, cbLayersTo1, cbLayersMod1, chkAllLayers1.Checked);
end;

procedure TfrmEditTensors.chkAllLayers2Click(Sender: TObject);
begin
  frmEditTensorsEnableComboBoxFilter(cbLayersFrom2, cbLayersTo2, cbLayersMod2, chkAllLayers2.Checked);
end;

procedure TfrmEditTensors.chkAllLayersOutClick(Sender: TObject);
begin
  frmEditTensorsEnableComboBoxFilter(cbLayersFromOut, cbLayersToOut, cbLayersModOut, chkAllLayersOut.Checked);
end;

procedure TfrmEditTensors.chkAllLayersSClick(Sender: TObject);
begin
  frmEditTensorsEnableComboBoxFilter(cbLayersFromS, cbLayersToS, cbLayersModS, chkAllLayersS.Checked);
end;

procedure TfrmEditTensors.chkUseIgnoredPrefixes1Click(Sender: TObject);
begin
  cfg.UseIgnoredPrefixes1 := chkUseIgnoredPrefixes1.Checked;
  cfgSaveSettings(cfg);
  if Assigned(FModelInp1) then
  begin
    // frmEditTensorsRebuildView1; to do
    // frmEditTensorsRebuildViewOut;
    eLogMsg(mLang.gMsgFmt('PrefixFilterChanged', [IfThen(cfg.UseIgnoredPrefixes1, 'Activé', 'Désactivé')]));
  end;

end;

procedure TfrmEditTensors.chkUseIgnoredPrefixes2Click(Sender: TObject);
begin
  cfg.UseIgnoredPrefixes2 := chkUseIgnoredPrefixes2.Checked;
  cfgSaveSettings(cfg);
  if Assigned(FModelInp2) then
  begin
    // frmEditTensorsRebuildView2;
    // frmEditTensorsRebuildViewOut;
    eLogMsg(mLang.gMsgFmt('FTE.PrefixFilterChanged', [IfThen(cfg.UseIgnoredPrefixes2, 'Activé', 'Désactivé')]));
  end;
end;

procedure TfrmEditTensors.chkUseIgnoredPrefixesSClick(Sender: TObject);
begin
  cfg.UseIgnoredPrefixesS := chkUseIgnoredPrefixesS.Checked;
  cfgSaveSettings(cfg);
  if Assigned(FModelInpS) then
  begin
    // todo Le filtrage SafeTensors s'applique au chargement, pas en temps réel sur modèle déjà chargé
    // frmEditTensorsRebuildViewS;
    // frmEditTensorsRebuildViewOut;
    eLogMsg(mLang.gMsgFmt('FTE.PrefixFilterChanged', [IfThen(cfg.UseIgnoredPrefixesS, 'Activé', 'Désactivé')]));
  end;
end;

procedure TfrmEditTensors.chkUseDLLClick(Sender: TObject);
begin
  SetUseDLLCfgFromUi(chkUseDLL.Checked);
end;

procedure TfrmEditTensors.chkUseImplClick(Sender: TObject);
begin
  SetUseImplCfgFromUi(chkUseImpl.Checked);
end;

procedure TfrmEditTensors.btnCancelClick(Sender: TObject);
begin
  btnCancel.Enabled := False;
  if not FSaveRunning then
    Exit;
  // if MessageDlg('⚠️ Annuler la sauvegarde ?' + #13#10 + 'Le fichier en cours de création sera immédiatement supprimé.',
  // mtConfirmation, [mbYes, mbNo], 0) = mrNo then
  if MessageDlg(mLang.gMsg('FTE.ConfirmCancelSave'), mtConfirmation, [mbYes, mbNo], 0) = mrNo then
    Exit;

  FCancelMutex.Enter;
  try
    FCancelSave := True;
  finally
    FCancelMutex.Leave;
  end;

  // StatusBar1.Panels[0].Text := 'Interruption du writer...';
  eLogMsg(mLang.gMsg('FTE.OperationCancelled'));
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
begin
  if SaveDialog1.Execute then
    edtOut.Text := SaveDialog1.FileName;
end;

procedure TfrmEditTensors.ActBrowseSrcA1Execute(Sender: TObject);

var
  ssfn, ssfn0: String;
  i: Integer;
begin
  OpenDialog1.Filter := 'GGUF (*.gguf)|*.gguf|All (*.*)|*.*';
  if OpenDialog1.Execute then
  begin
    if (edtSrc1.Text <> OpenDialog1.FileName) and FileExists(OpenDialog1.FileName) then
    begin
      edtSrc1.Text := OpenDialog1.FileName;
      i := 1;
      ssfn0 := ChangeFileExt(OpenDialog1.FileName, '') + '_edited';
      ssfn := ssfn0 + IntToStr(i) + '.gguf';
      While FileExists(ssfn) do
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
begin
  OpenDialog1.Filter := 'GGUF (*.gguf)|*.gguf|All (*.*)|*.*';
  if OpenDialog1.Execute then
    if (edtSrc2.Text <> OpenDialog1.FileName) and FileExists(OpenDialog1.FileName) then
    begin
      edtSrc2.Text := OpenDialog1.FileName;
      ActLoadSrcB2Execute(Sender);
    end;
end;

procedure TfrmEditTensors.ActBrowseSrcSExecute(Sender: TObject);
begin
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

procedure TfrmEditTensors.ActLoadSrcSExecute(Sender: TObject);
begin
  frmEditTensorsActLoadSrcS3Execute(frmEditTensors.edtSrcS.Text);
end;

procedure TfrmEditTensors.ActSaveOutExecute(Sender: TObject);
begin
  frmEditTensorsActSaveOutExecute();
end;

procedure TfrmEditTensors.ActSettingsExecute(Sender: TObject);
begin
  if Not Assigned(frmSettings) then
    Application.CreateForm(TfrmSettings, frmSettings);
  frmSettings.Show;
end;

procedure TfrmEditTensors.ActShowLogsExecute(Sender: TObject);
begin
  if Not Assigned(frmLogs) then
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
  if frmEditKVsGGUF = nil then
    Application.CreateForm(TfrmEditKVsGGUF, frmEditKVsGGUF);
  try
    frmEditKVsGGUF.ModelA := FModelInp1;
    frmEditKVsGGUF.ModelB := FModelInp2;
    frmEditKVsGGUF.ModelOut := FModelOut;
    frmEditKVsGGUF.Show;
  finally
  end;
end;

procedure TfrmEditTensors.ActViewTensorsExecute(Sender: TObject);
begin
  if frmViewTensors = nil then
    Application.CreateForm(TfrmViewTensors, frmViewTensors);
  try
    frmViewTensors.ModelA := FModelInp1;
    frmViewTensors.ModelB := FModelInp2;
    frmViewTensors.ModelS := FModelInpS;
    frmViewTensors.ModelOut := FModelOut;
    frmViewTensors.UpdateFilterTypeItems;
    frmViewTensors.PopulateTensorList;
    frmViewTensors.Show;
  finally
  end;
end;

procedure TfrmEditTensors.OnProgressEventLoad(const Msg: string; AIdx, ATotal: Int64);
var
  CurrentUIUpdateTick, xx: Int64;
begin
  CurrentUIUpdateTick := GetTickCount64;
  xx := CurrentUIUpdateTick - FLastUIUpdateTick;
  if (xx < -1) then
    Exit;
  FLastUIUpdateTick := CurrentUIUpdateTick;
  eLogMsg(Msg, AIdx, ATotal);
end;

procedure TfrmEditTensors.OnProgressEventSave(const Msg: string; ATensorIdx, ATensorTotal, AByteIdx, AByteTotal: Int64);
var
  ElapsedMs: Int64;
  SpeedMBs: Double;
  CurrentUIUpdateTick: Int64;
begin
  // Throttle UI (~20Hz) pour éviter la surcharge de la file VCL
  // exit;
  CurrentUIUpdateTick := GetTickCount64;
  if (CurrentUIUpdateTick - FLastUIUpdateTick < 50) and (ATensorIdx = FLastTensorIdx) then
    Exit;
  FLastUIUpdateTick := CurrentUIUpdateTick;
  FLastTensorIdx := ATensorIdx;
  TThread.Synchronize(nil,
    procedure
    var
      SaveErr: String;
      aDiv: Integer;
      aPerc: Integer;
    begin
      try
        if not Assigned(frmEditTensors) then
          Exit;
        // Vérification annulation post-UI
        FCancelMutex.Enter;
        try
          if FCancelSave then
          begin // LogMsg('[SAVE] ⛔ Annulation détectée. Interruption immédiate...');
            eLogMsg(mLang.gMsg('FTE.SaveCancelledDetected'));
            Exit;
          end;
        finally
          FCancelMutex.Leave;
        end;
        // Changement de tenseur détecté
        if ATensorIdx <> FLastTensorIdx then
        begin
          if FLastTensorIdx > 0 then
          begin
            ElapsedMs := GetTickCount64 - FTensorStartTick;
            SpeedMBs := 0.0;
            if ElapsedMs > 0 then
              SpeedMBs := (FLastTensorSize / (1024.0 * 1024.0)) / (ElapsedMs / 1000.0);
            // LogMsg(Format('[SAVE] ✅ Tenseur %d/%d terminé en %s | ⚡ %.2f Mo/s', [FLastTensorIdx, ATensorTotal,FormatDurationMs(ElapsedMs), SpeedMBs]) + ', Size : ' + FormatBytes(FLastTensorSize));
            eLogMsg(mLang.gMsgFmt('FTE.SaveTensorFinished', [FLastTensorIdx, ATensorTotal, FormatDurationMs(ElapsedMs),
              SpeedMBs, FormatBytes(FLastTensorSize)]));
          end;

          FLastTensorIdx := ATensorIdx;
          FTensorStartTick := GetTickCount64;
          FCurBytesTensor := AByteIdx;
          FLastTensorSize := AByteTotal; // Taille du tenseur (envoyé par le writer)
          // LogMsg('[SAVE] ➡️ Début : ' + Msg);
          eLogMsg(mLang.gMsgFmt('FTE.SaveTensorStarted', [Msg]));
        end;

        FCurBytesTensor := AByteIdx;
        FLastTensorSize := AByteTotal;
        // UI Fluide
        ElapsedMs := GetTickCount64 - FTensorStartTick;
        aPerc := 0;
        if AByteTotal > 0 then
          aPerc := Trunc(AByteIdx / AByteTotal * 100);
        frmEditTensors.StatusBar1.Panels[0].Text := Format('%s | %d ', [Msg, aPerc]) + '%';
        frmEditTensors.ProgressBar2.Max := 100;
        frmEditTensors.ProgressBar2.Position := aPerc;

        aPerc := 0;
        if ATensorTotal > 0 then
          aPerc := Trunc(ATensorIdx / ATensorTotal * 100);
        frmEditTensors.ProgressBar1.Max := 100;
        frmEditTensors.ProgressBar1.Position := aPerc;

      except
        on e: Exception do
          SaveErr := e.Message;

      end;

    end);
end;

procedure TfrmEditTensors.btnTransferAll1Click(Sender: TObject);
var
  i: Integer;
begin
  if Assigned(FModelOut) then
    FreeAndNil(FModelOut);
  FModelOut := FModelInp1.Clone;
  // Mise à jour des infos SourceId pour le modèle de sortie
  for i := 0 to FModelOut.Tensors.Count - 1 do
  begin
    TGGUFTensorInfo(FModelOut.Tensors[i]).SourceId := 1;
  end;
  frmEditTensorsRebuildViewOut;
end;

procedure TfrmEditTensors.btnTransferToOut1Click(Sender: TObject);
begin
  TransferSelectedTensorToOut(1, cbLayersFrom1, cbLayersTo1, cbLayersMod1, chkAllLayers1.Checked);
end;

procedure TfrmEditTensors.btnTransferToOut2Click(Sender: TObject);
begin
  TransferSelectedTensorToOut(2, cbLayersFrom2, cbLayersTo2, cbLayersMod2, chkAllLayers2.Checked);
end;

procedure TfrmEditTensors.btnTransferToOutSClick(Sender: TObject);
begin
  TransferSelectedTensorToOut(3, cbLayersFromS, cbLayersToS, cbLayersModS, chkAllLayersS.Checked);
end;

procedure TfrmEditTensors.btnTransposeClick(Sender: TObject);
begin
  frmEditTensorsDoTransposeActiveTensor;
end;

procedure TfrmEditTensors.btnTransferAll2Click(Sender: TObject);
var
  i: Integer;
begin
  if Assigned(FModelOut) then
    FreeAndNil(FModelOut);
  FModelOut := FModelInp2.Clone;
  // Mise à jour des infos SourceId pour le modèle de sortie
  for i := 0 to FModelOut.Tensors.Count - 1 do
  begin
    TGGUFTensorInfo(FModelOut.Tensors[i]).SourceId := 2;
  end;
  frmEditTensorsRebuildViewOut;
end;

procedure TfrmEditTensors.btnTransferAllSClick(Sender: TObject);
var
  SrcMod: TGGUFFile;
  SrcLV: TListView;
  TCurrent: TGGUFTensorInfo;
  i, J, SourceId: Integer;
  Found: Boolean;
  MatchName: Boolean;
begin
  SrcMod := frmEditTensors.FModelInpS;
  if not Assigned(SrcMod) then
    Exit;

  for i := 0 to SrcMod.Tensors.Count - 1 do
  begin
    TCurrent := TGGUFTensorInfo(SrcMod.Tensors[i]).Clone;
    TCurrent.SourceId := 3;
    // Ajout ou mise à jour dans ModelOut
    Found := False;
    for J := 0 to frmEditTensors.FModelOut.Tensors.Count - 1 do
    begin
      if SameText(string(TGGUFTensorInfo(frmEditTensors.FModelOut.Tensors[J]).Name), string(TCurrent.Name)) then
      begin
        frmEditTensors.FModelOut.Tensors[J] := TCurrent;
        Found := True;
        Break;
      end;
    end;
    if not Found then
      frmEditTensors.FModelOut.Tensors.Add(TCurrent);
  end;
  CalculateAllPatternSizes(frmEditTensors.FModelOut);
  frmEditTensorsRebuildViewOut;
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

procedure TfrmEditTensors.btnShowMappedNamesSClick(Sender: TObject);
begin
  FrmMappedNamesManager.cmbMappingFile.Text := cbMappedNamesS.Text;
  FrmMappedNamesManager.Show;
end;

end.
