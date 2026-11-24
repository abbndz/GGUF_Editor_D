unit uFullDiffPipeline;

{ ============================================================================
  PIPELINE PARALLELE "passe FULL"  (histogramme Full + stats WRMSE exactes)
  ----------------------------------------------------------------------------
  OBJECTIF
    Calculer en UNE seule passe, en PARALLELE, les stats exactes
    (WRMSE / RMS / MAE / Mean / WRel + vrais Min/Max) et le binning
    d'histogramme, sur des tenseurs de 10..100 Go avec peu de RAM (ex 16 Go).

  ARCHITECTURE PRODUCTEUR / CONSOMMATEUR :
    - 1 thread PRODUCTEUR : lit SEQUENTIELLEMENT de grosses briques (~4 Mo
      par tenseur) via CreateFile + FILE_FLAG_SEQUENTIAL_SCAN.  Il ne lit que
      des OCTETS BRUTS (aucune dequantification) : comportement optimal HDD
      comme SSD, et AUCUN "storm" de page faults mmap.
    - N thread WORKERS : Dequant (+ Quant/ReDequant si simulation) + scale
      NVFP4 + bins + TDiffAcc.  C'est la quantification Pascal (ex IQ4_NL)
      qui dominait le temps -> repartie sur les coeurs = gain ~lineaire.
    - FILE BORNEE (backpressure) : le producteur attend si toutes les briques
      sont en vol.  Memoire <= QueueCapacity * nspe * ChunkBytes, independante
      de la taille du fichier.
    - REDUCTION :
        * bins : ENTIERES, somme par worker a la fin = exacte, independante
          de l'ordre ;
        * TDiffAcc : un accumulateur PAR BRIQUE dans un tableau indexe par
          numero de brique (croissant), fusionnes dans cet ordre =
          BIT-DETERMINISTE.

  ANNULATION / PROGRESSION
  - Drapeau FCancel + callback FCancelFn verifie par le producteur et les
    workers ; progression throttlee a 1 appel par changement de pourcentage.
  - NE PAS confondre avec TTensorReader : ce pipeline a son propre producteur
    stream (CreateFile+SEQ_SCAN) et ses propres buffers.
============================================================================ }

interface

uses
  System.SysUtils, System.SyncObjs, System.Threading, System.Classes,
  uGGUFModel, uGGMLTypes, uDiffStats,uLog, uMath;

type
  // ------------------------------------------------------------------
  // TFullSpec : specification de lecture + dequant/sim d'UN tenseur
  // ------------------------------------------------------------------
  TFullSpec = record
    TypeOrg, TypeTgt: Integer;   // type reellement lu / type simule cible
    SrcE, SrcBy: Int64;          // QK et octets du bloc SOURCE
    DstE, DstBy: Int64;          // QK et octets du bloc DESTINATION (si sim)
    PPC: Int64;                  // LCM(SrcE,DstE) : bloc commun minimal
    DoSim: Boolean;              // True = Quant + ReDequant (simulation IsConverted)
    UseDLL: Boolean;             // route par ggml-base.dll si dispo
    UseImpl, RmseType: Integer;  // profils de quantisation
    ApplyScale: Boolean;         // True si TypeTgt = NVFP4
    OutScale: Single;            // echelle appliquee apres dequant/sim
    Base: Int64;                 // offset des donnees dans le fichier
    Path: string;                // fichier reellement lu (transpose si present)
    TotElems: Int64;             // nb d'elements du tenseur
    /// True si la spec est exploitable par le moteur
    function Valid: Boolean;
  end;

  TArrofSingle = array of Single;


  // ------------------------------------------------------------------
  // TFullSeriesAgg : bins + compteurs + vrais min/max d'UNE serie
  // ------------------------------------------------------------------
  TFullSeriesAgg = record
    Counts: array of Int64;      // effectifs par bin (entiers, somme exacte)
    NNan, NInf: Int64;
    MinV, MaxV: Double;          // vrais min/max NON clampes (remontent du scan)
    procedure Init(MaxBars: Integer);
    /// Somme Other dans Self (bins + compteurs + min/max)
    procedure AddFrom(const Other: TFullSeriesAgg);
  end;

  // ------------------------------------------------------------------
  // TFullDiffResult : resultat complet d'une passe
  // ------------------------------------------------------------------
  TFullDiffResult = record
    Series: array of TFullSeriesAgg;  // 1 (simple) ou 2 (diff)
    Acc: TDiffAcc;                     // stats de difference (si ComputeAcc)
    procedure Init(NSeries, ABins: Integer);
  end;

  // ------------------------------------------------------------------
  // TFullDiffParams : parametres d'execution
  // ------------------------------------------------------------------
  TFullDiffParams = record
    Specs: array of TFullSpec;         // 1 ou 2 tenseurs
    StartElem, TotalElems: Int64;      // 1er element a lire (0 = debut) ; TotalElems = NOMBRE
    MaxBars: Integer;
    WinMin, WinMax, BinW: Double;      // fenetre de binning (estimee ou fixe)
    MakeBins: Boolean;                 // calculer les effectifs
    ComputeAcc: Boolean;               // calculer TDiffAcc (WRMSE...)
    SubMode: Boolean;                  // Acc : V1-V2 sinon ratio V1/V2
    WT: TDiffWeights;                  // Acc : ponderation
    ChunkBytes: Integer;               // cible octets lus / brique / tenseur
    QueueCapacity: Integer;            // briques en vol (backpressure)
    Workers: Integer;                  // nb de threads consommateurs
  end;

  TOnProgressFull = reference to procedure(ADone, ATotal: Int64; APct: Integer);
  TOnCancelFull   = reference to function: Boolean;

/// Construit une spec a partir d'un TGGUFTensorInfo (mmes regles que TTensorReader)
function MakeFullSpec(T: TGGUFTensorInfo; AScale: Single = 1.0): TFullSpec;

/// Passe FULL parallele (bloque jusqu'a la fin).
/// Erreur I/O ou worker -> exception levee dans le thread appelant.
function RunFullDiffParallel(const P: TFullDiffParams;
  OnProgress: TOnProgressFull = nil;
  OnCancel: TOnCancelFull = nil): TFullDiffResult;

const
  CMIN_CHUNK_ELEMS = 1024;              // brique minimale (elements)
  CMAX_CHUNK_ELEMS = 4 * 1024 * 1024;   // brique maximale (elements)

var
  /// Taille de brique cible en OCTETS BRUTS / tenseur. 4 Mo = bon compromis :
  /// grosses lectures sequentielles (HDD/SSD) et memoire bornee.
  GFullChunkBytes: Integer = 4 * 1024 * 1024;
  /// Nombre de briques en vol (backpressure).
  /// Memoire ~ QueueCapacity * nbSpecs * GFullChunkBytes (ex : 4*2*4Mo = 32 Mo).
  GFullQueueCap: Integer = 4;

implementation

uses
  Winapi.Windows,      // CreateFile / ReadFile / SetFilePointerEx / GetFileSizeEx
  uGGMLConstants,      // GGML_TYPE_NVFP4
  uGgmlQuants;         // Dequant / Quant


{ ============================================================================
  TFullSpec / TFullSeriesAgg / TFullDiffResult
============================================================================ }

function TFullSpec.Valid: Boolean;
begin
  Result := (Path <> '') and (SrcE > 0) and (SrcBy > 0) and (PPC > 0) and
            (TotElems > 0) and ((not DoSim) or (DstE > 0) or (DstBy <= 0));
end;

procedure TFullSeriesAgg.Init(MaxBars: Integer);
begin
  SetLength(Counts, MaxBars);
  if MaxBars > 0 then
    FillChar(Counts[0], MaxBars * SizeOf(Int64), 0);
  NNan := 0;
  NInf := 0;
  MinV := MaxDouble;
  MaxV := -MaxDouble;
end;

procedure TFullSeriesAgg.AddFrom(const Other: TFullSeriesAgg);
var
  i: Integer;
begin
  NNan := NNan + Other.NNan;
  NInf := NInf + Other.NInf;
  if Other.MinV < MinV then MinV := Other.MinV;
  if Other.MaxV > MaxV then MaxV := Other.MaxV;
  if Length(Counts) <> Length(Other.Counts) then Exit;
  for i := 0 to High(Counts) do
    Counts[i] := Counts[i] + Other.Counts[i];   // somme entiere : exacte
end;

procedure TFullDiffResult.Init(NSeries, ABins: Integer);
var
  s: Integer;
begin
  SetLength(Series, NSeries);
  for s := 0 to NSeries - 1 do
    Series[s].Init(ABins);
  Acc.Reset;
end;

{ ============================================================================
  MakeFullSpec
============================================================================ }

function MakeFullSpec(T: TGGUFTensorInfo; AScale: Single = 1.0): TFullSpec;
begin
  // PAS de FillChar : le record contient des champs ger string/dyn array.
  Result.TypeOrg := 0;
  Result.TypeTgt := 0;
  Result.SrcE := 0;
  Result.SrcBy := 0;
  Result.DstE := 1;
  Result.DstBy := 0;
  Result.PPC := 0;
  Result.DoSim := False;
  Result.UseDLL := False;
  Result.UseImpl := 0;
  Result.RmseType := 0;
  Result.ApplyScale := AScale <> 1.0;
  Result.OutScale := 1.0;
  Result.Base := 0;
  Result.Path := '';
  Result.TotElems := 0;
  if T = nil then Exit;

  Result.TypeOrg := Integer(T.TensorTypeOrg);
  Result.DoSim   := T.IsConverted;
  if Result.DoSim then
    Result.TypeTgt := Integer(T.TensorType)
  else
    Result.TypeTgt := Result.TypeOrg;
  Result.UseImpl  := T.UseImpl;
  Result.RmseType := T.RmseType;
  Result.UseDLL   := (Result.UseImpl = 0) or (Result.UseImpl = 2);

  if GGML_TypeIsQuant(Result.TypeOrg) then
  begin
    Result.SrcE := GGML_BlockElems(Result.TypeOrg);
    Result.SrcBy := GGML_BlockBytes(Result.TypeOrg);
  end
  else
  begin
    Result.SrcE := 1;                       // scalaire : pas d'aliasing de bloc
    Result.SrcBy := GGML_BlockBytes(Result.TypeOrg);
  end;

  if Result.DoSim then
  begin
    if GGML_TypeIsQuant(Result.TypeTgt) then
    begin
      Result.DstE := GGML_BlockElems(Result.TypeTgt);
      Result.DstBy := GGML_BlockBytes(Result.TypeTgt);
    end
    else
    begin
      Result.DstE := 1;
      Result.DstBy := GGML_BlockBytes(Result.TypeTgt);
    end;
  end
  else
  begin
    Result.DstE := 1;
    Result.DstBy := 0;
  end;

  if (Result.SrcE <= 0) or (Result.DstE <= 0) or (Result.SrcBy <= 0) then Exit;

  Result.PPC := Lcm64(Result.SrcE, Result.DstE);
  if Result.PPC <= 0 then Exit;

  Result.ApplyScale := (Result.TypeTgt = GGML_TYPE_NVFP4) and (AScale <> 1.0);
  Result.OutScale := AScale;
  Result.TotElems := T.TotElems;
  Result.Base := T.TensorDataFilePos + T.SourceOffset;
  Result.Path := T.SourceFile;
  if T.IsTransposed and (T.TransposFile <> '') and FileExists(T.TransposFile) then
  begin
    Result.Path := T.TransposFile;
    Result.Base := 0;                       // dump transpose = fichier brut
  end;
end;

{ ============================================================================
  TFullChunk : une brique de la file (octets bruts + resultat local)
============================================================================ }

type
  TFullChunk = class
  public
    Seq: Integer;           // numero de brique (ordre croissant de production)
    IdxStart: Int64;        // index du 1er element de la brique
    NElem: Int64;           // elements valides de la brique
    Raw1: TBytes;           // octets bruts T1
    Raw2: TBytes;           // octets bruts T2 (mode diff)
  end;

  { ------------------------------------------------------------------
    TFullQueue : file bornee producteur/consommateur (moniteur)
    - GetFree : attend une brique libre (ou Stop -> nil)
    - PutReady / TakeReady : producteur -> workers
    - PutFree : recycle une brique
    Predicat re-evalue en boucle + WaitFor(timeout) : pas de race event.
  ------------------------------------------------------------------ }
  TFullQueue = class
  private
    FLock: TCriticalSection;
    FOnReady: TEvent;       // ManualReset : au moins une brique prete
    FOnFree: TEvent;        // ManualReset : au moins une brique libre
    FFree: TList;           // briques disponibles
    FReady: TList;          // briques remplies en attente de consommation
    FStop: Boolean;
  public
    constructor Create;
    destructor Destroy; override;
    function GetFree: TFullChunk;
    procedure PushFree(C: TFullChunk);
    procedure PutReady(C: TFullChunk);
    function TakeReady: TFullChunk;   // nil = Stop et plus rien a consommer
    procedure Stop;
  end;

  { ============================================================================
  TWorkerAgg : agregats locaux d'UN worker (publies a sa sortie)
============================================================================ }

  TWorkerAgg = class
  public
    S: array of TFullSeriesAgg;   // 1 par tenseur (bins + compteurs + min/max)
  end;

{ ============================================================================
  TFullDiffEngine : moteur producteur/consommateur
============================================================================ }

  TFullDiffEngine = class
  private
    FP: TFullDiffParams;
    FQ: TFullQueue;
    FAccSeq: array of TDiffAcc;     // 1 Acc par brique, reduction deterministe
    FWorkerResults: TList;          // liste de TWorkerAgg
    FWorkerAgg: TCriticalSection;   // protege FWorkerResults / FDone / FErr
    FDone: Int64;
    FTotal: Int64;
    FLastPct: Integer;
    FSeqCounter: Integer;
    FCancel: Integer;               // 0/1 via InterlockedExchange
    FChunkElems: Int64;             // elements par brique (multiple du PPC global)
    FGlobalPPC: Int64;
    FProgress: TOnProgressFull;
    FCancelFn: TOnCancelFull;
    function Cancelled: Boolean;
    procedure ReportChunk(NElem: Int64);
    function ReadBlockSeq(h: THandle; off: Int64; buf: PByte; cnt: Int64): Boolean;
    procedure Producer;
    procedure Worker;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Cancel;
    //function Execute: TFullDiffResult;
    procedure DoDequant(C: TFullChunk; n: Int64; out f1, f2: TArrofSingle);
  end;

constructor TFullQueue.Create;
begin
  FLock := TCriticalSection.Create;
  FOnReady := TEvent.Create(nil, True, False, '');
  FOnFree := TEvent.Create(nil, True, True, '');
  FFree := TList.Create;
  FReady := TList.Create;
  FStop := False;
end;

destructor TFullQueue.Destroy;
var
  C: TObject;
begin
  //while FFree.Count > 0 do TObject(FFree.Delete(FFree.Count - 1)).Free;
  //while FReady.Count > 0 do TObject(FReady.Delete(FReady.Count - 1)).Free;
  // Extract renvoie bien l'objet retire (Delete renvoie un Boolean)
  while FFree.Count > 0 do
  begin
    C := TObject(FFree[FFree.Count - 1]);
    FFree.Delete(FFree.Count - 1);
    C.Free;
  end;
  while FReady.Count > 0 do
  begin
    C := TObject(FReady[FReady.Count - 1]);
    FReady.Delete(FReady.Count - 1);
    C.Free;
  end;
  FFree.Free;
  FReady.Free;
  FOnReady.Free;
  FOnFree.Free;
  FLock.Free;
end;

function TFullQueue.GetFree: TFullChunk;
begin
  Result := nil;
  while True do
  begin
    FLock.Enter;
    try
      if FStop then Exit;
      if FFree.Count > 0 then
      begin
        Result := TFullChunk(FFree[FFree.Count - 1]);
        FFree.Delete(FFree.Count - 1);
        if FFree.Count = 0 then
          FOnFree.ResetEvent;
        Exit;
      end;
    finally
      FLock.Leave;
    end;
    FOnFree.WaitFor(INFINITE); // 50
  end;
end;



procedure TFullQueue.PushFree(C: TFullChunk);
begin
  FLock.Enter;
  try
    FFree.Add(C);
    FOnFree.SetEvent;
  finally
    FLock.Leave;
  end;
end;

procedure TFullQueue.PutReady(C: TFullChunk);
begin
  FLock.Enter;
  try
    if FStop then
    begin
      // fin demandee : on recycle immediatement, on ne produit plus
      FFree.Add(C);
      FOnFree.SetEvent;
    end
    else
    begin
      FReady.Add(C);
      FOnReady.SetEvent;
    end;
  finally
    FLock.Leave;
  end;
end;

function TFullQueue.TakeReady: TFullChunk;
begin
  Result := nil;
  while True do
  begin
    FLock.Enter;
    try
      if FReady.Count > 0 then
      begin
        // on DRAINNE les briques pretes meme apres Stop (donnees valides)
        Result := TFullChunk(FReady[FReady.Count - 1]);
        FReady.Delete(FReady.Count - 1);
        if FReady.Count = 0 then
          FOnReady.ResetEvent;
        Exit;
      end;
      if FStop then Exit;
    finally
      FLock.Leave;
    end;
    FOnReady.WaitFor(INFINITE);  // 50
  end;
end;


procedure TFullQueue.Stop;
begin
  FLock.Enter;
  try
    FStop := True;
    FOnReady.SetEvent;
    FOnFree.SetEvent;
  finally
    FLock.Leave;
  end;
end;

constructor TFullDiffEngine.Create;
begin
  FQ := TFullQueue.Create;
  FWorkerAgg := TCriticalSection.Create;
  FWorkerResults := TList.Create;   // possede des TWorkerAgg
  FDone := 0;
  FTotal := 0;
  FLastPct := -1;
  FSeqCounter := 0;
  FCancel := 0;
  FChunkElems := 0;
  FGlobalPPC := 0;
end;

destructor TFullDiffEngine.Destroy;
var
  i: Integer;
begin
  // Ordre STRICT inverse de la creation.
  // 1) les agregats publies par les workers (la liste LES POSSIEDE)
  if FWorkerResults <> nil then
  begin
    for i := 0 to FWorkerResults.Count - 1 do
      TObject(FWorkerResults[i]).Free;
    FWorkerResults.Free;
    FWorkerResults := nil;
  end;
  // 2) le verrou
  if FWorkerAgg <> nil then
  begin
    FWorkerAgg.Free;
    FWorkerAgg := nil;
  end;
  // 3) la file : TFullQueue.Destroy libere lui-meme toutes ses briques
  //    (FFree + FReady) -> ne surtout pas liberer les TFullChunk ici.
  if FQ <> nil then
  begin
    FQ.Stop;      // reveille d'eventuels threads encore bloques (assurance)
    FQ.Free;
    FQ := nil;
  end;
  inherited;
end;

procedure TFullDiffEngine.Cancel;
begin
  InterlockedExchange(FCancel, 1);
  FQ.Stop;
end;

function TFullDiffEngine.Cancelled: Boolean;
begin
  if FCancel <> 0 then
    Exit(True);
  if Assigned(FCancelFn) then
    Result := FCancelFn
  else
    Result := False;
end;

// Progression throttlee : 1 callback par valeur de pourcentage (une seule fois).
procedure TFullDiffEngine.ReportChunk(NElem: Int64);
var
  pct: Integer;
begin
  FWorkerAgg.Enter;
  try
    Inc(FDone, NElem);
    if not Assigned(FProgress) or (FTotal <= 0) then Exit;
    pct := Round(FDone * 100.0 / FTotal);
    if pct > 100 then pct := 100;
    if pct <> FLastPct then
    begin
      FLastPct := pct;
      FProgress(FDone, FTotal, pct);
    end;
  finally
    FWorkerAgg.Leave;
  end;
end;

// Lecture sequentielle robuste : relit si ReadFile renvoie partiel.
function TFullDiffEngine.ReadBlockSeq(h: THandle; off: Int64; buf: PByte;
  cnt: Int64): Boolean;
var
  got, total: DWORD;
begin
  Result := False;
  if cnt <= 0 then
    Exit(True);
  if cnt > $7FFFFFF0 then
    Exit; // taille irrealiste pour un bloc
  if not SetFilePointerEx(h, off, nil, FILE_BEGIN) then
    Exit;
  total := 0;
  while total < DWORD(cnt) do
  begin
    if not ReadFile(h, buf[total], DWORD(cnt) - total, got, nil) then
      Exit;
    if got = 0 then
      Break; // EOF
    Inc(total, got);
  end;
  Result := (Int64(total) = cnt);
end;

// PRODUCTEUR : lit les octets bruts, ne calcule RIEN.
procedure TFullDiffEngine.Producer;
var
  ns, i: Integer;
  h: array[0..1] of THandle;
  fs: array[0..1] of Int64;
  pos, want, n: Int64;
  C: TFullChunk;
  sp: TFullSpec;
  off, avail, availE,availT, rb: Int64;
  lim: Integer; limOff, limAvail, limTot: Int64;
  okAll: Boolean;
  sErr : string;
begin
  ns := Length(FP.Specs);
  if (ns < 1) or (ns > 2) then
  begin
    sErr := 'TFullDiffEngine.Producer : 1 ou 2 specs attendues';
    LogE(sErr);
    //raise Exception.Create(sErr);
    FQ.Stop;
    Exit;
  end;

  h[0] := 0;
  h[1] := 0;
  fs[0] := 0;
  fs[1] := 0;
  for i := 0 to ns - 1 do
  begin
    h[i] := CreateFile(PChar(FP.Specs[i].Path), GENERIC_READ, FILE_SHARE_READ, nil,
      OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL or FILE_FLAG_SEQUENTIAL_SCAN, 0);
    if h[i] = INVALID_HANDLE_VALUE then
      h[i] := 0;
    if h[i] <> 0 then
      GetFileSizeEx(h[i], fs[i]);
  end;

  try
    if (h[0] = 0) or ((ns = 2) and (h[1] = 0)) then
    begin
      sErr := 'TFullDiffEngine.Producer : ouverture impossible ' + SysErrorMessage(GetLastError);
      LogE(sErr);
    //raise Exception.Create(sErr);
      Exit;
    end;

    pos := FP.StartElem;
    while pos < FP.StartElem + FTotal do
    begin
      if Cancelled then
      begin
        LogW('TFullDiffEngine.Producer : annulation');
        Break;
      end;

      C := FQ.GetFree;
      if C = nil then Break; // Stop

      // taille demandee, pas plus que ce qu'il reste
      // FTotal est une LONGUEUR, pos un index absolu : la fin est StartElem+FTotal
      want := Min(FChunkElems, (FP.StartElem + FTotal) - pos);

      // on limite aux octets reellement disponibles dans CHAQUE fichier
      // on limite aux octets ET aux elements reellement disponibles dans CHAQUE spec
      n := want;
      lim := 0; limOff := 0; limAvail := 0; limTot := 0;
      for i := 0 to ns - 1 do
      begin
        sp := FP.Specs[i];
        off   := sp.Base + (pos div sp.SrcE) * sp.SrcBy;
        avail := fs[i] - off;
        if avail <= 0 then availE := 0
        else availE := (avail div sp.SrcBy) * sp.SrcE;
        availT := sp.TotElems - pos;              // ★ ne JAMAIS deborder du tenseur :
        if availE > availT then availE := availT; //   sinon on binne le TENSEUR VOISIN
        if availE < n then
        begin
          n := availE; lim := i;
          limOff := off; limAvail := avail; limTot := availT;
        end;
      end;

      n := (n div FGlobalPPC) * FGlobalPPC;
      if n <= 0 then
      begin
        LogW('RunFullDiffParallel: spec#%d: 0 bloc exploitable a l''elem %d | demande=%d fs=%d off=%d' //
          + ' availOct=%d availElem=%d PPC=%d', //
          [lim, pos, want, fs[lim], limOff, limAvail, limTot, FGlobalPPC]);
        FQ.PushFree(C);
        Break;
      end;

      // lecture brute des ns fichiers pour cette brique
      okAll := True;
      for i := 0 to ns - 1 do
      begin
        sp := FP.Specs[i];
        rb := (n div sp.SrcE) * sp.SrcBy;
        off := sp.Base + (pos div sp.SrcE) * sp.SrcBy;
        if i = 0 then
        begin
          if Int64(Length(C.Raw1)) < rb then okAll := False
          else if not ReadBlockSeq(h[i], off, @C.Raw1[0], rb) then okAll := False;
        end
        else
        begin
          if Int64(Length(C.Raw2)) < rb then okAll := False
          else if not ReadBlockSeq(h[i], off, @C.Raw2[0], rb) then okAll := False;
        end;
      end;

      if not okAll then
      begin
        LogW('RunFullDiffParallel: lecture courte a l''elem %d (rb=%d off=%d)', [pos, rb, off]);
        FQ.PushFree(C);
        Break;
      end;

      C.IdxStart := pos;
      C.NElem := n;
      C.Seq := InterlockedIncrement(FSeqCounter) - 1;
      FQ.PutReady(C);

      Inc(pos, n);
    end;
  finally
    if h[0] <> 0 then CloseHandle(h[0]);
    if h[1] <> 0 then CloseHandle(h[1]);
    FQ.Stop; // reveille les workers : fin normale ou annulee
  end;
end;

procedure TFullDiffEngine.Worker;
var
  WA: TWorkerAgg;
  C: TFullChunk;
  ns, i, s, series: Integer;
  n: Int64;
  f1, f2: TArrOfSingle;
  a: TDiffAcc;
  v: Single;
  bi: Integer;
begin
  ns := Length(FP.Specs);
  WA := TWorkerAgg.Create;
  SetLength(WA.S, ns);
  for s := 0 to ns - 1 do
    if FP.MakeBins then WA.S[s].Init(FP.MaxBars);

  try
    while True do
    begin
      C := FQ.TakeReady;
      if C = nil then Break;
      try
        if not Cancelled then
        begin
          n := C.NElem;
          if (n > 0) and (n <= FChunkElems) then
          begin
            DoDequant(C, n, f1, f2);

            if FP.MakeBins then
              for series := 0 to ns - 1 do
              begin
                for i := 0 to n - 1 do
                begin
                  if series = 0 then v := f1[i] else v := f2[i];
                  if IsNaN(v) then Inc(WA.S[series].NNan)
                  else if IsInfinite(v) then Inc(WA.S[series].NInf)
                  else
                  begin
                    if v < WA.S[series].MinV then WA.S[series].MinV := v;
                    if v > WA.S[series].MaxV then WA.S[series].MaxV := v;
                    bi := Trunc((v - FP.WinMin) / FP.BinW);
                    if bi < 0 then
                    begin
                      bi := 0 ;
                    end
                    else if bi >= FP.MaxBars then
                    begin
                      bi := FP.MaxBars - 1;
                    end;
                    if bi >= 0 then Inc(WA.S[series].Counts[bi]);
                  end;
                end;
              end;

            if FP.ComputeAcc then
            begin
              a.Reset;
              for i := 0 to n - 1 do
                a.Add(f1[i], f2[i], C.IdxStart + i, FP.SubMode, FP.WT);
              if (C.Seq >= 0) and (C.Seq < Length(FAccSeq)) then
                FAccSeq[C.Seq] := a;
            end;
          end;
          ReportChunk(n);
        end;
      except
        on E: Exception do
        begin
          LogE(E.Message);
          //raise Exception.Create(sErr);
          InterlockedExchange(FCancel, 1);
        end;
      end;
      FQ.PushFree(C);
    end;
  finally
    FWorkerAgg.Enter;
    try FWorkerResults.Add(WA) finally FWorkerAgg.Leave; end;
  end;
end;

// Dequant + (sim) + scale pour une brique ; f1/f2 dimensionnes a n.
// Les buffers q1/q2 sont thread-local statiques (recycles a chaque brique).
procedure TFullDiffEngine.DoDequant(C: TFullChunk; n: Int64;
  out f1, f2: TArrofSingle);
var
  s0, s1: TFullSpec;
  ns, i: Integer;
  sc: Single;
  q1, q2: TBytes;
begin
  ns := Length(FP.Specs);
  s0 := FP.Specs[0];
  if ns = 2 then s1 := FP.Specs[1] else s1 := s0;

  SetLength(f1, n);
  SetLength(f2, n);
  if s0.DoSim then
    SetLength(q1, ((n div Max(1, s0.DstE)) + 1) * Max(1, s0.DstBy))
  else
    SetLength(q1, 1);
  if s1.DoSim then
    SetLength(q2, ((n div Max(1, s1.DstE)) + 1) * Max(1, s1.DstBy))
  else
    SetLength(q2, 1);

  // T1
  Dequant(@C.Raw1[0], @f1[0], Integer(n), s0.TypeOrg, s0.UseDLL);
  if s0.DoSim then
  begin
    Quant(@f1[0], @q1[0], Integer(n), s0.TypeTgt, s0.UseImpl, s0.RmseType);
    Dequant(@q1[0], @f1[0], Integer(n), s0.TypeTgt, s0.UseDLL);
  end;
  if s0.ApplyScale and (s0.OutScale <> 1.0) then
  begin
    sc := s0.OutScale;
    for i := 0 to n - 1 do
      f1[i] := f1[i] * sc;
  end;

  // T2 (diff)
  if ns = 2 then
  begin
    Dequant(@C.Raw2[0], @f2[0], Integer(n), s1.TypeOrg, s1.UseDLL);
    if s1.DoSim then
    begin
      Quant(@f2[0], @q2[0], Integer(n), s1.TypeTgt, s1.UseImpl, s1.RmseType);
      Dequant(@q2[0], @f2[0], Integer(n), s1.TypeTgt, s1.UseDLL);
    end;
    if s1.ApplyScale and (s1.OutScale <> 1.0) then
    begin
      sc := s1.OutScale;
      for i := 0 to n - 1 do
        f2[i] := f2[i] * sc;
    end;
  end
  else
    Move(f1[0], f2[0], n * SizeOf(Single));
end;

{ ============================================================================
  Point d'entree public
============================================================================ }
function RunFullDiffParallel(const P: TFullDiffParams;
  OnProgress: TOnProgressFull = nil;
  OnCancel: TOnCancelFull = nil): TFullDiffResult;
var
  E: TFullDiffEngine;
  C: TFullChunk;
  i, W, k: Integer;
  gppc: Int64;
  maxBPE: Double;
  m0, m1: Int64;
  alignedStart: Int64;
  ws: array of ITask;
  prod: ITask;
  acc: TDiffAcc;
  WA: TWorkerAgg;
begin
  Result.Init(Length(P.Specs), P.MaxBars);
  if (Length(P.Specs) < 1) or (Length(P.Specs) > 2) then
    raise Exception.Create('RunFullDiffParallel: 1 ou 2 specs attendues');
  for i := 0 to High(P.Specs) do
    if not P.Specs[i].Valid then
      raise Exception.Create('RunFullDiffParallel: spec invalide #' + IntToStr(i));

  E := TFullDiffEngine.Create;      // create possede deja FQ / FWorkerAgg / FWorkerResults
  try
    gppc := 1;
    for i := 0 to High(P.Specs) do gppc := Lcm64(gppc, P.Specs[i].PPC);
    if gppc <= 0 then
      raise Exception.Create('RunFullDiffParallel: PPC invalide');

    // octets bruts par element lu (le plus glouton des specs) -> taille de brique
    maxBPE := 1.0;
    for i := 0 to High(P.Specs) do
      if (P.Specs[i].SrcE > 0) and (P.Specs[i].SrcBy > 0) and
         ((P.Specs[i].SrcBy / P.Specs[i].SrcE) > maxBPE) then
        maxBPE := P.Specs[i].SrcBy / P.Specs[i].SrcE;

    alignedStart := (P.StartElem div gppc) * gppc;

    E.FP := P;
    E.FP.StartElem := alignedStart;
    E.FGlobalPPC   := gppc;
    E.FProgress    := OnProgress;
    E.FCancelFn    := OnCancel;
    E.FDone := 0; E.FLastPct := -1; E.FSeqCounter := 0;

    E.FChunkElems := Trunc(P.ChunkBytes / maxBPE);
    if E.FChunkElems < CMIN_CHUNK_ELEMS then E.FChunkElems := CMIN_CHUNK_ELEMS;
    if E.FChunkElems > CMAX_CHUNK_ELEMS then E.FChunkElems := CMAX_CHUNK_ELEMS;
    E.FChunkElems := AlignUpI64(E.FChunkElems, gppc);
    // FTotal = LONGUEUR reellement lue (zone + tete d'alignement)
    E.FTotal := P.TotalElems + (P.StartElem - alignedStart);
    if E.FChunkElems > E.FTotal then E.FChunkElems := AlignUpI64(E.FTotal, gppc);

    // --- pre-allocation des briques DANS la file existante ---
    for i := 0 to P.QueueCapacity - 1 do
    begin
      C := TFullChunk.Create;
      m0 := (E.FChunkElems div P.Specs[0].SrcE) * P.Specs[0].SrcBy;
      SetLength(C.Raw1, m0);
      if Length(P.Specs) = 2 then
      begin
        m1 := (E.FChunkElems div P.Specs[1].SrcE) * P.Specs[1].SrcBy;
        SetLength(C.Raw2, m1);
      end;
      E.FQ.PushFree(C);             // methode publique (pas E.FQ.FFree)
    end;

    if P.ComputeAcc then
      SetLength(E.FAccSeq, (P.TotalElems div Max(1, E.FChunkElems)) + 2);

    // --- threads ---
    W := P.Workers;
    if W < 1 then W := 1;
    SetLength(ws, W);
    for i := 0 to W - 1 do
      ws[i] := TTask.Run(E.Worker);
    prod := TTask.Run(E.Producer);

    try
      TTask.WaitForAll(ws);
      prod.Wait;
    except
      E.Cancel;        // un thread a leve : on arrete tout avant de reduire
      raise;
    end;

    if (E.FDone = 0) and (Length(P.Specs) > 0) then
      LogW('[FULL] producteur arrete: lus=%d/%d elems | %d briques',  //
        [E.FDone, E.FTotal, E.FSeqCounter]);
    if (E.FDone = 0) and (Length(P.Specs) > 0) then
      LogW('[FULL] AUCUN element traite sur [%d..%d] (annulation ? fichier absent ?)',
        [P.StartElem, P.StartElem + P.TotalElems - 1]);

    // --- reduction des bins (entiers, exacte) ---
    if P.MakeBins then
      for k := 0 to E.FWorkerResults.Count - 1 do
      begin
        WA := TWorkerAgg(E.FWorkerResults[k]);
        for i := 0 to High(P.Specs) do
          if (i < Length(WA.S)) and
             (Length(WA.S[i].Counts) = Length(Result.Series[i].Counts)) then
            Result.Series[i].AddFrom(WA.S[i]);
      end;

    // --- reduction des Acc dans l'ordre des briques (deterministe) ---
    if P.ComputeAcc then
    begin
      acc.Reset;
      for i := 0 to High(E.FAccSeq) do
        acc.Merge(E.FAccSeq[i]);
      Result.Acc := acc;
    end;
  finally
    // UNIQUEMENT E.Free : Destroy libere FWorkerResults, FWorkerAgg, FQ.
    E.Free;
  end;
end;

end.

