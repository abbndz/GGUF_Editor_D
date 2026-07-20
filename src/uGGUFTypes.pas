unit uGGUFTypes;

interface

uses
  Classes, SysUtils, uMath, uGgufStrUtils;

type
  TGGUFValueType = (gvt_None = -1, gvt_UINT8 = 0, gvt_INT8 = 1, gvt_UINT16 = 2, gvt_INT16 = 3, gvt_UINT32 = 4,
    gvt_INT32 = 5, gvt_FLOAT32 = 6, gvt_BOOL = 7, gvt_STRING = 8, gvt_ARRAY = 9, gvt_UINT64 = 10, gvt_INT64 = 11,
    gvt_FLOAT64 = 12);

  TGGUFArray = class
  private
    FElemType: TGGUFValueType;
  public
    Items: TStringList;
    constructor Create;
    destructor Destroy; override;
    property ElemType: TGGUFValueType read FElemType write FElemType;

    // Import/Export au format simple TStrings (une valeur par ligne)
    function LoadFromText(const Text: string): Boolean;
    function SaveToText: string;

    // Preview format TYPE:[val1,val2]
    function Preview(MaxItems: Integer = 5): string;
    function PreviewFull: string;
  end;

  TGGUFValue = class
  public
    ValueType: TGGUFValueType;
    VU8: Byte;
    VI8: ShortInt;
    VU16: Word;
    VI16: SmallInt;
    VU32: Cardinal;
    VI32: Integer;
    VU64: UInt64;
    VI64: Int64;
    VF32: Single;
    VF64: Double;
    VBool: Boolean;
    VStr: AnsiString;
    VArr: TGGUFArray;

    constructor Create;
    destructor Destroy; override;

    function AsStrPrev(MaxItems: Integer = 5): string;
    function AsStrFull: string;
    function AsInteger: Integer;
    function Clone: TGGUFValue;
  end;

  TGGUFKeyValue = class
  public
    Key: AnsiString;
    Val: TGGUFValue;
    Keep: Boolean;
    constructor Create;
    destructor Destroy; override;
    function Clone: TGGUFKeyValue;
  end;

function GGUFTypeToStr(VT: TGGUFValueType): string;
function StrToGGUFType(const S: string): TGGUFValueType;
function CreatNewKeyValue(const sKey, sVal: String; AType: TGGUFValueType): TGGUFKeyValue;
function ParseStringValue(const S: string; AType: TGGUFValueType; out AValue: TGGUFValue): Boolean;
function GGUFValuesEqual(V1, V2: TGGUFValue): Boolean;
function ValueToStrPrev(V: TGGUFValue): string;
function ValueToStrFull(V: TGGUFValue): string;
function EscapeJSONString(const S: string): string;
function UnescapeJSONString(const S: string): string;
function ArrayToStrFull(A: TGGUFArray): string;
function ArrayToStrPrev(A: TGGUFArray; MaxItems: Integer = 3): string;
function ParseArrayStrict(const S: string; out ElemType: TGGUFValueType; out Items: TStringList): Boolean;

implementation

{ TGGUFArray }
constructor TGGUFArray.Create;
begin
  inherited Create;
  Items := TStringList.Create;
  FElemType := gvt_STRING;
end;

destructor TGGUFArray.Destroy;
begin
  Items.Free;
  inherited;
end;

function TGGUFArray.LoadFromText(const Text: string): Boolean;
var
  Lines: TStringList;
  i: Integer;
begin
  Result := False;
  Lines := TStringList.Create;
  try
    Lines.Text := Text;
    Items.Clear;
    for i := 0 to Lines.Count - 1 do
      Items.Add(Lines[i]);
    Result := Items.Count > 0;
  finally
    Lines.Free;
  end;
end;

function TGGUFArray.SaveToText: string;
begin
  Result := Items.Text;
end;

function TGGUFArray.Preview(MaxItems: Integer = 5): string;
var
  i, n: Integer;
  S: string;
begin
  if not Assigned(Self) then
    Exit('ARRAY:[]');
  n := Min(Items.Count, MaxItems);
  Result := GGUFTypeToStr(ElemType) + ':[';
  for i := 0 to n - 1 do
  begin
    if i > 0 then
      Result := Result + ',';
    if ElemType = gvt_STRING then
      S := '"' + EscapeJSONString(Items[i]) + '"'
    else
      S := Trim(Items[i]);
    Result := Result + S;
  end;
  if Items.Count > MaxItems then
    Result := Result + Format(', ... (%d items)]', [Items.Count])
  else
    Result := Result + ']';
end;

function TGGUFArray.PreviewFull: string;
begin
  Result := Preview(MaxInt);
end;

{ TGGUFValue }
constructor TGGUFValue.Create;
begin
  inherited Create;
  VArr := nil;
end;

destructor TGGUFValue.Destroy;
begin
  if Assigned(VArr) then
    VArr.Free;
  inherited;
end;

function TGGUFValue.AsStrPrev(MaxItems: Integer = 5): string;
begin
  case ValueType of
    gvt_UINT8:
      Result := IntToStr(VU8);
    gvt_INT8:
      Result := IntToStr(VI8);
    gvt_UINT16:
      Result := IntToStr(VU16);
    gvt_INT16:
      Result := IntToStr(VI16);
    gvt_UINT32:
      Result := IntToStr(VU32);
    gvt_INT32:
      Result := IntToStr(VI32);
    gvt_UINT64:
      Result := IntToStr(VU64);
    gvt_INT64:
      Result := IntToStr(VI64);
    gvt_FLOAT32:
      Result := FloatToStrF(VF32, ffFixed, 15, 9);
    gvt_FLOAT64:
      Result := FloatToStrF(VF64, ffFixed, 15, 9);
    gvt_BOOL:
      Result := IfThen(VBool, 'true', 'false');
    gvt_STRING:
      Result := string(VStr);
    gvt_ARRAY:
      Result := VArr.Preview(MaxItems);
  else
    Result := '<unknown>';
  end;
end;

function TGGUFValue.AsStrFull: string;
begin
  case ValueType of
    gvt_UINT8:
      Result := IntToStr(VU8);
    gvt_INT8:
      Result := IntToStr(VI8);
    gvt_UINT16:
      Result := IntToStr(VU16);
    gvt_INT16:
      Result := IntToStr(VI16);
    gvt_UINT32:
      Result := IntToStr(VU32);
    gvt_INT32:
      Result := IntToStr(VI32);
    gvt_UINT64:
      Result := IntToStr(VU64);
    gvt_INT64:
      Result := IntToStr(VI64);
    gvt_FLOAT32:
      Result := FloatToStrF(VF32, ffFixed, 15, 9);
    gvt_FLOAT64:
      Result := FloatToStrF(VF64, ffFixed, 15, 9);
    gvt_BOOL:
      Result := IfThen(VBool, 'true', 'false');
    gvt_STRING:
      Result := string(VStr);
    gvt_ARRAY:
      Result := VArr.PreviewFull;
  else
    Result := '<unknown>';
  end;
end;

function TGGUFValue.AsInteger: Integer;
begin
  case ValueType of
    gvt_UINT8:
      Result := Integer(VU8);
    gvt_INT8:
      Result := Integer(VI8);
    gvt_UINT16:
      Result := Integer(VU16);
    gvt_INT16:
      Result := Integer(VI16);
    gvt_UINT32:
      Result := Integer(VU32);
    gvt_INT32:
      Result := VI32;
    gvt_UINT64:
      Result := Integer(Int64(VU64));
    gvt_INT64:
      Result := VI64;
    gvt_FLOAT32:
      Result := Integer(trunc(VF32));
    gvt_FLOAT64:
      Result := Integer(trunc(VF64));
    gvt_BOOL:
      if VBool then
        Result := 1
      else
        Result := 0;
  else
    Result := 0;
  end;
end;

function TGGUFValue.Clone: TGGUFValue;
var
  i: Integer;
begin
  Result := TGGUFValue.Create;
  Result.ValueType := ValueType;
  Result.VU8 := VU8;
  Result.VI8 := VI8;
  Result.VU16 := VU16;
  Result.VI16 := VI16;
  Result.VU32 := VU32;
  Result.VI32 := VI32;
  Result.VU64 := VU64;
  Result.VI64 := VI64;
  Result.VF32 := VF32;
  Result.VF64 := VF64;
  Result.VBool := VBool;
  Result.VStr := VStr;
  if Assigned(VArr) then
  begin
    Result.VArr := TGGUFArray.Create;
    Result.VArr.ElemType := VArr.ElemType;
    Result.VArr.Items.Assign(VArr.Items);
  end;
end;

function GGUFValuesEqual(V1, V2: TGGUFValue): Boolean;
var
  S1, S2: string;
  Eps: Double;
begin
  if V1 = V2 then
    Exit(True);
  if (V1 = nil) or (V2 = nil) then
    Exit(False);
  if V1.ValueType <> V2.ValueType then
    Exit(False);

  if V1.ValueType in [gvt_FLOAT32, gvt_FLOAT64] then
  begin
    Eps := 1E-6;
    if V1.ValueType = gvt_FLOAT32 then
      Result := (abs(V1.VF32 - V2.VF32) < Eps)
    else
      Result := (abs(V1.VF64 - V2.VF64) < Eps);
    Exit;
  end;

  // Pour le reste, comparaison textuelle normalisée
  S1 := V1.AsStrFull;
  S2 := V2.AsStrFull;
  Result := SameText(S1, S2);
end;

function ValueToStrPrev(V: TGGUFValue): string;
begin
  if not Assigned(V) then
    Exit('');
  Result := V.AsStrPrev;
end;

function ValueToStrFull(V: TGGUFValue): string;
begin
  if not Assigned(V) then
    Exit('');
  Result := V.AsStrFull;
end;

function EscapeJSONString(const S: string): string;
var
  i: Integer;
  ch: WideChar;
begin
  Result := '';
  for i := 1 to Length(S) do
  begin
    ch := WideChar(S[i]);
    case ch of
      '"':
        Result := Result + '\"';
      '\':
        Result := Result + '\\';
      #8:
        Result := Result + '\b';
      #9:
        Result := Result + '\t';
      #10:
        Result := Result + '\n';
      #13:
        Result := Result + '\r';
    else
      if Ord(ch) < 32 then
        Result := Result + '\u' + IntToHex(Ord(ch), 4)
      else
        Result := Result + Char(ch);
    end;
  end;
end;

function HexToInt4(c: Char): Integer;
begin
  if (c >= '0') and (c <= '9') then
    Result := Ord(c) - Ord('0')
  else if (c >= 'A') and (c <= 'F') then
    Result := 10 + (Ord(c) - Ord('A'))
  else if (c >= 'a') and (c <= 'f') then
    Result := 10 + (Ord(c) - Ord('a'))
  else
    Result := -1;
end;

function UnescapeJSONString(const S: string): string;
var
  i, V, A, b, c, d: Integer;
  ch: Char;
begin
  Result := '';
  i := 1;
  while i <= Length(S) do
  begin
    ch := S[i];
    if ch <> '\' then
    begin
      Result := Result + ch;
      Inc(i);
      Continue;
    end;
    Inc(i);
    if i > Length(S) then
      raise Exception.Create('Bad escape');
    ch := S[i];
    case ch of
      '"':
        Result := Result + '"';
      '\':
        Result := Result + '\';
      'b':
        Result := Result + #8;
      't':
        Result := Result + #9;
      'n':
        Result := Result + #10;
      'r':
        Result := Result + #13;
      'u':
        begin
          if i + 4 > Length(S) then
            raise Exception.Create('Bad \uXXXX');
          A := HexToInt4(S[i + 1]);
          b := HexToInt4(S[i + 2]);
          c := HexToInt4(S[i + 3]);
          d := HexToInt4(S[i + 4]);
          if (A < 0) or (b < 0) or (c < 0) or (d < 0) then
            raise Exception.Create('Bad \uXXXX');
          V := (A shl 12) or (b shl 8) or (c shl 4) or d;
          Result := Result + WideChar(V);
          Inc(i, 4);
        end;
    else
      raise Exception.Create('Unknown escape: \' + ch);
    end;
    Inc(i);
  end;
end;

function ArrayToStrFull(A: TGGUFArray): string;
begin
  Result := A.PreviewFull;
end;

function ArrayToStrPrev(A: TGGUFArray; MaxItems: Integer = 3): string;
begin
  Result := A.Preview(MaxItems);
end;

function ParseElemTypeText(const T: string; out VT: TGGUFValueType): Boolean;
begin
  Result := True;
  VT := TGGUFValueType(StrToGGUFType(T));
  if VT = gvt_None then
    Result := False;
end;

function ParseArrayStrict(const S: string; out ElemType: TGGUFValueType; out Items: TStringList): Boolean;
var
  p, i: Integer;
  head, body, tok: string;
  ch: Char;
  inStr, esc: Boolean;
  procedure AddToken(const T: string);
  begin
    if ElemType = gvt_STRING then
      Items.Add(UnescapeJSONString(T))
    else
      Items.Add(Trim(T));
  end;
  function SkipSpaces(var idx: Integer): Boolean;
  begin
    while (idx <= Length(body)) and (body[idx] <= ' ') do
      Inc(idx);
    Result := idx <= Length(body);
  end;

begin
  Result := False;
  Items := nil;
  p := pos(':', S);
  if p <= 0 then
    Exit;
  head := Trim(Copy(S, 1, p - 1));
  body := Trim(Copy(S, p + 1, MaxInt));
  if (Length(body) >= 2) and (body[1] = '[') and (body[Length(body)] = ']') then
    body := Copy(body, 2, Length(body) - 2);
  if not ParseElemTypeText(head, ElemType) then
    Exit;
  Items := TStringList.Create;
  try
    i := 1;
    while True do
    begin
      if not SkipSpaces(i) then
        Break;
      if ElemType = gvt_STRING then
      begin
        if body[i] <> '"' then
          raise Exception.Create('ARRAY STRING: expected "');
        Inc(i);
        tok := '';
        inStr := True;
        esc := False;
        while i <= Length(body) do
        begin
          ch := body[i];
          if esc then
          begin
            tok := tok + '\' + ch;
            esc := False;
            Inc(i);
            Continue;
          end;
          if ch = '\' then
          begin
            esc := True;
            Inc(i);
            Continue;
          end;
          if ch = '"' then
          begin
            inStr := False;
            Inc(i);
            Break;
          end;
          tok := tok + ch;
          Inc(i);
        end;
        if inStr then
          raise Exception.Create('Unterminated string');
        AddToken(tok);
      end
      else
      begin
        tok := '';
        while (i <= Length(body)) and (body[i] <> ',') do
        begin
          tok := tok + body[i];
          Inc(i);
        end;
        tok := Trim(tok);
        if tok <> '' then
          AddToken(tok);
      end;
      SkipSpaces(i);
      if (i <= Length(body)) and (body[i] = ',') then
        Inc(i)
      else
        Break;
    end;
    Result := True;
  except
    Items.Free;
    Items := nil;
    raise;
  end;
end;

function GGUFTypeToStr(VT: TGGUFValueType): string;
begin
  case VT of
    gvt_UINT8:
      Result := 'UINT8';
    gvt_INT8:
      Result := 'INT8';
    gvt_UINT16:
      Result := 'UINT16';
    gvt_INT16:
      Result := 'INT16';
    gvt_UINT32:
      Result := 'UINT32';
    gvt_INT32:
      Result := 'INT32';
    gvt_UINT64:
      Result := 'UINT64';
    gvt_INT64:
      Result := 'INT64';
    gvt_FLOAT32:
      Result := 'FLOAT32';
    gvt_FLOAT64:
      Result := 'FLOAT64';
    gvt_BOOL:
      Result := 'BOOL';
    gvt_STRING:
      Result := 'STRING';
    gvt_ARRAY:
      Result := 'ARRAY';
  else
    Result := 'UNKNOWN';
  end;
end;

function StrToGGUFType(const S: string): TGGUFValueType;
var
  T: string;
begin
  T := UpperCase(Trim(S));
  if T = 'UINT8' then
    Result := gvt_UINT8
  else if T = 'INT8' then
    Result := gvt_INT8
  else if T = 'UINT16' then
    Result := gvt_UINT16
  else if T = 'INT16' then
    Result := gvt_INT16
  else if T = 'UINT32' then
    Result := gvt_UINT32
  else if T = 'INT32' then
    Result := gvt_INT32
  else if T = 'UINT64' then
    Result := gvt_UINT64
  else if T = 'INT64' then
    Result := gvt_INT64
  else if T = 'FLOAT32' then
    Result := gvt_FLOAT32
  else if T = 'FLOAT64' then
    Result := gvt_FLOAT64
  else if T = 'BOOL' then
    Result := gvt_BOOL
  else if T = 'ARRAY' then
    Result := gvt_ARRAY
  else if T = 'STRING' then
    Result := gvt_STRING
  else
    Result := gvt_None;
end;

Function CreatNewKeyValue(const sKey, sVal: String; AType: TGGUFValueType): TGGUFKeyValue;
var
  Key: AnsiString;
  NewV: TGGUFValue;
  S: string;
begin
  Key := AnsiString(sKey);
  if Key = '' then
    raise Exception.Create('Key vide.');
  Result := TGGUFKeyValue.Create;
  Result.Key := Key;
  NewV := TGGUFValue.Create;
  S := Trim(sVal);
  ParseStringValue(S, AType, NewV);
  Result.Val := NewV;
  Result.Keep := True;
end;

function ParseStringValue(const S: string; AType: TGGUFValueType; out AValue: TGGUFValue): Boolean;
var
  FS: TFormatSettings;
  TempDouble: Double;
  TempInt64: Int64;
  TempUInt64: UInt64;
  Items: TStringList;
  ElemType: TGGUFValueType;
begin
  Result := False;
  AValue := TGGUFValue.Create;
  AValue.ValueType := AType;
  FS := TFormatSettings.Create;
  FS.DecimalSeparator := '.';
  try
    case AType of
      gvt_UINT8:
        begin
          AValue.VU8 := Byte(pStrToUInt8(S));
          Result := True;
        end;
      gvt_INT8:
        begin
          AValue.VI8 := ShortInt(pStrToInt64(S));
          Result := True;
        end;
      gvt_UINT16:
        begin
          AValue.VU16 := Word(pStrToUInt16(S));
          Result := True;
        end;
      gvt_INT16:
        begin
          AValue.VI16 := SmallInt(pStrToInt64(S));
          Result := True;
        end;
      gvt_UINT32:
        begin
          AValue.VU32 := Cardinal(pStrToUInt32(S));
          Result := True;
        end;
      gvt_INT32:
        begin
          AValue.VI32 := StrToInt(S);
          Result := True;
        end;
      gvt_UINT64:
        begin
          AValue.VU64 := pStrToUInt64(S);
          Result := True;
        end;
      gvt_INT64:
        begin
          AValue.VI64 := pStrToInt64(S);
          Result := True;
        end;
      gvt_FLOAT32:
        begin
          if TryStrToFloat(S, TempDouble, FS) then
          begin
            AValue.VF32 := Single(TempDouble);
            Result := True;
          end;
        end;
      gvt_FLOAT64:
        begin
          if TryStrToFloat(S, TempDouble, FS) then
          begin
            AValue.VF64 := TempDouble;
            Result := True;
          end;
        end;
      gvt_BOOL:
        begin
          AValue.VBool := pStrToBool(S);
          Result := True;
        end;
      gvt_STRING:
        begin
          AValue.VStr := AnsiString(S);
          Result := True;
        end;
      gvt_ARRAY:
        begin
          if ParseArrayStrict(S, ElemType, Items) then
          begin
            AValue.VArr := TGGUFArray.Create;
            AValue.VArr.ElemType := ElemType;
            AValue.VArr.Items.Assign(Items);
            Items.Free;
            Result := True;
          end;
        end;
    else
      AValue.Free;
    end;
  except
    AValue.Free;
    raise;
  end;
end;

constructor TGGUFKeyValue.Create;
begin
  inherited Create;
  Val := TGGUFValue.Create;
  Keep := True;
end;

destructor TGGUFKeyValue.Destroy;
begin
  Val.Free;
  inherited;
end;

function TGGUFKeyValue.Clone: TGGUFKeyValue;
begin
  Result := TGGUFKeyValue.Create;
  Result.Key := Key;
  Result.Val.Free;
  Result.Val := Val.Clone;
  Result.Keep := Keep;
end;

end.
