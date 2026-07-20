unit uGgufStrUtils;

interface

uses
  Contnrs, System.SysUtils, System.Classes, System.Generics.Collections, uMath;

function IfThen(AValue: Boolean; const ATrue: string; AFalse: string = ''): string;
function FormatDurationMs(MS: Int64): string;
function pStrToBool(const S: string): Boolean;
function pStrToFloat(const S: string): Double;
function pStrToUInt64(const S: string): UInt64;
function pStrToInt64(const S: string): Int64;
function pStrToUInt32(const S: string): Cardinal;
function pStrToUInt16(const S: string): Word;
function pStrToUInt8(const S: string): Byte;

implementation

function IfThen(AValue: Boolean; const ATrue: string; AFalse: string = ''): string;
begin
  if AValue then
    Result := ATrue
  else
    Result := AFalse;
end;

function FormatDurationMs(MS: Int64): string;
begin
  if MS < 1000 then
    Result := Format('%d ms', [MS])
  else if MS < 60000 then
    Result := Format('%.2f s', [MS / 1000.0])
  else if MS < 3600000 then
    Result := Format('%.2f min', [MS / 60000.0])
  else
    Result := Format('%.2f h', [MS / 3600000.0]);
end;

function pStrToBool(const S: string): Boolean;
var
  T: string;
begin
  T := LowerCase(Trim(S));
  Result := (T = '1') or (T = 'true') or (T = 'yes') or (T = 'y');
end;

function pStrToFloat(const S: string): Double;
var
  FS: TFormatSettings;
  T: string;
begin
  T := Trim(S);
  // Essai avec '.'
  // FS := DefaultFormatSettings;
  FS := TFormatSettings.Create;
  FS.DecimalSeparator := '.';
  try
    Result := StrToFloat(T, FS);
    exit;
  except
  end;
  // Fallback avec ',' (locale FR)
  // FS := DefaultFormatSettings;
  FS.DecimalSeparator := ',';
  Result := StrToFloat(T, FS);
end;

function pStrToUInt64(const S: string): UInt64;
var
  T: string;
  I: Integer;
  c: Char;
  acc: UInt64;
begin
  T := Trim(S);
  if T = '' then
    raise Exception.Create('UInt64 parse: empty');

  // Pas de signe négatif
  if T[1] = '-' then
    raise Exception.Create('UInt64 parse: negative');

  acc := 0;
  for I := 1 to Length(T) do
  begin
    c := T[I];
    if (c < '0') or (c > '9') then
      raise Exception.Create('UInt64 parse: bad char');
    acc := acc * 10 + UInt64(Ord(c) - Ord('0'));
  end;
  Result := acc;
end;

function pStrToInt64(const S: string): Int64;
begin
  if not TryStrToInt64(Trim(S), Result) then
    raise Exception.Create('Int64 parse: bad char');
end;

function pStrToUInt32(const S: string): Cardinal;
var
  v: Int64;
begin
  v := StrToInt64(Trim(S));
  if (v < 0) or (v > High(Cardinal)) then
    raise Exception.Create('UInt32 out of range');
  Result := Cardinal(v);
end;

function pStrToUInt16(const S: string): Word;
var
  v: Integer;
begin
  v := StrToInt(Trim(S));
  if (v < 0) or (v > High(Word)) then
    raise Exception.Create('UInt16 out of range');
  Result := Word(v);
end;

function pStrToUInt8(const S: string): Byte;
var
  v: Integer;
begin
  v := StrToInt(Trim(S));
  if (v < 0) or (v > High(Byte)) then
    raise Exception.Create('UInt8 out of range');
  Result := Byte(v);
end;

end.
