unit uViewTensors;

interface

uses
  Winapi.Windows, Winapi.Messages, Winapi.CommCtrl, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.ExtCtrls, VclTee.TeeProcs, VclTee.TeEngine, VclTee.Chart, VclTee.Series,
  Vcl.StdCtrls, Vcl.CheckLst, Vcl.ComCtrls, System.SyncObjs, Generics.Collections, VclTee.TeeGDIPlus,
  System.Diagnostics, uGGUFModel, uGGMLTypes, uGgmlQuants, uAppConfig, uRangeSlider, uMath;

type
  TDiffStats = record
    Count, MaxIdx, MinIdx: Int64;
    Mean, RMS, MAE, MaxDiff, MinDiff: Double;
  end;

type
  TfrmViewTensors = class(TForm)
    PanelTop: TPanel;
    SaveDialog1: TSaveDialog;
    StatusBar1: TStatusBar;
    PanelLeft: TPanel;
    PanelLeftBot2: TPanel;
    PanelLeftTop: TPanel;
    ChListBoxTensors: TCheckListBox;
    pnlFilters: TPanel;
    cbFilterV: TComboBox;
    chkM1: TCheckBox;
    chkM2: TCheckBox;
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
    btnApply1: TButton;
    edtXMax: TEdit;
    edtXMin: TEdit;
    chkXAxisAuto: TCheckBox;
    TabHist: TTabSheet;
    Chart2: TChart;
    PanChart2Top: TPanel;
    btnHistogram: TButton;
    btnResetZoom2: TButton;
    Splitter3: TSplitter;
    Splitter4: TSplitter;
    ProgressBar1: TProgressBar;
    ProgressBar2: TProgressBar;
    lvSeries: TListView;
    PanelLeftBot1: TPanel;
    brnClearAllSelected: TButton;
    Label1: TLabel;
    btnResetZoom: TButton;
    btnZoomOut: TButton;
    btnZoomIn: TButton;
    btnNavRight: TButton;
    btnNavLeft: TButton;
    pnlBaseBotSlider: TPanel;
    pnlRangeSlider1: TPanel;
    chkMS: TCheckBox;
    chkUseImpl: TCheckBox;
    chkUseDLL: TCheckBox;
    cbNbrSelect: TComboBox;

    procedure SetUiFromCfg(var c: TGlobalConfig);
    procedure SetCfgFromUi(var c: TGlobalConfig);

    procedure FormCreate(Sender: TObject);
    procedure btnResetZoomClick(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure btnApply1Click(Sender: TObject);
    procedure btnHistogramClick(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);

    procedure UpdateFilterTypeItems;
    function GetFormatTensorNameList(T: TGGUFTensorInfo): String;
    procedure PopulateTensorList;

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
    procedure btnResetZoom2Click(Sender: TObject);

    // NOUVEAUX EVENTS X-Axis
    procedure chkXAxisAutoClick(Sender: TObject);
    procedure brnClearAllSelectedClick(Sender: TObject);
    procedure chkT1vT2Click(Sender: TObject);
    procedure ChListBoxTensorsClickCheck(Sender: TObject);
    procedure lvSeriesAdvancedCustomDrawItem(Sender: TCustomListView; Item: TListItem; State: TCustomDrawState;
      Stage: TCustomDrawStage; var DefaultDraw: Boolean);
    procedure cbFilterVChange(Sender: TObject);
    procedure chkUseDLLClick(Sender: TObject);
    procedure chkUseImplClick(Sender: TObject);
    procedure chkMOutClick(Sender: TObject);
    procedure edtXMinKeyPress(Sender: TObject; var Key: Char);
    procedure edtYMinKeyPress(Sender: TObject; var Key: Char);
    procedure FormDestroy(Sender: TObject);
    function GetLimitFromCombo: Integer;
    procedure EnforceSelectionLimit;
    procedure cbNbrSelectChange(Sender: TObject);

  private
    FModel1: TGGUFFile;
    FModel2: TGGUFFile;
    FModelS: TGGUFFile;
    FModelOut: TGGUFFile;
    xT1, xT2: TGGUFTensorInfo;
    FUpdatingXAxis: Boolean;
    FIsZooming: Boolean;
    FCancelThread: Boolean;

    // CHAMPS POUR LA NAVIGATION ---
    FCurrentStartIdx, FCurrentEndIdx: Int64;
    FCurrentStartIdxMan, FCurrentEndIdxMan: Int64;
    FGlobalMaxElems: Int64;

    // CHAMPS POUR NAVIGATION SOURIS CUSTOM
    FIsDragging: Boolean;
    FDragStartX: Integer;
    FDragStartMinX, FDragStartMaxX: Double;

    FRangeSlider: TRangeSlider;
    FSelectionOrder: TList<Integer>; // Garde l'ordre des tenseurs sélectionnés
    FCurrDiffStats: TDiffStats; // Stocke les résultats temporaires
    FElapsedMs: Double;

    procedure RefreshChart(StartX, EndX: Double; ForceFullRange: Boolean = False);
    procedure AddSeriesToListView(T: TGGUFTensorInfo; Title: String; c: Integer);
    procedure AddTensorDataToChart(T: TGGUFTensorInfo; StartIdx, EndIdx: Int64; LS1: TFastLineSeries;
      OutlierS, BlockS: TPointSeries; bShowBlockS: Boolean = true; bShowOutlierS: Boolean = true;
      UseDLL: Boolean = true);
    procedure AddTensorDiffDataToChart(T1, T2: TGGUFTensorInfo; StartIdx, EndIdx: Int64; LS1, LS2, LS3: TFastLineSeries;
      BlockS: TPointSeries; bShowBlockS: Boolean = true; UseDLL: Boolean = true);

    function FormatTensorLogInfo(T: TGGUFTensorInfo): string;

    procedure OnProgressFB(const Msg: string; ATIdx, ATTotal, AIdx, ATotal: Int64);

    procedure GenerateHistogramData(T: TGGUFTensorInfo; Series: TBarSeries; UseDLL: Boolean = true);
    procedure UpdateStatusBarDiffStats(const Stats: TDiffStats; ElapsedMs: Double);

  public
    property ModelA: TGGUFFile read FModel1 write FModel1;
    property ModelB: TGGUFFile read FModel2 write FModel2;
    property ModelS: TGGUFFile read FModelS write FModelS;
    property ModelOut: TGGUFFile read FModelOut write FModelOut;

  end;

procedure vLogMsg(const S: string);

var
  frmViewTensors: TfrmViewTensors;

implementation

uses uEditTensors, uEditTensorsMan, uLog, uLangManager;

{$R *.dfm}

procedure vLogMsg(const S: string);
begin
  TThread.Queue(nil,
    procedure
    begin
      frmViewTensors.StatusBar1.Panels[0].Text := S;
    end);

  // Logging fichier/debug
  if Assigned(frmLogs) then
    LogMsg('[VIEW]  ' + S)
  else
    OutputDebugString(PChar('[VIEW]  ' + S));
end;

// CONFIGURATION & INIT
procedure TfrmViewTensors.SetUiFromCfg(var c: TGlobalConfig);
begin
  chkUseDLL.Checked := c.UseFDLL;
  chkUseImpl.Checked := c.UseFImpl;

  FUpdatingXAxis := true;
  cbFilterV.Text := c.cbFilterV;
  chkYAxisAuto.Checked := c.chkYAxisAuto;
  SetedtYMinedtYMaxValus(c.YAxisMinMan, c.YAxisMaxMan);
  chkXAxisAuto.Checked := c.chkXAxisAuto;
  cbNbrSelect.Text := c.sTensorsPerChart;
  chkT1vT2.Checked := c.chkT1vT2;
  edtXMin.Text := IntToStr(c.XStartIdxMan);
  edtXMax.Text := IntToStr(c.XEndIdxMan);
  FUpdatingXAxis := False;
end;

procedure TfrmViewTensors.SetCfgFromUi(var c: TGlobalConfig);
begin
  c.cbFilterV := cbFilterV.Text;

  c.chkYAxisAuto := chkYAxisAuto.Checked;

  c.YAxisMinMan := StrToFloatDef(edtYMin.Text, -0.1);
  c.YAxisMaxMan := StrToFloatDef(edtYMax.Text, 0.1);

  c.chkXAxisAuto := chkXAxisAuto.Checked;

  c.sTensorsPerChart := cbNbrSelect.Text;
  if c.sTensorsPerChart = 'ONE' then
    c.iTensorsPerChart := 1
  else if c.sTensorsPerChart = 'ONE ONLY' then
    c.iTensorsPerChart := 1
  else if c.sTensorsPerChart = 'ALL' then
    c.iTensorsPerChart := SAFETY_MAX_TENSORS
  else
    c.iTensorsPerChart := StrToInt64Def(c.sTensorsPerChart, 2);

  c.chkT1vT2 := chkT1vT2.Checked;

  // S'assurer que les valeurs sont des Int64 corrects
  c.XStartIdxMan := StrToInt64Def(edtXMin.Text, 0);
  c.XEndIdxMan := StrToInt64Def(edtXMax.Text, 1024);
end;

procedure TfrmViewTensors.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  FCancelThread := true;
  SetCfgFromUi(cfg);
  cfgSaveSettings(cfg);
  // FRangeSlider.Free;
end;

procedure TfrmViewTensors.FormCreate(Sender: TObject);
begin
  KeyPreview := true; // Nécessaire pour intercepter les touches < > + -
  FIsZooming := False;
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
  Chart1.DoubleBuffered := true;

  Chart2.Legend.Visible := False; // Pour l'histogramme

  FRangeSlider := TRangeSlider.Create(Self);
  FRangeSlider.Parent := pnlRangeSlider1;
  FRangeSlider.Align := alClient;
  FRangeSlider.Margins.SetBounds(1, 1, 1, 1);
  FRangeSlider.AlignWithMargins := true;
  FRangeSlider.OnChange := SliderChange;

  // Initialisation des valeurs
  FRangeSlider.MinVal := 0;
  FRangeSlider.MaxVal := 1000;

  FSelectionOrder := TList<Integer>.Create;

  // cfgLoadSettings(cfg);
  SetUiFromCfg(cfg);
end;

procedure TfrmViewTensors.FormDestroy(Sender: TObject);
begin
  FSelectionOrder.Free;
end;

// Quand l'utilisateur bouge le slider -> On met à jour le graphique
procedure TfrmViewTensors.SliderChange(Sender: TObject);
begin
  if FGlobalMaxElems <= 0 then
    Exit;
  // Conversion du ratio (0..1000) en indices réels
  FCurrentStartIdx := Round(FRangeSlider.StartIdx * FGlobalMaxElems / 1000.0);
  FCurrentEndIdx := Round(FRangeSlider.EndIdx * FGlobalMaxElems / 1000);

  // On force le rafraîchissement du graphique sans déclencher de boucle infinie
  // (On utilise une variable flag ou on vérifie si les valeurs ont vraiment changé)
  RefreshChart(FCurrentStartIdx, FCurrentEndIdx, False);
end;

// ============================================================================
// CLAVIER
// ============================================================================
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

procedure TfrmViewTensors.FormShow(Sender: TObject);
begin
  PopulateTensorList;
  // LogMsg('Système prêt. Sélectionnez les tenseurs à analyser.');
  // LogMsg(mLang.gMsg('SystemReady'));
  vLogMsg(mLang.gMsg('FVT.SystemReady'));
end;

function TfrmViewTensors.FormatTensorLogInfo(T: TGGUFTensorInfo): string;
begin
  Result := Format('%s-%s-%s', [string(T.Name), GGMLTypeToStr(Integer(T.TensorType)), FormatBytes(T.ByteSize)]);
end;

procedure TfrmViewTensors.lvSeriesAdvancedCustomDrawItem(Sender: TCustomListView; Item: TListItem;
State: TCustomDrawState; Stage: TCustomDrawStage; var DefaultDraw: Boolean);
var
  SeriesColor: TColor;
  RectColor: TRect;
  T: TGGUFTensorInfo;
begin
  T := TGGUFTensorInfo(Item.Data);
  SeriesColor := T.SeriesColor;
  if SeriesColor > 0 then
    Sender.Canvas.Font.Color := SeriesColor
  else
    Sender.Canvas.Font.Color := clblack;

  if Item.Index mod 2 = 0 then
    Sender.Canvas.Brush.Color := $00ECECEC
  else
    Sender.Canvas.Brush.Color := clWhite;
end;

procedure TfrmViewTensors.btnApply1Click(Sender: TObject);
begin
  RefreshChart(0, 0, true);
end;

procedure TfrmViewTensors.UpdateStatusBarDiffStats(const Stats: TDiffStats; ElapsedMs: Double);
begin
  if not Assigned(StatusBar1) or (StatusBar1.Panels.Count < 4) then
    Exit;
  // Panneau 0 : Count & Min Diff & Max Diff & Temps d'exécution & Mode
  StatusBar1.Panels[0].Text := Format('Count: %d | Min: %.6f  | Max: %.6f | Diff: %.2f ms',
    [Stats.Count, Stats.MinDiff, Stats.MaxDiff, ElapsedMs]);
  if Stats.Count > 0 then
  begin
    // Panneau 1 : MAE
    StatusBar1.Panels[1].Text := Format('MAE: %.6f', [Stats.MAE]);
    // Panneau 2 :RMS
    StatusBar1.Panels[2].Text := Format('RMS: %.6f', [Stats.RMS]);
    // Panneau 3 : Moyenne
    StatusBar1.Panels[3].Text := Format('Mean: %.6f', [Stats.Mean]);
  end
  else
  begin
    StatusBar1.Panels[1].Text := 'No valid data';
    StatusBar1.Panels[2].Text := '';
    StatusBar1.Panels[3].Text := '';
  end;
end;

procedure TfrmViewTensors.AddTensorDataToChart(T: TGGUFTensorInfo; StartIdx, EndIdx: Int64; LS1: TFastLineSeries;
OutlierS, BlockS: TPointSeries; bShowBlockS: Boolean = true; bShowOutlierS: Boolean = true; UseDLL: Boolean = true);
var
  TotalElems, Range, StepSize: Int64;
  i, j: Integer;
  SrcBlockElems, SrcBlockBytes, DstBlockElems, DstBlockBytes, ix: Int64;
  TypeIdOrg, TypeIdTarget: Integer;
  FS: TFileStream;
  ReadIdx, ChunkIdx, ElemOffsetInChunk, ElementsToRead, BaseFileOffset: Int64;
  SrcBuf, TmpQBuf: TBytes;
  F32Buf: array of Single;
  TargetEnd: Int64;
  Val, LocalSum, LocalMean, lastLocalMean: Single;
  ValidCount: Integer;
  DoSimulation: Boolean;
  MaxBlockElems, SrcChunkBytes, DstChunkBytes, iOutlierS: Int64;
begin
  if not Assigned(T) then
    Exit;
  TotalElems := T.TotElems;
  if StartIdx < 0 then
    StartIdx := 0;
  if EndIdx >= TotalElems then
    EndIdx := TotalElems - 1;
  if StartIdx > EndIdx then
    Exit;

  TypeIdOrg := Integer(T.TensorTypeOrg);
  DoSimulation := T.IsConverted;
  if DoSimulation then
    TypeIdTarget := Integer(T.TensorType)
  else
    TypeIdTarget := TypeIdOrg;

  if GGML_TypeIsQuant(TypeIdOrg) then
  begin
    SrcBlockElems := GGML_BlockElems(TypeIdOrg);
    SrcBlockBytes := GGML_BlockBytes(TypeIdOrg);
  end
  else
  begin
    SrcBlockElems := Min(32, TotalElems);
    SrcBlockBytes := SrcBlockElems * GGML_TypeScalarSize(TypeIdOrg);
  end;

  if GGML_TypeIsQuant(TypeIdTarget) then
  begin
    DstBlockElems := GGML_BlockElems(TypeIdTarget);
    DstBlockBytes := GGML_BlockBytes(TypeIdTarget);
  end
  else
  begin
    DstBlockElems := Min(32, TotalElems);
    DstBlockBytes := DstBlockElems * GGML_TypeScalarSize(TypeIdTarget);
  end;

  if (SrcBlockElems <= 0) or (SrcBlockBytes <= 0) or (DstBlockElems <= 0) or (DstBlockBytes <= 0) then
    Exit;

  // Calcul du Super-Bloc (ex: 256 pour aligner 32 et 256)
  MaxBlockElems := Max(SrcBlockElems, DstBlockElems);
  if (MaxBlockElems mod SrcBlockElems <> 0) or (MaxBlockElems mod DstBlockElems <> 0) then
    MaxBlockElems := SrcBlockElems * DstBlockElems; // Fallback sécurité

  // On calcule la taille totale en octets pour lire MaxBlockElems d'un coup
  SrcChunkBytes := (MaxBlockElems div SrcBlockElems) * SrcBlockBytes;
  DstChunkBytes := (MaxBlockElems div DstBlockElems) * DstBlockBytes;

  SetLength(SrcBuf, SrcChunkBytes);
  SetLength(TmpQBuf, DstChunkBytes);
  SetLength(F32Buf, MaxBlockElems);

  // FS := TFileStream.Create(T.SourceFile, fmOpenRead or fmShareDenyWrite);

  // Détection du fichier transposé
  // UseTransposedFile := ;
  if (T.IsTransposed and (T.TransposFile <> '') and (FileExists(T.TransposFile))) then
  begin
    FS := TFileStream.Create(T.TransposFile, fmOpenRead or fmShareDenyWrite);
    BaseFileOffset := 0; // Les dumps transposés sont bruts, départ à 0
  end
  else
  begin
    FS := TFileStream.Create(T.SourceFile, fmOpenRead or fmShareDenyWrite);
    BaseFileOffset := T.TensorDataFilePos + T.SourceOffset;
  end;

  try
    Range := EndIdx - StartIdx + 1;
    LocalSum := 0;
    ValidCount := 0;
    LocalMean := 0;
    lastLocalMean := 0;

    if Range <= (cfg.TVNumBins * cfg.TVPtsPerBin) then
    begin
      // MODE ZOOM RAPPROCHÉ
      ReadIdx := StartIdx;
      iOutlierS := 0;
      while ReadIdx <= EndIdx do
      begin
        iOutlierS := 0;
        ChunkIdx := ReadIdx div MaxBlockElems;
        ElemOffsetInChunk := ReadIdx mod MaxBlockElems;

        // Lecture d'un Super-Bloc complet (ex: 8x34 = 272 octets)
        // FS.Position := T.TensorDataFilePos + T.SourceOffset + (ChunkIdx * SrcChunkBytes);
        FS.Position := BaseFileOffset + (ChunkIdx * SrcChunkBytes);

        FS.ReadBuffer(SrcBuf[0], SrcChunkBytes);

        // Déquantification en une seule passe : les 256 floats sont remplis !
        Dequant(@SrcBuf[0], @F32Buf[0], MaxBlockElems, TypeIdOrg, UseDLL);

        if DoSimulation then
        begin
          // F32Buf contient bien 256 vraies valeurs, aucun plantage
          Quant(@F32Buf[0], @TmpQBuf[0], MaxBlockElems, TypeIdTarget, UseDLL);
          Dequant(@TmpQBuf[0], @F32Buf[0], MaxBlockElems, TypeIdTarget, UseDLL);
        end;

        { for i := 0 to MaxBlockElems - 1 do
          begin
          if not IsNaN(F32Buf[i]) and not IsInfinite(F32Buf[i]) then
          begin
          LocalSum := LocalSum + Abs(F32Buf[i]);
          if ValidCount > 31 then
          LocalSum := LocalSum - LocalMean
          else
          Inc(ValidCount);
          end;
          end;
          if ValidCount > 0 then
          LocalMean := LocalSum / ValidCount
          else
          LocalMean := 0; }

        ElementsToRead := Min(MaxBlockElems - ElemOffsetInChunk, EndIdx - ReadIdx + 1);
        for i := 0 to ElementsToRead - 1 do
        begin
          ix := ReadIdx + i;
          Val := F32Buf[ElemOffsetInChunk + i];
          if TypeIdTarget = 40 then
            Val := Val * cfg.NVFP4_Scale;
          if IsNaN(Val) then
            OutlierS.AddXY(ix, 0, '', clWhite) // 'NaN
          else if IsInfinite(Val) then
          begin
            OutlierS.AddXY(ix, 0, '', clFuchsia); // 'Inf
          end
          else
          begin
            if Range < 1024 then
            begin
              if bShowBlockS and (ix mod 32 = 0) then
                BlockS.AddXY(ix, Val, '', clYellow)
            end
            else if Range < 8192 then
              if bShowBlockS and (ix mod 256 = 0) then
                BlockS.AddXY(ix, Val, '', clLime);

            LS1.AddXY(ix, Val);
            if bShowOutlierS and (iOutlierS < 4) and (Range < 320000) then
            begin
              LocalSum := LocalSum + Abs(Val);
              if ValidCount > 31 then
                LocalSum := LocalSum - LocalMean
              else
                Inc(ValidCount);
              if ValidCount > 0 then
                LocalMean := LocalSum / ValidCount
              else
                LocalMean := 0;
              if ValidCount > 4 then
                if (LocalMean > 0.0001) and (Abs(Val) > (LocalMean * 8)) then
                begin
                  OutlierS.AddXY(ix, Val, '', clRed);
                  // LocalSum := LocalSum - Abs(Val);
                  iOutlierS := iOutlierS + 1;
                end;
            end;
          end;
        end;
        Inc(ReadIdx, ElementsToRead);
      end;
    end
    else
    begin
      // MODE ÉCHANTILLONNAGE (LOD)
      StepSize := Max(1, Range div cfg.TVNumBins);
      for i := 0 to cfg.TVNumBins - 1 do
      begin
        ReadIdx := StartIdx + (i * StepSize);
        TargetEnd := Min(ReadIdx + cfg.TVPtsPerBin - 1, EndIdx);
        iOutlierS := 0;

        while ReadIdx <= TargetEnd do
        begin
          ChunkIdx := ReadIdx div MaxBlockElems;
          ElemOffsetInChunk := ReadIdx mod MaxBlockElems;

          // FS.Position := T.TensorDataFilePos + T.SourceOffset + (ChunkIdx * SrcChunkBytes);
          FS.Position := BaseFileOffset + (ChunkIdx * SrcChunkBytes);

          FS.ReadBuffer(SrcBuf[0], SrcChunkBytes);

          Dequant(@SrcBuf[0], @F32Buf[0], MaxBlockElems, TypeIdOrg, UseDLL);

          if DoSimulation then
          begin
            Quant(@F32Buf[0], @TmpQBuf[0], MaxBlockElems, TypeIdTarget, UseDLL);
            Dequant(@TmpQBuf[0], @F32Buf[0], MaxBlockElems, TypeIdTarget, UseDLL);
          end;

          ElementsToRead := Min(MaxBlockElems - ElemOffsetInChunk, TargetEnd - ReadIdx + 1);
          for j := 0 to ElementsToRead - 1 do
          begin
            ix := ReadIdx + j; // ix := ReadIdx + i;
            Val := F32Buf[ElemOffsetInChunk + j];
            if TypeIdTarget = 40 then
              Val := Val * cfg.NVFP4_Scale;

            if IsNaN(Val) then
              OutlierS.AddXY(ix, 0, '', clWhite) // 'NaN
            else if IsInfinite(Val) then
              OutlierS.AddXY(ix, 0, '', clFuchsia) // 'Inf'
            else
            begin
              if Range < 8192 then
                if bShowBlockS and (ix mod 256 = 0) then
                  BlockS.AddXY(ix, Val, '', clRed);

              LS1.AddXY(ix, Val);
              if bShowOutlierS and (iOutlierS < 4) then
              begin
                LocalSum := LocalSum + Abs(Val);
                if ValidCount > 31 then
                  LocalSum := LocalSum - LocalMean
                else
                  Inc(ValidCount);
                if ValidCount > 1 then
                  LocalMean := LocalSum / ValidCount
                else
                  LocalMean := 0;
                if ValidCount > 4 then
                  if (LocalMean > 0.0001) and (Abs(Val) > (LocalMean * 8)) then
                  begin
                    OutlierS.AddXY(ix, Val, '', clRed);
                    // LocalSum := LocalSum - Abs(Val);
                    iOutlierS := iOutlierS + 1;
                  end;
              end;
            end;
          end;
          Inc(ReadIdx, ElementsToRead);
        end;
      end;
    end;
  finally
    FS.Free;
  end;
end;

procedure TfrmViewTensors.AddTensorDiffDataToChart(T1, T2: TGGUFTensorInfo; StartIdx, EndIdx: Int64;
LS1, LS2, LS3: TFastLineSeries; BlockS: TPointSeries; bShowBlockS: Boolean = true; UseDLL: Boolean = true);
var
  TotalElems, Range, StepSize: Int64;
  i, k: Integer;
  SrcE1, SrcB1, DstE1, DstB1, SrcE2, SrcB2, DstE2, DstB2: Int64;
  FS1, FS2: TFileStream;
  SrcBuf1, SrcBuf2, SimBuf1, SimBuf2: TBytes;
  FP1, FP2: array of Single;
  ReadIdx, ChunkIdx, Off, ix: Int64;
  V1, V2, Diff, AbsDiff: Single;
  DoSim1, DoSim2: Boolean;
  Type1Org, Type2Org, Type1Tgt, Type2Tgt: Integer;
  TargetEnd, ElementsToRead: Int64;
  MaxBlockElems, Src1ChunkBytes, Dst1ChunkBytes, Src2ChunkBytes, Dst2ChunkBytes: Int64;
  SafeRange: Int64;
  BaseFileOffset1, BaseFileOffset2: Int64;
  UseTransposedFile1, UseTransposedFile2: Boolean;
  // VARIABLES STATISTIQUES
  SumDiff, SumSqDiff, SumAbsDiff: Double;
  CountDiff: Int64;
  MaxDiff, MinDiff: Double;
  MaxDiffIdx, MinDiffIdx: Int64;
  Sw: TStopwatch; // Chronomètre haute précision
begin
  if not Assigned(T1) or not Assigned(T2) or (StartIdx >= EndIdx) then
    Exit;

  TotalElems := Max(T1.TotElems, T2.TotElems);
  StartIdx := Max(0, StartIdx);
  EndIdx := Min(TotalElems - 1, EndIdx);
  if StartIdx >= EndIdx then
    Exit;

  Type1Org := Integer(T1.TensorTypeOrg);
  Type2Org := Integer(T2.TensorTypeOrg);
  Type1Tgt := Integer(T1.TensorType);
  Type2Tgt := Integer(T2.TensorType);
  DoSim1 := T1.IsConverted;
  DoSim2 := T2.IsConverted;

  if GGML_TypeIsQuant(Type1Org) then
  begin
    SrcE1 := GGML_BlockElems(Type1Org);
    SrcB1 := GGML_BlockBytes(Type1Org);
  end
  else
  begin
    SrcE1 := Min(32, TotalElems);
    SrcB1 := 32 * GGML_TypeScalarSize(Type1Org);
  end;
  if GGML_TypeIsQuant(Type2Org) then
  begin
    SrcE2 := GGML_BlockElems(Type2Org);
    SrcB2 := GGML_BlockBytes(Type2Org);
  end
  else
  begin
    SrcE2 := Min(32, TotalElems);
    SrcB2 := 32 * GGML_TypeScalarSize(Type2Org);
  end;
  if GGML_TypeIsQuant(Type1Tgt) then
  begin
    DstE1 := GGML_BlockElems(Type1Tgt);
    DstB1 := GGML_BlockBytes(Type1Tgt);
  end
  else
  begin
    DstE1 := Min(32, TotalElems);
    DstB1 := 32 * GGML_TypeScalarSize(Type1Tgt);
  end;
  if GGML_TypeIsQuant(Type2Tgt) then
  begin
    DstE2 := GGML_BlockElems(Type2Tgt);
    DstB2 := GGML_BlockBytes(Type2Tgt);
  end
  else
  begin
    DstE2 := Min(32, TotalElems);
    DstB2 := 32 * GGML_TypeScalarSize(Type2Tgt);
  end;

  MaxBlockElems := Max(Max(SrcE1, DstE1), Max(SrcE2, DstE2));
  if (MaxBlockElems mod SrcE1 <> 0) or (MaxBlockElems mod SrcE2 <> 0) then
    MaxBlockElems := 256;

  Src1ChunkBytes := ((MaxBlockElems + SrcE1 - 1) div SrcE1) * SrcB1;
  Src2ChunkBytes := ((MaxBlockElems + SrcE2 - 1) div SrcE2) * SrcB2;
  Dst1ChunkBytes := ((MaxBlockElems + DstE1 - 1) div DstE1) * DstB1;
  Dst2ChunkBytes := ((MaxBlockElems + DstE2 - 1) div DstE2) * DstB2;

  SetLength(SrcBuf1, Src1ChunkBytes);
  SetLength(SimBuf1, Dst1ChunkBytes);
  SetLength(SrcBuf2, Src2ChunkBytes);
  SetLength(SimBuf2, Dst2ChunkBytes);
  SetLength(FP1, MaxBlockElems);
  SetLength(FP2, MaxBlockElems);

  // INITIALISATION ACCUMULATEURS
  SumDiff := 0;
  SumSqDiff := 0;
  SumAbsDiff := 0;
  CountDiff := 0;
  MaxDiff := -MaxDouble;
  MinDiff := MaxDouble;
  MaxDiffIdx := -1;
  MinDiffIdx := -1;

  UseTransposedFile1 := (T1.IsTransposed and (T1.TransposFile <> '') and (FileExists(T1.TransposFile)));
  UseTransposedFile2 := (T2.IsTransposed and (T2.TransposFile <> '') and (FileExists(T2.TransposFile)));
  if UseTransposedFile1 then
  begin
    FS1 := TFileStream.Create(T1.TransposFile, fmOpenRead or fmShareDenyWrite);
    BaseFileOffset1 := 0;
  end
  else
  begin
    FS1 := TFileStream.Create(T1.SourceFile, fmOpenRead or fmShareDenyWrite);
    BaseFileOffset1 := T1.TensorDataFilePos + T1.SourceOffset;
  end;

  if UseTransposedFile2 then
  begin
    FS2 := TFileStream.Create(T2.TransposFile, fmOpenRead or fmShareDenyWrite);
    BaseFileOffset2 := 0;
  end
  else
  begin
    FS2 := TFileStream.Create(T2.SourceFile, fmOpenRead or fmShareDenyWrite);
    BaseFileOffset2 := T2.TensorDataFilePos + T2.SourceOffset;
  end;

  // DÉBUT DU CHRONOMÉTRAGE
  Sw := TStopwatch.StartNew;

  try
    Range := EndIdx - StartIdx + 1;
    SafeRange := Int64(cfg.TVNumBins) * cfg.TVPtsPerBin;
    // MODE 1 : ZOOM RAPPROCHÉ
    if Range <= SafeRange then
    begin
      ReadIdx := StartIdx;
      while ReadIdx <= EndIdx do
      begin
        ChunkIdx := ReadIdx div MaxBlockElems;
        Off := ReadIdx mod MaxBlockElems;
        FS1.Position := BaseFileOffset1 + (ChunkIdx * Src1ChunkBytes);
        FS1.ReadBuffer(SrcBuf1[0], Src1ChunkBytes);
        FS2.Position := BaseFileOffset2 + (ChunkIdx * Src2ChunkBytes);
        FS2.ReadBuffer(SrcBuf2[0], Src2ChunkBytes);

        Dequant(@SrcBuf1[0], @FP1[0], MaxBlockElems, Type1Org, UseDLL);
        Dequant(@SrcBuf2[0], @FP2[0], MaxBlockElems, Type2Org, UseDLL);

        if DoSim1 then
        begin
          Quant(@FP1[0], @SimBuf1[0], MaxBlockElems, Type1Tgt, UseDLL);
          Dequant(@SimBuf1[0], @FP1[0], MaxBlockElems, Type1Tgt, UseDLL);
        end;
        if DoSim2 then
        begin
          Quant(@FP2[0], @SimBuf2[0], MaxBlockElems, Type2Tgt, UseDLL);
          Dequant(@SimBuf2[0], @FP2[0], MaxBlockElems, Type2Tgt, UseDLL);
        end;

        ElementsToRead := Min(MaxBlockElems - Off, EndIdx - ReadIdx + 1);
        if ElementsToRead <= 0 then
          Break;
        for k := 0 to ElementsToRead - 1 do
        begin
          V1 := FP1[Off + k];
          V2 := FP2[Off + k];
          if Type1Tgt = 40 then
            V1 := V1 * cfg.NVFP4_Scale;
          if Type2Tgt = 40 then
            V2 := V2 * cfg.NVFP4_Scale;
          ix := ReadIdx + k;
          if not IsNaN(V1) and not IsInfinite(V1) then
            LS1.AddXY(ix, V1);
          if not IsNaN(V2) and not IsInfinite(V2) then
            LS2.AddXY(ix, V2);
          Diff := V1 - V2;
          if Range <= 512 then
            if bShowBlockS and (ix mod 32 = 0) then
              BlockS.AddXY(ix, V1, '', clYellow)
            else if (Range <= 8192) then
              if bShowBlockS and (ix mod 256 = 0) then
                BlockS.AddXY(ix, V1, '', clLime);

          if not IsNaN(Diff) and not IsInfinite(Diff) then
          begin
            LS3.AddXY(ix, Diff * cfg.DiffAmplificationFactor);
            AbsDiff := Abs(Diff);
            Inc(CountDiff);
            SumDiff := SumDiff + Diff;
            SumSqDiff := SumSqDiff + (Diff * Diff);
            SumAbsDiff := SumAbsDiff + AbsDiff;
            if Diff > MaxDiff then
            begin
              MaxDiff := Diff;
              MaxDiffIdx := ix;
            end;
            if Diff < MinDiff then
            begin
              MinDiff := Diff;
              MinDiffIdx := ix;
            end;
          end;
        end;
        Inc(ReadIdx, ElementsToRead);
      end;
    end
    else
    begin
      // MODE 2 : ÉCHANTILLONNAGE (LOD)
      StepSize := Max(1, Range div cfg.TVNumBins);
      for i := 0 to cfg.TVNumBins - 1 do
      begin
        ReadIdx := StartIdx + (i * StepSize);
        TargetEnd := Min(ReadIdx + cfg.TVPtsPerBin - 1, EndIdx);
        while ReadIdx <= TargetEnd do
        begin
          ChunkIdx := ReadIdx div MaxBlockElems;
          Off := ReadIdx mod MaxBlockElems;
          FS1.Position := BaseFileOffset1 + (ChunkIdx * Src1ChunkBytes);
          FS1.ReadBuffer(SrcBuf1[0], Src1ChunkBytes);
          FS2.Position := BaseFileOffset2 + (ChunkIdx * Src2ChunkBytes);
          FS2.ReadBuffer(SrcBuf2[0], Src2ChunkBytes);

          Dequant(@SrcBuf1[0], @FP1[0], MaxBlockElems, Type1Org, UseDLL);
          Dequant(@SrcBuf2[0], @FP2[0], MaxBlockElems, Type2Org, UseDLL);

          if DoSim1 then
          begin
            Quant(@FP1[0], @SimBuf1[0], MaxBlockElems, Type1Tgt, UseDLL);
            Dequant(@SimBuf1[0], @FP1[0], MaxBlockElems, Type1Tgt, UseDLL);
          end;
          if DoSim2 then
          begin
            Quant(@FP2[0], @SimBuf2[0], MaxBlockElems, Type2Tgt, UseDLL);
            Dequant(@SimBuf2[0], @FP2[0], MaxBlockElems, Type2Tgt, UseDLL);
          end;
          ElementsToRead := Min(MaxBlockElems - Off, TargetEnd - ReadIdx + 1);
          if ElementsToRead <= 0 then
            Break;
          for k := 0 to ElementsToRead - 1 do
          begin
            V1 := FP1[Off + k];
            V2 := FP2[Off + k];
            if Type1Tgt = 40 then
              V1 := V1 * cfg.NVFP4_Scale;
            if Type2Tgt = 40 then
              V2 := V2 * cfg.NVFP4_Scale;
            if not IsNaN(V1) and not IsInfinite(V1) then
              LS1.AddXY(ReadIdx + k, V1);
            if not IsNaN(V2) and not IsInfinite(V2) then
              LS2.AddXY(ReadIdx + k, V2);
            Diff := V1 - V2;
            if not IsNaN(Diff) and not IsInfinite(Diff) then
            begin
              LS3.AddXY(ReadIdx + k, Diff * cfg.DiffAmplificationFactor);
              AbsDiff := Abs(Diff);
              Inc(CountDiff);
              SumDiff := SumDiff + Diff;
              SumSqDiff := SumSqDiff + (Diff * Diff);
              SumAbsDiff := SumAbsDiff + AbsDiff;
              if Diff > MaxDiff then
              begin
                MaxDiff := Diff;
                MaxDiffIdx := ReadIdx + k;
              end;
              if Diff < MinDiff then
              begin
                MinDiff := Diff;
                MinDiffIdx := ReadIdx + k;
              end;
            end;
          end;
          Inc(ReadIdx, ElementsToRead);
        end;
      end;
    end;
  finally
    Sw.Stop; // FIN DU CHRONOMÉTRAGE
    FElapsedMs := Sw.ElapsedMilliseconds;

    // Remplissage du record
    FCurrDiffStats.Count := CountDiff;
    FCurrDiffStats.MaxIdx := MaxDiffIdx;
    FCurrDiffStats.MinIdx := MinDiffIdx;
    if CountDiff > 0 then
    begin
      FCurrDiffStats.Mean := SumDiff / CountDiff;
      FCurrDiffStats.RMS := Sqrt(SumSqDiff / CountDiff);
      FCurrDiffStats.MAE := SumAbsDiff / CountDiff;
      FCurrDiffStats.MaxDiff := MaxDiff;
      FCurrDiffStats.MinDiff := MinDiff;
    end
    else
      FillChar(FCurrDiffStats, SizeOf(FCurrDiffStats), 0);
    UpdateStatusBarDiffStats(FCurrDiffStats, FElapsedMs);
    if CountDiff > 0 then
      // LogMsg(Format
      // ('[DIFF] %s vs %s | Plage:[%d..%d] | Éléments: %d | Mean=%.6f | RMS=%.6f | MAE=%.6f | MaxDiff=%.6f (@%d) | MinDiff=%.6f (@%d) | ⏱ %.2f ms',
      // [FormatTensorLogInfo(T1), FormatTensorLogInfo(T2), StartIdx, EndIdx, CountDiff, SumDiff / CountDiff,
      // Sqrt(SumSqDiff / CountDiff), SumAbsDiff / CountDiff, MaxDiff, MaxDiffIdx, MinDiff, MinDiffIdx, ElapsedMs]))
      //LogMsg(Format(mLang.gMsg('FVT.DiffLogFormat'), [FormatTensorLogInfo(T1), FormatTensorLogInfo(T2), StartIdx,
      //  EndIdx, CountDiff, SumDiff / CountDiff, Sqrt(SumSqDiff / CountDiff), SumAbsDiff / CountDiff, MaxDiff,
      //  MaxDiffIdx, MinDiff, MinDiffIdx, FElapsedMs]))
      LogMsg(mLang.gMsgFmt('FVT.DiffLogFormat', [FormatTensorLogInfo(T1), FormatTensorLogInfo(T2), StartIdx, EndIdx, CountDiff, SumDiff / CountDiff, Sqrt(SumSqDiff / CountDiff), SumAbsDiff / CountDiff, MaxDiff, MaxDiffIdx, MinDiff, MinDiffIdx, FElapsedMs]))

    else
      // LogMsg(Format('[DIFF] Aucune donnée valide comparée. | Éléments: 0 | ⏱ %.2f ms', [ElapsedMs]));
      LogMsg(mLang.gMsgFmt('FVT.DiffNoDataLog', [FElapsedMs]));
    FS1.Free;
    FS2.Free;
  end;
end;


// GRAPHIQUE & DÉTECTION OUTLIERS

// ============================================================================
// CORE: RefreshChart avec gestion de FCurrentSelectedTensorIndex
// ============================================================================
procedure TfrmViewTensors.RefreshChart(StartX, EndX: Double; ForceFullRange: Boolean = False);
var
  i: Integer;
  LS1, LS2, LS3: TFastLineSeries;
  OutlierS, BlockS: TPointSeries;
  SelectedTensors: TList;
  GlobalMaxElems, LocalStart, LocalEnd: Int64;
  T1, T2: TGGUFTensorInfo;
  CountChecked: Integer;
  IsT1vT2Mode: Boolean;
begin
  IsT1vT2Mode := cfg.chkT1vT2 and (cfg.iTensorsPerChart = 2);
  GlobalMaxElems := 0;
  // if IsT1vT2Mode then GlobalMaxElems := maxInt else GlobalMaxElems := 0;
  lvSeries.Items.BeginUpdate;
  SelectedTensors := TList.Create;
  try
    // Libérer les clones stockés dans Data avant le Clear
    for i := 0 to lvSeries.Items.Count - 1 do
    begin
      if Assigned(lvSeries.Items[i].Data) then
        TGGUFTensorInfo(lvSeries.Items[i].Data).Free;
    end;
    lvSeries.Items.Clear;
    Chart1.SeriesList.Clear;
    // Calculer le nouveau maximum global pour vérifier les limites  et Compter les tenseurs sélectionnés

    for i := 0 to ChListBoxTensors.Count - 1 do
      if ChListBoxTensors.Checked[i] then
      begin
        GlobalMaxElems := Max(GlobalMaxElems, (TGGUFTensorInfo(ChListBoxTensors.Items.Objects[i]).TotElems));
        SelectedTensors.Add(ChListBoxTensors.Items.Objects[i]);
      end;

    CountChecked := SelectedTensors.Count;
    FGlobalMaxElems := GlobalMaxElems;
    // Ne réinitialiser la plage que si le mode Auto est ON
    if ForceFullRange and chkXAxisAuto.Checked then
    begin
      // Mode Auto + Refresh forcé : plage complète
      FCurrentStartIdx := 0;
      FCurrentEndIdx := FGlobalMaxElems - 1;
    end
    else
    begin
      // Mode Manuel : préserver la plage, même si le nouveau tenseur est plus petit
      // Mode Manuel ou pas de ForceFullRange
      // FGlobalMaxElems := GlobalMaxElems;
      // Cas initial (0,0) avec des données :
      if (FCurrentEndIdx = FCurrentStartIdx) and (FCurrentEndIdx = 0) then
      begin
        FCurrentStartIdx := cfg.XStartIdxMan;
        FCurrentEndIdx := cfg.XEndIdxMan;
        if FGlobalMaxElems = 0 then
          FGlobalMaxElems := FCurrentEndIdx;
      end;

      if FCurrentEndIdx < FCurrentStartIdx then
      begin
        FCurrentStartIdx := 0;
        if FGlobalMaxElems > 0 then
          FCurrentEndIdx := FGlobalMaxElems - 1
        else
          FGlobalMaxElems := 1;
      end;
    end;

    StartX := FCurrentStartIdx;
    EndX := FCurrentEndIdx;
    if FGlobalMaxElems > 0 then
    begin
      FRangeSlider.MinVal := 0;
      FRangeSlider.MaxVal := 1000; // On utilise une échelle fixe de 1000 pour la précision du glissement
      FRangeSlider.StartIdx := Round((FCurrentStartIdx / FGlobalMaxElems) * 1000);
      FRangeSlider.EndIdx := Round((FCurrentEndIdx / FGlobalMaxElems) * 1000);
    end;

    Chart1.BottomAxis.SetMinMax(StartX, EndX);
    // Synchroniser les Edits
    FUpdatingXAxis := true;
    edtXMin.Text := IntToStr(FCurrentStartIdx);
    edtXMax.Text := IntToStr(FCurrentEndIdx);
    cfg.XStartIdxMan := FCurrentStartIdx;
    cfg.XEndIdxMan := FCurrentEndIdx;
    FUpdatingXAxis := False;

    if chkYAxisAuto.Checked then
    begin
      Chart1.LeftAxis.Automatic := true;
      SetedtYMinedtYMaxValus(Chart1.LeftAxis.Minimum, Chart1.LeftAxis.Maximum);
    end
    else
      UpdateYAxisRangeFromEdit;

    // Dessiner les séries

    // CAS SPÉCIAL : DIFFÉRENCE (T1 - T2)
    if (CountChecked = 2) and cfg.chkT1vT2 then
    begin
      T1 := TGGUFTensorInfo(SelectedTensors[0]);
      T2 := TGGUFTensorInfo(SelectedTensors[1]);
      LS1 := TFastLineSeries.Create(Chart1);
      LS1.ParentChart := Chart1;
      // LS1.Title := string(T1.Name);
      LS1.Title := GetFormatTensorNameList(T1);
      // LineSeries1.SeriesColor := clBlue;

      LS2 := TFastLineSeries.Create(Chart1);
      LS2.ParentChart := Chart1;
      // LS2.Title := string(T2.Name);
      LS2.Title := GetFormatTensorNameList(T2);
      // LineSeries2.SeriesColor := clGreen;

      LS3 := TFastLineSeries.Create(Chart1);
      LS3.ParentChart := Chart1;
      LS3.Title := 'Diff (T1 - T2)';
      // LineSeries2.SeriesColor := clGreen;

      BlockS := TPointSeries.Create(Chart1);
      BlockS.ParentChart := Chart1;
      BlockS.Title := 'Block256';
      BlockS.Pointer.Style := psArrow; // psArrow;
      BlockS.Pointer.Size := 7;
      BlockS.Color := clYellow;
      BlockS.ShowInLegend := False;

      LocalStart := Max(0, Trunc(StartX));
      LocalEnd := Min(T1.TotElems - 1, Trunc(EndX));
      LocalEnd := Min(T2.TotElems - 1, LocalEnd);

      LS1.BeginUpdate;
      LS2.BeginUpdate;
      LS3.BeginUpdate;
      BlockS.BeginUpdate;
      AddTensorDiffDataToChart(T1, T2, LocalStart, LocalEnd, LS1, LS2, LS3, BlockS, cfg.bShowBlockS, cfg.UseFDLL);
      LS1.EndUpdate;
      LS2.EndUpdate;
      LS3.EndUpdate;
      BlockS.EndUpdate;
      AddSeriesToListView(T1, LS1.Title, Integer(LS1.SeriesColor));
      AddSeriesToListView(T1, LS2.Title, Integer(LS2.SeriesColor));
      AddSeriesToListView(T1, LS3.Title, Integer(LS3.SeriesColor));
    end
    else
    begin
      for i := 0 to ChListBoxTensors.Count - 1 do
      begin
        if ChListBoxTensors.Checked[i] then
        begin
          T1 := TGGUFTensorInfo(ChListBoxTensors.Items.Objects[i]);

          LS1 := TFastLineSeries.Create(Chart1);
          LS1.ParentChart := Chart1;
          // LS1.Title := ChListBoxTensors.Items[i];
          LS1.Title := GetFormatTensorNameList(T1);

          OutlierS := TPointSeries.Create(Chart1);
          OutlierS.ParentChart := Chart1;
          OutlierS.Title := 'Anomalies ' + ChListBoxTensors.Items[i];
          OutlierS.Pointer.Style := psCircle;
          OutlierS.Pointer.Size := 3;
          OutlierS.Color := clRed;
          OutlierS.ShowInLegend := False;

          BlockS := TPointSeries.Create(Chart1);
          BlockS.ParentChart := Chart1;
          BlockS.Title := 'Block256';
          BlockS.Pointer.Style := psArrow; // psArrow;
          BlockS.Pointer.Size := 7;
          BlockS.Color := clYellow;
          BlockS.ShowInLegend := False;

          LocalStart := Max(0, Trunc(StartX));
          LocalEnd := Min(T1.TotElems - 1, Trunc(EndX));

          if LocalStart <= LocalEnd then
          begin
            LS1.BeginUpdate;
            OutlierS.BeginUpdate;
            BlockS.BeginUpdate;
            AddTensorDataToChart(T1, LocalStart, LocalEnd, LS1, OutlierS, BlockS, cfg.bShowBlockS, cfg.bShowOutlierS,
              cfg.UseFDLL);
            LS1.EndUpdate;
            OutlierS.EndUpdate;
            BlockS.EndUpdate;
          end;

          AddSeriesToListView(T1, LS1.Title, Integer(LS1.SeriesColor));
          // if Assigned(OutlierSeries) then
          // AddSeriesToListView(OutlierSeries);
        end;
      end;
    end;
  finally
    SelectedTensors.Free;
    lvSeries.Items.EndUpdate;
  end;
end;

procedure TfrmViewTensors.AddSeriesToListView(T: TGGUFTensorInfo; Title: String; c: Integer);
var
  aLItem: TListItem;
  T1: TGGUFTensorInfo;
begin
  if Title = '' then
    Exit;
  aLItem := lvSeries.Items.Add;
  aLItem.Caption := Title;
  // On stocke T dans la propriété .Data , pour pouvoir la récupérer au moment du dessin personnalisé.
  T1 := T.Clone;
  if Title = 'Diff (T1 - T2)' then
  begin
    T1.Name := 'Diff (T1 - T2)';
  end;
  T1.SeriesColor := c; // Integer(ASeries.SeriesColor);
  aLItem.Data := Pointer(T1);
end;

// Gestion du "Tout sélectionner"
procedure TfrmViewTensors.chkMOutClick(Sender: TObject);
begin
  PopulateTensorList;
end;

procedure TfrmViewTensors.chkT1vT2Click(Sender: TObject);
begin
  cfg.chkT1vT2 := chkT1vT2.Checked;
  if cfg.chkT1vT2 then
  begin
    cbNbrSelect.Text := '2'; // Force à "2"
    EnforceSelectionLimit;
  end;
  RefreshChart(FCurrentStartIdx, FCurrentEndIdx, False);
end;

procedure TfrmViewTensors.chkUseDLLClick(Sender: TObject);
begin
  frmEditTensors.SetUseDLLCfgFromUi(chkUseDLL.Checked);
end;

procedure TfrmViewTensors.chkUseImplClick(Sender: TObject);
begin
  frmEditTensors.SetUseImplCfgFromUi(chkUseImpl.Checked);
end;

procedure TfrmViewTensors.chkXAxisAutoClick(Sender: TObject);
begin
  if (csDesigning in ComponentState) or FUpdatingXAxis then
    Exit;
  // if chkXAxisAuto.Checked then  Exit;
  if FGlobalMaxElems < 1 then
    Exit;
  FUpdatingXAxis := true; // On bloque les événements
  if chkXAxisAuto.Checked then
  begin
    // Mode Auto
    edtXMin.Enabled := False;
    edtXMax.Enabled := False;
    edtXMin.ReadOnly := true;
    edtXMax.ReadOnly := true;
    // Mode Auto : l'axe suit le zoom/drag. On ne force pas de refresh global.
  end
  else
  begin
    // Mode Manuel
    edtXMin.Enabled := true;
    edtXMax.Enabled := true;
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
      RefreshChart(FCurrentStartIdx, FCurrentEndIdx, False);
    end;
  end;
end;

// remplir le ComboBox de filtre dynamiquement
procedure TfrmViewTensors.UpdateFilterTypeItems;
var
  Patterns: TStringList;
  i, j: Integer;
  T: TGGUFTensorInfo;
  ModelS: array of TGGUFFile;
  sFiter: String;
begin
  Patterns := TStringList.Create;
  try
    Patterns.Sorted := true;
    Patterns.Duplicates := dupIgnore;
    sFiter := cbFilterV.Text;
    // On met les modèles dans un tableau pour boucler facilement
    SetLength(ModelS, 4);
    ModelS[0] := FModel1;
    ModelS[1] := FModel2;
    ModelS[2] := FModelS;
    ModelS[3] := FModelOut;

    for i := 0 to 3 do
    begin
      if Assigned(ModelS[i]) then
      begin
        for j := 0 to ModelS[i].Tensors.Count - 1 do
        begin
          T := TGGUFTensorInfo(ModelS[i].Tensors[j]);
          { if T.IsNameMapped then
            begin
            if T.TensorPatternNameMap <> '' then
            Patterns.Add(T.TensorPatternNameMap);
            end
            else
            begin }
          if T.TensorPatternName <> '' then
            Patterns.Add(T.TensorPatternName);
          // end;
        end;
      end;
    end;
    // Patterns.Sorted := False;
    cbFilterV.Items.Add(''); // Tous
    cbFilterV.Items.AddStrings(Patterns);
    // cbFilterT.ItemIndex := 0;
    cbFilterV.Text := sFiter;
  finally
    Patterns.Free;
  end;
end;

function TfrmViewTensors.GetFormatTensorNameList(T: TGGUFTensorInfo): String;
var
  Prefix, strQ: string;
begin
  Prefix := '';
  if T.IsConverted then
    Prefix := 'O'
  else if T.SourceId = 1 then
    Prefix := 'A'
  else if T.SourceId = 2 then
    Prefix := 'B'
  else if T.SourceId = 3 then
    Prefix := 'S';
  // FGlobalMaxElems := Max(FGlobalMaxElems, T.TotElems);
  strQ := GGMLTypeToStr(Integer(T.TensorType));
  Result := Format('%s [%s]-%s', [string(T.Name), Prefix, strQ]);
end;

procedure TfrmViewTensors.PopulateTensorList;
var
  i, j: Integer;
  T: TGGUFTensorInfo;
  FilterText, TName: string;
  ShowM1, ShowM2, ShowMS, ShowMOut: Boolean;
  MatchT: Boolean;
  AllTensors: TList;
begin
  FilterText := LowerCase(Trim(cbFilterV.Text));
  ShowM1 := (chkM1.Checked) and Assigned(ModelA);
  ShowM2 := (chkM2.Checked) and Assigned(ModelB);
  ShowMS := (chkMS.Checked) and Assigned(ModelS);
  ShowMOut := (chkMOut.Checked) and Assigned(ModelOut);

  FSelectionOrder.Clear;

  AllTensors := TList.Create;
  try
    // 1. Collecte de TOUS les tenseurs des modèles activés
    if ShowM1 then
      for i := 0 to FModel1.Tensors.Count - 1 do
        AllTensors.Add(FModel1.Tensors[i]);

    if ShowM2 then
      for i := 0 to FModel2.Tensors.Count - 1 do
        AllTensors.Add(FModel2.Tensors[i]);

    if ShowMS then
      for i := 0 to FModelS.Tensors.Count - 1 do
        AllTensors.Add(FModelS.Tensors[i]);

    if ShowMOut then
      for i := 0 to FModelOut.Tensors.Count - 1 do
      begin
        T := TGGUFTensorInfo(FModelOut.Tensors[i]);
        if T.IsConverted then
          AllTensors.Add(FModelOut.Tensors[i]);
      end;
    // TRI ALPHABÉTIQUE (A-Z)
    AllTensors.Sort(@CompareTensorsByName);
    FGlobalMaxElems := 0;
    // Affichage dans le CheckListBox
    ChListBoxTensors.Items.BeginUpdate;
    try
      ChListBoxTensors.Items.Clear;
      for i := 0 to AllTensors.Count - 1 do
      begin
        T := TGGUFTensorInfo(AllTensors[i]);
        // Mise à jour du Max pour le slider
        FGlobalMaxElems := Max(FGlobalMaxElems, T.TotElems);
        // Filtrage par texte
        TName := LowerCase(string(T.Name));
        MatchT := (cbFilterV.ItemIndex = 0) or (FilterText = '') or (Pos(FilterText, TName) > 0);
        if MatchT then
        begin
          // On ajoute l'objet au CheckListBox pour pouvoir le retrouver
          // On utilise GetFormatTensorNameList pour un affichage propre (ex: name[A]-Type-Size)
          ChListBoxTensors.Items.AddObject(GetFormatTensorNameList(T), T);
        end;
      end;
    finally
      ChListBoxTensors.Items.EndUpdate;
    end;
  finally
    AllTensors.Free;
  end;
end;

procedure TfrmViewTensors.SetedtYMinedtYMaxValus(Mn, Mx: Double);
begin
  if ((Mn = 0) and (Mx = 0)) or (Mn = Mx) then
    Exit;
  // Ajustement de l'échelle des Edits
  if Mx - Mn > 1000 then
  begin
    edtYMin.Text := IntToStr(Round(Mn * 1025 / 1000));
    edtYMax.Text := IntToStr(Round(Mx * 1025 / 1000));
  end
  else
  begin
    if Mx - Mn > 10 then
    begin
      edtYMin.Text := IntToStr(Round(Mn * 102.5 / 100));
      edtYMax.Text := IntToStr(Round(Mx * 102.5 / 100));
    end
    else
    begin
      edtYMin.Text := FloatToStr(Round(Mn * 10250) / 10000);
      edtYMax.Text := FloatToStr(Round(Mx * 10250) / 10000);
    end;
  end;
end;

procedure TfrmViewTensors.chkYAxisAutoClick(Sender: TObject);
begin
  if chkYAxisAuto.Checked then
  begin
    Chart1.LeftAxis.Automatic := true;
  end
  else
  begin
    Chart1.LeftAxis.Automatic := False;
    SetedtYMinedtYMaxValus(Chart1.LeftAxis.Minimum, Chart1.LeftAxis.Maximum);
    UpdateYAxisRangeFromEdit;
  end;
end;

procedure TfrmViewTensors.ChListBoxTensorsClickCheck(Sender: TObject);
var
  i, clickedIdx, CheckedCount: Integer;
  Limit: Integer;
  IsT1vT2Mode: Boolean;
begin
  IsT1vT2Mode := cfg.chkT1vT2 and (cfg.iTensorsPerChart = 2);
  clickedIdx := ChListBoxTensors.ItemIndex;
  if clickedIdx = -1 then
    Exit;

  Limit := cfg.iTensorsPerChart; // Charge la config utilisateur

  ChListBoxTensors.Items.BeginUpdate;
  try
    CheckedCount := 0;
    for i := 0 to ChListBoxTensors.Count - 1 do
      if ChListBoxTensors.Checked[i] then
        Inc(CheckedCount);

    if (cfg.iTensorsPerChart = 1) then
    begin
      if ChListBoxTensors.Checked[clickedIdx] then
        for i := 0 to ChListBoxTensors.Count - 1 do
          if i <> clickedIdx then
            ChListBoxTensors.Checked[i] := False;
      // On reset la liste d'ordre
      FSelectionOrder.Clear;
      if ChListBoxTensors.Checked[clickedIdx] then
        FSelectionOrder.Add(clickedIdx);
    end
    // MODE "COMPARAISON T1-T2" : Ne garder que les 2 derniers sélectionnés
    else if IsT1vT2Mode then
    begin
      if ChListBoxTensors.Checked[clickedIdx] then
      begin
        FSelectionOrder.Add(clickedIdx);
        while FSelectionOrder.Count > 2 do
        begin
          i := FSelectionOrder[0];
          ChListBoxTensors.Checked[i] := False;
          FSelectionOrder.Delete(0);
        end;
      end
      else
      begin
        i := FSelectionOrder.IndexOf(clickedIdx);
        if i <> -1 then
          FSelectionOrder.Delete(i);
      end;
    end
    else if ChListBoxTensors.Checked[clickedIdx] then
    begin
      // L'utilisateur vient de cocher : on l'ajoute à la fin de la liste
      FSelectionOrder.Add(clickedIdx);
      // On supprime les plus anciens pour ne garder que les N (Limit) derniers
      while FSelectionOrder.Count > Limit do
      begin
        i := FSelectionOrder[0];
        ChListBoxTensors.Checked[i] := False; // Décoche l'ancien
        FSelectionOrder.Delete(0);
      end;
    end
    else
    begin
      // L'utilisateur vient de décocher : on le retire de la liste d'ordre
      i := FSelectionOrder.IndexOf(clickedIdx);
      if i <> -1 then
        FSelectionOrder.Delete(i);
    end;
  finally
    ChListBoxTensors.Items.EndUpdate;
  end;
  RefreshChart(FCurrentStartIdx, FCurrentEndIdx, chkXAxisAuto.Checked);
end;

procedure TfrmViewTensors.edtXMinKeyPress(Sender: TObject; var Key: Char);
begin
  IF Key = #13 Then
  begin
    UpdateXAxisRangeFromEdit;
  end;
end;

procedure TfrmViewTensors.edtYMinKeyPress(Sender: TObject; var Key: Char);
begin
  IF Key = #13 Then
  begin
    UpdateYAxisRangeFromEdit;
  end;
end;

procedure TfrmViewTensors.UpdateYAxisRangeFromEdit;
var
  MinVal, MaxVal, Val: Double;
begin
  if FGlobalMaxElems <= 1 then
    Exit; // Pas de plage valide si 0 ou 1 élément
  MinVal := StrToFloatDef(edtYMin.Text, -1);
  MaxVal := StrToFloatDef(edtYMax.Text, 1);
  if MinVal > MaxVal then
  begin
    Val := MinVal;
    MinVal := MaxVal;
    MaxVal := Val;
  end;
  if (MinVal <> 0) and (MaxVal <> 0) then
    Chart1.LeftAxis.SetMinMax(MinVal, MaxVal);
end;

procedure TfrmViewTensors.UpdateXAxisRangeFromEdit;
var
  NewStart, NewEnd: Int64;
begin
  if FGlobalMaxElems <= 1 then
    Exit; // Pas de plage valide si 0 ou 1 élément

  FUpdatingXAxis := true;
  try
    NewEnd := StrToInt64Def(edtXMax.Text, FGlobalMaxElems - 1);
    if NewEnd < 0 then
      NewEnd := 0;
    NewStart := StrToInt64Def(edtXMin.Text, 0);
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
    RefreshChart(FCurrentStartIdx, FCurrentEndIdx, False);
  finally
    FUpdatingXAxis := False;
  end;
end;

procedure TfrmViewTensors.Chart1MouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  Range: Int64;
begin
  // On ne déclenche le glissement que par le bouton gauche
  if Button = mbLeft then
  begin
    FIsDragging := true;
    FDragStartX := X;
    // Capture de l'état des axes au moment du clic pour calculer le delta
    FDragStartMinX := Chart1.BottomAxis.Minimum;
    FDragStartMaxX := Chart1.BottomAxis.Maximum;
  end;
end;

procedure TfrmViewTensors.Chart1MouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
var
  dx, dy: Double;
  DeltaX, DeltaY: Integer;
  XUnitPerPixel, YUnitPerPixel: Double;
  NewMinX, NewMaxX, NewMinY, NewMaxY: Double;
begin
  if not FIsDragging then
    Exit;
  // NAVIGATION HORIZONTALE (INDEX)
  DeltaX := X - FDragStartX;
  // Calcul de la valeur de l'unité par pixel (Précision extrême)
  // On divise la plage de l'axe par la largeur du graphique en pixels
  XUnitPerPixel := (FDragStartMaxX - FDragStartMinX) / Chart1.Width;
  // On déplace la fenêtre de la valeur du delta
  NewMinX := FDragStartMinX - (DeltaX * XUnitPerPixel);
  NewMaxX := FDragStartMaxX - (DeltaX * XUnitPerPixel);
  if (NewMinX < 0) or (NewMaxX > FGlobalMaxElems) then
    if NewMaxX - NewMinX <= cfg.MinXAxisRang then
      Exit;
  // Appliquer l'axe visuellement (immédiat, sans recharger le fichier)
  Chart1.BottomAxis.SetMinMax(NewMinX, NewMaxX);
end;

procedure TfrmViewTensors.Chart1MouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  Step, Range: Int64;
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
      else if FCurrentEndIdx >= FGlobalMaxElems then
      begin
        if FGlobalMaxElems >= cfg.MinXAxisRang then
          FCurrentStartIdx := FCurrentEndIdx - cfg.MinXAxisRang
        else
          FCurrentStartIdx := FCurrentEndIdx - FGlobalMaxElems;
      end;
    end;
    RefreshChart(FCurrentStartIdx, FCurrentEndIdx, False);
  end;
end;

procedure TfrmViewTensors.Chart1MouseWheelUp(Sender: TObject; Shift: TShiftState; MousePos: TPoint;
var Handled: Boolean);
var
  Range, NewRange, AnchorValue, NewMin, NewMax: Double;
  iMousePos: TPoint;
  PlotLeft, PlotWidth, PlotX: Integer;
  Ratio: Double;
begin
  Handled := true; // Désactive le zoom natif de TeeChart
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
    Chart1.LeftAxis.Automatic := true
  else
    UpdateYAxisRangeFromEdit;
  RefreshChart(FCurrentStartIdx, FCurrentEndIdx, False);

end;

procedure TfrmViewTensors.Chart1MouseWheelDown(Sender: TObject; Shift: TShiftState; MousePos: TPoint;
var Handled: Boolean);
var
  Range, NewRange, AnchorValue, NewMin, NewMax: Double;
  iMousePos: TPoint;
  PlotLeft, PlotWidth, PlotX: Integer;
  Ratio: Double;
begin
  Handled := true;
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
    Chart1.LeftAxis.Automatic := true
  else
    UpdateYAxisRangeFromEdit;
  RefreshChart(FCurrentStartIdx, FCurrentEndIdx, False);
end;

procedure TfrmViewTensors.Chart1UndoZoom(Sender: TObject);
begin
  FIsZooming := False;
  FCurrentStartIdx := 0;
  FCurrentEndIdx := FGlobalMaxElems - 1;
  RefreshChart(FCurrentStartIdx, FCurrentEndIdx, true);
end;

procedure TfrmViewTensors.btnResetZoom2Click(Sender: TObject);
begin
  Chart2.UndoZoom;
end;

procedure TfrmViewTensors.btnResetZoomClick(Sender: TObject);
begin
  // Chart1.UndoZoom;
  Chart1.BottomAxis.SetMinMax(0, FGlobalMaxElems - 1);
  FCurrentStartIdx := 0;
  FCurrentEndIdx := FGlobalMaxElems - 1;
  RefreshChart(0, FGlobalMaxElems - 1, true);
end;

// ANALYSE ASYNCHRONE & EXPORT CSV
procedure TfrmViewTensors.OnProgressFB(const Msg: string; ATIdx, ATTotal, AIdx, ATotal: Int64);
begin
  TThread.Queue(nil,
    procedure
    begin
      // Sécurité : quitter si la forme est fermée ou si l'analyse a été annulée
      if FCancelThread or not Assigned(ProgressBar1) or not Assigned(ProgressBar2) then
        Exit;

      // Mise à jour des barres de progression
      ProgressBar1.Max := ATTotal;
      ProgressBar1.Position := ATIdx;
      ProgressBar2.Max := ATotal;
      ProgressBar2.Position := AIdx;
      vLogMsg(Msg);
    end);
end;

// PARTIE HISTOGRAMME
procedure TfrmViewTensors.btnHistogramClick(Sender: TObject);
var
  i: Integer;
  T: TGGUFTensorInfo;
  Series: TBarSeries;
begin
  Chart2.SeriesList.Clear;
  PageControl1.ActivePage := TabHist;
  lvSeries.Items.BeginUpdate;
  try
    lvSeries.Items.Clear;
    Chart2.SeriesList.Clear;
    Screen.Cursor := crHourGlass;
    try
      for i := 0 to ChListBoxTensors.Count - 1 do
        if ChListBoxTensors.Checked[i] then
        begin
          T := TGGUFTensorInfo(ChListBoxTensors.Items.Objects[i]);
          if not Assigned(T) then
            Continue;
          Series := TBarSeries.Create(Chart2);
          Series.ParentChart := Chart2;
          // Series.Title := ChListBoxTensors.Items[i];
          Series.Title := GetFormatTensorNameList(T);
          Series.Marks.Visible := False;
          // Cache les étiquettes pour la clarté
          GenerateHistogramData(T, Series);
          AddSeriesToListView(T, Series.Title, Integer(Series.SeriesColor));
        end;
    finally
      Screen.Cursor := crDefault;
    end;
  finally
    lvSeries.Items.EndUpdate;
  end;
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

  RefreshChart(FCurrentStartIdx, FCurrentEndIdx, False);
end;

procedure TfrmViewTensors.cbFilterVChange(Sender: TObject);
begin
  PopulateTensorList;
end;

function TfrmViewTensors.GetLimitFromCombo: Integer;
begin
  cfg.sTensorsPerChart := UpperCase(cbNbrSelect.Text);
  if cfg.sTensorsPerChart = 'ONE' then
    cfg.iTensorsPerChart := 1
  else if cfg.sTensorsPerChart = 'ONE ONLY' then
    cfg.iTensorsPerChart := 1
  else if cfg.sTensorsPerChart = 'ALL' then
    cfg.iTensorsPerChart := SAFETY_MAX_TENSORS
  else
    cfg.iTensorsPerChart := StrToInt64Def(cfg.sTensorsPerChart, 2);
  Result := cfg.iTensorsPerChart;
end;

procedure TfrmViewTensors.EnforceSelectionLimit;
var
  i, Limit: Integer;
begin
  Limit := Min(GetLimitFromCombo, SAFETY_MAX_TENSORS);
  if FSelectionOrder.Count > Limit then
  begin
    ChListBoxTensors.Items.BeginUpdate;
    try
      while FSelectionOrder.Count > Limit do
      begin
        i := FSelectionOrder[0];
        ChListBoxTensors.Checked[i] := False;
        FSelectionOrder.Delete(0);
      end;
    finally
      ChListBoxTensors.Items.EndUpdate;
    end;
  end;
end;

procedure TfrmViewTensors.cbNbrSelectChange(Sender: TObject);
var
  i, lastCheckedIdx: Integer;
begin
  GetLimitFromCombo;
  EnforceSelectionLimit;
  RefreshChart(FCurrentStartIdx, FCurrentEndIdx, False);
end;

procedure TfrmViewTensors.brnClearAllSelectedClick(Sender: TObject);
var
  i: Integer;
begin
  ChListBoxTensors.Items.BeginUpdate;
  try
    for i := 0 to ChListBoxTensors.Items.Count - 1 do
      ChListBoxTensors.Checked[i] := False;
  finally
    ChListBoxTensors.Items.EndUpdate;
  end;
  cbFilterV.Text := '';
  PopulateTensorList;
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
  RefreshChart(FCurrentStartIdx, FCurrentEndIdx, False);
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
  RefreshChart(FCurrentStartIdx, FCurrentEndIdx, False);
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

  RefreshChart(FCurrentStartIdx, FCurrentEndIdx, False);
end;

procedure TfrmViewTensors.GenerateHistogramData(T: TGGUFTensorInfo; Series: TBarSeries; UseDLL: Boolean = true);
var
  TotalElems, ReadIdx, BlockIdx: Int64;
  i, BlkElems, BlkBytes, TypeIdOrg, TypeIdTarget, ScalarSize: Integer;
  FS: TFileStream;
  BlockBuf, SimBuf: TBytes;
  F32Buf: array of Single;
  Val, VMin, VMax, Range, BinWidth: Single;
  HistCounts: array of Int64;
  BinIdx: Integer;
  IsQuantOrg: Boolean;
  Pass1Min, Pass1Max: Single;
  DoSim: Boolean;
begin
  TotalElems := T.TotElems;
  if TotalElems = 0 then
    Exit;

  // 1. Configuration des types
  TypeIdOrg := Integer(T.TensorTypeOrg);
  DoSim := T.IsConverted;
  TypeIdTarget := Integer(T.TensorType);

  // Blocs Source (lecture fichier)
  ScalarSize := GGML_TypeScalarSize(TypeIdOrg);
  IsQuantOrg := GGML_TypeIsQuant(TypeIdOrg);
  if IsQuantOrg then
  begin
    BlkElems := GGML_BlockElems(TypeIdOrg);
    BlkBytes := GGML_BlockBytes(TypeIdOrg);
  end
  else
  begin
    BlkElems := 32;
    BlkBytes := BlkElems * ScalarSize;
  end;

  if (BlkElems <= 0) or (BlkBytes <= 0) then
    Exit;

  // Allocation tampons
  SetLength(BlockBuf, BlkBytes);
  SetLength(F32Buf, BlkElems);
  if DoSim then
    SetLength(SimBuf, GGML_RowSize(Integer(T.TensorType), BlkElems));

  FS := TFileStream.Create(T.SourceFile, fmOpenRead or fmShareDenyWrite);
  try
    SetLength(HistCounts, cfg.HistBins);
    for i := 0 to cfg.HistBins - 1 do
      HistCounts[i] := 0;
    // PASS 1 : Estimation rapide des bornes (avec stride)
    Pass1Min := MaxSingle;
    Pass1Max := -MaxSingle;
    ReadIdx := 0;
    while ReadIdx < TotalElems do
    begin
      BlockIdx := ReadIdx div BlkElems;
      FS.Position := T.TensorDataFilePos + T.SourceOffset + (BlockIdx * BlkBytes);
      FS.ReadBuffer(BlockBuf[0], BlkBytes);
      // Déquantification source
      Dequant(@BlockBuf[0], @F32Buf[0], BlkElems, TypeIdOrg);

      // Simulation si active : Quant -> Dequant cible
      if DoSim then
      begin
        Quant(@F32Buf[0], @SimBuf[0], BlkElems, TypeIdTarget, UseDLL);
        Dequant(@SimBuf[0], @F32Buf[0], BlkElems, TypeIdTarget, UseDLL);
      end;
      // Mise à jour Min/Max
      for i := 0 to Min(BlkElems, TotalElems - ReadIdx) - 1 do
      begin
        Val := F32Buf[i];
        if not IsNaN(Val) and not IsInfinite(Val) then
        begin
          if Val < Pass1Min then
            Pass1Min := Val;
          if Val > Pass1Max then
            Pass1Max := Val;
        end;
      end;
      // Stride pour accélérer l'estimation
      Inc(ReadIdx, BlkElems * cfg.HistStride);
    end;

    // Gestion des cas limites
    if Pass1Min = MaxSingle then
      Pass1Min := 0;
    if Pass1Max = -MaxSingle then
      Pass1Max := 0;
    if Pass1Min = Pass1Max then
    begin
      Pass1Min := Pass1Min - 0.5;
      Pass1Max := Pass1Max + 0.5;
    end;

    VMin := Pass1Min;
    VMax := Pass1Max;
    Range := VMax - VMin;
    if Range <= 0 then
      Range := 1.0;
    BinWidth := Range / cfg.HistBins;

    // PASS 2 : Binning précis (sans stride)
    ReadIdx := 0;
    while ReadIdx < TotalElems do
    begin
      BlockIdx := ReadIdx div BlkElems;
      FS.Position := T.TensorDataFilePos + T.SourceOffset + (BlockIdx * BlkBytes);
      FS.ReadBuffer(BlockBuf[0], BlkBytes);

      // Déquantification source
      Dequant(@BlockBuf[0], @F32Buf[0], BlkElems, TypeIdOrg, UseDLL);

      // Simulation si active
      if DoSim then
      begin
        Quant(@F32Buf[0], @SimBuf[0], BlkElems, TypeIdTarget, UseDLL);
        Dequant(@SimBuf[0], @F32Buf[0], BlkElems, TypeIdTarget, UseDLL);
      end;

      // Remplissage des bins
      for i := 0 to Min(BlkElems, TotalElems - ReadIdx) - 1 do
      begin
        Val := F32Buf[i];
        if not IsNaN(Val) and not IsInfinite(Val) then
        begin
          BinIdx := Trunc((Val - VMin) / BinWidth);
          if BinIdx < 0 then
            BinIdx := 0;
          if BinIdx >= cfg.HistBins then
            BinIdx := cfg.HistBins - 1;
          Inc(HistCounts[BinIdx]);
        end;
      end;

      Inc(ReadIdx, BlkElems);
    end;

    // Rendu sur le graphique
    Series.Clear;
    for i := 0 to cfg.HistBins - 1 do
      Series.AddBar(HistCounts[i], Format('%.2f', [VMin + (i * BinWidth)]), clTeeColor);

  finally
    FS.Free;
  end;
end;

end.
