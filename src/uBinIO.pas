unit uBinIO;

interface

uses
  Classes, SysUtils
  // , Winapi.Windows
    ;

var
  iUnused: Integer;

type
  EBinIO = class(Exception);

  TBinReader = class
  private
    FStream: TStream;
  public
    constructor Create(AStream: TStream);

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

    function ReadBytes(Count: Integer): TBytes;
    function ReadStringU64: AnsiString;

    property Stream: TStream read FStream;
  end;

  TBinWriter = class
  private
    FStream: TStream;
  public
    constructor Create(AStream: TStream);

    procedure WriteBuffer(PB: PByte; Count: Int64);

    procedure WriteU8(V: Byte);
    procedure WriteI8(V: ShortInt);

    procedure WriteU16(V: Word);
    procedure WriteI16(V: SmallInt);

    procedure WriteU32(V: Cardinal);
    procedure WriteI32(V: Integer);

    procedure WriteU64(V: UInt64);
    procedure WriteI64(V: Int64);

    procedure WriteF32(V: Single);
    procedure WriteF64(V: Double);

    procedure WriteBoolI8(V: Boolean);

    procedure WriteBytes(const B: TBytes);
    procedure WriteStringU64(const S: AnsiString);

    procedure PadToAlignment(Align: Cardinal; PadByteData: Byte = 0);

    property Stream: TStream read FStream;
  end;

implementation

constructor TBinReader.Create(AStream: TStream);
begin
  inherited Create;
  FStream := AStream;
end;

function TBinReader.ReadBytes(Count: Integer): TBytes;
begin
  SetLength(Result, Count);
  if Count > 0 then
    if FStream.Read(Result[0], Count) <> Count then
      raise EBinIO.Create('Unexpected EOF');
end;

function TBinReader.ReadU8: Byte;
begin
  if FStream.Read(Result, 1) <> 1 then
    raise EBinIO.Create('EOF U8');
end;

function TBinReader.ReadI8: ShortInt;
begin
  if FStream.Read(Result, 1) <> 1 then
    raise EBinIO.Create('EOF I8');
end;

function TBinReader.ReadU16: Word;
var
  B: array [0 .. 1] of Byte;
begin
  if FStream.Read(B[0], 2) <> 2 then
    raise EBinIO.Create('EOF U16');
  Result := Word(B[0]) or (Word(B[1]) shl 8);
end;

function TBinReader.ReadI16: SmallInt;
begin
  Result := SmallInt(ReadU16);
end;

function TBinReader.ReadU32: Cardinal;
var
  B: array [0 .. 3] of Byte;
begin
  if FStream.Read(B[0], 4) <> 4 then
    raise EBinIO.Create('EOF U32');
  Result := Cardinal(B[0]) or (Cardinal(B[1]) shl 8) or (Cardinal(B[2]) shl 16) or (Cardinal(B[3]) shl 24);
end;

function TBinReader.ReadI32: Integer;
begin
  Result := Integer(ReadU32);
end;

function TBinReader.ReadU64: UInt64;
var
  lo, hi: Cardinal;
begin
  lo := ReadU32;
  hi := ReadU32;
  Result := UInt64(lo) or (UInt64(hi) shl 32);
end;

function TBinReader.ReadI64: Int64;
begin
  Result := Int64(ReadU64);
end;

function TBinReader.ReadF32: Single;
var
  u: Cardinal;
begin
  u := ReadU32;
  Move(u, Result, SizeOf(Result));
end;

function TBinReader.ReadF64: Double;
var
  u: UInt64;
begin
  u := ReadU64;
  Move(u, Result, SizeOf(Result));
end;

function TBinReader.ReadBoolI8: Boolean;
begin
  Result := (ReadI8 <> 0);
end;

function TBinReader.ReadStringU64: AnsiString;
var
  L: UInt64;
  B: TBytes;
begin
  try
    L := ReadU64;
    if L > UInt64(1024 * 1024 * 64) then // garde-fou simple
      raise EBinIO.Create('String too large');
    if L > 0 then
    begin
      B := ReadBytes(Integer(L));
      SetString(Result, PAnsiChar(@B[0]), Length(B));
    end
    else
    begin
      iUnused := iUnused + 1;
      Result := ' '; // 'unused' + IntToStr(iUnused);
    end;
  except
  end;
end;

constructor TBinWriter.Create(AStream: TStream);
begin
  inherited Create;
  FStream := AStream;
end;

procedure TBinWriter.WriteBytes(const B: TBytes);
begin
  if Length(B) > 0 then
    FStream.WriteBuffer(B[0], Length(B));
end;

procedure TBinWriter.WriteBuffer(PB: PByte; Count: Int64);
begin
  if Count > 0 then
    FStream.WriteBuffer(PB[0], Count);
end;

procedure TBinWriter.WriteU8(V: Byte);
begin
  FStream.WriteBuffer(V, 1);
end;

procedure TBinWriter.WriteI8(V: ShortInt);
begin
  FStream.WriteBuffer(V, 1);
end;

procedure TBinWriter.WriteU16(V: Word);
var
  B: array [0 .. 1] of Byte;
begin
  B[0] := Byte(V and $FF);
  B[1] := Byte((V shr 8) and $FF);
  FStream.WriteBuffer(B[0], 2);
end;

procedure TBinWriter.WriteI16(V: SmallInt);
begin
  WriteU16(Word(V));
end;

procedure TBinWriter.WriteU32(V: Cardinal);
var
  B: array [0 .. 3] of Byte;
begin
  B[0] := Byte(V and $FF);
  B[1] := Byte((V shr 8) and $FF);
  B[2] := Byte((V shr 16) and $FF);
  B[3] := Byte((V shr 24) and $FF);
  FStream.WriteBuffer(B[0], 4);
end;

procedure TBinWriter.WriteI32(V: Integer);
begin
  WriteU32(Cardinal(V));
end;

procedure TBinWriter.WriteU64(V: UInt64);
begin
  WriteU32(Cardinal(V and $FFFFFFFF));
  WriteU32(Cardinal((V shr 32) and $FFFFFFFF));
end;

procedure TBinWriter.WriteI64(V: Int64);
begin
  WriteU64(UInt64(V));
end;

procedure TBinWriter.WriteF32(V: Single);
var
  u: Cardinal;
begin
  Move(V, u, SizeOf(u));
  WriteU32(u);
end;

procedure TBinWriter.WriteF64(V: Double);
var
  u: UInt64;
begin
  Move(V, u, SizeOf(u));
  WriteU64(u);
end;

procedure TBinWriter.WriteBoolI8(V: Boolean);
begin
  if V then
    WriteI8(1)
  else
    WriteI8(0);
end;

procedure TBinWriter.WriteStringU64(const S: AnsiString);
begin
  if Length(S) > 0 then
  begin
    WriteU64(UInt64(Length(S)));
    FStream.WriteBuffer(S[1], Length(S));
  end
  else
  begin
    WriteU64(UInt64(1));
    FStream.WriteBuffer(String(' ')[1], 1);
  end;
end;

procedure TBinWriter.PadToAlignment(Align: Cardinal; PadByteData: Byte);
var
  PosNow: Int64;
  Pad: Cardinal;
begin
  if Align = 0 then
    Exit;
  PosNow := FStream.Position;
  Pad := Cardinal((Align - (PosNow mod Align)) mod Align);
  while Pad > 0 do
  begin
    FStream.WriteBuffer(PadByteData, 1);
    Dec(Pad);
  end;
end;

end.
