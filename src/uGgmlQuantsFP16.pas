unit uGgmlQuantsFP16;

interface

uses
  SysUtils, Classes, uMath, uGGMLConstants; // , System.Math

{$POINTERMATH ON}
// FONCTIONS DE BASE (FP16/BF16)
function FP16NeighUP(x: Single): Single;
function FP16NeighDown(x: Single): Single;
function FP16NeighIdx(x: Single; idx: Integer): Single;
function FP16ToFP32(const H: TUInt16): Single; inline;
function FP32ToFP16(const F: Single): TUInt16; inline;

function FP32ToBF16(const F: Single): TUInt16; inline;
function BF16ToFP32(const B: TUInt16): Single; inline;

// Types Entiers vers F32
procedure DequantI8(const Data: PByte; Dest: PSingle; n: Integer);
procedure DequantI16(const Data: PByte; Dest: PSingle; n: Integer);
procedure DequantI32(const Data: PByte; Dest: PSingle; n: Integer);
procedure DequantI64(const Data: PByte; Dest: PSingle; n: Integer);

// Type F64 vers F32
procedure DequantF64(const Data: PByte; Dest: PSingle; n: Integer);

// Types F32 vers Entiers (Quantification)
procedure QuantI8(const src: PSingle; Dest: PByte; n: Integer);
procedure QuantI16(const src: PSingle; Dest: PByte; n: Integer);
procedure QuantI32(const src: PSingle; Dest: PByte; n: Integer);
procedure QuantI64(const src: PSingle; Dest: PByte; n: Integer);

// Type F32 vers F64
procedure QuantF64(const src: PSingle; Dest: PByte; n: Integer);

implementation

// FONCTIONS DE BASE (FP16/BF16)
// Fonction pour trouver le voisin immédiatement supérieur (plus grand)
function FP16NeighUP(x: Single): Single;
var
  H: TUInt16;
  Sign: Boolean;
  Mag: Word;
begin
  H := FP32ToFP16(x);

  // Gestion des NaN et Infinis
  if (H and $7C00) = $7C00 then
  begin
    if (H and $03FF) <> 0 then
      Exit(x); // NaN reste NaN
    if (H and $8000) <> 0 then
      Result := FP16ToFP32($FBFF) // -Inf -> plus grand négatif fini
    else
      Result := x; // +Inf reste +Inf
    Exit;
  end;

  Sign := (H and $8000) <> 0;
  Mag := H and $7FFF;

  // Si le nombre est zéro (+0 ou -0), le voisin supérieur est le plus petit subnormal positif
  if Mag = 0 then
  begin
    Result := FP16ToFP32($0001);
    Exit;
  end;

  if not Sign then
  begin
    // Nombre positif : incrémenter la magnitude augmente la valeur
    Inc(Mag);
  end
  else
  begin
    // Nombre négatif : décrémenter la magnitude augmente la valeur (rapproche de 0)
    Dec(Mag);
    if Mag = 0 then
      Sign := False; // Passage à +0 ($0000)
  end;

  if Sign then
    H := $8000 or Mag
  else
    H := Mag;

  Result := FP16ToFP32(H);
end;

// Fonction pour trouver le voisin immédiatement inférieur (plus petit)
function FP16NeighDown(x: Single): Single;
var
  H: TUInt16;
  Sign: Boolean;
  Mag: Word;
begin
  H := FP32ToFP16(x);

  // Gestion des NaN et Infinis
  if (H and $7C00) = $7C00 then
  begin
    if (H and $03FF) <> 0 then
      Exit(x); // NaN
    if (H and $8000) <> 0 then
      Result := x // -Inf reste -Inf
    else
      Result := FP16ToFP32($7FFF); // +Inf -> plus grand positif fini
    Exit;
  end;

  Sign := (H and $8000) <> 0;
  Mag := H and $7FFF;

  // Si le nombre est zéro, le voisin inférieur est le plus petit subnormal négatif
  if Mag = 0 then
  begin
    Result := FP16ToFP32($8001);
    Exit;
  end;

  if not Sign then
  begin
    // Nombre positif : décrémenter la magnitude diminue la valeur
    Dec(Mag);
    if Mag = 0 then
      Sign := True; // Passage à -0 ($8000)
  end
  else
  begin
    // Nombre négatif : incrémenter la magnitude diminue la valeur (plus négatif)
    Inc(Mag);
    if Mag > $7FFF then
    begin
      Result := FP16ToFP32($FC00); // -Inf
      Exit;
    end;
  end;

  if Sign then
    H := $8000 or Mag
  else
    H := Mag;

  Result := FP16ToFP32(H);
end;

// Fonction pour trouver le i-ème voisin (idx positif ou négatif)
function FP16NeighIdx(x: Single; idx: Integer): Single;
var
  i: Integer;
begin
  Result := x;
  if idx > 0 then
  begin
    for i := 1 to idx do
      Result := FP16NeighUP(Result);
  end
  else if idx < 0 then
  begin
    for i := 1 to -idx do
      Result := FP16NeighDown(Result);
  end;
end;

function FP32ToFP16(const F: Single): TUInt16;
var
  U, Sign, Exp, Mant: Cardinal;
begin
  Move(F, U, SizeOf(U));
  Sign := (U shr 16) and $8000;
  Exp := (U shr 23) and $FF;
  Mant := U and $7FFFFF;

  if Exp = $FF then
  begin
    if Mant <> 0 then
      // Result := Sign or $7C00 or (Mant shr 13) // NaN
      Result := Sign or $7C00 or $0200 or ((Mant shr 13) and $01FF)
    else
      Result := Sign or $7C00; // Inf
  end
  else if Exp = 0 then
      Exit(Sign) // Zéro parfait
  else
  begin
    if Exp < 113 then // 127 - 14 : Plage des Subnormaux (Crucial pour l'IA)
    begin
      if Exp < 95 then         // |F| < 2^-32 : sous-flux FP16 -> +/-0.
        Exit(Sign);            // (evite SHR/SHL > 31 : UB x64 + EOverflow si {$Q+})

      Mant := Mant or $800000; // Ajout du bit implicite
      // Arrondi propre pour sauver les échelles très faibles
      Mant := Mant + (1 shl (125 - Exp));
      Result := Sign or (Mant shr (126 - Exp));
    end
    else if Exp > 142 then // 127 + 15 : Débordement -> Inf
      Result := Sign or $7C00
    else // Normal
    begin
      Exp := Exp - 112;
      //Mant := Mant + $1000; // Arrondi (1 << 12)
      Mant := Mant + $0FFF + ((Mant shr 13) and 1);   // roundTiesToEven
      if (Mant and $800000) <> 0 then // Si l'arrondi fait déborder la mantisse
      begin
        Mant := 0;
        Inc(Exp);
      end;
      Result := Sign or (Exp shl 10) or (Mant shr 13);
    end;
  end;
end;


function FP32ToFP16o(const F: Single): TUInt16;
var
  U, Sign, Exp, Mant: Cardinal;
begin
  Move(F, U, SizeOf(U));
  Sign := (U shr 16) and $8000;
  Exp := (U shr 23) and $FF;
  Mant := U and $7FFFFF;

  if Exp = $FF then
  begin
    if Mant <> 0 then
      // Result := Sign or $7C00 or (Mant shr 13) // NaN
      Result := Sign or $7C00 or $0200 or ((Mant shr 13) and $01FF)
    else
      Result := Sign or $7C00; // Inf
  end
  else if Exp = 0 then
      Exit(Sign) // Zéro parfait
  else
  begin
    if Exp < 113 then // 127 - 14 : Plage des Subnormaux (Crucial pour l'IA)
    begin
      if Exp < 95 then         // |F| < 2^-32 : sous-flux FP16 -> +/-0.
        Exit(Sign);            // (evite SHR/SHL > 31 : UB x64 + EOverflow si {$Q+})

      Mant := Mant or $800000; // Ajout du bit implicite
      // Arrondi propre pour sauver les échelles très faibles
      Mant := Mant + (1 shl (125 - Exp));
      Result := Sign or (Mant shr (126 - Exp));
    end
    else if Exp > 142 then // 127 + 15 : Débordement -> Inf
      Result := Sign or $7C00
    else // Normal
    begin
      Exp := Exp - 112;
      Mant := Mant + $1000; // Arrondi (1 << 12)
      if (Mant and $800000) <> 0 then // Si l'arrondi fait déborder la mantisse
      begin
        Mant := 0;
        Inc(Exp);
      end;
      Result := Sign or (Exp shl 10) or (Mant shr 13);
    end;
  end;
end;

function FP16ToFP32(const H: TUInt16): Single; inline;
var
  Sign, Exp, Mant, U: Integer;
begin
  Sign := (H and $8000) shl 16;
  Exp := (H and $7C00) shr 10;
  Mant := H and $03FF;

  if Exp = $1F then
  begin
    if Mant <> 0 then
      U := Sign or $7F800000 or (Mant shl 13) // NaN
    else
      U := Sign or $7F800000; // Inf
  end
  else if Exp = 0 then
  begin
    if Mant = 0 then
      U := Sign // Zéro
    else
    begin
      // Restauration d'un Subnormal (Crucial pour lire les échelles faibles)
      while (Mant and $0400) = 0 do
      begin
        Mant := Mant shl 1;
        Dec(Exp);
      end;
      Exp := Exp + 113; // 127 - 15 + 1
      Mant := Mant and $03FF;
      U := Sign or (Exp shl 23) or (Mant shl 13);
    end;
  end
  else // Normal
  begin
    Exp := Exp + 112; // 127 - 15
    U := Sign or (Exp shl 23) or (Mant shl 13);
  end;
  Move(U, Result, SizeOf(Single));
end;


// F32 -> BF16 : transcription bit-a-bit de ggml_compute_fp32_to_bf16
function FP32ToBF16(const F: Single): TUInt16; inline;
var U: TUInt32;
begin
  Move(F, U, SizeOf(U));
  if (U and $7FFFFFFF) > $7F800000 then   // NaN -> NaN quiet (| $40 = MSB de la mantisse BF16)
    Exit(TUInt16((U shr 16) or $0040));
  U := U + ($7FFF + ((U shr 16) and 1));  // roundTiesToEven
  Result := TUInt16(U shr 16);
end;

function FP32ToBF16o(const F: Single): TUInt16; inline;
var
  U: TUInt32;
begin
  Move(F, U, SizeOf(U));
  // BF16 tronque simplement les 16 bits de poids faible (pas de arrondi)
  Result := TUInt16(U shr 16);
end;

function BF16ToFP32(const B: TUInt16): Single; inline;
var
  U: TUInt32;
begin
  U := TUInt32(B) shl 16;
  Move(U, Result, SizeOf(Result));
end;

// DÉQUANTISATION (Vers Single/F32)
procedure DequantI8(const Data: PByte; Dest: PSingle; n: Integer);
var
  i: Integer;
begin
  for i := 0 to n - 1 do
    Dest[i] := Single(PShortInt(Data)[i]); // PShortInt est un Signed Byte (-128 à 127)
end;

procedure DequantI16(const Data: PByte; Dest: PSingle; n: Integer);
var
  i: Integer;
begin
  for i := 0 to n - 1 do
    Dest[i] := Single(PSmallInt(Data)[i]);
end;

procedure DequantI32(const Data: PByte; Dest: PSingle; n: Integer);
var
  i: Integer;
begin
  for i := 0 to n - 1 do
    Dest[i] := Single(PInteger(Data)[i]);
end;

procedure DequantI64(const Data: PByte; Dest: PSingle; n: Integer);
var
  i: Integer;
begin
  for i := 0 to n - 1 do
    Dest[i] := Single(PInt64(Data)[i]);
end;

procedure DequantF64(const Data: PByte; Dest: PSingle; n: Integer);
var
  i: Integer;
begin
  for i := 0 to n - 1 do
    Dest[i] := Single(PDouble(Data)[i]); // Conversion Float64 -> Float32
end;

// QUANTIFICATION (Depuis Single/F32)
procedure QuantI8(const src: PSingle; Dest: PByte; n: Integer);
var
  i: Integer;
begin
  for i := 0 to n - 1 do
    PShortInt(Dest)[i] := ClampInt(Round(src[i]), -128, 127);
end;

procedure QuantI16(const src: PSingle; Dest: PByte; n: Integer);
var
  i: Integer;
begin
  for i := 0 to n - 1 do
    PSmallInt(Dest)[i] := ClampInt(Round(src[i]), -32768, 32767);
end;

procedure QuantI32(const src: PSingle; Dest: PByte; n: Integer);
var
  i: Integer;
begin
  for i := 0 to n - 1 do
    PInteger(Dest)[i] := Round(src[i]);
end;

procedure QuantI64(const src: PSingle; Dest: PByte; n: Integer);
var
  i: Integer;
begin
  for i := 0 to n - 1 do
    PInt64(Dest)[i] := Round(src[i]);
end;

procedure QuantF64(const src: PSingle; Dest: PByte; n: Integer);
var
  i: Integer;
begin
  for i := 0 to n - 1 do
    PDouble(Dest)[i] := Double(src[i]);
end;


end.
