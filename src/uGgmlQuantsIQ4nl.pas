unit uGgmlQuantsIQ4nl;

interface

uses
  SysUtils, Classes, uMath, uGGMLTypes, uGGMLConstants, uGGMLQuantUtils,
  uGgmlQuantsFP16, uAppConfig;

{$B-}
{$R-}
{$POINTERMATH ON}
{$J-}
{$O+}
{$ALIGN 8}

const
  kvalues_iq4nl: array [0 .. 15] of Int8 =
    (-127, -104, -83, -65, -49, -35, -22, -10, 1, 13, 25, 38, 53, 69, 89, 113);

  // mid[k] = (values[k] + values[k+1]) / 2
  IQ4NL_MID: array [0 .. 14] of Single = (
    -115.5, -93.5, -74.0, -57.0, -42.0, -28.5, -16.0, -4.5,
      7.0,  19.0,  31.5,  45.5,  61.0,  79.0, 101.0
  );

function BestIndexInt8(n: Integer; const Val: PShortInt; x: Single): Integer;
function BestIndexIQ4NL(x: Single): Integer;

procedure DequantIQ4_NL(const Data: PByte; Dest: PSingle; n_row: Integer);

// Reference deterministe : quantize_row_iq4_nl_ref, ntry = -1, imatrix ignoree.
procedure QuantIQ4_NL_Ref(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);

// Implementation alignee sur quantize_iq4_nl / quantize_row_iq4_nl_impl.
// Si qWeights <> nil, il est traite comme une imatrix C :
//   weight[j] = qWeights[j] * sqrt(sigma2 + x[j]^2)
// Si qWeights = nil, comportement selon cfg/RmseType/FillWeights.
procedure QuantIQ4_NL_Impl1(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil;
  iQk: Integer = QP_PROF_IMPL1; ntryOvr: Integer = 0);
procedure QuantIQ4_NL_Impl2(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
procedure QuantIQ4_NL_Impl3(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
procedure QuantIQ4_NL_Impl4(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
procedure QuantIQ4_NL_Impl5(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);

implementation

const
  IQ4NL_NTRY_C = 7;
  IQ4NL_NTRY_MAX = 24;

function BestIndexInt8(n: Integer; const Val: PShortInt; x: Single): Integer;
var
  ml, mu, mav: Integer;
begin
  if x <= Val[0] then
    Exit(0);
  if x >= Val[n - 1] then
    Exit(n - 1);

  ml := 0;
  mu := n - 1;
  while mu - ml > 1 do
  begin
    mav := (ml + mu) div 2;
    if x < Val[mav] then
      mu := mav
    else
      ml := mav;
  end;

  if mu = 0 then
    Result := 0
  else if (x - Val[mu - 1]) < (Val[mu] - x) then
    Result := mu - 1
  else
    Result := mu;
end;

// Equivalent au nouveau C : best_index_iq4nl(mid, x)
function BestIndexIQ4NL(x: Single): Integer;
var
  l, k: Integer;
begin
  l := 15;
  for k := 0 to High(IQ4NL_MID) do
    if x < IQ4NL_MID[k] then
      Dec(l);
  Result := l;
end;

procedure DequantIQ4_NL(const Data: PByte; Dest: PSingle; n_row: Integer);
var
  nb, ib, j: Integer;
  pBlock: PBlockIQ4_NL;
  d: Single;
begin
  nb := n_row div QK4_NL;
  pBlock := PBlockIQ4_NL(Data);

  for ib := 0 to nb - 1 do
  begin
    d := FP16ToFP32(pBlock^.d);
    for j := 0 to QK4_NL div 2 - 1 do
    begin
      Dest[j] := d * kvalues_iq4nl[pBlock^.qs[j] and $0F];
      Dest[j + QK4_NL div 2] := d * kvalues_iq4nl[pBlock^.qs[j] shr 4];
    end;
    Inc(Dest, QK4_NL);
    Inc(pBlock);
  end;
end;

// ---------------------------------------------------------------------------
// REF : equivalent a quantize_row_iq4_nl_ref
// ntry = -1
// qWeights = ignoree
// ---------------------------------------------------------------------------
procedure QuantIQ4_NL_Ref(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
var
  nb, ib, j, LIdx: Integer;
  pBlock: PBlockIQ4_NL;
  d, id, sumqx, sumq2, amax, max_val, v, q, w: Single;
  L: array [0 .. QK4_NL - 1] of Byte;
  weights: array [0 .. QK4_NL - 1] of Single;
begin
  Assert(n_row mod QK4_NL = 0);

  nb := n_row div QK4_NL;
  pBlock := PBlockIQ4_NL(Dest);

  for ib := 0 to nb - 1 do
  begin
    FillChar(pBlock^.qs[0], QK4_NL div 2, 0);
    pBlock^.d := FP32ToFP16(0.0);
    FillChar(L[0], SizeOf(L), 0);

    amax := 0.0;
    max_val := 0.0;
    for j := 0 to QK4_NL - 1 do
    begin
      v := Abs(pSrc[j]);
      if v > amax then
      begin
        amax := v;
        max_val := pSrc[j];
      end;
    end;

    d := 0.0;

    if amax >= GROUP_EPS then
    begin
      // C ref : quant_weights == NULL -> weight = x*x
      for j := 0 to QK4_NL - 1 do
      begin
        w := pSrc[j] * pSrc[j];
        if (w < 0.0) or IsInfinite(w) or IsNan(w) then
          w := 1.0;
        weights[j] := w;
      end;

      // ntry = -1 => d = max / values[0]
      d := max_val / Single(kvalues_iq4nl[0]);
      id := 0.0;
      if d <> 0.0 then
        id := 1.0 / d;

      for j := 0 to QK4_NL - 1 do
        L[j] := Byte(BestIndexIQ4NL(id * pSrc[j]));

      sumqx := 0.0;
      sumq2 := 0.0;

      for j := 0 to QK4_NL - 1 do
      begin
        q := Single(kvalues_iq4nl[L[j]]);
        w := weights[j];
        sumqx := sumqx + w * q * pSrc[j];
        sumq2 := sumq2 + w * q * q;
      end;

      if sumq2 > 0.0 then
        d := sumqx / sumq2
      else
        d := 0.0;

      // ntry <= 0 : le C ne recompose pas L avec le scale final.
      // On garde L issu de l'id initial.
    end;

    if IsNan(d) or IsInfinite(d) then
      d := 0.0;

    pBlock^.d := FP32ToFP16(d);

    for j := 0 to 15 do
      pBlock^.qs[j] := Byte(L[j] or (L[j + 16] shl 4));

    Inc(pSrc, QK4_NL);
    Inc(pBlock);
  end;
end;

// ---------------------------------------------------------------------------
// IMPL : equivalent a quantize_iq4_nl avec imatrix, ntry = 7 par defaut.
// ---------------------------------------------------------------------------
procedure QuantIQ4_NL_Impl1(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil;
  iQk: Integer = QP_PROF_IMPL1; ntryOvr: Integer = 0);
var
  nb, ib, j, LIdx, itry, fam, ntry, nFam: Integer;
  pBlock: PBlockIQ4_NL;
  d, id, sumqx, sumq2, best, amax, max_val, v, q, w, sigma2: Single;
  L: array [0 .. QK4_NL - 1] of Byte;
  weights: array [0 .. QK4_NL - 1] of Single;
  cfgQK: PQuantPreset;
begin
  Assert(iQk >= 0);
  Assert(n_row mod QK4_NL = 0);

  cfgQK := cfg.ggmlReg.GetPPreset(GGML_TYPE_IQ4_NL, iQk);

  ntry := cfgQK.Nstep;
  if ntryOvr <> 0 then
    ntry := ntryOvr;

  if ntry < 0 then
    ntry := IQ4NL_NTRY_C;
  if ntry > IQ4NL_NTRY_MAX then
    ntry := IQ4NL_NTRY_MAX;

  nFam := cfgQK.QpNStep;
  if nFam < 1 then
    nFam := 1
  else if nFam > 2 then
    nFam := 2;

  nb := n_row div QK4_NL;
  pBlock := PBlockIQ4_NL(Dest);

  for ib := 0 to nb - 1 do
  begin
    FillChar(pBlock^.qs[0], QK4_NL div 2, 0);
    pBlock^.d := FP32ToFP16(0.0);
    FillChar(L[0], SizeOf(L), 0);

    // C : sigma2 = 2 * sum(x^2) / super_block_size
    sigma2 := 0.0;
    for j := 0 to QK4_NL - 1 do
      sigma2 := sigma2 + pSrc[j] * pSrc[j];
    sigma2 := sigma2 * (2.0 / QK4_NL);

    // Poids, avec semantique C si qWeights <> nil.
    if qWeights <> nil then
    begin
      for j := 0 to QK4_NL - 1 do
      begin
        w := qWeights[j] * Sqrt(sigma2 + pSrc[j] * pSrc[j]);

        // Garde-fou Delphi. Le C ne le fait pas toujours,
        // mais evite les NaN/Inf si imatrix invalide.
        if (w < 0.0) or IsNan(w) or IsInfinite(w) then
        begin
          w := pSrc[j] * pSrc[j];
          if (w < 0.0) or IsNan(w) or IsInfinite(w) then
            w := 1.0;
        end;

        weights[j] := w;
      end;
    end
    else
    begin
      // Compatibilité avec ton systeme de presets.
      // Si tu veux strictement le C sans imatrix, remplace ce bloc par :
      //   for j := 0 to QK4_NL - 1 do
      //     weights[j] := pSrc[j] * pSrc[j];
      FillWeights(pSrc, nil, @weights[0], QK4_NL, cfgQK.RmseType, True);
    end;

    amax := 0.0;
    max_val := 0.0;
    for j := 0 to QK4_NL - 1 do
    begin
      v := Abs(pSrc[j]);
      if v > amax then
      begin
        amax := v;
        max_val := pSrc[j];
      end;
    end;

    d := 0.0;

    if amax >= GROUP_EPS then
    begin
      if ntry > 0 then
        d := -max_val / Single(kvalues_iq4nl[0])
      else
        d := max_val / Single(kvalues_iq4nl[0]);

      id := 0.0;
      if d <> 0.0 then
        id := 1.0 / d;

      for j := 0 to QK4_NL - 1 do
        L[j] := Byte(BestIndexIQ4NL(id * pSrc[j]));

      sumqx := 0.0;
      sumq2 := 0.0;

      for j := 0 to QK4_NL - 1 do
      begin
        q := Single(kvalues_iq4nl[L[j]]);
        w := weights[j];
        sumqx := sumqx + w * q * pSrc[j];
        sumq2 := sumq2 + w * q * q;
      end;

      if sumq2 > 0.0 then
        d := sumqx / sumq2
      else
        d := 0.0;

      best := d * sumqx;

      for itry := -ntry to ntry do
      begin
        for fam := 0 to nFam - 1 do
        begin
          id := (Single(itry) + Single(kvalues_iq4nl[0])) / max_val;

          // Extension Pascal : famille directe.
          // Pour matcher exactement le C, force nFam := 1.
          if fam = 1 then
            id := -id;

          sumqx := 0.0;
          sumq2 := 0.0;

          for j := 0 to QK4_NL - 1 do
          begin
            LIdx := BestIndexIQ4NL(id * pSrc[j]);
            q := Single(kvalues_iq4nl[LIdx]);
            w := weights[j];

            sumqx := sumqx + w * q * pSrc[j];
            sumq2 := sumq2 + w * q * q;
          end;

          if (sumq2 > 0.0) and (sumqx * sumqx > best * sumq2) then
          begin
            d := sumqx / sumq2;
            best := d * sumqx;
          end;
        end;
      end;
    end;

    if IsNan(d) or IsInfinite(d) then
      d := 0.0;

    pBlock^.d := FP32ToFP16(d);

    // Comme le C : si ntry > 0, reencodage final avec d,
    // pas avec dDec = FP16ToFP32(FP32ToFP16(d)).
    if ntry > 0 then
    begin
      id := 0.0;
      if d <> 0.0 then
        id := 1.0 / d;

      for j := 0 to QK4_NL - 1 do
        L[j] := Byte(BestIndexIQ4NL(id * pSrc[j]));
    end;

    for j := 0 to 15 do
      pBlock^.qs[j] := Byte(L[j] or (L[j + 16] shl 4));

    Inc(pSrc, QK4_NL);
    Inc(pBlock);

    if qWeights <> nil then
      Inc(qWeights, QK4_NL);
  end;
end;

procedure QuantIQ4_NL_Impl2(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
begin
  QuantIQ4_NL_Impl1(pSrc, Dest, n_row, qWeights, QP_PROF_IMPL2);
end;

procedure QuantIQ4_NL_Impl3(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
begin
  QuantIQ4_NL_Impl1(pSrc, Dest, n_row, qWeights, QP_PROF_IMPL3);
end;

procedure QuantIQ4_NL_Impl4(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
begin
  QuantIQ4_NL_Impl1(pSrc, Dest, n_row, qWeights, QP_PROF_IMPL4);
end;

procedure QuantIQ4_NL_Impl5(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
begin
  QuantIQ4_NL_Impl1(pSrc, Dest, n_row, qWeights, QP_PROF_IMPL5);
end;

end.

