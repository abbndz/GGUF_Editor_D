unit uGgmlQuantsQ4K;

interface

uses
  SysUtils, Classes, uGGMLTypes, uGGMLConstants, uGGMLQuantUtils, uMath,
  uAppConfig;

{$B-}
{$R-}
{$POINTERMATH ON}
{$J-}
{$O+}
{$ALIGN 8}
{$R-}
// DÉQUANTISATION Q4_K
// Format : 4.5 bits/poids. Super-bloc de 256 éléments.
// Structure : 8 sous-blocs de 32 éléments. Chaque sous-bloc a un scale (d) et un min (min).
// x = d * q - min. Les scales/min sont packés sur 6 bits dans un tableau de 12 octets.
procedure DequantQ4_K(const Data: PByte; Dest: PSingle; n_row: Integer);

// QUANTISATION Q4_K (RÉFÉRENCE)
// Algorithme standard GGML.
// Étape 1 : Pour chaque sous-bloc de 32, trouver scale et min optimaux via MakeQkx2Quants.
// Étape 2 : Quantifier les 8 scales + 8 mins sur 6 bits et packer.
// Étape 3 : Normaliser les scales/mins globaux (d, dmin).
// Étape 4 : Requantifier L avec d, dmin finaux et packer dans qs.
procedure QuantQ4_K_Ref(pSrc: PSingle; Dest: PByte; n_row: Integer);

// QUANTISATION Q4_K (HAUTE QUALITÉ / RMSE)
// Utilise weights σ² + |x| ou quant_weights externes.
// Étape 1 : Calcul σ² = 2*∑x²/N (variance pondérée).
// Étape 2 : Pour chaque sous-bloc, calcul weights et optimiser scale/min via MakeQkx2Quants.
// Étape 3 : Optimiser les 8 scales + 8 mins ensemble via MakeQpQuants (super-scale/min).
// Étape 4 : Packer les scales/mins sur 6 bits, puis requantifier L avec les valeurs finales.
procedure QuantQ4_K_Impl1(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil; iQk: Integer = QP_PROF_IMPL1);
procedure QuantQ4_K_Impl2(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
procedure QuantQ4_K_Impl3(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
procedure QuantQ4_K_Impl4(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
procedure QuantQ4_K_Impl5(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);

implementation

uses uGgmlQuantsFP16;

procedure DequantQ4_K(const Data: PByte; Dest: PSingle; n_row: Integer);
var
  nb, i, j, l: Integer;
  pBlock: PBlockQ4_K;
  pDest: PSingle;
  d_block, m_block, d1, m1, d2, m2: Single;
  sc, m: Byte;
  q_idx: Integer;
begin
  nb := n_row div QK_K;
  pBlock := PBlockQ4_K(Data);
  pDest := Dest;

  for i := 0 to nb - 1 do
  begin
    d_block := FP16ToFP32(pBlock^.d);
    m_block := FP16ToFP32(pBlock^.dmin);
    q_idx := 0;

    // 4 itérations = 8 sous-blocs (2 par itération)
    for j := 0 to 3 do
    begin
      // Paire 1 (indices 0-7)
      // GetScaleMinK4a(j * 2 + 0, @pBlock^.scales[0], sc, m);
      if j < 2 then
      begin
        sc := pBlock^.scales[j * 2] and $3F; // Scale bas (6 bits)
        m := pBlock^.scales[j * 2 + 4] and $3F; // Min bas (6 bits)
      end
      else
      begin
        // Décalage et masquage pour les indices 4-7
        sc := (pBlock^.scales[j * 2 + 4] and $0F) or ((pBlock^.scales[j * 2 - 4] shr 6) shl 4);
        m := (pBlock^.scales[j * 2 + 4] shr 4) or ((pBlock^.scales[j * 2] shr 6) shl 4);
      end;

      d1 := d_block * sc;
      m1 := m_block * m;

      // Paire 2 (indices 8-15)
      // GetScaleMinK4(j * 2 + 1, @pBlock^.scales[0], sc, m);
      if j < 2 then
      begin
        sc := pBlock^.scales[j * 2 + 1] and $3F; // Scale bas (6 bits)
        m := pBlock^.scales[j * 2 + 1 + 4] and $3F; // Min bas (6 bits)
      end
      else
      begin
        // Décalage et masquage pour les indices 4-7
        sc := (pBlock^.scales[j * 2 + 1 + 4] and $0F) or ((pBlock^.scales[j * 2 + 1 - 4] shr 6) shl 4);
        m := (pBlock^.scales[j * 2 + 1 + 4] shr 4) or ((pBlock^.scales[j * 2 + 1] shr 6) shl 4);
      end;

      d2 := d_block * sc;
      m2 := m_block * m;

      // Déquantisation basse & haute
      for l := 0 to 31 do
        pDest[j * 64 + l] := d1 * (pBlock^.qs[q_idx + l] and $0F) - m1;

      for l := 0 to 31 do
        pDest[j * 64 + 32 + l] := d2 * (pBlock^.qs[q_idx + l] shr 4) - m2;

      Inc(q_idx, 32);
    end;
    Inc(pDest, QK_K);
    Inc(pBlock);
  end;
end;

procedure QuantQ4_K_Ref(pSrc: PSingle; Dest: PByte; n_row: Integer);
var
  nb, i, j, l: Integer;
  pBlock: PBlockQ4_K;
  LLa: array [0 .. QK_K - 1] of Byte;
  Laux: array [0 .. 31] of Byte;
  scales, mins: array [0 .. 7] of Single;
  d_block, m_block, d_sub, id_sub, m_sub, inv_scale, inv_min: Single;
  Ls, lm: Byte;
  sum_x2, av_x: Single;
  weights: array [0 .. 31] of Single;
  cfgQK: TQuantPreset;
begin
  cfgQK := cfg.ggmlReg.GetPreset(GGML_TYPE_Q4_K, 0);
  nb := n_row div QK_K;
  pBlock := PBlockQ4_K(Dest);
  for i := 0 to nb - 1 do
  begin
    d_block := 0.0;
    m_block := 0.0;

    // 1. Optimisation scale + min par sous-bloc
    for j := 0 to 7 do
    begin
      sum_x2 := 0.0;
      for l := 0 to 31 do
        sum_x2 := sum_x2 + pSrc[j * 32 + l] * pSrc[j * 32 + l];

      av_x := Sqrt(sum_x2 / 32);
      for l := 0 to 31 do
        weights[l] := av_x + Abs(pSrc[j * 32 + l]);

      // Grille fixe identique au C : -1.0, 0.1, 20 : référence GGML exacte
      // scales[j] := MakeQkx2Quants(32, 15, @pSrc[j * 32], @weights[0], @L_arr[j * 32], mins[j], @Laux[0], -1.0, 0.1,
      // 20, False);
      // scales[j] = make_qkx2_quants(32, 15, x + 32*j, weights, L + 32*j, &mins[j], Laux, -1.f, 0.1f, 20, false);
      scales[j] := MakeQkx2Quants(32, 15, @pSrc[32 * j], @weights[0], @LLa[32 * j], mins[j], @Laux[0], -1.0, 0.1, 20,
        cfgQK.UseMAD);

      if scales[j] > d_block then
        d_block := scales[j];
      if mins[j] > m_block then
        m_block := mins[j];
    end;

    // 2. Calcul des INVERSES GLOBAUX
    // Le C utilise max_scale et max_min (d_block / m_block) pour normaliser TOUT le super-bloc
    if d_block > 0 then
      inv_scale := 63.0 / d_block
    else
      inv_scale := 0.0;
    if m_block > 0 then
      inv_min := 63.0 / m_block
    else
      inv_min := 0.0;

    // 3. Quantification 6-bit + Packing GGML
    FillChar(pBlock^.scales[0], 12, 0);
    for j := 0 to 7 do
    begin
      Ls := ClampInt(NearestInt(inv_scale * scales[j]), 0, 63);
      lm := ClampInt(NearestInt(inv_min * mins[j]), 0, 63);

      if j < 4 then
      begin
        pBlock^.scales[j] := Ls;
        pBlock^.scales[j + 4] := lm;
      end
      else
      begin
        pBlock^.scales[j + 4] := (Ls and $0F) or ((lm and $0F) shl 4);
        pBlock^.scales[j - 4] := pBlock^.scales[j - 4] or ((Ls shr 4) shl 6);
        pBlock^.scales[j] := pBlock^.scales[j] or ((lm shr 4) shl 6);
      end;
    end;

    // 4. Échelles globales FP16
    pBlock^.d := FP32ToFP16(d_block / 63.0);
    pBlock^.dmin := FP32ToFP16(m_block / 63.0);

    // 5. Requantification finale avec scales packés
    for j := 0 to 7 do
    begin
      // GetScaleMinK4(j, @pBlock^.scales[0], Ls, lm);
      if j < 4 then
      begin
        Ls := pBlock^.scales[j] and $3F; // Scale bas (6 bits)
        lm := pBlock^.scales[j + 4] and $3F; // Min bas (6 bits)
      end
      else
      begin
        // Décalage et masquage pour les indices 4-7
        Ls := (pBlock^.scales[j + 4] and $0F) or ((pBlock^.scales[j - 4] shr 6) shl 4);
        lm := (pBlock^.scales[j + 4] shr 4) or ((pBlock^.scales[j] shr 6) shl 4);
      end;

      if (Ls = 0) and (lm = 0) then
        FillChar(LLa[j * 32], 32, 0)
      else
      begin
        d_sub := FP16ToFP32(pBlock^.d) * Ls;
        if Abs(d_sub) > GROUP_EPS then
        begin
          id_sub := 1.0 / d_sub;
          m_sub := FP16ToFP32(pBlock^.dmin) * lm;
          for l := 0 to 31 do
            LLa[j * 32 + l] := ClampInt(NearestInt((pSrc[j * 32 + l] + m_sub) * id_sub), 0, 15);
        end
        else
          FillChar(LLa[j * 32], 32, 0);
      end;
    end;

    // 6. Packing qs (Interleaving exact C)
    for j := 0 to 3 do
      for l := 0 to 31 do
      begin
        pBlock^.qs[j * 32 + l] := LLa[j * 64 + l] or (LLa[j * 64 + l + 32] shl 4);
      end;
    Inc(pSrc, QK_K);
    Inc(pBlock);
  end;
end;

// QuantQ4_K_Impl : Optimisation RMSE pondérée GGML
procedure QuantQ4_K_Impl1(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil; iQk: Integer = QP_PROF_IMPL1);
var
  nb, ib, i, ii, j, k, l, RadLs, RadLm: Integer;
  pBlock: PBlockQ4_K;
  LLa: array [0 .. QK_K - 1] of Byte;
  Laux: array [0 .. 31] of Byte;
  LLs, LLm: array [0 .. Q4K_NSUB - 1] of Byte;
  scales, mins, sw: array [0 .. Q4K_NSUB - 1] of Single;
  weights: array [0 .. QK_K - 1] of Single;
  d_block, m_block, d_dec, m_dec, d_sub, id_sub, m_sub: Single;
  //cfgQK: TQuantPreset;
  cfgQK: PQuantPreset;
begin
  Assert(n_row mod QK_K = 0);
  cfgQK := cfg.ggmlReg.GetPPreset(GGML_TYPE_Q4_K, iQk);
  RadLs := cfgQK.RadiusLs;
  RadLm := cfgQK.RadiusLm;

  if (RadLs < 0) then
    RadLs := 0;
  if (RadLm < 0) then
    RadLm := 0;

  nb := n_row div QK_K;
  pBlock := PBlockQ4_K(Dest);

  for ib := 0 to nb - 1 do
  begin
    FillWeights(pSrc, qWeights, @weights[0], QK_K, cfgQK.RmseType, True);

    // 1. scale + min optimaux par sous-bloc de 32
    for j := 0 to Q4K_NSUB - 1 do
    begin
      sw[j] := 0.0;
      for l := 0 to Q4K_SUB - 1 do
        sw[j] := sw[j] + weights[Q4K_SUB * j + l];
      if iQk = 0 then
        scales[j] := MakeQkx2aQuants(Q4K_SUB, Q4K_NMAXQ, @pSrc[Q4K_SUB * j], @weights[Q4K_SUB * j], @LLa[Q4K_SUB * j],
          mins[j], @Laux[0], -cfgQK.Rmin, cfgQK.Rdelta, cfgQK.Nstep, cfgQK.UseMAD)
      else
        scales[j] := MakeQkx2Quants(Q4K_SUB, Q4K_NMAXQ, @pSrc[Q4K_SUB * j], @weights[Q4K_SUB * j], @LLa[Q4K_SUB * j],
          mins[j], @Laux[0], -cfgQK.Rmin, cfgQK.Rdelta, cfgQK.Nstep, cfgQK.UseMAD);
    end;

    // 2. super-echelle / super-min
    d_block := MakeQpQuants(Q4K_NSUB, Q4K_SCALEMAX, @scales[0], @sw[0], @LLs[0], cfgQK.QpStep, cfgQK.QpNStep,
      cfgQK.QcIter);
    m_block := MakeQpQuants(Q4K_NSUB, Q4K_SCALEMAX, @mins[0], @sw[0], @LLm[0], cfgQK.QpStep, cfgQK.QpNStep,
      cfgQK.QcIter);

    // 3. SNAP FP16 : d_dec / m_dec sont les valeurs que le decodeur appliquera
    pBlock^.d := FP32ToFP16(d_block);
    pBlock^.dmin := FP32ToFP16(m_block);
    d_dec := FP16ToFP32(pBlock^.d);
    m_dec := FP16ToFP32(pBlock^.dmin);

    for j := 0 to Q4K_NSUB - 1 do
    begin
      LLs[j] := Byte(ClampInt(LLs[j], 0, Q4K_SCALEMAX));
      LLm[j] := Byte(ClampInt(LLm[j], 0, Q4K_SCALEMAX));
    end;

    // 4. Raffinage joint (CodeS,CodeM) + poids, objectif = objet FP16 reellement ecrit
    if (RadLs > 0) or (RadLm > 0) then
      for j := 0 to Q4K_NSUB - 1 do
        RefineScaleMinCodes(LLs[j], LLm[j], Q4K_SUB, Q4K_SCALEMAX, Q4K_NMAXQ, RadLs, RadLm, @pSrc[Q4K_SUB * j],
          @weights[Q4K_SUB * j], @LLa[Q4K_SUB * j], d_dec, m_dec);

    // 5. Repack + requantification sur les octets ecrits
    { Packing 6 bits (d, dmin) dans scales[12] : layout GGML Q4_K/Q5_K }
    FillChar(pBlock^.scales[0], 12, 0);
    for k := 0 to Q4K_NSUB - 1 do
    begin
      if k < 4 then
      begin
        pBlock^.scales[k] := LLs[k];
        pBlock^.scales[k + 4] := LLm[k];
      end
      else
      begin
        pBlock^.scales[k + 4] := (LLs[k] and $0F) or ((LLm[k] and $0F) shl 4);
        pBlock^.scales[k - 4] := pBlock^.scales[k - 4] or ((LLs[k] shr 4) shl 6);
        pBlock^.scales[k] := pBlock^.scales[k] or ((LLm[k] shr 4) shl 6);
      end;
    end;

    { Requantification depuis les octets scales reellement ecrits }
    for k := 0 to Q4K_NSUB - 1 do
    begin
      if k < 4 then
      begin
        LLs[k] := pBlock^.scales[k] and $3F;
        LLm[k] := pBlock^.scales[k + 4] and $3F;
      end
      else
      begin
        LLs[k] := (pBlock^.scales[k + 4] and $0F) or ((pBlock^.scales[k - 4] shr 6) shl 4);
        LLm[k] := (pBlock^.scales[k + 4] shr 4) or ((pBlock^.scales[k] shr 6) shl 4);
      end;

      d_sub := d_dec * LLs[k];
      if Abs(d_sub) > GROUP_EPS then
      begin
        id_sub := 1.0 / d_sub;
        m_sub := m_dec * LLm[k];
        for ii := 0 to Q4K_SUB - 1 do
          LLa[Q4K_SUB * k + ii] := Byte(ClampInt(NearestInt((pSrc[Q4K_SUB * k + ii] + m_sub) * id_sub), 0, Q4K_NMAXQ));
      end
      else
        FillChar(LLa[Q4K_SUB * k], Q4K_SUB, 0);
    end;

    { Packing 4 bits interleove (sous-blocs 2c en nibbles bas, 2c+1 en nibbles hauts) }
    for j := 0 to 3 do
      for i := 0 to Q4K_SUB - 1 do
        pBlock^.qs[j * Q4K_SUB + i] := Byte(LLa[j * 64 + i] or (LLa[j * 64 + i + 32] shl 4));

    Inc(pBlock);
    Inc(pSrc, QK_K);
    if qWeights <> nil then
      Inc(qWeights, QK_K);
  end;
end;

procedure QuantQ4_K_Impl2(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
begin
  QuantQ4_K_Impl1(pSrc, Dest, n_row, qWeights, QP_PROF_IMPL2);
end;

procedure QuantQ4_K_Impl3(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
begin
  QuantQ4_K_Impl1(pSrc, Dest, n_row, qWeights, QP_PROF_IMPL3);
end;

procedure QuantQ4_K_Impl4(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
begin
  QuantQ4_K_Impl1(pSrc, Dest, n_row, qWeights, QP_PROF_IMPL4);
end;


procedure QuantQ4_K_Impl5(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
begin
  QuantQ4_K_Impl1(pSrc, Dest, n_row, qWeights, QP_PROF_IMPL5);
end;


end.
