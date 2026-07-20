unit uSafeTensors;

interface

uses
  Classes, SysUtils, uBinIO, uMiniJSON, Generics.Collections;

type
  TSafeTensorEntry = class
  public
    Name: string;
    DType: string;
    ShapeArray: TArray<Int64>;
    HeaderDataStart, OffsetStart, OffsetEnd: Int64;
    ByteSize: Int64;
    SourceFile: string;
    constructor Create;
    destructor Destroy; override;
    function GetTotalElements: Int64;
  end;

  TSafeTensorsMeta = class
  public
    Entries: TObjectList<TSafeTensorEntry>;
    TotalFileSize: Int64;
    constructor Create;
    destructor Destroy; override;
  end;

function LoadSafeTensorsMeta(const FileName: string): TSafeTensorsMeta;
function LoadSafeTensorData(const FileName: string; Entry: TSafeTensorEntry): TBytes;

implementation

constructor TSafeTensorEntry.Create;
begin
  inherited Create;
  SetLength(ShapeArray, 0);
  OffsetStart := 0;
  OffsetEnd := 0;
  HeaderDataStart := 0;
  ByteSize := 0;
  SourceFile := '';
end;

destructor TSafeTensorEntry.Destroy;
begin
  SetLength(ShapeArray, 0);
  inherited;
end;

function TSafeTensorEntry.GetTotalElements: Int64;
var
  I: Integer;
begin
  Result := 1;
  for I := 0 to High(ShapeArray) do
    Result := Result * ShapeArray[I];
end;

constructor TSafeTensorsMeta.Create;
begin
  inherited Create;
  Entries := TObjectList<TSafeTensorEntry>.Create;
  TotalFileSize := 0;
end;

destructor TSafeTensorsMeta.Destroy;
begin
  Entries.Free;
  inherited;
end;

{ Procédure interne pour parser UN seul fichier }
procedure ParseSingleFile(const FileName: string; Meta: TSafeTensorsMeta; out FileSize: Int64);
var
  FS: TFileStream;
  R: TBinReader;
  HeaderSize: UInt64;
  HeaderBytes: TBytes;
  HeaderJSON: UnicodeString;
  Root, Obj, V: TMJValue;
  I, J: Integer;
  Key: UnicodeString;
  Entry: TSafeTensorEntry;
  NumVal: Int64;
begin
  FileSize := 0;
  FS := TFileStream.Create(FileName, fmOpenRead or fmShareDenyWrite);
  try
    FileSize := FS.Size;
    R := TBinReader.Create(FS);
    try
      HeaderSize := R.ReadU64;


      if HeaderSize > UInt64(1024 * 1024 * 200) then
        raise Exception.Create('Safetensors: Header trop volumineux');

      HeaderBytes := R.ReadBytes(Integer(HeaderSize));
      HeaderJSON := UTF8Decode(AnsiString(PAnsiChar(@HeaderBytes[0])));

      Root := MJParse(HeaderJSON);
      try
        if Root.Kind <> mjObject then
          raise Exception.Create('Safetensors: Header JSON invalide');

        for I := 0 to Root.ObjKeys.Count - 1 do
        begin
          Key := Root.ObjKeys[I];
          if Key = '__metadata__' then
            Continue;

          Obj := TMJValue(Root.ObjVals[I]);
          if Obj.Kind <> mjObject then
            Continue;

          Entry := TSafeTensorEntry.Create;
          Entry.Name := string(Key);
          Entry.SourceFile := FileName;

          // DType
          V := Obj.ObjGet('dtype');
          if Assigned(V) and (V.Kind = mjString) then
            Entry.DType := string(V.StrVal);

          // Shape
          V := Obj.ObjGet('shape');
          if Assigned(V) and (V.Kind = mjArray) then
          begin
            SetLength(Entry.ShapeArray, V.Arr.Count);
            for J := 0 to V.Arr.Count - 1 do
            begin
              NumVal := Trunc(TMJValue(V.Arr[J]).NumVal);
              If NumVal < 0 Then
                NumVal := 0;
              Entry.ShapeArray[J] := NumVal;
            end;
          end;

          // Offsets
          V := Obj.ObjGet('offsets');
          if not Assigned(V) then
            V := Obj.ObjGet('data_offsets');

          if Assigned(V) and (V.Kind = mjArray) and (V.Arr.Count >= 2) then
          begin
            Entry.OffsetStart := Trunc(TMJValue(V.Arr[0]).NumVal);
            Entry.OffsetEnd := Trunc(TMJValue(V.Arr[1]).NumVal);
            Entry.ByteSize := Entry.OffsetEnd - Entry.OffsetStart;
          end;
          Entry.HeaderDataStart := 8 + HeaderSize; // Position où les données commencent dans CE fichier
          Meta.Entries.Add(Entry);
        end;
      finally
        Root.Free;
      end;
    finally
      R.Free;
    end;
  finally
    FS.Free;
  end;
end;

function LoadSafeTensorsMeta(const FileName: string): TSafeTensorsMeta;
var
  I, PosOfOf: Integer;
  BaseName, PartName, sNo: string;
  TotalCount, CurrentNo: Integer;
  SingleFileSize: Int64;
  TargetFile: string;
begin
  Result := TSafeTensorsMeta.Create;

  // 1. Détection du pattern de shard (ex: model.safetensors-00001-of-00002.safetensors)
  PosOfOf := Pos('-of-', FileName);

  if (PosOfOf > 7) then // On cherche le pattern -XXXXX-of-XXXXX
  begin
    // Extraction de la base : "model.safetensors"
    // On recule de 7 pour enlever "-00001" (6 chars + le tiret)
    BaseName := Copy(FileName, 1, PosOfOf - 7);

    // Extraction du numéro actuel et du total
    // On parse la partie "-00001" et "00002"
    try
      // On récupère la chaîne entre le dernier '-' et le '-of-'
      // Dans "model.safetensors-00001-of-00002.safetensors"
      // le segment "-00001" commence à PosOfOf - 6
      sNo := Copy(FileName, PosOfOf - 5, 5);
      CurrentNo := StrToInt(sNo);

      // Le total est juste après le "-of-"
      // On prend les 5 caractères suivants
      sNo := Copy(FileName, PosOfOf + 4, 5);
      TotalCount := StrToInt(sNo);
    except
      raise Exception.Create('Format de shard Safetensors invalide');
    end;

    // 2. Boucle sur tous les shards détectés
    for I := 1 to TotalCount do
    begin
      // Construction du nom : Base + -XXXXX-of-XXXXX + Extension
      // Note: on récupère l'extension originale à la fin
      TargetFile := BaseName + Format('-%0.5d-of-%0.5d.safetensors', [I, TotalCount]);

      if FileExists(TargetFile) then
      begin
        ParseSingleFile(TargetFile, Result, SingleFileSize);
        Result.TotalFileSize := Result.TotalFileSize + SingleFileSize;
      end
      else
        raise Exception.Create('Shard manquant : ' + TargetFile);
    end;
  end
  else
  begin
    // 3. Mode fichier unique
    ParseSingleFile(FileName, Result, SingleFileSize);
    Result.TotalFileSize := SingleFileSize;
  end;
end;

function LoadSafeTensorData(const FileName: string; Entry: TSafeTensorEntry): TBytes;
var
  FS: TFileStream;
  ReadSize: Int64;
begin
  Result := nil;
  if (Entry.OffsetStart < 0) or (Entry.OffsetEnd <= Entry.OffsetStart) then
    Exit;

  ReadSize := Entry.OffsetEnd - Entry.OffsetStart;
  SetLength(Result, ReadSize);

  // Utilisation de Entry.SourceFile pour être sûr de lire le bon shard
  FS := TFileStream.Create(Entry.SourceFile, fmOpenRead or fmShareDenyWrite);
  try
    FS.Position := Entry.OffsetStart;
    if FS.Read(Result[0], ReadSize) <> ReadSize then
      raise Exception.Create('Safetensors: Lecture incomplète pour ' + Entry.Name);
  finally
    FS.Free;
  end;
end;

end.
