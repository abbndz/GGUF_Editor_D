unit uGgmlQuantsQ6K;

interface

uses
  SysUtils, Classes, uGGMLTypes, uGGMLConstants, uMath, uAppConfig;

{$B-}
{$R-}
{$POINTERMATH ON}
{$J-}
{$O+}
{$ALIGN 8}

  // DÉCLARATIONS DES PROCEDURES Q6_K
procedure DequantQ6_K(const Data: PByte; Dest: PSingle; n_row: Integer);
procedure QuantQ6_K_Ref(pSrc: PSingle; Dest: PByte; n_row: Integer);
procedure QuantQ6_K_Impl1(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil; iQk: Integer = QP_PROF_IMPL1);
procedure QuantQ6_K_Impl2(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
procedure QuantQ6_K_Impl3(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
procedure QuantQ6_K_Impl4(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
procedure QuantQ6_K_Impl5(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);

implementation

uses uGgmlQuants, uGgmlQuantsFP16, uGGMLQuantUtils;

// DÉQUANTISATION Q6_K
// Format : 6.5625 bits/poids. Super-bloc de 256 éléments.
// Structure : 16 sous-blocs de 16 éléments.
// Math : x = d * q, où q : [-32, 31] (6 bits signé).
// Les poids sont stockés sur 6 bits : ql (4 bits LSB) et qh (2 bits MSB).
// Les échelles sont quantifiées sur 8 bits signed [-128, 127].
procedure DequantQ6_K(const Data: PByte; Dest: PSingle; n_row: Integer);
var
  nb, i, L, is_idx, base, n_chunk: Integer;
  pBlock: PBlockQ6_K;
  d_all, sc1, sc2, sc3, sc4: Single;
  ql_idx, qh_idx: Integer;
  q1, q2, q3, q4: Integer;
  ql1, ql2, qh: Byte;
begin
  nb := n_row div QK_K;
  pBlock := PBlockQ6_K(Data);

  for i := 0 to nb - 1 do
  begin
    d_all := FP16ToFP32(pBlock.D);
    ql_idx := 0;
    qh_idx := 0;

    // 2 chunks de 128 éléments (couvre les 16 sous-blocs)
    for n_chunk := 0 to 1 do
    begin
      base := n_chunk * 128;
      for L := 0 to 31 do
      begin
        is_idx := L div 16; // Index du sous-bloc dans le tableau scales[16] , is_idx : vaut toujours 0 ou 1
        // Récupération des 4 échelles couvrant cette position L
        sc1 := d_all * pBlock.scales[n_chunk * 8 + is_idx];
        sc2 := d_all * pBlock.scales[n_chunk * 8 + is_idx + 2];
        sc3 := d_all * pBlock.scales[n_chunk * 8 + is_idx + 4];
        sc4 := d_all * pBlock.scales[n_chunk * 8 + is_idx + 6];

        ql1 := pBlock.ql[ql_idx + L];
        ql2 := pBlock.ql[ql_idx + 32 + L];
        qh := pBlock.qh[qh_idx + L];

        // Reconstruction des 4 valeurs 6-bit signed [-32, 31]  à partir de ql et qh
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
    Inc(Dest, QK_K);
  end;
end;

// ============================================================================
// QUANTISATION Q6_K (VERSION RÉFÉRENCE)
// Algorithme standard GGML (quantize_row_q6_K_ref).
// ============================================================================
procedure QuantQ6_K_Ref(pSrc: PSingle; Dest: PByte; n_row: Integer);
var
  nb, ib, j, L, offset_j: Integer;
  pBlock: PBlockQ6_K;
  max_scale, max_abs_scale, abs_scale, iscale, d_all, d_sub: Single;
  scales: array [0 .. 15] of Single;
  weights: array [0 .. 255] of Single;
  LL: array [0 .. 255] of ShortInt;
  ql_idx, qh_idx, q1, q2, q3, q4: Integer;
begin
  nb := n_row div QK_K;
  pBlock := PBlockQ6_K(Dest);
  for ib := 0 to nb - 1 do
  begin
    // FillWeights(pSrc, nil, @weights[0], QK_K, cfgQK.RmseType, False);
    for j := 0 to 255 do
    begin
      weights[j] := 1.0;
    end;

    max_scale := 0.0;
    max_abs_scale := 0.0;

    // 1. Quantification initiale par sous-bloc de 16 éléments
    for j := 0 to 15 do
    begin
      scales[j] := MakeQxQuants(16, 32, @pSrc[j * 16], @LL[j * 16], 1, @weights[0], 0.1, 9);
      abs_scale := Abs(scales[j]);
      if abs_scale > max_abs_scale then
      begin
        max_abs_scale := abs_scale;
        max_scale := scales[j];
      end;
    end;

    // 2. Cas nul : bloc entièrement vide
    if max_abs_scale < GROUP_EPS then
    begin
      FillChar(pBlock^, SizeOf(TBlockQ6_K), 0);
      Inc(pBlock);
      Continue;
    end;

    // 3. Échelle globale et quantification des sous-échelles sur 8 bits
    iscale := -128.0 / max_scale;
    d_all := 1.0 / iscale;
    pBlock.D := FP32ToFP16(d_all);
    for j := 0 to 15 do
      pBlock.scales[j] := Min(127, NearestInt(iscale * scales[j])); // Exact C: MIN(127, ...)

    // 4. Requantification finale des poids
    for j := 0 to 15 do
    begin
      // d_all := FP16ToFP32o(pBlock.D) * pBlock.scales[j];
      d_sub := d_all * pBlock.scales[j];
      if Abs(d_sub) > 1E-20 then
        for L := 0 to 15 do
          LL[j * 16 + L] := ClampInt(NearestInt(pSrc[j * 16 + L] / d_sub), -32, 31) + 32
      else
        FillChar(LL[j * 16], 16, 0);
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

        pBlock.ql[L + ql_idx] := Byte(q1 or (q3 shl 4));
        pBlock.ql[L + ql_idx + 32] := Byte(q2 or (q4 shl 4));
        // Conversion signed[-32,31] -> unsigned[0,3] pour le pack 2-bit
        // LL contient déjà +32, on shift directement par 4
        pBlock.qh[qh_idx + L] := Byte((LL[offset_j + L] shr 4) or ((LL[offset_j + L + 32] shr 4) shl 2) or
          ((LL[offset_j + L + 64] shr 4) shl 4) or ((LL[offset_j + L + 96] shr 4) shl 6));
      end;
      Inc(ql_idx, 64);
      Inc(qh_idx, 32);
    end;
    Inc(pSrc, QK_K);
    Inc(pBlock);
  end;
end;

// ============================================================================
// QUANTISATION Q6_K (HAUTE QUALITÉ / RMSE)
// ============================================================================
procedure QuantQ6_K_Impl1(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil; iQk: Integer = QP_PROF_IMPL1);
var
  nb, sb, ib, j, L, offset_j: Integer;
  pBlock: PBlockQ6_K;
  max_scale, max_abs_scale, abs_scale, iscale, d_all, d_sub: Single;
  scales: array [0 .. 15] of Single;
  LLq: array [0 .. 255] of ShortInt;
  ql_idx, qh_idx, q1, q2, q3, q4: Integer;
  weights: array [0 .. 255] of Single;
  cfgQK: PQuantPreset;
begin
  cfgQK := cfg.ggmlReg.GetPPreset(GGML_TYPE_Q6_K, iQk);
  nb := n_row div QK_K;
  pBlock := PBlockQ6_K(Dest);

  for sb := 0 to nb - 1 do
  begin
    FillWeights(pSrc, qWeights, @weights[0], QK_K, cfgQK.RmseType, True);
    FillChar(pBlock^, SizeOf(TBlockQ6_K), 0);
    max_scale := 0.0;
    max_abs_scale := 0.0;
    // 2. Optimisation par sous-bloc de 16 éléments
    for j := 0 to 15 do
    begin
      scales[j] := MakeQxQuants(16, 32, @pSrc[j * 16], @LLq[j * 16], cfgQK.RmseType, @weights[j * 16], cfgQK.Rdelta,
        cfgQK.Nstep);
      abs_scale := Abs(scales[j]);
      if abs_scale > max_abs_scale then
      begin
        max_abs_scale := abs_scale;
        max_scale := scales[j];
      end;
    end;

    // 3. Cas nul
    if max_abs_scale < GROUP_EPS then
    begin
      Inc(pBlock);
      Inc(pSrc, QK_K);
      if qWeights <> nil then
        Inc(qWeights, QK_K);
      Continue;
    end;

    // 4. Échelle globale + quantification des sous-échelles
    iscale := -128.0 / max_scale;
    d_all := 1.0 / iscale;
    pBlock.D := FP32ToFP16(d_all);
    for ib := 0 to 15 do
      pBlock.scales[ib] := Min(127, NearestInt(iscale * scales[ib]));

    // 5. Requantification finale
    for j := 0 to 15 do
    begin
      d_sub := d_all * pBlock.scales[j];
      if Abs(d_sub) > 1E-20 then
      begin
        for L := 0 to 15 do
          LLq[j * 16 + L] := ClampInt(NearestInt(pSrc[j * 16 + L] / d_sub), -32, 31) + 32;
      end
      else
        FillChar(LLq[j * 16], 16, 0);
    end;

    // 6. Packaging ql + qh
    ql_idx := 0;
    qh_idx := 0;
    for j := 0 to 1 do
    begin
      offset_j := j * 128;
      for L := 0 to 31 do
      begin
        q1 := LLq[offset_j + L] and $0F;
        q2 := LLq[offset_j + L + 32] and $0F;
        q3 := LLq[offset_j + L + 64] and $0F;
        q4 := LLq[offset_j + L + 96] and $0F;
        pBlock.ql[L + ql_idx] := Byte(q1 or (q3 shl 4));
        pBlock.ql[L + ql_idx + 32] := Byte(q2 or (q4 shl 4));
        pBlock.qh[qh_idx + L] := Byte((LLq[offset_j + L] shr 4) or ((LLq[offset_j + L + 32] shr 4) shl 2) or
          ((LLq[offset_j + L + 64] shr 4) shl 4) or ((LLq[offset_j + L + 96] shr 4) shl 6));
      end;
      Inc(ql_idx, 64);
      Inc(qh_idx, 32);
    end;

    Inc(pBlock);
    Inc(pSrc, QK_K);
    if qWeights <> nil then
      Inc(qWeights, QK_K);
  end;
end;

procedure QuantQ6_K_Impl2(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
begin
  QuantQ6_K_Impl1(pSrc, Dest, n_row, qWeights, QP_PROF_IMPL2);

end;

procedure QuantQ6_K_Impl3(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
begin
  QuantQ6_K_Impl1(pSrc, Dest, n_row, qWeights, QP_PROF_IMPL3);
end;

procedure QuantQ6_K_Impl4(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
begin
  QuantQ6_K_Impl1(pSrc, Dest, n_row, qWeights, QP_PROF_IMPL4);
end;

procedure QuantQ6_K_Impl5(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
begin
  QuantQ6_K_Impl1(pSrc, Dest, n_row, qWeights, QP_PROF_IMPL5);
end;

end.
