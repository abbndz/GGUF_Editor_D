unit uGgmlQuantsIQ2_XXS;

{ IQ2_XXS (2.0625 bpw) — déquantisation + quantisation
  Bloc (TBlockIQ2_XXS dans uGGMLConstants) = 66 octets pour QK_K = 256 :
  d  :  2 octets  FP16 (échelle globale, AUCUN fudge factor en IQ2_XXS)
  qs : 64 octets = 32 Word -> 2 Word par groupe de 8 valeurs (32 bits / 8 valeurs)

  Un groupe de 8 valeurs (1 aux8 + 1 aux16) occupe 32 bits (little endian) :
  bits  0.. 7 : index de grille IQ2XXS_GRID (8 bits, 256 grilles)
  bits  8..14 : 7 bits de signe du groupe
  bits 15..28 : 7 bits de signe du groupe suivant
  bits 29..32 : échelle 4 bits des 4 octets de signes (4 sous-groupes de 32)
  => octet 0,1 = qs[i] ; octet 2,3 = qs[i+1]
  aux8[0..3] = 4 index de grille   (premier uint32)
  aux8[4..7] = 4 octets de signes  (second uint32)
  db = d * (0.5 + (aux32[1] shr 28)) * 0.25 }

interface

uses
  SysUtils, Math, Generics.Defaults, Generics.Collections,
  uGGMLTypes, uGGMLConstants, uGgmlQuantsFP16, uGgmlQuantsIQGRIDs, uAppConfig;

{$POINTERMATH ON}
{$O+}
{$ALIGN 8}
procedure DequantIQ2_XXS(const Data: PByte; Dest: PSingle; n_row: Integer);
procedure QuantIQ2_XXS_Ref(pSrc: PSingle; Dest: PByte; n_row: Integer);
procedure QuantIQ2_XXS_Impl1(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil; iQk: Integer = QP_PROF_IMPL1);
procedure QuantIQ2_XXS_Impl2(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
procedure QuantIQ2_XXS_Impl3(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
procedure QuantIQ2_XXS_Impl4(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
procedure QuantIQ2_XXS_Impl5(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);

implementation

uses uGGMLQuantUtils, uLog;

// x = db * grid[idx] * signe ;  db = d * (0.5 + L4bits) * 0.25
procedure DequantIQ2_XXS(const Data: PByte; Dest: PSingle; n_row: Integer);
const
  SGN: array [Boolean] of Single = (1.0, -1.0); // False=+1, True=-1
var
  nb, i, ib32, l, j: Integer;
  B: PBlockIQ2_XXS;
  d, db: Single;
  aux32: array [0 .. 1] of UInt32;
  aux8: PByte;
  pAux: PCardinal;
  grid: PByte;
  sb: Byte;
begin
  // Assert(n_row mod QK_K = 0);
  nb := n_row div QK_K;
  aux8 := PByte(@aux32[0]); // little endian, comme en C

  for i := 0 to nb - 1 do
  begin
    B := PBlockIQ2_XXS(Data + Int64(i) * SizeOf(TBlockIQ2_XXS));
    d := FP16ToFP32(B.d);
    pAux := PCardinal(@B.qs[0]); // qs commence à l'offset 2 (d:Word) : load 4 octets directs

    for ib32 := 0 to (QK_K div 32) - 1 do
    begin
      // memcpy(aux32, x[i].qs + 4*ib32, 2*sizeof(uint32_t)) : 4 Word consecutifs
      aux32[0] := pAux[2 * ib32];
      aux32[1] := pAux[2 * ib32 + 1];

      db := d * (0.5 + (aux32[1] shr 28)) * 0.25;

      for l := 0 to 3 do
      begin
        grid := PByte(@IQ2XXS_GRID[aux8[l]]); // index 0..255, aux8[l] est un Byte => OK
        sb := KSIGNS_IQ2XS[(aux32[1] shr (7 * l)) and $7F];

        for j := 0 to 7 do
        begin
          Dest^ := db * grid[j] * SGN[((sb shr j) and 1) <> 0];
          Inc(Dest);
        end;
      end;
    end;
  end;
end;

// kMaxQ = 3, 8 sous-blocs de 32 valeurs (= 2 octets de grille + 4 octets de
// signes + 1 index d'echelle 4 bits par sous-bloc).
// NB : le C GGML_ASSERT(quant_weights) -> ici qWeights = nil est traite comme
// poids uniformes (= 1) pour fournir un mode "Ref".
procedure QuantIQ2_XXS_Ref(pSrc: PSingle; Dest: PByte; n_row: Integer);
const
  kMaxQ = 3;
var
  nbl, nb, ib, i, k, is_idx, grid_index, imin, l_val: Integer;
  y: PBlockIQ2_XXS;
  xbl, xb: PSingle;
  q2: array [0 .. (2 * (QK_K div 32)) - 1] of UInt32; // [2*ib] signes+index, [2*ib+1] echelle
  scales: array [0 .. (QK_K div 32) - 1] of Single;
  weight, xval, waux: array [0 .. 31] of Single;
  LLa, Laux: array [0 .. 31] of ShortInt;
  block_signs: array [0 .. 3] of Byte;
  sumx2, sigma2, max_val, eff_max, best, scale, id, this_scale, sumqx, sumq2, w, q, d, max_scale, ax, mn: Single;
  s_byte: Byte;
  nflip: Integer;
  u: UInt16;
begin
  if not iq2xxs_initialized then
    InitIQ2XXSGrid;

  // Assert(n_row mod QK_K = 0);
  nbl := n_row div QK_K;

  // LogMsg('kgrid_2bit_256 = ' + IntToStr(High(kgrid_2bit_256) + 1)); // doit afficher 256

  for nb := 0 to nbl - 1 do
  begin
    y := PBlockIQ2_XXS(Dest);
    y[nb].d := FP32ToFP16(0);
    FillChar(y[nb].qs[0], QK_K div 4, 0);
    FillChar(q2[0], SizeOf(q2), 0);

    max_scale := 0;
    xbl := @pSrc[QK_K * nb];

    sumx2 := 0;
    for i := 0 to QK_K - 1 do
      sumx2 := (sumx2 + (xbl[i] * xbl[i]));
    sigma2 := (sumx2 / QK_K); // PAS de facteur 2 ici (contrairement a IQ2_S/IQ3_S)

    for ib := 0 to 7 do
    begin
      xb := @xbl[32 * ib];

      for i := 0 to 31 do
        weight[i] := abs(xb[i]); // 1.0; // mode Ref (le C aurait asserted)

      for i := 0 to 31 do
        waux[i] := Sqrt(weight[i]);

      // Signes + correction de parite (nflip impair -> on retourne la plus petite
      // contribution |w*x^2| pour rester dans la convention des 7 bits de signe)
      for k := 0 to 3 do
      begin
        nflip := 0;
        s_byte := 0;
        for i := 0 to 7 do
          if xb[8 * k + i] >= 0 then
            xval[8 * k + i] := xb[8 * k + i]
          else
          begin
            xval[8 * k + i] := (-xb[8 * k + i]);
            Inc(nflip);
            s_byte := s_byte or (1 shl i);
          end;
        if (nflip mod 2) <> 0 then
        begin
          imin := 0;
          mn := (weight[8 * k + imin] * (xb[8 * k + imin] * xb[8 * k + imin]));
          for i := 1 to 7 do
          begin
            ax := (weight[8 * k + i] * (xb[8 * k + i] * xb[8 * k + i]));
            if ax < mn then
            begin
              mn := ax;
              imin := i;
            end;
          end;
          xval[8 * k + imin] := (-xval[8 * k + imin]);
          s_byte := s_byte xor (1 shl imin);
        end;
        block_signs[k] := s_byte and 127;
      end;

      max_val := xval[0];
      for i := 1 to 31 do
        if xval[i] > max_val then
          max_val := xval[i];
      FillChar(LLa[0], SizeOf(LLa), 0);
      if max_val < GROUP_MAX_EPS_IQ2_XXS then
      begin
        scales[ib] := 0;
        Continue;
      end;

      scale := MakeQPQuants(32, kMaxQ + 1, @xval[0], @weight[0], @Laux[0]);
      for i := 0 to 31 do
        LLa[i] := ShortInt(Laux[i]); // C : (uint8_t*)L
      eff_max := (scale * kMaxQ);
      if eff_max <= 0 then
      begin
        scales[ib] := 0;
        FillChar(LLa[0], SizeOf(LLa), 0);
        Continue;
      end;

      best := 0;
      // Boucle de recherche fine : is = -6..6, pas de 0.1, centre eff_max
      for is_idx := -6 to 6 do
      begin
        id := (((2 * kMaxQ - 1) + (is_idx * 0.1)) / eff_max);
        this_scale := 1 / id;

        for k := 0 to 3 do
        begin
          for i := 0 to 7 do
          begin
            l_val := Round((0.5) * ((id * xval[8 * k + i]) - 1));
            Laux[8 * k + i] := MAX(0, MIN(kMaxQ - 1, l_val));
          end;
          u := 0;
          for i := 0 to 7 do
            u := u or (UInt16(Laux[8 * k + i]) shl (2 * i));
          grid_index := kmap_q2xxs[u];
          if grid_index < 0 then
            grid_index := FindBestNeighbourIQ2xxs(@kneighbors_q2xxs[-grid_index - 1], @kgrid_q2xxs[0], @xval[8 * k],
              @waux[8 * k], this_scale, @Laux[8 * k]);
        end;

        sumqx := 0;
        sumq2 := 0;
        for i := 0 to 31 do
        begin
          w := weight[i];
          q := (2 * Laux[i] + 1);
          sumqx := (sumqx + ((w * xval[i]) * q));
          sumq2 := (sumq2 + (w * (q * q)));
        end;
        if (sumq2 > 0) and ((sumqx * sumqx) > (best * sumq2)) then
        begin
          scale := (sumqx / sumq2);
          best := (scale * sumqx);
          for i := 0 to 31 do
            LLa[i] := Laux[i];
        end;
      end;

      // Reprojection finale avec l'echelle retenue + re-ancrage sur la grille
      // (le C n'a PAS de "is_on_grid" ici : les 4 groupes sont reprojectes)
      if scale > 0 then
      begin
        id := 1 / scale;
        for k := 0 to 3 do
        begin
          u := 0;
          for i := 0 to 7 do
          begin
            l_val := Round(0.5 * ((id * xval[8 * k + i]) - 1));
            l_val := MAX(0, MIN(kMaxQ - 1, l_val));
            u := u or (UInt16(l_val) shl (2 * i));
          end;
          grid_index := kmap_q2xxs[u];
          if grid_index < 0 then
            grid_index := FindBestNeighbourIQ2xxs(@kneighbors_q2xxs[-grid_index - 1], @kgrid_q2xxs[0], @xval[8 * k],
              @waux[8 * k], scale, @LLa[8 * k]);
          // re-ancrage : L provient de la grille choisie (comme en C)
          PShortInt(@LLa[8 * k])^ := ShortInt((PShortInt(PByte(@kgrid_q2xxs[grid_index]))^ - 1) div 2);
          for i := 1 to 7 do
            PShortInt(@LLa[8 * k + i])^ := ShortInt((PShortInt(PByte(@kgrid_q2xxs[grid_index]) + i)^ - 1) div 2);
        end;

        sumqx := 0;
        sumq2 := 0;
        for i := 0 to 31 do
        begin
          w := weight[i];
          q := (2 * LLa[i] + 1);
          sumqx := sumqx + ((w * xval[i]) * q);
          sumq2 := sumq2 + (w * (q * q));
        end;
        if sumq2 > 0 then
          scale := sumqx / sumq2;
      end;

      if scale < 0 then
      begin
        scale := -scale;
        for k := 0 to 3 do
          block_signs[k] := (not block_signs[k]) and 127;
      end;

      // Ecriture : q2[2*ib] = index(8b) | signes(7b)<<8 | ... ; q2[2*ib+1] = signes | echelle<<28
      for k := 0 to 3 do
      begin
        u := 0;
        for i := 0 to 7 do
          u := u or (UInt16(LLa[8 * k + i]) shl (2 * i));
        grid_index := kmap_q2xxs[u];
        if grid_index < 0 then
          raise EGGML.CreateFmt('Oops: point %u hors grille IQ2_XXS', [u]);
        q2[2 * ib] := q2[2 * ib] or (UInt32(grid_index and 255) shl (8 * k));
        q2[2 * ib + 1] := q2[2 * ib + 1] or (UInt32(block_signs[k] and 127) shl (7 * k));
      end;

      if scale < 0 then
        scale := 0; // GGML_ASSERT(scale >= 0)

      scales[ib] := scale;
      if scale > max_scale then
        max_scale := scale;
    end;

    if max_scale = 0 then
    begin
      // le bloc reste a 0 (d = 0, qs = 0)
      Continue;
    end;

    d := (max_scale / 31);
    y[nb].d := FP32ToFP16(d); // AUCUN fudge factor en IQ2_XXS
    id := 1 / d;
    for ib := 0 to (QK_K div 32) - 1 do
    begin
      l_val := Round(0.5 * ((id * scales[ib]) - 1));
      l_val := MAX(0, MIN(15, l_val));
      q2[2 * ib + 1] := q2[2 * ib + 1] or (UInt32(l_val) shl 28);
    end;
    Move(q2[0], y[nb].qs[0], QK_K div 4);
  end;
end;

procedure QuantIQ2_XXS_Impl1(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil; iQk: Integer = QP_PROF_IMPL1);
const
  kMaxQ = 3;
var
  nbl, ibl, ib, i, k, is_idx, grid_index, imin, l_val: Integer;
  y: PBlockIQ2_XXS;
  xbl, xb, qw: PSingle;
  q2: array [0 .. (2 * (QK_K div 32)) - 1] of UInt32; // [2*ib] signes+index, [2*ib+1] echelle
  scales: array [0 .. (QK_K div 32) - 1] of Single;
  weight, xval, waux: array [0 .. 31] of Single;
  l, Laux: array [0 .. 31] of ShortInt;
  block_signs: array [0 .. 3] of Byte;
  sumx2, sigma2, max_val, eff_max, best, scale, id, this_scale, sumqx, sumq2, w, q, d, max_scale, ax, mn: Single;
  s_byte: Byte;
  nflip: Integer;
  u: UInt16;
  cfgQK: PQuantPreset;
begin
  cfgQK := cfg.ggmlReg.GetPPreset(GGML_TYPE_IQ2_XXS, iQk);
  if not iq2xxs_initialized then
    InitIQ2XXSGrid;
  // Assert(n_row mod QK_K = 0);
  nbl := n_row div QK_K;
  // LogMsg('kgrid_2bit_256 = ' + IntToStr(High(kgrid_2bit_256) + 1)); // doit afficher 256
  for ibl := 0 to nbl - 1 do
  begin
    y := PBlockIQ2_XXS(Dest);
    y[ibl].d := FP32ToFP16(0);
    FillChar(y[ibl].qs[0], QK_K div 4, 0);
    FillChar(q2[0], SizeOf(q2), 0);

    max_scale := 0;
    xbl := @pSrc[QK_K * ibl];

    sumx2 := 0;
    for i := 0 to QK_K - 1 do
      sumx2 := (sumx2 + (xbl[i] * xbl[i]));
    sigma2 := (sumx2 / QK_K);

    for ib := 0 to 7 do
    begin
      xb := @xbl[32 * ib];

      if qWeights <> nil then
      begin
        qw := qWeights + QK_K * ibl + 32 * ib;
        for i := 0 to 31 do
          weight[i] := (qw[i] * Sqrt((sigma2 + (xb[i] * xb[i]))));
      end
      else
      begin
        for i := 0 to 31 do
        begin
          case cfgQK.RmseType of
            1:
              w := 1.0;
            2:
              w := Sqrt(abs(xb[i]));
            3:
              w := abs(xb[i]);
            4:
              w := Sqr(xb[i]);
          else
            w := 1.0;
          end;
          if cfgQK.RmseType = 0 then
            weight[i] := Sqr(xb[i])
          else
            weight[i] := w * Sqrt(sigma2 + (xb[i] * xb[i])); // w;
        end;
      end;

      for i := 0 to 31 do
        waux[i] := Sqrt(weight[i]);

      // Signes + correction de parite (nflip impair -> on retourne la plus petite
      // contribution |w*x^2| pour rester dans la convention des 7 bits de signe)
      for k := 0 to 3 do
      begin
        nflip := 0;
        s_byte := 0;
        for i := 0 to 7 do
          if xb[8 * k + i] >= 0 then
            xval[8 * k + i] := xb[8 * k + i]
          else
          begin
            xval[8 * k + i] := (-xb[8 * k + i]);
            Inc(nflip);
            s_byte := s_byte or (1 shl i);
          end;
        if (nflip mod 2) <> 0 then
        begin
          imin := 0;
          mn := (weight[8 * k + imin] * (xb[8 * k + imin] * xb[8 * k + imin]));
          for i := 1 to 7 do
          begin
            ax := (weight[8 * k + i] * (xb[8 * k + i] * xb[8 * k + i]));
            if ax < mn then
            begin
              mn := ax;
              imin := i;
            end;
          end;
          xval[8 * k + imin] := (-xval[8 * k + imin]);
          s_byte := s_byte xor (1 shl imin);
        end;
        block_signs[k] := s_byte and 127;
      end;

      max_val := xval[0];
      for i := 1 to 31 do
        if xval[i] > max_val then
          max_val := xval[i];
      FillChar(l[0], SizeOf(l), 0);
      if max_val < GROUP_MAX_EPS_IQ2_XXS then
      begin
        scales[ib] := 0;
        Continue;
      end;

      scale := MakeQPQuants(32, kMaxQ + 1, @xval[0], @weight[0], @Laux[0], cfgQK.QpStep, cfgQK.QpNStep, cfgQK.QcIter);

      for i := 0 to 31 do
        l[i] := ShortInt(Laux[i]); // C : (uint8_t*)L
      eff_max := (scale * kMaxQ);
      if eff_max <= 0 then
      begin
        scales[ib] := 0;
        FillChar(l[0], SizeOf(l), 0);
        Continue;
      end;

      best := 0;
      // Boucle de recherche fine : is = -6..6, pas de 0.1, centre eff_max
      // for is_idx := -6 to 6 do
      for is_idx := -cfgQK.Nstep to cfgQK.Nstep do
      begin
        // id := (((2 * kMaxQ - 1) + (is_idx * 0.1)) / eff_max);
        id := (((2 * kMaxQ - 1) + (is_idx * cfgQK.Rdelta)) / eff_max);
        this_scale := 1 / id;

        for k := 0 to 3 do
        begin
          for i := 0 to 7 do
          begin
            l_val := Round((0.5) * ((id * xval[8 * k + i]) - 1));
            Laux[8 * k + i] := MAX(0, MIN(kMaxQ - 1, l_val));
          end;
          u := 0;
          for i := 0 to 7 do
            u := u or (UInt16(Laux[8 * k + i]) shl (2 * i));
          grid_index := kmap_q2xxs[u];
          if grid_index < 0 then
            grid_index := FindBestNeighbourIQ2xxs(@kneighbors_q2xxs[-grid_index - 1], @kgrid_q2xxs[0], @xval[8 * k],
              @waux[8 * k], this_scale, @Laux[8 * k]);
        end;

        sumqx := 0;
        sumq2 := 0;
        for i := 0 to 31 do
        begin
          w := weight[i];
          q := (2 * Laux[i] + 1);
          sumqx := (sumqx + ((w * xval[i]) * q));
          sumq2 := (sumq2 + (w * (q * q)));
        end;
        if (sumq2 > 0) and ((sumqx * sumqx) > (best * sumq2)) then
        begin
          scale := (sumqx / sumq2);
          best := (scale * sumqx);
          for i := 0 to 31 do
            l[i] := Laux[i];
        end;
      end;

      // Reprojection finale avec l'echelle retenue + re-ancrage sur la grille
      // (le C n'a PAS de "is_on_grid" ici : les 4 groupes sont reprojectes)
      if scale > 0 then
      begin
        id := 1 / scale;
        for k := 0 to 3 do
        begin
          u := 0;
          for i := 0 to 7 do
          begin
            l_val := Round(0.5 * ((id * xval[8 * k + i]) - 1));
            l_val := MAX(0, MIN(kMaxQ - 1, l_val));
            u := u or (UInt16(l_val) shl (2 * i));
          end;
          grid_index := kmap_q2xxs[u];
          if grid_index < 0 then
            grid_index := FindBestNeighbourIQ2xxs(@kneighbors_q2xxs[-grid_index - 1], @kgrid_q2xxs[0], @xval[8 * k],
              @waux[8 * k], scale, @l[8 * k]);
          // re-ancrage : L provient de la grille choisie (comme en C)
          PShortInt(@l[8 * k])^ := ShortInt((PShortInt(PByte(@kgrid_q2xxs[grid_index]))^ - 1) div 2);
          for i := 1 to 7 do
            PShortInt(@l[8 * k + i])^ := ShortInt((PShortInt(PByte(@kgrid_q2xxs[grid_index]) + i)^ - 1) div 2);
        end;

        sumqx := 0;
        sumq2 := 0;
        for i := 0 to 31 do
        begin
          w := weight[i];
          q := (2 * l[i] + 1);
          sumqx := sumqx + ((w * xval[i]) * q);
          sumq2 := sumq2 + (w * (q * q));
        end;
        if sumq2 > 0 then
          scale := sumqx / sumq2;
      end;

      if scale < 0 then
      begin
        scale := -scale;
        for k := 0 to 3 do
          block_signs[k] := (not block_signs[k]) and 127;
      end;

      // Ecriture : q2[2*ib] = index(8b) | signes(7b)<<8 | ... ; q2[2*ib+1] = signes | echelle<<28
      for k := 0 to 3 do
      begin
        u := 0;
        for i := 0 to 7 do
          u := u or (UInt16(l[8 * k + i]) shl (2 * i));
        grid_index := kmap_q2xxs[u];
        if grid_index < 0 then
          raise EGGML.CreateFmt('Oops: point %u hors grille IQ2_XXS', [u]);
        q2[2 * ib] := q2[2 * ib] or (UInt32(grid_index and 255) shl (8 * k));
        q2[2 * ib + 1] := q2[2 * ib + 1] or (UInt32(block_signs[k] and 127) shl (7 * k));
      end;

      if scale < 0 then
        scale := 0; // GGML_ASSERT(scale >= 0)

      scales[ib] := scale;
      if scale > max_scale then
        max_scale := scale;
    end;

    if max_scale = 0 then
    begin
      // le bloc reste a 0 (d = 0, qs = 0)
      Continue;
    end;

    d := (max_scale / 31);
    y[ibl].d := FP32ToFP16(d); // AUCUN fudge factor en IQ2_XXS
    id := 1 / d;
    for ib := 0 to (QK_K div 32) - 1 do
    begin
      l_val := Round(0.5 * ((id * scales[ib]) - 1));
      l_val := MAX(0, MIN(15, l_val));
      q2[2 * ib + 1] := q2[2 * ib + 1] or (UInt32(l_val) shl 28);
    end;

    // memcpy(y[ibl].qs, q2, QK_K/4)
    Move(q2[0], y[ibl].qs[0], QK_K div 4);
  end;
end;

procedure QuantIQ2_XXS_Impl2(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
begin
  QuantIQ2_XXS_Impl1(pSrc, Dest, n_row, qWeights, QP_PROF_IMPL2);
end;

procedure QuantIQ2_XXS_Impl3(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
begin
  QuantIQ2_XXS_Impl1(pSrc, Dest, n_row, qWeights, QP_PROF_IMPL3);
end;

procedure QuantIQ2_XXS_Impl4(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
begin
  QuantIQ2_XXS_Impl1(pSrc, Dest, n_row, qWeights, QP_PROF_IMPL4);
end;

procedure QuantIQ2_XXS_Impl5(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
begin
  QuantIQ2_XXS_Impl1(pSrc, Dest, n_row, qWeights, QP_PROF_IMPL5);
end;

initialization

finalization

FreeIQ2XXSGrid;

end.
