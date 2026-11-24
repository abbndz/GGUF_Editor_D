unit uGGUFReader;

interface

uses
  Classes, SysUtils, Contnrs, System.Diagnostics, System.IOUtils,
  uMMAPReader, uBinIO, uGGUFModel, uGGUFTypes, uGGMLTypes, uStrUtils, uLangManager, uLog;
// IfThen : StrUtils,

type
  TGGUFReader = class
  public
    class function LoadFromFile(const sFileName: string; OnProgress: TOnProgressEvent1 = nil): TGGUFFile;
    class function LoadFromSingleFile(const sFileName: string; OnProgress: TOnProgressEvent1 = nil): TGGUFFile;
  end;

implementation

function ReadKVValue(R: TMMAPReader; ValueType: TGGUFValueType; const sKey: AnsiString): TGGUFValue;
var
  i: Integer;
  A: TGGUFArray;
  ElemT: TGGUFValueType;
  Count: Integer;
  ByteSize: Int64;
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
        Count := Integer(R.ReadU64);
        if (ElemT < Low(TGGUFValueType)) or (ElemT > High(TGGUFValueType)) then
          begin
            LogE('[GGUF-R] %s: bad ARRAY element type %d at offset %d', [string(sKey), Integer(ElemT), R.Position - 4]);
            raise EGGUF.Create('Array element type invalid');
          end;
        if (Count < 0) or (Count > $1000000) then
          begin
            LogE('[GGUF-R] %s: ARRAY count out of range (%d) at offset %d', [string(sKey), Count, R.Position - 8]);
            raise EGGUF.Create('Array count invalide');
          end;
        A := TGGUFArray.Create;
        A.ElemType := ElemT;
        A.Count := Count;
        if Count > 0 then
          begin
            if ElemT = gvt_STRING then
              begin
                A.IsStringArray := True;
                A.StrItems := TStringList.Create;
                A.StrItems.Capacity := Count;
                A.StrItems.BeginUpdate;
                try
                  for i := 0 to Count - 1 do
                    A.StrItems.Add(AToU8(R.ReadStringU64));   // et non Add(R.ReadStringU64)
                finally
                  A.StrItems.EndUpdate;
                end;
              end
            else
              begin
                A.IsStringArray := False;
                ByteSize := Int64(Count) * A.GetTypeSize;
                SetLength(A.DatItems, ByteSize);
                try
                  R.ReadBuffer(A.DatItems[0], ByteSize);
                except
                  on E: Exception do
                    begin
                      LogE('[GGUF-R] %s: cannot read ARRAY payload (%d x %s = %d bytes) at offset %d : %s', [string(sKey), Count, GGUFTypeToStr(ElemT), ByteSize, R.Position, E.Message]);
                      raise;
                    end;
                end;
              end;
          end;
        V.VArr := A;
      end;
    else
      begin
        LogE('[GGUF-R] %s: unsupported KV value type %d at offset %d', [string(sKey), Integer(ValueType), R.Position - 4]);
        raise EGGUF.Create('Unsupported KV value type');
      end;
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
  T: TGGUFTensorInfo;
  i: Integer;
  BlockElems1: Integer;
  BlockBytes1: Integer;
  BadType, Fixed: Integer;
  ErrMsg : String;
begin
  Result := True;
  BadType := 0; Fixed := 0;
  try
    for i := 0 to Tensors.Count - 1 do
      begin
        T := TGGUFTensorInfo(Tensors[i]);
        if not GGML_TypeIsQuant(T.TensorType) then
          begin
            // T.ByteSize := T.TotElems * GGML_TypeScalarSize(T.TensorType);
            BlockElems1 := 32; // unused for non-quant (kept for layout parity)
            BlockBytes1 := 32 * GGML_BlockBytes(T.TensorType);
            if GGML_BlockBytes(T.TensorType) <= 0 then
              begin
                Inc(BadType);
                if LogIsOn(lvWarn) then
                  LogW('RBADTYPE:' + '[GGUF-R] tensor "' + string(T.Name) + '": scalar size unknown for type : ' + IntToStr(T.TensorType));
              end;
          end
        else
          begin
            BlockElems1 := GGML_BlockElems(T.TensorType); // QK
            BlockBytes1 := GGML_BlockBytes(T.TensorType); // BS
            if ((BlockElems1 <= 0) or (BlockBytes1 <= 0)) then
            begin
              ErrMsg := 'GGML_RowSize: unsupported/unknown block size for ' + GGMLTypeToStr(T.TensorType) + ' (' + string(T.Name) + ')';
              LogW(ErrMsg);
              raise Exception.Create(ErrMsg);
            end;
            // Blocks := (T.BlockElems + T.BlockElems - 1) div T.BlockElems;
            // T.ByteSize := Blocks * T.BlockBytes;
            if T.Cols mod BlockElems1 <> 0 then
              begin
                Inc(Fixed);
                if LogIsOn(lvWarn) then
                  LogW('RBLK:' + GGMLTypeToStr(T.TensorType) + ' [GGUF-R] tensor "%s": cols=%d not a multiple of QK=%d (%s) - rounded size may differ from file', [string(T.Name), T.Cols, BlockElems1, GGMLTypeToStr(T.TensorType)]);
              end;
          end;
        T.ByteSize := GGML_TensorDataSize(T.TensorType, T.Dims);
        T.ByteSizeOrg := T.ByteSize;
        T.TensorTypeOrg := T.TensorType; // Type GGML original
        // T.ByteSize := GGML_TensorDataSize1(T.TensorType, T.Dims);
        T.TensorDataFilePos := TensorDataFilePos;
      end;
  except
    Result := False;
  end;
  if BadType > 0 then
    LogW('[GGUF-R] %d tensor(s) with unknown scalar type', [BadType]);
  if Fixed > 0 then
    LogW('[GGUF-R] %d tensor(s) with cols not multiple of QK', [Fixed]);
end;

function CalculByteSizeSourceOffset11(var Tensors: TObjectList; TensorDataFilePos, TensorDataByteSize: Int64): Boolean;
var
  Sorted: TObjectList;
  T: TGGUFTensorInfo;
  // calcul sizes
  BlobSize: Int64;
  NextOff: Int64;
  i: Integer;
begin
  Result := True;
  if CalculByteSizeSourceDataSize(Tensors, TensorDataFilePos) then
    Exit(False);
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
        LogW('[GGUF-R] size of "%s" derived from next offset: %s (type %s unknown in this build)',
          [string(T.Name), FormatBytes2f(T.ByteSize), GGMLTypeToStr(T.TensorType)]);
      end;
  finally
    Sorted.Free;
  end;
end;

class function TGGUFReader.LoadFromFile(const sFileName: string; OnProgress: TOnProgressEvent1 = nil): TGGUFFile;
const
  MAGIC_GGUF = $46554747; // 'GGUF' LE
var
  // FS: TFileStream;
  // R: TBinReader;
  R: TMMAPReader;
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
  SW: TStopwatch;
  CtxErr: string;
  CurKey: AnsiString;
  UnknownTypes, ZeroSize, DupNames: Integer;
begin
  Result := TGGUFFile.Create;
  SCount := -1;
  SNo := -1;
  STensorCount := -1;
  UnknownTypes := 0;
  ZeroSize := 0;
  DupNames := 0;
  CurKey := '';
  SW := TStopwatch.StartNew;
  LogD('[GGUF-R] open "%s" (%s)', [ExtractFileName(sFileName), FormatBytes2f(TFile.GetSize(sFileName))]);

  // FS := TFileStream.Create(FileName, fmOpenRead or fmShareDenyWrite);
  R := TMMAPReader.Create(sFileName);
  try
    try
      iUnused := 10000;
      Magic := R.ReadU32;
      if Magic <> MAGIC_GGUF then
        begin
          LogE('[GGUF-R] not a GGUF file: magic=$%.8X expected=$%.8X ("%s")', [Magic, MAGIC_GGUF, ExtractFileName(sFileName)]);
          raise EGGUF.Create('Not a GGUF file (magic mismatch)');
        end;

      Result.Version := R.ReadU32;

      if Result.Version > 3 then
        LogW('[GGUF-R] GGUF version %d > 3: reading v3 layout, unknown fields may be misparsed', [Result.Version]);
      if Result.Version < 3 then
        LogW('[GGUF-R] GGUF version %d (<3): 32-bit counts, legacy tensor-info layout assumed', [Result.Version]);

      if Result.Version >= 3 then
        Result.TensorCount := R.ReadU64
      else
        Result.TensorCount := R.ReadU32;

      if Result.Version >= 3 then
        Result.KVCount := R.ReadU64
      else
        Result.KVCount := R.ReadU32;

      if (Result.TensorCount < 0) or (Result.TensorCount > $100000) then
        begin
          LogE('[GGUF-R] tensor_count out of range: %d', [Result.TensorCount]);
          raise EGGUF.Create('GGUF: tensor_count out of range');
        end;
      if (Result.KVCount < 0) or (Result.KVCount > $1000000) then
        begin
          LogE('[GGUF-R] kv_count out of range: %d', [Result.KVCount]);
          raise EGGUF.Create('GGUF: kv_count out of range');
        end;

      LogI('[GGUF-R] header v%d | kv=%d | tensors=%d | mmap=%s',
        [Result.Version, Result.KVCount, Result.TensorCount, FormatBytes2f(R.Size)]);

      // Lecture des Key-Values
      for i := 0 to Integer(Result.KVCount) - 1 do
        begin
          sKy := R.ReadStringU64;
          VT := TGGUFValueType(R.ReadI32);
          if (VT < Low(TGGUFValueType)) or (VT > High(TGGUFValueType)) then
            begin
              LogE('[GGUF-R] "%s" (kv %d): invalid value type %d at offset %d', [string(sKy), i, Integer(VT), R.Position - 4]);
              //raise EGGUF.Create('GGUF: invalid KV value type');
            end;
          KV := TGGUFKeyValue.Create;
          KV.Key := sKy;
          KV.Val.Free;
          KV.Val := ReadKVValue(R, VT, sKy);

          // Détection intelligente du split pendant la lecture des KVs
          if (sKy = 'split.count') or (sKy = 'split.no') or (sKy = 'split.tensors.count') then
            begin
              if sKy = 'split.count' then
                begin
                  SCount := KV.Val.AsInteger;
                  if (SCount < 0) or (SCount > 99999) then
                    LogW('[SPLIT] split.count out of range (%d) in "%s"', [SCount, ExtractFileName(sFileName)]);
                end
              else if sKy = 'split.no' then
                SNo := KV.Val.AsInteger
              else
                STensorCount := KV.Val.AsInteger;
              LogW('[SPLIT] read %s = %d (dropped from output KVs)', [string(sKy), KV.Val.AsInteger]);
              KV.Free;
            end
          else
            begin
              if Result.FindKV(sKy) <> nil then
                begin
                  Inc(DupNames);
                  if LogIsOn(lvWarn) then
                    LogW('KVDUP:' + string(sKy) + Format(' [GGUF-R] duplicate key "%s" (kv %d) in "%s": both kept, last one wins on lookup', //
                      [string(sKy), i, ExtractFileName(sFileName)]), []);
                end;
              Result.KVs.Add(KV);
              if (sKy = 'general.architecture') or (sKy = 'general.name') then
                LogN('[GGUF-R] kv %d/%d "%s" = %s', [i, Result.KVCount, string(sKy), KV.Val.AsStrPrev(8)])
              else
                LogI('[GGUF-R] kv %d/%d "%s" = %s', [i, Result.KVCount, string(sKy), KV.Val.AsStrPrev(8)]);
            end;
          //if Assigned(OnProgress) and ((i mod 10 = 0) or (i = Integer(Result.KVCount) - 1)) then
          //  OnProgress(mLang.gMsgFmt('GGUF.MetadataReading', [i, Result.KVCount]) + ' , ' + sKy, i, Result.KVCount);

          //if LogIsOn(lvTrace) and (i mod 10 = 0) then
          //if Assigned(KV) then
          //LogT('[GGUF-R] kv %d/%d "%s" = %s', [i, Result.KVCount, string(sKy), KV.Val.AsStrPrev(3)]);
        end;
      if DupNames > 0 then
        LogW('[GGUF-R] %d duplicate key(s) found in "%s"', [DupNames, ExtractFileName(sFileName)]);

      Result.InitHeaderPartSizeBytes := R.Position;

      // Lecture des Tenseurs du fichier COURANT
      for i := 0 to Integer(Result.TensorCount) - 1 do
        begin
          T := TGGUFTensorInfo.Create;
          try
            T.Name := R.ReadStringU64;
            T.NDims := R.ReadU32;
            if T.NDims > 16 then
              begin
                LogE('[GGUF-R] tensor "%s": n_dims=%d out of range at offset %d', [string(T.Name), T.NDims, R.Position - 4]);
                raise EGGUF.Create('NDims invalide');
              end;
            SetLength(T.Dims, T.NDims);
            for d := 0 to Integer(T.NDims) - 1 do
              T.Dims[d] := R.ReadU64;
            T.GetCols;
            T.TensorType := R.ReadI32;
            T.TensorTypeOrg := T.TensorType;

            if (T.TensorType < 0) or (T.TensorType >= GGMLTypeCount) then
              LogW('[GGUF-R] tensor "%s": unknown GGML type %d (size will fall back to offset delta)', [string(T.Name), T.TensorType]);
            if (T.NDims = 0) or (T.Cols <= 0) or (T.Rows <= 0) then
              LogW('[GGUF-R] tensor "%s": degenerate shape = %s - quantisation not possible', [string(T.Name), TensorShapeText(T.Dims)]);
            if (T.TotElems <= 0) and (T.NDims > 0) then
              LogW('[GGUF-R] tensor "%s": zero elements', [string(T.Name)]);

            T.Offset := R.ReadU64;
            T.SourceOffset := T.Offset;
            T.ByteSize := T.Offset;
            T.SourceFile := sFileName;
            Result.Tensors.Add(T);
          except
            T.Free;
            raise;
          end;
          if Assigned(OnProgress) and ((i mod 10 = 0) or (i = Integer(Result.TensorCount) - 1)) then
            // OnProgress(Format('Lecture des tenseurs... (%d/%d)', [i, Result.TensorCount]), i, Result.TensorCount);
            OnProgress(mLang.gMsgFmt('GGUF.TensorLoading', [i, Result.TensorCount]), i, Result.TensorCount);

          if LogIsOn(lvInfo) then LogI('[GGUF-R] tensor %d/%d "%s" shape=%s type=%s', //
            [i, Result.TensorCount, string(T.Name), TensorShapeText(T.Dims), GGMLTypeToStr(T.TensorType)]);
        end;

      // Result.IntTensorsHeaderSizeBytes := FS.Position - Result.InitHeaderPartSizeBytes;

      // Alignement et position des données de tenseurs
      AlignKV := Result.FindKV('general.alignment');
      Result.Alignment := 32;

      if Assigned(AlignKV) then
        Result.Alignment := AlignKV.Val.AsInteger;
      if (Result.Alignment <= 0) or (Result.Alignment > 4096) then
        begin
          LogW('[GGUF-R] general.alignment=%d rejected (valid 1..4096), using 32', [Result.Alignment]);
          Result.Alignment := 32;
        end
      else if (Result.Alignment and (Result.Alignment - 1)) <> 0 then
        LogW('[GGUF-R] general.alignment=%d is not a power of two', [Result.Alignment]);

      while (R.Position mod Result.Alignment) <> 0 do
        R.Position := R.Position + 1;

      Result.TensorDataFilePos := R.Position;
      Result.TensorDataSizeBytes := R.Size - Result.TensorDataFilePos;
      Result.FileDataSizeBytes := R.Size;

      LogD('[GGUF-R] header=%d bytes | align=%d | tensor_data @ %d (%s)',
        [Result.InitHeaderPartSizeBytes, Result.Alignment, Result.TensorDataFilePos,
          FormatBytes2f(Result.TensorDataSizeBytes)]);

      if Result.TensorDataSizeBytes < 0 then
        begin
          LogE('[GGUF-R] tensor_data past EOF (pos=%d size=%d) in "%s"', [Result.TensorDataFilePos, R.Size, ExtractFileName(sFileName)]);
          raise EGGUF.Create('Invalid tensor_data position');
        end;

      // file truncated right after the header?
      if (Result.TensorCount > 0) and (Result.TensorDataSizeBytes = 0) then
        LogW('[GGUF-R] %d tensor(s) declared but tensor_data is empty (metadata-only file?) "%s"', [Result.TensorCount, ExtractFileName(sFileName)]);

      if not CalculByteSizeSourceDataSize(Result.Tensors, Result.TensorDataFilePos) then
        LogW('[GGUF-R] exact size computation failed for "%s" (unknown type present)', [ExtractFileName(sFileName)]);

      // LOGIQUE DE PATCH : GESTION DES SHARDS
      if (SCount > 0) and (SNo >= 0) then
        LogD('[SPLIT] "%s" declares part %d/%d (declared tensors=%d, present=%d)',
          [ExtractFileName(sFileName), SNo, SCount, STensorCount, Result.TensorCount]);

      // Si TensorCount est 0 mais qu'on est dans un split, on cherche les autres parties
      if (SCount > 1) and (Result.TensorCount < STensorCount) and (SNo = 0) then
        begin
          // On cherche le pattern "-00001-of-00002"
          PosOfOf := Pos('-of-', sFileName);
          if PosOfOf > 9 then
            begin
              // On extrait la base (ex: "C:\path\model-00001")
              // On recule de 6 caractères pour englober le "-00001"
              BaseName := Copy(sFileName, 1, PosOfOf - 7);
              LogI('[SPLIT] metadata part of %d: merging tensor info from sibling shards', [SCount]);
              // On parcourt les autres parties (de 1 à SCount-1)
              // On commence à k=1 car k=0 est le fichier actuel (le header)
              for k := 1 to SCount - 1 do
                begin
                  NextPartName := BaseName + Format('-%0.5d-of-%0.5d.gguf', [k + 1, SCount]);
                  if FileExists(NextPartName) then
                    begin
                      // On charge récursivement l'autre partie
                      OtherM := LoadFromFile(NextPartName);
                      try
                        Result.TensorCount := Result.TensorCount + OtherM.TensorCount;
                        Result.FileDataSizeBytes := Result.FileDataSizeBytes + OtherM.FileDataSizeBytes;
                        for j := 0 to OtherM.Tensors.Count - 1 do
                          Result.Tensors.Add(TGGUFTensorInfo(OtherM.Tensors[j]).Clone);
                        LogD('[SPLIT] part %d/%d merged: +%d tensors (%s)', [k + 1, SCount, OtherM.Tensors.Count, FormatBytes2f(OtherM.FileDataSizeBytes)]);
                      finally
                        OtherM.Free;
                      end;
                    end else
                      begin
                        LogE('[SPLIT] shard %d/%d missing: "%s" - model will be incomplete', [k + 1, SCount, NextPartName]);
                      end;
                end;
            end
          else
            LogW('[SPLIT] split.count=%d but "-XXXXX-of-" pattern not found in "%s"', [SCount, sFileName]);
          //LogMsg('[GGUF] split.count=' + IntToStr(SCount) + ' mais motif -XXXXX-of- non trouvé dans ' + sFileName);
        end;
      if (SCount > 1) and (SNo > 0) then
        LogI('[SPLIT] loading data part %d/%d', [SNo, SCount]);
    except
      Result.Free;
      Result := nil;
      raise;
    end;
  finally
    R.Free;
    SW.Stop;
    if (Result <> nil) then
      LogN('[GGUF-R] loaded "%s": v%d | %d KVs | %d tensors | %s | %s', //
        [ExtractFileName(sFileName), Result.Version, Result.KVs.Count, Result.Tensors.Count, FormatBytes2f(Result.FileDataSizeBytes), FormatDurationMs(SW.ElapsedMilliseconds)]);
  end;
end;

class function TGGUFReader.LoadFromSingleFile(const sFileName: string; OnProgress: TOnProgressEvent1 = nil): TGGUFFile;
const
  MAGIC_GGUF = $46554747;
var
  // FS: TFileStream;
  // R: TBinReader;
  R: TMMAPReader;
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
  R := nil;
  try
    // FS := TFileStream.Create(FileName, fmOpenRead or fmShareDenyWrite);
    // R := TBinReader.Create(FS);
    R := TMMAPReader.Create(sFileName);
    try
      Magic := R.ReadU32;
      if Magic <> MAGIC_GGUF then
        raise EGGUF.Create('Not a GGUF file (magic mismatch)');

      Result.Version := R.ReadU32;
      Result.TensorCount := R.ReadU64;

      Result.KVCount := R.ReadU64;

      for i := 0 to Result.KVCount - 1 do
        begin
          sKy := R.ReadStringU64;
          VT := TGGUFValueType(R.ReadI32);
          KV := TGGUFKeyValue.Create;
          KV.Key := sKy;
          KV.Val.Free;
          KV.Val := ReadKVValue(R, VT, sKy);
          if (sKy = 'split.count') or (sKy = 'split.no') or (sKy = 'split.tensors.count') then
            begin // ne pas enregistrer   split.*
              if sKy = 'split.count' then
                SCount := KV.Val.AsInteger
              else if sKy = 'split.no' then
                SNo := KV.Val.AsInteger
              else
                STensorCount := KV.Val.AsInteger;
              KV.Free;
            end
          else
            Result.KVs.Add(KV);
          if Assigned(OnProgress) and ((i mod 5 = 0) or (i = Result.KVCount - 1)) then
            //OnProgress(Format('Lecture des métadonnées... (%d/%d)', [i, Result.KVCount]), i, Result.KVCount);
            OnProgress(mLang.gMsgFmt('GGUF.MetadataReading', [i, Result.KVCount]), i, Result.KVCount);
        end;
      Result.InitHeaderPartSizeBytes := R.Position;
      for i := 0 to Result.TensorCount - 1 do
        begin
          T := TGGUFTensorInfo.Create;
          T.Name := R.ReadStringU64;
          T.NDims := R.ReadU32;
          if T.NDims > 16 then
            raise EGGUF.Create('NDims invalide');
          SetLength(T.Dims, T.NDims);
          for d := 0 to Integer(T.NDims) - 1 do
            T.Dims[d] := R.ReadU64;
          T.GetCols;
          T.TensorType := R.ReadI32;
          T.TensorTypeOrg := T.TensorType;
          T.Offset := R.ReadU64;
          T.SourceOffset := T.Offset;
          T.ByteSize := T.Offset; // Fallback, recalculé plus tard
          T.SourceFile := sFileName;
          Result.Tensors.Add(T);
          if Assigned(OnProgress) and ((i mod 20 = 0) or (i = Integer(Result.TensorCount) - 1)) then
            OnProgress(Format('Lecture des tenseurs... (%d/%d)', [i, Result.TensorCount]), i, Result.TensorCount);
        end;

      AlignKV := Result.FindKV('general.alignment');
      Result.Alignment := 32;
      if Assigned(AlignKV) then
        Result.Alignment := AlignKV.Val.AsInteger;
      if (Result.Alignment <= 0) or (Result.Alignment > 4096) then
        Result.Alignment := 32;

      while (R.Position mod Result.Alignment) <> 0 do
        R.Position := R.Position + 1;
      Result.TensorDataFilePos := R.Position;
      Result.FileDataSizeBytes := R.Size;
      Result.TensorDataSizeBytes := R.Size - Result.TensorDataFilePos;

      if Result.TensorDataSizeBytes < 0 then
        raise EGGUF.Create('Invalid tensor_data position');

      CalculByteSizeSourceDataSize(Result.Tensors, Result.TensorDataFilePos);
    finally
      R.Free;
    end;
  except
    Result.Free;
    Result := nil;
    raise;
  end;
  // R.Free;
end;

end.
