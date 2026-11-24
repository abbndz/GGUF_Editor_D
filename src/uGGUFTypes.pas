unit uGGUFTypes;

interface

uses
  Classes, SysUtils, uMath;

const
  MaxItemsValuesEqual = 2048;

type
  TGgufStr = UTF8String;

  TGGUFValueType = (gvt_None = -1, gvt_UINT8 = 0, gvt_INT8 = 1, gvt_UINT16 = 2, gvt_INT16 = 3, gvt_UINT32 = 4,
    gvt_INT32 = 5, gvt_FLOAT32 = 6, gvt_BOOL = 7, gvt_STRING = 8, gvt_ARRAY = 9, gvt_UINT64 = 10, gvt_INT64 = 11,
    gvt_FLOAT64 = 12);

  TGGUFArray = class
  private
    FElemType: TGGUFValueType;
    FCount: Integer;
  public
    StrItems: TStringList; // Uniquement pour gvt_STRING
    DatItems: TBytes; // Uniquement pour les types numériques
    IsStringArray: Boolean;
    constructor Create;
    destructor Destroy; override;
    property ElemType: TGGUFValueType read FElemType write FElemType;
    property Count: Integer read FCount write FCount;

    function GetTypeSize: Integer;
    function GetItemValue(Index: Integer): string;
    function SetItemValue(Index: Integer; const AValue: string): Boolean;
    function GetItemAsString(i: Integer): string;
    function LoadFromText(const Text: string): Boolean;
    function SaveToText: string;
    function Preview(MaxItems: UInt64 = 8): string;
    function PreviewFull: string;
  private

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
    VStr: TGgufStr;
    VArr: TGGUFArray;

    constructor Create;
    destructor Destroy; override;

    function AsStrPrev(MaxItems: Integer = 8): string;
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
function GGUFValuesEqual(V1, V2: TGGUFValue;AsStrFull: Boolean = False): Boolean;
function ValueToStrPrev(V: TGGUFValue): string;
function ValueToStrFull(V: TGGUFValue): string;
function EscapeJSONString(const S: string): string;
function UnescapeJSONString(const S: string): string;
function ArrayToStrFull(A: TGGUFArray): string;
function ArrayToStrPrev(A: TGGUFArray; MaxItems: Integer = 3): string;
function ParseArrayStrict(const S: string; out ElemType: TGGUFValueType; out Items: TStringList): Boolean;

implementation

uses uStrUtils;

{ TGGUFArray }
constructor TGGUFArray.Create;
begin
  inherited Create;
  IsStringArray := False;
  StrItems := nil;
  DatItems := nil;
  FCount := 0;
  FElemType := gvt_STRING;
end;

destructor TGGUFArray.Destroy;
begin
  if Assigned(StrItems) then
    StrItems.Free;
  inherited;
end;

function TGGUFArray.GetTypeSize: Integer;
begin
  case FElemType of
    gvt_UINT8:
      Result := 1;
    gvt_INT8:
      Result := 1;
    gvt_UINT16:
      Result := 2;
    gvt_INT16:
      Result := 2;
    gvt_UINT32:
      Result := 4;
    gvt_INT32:
      Result := 4;
    gvt_UINT64:
      Result := 8;
    gvt_INT64:
      Result := 8;
    gvt_FLOAT32:
      Result := 4;
    gvt_FLOAT64:
      Result := 8;
    gvt_BOOL:
      Result := 1;
  else
    Result := 1;
  end;
end;

function TGGUFArray.GetItemValue(Index: Integer): string;
begin
  if Index < 0 then
    Exit('');
  if IsStringArray then
  begin
    if Index < StrItems.Count then
      Result := StrItems[Index]
    else
      Result := '';
  end
  else
  begin
    Result := GetItemAsString(Index);
  end;
end;

function TGGUFArray.SetItemValue(Index: Integer; const AValue: string): Boolean;
var
  NewV: TGGUFValue;
  VT: TGGUFValueType;
begin
  Result := False;
  if (Index < 0) or (Index >= FCount) then
    Exit;
  if IsStringArray then
  begin
    StrItems[Index] := UnescapeJSONString(AValue);
    Result := True;
    Exit;
  end;
  VT := FElemType;
  NewV := TGGUFValue.Create;
  try
    if ParseStringValue(UnescapeJSONString(AValue), VT, NewV) then
    begin
      case VT of
        gvt_UINT8:
          DatItems[Index] := NewV.VU8;
        gvt_INT8:
          DatItems[Index] := Byte(NewV.VI8);
        gvt_UINT16:
          Move(NewV.VU16, DatItems[Index * 2], 2);
        gvt_INT16:
          Move(NewV.VI16, DatItems[Index * 2], 2);
        gvt_UINT32:
          Move(NewV.VU32, DatItems[Index * 4], 4);
        gvt_INT32:
          Move(NewV.VI32, DatItems[Index * 4], 4);
        gvt_UINT64:
          Move(NewV.VU64, DatItems[Index * 8], 8);
        gvt_INT64:
          Move(NewV.VI64, DatItems[Index * 8], 8);
        gvt_FLOAT32:
          Move(NewV.VF32, DatItems[Index * 4], 4);
        gvt_FLOAT64:
          Move(NewV.VF64, DatItems[Index * 8], 8);
        gvt_BOOL:
          DatItems[Index] := Byte(NewV.VBool);
      else
        Exit;
      end;
      Result := True;
    end;
  finally
    NewV.Free;
  end;
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
    if Assigned(StrItems) then
      StrItems.Clear
    else
      StrItems := TStringList.Create;
    for i := 0 to Lines.Count - 1 do
      StrItems.Add(UnescapeJSONString(Lines[i]));
    IsStringArray := True;
    FCount := StrItems.Count;
    Result := FCount > 0;
  finally
    Lines.Free;
  end;
end;

function TGGUFArray.SaveToText: string;
var
  Lines: TStringList;
  i: Integer;
begin
  Result := '';
  Lines := TStringList.Create;
  try
    if IsStringArray then
    begin
      for i := 0 to StrItems.Count - 1 do
        Lines.Add(EscapeJSONString(StrItems[i]));
    end
    else
    begin
      case FElemType of
        gvt_UINT8:
          for i := 0 to Count - 1 do
            Lines.Add(IntToStr(DatItems[i]));
        gvt_INT8:
          for i := 0 to Count - 1 do
            Lines.Add(IntToStr(ShortInt(DatItems[i])));
        gvt_UINT16:
          for i := 0 to Count - 1 do
            Lines.Add(IntToStr(PWord(@DatItems[i * 2])^));
        gvt_INT16:
          for i := 0 to Count - 1 do
            Lines.Add(IntToStr(SmallInt(PWord(@DatItems[i * 2])^)));
        gvt_UINT32:
          for i := 0 to Count - 1 do
            Lines.Add(IntToStr(Cardinal(PCardinal(@DatItems[i * 4])^)));
        gvt_INT32:
          for i := 0 to Count - 1 do
            Lines.Add(IntToStr(Integer(PInteger(@DatItems[i * 4])^)));
        gvt_UINT64:
          for i := 0 to Count - 1 do
            Lines.Add(IntToStr(UInt64(PUInt64(@DatItems[i * 8])^)));
        gvt_INT64:
          for i := 0 to Count - 1 do
            Lines.Add(IntToStr(PInt64(@DatItems[i * 8])^));
        gvt_FLOAT32:
          for i := 0 to Count - 1 do
            Lines.Add(FloatToStr(PSingle(@DatItems[i * 4])^));
        gvt_FLOAT64:
          for i := 0 to Count - 1 do
            Lines.Add(FloatToStr(PDouble(@DatItems[i * 8])^));
        gvt_BOOL:
          for i := 0 to Count - 1 do
            Lines.Add(IfThen1(DatItems[i] <> 0, 'true', 'false'));
      end;
    end;
    Result := Lines.Text;
  finally
    Lines.Free;
  end;
end;

function TGGUFArray.GetItemAsString(i: Integer): string;
begin
  if IsStringArray then
  begin
    Result := StrItems[i];
    Exit;
  end;
  // Pour les types numériques : On ne convertit en texte QUE lors de l'appel de cette fonction (affichage)
  case FElemType of
    gvt_UINT8:
      Result := IntToStr(DatItems[i]);
    gvt_INT8:
      Result := IntToStr(ShortInt(DatItems[i]));
    gvt_UINT16:
      Result := IntToStr(PWord(@DatItems[i * 2])^);
    gvt_INT16:
      Result := IntToStr(SmallInt(PWord(@DatItems[i * 2])^));
    gvt_UINT32:
      Result := IntToStr(Cardinal(PCardinal(@DatItems[i * 4])^));
    gvt_INT32:
      Result := IntToStr(Integer(PInteger(@DatItems[i * 4])^));
    gvt_UINT64:
      Result := IntToStr(UInt64(PUInt64(@DatItems[i * 8])^));
    gvt_INT64:
      Result := IntToStr(PInt64(@DatItems[i * 8])^);
    gvt_FLOAT32:
      Result := FloatToStr(PSingle(@DatItems[i * 4])^);
    gvt_FLOAT64:
      Result := FloatToStr(PDouble(@DatItems[i * 8])^);
    gvt_BOOL:
      Result := IfThen1(DatItems[i] <> 0, 'true', 'false');
  else
    Result := '<non-string>';
  end;
end;

function TGGUFArray.Preview(MaxItems: UInt64 = 8): string;
var
  i, n: Integer;
  S: string;
begin
  n := Min(Count, MaxItems);
  Result := GGUFTypeToStr(ElemType) + ':[';
  for i := 0 to n - 1 do
  begin
    if i > 0 then
      Result := Result + ',';
    if IsStringArray then
    begin
      S := '"' + EscapeJSONString(StrItems[i]) + '"';
      if length(S) > 5 * MaxItems then
        S := copy(S, 1, 5 * MaxItems) + '...';
    end
    else
      S := GetItemAsString(i);
    // S := Trim(GetItemAsString(i));
    Result := Result + S;
  end;
  if Count > MaxItems then
    Result := Result + Format(', ... (%d items)]', [Count])
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

function TGGUFValue.AsStrPrev(MaxItems: Integer = 8): string;
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
      Result := IfThen1(VBool, 'true', 'false');
    gvt_STRING:
    begin
        Result := AToU8(VStr);
        if length(result) > 5 * MaxItems then
          Result := copy(Result, 1, 5 * MaxItems) + '...';
    end;
    gvt_ARRAY:
      if Assigned(VArr) then Result := VArr.Preview(MaxItems) else Result := 'ARRAY:<nil>';
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
      Result := IfThen1(VBool, 'true', 'false');
    gvt_STRING:
      Result := AToU8(VStr);
    gvt_ARRAY:
      if Assigned(VArr) then Result := VArr.PreviewFull else Result := 'ARRAY:<nil>';
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
begin
  Result := TGGUFValue.Create;
  Result.ValueType := ValueType;
  if Assigned(VArr) then
  begin
    Result.VArr := TGGUFArray.Create;
    Result.VArr.ElemType := VArr.ElemType;
    Result.VArr.Count := VArr.Count;
    if VArr.IsStringArray then
    begin
      Result.VArr.IsStringArray := True;
      Result.VArr.StrItems := TStringList.Create;
      Result.VArr.StrItems.Assign(VArr.StrItems);
    end
    else
    begin
      Result.VArr.IsStringArray := False;
      if Length(VArr.DatItems) > 0 then
      begin
        SetLength(Result.VArr.DatItems, Length(VArr.DatItems));
        Move(VArr.DatItems[0], Result.VArr.DatItems[0], Length(VArr.DatItems));
      end;
    end;
  end
  else
  begin
    //Result.ValueType := ValueType;
    case ValueType of
      gvt_UINT8:
        Result.VU8 := VU8;
      gvt_INT8:
        Result.VI8 := VI8;
      gvt_UINT16:
        Result.VU16 := VU16;
      gvt_INT16:
        Result.VI16 := VI16;
      gvt_UINT32:
        Result.VU32 := VU32;
      gvt_INT32:
        Result.VI32 := VI32;
      gvt_UINT64:
        Result.VU64 := VU64;
      gvt_INT64:
        Result.VI64 := VI64;
      gvt_FLOAT32:
        Result.VF32 := VF32;
      gvt_FLOAT64:
        Result.VF64 := VF64;
      gvt_BOOL:
        Result.VBool := VBool;
      gvt_STRING:
        Result.VStr := VStr;
    end;
  end;
end;

function GGUFValuesEqual(V1, V2: TGGUFValue; AsStrFull: Boolean = False): Boolean;
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

  // Gestion des tableaux.
  if V1.ValueType = gvt_ARRAY then
  begin
    if (V1.VArr = nil) or (V2.VArr = nil) then
      Exit(False);

    if V1.VArr.Count <> V2.VArr.Count then
      Exit(False);

    if V1.VArr.ElemType <> V2.VArr.ElemType then
      Exit(False);
  end;

  if AsStrFull then
  begin
    S1 := V1.AsStrFull;
    S2 := V2.AsStrFull;
  end
  else
  begin
    S1 := V1.AsStrPrev(MaxItemsValuesEqual);
    S2 := V2.AsStrPrev(MaxItemsValuesEqual);
  end;
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
  Key := U8ToA(sKey);
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
  Items: TStringList;
  ElemType: TGGUFValueType;
  i: Integer;
begin
  Result := False;
  //if not Assigned(AValue) then
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
          AValue.VI8 := ShortInt(pStrToInt16(S));
          Result := True;
        end;
      gvt_UINT16:
        begin
          AValue.VU16 := pStrToUInt16(S);
          Result := True;
        end;
      gvt_INT16:
        begin
          AValue.VI16 := pStrToInt16(S);
          Result := True;
        end;
      gvt_UINT32:
        begin
          AValue.VU32 := pStrToUInt32(S);
          Result := True;
        end;
      gvt_INT32:
        begin
          AValue.VI32 := pStrToInt32(S);
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
          begin
            AValue.VF32 := Single(pStrToFloat(S));
            Result := True;
          end;
        end;
      gvt_FLOAT64:
        begin
          AValue.VF64 := Double(pStrToFloat(S));
          Result := True;
        end;
      gvt_BOOL:
        begin
          AValue.VBool := pStrToBool(S);
          Result := True;
        end;
      gvt_STRING:
        begin
          AValue.VStr := U8ToA(S);
          Result := True;
        end;
      gvt_ARRAY:
        begin
          if ParseArrayStrict(S, ElemType, Items) then
          begin
            AValue.VArr := TGGUFArray.Create;
            AValue.VArr.ElemType := ElemType;
            AValue.VArr.Count := Items.Count;
            if ElemType = gvt_STRING then
            begin
              AValue.VArr.IsStringArray := True;
              AValue.VArr.StrItems := TStringList.Create;
              AValue.VArr.StrItems.Assign(Items);
            end
            else
            begin
              AValue.VArr.IsStringArray := False;
              var
              ByteSizePerElem := AValue.VArr.GetTypeSize;
              var
              TotalBytes := Items.Count * ByteSizePerElem;
              SetLength(AValue.VArr.DatItems, TotalBytes);
              for i := 0 to Items.Count - 1 do
              begin
                var
                ValStr := Items[i];
                var
                Offset := i * ByteSizePerElem;
                case ElemType of
                  gvt_UINT8:
                    AValue.VArr.DatItems[Offset] := Byte(pStrToUInt8(ValStr));
                  gvt_INT8:
                    AValue.VArr.DatItems[Offset] := SmallInt(pStrToInt16(ValStr));
                  gvt_UINT16:
                    begin
                      var
                        V: Word := pStrToUInt16(ValStr);
                      Move(V, AValue.VArr.DatItems[Offset], 2);
                    end;
                  gvt_INT16:
                    begin
                      var
                        V: SmallInt := SmallInt(pStrToInt16(ValStr));
                      Move(V, AValue.VArr.DatItems[Offset], 2);
                    end;
                  gvt_UINT32:
                    begin
                      var
                        V: Cardinal := pStrToUInt32(ValStr);
                      Move(V, AValue.VArr.DatItems[Offset], 4);
                    end;
                  gvt_INT32:
                    begin
                      var
                        V: Integer := pStrToInt32(ValStr);
                      Move(V, AValue.VArr.DatItems[Offset], 4);
                    end;
                  gvt_UINT64:
                    begin
                      var
                        V: UInt64 := pStrToUInt64(ValStr);
                      Move(V, AValue.VArr.DatItems[Offset], 8);
                    end;
                  gvt_INT64:
                    begin
                      var
                        V: Int64 := pStrToInt64(ValStr);
                      Move(V, AValue.VArr.DatItems[Offset], 8);
                    end;
                  gvt_FLOAT32:
                    begin
                      var
                        V: Single := Single(pStrToFloat(ValStr));
                      Move(V, AValue.VArr.DatItems[Offset], 4);
                    end;
                  gvt_FLOAT64:
                    begin
                      var
                        V: Double := pStrToFloat(ValStr);
                      Move(V, AValue.VArr.DatItems[Offset], 8);
                    end;
                  gvt_BOOL:
                    if pStrToBool(ValStr) then
                      AValue.VArr.DatItems[Offset] := 1
                    else
                      AValue.VArr.DatItems[Offset] := 0;
                end;
              end;
            end;
            Items.Free;
            Result := True;
          end;
        end;
    else
      //begin FreeAndNil(AValue); Exit(False); end;
      AValue.Free;
    end;
  except
    //FreeAndNil(AValue);;//
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


