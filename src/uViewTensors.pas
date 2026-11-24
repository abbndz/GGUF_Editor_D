unit uViewTensors;

interface

uses
  Winapi.Windows, Winapi.Messages, Winapi.CommCtrl, System.SysUtils,
  System.Variants, System.Classes, Vcl.Graphics, Vcl.Controls, Vcl.Forms,
  Vcl.Dialogs, Vcl.ExtCtrls, VclTee.TeeProcs, VclTee.TeEngine, VclTee.Chart,
  VclTee.Series, Vcl.StdCtrls, Vcl.CheckLst, Vcl.ComCtrls, Generics.Collections,
  VclTee.TeeGDIPlus, SyncObjs, System.Threading, System.Diagnostics,
  uMMAPReader, uGGUFModel, uGGMLTypes, uGgmlQuants,
  uAppConfig, uRangeSlider, uQuantPresetConfig, uMath, uGGMLConstants, uStrUtils,
  uLog, uViewTensorsChart, uDiffStats;

type
  TfrmViewTensors = class(TForm)
    PanelTop: TPanel;
    SaveDialog1: TSaveDialog;
    stBar1: TStatusBar;
    PanelLeft: TPanel;
    PanelLeftBot2: TPanel;
    PanelLeftTop: TPanel;
    ChListBoxTensors: TCheckListBox;
    pnlFilters: TPanel;
    cbFilterV: TComboBox;
    chkM1: TCheckBox;
    chkM2: TCheckBox;
    chkM3: TCheckBox;
    chkMOut: TCheckBox;
    chkT1vT2: TCheckBox;
    pnlBase00: TPanel;
    pnlBaseBot0: TPanel;
    pnlBaseBotLeft: TPanel;
    PageControl1: TPageControl;
    TabGraph: TTabSheet;
    Chart1: TChart;
    PanChart1Top: TPanel;
    edtYMax: TEdit;
    edtYMin: TEdit;
    chkYAxisAuto: TCheckBox;
    btnApply: TButton;
    edtXMax: TEdit;
    edtXMin: TEdit;
    chkXAxisAuto: TCheckBox;
    TabHist: TTabSheet;
    Chart2: TChart;
    PanChart2Top: TPanel;
    btnHistogramFast: TButton;
    Splitter3: TSplitter;
    Splitter4: TSplitter;
    ProgressBar1: TProgressBar;
    ProgressBar2: TProgressBar;
    lvSeries: TListView;
    PanelLeftBot1: TPanel;
    btnClearAllSelected: TButton;
    Label1: TLabel;
    btnResetZoom: TButton;
    btnZoomOut: TButton;
    btnZoomIn: TButton;
    btnNavRight: TButton;
    btnNavLeft: TButton;
    pnlBaseBotSlider: TPanel;
    pnlRangeSlider1: TPanel;
    chkMS: TCheckBox;
    cbNbrSelect: TComboBox;
    chkT1dT2: TCheckBox;
    chkUseMAD: TCheckBox;
    edtNstep: TEdit;
    edtRdelta: TEdit;
    edtRmin: TEdit;
    edtQpSteps: TEdit;
    edtQpStep: TEdit;
    edtQCIter: TEdit;
    btnToggleSection: TButton;

    cbDTypeOut: TComboBox;
    cbUseImpl: TComboBox;
    cbRmseType: TComboBox;

    FSliderTimer: TTimer;
    btnHistogramFull: TButton;
    btnHistogramCancel: TButton;
    lblUseImpl: TLabel;
    btnRestoreQuantPreset: TButton;
    edtRadiusLm: TEdit;
    edtRadiusLs: TEdit;

    chkVAuto: TCheckBox;
    chkCntAuto: TCheckBox;
    edtCntMin: TEdit;
    edtCntMax: TEdit;
    edtValMax: TEdit;
    edtValMin: TEdit;
    edtWinMax: TEdit;
    edtWinMin: TEdit;

    procedure chkVAutoClick(Sender: TObject);

    procedure SetUiFromCfg(var c: TGlobalConfig);
    procedure SetCfgFromUi(var c: TGlobalConfig);

    procedure ApplyRmseFromEdit(AType, UseImpl, RmseType: Integer; const ATargetT: TGGUFTensorInfo);

    procedure SetTargetEnabled(AOn: Boolean);
    procedure UpdateUIFromQuantPreset(const P: PQuantPreset);
    procedure UpdateQuantPresetFromUI(const P: PQuantPreset);

    procedure FormCreate(Sender: TObject);
    procedure btnResetZoomClick(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure btnApplyClick(Sender: TObject);
    procedure btnHistogramFastClick(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);

    procedure UpdateYAxisRangeFromEdit;
    procedure UpdateXAxisRangeFromEdit;
    procedure SliderChange(Sender: TObject);

    // Navigation Boutons
    procedure btnNavLeftClick(Sender: TObject);
    procedure btnNavRightClick(Sender: TObject);
    procedure btnZoomInClick(Sender: TObject);
    procedure btnZoomOutClick(Sender: TObject);

    // Configuration Axis
    procedure chkYAxisAutoClick(Sender: TObject);
    procedure SetedtYMinedtYMaxValus(Mn, Mx: Double);

    // Clavier
    procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);

    // Souris (Drag & Zoom)
    procedure Chart1MouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure Chart1MouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure Chart1MouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure Chart1MouseWheelUp(Sender: TObject; Shift: TShiftState; MousePos: TPoint; var Handled: Boolean);
    procedure Chart1MouseWheelDown(Sender: TObject; Shift: TShiftState; MousePos: TPoint; var Handled: Boolean);
    procedure Chart1UndoZoom(Sender: TObject);

    // NOUVEAUX EVENTS X-Axis
    procedure chkXAxisAutoClick(Sender: TObject);
    procedure btnClearAllSelectedClick(Sender: TObject);
    procedure chkT1vT2Click(Sender: TObject);
    procedure ChListBoxTensorsClickCheck(Sender: TObject);
    procedure lvSeriesAdvancedCustomDrawItem(Sender: TCustomListView; Item: TListItem; State: TCustomDrawState; Stage: TCustomDrawStage; var DefaultDraw: Boolean);
    procedure cbFilterVChange(Sender: TObject);
    procedure chkMOutClick(Sender: TObject);
    procedure edtXMinKeyPress(Sender: TObject; var Key: Char);
    procedure edtYMinKeyPress(Sender: TObject; var Key: Char);
    procedure FormDestroy(Sender: TObject);
    procedure ClearRenderLists;
    procedure DetachModels;

    procedure cbNbrSelectChange(Sender: TObject);
    procedure chkT1dT2Click(Sender: TObject);
    procedure btnToggleSectionClick(Sender: TObject);
    procedure cbUseImplClick(Sender: TObject);
    procedure ProgressBar1MouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure FSliderTimerTimer(Sender: TObject);
    procedure btnHistogramFullClick(Sender: TObject);
    procedure btnHistogramCancelClick(Sender: TObject);

    procedure edtNstepKeyPress(Sender: TObject; var Key: Char);
    procedure cbRmseTypeClick(Sender: TObject);
    procedure btnRestoreQuantPresetClick(Sender: TObject);
    procedure cbDTypeOutClick(Sender: TObject);
    procedure chkCntAutoClick(Sender: TObject);
    procedure edtCntMinKeyPress(Sender: TObject; var Key: Char);
    procedure edtValMinKeyPress(Sender: TObject; var Key: Char);
    procedure FormResize(Sender: TObject);

  public
    FModel1: TGGUFFile;
    FModel2: TGGUFFile;
    FModel3: TGGUFFile;
    FModelS: TGGUFFile;
    FModelOut: TGGUFFile;
    FUpdatingXAxis: Boolean;

    FCancelThread: Boolean;
    FBusy: Boolean; // verrou anti-réentrance
    FchkClick: Boolean; // verrou anti-réentrance
    FClosing: Boolean;

    FWorkKind: Integer; // 0 = graphe, 1 = histogramme
    FWorkTotal, FWorkDone: Int64; // progression globale
    FWorkLabel: string; // sous-titre (nFormCreateom du tenseur)
    // CHAMPS POUR LA NAVIGATION ---
    FCurrentStartIdx, FCurrentEndIdx: Int64;
    FGlobalMaxElems: Int64;
    FLastUViewIUpdateTick: Int64;
    // CHAMPS POUR NAVIGATION SOURIS CUSTOM
    FIsDragging: Boolean;
    FDragStartX: Integer;
    FDragStartMinX, FDragStartMaxX: Double;

    FRangeSlider: TRangeSlider;
    FSelectionOrder: TList<Integer>; // Garde l'ordre des tenseurs sélectionnés
    FSelOutTensor: TGGUFTensorInfo;

    //FUpdatingHistoX: Boolean; // verrou anti-réentrance axe X Histo
    FUpdatingChecks: Boolean;

    // ---- arbitrage des rendus (graphe <-> histogramme) ----
    FRenderGen: Integer; // jeton unique des 2 jobs
    FPendKind: Integer;
    FPendS, FPendE: Int64;
    FPendForce: Boolean;
    FPendFull: Boolean;

	  FHistVMinMan, FHistVMaxMan: Double; // la MESURE (distincte de la fenetre appliquee)
    FHistDetOk: Boolean;
    FHistDetS, FHistDetE: Int64; // zone a laquelle la mesure s'applique
    FHistPeak: Int64; // pic de comptes du dernier rendu

    // les 5 procedures ci-dessous remplacent UpdateXAxisRangeFromEditHisto /
    FHistQuiet: Boolean;
    procedure SetVAutoQuiet(AOn: Boolean);

    procedure HistoCommitWindow; // edits -> etat (+cfg) ; NE regenere PAS
    procedure HistoShowWindow; // etat -> edits ; gardee sous FUpdatingHistWin
    procedure HistoApplyCountsAxis; // Chart2.LeftAxis + edtCnt* (0 en bas, pas *1.025)
    procedure RefreshActiveView(Force: Boolean = False);

    procedure PubPopulateTensorList();

    procedure ApplyProgress(ADone, ATotal: Int64; ALocalPct: Int64 = 0; const ALabel: string = '');

    procedure SetProgress(ADone, ATotal: Int64; ALocalPct: Int64 = 0; const ALabel: string = '');
    function IsCancelRequested: Boolean;

    procedure PubRefreshChart(ForceFullRange: Boolean = False);
    procedure AddSeriesToListView(const ATitle: string; AColor: TColor);

    procedure UpdateStatusBarDiffStats(const Stats: TDiffStats; ElapsedMs: Int64);

    procedure UpdateRmseControlsState;
    procedure SetEnableRmseTypeAll(e: Boolean);
    // RELOAD : registre -> UI. AType = GGML type, UseImpl = index combo.
    // RmseType in/out : valeur efficace retenue (preset si tuning, sinon valeur passée).
    procedure BindOutPresetToUI(AType, UseImpl: Integer; var RmseType: Integer);

    // WRITE : UI edt*+cbRmseType -> registre (identité courante). False si pas de preset.
    function PresetOf(AType, UseImpl: Integer): PQuantPreset;
    procedure LoadPresetToUI(AType, UseImpl: Integer); // REGISTRE -> UI
    procedure SavePresetToReg(AType, UseImpl: Integer); // UI -> REGISTRE
    function CurRmseFor(AType, UseImpl: Integer): Integer; // preset si tuning, sinon UI
    procedure QP_SetRmsePreset(AType, UseImpl, RmseType: Integer);

    function IsUIMainThread: Boolean;

    function RequestRender(AKind: Integer; AStar, AEnd: Int64;
      AForceFull, AFullPass: Boolean): Boolean;
    procedure EndRender;
    property RenderGen: Integer read FRenderGen;
  end;

const
  RK_NONE = 0;
  RK_CHART = 1;
  RK_HISTO = 2;

procedure vLogMsg(const S: string; LogToStatusBar: Boolean = False; Level: TLogLevel = lvInfo);

var
  frmViewTensors: TfrmViewTensors;
  GMainThreadID: TThreadID;

implementation

uses
  uEditTensors, uViewTensorsListMan, uViewTensorsHisto,
  uEditTensorsMan, uEditTensorsView, uLangManager;

{$R *.dfm}

function TfrmViewTensors.IsUIMainThread: Boolean;
begin
  Result := TThread.CurrentThread.ThreadID = GMainThreadID;
end;

function TfrmViewTensors.RequestRender(AKind: Integer; AStar, AEnd: Int64;
  AForceFull, AFullPass: Boolean): Boolean;
begin
  Result := False;
  if FClosing or (csDestroying in ComponentState) then
    Exit;
  if FBusy then
    begin
      // un rendu (graphe OU histo) tourne : on l'annule et on ne garde QUE la
      // derniere demande, typisee -> fin du "l'histo tue le graphe sans retour"
      FCancelThread := True;
      Inc(FRenderGen);
      FPendKind := AKind;
      FPendS := AStar;
      FPendE := AEnd;
      FPendForce := AForceFull;
      FPendFull := AFullPass;
      Exit;
    end;
  FBusy := True;
  FCancelThread := False;
  FWorkKind := Ord(AKind = RK_HISTO);
  FWorkTotal := 0;
  FWorkDone := 0;
  FLastUViewIUpdateTick := 0;
  Inc(FRenderGen);
  ProgressBar1.Visible := True;
  ProgressBar1.Position := 0;
  ProgressBar2.Visible := True;
  ProgressBar2.Position := 0;
  if AKind = RK_HISTO then
    btnHistogramCancel.Enabled := True;
  Result := True;
end;

procedure TfrmViewTensors.EndRender;
var
  WasBusy: Boolean;
  k: Integer;
  s, e: Int64;
  f, fp: Boolean;
begin
  WasBusy := FBusy;
  FBusy := False;

  if not FClosing then
    FCancelThread := False;

  if (ProgressBar1 <> nil) and not (csDestroying in ComponentState) then
    ProgressBar1.Visible := False;

  if (ProgressBar2 <> nil) and not (csDestroying in ComponentState) then
    ProgressBar2.Visible := False;

  if (btnHistogramCancel <> nil) and not (csDestroying in ComponentState) then
    btnHistogramCancel.Enabled := False;

  if FClosing then
    FPendKind := RK_NONE;

  if not WasBusy then
    Exit;

  if frmViewTensors = nil then Exit;
  if (FPendKind <> RK_NONE) and not FClosing and
     not (csDestroying in ComponentState) then
    begin
      k := FPendKind;
      s := FPendS;
      e := FPendE;
      f := FPendForce;
      fp := FPendFull;
      FPendKind := RK_NONE;
      if k = RK_CHART then
        begin
          RefreshChart(f)
        end
      else
        GenerateHistogram(fp);
    end;
end;

procedure TfrmViewTensors.PubPopulateTensorList();
begin
  vtUpdateFilterTypeItems;
  vtPopulateTensorList;
end;

procedure vLogMsg(const S: string; LogToStatusBar: Boolean = False; Level: TLogLevel = lvInfo);
begin
  if LogToStatusBar then
    TThread.Queue(nil,
      procedure
      begin
        if (frmViewTensors = nil) or (frmViewTensors.stBar1 = nil) then
          Exit;
        frmViewTensors.stBar1.Panels[0].Text := S;
      end);

  if Assigned(frmLogs) then
    LogMsg(S, Level)
  // LogMsg('[VIEW]  ' + S)
  else
    OutputDebugString(PChar('[VIEW]  ' + S));
end;

procedure TfrmViewTensors.ApplyProgress(ADone, ATotal: Int64; ALocalPct: Int64 = 0; const ALabel: string = '');
var
  GlobalPct: Int64;
begin
  if (not Assigned(ProgressBar1)) or (not ProgressBar1.Visible) then
    Exit;

  // 1. PROGRESSION INDIVIDUELLE (ProgressBar2)
  // Elle représente l'avancement du tenseur en cours
  ProgressBar2.Position := ALocalPct;

  // 2. PROGRESSION GLOBALE (ProgressBar1)
  // On calcule : (Tenseurs terminés + fraction du tenseur actuel) / Total
  // Formule : ((FWorkDone / FWorkTotal) + (ALocalPct / 100 * 1/FWorkTotal)) * 100
  if FWorkTotal > 0 then
    begin
      // Calcul de la progression globale pondérée pour un mouvement fluide
      // On ajoute la contribution du tenseur actuel au ratio global
      if (FWorkKind = 1) and (FWorkTotal = 1) then
      begin
        stBar1.Panels[0].Text := Format('HIST : %s [%d/%d] - %d %%', [ALabel, ADone, ATotal, ALocalPct ]);
        ProgressBar1.Position := ALocalPct;
      end
      else
      begin
        stBar1.Panels[0].Text := Format('CHART : %s [%d/%d] - %d %%', [ALabel, FWorkDone, FWorkTotal, ALocalPct ]);
        GlobalPct := Round(((FWorkDone * 100 / FWorkTotal) + ((ALocalPct * 1.0 / 100.0) * (1.0 / FWorkTotal)) * 100));
        if GlobalPct > 100 then
        GlobalPct := 100;
        ProgressBar1.Position := GlobalPct;
      end;


    end;
end;

procedure TfrmViewTensors.SetProgress(ADone, ATotal: Int64; ALocalPct: Int64 = 0; const ALabel: string = '');
var
  CurrentUIUpdateTick, xx: Int64;
begin
  CurrentUIUpdateTick := GetTickCount64;
  xx := CurrentUIUpdateTick - FLastUViewIUpdateTick;
  if (xx < 100) then // Réduit à 100ms pour plus de fluidité
    Exit;
  FLastUViewIUpdateTick := CurrentUIUpdateTick;

  if IsUIMainThread then
    ApplyProgress(ADone, ATotal, ALocalPct, ALabel)
  else
    TThread.Queue(nil,
      procedure
      begin
        ApplyProgress(ADone, ATotal, ALocalPct, ALabel);
        //LogN('[ApplyProgress] %s ADone=%d | ATotal=%d ALocalPct=%d ', [ALabel, ADone, ATotal,  ALocalPct]);
      end);
end;

function TfrmViewTensors.IsCancelRequested: Boolean;
begin
  Result := FCancelThread;
end;

// CONFIGURATION & INIT
procedure TfrmViewTensors.SetUiFromCfg(var c: TGlobalConfig);
begin
  FHistQuiet  := True;
  FUpdatingXAxis := True;

  TCombo_SetSel(cbUseImpl, c.UseImpl);
  TCombo_SetSel(cbRmseType, c.RmseType);
  c.UseImpl := cbUseImpl.ItemIndex;
  c.RmseType := cbRmseType.ItemIndex;


  cbFilterV.Text := c.cbFilterV;
  chkYAxisAuto.Checked := c.chkYAxisAuto;

  SetedtYMinedtYMaxValus(c.YAxisMinMan1, c.YAxisMaxMan);
  chkXAxisAuto.Checked := c.chkXAxisAuto1;

  chkVAuto.Checked := c.bHistVAuto;
  chkCntAuto.Checked := c.bHistNAuto;

  //TEdit_WriteFloat(edtValMin, c.HistVMinMan);
  //TEdit_WriteFloat(edtValMax, c.HistVMaxMan);
  edtValMin.Text := '--';
  edtValMax.Text := '--';

  FHistDetOk := False;
  TEdit_WriteInt64(edtCntMin, c.HistNMinMan);
  TEdit_WriteInt64(edtCntMax, c.HistNMaxMan);
  HistoShowWindow;

  edtWinMin.Enabled := not c.bHistVAuto;
  edtWinMin.ReadOnly := c.bHistVAuto;
  edtWinMax.Enabled := not c.bHistVAuto;
  edtWinMax.ReadOnly := c.bHistVAuto;

  edtCntMin.Enabled := not c.bHistNAuto;
  edtCntMin.ReadOnly := c.bHistNAuto;
  edtCntMax.Enabled := not c.bHistNAuto;
  edtCntMax.ReadOnly := c.bHistNAuto;


  cbNbrSelect.Text := c.sTensorsPerChart;
  chkT1vT2.Checked := c.chkT1sT2;
  chkT1dT2.Checked := c.chkT1dT2;
  edtXMin.Text := IntToStr(c.XStartIdxMan);
  edtXMax.Text := IntToStr(c.XEndIdxMan);

  FUpdatingXAxis := False;
  FHistQuiet  := False;
end;

procedure TfrmViewTensors.SetCfgFromUi(var c: TGlobalConfig);
var sTensorsPerChart: string;
begin
  c.cbFilterV := cbFilterV.Text;

  c.chkYAxisAuto := chkYAxisAuto.Checked;

  c.YAxisMinMan1 := TEdit_ReadFloat(edtYMin, -0.5);
  c.YAxisMaxMan := TEdit_ReadFloat(edtYMax, 0.5);

  c.chkXAxisAuto1 := chkXAxisAuto.Checked;

  c.bHistVAuto := chkVAuto.Checked;
  c.bHistNAuto := chkCntAuto.Checked;
  c.HistNMinMan := TEdit_ReadInt64(edtCntMin, c.HistNMinMan);
  c.HistNMaxMan := TEdit_ReadInt64(edtCntMax, c.HistNMaxMan);
  c.sTensorsPerChart := cbNbrSelect.Text;
  sTensorsPerChart := UpperCase(c.sTensorsPerChart);
  c.iTensorsPerChart := ParseTensorsPerChart(c.sTensorsPerChart);

  c.chkT1sT2 := chkT1vT2.Checked;
  c.chkT1dT2 := chkT1dT2.Checked;
  // c.HistModeFull := chkHistFull.Checked; // ne pas l'activer , activation manuelle une fois seullement !

  // S'assurer que les valeurs sont des Int64 corrects
  c.XStartIdxMan := StrToInt64Def(edtXMin.Text, 0);
  c.XEndIdxMan := StrToInt64Def(edtXMax.Text, 1024);
end;

// Appelé par frmEditTensors : écrit le registre pour (Type,Profil) ; ne touche la vue QUE si c'est la MÊME cible
procedure TfrmViewTensors.ApplyRmseFromEdit(AType, UseImpl, RmseType: Integer; const ATargetT: TGGUFTensorInfo);
var
  P: PQuantPreset;
begin
  P := PresetOf(AType, UseImpl);
  if Assigned(P) then
    begin
      if efRmseType in P.EnabledFields then
        P.RmseType := RmseType;
    end;

  if (FSelOutTensor <> nil) and (FSelOutTensor = ATargetT) then
    begin
      TCombo_SetSel(cbUseImpl, UseImpl);
      FSelOutTensor.UseImpl := UseImpl;
      TCombo_SetSel(cbRmseType, RmseType);
      FSelOutTensor.RmseType := RmseType;
      LoadPresetToUI(FSelOutTensor.TensorType, FSelOutTensor.UseImpl);
    end;
  // sinon : la vue garde SA cible ; elle relira le preset à sa prochaine sélection
end;

procedure TfrmViewTensors.SetTargetEnabled(AOn: Boolean);
begin
  cbDTypeOut.Enabled := AOn;
  cbUseImpl.Enabled := AOn;
  // btnApply.Enabled := AOn;
  btnRestoreQuantPreset.Enabled := AOn;
end;

procedure TfrmViewTensors.UpdateUIFromQuantPreset(const P: PQuantPreset);
begin
  if not Assigned(P) then // DLL-Ref / Pas-Ref
    begin
      SetEnableRmseTypeAll(False);
      chkUseMAD.Enabled := False;
      cbRmseType.Enabled := False;
      cbRmseType.ItemIndex := 0; //cfg.RmseType;

      frmEditTensors.cbRmseType.Enabled := False;
      frmEditTensors.cbRmseType.ItemIndex := 0;
      Exit;
    end;

  //cbUseImpl.Enabled := True;
  //cbDTypeOut.Enabled := True;

  edtRmin.Enabled := efRmin in P.EnabledFields; // profil DLL -> tous grisés
  edtRdelta.Enabled := efRdelta in P.EnabledFields;
  edtNstep.Enabled := efNstep in P.EnabledFields;
  edtQpStep.Enabled := efQpStep in P.EnabledFields;
  edtQpSteps.Enabled := efQpSteps in P.EnabledFields;
  edtQCIter.Enabled := efQcIter in P.EnabledFields;
  edtRadiusLs.Enabled := efRadiusLs in P.EnabledFields;
  edtRadiusLm.Enabled := efRadiusLm in P.EnabledFields;
  chkUseMAD.Enabled := efUseMAD in P.EnabledFields;
  cbRmseType.Enabled := efRmseType in P.EnabledFields;
  frmEditTensors.cbRmseType.Enabled := cbRmseType.Enabled;

  if edtRmin.Enabled then
    TEdit_WriteFloat(edtRmin, P.Rmin)
  else
    edtRmin.Text := '0';

  if edtRdelta.Enabled then
    TEdit_WriteFloat(edtRdelta, P.Rdelta)
  else
    edtRdelta.Text := '0';

  if edtNstep.Enabled then
    TEdit_WriteInt(edtNstep, P.Nstep)
  else
    edtNstep.Text := '0';

  if edtQpStep.Enabled then
    TEdit_WriteFloat(edtQpStep, P.QpStep)
  else
    edtQpStep.Text := '0';

  if edtQpSteps.Enabled then
    TEdit_WriteInt(edtQpSteps, P.QpNStep)
  else
    edtQpSteps.Text := '0';

  if edtQCIter.Enabled then
    TEdit_WriteInt(edtQCIter, P.QcIter)
  else
    edtQCIter.Text := '0';

  if edtRadiusLs.Enabled then
    TEdit_WriteInt(edtRadiusLs, ClampInt(P.RadiusLs, 0, 31))
  else
    edtRadiusLs.Text := '0';

  if edtRadiusLm.Enabled then
    TEdit_WriteInt(edtRadiusLm, ClampInt(P.RadiusLm, 0, 31))
  else
    edtRadiusLm.Text := '0';

  if cbRmseType.Enabled then
    TCombo_SetSel(cbRmseType, P.RmseType)     // profil DLL inclus => round-trip OK
  else
    cbRmseType.ItemIndex := 0;
  frmEditTensors.cbRmseType.ItemIndex := cbRmseType.ItemIndex;

  if chkUseMAD.Enabled then
    chkUseMAD.Checked := P.UseMAD
  else
    chkUseMAD.Checked := False;
end;

procedure TfrmViewTensors.UpdateQuantPresetFromUI(const P: PQuantPreset); // compat
begin
  if Assigned(FSelOutTensor) then
    SavePresetToReg(FSelOutTensor.TensorType, TCombo_GetSel(cbUseImpl, cfg.UseImpl));
end;

procedure TfrmViewTensors.FormClose(Sender: TObject; var Action: TCloseAction);
var
  t0: Int64;
begin
  cfg.FrmViewTensors_Left := Left;
  cfg.FrmViewTensors_Top := Top;
  cfg.FrmViewTensors_Width := Width;
  cfg.FrmViewTensors_Height := Height;

  FClosing := True;
  FCancelThread := True;
  Inc(FRenderGen); // perime le job en cours
  FSliderTimer.Enabled := False;
  PanelTop.Enabled := False;
  PanelLeft.Enabled := False; // neutralise les clics

  HistoCommitWindow; // 1) edt -> etat + cfg
  cfg.bHistVAuto := chkVAuto.Checked;
  SetCfgFromUi(cfg); // 2) le reste de la vue
  cfgSaveSettings(cfg); // 3) puis seulement on sauvegarde

  t0 := GetTickCount64;
  while FBusy and (GetTickCount64 - t0 < 3000) do
    begin
      CheckSynchronize; // draine ChartApplyJob / HistoApplyJob
      Sleep(10);
    end;
  // Sécurité si un worker ne termine pas.
  FBusy := False;
end;

procedure TfrmViewTensors.FormCreate(Sender: TObject);
var
  ll: TStringList;
begin
  FBusy := True;
  FHistQuiet  := True;
  FchkClick := True;
  FClosing := False;
  KeyPreview := True; // Nécessaire pour intercepter les touches < > + -

  FCancelThread := False;

  // Initialisation navigation par défaut
  FUpdatingXAxis := False;
  FCurrentStartIdx := 0;
  FCurrentEndIdx := 0;
  FGlobalMaxElems := 0;

  // DÉSACTIVER NAVIGATION NATIVE TEECHART
  Chart1.Zoom.Active := False;
  Chart1.AllowPanning := pmNone;
  Chart1.AllowZoom := False;
  // 1. Désactiver la légende TeeChart
  Chart1.Legend.Visible := False;
  Chart1.DoubleBuffered := True;

  Chart2.Legend.Visible := False; // Pour l'histogramme

  FRangeSlider := TRangeSlider.Create(Self);
  FRangeSlider.Parent := pnlRangeSlider1;
  FRangeSlider.Align := alClient;
  FRangeSlider.Margins.SetBounds(1, 1, 1, 1);
  FRangeSlider.AlignWithMargins := True;
  FRangeSlider.OnChange := SliderChange;

  // Initialisation des valeurs
  FRangeSlider.MinVal := 0;
  FRangeSlider.MaxVal := 1000;

  btnToggleSection.Caption := '[+]';
  PanChart1Top.Height := 36;

  FSelectionOrder := TList<Integer>.Create;

  cbDTypeOut.Items.Clear;
  { for i := 0 to GGMLTypeCount() do
    // if Assigned(GetQuantProc(i)) then // and Assigned(GetDequantProc(I)) ..
    begin
    frmViewTensors.cbDTypeOut.Items.Add(GGMLTypeToStr(i));
    end; }
  // if Assigned(FGGMLRegistry) then
  ll := GGMLTypeGetListDType;
  try
    cbDTypeOut.Items.AddStrings(ll)
  finally
    ll.Free
  end;
  cbDTypeOut.ItemIndex := 0;

  SetUiFromCfg(cfg);

  FLastUViewIUpdateTick := 0;
  GMainThreadID := TThread.CurrentThread.ThreadID; // le thread principal
  frmViewTensors.FchkClick := False;
  FBusy := False;
  FHistQuiet  := False;
end;

procedure TfrmViewTensors.ClearRenderLists;
var
  i: Integer;
begin
  FUpdatingChecks := True;
  try
    if Assigned(FSelectionOrder) then
      FSelectionOrder.Clear;

    FSelOutTensor := nil;

    if Assigned(ChListBoxTensors) then
    begin
      ChListBoxTensors.Items.BeginUpdate;
      try
        ChListBoxTensors.Items.Clear;
      finally
        ChListBoxTensors.Items.EndUpdate;
      end;
    end;

    if Assigned(lvSeries) then
    begin
      lvSeries.Items.BeginUpdate;
      try
        for i := 0 to lvSeries.Items.Count - 1 do
        begin
          if Assigned(lvSeries.Items[i].Data) then
            TLegendInfo(lvSeries.Items[i].Data).Free;
        end;
        lvSeries.Items.Clear;
      finally
        lvSeries.Items.EndUpdate;
      end;
    end;

    if Assigned(Chart1) then
      Chart1.RemoveAllSeries;

    if Assigned(Chart2) then
      Chart2.RemoveAllSeries;

  finally
    FUpdatingChecks := False;
  end;
end;


procedure TfrmViewTensors.DetachModels;
begin
  FClosing := True;
  FCancelThread := True;
  Inc(FRenderGen);

  FPendKind := RK_NONE;

  FBusy := False;

  if Assigned(FSliderTimer) then
    FSliderTimer.Enabled := False;

  ClearRenderLists;

  FModel1 := nil;
  FModel2 := nil;
  FModel3 := nil;
  FModelS := nil;
  FModelOut := nil;

  if Assigned(ProgressBar1) then
    ProgressBar1.Visible := False;

  if Assigned(ProgressBar2) then
    ProgressBar2.Visible := False;

  if Assigned(btnHistogramCancel) then
    btnHistogramCancel.Enabled := False;
end;



procedure TfrmViewTensors.FormDestroy(Sender: TObject);
begin
  DetachModels;

  // Important : mettre la référence globale à nil le plus tôt possible.
  frmViewTensors := nil;// rend effective TOUTES les gardes « <> nil » des ouvriers , apres tes NON !
  if Assigned(FSelectionOrder) then
    FreeAndNil(FSelectionOrder);
end;

// Quand l'utilisateur bouge le slider -> On met à jour le graphique
procedure TfrmViewTensors.SliderChange(Sender: TObject);
begin
  if FGlobalMaxElems <= 0 then
    Exit;
  FSliderTimer.Enabled := True; // debounce : un seul tir 150 ms après la fin du glissement
end;

// CLAVIER
procedure TfrmViewTensors.FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if not(csDesigning in ComponentState) then
    begin
      // Ignorer les touches si le focus est sur un champ de saisie
      if (ActiveControl is TEdit) or (ActiveControl is TMemo) or (ActiveControl is TCheckListBox) then
        Exit;
      // Si on est en mode FIXE, on ignore les touches de navigation X
      if not chkXAxisAuto.Checked then
        begin
          if Key in [188, 37, 190, 39, 187, 38, 189, 40] then // < > + -
            Exit;
        end;

      case Key of
        188: // Touche physique '<' (VK_OEM_COMMA)  37
          btnNavLeftClick(nil);
        37:
          btnNavLeftClick(nil);
        190: // Touche physique '>' (VK_OEM_PERIOD)    39
          btnNavRightClick(nil);
        39:
          btnNavRightClick(nil);
        187: // Touche physique '+' (VK_OEM_PLUS)    38
          btnZoomInClick(nil);
        38:
          btnZoomInClick(nil);
        189: // Touche physique '-' (VK_OEM_MINUS)   40
          btnZoomOutClick(nil);
        40:
          btnZoomOutClick(nil);
        else
          inherited;
      end;
    end;
end;

procedure TfrmViewTensors.FormResize(Sender: TObject);
begin
  stBar1.Panels[0].Width := ClampInt(Round(Width *0.4), 120, 800);
end;

procedure TfrmViewTensors.FormShow(Sender: TObject);
begin
  FClosing := False;
  FCancelThread := False;
  PanelTop.Enabled := True;
  PanelLeft.Enabled := True;
  vtPopulateTensorList;
  // LogMsg('Système prêt. Sélectionnez les tenseurs à analyser.');
  // LogMsg(mLang.gMsg('SystemReady'));
  vLogMsg(mLang.gMsg('FVT.SystemReady'));

  ValidateFormBounds(cfg.FrmViewTensors_Left, cfg.FrmViewTensors_Top, cfg.FrmViewTensors_Width, cfg.FrmViewTensors_Height);

  Left := cfg.FrmViewTensors_Left;
  Top := cfg.FrmViewTensors_Top;
  Width := cfg.FrmViewTensors_Width;
  Height := cfg.FrmViewTensors_Height;
  // WindowState := wsNormal;
end;

procedure TfrmViewTensors.FSliderTimerTimer(Sender: TObject);
begin
  if FBusy then
    Exit;
  if FGlobalMaxElems <= 0 then
    Exit;
  FSliderTimer.Enabled := False;
  // Conversion du ratio (0..1000) en indices réels
  FCurrentStartIdx := Round(FRangeSlider.StartIdx * FGlobalMaxElems / 1000.0);
  FCurrentEndIdx := Round(FRangeSlider.EndIdx * FGlobalMaxElems / 1000.0);
  // si on est sur l'onglet histogramme, le PageControl1Change ne se
  // déclenche pas (déjà sur TabHist) => on appelle explicitement :
  RefreshActiveView(False);
end;

procedure TfrmViewTensors.lvSeriesAdvancedCustomDrawItem(Sender: TCustomListView;
  Item: TListItem; State: TCustomDrawState; Stage: TCustomDrawStage; var DefaultDraw: Boolean);
var
  Lg: TLegendInfo;
begin
  if not Assigned(Item.Data) then Exit;
  Lg := TLegendInfo(Item.Data);
  if Lg.Color <> 0 then
    Sender.Canvas.Font.Color := Lg.Color
  else
    Sender.Canvas.Font.Color := clBlack;
  if Item.Index mod 2 = 0 then
    Sender.Canvas.Brush.Color := $00ECECEC
  else
    Sender.Canvas.Brush.Color := clWhite;
end;

procedure TfrmViewTensors.btnApplyClick(Sender: TObject);
var
  NewType, UseImpl: Integer;
begin
  //GMainThreadID := TThread.CurrentThread.ThreadID;
  if not(FSelOutTensor = nil) then
    begin
      NewType := StrToGGMLType(cbDTypeOut.Text);
      if NewType < 0 then
        Exit;
      UseImpl := TCombo_GetSel(cbUseImpl, cfg.UseImpl);
      SavePresetToReg(NewType, UseImpl); // edt* + cbRmseType -> preset courant
      if not QP_HasPreset(UseImpl) then      // Ref : tout désactiver
        begin
          SetEnableRmseTypeAll(False);
          chkUseMAD.Enabled := False;
          cbRmseType.Enabled := False;
        end;
      FSelOutTensor.UseImpl := UseImpl;
      FSelOutTensor.RmseType := TCombo_GetSel(cbRmseType, FSelOutTensor.RmseType);
    end;
  SetCfgFromUi(cfg);
  //frmEditTensors.ApplyOutSelPreset(FSelOutTensor, NewType, UseImpl, FSelOutTensor.RmseType);
  // if not DoQuantTypeOutChange(FSelOutTensor, NewType, UseImpl, FSelOutTensor.RmseType, frmEditTensors.chkAllLayersOut.Checked,
  //   frmEditTensors.cbLayersFromOut.Text, frmEditTensors.cbLayersToOut.Text, frmEditTensors.cbLayersModOut.Text) then
  //  Exit;
  RefreshChart(True);
end;

procedure TfrmViewTensors.UpdateStatusBarDiffStats(const Stats: TDiffStats; ElapsedMs: Int64);
begin
  if not Assigned(stBar1) or (stBar1.Panels.Count < 5) then
    Exit;
  // Panneau 0 : Count & Min Diff & Max Diff & Temps d'exécution & Mode
  stBar1.Panels[0].Text := Format('Count: %d | Min: %.6f  | Max: %.6f | Diff: %s', //
    [Stats.Count, Stats.MinDiff, Stats.MaxDiff, FormatDurationMs(ElapsedMs)]);
  if Stats.Count > 0 then
    begin
      // Panneau 1 :WRMSE
      stBar1.Panels[1].Text := Format('WRMSE: %.6f', [Stats.WRMSE]);
      // Panneau 2 :RMS
      stBar1.Panels[2].Text := Format('RMS: %.6f', [Stats.RMS]);
      // Panneau 3 : MAE
      stBar1.Panels[3].Text := Format('MAE: %.6f', [Stats.MAE]);
      // Panneau 4 : Moyenne
      stBar1.Panels[4].Text := Format('Mean: %.6f', [Stats.Mean]);
    end
  else
    begin
      stBar1.Panels[1].Text := mLang.gMsgFmt('FVT.DiffNoDataLog', [FormatDurationMs(Stats.FElapsedMs)]); //'No valid data';
      stBar1.Panels[2].Text := '';
      stBar1.Panels[3].Text := '';
      stBar1.Panels[4].Text := '';
    end;
end;

// GRAPHIQUE & DÉTECTION OUTLIERS

// CORE: RefreshChart avec gestion de FCurrentSelectedTensorIndex
procedure TfrmViewTensors.PubRefreshChart(ForceFullRange: Boolean = False);
begin
  RefreshChart(ForceFullRange);
end;

procedure TfrmViewTensors.AddSeriesToListView(const ATitle: string; AColor: TColor);
var
  aLItem: TListItem;
begin
  if (frmViewTensors = nil) or (ATitle = '') then Exit;
  if not IsUIMainThread then
    begin
      vLogMsg('[VIEW] AddSeriesToListView appelee hors thread principal !', False, lvWarn);
      Exit;
    end;
  aLItem := lvSeries.Items.Add;
  aLItem.Caption := ATitle;
  aLItem.Data := TLegendInfo.Create(ATitle, AColor);
end;

// Gestion du "Tout sélectionner"
procedure TfrmViewTensors.chkMOutClick(Sender: TObject);
begin
  if frmViewTensors.FchkClick then
    exit;
  frmViewTensors.FchkClick := True;
  vtPopulateTensorList;
  frmViewTensors.FchkClick := False;
end;

procedure TfrmViewTensors.chkT1dT2Click(Sender: TObject);
begin
  if frmViewTensors.FchkClick then
    exit;
  frmViewTensors.FchkClick := True;
  cfg.chkT1dT2 := chkT1dT2.Checked;
  if cfg.chkT1dT2 then
    begin
      // cbNbrSelect.Text := '2'; // Force à "2"
      cbNbrSelect.Text := '2:ByName'; // Force à "2:ByName"
      vtEnforceSelectionLimit;
    end;
  RefreshActiveView(False);
  frmViewTensors.FchkClick := False;
end;

procedure TfrmViewTensors.chkT1vT2Click(Sender: TObject);
begin
  if frmViewTensors.FchkClick then
    exit;
  frmViewTensors.FchkClick := True;
  cfg.chkT1sT2 := chkT1vT2.Checked;
  if cfg.chkT1sT2 then
    begin
      // cbNbrSelect.Text := '2'; // Force à "2"
      cbNbrSelect.Text := '2:ByName'; // Force à "2:ByName"
      vtEnforceSelectionLimit;
    end;
  RefreshActiveView(False);
  frmViewTensors.FchkClick := False;
end;

procedure TfrmViewTensors.UpdateRmseControlsState;
var
  i, j, SelectedCount, OutCount, TargetType: Integer;
  OutTensor, TCur: TGGUFTensorInfo;
  Found: Boolean;
begin
  SelectedCount := 0;
  OutCount := 0;
  for i := 0 to ChListBoxTensors.Count - 1 do
    if ChListBoxTensors.Checked[i] then
      begin
        Inc(SelectedCount);
        TCur := TGGUFTensorInfo(ChListBoxTensors.Items.Objects[i]);
        if (TCur <> nil) and TCur.IsConverted then
          Inc(OutCount);
      end;

  if (OutCount <> 1) or (SelectedCount > 2) then
    begin
      FSelOutTensor := nil;
      SetTargetEnabled(False);
      UpdateUIFromQuantPreset(nil); // edt* grisés, combo grisé
      Exit;
    end;

  for i := 0 to ChListBoxTensors.Count - 1 do
    begin
      OutTensor := TGGUFTensorInfo(ChListBoxTensors.Items.Objects[i]);
      if not(ChListBoxTensors.Checked[i] and Assigned(OutTensor) and OutTensor.IsConverted) then
        Continue;

      TargetType := OutTensor.TensorType;
      FSelOutTensor := OutTensor;
      SetTargetEnabled(True);

      // cbDTypeOut <- type
      Found := False;
      for j := 0 to cbDTypeOut.Items.Count - 1 do
        if SameText(cbDTypeOut.Items[j], GGMLTypeToStr(TargetType)) then
          begin
            TCombo_SetSel(cbDTypeOut, j);
            Found := True;
            Break;
          end;
      if not Found then
        TCombo_SetSel(cbDTypeOut, 0); // ne PAS Break ici

      // identité AVANT lecture ; preset -> edt* + cbRmseType (preset fait foi)
      TCombo_SetSel(cbUseImpl, OutTensor.UseImpl);
      LoadPresetToUI(TargetType, OutTensor.UseImpl);

      // resync du tenseur DEPUIS le preset affiché (cohérence vue<->registre)
      if QP_HasPreset(OutTensor.UseImpl) then
        OutTensor.RmseType := TCombo_GetSel(cbRmseType, OutTensor.RmseType);
      // profil Ref : combo grisé, on conserve OutTensor.RmseType tel quel
      Break;
    end;
end;

procedure TfrmViewTensors.BindOutPresetToUI(AType, UseImpl: Integer; var RmseType: Integer);
var P: PQuantPreset;
begin
  P := nil;
  if QP_HasPreset(UseImpl) then
    P := cfg.ggmlReg.GetPPreset(AType, QP_ProfileOfUseImpl(UseImpl));
  UpdateUIFromQuantPreset(P); // edt* + Enabled + cbRmseType
  //  RmseType := QP_ComboSel(cbRmseType, RmseType);   // valeur réellement affichée
end;

function TfrmViewTensors.PresetOf(AType, UseImpl: Integer): PQuantPreset;
var
  Pr: Integer;
begin
  Result := nil;
  Pr := QP_ProfileOfUseImpl(UseImpl);
  if Pr <> QP_PROF_NONE then
    Result := cfg.ggmlReg.GetPPreset(AType, Pr); // 0 DLL, 1..3 tuning
end;

// LECTURE registre -> UI  (aucune écriture)
procedure TfrmViewTensors.LoadPresetToUI(AType, UseImpl: Integer);
begin
  UpdateUIFromQuantPreset(PresetOf(AType, UseImpl));
end;

// ECRITURE UI -> registre (no-op si DLL-Ref / Pas-Ref)
procedure TfrmViewTensors.SavePresetToReg(AType, UseImpl: Integer);
var
  P: PQuantPreset;
begin
  P := PresetOf(AType, UseImpl);
  if not Assigned(P) then
    Exit;

  if efRmin in P.EnabledFields then
    P.Rmin := TEdit_ReadFloat(edtRmin, P.Rmin);
  if efRdelta in P.EnabledFields then
    P.Rdelta := TEdit_ReadFloat(edtRdelta, P.Rdelta);
  if efNstep in P.EnabledFields then
    P.Nstep := TEdit_ReadInt(edtNstep, P.Nstep);
  if efQpStep in P.EnabledFields then
    P.QpStep := TEdit_ReadFloat(edtQpStep, P.QpStep);
  if efQpSteps in P.EnabledFields then
    P.QpNStep := TEdit_ReadInt(edtQpSteps, P.QpNStep);
  if efQcIter in P.EnabledFields then
    P.QcIter := TEdit_ReadInt(edtQCIter, P.QcIter);
  if efRadiusLs in P.EnabledFields then
    P.RadiusLs := ClampInt(TEdit_ReadInt(edtRadiusLs, P.RadiusLs), 0, 31);
  if efRadiusLm in P.EnabledFields then
    P.RadiusLm := ClampInt(TEdit_ReadInt(edtRadiusLm, P.RadiusLm), 0, 31);

  P.RmseType := TCombo_GetSel(cbRmseType, P.RmseType); // <- persisté pour les 4 profils (DLL inclus)
  if efUseMAD in P.EnabledFields then
    P.UseMAD := chkUseMAD.Checked;

  if Assigned(FSelOutTensor) then
    begin
      FSelOutTensor.RmseType := P.RmseType;
      FSelOutTensor.UseImpl := UseImpl; // <- était perdu
    end;
end;

function TfrmViewTensors.CurRmseFor(AType, UseImpl: Integer): Integer;
var P: PQuantPreset;
begin
  P := PresetOf(AType, UseImpl);
  if Assigned(P) then Result := P.RmseType             // le preset fait foi sur changement d'identité
  else Result := TCombo_GetSel(cbRmseType, cfg.RmseType);
end;

procedure TfrmViewTensors.QP_SetRmsePreset(AType, UseImpl, RmseType: Integer);
begin
  TCombo_SetSel(cbRmseType, RmseType);
  SavePresetToReg(AType, UseImpl); // -> registre (+ FSelOutTensor)
  LoadPresetToUI(AType, UseImpl); // -> edt* (cohérence immédiate)
end;

procedure TfrmViewTensors.SetEnableRmseTypeAll(e: Boolean);
begin
  edtRmin.Enabled := e;
  edtRdelta.Enabled := e;
  edtNstep.Enabled := e;
  edtQpStep.Enabled := e;
  edtQpSteps.Enabled := e;
  edtQCIter.Enabled := e;
  // cbRmseType.Enabled := e;
  // chkUseMAD.Enabled := e;
  edtRadiusLs.Enabled := e;
  edtRadiusLm.Enabled := e;
  if not e then
    begin
      edtRmin.text := '0';
      edtRdelta.text := '0';
      edtNstep.text := '0';
      edtQpStep.text := '0';
      edtQpSteps.text := '0';
      edtQCIter.text := '0';
      // cbRmseType.Enabled := e;
      // chkUseMAD.Enabled := e;
      edtRadiusLs.text := '0';
      edtRadiusLm.text := '0';
    end;
end;

// cbUseImpl : LECTURE seule
procedure TfrmViewTensors.cbUseImplClick(Sender: TObject);
var
  UseImpl, RmseType: Integer;
begin
  if FSelOutTensor = nil then
    Exit;

  UseImpl := TCombo_GetSel(cbUseImpl, cfg.UseImpl);

  FSelOutTensor.UseImpl := UseImpl;

  LoadPresetToUI(FSelOutTensor.TensorType, FSelOutTensor.UseImpl); // edt* + cbRmseType

  btnApplyClick(Sender);

  RmseType := TCombo_GetSel(cbRmseType, cfg.RmseType);

  frmEditTensorsRebuildViewOut;

  RestoreListViewSelection(frmEditTensors.lvTensorsOut, string(FSelOutTensor.Name));

  TCombo_SetSel(frmEditTensors.cbUseImpl, UseImpl);
  TCombo_SetSel(frmEditTensors.cbRmseType, RmseType);

  frmEditTensors.cbRmseType.Enabled := QP_HasPreset(UseImpl);

  if not DoQuantTypeOutChange(FSelOutTensor, FSelOutTensor.TensorType, UseImpl, FSelOutTensor.RmseType, frmEditTensors.chkAllLayersOut.Checked,
    frmEditTensors.cbLayersFromOut.Text, frmEditTensors.cbLayersToOut.Text, frmEditTensors.cbLayersModOut.Text) then
    Exit;
end;

// cbRmseType : ECRITURE seule , preset du profil courant, DLL inclus
procedure TfrmViewTensors.cbRmseTypeClick(Sender: TObject);
var
  RmseType: Integer;
begin
  if FSelOutTensor = nil then
    Exit;
  RmseType := TCombo_GetSel(cbRmseType, cfg.RmseType);
  SavePresetToReg(FSelOutTensor.TensorType, TCombo_GetSel(cbUseImpl, cfg.UseImpl));
  btnApplyClick(Sender);
  frmEditTensorsRebuildViewOut;
  RestoreListViewSelection(frmEditTensors.lvTensorsOut, string(FSelOutTensor.Name));
  TCombo_SetSel(frmEditTensors.cbRmseType, RmseType);

  if not DoQuantTypeOutChange(FSelOutTensor, FSelOutTensor.TensorType, FSelOutTensor.UseImpl, FSelOutTensor.RmseType, frmEditTensors.chkAllLayersOut.Checked,
    frmEditTensors.cbLayersFromOut.Text, frmEditTensors.cbLayersToOut.Text, frmEditTensors.cbLayersModOut.Text) then
    Exit;
end;

procedure TfrmViewTensors.chkXAxisAutoClick(Sender: TObject);
begin
  if (csDesigning in ComponentState) or FUpdatingXAxis then
    Exit;
  // if chkXAxisAuto.Checked then  Exit;
  if FGlobalMaxElems < 1 then
    Exit;
  FUpdatingXAxis := True; // On bloque les événements
  if chkXAxisAuto.Checked then
    begin
      // Mode Auto
      edtXMin.Enabled := False;
      edtXMax.Enabled := False;
      edtXMin.ReadOnly := True;
      edtXMax.ReadOnly := True;
      // Mode Auto : l'axe suit le zoom/drag. On ne force pas de refresh global.
    end
  else
    begin
      // Mode Manuel
      edtXMin.Enabled := True;
      edtXMax.Enabled := True;
      edtXMin.ReadOnly := False;
      edtXMax.ReadOnly := False;
      // Mode Manuel : on initialise les Edits avec la vue actuelle
      // On change le texte sans déclencher l'événement via FUpdatingXAxis
      if (FCurrentStartIdx <> 0) and (FCurrentEndIdx <> 0) then
        begin
          edtXMin.Text := IntToStr(FCurrentStartIdx);
          edtXMax.Text := IntToStr(FCurrentEndIdx);
          cfg.XStartIdxMan := FCurrentStartIdx;
          cfg.XEndIdxMan := FCurrentEndIdx;
          RefreshChart(False);
        end;
    end;
  FUpdatingXAxis := False;
end;

procedure TfrmViewTensors.ProgressBar1MouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  FCancelThread := True;
end;

procedure TfrmViewTensors.SetedtYMinedtYMaxValus(Mn, Mx: Double);
begin
  if ((Mn = 0) and (Mx = 0)) or (Mn = Mx) then
    Exit;
  AxisMargin(Mn, Mx, 0.025);
  TEdit_WriteFloat(edtYMin, Mn);
  TEdit_WriteFloat(edtYMax, Mx);
end;

procedure TfrmViewTensors.chkYAxisAutoClick(Sender: TObject);
begin
  if chkYAxisAuto.Checked then
    begin
      Chart1.LeftAxis.Automatic := True;
    end
  else
    begin
      Chart1.LeftAxis.Automatic := False;
      SetedtYMinedtYMaxValus(Chart1.LeftAxis.Minimum, Chart1.LeftAxis.Maximum);
      UpdateYAxisRangeFromEdit;
    end;
end;

procedure TfrmViewTensors.ChListBoxTensorsClickCheck(Sender: TObject);
begin
  vtChListBoxTensorsClickCheck;
end;

// edtRmin/edtRdelta/edtNstep/edtQpStep/edtQpSteps/edtQCIter/edtRadiusLs/edtRadiusLm (#13)
procedure TfrmViewTensors.edtNstepKeyPress(Sender: TObject; var Key: Char);
begin
  if Key <> #13 then
    Exit;
  Key := #0;
  if FSelOutTensor = nil then
    Exit;
  SavePresetToReg(FSelOutTensor.TensorType, TCombo_GetSel(cbUseImpl, cfg.UseImpl));
  if not FBusy then
    begin
      RefreshActiveView(False);
    end;
end;

procedure TfrmViewTensors.edtValMinKeyPress(Sender: TObject; var Key: Char);
begin
  if Key <> #13 then
    Exit;
  Key := #0;
  HistoCommitWindow; // edits -> etat + cfg
  if not FBusy then
    GenerateHistogram(False);
end;

procedure TfrmViewTensors.edtXMinKeyPress(Sender: TObject; var Key: Char);
begin
  if Key = #13 then
    begin
      UpdateXAxisRangeFromEdit;
    end;
end;

procedure TfrmViewTensors.edtYMinKeyPress(Sender: TObject; var Key: Char);
begin
  if Key = #13 then
    begin
      Key := #0;
      UpdateYAxisRangeFromEdit;
    end;
end;

procedure TfrmViewTensors.UpdateYAxisRangeFromEdit;
var
  MinVal, MaxVal, Val: Double;
begin
  if FGlobalMaxElems <= 1 then
    Exit; // Pas de plage valide si 0 ou 1 élément
  MinVal := TEdit_ReadFloat(edtYMin, -1);
  MaxVal := TEdit_ReadFloat(edtYMax, 1);
  if MinVal > MaxVal then
    begin
      Val := MinVal;
      MinVal := MaxVal;
      MaxVal := Val;
    end;
  if (MinVal <> MaxVal) then
    Chart1.LeftAxis.SetMinMax(MinVal, MaxVal);
end;

procedure TfrmViewTensors.UpdateXAxisRangeFromEdit;
var
  NewStart, NewEnd: Int64;
begin
  if FGlobalMaxElems <= 1 then
    Exit; // Pas de plage valide si 0 ou 1 élément

  FUpdatingXAxis := True;
  try
    NewEnd := TEdit_ReadInt(edtXMax, FGlobalMaxElems - 1);
    if NewEnd < 0 then
      NewEnd := 0;
    NewStart := TEdit_ReadInt(edtXMin, 0);
    if NewStart < 0 then
      NewStart := 0;
    if NewEnd > FGlobalMaxElems - 1 then
      NewEnd := FGlobalMaxElems - 1;
    if NewEnd <= FCurrentStartIdx then
      begin
        NewEnd := FCurrentStartIdx + cfg.MinXAxisRang + 1;
        if NewEnd > FGlobalMaxElems - 1 then
          NewEnd := FGlobalMaxElems - 1;
        edtXMax.Text := IntToStr(NewEnd);
      end;
    if NewStart >= FCurrentEndIdx then
      begin
        if FCurrentEndIdx > cfg.MinXAxisRang then
          NewStart := FCurrentEndIdx - cfg.MinXAxisRang
        else
          NewStart := 0;
        edtXMin.Text := IntToStr(NewStart);
      end;
    FCurrentEndIdx := NewEnd;
    cfg.XEndIdxMan := NewEnd;
    FCurrentStartIdx := NewStart;
    cfg.XStartIdxMan := NewStart;
    RefreshActiveView(False);
  finally
    FUpdatingXAxis := False;
  end;
end;

procedure TfrmViewTensors.Chart1MouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  // On ne déclenche le glissement que par le bouton gauche
  if Button = mbLeft then
    begin
      FIsDragging := True;
      FDragStartX := X;
      // Capture de l'état des axes au moment du clic pour calculer le delta
      FDragStartMinX := Chart1.BottomAxis.Minimum;
      FDragStartMaxX := Chart1.BottomAxis.Maximum;
    end;
end;

procedure TfrmViewTensors.Chart1MouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
var
  DeltaX: Integer;
  XUnitPerPixel: Double;
  NewMinX, NewMaxX: Double;
begin
  if not FIsDragging then
    Exit;
  if Chart1.Width = 0 then
    Exit;
  // NAVIGATION HORIZONTALE (INDEX)
  DeltaX := X - FDragStartX;
  // Calcul de la valeur de l'unité par pixel (Précision extrême)
  // On divise la plage de l'axe par la largeur du graphique en pixels
  XUnitPerPixel := (FDragStartMaxX - FDragStartMinX) / Chart1.Width;
  // On déplace la fenêtre de la valeur du delta
  NewMinX := FDragStartMinX - (DeltaX * XUnitPerPixel);
  NewMaxX := FDragStartMaxX - (DeltaX * XUnitPerPixel);

  NewMinX:=Max(0,NewMinX);
  NewMaxX:=Min(FGlobalMaxElems,NewMaxX);

  // Appliquer l'axe visuellement (immédiat, sans recharger le fichier)
  Chart1.BottomAxis.SetMinMax(NewMinX, NewMaxX);
end;

procedure TfrmViewTensors.Chart1MouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  Range: Int64;
begin
  if FIsDragging then
    begin
      FIsDragging := False;
      if FGlobalMaxElems <= 1 then
        Exit;
      FCurrentStartIdx := Max(0, Trunc(Chart1.BottomAxis.Minimum));
      FCurrentEndIdx := Min(FGlobalMaxElems - 1, Trunc(Chart1.BottomAxis.Maximum));
      Range := FCurrentEndIdx - FCurrentStartIdx;
      if Range <= cfg.MinXAxisRang then
        begin
          if FCurrentStartIdx <= 0 then
            begin
              FCurrentStartIdx := 0;
              if FGlobalMaxElems >= cfg.MinXAxisRang then
                FCurrentEndIdx := FCurrentStartIdx + cfg.MinXAxisRang
              else
                FCurrentEndIdx := FCurrentStartIdx + FGlobalMaxElems
            end
          else if FCurrentEndIdx >= FGlobalMaxElems - 1 then
            begin
              if FGlobalMaxElems >= cfg.MinXAxisRang then
                FCurrentStartIdx := FCurrentEndIdx - cfg.MinXAxisRang
              else
                FCurrentStartIdx := FCurrentEndIdx - FGlobalMaxElems;
            end;
        end;
      RefreshChart(False);
    end;
end;

procedure TfrmViewTensors.Chart1MouseWheelUp(Sender: TObject; Shift: TShiftState; MousePos: TPoint; var Handled: Boolean);
var
  Range, NewRange, AnchorValue, NewMin, NewMax: Double;
  iMousePos: TPoint;
  PlotLeft, PlotWidth, PlotX: Integer;
  Ratio: Double;
begin
  Handled := True; // Désactive le zoom natif de TeeChart
  if FGlobalMaxElems <= 1 then
    Exit;
  Range := Chart1.BottomAxis.Maximum - Chart1.BottomAxis.Minimum;
  if Range <= 0 then
    Exit;
  // 1. Coordonnées relatives au client du Chart
  iMousePos := Chart1.ScreenToClient(MousePos);
  // 2. Récupération des bornes exactes de la zone de tracée
  PlotLeft := Chart1.ChartRect.Left;
  PlotWidth := Chart1.ChartRect.Right - Chart1.ChartRect.Left;
  if PlotWidth <= 0 then
    Exit;
  // 3. Position X relative à la zone de tracée (0.0 à 1.0)
  PlotX := iMousePos.X - PlotLeft;
  Ratio := PlotX / PlotWidth;
  Ratio := Max(0.0, Min(1.0, Ratio)); // Clamp aux bords
  // 4. Valeur exacte de l'axe X sous le curseur
  AnchorValue := Chart1.Axes.Bottom.CalcPosPoint(iMousePos.X);
  // 5. Zoom IN : réduction de 15%
  NewRange := Range * 0.85;
  // CALCUL : Préserve la valeur sous la souris
  NewMin := AnchorValue - Ratio * NewRange;
  NewMax := AnchorValue + (1.0 - Ratio) * NewRange;
  // 6. Bornes globales du modèle
  NewMin := Max(NewMin, 0);
  NewMax := Min(NewMax, FGlobalMaxElems - 1);
  // Sécurité anti-inversion de plage
  Range := NewMax - NewMin;
  if Range <= cfg.MinXAxisRang then
    begin
      if NewMin <= 0 then
        begin
          NewMin := 0;
          if FGlobalMaxElems >= cfg.MinXAxisRang then
            NewMax := NewMin + cfg.MinXAxisRang
          else
            NewMax := NewMin + FGlobalMaxElems
        end
      else if NewMax >= FGlobalMaxElems then
        begin
          if FGlobalMaxElems >= cfg.MinXAxisRang then
            NewMin := NewMax - cfg.MinXAxisRang
          else
            NewMin := NewMax - FGlobalMaxElems;
        end
      else
        begin
          NewMin := ((NewMax + NewMin) / 2) - (cfg.MinXAxisRang / 2);
          NewMax := NewMin + cfg.MinXAxisRang;
        end;
    end;
  // 7. Application et synchronisation
  Chart1.BottomAxis.SetMinMax(NewMin, NewMax);
  FCurrentStartIdx := Trunc(NewMin);
  FCurrentEndIdx := Trunc(NewMax);
  if chkYAxisAuto.Checked then
    Chart1.LeftAxis.Automatic := True
  else
    UpdateYAxisRangeFromEdit;
  RefreshChart(False);
end;

procedure TfrmViewTensors.Chart1MouseWheelDown(Sender: TObject; Shift: TShiftState; MousePos: TPoint; var Handled: Boolean);
var
  Range, NewRange, AnchorValue, NewMin, NewMax: Double;
  iMousePos: TPoint;
  PlotLeft, PlotWidth, PlotX: Integer;
  Ratio: Double;
begin
  Handled := True;
  if FGlobalMaxElems <= 1 then
    Exit;
  Range := Chart1.BottomAxis.Maximum - Chart1.BottomAxis.Minimum;
  if Range <= 0 then
    Exit;
  iMousePos := Chart1.ScreenToClient(MousePos);
  PlotLeft := Chart1.ChartRect.Left;
  PlotWidth := Chart1.ChartRect.Right - Chart1.ChartRect.Left;
  if PlotWidth <= 0 then
    Exit;
  PlotX := iMousePos.X - PlotLeft;
  Ratio := PlotX / PlotWidth;
  Ratio := Max(0.0, Min(1.0, Ratio));
  AnchorValue := Chart1.Axes.Bottom.CalcPosPoint(iMousePos.X);
  // Zoom OUT : augmentation de 15%
  NewRange := Range * 1.15;
  NewMin := AnchorValue - Ratio * NewRange;
  NewMax := AnchorValue + (1.0 - Ratio) * NewRange;
  NewMin := Max(NewMin, 0);
  NewMax := Min(NewMax, FGlobalMaxElems - 1);

  if NewMin >= NewMax then
    begin
      NewMax := Min(FGlobalMaxElems - 1, NewMin + cfg.MinXAxisRang);
      if NewMax <= NewMin then
        NewMin := Max(0, NewMax - cfg.MinXAxisRang);
    end;

  Chart1.BottomAxis.SetMinMax(NewMin, NewMax);

  FCurrentStartIdx := Trunc(NewMin);
  FCurrentEndIdx := Trunc(NewMax);
  if chkYAxisAuto.Checked then
    Chart1.LeftAxis.Automatic := True
  else
    UpdateYAxisRangeFromEdit;
  RefreshChart(False);
end;

procedure TfrmViewTensors.Chart1UndoZoom(Sender: TObject);
begin
  FCurrentStartIdx := 0;
  FCurrentEndIdx := FGlobalMaxElems - 1;
  RefreshActiveView(True);
end;

procedure TfrmViewTensors.btnResetZoomClick(Sender: TObject);
begin
  // Chart1.UndoZoom;
  if FGlobalMaxElems > 1 then
  begin
    Chart1.BottomAxis.SetMinMax(0, FGlobalMaxElems - 1);
    FCurrentStartIdx := 0;
    FCurrentEndIdx := FGlobalMaxElems - 1;
    Chart2.UndoZoom;
    RefreshActiveView(True);
  end;
end;

procedure TfrmViewTensors.btnRestoreQuantPresetClick(Sender: TObject);
var
  P: PQuantPreset;
  NewType, UseImpl: Integer;
begin
  if FSelOutTensor = nil then
    Exit;
  NewType := StrToGGMLType(cbDTypeOut.Text);
  if NewType < 0 then
    Exit;
  UseImpl := TCombo_GetSel(cbUseImpl, QP_USEIMPL_DLL_IMPL0);
  P := PresetOf(NewType, UseImpl);
  if Assigned(P) then
    begin
      P^ := GetDefaultPresetByCode(NewType, QP_ProfileOfUseImpl(UseImpl)); // 3 -> RmseType type DLL
      LoadPresetToUI(NewType, UseImpl);
    end;
  btnApplyClick(Sender);
end;

procedure TfrmViewTensors.btnToggleSectionClick(Sender: TObject);
begin
  if btnToggleSection.Caption = '[+]' then
    begin
      btnToggleSection.Caption := '[-]';
      PanChart1Top.Height := 72;
    end
  else
    begin
      btnToggleSection.Caption := '[+]';
      PanChart1Top.Height := 36;
    end;
  // Self.Invalidate;
  Self.Realign;
end;

// PARTIE HISTOGRAMME

procedure TfrmViewTensors.SetVAutoQuiet(AOn: Boolean);
begin
  FHistQuiet := True;
  try
    chkVAuto.Checked := AOn;
  finally
    FHistQuiet := False;
  end;
end;

procedure TfrmViewTensors.HistoCommitWindow;
begin
  if chkVAuto.Checked then
  begin
    cfg.HistWMinMan := TEdit_ReadFloat(edtValMin, cfg.HistWMinMan);
    cfg.HistWMaxMan := TEdit_ReadFloat(edtValMax, cfg.HistWMaxMan);
  end
  else
  begin
    cfg.HistWMinMan := TEdit_ReadFloat(edtWinMin, cfg.HistWMinMan);
    cfg.HistWMaxMan := TEdit_ReadFloat(edtWinMax, cfg.HistWMaxMan);
  end;
  if (cfg.HistWMinMan >= cfg.HistWMaxMan) then
  begin // plage degereenee
    cfg.HistWMinMan := -0.15;
    cfg.HistWMaxMan := 0.15;
  end;
  TEdit_WriteFloat(edtWinMin, cfg.HistWMinMan);
  TEdit_WriteFloat(edtWinMax, cfg.HistWMaxMan);
end;

procedure TfrmViewTensors.HistoShowWindow;
begin
  if FHistVMaxMan > FHistVMinMan then
  begin
    TEdit_WriteFloat(edtValMin, FHistVMinMan);
    TEdit_WriteFloat(edtValMax, FHistVMaxMan);
  end
  else
  begin
    edtValMin.Text := '--';
    edtValMax.Text := '--';
  end;
end;

procedure TfrmViewTensors.HistoApplyCountsAxis;
begin
  if FHistPeak <= 0 then
    Chart2.LeftAxis.Automatic := True
  else if chkCntAuto.Checked then
  begin
    Chart2.LeftAxis.Automatic := False;
    cfg.HistNMinMan := 0;
    cfg.HistNMaxMan := frmViewTensors.FHistPeak;
    Chart2.LeftAxis.SetMinMax(cfg.HistNMinMan, cfg.HistNMaxMan);
    TEdit_WriteInt64(edtCntMin, cfg.HistNMinMan);
    TEdit_WriteInt64(edtCntMax, cfg.HistNMaxMan);
  end
  else
  begin
    cfg.HistNMinMan := TEdit_ReadInt64(edtCntMin, cfg.HistNMinMan);
    cfg.HistNMaxMan := TEdit_ReadInt64(edtCntMax, cfg.HistNMaxMan);
    if cfg.HistNMaxMan <= cfg.HistNMinMan then
    begin
      cfg.HistNMinMan := 0;
      cfg.HistNMaxMan := frmViewTensors.FHistPeak;
    end;
    Chart2.LeftAxis.Automatic := False;
    Chart2.LeftAxis.SetMinMax(cfg.HistNMinMan, cfg.HistNMaxMan);
  end;
end;

procedure TfrmViewTensors.chkVAutoClick(Sender: TObject);
begin
  if FHistQuiet then Exit;

  if not chkVAuto.Checked then
    HistoCommitWindow;

  edtWinMin.Enabled := not chkVAuto.Checked;
  edtWinMin.ReadOnly := chkVAuto.Checked;
  edtWinMax.Enabled := not chkVAuto.Checked;
  edtWinMax.ReadOnly := chkVAuto.Checked;

  cfg.bHistVAuto := chkVAuto.Checked;
  if not FBusy then
    GenerateHistogram(False);
end;

procedure TfrmViewTensors.RefreshActiveView(Force: Boolean);
begin
  if frmViewTensors.FGlobalMaxElems > 0 then
    begin
      frmViewTensors.FRangeSlider.MinVal := 0;
      frmViewTensors.FRangeSlider.MaxVal := 1000;
      frmViewTensors.FRangeSlider.StartIdx := Round((frmViewTensors.FCurrentStartIdx / frmViewTensors.FGlobalMaxElems) * 1000);
      frmViewTensors.FRangeSlider.EndIdx := Round((frmViewTensors.FCurrentEndIdx / frmViewTensors.FGlobalMaxElems) * 1000);
    end;
  if PageControl1.ActivePage = TabHist then
    GenerateHistogram(Force)
  else
    RefreshChart(Force);
end;

procedure TfrmViewTensors.btnHistogramFastClick(Sender: TObject);
begin
  //if FBusy then  Exit;
  GenerateHistogram();
end;

procedure TfrmViewTensors.btnHistogramFullClick(Sender: TObject);
begin
  //if FBusy then  Exit;
  GenerateHistogram(True);
end;

procedure TfrmViewTensors.btnZoomOutClick(Sender: TObject);
var
  Range, Center, NewRange: Int64;
begin
  if FGlobalMaxElems <= 1 then
    Exit;
  Range := FCurrentEndIdx - FCurrentStartIdx;

  // Zoom centré : double la fenêtre tout en gardant le point milieu
  Center := FCurrentStartIdx + Round(Range / 2);
  NewRange := Min(FGlobalMaxElems - 1, Range * 2);

  FCurrentStartIdx := Max(0, Center - Round(NewRange / 2));
  FCurrentEndIdx := Min(FGlobalMaxElems - 1, Center + Round(NewRange / 2));

  RefreshActiveView(False);
end;

procedure TfrmViewTensors.btnHistogramCancelClick(Sender: TObject);
begin
  FCancelThread := True;
end;

procedure TfrmViewTensors.cbFilterVChange(Sender: TObject);
begin
  vtPopulateTensorList;
end;

procedure TfrmViewTensors.cbNbrSelectChange(Sender: TObject);
begin
  FUpdatingChecks := True;
  try
    vtGetLimitFromCombo;
    vtEnforceSelectionLimit;
    // La limite peut décocher des éléments, il faut rafraîchir l'état des contrôles
    UpdateRmseControlsState;
    RefreshActiveView(False);
  finally
    FUpdatingChecks := False;
  end;
end;

// cbDTypeOut : LECTURE du nouveau type (le bloc bloc-size est déjà dans DoQuantTypeOutChange)
procedure TfrmViewTensors.cbDTypeOutClick(Sender: TObject);
var
  i, NewType, UseImpl, RmseType: Integer;
begin
  if FSelOutTensor = nil then
    Exit;
  NewType := StrToGGMLType(cbDTypeOut.Text);
  if (NewType < 0) or (NewType = FSelOutTensor.TensorType) then
    Exit;

  UseImpl := TCombo_GetSel(cbUseImpl, cfg.UseImpl);
  RmseType := TCombo_GetSel(cbRmseType, FSelOutTensor.RmseType);
  //if not DoQuantTypeOutChange(FSelOutTensor, NewType, UseImpl, RmseType , False, '', '', '') then  Exit;
  if not DoQuantTypeOutChange(FSelOutTensor, NewType, UseImpl, RmseType, frmEditTensors.chkAllLayersOut.Checked,
    frmEditTensors.cbLayersFromOut.Text, frmEditTensors.cbLayersToOut.Text, frmEditTensors.cbLayersModOut.Text) then
    Exit;

  {ChListBoxTensors.Items.BeginUpdate;
  try
    for i := 0 to ChListBoxTensors.Items.Count - 1 do
      begin
        T := TGGUFTensorInfo(ChListBoxTensors.Items.Objects[i]);
        if T = FSelOutTensor then
          begin
            ChListBoxTensors.Items[i] := GetFormatTensorNameList(T);
            Break;
          end;
      end;
  finally
    ChListBoxTensors.Items.EndUpdate;
  end;    }

  LoadPresetToUI(NewType, UseImpl); // preset du nouveau (Type, Profil)
  btnApplyClick(Sender);
end;

procedure TfrmViewTensors.btnClearAllSelectedClick(Sender: TObject);
var
  i: Integer;
begin
  FUpdatingChecks := True;
  try
    ChListBoxTensors.Items.BeginUpdate;
    try
      for i := 0 to ChListBoxTensors.Items.Count - 1 do
        ChListBoxTensors.Checked[i] := False;
    finally
      ChListBoxTensors.Items.EndUpdate;
    end;
    cbFilterV.Text := '';
    vtPopulateTensorList;
  finally
    FUpdatingChecks := False;
  end;
end;

procedure TfrmViewTensors.btnNavLeftClick(Sender: TObject);
var
  Step: Int64;
begin
  if FCurrentEndIdx <= FCurrentStartIdx then
    Exit;
  Step := Max(1, (FCurrentEndIdx - FCurrentStartIdx) div 4); // Déplacement de 25% de la fenêtre

  if FCurrentStartIdx - Step < 0 then
    begin
      FCurrentStartIdx := 0;
      FCurrentEndIdx := Max(FCurrentEndIdx - Step, cfg.MinXAxisRang);
    end
  else
    begin
      FCurrentStartIdx := FCurrentStartIdx - Step;
      FCurrentEndIdx := FCurrentEndIdx - Step;
    end;
  RefreshActiveView(False);
end;

procedure TfrmViewTensors.btnNavRightClick(Sender: TObject);
var
  Step: Int64;
begin
  if FCurrentStartIdx >= FGlobalMaxElems - 1 - cfg.MinXAxisRang then
    Exit;
  Step := Max(1, (FCurrentEndIdx - FCurrentStartIdx) div 4);

  if FCurrentEndIdx + Step > FGlobalMaxElems - 1 - cfg.MinXAxisRang then
    begin
      FCurrentEndIdx := FGlobalMaxElems - 1;
      if Step > cfg.MinXAxisRang then
        FCurrentStartIdx := FCurrentEndIdx - Step
      else
        FCurrentStartIdx := FCurrentEndIdx - cfg.MinXAxisRang;
      if FCurrentStartIdx < 0 then
        FCurrentStartIdx := 0;
    end
  else
    begin
      FCurrentStartIdx := FCurrentStartIdx + Step;
      FCurrentEndIdx := FCurrentEndIdx + Step;
    end;
  RefreshActiveView(False);
end;

procedure TfrmViewTensors.btnZoomInClick(Sender: TObject);
var
  Range, Center, NewRange: Int64;
begin
  if FGlobalMaxElems <= 1 then
    Exit;
  Range := FCurrentEndIdx - FCurrentStartIdx;
  if Range <= cfg.MinXAxisRang then
    Exit;
  // Déjà au zoom max

  // Zoom centré : réduit la fenêtre de 50% tout en gardant le point milieu
  Center := FCurrentStartIdx + Round(Range / 2);
  NewRange := Max(1, Round(Range / 2));

  FCurrentStartIdx := Max(0, Center - Round(NewRange / 2));
  FCurrentEndIdx := Min(FGlobalMaxElems - 1, Center + Round(NewRange / 2));
  RefreshActiveView(False);
end;

procedure TfrmViewTensors.chkCntAutoClick(Sender: TObject);
begin
  if FHistQuiet then
    Exit;
  cfg.bHistNAuto := chkCntAuto.Checked;
  edtCntMin.Enabled := not chkCntAuto.Checked;
  edtCntMin.ReadOnly := chkCntAuto.Checked;
  edtCntMax.Enabled := not chkCntAuto.Checked;
  edtCntMax.ReadOnly := chkCntAuto.Checked;
  HistoApplyCountsAxis; // pas de regeneration utile
end;

procedure TfrmViewTensors.edtCntMinKeyPress(Sender: TObject; var Key: Char);
begin
  if Key <> #13 then Exit;
  Key := #0;
  HistoApplyCountsAxis;
end;

end.

