unit uGgmlQuantsMXFP4;

interface

uses
  SysUtils, Classes, uMath, Math, uGGMLTypes, uGGMLConstants, uGgmlQuantsFP16, uAppConfig;

{$B-}
{$R-}
{$POINTERMATH ON}
{$J-}
{$O+}
{$ALIGN 8}
// DEQUANTISATION MXFP4 (pas de preset : format OCP déterministe)
procedure DequantMXFP4(const Data: PByte; Dest: PSingle; n_row: Integer);

// QUANTISATION MXFP4 (Reference déterministe - unique, comme quantize_row_mxfp4_ref)
// ntry : nombre d'itérations de la grille d'ajustement de l'exposant E8M0 (0..3)
procedure QuantMXFP4_Ref(pSrc: PSingle; Dest: PByte; n_row: Integer; ntry: Integer = 0);

// QUANTISATION MXFP4 (Optimisation RMSE / pondération)
// qWeights : poids externes optionnels (mode expert).
// Sans qWeights : pondération interne w = x² (équivalent C rmse_type = 1)
// + facteur sqrt(2*sigma2 + x²), comme la branche "weights" du C.
procedure QuantMXFP4_Impl1(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil; iQk: Integer = QP_PROF_IMPL1);
procedure QuantMXFP4_Impl2(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
procedure QuantMXFP4_Impl3(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
procedure QuantMXFP4_Impl4(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
procedure QuantMXFP4_Impl5(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);

implementation

// E8M0 -> FP32 : 2^(e - 127)  (bit implicite = 1, exposant non biaisé = e - 127)
function E8M0ToFP32a(e: Byte): Single;
begin
  // Result := Exp2(Single(e) - 127.0);
  if e = 0 then
    Exit(0.0);
  Result := Exp((e - 127) * Ln(2.0)); // Compatibilité Delphi < 10.3
end;

function E8M0ToFP32(e: Byte): Single;
var
  I: Cardinal;
begin
  // if e = 0 then  Exit(0.0);
  I := Cardinal(e) shl 23; // bit-exact 2^(e-127)
  Move(I, Result, 4);
end;

// floor(log2(x)) exact, sans virgule flottante. Tue les divergences log2f(float) vs Log2(double)
// aux frontieres de puissances de 2 (reelles : amax = nextafter(2^k) vers le bas).
function FloorLog2F(x: Single): Integer;
var
  U: Cardinal;
begin
  Move(x, U, 4);
  Result := Integer((U shr 23) and $FF) - 127; // denormal -> -127 (gere par l'appelant)
end;

// Meilleur index FP4 pour (valeur, échelle) : minimisation |kvalues[i]*e - x|
// (équivalent C best_index_mxfp4)
function BestIndexMXFP4(x, e: Single): Integer;
var
  I: Integer;
  best_err, err: Single;
begin
  Result := 0;
  best_err := Abs(kvalues_mxfp4[0] * e - x);
  for I := 1 to 15 do
  begin
    err := Abs(kvalues_mxfp4[I] * e - x);
    if err < best_err then
    begin
      Result := I;
      best_err := err;
    end;
  end;
end;

// ============================================================================
procedure DequantMXFP4(const Data: PByte; Dest: PSingle; n_row: Integer);
var
  nb, ib, j: Integer;
  pBlock: PBlockMXFP4;
  d: Single;
begin
  nb := n_row div QK_MXFP4;
  pBlock := PBlockMXFP4(Data);

  for ib := 0 to nb - 1 do
  begin
    d := E8M0ToFP32(pBlock^.e);
    for j := 0 to QK_MXFP4 div 2 - 1 do
    begin
      Dest[j] := Single(kvalues_mxfp4[pBlock^.qs[j] and $0F]) * d;
      Dest[j + QK_MXFP4 div 2] := Single(kvalues_mxfp4[pBlock^.qs[j] shr 4]) * d;
    end;
    Inc(Dest, QK_MXFP4);
    Inc(pBlock);
  end;
end;

procedure QuantMXFP4_Ref(pSrc: PSingle; Dest: PByte; n_row: Integer; ntry: Integer = 0);
var
  nb, ib, j, e: Integer;
  pBlock: PBlockMXFP4;
  amax, v, d: Single;
  x1, x2: Byte;
begin
  nb := n_row div QK_MXFP4;
  pBlock := PBlockMXFP4(Dest);
  for ib := 0 to nb - 1 do
  begin
    amax := 0.0;
    for j := 0 to QK_MXFP4 - 1 do
    begin
      v := Abs(pSrc[j]);
      if v > amax then
        amax := v;
    end;

    if amax > 0.0 then
      e := FloorLog2F(amax) - 2 + 127 // == floorf(log2f(amax)) - 2 + 127, sans FP
    else
      e := 0;
    if e < 0 then
      e := 0
    else if e > 254 then
      e := 254; // 255 = +Inf, interdit ; AVANT le cast

    pBlock^.e := Byte(e);
    d := E8M0ToFP32(Byte(e));
    for j := 0 to QK_MXFP4 div 2 - 1 do
    begin
      x1 := Byte(BestIndexMXFP4(pSrc[j], d));
      x2 := Byte(BestIndexMXFP4(pSrc[j + QK_MXFP4 div 2], d));
      pBlock^.qs[j] := x1 or (x2 shl 4);
    end;
    Inc(pSrc, QK_MXFP4);
    Inc(pBlock);
  end;
end;

procedure QuantMXFP4_Impl1(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil; iQk: Integer = QP_PROF_IMPL1);
type
  TQ32 = array [0 .. QK_MXFP4 - 1] of Byte;
var
  ib, j, nb, delta, ntry, RmseType, e_ref, e_best, e_cand: Integer;
  pBlock: PBlockMXFP4;
  amax, v, sum2, sigma2, w, err, best_err: Single;
  weights: array [0 .. QK_MXFP4 - 1] of Single;
  Lbest, Lcur: TQ32;
  cfgMX: PQuantPreset;

  // Erreur quadratique ponderee d'un candidat + quants associes (1 seul best_index par element)
  function Eval(e: Byte; out L: TQ32): Single;
  var
    d, dv: Single;
    k: Integer;
  begin
    d := E8M0ToFP32(e); // bit-exact, 0 division
    Result := 0.0;
    for k := 0 to QK_MXFP4 - 1 do
    begin
      L[k] := Byte(BestIndexMXFP4(pSrc[k], d));
      dv := kvalues_mxfp4[L[k]] * d - pSrc[k];
      Result := Result + weights[k] * dv * dv;
    end;
    if uMath.IsNan(Result) or uMath.IsInfinite(Result) then
      Result := 1E30;
  end;

begin
  cfgMX := cfg.ggmlReg.GetPPreset(GGML_TYPE_MXFP4, iQk);
  RmseType := cfgMX.RmseType;
  ntry := cfgMX.Nstep;
  if ntry < 0 then
    ntry := 0;
  if ntry > 6 then
    ntry := 6; // +-6 octaves : au-dela, sans interet
  if (RmseType < 1) or (RmseType > 4) then
    RmseType := 1; // 0 = poids nuls -> interdit

  nb := n_row div QK_MXFP4;
  pBlock := PBlockMXFP4(Dest);

  for ib := 0 to nb - 1 do
  begin
    amax := 0.0;
    sum2 := 0.0;
    for j := 0 to QK_MXFP4 - 1 do
    begin
      v := Abs(pSrc[j]);
      if v > amax then
        amax := v;
      sum2 := sum2 + Sqr(pSrc[j]);
    end;
    sigma2 := 2.0 * sum2 / QK_MXFP4;

    if amax < GROUP_EPS then
    begin
      pBlock^.e := 0;
      FillChar(pBlock^.qs[0], QK_MXFP4 div 2, 0);
      Inc(pSrc, QK_MXFP4);
      Inc(pBlock);
      if qWeights <> nil then
        Inc(qWeights, QK_MXFP4);
      Continue;
    end;

    for j := 0 to QK_MXFP4 - 1 do
    begin
      if qWeights <> nil then
        w := qWeights[j] * Sqrt(sigma2 + Sqr(pSrc[j]))
      else
        case RmseType of
          1:
            w := 1.0;
          2:
            w := Sqrt(Abs(pSrc[j]));
          3:
            w := Abs(pSrc[j]);
          4:
            w := Sqr(pSrc[j]);
        else
          w := 1.0;
        end;
      if uMath.IsNan(w) or uMath.IsInfinite(w) or (w < 0.0) then
        w := 1.0;
      weights[j] := w; // * Sqrt(sigma2 + Sqr(pSrc[j]));
    end;

    e_ref := FloorLog2F(amax) - 2 + 127;
    if e_ref < 0 then
      e_ref := 0
    else if e_ref > 254 then
      e_ref := 254;

    e_best := e_ref;
    best_err := Eval(Byte(e_ref), Lbest);
    for delta := -ntry to ntry do
    begin
      if delta = 0 then
        Continue;
      e_cand := ClampInt(e_ref + delta, 0, 254); // base FIXE (ne pas deriver e_ref)
      if e_cand = e_ref then
        Continue;
      err := Eval(Byte(e_cand), Lcur);
      if err < best_err then // '<' strict -> tie = Ref
      begin
        best_err := err;
        e_best := e_cand;
        Lbest := Lcur;
      end;
    end;

    pBlock^.e := Byte(e_best); // JAMAIS rederive via Log2(best_d)
    for j := 0 to QK_MXFP4 div 2 - 1 do
      pBlock^.qs[j] := Lbest[j] or (Lbest[j + QK_MXFP4 div 2] shl 4);

    Inc(pSrc, QK_MXFP4);
    Inc(pBlock);
    if qWeights <> nil then
      Inc(qWeights, QK_MXFP4);
  end;
end;

procedure QuantMXFP4_Impl2(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
begin
  QuantMXFP4_Impl1(pSrc, Dest, n_row, qWeights, QP_PROF_IMPL2);
end;

procedure QuantMXFP4_Impl3(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
begin
  QuantMXFP4_Impl1(pSrc, Dest, n_row, qWeights, QP_PROF_IMPL3);
end;

procedure QuantMXFP4_Impl4(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
begin
  QuantMXFP4_Impl1(pSrc, Dest, n_row, qWeights, QP_PROF_IMPL4);
end;


procedure QuantMXFP4_Impl5(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
begin
  QuantMXFP4_Impl1(pSrc, Dest, n_row, qWeights, QP_PROF_IMPL5);
end;


end.
