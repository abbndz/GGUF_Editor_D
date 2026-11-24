unit uGgmlQuantsFP8_E4M3;

{ FP8 E4M3 / E5M2 - port bit-exact de ggml-impl.h :
    ggml_fp32_to_f8_e4m3 / ggml_f8_e4m3_to_fp32
  - arrondi ties-to-even exactement comme ggml_round_to_nearest_even
  - sous-normaux codes (M * 2^-9) avec report naturel vers 2^-6
  - saturation a 448 (0x7E) ; JAMAIS 0x7F (= NaN) pour une entree finie }

interface

uses
  SysUtils, uGGMLConstants, uMath;

{$B-}
{$R-}
{$POINTERMATH ON}
{$J-}
{$O+}
{$ALIGN 8}

const
  FP8_E4M3_MAX_FINITE: Single = 448.0; // 0x7E (E4M3 n'a pas d'infini)
  FP8_E5M2_MAX_FINITE: Single = 57344.0; // 0x7B (E5M2 a l'infini)

function FP32ToF8E4M3(const F: Single): Byte;
function F8E4M3ToFP32(B: Byte): Single;
function FP32ToF8E5M2(const F: Single): Byte;
function F8E5M2ToFP32(B: Byte): Single;

procedure DequantFP8_E4M3(const Data: PByte; Dest: PSingle; n: Integer);
procedure QuantFP8_E4M3(const src: PSingle; Dest: PByte; n: Integer);
procedure DequantFP8_E5M2(const Data: PByte; Dest: PSingle; n: Integer);
procedure QuantFP8_E5M2(const src: PSingle; Dest: PByte; n: Integer);

// Garde-fou de non-regression (a brancher sur un bouton debug / demarrage)
procedure SelfTestFP8;

var
  LUT_E4M3: array [0 .. 255] of Single;
  LUT_E5M2: array [0 .. 255] of Single;

implementation

const
  // magnitudes sous-normales, dyadiques donc EXACTES en binaire
  CSubE4M3: array [0 .. 7] of Single =
    (0.0, 0.001953125, 0.00390625, 0.005859375, 0.0078125,
     0.009765625, 0.01171875, 0.013671875);      // M * 2^-9
  CSubE5M2: array [0 .. 3] of Single =
    (0.0, 0.0000152587890625, 0.000030517578125,
     0.0000457763671875);                        // M * 2^-16

  FP8_CANON_NAN: Cardinal = $7FC00000;



function BitsOf(const F: Single): Cardinal; inline;
begin
  Move(F, Result, 4);
end;

function SingleFromBits(U: Cardinal): Single; inline;
begin
  Move(U, Result, 4);
end;

// floor(S / 2^Shift) avec arrondi "ties to even".
// Equivalent exact de ggml_round_to_nearest_even(S * 2^-Shift) pour S < 2^24
// (le scale par puissance de 2 est exact, le test d'egalite aussi).
function ShrRoundHalfEven(S: Cardinal; Shift: Integer): Cardinal; inline;
var
  Q, Half, Rem: Cardinal;
begin
  if Shift > 24 then
    Exit(0); // |x| < 0.5 ulp -> 0 (aucune egalite possible car S < 2^24)
  Q := S shr Shift;
  Half := Cardinal(1) shl (Shift - 1);
  Rem := S and ((Half shl 1) - 1);
  if (Rem > Half) or ((Rem = Half) and Odd(Q)) then
    Inc(Q);
  Result := Q;
end;

// ---------------------------------------------------------------------------
// E4M3 : encode
// ---------------------------------------------------------------------------
function FP32ToF8E4M3(const F: Single): Byte;
var
  U, M23: Cardinal;
  Sign, E32, M, E: Integer;
begin
  U := BitsOf(F);

  // NaN / Infinis (champs exponent + mantisse)
  if (U and $7F800000) = $7F800000 then
  begin
    if (U and $007FFFFF) <> 0 then
      Exit($7F);                                  // NaN -> canonique (pas de signe)
    Exit(Byte(((U shr 24) and $80) or $7E));      // +/-Inf -> saturation 448
  end;

  Sign := (U shr 24) and $80;                     // signe() : -0.0 preserve
  E32 := (U shr 23) and $FF;
  M23 := U and $007FFFFF;

  if E32 = 0 then
    Exit(Byte(Sign));                             // fp32 sous-normal -> 0

  if E32 <= 120 then
  begin
    // |x| < 2^-6 : sous-normaux = round_half_even(x * 512)
    // x*512 = S / 2^(141-e32).  M peut valoir 8 : le report donne
    // naturellement 0x08 = 2^-6 (le C fait pareil, cast (uint8_t)).
    Exit(Byte(Sign or (ShrRoundHalfEven(M23 or $00800000, 141 - E32) and $FF)));
  end;

  // 2^-6 <= |x| :  E = (e32 - 127) + 7 = e32 - 120 ;  M = round(m23 / 2^20)
  M := ShrRoundHalfEven(M23, 20);
  E := E32 - 120;
  if M = 8 then
  begin
    M := 0;
    Inc(E);
  end;
  if (E > 15) or ((E = 15) and (M > 6)) then
    Exit(Byte(Sign or $7E));                      // saturE a 448, jamais NaN

  Result := Byte(Sign or (E shl 3) or M);
end;

// ---------------------------------------------------------------------------
// E5M2 : encode (E5M2 possede l'infini ; si tu preferes saturer a 57344,
// remplace $7C par $7B dans les deux Exit de saturation)
// ---------------------------------------------------------------------------
function FP32ToF8E5M2(const F: Single): Byte;
var
  U, M23: Cardinal;
  Sign, E32, M, E: Integer;
begin
  U := BitsOf(F);
  if (U and $7F800000) = $7F800000 then
  begin
    if (U and $007FFFFF) <> 0 then
      Exit(Byte(((U shr 24) and $80) or $7F));    // NaN
    Exit(Byte(((U shr 24) and $80) or $7C));      // +/-Inf
  end;

  Sign := (U shr 24) and $80;
  E32 := (U shr 23) and $FF;
  M23 := U and $007FFFFF;

  if E32 = 0 then
    Exit(Byte(Sign));

  if E32 <= 112 then
  begin
    // |x| < 2^-14 : sous-normaux = round_half_even(x * 2^16), x*2^16 = S / 2^(134-e32)
    Exit(Byte(Sign or (ShrRoundHalfEven(M23 or $00800000, 134 - E32) and $FF)));
  end;

  M := ShrRoundHalfEven(M23, 21);                 // 2 mantissa bits -> shift 21
  E := E32 - 112;                                 // (e32-127)+15
  if M = 4 then
  begin
    M := 0;
    Inc(E);
  end;
  if (E > 30) or ((E = 30) and (M > 3)) then
    Exit(Byte(Sign or $7C));                      // -> Infini

  Result := Byte(Sign or (E shl 2) or M);
end;

// ---------------------------------------------------------------------------
// LUT de decodage (construites une seule fois)
// ---------------------------------------------------------------------------
procedure InitLUT_E4M3;
var
  B, E, M: Integer;
  V: Single;
begin
  for B := 0 to 255 do
  begin
    if (B and $7F) = $7F then
      V := SingleFromBits(FP8_CANON_NAN)          // OCP : 0x7F et 0xFF = NaN
    else
    begin
      E := (B shr 3) and $0F;
      M := B and $07;
      if E = 0 then
        V := CSubE4M3[M]                          // M * 2^-9
      else
        V := SingleFromBits((Cardinal(E + 120) shl 23) or (Cardinal(M) shl 20));
    end;
    if (B and $80) <> 0 then
      V := -V;                                    // -0.0 conserve, comme le C
    LUT_E4M3[B] := V;
  end;
end;

procedure InitLUT_E5M2;
var
  B, E, M: Integer;
  V: Single;
begin
  for B := 0 to 255 do
  begin
    E := (B shr 2) and $1F;
    M := B and $03;
    if E = $1F then
    begin
      if M = 0 then
        V := Infinity
      else
        V := SingleFromBits(FP8_CANON_NAN);
    end
    else if E = 0 then
      V := CSubE5M2[M]                            // M * 2^-16
    else
      V := SingleFromBits((Cardinal(E + 112) shl 23) or (Cardinal(M) shl 21));
    if (B and $80) <> 0 then
      V := -V;
    LUT_E5M2[B] := V;
  end;
end;

function F8E4M3ToFP32(B: Byte): Single; inline;
begin
  Result := LUT_E4M3[B];
end;

function F8E5M2ToFP32(B: Byte): Single; inline;
begin
  Result := LUT_E5M2[B];
end;

// ---------------------------------------------------------------------------
// Rangees
// ---------------------------------------------------------------------------
procedure DequantFP8_E4M3(const Data: PByte; Dest: PSingle; n: Integer);
var
  i: Integer;
begin
  for i := 0 to n - 1 do
    Dest[i] := LUT_E4M3[Data[i]];
end;

procedure QuantFP8_E4M3(const src: PSingle; Dest: PByte; n: Integer);
var
  i: Integer;
begin
  for i := 0 to n - 1 do
    Dest[i] := FP32ToF8E4M3(src[i]);
end;

procedure DequantFP8_E5M2(const Data: PByte; Dest: PSingle; n: Integer);
var
  i: Integer;
begin
  for i := 0 to n - 1 do
    Dest[i] := LUT_E5M2[Data[i]];
end;

procedure QuantFP8_E5M2(const src: PSingle; Dest: PByte; n: Integer);
var
  i: Integer;
begin
  for i := 0 to n - 1 do
    Dest[i] := FP32ToF8E5M2(src[i]);
end;

// ---------------------------------------------------------------------------
// Auto-test
// ---------------------------------------------------------------------------
procedure SelfTestFP8;
const
  // (entree, octet attendu) -- table verifiee contre la reference C
  GoldenE4M3: array [0 .. 15] of record V: Single; B: Byte; end =
    ((V: 0.0;          B: $00), (V: -0.0;         B: $80),
     (V: 1.0;          B: $38), (V: -1.0;         B: $B8),
     (V: 0.015625;     B: $08), (V: 0.001953125;  B: $01),   // 1*2^-9
     (V: 0.0048828125; B: $02), (V: 0.0029296875; B: $02),   // ties 2.5->2, 1.5->2
     (V: 0.0087890625; B: $04), (V: 0.0068359375; B: $04),   // ties 4.5->4, 3.5->4
     (V: 0.02;         B: $0A), (V: 1.0625;       B: $38),   // ties -> code pair
     (V: 1.1875;       B: $3A), (V: 448.0;        B: $7E),
     (V: 480.0;        B: $7E), (V: 1E30;         B: $7E));
var
  i, K: Integer;
  V: Single;
  B: Byte;
begin
  for i := Low(GoldenE4M3) to High(GoldenE4M3) do
  begin
    B := FP32ToF8E4M3(GoldenE4M3[i].V);
    if B <> GoldenE4M3[i].B then
      raise EGGML.CreateFmt('SelfTestFP8 E4M3: %.10g -> $%.2X (attendu $%.2X)',
        [GoldenE4M3[i].V, B, GoldenE4M3[i].B]);
  end;

  // round-trip des 256 codes : tout code non-NaN doit se re-encoder a l'identique
  for K := 0 to 255 do
  begin
    if (K and $7F) = $7F then Continue;           // NaN non inversible
    V := LUT_E4M3[K];
    B := FP32ToF8E4M3(V);
    if B <> Byte(K) then
      raise EGGML.CreateFmt('SelfTestFP8 E4M3 round-trip: $%.2X -> %.10g -> $%.2X',
        [K, V, B]);
  end;

  // aucune entree finie ne doit produire NaN (regression du bug $77)
  for K := -5000 to 5000 do
    for i := 0 to 3 do
    begin
      V := Single(K) * (0.001 * (i + 1)) + 0.0005;
      B := FP32ToF8E4M3(V);
      if (B and $7F) = $7F then
        raise EGGML.CreateFmt('SelfTestFP8 E4M3: NaN illegit pour %.10g', [V]);
    end;

  // E5M2 : sanity minimal
  if FP32ToF8E5M2(1.0) <> $3C then raise EGGML.Create('SelfTestFP8 E5M2: 1.0');
  if FP32ToF8E5M2(57344.0) <> $7B then raise EGGML.Create('SelfTestFP8 E5M2: max');
  for K := 0 to 255 do
    if not ((K and $7C) = $7C) then               // Inf/NaN excludes
      if LUT_E5M2[FP32ToF8E5M2(LUT_E5M2[K])] <> LUT_E5M2[K] then
        raise EGGML.CreateFmt('SelfTestFP8 E5M2 round-trip: $%.2X', [K]);
end;

initialization
  InitLUT_E4M3;
  InitLUT_E5M2;

end.

