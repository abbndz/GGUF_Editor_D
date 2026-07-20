unit uGgmlQuants;

interface

uses
  SysUtils, Classes, uGGMLTypes, uGGMLConstants, uMath, uLog;

{$B-} // active les checks de performance. Les indices sont validés par les structures GGML.
{$R-}  // Désactive les range checks pour éviter les surcoûts dans les boucles critiques

{$POINTERMATH ON}   // PByte + 2 = adresse + 2 octets (C-compatible)
{$J-}               // Désactive les checks de bounds (indices validés par la logique GGML)
{$O+}               // Active les optimisations du compilateur (inline, loop unroll)
{$ALIGN 8}          // Alignement SSE2 optimal pour les Single

const
  GROUP_MAX_EPS = 1E-15; // Seuil en dessous duquel un bloc de poids est considéré comme vide/nul

type
  EGGML = class(Exception); // Exception personnalisée pour erreurs de quantification GGML

  TGGMLShape = array of Int64; // Type générique pour stocker la dimension des tenseurs GGML

  // ============================================================================
  // DÉCLARATIONS PUBLIQUES : DÉQUANTISATION & QUANTISATION
  // ============================================================================
  // Format Q4_0 : 4 bits/paramètre. Bloc de 32 éléments.
  // Formule : x = d * (q - 8), où q ∈ [0, 15], d ∈ FP16
procedure DequantQ4_0(const Data: PByte; Dest: PSingle; n_row: Integer); // testé OK
procedure QuantQ4_0_Ref(const src: PSingle; Dest: PByte; n_row: Integer); // testé OK
procedure QuantQ4_0_Impl(const src: PSingle; Dest: PByte; n_row: Integer; quant_weights: PSingle = nil);
// testé OK très lent

// Format Q4_1 : 4 bits/paramètre. Bloc de 32 éléments.
// Formule : x = d * q + m, où q ∈ [0, 15], d,m ∈ FP16
procedure DequantQ4_1(const Data: PByte; Dest: PSingle; n_row: Integer); // testé OK
procedure QuantQ4_1_Ref(const src: PSingle; Dest: PByte; n_row: Integer); // testé OK
procedure QuantQ4_1_Impl(const src: PSingle; Dest: PByte; n_row: Integer; quant_weights: PSingle = nil);
// testé OK très lent

// Format Q5_0 : 5 bits/paramètre. Bloc de 32 éléments.
// Formule : x = d * (q - 16), où q ∈ [0, 31], d ∈ FP16. Bit 4 stocké dans qh[4]
procedure DequantQ5_0(const Data: PByte; Dest: PSingle; n_row: Integer); // testé OK
procedure QuantQ5_0_Ref(const src: PSingle; Dest: PByte; n_row: Integer); // testé OK
procedure QuantQ5_0_Impl(const src: PSingle; Dest: PByte; n_row: Integer; quant_weights: PSingle = nil);

// Format Q5_1 : 5 bits/paramètre. Bloc de 32 éléments.
// Formule : x = d * q + m, où q ∈ [0, 31], d,m ∈ FP16. Bit 4 stocké dans qh[4]
procedure DequantQ5_1(const Data: PByte; Dest: PSingle; n_row: Integer); // testé OK
procedure QuantQ5_1_Ref(const src: PSingle; Dest: PByte; n_row: Integer); // testé OK
procedure QuantQ5_1_Impl(const src: PSingle; Dest: PByte; n_row: Integer; quant_weights: PSingle = nil);
// testé OK très lent

// Format Q8_0 : 8 bits/paramètre. Bloc de 32 éléments.
// Formule : x = d * q, où q ∈ [-128, 127], d ∈ FP16
procedure DequantQ8_0(const Data: PByte; Dest: PSingle; n_row: Integer); // testé OK
procedure QuantQ8_0(const src: PSingle; Dest: PByte; n_row: Integer);
procedure QuantQ8_0_Ref(const src: PSingle; Dest: PByte; n_row: Integer);

// Format Q8_1 : 8 bits/paramètre. Bloc de 32 éléments.
// Formule : x = d * q + s, où s = d * Σq, d ∈ FP16
procedure DequantQ8_1(const Data: PByte; Dest: PSingle; n_row: Integer);
procedure QuantQ8_1_Ref(const src: PSingle; Dest: PByte; n_row: Integer);

// Formats entiers/floats standards
procedure DequantF16(const Data: PByte; Dest: PSingle; n_row: Integer);
procedure QuantF16(const src: PSingle; Dest: PByte; n_row: Integer);
procedure DequantBF16(const Data: PByte; Dest: PSingle; n_row: Integer);
procedure QuantBF16(const src: PSingle; Dest: PByte; n_row: Integer);

// ============================================================================
// DISPATCHERS GÉNÉRIQUES & UTILITAIRES
// ============================================================================
// Routeur de déquantisation : tente DLL → fallback Delphi → raise si inconnu
procedure DeQuant(const Data: PByte; Dest: PSingle; n_row, SrcType: Integer; UseDLL: Boolean = False);

// Routeur de quantisation : applique Ref ou Impl selon cfg.UseFImpl
procedure Quant(const src: PSingle; Dest: PByte; n_row, DstType: Integer; UseDLL: Boolean = False);

// Convertisseur de tenseurs via espace intermédiaire F32
function ConvertTensorData(const SrcData: TBytes; SrcType, DstType: Integer; Rows, Cols: Int64; out DstData: TBytes;
  UseDLL: Boolean = True; OnProgress: TOnProgressEvent1 = nil): Boolean;

implementation

uses uAppConfig, uGGMLQuantUtils, uGgmlQuantsQ4K, uGgmlQuantsQ6K;

// ============================================================================
procedure DequantQ4_0(const Data: PByte; Dest: PSingle; n_row: Integer);
var
  nb, i, j: Integer;
  B: PByte;
  D: Single;
  v0, v1: Integer;
begin
  // 1. Nombre de blocs complets de 32 éléments
  nb := n_row div QK4_0;
  B := Data;
  for i := 0 to nb - 1 do
  begin
    // 2. Lecture de l'échelle d (FP16 → FP32)
    D := FP16ToFP32o(PWord(B)^);
    Inc(B, 2);
    // 3. Dé-packing des 16 paires de 4 bits
    for j := 0 to (QK4_0 div 2) - 1 do
    begin
      // Bits 0-3 → premier poids, Bits 4-7 → second poids
      v0 := (B[j] and $0F) - 8; // Décalage -8 pour centrer [-8, 7]
      v1 := (B[j] shr 4) - 8;
      // 4. Application de l'échelle : x = d * v
      Dest[i * QK4_0 + j] := v0 * D;
      Dest[i * QK4_0 + j + (QK4_0 div 2)] := v1 * D;
    end;
    Inc(B, 16); // Chaque bloc fait 18 octets (2 d + 16 qs)
  end;
end;

procedure QuantQ4_0_Ref(const src: PSingle; Dest: PByte; n_row: Integer);
var
  nb, i, j: Integer;
  pBlock: PBlockQ4_0;
  amax, maxVal, D, id, x0, x1: Single;
  xi0, xi1: Integer;
begin
  nb := n_row div QK4_0;
  pBlock := PBlockQ4_0(Dest);

  for i := 0 to nb - 1 do
  begin
    amax := 0.0;
    maxVal := 0.0;

    // 1. Recherche du maximum absolu ET de sa valeur signée
    for j := 0 to QK4_0 - 1 do
    begin
      if Abs(src[i * QK4_0 + j]) > amax then
      begin
        amax := Abs(src[i * QK4_0 + j]);
        maxVal := src[i * QK4_0 + j];
      end;
    end;

    // 2. Calcul de l'échelle d = max / -8 (centre les valeurs autour de 0)
    D := maxVal / -8.0;
    if D <> 0 then
      id := 1.0 / D
    else
      id := 0.0;

    // 3. Stockage de d en FP16
    pBlock^.D := FP32ToFP16o(D);

    // 4. Quantification par paires avec arrondi à +8.5 (simule le cast C (int8_t)(x+8.5f))
    for j := 0 to (QK4_0 div 2) - 1 do
    begin
      x0 := src[i * QK4_0 + j] * id;
      x1 := src[i * QK4_0 + (QK4_0 div 2) + j] * id;
      xi0 := Trunc(Single(x0 + 8.5)); // Troncation vers zéro
      xi1 := Trunc(Single(x1 + 8.5));

      // Clampage strict [0, 15]
      if xi0 > 15 then
        xi0 := 15
      else if xi0 < 0 then
        xi0 := 0;
      if xi1 > 15 then
        xi1 := 15
      else if xi1 < 0 then
        xi1 := 0;

      // Packing : poids bas en bits 0-3, poids haut en bits 4-7
      pBlock^.qs[j] := Byte(xi0) or (Byte(xi1) shl 4);
    end;
    Inc(pBlock);
  end;
end;

procedure QuantQ4_0_Impl(const src: PSingle; Dest: PByte; n_row: Integer; quant_weights: PSingle = nil);
var
  nb, ib, j: Integer;
  sum_x2, sigma2, D: Single;
  pBlock: PBlockQ4_0;
  weight: array [0 .. QK4_0 - 1] of Single;
  L: array [0 .. QK4_0 - 1] of ShortInt;
begin
  // 1. Calcul de la variance globale σ² = ∑x² / N (utilisée pour pondérer les poids RMSE)
  sum_x2 := 0.0;
  for j := 0 to n_row - 1 do
    sum_x2 := sum_x2 + Sqr(src[j]);
  sigma2 := sum_x2 / n_row;

  nb := n_row div QK4_0;
  pBlock := PBlockQ4_0(Dest);

  for ib := 0 to nb - 1 do
  begin
    // 2. Calcul des poids d'optimisation RMSE
    for j := 0 to QK4_0 - 1 do
    begin
      if quant_weights <> nil then
        // Poids externes : qw * √(σ² + x²)
        weight[j] := quant_weights[ib * QK4_0 + j] * Sqrt(sigma2 + Sqr(src[ib * QK4_0 + j]))
      else
        // Poids internes : √(σ²) + |x| (variance locale)
        weight[j] := Sqrt(sigma2) + Abs(src[ib * QK4_0 + j]);
    end;

    // 3. Optimisation de l'échelle d via MakeQxQuants (rmse_type=1 → pondération x²)
    D := MakeQxQuants(QK4_0, 8, @src[ib * QK4_0], @L[0], 1, @weight[0]);
    pBlock^.D := FP32ToFP16o(D);

    // 4. Packing des poids optimisés L (déjà décalés de +8 par MakeQxQuants)
    for j := 0 to 15 do
      pBlock^.qs[j] := Byte(L[j]) or (Byte(L[j + 16]) shl 4);

    Inc(pBlock);
  end;
end;

// ============================================================================
procedure DequantQ4_1(const Data: PByte; Dest: PSingle; n_row: Integer);
var
  nb, i, j: Integer;
  B: PByte;
  D, m: Single;
  v0, v1: Integer;
begin
  nb := n_row div QK4_1;
  B := Data;
  for i := 0 to nb - 1 do
  begin
    // 1. Lecture de l'échelle d et du minimum m (FP16 → FP32)
    D := FP16ToFP32o(PWord(B)^);
    Inc(B, 2);
    m := FP16ToFP32o(PWord(B)^);
    Inc(B, 2);

    // 2. Dé-packing et déquantisation : x = d * q + m
    for j := 0 to (QK4_1 div 2) - 1 do
    begin
      v0 := B[j] and $0F;
      v1 := B[j] shr 4;
      Dest[i * QK4_1 + j] := v0 * D + m;
      Dest[i * QK4_1 + j + (QK4_1 div 2)] := v1 * D + m;
    end;
    Inc(B, 16);
  end;
end;

procedure QuantQ4_1_Ref(const src: PSingle; Dest: PByte; n_row: Integer);
var
  nb, i, j: Integer;
  pBlock: PBlockQ4_1;
  minVal, maxVal, D, id, x0, x1: Single;
  xi0, xi1: Integer;
begin
  nb := n_row div QK4_1;
  pBlock := PBlockQ4_1(Dest);

  for i := 0 to nb - 1 do
  begin
    minVal := 3.402823466E+38;
    maxVal := -3.402823466E+38;

    // 1. Recherche min/max du bloc
    for j := 0 to QK4_1 - 1 do
    begin
      if src[i * QK4_1 + j] < minVal then
        minVal := src[i * QK4_1 + j];
      if src[i * QK4_1 + j] > maxVal then
        maxVal := src[i * QK4_1 + j];
    end;

    // 2. Calcul de l'échelle : d = (max - min) / 15
    D := Single((maxVal - minVal) / 15.0);
    if D <> 0.0 then
      id := Single(1.0 / D)
    else
      id := 0.0;

    pBlock^.D := FP32ToFP16o(D);
    pBlock^.m := FP32ToFP16o(minVal);

    // 3. Quantification : x = (src - min) * id, arrondi à +0.5
    for j := 0 to (QK4_1 div 2) - 1 do
    begin
      x0 := Single((src[i * QK4_1 + j] - minVal) * id);
      x1 := Single((src[i * QK4_1 + (QK4_1 div 2) + j] - minVal) * id);
      xi0 := Trunc(Single(x0 + 0.5));
      xi1 := Trunc(Single(x1 + 0.5));

      if xi0 > 15 then
        xi0 := 15
      else if xi0 < 0 then
        xi0 := 0;
      if xi1 > 15 then
        xi1 := 15
      else if xi1 < 0 then
        xi1 := 0;

      pBlock^.qs[j] := Byte(xi0) or (Byte(xi1) shl 4);
    end;
    Inc(pBlock);
  end;
end;

procedure QuantQ4_1_Impl(const src: PSingle; Dest: PByte; n_row: Integer; quant_weights: PSingle = nil);
var
  nb, ib, j: Integer;
  sum_x2, sigma2, D, min_val: Single;
  av_x: Single;
  pBlock: PBlockQ4_1;
  weight: array [0 .. QK4_1 - 1] of Single;
  L, Laux: array [0 .. QK4_1 - 1] of Byte;
begin
  // 1. Variance globale et racine carrée
  sum_x2 := 0.0;
  for j := 0 to n_row - 1 do
    sum_x2 := sum_x2 + Sqr(src[j]);
  sigma2 := sum_x2 / n_row;
  av_x := Sqrt(sigma2);

  nb := n_row div QK4_1;
  pBlock := PBlockQ4_1(Dest);

  for ib := 0 to nb - 1 do
  begin
    // 2. Calcul des poids RMSE
    for j := 0 to QK4_1 - 1 do
    begin
      if quant_weights <> nil then
        weight[j] := quant_weights[ib * QK4_1 + j] * Sqrt(sigma2 + Sqr(src[ib * QK4_1 + j]))
      else
        weight[j] := av_x + Abs(src[ib * QK4_1 + j]);
    end;

    // 3. Optimisation conjointe Scale + Min via MakeQkx2Quants
    // rmin=-0.9, rdelta=0.05, nstep=36 → grille fine pour minimiser MSE
    D := MakeQkx2Quants(QK4_1, 15, @src[ib * QK4_1], @weight[0], @L[0], min_val, @Laux[0], -0.9, 0.05, 36, False);
    pBlock^.D := FP32ToFP16o(D);
    pBlock^.m := FP32ToFP16o(-min_val); // GGML stocke -min pour éviter les nombres négatifs

    for j := 0 to 15 do
      pBlock^.qs[j] := L[j] or (L[j + 16] shl 4);

    Inc(pBlock);
  end;
end;

// ============================================================================
procedure DequantQ5_0(const Data: PByte; Dest: PSingle; n_row: Integer);
var
  nb, i, j: Integer;
  Block: PBlockQ5_0;
  D: Single;
  qh: Cardinal;
  xh_0, xh_1, x0, x1: Integer;
begin
  nb := n_row div QK5_0;
  Block := PBlockQ5_0(Data);
  for i := 0 to nb - 1 do
  begin
    D := FP16ToFP32o(Block.D);
    qh := Block.qh; // Lecture du masque 32-bit contenant les 5èmes bits

    for j := 0 to 15 do
    begin
      // Extraction du bit 4 (valeur 16) pour les 16 premiers et seconds poids
      xh_0 := ((qh shr j) shl 4) and $10;
      xh_1 := ((qh shr (j + 16)) shl 4) and $10;

      // Reconstruction : q ∈ [0, 31], décalage -16 → [-16, 15]
      x0 := ((Block.qs[j] and $0F) or xh_0) - 16;
      x1 := ((Block.qs[j] shr 4) or xh_1) - 16;

      Dest[i * QK5_0 + j] := x0 * D;
      Dest[i * QK5_0 + j + 16] := x1 * D;
    end;
    Inc(Block);
  end;
end;

procedure QuantQ5_0_Ref(const src: PSingle; Dest: PByte; n_row: Integer);
var
  nb, i, j: Integer;
  pBlock: PBlockQ5_0;
  amax, maxVal, D, id: Single;
  xi0, xi1: Integer;
  qh: UInt32;
begin
  nb := n_row div 32;
  pBlock := PBlockQ5_0(Dest);

  for i := 0 to nb - 1 do
  begin
    amax := 0.0;
    maxVal := 0.0;
    for j := 0 to 31 do
    begin
      if Abs(src[i * 32 + j]) > amax then
      begin
        amax := Abs(src[i * 32 + j]);
        maxVal := src[i * 32 + j];
      end;
    end;

    // Échelle : d = max_signed / -16
    D := maxVal / -16.0;
    if D <> 0 then
      id := 1.0 / D
    else
      id := 0.0;

    pBlock^.D := FP32ToFP16o(D);
    FillChar(pBlock^.qs, SizeOf(pBlock^.qs), 0);
    qh := 0;

    for j := 0 to 15 do
    begin
      // Quantification avec offset +16.5 (simule (int8_t)(x*id + 16.5f))
      xi0 := Trunc(Single(src[i * 32 + j] * id + 16.5));
      xi1 := Trunc(Single(src[i * 32 + j + 16] * id + 16.5));

      // Clamp [0, 31]
      if xi0 < 0 then
        xi0 := 0
      else if xi0 > 31 then
        xi0 := 31;
      if xi1 < 0 then
        xi1 := 0
      else if xi1 > 31 then
        xi1 := 31;

      // Packing bits 0-3
      pBlock^.qs[j] := Byte(xi0 and $0F) or (Byte(xi1 and $0F) shl 4);

      // Extraction bit 4 pour qh
      if (xi0 and $10) <> 0 then
        qh := qh or (UInt32(1) shl j);
      if (xi1 and $10) <> 0 then
        qh := qh or (UInt32(1) shl (j + 16));
    end;
    pBlock^.qh := qh;
    Inc(pBlock);
  end;
end;

procedure QuantQ5_0_Impl(const src: PSingle; Dest: PByte; n_row: Integer; quant_weights: PSingle = nil);
var
  nb, ib, j: Integer;
  sum_x2, sigma2, D, av_x: Single;
  pBlock: PBlockQ5_0;
  weight: array [0 .. QK5_0 - 1] of Single;
  L: array [0 .. QK5_0 - 1] of ShortInt;
  qh: Cardinal;
begin
  sum_x2 := 0.0;
  for j := 0 to n_row - 1 do
    sum_x2 := sum_x2 + Sqr(src[j]);
  sigma2 := sum_x2 / n_row;
  av_x := Sqrt(sigma2);

  nb := n_row div QK5_0;
  pBlock := PBlockQ5_0(Dest);

  for ib := 0 to nb - 1 do
  begin
    // Calcul des poids RMSE
    for j := 0 to QK5_0 - 1 do
    begin
      if quant_weights <> nil then
        weight[j] := quant_weights[ib * QK5_0 + j] * Sqrt(sigma2 + Sqr(src[ib * QK5_0 + j]))
      else
        weight[j] := av_x + Abs(src[ib * QK5_0 + j]);
    end;

    // Optimisation scale avec MakeQxQuants (rmse_type=1)
    D := MakeQxQuants(QK5_0, 16, @src[ib * QK5_0], @L[0], 1, @weight[0]);
    pBlock^.D := FP32ToFP16o(D);

    qh := 0;
    for j := 0 to 15 do
    begin
      pBlock^.qs[j] := Byte(L[j] and $0F) or (Byte(L[j + 16] and $0F) shl 4);
      if (L[j] and $10) <> 0 then
        qh := qh or (Cardinal(1) shl j);
      if (L[j + 16] and $10) <> 0 then
        qh := qh or (Cardinal(1) shl (j + 16));
    end;
    pBlock^.qh := qh;
    Inc(pBlock);
  end;
end;

// ============================================================================
procedure DequantQ5_1(const Data: PByte; Dest: PSingle; n_row: Integer);
var
  nb, i, j: Integer;
  Block: PBlockQ5_1;
  D, m: Single;
  qh: Cardinal;
  xh_0, xh_1, x0, x1: Integer;
begin
  nb := n_row div QK5_1;
  Block := PBlockQ5_1(Data);
  for i := 0 to nb - 1 do
  begin
    D := FP16ToFP32o(Block.D);
    m := FP16ToFP32o(Block.m);
    qh := Block.qh;

    for j := 0 to 15 do
    begin
      xh_0 := ((qh shr j) shl 4) and $10;
      xh_1 := ((qh shr (j + 16)) shl 4) and $10;
      x0 := (Block.qs[j] and $0F) or xh_0;
      x1 := (Block.qs[j] shr 4) or xh_1;
      Dest[i * QK5_1 + j] := x0 * D + m;
      Dest[i * QK5_1 + j + 16] := x1 * D + m;
    end;
    Inc(Block);
  end;
end;

procedure QuantQ5_1_Ref(const src: PSingle; Dest: PByte; n_row: Integer);
var
  nb, i, j: Integer;
  pBlock: PBlockQ5_1;
  minVal, maxVal, D, id, x0, x1, a_val: Single;
  xi0, xi1: Integer;
  qh: UInt32;
begin
  nb := n_row div 32;
  pBlock := PBlockQ5_1(Dest);

  for i := 0 to nb - 1 do
  begin
    minVal := 1.0;
    maxVal := -1.0;
    for j := 0 to 31 do
    begin
      a_val := (src[i * 32 + j]);
      if a_val < minVal then
        minVal := a_val;
      if a_val > maxVal then
        maxVal := a_val;
    end;

    D := Single((maxVal - minVal) / 31.0);
    id := 0.0;
    if D <> 0.0 then
      id := Single(1.0 / D);

    pBlock^.D := FP32ToFP16o(D);
    pBlock^.m := FP32ToFP16o(minVal);
    FillChar(pBlock^.qs, SizeOf(pBlock^.qs), 0);
    qh := 0;

    for j := 0 to 15 do
    begin
      x0 := Single((src[i * 32 + j] - minVal) * id);
      x1 := Single((src[i * 32 + (j + 16)] - minVal) * id);
      xi0 := Trunc(Single(x0 + 0.5));
      xi1 := Trunc(Single(x1 + 0.5));

      if xi0 > 31 then
        xi0 := 31
      else if xi0 < 0 then
        xi0 := 0;
      if xi1 > 31 then
        xi1 := 31
      else if xi1 < 0 then
        xi1 := 0;

      pBlock^.qs[j] := Byte(xi0 and $0F) or (Byte(xi1 and $0F) shl 4);
      if (xi0 and $10) <> 0 then
        qh := qh or (UInt32(1) shl j);
      if (xi1 and $10) <> 0 then
        qh := qh or (UInt32(1) shl (j + 16));
    end;
    pBlock^.qh := qh;
    Inc(pBlock);
  end;
end;

procedure QuantQ5_1_Impl(const src: PSingle; Dest: PByte; n_row: Integer; quant_weights: PSingle = nil);
var
  nb, i, j: Integer;
  pBlock: PBlockQ5_1;
  sum_x2, sigma2, D, min_val: Single;
  weight: array [0 .. 31] of Single;
  L, Laux: array [0 .. 31] of Byte;
  qh: Cardinal;
  xi0, xi1: Byte;
begin
  nb := n_row div 32;
  pBlock := PBlockQ5_1(Dest);

  for i := 0 to nb - 1 do
  begin
    sum_x2 := 0.0;
    for j := 0 to 31 do
      sum_x2 := sum_x2 + Sqr(src[j]);
    sigma2 := sum_x2 / 32;
    for j := 0 to 31 do
    begin
      if Assigned(quant_weights) then
        weight[j] := quant_weights[i * 32 + j] * Sqrt(sigma2 + Sqr(src[i * 32 + j]))
      else
        weight[j] := Sqrt(sigma2 + Sqr(src[i * 32 + j]));
    end;

    // Optimisation conjointe Scale + Min (rmse_type=-1 via MakeQkx2Quants)
    D := MakeQkx2Quants(32, 31, @src[i * 32], @weight[0], @L[0], min_val, @Laux[0], -0.9, 0.05, 8, False);

    pBlock.D := FP32ToFP16o(D);
    pBlock.m := FP32ToFP16o(-min_val);

    qh := 0;
    for j := 0 to 15 do
    begin
      xi0 := L[j];
      xi1 := L[j + 16];
      pBlock.qs[j] := (xi0 and $0F) or ((xi1 and $0F) shl 4);
      qh := qh or (Cardinal((xi0 and $10) shr 4) shl j);
      qh := qh or (Cardinal((xi1 and $10) shr 4) shl (j + 16));
    end;
    pBlock.qh := qh;
    Inc(pBlock);
  end;
end;

// ============================================================================
procedure DequantQ8_0(const Data: PByte; Dest: PSingle; n_row: Integer);
var
  nb, i, j: Integer;
  pBlock: PBlockQ8_0;
  D: Single;
begin
  nb := n_row div QK8_0;
  pBlock := PBlockQ8_0(Data);
  for i := 0 to nb - 1 do
  begin
    D := FP16ToFP32o(pBlock^.D);
    for j := 0 to 31 do
      Dest[i * QK8_0 + j] := pBlock^.qs[j] * D; // x = d * q
    Inc(pBlock);
  end;
end;

procedure QuantQ8_0(const src: PSingle; Dest: PByte; n_row: Integer);
var
  nb, i, j: Integer;
  B: PByte;
  D, id, amax: Single;
  V: Integer;
begin
  nb := n_row div QK8_0;
  B := Dest;
  for i := 0 to nb - 1 do
  begin
    amax := 0.0;
    for j := 0 to QK8_0 - 1 do
      if Abs(src[i * QK8_0 + j]) > amax then
        amax := Abs(src[i * QK8_0 + j]);

    D := amax / 127.0;
    id := 0.0;
    if D <> 0 then
      id := 1.0 / D;

    PWord(B)^ := FP32ToFP16o(D);
    Inc(B, 2);

    for j := 0 to QK8_0 - 1 do
    begin
      V := NearestInt(src[i * QK8_0 + j] * id);
      // Note : GGML standard autorise -128. Ce code clamp à -127 pour compatibilité avec certains modèles.
      PShortInt(B + j)^ := Max(-127, Min(127, V));
    end;
    Inc(B, 32);
  end;
end;

procedure QuantQ8_0_Ref(const src: PSingle; Dest: PByte; n_row: Integer);
var
  nb, i, j: Integer;
  pBlock: PBlockQ8_0;
  amax, maxVal, D, id: Single;
  Val: Integer;
begin
  nb := n_row div QK8_0;
  pBlock := PBlockQ8_0(Dest);

  for i := 0 to nb - 1 do
  begin
    amax := 0.0;
    maxVal := 0.0;
    for j := 0 to QK8_0 - 1 do
    begin
      if Abs(src[i * QK8_0 + j]) > amax then
      begin
        amax := Abs(src[i * QK8_0 + j]);
        maxVal := src[i * QK8_0 + j];
      end;
    end;

    D := amax / 127.0;
    if D <> 0 then
      id := 1.0 / D
    else
      id := 0.0;
    pBlock^.D := FP32ToFP16o(D);

    for j := 0 to QK8_0 - 1 do
    begin
      Val := NearestInt(src[i * QK8_0 + j] * id);
      if Val > 127 then
        Val := 127
      else if Val < -128 then
        Val := -128;
      PShortInt(PByte(@pBlock^.qs[j]))^ := Val;
    end;
    Inc(pBlock);
  end;
end;

procedure DequantQ8_1(const Data: PByte; Dest: PSingle; n_row: Integer);
var
  nb, i, j: Integer;
  pBlock: PBlockQ8_1;
  D, s: Single;
begin
  nb := n_row div QK8_1;
  pBlock := PBlockQ8_1(Data);

  for i := 0 to nb - 1 do
  begin
    D := FP16ToFP32o(pBlock^.D);
    s := FP16ToFP32o(pBlock^.s); // s = d * Σq
    for j := 0 to 31 do
      Dest[i * QK8_1 + j] := (pBlock^.qs[j] * D) + s;
    Inc(pBlock);
  end;
end;

procedure QuantQ8_1_Ref(const src: PSingle; Dest: PByte; n_row: Integer);
var
  nb, i, j: Integer;
  pBlock: PBlockQ8_1;
  minVal, maxVal, D, id, sum: Single;
  Val: Integer;
begin
  nb := n_row div QK8_1;
  pBlock := PBlockQ8_1(Dest);

  for i := 0 to nb - 1 do
  begin
    minVal := 3.402823466E+38;
    maxVal := -3.402823466E+38;
    for j := 0 to QK8_1 - 1 do
    begin
      if src[i * QK8_1 + j] < minVal then
        minVal := src[i * QK8_1 + j];
      if src[i * QK8_1 + j] > maxVal then
        maxVal := src[i * QK8_1 + j];
    end;

    D := (maxVal - minVal) / 127.0;
    if D <> 0 then
      id := 1.0 / D
    else
      id := 0.0;

    pBlock^.D := FP32ToFP16o(D);
    sum := 0.0;

    for j := 0 to QK8_1 - 1 do
    begin
      Val := NearestInt((src[i * QK8_1 + j] - minVal) * id);
      if Val > 127 then
        Val := 127
      else if Val < -128 then
        Val := -128;
      PShortInt(PByte(@pBlock^.qs[j]))^ := Val;
      sum := sum + Val;
    end;

    // Stockage de s = d * Σq (compensateur de biais)
    pBlock^.s := FP32ToFP16o(sum * D);
    Inc(pBlock);
  end;
end;

procedure DequantF16(const Data: PByte; Dest: PSingle; n_row: Integer);
var
  i: Integer;
begin
  for i := 0 to n_row - 1 do
    Dest[i] := FP16ToFP32o(PWord(Data + (i * 2))^);
end;

procedure QuantF16(const src: PSingle; Dest: PByte; n_row: Integer);
var
  i: Integer;
begin
  for i := 0 to n_row - 1 do
    PWord(Dest + (i * 2))^ := FP32ToFP16o(src[i]);
end;

procedure DequantBF16(const Data: PByte; Dest: PSingle; n_row: Integer);
var
  i: Integer;
begin
  for i := 0 to n_row - 1 do
    Dest[i] := BF16ToFP32o(PWord(Data + (i * 2))^);
end;

procedure QuantBF16(const src: PSingle; Dest: PByte; n_row: Integer);
var
  i: Integer;
begin
  for i := 0 to n_row - 1 do
    PWord(Dest + (i * 2))^ := FP32ToBF16o(src[i]);
end;

// ============================================================================
procedure DeQuant(const Data: PByte; Dest: PSingle; n_row, SrcType: Integer; UseDLL: Boolean = False);
var
  Proc: TDequantProc;
begin
  // 1. Tentative d'appel DLL optimisée (Si activée et type supporté)
  if UseDLL and (SrcType <> GGML_TYPE_F32) and (SrcType <> GGML_TYPE_F16) and (SrcType <> GGML_TYPE_BF16) and
    (SrcType < GGMLTypeCountDLL) then
  begin
    Proc := GetDequantProc(SrcType);
    if Assigned(Proc) then
    begin
      Proc(Data, Dest, n_row);
      Exit; // Succès, on sort prématurément
    end;
  end;

  // 2. Fallback natif Delphi selon le type GGML
  case SrcType of
    GGML_TYPE_F32:
      Move(Data^, Dest^, n_row * SizeOf(Single));
    GGML_TYPE_F16:
      DequantF16(Data, Dest, n_row);
    GGML_TYPE_BF16:
      DequantBF16(Data, Dest, n_row);
    GGML_TYPE_Q4_0:
      DequantQ4_0(Data, Dest, n_row);
    GGML_TYPE_Q4_1:
      DequantQ4_1(Data, Dest, n_row);
    GGML_TYPE_Q5_0:
      DequantQ5_0(Data, Dest, n_row);
    GGML_TYPE_Q5_1:
      DequantQ5_1(Data, Dest, n_row);
    GGML_TYPE_Q8_0:
      DequantQ8_0(Data, Dest, n_row);
    GGML_TYPE_Q8_1:
      DequantQ8_1(Data, Dest, n_row);
    GGML_TYPE_Q3_K:
      DequantQ3_K(Data, Dest, n_row);
    GGML_TYPE_Q4_K:
      DequantQ4_K(Data, Dest, n_row);
    GGML_TYPE_Q5_K:
      DequantQ5_K(Data, Dest, n_row);
    GGML_TYPE_Q6_K:
      DequantQ6_K(Data, Dest, n_row);
    GGML_TYPE_I8:
      DequantI8(Data, Dest, n_row);
    GGML_TYPE_I16:
      DequantI16(Data, Dest, n_row);
    GGML_TYPE_I32:
      DequantI32(Data, Dest, n_row);
    GGML_TYPE_I64:
      DequantI64(Data, Dest, n_row);
    GGML_TYPE_F64:
      DequantF64(Data, Dest, n_row);
  else
    // Types FP8 / futurs formats (NVFP4, etc.)
    if SrcType = GGML_TYPE_F8_E4M3 then
      DequantFP8_E4M3(Data, Dest, n_row)
    else if SrcType = GGML_TYPE_F8_E5M2 then
      DequantFP8_E5M2(Data, Dest, n_row)
    else if SrcType = GGML_TYPE_F8_E4M3FN then
      DequantFP8_E4M3(Data, Dest, n_row)
    else if SrcType = GGML_TYPE_F8_E5M2FN then
      DequantFP8_E5M2(Data, Dest, n_row)
    else
      raise Exception.CreateFmt('Déquantisation non disponible pour type : %d (%s)', [SrcType, GGMLTypeToStr(SrcType)]);
  end;
end;

procedure Quant(const src: PSingle; Dest: PByte; n_row, DstType: Integer; UseDLL: Boolean = False);
var
  Proc: TQuantProc;
begin
  // 1. Tentative DLL si activée
  if UseDLL and (DstType <> GGML_TYPE_F32) and (DstType <> GGML_TYPE_F16) and (DstType <> GGML_TYPE_BF16) and
    (DstType < GGMLTypeCountDLL) then
  begin
    Proc := GetQuantProc(DstType);
    if Assigned(Proc) then
    begin
      try
        if DstType in [GGML_TYPE_IQ2_XXS, GGML_TYPE_IQ2_XS, GGML_TYPE_IQ3_XXS, GGML_TYPE_IQ3_S, GGML_TYPE_IQ2_S] then
          raise Exception.CreateFmt('Quantisation non disponible pour type : %d (%s)',
            [DstType, GGMLTypeToStr(DstType)])
        else
          Proc(src, Dest, 1, n_row, nil); // Signature DLL : (src, dst, row, cols, weights)
        Exit;
      except
        on E: Exception do
        begin
          LogMsg('ERREUR DLL Quant: ' + E.Message);
          raise Exception.Create('ERREUR DLL Quant: ' + E.Message);
        end;
      end;
      Exit
    end;
  end;

  // 2. Fallback natif : choix entre Ref (déterministe) et Impl (RMSE)
  case DstType of
    GGML_TYPE_F32:
      Move(src^, Dest^, n_row * SizeOf(Single));
    GGML_TYPE_F16:
      QuantF16(src, Dest, n_row);
    GGML_TYPE_BF16:
      QuantBF16(src, Dest, n_row);

    GGML_TYPE_Q4_0:
      if cfg.UseFImpl then
        QuantQ4_0_Impl(src, Dest, n_row)
      else
        QuantQ4_0_Ref(src, Dest, n_row);
    GGML_TYPE_Q4_1:
      if cfg.UseFImpl then
        QuantQ4_1_Impl(src, Dest, n_row)
      else
        QuantQ4_1_Ref(src, Dest, n_row);
    GGML_TYPE_Q5_0:
      if cfg.UseFImpl then
        QuantQ5_0_Impl(src, Dest, n_row)
      else
        QuantQ5_0_Ref(src, Dest, n_row);
    GGML_TYPE_Q5_1:
      if cfg.UseFImpl then
        QuantQ5_1_Impl(src, Dest, n_row)
      else
        QuantQ5_1_Ref(src, Dest, n_row);
    GGML_TYPE_Q8_0:
      if cfg.UseFImpl then
        QuantQ8_0_Ref(src, Dest, n_row)
      else
        QuantQ8_0(src, Dest, n_row);

    GGML_TYPE_Q8_1:
      QuantQ8_1_Ref(src, Dest, n_row);

    GGML_TYPE_Q3_K:
      if cfg.UseFImpl then
        QuantQ3_K_Impl(src, Dest, n_row)
      else
        QuantQ3_K_Ref(src, Dest, n_row);

    GGML_TYPE_Q4_K:
      if cfg.UseFImpl then
        QuantQ4_K_Impl(src, Dest, n_row)
      else
        QuantQ4_K_Ref(src, Dest, n_row);

    GGML_TYPE_Q5_K:
      if cfg.UseFImpl then
        QuantQ5_K_Impl(src, Dest, n_row)
      else
        QuantQ5_K_Ref(src, Dest, n_row);

    GGML_TYPE_Q6_K:
      if cfg.UseFImpl then
        QuantQ6_K_Impl(src, Dest, n_row)
      else
        QuantQ6_K_Ref(src, Dest, n_row);

    GGML_TYPE_I8:
      QuantI8(src, Dest, n_row);
    GGML_TYPE_I16:
      QuantI16(src, Dest, n_row);
    GGML_TYPE_I32:
      QuantI32(src, Dest, n_row);
    GGML_TYPE_I64:
      QuantI64(src, Dest, n_row);
    GGML_TYPE_F64:
      QuantF64(src, Dest, n_row);
  else
    if DstType = GGML_TYPE_F8_E4M3 then
      QuantFP8_E4M3(src, Dest, n_row)
    else if DstType = GGML_TYPE_F8_E5M2 then
      QuantFP8_E5M2(src, Dest, n_row)
    else if DstType = GGML_TYPE_F8_E4M3FN then
      QuantFP8_E4M3(src, Dest, n_row)
    else if DstType = GGML_TYPE_F8_E5M2FN then
      QuantFP8_E5M2(src, Dest, n_row)
    else
      raise Exception.CreateFmt('Quantisation non disponible pour type : %d (%s)', [DstType, GGMLTypeToStr(DstType)]);
  end;
end;

// ============================================================================
function ConvertTensorData(const SrcData: TBytes; SrcType, DstType: Integer; Rows, Cols: Int64; out DstData: TBytes;
  UseDLL: Boolean = True; OnProgress: TOnProgressEvent1 = nil): Boolean;
var
  F32Row: array of Single;
  SrcPtr, DstPtr: PByte;
  i: Integer;
  SrcRowBytes, DstRowBytes: Int64;
begin
  Result := False;
  if (Rows <= 0) or (Cols <= 0) or (Length(SrcData) = 0) then
    Exit;

  // 1. Calcul des tailles de ligne selon type source/destination
  if UseDLL and Assigned(GetRowSizeFunc) then
  begin
    SrcRowBytes := GetRowSizeFunc(SrcType, Cols);
    DstRowBytes := GetRowSizeFunc(DstType, Cols);
  end
  else
  begin
    SrcRowBytes := GGML_RowSize(SrcType, Cols);
    DstRowBytes := GGML_RowSize(DstType, Cols);
  end;

  if Int64(Length(SrcData)) < (Rows * SrcRowBytes) then
    // raise Exception.Create('Taille du buffer source insuffisante.');
    raise Exception.Create('Source buffer size insufficient.');

  SetLength(F32Row, Cols);
  SetLength(DstData, Rows * DstRowBytes);

  SrcPtr := @SrcData[0];
  DstPtr := @DstData[0];

  try
    // 2. Boucle ligne par ligne : Déquantiser → Quantiser
    for i := 0 to Rows - 1 do
    begin
      DeQuant(SrcPtr, System.PSingle(F32Row), Cols, SrcType, UseDLL);
      Quant(System.PSingle(F32Row), DstPtr, Cols, DstType, UseDLL);

      Inc(SrcPtr, SrcRowBytes);
      Inc(DstPtr, DstRowBytes);

      // 3. Callback de progression (évite les appels trop fréquents)
      if Assigned(OnProgress) then
      begin
        if (i mod 200 = 0) or (i = Rows - 1) then
          OnProgress(Format('Traitement : %d / %d lignes', [i + 1, Rows]), i + 1, Rows);
      end;
    end;
    Result := True;
  except
    on E: Exception do
    begin
      SetLength(DstData, 0);
      if Assigned(OnProgress) then
        // OnProgress('Erreur : ' + E.Message, 0, 1);
        OnProgress('Error: ' + E.Message, 0, 1);
      raise; // Propage l'exception avec stack trace intacte
    end;
  end;
end;

end.
