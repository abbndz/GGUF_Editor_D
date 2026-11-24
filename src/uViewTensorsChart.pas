unit uViewTensorsChart;

{ ============================================================================
  GRAPHE  --  modele "JOB" (aucun acces VCL dans l'ouvrier)
  ----------------------------------------------------------------------------
  RefreshChart (VCL thread)  : lit cfg + VCL, CLONE les tenseurs, construit le
                               TChartJob (jeton FRenderGen), demarre 1 thread.
  Ouvrier                    : TWalkPlan + TTensorReader + RunPlan uniquement.
                               -> TPlotBuf / TMarkBuf / TSeriesStats / stats diff
  ChartApplyJob (VCL thread) : TBar/Fast/PointSeries, lvSeries (TLegendInfo),
                               axes, StatusBar, logs.  Job perime = jete sans rien
                               toucher.  Puis EndRender (rejoue le pending typise).
  ----------------------------------------------------------------------------
  Arbitrage commun avec l'histogramme : FRenderGen / RequestRender / EndRender
  (uViewTensors) -> plus de "l'histo tue le graphe et le graphe ne revient pas".
  ComputeTensorDiffWrmse (code mort) SUPPRIMEE : etait la 4e copie de la boucle.
  Marqueurs : outliers PAR LIGNE ; blocs depuis la ligne 0 (plus d'overdraw).
============================================================================ }

interface

uses
  Winapi.Windows, System.SysUtils, System.Classes, Vcl.Graphics,
  Vcl.Controls, VclTee.Chart, VclTee.Series, VclTee.TeEngine, VclTee.TeeProcs,
  System.Generics.Collections, System.Threading, System.Diagnostics, uMath,
  uGGUFModel, uGGMLConstants, uGGMLTypes, uAppConfig, uLangManager,
  uDiffStats, uTensorStreamReader, uLog, uStrUtils;

type
  // Buffer plat : ecrit par l'ouvrier, lu par la VCL thread (aliasing impossible)
  TPlotBuf = class
  public
    X: array of Double;
    Y: array of Double;
    N: Integer;
    MinY, MaxY: Single;
    constructor Create;
    procedure EnsureCapacity(ACap: Integer);
    procedure Add(const aX: Int64; aY: Single);
    function IsEmpty: Boolean;
  end;

  TMarkBuf = class
  public
    X: array of Int64;
    Y: array of Single;
    C: array of TColor;
    N: Integer;
    procedure EnsureCapacity(ACap: Integer);
    procedure Add(const aX: Int64; aY: Single; aC: TColor);
    function IsEmpty: Boolean;
  end;

  // Detecteur d'outliers : regles HISTORIQUES conservees (2 jeux de parametres)
  TOutlierRun = record
    Sum, Mean: Double;
    ValidCount: Int64;
    Emitted, MaxEmit: Integer;
    MeanDivMin: Int64;         // zoom 0 / LOD 1
    NeedPositiveMean: Boolean; // zoom False / LOD True
    procedure Reset;
    procedure Observe(Val: Single);
    function IsOutlier(Val: Single): Boolean;
  end;

  TChartLine = class
  public
    Src: TGGUFTensorInfo;    // clone, propriete du job
    Buf: TPlotBuf;
    Outliers: TMarkBuf;      // option 8 : par ligne
    Stats: TSeriesStats;     // option 9 : stats par serie (mode simple et diff)
    S, E: Int64;
    Title: string;
    ElapsedMs: Int64;
    OutRun: TOutlierRun;
    constructor Create;
    destructor Destroy; override;
  end;

  TChartJob = class
  public
    Gen: Integer;
    Lines: TObjectList<TChartLine>;
    Blocks: TMarkBuf;            // global, alimente par la ligne 0
    StartIdx, EndIdx: Int64;
    End1, End2, EndDiff: Int64;
    ShowBlocks, ShowOutliers, IsDiff, IsSubMode: Boolean;
    ImplLabel: string;
    RmseIdx: Integer;
    // copie de cfg : l'ouvrier ne lit JAMAIS cfg
    NumBins, PtsPerBin, MinXRange: Integer;
    VFPScale, DiffAmp: Double;
    Stats: TDiffStats;
    StatsValid: Boolean;
    ElapsedMs: Int64;
    constructor Create;
    destructor Destroy; override;
  end;



  TLegendInfo = class
  public
    Title: string;
    Color: TColor;
    constructor Create(const ATitle: string; AColor: TColor);
  end;

procedure DoUpDateGlobalStartEndIdx(ForceFullRange: Boolean; var SelectedTensors: TList);
procedure RefreshChart(ForceFullRange: Boolean = False);

procedure DoRefreshChart(ForceFullRange: Boolean); forward;
procedure ChartFillLineRange(Job: TChartJob; LineIdx: Integer; AStar, AEnd: Int64); forward;
function Plan_TotalHint(Job: TChartJob; ARange: Int64; ALOD: Boolean): Int64; forward;

implementation

uses uViewTensors, uEditTensors;

{ ---------------- TLegendInfo ---------------- }

constructor TLegendInfo.Create(const ATitle: string; AColor: TColor);
begin
  inherited Create;
  Title := ATitle;
  Color := AColor;
end;

{ ---------------- TPlotBuf / TMarkBuf ---------------- }
constructor TPlotBuf.Create;
begin
  inherited Create;
  MinY := MaxSingle;
  MaxY := -MaxSingle;
end;

procedure TPlotBuf.EnsureCapacity(ACap: Integer);
begin
  if ACap <= Length(X) then
    Exit;
  if ACap > CMAX_PLOT_POINTS then
    ACap := CMAX_PLOT_POINTS;
  SetLength(X, ACap);
  SetLength(Y, ACap);
end;

procedure TPlotBuf.Add(const aX: Int64; aY: Single);
begin
  if N >= CMAX_PLOT_POINTS then Exit;
  if N >= Length(X) then
  begin
    if Length(X) = 0 then
      SetLength(X, 1024)
    else
      SetLength(X, Length(X) * 2);
    if Length(X) < N + 1 then
      SetLength(X, N + 1);
    SetLength(Y, Length(X));
  end;
  X[N] := aX;
  Y[N] := aY;
  Inc(N);
  if aY < MinY then MinY := aY;
  if aY > MaxY then MaxY := aY;
end;

function TPlotBuf.IsEmpty: Boolean;
begin
  Result := N = 0;
end;

procedure TMarkBuf.EnsureCapacity(ACap: Integer);
begin
  if ACap <= Length(X) then
    Exit;
  if ACap > CMAX_PLOT_POINTS then
    ACap := CMAX_PLOT_POINTS;
  SetLength(X, ACap);
  SetLength(Y, ACap);
  SetLength(C, ACap);
end;

procedure TMarkBuf.Add(const aX: Int64; aY: Single; aC: TColor);
begin
  if N >= Length(X) then
  begin
    if Length(X) = 0 then
      SetLength(X, 1024)
    else
      SetLength(X, Length(X) * 2);
    if Length(X) < N + 1 then
      SetLength(X, N + 1);
    SetLength(Y, Length(X));
    SetLength(C, Length(X));
  end;
  X[N] := aX;
  Y[N] := aY;
  C[N] := aC;
  Inc(N);
end;

function TMarkBuf.IsEmpty: Boolean;
begin
  Result := N = 0;
end;

{ ---------------- TOutlierRun ---------------- }
procedure TOutlierRun.Reset;
begin
  Sum := 0; Mean := 0; ValidCount := 0; Emitted := 0;
  if MaxEmit <= 0 then MaxEmit := 128;
end;

procedure TOutlierRun.Observe(Val: Single);
begin
  Sum := Sum + Abs(Val);
  if ValidCount > 31 then
    Sum := Sum - Mean
  else
    Inc(ValidCount);
  if ValidCount > MeanDivMin then
    Mean := Sum / ValidCount
  else
    Mean := 0;
end;

function TOutlierRun.IsOutlier(Val: Single): Boolean;
begin
  Result := False;
  if (Emitted >= MaxEmit) or (ValidCount <= 4) then
    Exit;
  if NeedPositiveMean and not (Mean > 0.0001) then
    Exit;
  if Abs(Val) > (Mean * 8) then
  begin
    Result := True;
    Inc(Emitted);
  end;
end;

{ ---------------- TChartLine / TChartJob ---------------- }
constructor TChartLine.Create;
begin
  Buf := TPlotBuf.Create;
  Outliers := TMarkBuf.Create;
  Stats.Reset;
  S := 0; E := -1;
end;

destructor TChartLine.Destroy;
begin
  Src.Free;
  Buf.Free;
  Outliers.Free;
  inherited;
end;

constructor TChartJob.Create;
begin
  Lines := TObjectList<TChartLine>.Create(True);
  Blocks := TMarkBuf.Create;
  FillChar(Stats, SizeOf(Stats), 0);
  VFPScale := 1.0;
  DiffAmp := 1.0;
end;

destructor TChartJob.Destroy;
begin
  if Assigned(Lines) then
    Lines.Free;
  if Assigned(Blocks) then
    Blocks.Free;
  inherited;
end;


{ ---------------- marqueurs de bloc (regles historiques) ---------------- }
procedure BlockMark(Job: TChartJob; LineIdx: Integer;
  ix: Int64; Val: Single; ARange: Int64; ALOD: Boolean);
begin
  if (not Job.ShowBlocks) or (LineIdx <> 0) then
    Exit;   // option 8 : un seul proprietaire (repere de structure, pas de valeur)
  if ALOD then
  begin
    if ARange < 8192 then
      if ix mod 256 = 0 then
        Job.Blocks.Add(ix, Val, clRed);
  end
  else
  begin
    if ARange < 1024 then
    begin
      if ix mod 32 = 0 then
      begin
        if ix mod 256 = 0 then
          Job.Blocks.Add(ix, Val, clLime)
        else
          Job.Blocks.Add(ix, Val, clYellow);
      end;
    end
    else if ARange < 8192 then
      if ix mod 256 = 0 then
        Job.Blocks.Add(ix, Val, clLime);
  end;
end;

// passe simple : 1 ligne
procedure ChartFillLine(Job: TChartJob; LineIdx: Integer);
var
  Ln: TChartLine;
  R: TTensorReader;
  Plan: TWalkPlan;
  S, E, Range: Int64;
  LOD: Boolean;
  eofIdx: Int64;
begin
  Ln := Job.Lines[LineIdx];
  if (Ln = nil) or (Ln.Src = nil) or (Ln.E < Ln.S) then
    Exit;

  S := uMath.Max(0, Ln.S);
  E := uMath.Min(Ln.Src.TotElems - 1, Ln.E);
  Ln.S := S;
  Ln.E := E;
  if E < S then
    Exit;
  Range := E - S + 1;
  LOD := SafeLODNeeded(Range, Job.NumBins, Job.PtsPerBin);

  R := TTensorReader.Create(Ln.Src);
  try
    if not R.Ok then
    begin
      //Ln.ErrMsg := R.ErrText;
      Exit;
    end;
    R.SetOutScale(Job.VFPScale);

    Plan := BuildPlan(S, E, LOD, Job.NumBins, Job.PtsPerBin);
    try
      Ln.Buf.EnsureCapacity(Plan.Total);
      Ln.Outliers.EnsureCapacity(uMath.Min(Plan.Total, 8192));

      // zoom / LOD : seuls les reglages outliers different (comme avant)
      Ln.OutRun.MaxEmit := IfThen1(LOD, 4, 128);
      Ln.OutRun.MeanDivMin := IfThen1(LOD, 1, 0);
      Ln.OutRun.NeedPositiveMean := LOD;
      Ln.OutRun.Reset;

      RunPlan(Plan, [R],
        procedure(Rs: array of TTensorReader; AStart: Int64; ACount: Int64)
        var
          j: Int64;
          ix: Int64;
          Val: Double;
          Rr: TTensorReader;
        begin
          Rr := Rs[0];
          for j := 0 to ACount - 1 do
          begin
            ix := AStart + j;
            Val := Rr.ValAt(ix);
            Ln.Stats.Add(Val);
            if uMath.IsNaN(Val) then
              Ln.Outliers.Add(ix, 0, clWhite)
            else if uMath.IsInfinite(Val) then
              Ln.Outliers.Add(ix, 0, clFuchsia)
            else
            begin
              BlockMark(Job, LineIdx, ix, Val, Range, LOD);
              Ln.Buf.Add(ix, Val);
              if Job.ShowOutliers and ((not LOD) or (Range < 320000)) then
              begin
                Ln.OutRun.Observe(Single(Val));
                if Ln.OutRun.IsOutlier(Single(Val)) then
                  Ln.Outliers.Add(ix, Val, clRed);
              end;
            end;
          end;
        end,
        function: Boolean
        begin
          Result := frmViewTensors.IsCancelRequested;
        end,
        procedure(ADone, ATotal: Int64; APct: Integer)
        begin
          frmViewTensors.SetProgress(S + ADone, Job.EndIdx + 1, APct, Ln.Title);
        end,
        eofIdx);

      if eofIdx >= 0 then // 'fin de fichier atteinte a l''element %d'
        if LogIsOn(lvWarn) then
           LogW(mLang.gMsgFmt('FVT.EOFWarn', [eofIdx]));
    finally
      Plan.Free;
    end;
  finally
    R.Free;
  end;
end;



function Plan_TotalHint(Job: TChartJob; ARange: Int64; ALOD: Boolean): Int64;
begin
  if ALOD then
    Result := Int64(Job.NumBins) * Int64(Job.PtsPerBin)
  else
    Result := ARange;
end;

//passe jointe : 2 lignes + stats (UNE seule lecture)
procedure ChartFillDiff(Job: TChartJob);
var
  L1, L2: TChartLine;
  R1, R2: TTensorReader;
  Plan: TWalkPlan;
  S, E, Range: Int64;
  LOD: Boolean;
  eofIdx: Int64;
  //AlignErr: string;
  WT: TDiffWeights;
  Acc: TDiffAcc;
  Sw: TStopwatch;
begin
  L1 := Job.Lines[0];
  L2 := Job.Lines[1];
  L1.Stats.Reset;
  L2.Stats.Reset;
  Acc.Reset;
  eofIdx := -1;

  S := uMath.Max(L1.S, L2.S);
  E := uMath.Min(L1.E, L2.E);
  if E < S then
    Exit;
  Job.EndDiff := E;

  Range := E - S + 1;

  LOD := SafeLODNeeded(Range, Job.NumBins, Job.PtsPerBin);

  Sw := TStopwatch.StartNew;
  R1 := TTensorReader.Create(L1.Src);
  R2 := TTensorReader.Create(L2.Src);
  try
    if not R1.Ok then
    begin
      //L1.ErrMsg := R1.ErrText;
      Exit;
    end;
    if not R2.Ok then
    begin
      //L2.ErrMsg := R2.ErrText;
      Exit;
    end;
    if not AlignMaxBE([R1, R2], IfThen1(LOD, Int64(CLOD_CHUNK_MIN), Int64(CREAD_CHUNK_ELEMS))) then
      Exit;
    //if not AlignMaxBE([R1, R2], 0) then  begin  Exit;   end;
    R1.SetOutScale(Job.VFPScale);
    R2.SetOutScale(Job.VFPScale);

    L1.Buf.EnsureCapacity(Plan_TotalHint(Job, Range, LOD));
    L2.Buf.EnsureCapacity(Plan_TotalHint(Job, Range, LOD));

    Plan := BuildPlan(S, E, LOD, Job.NumBins, Job.PtsPerBin);
    try
      BuildDiffWeights(L1.Src, WT);
      RunPlan(Plan, [R1, R2],
        procedure(Rs: array of TTensorReader; AStart: Int64; ACount: Int64)
        var
          j: Int64;
          ix: Int64;
          V1, V2, Diff: Double;
        begin
          for j := 0 to ACount - 1 do
          begin
            ix := AStart + j;
            V1 := Rs[0].ValAt(ix);
            V2 := Rs[1].ValAt(ix);
            L1.Stats.Add(V1);
            L2.Stats.Add(V2);
            if not uMath.IsNaN(V1) and not uMath.IsInfinite(V1) then
              L1.Buf.Add(ix, V1);
            if not uMath.IsNaN(V2) and not uMath.IsInfinite(V2) then
              L2.Buf.Add(ix, V2);
            if Job.IsSubMode then
              Diff := V1 - V2
            else
            begin
              if (Abs(V1) > 1E-6) and (Abs(V2) > 1E-6) then // seuil unifie avec TDiffAcc
                Diff := V1 / V2
              else
                Diff := 1.0;
            end;
            BlockMark(Job, 0, ix, V1, Range, LOD);
            if not uMath.IsNaN(Diff) and not uMath.IsInfinite(Diff) then
            begin
              Job.Lines[2].Buf.Add(ix, Diff * Job.DiffAmp);
              Acc.Add(V1, V2, ix, Job.IsSubMode, WT);
            end;
          end;
        end,
        function: Boolean
        begin
          Result := frmViewTensors.IsCancelRequested;
        end,
        procedure(ADone, ATotal: Int64; APct: Integer)
        begin
          frmViewTensors.SetProgress(S + ADone, Job.EndIdx + 1, APct, L1.Title);
        end,
        eofIdx);

      if eofIdx >= 0 then
      begin // 'fin de fichier (T1) a l''element %d',
        if LogIsOn(lvWarn) then
           LogW(mLang.gMsgFmt('FVT.EOFWarnT1',[eofIdx]));
      end;
    finally
      Plan.Free;
    end;
  finally
    Sw.Stop;
    Job.ElapsedMs := Sw.ElapsedMilliseconds;
    R1.Free;
    R2.Free;

    CopyStatsFromAcc(Job.Stats, Acc, Job.ElapsedMs);
    Job.StatsValid := Acc.Count > 0;

    if Acc.Count > 0 then
    begin
      if SameText(String(L1.Src.Name), String(L2.Src.Name)) then
      // 'FVT.ChartDiffLogA',Acc.MinVal2, Acc.MaxVal2,  | V2:[%.4f..%.4f]
        if LogIsOn(lvNotice) then
           LogN(
          '[%s-R%d%s] %s vs %s | P:[%d..%d] | E:%d | WRMSE=%.6f RMS=%.6f MAE=%.6f Mean=%.6f WRel=%.4f | V1:[%.4f..%.4f] | %s',  //
          [Job.ImplLabel, Job.RmseIdx, IfThen1(LOD, '/L', '/Z'),  //
           FormatTensorLogInfo(L1.Src), FormatTensorSrcSizeType(L2.Src),  //
           S, E, Acc.Count, Acc.WRMSE, Acc.RMS, Acc.MAE, Acc.Mean, Acc.WRMSERel,   //
           Acc.MinVal1, Acc.MaxVal1, FormatDurationMs(Job.ElapsedMs)])
      else // 'FVT.ChartDiffLogB',Acc.MinVal2, Acc.MaxVal2,  V2:[%.4f..%.4f] |
        if LogIsOn(lvNotice) then
           LogN(
          '[%s-R%d%s] %s vs %s | P:[%d..%d] | E:%d | WRMSE=%.6f | RMS=%.6f MAE=%.6f Mean=%.6f WRel=%.4f | V1:[%.4f..%.4f] | %s',//
          [Job.ImplLabel, Job.RmseIdx, IfThen1(LOD, '/L', '/Z'), //
           FormatTensorLogInfo(L1.Src), FormatTensorLogInfo(L2.Src),//
           S, E, Acc.Count, Acc.WRMSE, Acc.RMS, Acc.MAE, Acc.Mean, Acc.WRMSERel,  //
           Acc.MinVal1, Acc.MaxVal1,  FormatDurationMs(Job.ElapsedMs)]);
    end
    else  // 'Diff : aucune donnee valide (%.2f ms)'
      if LogIsOn(lvInfo) then
           LogI(mLang.gMsgFmt('FVT.DiffNoDataLog', [FormatDurationMs(Job.ElapsedMs)]));
  end;
end;


procedure ChartApplyJob(Job: TChartJob);
var
  i, k, n: Integer;
  Ln: TChartLine;
  LS: array of TFastLineSeries;
  PS: TPointSeries;
  Chart: TChart;
  YMin, YMax: Single;
  HasY: Boolean;
  Discard: Boolean;
  Best: TChartLine;
begin
  if (frmViewTensors = nil) or (csDestroying in frmViewTensors.ComponentState) then
  begin
    Job.Free;
    Exit;
  end;

  Chart := frmViewTensors.Chart1;
  Discard := (Job.Gen <> frmViewTensors.FRenderGen) or
             ((frmViewTensors.FCancelThread) and (Job.Lines.Count > 0));

  try
    if not Discard then
    begin
      YMin := MaxSingle ; YMax := -MaxSingle; HasY := False;
      for k := 0 to Job.Lines.Count - 1 do
        if Job.Lines[k].Buf.N > 0 then
        begin
          if Job.Lines[k].Buf.MinY < YMin then YMin := Job.Lines[k].Buf.MinY;
          if Job.Lines[k].Buf.MaxY > YMax then YMax := Job.Lines[k].Buf.MaxY;
          HasY := True;
        end;

      frmViewTensors.lvSeries.Items.BeginUpdate;
      try
        for i := 0 to frmViewTensors.lvSeries.Items.Count - 1 do
          if Assigned(frmViewTensors.lvSeries.Items[i].Data) then
            TLegendInfo(frmViewTensors.lvSeries.Items[i].Data).Free;
        frmViewTensors.lvSeries.Items.Clear;
        //Chart.SeriesList.Clear;
        Chart.RemoveAllSeries;

        SetLength(LS, Job.Lines.Count);
        for k := 0 to Job.Lines.Count - 1 do
        begin
          Ln := Job.Lines[k];
          LS[k] := nil;
          if Ln.Buf.N = 0 then
            Continue;
          SetLength(Ln.Buf.X, Ln.Buf.N);
          SetLength(Ln.Buf.Y, Ln.Buf.N);
          if (Ln.Src <> nil) or (Ln.Title <> '') then
          begin
            LS[k] := TFastLineSeries.Create(Chart);
            LS[k].ParentChart := Chart;
            LS[k].Title := Ln.Title;
            LS[k].AddArray(Ln.Buf.X, Ln.Buf.Y);
            // option 10 : la legende ne clone plus le tenseur
            frmViewTensors.AddSeriesToListView(Ln.Title, LS[k].SeriesColor);
          end;
        end;

        // marqueurs PAR LIGNE (option 8), dessines par-dessus les courbes
        for k := 0 to Job.Lines.Count - 1 do
        begin
          Ln := Job.Lines[k];
          if Ln.Outliers.IsEmpty then
            Continue;
          PS := TPointSeries.Create(Chart);
          PS.ParentChart := Chart;
          PS.Pointer.Style := psCircle;
          PS.Pointer.Size := 3;
          PS.ShowInLegend := False;
          PS.Title := Ln.Title;
          if LS[k] <> nil then
            PS.Color := LS[k].SeriesColor
          else
            PS.Color := clRed;
          for i := 0 to Ln.Outliers.N - 1 do
            PS.AddXY(Ln.Outliers.X[i], Ln.Outliers.Y[i], '', Ln.Outliers.C[i]);
        end;

        if not Job.Blocks.IsEmpty then
        begin
          PS := TPointSeries.Create(Chart);
          PS.ParentChart := Chart;
          PS.Title := 'Block256';
          PS.Pointer.Style := psArrow;
          PS.Pointer.Size := 7;
          PS.Color := clYellow;
          PS.ShowInLegend := False;
          for i := 0 to Job.Blocks.N - 1 do
            PS.AddXY(Job.Blocks.X[i], Job.Blocks.Y[i], '', Job.Blocks.C[i]);
        end;

        if HasY and frmViewTensors.chkYAxisAuto.Checked then
        begin
          Chart.LeftAxis.Automatic := True;
          frmViewTensors.SetedtYMinedtYMaxValus(YMin, YMax);
        end
        else if not frmViewTensors.chkYAxisAuto.Checked then
          frmViewTensors.UpdateYAxisRangeFromEdit;
      finally
        frmViewTensors.lvSeries.Items.EndUpdate;
        Chart.Invalidate;
      end;

      // StatusBar / logs
      if Job.IsDiff then
      begin
        frmViewTensors.UpdateStatusBarDiffStats(Job.Stats, Job.ElapsedMs);
        //vLogMsg(Job.LogMsg, False, Job.LogLevel);
      end
      else
      begin
        // option 9 : stats de la serie de reference (la plus peuplee)
        Best := nil;
        for k := 0 to Job.Lines.Count - 1 do
          if (Best = nil) or (Job.Lines[k].Stats.N > Best.Stats.N) then
            if Job.Lines[k].Src <> nil then
              Best := Job.Lines[k];
        if Best <> nil then
        begin
          if (frmViewTensors.stBar1 <> nil) and (frmViewTensors.stBar1.Panels.Count > 0) then
            frmViewTensors.stBar1.Panels[0].Text := // 'FVT.ChartStatus',
              Format('⚡ %s | %s | μ=%.4f σ=%.4f | N=%d',
              [FormatDurationMs(Job.ElapsedMs), ShortTensorName(string(Best.Src.Name)),
               Best.Stats.Mean, Best.Stats.Std, Best.Stats.N]);
          for k := 0 to Job.Lines.Count - 1 do
            if Job.Lines[k].Stats.N > 0 then  // 'FVT.ChartLineLog',
              vLogMsg(Format('[CHART %s-R%d] %s | [%d..%d] | %s | %s',
                [Job.ImplLabel, Job.RmseIdx, Job.Lines[k].Title, Job.Lines[k].S,
                 Job.Lines[k].E, Job.Lines[k].Stats.FullStr, FormatDurationMs(Job.ElapsedMs)]), False, lvInfo);
        end;
      end;
    end;
  finally
    Job.Free;
    if frmViewTensors <> nil then
      frmViewTensors.EndRender;   // libere FBusy + rejoue le pending typise
  end;
end;

// DEMARRAGE (VCL thread)
procedure RefreshChart(ForceFullRange: Boolean = False);
begin
  // Orbitrage UNIQUE via RequestRender (histogramme inclus)
  if frmViewTensors = nil then
    Exit;
  if not frmViewTensors.RequestRender(RK_CHART, frmViewTensors.FCurrentStartIdx, frmViewTensors.FCurrentEndIdx, ForceFullRange, False) then
    Exit;
  try
    DoRefreshChart(ForceFullRange);
  except
    on E: Exception do
    begin
      frmViewTensors.EndRender;  //   '[CHART] erreur init: %s',
      vLogMsg(mLang.gMsgFmt('FVT.ChartInitErr', [E.Message]), False, lvError);
    end;
  end;
end;

procedure DoUpDateGlobalStartEndIdx(ForceFullRange: Boolean; var SelectedTensors: TList);
var
  i: Integer;
begin
  frmViewTensors.FGlobalMaxElems := 0;
  for i := 0 to frmViewTensors.ChListBoxTensors.Count - 1 do
    if frmViewTensors.ChListBoxTensors.Checked[i] then
    begin
      frmViewTensors.FGlobalMaxElems := uMath.Max(frmViewTensors.FGlobalMaxElems, TGGUFTensorInfo(frmViewTensors.ChListBoxTensors.Items.Objects[i]).TotElems);
      SelectedTensors.Add(frmViewTensors.ChListBoxTensors.Items.Objects[i]);
    end;

  if ForceFullRange and frmViewTensors.chkXAxisAuto.Checked then
  begin
    frmViewTensors.FCurrentStartIdx := 0;
    frmViewTensors.FCurrentEndIdx := frmViewTensors.FGlobalMaxElems - 1;
  end
  else
  begin
    if (frmViewTensors.FCurrentEndIdx = frmViewTensors.FCurrentStartIdx) and (frmViewTensors.FCurrentEndIdx = 0) then
    begin
      frmViewTensors.FCurrentStartIdx := cfg.XStartIdxMan;
      frmViewTensors.FCurrentEndIdx := cfg.XEndIdxMan;
      if frmViewTensors.FGlobalMaxElems = 0 then
        frmViewTensors.FGlobalMaxElems := frmViewTensors.FCurrentEndIdx;
    end;
    if frmViewTensors.FCurrentEndIdx < frmViewTensors.FCurrentStartIdx then
    begin
      frmViewTensors.FCurrentStartIdx := 0;
      if frmViewTensors.FGlobalMaxElems > 0 then
        frmViewTensors.FCurrentEndIdx := frmViewTensors.FGlobalMaxElems - 1
      else
        frmViewTensors.FGlobalMaxElems := 1;
    end;
  end;
end;

procedure DoRefreshChart(ForceFullRange: Boolean);
var
  Job: TChartJob;
  i: Integer;
  T1, T2, T0, TT: TGGUFTensorInfo;
  Spec: TChartLine;
  SelectedTensors: TList;
  LocalStart: Int64;
  CountChecked: Integer;
  E1, E2: Int64;
  StartX, EndX: Int64;
  Started : Boolean;
begin
  Started := False ;
  Job := TChartJob.Create;
  try
    Job.Gen := frmViewTensors.FRenderGen;
    Job.NumBins   := ClampInt(cfg.TVNumBins, 32, 16384);
    Job.PtsPerBin := ClampInt(cfg.TVPtsPerBin, 2, 2048);
    Job.MinXRange := cfg.MinXAxisRang;
    Job.VFPScale := cfg.VFP_Scale;
    Job.DiffAmp := cfg.DiffAmplificationFactor;
    Job.ShowBlocks := cfg.bShowBlockS;
    Job.ShowOutliers := cfg.bShowOutlierS;
    Job.ImplLabel := frmViewTensors.cbUseImpl.Text;
    Job.RmseIdx := frmViewTensors.cbRmseType.ItemIndex;
    try
      SelectedTensors := TList.Create;
      try
        DoUpDateGlobalStartEndIdx(ForceFullRange, SelectedTensors);
        CountChecked := SelectedTensors.Count;
        StartX := frmViewTensors.FCurrentStartIdx;
        EndX := frmViewTensors.FCurrentEndIdx;

        if frmViewTensors.FGlobalMaxElems > 0 then
        begin
          frmViewTensors.FRangeSlider.MinVal := 0;
          frmViewTensors.FRangeSlider.MaxVal := 1000;
          frmViewTensors.FRangeSlider.StartIdx :=
            Round((frmViewTensors.FCurrentStartIdx / frmViewTensors.FGlobalMaxElems) * 1000);
          frmViewTensors.FRangeSlider.EndIdx :=
            Round((frmViewTensors.FCurrentEndIdx / frmViewTensors.FGlobalMaxElems) * 1000);
        end;

        frmViewTensors.Chart1.BottomAxis.SetMinMax(StartX, EndX);
        frmViewTensors.FUpdatingXAxis := True;
        frmViewTensors.edtXMin.Text := IntToStr(frmViewTensors.FCurrentStartIdx);
        frmViewTensors.edtXMax.Text := IntToStr(frmViewTensors.FCurrentEndIdx);
        cfg.XStartIdxMan := frmViewTensors.FCurrentStartIdx;
        cfg.XEndIdxMan := frmViewTensors.FCurrentEndIdx;
        frmViewTensors.FUpdatingXAxis := False;

        if frmViewTensors.chkYAxisAuto.Checked then
        begin
          frmViewTensors.Chart1.LeftAxis.Automatic := True;
          frmViewTensors.SetedtYMinedtYMaxValus(frmViewTensors.Chart1.LeftAxis.Minimum,
            frmViewTensors.Chart1.LeftAxis.Maximum);
        end
        else
          frmViewTensors.UpdateYAxisRangeFromEdit;

        LocalStart := uMath.Max(0, StartX);

        if (CountChecked = 2) and (cfg.chkT1sT2 or cfg.chkT1dT2) then
        begin
          T1 := TGGUFTensorInfo(SelectedTensors[0]);
          T2 := TGGUFTensorInfo(SelectedTensors[1]);
          if (T1 = nil) or (T2 = nil) then Exit;
          if (T1.ByteSize = 0) or (T2.ByteSize = 0) then Exit;
          if T2.ByteSize > T1.ByteSize then
          begin
            T0 := T1; T1 := T2; T2 := T0;
          end;

          E1 := Min(T1.TotElems - 1, EndX);
          E2 := Min(T2.TotElems - 1, EndX);

          Job.IsDiff := True;
          Job.IsSubMode := cfg.chkT1sT2;
          Job.End1 := E1;
          Job.End2 := E2;
          Job.EndDiff := uMath.Min(E1, E2);
          Job.StartIdx := LocalStart;
          Job.EndIdx := uMath.Max(E1, E2);

          if Job.EndDiff < LocalStart then Exit;

          Spec := TChartLine.Create;
          Spec.Src := T1.Clone;
          Spec.Title := GetFormatTensorNameList(T1);
          Spec.S := LocalStart;
          Spec.E := Job.EndDiff;
          Job.Lines.Add(Spec);

          Spec := TChartLine.Create;
          Spec.Src := T2.Clone;
          Spec.Title := GetFormatTensorNameList(T2);
          Spec.S := LocalStart;
          Spec.E := Job.EndDiff;
          Job.Lines.Add(Spec);

          Spec := TChartLine.Create;
          Spec.Src := nil;
          Spec.Title := 'Diff (T1 - T2)' ; // mLang.gMsg('FVT.DiffTitle', , []);
          Spec.S := LocalStart;
          Spec.E := Job.EndDiff;
          Job.Lines.Add(Spec);

          frmViewTensors.FWorkTotal := 1 + Ord((Job.End1 > Job.EndDiff) or (Job.End2 > Job.EndDiff));
        end
        else
        begin
          for i := 0 to SelectedTensors.Count - 1 do
          begin
            TT := TGGUFTensorInfo(SelectedTensors[i]);
            if TT = nil then Continue;
            Spec := TChartLine.Create;
            Spec.Src := TT.Clone;
            Spec.Title := GetFormatTensorNameList(TT);
            Spec.S := LocalStart;
            Spec.E := uMath.Min(TT.TotElems - 1, EndX);
            if Spec.E >= Spec.S then
              Job.Lines.Add(Spec)
            else
              Spec.Free;
          end;
          frmViewTensors.FWorkTotal := Job.Lines.Count;
        end;
      finally
        SelectedTensors.Free;
      end;

      if Job.Lines.Count = 0 then
      begin
        //frmViewTensors.EndRender;  // le finally libère FBusy
        Exit;
      end;
      Job.StartIdx := LocalStart;

      frmViewTensors.FWorkDone := 0;
      frmViewTensors.FLastUViewIUpdateTick := 0;

      LogD('[CHART] job gen=%d | bins=%d pts=%d | LOD=%s | blocks=%s outliers=%s | impl=%s rmse=%d | diff=%s', //
        [Job.Gen, Job.NumBins, Job.PtsPerBin,  //
        sStrBool(SafeLODNeeded(EndX - StartX + 1, Job.NumBins, Job.PtsPerBin)), //
        sStrBool(Job.ShowBlocks), sStrBool(Job.ShowOutliers), Job.ImplLabel, Job.RmseIdx, //
        sStrBool(Job.IsDiff)]);


      TThread.CreateAnonymousThread(
        procedure
        var
          k: Integer;
          Sw: TStopwatch;
        begin
          Sw := TStopwatch.StartNew;
          try
            if Job.IsDiff then
            begin
              try
                ChartFillDiff(Job);
              except
                on E: Exception do
                   LogE(E.Message);
              end;
              if not frmViewTensors.IsCancelRequested then
              begin
                if Job.End1 > Job.EndDiff then
                begin
                  try
                    ChartFillLineRange(Job, 0, Job.EndDiff + 1, Job.End1);
                  except
                    on E: Exception do
                       LogE(E.Message);
                  end;
                end
                else if Job.End2 > Job.EndDiff then
                begin
                  try
                    ChartFillLineRange(Job, 1, Job.EndDiff + 1, Job.End2);
                  except
                    on E: Exception do
                       LogE(E.Message);
                  end;
                end;
              end;
            end
            else
              for k := 0 to Job.Lines.Count - 1 do
              begin
                if frmViewTensors.IsCancelRequested then Break;
                try
                  ChartFillLine(Job, k);
                except
                  on E: Exception do
                     LogE(E.Message);
                end;
                TThread.Queue(nil,
                  procedure
                  begin
                    if (frmViewTensors = nil) or (Job.Gen <> frmViewTensors.FRenderGen) then
                      Exit;
                    Inc(frmViewTensors.FWorkDone);
                  end);
              end;
          finally
            Sw.Stop;
            if not Job.IsDiff then
              Job.ElapsedMs := Sw.ElapsedMilliseconds;
            TThread.Queue(nil,
              procedure
              begin
                ChartApplyJob(Job);
              end);
          end;
        end).Start;
      Started := True;
    except
      on E: Exception do
      begin
        //frmViewTensors.EndRender;// le finally libère FBusy
        vLogMsg(mLang.gMsgFmt('FVT.ChartInitErr', [E.Message]), False, lvError);
      end;
    end;
  finally
    if not Started then
    begin
      frmViewTensors.EndRender;
      Job.Free;
    end;
  end;
end;


// queue du tenseur le plus long (apres l'intersection de la passe Diff)
procedure ChartFillLineRange(Job: TChartJob; LineIdx: Integer; AStar, AEnd: Int64);
var
  Ln: TChartLine;
  SaveS, SaveE: Int64;
begin
  Ln := Job.Lines[LineIdx];
  if (Ln = nil) or (AEnd < AStar) then
    Exit;
  SaveS := Ln.S;
  SaveE := Ln.E;
  try
    Ln.S := AStar;
    Ln.E := AEnd;
    ChartFillLine(Job, LineIdx);
  finally
    if SaveE > AEnd then
      Ln.E := SaveE
    else
      Ln.E := AEnd;
    Ln.S := SaveS;
  end;
end;

end.

