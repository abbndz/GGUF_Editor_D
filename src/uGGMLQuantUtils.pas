unit uGGMLQuantUtils;
// Unité utilitaire pour l'optimisation RMSE (MSE) des quantifications GGML
// Fournit les algorithmes de recherche d'échelle, d'offset et d'optimisation de poids

interface

uses
  SysUtils, Classes, uMath, uGGMLConstants;

{$POINTERMATH ON}
//{$J-}             // Désactive les checks de bounds dynamique (indices validés manuellement)
//{$N+}             // Force l'usage du FPU SSE2/AVX (par défaut en D10+, mais explicite)

//{$B-} // active les checks de performance. Les indices sont validés par les structures GGML.
//{$R-}  // Désactive les range checks pour éviter les surcoûts dans les boucles critiques
//{$O+}

var
  GROUP_MAX_EPS: Single;
  ExpScale: Single = 1E-112; // 0x1.0p-112; // 2^(-112)
  ScaleToInf: Single = 1E+112; // 0x1.0p+112; // 2^112
  ScaleToZero: Single = 1E-110; // 0x1.0p-110; // 2^(-110)

const
  // Valeurs exactes de 0x1.0p+112 et 0x1.0p-110
  GGML_SCALE_TO_INF = 5.1922968585348276E+33; // 2^112
  GGML_SCALE_TO_ZERO = 7.642816256658557E-34; // 2^-110

  // Type-punning sûr (équivalent exact des `union` C)
type
  TFloatUInt32 = packed record
    case Boolean of
      True:
        (F: Single);
      False:
        (U: UInt32);
  end;

  // ============================================================================
  // CONVERSIONS FP16 / BF16 / E8M0 (Bit-Perfect GGML)
  // ============================================================================
//function FP16ToFP32g(H: UInt16): Single; inline;
function FP16ToFP32g(H: UInt16): Single; inline;
function FP32ToFP16g(F: Single): UInt16; inline;
function BF16ToFP32g(H: UInt16): Single; inline;
function FP32ToBF16g(S: Single): UInt16; inline;
function E8M0ToFP32g(X: UInt8): Single; inline;

// Helpers type-punning
function FP32ToBits(const A: Single): UInt32; inline;
function FP32FromBits(const A: UInt32): Single; inline;

// FONCTIONS DE BASE (FP16/BF16) ---
function FP16ToFP32o(const H: TUInt16): Single;  inline;
function FP32ToFP16o(const F: Single): TUInt16; inline;
function FP32ToBF16o(const F: Single): TUInt16; inline;
function BF16ToFP32o(const B: TUInt16): Single; inline;

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

procedure DequantFP8_E4M3(const Data: PByte; Dest: PSingle; n: Integer);
procedure DequantFP8_E5M2(const Data: PByte; Dest: PSingle; n: Integer);
procedure QuantFP8_E4M3(const src: PSingle; Dest: PByte; n: Integer);
procedure QuantFP8_E5M2(const src: PSingle; Dest: PByte; n: Integer);

// ============================================================================
// DECLARATIONS DES FONCTIONS D'OPTIMISATION
// ============================================================================
function MakeQxQuants(n, nmax: Integer; const X: PSingle; L: PShortInt; rmse_type: Integer; const qw: PSingle): Single;
// Optimisation RMSE générique pour formats 2 à 6 bits. Recherche l'échelle qui minimise l'erreur quadratique moyenne pondérée.

function MakeQ3Quants(n, nmax: Integer; const X: PSingle; L: PShortInt; do_rmse: Boolean): Single;
// Optimisation spécifique Q3_K (3 bits, range [-4, 3]). Utilise une descente de coordonnées itérative.

function MakeQkx2Quants(n, nmax: Integer; const X, weights: PSingle; L: PByte; out MinVal: Single; Laux: PByte;
  rmin, rdelta: Single; nstep: Integer; use_mad: Boolean): Single;
// Optimisation conjointe Échelle + Offset (Minimum) pour les formats K (Q4_K, Q5_K, Q6_K).
// Résout une régression pondérée pour trouver d et min optimaux.
function MakeQkx3Quants(n, nmax: Integer; const X, weights: PSingle; L: PByte; out MinVal: Single; Laux: PByte;
  rmin, rdelta: Single; nstep: Integer; use_mad: Boolean): Single;

function MakeQpQuants(n, nmax: Integer; const X, weights: PSingle; L: PByte): Single;
// Optimisation des super-paramètres (super-scales ou super-mins).
// Regroupe plusieurs paramètres de sous-blocs en une seule valeur quantifiée.

procedure GetScaleMinK4(j: Integer; const scales: PByte; out sc, m: Byte); inline;
// Décode un scale et un min packés sur 6 bits depuis le tableau de 12 octets du format Q4_K/Q5_K.

implementation

// ============================================================================
// HELPERS TYPE-PANNING
// ============================================================================
function FP32ToBits(const A: Single): UInt32; inline;
var
  T: TFloatUInt32;
begin
  T.F := A;
  Result := T.U;
end;

function FP32FromBits(const A: UInt32): Single; inline;
var
  T: TFloatUInt32;
begin
  T.U := A;
  Result := T.F;
end;

// ============================================================================
// FP16 <-> FP32 (OFFICIEL GGML)
// ============================================================================
function FP16ToFP32g(H: UInt16): Single; inline;
var
  W, Sign, TwoW, ExpOffset, MagicMask, DenormCutoff, ResultBits: UInt32;
  NormVal, DenormVal: Single;
begin
  W := UInt32(H) shl 16;
  Sign := W and $80000000;
  TwoW := W + W;
  ExpOffset := $E0 shl 23;

  const
    ExpScale: Single = 2.98023223876953125E-38; // 0x1.0p-112
  NormVal := FP32FromBits((TwoW shr 4) + ExpOffset) * ExpScale;

  MagicMask := 126 shl 23; // 0x7E000000
  const
    MagicBias: Single = 0.5;
  DenormVal := FP32FromBits((TwoW shr 17) or MagicMask) - MagicBias;

  DenormCutoff := UInt32(1) shl 27; // 0x08000000

  if TwoW < DenormCutoff then
    ResultBits := Sign or FP32ToBits(DenormVal)
  else
    ResultBits := Sign or FP32ToBits(NormVal);

  Result := FP32FromBits(ResultBits);
end;

function FP32ToFP16g(F: Single): UInt16; inline;
var
  W, Shl1W, Sign, Bias, BaseBits, Bits, ExpBits, MantissaBits, Nonsign: UInt32;
  Base: Single;
begin
  // 1. Mise à l'échelle pour éviter les underflows/overflows prématurés
  Base := (Abs(F) * GGML_SCALE_TO_INF) * GGML_SCALE_TO_ZERO;

  // 2. Extraction des bits FP32
  W := FP32ToBits(F);
  Shl1W := W + W; // Équivalent de w * 2
  Sign := W and $80000000; // Conservation du bit de signe

  // 3. Calcul de l'exposant de base (bias)
  Bias := Shl1W and $FF000000;
  if Bias < $71000000 then
    Bias := $71000000; // Force un exposant minimum pour le round-to-nearest

  // 4. Reconstruction de la valeur intermédiaire
  Base := FP32FromBits((Bias shr 1) + $07800000) + Base;
  Bits := FP32ToBits(Base);

  // 5. Extraction des champs FP16
  ExpBits := (Bits shr 13) and $00007C00;
  MantissaBits := Bits and $00000FFF;
  Nonsign := ExpBits + MantissaBits;

  // 6. Gestion du débordement / Inf / NaN
  if Shl1W > $FF000000 then
    Result := UInt16((Sign shr 16) or $7E00) // Overflow -> FP16 Inf
  else
    Result := UInt16((Sign shr 16) or Nonsign);
end;

// ============================================================================
// BF16 <-> FP32 (OFFICIEL GGML)
// ============================================================================
function BF16ToFP32g(H: UInt16): Single; inline;
var
  U: packed record case Boolean of True: (F: Single);
  False: (I: UInt32);
end;
begin
  U.I := UInt32(H) shl 16;
  Result := U.F;
end;

function FP32ToBF16g(S: Single): UInt16; inline;
var
  U: packed record case Boolean of True: (F: Single);
  False: (I: UInt32);
end;
begin
  U.F := S;
  if (U.I and $7FFFFFFF) > $7F800000 then
  begin
    // NaN : forcer le bit de quiet NaN (bit 6)
    Result := UInt16((U.I shr 16) or 64);
  end
  else
  begin
    // Round-to-Nearest-Even : ajoute 0x7FFF + LSB tronqué
    Result := UInt16((U.I + ($7FFF + ((U.I shr 16) and 1))) shr 16);
  end;
end;

// ============================================================================
// E8M0 <-> FP32 (OFFICIEL GGML)
// ============================================================================
function E8M0ToFP32g(X: UInt8): Single; inline;
var
  Bits: UInt32;
begin
  if X = 0 then
    Bits := $00400000 // 2^(-127) (denormalisé)
  else
    Bits := UInt32(X) shl 23; // Normalisé : 2^(X-127)

  Move(Bits, Result, SizeOf(Result));
end;

// FONCTIONS DE BASE (FP16/BF16)
function FP32ToFP16a(const F: Single): TUInt16;
var
  U: Cardinal;
begin
  Move(F, U, SizeOf(U));
  // Extraction des champs
  Result := (U shr 16) and $8000; // Signe
  case (U shr 23) and $FF of
    $00: // Zéro ou dénormalisé (troncature)
      if (U and $7FFFFF) <> 0 then
        Result := Result or 1; // Subnormal -> 0.002f (GGML simplifie à 0)
    $FF: // NaN ou Inf
      begin
        Result := Result or $7C00;
        if (U and $7FFFFF) <> 0 then
          Result := Result or 1; // NaN
      end;
  else
    begin
      var
      Exp := (U shr 23) and $FF;
      var
      Mant := U and $7FFFFF;
      Exp := Exp - 112; // 127 - 15
      if Exp >= 31 then
        Result := Result or $7C00 // Overflow -> Inf
      else if Exp > 0 then
      begin
        // Arrondi IEEE 754 Round-to-Nearest-Even
        Mant := Mant + $1000; // Bit de garde + bit de round
        Result := Result or (Exp shl 10) or (Mant shr 13);
        if Mant >= $200000 then // Overflow mantisse -> inc exposant
          Result := Result or $400; // Exp += 1 (shl 10 devient shl 10 + 1)
      end
      else
        Result := Result or 1; // Denormalized
    end;
  end;
end;

function FP16ToFP32o2(const H: TUInt16): Single;
var
  U: Cardinal;
  Sign, Exp, Mant: Cardinal;
begin
  Sign := (H and $8000) shl 16;
  Exp := (H and $7C00) shr 10;
  Mant := H and $03FF;

  if Exp = $1F then
    U := Sign or $7F800000 or (Mant shl 13) // NaN/Inf
  else if Exp = 0 then
    U := Sign // Zéro
  else
  begin
    Exp := Exp + 112;
    Mant := Mant shl 13;
    U := Sign or (Exp shl 23) or Mant;
  end;
  Move(U, Result, SizeOf(Single));
end;

function FP32ToFP16o2(const F: Single): TUInt16;
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
      Result := Sign or $7C00 or (Mant shr 13) // NaN
    else
      Result := Sign or $7C00; // Inf
  end
  else if Exp = 0 then
    Result := Sign // Zéro parfait
  else
  begin
    if Exp < 113 then // 127 - 14 : Plage des Subnormaux (Crucial pour l'IA)
    begin
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

function FP16ToFP32o1(const H: TUInt16): Single;
var
  Sign, Exp, Mant, U: Cardinal;
  Shift: Integer;
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
    begin
      // Zéro (positif ou négatif)
      U := Sign;
    end
    else
    begin
      // Nombres Subnormaux (Denormalized)
      // Le champ Exp est 0. La valeur est : (-1)^Sign * 2^(-14) * (Mant / 1024)
      // On doit normaliser la mantisse pour utiliser la conversion standard F32
      // mais en ajustant l'exposant correctement.

      // Trouver le bit le plus significatif de Mant (bits 0-9)
      // On décale Mant vers la gauche jusqu'à ce que le bit 10 (valeur 1024) soit à 1.
      // Cela correspond au bit implicite '1' des nombres normaux.
      Shift := 0;
      while (Mant and $0400) = 0 do // $0400 = 1024 (bit 10)
      begin
        Mant := Mant shl 1;
        Inc(Shift);
      end;
      // À ce stade, Mant a le bit 10 à 1.
      // L'exposant réel est : 1 - Bias_FP16 - Shift = 1 - 15 - Shift = -14 - Shift.
      // L'exposant F32 (Bias 127) doit être : 127 + (-14 - Shift) = 113 - Shift.
      Exp := 113 - Shift;

      // On garde les bits inférieurs (bits 0-9 de Mant original, qui sont maintenant bits 0-9 de Mant modifié)
      // Mais attention : Mant a été décalé. Le bit 10 est maintenant le bit "implicite".
      // Dans la conversion F32 standard, le bit 23 est le bit de poids fort de la mantisse.
      // Ici, notre Mant a le bit 10 à 1. Nous voulons le mettre au bit 23.
      // Décalage supplémentaire : 23 - 10 = 13.

      Mant := Mant and $03FF; // Garde les 10 bits de précision
      U := Sign or (Exp shl 23) or (Mant shl 13);
    end;
  end
  else // Nombres Normaux
  begin
    Exp := Exp + 112; // 127 - 15
    U := Sign or (Exp shl 23) or (Mant shl 13);
  end;
  Move(U, Result, SizeOf(Single));
end;


function FP32ToFP16o(const F: Single): TUInt16; inline;
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
      Result := Sign or $7C00 or (Mant shr 13) // NaN
    else
      Result := Sign or $7C00; // Inf
  end
  else if Exp = 0 then
    Result := Sign // Zéro parfait
  else
  begin
    if Exp < 113 then // 127 - 14 : Plage des Subnormaux (Crucial pour l'IA)
    begin
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

function FP16ToFP32o(const H: TUInt16): Single; inline;
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

function FP32ToBF16o(const F: Single): TUInt16;  inline;
var
  U: TUInt32;
begin
  Move(F, U, SizeOf(U));
  // BF16 tronque simplement les 16 bits de poids faible (pas de arrondi)
  Result := TUInt16(U shr 16);
end;

function BF16ToFP32o(const B: TUInt16): Single;   inline;
var
  U: TUInt32;
begin
  U := TUInt32(B) shl 16;
  Move(U, Result, SizeOf(Result));
end;

// DÉQUANTISATION (Vers Single/F32)
procedure DequantI8(const Data: PByte; Dest: PSingle; n: Integer);
var
  I: Integer;
begin
  for I := 0 to n - 1 do
    Dest[I] := Single(PShortInt(Data)[I]); // PShortInt est un Signed Byte (-128 à 127)
end;

procedure DequantI16(const Data: PByte; Dest: PSingle; n: Integer);
var
  I: Integer;
begin
  for I := 0 to n - 1 do
    Dest[I] := Single(PSmallInt(Data)[I]);
end;

procedure DequantI32(const Data: PByte; Dest: PSingle; n: Integer);
var
  I: Integer;
begin
  for I := 0 to n - 1 do
    Dest[I] := Single(PInteger(Data)[I]);
end;

procedure DequantI64(const Data: PByte; Dest: PSingle; n: Integer);
var
  I: Integer;
begin
  for I := 0 to n - 1 do
    Dest[I] := Single(PInt64(Data)[I]);
end;

procedure DequantF64(const Data: PByte; Dest: PSingle; n: Integer);
var
  I: Integer;
begin
  for I := 0 to n - 1 do
    Dest[I] := Single(PDouble(Data)[I]); // Conversion Float64 -> Float32
end;

// QUANTIFICATION (Depuis Single/F32)
procedure QuantI8(const src: PSingle; Dest: PByte; n: Integer);
var
  I: Integer;
begin
  for I := 0 to n - 1 do
    PShortInt(Dest)[I] := ClampInt(Round(src[I]), -128, 127);
end;

procedure QuantI16(const src: PSingle; Dest: PByte; n: Integer);
var
  I: Integer;
begin
  for I := 0 to n - 1 do
    PSmallInt(Dest)[I] := ClampInt(Round(src[I]), -32768, 32767);
end;

procedure QuantI32(const src: PSingle; Dest: PByte; n: Integer);
var
  I: Integer;
begin
  for I := 0 to n - 1 do
    PInteger(Dest)[I] := Round(src[I]);
end;

procedure QuantI64(const src: PSingle; Dest: PByte; n: Integer);
var
  I: Integer;
begin
  for I := 0 to n - 1 do
    PInt64(Dest)[I] := Round(src[I]);
end;

procedure QuantF64(const src: PSingle; Dest: PByte; n: Integer);
var
  I: Integer;
begin
  for I := 0 to n - 1 do
    PDouble(Dest)[I] := Double(src[I]);
end;

// === CONSTANTES FP8 ===
const
  F8_E4M3_EXP_BIAS = 7;
  F8_E5M2_EXP_BIAS = 15;

  // HELPERS DE CONVERSION BINAIRE (pour manipuler les bits du flottant)
function FloatBitsO(const A: Single): UInt32; inline;
begin
  Move(A, Result, SizeOf(Result));
end;

function FP32FromBitsO(const A: UInt32): Single; inline;
begin
  Move(A, Result, SizeOf(Result));
end;

// DEQUANTISATION FP8 (Safetensors -> Float32)
procedure DequantFP8_E4M3(const Data: PByte; Dest: PSingle; n: Integer);
var
  I: Integer;
  RawByte: UInt8;
  SignBit: Boolean;
  Exp, Mant: Integer;
  Val: Single;
begin
  for I := 0 to n - 1 do
  begin
    RawByte := Data[I];

    // Raccourci pour 0.0 (positif ou négatif)
    if (RawByte and $7F) = 0 then
    begin
      Dest[I] := 0.0;
      Continue;
    end;

    SignBit := (RawByte and $80) <> 0;
    Exp := (RawByte shr 3) and $0F;
    Mant := RawByte and $07;

    if Exp = 0 then
    begin
      // Dénormalisé : 2^(-6) * (Mant / 8) = Mant * 2^(-9)
      Val := Mant * Power(2.0, -9);
    end
    else if (Exp = 15) and (Mant = 7) then
    begin
      // NaN (Standard E4M3FN Safetensors/ONNX)
      Val := NaN;
    end
    else
    begin
      // Normalisé : 2^(Exp - Bias) * (1 + Mant / 8)
      Val := Power(2.0, Exp - 7) * (1.0 + Mant / 8.0);
    end;

    if SignBit then
      Val := -Val;

    Dest[I] := Val;
  end;
end;

procedure DequantFP8_E5M2(const Data: PByte; Dest: PSingle; n: Integer);
var
  I: Integer;
  RawByte: UInt8;
  SignBit: Boolean;
  Exp, Mant: Integer;
  Val: Single;
begin
  for I := 0 to n - 1 do
  begin
    RawByte := Data[I];

    if (RawByte and $7F) = 0 then
    begin
      Dest[I] := 0.0;
      Continue;
    end;

    SignBit := (RawByte and $80) <> 0;
    Exp := (RawByte shr 2) and $1F;
    Mant := RawByte and $03;

    if Exp = 0 then
    begin
      // Dénormalisé : 2^(-14) * (Mant / 4) = Mant * 2^(-16)
      Val := Mant * Power(2.0, -16);
    end
    else if Exp = 31 then
    begin
      // Infini ou NaN
      if Mant = 0 then
        Val := Infinity
      else
        Val := NaN;
    end
    else
    begin
      // Normalisé : 2^(Exp - Bias) * (1 + Mant / 4)
      Val := Power(2.0, Exp - 15) * (1.0 + Mant / 4.0);
    end;

    if SignBit then
      Val := -Val;

    Dest[I] := Val;
  end;
end;

// QUANTISATION FP8 (Float32 -> Safetensors)
procedure QuantFP8_E4M3(const src: PSingle; Dest: PByte; n: Integer);
var
  I: Integer;
  RawBits: UInt32;
  AbsVal: Single;
  Sign, Exp, Mant: UInt32; // Modifié ici
begin
  for I := 0 to n - 1 do
  begin
    AbsVal := Abs(src[I]);
    if AbsVal = 0 then
    begin
      Dest[I] := 0;
      Continue;
    end;

    Move(src[I], RawBits, SizeOf(RawBits));

    Sign := RawBits and $80000000;
    Exp := (RawBits shr 23) and $FF;
    Mant := (RawBits shr 20) and $07;

    // Ajustement de l'exposant
    if Exp < (127 - 7) then
    begin
      // Underflow : on force à zéro (ou on implémente l'arrondi dénormalisé)
      Dest[I] := UInt8(Sign shr 24);
    end
    else
    begin
      Exp := Exp - 127 + 7;
      if Exp >= 15 then
      begin
        // Overflow : Max possible (E4M3FN n'a pas d'Inf, valeur max)
        Dest[I] := UInt8((Sign shr 24) or ($0E shl 3) or $07);
      end
      else
        Dest[I] := UInt8((Sign shr 24) or (Exp shl 3) or Mant);
    end;
  end;
end;

procedure QuantFP8_E5M2(const src: PSingle; Dest: PByte; n: Integer);
var
  I: Integer;
  RawBits: UInt32;
  AbsVal: Single;
  Sign, Exp, Mant: Integer;
begin
  for I := 0 to n - 1 do
  begin
    RawBits := FloatBitsO(src[I]);
    AbsVal := Abs(src[I]);

    if AbsVal = 0.0 then
    begin
      Dest[I] := 0;
    end
    else if AbsVal > 57344.0 then // Max value for E5M2
    begin
      Dest[I] := $7F or (RawBits and $80); // Inf
    end
    else
    begin
      Sign := Integer(RawBits) and $80000000;
      Exp := (Integer(RawBits) shr 23) and $FF;
      Mant := (Integer(RawBits) shr 22) and $03; // Garde les 2 bits de poids fort

      // Conversion du bias : 127 -> 15
      Exp := Exp - 127 + 15;

      if Exp <= 0 then
        Dest[I] := Sign shr 24
      else if Exp > $1F then
        Dest[I] := $7F or (Sign shr 24)
      else
      begin
        Dest[I] := (Exp shl 2) or (Mant and $03) or (Sign shr 24);
      end;
    end;
  end;
end;

// ============================================================================
function MakeQxQuants(n, nmax: Integer; const X: PSingle; L: PShortInt; rmse_type: Integer; const qw: PSingle): Single;
var
  amax, MaxVal, iscale, scale, sumlx, suml2, weight, best: Single;
  I, itry, l_val: Integer;
begin
  // 1. Recherche du maximum absolu et de sa valeur signée dans le bloc
  amax := 0.0;
  MaxVal := 0.0;
  for I := 0 to n - 1 do
  begin
    if Abs(X[I]) > amax then
    begin
      amax := Abs(X[I]);
      MaxVal := X[I];
    end;
  end;

  // 2. Gestion du cas nul : si le bloc est quasi vide, on retourne des poids nuls
  if amax < GROUP_MAX_EPS then
  begin
    FillChar(L[0], n * SizeOf(ShortInt), 0);
    Exit(0.0);
  end;

  // 3. Échelle initiale basée sur le maximum signé
  iscale := -nmax / MaxVal;

  // 4. Si rmse_type = 0 : quantification simple sans optimisation MSE
  if rmse_type = 0 then
  begin
    for I := 0 to n - 1 do
    begin
      l_val := NearestInt(iscale * X[I]);
      L[I] := nmax + ClampInt(l_val, -nmax, nmax - 1);
    end;
    Exit(1.0 / iscale);
  end;

  // 5. Calcul des sommes pondérées initiales pour l'optimisation MSE
  // sumlx = ∑ w*x*l   et   suml2 = ∑ w*l²
  sumlx := 0.0;
  suml2 := 0.0;
  for I := 0 to n - 1 do
  begin
    l_val := NearestInt(iscale * X[I]);
    l_val := ClampInt(l_val, -nmax, nmax - 1);
    L[I] := l_val + nmax; // Décalage pour stockage unsigned

    // Calcul du poids selon le type d'optimisation
    if qw <> nil then
      weight := qw[I]
    else if rmse_type = 1 then
      weight := X[I] * X[I] // Pondération par x² (variance locale)
    else if rmse_type = 2 then
      weight := 1.0 // Pondération uniforme
    else if rmse_type = 3 then
      weight := Abs(X[I]) // Pondération par magnitude
    else
      weight := Sqrt(Abs(X[I])); // Racine carrée de la magnitude

    sumlx := sumlx + weight * X[I] * l_val;
    suml2 := suml2 + weight * l_val * l_val;
  end;

  // 6. Échelle initiale par régression pondérée (formule des moindres carrés)
  scale := 0.0;
  if suml2 > 0 then
    scale := sumlx / suml2;

  // 7. Exit anticipé pour rmse_type négatif (mode hybride GGML)
  if rmse_type < 0 then
  begin
    if suml2 > 0 then
      Exit(0.5 * (scale + 1.0 / iscale))
    else
      Exit(1.0 / iscale);
  end;

  // 8. Recherche locale autour de l'échelle optimale (grille de ±0.9)
  // Cette étape affine l'échelle pour minimiser l'erreur MSE pondérée
  best := scale * sumlx;
  for itry := -9 to 9 do
  begin
    if itry = 0 then
      Continue;
    iscale := -(nmax + 0.1 * itry) / MaxVal;
    sumlx := 0.0;
    suml2 := 0.0;
    for I := 0 to n - 1 do
    begin
      l_val := NearestInt(iscale * X[I]);
      l_val := ClampInt(l_val, -nmax, nmax - 1);
      if qw <> nil then
        weight := qw[I]
      else if rmse_type = 1 then
        weight := X[I] * X[I]
      else if rmse_type = 2 then
        weight := 1.0
      else if rmse_type = 3 then
        weight := Abs(X[I])
      else
        weight := Sqrt(Abs(X[I]));
      sumlx := sumlx + weight * X[I] * l_val;
      suml2 := suml2 + weight * l_val * l_val;
    end;

    // Critère d'acceptation : si (sumlx² / suml2) > meilleur MSE précédent
    if (suml2 > 0) and ((sumlx * sumlx) > (best * suml2)) then
    begin
      for I := 0 to n - 1 do
        L[I] := nmax + ClampInt(NearestInt(iscale * X[I]), -nmax, nmax - 1);
      scale := sumlx / suml2;
      best := scale * sumlx;
    end;
  end;
  Result := scale; // Retourne l'échelle optimisée
end;

// ============================================================================
function MakeQ3Quants(n, nmax: Integer; const X: PSingle; L: PShortInt; do_rmse: Boolean): Single;
var
  I, l_val, itry, n_changed, new_l: Integer;
  amax, MaxVal, iscale, sumlx, suml2, W, slx, sl2: Single;
begin
  // 1. Maxim du bloc
  amax := 0.0;
  MaxVal := 0.0;
  for I := 0 to n - 1 do
    if Abs(X[I]) > amax then
    begin
      amax := Abs(X[I]);
      MaxVal := X[I];
    end;

  // 2. Fallback nul
  if amax < GROUP_MAX_EPS then
  begin
    FillChar(L^, n * SizeOf(ShortInt), 0);
    Exit(0.0);
  end;

  iscale := -nmax / MaxVal;

  // 3. Mode RMSE : Descente de coordonnées itérative pour optimiser chaque poids
  if do_rmse then
  begin
    sumlx := 0.0;
    suml2 := 0.0;
    // Initialisation des poids et calcul des sommes pondérées
    for I := 0 to n - 1 do
    begin
      l_val := NearestInt(iscale * X[I]);
      l_val := ClampInt(l_val, -nmax, nmax - 1);
      L[I] := l_val;
      W := X[I] * X[I]; // Pondération par variance
      sumlx := sumlx + W * X[I] * l_val;
      suml2 := suml2 + W * l_val * l_val;
    end;

    // Boucle de raffinement : on teste le remplacement de chaque poids
    for itry := 0 to 4 do
    begin
      n_changed := 0;
      for I := 0 to n - 1 do
      begin
        W := X[I] * X[I];
        // Calcul des sommes sans le poids actuel (slx, sl2)
        slx := sumlx - W * X[I] * L[I];
        if slx > 0.0 then
        begin
          sl2 := suml2 - W * L[I] * L[I];
          if sl2 > 0.0 then
          begin
            // Nouveau poids optimal conditionnel
            // new_l := Round(X[i] * sl2 / slx);
            new_l := ClampInt(NearestInt(X[I] * sl2 / slx), -nmax, nmax - 1);
            if new_l <> L[I] then
            begin
              // Validation par critère MSE pondéré
              slx := slx + W * X[I] * new_l;
              sl2 := sl2 + W * new_l * new_l;
              if (slx * slx * suml2) > (sumlx * sumlx * sl2) then
              begin
                L[I] := new_l;
                sumlx := slx;
                suml2 := sl2;
                Inc(n_changed);
              end;
            end;
          end;
        end;
      end;
      if n_changed = 0 then
        Break; // Convergence atteinte
    end;

    // Décalage pour stockage unsigned
    for I := 0 to n - 1 do
      L[I] := L[I] + nmax;
    Result := 0.0;
    if suml2 > 0.0 then
      Result := sumlx / suml2;
  end
  else
  // 4. Mode classique : quantification directe sans optimisation
  begin
    for I := 0 to n - 1 do
    begin
      l_val := NearestInt(iscale * X[I]);
      L[I] := ClampInt(l_val, -nmax, nmax - 1) + nmax;
    end;
    Result := 1.0 / iscale;
  end;
end;

// ============================================================================
function MakeQkx2Quants(n, nmax: Integer; const X, weights: PSingle; L: PByte; out MinVal: Single; Laux: PByte;
  rmin, rdelta: Single; nstep: Integer; use_mad: Boolean): Single;
var
  I, l_val, is_step: Integer;
  loVal, hiVal, sum_w, sum_x, iscale, scale, best_error, diff, W: Single;
  sum_l, sum_l2, sum_xl, D, this_scale, this_min, cur_error: Single;
begin
  // 1. Analyse du bloc : min, max, sommes pondérées
  loVal := X[0];
  hiVal := X[0];
  if weights <> nil then
    sum_w := weights[0]
  else
    sum_w := X[0] * X[0];
  sum_x := sum_w * X[0];
  for I := 1 to n - 1 do
  begin
    if X[I] < loVal then
      loVal := X[I];
    if X[I] > hiVal then
      hiVal := X[I];
    if weights <> nil then
      W := weights[I]
    else
      W := X[I] * X[I];
    sum_w := sum_w + W;
    sum_x := sum_x + W * X[I];
  end;

  // Contrainte GGML : le minimum doit être ≤ 0 (on stocke -min)
  if loVal > 0.0 then
    loVal := 0.0;
  if hiVal <= loVal then
  begin
    FillChar(L^, n, 0);
    MinVal := -loVal;
    Exit(0.0);
  end;

  // 2. Échelle initiale et erreur de référence
  iscale := nmax / (hiVal - loVal);
  scale := 1.0 / iscale;
  best_error := 0.0;
  for I := 0 to n - 1 do
  begin
    l_val := NearestInt(iscale * (X[I] - loVal));
    L[I] := ClampInt(l_val, 0, nmax);
    diff := scale * L[I] + loVal - X[I];
    if use_mad then
      diff := Abs(diff)
    else
      diff := diff * diff;
    if weights <> nil then
      W := weights[I]
    else
      W := X[I] * X[I];
    best_error := best_error + W * diff;
  end;

  // 3. Si pas de recherche sur grille, on retourne le résultat initial
  if nstep < 1 then
  begin
    MinVal := -loVal;
    Exit(scale);
  end;

  // 4. Recherche sur grille d'échelles pour optimiser d et min simultanément
  for is_step := 0 to nstep do
  begin
    iscale := (rmin + rdelta * is_step + nmax) / (hiVal - loVal);
    sum_l := 0.0;
    sum_l2 := 0.0;
    sum_xl := 0.0;
    for I := 0 to n - 1 do
    begin
      l_val := NearestInt(iscale * (X[I] - loVal));
      l_val := ClampInt(l_val, 0, nmax);
      Laux[I] := l_val;
      if weights <> nil then
        W := weights[I]
      else
        W := X[I] * X[I];
      sum_l := sum_l + W * l_val;
      sum_l2 := sum_l2 + W * l_val * l_val;
      sum_xl := sum_xl + W * l_val * X[I];
    end;

    // Résolution système linéaire pondéré pour d et m :
    // x ≈ d*L + m  =>  moindres carrés avec pondération w
    D := sum_w * sum_l2 - sum_l * sum_l;
    if D > 0.0 then
    begin
      this_scale := (sum_w * sum_xl - sum_x * sum_l) / D;
      this_min := (sum_l2 * sum_x - sum_l * sum_xl) / D;

      // Contrainte GGML : min ≤ 0
      if this_min > 0.0 then
      begin
        this_min := 0.0;
        this_scale := sum_xl / sum_l2;
      end;

      // Calcul de l'erreur courante (MSE ou MAD)
      cur_error := 0.0;
      for I := 0 to n - 1 do
      begin
        diff := this_scale * Laux[I] + this_min - X[I];
        if use_mad then
          diff := Abs(diff)
        else
          diff := diff * diff;
        if weights <> nil then
          W := weights[I]
        else
          W := X[I] * X[I];
        cur_error := cur_error + W * diff;
      end;

      // Mise à jour si meilleure solution trouvée
      if cur_error < best_error then
      begin
        Move(Laux[0], L[0], n);
        best_error := cur_error;
        scale := this_scale;
        loVal := this_min;
      end;
    end;
  end;

  MinVal := -loVal;
  Result := scale;
end;

// ============================================================================
// make_qkx3_quants : utilisé dans les versions IMPL (Q4_K, Q5_K)
// Diffère de kx2 par les paramètres de grille et le fallback poids par défaut
function MakeQkx3Quants(n, nmax: Integer; const X, weights: PSingle; L: PByte; out MinVal: Single; Laux: PByte;
  rmin, rdelta: Single; nstep: Integer; use_mad: Boolean): Single;
begin
  // Implémentation identique à kx2, mais les parametres par défaut sont passés par l'appelant
  // On réutilise le même corps pour éviter la duplication, GGML le fait aussi
  Result := MakeQkx2Quants(n, nmax, X, weights, L, MinVal, Laux, rmin, rdelta, nstep, use_mad);
end;

// ============================================================================
function MakeQpQuants(n, nmax: Integer; const X, weights: PSingle; L: PByte): Single;
var
  I, is_step, l_val, new_l, itry, n_changed: Integer;
  hiVal, iscale, scale, best_mse, diff, W, iscale_is, scale_is, mse: Single;
  sumlx, suml2, slx, sl2: Single;
begin
  // 1. Trouve le maximum pour déterminer l'échelle initiale
  hiVal := 0.0;
  for I := 0 to n - 1 do
    if X[I] > hiVal then
      hiVal := X[I];

  if hiVal < GROUP_MAX_EPS then
  begin
    FillChar(L[0], n, 0);
    Exit(0.0);
  end;

  // 2. Quantification initiale et calcul MSE
  iscale := nmax / hiVal;
  for I := 0 to n - 1 do
    L[I] := Min(nmax, NearestInt(iscale * X[I]));
  scale := 1.0 / iscale;
  best_mse := 0.0;
  for I := 0 to n - 1 do
  begin
    diff := X[I] - scale * L[I];
    if weights <> nil then
      W := weights[I]
    else
      W := 1.0;
    best_mse := best_mse + W * diff * diff;
  end;

  // 3. Affinage de l'échelle par recherche sur grille (±0.4)
  for is_step := -4 to 4 do
  begin
    if is_step = 0 then
      Continue;
    iscale_is := (0.1 * is_step + nmax) / hiVal;
    scale_is := 1.0 / iscale_is;
    mse := 0.0;
    for I := 0 to n - 1 do
    begin
      l_val := Min(nmax, NearestInt(iscale_is * X[I]));
      diff := X[I] - scale_is * l_val;
      if weights <> nil then
        W := weights[I]
      else
        W := 1.0;
      mse := mse + W * diff * diff;
    end;
    if mse < best_mse then
    begin
      best_mse := mse;
      iscale := iscale_is;
    end;
  end;

  // 4. Recalcul des sommes pondérées avec l'échelle finale
  sumlx := 0.0;
  suml2 := 0.0;
  for I := 0 to n - 1 do
  begin
    l_val := Min(nmax, NearestInt(iscale * X[I]));
    L[I] := l_val;
    if weights <> nil then
      W := weights[I]
    else
      W := 1.0;
    sumlx := sumlx + W * X[I] * l_val;
    suml2 := suml2 + W * l_val * l_val;
  end;

  // 5. Descente de coordonnées pour optimiser les poids individuels
  for itry := 0 to 4 do
  begin
    n_changed := 0;
    for I := 0 to n - 1 do
    begin
      if weights <> nil then
        W := weights[I]
      else
        W := 1.0;
      slx := sumlx - W * X[I] * L[I];
      sl2 := suml2 - W * L[I] * L[I];
      if (slx > 0.0) and (sl2 > 0.0) then
      begin
        new_l := Min(nmax, NearestInt(X[I] * sl2 / slx));
        if new_l <> L[I] then
        begin
          slx := slx + W * X[I] * new_l;
          sl2 := sl2 + W * new_l * new_l;
          if (slx * slx * suml2) > (sumlx * sumlx * sl2) then
          begin
            L[I] := new_l;
            sumlx := slx;
            suml2 := sl2;
            Inc(n_changed);
          end;
        end;
      end;
    end;
    if n_changed = 0 then
      Break;
  end;

  Result := 0.0;
  if suml2 > 0.0 then
    Result := sumlx / suml2;
end;

// ============================================================================
procedure GetScaleMinK4(j: Integer; const scales: PByte; out sc, m: Byte); inline;
begin
  // Décodage des scales et mins packés sur 6 bits pour le format Q4_K/Q5_K
  // Les 12 octets contiennent 8 scales + 8 mins packés 4 par 4
  if j < 4 then
  begin
    sc := scales[j] and $3F; // Scale bas (6 bits)
    m := scales[j + 4] and $3F; // Min bas (6 bits)
  end
  else
  begin
    // Décalage et masquage pour les indices 4-7
    sc := (scales[j + 4] and $0F) or ((scales[j - 4] shr 6) shl 4);
    m := (scales[j + 4] shr 4) or ((scales[j] shr 6) shl 4);
  end;
end;

initialization

GROUP_MAX_EPS := 1E-15;

ExpScale := 1E-112; // 0x1.0p-112; // 2^(-112)

ScaleToInf := 1E+112; // 0x1.0p+112; // 2^112

ScaleToZero := 1E-110; // 0x1.0p-110; // 2^(-110)

end.
