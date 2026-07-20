unit uGgmlQuantsQ4K;

interface

uses
  SysUtils, Classes, uGGMLTypes, uGGMLConstants, uMath;

{$B-} // active les checks de performance. Les indices sont validés par les structures GGML.
{$R-}  // Désactive les range checks pour éviter les surcoûts dans les boucles critiques

{$POINTERMATH ON}   // PByte + 2 = adresse + 2 octets (C-compatible)
{$J-}               // Désactive les checks de bounds (indices validés par la logique GGML)
{$O+}               // Active les optimisations du compilateur (inline, loop unroll)
// {$ALIGN 8}         // Alignement SSE2 optimal pour les Single
{$R-}  // Désactive les range checks pour éviter les surcoûts dans les boucles critiques

type
  EGGML = class(Exception);

  // ============================================================================
  // DÉQUANTISATION Q3_K
  // Format : 3.4375 bits/poids. Super-bloc de 256 éléments.
  // Structure : 16 sous-blocs de 16 éléments. Chaque sous-bloc a son propre scale.
  // Les scales sont compressés sur 6 bits et regroupés dans un tableau de 12 octets.
  // Les poids quantifiés sont stockés sur 2 bits (0-3) + 1 bit de masque (hmask).
  // ============================================================================
procedure DequantQ3_K(const Data: PByte; Dest: PSingle; n_row: Integer);

// ============================================================================
// QUANTISATION Q3_K (RÉFÉRENCE)
// Algorithme déterministe (sans optimisation RMSE).
// Étape 1 : Pour chaque sous-bloc de 16 éléments, trouver le scale optimal.
// Étape 2 : Quantifier les 16 scales sur 6 bits et les packer dans y[i].scales.
// Étape 3 : Reconstruct les valeurs à partir des scales packés pour générer les poids L.
// Étape 4 : Stocker les bits de poids dans qs et les masques dans hmask.
// ============================================================================
procedure QuantQ3_K_Ref(const src: PSingle; Dest: PByte; n_row: Integer);

// ============================================================================
// QUANTISATION Q3_K (HAUTE QUALITÉ / RMSE)
// Utilise des poids internes (quant_weights) ou une estimation σ² pour optimiser MSE.
// Étape 1 : Calcul σ² global sur la ligne.
// Étape 2 : Pour chaque sous-bloc, optimiser scale + poids L via MakeQxQuants.
// Étape 3 : Optimiser les 16 scales ensemble via MakeQxQuants (super-scale).
// Étape 4 : Packer les scales sur 6 bits et requantifier L pour correspondre aux scales finaux.
// ============================================================================
procedure QuantQ3_K_Impl(const src: PSingle; Dest: PByte; n_row: Integer; quant_weights: PSingle = nil);

// ============================================================================
// DÉQUANTISATION Q4_K
// Format : 4.5 bits/poids. Super-bloc de 256 éléments.
// Structure : 8 sous-blocs de 32 éléments. Chaque sous-bloc a un scale (d) et un min (min).
// x = d * q - min. Les scales/min sont packés sur 6 bits dans un tableau de 12 octets.
// ============================================================================
procedure DequantQ4_K(const Data: PByte; Dest: PSingle; n_row: Integer);

// ============================================================================
// QUANTISATION Q4_K (RÉFÉRENCE)
// Algorithme standard GGML.
// Étape 1 : Pour chaque sous-bloc de 32, trouver scale et min optimaux via MakeQkx2Quants.
// Étape 2 : Quantifier les 8 scales + 8 mins sur 6 bits et packer.
// Étape 3 : Normaliser les scales/mins globaux (d, dmin).
// Étape 4 : Requantifier L avec d, dmin finaux et packer dans qs.
// ============================================================================
procedure QuantQ4_K_Fast(const src: PSingle; Dest: PByte; n_row: Integer);
procedure QuantQ4_K_Ref(const src: PSingle; Dest: PByte; n_row: Integer);

// ============================================================================
// QUANTISATION Q4_K (HAUTE QUALITÉ / RMSE)
// Utilise weights σ² + |x| ou quant_weights externes.
// Étape 1 : Calcul σ² = 2*∑x²/N (variance pondérée).
// Étape 2 : Pour chaque sous-bloc, calcul weights et optimiser scale/min via MakeQkx2Quants.
// Étape 3 : Optimiser les 8 scales + 8 mins ensemble via MakeQpQuants (super-scale/min).
// Étape 4 : Packer les scales/mins sur 6 bits, puis requantifier L avec les valeurs finales.
// ============================================================================
procedure QuantQ4_K_Impl(const src: PSingle; Dest: PByte; n_row: Integer; quant_weights: PSingle = nil);

implementation

uses uGgmlQuants, uGGMLQuantUtils, uGgmlQuantsQ6K;

// ============================================================================
// DÉQUANTISATION Q3_K
// ============================================================================
procedure DequantQ3_K(const Data: PByte; Dest: PSingle; n_row: Integer);
var
  nb, i, n_chunk, j, l, shift, is_idx: Integer;
  pBlock: PBlockQ3_K;
  d_all, dl: Single;
  m: Byte;
  sub: Integer;
  aux: array [0 .. 3] of Cardinal;
  scales_unpacked: array [0 .. 15] of ShortInt absolute aux;
  tmp: Cardinal;
begin
  // 1. Découpage en super-blocs de 256 éléments
  nb := n_row div QK_K;
  pBlock := PBlockQ3_K(Data);

  for i := 0 to nb - 1 do
  begin
    // 2. Échelle globale du super-bloc (FP16 -> FP32)
    d_all := FP16ToFP32o(pBlock.d);

    // 3. Dé-packing des 16 scales sur 6 bits depuis 12 octets
    // Les 12 octets contiennent les scales packés 4 par 4.
    // Cette étape décompresse les bits pour obtenir les 16 valeurs [-32, +31].
    FillChar(aux, SizeOf(aux), 0);
    Move(pBlock.scales[0], aux[0], 12);
    tmp := aux[2];
    aux[2] := ((aux[0] shr 4) and $0F0F0F0F) or (((tmp shr 4) and $03030303) shl 4);
    aux[3] := ((aux[1] shr 4) and $0F0F0F0F) or (((tmp shr 6) and $03030303) shl 4);
    aux[0] := (aux[0] and $0F0F0F0F) or (((tmp shr 0) and $03030303) shl 4);
    aux[1] := (aux[1] and $0F0F0F0F) or (((tmp shr 2) and $03030303) shl 4);

    is_idx := 0;
    m := 1; // Masque pour hmask (bit 0 à bit 7 sur 8 sous-blocs)

    // 4. Traitement par chunk de 128 éléments (moitié haute / moitié basse)
    for n_chunk := 0 to 1 do
    begin
      shift := 0;
      for j := 0 to 3 do
      begin
        // --- Première moitié du chunk (16 éléments) ---
        // Scale local = d_all * (scale_packed - 32)
        dl := d_all * (scales_unpacked[is_idx] - 32);
        Inc(is_idx);
        for l := 0 to 15 do
        begin
          // Le poids quantifié est (qs[2 bits] - 4) si hmask=0, sinon (qs[2 bits])
          // hmask indique si le poids original était >= 4 (donc besoin du 3ème bit caché)
          if (pBlock.hmask[l] and m) = 0 then
            sub := 4
          else
            sub := 0;
          // Ajout du décalage (n_chunk * 32) pour lire la bonne moitié de qs
          Dest[n_chunk * 128 + j * 32 + l] := dl * (Integer((pBlock.qs[n_chunk * 32 + l] shr shift) and 3) - sub);
        end;

        // Seconde moitié du chunk (16 éléments)
        dl := d_all * (scales_unpacked[is_idx] - 32);
        Inc(is_idx);
        for l := 0 to 15 do
        begin
          if (pBlock.hmask[l + 16] and m) = 0 then
            sub := 4
          else
            sub := 0;
          // Idem pour la seconde partie
          Dest[n_chunk * 128 + j * 32 + 16 + l] :=
            dl * (Integer((pBlock.qs[n_chunk * 32 + 16 + l] shr shift) and 3) - sub);
        end;

        Inc(shift, 2);
        m := m shl 1;
      end;
    end;

    // 5. Avance au super-bloc suivant (256 éléments déquantisés)
    Inc(Dest, 256);
    Inc(pBlock);
  end;
end;

// ============================================================================
procedure QuantQ3_K_Ref(const src: PSingle; Dest: PByte; n_row: Integer);
var
  nb, i, j, l, m, base, dest_base, l_val: Integer;
  pBlock: PBlockQ3_K;
  max_scale, amax, scale, iscale, d_val: Single;
  scales_f: array [0 .. 15] of Single;
  L_arr: array [0 .. 255] of ShortInt;
  sc: ShortInt;
  hm: Byte;
begin
  nb := n_row div QK_K;
  pBlock := PBlockQ3_K(Dest);

  for i := 0 to nb - 1 do
  begin
    max_scale := 0.0;
    amax := 0.0;

    // 1. Optimisation scale par sous-bloc de 16 éléments (référence)
    for j := 0 to 15 do
    begin
      // make_q3_quants renvoie le scale optimal et remplit L_arr avec les poids quantifiés [-4, +3]
      scale := MakeQ3Quants(16, 4, @src[i * QK_K + 16 * j], @L_arr[16 * j], true);
      scales_f[j] := scale;
      if Abs(scale) > amax then
      begin
        amax := Abs(scale);
        max_scale := scale;
      end;
    end;

    // 2. Initialisation du tableau de scales packés
    FillChar(pBlock.scales[0], 12, 0);

    // 3. Quantification des 16 scales sur 6 bits (valeur -32 à +31)
    if max_scale <> 0.0 then
    begin
      iscale := -32.0 / max_scale;
      for j := 0 to 15 do
      begin
        // l_val := Max(-32, Min(31, CRound(iscale * scales_f[j]))) + 32;
        l_val := ClampInt(NearestInt(iscale * scales_f[j]), -32, 31) + 32; // 0..63
        if j < 8 then
          pBlock.scales[j] := l_val and $0F
        else
          pBlock.scales[j - 8] := pBlock.scales[j - 8] or ((l_val and $0F) shl 4);

        l_val := l_val shr 4;
        pBlock.scales[j mod 4 + 8] := pBlock.scales[j mod 4 + 8] or (l_val shl (2 * (j div 4)));
      end;
      pBlock.d := FP32ToFP16o(1.0 / iscale);
    end
    else
    begin
      pBlock.d := FP32ToFP16o(0.0);
    end;

    // 4. Reconstruction des poids finaux L (0-7) à partir des scales packés
    for j := 0 to 15 do
    begin
      if j < 8 then
        sc := pBlock.scales[j] and $0F
      else
        sc := pBlock.scales[j - 8] shr 4;

      sc := (sc or (((pBlock.scales[8 + j mod 4] shr (2 * (j div 4))) and 3) shl 4)) - 32;
      d_val := FP16ToFP32o(pBlock.d) * sc;

      if d_val = 0.0 then
      begin
        // Fallback : si scale nul, on force les poids à la valeur neutre (4 = 0 après déquantisation)
        for l := 0 to 15 do
          L_arr[16 * j + l] := 4;
        Continue;
      end;

      for l := 0 to 15 do
      begin
        l_val := NearestInt(src[i * QK_K + 16 * j + l] / d_val);
        // l_val := Max(-4, Min(3, l_val));
        l_val := ClampInt(l_val, -4, 3);
        L_arr[16 * j + l] := l_val + 4; // Stocké en [0, 7]
      end;
    end;

    // 5. Extraction des masques (hmask) et finalisation des poids
    FillChar(pBlock.hmask[0], 32, 0);
    m := 0;
    hm := 1;
    for j := 0 to 255 do
    begin
      if L_arr[j] > 3 then // Si poids >= 4, on active le masque et on soustrait 4
      begin
        pBlock.hmask[m] := pBlock.hmask[m] or hm;
        L_arr[j] := L_arr[j] - 4;
      end;
      Inc(m);
      if m = 32 then
      begin
        m := 0;
        hm := hm shl 1;
      end;
    end;

    // 6. Packing des 2 bits de poids sur 32 octets (qs)
    for j := 0 to 1 do
    begin
      base := j * 128;
      dest_base := j * 32;
      for l := 0 to 31 do
      begin
        // Chaque octet qs contient 4 poids de 2 bits (l, l+32, l+64, l+96)
        // "and 3" pour empêcher la pollution des bits supérieurs
        pBlock.qs[dest_base + l] := (Byte(L_arr[base + l]) and 3) or ((Byte(L_arr[base + l + 32]) and 3) shl 2) or
          ((Byte(L_arr[base + l + 64]) and 3) shl 4) or ((Byte(L_arr[base + l + 96]) and 3) shl 6);
      end;
    end;

    Inc(pBlock);
  end;
end;

// ============================================================================
procedure QuantQ3_K_Impl(const src: PSingle; Dest: PByte; n_row: Integer; quant_weights: PSingle = nil);
var
  nb, i, j, l, m, base, dest_base, l_val: Integer;
  pBlock: PBlockQ3_K;
  sum_x2, sigma2, sumw, d_block, d_val: Single;
  scales_f, sw, weight: array [0 .. 15] of Single;
  L_arr: array [0 .. 255] of ShortInt;
  Ls: array [0 .. 15] of ShortInt;
  sc: ShortInt;
  qw_ptr: PSingle;
  hm: Byte;
begin
  nb := n_row div QK_K;
  pBlock := PBlockQ3_K(Dest);

  for i := 0 to nb - 1 do
  begin
    // 1. Calcul de la variance globale σ² = 2*∑x²/N (utilisé pour pondérer les poids RMSE)
    sum_x2 := 0.0;
    for l := 0 to 255 do
      sum_x2 := sum_x2 + Sqr(src[i * QK_K + l]);
    sigma2 := 2 * sum_x2 / QK_K;

    // 2. Optimisation RMSE par sous-bloc
    for j := 0 to 15 do
    begin
      if Assigned(quant_weights) then
      begin
        qw_ptr := @quant_weights[i * QK_K + 16 * j];
        for l := 0 to 15 do
          weight[l] := qw_ptr[l] * Sqrt(sigma2 + Sqr(src[i * QK_K + 16 * j + l]));
      end
      else
      begin
        for l := 0 to 15 do
          weight[l] := Sqr(src[i * QK_K + 16 * j + l]);
      end;

      sumw := 0.0;
      for l := 0 to 15 do
        sumw := sumw + weight[l];
      sw[j] := sumw;

      // make_qx_quants avec rmse_type=1 (poids x²) optimise scale + L
      scales_f[j] := MakeQxQuants(16, 4, @src[i * QK_K + 16 * j], @L_arr[16 * j], 1, @weight[0]);
    end;

    // 3. Optimisation du super-scale (regroupe les 16 scales)
    FillChar(pBlock.scales[0], 12, 0);
    d_block := MakeQxQuants(16, 32, @scales_f[0], @Ls[0], 1, @sw[0]);

    // 4. Packing des 16 scales optimisés sur 6 bits
    for j := 0 to 15 do
    begin
      l_val := Max(0, Min(63, Ls[j]));
      if j < 8 then
        pBlock.scales[j] := l_val and $0F
      else
        pBlock.scales[j - 8] := pBlock.scales[j - 8] or ((l_val and $0F) shl 4);

      l_val := l_val shr 4;
      pBlock.scales[j mod 4 + 8] := pBlock.scales[j mod 4 + 8] or ((l_val and 3) shl (2 * (j div 4)));
    end;

    pBlock.d := FP32ToFP16o(d_block);

    // 5. Reconstruction finale des poids L avec les scales packés
    for j := 0 to 15 do
    begin
      if j < 8 then
        sc := pBlock.scales[j] and $0F
      else
        sc := pBlock.scales[j - 8] shr 4;

      sc := (sc or (((pBlock.scales[8 + j mod 4] shr (2 * (j div 4))) and 3) shl 4)) - 32;
      d_val := FP16ToFP32o(pBlock.d) * sc;

      if d_val = 0.0 then
      begin
        for l := 0 to 15 do
          L_arr[16 * j + l] := 4;
        Continue;
      end;

      for l := 0 to 15 do
      begin
        l_val := NearestInt(src[i * QK_K + 16 * j + l] / d_val);
        // l_val := Max(-4, Min(3, l_val));
        l_val := ClampInt(l_val, -4, 3);
        L_arr[16 * j + l] := l_val + 4;
      end;
    end;

    // 6. Extraction hmask & packing qs (identique à Ref)
    FillChar(pBlock.hmask[0], 32, 0);
    m := 0;
    hm := 1;
    for j := 0 to 255 do
    begin
      if L_arr[j] > 3 then
      begin
        pBlock.hmask[m] := pBlock.hmask[m] or hm;
        L_arr[j] := L_arr[j] - 4;
      end;
      Inc(m);
      if m = 32 then
      begin
        m := 0;
        hm := hm shl 1;
      end;
    end;

    for j := 0 to 1 do
    begin
      base := j * 128;
      dest_base := j * 32;
      for l := 0 to 31 do
      begin
        pBlock.qs[dest_base + l] := (Byte(L_arr[base + l]) and 3) or ((Byte(L_arr[base + l + 32]) and 3) shl 2) or
          ((Byte(L_arr[base + l + 64]) and 3) shl 4) or ((Byte(L_arr[base + l + 96]) and 3) shl 6);
      end;
    end;

    Inc(pBlock);
  end;
end;

// ============================================================================
procedure DequantQ4_K(const Data: PByte; Dest: PSingle; n_row: Integer);
var
  nb, i, j, l: Integer;
  pBlock: PBlockQ4_K;
  d_block, m_block, d_sub1, d_sub2, m_sub1, m_sub2: Single;
  sc1, m1, sc2, m2: Byte;
  q_idx: Integer;
begin
  nb := n_row div QK_K;
  pBlock := PBlockQ4_K(Data);

  for i := 0 to nb - 1 do
  begin
    d_block := FP16ToFP32o(pBlock.d);
    m_block := FP16ToFP32o(pBlock.dmin);
    q_idx := 0;

    // 4 sous-paires de 32 éléments (8 sous-blocs total)
    for j := 0 to 3 do
    begin
      // Récupération des scales & mins packés sur 6 bits pour chaque paire
      GetScaleMinK4(j * 2 + 0, @pBlock.scales[0], sc1, m1);
      GetScaleMinK4(j * 2 + 1, @pBlock.scales[0], sc2, m2);

      d_sub1 := d_block * sc1;
      m_sub1 := m_block * m1;
      d_sub2 := d_block * sc2;
      m_sub2 := m_block * m2;

      // Déquantisation : x = d * q_low - min
      for l := 0 to 31 do
        Dest[i * QK_K + j * 64 + l] := d_sub1 * (pBlock.qs[q_idx + l] and $0F) - m_sub1;
      // Déquantisation : x = d * q_high - min
      for l := 0 to 31 do
        Dest[i * QK_K + j * 64 + 32 + l] := d_sub2 * (pBlock.qs[q_idx + l] shr 4) - m_sub2;

      // Inc(q_idx, 32);
      q_idx := q_idx + 32;
    end;
    Inc(pBlock);
  end;
end;

// ============================================================================
procedure QuantQ4_K_Fast(const src: PSingle; Dest: PByte; n_row: Integer); // testé OK
var
  nb, i, j, l: Integer;
  pBlock: PBlockQ4_K;
  L_arr: array [0 .. 255] of Byte;
  lmin, lmax, max_scale, max_min, d_block, m_block, inv_scale, inv_min, d_sub, m_sub: Single;
  scales_f, mins_f: array [0 .. 7] of Single;
  Ls, lm, Val: Integer;
  SubBlockSc, SubBlockM: array [0 .. 7] of Byte;
  q_idx: Integer;
begin
  nb := n_row div QK_K;
  pBlock := PBlockQ4_K(Dest);

  for i := 0 to nb - 1 do
  begin
    max_scale := 0;
    max_min := 0;

    // 1. Analyse des 8 sous-blocs de 32 éléments
    for j := 0 to 7 do
    begin
      lmin := src[i * QK_K + j * 32];
      lmax := lmin;
      for l := 1 to 31 do
      begin
        if src[i * QK_K + j * 32 + l] < lmin then
          lmin := src[i * QK_K + j * 32 + l];
        if src[i * QK_K + j * 32 + l] > lmax then
          lmax := src[i * QK_K + j * 32 + l];
      end;

      // Le format Q4_K ne gère pas les "min" positifs.
      // Si la matrice n'a que des valeurs positives, on ancre le minimum à 0.
      if lmin > 0 then
        lmin := 0; // GGUF Q4_K ancre souvent le min à 0 pour les positifs

      scales_f[j] := (lmax - lmin) / 15.0;
      mins_f[j] := -lmin;

      if scales_f[j] > max_scale then
        max_scale := scales_f[j];
      if mins_f[j] > max_min then
        max_min := mins_f[j];
    end;

    // 2. Calcul des échelles globales du super-bloc
    inv_scale := 0;
    if max_scale > 0 then
      inv_scale := 63.0 / max_scale;
    inv_min := 0;
    if max_min > 0 then
      inv_min := 63.0 / max_min;

    // 3. Quantisation des sous-blocs
    FillChar(pBlock.scales[0], 12, 0);
    for j := 0 to 7 do
    begin
      // Clamp les valeurs 6-bit
      // Ls := Max(0, Min(63, CRound1(inv_scale * scales_f[j])));
      Ls := ClampInt(NearestInt(inv_scale * scales_f[j]), 0, 63);
      // lm := Max(0, Min(63, CRound1(inv_min * mins_f[j])));
      lm := ClampInt(NearestInt(inv_min * mins_f[j]), 0, 63);
      SubBlockSc[j] := Ls;
      SubBlockM[j] := lm;

      // Packing spécifique 6-bits GGUF
      if j < 4 then
      begin
        pBlock.scales[j] := Ls;
        pBlock.scales[j + 4] := lm;
      end
      else
      begin
        pBlock.scales[j + 4] := (Ls and $0F) or ((lm and $0F) shl 4);
        pBlock.scales[j - 4] := pBlock.scales[j - 4] or ((Ls shr 4) shl 6);
        pBlock.scales[j] := pBlock.scales[j] or ((lm shr 4) shl 6);
      end;
    end;

    d_block := max_scale / 63.0;
    m_block := max_min / 63.0;

    pBlock.d := FP32ToFP16o(d_block);
    pBlock.dmin := FP32ToFP16o(m_block);

    d_block := FP16ToFP32o(pBlock.d);
    m_block := FP16ToFP32o(pBlock.dmin);

    for j := 0 to 7 do
    begin
      d_sub := d_block * SubBlockSc[j];
      m_sub := m_block * SubBlockM[j];
      for l := 0 to 31 do
      begin
        if d_sub <> 0 then
          Val := NearestInt((src[i * QK_K + j * 32 + l] + m_sub) / d_sub)
        else
          Val := 0;
        L_arr[j * 32 + l] := Max(0, Min(15, Val));
      end;
    end;

    // Entrelacement spécifique
    q_idx := 0;
    for j := 0 to 3 do
    begin
      for l := 0 to 31 do
      begin
        pBlock.qs[q_idx] := L_arr[j * 64 + l] or (L_arr[j * 64 + l + 32] shl 4);
        // Inc(q_idx);
        q_idx := q_idx + 1
      end;
    end;
    Inc(pBlock);
  end;
end;

procedure QuantQ4_K_Ref(const src: PSingle; Dest: PByte; n_row: Integer);
var
  nb, i, j, l, q_idx: Integer;
  pBlock: PBlockQ4_K;
  L_arr: array [0 .. QK_K - 1] of Byte;
  Laux: array [0 .. 31] of Byte;
  scales_f, mins_f: array [0 .. QK_K div 32 - 1] of Single;
  d_block, m_block, d_sub, m_sub: Single;
  Ls, lm: Byte;
  sum_x2, av_x: Single;
  weights: array [0 .. 31] of Single;
begin
  nb := n_row div QK_K;
  pBlock := PBlockQ4_K(Dest);

  for i := 0 to nb - 1 do
  begin
    FillChar(L_arr, SizeOf(L_arr), 0);
    d_block := 0.0;
    m_block := 0.0;

    // 1. Optimisation scale + min par sous-bloc (COMME LE C Ref : poids av_x + |x|)
    for j := 0 to 7 do
    begin
      sum_x2 := 0.0;
      for l := 0 to 31 do
        sum_x2 := sum_x2 + src[i * QK_K + j * 32 + l] * src[i * QK_K + j * 32 + l];

      // Division par 32 (taille du sous-bloc), pas par QK_K
      av_x := Sqrt(sum_x2 / 32);
      for l := 0 to 31 do
        weights[l] := av_x + Abs(src[i * QK_K + j * 32 + l]);

      // Passage des poids : identique à quantize_row_q4_K_ref du C
      scales_f[j] := MakeQkx2Quants(32, 15, @src[i * QK_K + j * 32], @weights[0], @L_arr[j * 32], mins_f[j], @Laux[0],
        -1.0, 0.1, 20, false);

      if scales_f[j] > d_block then
        d_block := scales_f[j];
      if mins_f[j] > m_block then
        m_block := mins_f[j];
    end;

    // 2. Quantification 6-bit + Packing (identique C)
    FillChar(pBlock.scales[0], 12, 0);
    for j := 0 to 7 do
    begin
      Ls := ClampInt(NearestInt(63.0 / Max(GROUP_MAX_EPS, scales_f[j])), 0, 63);
      lm := ClampInt(NearestInt(63.0 / Max(GROUP_MAX_EPS, mins_f[j])), 0, 63);

      if j < 4 then
      begin
        pBlock.scales[j] := Ls;
        pBlock.scales[j + 4] := lm;
      end
      else
      begin
        pBlock.scales[j + 4] := (Ls and $0F) or ((lm and $0F) shl 4);
        pBlock.scales[j - 4] := pBlock.scales[j - 4] or ((Ls shr 4) shl 6);
        pBlock.scales[j] := pBlock.scales[j] or ((lm shr 4) shl 6);
      end;
    end;

    // 3. Normalisation super-échelles FP16
    pBlock.d := FP32ToFP16o(d_block / 63.0);
    pBlock.dmin := FP32ToFP16o(m_block / 63.0);

    // 4. Requantification finale avec scales packés
    q_idx := 0;
    for j := 0 to 7 do
    begin
      GetScaleMinK4(j, @pBlock.scales[0], Ls, lm);

      if (Ls = 0) and (lm = 0) then
        FillChar(L_arr[j * 32], 32, 0)
      else
      begin
        d_sub := FP16ToFP32o(pBlock.d) * Ls;
        if d_sub <> 0 then
        begin
          m_sub := FP16ToFP32o(pBlock.dmin) * lm;
          for l := 0 to 31 do
            L_arr[j * 32 + l] := ClampInt(NearestInt((src[i * QK_K + j * 32 + l] + m_sub) / d_sub), 0, 15)
        end
        else
          FillChar(L_arr[j * 32], 32, 0);
      end;
    end;

    // 5. Packing qs
    q_idx := 0;
    for j := 0 to 3 do
      for l := 0 to 31 do
      begin
        pBlock.qs[q_idx] := L_arr[j * 64 + l] or (L_arr[j * 64 + l + 32] shl 4);
        Inc(q_idx);
      end;
    Inc(pBlock);
  end;
end;

// QuantQ4_K_Impl : Optimisation RMSE pondérée GGML
procedure QuantQ4_K_Impl(const src: PSingle; Dest: PByte; n_row: Integer; quant_weights: PSingle = nil);
var
  nb, i, j, l, q_idx: Integer;
  pBlock: PBlockQ4_K;
  L_arr: array [0 .. QK_K - 1] of Byte;
  Laux: array [0 .. 31] of Byte;
  scales_f, mins_f, sw: array [0 .. QK_K div 32 - 1] of Single;
  weights: array [0 .. 31] of Single;
  Ls_arr, Lm_arr: array [0 .. QK_K div 32 - 1] of Byte;
  d_block, m_block, d_sub, m_sub: Single;
  sigma2, av_x: Single;
  qw_ptr: PSingle;
begin
  nb := n_row div QK_K;
  pBlock := PBlockQ4_K(Dest);

  for i := 0 to nb - 1 do
  begin
    // 1. Calcul σ² = 2*∑x²/N (variance pondérée pour RMSE)
    sigma2 := 0;
    for l := 0 to QK_K - 1 do
      sigma2 := sigma2 + (src[i * QK_K + l] * src[i * QK_K + l]);
    // sigma2 := sigma2 + Sqr(src[i * QK_K + l]);
    sigma2 := 2 * sigma2 / QK_K;
    av_x := Sqrt(sigma2);

    // 2. Optimisation RMSE par sous-bloc de 32
    for j := 0 to 7 do
    begin
      if Assigned(quant_weights) then
        qw_ptr := @quant_weights[i * QK_K + 32 * j]
      else
        qw_ptr := nil;

      // Calcul des poids : qw * √(σ² + x²) ou √(σ²) + |x|
      if qw_ptr <> nil then
        for l := 0 to 31 do
          weights[l] := qw_ptr[l] * Sqrt(sigma2 + Sqr(src[i * QK_K + 32 * j + l]))
      else
        for l := 0 to 31 do
          weights[l] := av_x + Abs(src[i * QK_K + 32 * j + l]);

      sw[j] := 0;
      for l := 0 to 31 do
        sw[j] := sw[j] + weights[l];

      // make_qkx2_quants optimise scale + min avec pondération RMSE
      // scales_f[j] := MakeQkx2Quants(32, 15, @src[i * QK_K + 32 * j], @weights[0], @L_arr[32 * j], mins_f[j], @Laux[0],-0.9, 0.05, 36, false);
      scales_f[j] := MakeQkx2Quants(32, 15, @src[i * QK_K + 32 * j], @weights[0], @L_arr[32 * j], mins_f[j], @Laux[0],
        -0.9, 0.05, 36, false);

      // scales_f[j] := MakeQkx2Quants(32, 15, @src[i * QK_K + j * 32], @weights[0], @L_arr[j * 32], mins_f[j], @Laux[0],-1.0, 0.1, 20, false);
    end;

    // 3. Optimisation des super-scales & super-mins (8 valeurs chacun)
    d_block := MakeQpQuants(8, 63, @scales_f[0], @sw[0], @Ls_arr[0]);
    m_block := MakeQpQuants(8, 63, @mins_f[0], @sw[0], @Lm_arr[0]);

    // 4. Packing des scales/mins sur 6 bits
    FillChar(pBlock.scales[0], 12, 0);
    for j := 0 to 7 do
    begin
      // Ls_arr[j] := Min(63, Ls_arr[j]);
      Ls_arr[j] := ClampInt(Ls_arr[j], 0, 63);
      // Lm_arr[j] := Min(63, Lm_arr[j]);
      Lm_arr[j] := ClampInt(Lm_arr[j], 0, 63);
      if j < 4 then
      begin
        pBlock.scales[j] := Ls_arr[j];
        pBlock.scales[j + 4] := Lm_arr[j];
      end
      else
      begin
        pBlock.scales[j + 4] := (Ls_arr[j] and $0F) or ((Lm_arr[j] and $0F) shl 4);
        pBlock.scales[j - 4] := pBlock.scales[j - 4] or ((Ls_arr[j] shr 4) shl 6);
        pBlock.scales[j] := pBlock.scales[j] or ((Lm_arr[j] shr 4) shl 6);
      end;
    end;

    pBlock.d := FP32ToFP16o(d_block);
    pBlock.dmin := FP32ToFP16o(m_block);

    // 5. Requantification finale des poids L avec les scales finaux
    q_idx := 0;
    for j := 0 to 7 do
    begin
      if j < 4 then
        Ls_arr[j] := pBlock.scales[j] and $3F
      else
        Ls_arr[j] := (pBlock.scales[j + 4] and $0F) or ((pBlock.scales[j - 4] shr 6) shl 4);

      if j < 4 then
        Lm_arr[j] := pBlock.scales[j + 4] and $3F
      else
        Lm_arr[j] := (pBlock.scales[j + 4] shr 4) or ((pBlock.scales[j] shr 6) shl 4);

      d_sub := FP16ToFP32o(pBlock.d) * Ls_arr[j];

      if d_sub <> 0 then
      begin
        m_sub := FP16ToFP32o(pBlock.dmin) * Lm_arr[j];
        for l := 0 to 31 do
          // L_arr[j * 32 + l] := Max(0, Min(15, CRound1((src[i * QK_K + 32 * j + l] + dm_f) / d)))
          L_arr[j * 32 + l] := ClampInt(NearestInt((src[i * QK_K + 32 * j + l] + m_sub) / d_sub), 0, 15)
      end
      else
        FillChar(L_arr[j * 32], 32, 0);
    end;

    // 6. Packing final dans qs
    for j := 0 to 3 do
    begin
      for l := 0 to 31 do
      begin
        pBlock.qs[q_idx] := L_arr[j * 64 + l] or (L_arr[j * 64 + l + 32] shl 4);
        q_idx := q_idx + 1
      end;
    end;
    Inc(pBlock);
  end;
end;

end.
