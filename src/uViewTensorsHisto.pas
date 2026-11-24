unit uViewTensorsHisto;

{ ============================================================================
  HISTOGRAMME  --  modele « JOB » (l'ouvrier ne lit NI cfg NI VCL)
  ----------------------------------------------------------------------------
  GenerateHistogram(Fast|Full)      (VCL thread)
    FillJobFromUi   : cfg + controles -> record plat, CLONE les tenseurs
    1 thread        : MesurerZone -> ResolveWindow -> PrepareBins -> Biner
    HistoApplyJob   : (VCL) series, 2 axes, edtWin*/edtVal*/edtCnt*, lblHistStat,
                      statusbar, logs.  Job perime/annule = JETE.  Puis EndRender.
  ----------------------------------------------------------------------------
  FENETRE (axe X = valeurs) : 2 modes, aucun bouton « Calib » / « Reset ».
    V-Auto (chkVAuto) coche : la fenetre = la MESURE de la zone.
        FAST  : 1 passe de mesure (LOD) -> fenetre -> 1 passe de binning (LOD)
        FULL  : 1 passe de mesure (LOD, bon marche) -> fenetre -> passe FULL,
                puis les vrais min/max EXACTS du pipeline remplacent la mesure.
    manuel (decoche) : la fenetre = edtWin* / cfg.HistWMinMan..HistWMaxMan.
  ZONE  : [FCurrentStartIdx..FCurrentEndIdx] (plage globale sans zoom), honoree
          en FAST comme en FULL.  En mode couple, zone = INTERSECTION des 2.
  DIFF  : 2 tenseurs + (chkT1sT2 = T1-T2 | chkT1dT2 = T1/T2) : passe jointe
          (1 seule lecture, alignee sur le PPC) + WRMSE/RMS/MAE/Mean/WRel.
  ----------------------------------------------------------------------------
  Invariants :
    1. edtWin* == Job.WMin/WMax == « W: » des logs      (ce qui est applique)
    2. edtVal* == Job.Meas*     == « V1: » des logs      (la mesure)
    3. la fenetre est resolue UNE fois par job ; le binning ne la change jamais
    4. hors fenetre = compte dans le bin de bord (jamais jete) => N et sat justes
============================================================================ }

interface

uses
  Winapi.Windows, System.SysUtils, System.Classes, System.Threading,
  System.Diagnostics, System.Generics.Collections,
  VclTee.Chart, VclTee.Series, Vcl.Graphics, VclTee.TeEngine,
  uMath, uGGUFModel, uGGMLTypes, uAppConfig, uGGMLConstants, uLangManager,
  uTensorStreamReader, uFullDiffPipeline, uLog, uDiffStats;

type
  { ---- UN histogramme : compteurs + stats.  Aucun etat VCL. ----------------
     Init NE TOUCHE PAS Lo/Hi/Ok : la mesure survit a la preparation des bins. }
  THistogram = record
    MaxBars: Integer;
    Counts: array of Int64;
    VMin, VMax, BinW: Double;     // fenetre reellement appliquee
    N, NIn, NNan, NInf: Int64;    // N = comptes ; NIn = valeurs finies dans la fenetre
    Lo, Hi: Double;               // MESURE (min/max finis)
    Ok: Boolean;                  // Lo/Hi valides
    SumsOk: Boolean;              // Sum/SumSq alimentes (FAST) ; FALSE -> Moy/Std estimees
    Sum, SumSq, SumCube: Double;
    Mean, Std, Med, ModeVal, Skew: Double;
    ReadElems: Int64;             // elements planifies par le binning
    UnitE: Int64;                 // PPC = unite independante (0 = inconnue)
    procedure Init(ABins: Integer);
    procedure Add(V: Double);
    procedure Observe(V: Double);
    procedure Finish;
    function Empty: Boolean;
    function MeasureStr: string;
  end;

    { ---- 1 serie = 1 tenseur CLONE + son histogramme ----------------------- }
  THistoSeries = class
  public
    Src: TGGUFTensorInfo;
    H: THistogram;
    S, E: Int64;                  // plage propre, deja clippee
    Title: string;
    LOD: Boolean;                 // LOD reellement utilise (log /L ou /Z)
    ElapsedMs: Int64;
    constructor Create;
    destructor Destroy; override;
  end;
  { Dynamic array (refcounte) : lui SEUL est capturable dans une closure.
    Un open-array en parametre (E2555) ne l'est pas. }
  THistoSeriesArr = array of THistoSeries;


  { ---- LE job : plan (copie VCL/cfg) + resultats. ------------------------- }
  THistoJob = class
  public
    Gen: Integer;
    Series: TObjectList<THistoSeries>;
    // plan
    ElemStart, ElemEnd: Int64;
    MaxBars, StatBins, StatPts: Integer;
    VAuto, NAuto, Full, IsDiff, IsSubMode: Boolean;
    WMin, WMax: Double;           // fenetre appliquee
    ImplLabel: string;
    RmseIdx: Integer;
    VFPScale: Double;
    // mesure + couverture
    MeasLo, MeasHi: Double;
    MeasOk: Boolean;
    Sampled, ZoneLen, Units: Int64;
    // sortie
    Stats: TDiffStats;
    StatsValid: Boolean;
    Peak: Int64;
    ElapsedMs: Int64;
    ExactMeas: Boolean;
    constructor Create;
    destructor Destroy; override;
  end;

  { Visiteur commun aux deux phases : Srs = 1 serie, ou 2 en mode couple. }
  //THistoVisit = reference to procedure(Srs: array of THistoSeries;
  //  Rs: array of TTensorReader; AStart, ACount: Int64);

  THistoVisit = reference to procedure(Srs: THistoSeriesArr;
    Rs: array of TTensorReader; AStart, ACount: Int64);

procedure GenerateHistogram(HistModeFull: Boolean = False);

implementation

uses uViewTensors, uViewTensorsChart, uStrUtils;

const
  CHISTO_PCT_DETECT = 25;    // poids de la passe de mesure dans la progression
  CSE_KAPPA         = 0.8;   // kappa-1 : residu de quantification
  CWIN_MARGIN = 0.05;    // marge d'extension quand la mesure vient d'un echantillon


procedure HistoApplyJob(Job: THistoJob);   forward;
procedure ResolveWindow(Job: THistoJob);     forward;
function ReuseExactMeasure(Job: THistoJob): Boolean; forward;

{ ============================================================================
  0. petits utilitaires
============================================================================ }

function Cancelled: Boolean; inline;
begin
  Result := (frmViewTensors = nil) or frmViewTensors.IsCancelRequested;
end;

function PctMesure(APct: Integer): Integer; inline;
begin
  Result := (APct * CHISTO_PCT_DETECT) div 100;      // 0..25
end;

function PctBinning(Job: THistoJob; APct: Integer): Integer; inline;
var B: Integer;
begin
  B := 0;
  if Job.VAuto then B := CHISTO_PCT_DETECT;           // fenetre deja payee
  Result := B + (APct * (100 - B)) div 100;
end;

procedure BumpWorkDone(Job: THistoJob);
begin
  TThread.Queue(nil,
    procedure
    begin
      if (frmViewTensors = nil) or (Job.Gen <> frmViewTensors.FRenderGen) then
        Exit;
      Inc(frmViewTensors.FWorkDone);
    end);
end;

{ ============================================================================
  1. THistogram
============================================================================ }

procedure THistogram.Init(ABins: Integer);
begin
  MaxBars := ABins;
  SetLength(Counts, ABins);
  if ABins > 0 then
    FillChar(Counts[0], ABins * SizeOf(Int64), 0);
  VMin := 0; VMax := 0; BinW := 0;
  N := 0; NIn := 0; NNan := 0; NInf := 0;
  SumsOk := False;
  Sum := 0; SumSq := 0; SumCube := 0;
  Mean := 0; Std := 0; Med := 0; ModeVal := 0; Skew := 0;
  ReadElems := 0; UnitE := 0;
  // Lo/Hi/Ok VOLONTAIREMENT non reinitalises : la mesure de la passe A survit.
end;

procedure THistogram.Observe(V: Double);
begin
  if IsNaN(V) or IsInfinite(V) then Exit;
  if not Ok then
  begin
    Lo := V; Hi := V; Ok := True;
    Exit;
  end;
  if V < Lo then Lo := V;
  if V > Hi then Hi := V;
end;

// clamp aux bins de bord : la valeur reste COMPTEE (jamais jetee), mais ne
// pollue pas Moy/Std/Ecart (le vrai min/max vient de Lo/Hi, pas d'ici).
procedure THistogram.Add(V: Double);
var
  bi: Integer;
begin
  if (MaxBars <= 0) or (BinW <= 0) then Exit;
  bi := Trunc((V - VMin) / BinW);
  if bi < 0 then bi := 0
  else if bi >= MaxBars then bi := MaxBars - 1;
  Inc(Counts[bi]);
  Inc(N);
  if (V >= VMin) and (V <= VMax) then
  begin
    Inc(NIn);
    Sum := Sum + V; SumSq := SumSq + V * V; SumCube := SumCube + V * V * V;
    SumsOk := True;
  end;
end;

procedure THistogram.Finish;
var
  i, iMed, iMode: Integer;
  Half, Cum, C, E2, E3, VarVal, Dn: Double;
begin
  if N <= 0 then Exit;

  if not SumsOk then
  begin
    // passe FULL : le pipeline ne rend que des compteurs -> moyenne/ecart
    // ESTIMES sur les centres de bins (signale en commentaire dans le log).
    for i := 0 to MaxBars - 1 do
      if Counts[i] <> 0 then
      begin
        C := VMin + (i + 0.5) * BinW;
        Sum := Sum + Counts[i] * C;
        SumSq := SumSq + Counts[i] * C * C;
        SumCube := SumCube + Counts[i] * C * C * C;
      end;
    NIn := N;
  end;

  Dn := NIn;
  if Dn <= 0 then Dn := N;
  Mean := Sum / Dn;
  VarVal := SumSq / Dn - (Mean * Mean);
  if VarVal < 0 then VarVal := 0;
  Std := Sqrt(VarVal);

  Half := N / 2.0;
  Cum := 0; iMed := -1;
  for i := 0 to MaxBars - 1 do
  begin
    Cum := Cum + Counts[i];
    if Cum >= Half then begin iMed := i; Break; end;
  end;
  iMode := -1;
  for i := 0 to MaxBars - 1 do
    if (iMode = -1) or (Counts[i] > Counts[iMode]) then iMode := i;

  if iMed <> -1 then Med := VMin + (iMed + 0.5) * BinW;
  if iMode <> -1 then ModeVal := VMin + (iMode + 0.5) * BinW;

  if Std > 1E-9 then
  begin
    E2 := SumSq / Dn;
    E3 := SumCube / Dn;
    Skew := (E3 - 3 * Mean * E2 + 2 * Mean * Mean * Mean) / (Std * Std * Std);
  end
  else
    Skew := 0;
end;


function THistogram.Empty: Boolean;
begin
  Result := N = 0;
end;

function THistogram.MeasureStr: string;
begin
  if not Ok then Exit('[--]');
  Result := Format('[%.4f..%.4f]', [Lo, Hi]);
end;

{ ============================================================================
  2. THistoSeries / THistoJob
============================================================================ }

constructor THistoSeries.Create;
begin
  S := 0; E := -1;
  Title := '';
  LOD := False;
  ElapsedMs := 0;
  FillChar(H, SizeOf(H), 0);   // OK : les champs geres (Counts) sont remis a nil
  H.Lo := MaxDouble; H.Hi := -MaxDouble; H.Ok := False;
end;

destructor THistoSeries.Destroy;
begin
  SetLength(H.Counts, 0);
  Src.Free;
  inherited;
end;

constructor THistoJob.Create;
begin
  Series := TObjectList<THistoSeries>.Create(True);
  FillChar(Stats, SizeOf(Stats), 0);
  VFPScale := 1.0;
  MeasLo := MaxDouble; MeasHi := -MaxDouble; MeasOk := False;
end;

destructor THistoJob.Destroy;
begin
  Series.Free;
  inherited;
end;

{ ============================================================================
  3. FENETRE : un seul endroit
============================================================================ }

function ValidWindow(Mn, Mx: Double): Boolean;
var m: Double;
begin
  m := Max(Abs(Mn), Abs(Mx));
  if (m = 0) or (m = MaxDouble) or IsNaN(m) or IsInfinite(m) then m := 1;
  Result := (Mx > Mn) and (Mx - Mn > 1E-9 * m) and
            not (IsNaN(Mn) or IsNaN(Mx) or IsInfinite(Mn) or IsInfinite(Mx));
end;

procedure AggregateMeasure(Job: THistoJob);
var
  k: Integer;
  Sr: THistoSeries;
begin
  Job.MeasOk := False;
  Job.MeasLo := MaxDouble; Job.MeasHi := -MaxDouble;
  for k := 0 to Job.Series.Count - 1 do
  begin
    Sr := Job.Series[k];
    if not Sr.H.Ok then Continue;
    if not Job.MeasOk then
    begin
      Job.MeasLo := Sr.H.Lo; Job.MeasHi := Sr.H.Hi; Job.MeasOk := True;
    end
    else
    begin
      if Sr.H.Lo < Job.MeasLo then Job.MeasLo := Sr.H.Lo;
      if Sr.H.Hi > Job.MeasHi then Job.MeasHi := Sr.H.Hi;
    end;
  end;
end;

procedure ResolveWindow(Job: THistoJob);
begin
  if (not Job.VAuto) and ValidWindow(Job.WMin, Job.WMax) then Exit;   // l'utilisateur fait foi
  if Job.MeasOk and ValidWindow(Job.MeasLo, Job.MeasHi) then
  begin
    Job.WMin := Job.MeasLo; Job.WMax := Job.MeasHi;
    if not Job.ExactMeas then                 // echantillon LOD -> les vrais bords sont ailleurs
      AxisMargin(Job.WMin, Job.WMax, CWIN_MARGIN);   // uMath, deja dans les uses
    Exit;
  end;
  //Job.WMin := -0.5; Job.WMax := 0.5;
end;


procedure PrepareBins(Job: THistoJob);
var
  k, B: Integer;
begin
  B := Job.MaxBars;
  if B < 4 then B := 4;
  for k := 0 to Job.Series.Count - 1 do
    with Job.Series[k].H do
    begin
      Init(B);
      VMin := Job.WMin;
      VMax := Job.WMax;
      BinW := (Job.WMax - Job.WMin) / B;
    end;
end;

{ ============================================================================
  4. LE parcours unique (FAST) : remplace HistoDetectLine / HistoDetectDiff /
     HistoFillBins / HistoFillDiff.  1 lecteur, ou 2 alignes sur le PPC si
     Srs a 2 elements (mode couple) -> UNE seule lecture pour les deux.
============================================================================ }

function WalkSeries(Job: THistoJob; Srs: THistoSeriesArr;
  PhaseBin: Boolean; Visit: THistoVisit): Boolean;
var
  n, k: Integer;
  Rs: array of TTensorReader;
  R: TTensorReader;
  Plan: TWalkPlan;
  S, E, eofIdx, Chunk: Int64;
  DoLOD: Boolean;
  SW: TStopwatch;
begin
  Result := False;
  n := Length(Srs);
  if (n < 1) or (n > 2) then Exit;

  S := Srs[0].S; E := Srs[0].E;
  for k := 1 to n - 1 do
  begin
    if Srs[k].S > S then S := Srs[k].S;          // couple -> INTERSECTION
    if Srs[k].E < E then E := Srs[k].E;
  end;
  if E < S then Exit;

  SW := TStopwatch.StartNew;
  SetLength(Rs, n);
  try
    for k := 0 to n - 1 do
    begin
      R := TTensorReader.Create(Srs[k].Src);
      if not R.Ok then
      begin
        //Srs[k].ErrMsg := R.ErrText;
        R.Free;
        Exit;
      end;
      R.SetOutScale(Job.VFPScale);
      Rs[k] := R;
      Srs[k].H.UnitE := R.PPC;
    end;

    DoLOD := SafeLODNeeded(E - S + 1, Job.StatBins, Job.StatPts);
    // LOD : 1 bloc = 1 echantillon (pas de sur-lecture) ; contigu : 1 ReadFile / 4096 (CREAD_CHUNK_ELEMS)

    Chunk := IfThen1(DoLOD, Int64(CLOD_CHUNK_MIN), Int64(CREAD_CHUNK_ELEMS));
    if n > 1 then
    begin
      if not AlignMaxBE(Rs, Chunk) then Exit; // super-bloc COMMUN (déjà arrondi au PPC)
      for k := 0 to n - 1 do Srs[k].H.UnitE := Rs[k].MaxBE;
    end
    else
      for k := 0 to n - 1 do
        if not Rs[k].Reshape(AlignUpI64(Chunk, Rs[k].PPC)) then Exit;


    for k := 0 to n - 1 do Srs[k].LOD := DoLOD;

    Plan := BuildPlan(S, E, DoLOD, Job.StatBins, Job.StatPts);
    try
      if Srs[0].H.ReadElems < Plan.Total then Srs[0].H.ReadElems := Plan.Total;
      if n = 2 then Srs[1].H.ReadElems := 0;      // passe jointe : compte UNE fois

      // ★ tout ce qui est capture ici est LOCAL ou PARAMETRE PAR VALEUR :
      //   Job / Srs (dynamic array), S / E / PhaseBin (locaux), Visit (valeur)
      RunPlan(Plan, Rs,
        procedure(RsIn: array of TTensorReader; AStart, ACount: Int64)
        begin
          Visit(Srs, RsIn, AStart, ACount);
        end,
        function: Boolean
        begin
          Result := Cancelled;
        end,
        procedure(ADone, ATotal: Int64; APct: Integer)
        var T: string; P: Integer;
        begin
          T := Srs[0].Title;                                   // copie locale hors closure
          if PhaseBin then P := PctBinning(Job, APct) else P := PctMesure(APct);
          frmViewTensors.SetProgress(S + ADone, E + 1, P, T);
        end,
        eofIdx);

      if eofIdx >= 0 then
      if LogIsOn(lvWarn) then
           LogW(mLang.gMsgFmt('FVT.EOFWarn', [eofIdx]));
      Result := True;
    finally
      Plan.Free;
    end;
  finally
    SW.Stop;
    Job.ElapsedMs := SW.ElapsedMilliseconds;
    for k := 0 to n - 1 do
      if Rs[k] <> nil then Rs[k].Free;
    if PhaseBin then
      for k := 0 to n - 1 do
        if Srs[k].ElapsedMs = 0 then Srs[k].ElapsedMs := SW.ElapsedMilliseconds;
  end;
end;

// une serie, puis l'autre, ou le couple en UNE fois (mode couple)
procedure ForEach(Job: THistoJob; PhaseBin: Boolean; Visit: THistoVisit);
var
  k: Integer;
  Srs: THistoSeriesArr;//array of THistoSeries;
begin
  if Job.IsDiff then
  begin
    SetLength(Srs, 2);
    Srs[0] := Job.Series[0]; Srs[1] := Job.Series[1];
    WalkSeries(Job, Srs, PhaseBin, Visit);
    BumpWorkDone(Job);
    Exit;
  end;
  for k := 0 to Job.Series.Count - 1 do
  begin
    if Cancelled then Break;
    SetLength(Srs, 1);
    Srs[0] := Job.Series[k];
    WalkSeries(Job, Srs, PhaseBin, Visit);
    BumpWorkDone(Job);
  end;
end;

procedure MesurerZone(Job: THistoJob);
var
  Vst: THistoVisit;
begin
  Vst := procedure(Srs: THistoSeriesArr {array of THistoSeries}; Rs: array of TTensorReader;
    AStart, ACount: Int64)
    var
      k: Integer;
      j: Int64;
    begin
      for k := 0 to High(Srs) do
        for j := 0 to ACount - 1 do
          Srs[k].H.Observe(Rs[k].ValAt(AStart + j));   // min/max, NaN/Inf ignores
    end;
  ForEach(Job, False, Vst);
  AggregateMeasure(Job);
end;

procedure BinerFast(Job: THistoJob);
var
  WT: TDiffWeights;
  Acc: TDiffAcc;
  Vst: THistoVisit;
begin
  Acc.Reset;
  if Job.IsDiff then BuildDiffWeights(Job.Series[0].Src, WT);

  Vst := procedure(Srs: THistoSeriesArr {array of THistoSeries}; Rs: array of TTensorReader;
    AStart, ACount: Int64)
    var
      k: Integer;
      j: Int64;
      v: Double;
    begin
      for k := 0 to High(Srs) do
        for j := 0 to ACount - 1 do
        begin
          v := Rs[k].ValAt(AStart + j);
          if IsNaN(v) then Inc(Srs[k].H.NNan)
          else if IsInfinite(v) then Inc(Srs[k].H.NInf)
          else
          begin
            Srs[k].H.Observe(v);
            Srs[k].H.Add(v);
          end;
        end;
      if Length(Srs) = 2 then                     // couple : stats de difference
        for j := 0 to ACount - 1 do
          Acc.Add(Single(Rs[0].ValAt(AStart + j)), Single(Rs[1].ValAt(AStart + j)),
                  AStart + j, Job.IsSubMode, WT);
    end;

  ForEach(Job, True, Vst);

  if Job.IsDiff then
   begin
    CopyStatsFromAcc(Job.Stats, Acc , Job.ElapsedMs);
    Job.StatsValid := Acc.Count > 0;
  end;
end;

{ ============================================================================
  5. Passe FULL : pipeline parallele (uFullDiffPipeline), 1 ou 2 specs
============================================================================ }

function MakeFullParams(Job: THistoJob; Srs: array of THistoSeries;
  out SE, EE: Int64; out P: TFullDiffParams): Boolean;
var
  k, n: Integer;
begin
  Result := False;
  n := Length(Srs);
  SetLength(P.Specs, n);
  SE := Srs[0].S;
  EE := Srs[0].E + 1;
  for k := 0 to n - 1 do
  begin
    P.Specs[k] := MakeFullSpec(Srs[k].Src);
    if P.Specs[k].ApplyScale then P.Specs[k].OutScale := Single(Job.VFPScale);
    if not P.Specs[k].Valid then
    begin
      if LogIsOn(lvError) then
           LogE(Format('[FULL] format inexploitable (%s)',
        [GGMLTypeToStr(P.Specs[k].TypeOrg)]));
      Exit;
    end;
    if P.Specs[k].TotElems < EE then EE := P.Specs[k].TotElems;
  end;
  for k := 1 to n - 1 do
    if Srs[k].S > SE then SE := Srs[k].S;         // couple -> intersection
  if EE <= SE then Exit;

  P.StartElem  := SE;
  P.TotalElems := EE - SE;
  P.MaxBars   := Job.MaxBars;
  P.WinMin     := Job.WMin;
  P.WinMax     := Job.WMax;
  P.BinW       := (Job.WMax - Job.WMin) / Job.MaxBars;
  P.MakeBins   := True;
  P.ComputeAcc := (n = 2);
  P.SubMode    := Job.IsSubMode;
  if n = 2 then BuildDiffWeights(Srs[0].Src, P.WT);
  P.ChunkBytes    := GFullChunkBytes;
  P.QueueCapacity := GFullQueueCap;
  P.Workers       := TThread.ProcessorCount;
  Result := True;
end;

// compteurs exacts du pipeline -> histogramme ; les VRAIS min/max deviennent la mesure
procedure ApplyAgg(const Src: TFullSeriesAgg; var H: THistogram; MaxBars: Integer);
var
  g: Integer;
begin
  if Length(H.Counts) <> MaxBars then
    SetLength(H.Counts, MaxBars);
  if MaxBars > 0 then
  begin
    if Length(Src.Counts) = MaxBars then
      Move(Src.Counts[0], H.Counts[0], MaxBars * SizeOf(Int64))
    else
      FillChar(H.Counts[0], MaxBars * SizeOf(Int64), 0);
  end;
  H.MaxBars := MaxBars;
  H.N := 0;
  for g := 0 to MaxBars - 1 do
    Inc(H.N, H.Counts[g]);
  H.NIn := H.N;
  H.NNan := Src.NNan;
  H.NInf := Src.NInf;
  if (Src.MinV < MaxSingle) and (Src.MaxV > -MaxSingle) and (Src.MaxV > Src.MinV) then
  begin
    H.Lo := Src.MinV;
    H.Hi := Src.MaxV;
    H.Ok := True;   // mesure EXACTE
  end;
end;

procedure FullOne(Job: THistoJob; Sr: THistoSeries);
var
  P: TFullDiffParams;
  R: TFullDiffResult;
  SE, EE: Int64;
  DoneMax: Int64;
  SW: TStopwatch;
begin
  DoneMax := 0;
  if not MakeFullParams(Job, Sr, SE, EE, P) then Exit;
  SW := TStopwatch.StartNew;
  try
    R := RunFullDiffParallel(P,
      procedure(ADone, ATotal: Int64; APct: Integer)
      begin
        if ADone > DoneMax then DoneMax := ADone;
        frmViewTensors.SetProgress(SE + ADone, EE, PctBinning(Job, APct), Sr.Title);
      end,
      function: Boolean
      begin
        Result := Cancelled;
      end);

    ApplyAgg(R.Series[0], Sr.H, Job.MaxBars);

    if (Sr.H.N = 0) then
      if LogIsOn(lvError) then
           LogE('FULL: 0 element binne sur [%d..%d] (voir log [FULL])', [SE, EE - 1]);

    if Sr.H.Ok then
      Job.ExactMeas := True;

    Sr.H.ReadElems := Min(DoneMax, EE - SE);
    Sr.H.UnitE := P.Specs[0].PPC;
    Sr.LOD := False;
  finally
    SW.Stop;
    Sr.ElapsedMs := SW.ElapsedMilliseconds;
  end;
end;

procedure FullPair(Job: THistoJob);
var
  P: TFullDiffParams;
  R: TFullDiffResult;
  Srs: array of THistoSeries;
  SE, EE: Int64;
  DoneMax: Int64;      // locale => capturable
  SW: TStopwatch;
begin
  DoneMax := 0;
  SetLength(Srs, 2);
  Srs[0] := Job.Series[0]; Srs[1] := Job.Series[1];
  if not MakeFullParams(Job, Srs, SE, EE, P) then Exit;
  SW := TStopwatch.StartNew;
  try
    R := RunFullDiffParallel(P,
      procedure(ADone, ATotal: Int64; APct: Integer)
      begin
        if ADone > DoneMax then DoneMax := ADone;
        frmViewTensors.SetProgress(SE + ADone, EE, PctBinning(Job, APct), Srs[0].Title);
      end,
      function: Boolean
      begin
        Result := Cancelled;
      end);
    ApplyAgg(R.Series[0], Srs[0].H, Job.MaxBars);
    ApplyAgg(R.Series[1], Srs[1].H, Job.MaxBars);

    if (Srs[0].H.N = 0) and (Srs[1].H.N = 0) then
      if LogIsOn(lvError) then
           LogE('FULL: 0 element binne sur [%d..%d] (voir log [FULL])', [SE, EE - 1]);

    if Srs[0].H.Ok then
      Job.ExactMeas := True;

    // ★ couverture REELLE (le decalage d'alignement <= PPC-1 est absorbe par Min)
    Srs[0].H.ReadElems := Min(DoneMax, EE - SE);
    Srs[1].H.ReadElems := 0;     // passe jointe : une unite
    if (DoneMax < (EE - SE)) and not Cancelled then
      LogW('[FULL] zone [%d..%d] couverte a %.2f%% (%d/%d elem)',
        [SE, EE - 1, 100.0 * DoneMax / (EE - SE), DoneMax, EE - SE]);

    //Srs[0].H.UnitE := Min(P.Specs[0].PPC, P.Specs[1].PPC);
    Srs[0].H.UnitE := Lcm64(P.Specs[0].PPC, P.Specs[1].PPC);
    Srs[0].LOD := False; Srs[1].LOD := False;
    SW.Stop;
    Srs[0].ElapsedMs := SW.ElapsedMilliseconds;
    Srs[1].ElapsedMs := Srs[0].ElapsedMs;

    CopyStatsFromAcc(Job.Stats, R.Acc , Srs[0].ElapsedMs);
    Job.StatsValid := R.Acc.Count > 0;
    // la fenetre etait estimee par la passe de mesure : on dit si elle etait trop etroite
    if Job.MeasOk and ((Job.WMin > Job.MeasLo) or (Job.WMax < Job.MeasHi)) then
      LogW('[HIST/F] fenetre [%s..%s] TROP ETROITE vs exact %s',
        [FormatFloat4f(Job.WMin), FormatFloat4f(Job.WMax),
         Format('[%.4f..%.4f]', [Job.MeasLo, Job.MeasHi])]);
  finally

  end;
end;

procedure Biner(Job: THistoJob);
var
  k: Integer;
begin
  if not Job.Full then
  begin
    BinerFast(Job);
    Exit;
  end;
  if Job.IsDiff then
  begin
    FullPair(Job);
    BumpWorkDone(Job);
    Exit;
  end;
  for k := 0 to Job.Series.Count - 1 do
  begin
    if Cancelled then Break;
    FullOne(Job, Job.Series[k]);
    BumpWorkDone(Job);
  end;
end;

{ ============================================================================
  6. Qualite de la mesure + textes (construits par l'ouvrier, affiches par la VCL)
============================================================================ }

procedure UpdateQuality(Job: THistoJob);
var
  k: Integer;
  Sr: THistoSeries;
begin
  Job.Sampled := 0; Job.Units := 0;
  Job.ZoneLen := Max(0, Job.ElemEnd - Job.ElemStart + 1);
  for k := 0 to Job.Series.Count - 1 do
  begin
    Sr := Job.Series[k];
    if Sr.H.ReadElems > Job.Sampled then Job.Sampled := Sr.H.ReadElems; // couverture max
    if Sr.H.UnitE > 0 then Inc(Job.Units, Sr.H.ReadElems div Sr.H.UnitE)
    else Inc(Job.Units, Sr.H.ReadElems);
  end;
end;

function ModeTag(Job: THistoJob; Sr: THistoSeries): string; inline;
begin
  if Job.Full then Result := '/F'
  else if Sr.LOD then Result := '/L'
  else Result := '/Z';
end;

procedure FillLineLog(Job: THistoJob; Sr: THistoSeries);
begin
  if Sr.H.N > 0 then
  begin
    if LogIsOn(lvInfo) then
           LogI(
      '[HIST %s%s] %s | P:[%d..%d] | N:%d (cov %s) | NaN:%d Inf:%d | V1:%s' +
      ' | Moy=%.6f Ecart=%.6f Med=%.6f Mode=%.6f Skew=%.2f | | %s',
      [Job.ImplLabel, ModeTag(Job, Sr), Sr.Title, Sr.S, Sr.E,
       Sr.H.N, PctOf(Sr.H.ReadElems, Max(1, Sr.E - Sr.S + 1)),
       Sr.H.NNan, Sr.H.NInf, Sr.H.MeasureStr,
       Sr.H.Mean, Sr.H.Std, Sr.H.Med, Sr.H.ModeVal, Sr.H.Skew,
       FormatDurationMs(Sr.ElapsedMs)])
  end
  else
    if LogIsOn(lvWarn) then
           LogW('[HIST %s%s] %s | P:[%d..%d] | AUCUNE valeur | V1:%s | NaN:%d Inf:%d | %s',
      [Job.ImplLabel, ModeTag(Job, Sr), Sr.Title, Sr.S, Sr.E,
       Sr.H.MeasureStr, Sr.H.NNan, Sr.H.NInf, FormatDurationMs(Sr.ElapsedMs)]);
end;

procedure FillDiffLog(Job: THistoJob; S, E: Int64);
var
  N1, N2: string;
begin
  if SameText(string(Job.Series[0].Src.Name), string(Job.Series[1].Src.Name)) then
    N2 := FormatTensorSrcSizeType(Job.Series[1].Src)  //GGMLTypeToStr(Job.Series[1].Src.TensorType)   // meme nom -> le type suffit
  else
    N2 := FormatTensorLogInfo(Job.Series[1].Src);
  N1 := FormatTensorLogInfo(Job.Series[0].Src);

  if not Job.StatsValid then
  begin
    if LogIsOn(lvInfo) then
      LogI(mLang.gMsgFmt('FVT.DiffNoDataLog', [FormatDurationMs(Job.ElapsedMs)]), []);
    Exit;
  end;
  if LogIsOn(lvNotice) then
    LogN('[%s-R%d%s] %s vs %s | P:[%d..%d] | E:%d | WRMSE=%.6f RMS=%.6f MAE=%.6f Mean=%.6f WRel=%.4f | V1:%s | %s', //
      [Job.ImplLabel, Job.RmseIdx, ModeTag(Job, Job.Series[0]), N1, N2, S, E, //
      Job.Stats.Count, Job.Stats.WRMSE, Job.Stats.RMS, Job.Stats.MAE, Job.Stats.Mean, //
      Job.Stats.WRMSERel, Job.Series[0].H.MeasureStr , FormatDurationMs(Job.ElapsedMs)]);

    if LogIsOn(lvTrace) then
       LogT('cov=%s nBlk=%d', [PctOf(Job.Sampled, Job.ZoneLen),Job.Units]);
end;

procedure ComposeStatus(Job: THistoJob);
var
  k, nValid, nMax: Integer;
  Sr: THistoSeries;
begin
  nValid := 0; nMax := -1;
  for k := 0 to Job.Series.Count - 1 do
    if not Job.Series[k].H.Empty then
    begin
      Inc(nValid);
      if (nMax = -1) or (Job.Series[k].H.N > Job.Series[nMax].H.N) then nMax := k;
    end;

  if Job.IsDiff then
  begin
    if not Job.StatsValid then
      if LogIsOn(lvWarn) then
        LogW(mLang.gMsg('FVT.HistNoData'));
    Exit;   // sinon la statusbar est tenue par UpdateStatusBarDiffStats
  end;
  if nValid = 0 then
  begin
  if LogIsOn(lvWarn) then
      LogW(mLang.gMsg('FVT.HistNoData'));
    Exit;
  end;

  Sr := Job.Series[nMax];
  if Job.Series.Count = 1 then
  begin
    if LogIsOn(lvInfo) then
      LogI('%s | %s | mu=%.4f sd=%.4f | W:[%s..%s] | cov %s', [FormatDurationMs(Job.ElapsedMs),  //
        ShortTensorName(string(Sr.Src.Name)), Sr.H.Mean, Sr.H.Std, FormatFloat4f(Job.WMin), //
        FormatFloat4f(Job.WMax), PctOf(Job.Sampled, Job.ZoneLen)])
  end
  else if LogIsOn(lvInfo) then
    LogI('%s | %d/%d series | MaxBars=%d | W:[%s..%s] | mu=%.4f sd=%.4f | cov %s', //
      [FormatDurationMs(Job.ElapsedMs), nValid, Job.Series.Count, Job.MaxBars, FormatFloat4f(Job.WMin), //
      FormatFloat4f(Job.WMax), Sr.H.Mean, Sr.H.Std, PctOf(Job.Sampled, Job.ZoneLen)]);
end;


{ ============================================================================
  7. OUVRIER : sequence complete, aucune VCL
============================================================================ }
procedure HistoWorker(Job: THistoJob);
var
  k: Integer;
  SW: TStopwatch;
  S, E: Int64;
begin
  SW := TStopwatch.StartNew;
  S := Job.ElemStart; E := Job.ElemEnd;   // valeurs sures meme en cas de sortie anticipee
  try
    try
      // 1) FENETRE
      if Job.VAuto and (not ReuseExactMeasure(Job)) and (not Cancelled) then
        MesurerZone(Job);                         // LOD bon marche
      AggregateMeasure(Job);                      // <- doit precéder ResolveWindow
      ResolveWindow(Job);
      PrepareBins(Job);
      if Job.IsDiff and (Job.Series.Count > 1) then
      begin
        if Job.Series[1].S > S then S := Job.Series[1].S;   // couple -> intersection
        if Job.Series[1].E < E then E := Job.Series[1].E;
      end;
      // 2) BINNING
      if Cancelled then
      begin
        if LogIsOn(lvWarn) then
           LogW('passe annulee (demande plus recente)')
      end
      else
        Biner(Job);
    except
      on Ex: Exception do
        if Job.Series.Count > 0 then
          if LogIsOn(lvError) then
             LogE(Ex.Message);
    end;
  finally
    SW.Stop;
    // ★ ORDRE IMPOSE : chrono -> stats -> qualite -> mesure exacte -> textes
    Job.ElapsedMs := SW.ElapsedMilliseconds;
    Job.Stats.FElapsedMs := Job.ElapsedMs;
    for k := 0 to Job.Series.Count - 1 do Job.Series[k].H.Finish;
    UpdateQuality(Job);
    AggregateMeasure(Job);  // FULL : les min/max EXACTS remplacent l'estimation
    if Job.IsDiff then FillDiffLog(Job, S, E);
    for k := 0 to Job.Series.Count - 1 do FillLineLog(Job, Job.Series[k]);
    ComposeStatus(Job);
    TThread.Queue(nil,
      procedure begin HistoApplyJob(Job); end);
  end;
end;

// FULL + auto : un FULL precedent sur la MEME zone a deja donne les min/max exacts
function ReuseExactMeasure(Job: THistoJob): Boolean;
begin
  Result := False;
  if not (Job.VAuto and Job.Full) then Exit;
  if frmViewTensors = nil then Exit;
  if not (frmViewTensors.FHistDetOk and
          (frmViewTensors.FHistDetS = Job.ElemStart) and
          (frmViewTensors.FHistDetE = Job.ElemEnd)) then Exit;
  Job.MeasLo := frmViewTensors.FHistVMinMan;
  Job.MeasHi := frmViewTensors.FHistVMaxMan;
  Job.MeasOk := ValidWindow(Job.MeasLo, Job.MeasHi);
  Job.ExactMeas := Job.MeasOk;
  Result := Job.MeasOk;                       // -> passe de mesure economisee
end;



{ ============================================================================
  8. APPLY (VCL thread) : rendu, axes, edits, statusbar, logs
============================================================================ }

// step-after : 2 points par bin (X NUMERIQUES = vraies bornes).  Garde SetMinMax
// et UndoZoom actifs (une TBarSeries + libelles ferait un axe ORDINAL muet).
procedure AddStepArray(S: TFastLineSeries; const H: THistogram; out Peak: Int64);
var
  g, j, n: Integer;
  Sum: Int64;
  x0: Double;
  Xs, Ys: array of Double;
begin
  Peak := 0;
  if (H.MaxBars <= 0) then Exit;
  n := H.MaxBars ;
  SetLength(Xs, n * 2);
  SetLength(Ys, n * 2);
  for g := 0 to n - 1 do
  begin
    Sum := 0;
    for j := g to Min(H.MaxBars - 1, g ) do
      Inc(Sum, H.Counts[j]);
    if Sum > Peak then Peak := Sum;
    x0 := H.VMin + g * H.BinW;
    Xs[2 * g] := x0;                Ys[2 * g] := Sum;
    Xs[2 * g + 1] := x0 + H.BinW; Ys[2 * g + 1] := Sum;
  end;
  S.AddArray(Xs, Ys);
end;

procedure AddBinsArray(S: TBarSeries; const H: THistogram; out Peak: Int64);
var
  g, j, n: Integer;
  Sum: Int64;
  W: Double;
  Xs, Ys: array of Double;
begin
  Peak := 0;
  if (H.MaxBars <= 0) then
    Exit;
  n := H.MaxBars;
  W := H.BinW;
  SetLength(Xs, n);
  SetLength(Ys, n);

  for g := 0 to n - 1 do
  begin
    Sum := H.Counts[g];
    if Sum > Peak then
      Peak := Sum;
    Xs[g] := H.VMin + (g + 0.5) * W;   // CENTRE : 1 barre = 1 marche
    Ys[g] := Sum;
  end;
  S.AddArray(Xs, Ys);
end;


procedure HistoApplyJob(Job: THistoJob);
var
  Chart: TChart;
  i, k: Integer;
  Sr: THistoSeries;
  //S: TFastLineSeries;
  S: TBarSeries;
  Discard: Boolean;
  PeakAll, ThisPeak: Int64;
begin
  if (frmViewTensors = nil) or (csDestroying in frmViewTensors.ComponentState) then
  begin
    Job.Free;
    Exit;
  end;
  Chart := frmViewTensors.Chart2;
  Discard := (Job.Gen <> frmViewTensors.FRenderGen) or
             (frmViewTensors.FCancelThread and (Job.Series.Count > 0));

  if Discard then
    LogT('[HIST] job gen=%d JETE (current=%d cancel=%s) %s',
      [Job.Gen, frmViewTensors.FRenderGen, sStrBool(frmViewTensors.FCancelThread),
       FormatDurationMs(Job.ElapsedMs)])
  else
    LogT('[HIST] applique gen=%d | %d series | W:[%.6g..%.6g] | MaxBars=%d  %s',//
      [Job.Gen, Job.Series.Count, Job.WMin, Job.WMax, Job.MaxBars,        //
       FormatDurationMs(Job.ElapsedMs)]);

  try
    if not Discard then
    begin
      try
        frmViewTensors.lvSeries.Items.BeginUpdate;
        try
          for i := 0 to frmViewTensors.lvSeries.Items.Count - 1 do
            if Assigned(frmViewTensors.lvSeries.Items[i].Data) then
              TLegendInfo(frmViewTensors.lvSeries.Items[i].Data).Free;
          frmViewTensors.lvSeries.Items.Clear;
          Chart.RemoveAllSeries;          // Clear DETACHE sans liberer -> fuite

          PeakAll := 0;
          for k := 0 to Job.Series.Count - 1 do
          begin
            Sr := Job.Series[k];
            if Sr.H.MaxBars <= 0 then Continue;
            if Sr.H.N = 0 then
            begin
              if LogIsOn(lvWarn) then
                LogW('[HIST] "%s": 0 valeur | %s W:[%s..%s] zone=[%d..%d] lus=%d' + //
                ' unitE=%d mesure=%s NaN:%d Inf:%d', [Sr.Title, ModeTag(Job, Sr),//
                 FormatFloat4f(Job.WMin), FormatFloat4f(Job.WMax), Job.ElemStart,//
                 Job.ElemEnd, Sr.H.ReadElems, Sr.H.UnitE, Sr.H.MeasureStr,    //
                  Sr.H.NNan, Sr.H.NInf]);
              Continue;
            end;

            //S := TFastLineSeries.Create(Chart);
            S := TBarSeries.Create(Chart);
            S.ParentChart := Chart;
            S.Title := Sr.Title;
            S.Marks.Visible := False;
            S.BarStyle := bsRectangle;
            S.BarWidthPercent := 50;
            //AddStepArray(S, Sr.H, ThisPeak);
            AddBinsArray(S, Sr.H, ThisPeak);
            if ThisPeak > PeakAll then PeakAll := ThisPeak;

            frmViewTensors.AddSeriesToListView(Sr.Title, S.SeriesColor);
          end;


          //cfg.HistVMinMan := Job.WMin;
          //cfg.HistVMaxMan := Job.WMax;

          frmViewTensors.FHistVMinMan := Job.MeasLo;
          frmViewTensors.FHistVMaxMan := Job.MeasHi;
          frmViewTensors.FHistDetOk := Job.MeasOk and Job.ExactMeas;  // seule une mesure exacte se rejoue
          frmViewTensors.FHistDetS := Job.ElemStart;
          frmViewTensors.FHistDetE := Job.ElemEnd;

          Chart.BottomAxis.Automatic := False;
          Chart.BottomAxis.SetMinMax(Job.WMin, Job.WMax);
          frmViewTensors.HistoShowWindow;   // edtWin* (applique) + edtVal* (mesure)

          // ---- AXE FREQUENCES ----
          Job.Peak := PeakAll;
          frmViewTensors.FHistPeak := PeakAll;
          frmViewTensors.HistoApplyCountsAxis;

          //if frmViewTensors.lblHistStat <> nil then
          //  frmViewTensors.lblHistStat.Caption := Format('sat %.1f%%  cov %s  +/-%.2f%%',
          //    [100 * Job.Sat, PctOf(Job.Sampled, Job.ZoneLen), Job.SeRelPct]);

          if Job.IsDiff then
          begin
          {  if Job.StatsValid then
              frmViewTensors.UpdateStatusBarDiffStats(Job.Stats, Job.ElapsedMs)
            else if (frmViewTensors.StatusBar1 <> nil) and
                    (frmViewTensors.StatusBar1.Panels.Count > 0) then
              frmViewTensors.StatusBar1.Panels[0].Text := Job.StatusText; }
          end
          else if (frmViewTensors.stBar1 <> nil) and
                  (frmViewTensors.stBar1.Panels.Count > 0) then
            ;//frmViewTensors.StatusBar1.Panels[0].Text := Job.StatusText;
        finally
          frmViewTensors.lvSeries.Items.EndUpdate;
        end;
      finally
        Chart.Invalidate;
      end;
    end;
  finally
    Job.Free;
    frmViewTensors.EndRender;    // FBusy=False, barres masquees, replay du pending
  end;
end;

{ ============================================================================
  9. CONSTRUCTION DU JOB (VCL thread ONLY : cfg + controles)
============================================================================ }

procedure FillJobFromUi(Job: THistoJob; HistModeFull: Boolean);
var
  i: Integer;
  Sel: TList;
  T1, T2, T0, TT: TGGUFTensorInfo;
  Sr: THistoSeries;
begin
  Sel := TList.Create;
  try
    DoUpDateGlobalStartEndIdx(HistModeFull, Sel);
    Job.Gen      := frmViewTensors.FRenderGen;
    Job.Full     := HistModeFull;
    Job.ElemStart := Max(0, frmViewTensors.FCurrentStartIdx);
    Job.ElemEnd   := frmViewTensors.FCurrentEndIdx;

    if cfg.HistMaxBars > 0 then
      Job.MaxBars := cfg.HistMaxBars
    else if frmViewTensors.Chart2.Width > 0 then
      Job.MaxBars := frmViewTensors.Chart2.Width div 2;   // ~1 barre / 2 px

    Job.MaxBars := ClampInt(Job.MaxBars, 4, 16384);

    Job.StatBins := ClampInt(cfg.TVNumBins, 32, 16384);
    Job.StatPts  := ClampInt(cfg.TVPtsPerBin, 8, 16384);

    Job.VAuto := frmViewTensors.chkVAuto.Checked;
    Job.NAuto := frmViewTensors.chkCntAuto.Checked;

    frmViewTensors.HistoCommitWindow;


    Job.WMin  := cfg.HistWMinMan;
    Job.WMax  := cfg.HistWMaxMan;

    Job.ImplLabel := frmViewTensors.cbUseImpl.Text;
    Job.RmseIdx   := frmViewTensors.cbRmseType.ItemIndex;
    Job.VFPScale  := cfg.VFP_Scale;

    if Sel.Count = 0 then
      Exit;

    Job.IsDiff := (Sel.Count = 2) and (cfg.chkT1sT2 or cfg.chkT1dT2);
    Job.IsSubMode := cfg.chkT1sT2;

    if Job.IsDiff then
    begin
      T1 := TGGUFTensorInfo(Sel[0]);
      T2 := TGGUFTensorInfo(Sel[1]);
      if (T1 = nil) or (T2 = nil) then Exit;
      if (T1.ByteSize = 0) or (T2.ByteSize = 0) then Exit;
      if T2.ByteSize > T1.ByteSize then      // T1 = reference (la plus grosse)
      begin
        T0 := T1; T1 := T2; T2 := T0;
      end;
      Sr := THistoSeries.Create;
      Sr.Src := T1.Clone; Sr.Title := GetFormatTensorNameList(T1);
      Sr.S := Job.ElemStart; Sr.E := Min(T1.TotElems - 1, Job.ElemEnd);
      Job.Series.Add(Sr);
      Sr := THistoSeries.Create;
      Sr.Src := T2.Clone; Sr.Title := GetFormatTensorNameList(T2);
      Sr.S := Job.ElemStart; Sr.E := Min(T2.TotElems - 1, Job.ElemEnd);
      Job.Series.Add(Sr);      // l'intersection est faite par le parcours
      Exit;
    end;

    for i := 0 to Sel.Count - 1 do
    begin
      TT := TGGUFTensorInfo(Sel[i]);
      if TT = nil then Continue;
      Sr := THistoSeries.Create;
      Sr.Src := TT.Clone; Sr.Title := GetFormatTensorNameList(TT);
      Sr.S := Job.ElemStart; Sr.E := Min(TT.TotElems - 1, Job.ElemEnd);
      if Sr.E >= Sr.S then Job.Series.Add(Sr) else Sr.Free;
    end;
  finally
    Sel.Free;
  end;
end;

procedure DoGenerateHistogram(HistModeFull: Boolean);
var
  Job: THistoJob;
  Started: Boolean;
begin
  Job := THistoJob.Create;
  Started := False;
  try
    try
      FillJobFromUi(Job, HistModeFull);
      if Job.Series.Count = 0 then
        Exit;

      if Job.IsDiff then
        frmViewTensors.FWorkTotal := 1     // passe jointe = 1 unite
      else
        frmViewTensors.FWorkTotal := Job.Series.Count;
      frmViewTensors.FWorkDone := 0;
      frmViewTensors.FLastUViewIUpdateTick := 0;

      LogT('[HIST] job gen=%d | %s | MaxBars=%d | fenetre=%s | stat=%dx%d' +   //
        ' | impl=%s rmse=%d | zone=[%d..%d] | series=%d', [Job.Gen, IfThen1(Job.Full, //
        'FULL', 'FAST'), Job.MaxBars, IfThen1(Job.VAuto, 'auto', Format('[%.6g..%.6g] imposee', //
        [Job.WMin, Job.WMax])), Job.StatBins, Job.StatPts, Job.ImplLabel, Job.RmseIdx, //
        Job.ElemStart, Job.ElemEnd, Job.Series.Count]);

      TThread.CreateAnonymousThread(
        procedure
        begin
          HistoWorker(Job);          // le job appartient desormais a l'ouvrier
        end).Start;
      Started := True;
    except
      on E: Exception do
      begin
        //frmViewTensors.EndRender;// le finally libère FBusy
        vLogMsg(mLang.gMsgFmt('FVT.ChartInitErr', [E.Message]), False, lvError);
        //Job.Free;
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

procedure GenerateHistogram(HistModeFull: Boolean = False);
begin
  if frmViewTensors = nil then
    Exit;
  // arbitrage grappe/histogramme + annulation : dans RequestRender (uViewTensors)
  if not frmViewTensors.RequestRender(RK_HISTO, frmViewTensors.FCurrentStartIdx, frmViewTensors.FCurrentEndIdx, False, HistModeFull) then
    Exit;
  try
    DoGenerateHistogram(HistModeFull);
  except
    on E: Exception do
    begin
      vLogMsg(mLang.gMsgFmt('FVT.HistInitErr', [E.Message]), False, lvError);
      frmViewTensors.EndRender;
    end;
  end;
end;

end.

