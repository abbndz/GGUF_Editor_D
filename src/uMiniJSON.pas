unit uMiniJSON;

interface

uses
  Classes, SysUtils;

type
  TMJKind = (mjNull, mjBool, mjNumber, mjString, mjArray, mjObject);

  TMJValue = class
  public
    Kind: TMJKind;
    BoolVal: Boolean;
    NumVal: Double;
    StrVal: UnicodeString;
    Arr: TList;          // of TMJValue
    ObjKeys: TStringList;
    ObjVals: TList;      // of TMJValue
    constructor Create;
    destructor Destroy; override;

    function ObjGet(const Key: UnicodeString): TMJValue;
  end;

function MJParse(const S: UnicodeString): TMJValue;

implementation

type
  TMJParser = class
  private
    P: PWideChar;
    function Peek: WideChar;
    function Next: WideChar;
    procedure SkipWS;
    function ParseValue: TMJValue;
    function ParseString: UnicodeString;
    function ParseNumber: Double;
    function ParseLiteral(const Lit: UnicodeString): Boolean;
    function ParseArray: TMJValue;
    function ParseObject: TMJValue;
  end;

constructor TMJValue.Create;
begin
  inherited Create;
  Arr := nil;
  ObjKeys := nil;
  ObjVals := nil;
end;

destructor TMJValue.Destroy;
var i: Integer;
begin
  if Assigned(Arr) then
  begin
    for i := 0 to Arr.Count - 1 do TMJValue(Arr[i]).Free;
    Arr.Free;
  end;
  if Assigned(ObjVals) then
  begin
    for i := 0 to ObjVals.Count - 1 do TMJValue(ObjVals[i]).Free;
    ObjVals.Free;
  end;
  if Assigned(ObjKeys) then ObjKeys.Free;
  inherited;
end;

function TMJValue.ObjGet(const Key: UnicodeString): TMJValue;
var idx: Integer;
begin
  Result := nil;
  if (Kind <> mjObject) or (not Assigned(ObjKeys)) then Exit;
  idx := ObjKeys.IndexOf(Key);
  if idx >= 0 then Result := TMJValue(ObjVals[idx]);
end;

function TMJParser.Peek: WideChar;
begin
  Result := P^;
end;

function TMJParser.Next: WideChar;
begin
  Result := P^;
  if P^ <> #0 then Inc(P);
end;

procedure TMJParser.SkipWS;
begin
  while (Peek = ' ') or (Peek = #9) or (Peek = #10) or (Peek = #13) do Next;
end;

function TMJParser.ParseLiteral(const Lit: UnicodeString): Boolean;
var i: Integer;
begin
  Result := True;
  for i := 1 to Length(Lit) do
    if Next <> Lit[i] then begin Result := False; Exit; end;
end;

function TMJParser.ParseString: UnicodeString;
var
  ch: WideChar;
begin
  Result := '';
  if Next <> '"' then raise Exception.Create('JSON: expected "');
  while True do
  begin
    ch := Next;
    if ch = #0 then raise Exception.Create('JSON: unterminated string');
    if ch = '"' then Break;
    if ch = '\' then
    begin
      ch := Next;
      case ch of
        '"': Result := Result + '"';
        '\': Result := Result + '\';
        '/': Result := Result + '/';
        'b': Result := Result + #8;
        'f': Result := Result + #12;
        'n': Result := Result + #10;
        'r': Result := Result + #13;
        't': Result := Result + #9;
      else
        raise Exception.Create('JSON: bad escape');
      end;
    end
    else
      Result := Result + ch;
  end;
end;

function TMJParser.ParseNumber: Double;
var
  Start: PWideChar;
  Tmp: UnicodeString;
begin
  Start := P;
  if Peek = '-' then Next;
  while (Peek >= '0') and (Peek <= '9') do Next;
  if Peek = '.' then
  begin
    Next;
    while (Peek >= '0') and (Peek <= '9') do Next;
  end;
  if (Peek = 'e') or (Peek = 'E') then
  begin
    Next;
    if (Peek = '+') or (Peek = '-') then Next;
    while (Peek >= '0') and (Peek <= '9') do Next;
  end;
  SetString(Tmp, Start, (P - Start));
  Result := StrToFloat(string(Tmp));
end;

function TMJParser.ParseArray: TMJValue;
var V: TMJValue;
begin
  Result := TMJValue.Create;
  Result.Kind := mjArray;
  Result.Arr := TList.Create;

  if Next <> '[' then raise Exception.Create('JSON: expected [');
  SkipWS;
  if Peek = ']' then begin Next; Exit; end;

  while True do
  begin
    SkipWS;
    V := ParseValue;
    Result.Arr.Add(V);
    SkipWS;
    if Peek = ',' then begin Next; Continue; end;
    if Peek = ']' then begin Next; Break; end;
    raise Exception.Create('JSON: expected , or ]');
  end;
end;

function TMJParser.ParseObject: TMJValue;
var K: UnicodeString; V: TMJValue;
begin
  Result := TMJValue.Create;
  Result.Kind := mjObject;
  Result.ObjKeys := TStringList.Create;
  Result.ObjKeys.CaseSensitive := True;
  Result.ObjVals := TList.Create;

  if Next <> '{' then raise Exception.Create('JSON: expected {');
  SkipWS;
  if Peek = '}' then begin Next; Exit; end;

  while True do
  begin
    SkipWS;
    K := ParseString;
    SkipWS;
    if Next <> ':' then raise Exception.Create('JSON: expected :');
    SkipWS;
    V := ParseValue;
    Result.ObjKeys.Add(string(K));
    Result.ObjVals.Add(V);
    SkipWS;
    if Peek = ',' then begin Next; Continue; end;
    if Peek = '}' then begin Next; Break; end;
    raise Exception.Create('JSON: expected , or }');
  end;
end;

function TMJParser.ParseValue: TMJValue;
begin
  SkipWS;
  case Peek of
    '"':
      begin
        Result := TMJValue.Create;
        Result.Kind := mjString;
        Result.StrVal := ParseString;
      end;
    '{': Result := ParseObject;
    '[': Result := ParseArray;
    't':
      begin
        if not ParseLiteral('true') then raise Exception.Create('JSON: bad literal');
        Result := TMJValue.Create; Result.Kind := mjBool; Result.BoolVal := True;
      end;
    'f':
      begin
        if not ParseLiteral('false') then raise Exception.Create('JSON: bad literal');
        Result := TMJValue.Create; Result.Kind := mjBool; Result.BoolVal := False;
      end;
    'n':
      begin
        if not ParseLiteral('null') then raise Exception.Create('JSON: bad literal');
        Result := TMJValue.Create; Result.Kind := mjNull;
      end;
  else
    begin
      Result := TMJValue.Create;
      Result.Kind := mjNumber;
      Result.NumVal := ParseNumber;
    end;
  end;
end;

function MJParse(const S: UnicodeString): TMJValue;
var P: TMJParser;
begin
  P := TMJParser.Create;
  try
    P.P := PWideChar(S);
    Result := P.ParseValue;
  finally
    P.Free;
  end;
end;

end.
