unit uGgmlQuantsQ5K;

interface

uses
  SysUtils, Classes, uGGMLTypes, uGGMLConstants, uGGMLQuantUtils, uMath, uAppConfig;

{$B-}
{$R-}
{$POINTERMATH ON}
{$J-}
{$O+}
{$ALIGN 8}
{$R-}

type
  EGGML = class(Exception);

  // DÉCLARATIONS DES PROCEDURES Q5_K & Q6_K
procedure DequantQ5_K(const Data: PByte; Dest: PSingle; n_row: Integer);
procedure QuantQ5_K_Ref(pSrc: PSingle; Dest: PByte; n_row: Integer);
procedure QuantQ5_K_Impl1(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil; iQk: Integer = QP_PROF_IMPL1);
procedure QuantQ5_K_Impl2(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
procedure QuantQ5_K_Impl3(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
procedure QuantQ5_K_Impl4(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
procedure QuantQ5_K_Impl5(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);

implementation

uses uGgmlQuants, uGgmlQuantsFP16;

// DÉQUANTISATION Q5_K
// Format : 5.5 bits/poids. Super-bloc de 256 éléments.
// Structure : 8 sous-blocs de 32 éléments.
// Math : x = d * q - min, où q : [0, 31] (5 bits).
// Les 5ème bits (bit 4) sont stockés dans un masque qh[32].
// Les échelles d et min sont quantifiées sur 6 bits et packées dans scales[12].
procedure DequantQ5_K(const Data: PByte; Dest: PSingle; n_row: Integer);
var
  nb, i, chunk, L, q_idx, is_idx, base: Integer;
  pBlock: PBlockQ5_K;
  pDest: PSingle;
  d_all, min_all, d1, d2, min1, min2: Single;
  scales, mins: array [0 .. 7] of Byte;
  hm1, hm2: Integer;
  m1, m2: Word;
begin
  // Découpage en super-blocs de 256 éléments
  nb := n_row div QK_K;
  pBlock := PBlockQ5_K(Data);
  pDest := Dest;

  for i := 0 to nb - 1 do
  begin
    // Décompression des échelles globales FP16 -> FP32
    d_all := FP16ToFP32(pBlock.D);
    min_all := FP16ToFP32(pBlock.dmin);

    // Dé-packing des 8 scales et 8 mins sur 6 bits depuis 12 octets
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

    // Traitement par chunk de 64 éléments (couvre 2 sous-blocs de 32)
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

      base := chunk * 64;

      // Reconstruction des 32 poids pour chaque sous-bloc
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
        pDest[base + L] := d1 * ((pBlock.qs[q_idx + L] and $0F) + hm1) - min1;
        pDest[base + L + 32] := d2 * ((pBlock.qs[q_idx + L] shr 4) + hm2) - min2;
      end;

      Inc(q_idx, 32);
      m1 := m1 shl 2; // Les masques qh avancent de 2 bits par chunk (layout GGML)
      m2 := m2 shl 2;
    end;
    Inc(pDest, QK_K);
    Inc(pBlock);
  end;
end;

// QUANTISATION Q5_K (VERSION RÉFÉRENCE)
// Algorithme déterministe sans optimisation RMSE.
procedure QuantQ5_K_Ref(pSrc: PSingle; Dest: PByte; n_row: Integer);
var
  nb, i, j, L, ii, q_idx, l1, l2: Integer;
  pBlock: PBlockQ5_K;
  LLq: array [0 .. 255] of Byte;
  Laux: array [0 .. 31] of Byte;
  weights: array [0 .. 31] of Single;
  mins, scales: array [0 .. 7] of Single;
  max_scale, max_min, inv_scale, inv_min: Single;
  dl, dm, dl_b, dm_b: Single;
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

    for j := 0 to 7 do
    begin
      sum_x2 := 0;
      for L := 0 to 31 do
        sum_x2 := sum_x2 + pSrc[j * 32 + L] * pSrc[j * 32 + L];
      av_x := Sqrt(sum_x2 / 32);

      for L := 0 to 31 do
        weights[L] := av_x + Abs(pSrc[j * 32 + L]);

      // Ref GGML : rmse_type=1 (variance), grille -0.5, 0.1, 15
      scales[j] := MakeQkx2Quants(32, 31, @pSrc[j * 32], @weights[0], @LLq[j * 32], mins[j], @Laux[0], -0.5, 0.1,
        15, false);

      if scales[j] > max_scale then
        max_scale := scales[j];
      if mins[j] > max_min then
        max_min := mins[j];
    end;

    inv_scale := 0;
    if max_scale > 0 then
      inv_scale := 63.0 / max_scale;
    inv_min := 0;
    if max_min > 0 then
      inv_min := 63.0 / max_min;

    FillChar(pBlock.scales[0], 12, 0);
    for j := 0 to 7 do
    begin
      ls := ClampInt(NearestInt(inv_scale * scales[j]), 0, 63);
      lm := ClampInt(NearestInt(inv_min * mins[j]), 0, 63);

      if j < 4 then
      begin
        pBlock.scales[j] := ls;
        pBlock.scales[j + 4] := lm;
      end
      else
      begin
        pBlock.scales[j + 4] := (ls and $0F) or ((lm and $0F) shl 4);
        pBlock.scales[j - 4] := pBlock.scales[j - 4] or ((ls shr 4) shl 6);
        pBlock.scales[j] := pBlock.scales[j] or ((lm shr 4) shl 6); // Correction typo j-0 -> j
      end;
    end;

    dl_b := max_scale / 63.0;
    pBlock.D := FP32ToFP16(dl_b);
    dm_b := max_min / 63.0;
    pBlock.dmin := FP32ToFP16(dm_b);

    for j := 0 to 7 do
    begin
      if j < 4 then
      begin
        ls := pBlock.scales[j] and $3F; // Scale bas (6 bits)
        lm := pBlock.scales[j + 4] and $3F; // Min bas (6 bits)
      end
      else
      begin
        // Décalage et masquage pour les indices 4-7
        ls := (pBlock.scales[j + 4] and $0F) or ((pBlock.scales[j - 4] shr 6) shl 4);
        lm := (pBlock.scales[j + 4] shr 4) or ((pBlock.scales[j] shr 6) shl 4);
      end;

      // dl := FP16ToFP32o(pBlock.D) * ls;
      dl := dl_b * ls;
      // dm := FP16ToFP32o(pBlock.dmin) * lm;
      dm := dm_b * lm;

      if Abs(dl) < GROUP_EPS then
        Continue;

      for ii := 0 to 31 do
        LLq[j * 32 + ii] := ClampInt(NearestInt((pSrc[j * 32 + ii] + dm) / dl), 0, 31);
    end;

    FillChar(pBlock.qh[0], 32, 0);
    m1 := 1;
    m2 := 2;
    q_idx := 0;

    for j := 0 to 3 do
    begin
      for L := 0 to 31 do
      begin
        l1 := LLq[j * 64 + L];
        l2 := LLq[j * 64 + L + 32];

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
    Inc(pSrc, QK_K);
    Inc(pBlock);
  end;
end;

// QUANTISATION Q5_K (HAUTE QUALITÉ / RMSE)
procedure QuantQ5_K_Impl1(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil; iQk: Integer = QP_PROF_IMPL1);
var
  nb, i, ii, j, k, L, l1, l2, RadLs, RadLm: Integer;
  c, b, qi: Integer;
  mm1, mm2: Word;
  pBlock: PBlockQ5_K;
  LLq: array [0 .. 255] of Byte;
  Laux: array [0 .. 31] of Byte;
  LLs, LLm: array [0 .. 7] of Byte;
  mins, scales, sw: array [0 .. 7] of Single;
  weights: array [0 .. QK_K - 1] of Single;
  sumw: Single;
  d_block, m_block, d_dec, m_dec, dl, ml: Single;
  cfgQK: PQuantPreset;
begin
  Assert(n_row mod QK_K = 0);
  cfgQK := cfg.ggmlReg.GetPPreset(GGML_TYPE_Q5_K, iQk);
  RadLs := cfgQK.RadiusLs;
  RadLm := cfgQK.RadiusLm;

  if (RadLs < 0) then
    RadLs := 0;
  if (RadLm < 0) then
    RadLm := 0;

  { if (RadLs > 7) then
    RadLs := 7;
    if (RadLm > 7) then
    RadLm := 7; }

  nb := n_row div QK_K;
  pBlock := PBlockQ5_K(Dest);

  for i := 0 to nb - 1 do
  begin
    FillWeights(pSrc, qWeights, @weights[0], QK_K, cfgQK.RmseType, True);

    // 1. scale + min par sous-bloc de 32
    for j := 0 to 7 do
    begin
      sumw := 0;
      for L := 0 to Q5K_SUB - 1 do
        sumw := sumw + weights[Q5K_SUB * j + L];
      sw[j] := sumw;
      scales[j] := MakeQkx2Quants(Q5K_SUB, Q5K_NMAXQ, @pSrc[Q5K_SUB * j], @weights[Q5K_SUB * j], @LLq[Q5K_SUB * j],
        mins[j], @Laux[0], -cfgQK.Rmin, cfgQK.Rdelta, cfgQK.Nstep, cfgQK.UseMAD);
    end;

    // 2. super-parametres
    d_block := MakeQpQuants(8, Q5K_SCALEMAX, @scales[0], @sw[0], @LLs[0], cfgQK.QpStep, cfgQK.QpNStep, cfgQK.QcIter);
    m_block := MakeQpQuants(8, Q5K_SCALEMAX, @mins[0], @sw[0], @LLm[0], cfgQK.QpStep, cfgQK.QpNStep, cfgQK.QcIter);

    // 3. SNAP FP16 (indispensable : c'est la valeur vue par le decodeur et par Refine)
    pBlock^.D := FP32ToFP16(d_block);
    pBlock^.dmin := FP32ToFP16(m_block);
    d_dec := FP16ToFP32(pBlock^.D);
    m_dec := FP16ToFP32(pBlock^.dmin);

    for j := 0 to 7 do
    begin
      LLs[j] := Byte(ClampInt(LLs[j], 0, Q5K_SCALEMAX));
      LLm[j] := Byte(ClampInt(LLm[j], 0, Q5K_SCALEMAX));
    end;

    // 4. Raffinage joint (CodeS,CodeM) sous contrainte FP16
    if (RadLs > 0) or (RadLm > 0) then
      for j := 0 to 7 do
        RefineScaleMinCodes(LLs[j], LLm[j], Q5K_SUB, Q5K_SCALEMAX, Q5K_NMAXQ, RadLs, RadLm, @pSrc[Q5K_SUB * j],
          @weights[Q5K_SUB * j], @LLq[Q5K_SUB * j], d_dec, m_dec);

    // 5. Repack + requantification + packing qs/qh
    FillChar(pBlock^.scales[0], 12, 0);
    for k := 0 to 7 do
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

    { Requantification [0..31] depuis les octets scales reellement ecrits }
    for k := 0 to 7 do
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

      dl := d_dec * LLs[k];
      if Abs(dl) <= GROUP_EPS then
        Continue;
      ml := m_dec * LLm[k];
      for ii := 0 to Q5K_SUB - 1 do
        LLq[Q5K_SUB * k + ii] := Byte(ClampInt(NearestInt((pSrc[Q5K_SUB * k + ii] + ml) / dl), 0, Q5K_NMAXQ));
    end;

    { qs (4 LSB) + qh (5e bit), masque 1 bit / sous-bloc, layout GGML }
    FillChar(pBlock^.qh[0], SizeOf(pBlock^.qh), 0);
    qi := 0;
    mm1 := 1;
    mm2 := 2;
    for c := 0 to 3 do
    begin
      b := c * 64;
      for ii := 0 to 31 do
      begin
        l1 := LLq[b + ii];
        if l1 > 15 then
        begin
          Dec(l1, 16);
          pBlock^.qh[ii] := pBlock^.qh[ii] or mm1;
        end;
        l2 := LLq[b + ii + 32];
        if l2 > 15 then
        begin
          Dec(l2, 16);
          pBlock^.qh[ii] := pBlock^.qh[ii] or mm2;
        end;
        pBlock^.qs[qi + ii] := Byte(l1 or (l2 shl 4));
      end;
      Inc(qi, 32);
      mm1 := mm1 shl 2;
      mm2 := mm2 shl 2;
    end;

    Inc(pBlock);
    Inc(pSrc, QK_K);
    if qWeights <> nil then
      Inc(qWeights, QK_K);
  end;
end;

// QUANTISATION Q5_K (HAUTE QUALITÉ / RMSE)
procedure QuantQ5_K_Impl2(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
begin
  QuantQ5_K_Impl1(pSrc, Dest, n_row, qWeights, QP_PROF_IMPL2);
end;

procedure QuantQ5_K_Impl3(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
begin
  QuantQ5_K_Impl1(pSrc, Dest, n_row, qWeights, QP_PROF_IMPL3);
end;

procedure QuantQ5_K_Impl4(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
begin
  QuantQ5_K_Impl1(pSrc, Dest, n_row, qWeights, QP_PROF_IMPL4);
end;

procedure QuantQ5_K_Impl5(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
begin
  QuantQ5_K_Impl1(pSrc, Dest, n_row, qWeights, QP_PROF_IMPL5);
end;

end.
