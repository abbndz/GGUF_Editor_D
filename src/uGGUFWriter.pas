unit uGGUFWriter;

interface

uses
  Classes, SysUtils, Winapi.Windows, Contnrs, Math,System.Diagnostics, System.IOUtils,
  uMMAPReader, uBinIO, uGGUFModel, uGGUFTypes, uGGMLTypes, uGgmlQuants, uLog,  uStrUtils,
  Generics.Collections, uGGMLConstants, uSaveProgress;

type
  TGGUFWriter = class
  public
    class procedure SaveAs(const Model: TGGUFFile; const BaseOut: string; MaxBytesPerPart: Int64;
      DoSeparateMeta: Boolean; OnProgress: TOnSaveProgressEvent; ACancelFlag: PBoolean);

    // Merge shards => un GGUF unique
    class procedure MergeParts(const PartFiles: TStringList; const OutFile: string;
      OnProgress: TOnProgressEvent2 = nil);
  end;

function WriteSingleFile(const Model: TGGUFFile; const DstFile: string; PartNo, PartTot: Integer; IsMetaPart: Boolean;
  BaseDoneBytes, JobTotalBytes: Int64; ACancelFlag: PBoolean; OnProgress: TOnSaveProgressEvent): Int64;

implementation

uses uGGUFReader, uGGUFParts;

const
  MAGIC_GGUF = $46554747;
  CREAD_WRITE_SIZE = 4 * 1024 * 1024;  // budget SOURCE par passe de conversion // 4 MiB : lecture/ecriture brute ($10000; // 64 KiB)
  PROGRESS_TICK_MS = 80;

procedure WriteKVValue(W: TBinWriter; v: TGGUFValue);
var
  i: Integer;
  Exp : Int64;
  { ParsedVals: TArray<Double>; // Cache pour FLOAT32/64
    ParsedInts: TArray<Int64>; // Cache pour entiers
    ParsedBools: TArray<Boolean>;
    ParsedStrs: TArray<AnsiString>; }
begin
  W.WriteI32(Integer(v.ValueType));
  case v.ValueType of
    gvt_UINT8:
      W.WriteU8(v.VU8);
    gvt_INT8:
      W.WriteI8(v.VI8);
    gvt_UINT16:
      W.WriteU16(v.VU16);
    gvt_INT16:
      W.WriteI16(v.VI16);
    gvt_UINT32:
      W.WriteU32(v.VU32);
    gvt_INT32:
      W.WriteI32(v.VI32);
    gvt_UINT64:
      W.WriteU64(v.VU64);
    gvt_INT64:
      W.WriteI64(v.VI64);
    gvt_FLOAT32:
      W.WriteF32(v.VF32);
    gvt_FLOAT64:
      W.WriteF64(v.VF64);
    gvt_BOOL:
      W.WriteBoolI8(v.VBool);
    gvt_STRING:
      W.WriteStringU64(v.VStr);
    gvt_ARRAY:
      begin
      if v.VArr = nil then
        begin
          LogE('[GGUF-W] ARRAY value with nil VArr -> writing empty STRING array', []);
          W.WriteI32(Integer(gvt_STRING)); W.WriteU64(0);
          Exit;
        end;

        if (v.VArr.ElemType = gvt_STRING) and not v.VArr.IsStringArray then
          raise EGGUF.Create('ARRAY STRING incoherent (IsStringArray=False)');

        W.WriteI32(Integer(v.VArr.ElemType));

        if v.VArr.IsStringArray then
        begin
          W.WriteU64(UInt64(v.VArr.StrItems.Count));
          case v.VArr.ElemType of
            gvt_UINT8:
              for i := 0 to v.VArr.StrItems.Count - 1 do
                W.WriteU8(pStrToUInt8(v.VArr.StrItems[i]));
            gvt_INT8:
              for i := 0 to v.VArr.StrItems.Count - 1 do
                W.WriteI8(ShortInt(pStrToInt64(v.VArr.StrItems[i])));
            gvt_UINT16:
              for i := 0 to v.VArr.StrItems.Count - 1 do
                W.WriteU16(pStrToUInt16(v.VArr.StrItems[i]));
            gvt_INT16:
              for i := 0 to v.VArr.StrItems.Count - 1 do
                W.WriteI16(SmallInt(pStrToInt64(v.VArr.StrItems[i])));
            gvt_UINT32:
              for i := 0 to v.VArr.StrItems.Count - 1 do
                W.WriteU32(pStrToUInt32(v.VArr.StrItems[i]));
            gvt_INT32:
              for i := 0 to v.VArr.StrItems.Count - 1 do
                W.WriteI32(pStrToInt32(v.VArr.StrItems[i]) );//StrToInt(Trim(v.VArr.StrItems[i])));
            gvt_UINT64:
              for i := 0 to v.VArr.StrItems.Count - 1 do
                W.WriteU64(pStrToUInt64(v.VArr.StrItems[i]));
            gvt_INT64:
              for i := 0 to v.VArr.StrItems.Count - 1 do
                W.WriteI64(pStrToInt64(v.VArr.StrItems[i]));
            gvt_FLOAT32:
              for i := 0 to v.VArr.StrItems.Count - 1 do
                W.WriteF32(pStrToFloat(v.VArr.StrItems[i]));
            gvt_FLOAT64:
              for i := 0 to v.VArr.StrItems.Count - 1 do
                W.WriteF64(pStrToFloat(v.VArr.StrItems[i]));
            gvt_BOOL:
              for i := 0 to v.VArr.StrItems.Count - 1 do
                W.WriteBoolI8(pStrToBool(v.VArr.StrItems[i]));
            gvt_STRING:
              for i := 0 to v.VArr.StrItems.Count - 1 do
                 W.WriteStringU64(U8ToA(v.VArr.StrItems[i]));
                 //W.WriteStringU64(AnsiString(v.VArr.StrItems[i]));
          else
            raise EGGUF.Create('Array element type not supported');
          end;
        end
        else
        begin
          Exp := Int64(v.VArr.Count) * v.VArr.GetTypeSize;
          if Int64(Length(v.VArr.DatItems)) <> Exp then
            LogW('[GGUF-W] array payload size mismatch: count=%d x %d = %d bytes, buffer=%d bytes', [v.VArr.Count, v.VArr.GetTypeSize, Exp, Length(v.VArr.DatItems)]);

          W.WriteU64(UInt64(v.VArr.Count));
          if Length(v.VArr.DatItems) > 0 then
            W.WriteBuffer(@v.VArr.DatItems[0], Length(v.VArr.DatItems));
        end;
      end;
  else
    raise EGGUF.Create('Unsupported KV type in writer');
  end;
end;

procedure WriteTensorInfo(W: TBinWriter; T: TGGUFTensorInfo);
var
  d: Integer;
begin
  W.WriteStringU64(T.Name);
  W.WriteU32(Length(T.Dims));
  for d := 0 to Length(T.Dims)- 1 do
    W.WriteU64(T.Dims[d]);
  if T.IsConverted then
    W.WriteI32(Integer(T.TensorType))
  else
    W.WriteI32(Integer(T.TensorTypeOrg));
  W.WriteU64(T.Offset);
end;

function EstimatePartTotalBytes(Part: TGGUFFile): UInt64;
var
  J: Integer;
  CurRel: UInt64;
  T: TGGUFTensorInfo;
begin
  Result := UInt64(Part.InitHeaderPartSizeBytes);
  CurRel := 0;
  for J := 0 to Part.Tensors.Count - 1 do
  begin
    T := TGGUFTensorInfo(Part.Tensors[J]);
    if Part.Alignment > 0 then
      CurRel := UInt64(((CurRel + (Part.Alignment - 1)) div Part.Alignment) * Part.Alignment);
    if T.IsConverted then
      Inc(CurRel, T.ByteSize)
    else
      Inc(CurRel, T.ByteSizeOrg);
  end;
  Result := Result + CurRel;
end;

function WriteSingleFile(const Model: TGGUFFile; const DstFile: string; PartNo, PartTot: Integer; IsMetaPart: Boolean;
  BaseDoneBytes, JobTotalBytes: Int64; ACancelFlag: PBoolean; OnProgress: TOnSaveProgressEvent): Int64;
const
  PROG_MIN_MS = 120;
var
  W: TBinWriter;
  Dst: TFileStream;
  i, J: Integer;
  T: TGGUFTensorInfo;
  KV: TGGUFKeyValue;
  CurrOffset: UInt64;
  BaseFileOffset, TensorDataStartDst: Int64;
  TargetPos: Int64;
  Buf: TBytes;
  ReadN, ToRead, CurBufPos, CurSrcPos, TotSrcSize: Int64;
  SrcStreams: TDictionary<string, TFileStream>;
  SrcStream: TFileStream;
  SrcFile: string;
  Rows, RowsX, Cols, ColsX, QK: Int64;
  SrcData, DstData: TBytes;
  SrcRowBytesX, DstRowBytesX, SrcRowBytes1, DstRowBytes1, RowsPerChunk: Int64;
  TensorDone, TensorSize, PadN, n2: Int64;
  TotalTensors, KVsCount: Integer;
  LastProgTick: UInt64;

  SW: TStopwatch;
  EstPart: Int64;

  procedure Fire(AKind: TProgressKind; ATensorIdx: Integer; ADone, ATot: Int64; const AName: string = '');
  var
    Info: TProgressInfo;
  begin
    if not Assigned(OnProgress) then
      Exit;

    Info := NewProgress(AKind);
    FillProgressBase(Info, PartNo, PartTot, IsMetaPart, BaseDoneBytes + Dst.Position, JobTotalBytes, DstFile);

    Info.TensorIdx := ATensorIdx;
    Info.TensorTotal := TotalTensors;
    Info.TensorBytesDone := ADone;
    Info.TensorBytesTotal := ATot;
    Info.PartBytes := Dst.Position;
    Info.Msg := AName;

    OnProgress(Info);
  end;

begin
  Result := 0;

    if not Assigned(Model) then
  begin
    LogE('[GGUF-W] WriteSingleFile called with nil model', []);
    Exit;
  end;
  SW := TStopwatch.StartNew;

  EstPart := Int64(EstimatePartTotalBytes(Model));
  LogN('[GGUF-W] >>> part %d/%d "%s"%s | %d tensors | %d KVs | align=%d | est=%s', //
    [PartNo, PartTot, ExtractFileName(DstFile), IfThen1(IsMetaPart, ' (metadata-only)', ''), //
    Model.Tensors.Count, Model.KVs.Count, Model.Alignment, FormatBytes2f(EstPart)]);

  SetLength(Buf, CREAD_WRITE_SIZE + 1);

  TotalTensors := Model.Tensors.Count;
  SrcStreams := TDictionary<string, TFileStream>.Create;
  try
    Dst := TFileStream.Create(DstFile, fmCreate);
    try
      W := TBinWriter.Create(Dst);
      try
        Fire(pkHeader, 0, 0, 0);

        // 1. Écriture des Key-Values
        KVsCount := 0;
        for i := 0 to Model.KVs.Count - 1 do
        begin
          if TGGUFKeyValue(Model.KVs[i]).Keep then
            Inc(KVsCount);
        end;

        W.WriteU32(MAGIC_GGUF);
        W.WriteU32(Model.Version);
        W.WriteU64(UInt64(Model.Tensors.Count));
        W.WriteU64(UInt64(KVsCount));
        LogD('[GGUF-W] magic+v%d, %d KVs kept of %d, %d tensors declared',
          [Model.Version, KVsCount, Model.KVs.Count, TotalTensors]);

        for i := 0 to Model.KVs.Count - 1 do
        begin
          KV := TGGUFKeyValue(Model.KVs[i]);
          if KV.Keep then
          begin
            W.WriteStringU64(KV.Key);
            WriteKVValue(W, KV.Val);
          end;

          if Assigned(ACancelFlag) and ACancelFlag^ then
            Exit;
        end;

        // 2. Écriture des métadonnées tenseurs
        CurrOffset := 0;
        for i := 0 to TotalTensors - 1 do
        begin
          T := TGGUFTensorInfo(Model.Tensors[i]);
          W.WriteStringU64(T.Name);
          W.WriteU32(Length(T.Dims));

          for J := 0 to Length(T.Dims) - 1 do
            W.WriteU64(T.Dims[J]);

          if (Model.Alignment > 0) and (CurrOffset mod Model.Alignment <> 0) then
            CurrOffset := CurrOffset + (Model.Alignment - (CurrOffset mod Model.Alignment));

          T.Offset := CurrOffset;

          if T.IsConverted then
          begin
            W.WriteI32(Integer(T.TensorType));
            Inc(CurrOffset, T.ByteSize);
          end
          else
          begin
            W.WriteI32(Integer(T.TensorTypeOrg));
            Inc(CurrOffset, T.ByteSizeOrg);
          end;

          W.WriteU64(T.Offset);

          if Assigned(ACancelFlag) and ACancelFlag^ then
            Exit;
        end;

        W.PadToAlignment(Model.Alignment, 0);
        TensorDataStartDst :=  W.Position;// = Dst.Position;

        // 3. Écriture des données
        for i := 0 to TotalTensors - 1 do
        begin
          if Assigned(ACancelFlag) and ACancelFlag^ then
            Exit;

          T := TGGUFTensorInfo(Model.Tensors[i]);

          if T.IsConverted then
            TensorSize := T.ByteSize
          else
            TensorSize := T.ByteSizeOrg;

          TensorDone := 0;
          LastProgTick := GetTickCount64;

          Fire(pkTensorStart, i + 1, 0, TensorSize, string(T.Name));

          TargetPos := TensorDataStartDst + Int64(T.Offset);
          W.PadToAlignment(Model.Alignment, 0);

           if W.Position <> TargetPos then // = if Dst.Position <> TargetPos then
          begin
            LogE('[GGUF-W] OFFSET DRIFT on "%s": expected=%d got=%d (delta=%d) | declared off=%d size=%d srcSize=%d', //
            [string(T.Name), TargetPos, W.Position, TargetPos - W.Position, T.Offset, TensorSize, T.ByteSizeOrg]);
            raise EGGUF.Create(Format('Offset drift on %s (expected %d, got %d)', [string(T.Name), TargetPos, W.Position]));
          end;

          if (T.IsTransposed and (T.TransposFile <> '') and (FileExists(T.TransposFile))) then
          begin
            SrcFile := T.TransposFile;
            BaseFileOffset := 0;
          end
          else
          begin
            SrcFile := T.SourceFile;
            BaseFileOffset := T.TensorDataFilePos + T.SourceOffset;
          end;

          if SrcFile = '' then
            raise Exception.Create('Tenseur "' + string(T.Name) + '" sans source.');

          if not SrcStreams.TryGetValue(SrcFile, SrcStream) then
          begin
            SrcStream := TFileStream.Create(SrcFile, fmOpenRead or fmShareDenyWrite);
            SrcStreams.Add(SrcFile, SrcStream);
          end;

          if T.IsConverted then
          begin
           { if (T.TensorType = GGML_TYPE_F8_E4M3) or (T.TensorType = GGML_TYPE_F8_E5M2) or
              (T.TensorType = GGML_TYPE_F8_E4M3FN) or (T.TensorType = GGML_TYPE_F8_E5M2FN) then
              raise Exception.Create(string(T.Name) + ' : unsupported GGML_TYPE for ' + GGMLTypeToStr(T.TensorType)); }

            if Length(T.Dims) = 0 then
              raise EGGUF.Create('Tenseur converti sans dimensions: ' + string(T.Name));

            Cols := T.Dims[0];
            Rows := 1;
            for J := 1 to Length(T.Dims) - 1 do
              Rows := Rows * T.Dims[J];

            if (Rows <= 0) or (Cols <= 0) then
              raise EGGUF.Create('Dimensions invalides pour ' + string(T.Name));

            if GGML_TypeIsQuant(T.TensorType) then
            begin
              QK := GGML_BlockElems(T.TensorType);
              if Cols mod QK <> 0 then
                raise Exception.Create(string(T.Name) + ' : GGML_RowSize: unsupported block size for ' +
                  GGMLTypeToStr(T.TensorType));
            end;

            SrcRowBytes1 := TGGUFTensorInfo.GetRowSize(T.TensorTypeOrg, Cols);
            DstRowBytes1 := TGGUFTensorInfo.GetRowSize(T.TensorType, Cols);

            if (SrcRowBytes1 <= 0) or (DstRowBytes1 <= 0) then
              raise EGGUF.Create('Taille de ligne invalide pour ' + string(T.Name));

            RowsPerChunk := Max(1, CREAD_WRITE_SIZE div Max(1, SrcRowBytes1));
            if RowsPerChunk > Rows then RowsPerChunk := Rows;

            SrcRowBytesX := RowsPerChunk * SrcRowBytes1;
            DstRowBytesX := RowsPerChunk * DstRowBytes1;

            TotSrcSize := SrcRowBytes1 * Rows;
            ColsX := RowsPerChunk * Cols;

            SetLength(SrcData, SrcRowBytesX);
            SetLength(DstData, DstRowBytesX);

            SrcStream.Position := BaseFileOffset;
            CurSrcPos := 0;

            LogD('[CONV] %s : %s -> %s | rows=%d cols=%d | srcRow=%d dstRow=%d | chunkRows=%d | %s -> %s', //
            [string(T.Name), GGMLTypeToStr(T.TensorTypeOrg), GGMLTypeToStr(T.TensorType), Rows, Cols,//
             SrcRowBytes1, DstRowBytes1, RowsPerChunk, FormatBytes2f(TotSrcSize), FormatBytes2f(TensorSize)]);

            if RowsPerChunk > 1 then
              LogT('[CONV] %s : chunking %d rows per pass', [string(T.Name), RowsPerChunk]);

            while CurSrcPos < TotSrcSize do
            begin
              if Assigned(ACancelFlag) and ACancelFlag^ then
                Exit;

              if TotSrcSize - CurSrcPos > SrcRowBytesX then
                ToRead := SrcRowBytesX
              else
              begin
                ToRead := TotSrcSize - CurSrcPos;
                RowsX := ToRead div SrcRowBytes1;
                if RowsX <= 0 then
                begin
                  LogE('[CONV] %s : truncated source, %d bytes left (< 1 row of %d) at offset %d', //
                    [string(T.Name), ToRead, SrcRowBytes1, BaseFileOffset + CurSrcPos]);
                  raise EGGUF.Create(Format('Truncated source data for %s', [string(T.Name)]));
                end;

                DstRowBytesX := RowsX * DstRowBytes1;
                ColsX := RowsX * Cols;
              end;

              CurBufPos := 0;
              while ToRead > 0 do
              begin
                if Assigned(ACancelFlag) and ACancelFlag^ then
                  Exit;

                ReadN := ToRead;
                if ReadN > Length(Buf) then
                  ReadN := Length(Buf);

                ReadN := SrcStream.Read(Buf[0], ReadN);
                if ReadN <= 0 then
                  raise Exception.CreateFmt('EOF prématuré, tenseur %s', [string(T.Name)]);

                Move(Buf[0], SrcData[CurBufPos], ReadN);
                Inc(CurBufPos, ReadN);
                Dec(ToRead, ReadN);
              end;

              CurSrcPos := CurSrcPos + CurBufPos;

              if not ConvertTensorData(SrcData, T.TensorTypeOrg, T.TensorType, 1, ColsX, DstData, T.UseImpl,
                T.RmseType, nil) then
                raise Exception.Create('Conversion échouée, tenseur : ' + string(T.Name));

              Dst.WriteBuffer(DstData[0], DstRowBytesX);

              if TensorSize > 0 then
                TensorDone := Min(TensorDone + DstRowBytesX, TensorSize)
              else
                TensorDone := TensorDone + DstRowBytesX;

              if Assigned(ACancelFlag) and ACancelFlag^ then
                Exit;

              if (GetTickCount64 - LastProgTick >= PROG_MIN_MS) or ((TensorSize > 0) and (TensorDone >= TensorSize))
              then
              begin
                LastProgTick := GetTickCount64;
                Fire(pkTensorProg, i + 1, TensorDone, TensorSize, string(T.Name));
              end;
            end;
            if (TensorSize > 0) and (TensorDone < TensorSize) then
            begin
              //LogW('[GGUF-W] "%s" wrote only %s of %s (padded to declared size)', //
              LogW('[GGUF-W] "%s" complete de %s (zeros) pour atteindre la taille declaree : %s', //
                [string(T.Name), FormatBytes2f(TensorDone), FormatBytes2f(TensorSize)]);
              PadN := TensorSize - TensorDone;
              FillChar(Buf[0], Min(PadN, Length(Buf)), 0);
              while PadN > 0 do
              begin
                n2 := Min(PadN, Length(Buf));
                Dst.WriteBuffer(Buf[0], n2);
                Dec(PadN, n2);
                Inc(TensorDone, n2);
              end;
              TensorDone := TensorSize;
            end;
          end
          else
          begin
            SrcStream.Position := BaseFileOffset;
            ToRead := T.ByteSizeOrg;

            while ToRead > 0 do
            begin
              if Assigned(ACancelFlag) and ACancelFlag^ then
                Exit;

              ReadN := ToRead;
              if ReadN > CREAD_WRITE_SIZE then
                ReadN := CREAD_WRITE_SIZE;

              ReadN := SrcStream.Read(Buf[0], ReadN);
              if ReadN <= 0 then
                raise EGGUF.CreateFmt('Lecture prématurée sur %s : %d octets manquants', [string(T.Name), ToRead]);

              Dst.WriteBuffer(Buf[0], ReadN); // =  W.WriteBuffer(@Buf[0], ReadN);

              Dec(ToRead, ReadN);

              if TensorSize > 0 then
                TensorDone := Min(TensorDone + ReadN, TensorSize)
              else
                TensorDone := TensorDone + ReadN;

              if Assigned(ACancelFlag) and ACancelFlag^ then
                Exit;

              if (GetTickCount64 - LastProgTick >= PROG_MIN_MS) or ((TensorSize > 0) and (TensorDone >= TensorSize))
              then
              begin
                LastProgTick := GetTickCount64;
                Fire(pkTensorProg, i + 1, TensorDone, TensorSize, string(T.Name));
              end;
            end;
          end;

          if (TensorSize > 0) and (TensorDone < TensorSize) then
          begin
            //LogW('[GGUF-W] "%s" wrote only %s of %s (padded to declared size)', //
            LogW('[GGUF-W] "%s" complete de %s (zeros) pour atteindre la taille declaree : %s', //
              [string(T.Name), FormatBytes2f(TensorDone), FormatBytes2f(TensorSize)]);

            PadN := TensorSize - TensorDone;
            FillChar(Buf[0], Min(PadN, Length(Buf)), 0);
            while PadN > 0 do
            begin
              n2 := Min(PadN, Length(Buf));
              Dst.WriteBuffer(Buf[0], n2);
              Dec(PadN, n2);
              Inc(TensorDone, n2);
            end;
            TensorDone := TensorSize;
          end;


          if (TensorSize > 0) and not(Assigned(ACancelFlag) and ACancelFlag^) then
            Fire(pkTensorProg, i + 1, TensorSize, TensorSize, string(T.Name));
        end;

      finally
        W.Free;
      end;
      Result := Dst.Position;
      LogN('[GGUF-W] <<< part %d/%d written: %s (est %s, delta %+d bytes) | %s | %s', //
        [PartNo, PartTot, FormatBytes2f(Result), FormatBytes2f(EstPart), //
        Result - EstPart, FormatPctF(Result, EstPart), FormatDurationMs(SW.ElapsedMilliseconds)]);
    finally
      Dst.Free;
      try
        for SrcStream in SrcStreams.Values do
          SrcStream.Free;
        SrcStreams.Clear;
      except
      end;
    end;
  finally
    SrcStreams.Free;
  end;
end;

class procedure TGGUFWriter.SaveAs(const Model: TGGUFFile; const BaseOut: string; MaxBytesPerPart: Int64;
  DoSeparateMeta: Boolean; OnProgress: TOnSaveProgressEvent; ACancelFlag: PBoolean);
var
  Parts: TObjectList;
  i, PartCount: Integer;
  CurPart: TGGUFFile;
  BaseNoExt, OutName: string;
  estMax, ActualPartBytes: Int64;
  Cancelled: Boolean;
  TotalJob, CumDone: Int64;
  Info: TProgressInfo;

  function CheckCancel: Boolean;
  begin
    Result := Assigned(ACancelFlag) and ACancelFlag^;
    if Result and not Cancelled then
    begin
      Cancelled := True;
      if Assigned(OnProgress) then
      begin
        Info := NewProgress(pkCancelled);
        FillProgressBase(Info, 0, 0, False, CumDone, TotalJob, BaseOut);
        OnProgress(Info);
      end;
    end;
  end;

  procedure FireJob(AKind: TProgressKind; ADone, ATotal: Int64; APartNo, APartTot, APartBytes: Int64;
    const ASourceFile: string = '');
  begin
    if not Assigned(OnProgress) then
      Exit;

    Info := NewProgress(AKind);
    FillProgressBase(Info, APartNo, APartTot, False, ADone, ATotal, ASourceFile);
    Info.TensorTotal := Model.Tensors.Count;
    Info.PartBytes := APartBytes;
    OnProgress(Info);
  end;

begin
  if not Assigned(Model) then
    Exit;
  Cancelled := False;

  LogN('[SPLIT] SaveAs "%s" | split=%s | metaSeparate=%s | %d tensors | est %s', //
    [ExtractFileName(BaseOut), IfThen1(MaxBytesPerPart <= 0, 'single file', //
    FormatBytes2f(MaxBytesPerPart)), sStrBool(DoSeparateMeta), Model.Tensors.Count, //
    FormatBytes2f(Int64(EstimatePartTotalBytes(Model)))]);


  // CAS FICHIER UNIQUE
  if MaxBytesPerPart <= 0 then
  begin
    TotalJob := Int64(EstimatePartTotalBytes(Model));
    CumDone := 0;

    ActualPartBytes := WriteSingleFile(Model, BaseOut, 1, 1, False, 0, TotalJob, ACancelFlag, OnProgress);
    if CheckCancel then
      Exit;

    Inc(CumDone, ActualPartBytes);
    if CumDone < TotalJob then
      CumDone := TotalJob;

    FireJob(pkPartDone, CumDone, TotalJob, 1, 1, ActualPartBytes, BaseOut);
    FireJob(pkDone, TotalJob, TotalJob, 1, 1, ActualPartBytes, BaseOut);
    Exit;
  end;

  // CAS MULTI-PARTS
  Parts := TObjectList.Create(True);
  try
    CurPart := Model.CloneMetaOnly;
    CurPart.InitHeaderPartSizeBytes := Model.InitHeaderPartSizeBytes;

    if DoSeparateMeta then
    begin
      if CheckCancel then
        Exit;
      Parts.Add(CurPart);
      CurPart := nil;
      CurPart := Model.CloneVersionOnly;
    end;

    for i := 0 to Model.Tensors.Count - 1 do
    begin
      if CheckCancel then
        Exit;

      CurPart.Tensors.Add(TGGUFTensorInfo(Model.Tensors[i]).Clone);

      if (CurPart.Tensors.Count > 1) and (EstimatePartTotalBytes(CurPart) > UInt64(MaxBytesPerPart)) then
      begin
        LogD('[SPLIT] part closed after %d tensors (%s > %s)', //
          [CurPart.Tensors.Count - 1, FormatBytes2f(Int64(EstimatePartTotalBytes(CurPart))), //
          FormatBytes2f(MaxBytesPerPart)]);
        CurPart.Tensors.Delete(CurPart.Tensors.Count - 1);
        if CurPart.Tensors.Count = 0 then
        begin
         //LogE('[SPLIT] tensor "%s" alone (%s) exceeds the part limit %s', //
          //   [string(TGGUFTensorInfo(Model.Tensors[i]).Name)...]);
          CurPart.Free; CurPart := nil;
          raise EGGUF.Create('Un tenseur dépasse MaxBytesPerPart');
        end;   // todo ! ...

        Parts.Add(CurPart);
        CurPart := Model.CloneVersionOnly;
        CurPart.Tensors.Add(TGGUFTensorInfo(Model.Tensors[i]).Clone);
      end;
    end;

    if CheckCancel then
      Exit;

    if CurPart.Tensors.Count > 0 then
      Parts.Add(CurPart)
    else
      CurPart.Free;

    PartCount := Parts.Count;
    BaseNoExt := ChangeFileExt(Trim(BaseOut), '');

    TotalJob := 0;
    for i := 0 to Parts.Count - 1 do
      Inc(TotalJob, Int64(EstimatePartTotalBytes(TGGUFFile(Parts[i]))));

    if TotalJob <= 0 then
      TotalJob := 1;

    CumDone := 0;

    for i := 0 to Parts.Count - 1 do
    begin
      if CheckCancel then
        Break;

      TGGUFFile(Parts[i]).SetKV_U16('split.count', PartCount);
      TGGUFFile(Parts[i]).SetKV_U16('split.no', i);
      TGGUFFile(Parts[i]).SetKV_I32('split.tensors.count', Model.Tensors.Count);

      //TGGUFFile(Parts[i]).SetKV_U32('split.count', PartCount);
      //TGGUFFile(Parts[i]).SetKV_U32('split.no', i);
      //llama_model_load: error loading model: key split.count has wrong type u32 but expected type u16
      //TGGUFFile(Parts[i]).SetKV_U32('split.tensors.count', Model.Tensors.Count);
      //E llama_model_load: error loading model: key split.tensors.count has wrong type u32 but expected type i32

      OutName := Format('%s-%0.5d-of-%0.5d.gguf', [BaseNoExt, i + 1, PartCount]);
      estMax := Int64(EstimatePartTotalBytes(TGGUFFile(Parts[i])));

      ActualPartBytes := WriteSingleFile(TGGUFFile(Parts[i]), OutName, i + 1, PartCount, (DoSeparateMeta and (i = 0)),
        CumDone, TotalJob, ACancelFlag, OnProgress);

      Inc(CumDone, ActualPartBytes);
      if (estMax > 0) and (ActualPartBytes > estMax + Model.Alignment * 2) then
        LogW('[SPLIT] part %d wrote %s but %s estimated (delta %+d)',  //
          [i + 1, FormatBytes2f(ActualPartBytes), FormatBytes2f(estMax), ActualPartBytes - estMax])
      else if (MaxBytesPerPart > 0) and (ActualPartBytes > MaxBytesPerPart) then
        LogW('[SPLIT] part %d EXCEEDS the requested limit: %s > %s',  //
          [i + 1, FormatBytes2f(ActualPartBytes), FormatBytes2f(MaxBytesPerPart)]);

      LogD('[SPLIT] part %d/%d "%s": %d tensors, %s',   //
        [i + 1, PartCount, ExtractFileName(OutName), TGGUFFile(Parts[i]).Tensors.Count, FormatBytes2f(ActualPartBytes)]);

      if CheckCancel then
      begin
        LogW('[GGUF-W] cancel requested at part ? (cumulative %s of %s) - output will be deleted', //
          [FormatBytes2f(CumDone), FormatBytes2f(TotalJob)]);
        Break;
      end;

      FireJob(pkPartDone, CumDone, TotalJob, i + 1, PartCount, ActualPartBytes, OutName);
    end;

    if not Cancelled then
      FireJob(pkDone, TotalJob, TotalJob, PartCount, PartCount, 0, BaseOut);

  finally
    //if CurPart <> nil then CurPart.Free;
    Parts.Free;
  end;
end;

procedure WriteHeaderAndInfos(Model: TGGUFFile; const DstFile: string; out TensorDataStartDst: Int64);
var
  Dst: TFileStream;
  W: TBinWriter;
  i: Integer;
begin
  Dst := TFileStream.Create(DstFile, fmCreate);
  try
    W := TBinWriter.Create(Dst);
    try
      W.WriteU32(MAGIC_GGUF);
      W.WriteU32(Model.Version);
      W.WriteU64(UInt64(Model.Tensors.Count));
      W.WriteU64(UInt64(Model.KVs.Count));
      for i := 0 to Model.KVs.Count - 1 do
      begin
        W.WriteStringU64(TGGUFKeyValue(Model.KVs[i]).Key);
        WriteKVValue(W, TGGUFKeyValue(Model.KVs[i]).Val);
      end;
      for i := 0 to Model.Tensors.Count - 1 do
        WriteTensorInfo(W, TGGUFTensorInfo(Model.Tensors[i]));
      W.PadToAlignment(Model.Alignment, 0);
      TensorDataStartDst := Dst.Position;
    finally
      W.Free;
    end;
  finally
    Dst.Free;
  end;
end;

class procedure TGGUFWriter.MergeParts(const PartFiles: TStringList; const OutFile: string;
  OnProgress: TOnProgressEvent2 = nil);
var
  SplitIdx: TSplitIndex;
  MasterFile: string;
  M, PartM, OutModel: TGGUFFile;
  TensorDataStartDst: Int64;
  Dst: TFileStream;
  W: TBinWriter;
  i, J: Integer;
  Cur: TGGUFTensorInfo;
  CurRel: UInt64;
  PadCount: Int64;
  Buf: array of Byte;
  SizeOf_Buf: Integer;
  ToRead: Int64;
  ReadN: Integer;
  TotalBytes, CurrentBytes: Int64;
  TotalTensors: Integer;
  SeenKVKeys, SeenTensorNames: TStringList;
  KV: TGGUFKeyValue;
  T: TGGUFTensorInfo;
  No, Cnt: Integer;
  Key: string;
begin
  if (PartFiles = nil) or (PartFiles.Count = 0) then
    raise EGGUF.Create('MergeParts: aucune partie fournie');

  SizeOf_Buf := 1024 * 1024;
  SetLength(Buf, SizeOf_Buf);

  SplitIdx := BuildAndVerifySplitIndex(PartFiles, MasterFile);
  No := -1; Cnt := -1;
  try
    M := TGGUFReader.LoadFromSingleFile(MasterFile);
    OutModel := M.CloneMetaOnly;
    try
      OutModel.KVs.Clear;
      OutModel.Tensors.Clear;

      SeenKVKeys := TStringList.Create;
      SeenKVKeys.CaseSensitive := True;
      SeenTensorNames := TStringList.Create;
      SeenTensorNames.CaseSensitive := True;
      try
        for i := 0 to SplitIdx.Count - 1 do
        begin
          PartM := TGGUFReader.LoadFromSingleFile(SplitIdx.FilesByNo.Values[IntToStr(i)]);
          try
            // FUSION KVs : ignore les doublons
            for J := 0 to PartM.KVs.Count - 1 do
            begin
              KV := TGGUFKeyValue(PartM.KVs[J]);
              if SeenKVKeys.IndexOf(string(KV.Key)) < 0 then
              begin
                OutModel.KVs.Add(KV.Clone);
                SeenKVKeys.Add(string(KV.Key));
              end;
            end;

            // FUSION TENSEURS : ignore les doublons
            for J := 0 to PartM.Tensors.Count - 1 do
            begin
              T := TGGUFTensorInfo(PartM.Tensors[J]);
              if SeenTensorNames.IndexOf(string(T.Name)) < 0 then
              begin
                Cur := T.Clone;
                Cur.SourceFile := SplitIdx.FilesByNo.Values[IntToStr(i)];
                Cur.SourceOffset := T.SourceOffset;
                Cur.TensorDataFilePos := T.TensorDataFilePos;
                Cur.ByteSize := T.ByteSize;
                Cur.ByteSizeOrg := T.ByteSizeOrg;
                OutModel.Tensors.Add(Cur);
                SeenTensorNames.Add(string(T.Name));
              end;
            end;
          finally
            PartM.Free;
          end;
        end;
      finally
        SeenKVKeys.Free;
        SeenTensorNames.Free;
      end;
      // RECALCUL OFFSETS & ALIGNEMENT
      TotalTensors := OutModel.Tensors.Count;
      TotalBytes := 0;
      for i := 0 to TotalTensors - 1 do
        TotalBytes := TotalBytes + TGGUFTensorInfo(OutModel.Tensors[i]).ByteSizeOrg;

      CurRel := 0;
      for i := 0 to TotalTensors - 1 do
      begin
        if OutModel.Alignment > 0 then
          CurRel := UInt64(((CurRel + (OutModel.Alignment - 1)) div OutModel.Alignment) * OutModel.Alignment);
        Cur := TGGUFTensorInfo(OutModel.Tensors[i]);
        Cur.Offset := CurRel;
        if Cur.IsConverted then
          CurRel := CurRel + Cur.ByteSize
        else
          CurRel := CurRel + Cur.ByteSizeOrg;
      end;

      WriteHeaderAndInfos(OutModel, OutFile, TensorDataStartDst);

      // COPIE DES DONNÉES TENSEURS
      Dst := TFileStream.Create(OutFile, fmOpenReadWrite);
      try
        Dst.Position := TensorDataStartDst;
        W := TBinWriter.Create(Dst);
        try
          CurrentBytes := 0;
          for i := 0 to SplitIdx.Count - 1 do
          begin
            PartM := TGGUFReader.LoadFromSingleFile(SplitIdx.FilesByNo.Values[IntToStr(i)]);
            try
              if Assigned(OnProgress) then
                OnProgress(Format('Merge part %d/%d', [i + 1, SplitIdx.Count]), 0, SplitIdx.Count, CurrentBytes,
                  TotalBytes);

              with TFileStream.Create(SplitIdx.FilesByNo.Values[IntToStr(i)], fmOpenRead or fmShareDenyWrite) do
                try
                  for J := 0 to TotalTensors - 1 do
                  begin
                    Cur := TGGUFTensorInfo(OutModel.Tensors[J]);
                    if Cur.SourceFile <> SplitIdx.FilesByNo.Values[IntToStr(i)] then
                      Continue;

                    PadCount := Int64(Cur.Offset) - Int64(Dst.Position - TensorDataStartDst);
                    while PadCount > 0 do
                    begin
                      W.WriteU8(0);
                      Dec(PadCount);
                    end;

                    Position := PartM.TensorDataFilePos + Int64(Cur.SourceOffset);
                    ToRead := Int64(Cur.ByteSizeOrg);
                    while ToRead > 0 do
                    begin
                      if ToRead > SizeOf_Buf then
                        ReadN := SizeOf_Buf
                      else
                        ReadN := Integer(ToRead);
                      ReadN := Read(Buf[0], ReadN);
                      if ReadN <= 0 then
                        raise EGGUF.Create('MergeParts: EOF prématuré lors de la copie');
                      Dst.WriteBuffer(Buf[0], ReadN);
                      Dec(ToRead, ReadN);
                      Inc(CurrentBytes, ReadN);

                      if Assigned(OnProgress) and (CurrentBytes mod (64 * 1024) = 0) then
                        OnProgress(Format('Tensor %d/%d: %s', [J + 1, TotalTensors, string(Cur.Name)]), J + 1,
                          TotalTensors, CurrentBytes, TotalBytes);
                    end;
                  end;
                finally
                  Free;
                end;

              if Assigned(OnProgress) then
                OnProgress(Format('Partie %d/%d fusionnée', [i + 1, SplitIdx.Count]), 0, SplitIdx.Count, CurrentBytes,
                  TotalBytes);
            finally
              PartM.Free;
            end;
          end;
        finally
          W.Free;
        end;
      finally
        Dst.Free;
      end;
    finally
      OutModel.Free;
    end;
  finally
    M.Free;
    SplitIdx.Free;
  end;

  if Assigned(OnProgress) then
    OnProgress('Merge terminé', TotalTensors, TotalTensors, TotalBytes, TotalBytes);
end;

end.
