unit uGgmlQuantsQ50;

interface

uses
  SysUtils, Classes, System.Threading, uGGMLTypes, uGGMLConstants, uGGMLQuantUtils, uMath, uLog,
  uAppConfig;

{$POINTERMATH ON}
// Format Q5_0 : 5 bits/paramètre. Bloc de 32 éléments.
// Formule : x = d * (q - 16), où q : [0, 31], d : FP16. Bit 4 stocké dans qh[4]
procedure DequantQ5_0(const Data: PByte; Dest: PSingle; n_row: Integer); // testé OK
procedure QuantQ5_0_Ref(pSrc: PSingle; Dest: PByte; n_row: Integer); // testé OK
procedure QuantQ5_0_Impl1(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil; iQk: Integer = QP_PROF_IMPL1);
procedure QuantQ5_0_Impl2(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
procedure QuantQ5_0_Impl3(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
procedure QuantQ5_0_Impl4(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
procedure QuantQ5_0_Impl5(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);

// Format Q5_1 : 5 bits/paramètre. Bloc de 32 éléments.
// Formule : x = d * q + m, où q : [0, 31], d,m : FP16. Bit 4 stocké dans qh[4]
procedure DequantQ5_1(const Data: PByte; Dest: PSingle; n_row: Integer); // testé OK
procedure QuantQ5_1_Ref(pSrc: PSingle; Dest: PByte; n_row: Integer); // testé OK
procedure QuantQ5_1_Impl1(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil; iQk: Integer = QP_PROF_IMPL1);
procedure QuantQ5_1_Impl2(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
procedure QuantQ5_1_Impl3(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
procedure QuantQ5_1_Impl4(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
procedure QuantQ5_1_Impl5(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);

implementation

uses uGgmlQuantsFP16;

procedure DequantQ5_0(const Data: PByte; Dest: PSingle; n_row: Integer);
var
  nb, i, j: Integer;
  pBlock: PBlockQ5_0;
  D: Single;
  qh: Cardinal;
  xh_0, xh_1, x0, x1: Integer;
begin
  nb := n_row div QK5_0;
  pBlock := PBlockQ5_0(Data);
  for i := 0 to nb - 1 do
  begin
    D := FP16ToFP32(pBlock.D);
    qh := pBlock.qh; // Lecture du masque 32-bit contenant les 5èmes bits

    for j := 0 to 15 do
    begin
      // Extraction du bit 4 (valeur 16) pour les 16 premiers et seconds poids
      xh_0 := ((qh shr j) shl 4) and $10;
      xh_1 := ((qh shr (j + 16)) shl 4) and $10;

      // Reconstruction : q ∈ [0, 31], décalage -16 → [-16, 15]
      x0 := ((pBlock.qs[j] and $0F) or xh_0) - 16;
      x1 := ((pBlock.qs[j] shr 4) or xh_1) - 16;

      Dest[i * QK5_0 + j] := x0 * D;
      Dest[i * QK5_0 + j + 16] := x1 * D;
    end;
    Inc(pBlock);
  end;
end;

procedure QuantQ5_0_Ref(pSrc: PSingle; Dest: PByte; n_row: Integer);
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
      if Abs(pSrc[i * 32 + j]) > amax then
      begin
        amax := Abs(pSrc[i * 32 + j]);
        maxVal := pSrc[i * 32 + j];
      end;
    end;

    // Échelle : d = max_signed / -16
    D := maxVal / -16.0;
    if D <> 0 then
      id := 1.0 / D
    else
      id := 0.0;

    pBlock^.D := FP32ToFP16(D);
    FillChar(pBlock^.qs, SizeOf(pBlock^.qs), 0);
    qh := 0;

    for j := 0 to 15 do
    begin
      // Quantification avec offset +16.5 (simule (int8_t)(x*id + 16.5f))
      xi0 := Trunc(Single(pSrc[i * 32 + j] * id + 16.5));
      xi1 := Trunc(Single(pSrc[i * 32 + j + 16] * id + 16.5));

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

procedure QuantQ5_0_Impl1(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil; iQk: Integer = QP_PROF_IMPL1);
var
  nb, ib, j: Integer;
  D: Single;
  pBlock: PBlockQ5_0;
  weights: array [0 .. QK5_0 - 1] of Single;
  LLq: array [0 .. QK5_0 - 1] of Byte;
  qh: Cardinal;
  cfgQK: PQuantPreset;
begin
  cfgQK := cfg.ggmlReg.GetPPreset(GGML_TYPE_Q5_0, iQk);
  nb := n_row div QK5_0;
  pBlock := PBlockQ5_0(Dest);

  for ib := 0 to nb - 1 do
  begin
    FillWeights(pSrc, qWeights, @weights[0], QK5_0, cfgQK.RmseType, False);

    D := MakeQxQuants(QK5_0, 16, pSrc, @LLq[0], cfgQK.RmseType, @weights[0], cfgQK.Rdelta, cfgQK.nstep);
    pBlock^.D := FP32ToFP16(D);
    qh := 0;
    for j := 0 to 15 do
    begin
      if (LLq[j] and $10) <> 0 then
        qh := qh or (Cardinal(1) shl j);
      if (LLq[j + 16] and $10) <> 0 then
        qh := qh or (Cardinal(1) shl (j + 16));
      pBlock^.qs[j] := Byte(LLq[j] and $0F) or (Byte(LLq[j + 16] and $0F) shl 4);
    end;
    pBlock^.qh := qh;

    Inc(pBlock);
    Inc(pSrc, QK5_0);
    if qWeights <> nil then
      Inc(qWeights, QK5_0);
  end;
end;

procedure QuantQ5_0_Impl2(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
begin
  QuantQ5_0_Impl1(pSrc, Dest, n_row, qWeights, QP_PROF_IMPL2);
end;

procedure QuantQ5_0_Impl3(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
begin
  QuantQ5_0_Impl1(pSrc, Dest, n_row, qWeights, QP_PROF_IMPL3);
end;

procedure QuantQ5_0_Impl4(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
begin
  QuantQ5_0_Impl1(pSrc, Dest, n_row, qWeights, QP_PROF_IMPL4);
end;

procedure QuantQ5_0_Impl5(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
begin
  QuantQ5_0_Impl1(pSrc, Dest, n_row, qWeights, QP_PROF_IMPL5);
end;

procedure DequantQ5_1(const Data: PByte; Dest: PSingle; n_row: Integer);
var
  nb, i, j: Integer;
  pBlock: PBlockQ5_1;
  D, m: Single;
  qh: Cardinal;
  xh_0, xh_1, x0, x1: Integer;
begin
  nb := n_row div QK5_1;
  pBlock := PBlockQ5_1(Data);
  for i := 0 to nb - 1 do
  begin
    D := FP16ToFP32(pBlock.D);
    m := FP16ToFP32(pBlock.m);
    qh := pBlock.qh;

    for j := 0 to 15 do
    begin
      xh_0 := ((qh shr j) shl 4) and $10;
      xh_1 := ((qh shr (j + 16)) shl 4) and $10;
      x0 := (pBlock.qs[j] and $0F) or xh_0;
      x1 := (pBlock.qs[j] shr 4) or xh_1;
      Dest[i * QK5_1 + j] := x0 * D + m;
      Dest[i * QK5_1 + j + 16] := x1 * D + m;
    end;
    Inc(pBlock);
  end;
end;

procedure QuantQ5_1_Ref(pSrc: PSingle; Dest: PByte; n_row: Integer);
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
      a_val := (pSrc[i * 32 + j]);
      if a_val < minVal then
        minVal := a_val;
      if a_val > maxVal then
        maxVal := a_val;
    end;

    D := Single((maxVal - minVal) / 31.0);
    id := 0.0;
    if D <> 0.0 then
      id := Single(1.0 / D);

    pBlock^.D := FP32ToFP16(D);
    pBlock^.m := FP32ToFP16(minVal);
    FillChar(pBlock^.qs, SizeOf(pBlock^.qs), 0);
    qh := 0;

    for j := 0 to 15 do
    begin
      x0 := Single((pSrc[i * 32 + j] - minVal) * id);
      x1 := Single((pSrc[i * 32 + (j + 16)] - minVal) * id);
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

procedure QuantQ5_1_Impl1(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil; iQk: Integer = QP_PROF_IMPL1);
var
  nb, ib, j: Integer;
  D, min_val: Single;
  pBlock: PBlockQ5_1;
  weights: array [0 .. QK5_1 - 1] of Single;
  LLq, Laux: array [0 .. QK5_1 - 1] of Byte;
  qh: Cardinal;
  cfgQK: PQuantPreset;
begin
  cfgQK := cfg.ggmlReg.GetPPreset(GGML_TYPE_Q5_1, iQk);
  nb := n_row div QK5_1;
  pBlock := PBlockQ5_1(Dest);
  for ib := 0 to nb - 1 do
  begin
    FillWeights(pSrc, qWeights, @weights[0], QK5_0, cfgQK.RmseType, False);
    // make_qkx3_quants(QK5_1, 31, xb, weight, L, &min, Laux, -0.9f, 0.05f, 36, false);
    D := MakeQkx2Quants(QK5_1, 31, pSrc, @weights[0], @LLq[0], min_val, @Laux[0], -cfgQK.rmin, cfgQK.Rdelta,
      cfgQK.nstep, cfgQK.UseMAD);
    pBlock^.D := FP32ToFP16(D);
    pBlock^.m := FP32ToFP16(-min_val);

    qh := 0;
    for j := 0 to 15 do
    begin
      qh := qh or (Cardinal((LLq[j] and $10) shr 4) shl j);
      qh := qh or (Cardinal((LLq[j + 16] and $10) shr 4) shl (j + 16));
      pBlock^.qs[j] := (LLq[j] and $0F) or ((LLq[j + 16] and $0F) shl 4);
    end;
    pBlock^.qh := qh;

    Inc(pBlock);
    Inc(pSrc, QK5_1);
    if qWeights <> nil then
      Inc(qWeights, QK5_1);
  end;
end;

procedure QuantQ5_1_Impl2(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
begin
  QuantQ5_1_Impl1(pSrc, Dest, n_row, qWeights, QP_PROF_IMPL2);
end;

procedure QuantQ5_1_Impl3(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
begin
  QuantQ5_1_Impl1(pSrc, Dest, n_row, qWeights, QP_PROF_IMPL3);
end;

procedure QuantQ5_1_Impl4(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
begin
  QuantQ5_1_Impl1(pSrc, Dest, n_row, qWeights, QP_PROF_IMPL4);
end;

procedure QuantQ5_1_Impl5(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
begin
  QuantQ5_1_Impl1(pSrc, Dest, n_row, qWeights, QP_PROF_IMPL5);
end;

end.
