unit uGGUFWriter;

interface

uses
  Classes, SysUtils, Contnrs, Math, uBinIO, uGGUFModel, uGGUFTypes, uGGMLTypes, uGgmlQuants, uLog, uGgufStrUtils,
  Generics.Collections, uGGMLConstants;

type
  TOnProgressEvent2 = procedure(const Msg: string; ATensorIdx, ATensorTotal, AByteIdx, AByteTotal: Int64) of object;

  TMergeProgressEvent = procedure(AIdx, ATotal: Integer; const Cur, Max: Int64) of object;

type
  TGGUFWriter = class
  public
    class procedure SaveAs(const Model: TGGUFFile; const BaseOut: string; MaxBytesPerPart: Int64;
      DoSeparateMeta: Boolean = True; UseDLL: Boolean = True; OnProgress: TOnProgressEvent2 = nil;
      ACancelFlag: PBoolean = nil);

    // Merge shards => un GGUF unique
    class procedure MergeParts(const PartFiles: TStringList; const OutFile: string;
      OnProgress: TOnProgressEvent2 = nil);
  end;

procedure WriteSingleFile(const Model: TGGUFFile; const DstFile: string; UseDLL: Boolean; OnProgress: TOnProgressEvent2;
  TotalBytes: Int64; ACancelFlag: PBoolean = nil);

implementation

uses uGGUFReader, uGGUFParts;

const
  MAGIC_GGUF = $46554747;
  BufSize = $10000; // 64 Ko
  BufSize1 = $100000; // 1 Mo

procedure WriteKVValue(W: TBinWriter; v: TGGUFValue);
var
  i: Integer;
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
        W.WriteI32(Integer(v.VArr.ElemType));
        W.WriteU64(UInt64(v.VArr.Items.Count));
        for i := 0 to v.VArr.Items.Count - 1 do
        begin
          case v.VArr.ElemType of
            gvt_UINT8:
              W.WriteU8(pStrToUInt8(v.VArr.Items[i]));
            gvt_INT8:
              W.WriteI8(ShortInt(pStrToInt64(v.VArr.Items[i])));
            gvt_UINT16:
              W.WriteU16(pStrToUInt16(v.VArr.Items[i]));
            gvt_INT16:
              W.WriteI16(SmallInt(pStrToInt64(v.VArr.Items[i])));
            gvt_UINT32:
              W.WriteU32(pStrToUInt32(v.VArr.Items[i]));
            gvt_INT32:
              W.WriteI32(StrToInt(Trim(v.VArr.Items[i])));
            gvt_UINT64:
              W.WriteU64(pStrToUInt64(v.VArr.Items[i]));
            gvt_INT64:
              W.WriteI64(pStrToInt64(v.VArr.Items[i]));
            gvt_FLOAT32:
              W.WriteF32(pStrToFloat(v.VArr.Items[i]));
            gvt_FLOAT64:
              W.WriteF64(pStrToFloat(v.VArr.Items[i]));
            gvt_BOOL:
              W.WriteBoolI8(pStrToBool(v.VArr.Items[i]));
            gvt_STRING:
             // W.WriteStringU64(AnsiString(v.VArr.Items[i]));
             W.WriteStringU64(UTF8Encode(v.VArr.Items[i]));
          else
            raise EGGUF.Create('Array element type not supported');
          end;
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
  W.WriteU32(T.NDims);
  for d := 0 to Integer(T.NDims) - 1 do
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

procedure WriteSingleFile(const Model: TGGUFFile; const DstFile: string; UseDLL: Boolean; OnProgress: TOnProgressEvent2;
  TotalBytes: Int64; ACancelFlag: PBoolean = nil);
var
  W: TBinWriter;
  Dst: TFileStream;
  i, J: Integer;
  T: TGGUFTensorInfo;
  KV: TGGUFKeyValue;
  CurrOffset: UInt64;
  BaseFileOffset, TensorDataStartDst: Int64;
  TargetPos: Int64;
  Buf: array [0 .. BufSize] of Byte;
  ReadN, ToRead, CurrentPos: Int64;
  SrcStreams: TDictionary<string, TFileStream>;
  SrcStream: TFileStream;
  SrcFile, ExpMsg: string;
  Rows, Cols: Int64;
  SrcData, DstData: TBytes;
  SrcRowBytes, DstRowBytes: Int64;
  ProcessedTensorBytes: Int64;
  TotalTensors, KVsCount: Integer;
begin
  if not Assigned(Model) then
    Exit;

  TotalTensors := Model.Tensors.Count;
  SrcStreams := TDictionary<string, TFileStream>.Create;
  try
    Dst := TFileStream.Create(DstFile, fmCreate);
    try
      W := TBinWriter.Create(Dst);
      try
        KVsCount := 0;
        for i := 0 to Model.KVs.Count - 1 do
        begin
          if TGGUFKeyValue(Model.KVs[i]).Keep then
          begin
            KVsCount := KVsCount + 1;
          end;
        end;
        W.WriteU32(MAGIC_GGUF);
        W.WriteU32(Model.Version);
        W.WriteU64(UInt64(Model.Tensors.Count));
        // W.WriteU64(UInt64(Model.KVs.Count));
        W.WriteU64(UInt64(KVsCount));

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
        TensorDataStartDst := Dst.Position;

        for i := 0 to TotalTensors - 1 do
        begin
          T := TGGUFTensorInfo(Model.Tensors[i]);
          if Assigned(ACancelFlag) and ACancelFlag^ then
            Exit;

          if Assigned(OnProgress) and (i > 0) then
          begin
            // Simule un appel progress pour vérifier le flag FCancelSave du formulaire
            OnProgress(Format('Tensor %d/%d : %s', [i + 1, TotalTensors, string(T.Name)]), i + 1, TotalTensors, 0, 0);
          end;

          TargetPos := TensorDataStartDst + Int64(T.Offset);
          W.PadToAlignment(Model.Alignment, 0);

          if (T.IsTransposed and (T.TransposFile <> '') and (FileExists(T.TransposFile))) then
          begin
            SrcFile := T.TransposFile;
            BaseFileOffset := 0; // Les dumps transposés sont bruts, départ à 0
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

          ProcessedTensorBytes := 0;
          if T.IsConverted then
          begin
            Cols := T.Dims[0];
            Rows := 1;
            for J := 1 to Length(T.Dims) - 1 do
              Rows := Rows * T.Dims[J];

            SrcRowBytes := TGGUFTensorInfo.GetRowSize(T.TensorTypeOrg, Cols);
            DstRowBytes := TGGUFTensorInfo.GetRowSize(T.TensorType, Cols);

            SetLength(SrcData, SrcRowBytes);
            SetLength(DstData, DstRowBytes);

            SrcStream.Position := BaseFileOffset; // T.TensorDataFilePos + T.SourceOffset;

            for J := 0 to Rows - 1 do
            begin
              ToRead := SrcRowBytes;
              CurrentPos := 0;
              while ToRead > 0 do
              begin
                ReadN := ToRead;
                if ReadN > BufSize then
                  ReadN := BufSize;
                ReadN := SrcStream.Read(Buf[0], ReadN);
                if ReadN <= 0 then
                  raise Exception.CreateFmt('EOF prématuré ligne %d/%d tenseur %s', [J + 1, Rows, string(T.Name)]);
                Move(Buf[0], SrcData[CurrentPos], ReadN);
                Inc(CurrentPos, ReadN);
                Dec(ToRead, ReadN);
              end;
              if CurrentPos <> SrcRowBytes then
                raise Exception.CreateFmt('Lecture incomplète ligne %d de %s', [J + 1, string(T.Name)]);

              // Dans WriteSingleFile, avant d'écrire un tenseur converti :
              if (T.IsConverted) and ((T.TensorType = GGML_TYPE_F8_E4M3) or (T.TensorType = GGML_TYPE_F8_E5M2) or
                (T.TensorType = GGML_TYPE_F8_E4M3FN) or (T.TensorType = GGML_TYPE_F8_E5M2FN)) then
              begin
                // GGML v3 ne supporte pas FP8. Conversion automatique vers F16 pour la sauvegarde
                T.TensorType := GGML_TYPE_F16;
                // Log(Format('Tenseur %s converti de F8 -> F16 pour compatibilité GGUF.', [string(T.Name)]));
              end;

              if not ConvertTensorData(SrcData, T.TensorTypeOrg, T.TensorType, 1, Cols, DstData, UseDLL, nil) then
                raise Exception.Create('Conversion échouée ligne ' + IntToStr(J + 1) + ' de ' + string(T.Name));

              Dst.WriteBuffer(DstData[0], DstRowBytes);
              Inc(ProcessedTensorBytes, DstRowBytes);

              if Assigned(ACancelFlag) and ACancelFlag^ then
                Exit;

              // Mise à jour ProgressBar2 (Ligne par ligne)
              if Assigned(OnProgress) then
                // if J mod 1024 = 0 then
                // OnProgress(Format('Tensor %d/%d : %s [Row %d/%d]', [i + 1, TotalTensors, string(T.Name), J + 1, Rows]), i + 1, TotalTensors, J + 1, Rows);
                OnProgress(Format('Tensor %d/%d : %s', [i + 1, TotalTensors, string(T.Name)]), i + 1, TotalTensors,
                  ProcessedTensorBytes, T.ByteSize);
            end;
          end
          else
          begin
            SrcStream.Position := BaseFileOffset; // T.TensorDataFilePos + T.SourceOffset;
            ToRead := T.ByteSizeOrg;

            while ToRead > 0 do
            begin
              ReadN := ToRead;
              if ReadN > BufSize then
                ReadN := BufSize;
              ReadN := SrcStream.Read(Buf[0], ReadN);
              if ReadN <= 0 then
                Break;
              Dst.WriteBuffer(Buf[0], ReadN);
              Dec(ToRead, ReadN);
              Inc(ProcessedTensorBytes, ReadN);
              if Assigned(ACancelFlag) and ACancelFlag^ then
                Exit;
              if Assigned(OnProgress) then
                // if ProcessedTensorBytes mod BufSize1 = 0 then
                // OnProgress(Format('Tensor %d/%d : %s [Size %d/%d]', [i + 1, TotalTensors, string(T.Name), ProcessedTensorBytes, ToRead]), i + 1, TotalTensors, ProcessedTensorBytes, ToRead);
                OnProgress(Format('Tensor %d/%d : %s', [i + 1, TotalTensors, string(T.Name)]), i + 1, TotalTensors,
                  ProcessedTensorBytes, T.ByteSize);
            end;
          end;
          { if Assigned(OnProgress) then
            OnProgress(Format('Tensor %d/%d: %s', [i + 1, TotalTensors, string(T.Name)]), i + 1, TotalTensors,
            ProcessedTensorBytes, TotalBytes); }
        end;
        if Assigned(OnProgress) then
          OnProgress('Terminé', TotalTensors, TotalTensors, TotalBytes, TotalBytes);

      finally
        W.Free;
      end;
    finally
      Dst.Free;
    end;
  finally
    for SrcStream in SrcStreams.Values do
      SrcStream.Free;
    SrcStreams.Free;
  end;
end;

class procedure TGGUFWriter.SaveAs(const Model: TGGUFFile; const BaseOut: string; MaxBytesPerPart: Int64;
  DoSeparateMeta: Boolean = True; UseDLL: Boolean = True; OnProgress: TOnProgressEvent2 = nil;
  ACancelFlag: PBoolean = nil);
var
  Parts: TObjectList;
  i, PartCount: Integer;
  CurPart: TGGUFFile;
  BaseNoExt, OutName: string;
  estMax, TotalBytes: Int64;
  TensorsCount: Cardinal;
begin
  if not Assigned(Model) then
    Exit;
  if MaxBytesPerPart <= 0 then
  begin
    // MODE SINGLE FILE: Pas de split, pas de split.* KVs
    TotalBytes := 0;
    for i := 0 to Model.Tensors.Count - 1 do
      TotalBytes := TotalBytes + TGGUFTensorInfo(Model.Tensors[i]).ByteSizeOrg;
    WriteSingleFile(Model, BaseOut, UseDLL, OnProgress, TotalBytes, ACancelFlag);
  end
  else
  begin
    // MODE SPLIT: Ajout split.*, découpe par taille
    Parts := TObjectList.Create(True);
    try
      TensorsCount := Model.Tensors.Count;
      CurPart := Model.CloneMetaOnly;
      CurPart.InitHeaderPartSizeBytes := Model.InitHeaderPartSizeBytes;
      if DoSeparateMeta then
      begin
        if Assigned(ACancelFlag) and ACancelFlag^ then
          Exit;
        Parts.Add(CurPart);
        CurPart := Model.CloneVersOnly;
      end;

      try
        for i := 0 to Model.Tensors.Count - 1 do
        begin
          if Assigned(ACancelFlag) and ACancelFlag^ then
            Break;
          CurPart.Tensors.Add(TGGUFTensorInfo(Model.Tensors[i]).Clone);
          if (CurPart.Tensors.Count > 1) and (EstimatePartTotalBytes(CurPart) > UInt64(MaxBytesPerPart)) then
          begin
            CurPart.Tensors.Delete(CurPart.Tensors.Count - 1);
            if CurPart.Tensors.Count = 0 then
              raise EGGUF.Create('Un tenseur dépasse MaxBytesPerPart');
            Parts.Add(CurPart);
            CurPart := Model.CloneVersOnly;
            CurPart.InitHeaderPartSizeBytes := 64;
            CurPart.Tensors.Add(TGGUFTensorInfo(Model.Tensors[i]).Clone);
          end;
        end;
        if Assigned(ACancelFlag) and ACancelFlag^ then
          Exit;
        if CurPart.Tensors.Count > 0 then
          Parts.Add(CurPart)
        else
          CurPart.Free;
      except
        CurPart.Free;
        raise;
      end;

      PartCount := Parts.Count;
      BaseNoExt := ChangeFileExt(Trim(BaseOut), '');
      for i := 0 to Parts.Count - 1 do
      begin
        if Assigned(ACancelFlag) and ACancelFlag^ then
          Break;
        TGGUFFile(Parts[i]).SetKV_U16('split.count', Cardinal(PartCount));
        TGGUFFile(Parts[i]).SetKV_U16('split.no', Cardinal(i));
        TGGUFFile(Parts[i]).SetKV_I32('split.tensors.count', TensorsCount);

        OutName := Format('%s-%0.5d-of-%0.5d.gguf', [BaseNoExt, i + 1, PartCount]);
        estMax := Int64(EstimatePartTotalBytes(TGGUFFile(Parts[i])));

        if Assigned(OnProgress) then
          OnProgress(Format('Split part %d/%d', [i + 1, PartCount]), i + 1, PartCount, 0, estMax);

        WriteSingleFile(TGGUFFile(Parts[i]), OutName, UseDLL, nil, estMax, ACancelFlag);
        if Assigned(ACancelFlag) and ACancelFlag^ then
          Break;

        if Assigned(OnProgress) then
          OnProgress(Format('Split part %d/%d écrit', [i + 1, PartCount]), i + 1, PartCount, estMax, estMax);
      end;
      if Assigned(ACancelFlag) and ACancelFlag^ then
        Exit;

      if Assigned(OnProgress) then
        OnProgress('Split terminé', PartCount, PartCount, 0, 0);
    finally
      Parts.Free;
    end;
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
  Master, PartM, OutModel: TGGUFFile;
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
begin
  if (PartFiles = nil) or (PartFiles.Count = 0) then
    raise EGGUF.Create('MergeParts: aucune partie fournie');

  SizeOf_Buf := 1024 * 1024;
  SetLength(Buf, SizeOf_Buf);

  SplitIdx := BuildAndVerifySplitIndex(PartFiles, MasterFile);
  try
    Master := TGGUFReader.LoadFromSingleFile(MasterFile);
    try
      OutModel := Master.CloneMetaOnly;
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
    Master.Free;
    SplitIdx.Free;
  end;

  if Assigned(OnProgress) then
    OnProgress('Merge terminé', TotalTensors, TotalTensors, TotalBytes, TotalBytes);
end;

end.
