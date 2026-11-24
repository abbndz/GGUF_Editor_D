unit uTensorStreamReader;

{ LECTEUR / DEQUANTIFICATEUR PARTAGE  (graphe + histogramme + batch futurs)
  ----------------------------------------------------------------------------
  ROLE
    TTensorReader : ouvre le bon fichier (transposé ou natif), aligne les blocs
      source/cible sur leur PPC (plus petit commun multiple des QK), lit BLOC
      par BLOC avec CACHE, et fournit des valeurs F32 deja simulees
      (Quant + Dequant si IsConverted).
      Ne leve JAMAIS : Ok = False + ErrText.  Aucune VCL, aucun cfg.

   BACKEND DE LECTURE (3 modes, cfg.IOReaderMode -> GReaderMode)
    ioAuto   : mmap si taille(fichier) <= GMmapCapBytes, sinon stream sequentiel.
    ioMmap   : mmap FORCE. Fallback stream + LogW si la creation de la vue
               echoue ou si la taille depasse le plafond (page-fault storm).
    ioStream : stream CreateFile + FILE_FLAG_SEQUENTIAL_SCAN dans tous les cas.
    GMmapCapBytes : RAM physique / 4 (plancher 64 Mo), calcule UNE fois par
               InitMmapCapBytes (l'UI peut imposer un plafond en Mo).
    POURQUOI le plafond : mapper en vue complete un fichier > RAM physique
      produit un page-fault storm (1 fault / 4 Ko touches) : working set non
      borne, cache systeme en thrash. En stream, le working set est constant et
      le read-ahead est batche par Windows.
    Le LOD (TWalkPlan) etant MONOTONE, le stream le sert aussi bien que le mmap :
      seul du vrai random-access non monotone beneficierait d'un mmap fenetre.
    NB : la passe FULL du pipeline (uFullDiffPipeline) a SON PROPRE producteur
      stream ; ce reader ne sert que le graphe et le FAST de l'histogramme.

  DONNEES / MEMOIRE
    Les buffers par lecteur sont bornes (SrcBuf/DstBuf/F32 proportionnels a
    MaxBE <= CMAXBE_HARD_CAP) : la memoire par lecteur ne depend PAS de la
    taille du fichier, seulement du super-bloc.

  COMPOSITION DES UNITES
    TWalkPlan : parcours precalcule (contigu ou LOD) -> progression EXACTE
      (elements traites / elements planifies) et annulation entre chaque plage.
    RunPlan   : driver UNIQUE appele par les 4 visitors (chart/histo,
      simple/diff) ; throttle la progression sur le changement de pourcentage.
    TSeriesStats : stats par serie (mode simple) ; accumulation en Single
      (x64 : SSE, pas de conversion x87 inutile) avec compensation de Kahan.
  ----------------------------------------------------------------------------
    AlignMaxBE(ARs, ATarget) : calibre le super-bloc commun sur le PPC des
      readers ; ATarget = 0 -> PPC minimal ; sinon arrondi superieur multiple du
      PPC, plafonne a CMAXBE_HARD_CAP. }

interface

uses
  System.SysUtils, uGGUFModel,  uMMAPReader;

type
  /// Backend de lecture reellement ouvert par TTensorReader
  TBackendFile = (btNone, btMmap, btStream);

  // --------------------------------------------------------------------------
  // TTensorReader : lecteur d'UN tenseur, avec cache de super-bloc et choix
  // automatique du backend (mmap si fichier <= cap, stream sinon).
  // --------------------------------------------------------------------------
  TTensorReader = class
  private
    // --- Source / backend -------------------------------------------------
    FFS: TMMAPReader;        // backend btMmap   : projection complete
    FStream: THandle;        // backend btStream : handle CreateFile + SEQ_SCAN
    FStreamSize: Int64;      // taille du fichier (les deux backends)
    FBase: Int64;            // offset des donnees du tenseur dans le fichier
                             //  (0 pour un dump transpose, sinon TensorDataFilePos + SourceOffset)

    // --- Types et blocs ---------------------------------------------------
    FTypeOrg, FTypeTgt: Integer;     // type reellement lu / type simule cible
    FSrcE, FSrcBy: Int64;            // QK et taille de bloc SOURCE (elements, octets)
    FDstE, FDstBy: Int64;            // QK et taille de bloc DESTINATION (si simule)
    FL: Int64;                       // PPC = LCM(FSrcE, FDstE) : bloc commun minimal
    FMaxBE: Int64;                   // super-bloc lu d'un coup (multiple de FL)
    FSrcChunk, FDstChunk: Int64;     // octets par super-bloc, src / dst

    // --- Simulation de conversion (IsConverted) ---------------------------
    FDoSim: Boolean;                 // True = Quant + Dequant intermediaires
    FUseDLL: Boolean;                // route par ggml-base.dll si disponible
    FUseImpl, FRmseType: Integer;    // profil de quantisation / type de RMSE

    // --- Mise a l'echelle NVFP4 -------------------------------------------
    FApplyScale: Boolean;            // True seulement si TypeTgt = NVFP4
    FOutScale: Single;               // facteur applique UNE fois par bloc

    // --- Cache de bloc ----------------------------------------------------
    FBlk: Int64;                     // index du bloc en cache (-1 = aucun)
    FBlkBase: Int64;                 // index du 1er element du bloc en cache
    FValidElem: Int64;               // elements valides dans FF32 (fin de fichier)

    // --- Etat / erreurs ---------------------------------------------------
    //FErr: string;                    // message lisible si Ok = False
    FOk: Boolean;                    // lecteur utilisable (jamais d'exception)

    // --- Buffers ----------------------------------------------------------
    FSrcBuf, FSimBuf: TBytes;        // octets lus / octets quantifies
    FF32: array of Single;           // valeurs dequantisees (+ scale applique)

    /// Charge (ou retrouve en cache) le bloc contenant ABlk
    function LoadBlock(ABlk: Int64): Boolean;
    /// Lit Count octets a ASrcOff dans ABuf selon le backend ouvert
    function ReadAtOff(ASrcOff: Int64; ABuf: PByte; ACount: Int64): Boolean;
    /// Taille totale du fichier courant (les deux backends)
    function TotalSize: Int64;
    /// Libere tous les handles / buffers (appele par Destroy et en cas d'erreur)
    procedure FreeAll;
    function GetBackend: TBackendFile;
  public

    constructor Create(T: TGGUFTensorInfo);
    destructor Destroy; override;

    /// True si le lecteur est pret (format supporte + fichier ouvert + buffers)
    function Ok: Boolean;
    property Backend: TBackendFile read GetBackend;  // utile pour les logs

    // --- Metadons exposes (alignement passe jointe, diagnostics) ----------
    property TypeOrg: Integer read FTypeOrg;
    property TypeTgt: Integer read FTypeTgt;
    property PPC: Int64 read FL;        // bloc commun minimal (LCM src/dst)
    property MaxBE: Int64 read FMaxBE;  // super-bloc courant (multiple de PPC)
    property BlockBase: Int64 read FBlkBase;
    property DoSim: Boolean read FDoSim;
    property UseImpl: Integer read FUseImpl;
    property RmseType: Integer read FRmseType;

    /// Echelle appliquee uniquement si TypeTgt = NVFP4 (sinon 1.0).
    /// La multiplication est faite par bloc (LoadBlock), PAS par element.
    procedure SetOutScale(AScale: Double);

    /// Charge le bloc contenant AIdx ; False = plus aucune donnee dispo (EOF/erreur)
    function ReadAt(AIdx: Int64): Boolean;
    /// Elements encore valides a partir de AIdx dans le bloc courant (0 = EOF)
    function ValidFrom(AIdx: Int64): Int64;
    /// Valeur du bloc courant (ReadAt prealable obligatoire) -- Single natif
    function ValAt(AIdx: Int64): Single; inline;
    /// Recalcule les buffers pour une nouvelle taille de super-bloc (doit etre
    /// multiple du PPC) ; reinitialise le cache ; retourne Ok apres reshape.
    function Reshape(ANewMaxBE: Int64): Boolean;
  end;

  // --------------------------------------------------------------------------
  // TWalkPlan : liste de ranges (start, count) a parcourir.
  //  - Contiguous : une seule entree = toute la plage (zoom)
  //  - LOD        : NumBins entrees de PtsPerBin elements (echantillonnage)
  //  Total = elements planifies = denominateur de progression.
  // --------------------------------------------------------------------------
  TWalkPlan = class
  private
    FStart: array of Int64;
    FCount: array of Int64;
    FItems: Integer;
    FTotal: Int64;
    FCursor: Integer;
    procedure AddEntry(AStar, AC: Int64);
  public
    class function Contiguous(AStar, AEnd: Int64): TWalkPlan;
    class function LOD(AStar, AEnd: Int64; ANumBins, APtsPerBin: Integer): TWalkPlan;
    procedure Restart;
    function Next(out AStar, ACnt: Int64): Boolean;
    property Total: Int64 read FTotal;
    property ItemsCount: Integer read FItems;
    property Cursor: Integer read FCursor;
  end;

  // --------------------------------------------------------------------------
  // TSeriesStats : statistiques d'une serie (mode simple 1..N tenseurs).
  //  - Add(V) encaisse un Single ; NaN/Inf sont comptes a part (pas dans Mean/Std)
  //  - Sum/SumSq en Double avec compensation de Kahan pour eviter la perte de
  //    precision sur les grands N (x64 : double = SSE, surcout negligeable).
  // --------------------------------------------------------------------------
  TSeriesStats = record
  private
    // termes de compensation Kahan (evite l'accumulation d'erreur a grande N)
    FCompSum, FCompSumSq: Double;
  public
    N, NNan, NInf: Int64;
    MinV, MaxV: Double;
    Sum, SumSq: Double;
    procedure Reset;
    procedure Add(V: Single); inline;
    function Mean: Double;
    function Std: Double;
    function FullStr: string;
  end;

  // --- Types de callback utilises par RunPlan -------------------------------
  TCanAbort = reference to function: Boolean;
  TProgressCb = reference to procedure(ADone, ATotal: Int64; ALocalPct: Integer);
  TEntryVisitor = reference to procedure(Rs: array of TTensorReader;
    AStart: Int64; ACount: Int64);

{ Calibre le super-bloc commun de tous les readers sur le PPC (LCM des PPC).
 ATarget = 0 -> PPC minimal (petites lectures) ; les parcours passants appellent
 avec CREAD_CHUNK_ELEMS pour eviter un ReadFile tous les PPC. }
function AlignMaxBE(ARs: array of TTensorReader; ATarget: Int64): Boolean;

/// True = plan epuise ; False = annule ou EOF (AEOFIdx >= 0 dans ce cas,
/// AEOFIdx = -2 si erreur lecteur).  La progression est throttle : on n'appelle
/// AProgress que quand le pourcentage change (evite des milliers de callbacks).
function RunPlan(APlan: TWalkPlan; ARs: array of TTensorReader;
  AVisitor: TEntryVisitor; AAbort: TCanAbort; AProgress: TProgressCb;
  out AEOFIdx: Int64): Boolean;

/// True si la plage doit passer en LOD (> NumBins * PtsPerBin)
function SafeLODNeeded(ARange: Int64; ANumBins, APtsPerBin: Integer): Boolean;
/// Construit le plan adapte (LOD ou contigu)
function BuildPlan(AStar, AEnd: Int64; ALOD: Boolean; ANumBins, APtsPerBin: Integer): TWalkPlan;

/// Cap memoire en dessous duquel le mmap est prefere au stream.
{Renvoie le plafond en cache (GMmapCapBytes) : valeur RAM/4 initialisée par
InitMmapCapBytes, ou plafond impose par l'UI. Ne pas appeler GlobalMemoryStatusEx
ici (coût système par ouverture de lecteur). }
function RecommendedMmapCapBytes: Int64;

const
  CMAX_PLOT_POINTS = 1 shl 20;    // 1 M points/série (16 Mo) : cap de rendu,
                                  // au-dela = inutile a l'ecran et gaspilleux

  CMAXBE_HARD_CAP  = 65536;       // plafond absolu de super-bloc (garde PPC)
  CLOD_CHUNK_MIN   = 32;          // super-bloc mini en LOD (types 32 elts) ou CREAD_CHUNK_ELEMS todo !
  CREAD_CHUNK_ELEMS = 4096;       // taille de lecture mini (memoire BORNEE : 4096*8B = 32 Ko)

type
  /// Politique de choix du backend de lecture (cfg.IOReaderMode -> GReaderMode)
  TIOSourceMode = (ioAuto, ioMmap, ioStream);

var
  /// Choix utilisateur. Par defaut Auto (comportement historique).
  GReaderMode: TIOSourceMode = ioAuto;

/// Calcule UNE fois le plafond lie a la RAM (GlobalMemoryStatusEx ne doit PAS
/// etre appele a chaque ouverture de lecteur). 0 = non initialise.
GMmapCapBytes: Int64 = 0;

/// Initialise le plafond depuis la RAM physique : RAM/4, plancher 64 Mo.
/// Appelle a l'initialisation de l'unite ; SetReaderMode peut le surcharger.
procedure InitMmapCapBytes;

/// UI/INI -> politique E/S.
///  AMmapCapMb > 0 : plafond IMPOSE (en Mo) utilise en mode ioAuto (et
///                   servi comme seuil d'avertissement en ioMmap).
///  AMmapCapMb = 0 : plafond derive de la RAM (RAM/4) -> re-evalue a la demande.
procedure SetReaderMode(M: TIOSourceMode; AMmapCapMb: Int64);

function ReaderModeFromInt(V: Integer): TIOSourceMode;   // 0=Auto 1=Mmap 2=Stream
function ReaderModeToInt(M: TIOSourceMode): Integer;
function ReaderModeToStr(M: TIOSourceMode): string;      // 'auto'/'mmap'/'stream'



implementation

uses
  Winapi.Windows,        // CreateFile / ReadFile / SetFilePointerEx / MEMORYSTATUSEX
  uGGMLTypes, uGGMLConstants, uGgmlQuants, uLangManager, uMath, uLog, uStrUtils;


procedure InitMmapCapBytes;
var st: MEMORYSTATUSEX;
begin
  GMmapCapBytes := 1 shl 30;                     // 1 GiB si l'API echoue
  st.dwLength := SizeOf(st);
  if GlobalMemoryStatusEx(st) and (st.ullTotalPhys > 0) then
    GMmapCapBytes := Int64(st.ullTotalPhys) div 4;
  if GMmapCapBytes < (64 shl 20) then
    GMmapCapBytes := 64 shl 20;                  // plancher : les petits fichiers meritent le mmap
end;

function RecommendedMmapCapBytes: Int64;
begin
  if GMmapCapBytes = 0 then InitMmapCapBytes;    // lazy : insensible a l'ordre d'init
  Result := GMmapCapBytes;
end;

procedure SetReaderMode(M: TIOSourceMode; AMmapCapMb: Int64);
begin
  GReaderMode := M;
  if AMmapCapMb > 0 then
    GMmapCapBytes := AMmapCapMb shl 20
  else
    GMmapCapBytes := 0;                          // 0 = « recalcule depuis la RAM »
  LogI('[IO] reader=%s cap=%s', [ReaderModeToStr(GReaderMode),
    FormatBytes2f(RecommendedMmapCapBytes)]);
end;

function ReaderModeFromInt(V: Integer): TIOSourceMode;
begin
  case V of 1: Result := ioMmap; 2: Result := ioStream;
  else Result := ioAuto; end;
end;
function ReaderModeToInt(M: TIOSourceMode): Integer;
begin Result := Integer(M); end;
function ReaderModeToStr(M: TIOSourceMode): string;
begin
  case M of ioMmap: Result := 'mmap'; ioStream: Result := 'stream';
  else Result := 'auto'; end;
end;

// Taille reelle du fichier ; High(Int64) si illisible => jamais de mmap.
function ProbeFileSize(const APath: string): Int64;
var h: THandle; sz: TLargeInteger;
begin
  Result := High(Int64);
  h := CreateFile(PChar(APath), GENERIC_READ, FILE_SHARE_READ, nil,
    OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, 0);
  if h = INVALID_HANDLE_VALUE then Exit;
  try
    if GetFileSizeEx(h, sz) then Result := sz;
  finally
    CloseHandle(h);
  end;
end;


{ ============================================================================
  TTensorReader -- backend / construction
============================================================================ }

// Petit helper interne : backend courant (pour la propriete publique)
function TTensorReader.GetBackend: TBackendFile;
begin
  if FFS <> nil then
    Exit(btMmap);
  if (FStream <> 0) and (FStream <> INVALID_HANDLE_VALUE) then
    Exit(btStream);
  Result := btNone;
end;

// Libere tous les ressources (handles + buffers). Appelle aussi en cas d'erreur
// de construction pour laisser l'objet propre et non destructeur.
procedure TTensorReader.FreeAll;
begin
  if FFS <> nil then
  begin
    FFS.Free;
    FFS := nil;
  end;
  if (FStream <> 0) and (FStream <> INVALID_HANDLE_VALUE) then
    CloseHandle(FStream);
  FStream := 0;
  FStreamSize := 0;
  SetLength(FSrcBuf, 0);
  SetLength(FSimBuf, 0);
  SetLength(FF32, 0);
end;

constructor TTensorReader.Create(T: TGGUFTensorInfo);
var
  path, pathT: string;
  fsize: Int64;
  useMmap: Boolean;
  L: Int64;
  FileHandle: THandle;
  FileSizeEx: TLargeInteger;
begin
  inherited Create;
  // --- Etat initial : cache vide, pas de scale, pas d'erreur ----------------
  FBlk := -1;
  FBlkBase := -1;
  FValidElem := 0;
  FOutScale := 1.0;
  FOk := False;
  FFS := nil;
  FStream := 0;
  FStreamSize := 0;

  if T = nil then
  begin
    if LogIsOn(lvError) then
      LogE(mLang.gMsg('FVT.ReaderNoTensor')); // 'tensor absent'
    Exit;
  end;

  // --- Types reel et cible (la simulation remplace-t-elle le type ?) -------
  FTypeOrg := Integer(T.TensorTypeOrg);
  FDoSim := T.IsConverted;
  if FDoSim then
    FTypeTgt := Integer(T.TensorType)
  else
    FTypeTgt := FTypeOrg;
  FUseImpl := T.UseImpl;
  FRmseType := T.RmseType;
  FUseDLL := (FUseImpl = 0) or (FUseImpl = 2); // route DLL Ref / Impl optimisee

  // --- Blocs SOURCE : QK + octets (les scalaires ont QK = 1) ---------------
  if GGML_TypeIsQuant(FTypeOrg) then
  begin
    FSrcE := GGML_BlockElems(FTypeOrg);
    FSrcBy := GGML_BlockBytes(FTypeOrg);
  end
  else
  begin
    FSrcE := 1; // scalaire : pas d'aliasing de bloc
    FSrcBy := GGML_BlockBytes(FTypeOrg);
  end;

  // --- Blocs DESTINATION : seulement si simulation --------------------------
  if FDoSim then
  begin
    if GGML_TypeIsQuant(FTypeTgt) then
    begin
      FDstE := GGML_BlockElems(FTypeTgt);
      FDstBy := GGML_BlockBytes(FTypeTgt);
    end
    else
    begin
      FDstE := 1;
      FDstBy := GGML_BlockBytes(FTypeTgt);
    end;
  end
  else
  begin
    FDstE := 1;
    FDstBy := 0; // pas de buffer destination
  end;

  if (FSrcE <= 0) or (FDstE <= 0) or (FSrcBy <= 0) then
  begin
    if LogIsOn(lvError) then
      LogE('format non supporte (%s)', [GGMLTypeToStr(FTypeOrg)]);
    Exit;
  end;

  // --- PPC = LCM des deux QK : plus petit bloc lu d'un coup correct ---------
  L := Lcm64(FSrcE, FDstE);
  if L <= 0 then
  begin
    if LogIsOn(lvError) then
      LogE(mLang.gMsg('FVT.ReaderBadPPC')); // 'PPC de blocs invalide'
    Exit;
  end;
  FL := L;

  // MaxBE initial = PPC (plus de gonflage automatique a 256 qui sur-lisait
  // 8x les types 32 elements en LOD).  On arrondit au-dessus du PPC si PPC <
  // CLOD_CHUNK_MIN (ex. scalaires) pour limiter le nombre de LoadBlock.
  FMaxBE := L;
  if FMaxBE < CREAD_CHUNK_ELEMS then
    FMaxBE := ((CREAD_CHUNK_ELEMS + L - 1) div L) * L;   // multiple du PPC
  if FMaxBE < CLOD_CHUNK_MIN then
    FMaxBE := ((CLOD_CHUNK_MIN + L - 1) div L) * L;

  if FMaxBE > CMAXBE_HARD_CAP then
    FMaxBE := (CMAXBE_HARD_CAP div L) * L;
  if FMaxBE <= 0 then
  begin
    LogE(mLang.gMsg('FVT.ReaderBadPPC'));
    Exit;
  end;

  // --- Buffers proportionnels au super-bloc (memoire BORNEE par bloc) ------
  FSrcChunk := (FMaxBE div FSrcE) * FSrcBy;
  FDstChunk := (FMaxBE div FDstE) * FDstBy;
  SetLength(FSrcBuf, FSrcChunk);
  SetLength(FF32, FMaxBE);
  if FDoSim then
    SetLength(FSimBuf, FDstChunk);

  FApplyScale := (FTypeTgt = GGML_TYPE_NVFP4);

  // --- Choix du fichier (transpose si disponible) + backend -----------------
  pathT := '';
  if T.IsTransposed then
    pathT := T.TransposFile;
  if (pathT <> '') and FileExists(pathT) then
  begin
    path := pathT;
    FBase := 0; // dump transpose = fichier brut
  end
  else
  begin
    path := T.SourceFile;
    FBase := T.TensorDataFilePos + T.SourceOffset;
  end;

  // Politique de backend : mode UI, puis contrainte sequentielle
  case GReaderMode of
    ioMmap:   useMmap := True;                            // force (fallback ci-dessous)
    ioStream: useMmap := False;
  else
    useMmap := (ProbeFileSize(path) <= RecommendedMmapCapBytes);
  end;

  try
    if useMmap then
    begin
      try
        FFS := TMMAPReader.Create(path);
        FStreamSize := FFS.Size;
        if (GReaderMode = ioMmap) and (FStreamSize > RecommendedMmapCapBytes) then
          LogW('[IO] mmap FORCE sur %s (%s > cap %s) : page-fault storm possible',
            [ExtractFileName(path), FormatBytes2f(FStreamSize),
             FormatBytes2f(RecommendedMmapCapBytes)]);
      except
        on EM: Exception do
        begin
          FFS := nil;
          useMmap := False;                       // on ne meurt pas pour un mmap refuse
          LogW('[IO] mmap impossible (%s) -> stream', [EM.Message]);
        end;
      end;
    end;

    if not useMmap then
    begin
      FStream := CreateFile(PChar(path), GENERIC_READ, FILE_SHARE_READ, nil,
        OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL or FILE_FLAG_SEQUENTIAL_SCAN, 0);
      if FStream = INVALID_HANDLE_VALUE then
      begin
        FStream := 0;
        if LogIsOn(lvError) then
           LogE(SysErrorMessage(GetLastError));
        Exit;
      end;
      if not GetFileSizeEx(FStream, FStreamSize) then
        FStreamSize := 0;
    end;

    FOk := (T.TotElems > 0) and
           ((FFS <> nil) or ((FStream <> 0) and (FStream <> INVALID_HANDLE_VALUE)));

    if LogIsOn(lvDebug) then
      LogD('[MAPPTR] open "%s" %s -> %s | elems=%d cols=%d rows=%d | srcQK=%d srcBS=%d dstQK=%d dstBS=%d | PPC=%d MaxBE=%d | sim=%s dll=%s | backend=%s | chunk %s/%s',
        [string(T.Name), GGMLTypeToStr(FTypeOrg), GGMLTypeToStr(FTypeTgt),
         T.TotElems, T.Cols, T.Rows, FSrcE, FSrcBy, FDstE, FDstBy, FL, FMaxBE,
         sStrBool(FDoSim), sStrBool(FUseDLL),
         IfThen1(GetBackend = btMmap, 'mmap', 'stream'),
         FormatBytes2f(FSrcChunk), FormatBytes2f(FDstChunk)]);
  except
    on E: Exception do
    begin
      LogE(E.Message);
      FreeAll;
    end;
  end;
end;

destructor TTensorReader.Destroy;
begin
  FreeAll;
  inherited;
end;

// Etat utilisable : type ok + handle ouvert + buffers cohérents
function TTensorReader.Ok: Boolean;
begin
  Result := FOk and ((FFS <> nil) or
    ((FStream <> 0) and (FStream <> INVALID_HANDLE_VALUE))) and
    (FMaxBE > 0) and (Length(FF32) = FMaxBE) and
    (not FDoSim or (FDstChunk > 0));
end;

function TTensorReader.TotalSize: Int64;
begin
  Result := FStreamSize; // les deux backends alimentent le meme champ
end;

// Lecture unifiee : mmap (deplacement + copie) ou stream (seek + ReadFile)
function TTensorReader.ReadAtOff(ASrcOff: Int64; ABuf: PByte; ACount: Int64): Boolean;
var
  n: DWORD;
  err: DWORD;
begin
  Result := False;
  if ACount <= 0 then
    Exit(True); // rien a lire = succes

  if FFS <> nil then
  begin
    try
      FFS.Position := ASrcOff;
      Result := (FFS.ReadBuffer(ABuf^, ACount) = ACount);
      if not Result then
        if LogIsOn(lvError) then
           LogE('lecture mmap hors fichier');
    except
      on E: Exception do
         LogE('mmap: ' + E.Message);
    end;
    Exit;
  end;

  if (FStream <> 0) and (FStream <> INVALID_HANDLE_VALUE) then
  begin
    err := 0;
    if not SetFilePointerEx(FStream, ASrcOff, nil, FILE_BEGIN) then
    begin
      if LogIsOn(lvError) then
           LogE(SysErrorMessage(GetLastError));
      Exit;
    end;
    // ACount est borne par FSrcChunk (<= CMAXBE_HARD_CAP * quelques octets) :
    // le cast DWORD est sur, on le verifie quand meme.
    if ACount > $FFFFFF00 then
    begin
      if LogIsOn(lvError) then
         LogE('bloc trop gros pour ReadFile');
      Exit;
    end;
    if not ReadFile(FStream, ABuf^, DWORD(ACount), n, nil) then
    begin
      err := GetLastError;
      if err <> ERROR_HANDLE_EOF then
        if LogIsOn(lvError) then
           LogE(SysErrorMessage(err));
      Exit;
    end;
    Result := (n = DWORD(ACount));
    if not Result then
      if LogIsOn(lvError) then
           LogE('fin de fichier pendant la lecture');
  end;
end;

{ ============================================================================
  TTensorReader -- chargement / lecture de blocs
============================================================================ }

// Charge le bloc (super-bloc) contenant ABlk.  Si deja en cache, succes immediat.
// Applique ensuite l'echelle NVFP4 une fois pour tout le bloc (pas par element).
function TTensorReader.LoadBlock(ABlk: Int64): Boolean;
var
  off, avail, nElem, j: Int64;
begin
  Result := False;
  if not Ok then
  begin
    FBlk := -1;
    FValidElem := 0;
    Exit;
  end;

  if (ABlk = FBlk) and (FValidElem > 0) then
    Exit(True); // cache : aucun travail

  // offset fichier du debut du super-bloc
  off := FBase + ABlk * FSrcChunk;
  avail := TotalSize - off;
  if avail <= 0 then
    Exit; // au-dela du fichier = EOF
  if avail > FSrcChunk then
    avail := FSrcChunk;
  // on ne garde que des blocs complets : la lecture partielle se fera sur la
  // derniere fraction, mais nElem sera tronque au nombre entier de blocs source
  avail := (avail div FSrcBy) * FSrcBy;
  if avail <= 0 then
  begin
    FBlk := -1;
    FValidElem := 0;
    Exit; // EOF (bloc incomplet en fin de fichier)
  end;

  if not ReadAtOff(off, @FSrcBuf[0], avail) then
  begin
    FBlk := -1;
    FValidElem := 0;
    Exit; // erreur I/O ou EOF
  end;

  // nombre d'elements reellement valides dans FF32
  nElem := (avail div FSrcBy) * FSrcE;
  if FDoSim then
    nElem := (nElem div FL) * FL      // simulation : multiple du PPC (sinon Quant invalide)
  else
    nElem := (nElem div FSrcE) * FSrcE;
  if nElem > FMaxBE then
    nElem := FMaxBE;
  if nElem <= 0 then
  begin
    FBlk := -1;
    FValidElem := 0;
    Exit; // EOF
  end;

  // Dequantification du bloc entier
  Dequant(@FSrcBuf[0], @FF32[0], Integer(nElem), FTypeOrg, FUseDLL);

  // Simulation de conversion : Quant puis Re-Dequant (rendu "comme si")
  if FDoSim then
  begin
    Quant(@FF32[0], @FSimBuf[0], Integer(nElem), FTypeTgt, FUseImpl, FRmseType);
    Dequant(@FSimBuf[0], @FF32[0], Integer(nElem), FTypeTgt, FUseDLL);
  end;

  // Echelle NVFP4 : UNE seule boucle sur le bloc (avant : par element, gaspillage)
  if FApplyScale and (FOutScale <> 1.0) then
    for j := 0 to nElem - 1 do
      FF32[j] := FF32[j] * FOutScale;

  FBlk := ABlk;
  FBlkBase := ABlk * FMaxBE;
  FValidElem := nElem;
  Result := True;
end;

// Charge le bloc contenant AIdx ; True = au moins un element valide a cet index
function TTensorReader.ReadAt(AIdx: Int64): Boolean;
begin
  Result := LoadBlock(AIdx div FMaxBE);
end;

// Nombre d'elements encore valides a partir de AIdx (0 = EOF / bloc non charge)
function TTensorReader.ValidFrom(AIdx: Int64): Int64;
begin
  if (FBlk < 0) or (AIdx div FMaxBE <> FBlk) then
    Exit(0);
  Result := FValidElem - (AIdx - FBlkBase);
  if Result < 0 then
    Result := 0;
end;

// Acces directs au bloc courant (ReadAt prealable obligatoire)
function TTensorReader.ValAt(AIdx: Int64): Single;
begin
  Result := FF32[AIdx - FBlkBase];
end;

// Echelle de sortie : ignoree si le type cible n'est pas NVFP4
procedure TTensorReader.SetOutScale(AScale: Double);
begin
  if FApplyScale and (AScale > 0) then
    FOutScale := Single(AScale)
  else
    FOutScale := 1.0;
end;

// Nouvelle taille de super-bloc (doit etre multiple du PPC).  Recalcule les
// buffers et invalide le cache.  Retourne Ok apres reshape.
function TTensorReader.Reshape(ANewMaxBE: Int64): Boolean;
begin
  Result := False;
  if ANewMaxBE <= 0 then
    Exit;
  if (FL > 0) and (ANewMaxBE mod FL <> 0) then
    Exit; // obligatoire : la simulation exige un multiple du PPC
  if ANewMaxBE = FMaxBE then
    Exit(Ok);

  FSrcChunk := (ANewMaxBE div FSrcE) * FSrcBy;
  FDstChunk := (ANewMaxBE div FDstE) * FDstBy;
  SetLength(FSrcBuf, FSrcChunk);
  if FDoSim then
    SetLength(FSimBuf, FDstChunk);
  SetLength(FF32, ANewMaxBE);
  FMaxBE := ANewMaxBE;
  FBlk := -1;
  FBlkBase := -1;
  FValidElem := 0;
  Result := Ok;
end;

{ ============================================================================
  AlignMaxBE : calibre les super-blocs d'une passe jointe (2 readers) sur le PPC
============================================================================ }

// Aligne les readers sur un super-bloc commun = multiple du PPC commun.
// ATarget = 0 -> minimal (PPC commun).  Les appels existants
// AlignMaxBE([R1, R2], 0, Err) restent valides et deviennent optimaux (32 pour
// BF16 vs IQ4_NL au lieu de 256).
function AlignMaxBE(ARs: array of TTensorReader; ATarget: Int64): Boolean;
var
  i: Integer;
  base, want: Int64;
begin
  Result := False;
  if Length(ARs) = 0 then
    Exit;

  // 1) PPC commun = LCM des PPC de chaque reader
  base := 1;
  for i := 0 to High(ARs) do
  begin
    if (ARs[i] = nil) or (not ARs[i].Ok) then
    begin
      if ARs[i] = nil then
         LogE('nil reader');
      Exit;
    end;
    base := Lcm64(base, ARs[i].PPC);
    if (base <= 0) or (base > CMAXBE_HARD_CAP) then
    begin
      // 'formats incompatibles pour la passe jointe (PPC=%d)'
      if LogIsOn(lvError) then
           LogE( mLang.gMsgFmt('FVT.ReaderIncompat', [base]));
      Exit;
    end;
  end;

  // 2) taille demandee arrondie au-dessus du PPC (Target <= PPC = PPC minimal)
  if ATarget <= base then
    want := base
  else
    want := ((ATarget + base - 1) div base) * base;

  // plancher : PPC strict = 1 element pour F32/F16/BF16 -> 1 ReadFile par
  // element. En LOD on descend volontairement a CLOD_CHUNK_MIN, jamais plus bas.
  if want < CLOD_CHUNK_MIN then
    want := ((CLOD_CHUNK_MIN + base - 1) div base) * base;

  // 3) plafond absolu, toujours multiple du PPC
  if want > CMAXBE_HARD_CAP then
    want := (CMAXBE_HARD_CAP div base) * base;
  if want <= 0 then
    want := base;

  // 4) reshape de tous les readers
  for i := 0 to High(ARs) do
    if not ARs[i].Reshape(want) then
    begin
      // 'reshape impossible (%s)'
      if LogIsOn(lvError) then
         LogE( mLang.gMsgFmt('FVT.ReaderReshape', [GGMLTypeToStr(ARs[i].TypeOrg)]));
      Exit;
    end;
  Result := True;
end;

{ ============================================================================
  TWalkPlan : parcours precalcule
============================================================================ }

// Ajoute un range (start, count) ; croissance geometrique des tableaux
procedure TWalkPlan.AddEntry(AStar, AC: Int64);
begin
  if AC <= 0 then
    Exit;
  if FItems = Length(FStart) then
  begin
    if FItems = 0 then
      SetLength(FStart, 128)
    else
      SetLength(FStart, Length(FStart) * 2);
    SetLength(FCount, Length(FStart));
  end;
  FStart[FItems] := AStar;
  FCount[FItems] := AC;
  Inc(FItems);
  FTotal := FTotal + AC;
end;

// Plan d'une plage complete (mode zoom) : une seule entree [AStar..AE]
class function TWalkPlan.Contiguous(AStar, AEnd: Int64): TWalkPlan;
begin
  Result := TWalkPlan.Create;
  if AEnd >= AStar then
    Result.AddEntry(AStar, AEnd - AStar + 1);
end;

// Plan echantillonne (LOD) : NumBins blocs de PtsPerBin elements, par pas
// step = Range / NumBins.  Parcours CROISSANT = compatible stream sequentiel.
class function TWalkPlan.LOD(AStar, AEnd: Int64; ANumBins, APtsPerBin: Integer): TWalkPlan;
var
  i, step, st: Int64;
  range: Int64;
begin
  Result := TWalkPlan.Create;
  if AEnd < AStar then
    Exit;
  if ANumBins < 1 then ANumBins := 1;
  if APtsPerBin < 1 then APtsPerBin := 1;
  range := AEnd - AStar + 1;
  step := Max(1, range div ANumBins);
  for i := 0 to ANumBins - 1 do
  begin
    st := AStar + i * step;
    if st > AEnd then Break;
    Result.AddEntry(st, Min(Int64(APtsPerBin), AEnd - st + 1));
  end;
end;

{ Re-lecture du plan ; utilisé uniquement si un visitor le demande
— ici la 2e passe est un BuildPlan neuf, pas un Restart.}
procedure TWalkPlan.Restart;
begin
  FCursor := 0;
end;

// Iterateur : True = entree retournee ; False = plan epuise
function TWalkPlan.Next(out AStar, ACnt: Int64): Boolean;
begin
  if FCursor >= FItems then
  begin
    AStar := 0;
    ACnt := 0;
    Exit(False);
  end;
  AStar := FStart[FCursor];
  ACnt := FCount[FCursor];
  Inc(FCursor);
  Result := True;
end;

{ ============================================================================
  RunPlan : driver unique (progression exacte + annulation + throttle)
============================================================================ }

function RunPlan(APlan: TWalkPlan; ARs: array of TTensorReader;
  AVisitor: TEntryVisitor; AAbort: TCanAbort; AProgress: TProgressCb;
  out AEOFIdx: Int64): Boolean;
var
  st, cnt, pos, remain, n, m, done: Int64;
  k: Integer;
  pct, LastPct: Integer;
begin
  Result := False;
  AEOFIdx := -1;
  done := 0;
  LastPct := -1;
  if (APlan = nil) or (APlan.Total <= 0) then
    Exit;
  for k := 0 to High(ARs) do
    if (ARs[k] = nil) or (not ARs[k].Ok) then
    begin
      AEOFIdx := -2; // erreur lecteur
      Exit;
    end;

  while APlan.Next(st, cnt) do
  begin
    if Assigned(AAbort) and AAbort then
      Exit; // annulation propre (pas d'EOF)
    pos := st;
    remain := cnt;
    while remain > 0 do
    begin
      if Assigned(AAbort) and AAbort then
        Exit;
      n := remain;
      // intersection des elements valides : chaque reader peut couper plus tot
      // (fin de fichier) ; on s'arrete au minimum.
      for k := 0 to High(ARs) do
      begin
        if not ARs[k].ReadAt(pos) then
        begin
          AEOFIdx := pos;
          Exit;
        end;
        m := ARs[k].ValidFrom(pos);
        if m < n then
          n := m;
      end;
      if n <= 0 then
      begin
        AEOFIdx := pos;
        Exit;
      end;
      if Assigned(AVisitor) then
        AVisitor(ARs, pos, n);
      Inc(done, n);
      Inc(pos, n);
      Dec(remain, n);
      // progression throttle : 1 callback par changement de pourcentage au lieu
      // d'un callback par mini-bloc (economise UI + conversions + Format)
      if Assigned(AProgress) then
      begin
        pct := Round(done * 100.0 / APlan.Total);
        if pct > 100 then pct := 100;
        if (pct <> LastPct) or (done >= APlan.Total) then
        begin
          AProgress(done, APlan.Total, pct);
          LastPct := pct;
        end;
      end;
    end;
  end;
  Result := True; // plan epuise normalement
end;

{ ============================================================================
  Plans utilitaires (regles identiques au graphe)
============================================================================ }

// True si la plage doit passer en LOD : Range > NumBins * PtsPerBin
function SafeLODNeeded(ARange: Int64; ANumBins, APtsPerBin: Integer): Boolean;
var
  safe: Int64;
begin
  safe := Int64(ANumBins) * Int64(APtsPerBin);
  if safe <= 0 then
    Exit(False); // reglages invalide : on ne LOD pas
  Result := ARange > safe;
end;

// Construit le plan adapte au mode (LOD ou contigu)
function BuildPlan(AStar, AEnd: Int64; ALOD: Boolean; ANumBins, APtsPerBin: Integer): TWalkPlan;
begin
  if ALOD then
    Result := TWalkPlan.LOD(AStar, AEnd, ANumBins, APtsPerBin)
  else
    Result := TWalkPlan.Contiguous(AStar, AEnd);
end;

{ ============================================================================
  TSeriesStats : stats d'une serie (Single en entree, Double en accumulateurs)
============================================================================ }

procedure TSeriesStats.Reset;
begin
  N := 0; NNan := 0; NInf := 0;
  MinV := MaxDouble; MaxV := -MaxDouble;
  Sum := 0; SumSq := 0;
  FCompSum := 0; FCompSumSq := 0;
end;

// Encaisse une valeur.  NaN/Inf sont comptes a part (pas de contamination des
// moyennes/ecarts-types).  Les accumulateurs Sum/SumSq utilisent la
// compensation de Kahan : sur les gros tenseurs, la somme naive perd beaucoup
// de precision ; ici Sum reste fiable sans couter plus de flops notables.
procedure TSeriesStats.Add(V: Single);
var
  y, t, w: Double;
begin
  if IsNaN(V) then
  begin
    Inc(NNan);
    Exit;
  end;
  if IsInfinite(V) then
  begin
    Inc(NInf);
    Exit;
  end;
  Inc(N);
  if V < MinV then MinV := V;
  if V > MaxV then MaxV := V;

  // Kahan sur Sum
  y := Double(V) - FCompSum;
  t := Sum + y;
  FCompSum := (t - Sum) - y;
  Sum := t;

  // Kahan sur SumSq
  w := Double(V) * Double(V);
  y := w - FCompSumSq;
  t := SumSq + y;
  FCompSumSq := (t - SumSq) - y;
  SumSq := t;
end;

function TSeriesStats.Mean: Double;
begin
  if N > 0 then Result := Sum / N else Result := 0;
end;

// Ecart-type (population) ; variance par E[X^2] - E[X]^2, bornee a 0
function TSeriesStats.Std: Double;
var
  v: Double;
begin
  if N <= 0 then Exit(0);
  v := SumSq / N - Sqr(Mean);
  if v < 0 then v := 0;
  Result := Sqrt(v);
end;

// Resume pour les logs
function TSeriesStats.FullStr: string;
begin
  if N <= 0 then
    Exit(SafeFmt('N=0 | NaN=%d | Inf=%d', [NNan, NInf]));
  Result := SafeFmt('N=%d | Min=%.6f Max=%.6f | mu=%.6f sd=%.6f | NaN=%d Inf=%d',
    [N, MinV, MaxV, Mean, Std, NNan, NInf]);
end;


end.

