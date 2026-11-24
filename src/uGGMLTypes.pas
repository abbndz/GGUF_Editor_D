unit uGGMLTypes;

interface

uses
  Classes, SysUtils, Windows,System.SyncObjs,System.Diagnostics, IniFiles,
  uGGMLConstants, uMath, uLog;


const
  /// Fichier du registre des types + chemin de DLL ([General] DLLName)
  CCFG_TYPE_INI = 'cfg_ggml_type.ini';


type
  // Type GGML indexé (0=F32, 2=Q4_0, etc.)
  TGGMLType = Integer;

  // Événements de progression
  TOnProgressEvent1 = procedure(const Msg: string; AIdx, ATotal: Int64; Level: TLogLevel = lvTrace) of object;
  TOnProgressEvent2 = procedure(const Msg: string; ATIdx, ATTotal, AIdx, ATotal: Int64; Level: TLogLevel = lvTrace)
    of object;

  TMergeProgressEvent = procedure(AIdx, ATotal: Integer; const Cur, Max: Int64; DoLog: Boolean = false) of object;

  // Pointeurs de procédures DLL pour quantisation/déquantisation
  TQuantImplProc = function(const src: System.PSingle; dest: PByte; nrow, n_per_row: Int64; weights: System.PSingle): NativeUInt; cdecl;

  TQuantRefProc = function(const src: System.PSingle; dest: PByte; nrow, n_per_row: Int64): NativeUInt; cdecl;

  TDequantProc = function(const data: PByte; dest: System.PSingle; k: Int64): NativeUInt; cdecl;
  TRowSizeProc = function(t: Integer; n: Int64): NativeUInt; cdecl;

  // Configuration dynamique par type GGML
  TGGMLTypeConfig = record
    Name: string;
    // ScalarSize: Integer;
    BlockElems: Integer; // QK (Éléments par bloc)
    BlockBytes: Integer; // Octets par bloc
    IsQuant: Boolean;
    DequantPName: string;
    QuantImplName: string;
    QuantRefName: string;
    Presets: array [0 .. 5] of TQuantPreset;
  end;


type
  // Registre centralisé des types GGML et chargement DLL
  TGGMLRegistry = class
  private
    FConfigs: TArray<TGGMLTypeConfig>;
    FStrGGMLDLLName: String;
    FResolvedDLL: string;
    FStrRowSizeFunc: String;
    FPresetIniPath: String;
    FCount: Integer;
    FCountDLL: Integer;
    FDequantProcs: TArray<TDequantProc>;
    FQuantRefProcs: TArray<TQuantRefProc>;
    FQuantImplProcs: TArray<TQuantImplProc>;
    FLibHandle: THandle;
    FTriedIQxxInit : Boolean;
    FInitLock: TCriticalSection;

    procedure LoadDefaults;
    procedure LoadFromIni(const IniPath: string);
    procedure AddSoftwareTypes;
    procedure LoadFunsFromDLL;
    procedure GetProcStatsSimple(out ND, NQRef, NQImpl: Integer);
  public
    constructor Create;
    destructor Destroy; override;

    procedure Initialize(const IniPath: string = ''; LoadLib: Boolean = True);
    /// Nom demande (vient de cfg_ggml_type.ini [General] DLLName, sinon le nom nu)
    property DllNameRaw: string read FStrGGMLDLLName;
    /// Chemin reellement ouvert ('' = DLL non chargee -> tout en natif Delphi)
    property DllResolved: string read FResolvedDLL;
    function IsDllLoaded: Boolean;
    /// Charge la DLL si pas encore faite. Le nom vient de l'INI : AUCUN SetDllName ici.
    procedure LoadLibraryNow;

    procedure SetDllName(const AName: string);

    procedure InitializeIQxx();
    procedure DeInitializeIQxx();
    class function InitGlobal(const IniPath: string = ''; LoadLib: Boolean = True): TGGMLRegistry;

    property Configs: TArray<TGGMLTypeConfig> read FConfigs;
    property Count: Integer read FCount;
    property CountDLL: Integer read FCountDLL;

    procedure SavePresetsToIni();
    procedure LoadPresetsFromIni();
    function HasPresetSupport(AType: Integer): Boolean;
    function GetPreset(AType: Integer; AProfile: Integer): TQuantPreset;
    function GetPPreset(AType: Integer; AProfile: Integer): PQuantPreset;
  end;

function ResolveGgmlDllPath(const ARaw: string): string;

/// Vrai si AName est chargeable (fichier existant, ou nom nu = recherche PATH par Windows)
function GgmlDllUsable(const AName: string): Boolean;
/// Ecrit [General] DLLName dans cfg_ggml_type.ini -> applique AU PROCHAIN LANCEMENT.
/// TIniFile modifie la cle EN PLACE : [Types], [BlockElems], [DLLFunctions] et les
/// commentaires survivent (pas de reecriture integrale du fichier).
function GgmlWriteDllName(const AName: string): Boolean;

  // API PUBLIQUE GGML (Utilitaires bas niveau)
  // Note architecturale : Pour les opérations de haut niveau, privilégiez
  // TGGUFTensorInfo.GetRowSize() et TGGUFTensorInfo.GetTensorDataSize()
procedure GgmlWarmUpIQxx;
function GGMLTypeCount: Integer;
function GGMLTypeCountDLL: Integer;
function GGMLTypeGetListDType: TStringList;
function GGMLTypeGetListAllDType: TStringList;
function GGMLTypeToStr(VT: Integer): string;
function StrToGGMLType(const S: string): Integer;

function SafeTensorsDTypeToGGML(const S: string): Integer;

function GGML_BlockElems(VT: Integer): Integer;
function GGML_BlockBytes(VT: Integer): Integer;
function GGML_TypeIsQuant(VT: Integer): Boolean;

// Calculs de taille GGML standards
function GGML_RowSize(VT: Integer; n: Int64): Int64;
function GGML_TensorDataSize(VT: Integer; const Shape: array of Int64): Int64;

// Accès aux procédures DLL
function GetDequantProc(TypeId: Integer): TDequantProc;
function GetQuantRefProc(TypeId: Integer): TQuantRefProc;
function GetQuantImplProc(TypeId: Integer): TQuantImplProc;

var
  GetRowSizeFunc: TRowSizeProc;
  FGGMLRegistry: TGGMLRegistry;
  FInitialized: Boolean = false;
  FIsInIQxxInit: Boolean;
  FfrmEditTensorsFormClose : Boolean;

implementation

uses uQuantPresetConfig, uAppConfig, uStrUtils;

{ TGGMLRegistry }

constructor TGGMLRegistry.Create;
begin
  inherited Create;
  SetLength(FConfigs, 64);
  SetLength(FDequantProcs, 64);
  SetLength(FQuantRefProcs, 64);
  SetLength(FQuantImplProcs, 64);
  FCount := 0;
  FCountDLL := 0;
  FLibHandle := 0;
  FIsInIQxxInit := False;
  FInitLock := TCriticalSection.Create;
  FPresetIniPath := IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0))) + QUANT_PRESETS_INI;
end;

destructor TGGMLRegistry.Destroy;
begin
  if FLibHandle <> 0 then
  begin
    if FTriedIQxxInit  then
    begin
      DeInitializeIQxx
    end;
    FreeLibrary(FLibHandle);
  end;
  inherited Destroy;
end;

function GgmlDllUsable(const AName: string): Boolean;
var R: string;
begin
  R := ResolveGgmlDllPath(AName);
  Result := FileExists(R) or (ExtractFilePath(R) = '');  // nom nu -> laisse Windows decider
end;

function GgmlWriteDllName(const AName: string): Boolean;
var
  IniPath, S: string;
  Ini: TIniFile;
begin
  S := Trim(AName);
  if (S = '') or SameText(S, '<auto>') then
    S := CStrGGMLDLLName;                 // 'auto' = nom nu, jamais une chaine vide
  IniPath := IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0))) + CCFG_TYPE_INI;
  Result := False;
  try
    Ini := TIniFile.Create(IniPath);
    try
      Ini.WriteString('General', 'DLLName', S);
      Result := True;
    finally
      Ini.Free;
    end;
  except
    on E: Exception do
      LogMsg('[GGML] écriture impossible de "' + IniPath + '" : ' + E.Message, lvError);
  end;
end;


procedure GgmlWarmUpIQxx;
begin
  if FGGMLRegistry = nil then
    Exit;
  TThread.CreateAnonymousThread(
    procedure
    var
      SW: TStopwatch;
    begin
      SW := TStopwatch.StartNew;
      FGGMLRegistry.InitializeIQxx;
      SW.Stop;
      LogN('[GGML] grilles IQ pretes en %s', [FormatDurationMs(SW.ElapsedMilliseconds)]);
    end).Start;
end;

procedure TGGMLRegistry.Initialize(const IniPath: string = '';LoadLib: Boolean = True);
begin
  if FLibHandle <> 0 then
  begin
    DeInitializeIQxx;
    FreeLibrary(FLibHandle);
    FLibHandle := 0;
    SetLength(FDequantProcs, 0);
    SetLength(FQuantRefProcs, 0);
    SetLength(FQuantImplProcs, 0);
    SetLength(FConfigs, 0);
  end;
  LoadDefaults; // Base GGML native
  if (IniPath <> '') and FileExists(IniPath) then
    LoadFromIni(IniPath); // Surcharges/Extensions INI

  LoadPresetsFromIni(); // Surcharges/Extensions INI

  AddSoftwareTypes; // Types Safetensors  logiciels (FP8, futurs ...)  *
  if LoadLib then
  LoadFunsFromDLL; // Chargement des pointeurs DLL
end;

function TGGMLRegistry.IsDllLoaded: Boolean;
begin
  Result := FLibHandle <> 0;
end;

procedure TGGMLRegistry.LoadLibraryNow;
begin
  LoadFunsFromDLL; // idempotent : LoadFunsFromDLL sort immediatement si FLibHandle <> 0
end;

procedure TGGMLRegistry.SetDllName(const AName: string);
begin
  FStrGGMLDLLName := Trim(AName);
  if (FStrGGMLDLLName = '') or SameText(FStrGGMLDLLName, '<auto>') then
    FStrGGMLDLLName := CStrGGMLDLLName;
  // Volontaire : AUCUN LoadLibrary ici. Prochain lancement seulement.
end;
{ void iq2xs_free_impl(enum ggml_type type) {
  GGML_ASSERT(type == GGML_TYPE_IQ2_XXS || type == GGML_TYPE_IQ2_XS || type == GGML_TYPE_IQ1_S || type == GGML_TYPE_IQ1_M || type == GGML_TYPE_IQ2_S);
  const int gindex = iq2_data_index(type);
  if (iq2_data[gindex].grid) {
  free(iq2_data[gindex].grid);       iq2_data[gindex].grid = NULL;
  free(iq2_data[gindex].map);        iq2_data[gindex].map  = NULL;
  free(iq2_data[gindex].neighbours); iq2_data[gindex].neighbours = NULL;
  )
}

procedure TGGMLRegistry.InitializeIQxx();
var
  IQ2Init, IQ3Init: procedure(const ggml_type: Integer); cdecl; // Pointeurs temp pour l'initialisation !
  {
    GGML_API void iq2xs_init_impl(enum ggml_type type);
    GGML_API void iq2xs_free_impl(enum ggml_type type);
    GGML_API void iq3xs_init_impl(int grid_size);
    GGML_API void iq3xs_free_impl(int grid_size); }
begin
  FInitLock.Enter;
  try
    try
      if (FLibHandle = 0) or FTriedIQxxInit  or FIsInIQxxInit then
        Exit;
      FIsInIQxxInit := True;
      IQ2Init := GetProcAddress(FLibHandle, 'iq2xs_init_impl');
    // GGML_ASSERT(type == GGML_TYPE_IQ2_XXS || type == GGML_TYPE_IQ2_XS || type == GGML_TYPE_IQ1_S || type == GGML_TYPE_IQ1_M || type == GGML_TYPE_IQ2_S);
      if Assigned(IQ2Init) then
      begin
        if FfrmEditTensorsFormClose then exit;
        IQ2Init(GGML_TYPE_IQ2_XXS);
        LogT('[GGML] DLL GGML_TYPE_IQ2_XXS Initialized');
        if FfrmEditTensorsFormClose then exit;
        IQ2Init(GGML_TYPE_IQ2_XS);
        LogT('[GGML] DLL GGML_TYPE_IQ2_XS Initialized');
        if FfrmEditTensorsFormClose then exit;
        IQ2Init(GGML_TYPE_IQ1_S);
        LogT('[GGML] DLL GGML_TYPE_IQ1_S Initialized');
        if FfrmEditTensorsFormClose then exit;
        IQ2Init(GGML_TYPE_IQ2_S);
        LogT('[GGML] DLL GGML_TYPE_IQ2_S Initialized');
        if FfrmEditTensorsFormClose then exit;
        IQ2Init(GGML_TYPE_IQ1_M);
        LogT('[GGML] DLL GGML_TYPE_IQ1_M Initialized');
      end;
      IQ3Init := GetProcAddress(FLibHandle, 'iq3xs_init_impl');
    // GGML_ASSERT(grid_size == 256 || grid_size == 512);
      if Assigned(IQ3Init) then
      begin
        if FfrmEditTensorsFormClose then exit;
        IQ3Init(256);
        LogT('[GGML] DLL IQ3Init Grid 256 Initialized');
        if FfrmEditTensorsFormClose then exit;
        IQ3Init(512);
        LogT('[GGML] DLL IQ3Init Grid 512 Initialized');
      end;
    except
    end;
  finally
    FTriedIQxxInit := True;
    FIsInIQxxInit := False;
    FInitLock.Leave;
  end;
end;

procedure TGGMLRegistry.DeInitializeIQxx();
var
  IQ2Free, IQ3free: procedure(const ggml_type: Integer); cdecl;
begin
  try
    if FLibHandle <> 0 then
    begin
      FIsInIQxxInit := True;
      if FTriedIQxxInit then
      begin
        IQ2Free := GetProcAddress(FLibHandle, 'iq2xs_free_impl');
        // GGML_ASSERT(type == GGML_TYPE_IQ2_XXS || type == GGML_TYPE_IQ2_XS || type == GGML_TYPE_IQ1_S || type == GGML_TYPE_IQ1_M || type == GGML_TYPE_IQ2_S);
        if Assigned(IQ2Free) then
        begin
          IQ2Free(GGML_TYPE_IQ2_XXS);
          IQ2Free(GGML_TYPE_IQ2_XS);
          IQ2Free(GGML_TYPE_IQ1_S);
          IQ2Free(GGML_TYPE_IQ2_S);
          IQ2Free(GGML_TYPE_IQ1_M);
        end;
        IQ3free := GetProcAddress(FLibHandle, 'iq3xs_free_impl');
        // GGML_ASSERT(grid_size == 256 || grid_size == 512);
        if Assigned(IQ3free) then
        begin
          IQ3free(256);
          IQ3free(512);
        end;
      end;
      FTriedIQxxInit := false;
    end;
  except
  end;
  FIsInIQxxInit := False;
end;

class function TGGMLRegistry.InitGlobal(const IniPath: string = '';LoadLib: Boolean = True): TGGMLRegistry;
var
  vIniPath: String;
begin
  if not FInitialized then
  begin
    vIniPath := IniPath;
    if vIniPath = '' then
      vIniPath := IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0))) + CCFG_TYPE_INI;
    try
      FGGMLRegistry := TGGMLRegistry.Create;

      FGGMLRegistry.Initialize(vIniPath, LoadLib);
    except
      on E: Exception do
      begin
        FGGMLRegistry.Free;
        FGGMLRegistry := nil;
        raise;
      end;
    end;
    FInitialized := True;
  end;
  Result := FGGMLRegistry;
end;

procedure TGGMLRegistry.LoadDefaults;
var
  i,j: Integer;
begin
  SetLength(FConfigs, 64);
  SetLength(FDequantProcs, 64);
  SetLength(FQuantRefProcs, 64);
  SetLength(FQuantImplProcs, 64);
  FCount := Length(CDefaultGGMLTypeIsQuant); // 42;
  FCountDLL := FCount;
  // FStrGGMLDLLName := IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0))) + CStrGGMLDLLName;
  FStrGGMLDLLName := CStrGGMLDLLName;
  FStrRowSizeFunc := 'ggml_row_size';

  for i := 0 to FCount - 1 do
  begin
    FConfigs[i].Name := CDefaultGGMLTypeNames[i];
    // Configuration par défaut des scalaires
    // FConfigs[i].ScalarSize := CDefaultGGMLTypeScalarSizes[i];
    FConfigs[i].IsQuant := CDefaultGGMLTypeIsQuant[i];
    // Configuration par défaut des Quantifiés
    FConfigs[i].BlockElems := CDefaultGGMLTypeBlockElems[i];
    FConfigs[i].BlockBytes := CDefaultGGMLTypeBlockBytes[i];
    FConfigs[i].DequantPName := CDefaultGGMLTypeDLLFunDequant[i];
    FConfigs[i].QuantRefName := CDefaultGGMLTypeDLLFunQuantRef[i];
    FConfigs[i].QuantImplName := CDefaultGGMLTypeDLLFunQuantImpl[i];


    // Chargement des défauts pour les profils
    //if FConfigs[i].IsQuant then
    begin
      for j := 0 to Length(FConfigs[i].Presets) - 1 do
        FConfigs[i].Presets[j] := GetDefaultPresetByCode(i, j);
    end;
  end;
end;

procedure TGGMLRegistry.LoadFromIni(const IniPath: string);
var
  Ini: TIniFile;
  i,j, Count: Integer;
begin
  Ini := TIniFile.Create(IniPath);
  try
    // LU AVANT le test TypeCount : le chemin de DLL doit etre pris en compte meme
    // si cet INI ne surcharge aucun type (cas normal apres le bouton Parcourir).
    // Pas de test FileExists ici : ResolveGgmlDllPath sait deja self-healer un
    // chemin perime (il retente avec le nom nu, puis le PATH).
    FStrGGMLDLLName := Ini.ReadString('General', 'DLLName', FStrGGMLDLLName);
    FStrRowSizeFunc := Ini.ReadString('DLLFunctions', 'RowSize', 'ggml_row_size');

    Count := Ini.ReadInteger('General', 'TypeCount', 0);
    if Count > 0 then
    begin
      FCount := Count;
      FCountDLL := Count;
      if Count > 64 then
      begin
        SetLength(FConfigs, Count);
        SetLength(FDequantProcs, Count);
        SetLength(FQuantRefProcs, Count);
        SetLength(FQuantImplProcs, Count);
      end;

      for i := 0 to Count - 1 do
      begin
        FConfigs[i].Name := Ini.ReadString('Types', IntToStr(i), FConfigs[i].Name);
        // FConfigs[i].ScalarSize := Ini.ReadInteger('ScalarSizes', IntToStr(i), FConfigs[i].ScalarSize);
        FConfigs[i].IsQuant := Ini.ReadBool('IsQuant', IntToStr(i), FConfigs[i].IsQuant);
        FConfigs[i].BlockElems := Ini.ReadInteger('BlockElems', IntToStr(i), FConfigs[i].BlockElems);
        FConfigs[i].BlockBytes := Ini.ReadInteger('BlockBytes', IntToStr(i), FConfigs[i].BlockBytes);
        FConfigs[i].DequantPName := Ini.ReadString('DLLFunctions', 'Dequant.' + IntToStr(i), FConfigs[i].DequantPName);
        FConfigs[i].QuantRefName := Ini.ReadString('DLLFunctions', 'QuantRef.' + IntToStr(i), FConfigs[i].QuantRefName);
        FConfigs[i].QuantImplName := Ini.ReadString('DLLFunctions', 'QuantImpl.' + IntToStr(i), FConfigs[i].QuantImplName);
        // types nouveaux/étendus par l'INI : presets jamais initialisés -> seed défaut
        if (FConfigs[i].Presets[0].EnabledFields = []) then
          for j := 0 to High(FConfigs[i].Presets) do
            FConfigs[i].Presets[j] := GetDefaultPresetByCode(i, j);
      end;
    end;
  finally
    Ini.Free;
  end;
end;

// Resolve un nom/chemin de DLL. Ne leve JAMAIS, ne verifie pas les droits.
// 1) tel quel            2) relatif au dossier EXE
// 3) SELF-HEALING : ancien chemin absolu perimetre -> on retente avec le simple nom
// 4) sous-dossiers usuels (dll/, libs/, bin\)
// 5) nom nu => recherche standard Windows (PATH)
function ResolveGgmlDllPath(const ARaw: string): string;
var
  ExeDir, S, Base, Cand: string;
  Subs: array [0 .. 3] of string;
  i: Integer;
begin
  ExeDir := IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0)));
  S := Trim(ARaw);
  if (S = '') or SameText(S, '<auto>') then
    S := CStrGGMLDLLName;
  Base := ExtractFileName(S);

  if FileExists(S) then
    Exit(ExpandFileName(S)); // 1
  Cand := ExeDir + S;
  if FileExists(Cand) then
    Exit(Cand); // 2
  if (Base <> '') and FileExists(ExeDir + Base) then
    Exit(ExeDir + Base); // 3  <-- deplacement du dossier
  Subs[0] := 'dll';
  Subs[1] := 'dlls';
  Subs[2] := 'libs';
  Subs[3] := 'bin';
  for i := 0 to High(Subs) do
    if FileExists(ExeDir + Subs[i] + PathDelim + Base) then
      Exit(ExeDir + Subs[i] + PathDelim + Base); // 4
  Result := Base; // 5
end;

function TryLoadGgmlLib(const APath: string; out H: THandle; out ErrCode: DWORD): Boolean;
const
  CLOAD_WITH_ALTERED_SEARCH_PATH = $00000008; // les dependances sont cherchees a cote de la DLL
begin
  H := 0;
  ErrCode := 0;
  try
    if (ExtractFilePath(APath) = '') then
      H := LoadLibrary(PChar(APath)) // nom nu : recherche OS
    else if Win32MajorVersion >= 6 then
      H := LoadLibraryEx(PChar(APath), 0, CLOAD_WITH_ALTERED_SEARCH_PATH)
    else
      H := LoadLibrary(PChar(APath));
  except
    on E: Exception do
    begin
      LogMsg('[GGML] LoadLibrary exception sur ' + APath + ' : ' + E.Message);
      H := 0;
    end;
  end;
  Result := (H <> 0);
  if not Result then
    ErrCode := GetLastError;
end;

// AJOUT DYNAMIQUE DES TYPES LOGICIELS (FP8, NVFP4, etc.)
procedure TGGMLRegistry.AddSoftwareTypes;
const
  // Liste extensible pour les types sans support DLL natif (GGML v3 ou futurs standards)
SoftTypes:
array [0 .. 2] of record Name: string;
BlockElems, BlockBytes: Integer;
DLLDec, DLLQuantRef, DLLQuantImpl: string;
end
= ( //
//  (Name: 'F8_E4M3'; BlockElems: 1; BlockBytes: 1; DLLDec: ''; DLLQuant: ''), //
  (Name: 'F8_E5M2'; BlockElems: 1; BlockBytes: 1; DLLDec: ''; DLLQuantRef: ''; DLLQuantImpl: ''), //
  (Name: 'F8_E4M3FN'; BlockElems: 1; BlockBytes: 1; DLLDec: ''; DLLQuantRef: ''; DLLQuantImpl: ''), //
  (Name: 'F8_E5M2FN'; BlockElems: 1; BlockBytes: 1; DLLDec: ''; DLLQuantRef: ''; DLLQuantImpl: '') //
  );

var
  i, StartIdx: Integer;
begin
  StartIdx := FCount;
  SetLength(FConfigs, FCount + Length(SoftTypes));
  SetLength(FDequantProcs, FCount + Length(SoftTypes));
  SetLength(FQuantRefProcs, FCount + Length(SoftTypes));
  SetLength(FQuantImplProcs, FCount + Length(SoftTypes));

  for i := 0 to Length(SoftTypes) - 1 do
  begin
    FillChar(FConfigs[StartIdx + i].Presets, SizeOf(FConfigs[StartIdx + i].Presets), 0);
    with FConfigs[StartIdx + i] do
    begin
      Name := SoftTypes[i].Name;
      // ScalarSize := SoftTypes[i].ScalarSize;
      IsQuant := False;
      BlockElems := SoftTypes[i].BlockElems;
      BlockBytes := SoftTypes[i].BlockBytes;
      DequantPName := SoftTypes[i].DLLDec; // Vides = fallback Delphi forcé
      QuantRefName := SoftTypes[i].DLLQuantref;
      QuantImplName := SoftTypes[i].DLLQuantImpl;
    end;
  end;
  GGML_TYPE_F8_E5M2 := FCount + 0;
  GGML_TYPE_F8_E4M3FN := FCount + 1;
  GGML_TYPE_F8_E5M2FN := FCount + 2;
  FCount := FCount + Length(SoftTypes);
end;

procedure TGGMLRegistry.GetProcStatsSimple(out ND, NQRef, NQImpl: Integer);
var
  i: Integer;
begin
  ND := 0;
  NQRef := 0;
  NQImpl := 0;
  for i := 0 to FCountDLL - 1 do
  begin
    if i < Length(FQuantRefProcs) then
      if Assigned(FQuantRefProcs[i]) then
        Inc(NQRef);
    if i < Length(FQuantImplProcs) then
      if Assigned(FQuantImplProcs[i]) then
        Inc(NQImpl);
    if i < Length(FDequantProcs) then
      if Assigned(FDequantProcs[i]) then
        Inc(ND);
  end;
end;

procedure TGGMLRegistry.LoadFunsFromDLL;
var
  i, ND, NQRef, NQImpl: Integer;
  H: THandle;
  ErrCode: DWORD;
  Resolved: string;
begin
  Resolved := ResolveGgmlDllPath(FStrGGMLDLLName);
  if FLibHandle <> 0 then // deja chargee (Reload() ne sera jamais appele depuis une UI,
  begin // mais Initialize() peut letre : on ne FreeLibrary PAS -> pas d'AV
    LogMsg('[GGML] DLL deja chargee, aucune rechargement a chaud : ' + FResolvedDLL);
    Exit;
  end;

  if not TryLoadGgmlLib(Resolved, H, ErrCode) then
  begin
    // 193 = ERROR_BAD_EXE_FORMAT -> DLL 64 bits dans une app 32 bits (ou l'inverse)
    // 126 = introuvable   127 = fonction dependante manquante
    LogMsg(Format('[GGML] DLL NON chargee: %s  (demandee: %s)  err %d - %s', [Resolved, FStrGGMLDLLName, ErrCode,
      SysErrorMessage(ErrCode)]));
    LogMsg('[GGML] -> fallback 100%% natif Delphi (les types restent quantifiables).');
    FResolvedDLL := '';
    Exit; // tables du registre et fallbacks Delphi laisses intacts
  end;

  FLibHandle := H;
  FResolvedDLL := Resolved;
  GetRowSizeFunc := TRowSizeProc(GetProcAddress(H, PAnsiChar(AnsiString(FStrRowSizeFunc))));
  if not Assigned(GetRowSizeFunc) then
    LogMsg('[GGML] fonction "' + FStrRowSizeFunc + '" absente de la DLL -> taille de ligne native Delphi.');

  for i := 0 to FCountDLL - 1 do
  begin
    if FConfigs[i].DequantPName <> '' then
      FDequantProcs[i] := TDequantProc(GetProcAddress(H, PAnsiChar(AnsiString(FConfigs[i].DequantPName))))
    else
      FDequantProcs[i] := nil;

    if FConfigs[i].QuantRefName <> '' then
      FQuantRefProcs[i] := TQuantRefProc(GetProcAddress(H, PAnsiChar(AnsiString(FConfigs[i].QuantRefName))))
    else
      FQuantRefProcs[i] := nil;

    if FConfigs[i].QuantImplName <> '' then
      FQuantImplProcs[i] := TQuantImplProc(GetProcAddress(H, PAnsiChar(AnsiString(FConfigs[i].QuantImplName))))
    else
      FQuantImplProcs[i] := nil;
  end;
  GetProcStatsSimple(ND, NQRef, NQImpl);
  LogN(Format('[GGML] DLL chargee: %s | %d types, %d (ref) %d (impl) quant + %d dequant resous', [Resolved, FCountDLL, NQRef, NQImpl, ND]));
end;

// API PUBLIQUE GGML

function GGMLTypeCount: Integer;
begin
  Result := FGGMLRegistry.FCount;
end;

function GGMLTypeCountDLL: Integer;
begin
  Result := FGGMLRegistry.FCountDLL;
end;

function GGMLTypeGetListDType: TStringList;
var
  i: Integer;
begin
  Result := TStringList.Create;
  if Assigned(FGGMLRegistry) then
  begin
    for i := 0 to FGGMLRegistry.FCount - 1 do
    begin
      if (Assigned(FGGMLRegistry.FQuantRefProcs[i]) or Assigned(FGGMLRegistry.FQuantImplProcs[i]) )then // and Assigned(FGGMLRegistry.FDequantProcs[i]) ..
      begin
        Result.Add(FGGMLRegistry.FConfigs[i].Name);
      end
      else if (i < Length(GGMLTypePasImplExist)) then
      begin // Pascal Impl
        if (GGMLTypePasImplExist[i]) then
          Result.Add(CDefaultGGMLTypeNames[i]);
      end;
    end;
  end;
end;

function GGMLTypeGetListAllDType: TStringList;
var
  i: Integer;
begin
  Result := TStringList.Create;
  if Assigned(FGGMLRegistry) then
    for i := 0 to FGGMLRegistry.FCount - 1 do
    begin
      Result.Add(FGGMLRegistry.FConfigs[i].Name);
    end;
end;

function GGMLTypeToStr(VT: Integer): string;
begin
  if (FGGMLRegistry = nil) then
    Exit('UNKNOWN');
  if (VT < 0) or (VT >= FGGMLRegistry.FCount) then
    Exit('UNKNOWN');
  Result := FGGMLRegistry.FConfigs[VT].Name;
end;

function StrToGGMLType(const S: string): Integer;
var
  i: Integer;
begin
  if FGGMLRegistry = nil then
    Exit(-1);
  Result := -1;
  for i := 0 to FGGMLRegistry.FCount - 1 do
    if SameText(FGGMLRegistry.FConfigs[i].Name, S) then
    begin
      Result := i;
      Exit;
    end;
end;

function SafeTensorsDTypeToGGML(const S: string): Integer;
var
  DType: string;
begin
  DType := UpperCase(Trim(S));
  if DType = 'F32' then
    Result := GGML_TYPE_F32
  else if DType = 'F16' then
    Result := GGML_TYPE_F16
  else if DType = 'BF16' then
    Result := GGML_TYPE_BF16
  else if DType = 'I32' then
    Result := GGML_TYPE_I32
  else if DType = 'U32' then
    Result := GGML_TYPE_I32
  else if DType = 'I64' then
    Result := GGML_TYPE_I64
  else if DType = 'F64' then
    Result := GGML_TYPE_F64
  else if DType = 'I8' then
    Result := GGML_TYPE_I8
  else if DType = 'I16' then
    Result := GGML_TYPE_I16
  else if DType = 'U8' then
    Result := GGML_TYPE_I8
  else if DType = 'U16' then
    Result := GGML_TYPE_I16
  else if DType = 'F8_E4M3' then
    Result := GGML_TYPE_F8_E4M3
  else if DType = 'F8_E4M3FN' then
    Result := GGML_TYPE_F8_E4M3FN
  else if DType = 'F8_E5M2' then
    Result := GGML_TYPE_F8_E5M2
  else if DType = 'F8_E5M2FN' then
    Result := GGML_TYPE_F8_E5M2FN
  else
    Result := GGML_TYPE_F32;
end;

function GGML_BlockElems(VT: Integer): Integer;
begin
  if (VT < 0) or (VT >= FGGMLRegistry.FCount) then
    Exit(0);
  Result := FGGMLRegistry.FConfigs[VT].BlockElems;
end;

function GGML_BlockBytes(VT: Integer): Integer;
begin
  if (VT < 0) or (VT >= FGGMLRegistry.FCount) then
    Exit(0);
  Result := FGGMLRegistry.FConfigs[VT].BlockBytes;
end;

function GGML_TypeIsQuant(VT: Integer): Boolean;
begin
  if (VT < 0) or (VT >= FGGMLRegistry.FCount) then
    Exit(false);
  Result := FGGMLRegistry.FConfigs[VT].IsQuant;
end;

function GGML_RowSize(VT: Integer; n: Int64): Int64;
var
  QK, BS: Integer;
  Blocks: Int64;
begin
  if n < 0 then
    raise Exception.Create('GGML_RowSize: N < 0');
  if not GGML_TypeIsQuant(VT) then
  begin
    Result := Int64(n * GGML_BlockBytes(VT));
    Exit;
  end;
  QK := GGML_BlockElems(VT);
  BS := GGML_BlockBytes(VT);
  if (BS <= 0) or (QK <= 0) then
    raise Exception.CreateFmt('GGML_RowSize: unsupported/unknown block size for %s', [GGMLTypeToStr(VT)]);
  Blocks := (n + QK - 1) div QK;
  Result := Blocks * BS;
end;

function GGML_TensorDataSize(VT: Integer; const Shape: array of Int64): Int64;
var
  Cols, Rows, i: Int64;
begin
  if Length(Shape) = 0 then
    Exit(0);
  Cols := Shape[0]; // GGUF : dims stockées à l'envers -> [0] = longueur de ligne
  Rows := 1;
  for i := 1 to High(Shape) do
    Rows := Rows * Shape[i];
  Result := Rows * GGML_RowSize(VT, Cols);
end;

function GetDequantProc(TypeId: Integer): TDequantProc;
begin
  if not Assigned(FGGMLRegistry) then
    Exit(nil);
  if (TypeId < 0) or (TypeId >= FGGMLRegistry.FCount) then
    Exit(nil);
  if not FGGMLRegistry.FTriedIQxxInit then
  begin
    FGGMLRegistry.InitializeIQxx();
  end;
  Result := FGGMLRegistry.FDequantProcs[TypeId];
end;

function GetQuantRefProc(TypeId: Integer): TQuantRefProc;
begin
  if not Assigned(FGGMLRegistry) then
    Exit(nil);

  if (TypeId < 0) or (TypeId >= FGGMLRegistry.FCount) then
    Exit(nil);

  if not FGGMLRegistry.FTriedIQxxInit then
  begin
    FGGMLRegistry.InitializeIQxx();
  end;
  Result := FGGMLRegistry.FQuantRefProcs[TypeId];
end;

function GetQuantImplProc(TypeId: Integer): TQuantImplProc;
begin
  if not Assigned(FGGMLRegistry) then
    Exit(nil);

  if (TypeId < 0) or (TypeId >= FGGMLRegistry.FCount) then
    Exit(nil);

  if not FGGMLRegistry.FTriedIQxxInit then
  begin
    FGGMLRegistry.InitializeIQxx();
  end;
  Result := FGGMLRegistry.FQuantImplProcs[TypeId];
end;


procedure TGGMLRegistry.SavePresetsToIni();
var
  Ini: TMemIniFile;
  i, p: Integer;
  Section: string;
begin
  if ((FPresetIniPath = '')) then
    Exit;
  Ini := TMemIniFile.Create(FPresetIniPath, TEncoding.UTF8);
  try
    for i := 0 to FCount - 1 do
    begin
      if FConfigs[i].IsQuant then
      begin
        for p := 0 to Length(FConfigs[i].Presets) - 1 do
        begin
          Section := Format('Preset_Type_%d_Prof_%d', [i, p]);
          WriteQuantPreset(Ini, Section, FConfigs[i].Presets[p]);
          { Ini.WriteString(Section, 'Name', FConfigs[i].Presets[p].Name);
            Ini.WriteFloat(Section, 'Rmin', FConfigs[i].Presets[p].Rmin);
            ... }
        end;
      end;
    end;
    Ini.UpdateFile;
  finally
    Ini.Free;
  end;
end;

procedure TGGMLRegistry.LoadPresetsFromIni();
var
  Ini: TMemIniFile;
  i, p: Integer;
  Section: string;
begin
  if not((FPresetIniPath <> '') and FileExists(FPresetIniPath)) then
    Exit;
  Ini := TMemIniFile.Create(FPresetIniPath, TEncoding.UTF8);
  try
    for i := 0 to FCount - 1 do
    begin
      if FConfigs[i].IsQuant then
      begin
        for p := 0 to Length(FConfigs[i].Presets) - 1 do
        begin
          Section := Format('Preset_Type_%d_Prof_%d', [i, p]);
          if Ini.SectionExists(Section) then
          begin
            ReadQuantPreset(Ini, Section, FConfigs[i].Presets[p]);
            { FConfigs[i].Presets[p].Name := Ini.ReadString(Section, 'Name', FConfigs[i].Presets[p].Name);
              ... }
          end;
        end;
      end;
    end;
  finally
    Ini.Free;
  end;
end;

function TGGMLRegistry.HasPresetSupport(AType: Integer): Boolean;
begin
  Result := (AType >= 0) and (AType < FCount) and FConfigs[AType].IsQuant
   { and not StartsText('F8_', FConfigs[AType].Name) } ;
end;


function TGGMLRegistry.GetPreset(AType: Integer; AProfile: Integer): TQuantPreset;
var
  P: PQuantPreset;
begin
  P := GetPPreset(AType, AProfile);
  if Assigned(P) then
    Exit(P^);
  Result := GetDefaultPresetByCode(AType, Max(0, AProfile));      // fallback sans écriture
end;

function TGGMLRegistry.GetPPreset(AType: Integer; AProfile: Integer): PQuantPreset;
begin
  Result := nil;
  if not HasPresetSupport(AType) then
    Exit;
  if (AType >= 0) and (AType < FCount) and (AProfile >= 0) and (AProfile < Length(FConfigs[AType].Presets)) then
    Result := @FConfigs[AType].Presets[AProfile]
  else
    Result := nil;
end;

initialization

// TGGMLRegistry.InitGlobal;

finalization

// FreeAndNil(FRegistry);
FInitialized := false;

end.
