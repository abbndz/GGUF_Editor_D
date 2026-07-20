unit uTensorTranspose;

interface

uses
  Classes, SysUtils, Generics.Collections, uGGUFModel, uGGUFTypes, uGGMLTypes, uMath, uBinIO, uLog, uGgmlQuants,
  System.SyncObjs, System.Threading; // Nécessaire pour TParallel et Max;  System.Math

type
  TProgressProc = reference to procedure(AProgress: Integer);
  // TProgressProc = procedure(Percent: Integer) of object;

  TTransposeEngine = class
  private
    FCriticalSection: TCriticalSection;
  public
    constructor Create;
    destructor Destroy; override;
    class function GetModelTmpDir(const ModelFileName, TensorName: string): string; static;
    class function SetTransposDims(var T: TGGUFTensorInfo): string;
    class procedure ExecuteTransposition1(const T: TGGUFTensorInfo; const SourceStream: TStream;
      const ModelFileName: string; UseDLL: Boolean = False; const OnProgress: TProgressProc = nil); static;
    class procedure ExecuteTransposition2(const T: TGGUFTensorInfo; const SourceStream: TStream;
      const ModelFileName: string; UseDLL: Boolean = False; const OnProgress: TProgressProc = nil); static;
  end;

implementation

constructor TTransposeEngine.Create;
begin
  inherited;
  FCriticalSection := TCriticalSection.Create;
end;

destructor TTransposeEngine.Destroy;
begin
  FCriticalSection.Free;
  inherited;
end;

class function TTransposeEngine.GetModelTmpDir(const ModelFileName: string; const TensorName: string): string;
var
  ModelName, BaseDir: string;
begin
  BaseDir := IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0))) + 'tmp';
  ModelName := ChangeFileExt(ExtractFileName(ModelFileName), '');
  Result := IncludeTrailingPathDelimiter(BaseDir + PathDelim + ModelName);
  if not DirectoryExists(Result) then
    ForceDirectories(Result);
  Result := Result + TensorName + '_transposed.bin';
end;

class function TTransposeEngine.SetTransposDims(var T: TGGUFTensorInfo): string;
var
  TempR: Int64;
begin
  // Si le tenseur est 2D, on inverse aussi Dims[0] et Dims[1]
  // Échanger Rows/Cols et Dims pour cohérence avec le viewer
  if T.NDims = 2 then
  begin
    T.IsTransposed := Not T.IsTransposed;
    TempR := T.Rows;
    T.Rows := T.Cols;
    T.Cols := TempR;
    TempR := T.Dims[0];
    T.Dims[0] := T.Dims[1];
    T.Dims[1] := TempR;
  end;
end;

class procedure TTransposeEngine.ExecuteTransposition1(const T: TGGUFTensorInfo; const SourceStream: TStream;
  const ModelFileName: string; UseDLL: Boolean = False; const OnProgress: TProgressProc = nil);
var
  Rows, Cols, TotalElems: Int64;
  I, J: Integer;
  SrcF32, DstF32: TArray<Single>;
  SrcRaw, DstRaw: TArray<Byte>;
  TmpPath: string;
  fStream: TFileStream;
  ProgressStep: Integer;
  TotalBytes: Int64;
begin
  if not Assigned(T) or (T.NDims < 2) or (T.TotElems <= 0) then
    raise Exception.Create('Tenseur invalide pour transposition.');

  Cols := T.Dims[0];
  Rows := T.Dims[1];
  TotalElems := Rows * Cols;

  TotalBytes := T.ByteSizeOrg;
  if TotalBytes <= 0 then
    TotalBytes := TGGUFTensorInfo.GetTensorDataSize(T.TensorTypeOrg, T.Dims);

  // ÉTAPE 1 : LECTURE ET DÉQUANTIFICATION
  SourceStream.Position := T.TensorDataFilePos + T.SourceOffset;

  SetLength(SrcRaw, TotalBytes);
  try
    SourceStream.ReadBuffer(SrcRaw[0], TotalBytes);

    SetLength(SrcF32, TotalElems);
    // On convertit de Raw -> F32
    DeQuant(@SrcRaw[0], @SrcF32[0], TotalElems, T.TensorTypeOrg, UseDLL);
  finally
    // On vide SrcRaw IMMÉDIATEMENT après la déquantification
    SetLength(SrcRaw, 0);
  end;

  // ÉTAPE 2 : TRANSPOSITION
  try
    SetLength(DstF32, TotalElems);
    ProgressStep := Max(1, Rows div 100);

    for I := 0 to Rows - 1 do
    begin
      for J := 0 to Cols - 1 do
      begin
        // Transposition mathématique
        DstF32[J * Rows + I] := SrcF32[I * Cols + J];
      end;

      if Assigned(OnProgress) and ((I mod ProgressStep = 0) or (I = Rows - 1)) then
        OnProgress((I + 1) * 100 div Rows);
    end;
  finally
    // On vide SrcF32 IMMÉDIATEMENT après la transposition
    SetLength(SrcF32, 0);
  end;

  // ÉTAPE 3 : RE-QUANTIFICATION ET ÉCRITURE
  try
    SetLength(DstRaw, TotalBytes);
    // On convertit de F32 (transposé) -> Raw
    Quant(@DstF32[0], @DstRaw[0], TotalElems, T.TensorTypeOrg, UseDLL);
  finally
    // On vide DstF32 IMMÉDIATEMENT après la quantification
    SetLength(DstF32, 0);
  end;

  // ÉTAPE 4 : SAUVEGARDE ---
  TmpPath := GetModelTmpDir(ModelFileName, string(T.NameOrg));
  fStream := TFileStream.Create(TmpPath, fmCreate);
  try
    fStream.WriteBuffer(DstRaw[0], TotalBytes);
  finally
    fStream.Free;
    // On vide le dernier buffer
    SetLength(DstRaw, 0);
  end;
end;

class procedure TTransposeEngine.ExecuteTransposition2(const T: TGGUFTensorInfo; const SourceStream: TStream;
  const ModelFileName: string; UseDLL: Boolean = False; const OnProgress: TProgressProc = nil);
var
  Rows, Cols, TotalElems: Int64;
  I, J, BI, Bjj: Integer;
  SrcF32, DstF32: TArray<Single>;
  SrcRaw, DstRaw: TArray<Byte>;
  TmpPath: string;
  fStream: TFileStream;
  TotalBytes: Int64;
  BlockSize: Integer;
const
  BLOCK_SIZE = 32; // Taille du bloc pour optimiser le cache L1/L2
begin
  if not Assigned(T) or (T.NDims < 2) or (T.TotElems <= 0) then
    raise Exception.Create('Tenseur invalide pour transposition.');

  Cols := T.Dims[0];
  Rows := T.Dims[1];
  TotalElems := Rows * Cols;

  TotalBytes := T.ByteSizeOrg;
  if TotalBytes <= 0 then
    TotalBytes := TGGUFTensorInfo.GetTensorDataSize(T.TensorTypeOrg, T.Dims);

  // 1. Lecture du flux
  SourceStream.Position := T.TensorDataFilePos + T.SourceOffset;
  SetLength(SrcRaw, TotalBytes);
  SourceStream.ReadBuffer(SrcRaw[0], TotalBytes);

  // 2. Déquantification
  SetLength(SrcF32, TotalElems);
  DeQuant(@SrcRaw[0], @SrcF32[0], TotalElems, T.TensorTypeOrg, UseDLL);

  // Libération précoce de SrcRaw pour gagner de la place
  SetLength(SrcRaw, 0);
  SrcRaw := nil;

  // 3. Transposition par blocs (Tiled Transpose) + Parallélisme
  SetLength(DstF32, TotalElems);
  BlockSize := BLOCK_SIZE;

  // On traite la matrice par blocs de 32x32 pour rester dans le cache CPU
  TParallel.For(0, (Rows - 1) div BlockSize,
    procedure(BI: Integer)
    var
      I, J, Bjj, IEnd, JEnd: Integer;
      RowStart, ColStart: Integer;
    begin
      RowStart := BI * BlockSize;
      IEnd := Min(RowStart + BlockSize, Integer(Rows));

      for Bjj := 0 to (Cols - 1) div BlockSize do
      begin
        ColStart := Bjj * BlockSize;
        JEnd := Min(ColStart + BlockSize, Integer(Cols));

        // Transposition du bloc local
        for I := RowStart to IEnd - 1 do
        begin
          for J := ColStart to JEnd - 1 do
          begin
            // L'écriture est maintenant plus "locale" dans le cache
            DstF32[J * Rows + I] := SrcF32[I * Cols + J];
          end;
        end;
      end;
    end);

  if Assigned(OnProgress) then
    OnProgress(100);

  // 4. Re-quantification
  SetLength(DstRaw, TotalBytes);
  Quant(@DstF32[0], @DstRaw[0], TotalElems, T.TensorTypeOrg, UseDLL);

  // 5. Écriture
  TmpPath := GetModelTmpDir(ModelFileName, string(T.NameOrg));
  fStream := TFileStream.Create(TmpPath, fmCreate);
  try
    fStream.WriteBuffer(DstRaw[0], TotalBytes);
  finally
    fStream.Free;
  end;
end;

end.
