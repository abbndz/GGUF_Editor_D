unit uGgmlQuantsQ6K;

interface

uses
  SysUtils, Classes, uGGMLTypes, uGGMLConstants, uMath;

{$B-} // active les checks de performance. Les indices sont validés par les structures GGML.
{$R-}  // Désactive les range checks pour éviter les surcoûts dans les boucles critiques

{$POINTERMATH ON}   // PByte + 2 = adresse + 2 octets (C-compatible)
{$J-}               // Désactive les checks de bounds (indices validés par la logique GGML)
{$O+}               // Active les optimisations du compilateur (inline, loop unroll)
{$ALIGN 8}          // Alignement SSE2 optimal pour les Single

type
  EGGML = class(Exception);

  // ============================================================================
  // DÉCLARATIONS DES PROCEDURES Q5_K & Q6_K
  // ============================================================================
procedure DequantQ5_K(const Data: PByte; Dest: PSingle; n_row: Integer);
procedure QuantQ5_K_Fast(const src: PSingle; Dest: PByte; n_row: Integer);
procedure QuantQ5_K_Ref(const src: PSingle; Dest: PByte; n_row: Integer);
procedure QuantQ5_K_Impl(const src: PSingle; Dest: PByte; n_row: Integer; quant_weights: PSingle = nil);

procedure DequantQ6_K(const Data: PByte; Dest: PSingle; n_row: Integer);
procedure QuantQ6_K_Ref(const src: PSingle; Dest: PByte; n_row: Integer);
procedure QuantQ6_K_Impl(const src: PSingle; Dest: PByte; n_row: Integer; quant_weights: PSingle = nil);

implementation

uses uGgmlQuants, uGGMLQuantUtils;

// ============================================================================
// DÉQUANTISATION Q5_K
// Format : 5.5 bits/poids. Super-bloc de 256 éléments.
// Structure : 8 sous-blocs de 32 éléments.
// Math : x = d * q - min, où q ∈ [0, 31] (5 bits).
// Les 5ème bits (bit 4) sont stockés dans un masque qh[32].
// Les échelles d et min sont quantifiées sur 6 bits et packées dans scales[12].
// ============================================================================
procedure DequantQ5_K(const Data: PByte; Dest: PSingle; n_row: Integer);
var
  nb, i, chunk, L, q_idx, is_idx, base: Integer;
  pBlock: PBlockQ5_K;
  d_all, min_all, d1, d2, min1, min2: Single;
  scales, mins: array [0 .. 7] of Byte;
  hm1, hm2: Integer;
  m1, m2: Word;
begin
  // 1. Découpage en super-blocs de 256 éléments
  nb := n_row div QK_K;
  pBlock := PBlockQ5_K(Data);

  for i := 0 to nb - 1 do
  begin
    // 2. Décompression des échelles globales FP16 -> FP32
    d_all := FP16ToFP32o(pBlock.D);
    min_all := FP16ToFP32o(pBlock.dmin);

    // 3. Dé-packing des 8 scales et 8 mins sur 6 bits depuis 12 octets
    // Logique identique à GetScaleMinK4 mais implémentée en ligne pour optimiser la mémoire cache
    for chunk := 0 to 3 do
    begin
      scales[chunk] := pBlock.scales[chunk] and $3F;
      mins[chunk] := pBlock.scales[chunk + 4] and $3F;
      scales[chunk + 4] := (pBlock.scales[chunk + 8] and $0F) or ((pBlock.scales[chunk] shr 6) shl 4);
      mins[chunk + 4] := (pBlock.scales[chunk + 8] shr 4) or ((pBlock.scales[chunk + 4] shr 6) shl 4);
    end;

    q_idx := 0;
    is_idx := 0;
    m1 := 1; // Masque pour les 5èmes bits des 16 premiers sous-blocs
    m2 := 2; // Masque pour les 5èmes bits des 16 seconds sous-blocs

    // 4. Traitement par chunk de 64 éléments (couvre 2 sous-blocs de 32)
    for chunk := 0 to 3 do
    begin
      // Scale & Min pour le sous-bloc A (éléments 0-31 du chunk)
      d1 := d_all * scales[is_idx];
      min1 := min_all * mins[is_idx];
      Inc(is_idx);
      // Scale & Min pour le sous-bloc B (éléments 32-63 du chunk)
      d2 := d_all * scales[is_idx];
      min2 := min_all * mins[is_idx];
      Inc(is_idx);

      base := i * QK_K + chunk * 64;

      // 5. Reconstruction des 32 poids pour chaque sous-bloc
      for L := 0 to 31 do
      begin
        // Extraction du 5ème bit (bit 4) du masque qh
        hm1 := 0;
        if (pBlock.qh[L] and m1) <> 0 then
          hm1 := 16;
        hm2 := 0;
        if (pBlock.qh[L] and m2) <> 0 then
          hm2 := 16;

        // x = d * (qs_low + qh_bit) - min
        Dest[base + L] := d1 * ((pBlock.qs[q_idx + L] and $0F) + hm1) - min1;
        Dest[base + L + 32] := d2 * ((pBlock.qs[q_idx + L] shr 4) + hm2) - min2;
      end;

      Inc(q_idx, 32);
      m1 := m1 shl 2; // Les masques qh avancent de 2 bits par chunk (layout GGML)
      m2 := m2 shl 2;
    end;
    Inc(pBlock);
  end;
end;

// ============================================================================
// QUANTISATION Q5_K (VERSION RÉFÉRENCE)
// ============================================================================
procedure QuantQ5_K_Fast(const src: PSingle; Dest: PByte; n_row: Integer);
var
  nb, i, j, chunk, L, base, q_idx, l1, l2: Integer;
  pBlock: PBlockQ5_K;
  lmin, lmax, max_scale, max_min, D, dmin, inv_scale, inv_min, dl, ml: Single;
  scales_f, mins_f: array [0 .. 7] of Single;
  SubBlockSc, SubBlockM: array [0 .. 7] of Byte;
  q_vals: array [0 .. 255] of Integer;
  m1, m2: Byte;
begin
  nb := n_row div QK_K;
  pBlock := PBlockQ5_K(Dest);

  for i := 0 to nb - 1 do
  begin
    max_scale := 0;
    max_min := 0;

    for j := 0 to 7 do
    begin
      lmin := src[i * QK_K + j * 32];
      lmax := lmin;
      for L := 1 to 31 do
      begin
        if src[i * QK_K + j * 32 + L] < lmin then
          lmin := src[i * QK_K + j * 32 + L];
        if src[i * QK_K + j * 32 + L] > lmax then
          lmax := src[i * QK_K + j * 32 + L];
      end;
      if lmin > 0 then
        lmin := 0;

      scales_f[j] := (lmax - lmin) / 31.0;
      mins_f[j] := -lmin;

      if scales_f[j] > max_scale then
        max_scale := scales_f[j];
      if mins_f[j] > max_min then
        max_min := mins_f[j];
    end;

    inv_scale := 0;
    if max_scale > 0 then
      inv_scale := 63.0 / max_scale;
    inv_min := 0;
    if max_min > 0 then
      inv_min := 63.0 / max_min;

    D := max_scale / 63.0;
    dmin := max_min / 63.0;
    pBlock.D := FP32ToFP16o(D);
    pBlock.dmin := FP32ToFP16o(dmin);

    FillChar(pBlock.scales[0], 12, 0);
    for j := 0 to 7 do
    begin
      // SubBlockSc[j] := Max(0, Min(63, CRound1(inv_scale * scales_f[j])));
      SubBlockSc[j] := ClampInt(NearestInt(inv_scale * scales_f[j]), 0, 63);
      // SubBlockM[j] := Max(0, Min(63, CRound1(inv_min * mins_f[j])));
      SubBlockM[j] := ClampInt(NearestInt(inv_min * mins_f[j]), 0, 63);
      if j < 4 then
      begin
        pBlock.scales[j] := SubBlockSc[j];
        pBlock.scales[j + 4] := SubBlockM[j];
      end
      else
      begin
        pBlock.scales[j + 4] := (SubBlockSc[j] and $0F) or ((SubBlockM[j] and $0F) shl 4);
        pBlock.scales[j - 4] := pBlock.scales[j - 4] or ((SubBlockSc[j] shr 4) shl 6);
        pBlock.scales[j] := pBlock.scales[j] or ((SubBlockM[j] shr 4) shl 6);
      end;
    end;

    for j := 0 to 7 do
    begin
      dl := D * SubBlockSc[j];
      ml := dmin * SubBlockM[j];
      for L := 0 to 31 do
      begin
        if dl <> 0 then
          // q_vals[j * 32 + L] := Max(0, Min(31, CRound1((src[i * QK_K + j * 32 + L] + ml) / dl)))
          q_vals[j * 32 + L] := ClampInt(NearestInt((src[i * QK_K + j * 32 + L] + ml) / dl), 0, 31)
        else
          q_vals[j * 32 + L] := 0;
      end;
    end;

    FillChar(pBlock.qh[0], 32, 0);
    q_idx := 0;
    m1 := 1;
    m2 := 2;

    for chunk := 0 to 3 do
    begin
      base := chunk * 64;
      for L := 0 to 31 do
      begin
        l1 := q_vals[base + L];
        if l1 > 15 then
        begin
          Dec(l1, 16);
          pBlock.qh[L] := pBlock.qh[L] or m1;
        end;

        l2 := q_vals[base + L + 32];
        if l2 > 15 then
        begin
          Dec(l2, 16);
          pBlock.qh[L] := pBlock.qh[L] or m2;
        end;

        pBlock.qs[q_idx + L] := Byte(l1) or (Byte(l2) shl 4);
      end;
      Inc(q_idx, 32);
      m1 := m1 shl 2;
      m2 := m2 shl 2;
    end;
    Inc(pBlock);
  end;
end;

// ============================================================================
// QUANTISATION Q5_K (VERSION RÉFÉRENCE)
// Algorithme déterministe sans optimisation RMSE.
// Suit strictement la logique C de quantize_row_q5_K_ref.
// ============================================================================
procedure QuantQ5_K_Ref(const src: PSingle; Dest: PByte; n_row: Integer);
var
  nb, i, j, L, ii, q_idx: Integer;
  pBlock: PBlockQ5_K;
  L_arr: array [0 .. 255] of Byte;
  Laux: array [0 .. 31] of Byte;
  weights: array [0 .. 31] of Single;
  mins, scales: array [0 .. 7] of Single;
  max_scale, max_min, inv_scale, inv_min: Single;
  ls, lm: Byte;
  m1, m2: Word;
  sum_x2, av_x: Single;
begin
  nb := n_row div QK_K;
  pBlock := PBlockQ5_K(Dest);

  for i := 0 to nb - 1 do
  begin
    max_scale := 0;
    max_min := 0;

    // 1. Optimisation scale + min par sous-bloc de 32 éléments
    for j := 0 to 7 do
    begin
      // Calcul de la moyenne racine carrée (√(∑x²/32))
      sum_x2 := 0;
      for L := 0 to 31 do
        sum_x2 := sum_x2 + src[i * QK_K + j * 32 + L] * src[i * QK_K + j * 32 + L];
      av_x := Sqrt(sum_x2 / 32);

      // Pondération : w = av_x + |x| (standard GGML Ref)
      for L := 0 to 31 do
        weights[L] := av_x + Abs(src[i * QK_K + j * 32 + L]);

      // Recherche d'échelle et min optimaux avec grille de recherche
      scales[j] := MakeQkx2Quants(32, 31, @src[i * QK_K + j * 32], @weights[0], @L_arr[j * 32], mins[j], @Laux[0], -0.5,
        0.1, 15, false);

      if scales[j] > max_scale then
        max_scale := scales[j];
      if mins[j] > max_min then
        max_min := mins[j];
    end;

    // 2. Calcul des inverses pour le packaging super-bloc (max 63)
    inv_scale := 0;
    if max_scale > 0 then
      inv_scale := 63.0 / max_scale;
    inv_min := 0;
    if max_min > 0 then
      inv_min := 63.0 / max_min;

    // 3. Packaging des 8 scales + 8 mins sur 12 octets (6 bits chacun)
    FillChar(pBlock.scales[0], 12, 0);
    for j := 0 to 7 do
    begin
      ls := NearestInt(inv_scale * scales[j]);
      lm := NearestInt(inv_min * mins[j]);
      if ls > 63 then
        ls := 63;
      if lm > 63 then
        lm := 63;

      if j < 4 then
      begin
        pBlock.scales[j] := ls;
        pBlock.scales[j + 4] := lm;
      end
      else
      begin
        pBlock.scales[j + 4] := (ls and $0F) or ((lm and $0F) shl 4);
        pBlock.scales[j - 4] := pBlock.scales[j - 4] or ((ls shr 4) shl 6);
        pBlock.scales[j] := pBlock.scales[j] or ((lm shr 4) shl 6);
      end;
    end;

    // 4. Packaging des paramètres globaux D et dmin en FP16
    pBlock.D := FP32ToFP16o(max_scale / 63.0);
    pBlock.dmin := FP32ToFP16o(max_min / 63.0);

    // 5. Requantification finale des poids avec les scales packés
    for j := 0 to 7 do
    begin
      GetScaleMinK4(j, @pBlock.scales[0], ls, lm);
      var
        dl: Single := FP16ToFP32o(pBlock.D) * ls;
      var
        dm: Single := FP16ToFP32o(pBlock.dmin) * lm;

      if Abs(dl) < GROUP_MAX_EPS then
        Continue;

      // x = dl * q - dm  =>  q = NearInt((x + dm) / dl)
      for ii := 0 to 31 do
        // L_arr[j * 32 + ii] := Max(0, Min(31, CRound1((src[i * QK_K + j * 32 + ii] + dm) / dl)));
        L_arr[j * 32 + ii] := ClampInt(NearestInt((src[i * QK_K + j * 32 + ii] + dm) / dl), 0, 31)
    end;

    // 6. Packaging final : qs (4 bits LSB) + qh (1 bit MSB)
    FillChar(pBlock.qh[0], 32, 0);
    m1 := 1;
    m2 := 2;
    q_idx := 0;

    for j := 0 to 3 do
    begin
      for L := 0 to 31 do
      begin
        var
          l1: Integer := L_arr[j * 64 + L];
        var
          l2: Integer := L_arr[j * 64 + L + 32];

        if l1 > 15 then
        begin
          Dec(l1, 16);
          pBlock.qh[L] := pBlock.qh[L] or m1;
        end;
        if l2 > 15 then
        begin
          Dec(l2, 16);
          pBlock.qh[L] := pBlock.qh[L] or m2;
        end;

        pBlock.qs[q_idx + L] := Byte(l1) or (Byte(l2) shl 4);
      end;
      Inc(q_idx, 32);
      m1 := m1 shl 2;
      m2 := m2 shl 2;
    end;

    Inc(pBlock);
  end;
end;

// ============================================================================
// QUANTISATION Q5_K (HAUTE QUALITÉ / RMSE)
// Utilise σ² ou des poids externes pour minimiser l'erreur quadratique moyenne.
// Correspond à quantize_row_q5_K_impl du C.
// ============================================================================
procedure QuantQ5_K_Impl(const src: PSingle; Dest: PByte; n_row: Integer; quant_weights: PSingle = nil);
var
  nb, i, j, L, chunk, base, q_idx, l1, l2: Integer;
  pBlock: PBlockQ5_K;
  L_arr: array [0 .. 255] of Byte;
  Laux: array [0 .. 31] of Byte;
  ls, lm: array [0 .. 7] of Byte;
  mins, scales, sw: array [0 .. 7] of Single;
  weights: array [0 .. 31] of Single;
  sum_x2, sigma2, av_x, sumw: Single;
  d_block, m_block, dl, ml: Single;
  ls_val, lm_val: Byte;
  m1, m2: Word;
begin
  nb := n_row div QK_K;
  pBlock := PBlockQ5_K(Dest);

  for i := 0 to nb - 1 do
  begin
    // 1. Calcul de la variance pondérée globale σ² = 2*∑x²/N
    sum_x2 := 0;
    for L := 0 to QK_K - 1 do
      sum_x2 := sum_x2 + Sqr(src[i * QK_K + L]);
    sigma2 := 2 * sum_x2 / QK_K;
    av_x := Sqrt(sigma2);

    // 2. Optimisation RMSE par sous-bloc de 32 éléments
    for j := 0 to 7 do
    begin
      if Assigned(quant_weights) then
        // Poids externes : qw * √(σ² + x²)
        for L := 0 to 31 do
          weights[L] := quant_weights[i * QK_K + 32 * j + L] * Sqrt(sigma2 + Sqr(src[i * QK_K + 32 * j + L]))
      else
        // Poids internes : √(σ²) + |x|
        for L := 0 to 31 do
          weights[L] := av_x + Abs(src[i * QK_K + 32 * j + L]);

      sumw := 0;
      for L := 0 to 31 do
        sumw := sumw + weights[L];
      sw[j] := sumw;

      // make_qkx2_quants avec paramètres RMSE Q5_K (-0.9, 0.05, 36)
      scales[j] := MakeQkx2Quants(32, 31, @src[i * QK_K + 32 * j], @weights[0], @L_arr[32 * j], mins[j], @Laux[0], -0.9,
        0.05, 36, false);
      // scales[j] := MakeQkx3Quants(32, 31, @src[i * QK_K + 32 * j], @weights[0], @L_arr[32 * j], mins[j], @Laux[0], -0.9, 0.05, 36, false);
      // rmin = -0.9 : décalage de la grille vers le bas (GGML Impl.)
      // rdelta = 0.05 : pas fin pour capturer les minima locaux
      // nstep = 36 : nombre de points de recherche (36 * 0.05 ≈ 1.8, couvre ±0.9 autour de la norme)
      // use_mad = false : utilise MSE pondéré (conforme au C)
    end;

    // 3. Optimisation des super-paramètres (échelles + mins du super-bloc)
    d_block := MakeQpQuants(8, 63, @scales[0], @sw[0], @ls[0]);
    m_block := MakeQpQuants(8, 63, @mins[0], @sw[0], @lm[0]);

    // 4. Packaging 6 bits des super-paramètres
    for j := 0 to 7 do
    begin
      ls_val := Min(63, ls[j]);
      lm_val := Min(63, lm[j]);
      if j < 4 then
      begin
        pBlock.scales[j] := ls_val;
        pBlock.scales[j + 4] := lm_val;
      end
      else
      begin
        pBlock.scales[j + 4] := (ls_val and $0F) or ((lm_val and $0F) shl 4);
        pBlock.scales[j - 4] := pBlock.scales[j - 4] or ((ls_val shr 4) shl 6);
        pBlock.scales[j] := pBlock.scales[j] or ((lm_val shr 4) shl 6);
      end;
    end;

    pBlock.D := FP32ToFP16o(d_block);
    pBlock.dmin := FP32ToFP16o(m_block);

    // 5. Requantification finale avec les paramètres FP16 packés
    for j := 0 to 7 do
    begin
      if j < 4 then
      begin
        ls_val := pBlock.scales[j] and $3F;
        lm_val := pBlock.scales[j + 4] and $3F;
      end
      else
      begin
        ls_val := (pBlock.scales[j + 4] and $0F) or ((pBlock.scales[j - 4] shr 6) shl 4);
        lm_val := (pBlock.scales[j + 4] shr 4) or ((pBlock.scales[j] shr 6) shl 4);
      end;

      dl := FP16ToFP32o(pBlock.D) * ls_val;
      if dl = 0 then
        Continue;
      ml := FP16ToFP32o(pBlock.dmin) * lm_val;

      for L := 0 to 31 do
        // L_arr[32 * j + L] := Max(0, Min(31, CRound1((src[i * QK_K + 32 * j + L] + ml) / dl)));
        L_arr[32 * j + L] := ClampInt(NearestInt((src[i * QK_K + 32 * j + L] + ml) / dl), 0, 31);
    end;

    // 6. Packaging final qs (4 bits) + qh (1 bit)
    FillChar(pBlock.qh[0], 32, 0);
    q_idx := 0;
    m1 := 1;
    m2 := 2;

    for chunk := 0 to 3 do
    begin
      base := chunk * 64;
      for L := 0 to 31 do
      begin
        l1 := L_arr[base + L];
        if l1 > 15 then
        begin
          Dec(l1, 16);
          pBlock.qh[L] := pBlock.qh[L] or m1;
        end;

        l2 := L_arr[base + L + 32];
        if l2 > 15 then
        begin
          Dec(l2, 16);
          pBlock.qh[L] := pBlock.qh[L] or m2;
        end;

        pBlock.qs[q_idx + L] := Byte(l1) or (Byte(l2) shl 4);
      end;
      Inc(q_idx, 32);
      m1 := m1 shl 2;
      m2 := m2 shl 2;
    end;

    Inc(pBlock);
  end;
end;

// ============================================================================
// DÉQUANTISATION Q6_K
// Format : 6.5625 bits/poids. Super-bloc de 256 éléments.
// Structure : 16 sous-blocs de 16 éléments.
// Math : x = d * q, où q ∈ [-32, 31] (6 bits signé).
// Les poids sont stockés sur 6 bits : ql (4 bits LSB) et qh (2 bits MSB).
// Les échelles sont quantifiées sur 8 bits signed [-128, 127].
// ============================================================================
procedure DequantQ6_K(const Data: PByte; Dest: PSingle; n_row: Integer);
var
  nb, i, n_chunk, L, is_idx, base: Integer;
  pBlock: PBlockQ6_K;
  d_all: Single;
  ql_idx, qh_idx: Integer;
  q1, q2, q3, q4: Integer;
  ql1, ql2, qh: Byte;
  sc1, sc2, sc3, sc4: Single;
begin
  nb := n_row div QK_K;
  pBlock := PBlockQ6_K(Data);

  for i := 0 to nb - 1 do
  begin
    d_all := FP16ToFP32o(pBlock.D);
    ql_idx := 0;
    qh_idx := 0;

    // 2 chunks de 128 éléments (couvre les 16 sous-blocs)
    for n_chunk := 0 to 1 do
    begin
      base := i * QK_K + n_chunk * 128;

      for L := 0 to 31 do
      begin
        is_idx := L div 16; // Index du sous-bloc dans le tableau scales[16]

        // Récupération des 4 échelles couvrant cette position L
        sc1 := d_all * pBlock.scales[n_chunk * 8 + is_idx];
        sc2 := d_all * pBlock.scales[n_chunk * 8 + is_idx + 2];
        sc3 := d_all * pBlock.scales[n_chunk * 8 + is_idx + 4];
        sc4 := d_all * pBlock.scales[n_chunk * 8 + is_idx + 6];

        ql1 := pBlock.ql[ql_idx + L];
        ql2 := pBlock.ql[ql_idx + 32 + L];
        qh := pBlock.qh[qh_idx + L];

        // Reconstruction des 4 valeurs 6-bit signed à partir de ql et qh
        q1 := Integer((ql1 and $0F) or ((qh and $03) shl 4)) - 32;
        q2 := Integer((ql2 and $0F) or (((qh shr 2) and $03) shl 4)) - 32;
        q3 := Integer(((ql1 shr 4) and $0F) or (((qh shr 4) and $03) shl 4)) - 32;
        q4 := Integer(((ql2 shr 4) and $0F) or (((qh shr 6) and $03) shl 4)) - 32;

        // Application de l'échelle : x = d * scale * q
        Dest[base + L] := sc1 * q1;
        Dest[base + L + 32] := sc2 * q2;
        Dest[base + L + 64] := sc3 * q3;
        Dest[base + L + 96] := sc4 * q4;
      end;

      Inc(ql_idx, 64); // ql avance de 64 octets par chunk
      Inc(qh_idx, 32); // qh avance de 32 octets par chunk
    end;
    Inc(pBlock);
  end;
end;

// ============================================================================
// QUANTISATION Q6_K (VERSION RÉFÉRENCE)
// Algorithme standard GGML (quantize_row_q6_K_ref).
// ============================================================================
procedure QuantQ6_K_Ref(const src: PSingle; Dest: PByte; n_row: Integer);
var
  nb, i, ib, j, L, offset_j: Integer;
  pBlock: PBlockQ6_K;
  max_scale, max_abs_scale, scale, abs_scale, iscale, sd, sub_scale: Single; // Double;
  scales_f: array [0 .. 15] of Single; // Double;
  LL: array [0 .. 255] of ShortInt;
  ql_idx, qh_idx, q1, q2, q3, q4: Integer;
begin
  nb := n_row div QK_K;
  pBlock := PBlockQ6_K(Dest);

  for i := 0 to nb - 1 do
  begin
    max_scale := 0.0;
    max_abs_scale := 0.0;

    // 1. Quantification initiale par sous-bloc de 16 éléments
    for ib := 0 to 15 do
    begin
      scale := MakeQxQuants(16, 32, @src[i * QK_K + ib * 16], @LL[ib * 16], 1, nil);
      scales_f[ib] := scale;
      abs_scale := Abs(scale);
      if abs_scale > max_abs_scale then
      begin
        max_abs_scale := abs_scale;
        max_scale := scale;
      end;
    end;

    // 2. Cas nul : bloc entièrement vide
    if max_abs_scale < GROUP_MAX_EPS then
    begin
      FillChar(pBlock^, SizeOf(TBlockQ6_K), 0);
      Inc(pBlock);
      Continue;
    end;

    // 3. Échelle globale et quantification des sous-échelles sur 8 bits
    iscale := -128.0 / max_scale;
    sd := 1.0 / iscale;
    pBlock^.D := FP32ToFP16o(Single(sd));

    for ib := 0 to 15 do
      pBlock.scales[ib] := ClampInt(NearestInt(iscale * scales_f[ib]), -128, 127);

    // 4. Requantification finale des poids
    for ib := 0 to 15 do
    begin
      sub_scale := sd * pBlock^.scales[ib];
      if Abs(sub_scale) > 1E-20 then
        for L := 0 to 15 do
          // LL[ib * 16 + L] := Max(-32, Min(31, CRound1(src[i * QK_K + ib * 16 + L] / sub_scale)))
          LL[ib * 16 + L] := ClampInt(NearestInt(src[i * QK_K + ib * 16 + L] / sub_scale), -32, 31)
      else
        FillChar(LL[ib * 16], 16, 0);
    end;

    // 5. Packaging ql (4 LSB) et qh (2 MSB)
    ql_idx := 0;
    qh_idx := 0;
    for j := 0 to 1 do
    begin
      offset_j := j * 128;
      for L := 0 to 31 do
      begin
        q1 := LL[offset_j + L] and $0F;
        q2 := LL[offset_j + L + 32] and $0F;
        q3 := LL[offset_j + L + 64] and $0F;
        q4 := LL[offset_j + L + 96] and $0F;

        pBlock^.ql[L + ql_idx] := Byte(q1 or (q3 shl 4));
        pBlock^.ql[L + ql_idx + 32] := Byte(q2 or (q4 shl 4));

        // Conversion signed[-32,31] -> unsigned[0,3] pour le pack 2-bit
        pBlock^.qh[qh_idx + L] := Byte(((LL[offset_j + L] + 32) shr 4) or (((LL[offset_j + L + 32] + 32) shr 4) shl 2)
          or (((LL[offset_j + L + 64] + 32) shr 4) shl 4) or (((LL[offset_j + L + 96] + 32) shr 4) shl 6));
      end;
      Inc(ql_idx, 64);
      Inc(qh_idx, 32);
    end;
    Inc(pBlock);
  end;
end;

// ============================================================================
// QUANTISATION Q6_K (HAUTE QUALITÉ / RMSE)
// Utilise σ² ou quant_weights pour optimiser chaque sous-bloc.
// Correspond à quantize_row_q6_K_impl du C.
// ============================================================================
procedure QuantQ6_K_Impl(const src: PSingle; Dest: PByte; n_row: Integer; quant_weights: PSingle = nil);
var
  nb, i, ib, j, L, offset_j: Integer;
  pBlock: PBlockQ6_K;
  max_scale, max_abs_scale, scale, abs_scale, iscale, sd: Single;
  scales_f: array [0 .. 15] of Single;
  LL: array [0 .. 255] of ShortInt;
  qw_ptr: PSingle;
  ql_idx, qh_idx, q1, q2, q3, q4: Integer;
begin
  nb := n_row div QK_K;
  pBlock := PBlockQ6_K(Dest);

  for i := 0 to nb - 1 do
  begin
    max_scale := 0.0;
    max_abs_scale := 0.0;

    // 1. Optimisation RMSE par sous-bloc de 16 éléments
    for ib := 0 to 15 do
    begin
      qw_ptr := nil;
      if Assigned(quant_weights) then
        qw_ptr := @quant_weights[i * QK_K + 16 * ib];

      scale := MakeQxQuants(16, 32, @src[i * QK_K + ib * 16], @LL[ib * 16], 1, qw_ptr);
      scales_f[ib] := scale;
      abs_scale := Abs(scale);
      if abs_scale > max_abs_scale then
      begin
        max_abs_scale := abs_scale;
        max_scale := scale;
      end;
    end;

    // 2. Cas nul
    if max_abs_scale < GROUP_MAX_EPS then
    begin
      FillChar(pBlock^, SizeOf(TBlockQ6_K), 0);
      Inc(pBlock);
      Continue;
    end;

    // 3. Échelle globale FP16 + quantification sous-échelles 8-bit
    iscale := -128.0 / max_scale;
    sd := 1.0 / iscale;
    pBlock.D := FP32ToFP16o(sd);

    for ib := 0 to 15 do
      pBlock.scales[ib] := ClampInt(NearestInt(iscale * scales_f[ib]), -128, 127);

    // 4. Requantification avec les échelles packées
    for ib := 0 to 15 do
    begin
      sd := FP16ToFP32o(pBlock.D) * pBlock.scales[ib];
      if Abs(sd) > 1E-20 then
      begin
        for L := 0 to 15 do
          LL[ib * 16 + L] := ClampInt(NearestInt(src[i * QK_K + ib * 16 + L] / sd), -32, 31) + 32;
      end
      else
        FillChar(LL[ib * 16], 16, 0);
    end;

    // 5. Packaging ql (4 bits) + qh (2 bits)
    ql_idx := 0;
    qh_idx := 0;
    for j := 0 to 1 do
    begin
      offset_j := j * 128;
      for L := 0 to 31 do
      begin
        q1 := LL[offset_j + L] and $0F;
        q2 := LL[offset_j + L + 32] and $0F;
        q3 := LL[offset_j + L + 64] and $0F;
        q4 := LL[offset_j + L + 96] and $0F;

        pBlock.ql[L + ql_idx] := Byte(q1 or (q3 shl 4));
        pBlock.ql[L + ql_idx + 32] := Byte(q2 or (q4 shl 4));

        // Pas d'ajout +32 ici car LL contient déjà des valeurs unsigned [0, 63] après +32 dans la boucle précédente
        pBlock.qh[qh_idx + L] := Byte(((LL[offset_j + L]) shr 4) or (((LL[offset_j + L + 32]) shr 4) shl 2) or
          (((LL[offset_j + L + 64]) shr 4) shl 4) or (((LL[offset_j + L + 96]) shr 4) shl 6));
      end;
      Inc(ql_idx, 64);
      Inc(qh_idx, 32);
    end;
    Inc(pBlock);
  end;
end;

end.
