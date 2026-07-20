unit uGGUFReader;

interface

uses
  Classes, SysUtils, Contnrs, uBinIO, uGGUFModel, uGGUFTypes, uGGMLTypes, uGgufStrUtils, uLangManager;
// IfThen : StrUtils,

type
  TGGUFReader = class
  public
    class function LoadFromFile(const FileName: string; OnProgress: TOnProgressEvent1 = nil): TGGUFFile;
    class function LoadFromSingleFile(const FileName: string; OnProgress: TOnProgressEvent1 = nil): TGGUFFile;
  end;

implementation

function ReadKVValue(R: TBinReader; ValueType: TGGUFValueType): TGGUFValue;
var
  i: Integer;
  A: TGGUFArray;
  ElemT: TGGUFValueType;
  Count: UInt64;
  V: TGGUFValue;
begin
  V := TGGUFValue.Create;
  V.ValueType := ValueType;

  case ValueType of
    gvt_UINT8:
      V.VU8 := R.ReadU8;
    gvt_INT8:
      V.VI8 := R.ReadI8;
    gvt_UINT16:
      V.VU16 := R.ReadU16;
    gvt_INT16:
      V.VI16 := R.ReadI16;
    gvt_UINT32:
      V.VU32 := R.ReadU32;
    gvt_INT32:
      V.VI32 := R.ReadI32;
    gvt_UINT64:
      V.VU64 := R.ReadU64;
    gvt_INT64:
      V.VI64 := R.ReadI64;
    gvt_FLOAT32:
      V.VF32 := R.ReadF32;
    gvt_FLOAT64:
      V.VF64 := R.ReadF64;
    gvt_BOOL:
      V.VBool := R.ReadBoolI8;
    gvt_STRING:
      V.VStr := R.ReadStringU64;
    gvt_ARRAY:
      begin
        ElemT := TGGUFValueType(R.ReadI32);
        Count := R.ReadU64;
        A := TGGUFArray.Create;
        A.ElemType := ElemT;
        for i := 0 to Integer(Count) - 1 do
        begin
          case ElemT of
            gvt_UINT8:
              A.Items.Add(IntToStr(R.ReadU8));
            gvt_INT8:
              A.Items.Add(IntToStr(R.ReadI8));
            gvt_UINT16:
              A.Items.Add(IntToStr(R.ReadU16));
            gvt_INT16:
              A.Items.Add(IntToStr(R.ReadI16));
            gvt_UINT32:
              A.Items.Add(IntToStr(Integer(R.ReadU32)));
            gvt_INT32:
              A.Items.Add(IntToStr(R.ReadI32));
            gvt_UINT64:
              A.Items.Add(IntToStr(Int64(R.ReadU64)));
            gvt_INT64:
              A.Items.Add(IntToStr(R.ReadI64));
            gvt_FLOAT32:
              A.Items.Add(FloatToStr(R.ReadF32));
            gvt_FLOAT64:
              A.Items.Add(FloatToStr(R.ReadF64));
            gvt_BOOL:
              A.Items.Add(IfThen(R.ReadBoolI8, 'true', 'false'));
            gvt_STRING:
              A.Items.Add(string(R.ReadStringU64));
          else
            raise EGGUF.Create('Unsupported array element type');
          end;
        end;
        V.VArr := A;
      end;
  else
    raise EGGUF.Create('Unsupported KV value type');
  end;

  Result := V;
end;

function CompareTensorSourceOffset(Item1, Item2: Pointer): Integer;
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

function CalculByteSizeSourceDataSize(var Tensors: TObjectList; TensorDataFilePos: Int64): Boolean;
var
  Sorted: TObjectList;
  T: TGGUFTensorInfo;
  // calcul sizes
  BlobSize, Blocks: Int64;
  NextOff: UInt64;
  i, j: Integer;
begin
  Result := True;
  try
    for i := 0 to Tensors.Count - 1 do
    begin
      T := TGGUFTensorInfo(Tensors[i]);
      if not GGML_TypeIsQuant(T.TensorType) then
      begin
        // T.ByteSize := T.TotElems * GGML_TypeScalarSize(T.TensorType);
        T.BlockElems := 32;
        T.BlockBytes := 32 * GGML_TypeScalarSize(T.TensorType);
      end
      else
      begin
        T.BlockElems := GGML_BlockElems(T.TensorType); // QK
        T.BlockBytes := GGML_BlockBytes(T.TensorType); // BS
        if ((T.BlockElems <= 0) or (T.BlockBytes <= 0)) then
          raise Exception.CreateFmt('GGML_RowSize: unsupported/unknown block size for %s',
            [GGMLTypeToStr(T.TensorType)]);
        // Blocks := (T.BlockElems + T.BlockElems - 1) div T.BlockElems;
        // T.ByteSize := Blocks * T.BlockBytes;
      end;
      T.ByteSize := GGML_TensorDataSize1(T.TensorType, T.Dims);
      T.ByteSizeOrg := T.ByteSize;
      T.TensorTypeOrg := T.TensorType; // Type GGML original
      // T.ByteSize := GGML_TensorDataSize1(T.TensorType, T.Dims);
      T.TensorDataFilePos := TensorDataFilePos;
    end;
  except
    Result := False;
  end;
end;

function CalculByteSizeSourceOffset11(var Tensors: TObjectList; TensorDataFilePos, TensorDataByteSize: Int64): Boolean;
var
  Sorted: TObjectList;
  T: TGGUFTensorInfo;
  // calcul sizes
  BlobSize: Int64;
  NextOff: Int64;
  i, j: Integer;
begin
  Result := True;
  if CalculByteSizeSourceDataSize(Tensors, TensorDataFilePos) then
    Exit;
  BlobSize := TensorDataByteSize;
  // 4. Calcul des ByteSize par tenseur
  Sorted := TObjectList.Create(False);
  try
    for i := 0 to Tensors.Count - 1 do
      Sorted.Add(Tensors[i]);
    Sorted.Sort(@CompareTensorSourceOffset);

    for i := 0 to Sorted.Count - 1 do
    begin
      T := TGGUFTensorInfo(Sorted[i]);
      T.TensorDataFilePos := TensorDataFilePos;

      if Int64(T.SourceOffset) < 0 then
        raise EGGUF.Create('Bad tensor offset');
      if Int64(T.SourceOffset) > BlobSize then
        raise EGGUF.Create('Tensor offset out of blob');

      if i < Sorted.Count - 1 then
        NextOff := TGGUFTensorInfo(Sorted[i + 1]).SourceOffset
      else
        NextOff := UInt64(BlobSize);

      if NextOff < T.SourceOffset then
        raise EGGUF.Create('Tensor offsets not monotonic');

      T.ByteSize := NextOff - T.SourceOffset;
      T.ByteSizeOrg := T.ByteSize;
    end;
  finally
    Sorted.Free;
  end;
end;

class function TGGUFReader.LoadFromFile(const FileName: string; OnProgress: TOnProgressEvent1 = nil): TGGUFFile;
const
  MAGIC_GGUF = $46554747; // 'GGUF' LE
var
  FS: TFileStream;
  R: TBinReader;
  Magic: Cardinal;
  i, d: Integer;
  sKy: AnsiString;
  VT: TGGUFValueType;
  KV: TGGUFKeyValue;
  T: TGGUFTensorInfo;
  AlignKV: TGGUFKeyValue;
  SCount, SNo, STensorCount: Integer;
  PosOfOf: Integer;
  BaseName, NextPartName: string;
  k, j: Integer;
  OtherM: TGGUFFile;
begin
  Result := TGGUFFile.Create;
  SCount := -1;
  SNo := -1;
  STensorCount := -1;
  try
    FS := TFileStream.Create(FileName, fmOpenRead or fmShareDenyWrite);
    try
      iUnused := 10000;
      R := TBinReader.Create(FS);
      try
        Magic := R.ReadU32;
        if Magic <> MAGIC_GGUF then
          raise EGGUF.Create('Not a GGUF file (magic mismatch)');

        Result.Version := R.ReadU32;

        Result.TensorCount := R.ReadU64;
        Result.KVCount := R.ReadU64;
        // Lecture des Key-Values
        for i := 0 to Integer(Result.KVCount) - 1 do
        begin
          sKy := R.ReadStringU64;
          VT := TGGUFValueType(R.ReadI32);
          KV := TGGUFKeyValue.Create;
          KV.Key := sKy;
          KV.Val.Free;
          KV.Val := ReadKVValue(R, VT);
          // Détection intelligente du split pendant la lecture des KVs
          if sKy = 'split.count' then
            SCount := KV.Val.AsInteger
          else if sKy = 'split.no' then
            SNo := KV.Val.AsInteger
          else if sKy = 'split.tensors.count' then
            STensorCount := KV.Val.AsInteger
          else
            Result.KVs.Add(KV); // ne pas enregistrer   split.*

          if Assigned(OnProgress) and ((i mod 1 = 0) or (i = Integer(Result.KVCount) - 1)) then
            // OnProgress(Format('Lecture des métadonnées... (%d/%d)', [i, Result.KVCount]), i, Result.KVCount);
            OnProgress(mLang.gMsgFmt('GGUF.MetadataReading', [i, Result.KVCount]) + ' , ' + KV.Key, i, Result.KVCount);
          // charges
        end;

        Result.InitHeaderPartSizeBytes := FS.Position;

        // Lecture des Tenseurs du fichier COURANT
        for i := 0 to Integer(Result.TensorCount) - 1 do
        begin
          T := TGGUFTensorInfo.Create;
          T.Name := R.ReadStringU64;
          T.NDims := R.ReadU32;
          SetLength(T.Dims, T.NDims);
          for d := 0 to Integer(T.NDims) - 1 do
            T.Dims[d] := R.ReadU64;
          T.GetCols;
          T.TensorType := Cardinal(R.ReadI32);
          T.TensorTypeOrg := T.TensorType;
          T.Offset := R.ReadU64;
          T.SourceOffset := T.Offset;
          T.ByteSize := T.Offset;
          T.SourceFile := FileName;
          Result.Tensors.Add(T);

          if Assigned(OnProgress) and ((i mod 20 = 0) or (i = Integer(Result.TensorCount) - 1)) then
            // OnProgress(Format('Lecture des tenseurs... (%d/%d)', [i, Result.TensorCount]), i, Result.TensorCount);
            OnProgress(mLang.gMsgFmt('GGUF.TensorLoading', [i, Result.TensorCount]), i, Result.TensorCount);
        end;

        // Result.IntTensorsHeaderSizeBytes := FS.Position - Result.InitHeaderPartSizeBytes;

        // Alignement et position des données de tenseurs
        AlignKV := Result.FindKV('general.alignment');
        if Assigned(AlignKV) then
          Result.Alignment := AlignKV.Val.AsInteger
        else
          Result.Alignment := 32;

        while (FS.Position mod Result.Alignment) <> 0 do
          FS.Position := FS.Position + 1;

        Result.TensorDataFilePos := FS.Position;
        Result.TensorDataSizeBytes := FS.Size - Result.TensorDataFilePos;
        Result.FileDataSizeBytes := FS.Size;

        if Result.TensorDataSizeBytes < 0 then
          raise EGGUF.Create('Invalid tensor_data position');

        CalculByteSizeSourceDataSize(Result.Tensors, Result.TensorDataFilePos);

        // LOGIQUE DE PATCH : GESTION DES SHARDS
        // Si TensorCount est 0 mais qu'on est dans un split, on cherche les autres parties
        if (SCount > 1) and (Result.TensorCount < STensorCount) and (SNo = 0) then
        begin
          // On cherche le pattern "-00001-of-00002"
          PosOfOf := Pos('-of-', FileName);
          if PosOfOf > 9 then
          begin
            // On extrait la base (ex: "C:\path\model-00001")
            // On recule de 6 caractères pour englober le "-00001"
            BaseName := Copy(FileName, 1, PosOfOf - 7);

            // On parcourt les autres parties (de 1 à SCount-1)
            // On commence à k=1 car k=0 est le fichier actuel (le header)
            for k := 1 to SCount - 1 do
            begin
              NextPartName := BaseName + Format('-%0.5d-of-%0.5d.gguf', [k + 1, SCount]);
              if FileExists(NextPartName) then
              begin
                // On charge récursivement l'autre partie
                OtherM := LoadFromFile(NextPartName);
                Result.TensorCount := Result.TensorCount + OtherM.TensorCount;
                Result.FileDataSizeBytes := Result.FileDataSizeBytes + OtherM.FileDataSizeBytes;
                try
                  for j := 0 to OtherM.Tensors.Count - 1 do
                    Result.Tensors.Add(TGGUFTensorInfo(OtherM.Tensors[j]).Clone);
                finally
                  OtherM.Free;
                end;
              end;
            end;
          end;
        end;

      finally
        R.Free;
      end;
    except
      Result.Free;
      raise;
    end;
  finally
    FS.Free;
  end;
end;

class function TGGUFReader.LoadFromSingleFile(const FileName: string; OnProgress: TOnProgressEvent1 = nil): TGGUFFile;
const
  MAGIC_GGUF = $46554747;
var
  FS: TFileStream;
  R: TBinReader;
  Magic: Cardinal;
  i, d: Integer;
  sKy: AnsiString;
  VT: TGGUFValueType;
  KV: TGGUFKeyValue;
  T: TGGUFTensorInfo;
  AlignKV: TGGUFKeyValue;
  SCount, SNo, STensorCount: Integer;
begin
  Result := TGGUFFile.Create;
  try
    FS := TFileStream.Create(FileName, fmOpenRead or fmShareDenyWrite);
    R := TBinReader.Create(FS);
    try
      Magic := R.ReadU32;
      if Magic <> MAGIC_GGUF then
        raise EGGUF.Create('Not a GGUF file (magic mismatch)');

      Result.Version := R.ReadU32;
      Result.TensorCount := R.ReadU64;
      Result.KVCount := R.ReadU64;

      for i := 0 to Integer(Result.KVCount) - 1 do
      begin
        sKy := R.ReadStringU64;
        VT := TGGUFValueType(R.ReadI32);
        KV := TGGUFKeyValue.Create;
        KV.Key := sKy;
        KV.Val.Free;
        KV.Val := ReadKVValue(R, VT);
        if sKy = 'split.count' then
          SCount := KV.Val.AsInteger
        else if sKy = 'split.no' then
          SNo := KV.Val.AsInteger
        else if sKy = 'split.tensors.count' then
          STensorCount := KV.Val.AsInteger
        else
          Result.KVs.Add(KV); // ne pas enregistrer   split.*
        if Assigned(OnProgress) and ((i mod 5 = 0) or (i = Integer(Result.KVCount) - 1)) then
          OnProgress(Format('Lecture des métadonnées... (%d/%d)', [i, Result.KVCount]), i, Result.KVCount);
      end;
      Result.InitHeaderPartSizeBytes := FS.Position;
      for i := 0 to Integer(Result.TensorCount) - 1 do
      begin
        T := TGGUFTensorInfo.Create;
        T.Name := R.ReadStringU64;
        T.NDims := R.ReadU32;
        SetLength(T.Dims, T.NDims);
        for d := 0 to Integer(T.NDims) - 1 do
          T.Dims[d] := R.ReadU64;
        T.GetCols;
        T.TensorType := Cardinal(R.ReadI32);
        T.TensorTypeOrg := T.TensorType;
        T.Offset := R.ReadU64;
        T.SourceOffset := T.Offset;
        T.ByteSize := T.Offset; // Fallback, recalculé plus tard
        T.SourceFile := FileName;
        Result.Tensors.Add(T);
        if Assigned(OnProgress) and ((i mod 20 = 0) or (i = Integer(Result.TensorCount) - 1)) then
          OnProgress(Format('Lecture des tenseurs... (%d/%d)', [i, Result.TensorCount]), i, Result.TensorCount);
      end;

      AlignKV := Result.FindKV('general.alignment');
      if Assigned(AlignKV) then
        Result.Alignment := AlignKV.Val.AsInteger
      else
        Result.Alignment := 32;

      while (FS.Position mod Result.Alignment) <> 0 do
        FS.Position := FS.Position + 1;
      Result.TensorDataFilePos := FS.Position;
      Result.FileDataSizeBytes := FS.Size;
      Result.TensorDataSizeBytes := FS.Size - Result.TensorDataFilePos;

      if Result.TensorDataSizeBytes < 0 then
        raise EGGUF.Create('Invalid tensor_data position');

      CalculByteSizeSourceDataSize(Result.Tensors, Result.TensorDataFilePos);
    finally
      R.Free;
    end;
  except
    Result.Free;
    raise;
  end;
  FS.Free;
end;

end.
