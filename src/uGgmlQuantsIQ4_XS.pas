unit uGgmlQuantsIQ4_XS;

{ IQ4_XS
  ntry  = cfgQK.Nstep    : grille d'echelle par sous-bloc (pass 1)
  nFam  = cfgQK.QpNStep  : 1 = miroir seul (comme le C), 2 = miroir + directe
  (le C ne teste JAMAIS la famille du seed :
  id0 = 127/max_val, et a itry=0 il obtient -id0)
  RLS   = cfgQK.QcIter   : rayon de recherche exacte de ls (pass 2), 0..4
  0 = desactive (comportement type C)

  avec RLS = 0 :
  le pass 2 utilise dDec := FP16ToFP32(pBlock^.d) (l'echelle reellement
  decodee) au lieu du d pre-FP16 utilise par le C. }

interface

uses
  SysUtils, Classes, uGGMLTypes, uGGMLConstants, uGGMLQuantUtils, uMath,
  uAppConfig, uGgmlQuantsFP16, uGgmlQuantsIQ4nl;

{$B-}
{$R-}
{$POINTERMATH ON}
{$J-}
{$O+}
{$ALIGN 8}
procedure DequantIQ4_XS(const Data: PByte; Dest: PSingle; n_row: Integer);

// Reference deterministe (poids internes x^2, ntry = 7, imatrix ignoree)
procedure QuantIQ4_XS_Ref(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);

// Optimisation : poids = cfg.RmseType, ntry/nFam/RLS = preset
procedure QuantIQ4_XS_Impl1(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil; iQk: Integer = QP_PROF_IMPL1);
procedure QuantIQ4_XS_Impl2(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
procedure QuantIQ4_XS_Impl3(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
procedure QuantIQ4_XS_Impl4(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
procedure QuantIQ4_XS_Impl5(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);

implementation

const
  IQ4XS_NTRY_C = 7; // ntry fige du C (quantize_iq4_xs)
  IQ4XS_NB = QK_K div 32; // 8 sous-blocs par super-bloc
  IQ4XS_NTRY_MAX = 24; // au-dela : plateau demontre (runs 24/28/32)

  // DEQUANTISATION
procedure DequantIQ4_XS(const Data: PByte; Dest: PSingle; n_row: Integer);
var
  nb, i, ib, j, ls: Integer;
  pBlock: PBlockIQ4_XS;
  d, dl: Single;
  qs: PByte;
begin
  nb := n_row div QK_K;
  pBlock := PBlockIQ4_XS(Data);

  for i := 0 to nb - 1 do
  begin
    d := FP16ToFP32(pBlock^.d);
    qs := @pBlock^.qs[0];

    for ib := 0 to IQ4XS_NB - 1 do
    begin
      ls := ((pBlock^.scales_l[ib div 2] shr (4 * (ib and 1))) and $0F) or
        (((pBlock^.scales_h shr (2 * ib)) and $03) shl 4);
      dl := d * (ls - 32);

      for j := 0 to 15 do
      begin
        Dest[j] := dl * kvalues_iq4nl[qs[j] and $0F];
        Dest[j + 16] := dl * kvalues_iq4nl[qs[j] shr 4];
      end;
      Inc(Dest, 32);
      Inc(qs, 16);
    end;
    Inc(pBlock);
  end;
end;

// REF : (sans qWeights (imatrix))
procedure QuantIQ4_XS_Ref(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
var
  nb, i, ib, j, l, itry: Integer;
  pBlock: PBlockIQ4_XS;
  LLa: array [0 .. QK_K - 1] of Byte;
  scales: array [0 .. IQ4XS_NB - 1] of Single;
  weights, wx: array [0 .. 31] of Single;
  xb: PSingle;
  Lb: PByte;
  d, id, dl, idl, sumqx, sumq2, best, amax, abs_d, max_val, v, max_scale, abs_max_scale: Single;
begin
  nb := n_row div QK_K;
  pBlock := PBlockIQ4_XS(Dest);

  for i := 0 to nb - 1 do
  begin
    FillChar(pBlock^.qs[0], QK_K div 2, 0);
    pBlock^.scales_h := 0;
    FillChar(pBlock^.scales_l[0], SizeOf(pBlock^.scales_l), 0);

    max_scale := 0.0;
    abs_max_scale := 0.0;
    for ib := 0 to IQ4XS_NB - 1 do
    begin
      xb := @pSrc[ib * 32];
      Lb := @LLa[ib * 32]; // utilise seulement si amax >= GROUP_EPS ; le pass 2 reecrit tout

      amax := 0.0;
      max_val := 0.0;
      for j := 0 to 31 do
      begin
        v := Abs(xb[j]);
        if v > amax then
        begin
          amax := v;
          max_val := xb[j];
        end;
      end;

      if amax < GROUP_EPS then
      begin
        scales[ib] := 0.0;
        Continue;
      end;

      for j := 0 to 31 do
      begin
        weights[j] := xb[j] * xb[j]; // C : quant_weights = NULL -> x^2
        if (weights[j] < 0.0) or IsInfinite(weights[j]) or IsNan(weights[j]) then
          weights[j] := 1.0;
      end;
      for j := 0 to 31 do
        wx[j] := weights[j] * xb[j]; // invariant en itry

      d := -max_val / kvalues_iq4nl[0];
      id := 0.0;
      if d <> 0.0 then
        id := 1.0 / d;

      sumqx := 0.0;
      sumq2 := 0.0;
      for j := 0 to 31 do
      begin
        l := BestIndexInt8(16, @kvalues_iq4nl[0], id * xb[j]);
        Lb[j] := Byte(l);
        sumqx := sumqx + wx[j] * kvalues_iq4nl[l];
        sumq2 := sumq2 + weights[j] * kvalues_iq4nl[l] * kvalues_iq4nl[l];
      end;
      if sumq2 > 0.0 then
        d := sumqx / sumq2
      else
        d := 0.0;
      best := d * sumqx;

      for itry := -IQ4XS_NTRY_C to IQ4XS_NTRY_C do
      begin
        id := (itry + kvalues_iq4nl[0]) / max_val;
        sumqx := 0.0;
        sumq2 := 0.0;
        for j := 0 to 31 do
        begin
          l := BestIndexInt8(16, @kvalues_iq4nl[0], id * xb[j]);
          sumqx := sumqx + wx[j] * kvalues_iq4nl[l];
          sumq2 := sumq2 + weights[j] * kvalues_iq4nl[l] * kvalues_iq4nl[l];
        end;
        if (sumq2 > 0.0) and (sumqx * sumqx > best * sumq2) then
        begin
          d := sumqx / sumq2;
          best := d * sumqx;
        end;
      end;

      scales[ib] := d;
      abs_d := Abs(d);
      if abs_d > abs_max_scale then
      begin
        abs_max_scale := abs_d;
        max_scale := d;
      end;
    end;

    d := -max_scale / 32.0;
    pBlock^.d := FP32ToFP16(d);
    id := 0.0;
    if d <> 0.0 then
      id := 1.0 / d;

    for ib := 0 to IQ4XS_NB - 1 do
    begin
      l := NearestInt(id * scales[ib]);
      l := ClampInt(l, -32, 31);
      dl := d * l;
      idl := 0.0;
      if dl <> 0.0 then
        idl := 1.0 / dl;

      xb := pSrc + ib * 32;
      Lb := @LLa[ib * 32];
      for j := 0 to 31 do
        Lb[j] := Byte(BestIndexInt8(16, @kvalues_iq4nl[0], idl * xb[j]));

      l := l + 32; // [0..63]
      if (ib and 1) = 0 then
        pBlock^.scales_l[ib div 2] := Byte(l and $0F)
      else
        pBlock^.scales_l[ib div 2] := Byte(pBlock^.scales_l[ib div 2] or ((l and $0F) shl 4));
      pBlock^.scales_h := Word(pBlock^.scales_h or ((l shr 4) shl (2 * (ib and 7))));
    end;

    for ib := 0 to (QK_K div 32) - 1 do
      for j := 0 to 15 do
        pBlock^.qs[16 * ib + j] := Byte(LLa[32 * ib + j] or (LLa[32 * ib + 16 + j] shl 4));

    Inc(pSrc, QK_K);
    Inc(pBlock);
  end;
end;

procedure QuantIQ4_XS_Impl1(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil; iQk: Integer = QP_PROF_IMPL1);
var
  nb, isb, ib, j, l, k, itry, fam, ntry, nFam: Integer;
  pBlock: PBlockIQ4_XS;
  LLa: array [0 .. QK_K - 1] of Byte;
  scales: array [0 .. IQ4XS_NB - 1] of Single;
  wx: array [0 .. 31] of Single;
  weights: array [0 .. QK_K - 1] of Single;
  xb, ww: PSingle;
  Lb: PByte;
  d, dDec, id, idl, idUse, dl: Single;
  sumqx, sumq2, best, amax, abs_d, max_val, v, max_scale, abs_max_scale: Single;
  cfgQK: PQuantPreset;
begin
  Assert(iQk >= 0);
  Assert(n_row mod QK_K = 0);
  cfgQK := cfg.ggmlReg.GetPPreset(GGML_TYPE_IQ4_XS, iQk);

  // reglages (tous dans le preset, donc modifiables sans recompiler)
  ntry := cfgQK.Nstep;
  if ntry < 0 then
    ntry := IQ4XS_NTRY_C; // preset zero (INI absent) -> valeur du C, pas 0
  if ntry > IQ4XS_NTRY_MAX then
    ntry := IQ4XS_NTRY_MAX; // plateau : au-dela, on ne fait que payer le temps

  nFam := cfgQK.QpNStep; // 1 = miroir seul (C), >= 2 = miroir + directe  1..2
  if nFam < 1 then
    nFam := 1
  else if nFam > 2 then
    nFam := 2;

  nb := n_row div QK_K;
  pBlock := PBlockIQ4_XS(Dest);

  for isb := 0 to nb - 1 do
  begin
    FillChar(pBlock^.qs[0], QK_K div 2, 0);
    pBlock^.scales_h := 0;
    FillChar(pBlock^.scales_l[0], SizeOf(pBlock^.scales_l), 0);
    FillWeights(pSrc, qWeights, @weights[0], QK_K, cfgQK.RmseType, True);

    // pass 1 : echelle optimale par sous-bloc
    max_scale := 0.0;
    abs_max_scale := 0.0;
    for ib := 0 to IQ4XS_NB - 1 do
    begin
      xb := @pSrc[ib * 32];
      ww := @weights[ib * 32];
      Lb := @LLa[ib * 32];

      amax := 0.0;
      max_val := 0.0;
      for j := 0 to 31 do
      begin
        v := Abs(xb[j]);
        if v > amax then
        begin
          amax := v;
          max_val := xb[j];
        end;
      end;

      if amax < GROUP_EPS then
      begin
        scales[ib] := 0.0;
        Continue; // le pass 2 reecrit Lb (idl = 0)
      end;

      for j := 0 to 31 do
        wx[j] := ww[j] * xb[j]; // invariant en itry

      if ntry > 0 then
        d := -max_val / kvalues_iq4nl[0]
      else
        d := max_val / kvalues_iq4nl[0];

      id := 0.0;
      if d <> 0.0 then
        id := 1.0 / d;

      sumqx := 0.0;
      sumq2 := 0.0;
      for j := 0 to 31 do
      begin
        l := BestIndexInt8(16, @kvalues_iq4nl[0], id * xb[j]);
        Lb[j] := Byte(l);
        sumqx := sumqx + wx[j] * kvalues_iq4nl[l];
        sumq2 := sumq2 + ww[j] * kvalues_iq4nl[l] * kvalues_iq4nl[l];
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
          id := (itry + kvalues_iq4nl[0]) / max_val; // miroir (ce que fait le C)
          if fam = 1 then
            id := -id; // directe : couvre le seed +/- 0,79 % par pas (absent du C)
          sumqx := 0.0;
          sumq2 := 0.0;
          for j := 0 to 31 do
          begin
            l := BestIndexInt8(16, @kvalues_iq4nl[0], id * xb[j]);
            sumqx := sumqx + wx[j] * kvalues_iq4nl[l];
            sumq2 := sumq2 + ww[j] * kvalues_iq4nl[l] * kvalues_iq4nl[l];
          end;
          if (sumq2 > 0.0) and (sumqx * sumqx > best * sumq2) then
          begin
            d := sumqx / sumq2;
            best := d * sumqx;
          end;
        end;
      end;

      scales[ib] := d;
      abs_d := Abs(d);
      if abs_d > abs_max_scale then
      begin
        abs_max_scale := abs_d;
        max_scale := d;
      end;
    end;

    // pass 2 : ls choisi sur l'erreur REELLE, avec l'echelle decodee
    d := -max_scale / 32.0;
    pBlock^.d := FP32ToFP16(d);
    dDec := FP16ToFP32(pBlock^.d); // <-- ce que le decodeur multiplie vraiment

    idUse := 0.0;
    if dDec <> 0.0 then
      idUse := 1.0 / dDec;

    for ib := 0 to IQ4XS_NB - 1 do
    begin
      xb := @pSrc[ib * 32];
      ww := @weights[ib * 32];
      Lb := @LLa[ib * 32];

      l := NearestInt(idUse * scales[ib]);
      l := ClampInt(l, -32, 31);

      dl := dDec * Single(l);
      idl := 0.0;
      if dl <> 0.0 then
        idl := 1.0 / dl; // dl = 0 -> idl = 0 -> tous les poids a l'indice de 0
      for j := 0 to 31 do
        Lb[j] := Byte(BestIndexInt8(16, @kvalues_iq4nl[0], idl * xb[j]));

      k := l + 32; // [0..63]
      if (ib and 1) = 0 then
        pBlock^.scales_l[ib div 2] := Byte(k and $0F)
      else
        pBlock^.scales_l[ib div 2] := Byte(pBlock^.scales_l[ib div 2] or ((k and $0F) shl 4));
      pBlock^.scales_h := Word(pBlock^.scales_h or ((k shr 4) shl (2 * (ib and 7))));
    end;

    for ib := 0 to (QK_K div 32) - 1 do
      for j := 0 to 15 do
        pBlock^.qs[16 * ib + j] := Byte(LLa[32 * ib + j] or (LLa[32 * ib + 16 + j] shl 4));

    Inc(pSrc, QK_K);
    Inc(pBlock);
    if qWeights <> nil then
      Inc(qWeights, QK_K);
  end;
end;

procedure QuantIQ4_XS_Impl2(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
begin
  QuantIQ4_XS_Impl1(pSrc, Dest, n_row, qWeights, QP_PROF_IMPL2);
end;

procedure QuantIQ4_XS_Impl3(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
begin
  QuantIQ4_XS_Impl1(pSrc, Dest, n_row, qWeights, QP_PROF_IMPL3);
end;

procedure QuantIQ4_XS_Impl4(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
begin
  QuantIQ4_XS_Impl1(pSrc, Dest, n_row, qWeights, QP_PROF_IMPL4);
end;

procedure QuantIQ4_XS_Impl5(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
begin
  QuantIQ4_XS_Impl1(pSrc, Dest, n_row, qWeights, QP_PROF_IMPL5);
end;

end.
