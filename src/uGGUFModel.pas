unit uGGUFModel;

interface

uses
  Classes, SysUtils, Contnrs, uGGUFTypes, uGGMLTypes, uGGMLConstants;

type
  EGGUF = class(Exception);

  TGGUFTensorInfo = class
  private

  public
    Name: AnsiString;
    NameOrg: AnsiString;
    NameMap: AnsiString;
    IsNameMapped: Boolean;
    NDims: Cardinal;
    TotElems: Int64;
    Cols, Rows: Cardinal;
    Dims: array of Int64;
    TensorType: Integer; // Type ACTUEL (peut être celui d'origine ou le type cible si marqué)
    IsSafetensors: Boolean;
    TensorTypeOrg: Integer; // Type GGML original
    IsConverted: Boolean; // True si ce tenseur doit être converti lors de l'écriture / Affichage
    IsTransposed: Boolean; // Indique que le tenseur est actuellement "patché" par un fichier temporaire
    TransposFile: string; // Chemin du fichier temporaire (ex: ./tmp/tensor_name.bin)

    Offset: Int64;
    SourceOffset: Int64;
    TensorDataFilePos: Int64;
    ByteSize: UInt64;
    ByteSizeOrg: UInt64; // Taille des données brutes avant toute quantification
    BlockElems: Integer;
    BlockBytes: Integer;
    SourceFile: string; // utile merge multi-sources
    SourceId: Word; // ID source d’origine (1:Inp1 ou 2:Inp2, ...)

    LayerCount: Integer; // Ex: 48 , ou 1  si pas de couche
    LayerIndex: Integer; // Ex: 0, 10, -1 si pas de numéro

    TensorPatternName: string; // Ex: 'attn_norm.weight', 'ffn_gate.weight'
    PatternGlobalSize: Int64; // Taille totale de tous les tenseurs de ce type dans tout le modèle
    Keep: Boolean;
    SeriesColor: Integer;

    constructor Create;
    destructor Destroy; override;
    function GetTotalElements: Int64;
    function GetCols(): Int64;
    function GetRows(): Int64;
    function CalcSizeByGGML(): UInt64;
    function Clone: TGGUFTensorInfo;

    class function GetRowSize(VT: Integer; n: Int64): Int64;
    class function GetTensorDataSize(VT: Integer; const Shape: array of Int64): Int64;
  end;

  TGGUFFile = class
  public
    Version: Cardinal;
    KVCount: UInt64;
    Alignment: Cardinal; // general.alignment si présent, sinon 32
    KVs: TObjectList; // TGGUFKeyValue (OwnsObjects=True)
    Tensors: TObjectList; // TGGUFTensorInfo
    TensorCount: Int64;

    TensorDataFilePos: Int64; // position absolue du tensor_data dans le fichier source
    TensorDataSizeBytes: Int64;
    FileDataSizeBytes: Int64;
    InitHeaderPartSizeBytes: Int64;

    constructor Create;
    destructor Destroy; override;

    procedure SetKV_U16(const Key: AnsiString; v: Word);
    procedure SetKV_U32(const Key: AnsiString; v: Cardinal);
    procedure SetKV_I32(const Key: AnsiString; v: Integer);
    procedure SetKV_String(const Key: AnsiString; const v: AnsiString);
    class function KVShouldIgnoreInMerge(const Key: string): Boolean;

    function FindKV(const Key: AnsiString): TGGUFKeyValue;
    function HasKV(const Key: AnsiString): Boolean;
    function KVAsToStringList: TStringList;
    function CloneVersOnly: TGGUFFile;
    function CloneMetaOnly: TGGUFFile; // clone KVs + tensor headers (sans toucher aux bytes)
    function Clone: TGGUFFile;

    procedure CalculateAllTensorSizes;
    procedure CalculateUnknownTensorSizes; // traite TOUT si un type est inconnu
  end;

implementation

{ TGGUFTensorInfo }
constructor TGGUFTensorInfo.Create;
begin
  inherited Create;
  TotElems := 0;
  Offset := 0;
  SourceOffset := 0;
  TensorDataFilePos := 0;
  ByteSize := 0;
  ByteSizeOrg := 0;
  SourceFile := '';
  LayerCount := 1;
  LayerIndex := -1;
  TensorPatternName := '';
  PatternGlobalSize := 0;
  TensorType := 0;
  TensorTypeOrg := 0;
  IsConverted := False;
  IsTransposed := False;
  TransposFile := '';
end;

destructor TGGUFTensorInfo.Destroy;
begin
  SetLength(Dims, 0);
  inherited;
end;

function TGGUFTensorInfo.GetTotalElements: Int64;
begin
  Result := TotElems;
  if TotElems <= 0 then
  begin
    GetCols;
    Result := TotElems;
  end;
end;

function TGGUFTensorInfo.GetCols: Int64;
var
  i: Integer;
begin
  Result := Cols;
  if Cols <= 0 then
  begin
    if Integer(NDims) > 0 then
    begin
      Cols := Dims[High(Dims)];
      Rows := 1;
      if NDims > 1 then
        for i := 0 to NDims - 2 do
          Rows := Rows * Dims[i];
    end
    else
    begin
      Rows := 1;
      Cols := 1;
      TotElems := 1;
    end;
    TotElems := Cols * Rows;
    Result := Cols;
  end;
end;

function TGGUFTensorInfo.GetRows: Int64;
var
  i: Integer;
begin
  Result := Rows;
  if Rows <= 0 then
  begin
    if Integer(NDims) > 0 then
    begin
      Cols := Dims[0];
      // Cols := Dims[High(Dims)];
      Rows := 1;
      for i := 1 to Length(Dims) - 1 do
        // for i := 0 to NDims - 2 do
        Rows := Rows * Dims[i];
    end
    else
    begin
      Rows := 1;
      Cols := 1;
      TotElems := 1;
    end;
    TotElems := Cols * Rows;
    Result := Rows;
  end;
end;

function TGGUFTensorInfo.CalcSizeByGGML: UInt64;
begin
  if (TensorType < 0) or (TensorType >= GGMLTypeCount) then
    Exit(0);
  if GGML_TypeIsQuant(TensorType) then
    Result := GGML_TensorDataSize1(TensorType, Dims)
  else
    Result := TotElems * GGML_TypeScalarSize(TensorType);
end;

class function TGGUFTensorInfo.GetRowSize(VT: Integer; n: Int64): Int64;
begin
  Result := GGML_RowSize(VT, n);
end;

class function TGGUFTensorInfo.GetTensorDataSize(VT: Integer; const Shape: array of Int64): Int64;
begin
  Result := GGML_TensorDataSize1(VT, Shape);
end;

function TGGUFTensorInfo.Clone: TGGUFTensorInfo;
var
  i: Integer;
begin
  Result := TGGUFTensorInfo.Create;
  Result.Name := Name;
  Result.NDims := NDims;
  SetLength(Result.Dims, NDims);
  for i := 0 to Integer(NDims) - 1 do
    Result.Dims[i] := Dims[i];
  Result.Cols := Cols;
  Result.Rows := Rows;
  Result.TotElems := TotElems;
  Result.TensorType := TensorType;
  Result.IsSafetensors := IsSafetensors;
  Result.TensorTypeOrg := TensorTypeOrg;
  Result.IsConverted := IsConverted;
  Result.Offset := Offset;
  Result.SourceOffset := SourceOffset;
  Result.TensorDataFilePos := TensorDataFilePos;

  Result.ByteSize := ByteSize;
  Result.ByteSizeOrg := ByteSizeOrg;
  Result.SourceFile := SourceFile;
  Result.SourceId := SourceId;

  Result.NameOrg := NameOrg;
  Result.NameMap := NameMap;
  Result.IsTransposed := IsTransposed;
  Result.TransposFile := TransposFile;

  Result.LayerCount := LayerCount;
  Result.LayerIndex := LayerIndex;
  Result.TensorPatternName := TensorPatternName;
  Result.PatternGlobalSize := PatternGlobalSize;
  Result.Keep := Keep;
  Result.SeriesColor := SeriesColor;
end;

{ TGGUFFile }
constructor TGGUFFile.Create;
begin
  inherited Create;
  Alignment := 32;
  KVs := TObjectList.Create(True);
  Tensors := TObjectList.Create(True);
  TensorDataFilePos := 0;
  TensorDataSizeBytes := 0;
  FileDataSizeBytes := 0;
end;

destructor TGGUFFile.Destroy;
begin
  KVs.Free;
  Tensors.Free;
  inherited;
end;

function TGGUFFile.FindKV(const Key: AnsiString): TGGUFKeyValue;
var
  i: Integer;
  KV: TGGUFKeyValue;
begin
  Result := nil;
  for i := 0 to KVs.Count - 1 do
  begin
    KV := TGGUFKeyValue(KVs[i]);
    if KV.Key = Key then
    begin
      Result := KV;
      Exit;
    end;
  end;
end;

function TGGUFFile.HasKV(const Key: AnsiString): Boolean;
var
  i: Integer;
  KV: TGGUFKeyValue;
begin
  Result := False;
  for i := 0 to KVs.Count - 1 do
  begin
    KV := TGGUFKeyValue(KVs[i]);
    if KV.Key = Key then
    begin
      Result := True;
      Exit;
    end;
  end;
end;

function TGGUFFile.KVAsToStringList: TStringList;
var
  i: Integer;
  KV: TGGUFKeyValue;
begin
  Result := TStringList.Create;
  Result.CaseSensitive := True;
  Result.NameValueSeparator := '=';
  for i := 0 to KVs.Count - 1 do
  begin
    KV := TGGUFKeyValue(KVs[i]);
    Result.Values[string(KV.Key)] := KV.Val.AsStrFull;
  end;
end;

procedure TGGUFFile.SetKV_U16(const Key: AnsiString; v: Word);
var
  KV: TGGUFKeyValue;
begin
  KV := FindKV(Key);
  if not Assigned(KV) then
  begin
    KV := TGGUFKeyValue.Create;
    KV.Key := Key;
    KV.Val.Free;
    KV.Val := TGGUFValue.Create;
    KVs.Add(KV);
  end;
  KV.Val.ValueType := gvt_UINT16;
  KV.Val.VU16 := v;
end;

procedure TGGUFFile.SetKV_U32(const Key: AnsiString; v: Cardinal);
var
  KV: TGGUFKeyValue;
begin
  KV := FindKV(Key);
  if not Assigned(KV) then
  begin
    KV := TGGUFKeyValue.Create;
    KV.Key := Key;
    KV.Val.Free;
    KV.Val := TGGUFValue.Create;
    KVs.Add(KV);
  end;
  KV.Val.ValueType := gvt_UINT32;
  KV.Val.VU32 := v;
end;

procedure TGGUFFile.SetKV_I32(const Key: AnsiString; v: Integer);
var
  KV: TGGUFKeyValue;
begin
  KV := FindKV(Key);
  if not Assigned(KV) then
  begin
    KV := TGGUFKeyValue.Create;
    KV.Key := Key;
    KV.Val.Free;
    KV.Val := TGGUFValue.Create;
    KVs.Add(KV);
  end;
  KV.Val.ValueType := gvt_INT32;
  KV.Val.VI32 := v;
end;

procedure TGGUFFile.SetKV_String(const Key: AnsiString; const v: AnsiString);
var
  KV: TGGUFKeyValue;
begin
  KV := FindKV(Key);
  if not Assigned(KV) then
  begin
    KV := TGGUFKeyValue.Create;
    KV.Key := Key;
    KV.Val.Free;
    KV.Val := TGGUFValue.Create;
    KVs.Add(KV);
  end;
  KV.Val.ValueType := gvt_STRING;
  KV.Val.VStr := v;
  KV.Keep := True;
end;

class function TGGUFFile.KVShouldIgnoreInMerge(const Key: string): Boolean;
begin
  // ignorer tout ce qui est split.*
  if (Length(Key) >= 6) and (Copy(Key, 1, 6) = 'split.') then
  begin
    Result := True;
    Exit;
  end;
  Result := False;
end;

function CompareTensorBySourceOffset(Item1, Item2: Pointer): Integer;
var
  A, B: TGGUFTensorInfo;
begin
  A := TGGUFTensorInfo(Item1);
  B := TGGUFTensorInfo(Item2);
  if A.SourceOffset < B.SourceOffset then
    Result := -1
  else if A.SourceOffset > B.SourceOffset then
    Result := 1
  else
    Result := 0;
end;

procedure TGGUFFile.CalculateAllTensorSizes;
var
  i: Integer;
  T: TGGUFTensorInfo;
  HasUnknownType: Boolean;
begin
  // Calcul exact via GGML pour TOUS les tenseurs
  for i := 0 to Tensors.Count - 1 do
  begin
    T := TGGUFTensorInfo(Tensors[i]);
    T.ByteSize := TGGUFTensorInfo.GetTensorDataSize(T.TensorType, T.Dims);
    if T.ByteSize > 0 then
      T.ByteSizeOrg := T.ByteSize;
  end;

  // Vérifier s'il existe un type non reconnu
  HasUnknownType := False;
  for i := 0 to Tensors.Count - 1 do
    if TGGUFTensorInfo(Tensors[i]).ByteSize = 0 then
    begin
      HasUnknownType := True;
      Break;
    end;

  // Si tout est reconnu, on s'arrête ici (pas de fallback inutile)
  if not HasUnknownType then
    Exit;

  // Si un seul type est inconnu, on recalcule TOUT via la chaîne d'offsets
  CalculateUnknownTensorSizes;
end;

procedure TGGUFFile.CalculateUnknownTensorSizes;
var
  Sorted: TObjectList;
  i: Integer;
  T, NextT: TGGUFTensorInfo;
  EstSize: Int64;
begin
  Sorted := TObjectList.Create(False);
  try
    // On trie TOUS les tenseurs pour préserver la chaîne
    for i := 0 to Tensors.Count - 1 do
      Sorted.Add(Tensors[i]);
    Sorted.Sort(@CompareTensorBySourceOffset);

    for i := 0 to Sorted.Count - 1 do
    begin
      T := TGGUFTensorInfo(Sorted[i]);
      if i < Sorted.Count - 1 then
        NextT := TGGUFTensorInfo(Sorted[i + 1])
      else
        NextT := nil;

      if Assigned(NextT) then
      begin
        // Offset(N+1) - Offset(N) = Taille_réelle + Padding_GGUF
        // Comme les deux offsets sont alignés, la différence est un multiple d'Alignment.
        // On utilise cette valeur comme taille estimée sûre (inclut le padding max).
        EstSize := NextT.SourceOffset - T.SourceOffset;
        if EstSize > 0 then
        begin
          T.ByteSize := EstSize;
          T.ByteSizeOrg := EstSize;
        end;
      end
      else
      begin
        // Dernier tenseur du shard : taille = fin du blob - offset
        T.ByteSize := TensorDataSizeBytes - T.SourceOffset;
        T.ByteSizeOrg := T.ByteSize;
      end;
    end;
  finally
    Sorted.Free;
  end;
end;

function TGGUFFile.CloneVersOnly: TGGUFFile;
var
  i: Integer;
begin
  Result := TGGUFFile.Create;
  Result.Version := Version;
  Result.Alignment := Alignment;
end;

function TGGUFFile.CloneMetaOnly: TGGUFFile;
var
  i: Integer;
begin
  Result := TGGUFFile.Create;
  Result.Version := Version;
  Result.Alignment := Alignment;
  for i := 0 to KVs.Count - 1 do
    if not KVShouldIgnoreInMerge(string(TGGUFKeyValue(KVs[i]).Key)) then
      Result.KVs.Add(TGGUFKeyValue(KVs[i]).Clone);
end;

function TGGUFFile.Clone: TGGUFFile;
var
  i: Integer;
begin
  Result := TGGUFFile.Create;
  Result.Version := Version;
  Result.Alignment := Alignment;
  Result.TensorDataFilePos := TensorDataFilePos;
  Result.TensorDataSizeBytes := TensorDataSizeBytes;
  Result.FileDataSizeBytes := FileDataSizeBytes;

  for i := 0 to KVs.Count - 1 do
    if not KVShouldIgnoreInMerge(string(TGGUFKeyValue(KVs[i]).Key)) then
      Result.KVs.Add(TGGUFKeyValue(KVs[i]).Clone);
  for i := 0 to Tensors.Count - 1 do
    Result.Tensors.Add(TGGUFTensorInfo(Tensors[i]).Clone);
end;

end.
