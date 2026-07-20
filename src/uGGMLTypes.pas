unit uGGMLTypes;

interface

uses
  Classes, SysUtils, Windows, Math, IniFiles, uGGMLConstants;

type
  // Type GGML indexé (0=F32, 2=Q4_0, etc.)
  TGGMLType = Integer;

  // Événements de progression
  TOnProgressEvent1 = procedure(const Msg: string; AIdx, ATotal: Int64) of object;
  TOnProgressEvent2 = procedure(const Msg: string; ATIdx, ATTotal, AIdx, ATotal: Int64) of object;

  // Pointeurs de procédures DLL pour quantisation/déquantisation
  TQuantProc = procedure(const src: System.PSingle; dest: PByte; nrow, n_per_row: Int64;
    weights: System.PSingle); cdecl;
  TDequantProc = procedure(const data: PByte; dest: System.PSingle; k: Int64); cdecl;
  TRowSizeProc = function(t: Integer; n: Int64): NativeUInt; cdecl;

  // Configuration dynamique par type GGML
  TGGMLTypeConfig = record
    Name: string;
    ScalarSize: Integer;
    BlockElems: Integer; // QK (Éléments par bloc)
    BlockBytes: Integer; // Octets par bloc
    IsQuant: Boolean;
    DequantPName: string;
    QuantProcName: string;
  end;

  // Registre centralisé des types GGML et chargement DLL
  TGGMLRegistry = class
  private
    FConfigs: TArray<TGGMLTypeConfig>;
    FStrGGMLDLLName: String;
    FStrRowSizeFunc: String;
    FCount: Integer;
    FCountDLL: Integer;
    FDequantProcs: TArray<TDequantProc>;
    FQuantProcs: TArray<TQuantProc>;
    FLibHandle: THandle;
    procedure LoadDefaults;
    procedure LoadFromIni(const IniPath: string);
    procedure AddSoftwareTypes;
    procedure LoadFunsFromDLL;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Initialize(const IniPath: string = '');
    class function InitGlobal(const IniPath: string = ''): TGGMLRegistry;

    property Configs: TArray<TGGMLTypeConfig> read FConfigs;
    property Count: Integer read FCount;
    property CountDLL: Integer read FCountDLL;
  end;

  // API PUBLIQUE GGML (Utilitaires bas niveau)
  // Note architecturale : Pour les opérations de haut niveau, privilégiez
  // TGGUFTensorInfo.GetRowSize() et TGGUFTensorInfo.GetTensorDataSize()
function GGMLTypeCount: Integer;
function GGMLTypeCountDLL: Integer;
function GGMLTypeToStr(VT: Integer): string;
function StrToGGMLType(const S: string): Integer;

function SafeTensorsDTypeToGGML(const S: string): Integer;

function GGML_TypeScalarSize(VT: Integer): Integer;
function GGML_BlockElems(VT: Integer): Integer;
function GGML_BlockBytes(VT: Integer): Integer;
function GGML_TypeIsQuant(VT: Integer): Boolean;

// Calculs de taille GGML standards
function GGML_RowSize(VT: Integer; n: Int64): Int64;
function GGML_TensorDataSize01(VT: Integer; const Shape: array of Int64): Int64;
function GGML_TensorDataSize1(VT: Integer; const Shape: array of Int64): Int64;

// Accès aux procédures DLL
function GetDequantProc(TypeId: Integer): TDequantProc;
function GetQuantProc(TypeId: Integer): TQuantProc;

var
  GetRowSizeFunc: TRowSizeProc;

implementation

var
  FRegistry: TGGMLRegistry;
  FInitialized: Boolean = False;

  { TGGMLRegistry }

constructor TGGMLRegistry.Create;
begin
  inherited Create;
  SetLength(FConfigs, 64);
  SetLength(FDequantProcs, 64);
  SetLength(FQuantProcs, 64);
  FCount := 0;
  FCountDLL := 0;
  FLibHandle := 0;
end;

destructor TGGMLRegistry.Destroy;
begin
  if FLibHandle <> 0 then
    FreeLibrary(FLibHandle);
  inherited Destroy;
end;

procedure TGGMLRegistry.Initialize(const IniPath: string = '');
begin
  if FLibHandle <> 0 then
  begin
    FreeLibrary(FLibHandle);
    FLibHandle := 0;
    SetLength(FDequantProcs, 0);
    SetLength(FQuantProcs, 0);
    SetLength(FConfigs, 0);
  end;
  LoadDefaults; // Base GGML native
  if (IniPath <> '') and FileExists(IniPath) then
    LoadFromIni(IniPath); // Surcharges/Extensions INI

  AddSoftwareTypes; // Types Safetensors  logiciels (FP8, futurs ...)
  LoadFunsFromDLL; // Chargement des pointeurs DLL
end;

class function TGGMLRegistry.InitGlobal(const IniPath: string = ''): TGGMLRegistry;
var
  vIniPath: String;
begin
  if not FInitialized then
  begin
    vIniPath := IniPath;
    if vIniPath = '' then
      vIniPath := IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0))) + 'cfg_ggml_type.ini';
    try
      FRegistry := TGGMLRegistry.Create;
      FRegistry.Initialize(vIniPath);
    except
      on E: Exception do
      begin
        FRegistry.Free;
        FRegistry := nil;
        raise;
      end;
    end;
    FInitialized := True;
  end;
  Result := FRegistry;
end;

procedure TGGMLRegistry.LoadDefaults;
var
  i: Integer;
begin
  FCount := 42;
  //FStrGGMLDLLName := IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0))) + CStrGGMLDLLName;
  FStrGGMLDLLName := CStrGGMLDLLName;
  SetLength(FConfigs, 64);
  for i := 0 to FCount - 1 do
  begin
    FConfigs[i].Name := CDefaultGGMLTypeNames[i];
    // Configuration par défaut des scalaires
    FConfigs[i].ScalarSize := CDefaultGGMLTypeScalarSizes[i];
    FConfigs[i].IsQuant := CDefaultGGMLTypeIsQuant[i];
    // Configuration par défaut des Quantifiés
    FConfigs[i].BlockElems := CDefaultGGMLTypeBlockElems[i];
    FConfigs[i].BlockBytes := CDefaultGGMLTypeBlockBytes[i];
    FConfigs[i].DequantPName := CDefaultGGMLTypeDLLFunDequant[i];
    FConfigs[i].QuantProcName := CDefaultGGMLTypeDLLFunQuant[i];
  end;
end;

procedure TGGMLRegistry.LoadFromIni(const IniPath: string);
var
  Ini: TIniFile;
  i, Count, BlockEl, BlockBy: Integer;
  ProcName: AnsiString;
  ProcPtr: Pointer;
begin
  Ini := TIniFile.Create(IniPath);
  try
    Count := Ini.ReadInteger('General', 'TypeCount', 0);
    if Count > 0 then
    begin
      FCount := Count;
      FCountDLL := Count;
      SetLength(FConfigs, Count);
      FStrGGMLDLLName := Ini.ReadString('General', 'DLLName', CStrGGMLDLLName);
      FStrRowSizeFunc := Ini.ReadString('DLLFunctions', 'RowSize', 'ggml_row_size');
      for i := 0 to Count - 1 do
      begin
        FConfigs[i].Name := Ini.ReadString('Types', IntToStr(i), FConfigs[i].Name);
        FConfigs[i].ScalarSize := Ini.ReadInteger('ScalarSizes', IntToStr(i), FConfigs[i].ScalarSize);
        FConfigs[i].IsQuant := Ini.ReadBool('IsQuant', IntToStr(i), FConfigs[i].IsQuant);
        FConfigs[i].BlockElems := Ini.ReadInteger('BlockElems', IntToStr(i), FConfigs[i].BlockElems);
        FConfigs[i].BlockBytes := Ini.ReadInteger('BlockBytes', IntToStr(i), FConfigs[i].BlockBytes);
        FConfigs[i].DequantPName := Ini.ReadString('DLLFunctions', 'Dequant.' + IntToStr(i), FConfigs[i].DequantPName);
        FConfigs[i].QuantProcName := Ini.ReadString('DLLFunctions', 'Quant.' + IntToStr(i), FConfigs[i].QuantProcName);
      end;
    end;
  finally
    Ini.Free;
  end;
end;

// AJOUT DYNAMIQUE DES TYPES LOGICIELS (FP8, NVFP4, etc.)
procedure TGGMLRegistry.AddSoftwareTypes;
const
  // Liste extensible pour les types sans support DLL natif (GGML v3 ou futurs standards)
SoftTypes:
array [0 .. 3] of record Name: string;
ScalarSize, BlockElems, BlockBytes: Integer;
DLLDec, DLLQuant: string;
end
= ( //
  (Name: 'F8_E4M3'; ScalarSize: 1; BlockElems: 256; BlockBytes: 256; DLLDec: ''; DLLQuant: ''), //
  (Name: 'F8_E5M2'; ScalarSize: 1; BlockElems: 256; BlockBytes: 256; DLLDec: ''; DLLQuant: ''), //
  (Name: 'F8_E4M3FN'; ScalarSize: 1; BlockElems: 256; BlockBytes: 256; DLLDec: ''; DLLQuant: ''), //
  (Name: 'F8_E5M2FN'; ScalarSize: 1; BlockElems: 256; BlockBytes: 256; DLLDec: ''; DLLQuant: '') //
  );

var
  i, StartIdx: Integer;
begin
  StartIdx := FCount;
  SetLength(FConfigs, FCount + Length(SoftTypes));
  for i := 0 to Length(SoftTypes) - 1 do
  begin
    with FConfigs[StartIdx + i] do
    begin
      Name := SoftTypes[i].Name;
      ScalarSize := SoftTypes[i].ScalarSize;
      IsQuant := True; // Traités comme quantifiés pour le calcul de bloc
      BlockElems := SoftTypes[i].BlockElems;
      BlockBytes := SoftTypes[i].BlockBytes;
      DequantPName := SoftTypes[i].DLLDec; // Vides = fallback Delphi forcé
      QuantProcName := SoftTypes[i].DLLQuant;
    end;
  end;
  GGML_TYPE_F8_E4M3 := FCount + 0;
  GGML_TYPE_F8_E5M2 := FCount + 1;
  GGML_TYPE_F8_E4M3FN := FCount + 2;
  GGML_TYPE_F8_E5M2FN := FCount + 3;
  FCount := FCount + Length(SoftTypes);
end;

procedure TGGMLRegistry.LoadFunsFromDLL;
var
  i: Integer;
  ProcName: AnsiString;
  ProcPtr: Pointer;
begin
  try
    FLibHandle := LoadLibrary(PChar(FStrGGMLDLLName));
    if FLibHandle <> 0 then
    begin
      ProcName := FStrRowSizeFunc;
      if ProcName <> '' then
        GetRowSizeFunc := GetProcAddress(FLibHandle, PAnsiChar(ProcName));
      for i := 0 to FCountDLL - 1 do
      begin
        ProcName := FConfigs[i].DequantPName;
        if ProcName <> '' then
        begin
          ProcPtr := GetProcAddress(FLibHandle, PAnsiChar(ProcName));
          if ProcPtr <> nil then
            FDequantProcs[i] := TDequantProc(ProcPtr);
        end;
        ProcName := FConfigs[i].QuantProcName;
        if ProcName <> '' then
        begin
          ProcPtr := GetProcAddress(FLibHandle, PAnsiChar(ProcName));
          if ProcPtr <> nil then
            FQuantProcs[i] := TQuantProc(ProcPtr);
        end;
      end;
    end;
  finally
  end;
end;

// === API PUBLIQUE GGML ===

function GGMLTypeCount: Integer;
begin
  Result := FRegistry.FCount;
end;

function GGMLTypeCountDLL: Integer;
begin
  Result := FRegistry.FCountDLL;
end;

function GGMLTypeToStr(VT: Integer): string;
begin
  if (VT < 0) or (VT >= FRegistry.FCount) then
    Exit('UNKNOWN');
  Result := FRegistry.FConfigs[VT].Name;
end;

function StrToGGMLType(const S: string): Integer;
var
  i: Integer;
begin
  Result := -1;
  for i := 0 to FRegistry.FCount - 1 do
    if SameText(FRegistry.FConfigs[i].Name, S) then
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

function GGML_TypeScalarSize(VT: Integer): Integer;
begin
  if (VT < 0) or (VT >= FRegistry.FCount) then
    Exit(0);
  Result := FRegistry.FConfigs[VT].ScalarSize;
end;

function GGML_BlockElems(VT: Integer): Integer;
begin
  if (VT < 0) or (VT >= FRegistry.FCount) then
    Exit(0);
  Result := FRegistry.FConfigs[VT].BlockElems;
end;

function GGML_BlockBytes(VT: Integer): Integer;
begin
  if (VT < 0) or (VT >= FRegistry.FCount) then
    Exit(0);
  Result := FRegistry.FConfigs[VT].BlockBytes;
end;

function GGML_TypeIsQuant(VT: Integer): Boolean;
begin
  if (VT < 0) or (VT >= FRegistry.FCount) then
    Exit(False);
  Result := FRegistry.FConfigs[VT].IsQuant;
end;

function Mul64(A, B: Int64): Int64;
begin
  if (A = 0) or (B = 0) then
    Result := 0
  else
  begin
    if (Abs(B) = 0) or (Abs(A) > High(Int64) div Abs(B)) then
      raise Exception.Create('Int64 overflow in multiplication');
    Result := A * B;
  end;
end;

function GGML_RowSize(VT: Integer; n: Int64): Int64;
var
  QK, BS: Integer;
  Blocks: Int64;
begin
  Result := 0;
  if n < 0 then
    raise Exception.Create('GGML_RowSize: N < 0');
  if not GGML_TypeIsQuant(VT) then
  begin
    Result := Mul64(n, GGML_TypeScalarSize(VT));
    Exit;
  end;
  QK := GGML_BlockElems(VT);
  BS := GGML_BlockBytes(VT);
  if (BS <= 0) or (QK <= 0) then
    raise Exception.CreateFmt('GGML_RowSize: unsupported/unknown block size for %s', [GGMLTypeToStr(VT)]);
  Blocks := (n + QK - 1) div QK;
  Result := Mul64(Blocks, BS);
end;

function GGML_TensorDataSize01(VT: Integer; const Shape: array of Int64): Int64;
var
  Rows, LastDim: Int64;
  i: Integer;
begin
  if Length(Shape) = 0 then
    raise Exception.Create('GGML_TensorDataSize: empty shape');
  for i := 0 to High(Shape) do
    if Shape[i] < 0 then
      raise Exception.Create('GGML_TensorDataSize: negative dim');
  LastDim := Shape[High(Shape)];
  Rows := 1;
  for i := 0 to High(Shape) - 1 do
    Rows := Mul64(Rows, Shape[i]);
  Result := Mul64(Rows, GGML_RowSize(VT, LastDim));
end;

function GGML_TensorDataSize1(VT: Integer; const Shape: array of Int64): Int64;
var
  TotalElems, QK, BS, Blocks: Int64;
  i: Integer;
begin
  if Length(Shape) = 0 then
  begin
    Result := 0;
    Exit;
  end;

  // Calcul du nombre total d'éléments
  TotalElems := 1;
  for i := 0 to High(Shape) do
    TotalElems := Mul64(TotalElems, Shape[i]);

  // Types non quantifiés
  if not GGML_TypeIsQuant(VT) then
  begin
    Result := TotalElems * GGML_TypeScalarSize(VT);
    Exit;
  end;

  // Calcul pour types quantifiés
  QK := GGML_BlockElems(VT);
  BS := GGML_BlockBytes(VT);
  if (QK <= 0) or (BS <= 0) then
    raise Exception.CreateFmt('GGML_TensorDataSize: invalid block params for %s', [GGMLTypeToStr(VT)]);

  // Calculer le nombre de blocs nécessaires pour TOUS les éléments
  // On arrondit au supérieur pour ne pas perdre de données
  Blocks := (TotalElems + QK - 1) div QK;

  // Taille totale = Nombre de blocs * Taille d'un bloc
  Result := Blocks * BS;
end;

function GetDequantProc(TypeId: Integer): TDequantProc;
begin
  if (TypeId < 0) or (TypeId >= FRegistry.FCount) then
    Exit(nil);
  Result := FRegistry.FDequantProcs[TypeId];
end;

function GetQuantProc(TypeId: Integer): TQuantProc;
begin
  if (TypeId < 0) or (TypeId >= FRegistry.FCount) then
    Exit(nil);
  Result := FRegistry.FQuantProcs[TypeId];
end;

initialization

TGGMLRegistry.InitGlobal;

finalization

FreeAndNil(FRegistry);
FInitialized := False;

end.
