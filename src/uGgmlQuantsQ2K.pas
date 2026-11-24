unit uGgmlQuantsQ2K;

interface

uses
  SysUtils, Classes, uGGMLTypes, uGGMLConstants, uMath, uAppConfig;

{$B-}
{$R-}
{$POINTERMATH ON}
// {$J-}
{$O+}
{$ALIGN 8}
procedure DequantQ2_K(const Data: PByte; Dest: PSingle; n_row: Integer);

procedure QuantQ2_K_Ref(pSrc: PSingle; Dest: PByte; n_row: Integer);

procedure QuantQ2_K_Impl1(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil; iQk: Integer = QP_PROF_IMPL1);
procedure QuantQ2_K_Impl2(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
procedure QuantQ2_K_Impl3(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
procedure QuantQ2_K_Impl4(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
procedure QuantQ2_K_Impl5(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);

implementation

uses uGgmlQuants, uGgmlQuantsFP16, uGGMLQuantUtils;

procedure DequantQ2_K(const Data: PByte; Dest: PSingle; n_row: Integer);
var
  nb, i, n_chunk, j, l, shift, is_idx: Integer;
  B: PBlockQ2_K;
  d, min_val, dl, ml: Single;
  q: PByte;
  q_val: Integer;
begin
  nb := n_row div QK_K;
  B := PBlockQ2_K(Data);

  for i := 0 to nb - 1 do
  begin
    d := FP16ToFP32(B^.d);
    min_val := FP16ToFP32(B^.dmin);
    q := @B^.qs[0];
    is_idx := 0;

    // Traitement par chunks de 128 éléments (exactement comme le C)
    for n_chunk := 0 to 1 do
    begin
      shift := 0;
      for j := 0 to 3 do // 4 paires de sous-blocs par chunk
      begin
        // Sous-bloc gauche (16 éléments)
        dl := d * (B^.scales[is_idx] and $0F);
        ml := min_val * (B^.scales[is_idx] shr 4);
        Inc(is_idx);
        for l := 0 to 15 do
        begin
          q_val := ((q[l] shr shift) and 3);
          Dest[i * QK_K + n_chunk * 128 + j * 32 + l] := dl * q_val - ml;
        end;

        // Sous-bloc droit (16 éléments)
        dl := d * (B^.scales[is_idx] and $0F);
        ml := min_val * (B^.scales[is_idx] shr 4);
        Inc(is_idx);
        for l := 0 to 15 do
        begin
          q_val := ((q[l + 16] shr shift) and 3);
          Dest[i * QK_K + n_chunk * 128 + j * 32 + 16 + l] := dl * q_val - ml;
        end;

        Inc(shift, 2);
      end;
      Inc(q, 32); // Passe au chunk suivant de 32 octets
    end;
    Inc(B);
  end;
end;

procedure QuantQ2_K_Ref(pSrc: PSingle; Dest: PByte; n_row: Integer);
var
  nb, ib, j, i: Integer;
  B: PBlockQ2_K;
  LLq: array [0 .. QK_K - 1] of Byte;
  Laux: array [0 .. 15] of Byte;
  weights: array [0 .. 15] of Single;
  mins, scales: array [0 .. 15] of Single;
  max_scale, max_min, inv_scale, inv_min, d_super, m_super, dl, ml: Single;
  q_val: Integer;
  cfgQK: TQuantPreset;
begin
  cfgQK := cfg.ggmlReg.GetPreset(GGML_TYPE_Q2_K, 0);
  nb := n_row div QK_K;
  B := PBlockQ2_K(Dest);

  for ib := 0 to nb - 1 do
  begin
    // FillWeights(pSrc, nil, @weights[0], QK_K, cfgQK.RmseType, False);
    max_scale := 0;
    max_min := 0;

    // 1. Optimisation par sous-bloc
    for j := 0 to 15 do
    begin
      for i := 0 to 15 do
        weights[i] := 1.0;
      // make_qkx2_quants(16, 3, x + 16*j, weights, L + 16*j, &mins[j], Laux, -0.5f, 0.1f, 15, true);
      scales[j] := MakeQkx2Quants(16, 3, pSrc + 16 * j, @weights[0], @LLq[16 * j], mins[j], @Laux[0], -0.5, 0.1, 15,
        cfgQK.UseMAD);

      if scales[j] > max_scale then
        max_scale := scales[j];
      if mins[j] > max_min then
        max_min := mins[j];
    end;

    // 2. Packing des échelles globales
    inv_scale := 0;
    if max_scale > 0 then
      inv_scale := 15.0 / max_scale;
    B^.d := FP32ToFP16(max_scale / 15);
    for j := 0 to 15 do
      B^.scales[j] := Byte(ClampInt(NearestInt(inv_scale * scales[j]), 0, 15));

    // 3. Packing des minimums globaux
    inv_min := 0;
    if max_min > 0 then
      inv_min := 15.0 / max_min;
    B^.dmin := FP32ToFP16(max_min / 15);
    for j := 0 to 15 do
      B^.scales[j] := B^.scales[j] or Byte(ClampInt(NearestInt(inv_min * mins[j]), 0, 15) shl 4);
    // (Round(inv_min * mins[j]) shl 4);

    // 4. Requantization finale
    d_super := FP16ToFP32(B^.d);
    m_super := FP16ToFP32(B^.dmin);
    for j := 0 to 15 do
    begin
      dl := d_super * (B^.scales[j] and $0F);
      ml := m_super * (B^.scales[j] shr 4);
      if dl = 0 then
        Continue;

      for i := 0 to 15 do
      begin
        q_val := NearestInt((pSrc[16 * j + i] + ml) / dl);
        if q_val < 0 then
          q_val := 0
        else if q_val > 3 then
          q_val := 3;
        LLq[16 * j + i] := Byte(q_val);
      end;
    end;

    // 5. Packing 2-bit (interleaving spécifique Q2_K)
    for i := 0 to 31 do
    begin
      B^.qs[i] := LLq[i] or (LLq[i + 32] shl 2) or (LLq[i + 64] shl 4) or (LLq[i + 96] shl 6);
      B^.qs[i + 32] := LLq[128 + i] or (LLq[160 + i] shl 2) or (LLq[192 + i] shl 4) or (LLq[224 + i] shl 6);
    end;

    Inc(B);
    Inc(pSrc, QK_K);
  end;
end;

procedure QuantQ2_K_Impl1(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil; iQk: Integer = QP_PROF_IMPL1);
var
  nb, sb, j, i, ii, k, RadLs, RadLm: Integer;
  B: PBlockQ2_K;
  LLq: array [0 .. QK_K - 1] of Byte;
  Laux: array [0 .. 15] of Byte;
  weights: array [0 .. QK_K - 1] of Single;
  mins, scales, sw: array [0 .. 15] of Single;
  LLs, LLm: array [0 .. 15] of Byte;
  d_super, dmin_super, dl, ml: Single;
  cfgQK: PQuantPreset;
begin
  cfgQK := cfg.ggmlReg.GetPPreset(GGML_TYPE_Q2_K, iQk);
  RadLs := cfgQK.RadiusLs;
  RadLm := cfgQK.RadiusLm;

  if (RadLs < 0) then
    RadLs := 0;
  if (RadLm < 0) then
    RadLm := 0;

  nb := n_row div QK_K;
  B := PBlockQ2_K(Dest);

  for sb := 0 to nb - 1 do
  begin
    FillWeights(pSrc, qWeights, @weights[0], QK_K, cfgQK.RmseType, False);

    // 1. Optimisation par sous-bloc (16 sous-blocs de 16)
    for j := 0 to Q2K_NSUB - 1 do
    begin
      sw[j] := 0.0;
      for i := 0 to Q2K_SUB - 1 do
        sw[j] := sw[j] + weights[j * Q2K_SUB + i];

      scales[j] := MakeQkx2Quants(Q2K_SUB, Q2K_NMAXQ, @pSrc[j * Q2K_SUB], @weights[j * Q2K_SUB], @LLq[j * Q2K_SUB],
        mins[j], @Laux[0], -cfgQK.Rmin, cfgQK.Rdelta, cfgQK.Nstep, cfgQK.UseMAD);
    end;

    // 2. Super-parametres, puis SNAP FP16 (le decodeur ne voit que la valeur FP16)
    d_super := MakeQpQuants(Q2K_NSUB, Q2K_SCALEMAX, @scales[0], @sw[0], @LLs[0], cfgQK.QpStep, cfgQK.QpNStep,
      cfgQK.QcIter);
    dmin_super := MakeQpQuants(Q2K_NSUB, Q2K_SCALEMAX, @mins[0], @sw[0], @LLm[0], cfgQK.QpStep, cfgQK.QpNStep,
      cfgQK.QcIter);

    B^.d := FP32ToFP16(d_super);
    B^.dmin := FP32ToFP16(dmin_super);
    d_super := FP16ToFP32(B^.d);
    dmin_super := FP16ToFP32(B^.dmin);

    for j := 0 to Q2K_NSUB - 1 do
    begin
      LLs[j] := Byte(ClampInt(LLs[j], 0, Q2K_SCALEMAX));
      LLm[j] := Byte(ClampInt(LLm[j], 0, Q2K_SCALEMAX));
    end;

    // 3. Raffinage JOINT (CodeS,CodeM) + poids, sous contrainte FP16 figee.
    // (kx,ky)=(0,0) est dans la recherche => ne peut pas empirer.
    if (RadLs > 0) or (RadLm > 0) then
      for j := 0 to Q2K_NSUB - 1 do
        RefineScaleMinCodes(LLs[j], LLm[j], Q2K_SUB, Q2K_SCALEMAX, Q2K_NMAXQ, RadLs, RadLm, @pSrc[j * Q2K_SUB],
          @weights[j * Q2K_SUB], @LLq[j * Q2K_SUB], d_super, dmin_super);

    // 4. Repack des codes finaux + requantification alignee sur les octets ecrits
    { Packing des codes 4 bits : nibble bas = scale, nibble haut = min (layout Q2_K) }
    for k := 0 to Q2K_NSUB - 1 do
      B^.scales[k] := Byte((LLs[k] and $0F) or ((LLm[k] and $0F) shl 4));

    { Requantification avec les codes lus DANS LE BLOC (ce que le decodeur verra) }
    for k := 0 to Q2K_NSUB - 1 do
    begin
      LLs[k] := B^.scales[k] and $0F;
      LLm[k] := B^.scales[k] shr 4;
      dl := d_super * LLs[k];
      if dl = 0.0 then
        Continue; // comme avant : codes locaux conserves, dl*q = 0 -> sans effet
      ml := dmin_super * LLm[k];
      for ii := 0 to Q2K_SUB - 1 do
        LLq[k * Q2K_SUB + ii] := Byte(ClampInt(NearestInt((pSrc[k * Q2K_SUB + ii] + ml) / dl), 0, Q2K_NMAXQ));
    end;

    // 5. Packing 2 bits (interleaving Q2_K)
    for i := 0 to 31 do
    begin
      B^.qs[i] := LLq[i] or (LLq[i + 32] shl 2) or (LLq[i + 64] shl 4) or (LLq[i + 96] shl 6);
      B^.qs[i + 32] := LLq[128 + i] or (LLq[160 + i] shl 2) or (LLq[192 + i] shl 4) or (LLq[224 + i] shl 6);
    end;

    Inc(B);
    Inc(pSrc, QK_K);
    if qWeights <> nil then
      Inc(qWeights, QK_K);
  end;
end;

procedure QuantQ2_K_Impl2(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
begin
  QuantQ2_K_Impl1(pSrc, Dest, n_row, qWeights, QP_PROF_IMPL2);
end;

procedure QuantQ2_K_Impl3(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
begin
  QuantQ2_K_Impl1(pSrc, Dest, n_row, qWeights, QP_PROF_IMPL3);
end;

procedure QuantQ2_K_Impl4(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
begin
  QuantQ2_K_Impl1(pSrc, Dest, n_row, qWeights, QP_PROF_IMPL4);
end;

procedure QuantQ2_K_Impl5(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
begin
  QuantQ2_K_Impl1(pSrc, Dest, n_row, qWeights, QP_PROF_IMPL5);
end;

end.
