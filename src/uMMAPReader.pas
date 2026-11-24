unit uMMAPReader;

interface

uses
  Winapi.Windows, System.SysUtils;

type
  TMMAPReader = class
  private
    FHandle: THandle;
    FMapping: THandle;
    FPointer: PByte;
    FFileSize: Int64;
    FCurrentPos: Int64;
    function NextBytes(Count: Integer): PByte;
  public
    constructor Create(const FileName: string);
    destructor Destroy; override;

    function ReadU8: Byte;
    function ReadI8: ShortInt;
    function ReadU16: Word;
    function ReadI16: SmallInt;
    function ReadU32: Cardinal;
    function ReadI32: Integer;
    function ReadU64: UInt64;
    function ReadI64: Int64;
    function ReadF32: Single;
    function ReadF64: Double;
    function ReadBoolI8: Boolean;
    function ReadStringU64: AnsiString;
    function ReadBuffer(var Buffer; Count: Int64): Int64;
    function Read(var Buffer; Count: Int64): Int64;

    property Position: Int64 read FCurrentPos write FCurrentPos;
    property FileSize: Int64 read FFileSize;
    property Size: Int64 read FFileSize;
  end;

implementation

constructor TMMAPReader.Create(const FileName: string);
var
  FileHandle: THandle;
  FileSizeEx: TLargeInteger;
begin
  // 1. Ouvrir le fichier
  FileHandle := CreateFile(PChar(FileName), GENERIC_READ, FILE_SHARE_READ, nil, OPEN_EXISTING,
    FILE_ATTRIBUTE_NORMAL, 0);
  if FileHandle = INVALID_HANDLE_VALUE then
    raise Exception.Create('Impossible d''ouvrir le fichier : ' + FileName);

  try
    // Récupérer la taille du fichier

    // FFileSize := GetFileSize(FileHandle, 0);

    if not GetFileSizeEx(FileHandle, FileSizeEx) then
      raise Exception.Create('Erreur lors de la lecture de la taille du fichier.');

    FFileSize := UInt64(FileSizeEx);

    // 2. Créer l'objet de mapping
    FMapping := CreateFileMapping(FileHandle, nil, PAGE_READONLY, 0, 0, nil);
    if FMapping = 0 then
      raise Exception.Create('Erreur lors de la création du FileMapping.');

    // 3. Projeter le fichier dans la mémoire (CORRECTION : MapViewOfFile)
    FPointer := MapViewOfFile(FMapping, FILE_MAP_READ, 0, 0, 0);
    if FPointer = nil then
      raise Exception.Create('Erreur lors de la projection du fichier (MapViewOfFile).');

    FCurrentPos := 0;
  finally
    // On ferme le handle du fichier, le mapping garde sa propre référence
    CloseHandle(FileHandle);
  end;
end;

destructor TMMAPReader.Destroy;
begin
  if FPointer <> nil then
    UnmapViewOfFile(FPointer);
  if FMapping <> 0 then
    CloseHandle(FMapping);
  inherited;
end;

function TMMAPReader.NextBytes(Count: Integer): PByte;
begin
  if (FCurrentPos + Count) > FFileSize then
    raise Exception.Create('EOF atteint.');
  Result := FPointer + FCurrentPos;
  Inc(FCurrentPos, Count);
end;

function TMMAPReader.ReadU8: Byte;
begin
  Result := NextBytes(1)^;
end;

function TMMAPReader.ReadI8: ShortInt;
begin
  Result := ShortInt(NextBytes(1)^);
end;

function TMMAPReader.ReadU16: Word;
var
  P: PWord;
begin
  P := PWord(NextBytes(2));
  Result := P^;
end;

function TMMAPReader.ReadI16: SmallInt;
begin
  Result := SmallInt(ReadU16);
end;

function TMMAPReader.ReadU32: Cardinal;
var
  P: PCardinal;
begin
  P := PCardinal(NextBytes(4));
  Result := P^;
end;

function TMMAPReader.ReadI32: Integer;
begin
  Result := Integer(ReadU32);
end;

function TMMAPReader.ReadU64: UInt64;
var
  P: PUInt64;
begin
  P := PUInt64(NextBytes(8));
  Result := P^;
end;

function TMMAPReader.ReadI64: Int64;
begin
  Result := Int64(ReadU64);
end;

function TMMAPReader.ReadF32: Single;
var
  P: PSingle;
begin
  P := PSingle(NextBytes(4));
  Result := P^;
end;

function TMMAPReader.ReadF64: Double;
var
  P: PDouble;
begin
  P := PDouble(NextBytes(8));
  Result := P^;
end;

function TMMAPReader.ReadBoolI8: Boolean;
begin
  Result := NextBytes(1)^ <> 0;
end;

function TMMAPReader.ReadStringU64: AnsiString;
const
  MAX_STR = $4000000; // 64 Mo, comme uBinIO
var
  L: Int64;
  P: PByte;
begin
  { L := ReadU64;
    if L > 0 then
    begin
    SetLength(Result, L);
    Move(FPointer[FCurrentPos], Result[1], L);
    Inc(FCurrentPos, L);
    end
    else
    Result := ''; }
  L := Int64(ReadU64);
  if (L < 0) or (L > MAX_STR) then
    raise Exception.Create('GGUF: taille de chaine invalide');
  if L = 0 then
    Exit('');
  P := NextBytes(Integer(L)); // contrôle EOF mutualisé
  SetLength(Result, L);
  Move(P^, Result[1], L);
end;

function TMMAPReader.ReadBuffer(var Buffer; Count: Int64): Int64;
var
  Available: Int64;
begin
  Available := FFileSize - FCurrentPos;
  if Count > Available then
    raise Exception.CreateFmt('TMMAPReader: lecture %d octets hors fichier (pos=%d, size=%d)',
      [Count, FCurrentPos, FFileSize]);
  Move(FPointer[FCurrentPos], Buffer, Count);
  Inc(FCurrentPos, Count);
  Result := Count;
end;

function TMMAPReader.Read(var Buffer; Count: Int64): Int64;
begin
  Result := ReadBuffer(Buffer, Count);
end;

end.
