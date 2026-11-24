unit uStrUtils;

interface

uses
  System.SysUtils, System.Classes, Vcl.StdCtrls, uMath, uGGUFModel;

function U8ToA(const S: string): RawByteString; // Unicode -> octets UTF-8 bruts
function AToU8(const A: RawByteString): string;
function FToStr(V: Double): string;

function SafeFileName(const S: string): string;

function IfThen1(AValue: Boolean; const ATrue: string; AFalse: string = ''): string;overload;inline;
function IfThen1(AValue: Boolean; const ATrue: Int64; AFalse: Int64 = 0): Int64;overload; inline;
function IfThen1(AValue: Boolean; const ATrue: Integer; const AFalse: Integer = 0): Integer;overload;inline;
function sStrBool(B: Boolean): string; inline;
function pStrToBool(const S: string; const Default: Boolean = false): Boolean;
function pStrToFloat(const S: string; const Default: Double = 0): Double;
function pStrToUInt64(const S: string; const Default: UInt64 = 0): UInt64;
function pStrToInt64(const S: string; const Default: Int64 = 0): Int64;
function pStrToInt32(const S: string; const Default: Integer = 0): Integer;
function pStrToUInt32(const S: string; const Default: Cardinal = 0): Cardinal;
function pStrToInt16(const S: string; const Default: SmallInt = 0): SmallInt;
function pStrToUInt16(const S: string; const Default: Word = 0): Word;
function pStrToUInt8(const S: string; const Default: Byte = 0): Byte;

function InvFS: TFormatSettings; inline;

function FormatDurationMs(MS: Int64): string;                  // réécrite
function FormatSpeedMBs(ABytes, AMS: Int64): string;           // remplace SpeedMBs + Format
function UnFormatSizeStrMbGb(sSizeStr: string): Int64;
function FormatBytes2f(Bytes: Int64): string;                  // locale-safe
function FormatCount(N: Int64): string;                        // '1 234 567'
function FormatFloat4f(const V: Double): string;               // négatifs OK
function PctOf(ADone, ATotal: Int64): string;
function PctD(ADone, ATotal: Int64): Int64;
function FormatPctD(ADone, ATotal: Int64): string;
function FormatPctF(ADone, ATotal: Int64): string;
function FormatRmse(const LabelS: string; V: Double): string;  // '—' si non valide
function FormatSizeStrMbGb(Bytes: Int64): string;              // inverse de UnFormatSizeStrMbGb
function FormatSignatureDate(const Tpl: string): string;
function TensorShapeText(Dims: array of Int64): string;

function FormatTensorSrcSizeType(T: TGGUFTensorInfo): string;
function ShortTensorName(const Nm: string): string;
function FormatTensorLogInfo(T: TGGUFTensorInfo): string;
function GetFormatTensorNameList(T: TGGUFTensorInfo): String;


// combos / edits
function  TCombo_GetSel(cb: TComboBox; ADef: Integer): Integer;
procedure TCombo_SetSel(cb: TComboBox; AIndex: Integer);

function  TEdit_ReadFloat(ed: TEdit; ACur: Single): Single;
procedure TEdit_WriteFloat(ed: TEdit; V: Single);

function  TEdit_ReadInt(ed: TEdit; ACur: Integer): Integer;
procedure TEdit_WriteInt(ed: TEdit; V: Integer);

procedure TEdit_WriteInt64(ed: TEdit; V: Int64);   // ss := IntToStr(V)
function  TEdit_ReadInt64(ed: TEdit; ACur: Int64): Int64;

function ParseTensorsPerChart(const S: string): Integer;


implementation

uses uGGMLTypes, uGGMLConstants, uAppConfig;

function U8ToA(const S: string): RawByteString;
var
  B: TBytes;
begin
  Result := '';
  if S = '' then Exit;
  B := TEncoding.UTF8.GetBytes(S);    // sans BOM
  if Length(B) = 0 then Exit;
  SetLength(Result, Length(B));
  Move(B[0], Result[1], Length(B));  // pas de SetString/PAnsiChar : pas de balisage 1252
end;

function AToU8(const A: RawByteString): string;  // ⚠ param RawByteString
var
  B: TBytes;
begin
  if Length(A) = 0 then Exit('');
  SetLength(B, Length(A));
  Move(A[1], B[0], Length(A));
  Result := TEncoding.UTF8.GetString(B);
end;

function FToStr(V: Double): string;
var
  FS: TFormatSettings;
begin
 // FS := TFormatSettings.Create;
 // FS.DecimalSeparator := '.';
 // FS.ThousandSeparator := #0;
  //Result := FloatToStr(V, FS);
  Result := FloatToStr(V, InvFS);
end;

function SafeFileName(const S: string): string;
const Bad = ['\','/',':','*','?','"','<','>','|'];
var C: Char;
begin
  Result := '';
  for C in S do if C in Bad then Result := Result + '_' else Result := Result + C;
end;

function IfThen1(AValue: Boolean; const ATrue: string; AFalse: string = ''): string;
begin
  if AValue then
    Result := ATrue
  else
    Result := AFalse;
end;

function IfThen1(AValue: Boolean; const ATrue: Int64; AFalse: Int64 = 0): Int64;
begin
  if AValue then
    Result := ATrue
  else
    Result := AFalse;
end;

function IfThen1(AValue: Boolean; const ATrue: Integer; const AFalse: Integer = 0): Integer;
begin
  if AValue then
    Result := ATrue
  else
    Result := AFalse;
end;


function sStrBool(B: Boolean): string; inline;
begin if B then Result := 'yes' else Result := 'no'; end;


function pStrToBool(const S: string; const Default: Boolean = false): Boolean;
var
  T: string;
begin
  Result := Default;
  T := LowerCase(Trim(S));
  if (T = '1') or (T = 'true') or (T = 't') or (T = 'yes') or (T = 'y') or (T = 'on') or (T = 'oui') or (T = 'vrai') then
  begin
    Exit(True);
  end
  else if (T = '0') or (T = 'false') or (T = 'f') or (T = 'no') or (T = 'n') or (T = 'off') or (T = 'non') or (T = 'faux') then
    Exit(False);
end;

function pStrToFloat(const S: string; const Default: Double = 0): Double;
var
  FS: TFormatSettings;
  T: string;
begin
  T := Trim(S);
  FS := TFormatSettings.Create;
  FS.DecimalSeparator := '.';
  FS.ThousandSeparator := #0;
  if TryStrToFloat(T, Result, FS) then Exit;
  FS.DecimalSeparator := ',';
  if not TryStrToFloat(T, Result, FS) then
    Result := Default;
end;

function pStrToUInt64(const S: string; const Default: UInt64 = 0): UInt64;
var
  T: string;
  I: Integer;
  c: Char;
  acc: UInt64;
begin
  T := Trim(S);
  if T = '' then
  begin
    Result := Default;
    Exit;
  end;
  // raise Exception.Create('UInt64 parse: empty');

  // Pas de signe négatif
  if T[1] = '-' then
  begin
    Result := Default;
    Exit;
  end;
  // raise Exception.Create('UInt64 parse: negative');

  acc := 0;
  for I := 1 to Length(T) do
  begin
    c := T[I];
    if (c < '0') or (c > '9') then
    begin
      Result := Default;
      Exit;
    end;
    // raise Exception.Create('UInt64 parse: bad char');
    acc := acc * 10 + UInt64(Ord(c) - Ord('0'));
  end;
  Result := acc;
end;

function pStrToInt64(const S: string; const Default: Int64 = 0): Int64;
begin
  Result := StrToInt64Def(Trim(S), Default);
end;

function pStrToInt32(const S: string; const Default: Integer = 0): Integer;
var
  V: Int64;
begin
  V := StrToInt64Def(Trim(S), Default);
  if (V < Low(Integer)) or (V > High(Integer)) then
    raise Exception.Create('Int32 out of range');
  Result := Integer(V);
end;

function pStrToUInt32(const S: string; const Default: Cardinal = 0): Cardinal;
var
  V: Int64;
begin
  V := StrToInt64Def(Trim(S), Default);
  if (V < 0) or (V > High(Cardinal)) then
    raise Exception.Create('UInt32 out of range');
  Result := Cardinal(V);
end;

function pStrToInt16(const S: string; const Default: SmallInt = 0): SmallInt;
var
  V: Integer;
begin
  V := StrToInt64Def(Trim(S), Default);
  if (V < Low(SmallInt)) or (V > High(SmallInt)) then
    raise Exception.Create('UInt16 out of range');
  Result := SmallInt(V);
end;

function pStrToUInt16(const S: string; const Default: Word = 0): Word;
var
  V: Integer;
begin
  V := StrToInt64Def(Trim(S), Default);
  if (V < 0) or (V > High(Word)) then
    raise Exception.Create('UInt16 out of range');
  Result := Word(V);
end;

function pStrToUInt8(const S: string; const Default: Byte = 0): Byte;
var
  V: Integer;
begin
  V := StrToInt64Def(Trim(S), Default);
  if (V < 0) or (V > High(Byte)) then
    raise Exception.Create('UInt8 out of range');
  Result := Byte(V);
end;

function InvFS: TFormatSettings;
begin
  Result := TFormatSettings.Invariant;
  Result.DecimalSeparator := '.';
 // Result.ThousandSeparator := #0;
end;

{ Durées lisibles : 850 ms | 4,20 s | 2 min 07 s | 1 h 05 min 12 s }
function FormatDurationMs(MS: Int64): string;
var r, h, m, s: Int64;
begin
  if MS < 0 then Exit('-' + FormatDurationMs(-MS));
  if MS < 1000 then Exit(Format('%d ms', [MS], InvFS));
  r := MS div 1000;
  if r < 60 then
    Exit(Format('%.2f s', [MS / 1000.0], InvFS));       // garde 2 déc. sous la minute (perf)
  h := r div 3600;
  m := (r mod 3600) div 60;
  s := r mod 60;
  if h > 0 then
    Result := Format('%d h %.2d min %.2d s', [h, m, s], InvFS)
  else
    Result := Format('%d min %.2d s', [m, s], InvFS);
end;

{ Vitesse auto-unités, au lieu de '%.4f MB/s' }
function FormatSpeedMBs(ABytes, AMS: Int64): string;
var v: Double;
begin
  if AMS <= 0 then Exit('-');
  v := (ABytes / (1024.0 * 1024.0)) / (AMS / 1000.0);
  if v < 1 then
    Result := Format('%.1f KiB/s', [v * 1024.0], InvFS)
  else if v < 10 then
    Result := Format('%.2f MiB/s', [v], InvFS)
  else
    Result := Format('%.1f MiB/s', [v], InvFS);
end;


function UnFormatSizeStrMbGb(sSizeStr: string): Int64;
var FS: TFormatSettings;
const
  MB = 1048576; // 1024 * 1024;
var
  GB: Double;
  xMbGb: Int64;
begin
  FS := TFormatSettings.Invariant;
  GB := 1024 * MB;
  xMbGb := 1;
  // Result := Trunc(GB);
  sSizeStr := UpperCase(sSizeStr);
  if Pos('GB', sSizeStr) > 0 then
  begin
    xMbGb := Trunc(GB);
    sSizeStr := StringReplace(sSizeStr, 'GB', '', [rfReplaceAll]);
  end
  else if Pos('MB', sSizeStr) > 0 then
  begin
    xMbGb := MB;
    sSizeStr := StringReplace(sSizeStr, 'MB', '', [rfReplaceAll]);
  end;
  //Result := StrToInt64Def(Trim(sSizeStr), 0) * xMbGb;
  Result := Trunc(pStrToFloat(sSizeStr, 0) * xMbGb)
end;


function FormatBytes2f(Bytes: Int64): string;
const
  KB = 1024;
  MB = 1024 * KB;
var
  TB, GB: Double;
begin
  GB := 1024 * MB;
  TB := 1024 * GB;
  if Bytes >= TB then
    Result := Format('%.2f TB', [Bytes / TB], InvFS)
  else if Bytes >= GB then
    Result := Format('%.2f GB', [Bytes / GB], InvFS)
  else if Bytes >= 100 * MB then
    Result := Format('%.0f MB', [Bytes / MB], InvFS)
  else if Bytes >= 10 * MB then
    Result := Format('%.1f MB', [Bytes / MB], InvFS)
  else if Bytes >= MB then
    Result := Format('%.2f MB', [Bytes / MB], InvFS)
  else if Bytes >= 100 * KB then
    Result := Format('%.0f KB', [Bytes / KB], InvFS)
  else if Bytes >= 10 * KB then
    Result := Format('%.1f KB', [Bytes / KB], InvFS)
  else if Bytes >= KB then
    Result := Format('%.2f KB', [Bytes / KB], InvFS)
  else
    Result := Format('%d B', [Bytes], InvFS);
end;

function FormatCount(N: Int64): string;
var f: TFormatSettings;
begin
  f := InvFS;
  f.ThousandSeparator := ' ';
//  f.GroupSeparator := ' ';
  Result := FormatFloat('#,##0', N, f);
end;


// FormatFloat4f : gère les négatifs (Abs) + séparateur '.' + borne basse réaliste
function FormatFloat4f(const V: Double): string;
var a: Double; pat: string;
begin
  if IsNan(V) or IsInfinite(V) then Exit('NaN');
  a := Abs(V);
  //if a >= 1000 then pat := '# ##0'
  if a >= 1000 then pat := '###0'
  else if a >= 100 then pat := '0.#'
  else if a >= 10  then pat := '0.##'
  else if a >= 1   then pat := '0.###'
  else if a = 0   then Exit('0')
  else if a >= 0.0001 then pat := '0.####'
  else Exit(Format('%.2e', [V], InvFS));           // petits poids : notation scientifique
  Result := FormatFloat(pat, V, InvFS);
end;

function PctD(ADone, ATotal: Int64): Int64;
begin
  if ATotal <= 0 then Exit(0);
  Result := (ADone * 100 ) div  ATotal;
end;

function PctOf(ADone, ATotal: Int64): string;
begin
  if ATotal <= 0 then Exit('--');
  Result := Format('%.4f%%', [100 * ADone / ATotal], InvFS);
end;

function FormatPctD(ADone, ATotal: Int64): string;
begin
  if ATotal <= 0 then exit('--');
  Result := Format('%d%%', [PctD(ADone, ATotal)], InvFS);
end;

function PctF(ADone, ATotal: Int64): Single;
begin
  if ATotal <= 0 then Exit(0);
  Result := (ADone * 100 ) /  ATotal;
end;


function FormatPctF(ADone, ATotal: Int64): string;
var
  p: Single;
begin
  if ATotal <= 0 then exit('--');
  p := PctF(ADone, ATotal);
  if p >= 10 then
    Result := Format('%0.1f%%', [p], InvFS)
  else
    Result := Format('%0.2f%%', [p], InvFS)
end;

function FormatRmse(const LabelS: string; V: Double): string;
begin
  if (V <> V) then Result := LabelS + ': —'
  else Result := Format('%s: %.6f', [LabelS, V], InvFS);
end;

{ Symétrique de UnFormatSizeStrMbGb : pour relire/valider cfg.SplitSizeMbGbStr }
function FormatSizeStrMbGb(Bytes: Int64): string;
begin
  if Bytes <= 0 then Exit('None (One File)');
  if (Bytes mod (1024*1024*1024) = 0) then
    Result := Format('%d GB', [Bytes div (1024*1024*1024)], InvFS)
  else
    Result := Format('%.2f GB', [Bytes / (1024.0*1024*1024)], InvFS);
end;

function FormatSignatureDate(const Tpl: string): string;
begin
  Result := Tpl + ' ' + FormatDateTime('yyyy"-"mm"-"dd hh"-"nn"-"ss', Now, InvFS);
end;


function TensorShapeText(Dims: array of Int64): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to Length(Dims) - 1 do
  begin
    if I > 0 then
      Result := Result + 'x';
    Result := Result + IntToStr(Integer(Dims[I]));
  end;
end;

function ShortTensorName(const Nm: string): string;
begin
  if Length(Nm) > 18 then
    Result := Copy(Nm, 1, 15) + '...'
  else
    Result := Nm;
end;

function FormatTensorSrcSizeType(T: TGGUFTensorInfo): string;
var
  Prefix, strQ: string;
begin
  Prefix := '';
  // Détermination du préfixe selon la source
  if T.IsConverted then
    Prefix := 'O' // Output
  else if T.SourceId = SRC_MODEL1 then
    Prefix := 'A' // Model A
  else if T.SourceId = SRC_MODEL2 then
    Prefix := 'B' // Model B
  else if T.SourceId = SRC_MODEL3 then
    Prefix := 'C' // Model C
  else if T.SourceId = SRC_MODELS then
    Prefix := 'S'; // Model S
  // FGlobalMaxElems := Max(FGlobalMaxElems, T.TotElems);
  strQ := GGMLTypeToStr(Integer(T.TensorType));
  strQ :=strQ + '(' + FormatBytes2f(T.ByteSize) + ')';
  Result := Format('[%s]-%s', [Prefix, strQ]);
end;


function FormatTensorLogInfo(T: TGGUFTensorInfo): string;
begin
  // Format court pour les logs : Nom:Type
  // Result := Format('%s:%s-%s', [string(T.Name), GGMLTypeToStr(T.TensorType), FormatBytes2f(T.ByteSize)]);
  //Result := Format('%s:%s', [string(T.Name), GGMLTypeToStr(T.TensorType)]);
  //Result := GetFormatTensorNameList(T);
  Result := Format('%s', [string(T.Name)]) + FormatTensorSrcSizeType(T);
end;

function GetFormatTensorNameList(T: TGGUFTensorInfo): String;

begin
  // Format long pour la liste : Nom [Préfixe]-Type
  Result := Format('%s', [string(T.Name)]) + FormatTensorSrcSizeType(T);
end;


function TCombo_GetSel(cb: TComboBox; ADef: Integer): Integer;
begin
  Result := cb.ItemIndex;
  if (Result < 0) or (Result > cb.Items.Count - 1) then
    begin
      Result := ADef;
      if (ADef >= 0) and (ADef <= cb.Items.Count - 1) then
        cb.ItemIndex := ADef;
    end;
end;

procedure TCombo_SetSel(cb: TComboBox; AIndex: Integer);
begin
  if (AIndex >= 0) and (AIndex < cb.Items.Count) then
    cb.ItemIndex := AIndex;
end;

function TEdit_ReadInt(ed: TEdit; ACur: Integer): Integer;
begin
  if not TryStrToInt(Trim(ed.Text), Result) then
    Result := ACur;
  TEdit_WriteInt(ed, Result);
end;

procedure TEdit_WriteInt(ed: TEdit; V: Integer);
var
  ss: string;
begin
  ss := IntToStr(V);
  if ed.Text <> ss then
    ed.Text := ss;
end;


function TEdit_ReadInt64(ed: TEdit; ACur: Int64): Int64;
begin
  if not TryStrToInt64(Trim(ed.Text), Result) then
    Result := ACur;
  TEdit_WriteInt64(ed, Result);
end;

procedure TEdit_WriteInt64(ed: TEdit; V: Int64);
var
  ss: string;
begin
  ss := IntToStr(V);
  if ed.Text <> ss then
    ed.Text := ss;
end;


function TEdit_ReadFloat(ed: TEdit; ACur: Single): Single;
begin
  //if not TryStrToFloat(Trim(ed.Text), Result, InvFS) then Result := ACur;
  Result := Single(pStrToFloat(ed.Text, ACur));  // '.' puis ',' (locale)
  TEdit_WriteFloat(ed, Result);
end;

procedure TEdit_WriteFloat(ed: TEdit; V: Single);
var
  ss: string;
begin
  ss := FormatFloat4f(V);
  if ed.Text <> ss then
    ed.Text := ss;
end;


function ParseTensorsPerChart(const S: string): Integer;
var
  sS: string;
begin
  sS := UpperCase(Trim(S));
  if sS = 'ONE' then
    Result := 1
  else if sS = 'ONE ONLY' then
    Result := 1
  else if sS = '2:BYNAME' then
    Result := 2 //
  else if sS = 'ALL' then
    Result := SAFETY_MAX_TENSORS
  else
    Result := pStrToInt32(sS, 2);
  Result := ClampInt(Result, 1, SAFETY_MAX_TENSORS);
end;



end.

