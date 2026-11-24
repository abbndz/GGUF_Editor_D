unit uGgmlQuantsQ40;

interface

uses
  SysUtils, Classes, System.Threading, uGGMLTypes, uGGMLConstants, uGGMLQuantUtils, uMath, Math, uLog,
  uAppConfig;

{$B-}
{$R-}
{$POINTERMATH ON}
{$J-}
{$O+}
{$ALIGN 8}
// DÉCLARATIONS PUBLIQUES : DÉQUANTISATION & QUANTISATION
// Format Q4_0 : 4 bits/paramètre. Bloc de 32 éléments.
// Formule : x = d * (q - 8), où q : [0, 15], d : FP16
procedure DequantQ4_0(const Data: PByte; Dest: PSingle; n_row: Integer); // testé OK
procedure QuantQ4_0_Ref(pSrc: PSingle; Dest: PByte; n_row: Integer); // testé OK
procedure QuantQ4_0_Impl1(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil; iQk: Integer = QP_PROF_IMPL1);
procedure QuantQ4_0_Impl2(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
procedure QuantQ4_0_Impl3(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
procedure QuantQ4_0_Impl4(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
procedure QuantQ4_0_Impl5(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);

// Format Q4_1 : 4 bits/paramètre. Bloc de 32 éléments.
// Formule : x = d * q + m, où q : [0, 15], d,m ∈ FP16
procedure DequantQ4_1(const Data: PByte; Dest: PSingle; n_row: Integer); // testé OK
procedure QuantQ4_1_Ref(pSrc: PSingle; Dest: PByte; n_row: Integer); // testé OK
procedure QuantQ4_1_Impl1(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil; iQk: Integer = QP_PROF_IMPL1);
procedure QuantQ4_1_Impl2(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
procedure QuantQ4_1_Impl3(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
procedure QuantQ4_1_Impl4(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
procedure QuantQ4_1_Impl5(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);

implementation

uses uGgmlQuantsFP16;

procedure DequantQ4_0(const Data: PByte; Dest: PSingle; n_row: Integer);
var
  nb, i, j: Integer;
  B: PByte;
  D: Single;
  // pBlock: PBlockQ4_0;
  pDest: PSingle;
  v0, v1: Integer;
begin
  // 1. Nombre de blocs complets de 32 éléments
  nb := n_row div QK4_0;
  // pBlock := PBlockQ4_0(Data);
  pDest := Dest;
  B := Data;
  for i := 0 to nb - 1 do
  begin
    // 2. Lecture de l'échelle d (FP16 → FP32)
    D := FP16ToFP32(PWord(B)^);
    Inc(B, 2);
    // 3. Dé-packing des 16 paires de 4 bits
    for j := 0 to (QK4_0 div 2) - 1 do
    begin
      v0 := (B[j] and $0F) - 8;
      v1 := (B[j] shr 4) - 8;
      pDest[j] := v0 * D;
      pDest[j + (QK4_0 div 2)] := v1 * D;
    end;
    Inc(B, 16);
    Inc(pDest, QK4_0);
  end;
end;

procedure QuantQ4_0_Ref(pSrc: PSingle; Dest: PByte; n_row: Integer);
var
  nb, i, j: Integer;
  pBlock: PBlockQ4_0;
  amax, maxVal, D, id, x0, x1, AbsSrcX: Single;
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
      // if Abs(src[i * QK4_0 + j]) > amax then
      AbsSrcX := Abs(pSrc[j]);
      if AbsSrcX > amax then
      begin
        // amax := Abs(src[i * QK4_0 + j]);
        // maxVal := src[i * QK4_0 + j];
        amax := AbsSrcX;
        maxVal := pSrc[j];
      end;
    end;

    // 2. Calcul de l'échelle d = max / -8 (centre les valeurs autour de 0)
    D := maxVal / -8.0;
    if D <> 0 then
      id := 1.0 / D
    else
      id := 0.0;

    // 3. Stockage de d en FP16
    pBlock^.D := FP32ToFP16(D);
    // 4. Quantification par paires avec arrondi à +8.5
    for j := 0 to 15 do
    begin
      x0 := pSrc[j] * id;
      x1 := pSrc[16 + j] * id;
      xi0 := Trunc(Single(x0 + 8.5));
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
    Inc(pSrc, QK4_0);
    Inc(pBlock);
  end;
end;

procedure QuantQ4_0_Impl1(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil; iQk: Integer = QP_PROF_IMPL1);
var
  nb, ib, j: Integer;
  D: Single;
  pBlock: PBlockQ4_0;
  weights: array [0 .. QK4_0 - 1] of Single;
  LLq: array [0 .. QK4_0 - 1] of Byte;
  cfgQK: PQuantPreset;
begin
  Assert(iQk >= 0);
  Assert(n_row mod QK4_0 = 0);
  cfgQK := cfg.ggmlReg.GetPPreset(GGML_TYPE_Q4_0, iQk);

  nb := n_row div QK4_0;
  pBlock := PBlockQ4_0(Dest);

  for ib := 0 to nb - 1 do
  begin
    FillWeights(pSrc, qWeights, @weights[0], QK4_0, cfgQK.RmseType, cfgQK.UseMAD);
    // 3. Quantification
    D := MakeQxQuants(QK4_0, 8, pSrc, @LLq[0], cfgQK.RmseType, @weights[0], cfgQK.Rdelta, cfgQK.nstep);
    pBlock^.D := FP32ToFP16(D);
    for j := 0 to 15 do
      pBlock^.qs[j] := Byte(LLq[j]) or (Byte(LLq[j + 16]) shl 4);

    Inc(pBlock);
    Inc(pSrc, QK4_0);
    if qWeights <> nil then
      Inc(qWeights, QK4_0);
  end;
end;

procedure QuantQ4_0_Impl2(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
begin
  QuantQ4_0_Impl1(pSrc, Dest, n_row, qWeights, QP_PROF_IMPL2);
end;

procedure QuantQ4_0_Impl3(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
begin
  QuantQ4_0_Impl1(pSrc, Dest, n_row, qWeights, QP_PROF_IMPL3);
end;

procedure QuantQ4_0_Impl4(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
begin
  QuantQ4_0_Impl1(pSrc, Dest, n_row, qWeights, QP_PROF_IMPL4);
end;

procedure QuantQ4_0_Impl5(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
begin
  QuantQ4_0_Impl1(pSrc, Dest, n_row, qWeights, QP_PROF_IMPL5);
end;

procedure DequantQ4_1(const Data: PByte; Dest: PSingle; n_row: Integer);
var
  pDest: PSingle;
  nb, i, j: Integer;
  B: PByte;
  D, m: Single;
  v0, v1: Integer;
begin
  nb := n_row div QK4_1;
  pDest := Dest;
  B := Data;
  for i := 0 to nb - 1 do
  begin
    // 1. Lecture de l'échelle d et du minimum m (FP16 → FP32)
    D := FP16ToFP32(PWord(B)^);
    Inc(B, 2);
    m := FP16ToFP32(PWord(B)^);
    Inc(B, 2);
    // 2. Dé-packing et déquantisation : x = d * q + m
    for j := 0 to 15 do // (QK4_1 div 2) - 1
    begin
      v0 := B[j] and $0F;
      v1 := B[j] shr 4;
      pDest[j] := v0 * D + m;
      pDest[j + 16] := v1 * D + m;
    end;
    Inc(pDest, QK4_1);
    Inc(B, 16);
  end;
end;

procedure QuantQ4_1_Ref(pSrc: PSingle; Dest: PByte; n_row: Integer);
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
    minVal := pSrc[0];
    maxVal := pSrc[0];

    // 1. Recherche min/max du bloc
    for j := 0 to QK4_1 - 1 do
    begin
      if pSrc[j] < minVal then
        minVal := pSrc[j];
      if pSrc[j] > maxVal then
        maxVal := pSrc[j];
    end;

    // 2. Calcul de l'échelle : d = (max - min) / 15
    D := Single((maxVal - minVal) / 15.0);
    if D <> 0.0 then
      id := Single(1.0 / D)
    else
      id := 0.0;

    pBlock^.D := FP32ToFP16(D);
    pBlock^.m := FP32ToFP16(minVal);

    // 3. Quantification : x = (src - min) * id, arrondi à +0.5
    for j := 0 to 15 do
    begin
      x0 := Single((pSrc[j] - minVal) * id);
      x1 := Single((pSrc[16 + j] - minVal) * id);
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
    Inc(pSrc, QK4_1);
    Inc(pBlock);
  end;
end;

procedure QuantQ4_1_Impl1(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil; iQk: Integer = QP_PROF_IMPL1);
var
  nb, ib, j: Integer;
  D, min_val: Single;
  pBlock: PBlockQ4_1;
  weights: array [0 .. QK4_1 - 1] of Single;
  LLq, Laux: array [0 .. QK4_1 - 1] of Byte;
  cfgQK: PQuantPreset;
begin
  Assert(iQk >= 0);
  Assert(n_row mod QK4_1 = 0);
  cfgQK := cfg.ggmlReg.GetPPreset(GGML_TYPE_Q4_1, iQk);
  nb := n_row div QK4_1;
  pBlock := PBlockQ4_1(Dest);

  for ib := 0 to nb - 1 do
  begin
    FillWeights(pSrc, qWeights, @weights[0], QK4_1, cfgQK.RmseType, False);

    // 3. Optimisation conjointe Scale + Min
    D := MakeQkx2Quants(QK4_1, 15, pSrc, @weights[0], @LLq[0], min_val, @Laux[0], -cfgQK.rmin, cfgQK.Rdelta,
      cfgQK.nstep, cfgQK.UseMAD);

    pBlock^.D := FP32ToFP16(D);
    pBlock^.m := FP32ToFP16(-min_val); // GGML stocke -min pour éviter les négatifs ; on stocke le min réel

    // 4. Packing 4-bit (interleaving)
    for j := 0 to 15 do
      pBlock^.qs[j] := LLq[j] or (LLq[j + 16] shl 4);

    Inc(pBlock);
    Inc(pSrc, QK4_1);
    if qWeights <> nil then
      Inc(qWeights, QK4_1);
  end;
end;

procedure QuantQ4_1_Impl2(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
begin
  QuantQ4_1_Impl1(pSrc, Dest, n_row, qWeights, QP_PROF_IMPL2);
end;

procedure QuantQ4_1_Impl3(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
begin
  QuantQ4_1_Impl1(pSrc, Dest, n_row, qWeights, QP_PROF_IMPL3);
end;

procedure QuantQ4_1_Impl4(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
begin
  QuantQ4_1_Impl1(pSrc, Dest, n_row, qWeights, QP_PROF_IMPL4);
end;


procedure QuantQ4_1_Impl5(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
begin
  QuantQ4_1_Impl1(pSrc, Dest, n_row, qWeights, QP_PROF_IMPL5);
end;


end.
