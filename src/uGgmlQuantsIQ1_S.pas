unit uGgmlQuantsiq1_S;

{ IQ1_S (1.5625 bpw) - dequantisation + quantisation
  (IQ1S_BLOCK_SIZE = 32, NGRID_IQ1S = 2048)

  Bloc (TBlockIQ1_S) = 50 octets pour QK_K = 256 :
  d     : 2 octets FP16
  qs    : 32 octets = index de grille, bits 0..7   (4 par sous-bloc de 32)
  qh    : 16 octets = 8 Word
  bits  0..2 : index de grille, bits 8..10  (groupe l = 0)
  bits  3..5 : index de grille, bits 8..10  (groupe l = 1)
  bits  6..8 : index de grille, bits 8..10  (groupe l = 2)
  bits  9..11: index de grille, bits 8..10  (groupe l = 3)
  bits 12..14: indice d'echelle 0..7
  bit     15: signe de delta (1 => delta = -IQ1S_DELTA)
}

interface

uses
  SysUtils, Classes, Generics.Defaults, Generics.Collections, uGGMLTypes,
  uGGMLConstants, uMath, uLog, uAppConfig, uGgmlQuantsFP16;

{$POINTERMATH ON}
{$O+}
{$ALIGN 8}
procedure DequantIQ1_S(const Data: PByte; Dest: PSingle; n_row: Integer);

procedure QuantIQ1_S_Ref(pSrc: PSingle; Dest: PByte; n_row: Integer);

procedure QuantIQ1_S_Impl1(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil; iQk: Integer = QP_PROF_IMPL1);
procedure QuantIQ1_S_Impl2(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
procedure QuantIQ1_S_Impl3(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
procedure QuantIQ1_S_Impl4(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
procedure QuantIQ1_S_Impl5(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);

implementation

uses
  uGgmlQuantsIQGRIDs;

procedure DequantIQ1_S(const Data: PByte; Dest: PSingle; n_row: Integer);
var
  nb, i, ib, L, j, gridIdx: Integer;
  B: PBlockIQ1_S;
  d, dl, delta: Single;
  qs: PByte;
  qh: PWord;
  grid: PShortInt;
begin
  // Assert(n_row mod QK_K = 0);
  nb := n_row div QK_K;

  for i := 0 to nb - 1 do
  begin
    B := PBlockIQ1_S(Data + Int64(i) * SizeOf(TBlockIQ1_S));
    d := FP16ToFP32(B.d);
    qs := @B.qs[0];
    qh := PWord(@B.qh[0]); // 16 octets = 8 Word

    for ib := 0 to (QK_K div 32) - 1 do
    begin
      dl := d * (2 * ((qh[ib] shr 12) and 7) + 1);
      if (qh[ib] and $8000) <> 0 then
        delta := -IQ1S_DELTA
      else
        delta := IQ1S_DELTA;

      for L := 0 to 3 do
      begin
        gridIdx := qs[L] or ((((qh[ib] shr (3 * L)) and 7)) shl 8);
        grid := PShortInt(@IQ1S_GRID[gridIdx]); // octets int8 : -1, 0, +1
        for j := 0 to 7 do
        begin
          Dest^ := dl * (grid[j] + delta);
          Inc(Dest);
        end;
      end;
      Inc(qs, 4);
    end;
  end;
end;

function IQ1S_ClampNearestL(v: Single): Integer; inline;
begin
  // Equivalent de nearest_int(v) du C puis clamp 0..7.
  // roundf() arrondit les .5 a l'ecart de zero.
  if v <= 0 then
    Result := 0
  else if v >= 6.5 then
    Result := 7
  else
    Result := Trunc(v + 0.5);
end;

procedure QuantIQ1_S_Internal(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle; rmseType: Integer);
const
  block_size = 32;
var
  x_p, x_m: array[0..2] of Single;
  nbl, ibl, ib, i, j, k, i1, i2, grid_index: Integer;
  y: PBlockIQ1_S;
  xbl, xb, qw: PSingle;
  scales: array[0..(QK_K div 32) - 1] of Single;
  shifts: array[0..(QK_K div 32) - 1] of ShortInt;
  weight: array[0..block_size - 1] of Single;
  sumx, sumw: array[0..block_size] of Single; // prefix sums : 0..32
  pairs: array[0..block_size - 1] of TValIdx;
  L: array[0..block_size - 1] of ShortInt;
  index: array[0..(block_size div 8) - 1] of Word; // = 4
  grid: PShortInt;
  sumx2, sigma2, ww, max_val, best_score, scale, d, id: Single;
  sumqx, sumq2, w, q: Single;
  max_scale: Single;
  h: Word;
  besti1, besti2, best_shift, l_val: Integer;
  all_on_grid: Boolean;
  u: Word;
  neighbours_ptr: PUInt16;
  best_ax, ax: Single;
begin
  if not iq1s_initialized then
    InitIQ1SGrid;

  // Le C aurait asserté quant_weights != NULL ; on suit la convention des
  // autres unites : rmseType = -1 (Ref) ou RmseType = 0 -> poids x^2.
  Assert((rmseType >= 0) or (qWeights = nil));

  x_p[0] := -1 + IQ1S_DELTA;
  x_p[1] := IQ1S_DELTA;
  x_p[2] := 1 + IQ1S_DELTA;
  x_m[0] := -1 - IQ1S_DELTA;
  x_m[1] := -IQ1S_DELTA;
  x_m[2] := 1 - IQ1S_DELTA;

  // Assert(n_row mod QK_K = 0);
  nbl := n_row div QK_K;
  y := PBlockIQ1_S(Dest);

  for ibl := 0 to nbl - 1 do
  begin
    FillChar(y[ibl], SizeOf(TBlockIQ1_S), 0); // C : d = 0 + memset(qs) + memset(qh)
    max_scale := 0;

    xbl := @pSrc[QK_K * ibl];
    sumx2 := 0;
    for i := 0 to QK_K - 1 do
      sumx2 := sumx2 + xbl[i] * xbl[i];
    sigma2 := 2 * sumx2 / QK_K; // facteur 2 : comme IQ2_S / IQ3_S (PAS IQ2_XXS)

    for ib := 0 to (QK_K div 32) - 1 do
    begin
      xb := @xbl[block_size * ib];

      if rmseType < 0 then
      begin
        for i := 0 to block_size - 1 do
          weight[i] := xb[i] * xb[i];
      end
      else if qWeights <> nil then
      begin
        qw := @qWeights[QK_K * ibl + block_size * ib];
        for i := 0 to block_size - 1 do
          weight[i] := qw[i] * Sqrt(sigma2 + xb[i] * xb[i]);
      end
      else
      begin
        for i := 0 to block_size - 1 do
        begin
          case rmseType of
            1:
              ww := 1.0;
            2:
              ww := Sqrt(Abs(xb[i]));
            3:
              ww := Abs(xb[i]);
            4:
              ww := Sqr(xb[i]);
          else
            ww := 1.0;
          end;
          if rmseType = 0 then
            weight[i] := Sqr(xb[i])
          else
            weight[i] := ww * Sqrt(sigma2 + xb[i] * xb[i]);
        end;
      end;

      max_val := Abs(xb[0]);
      best_ax := Abs(xb[0]); // |xb| max : sert a initialiser la scale
      for i := 1 to block_size - 1 do
      begin
        ax := Abs(xb[i]);
        if ax > max_val then
          max_val := ax;
      end;
      best_ax := max_val;

      if max_val < GROUP_MAX_EPS_IQ1_S then
      begin
        scales[ib] := 0;
        shifts[ib] := 1;
        FillChar(L[0], block_size, 1);
        Continue;
      end;

      for j := 0 to block_size - 1 do
      begin
        pairs[j].v := xb[j];
        pairs[j].i := j;
      end;
      // Le qsort du C ne compare que la valeur (ordre parmi valeurs egales
      // arbitraire) ; on departage par l'index pour un resultat deterministe.
      TArray.Sort<TValIdx>(pairs, TComparer<TValIdx>.Construct(CmpValIdx));

      sumx[0] := 0;
      sumw[0] := 0;
      for j := 0 to block_size - 1 do
      begin
        i := pairs[j].i;
        sumx[j + 1] := sumx[j] + weight[i] * xb[i];
        sumw[j + 1] := sumw[j] + weight[i];
      end;

      best_score := -Single.MaxValue; // -FLT_MAX
      scale := best_ax;
      besti1 := -1;
      besti2 := -1;
      best_shift := 0;

      for i1 := 0 to block_size do
      begin
        for i2 := i1 to block_size do
        begin
          // delta = +IQ1S_DELTA  (x_p)
          sumqx := (sumx[i1] - sumx[0]) * x_p[0] + (sumx[i2] - sumx[i1]) * x_p[1] + (sumx[block_size] - sumx[i2]) * x_p[2];
          sumq2 := (sumw[i1] - sumw[0]) * x_p[0] * x_p[0] + (sumw[i2] - sumw[i1]) * x_p[1] * x_p[1] + (sumw[block_size] - sumw[i2]) * x_p[2] * x_p[2];
          if (sumq2 > 0) and (sumqx * sumqx > best_score * sumq2) then
          begin
            scale := sumqx / sumq2;
            best_score := scale * sumqx;
            besti1 := i1;
            besti2 := i2;
            best_shift := 1;
          end;
          // delta = -IQ1S_DELTA  (x_m)
          sumqx := (sumx[i1] - sumx[0]) * x_m[0] + (sumx[i2] - sumx[i1]) * x_m[1] + (sumx[block_size] - sumx[i2]) * x_m[2];
          sumq2 := (sumw[i1] - sumw[0]) * x_m[0] * x_m[0] + (sumw[i2] - sumw[i1]) * x_m[1] * x_m[1] + (sumw[block_size] - sumw[i2]) * x_m[2] * x_m[2];
          if (sumq2 > 0) and (sumqx * sumqx > best_score * sumq2) then
          begin
            scale := sumqx / sumq2;
            best_score := scale * sumqx;
            besti1 := i1;
            besti2 := i2;
            best_shift := -1;
          end;
        end;
      end;

      if (besti1 < 0) or (besti2 < 0) or (best_shift = 0) then
      begin
        scales[ib] := 0;
        shifts[ib] := 1;
        FillChar(L[0], block_size, 1);
        Continue;
      end;

      for j := 0 to besti1 - 1 do
        L[pairs[j].i] := 0;
      for j := besti1 to besti2 - 1 do
        L[pairs[j].i] := 1;
      for j := besti2 to block_size - 1 do
        L[pairs[j].i] := 2;

      if scale < 0 then
      begin
        for j := 0 to block_size - 1 do
          L[j] := 2 - L[j];
        scale := -scale;
        best_shift := -best_shift;
      end;

      // Ancrage sur la grille apprise (2048 vecteurs de 8 valeurs ternaires)
      all_on_grid := True;
      for k := 0 to (block_size div 8) - 1 do
      begin
        u := 0;
        for j := 0 to 7 do
          u := u or (Word(L[8 * k + j]) shl (2 * j));
        grid_index := kmap_q1s[u];
        if grid_index < 0 then
        begin
          all_on_grid := False;
          neighbours_ptr := @kneighbors_q1s[-grid_index - 1];
          if best_shift = 1 then
            grid_index := FindBestNeighbourIQ1(neighbours_ptr, @kgrid_q1s[0], @xb[8 * k], @weight[8 * k], scale, @x_p[0], @L[8 * k], NGRID_IQ1S)
          else
            grid_index := FindBestNeighbourIQ1(neighbours_ptr, @kgrid_q1s[0], @xb[8 * k], @weight[8 * k], scale, @x_m[0], @L[8 * k], NGRID_IQ1S);
          Assert(grid_index >= 0);
        end;
        index[k] := Word(grid_index);
      end;

      if not all_on_grid then
      begin
        sumqx := 0;
        sumq2 := 0;
        for k := 0 to (block_size div 8) - 1 do
        begin
          grid := PShortInt(@kgrid_q1s[index[k]]);
          for j := 0 to 7 do
          begin
            w := weight[8 * k + j];
            if best_shift = 1 then
              q := x_p[(grid[j] - 1) div 2]
            else
              q := x_m[(grid[j] - 1) div 2];
            sumqx := sumqx + w * q * xb[8 * k + j];
            sumq2 := sumq2 + w * q * q;
          end;
        end;
        if (sumqx > 0) and (sumq2 > 0) then
          scale := sumqx / sumq2;
      end;

      h := 0;
      for k := 0 to (block_size div 8) - 1 do
      begin
        y[ibl].qs[(block_size div 8) * ib + k] := index[k] and 255;
        h := h or ((index[k] shr 8) shl (3 * k));
      end;
      PWord(@y[ibl].qh[0])[ib] := h; // qh declare Byte ou Word : identique
      Assert(scale >= 0);
      scales[ib] := scale;
      shifts[ib] := ShortInt(best_shift);
      if scale > max_scale then
        max_scale := scale;
    end;

    if max_scale = 0 then
      Continue;

    d := max_scale / 15;
    y[ibl].d := FP32ToFP16(d * 1.125); // 1.125 = fudge factor du C, a conserver
    id := 1 / d;
    for ib := 0 to (QK_K div 32) - 1 do
    begin
      l_val := Round(0.5 * (id * scales[ib] - 1));
      l_val := MAX(0, MIN(7, l_val));
      if shifts[ib] = -1 then
        l_val := l_val or 8; // bit 15 : delta = -IQ1S_DELTA
      PWord(@y[ibl].qh[0])[ib] := PWord(@y[ibl].qh[0])[ib] or Word(l_val shl 12);
    end;
  end;
end;

procedure QuantIQ1_S_Ref(pSrc: PSingle; Dest: PByte; n_row: Integer);
begin
  QuantIQ1_S_Internal(pSrc, Dest, n_row, nil, -1);
end;

procedure QuantIQ1_S_Impl1(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle; iQk: Integer);
const
  block_size = 32;
  nsub = QK_K div block_size;       // 8
  ngroups = block_size div 8;       // 4
var
  x_p, x_m: array[0..2] of Single;
  xbl, xb, qw: PSingle;
  xp0, xp1, xp2, xm0, xm1, xm2: Single;
  xp0sq, xp1sq, xp2sq, xm0sq, xm1sq, xm2sq: Single;
  nbl, ibl, ib, i, j, k, i1, i2, grid_index: Integer;
  y: PBlockIQ1_S;
  qhP: PWord;
  kmapPtr: PInt;
  kneiPtr: PUInt16;
  kgridPtr: PUInt64;
  cfgQK:PQuantPreset;
  rmseType: Integer;
  weights: array[0..QK_K - 1] of Single;
  wBase: PSingle;
  scales: array[0..nsub - 1] of Single;
  shifts: array[0..nsub - 1] of ShortInt;
  pairs: array[0..block_size - 1] of TValIdx;
  tmpPair: TValIdx;
  L: array[0..block_size - 1] of ShortInt;
  index: array[0..ngroups - 1] of Word;
  sumx, sumw: array[0..block_size] of Single;
  sumx2, sigma2, xx, base: Single;
  max_val, best_score, scale: Single;
  d, id, max_scale: Single;
  total_sx, total_sw, sx1, sw1, sx2, sw2: Single;
  sumqx, sumq2, w, xv: Single;
  sumqx_f, sumq2_f, q: Single;
  besti1, besti2, best_shift, l_val, h: Integer;
  all_on_grid: Boolean;
  u: Word;
  neighbours_ptr: PUInt16;
  grid: PShortInt;
  xg: PSingle;
begin
  Assert(SizeOf(TBlockIQ1_S) = 50);
  Assert((n_row mod QK_K) = 0);

  if not iq1s_initialized then
    InitIQ1SGrid;

  kmapPtr := PInt(@kmap_q1s[0]);
  kneiPtr := PUInt16(@kneighbors_q1s[0]);
  kgridPtr := PUInt64(@kgrid_q1s[0]);

  cfgQK := cfg.ggmlReg.GetPPreset(GGML_TYPE_IQ1_S, iQk);
  rmseType := cfgQK.rmseType;

  x_p[0] := -1 + IQ1S_DELTA;
  x_p[1] := IQ1S_DELTA;
  x_p[2] := 1 + IQ1S_DELTA;

  x_m[0] := -1 - IQ1S_DELTA;
  x_m[1] := -IQ1S_DELTA;
  x_m[2] := 1 - IQ1S_DELTA;

  xp0 := x_p[0];
  xp1 := x_p[1];
  xp2 := x_p[2];

  xm0 := x_m[0];
  xm1 := x_m[1];
  xm2 := x_m[2];

  xp0sq := xp0 * xp0;
  xp1sq := xp1 * xp1;
  xp2sq := xp2 * xp2;

  xm0sq := xm0 * xm0;
  xm1sq := xm1 * xm1;
  xm2sq := xm2 * xm2;

  nbl := n_row div QK_K;
  y := PBlockIQ1_S(Dest);

  for ibl := 0 to nbl - 1 do
  begin
    FillChar(y[ibl], SizeOf(TBlockIQ1_S), 0);

    qhP := PWord(@y[ibl].qh[0]);

    xbl := @pSrc[QK_K * ibl];

    sumx2 := 0;
    for i := 0 to QK_K - 1 do
    begin
      xx := xbl[i];
      sumx2 := sumx2 + xx * xx;
    end;

    sigma2 := 2 * sumx2 / QK_K;

    // =========================================================================
    // Optimisation principale :
    // calcul des weights UNE SEULE FOIS pour tout le super-bloc de 256.
    //
    // Le C les recalcule dans le sous-bloc.
    // Ici on precalcule, puis on utilise un pointeur wBase par sous-bloc de 32.
    // =========================================================================
    if rmseType < 0 then
    begin
      // Mode Ref / ancien chemin Pascal : weight = x^2
      for i := 0 to QK_K - 1 do
      begin
        xx := xbl[i];
        weights[i] := xx * xx;
      end;
    end
    else if qWeights <> nil then
    begin
      qw := @qWeights[QK_K * ibl];

      for i := 0 to QK_K - 1 do
      begin
        xx := xbl[i];
        base := Sqrt(sigma2 + xx * xx);
        weights[i] := qw[i] * base;
      end;
    end
    else
    begin
      case rmseType of
        0:
          begin
            for i := 0 to QK_K - 1 do
            begin
              xx := xbl[i];
              weights[i] := xx * xx;
            end;
          end;

        1:
          begin
            for i := 0 to QK_K - 1 do
            begin
              xx := xbl[i];
              weights[i] := Sqrt(sigma2 + xx * xx);
            end;
          end;

        2:
          begin
            for i := 0 to QK_K - 1 do
            begin
              xx := xbl[i];
              base := Sqrt(sigma2 + xx * xx);
              weights[i] := Sqrt(Abs(xx)) * base;
            end;
          end;

        3:
          begin
            for i := 0 to QK_K - 1 do
            begin
              xx := xbl[i];
              base := Sqrt(sigma2 + xx * xx);
              weights[i] := Abs(xx) * base;
            end;
          end;

        4:
          begin
            for i := 0 to QK_K - 1 do
            begin
              xx := xbl[i];
              base := Sqrt(sigma2 + xx * xx);
              weights[i] := (xx * xx) * base;
            end;
          end;
      else
        begin
          for i := 0 to QK_K - 1 do
          begin
            xx := xbl[i];
            weights[i] := Sqrt(sigma2 + xx * xx);
          end;
        end;
      end;
    end;

    max_scale := 0;

    for ib := 0 to nsub - 1 do
    begin
      xb := @xbl[block_size * ib];
      wBase := @weights[block_size * ib];

      max_val := Abs(xb[0]);
      for i := 1 to block_size - 1 do
        if Abs(xb[i]) > max_val then
          max_val := Abs(xb[i]);

      if max_val < GROUP_MAX_EPS_IQ1_S then
      begin
        scales[ib] := 0;
        shifts[ib] := 1;
        Continue;
      end;

      // =====================================================================
      // Tri des valeurs.
      // Sur 32 elements, un tri par insertion est souvent plus rapide que
      // TArray.Sort<TValIdx> avec un comparer generique.
      //
      // On garde un tri deterministe : valeur, puis index.
      // =====================================================================
      for j := 0 to block_size - 1 do
      begin
        pairs[j].v := xb[j];
        pairs[j].i := j;
      end;

      for i := 1 to block_size - 1 do
      begin
        tmpPair := pairs[i];
        j := i - 1;

        while (j >= 0) and (CmpValIdx(pairs[j], tmpPair) > 0) do
        begin
          pairs[j + 1] := pairs[j];
          Dec(j);
        end;

        pairs[j + 1] := tmpPair;
      end;

      // =====================================================================
      // Prefix sums, comme dans le C.
      // =====================================================================
      sumx[0] := 0;
      sumw[0] := 0;

      for j := 0 to block_size - 1 do
      begin
        i := pairs[j].i;
        w := wBase[i];
        xv := xb[i];

        sumx[j + 1] := sumx[j] + w * xv;
        sumw[j + 1] := sumw[j] + w;
      end;

      total_sx := sumx[block_size];
      total_sw := sumw[block_size];

      best_score := -Single.MaxValue;
      scale := max_val;

      besti1 := -1;
      besti2 := -1;
      best_shift := 0;

      // =====================================================================
      // Recherche exacte des deux frontieres i1/i2.
      //
      // Le C utilise deja les prefix sums :
      //   O(N^2) avec N=32.
      //
      // On remplace juste les recalculs inutiles par des variables locales.
      // =====================================================================
      for i1 := 0 to block_size do
      begin
        sx1 := sumx[i1];
        sw1 := sumw[i1];

        sx2 := sx1;
        sw2 := sw1;

        for i2 := i1 to block_size do
        begin
          // delta = +IQ1S_DELTA
          sumqx := sx1 * xp0 + (sx2 - sx1) * xp1 + (total_sx - sx2) * xp2;

          sumq2 := sw1 * xp0sq + (sw2 - sw1) * xp1sq + (total_sw - sw2) * xp2sq;

          if sumq2 > 0 then
          begin
            if best_score < 0 then
            begin
              scale := sumqx / sumq2;
              best_score := scale * sumqx;

              besti1 := i1;
              besti2 := i2;
              best_shift := 1;
            end
            else if sumqx * sumqx > best_score * sumq2 then
            begin
              scale := sumqx / sumq2;
              best_score := scale * sumqx;

              besti1 := i1;
              besti2 := i2;
              best_shift := 1;
            end;
          end;

          // delta = -IQ1S_DELTA
          sumqx := sx1 * xm0 + (sx2 - sx1) * xm1 + (total_sx - sx2) * xm2;

          sumq2 := sw1 * xm0sq + (sw2 - sw1) * xm1sq + (total_sw - sw2) * xm2sq;

          if sumq2 > 0 then
          begin
            if best_score < 0 then
            begin
              scale := sumqx / sumq2;
              best_score := scale * sumqx;

              besti1 := i1;
              besti2 := i2;
              best_shift := -1;
            end
            else if sumqx * sumqx > best_score * sumq2 then
            begin
              scale := sumqx / sumq2;
              best_score := scale * sumqx;

              besti1 := i1;
              besti2 := i2;
              best_shift := -1;
            end;
          end;

          if i2 < block_size then
          begin
            sx2 := sumx[i2 + 1];
            sw2 := sumw[i2 + 1];
          end;
        end;
      end;

      if (besti1 < 0) or (besti2 < 0) or (best_shift = 0) then
      begin
        scales[ib] := 0;
        shifts[ib] := 1;
        Continue;
      end;

      // Affectation des labels selon les deux frontieres trouvees.
      for j := 0 to besti1 - 1 do
        L[pairs[j].i] := 0;

      for j := besti1 to besti2 - 1 do
        L[pairs[j].i] := 1;

      for j := besti2 to block_size - 1 do
        L[pairs[j].i] := 2;

      if scale < 0 then
      begin
        for j := 0 to block_size - 1 do
          L[j] := 2 - L[j];

        scale := -scale;
        best_shift := -best_shift;
      end;

      // =====================================================================
      // Ancrage sur la grille apprise IQ1_S.
      // IMPORTANT : en quantization, on utilise kgrid_q1s (lattice 1/3/5),
      // pas IQ1S_GRID (-1/0/+1).
      // =====================================================================
      all_on_grid := True;

      if best_shift = 1 then
        xg := @x_p[0]
      else
        xg := @x_m[0];

      for k := 0 to ngroups - 1 do
      begin
        u := 0;
        for j := 0 to 7 do
          u := Word(u or (Word(L[8 * k + j]) shl (2 * j)));

        grid_index := kmapPtr[u];

        if grid_index < 0 then
        begin
          all_on_grid := False;
          neighbours_ptr := @kneiPtr[(-grid_index) - 1];

          grid_index := FindBestNeighbourIQ1(neighbours_ptr, kgridPtr, @xb[8 * k], @wBase[8 * k], scale, xg, @L[8 * k], NGRID_IQ1S);
        end;

        index[k] := Word(grid_index);
      end;

      // Recalcul de la scale locale si un groupe de 8 n'etait pas exactement
      // sur la grille.
      if not all_on_grid then
      begin
        sumqx_f := 0;
        sumq2_f := 0;

        for k := 0 to ngroups - 1 do
        begin
          grid := PShortInt(PByte(kgridPtr) + index[k] * 8);

          for j := 0 to 7 do
          begin
            w := wBase[8 * k + j];
            q := xg[(grid[j] - 1) div 2];

            sumqx_f := sumqx_f + w * q * xb[8 * k + j];
            sumq2_f := sumq2_f + w * q * q;
          end;
        end;

        if (sumqx_f > 0) and (sumq2_f > 0) then
          scale := sumqx_f / sumq2_f;
      end;

      Assert(scale >= 0);

      // =====================================================================
      // Packing qs/qh.
      // =====================================================================
      h := 0;

      for k := 0 to ngroups - 1 do
      begin
        y[ibl].qs[ngroups * ib + k] := Byte(index[k] and $FF);
        h := h or (Integer(index[k] shr 8) shl (3 * k));
      end;

      qhP[ib] := Word(h);

      scales[ib] := scale;
      shifts[ib] := ShortInt(best_shift);

      if scale > max_scale then
        max_scale := scale;
    end;

    if max_scale = 0 then
      Continue;

    // =======================================================================
    // Echelle FP16 du super-bloc.
    //
    // IMPORTANT :
    // IQ1_S n'a PAS le recalcul final de d comme IQ1_M.
    // =======================================================================
    d := max_scale / 15;

    y[ibl].d := FP32ToFP16(d * 1.125);

    if d <> 0 then
      id := 1 / d
    else
      id := 0;

    for ib := 0 to nsub - 1 do
    begin
      l_val := IQ1S_ClampNearestL(0.5 * (id * scales[ib] - 1));

      if shifts[ib] = -1 then
        l_val := l_val or 8;

      qhP[ib] := Word(qhP[ib] or Word(l_val shl 12));
    end;
  end;
end;

procedure QuantIQ1_S_Impl2(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
var
  cfgQK: TQuantPreset;
begin
  cfgQK := cfg.ggmlReg.GetPreset(GGML_TYPE_IQ1_S, QP_PROF_IMPL2);
  //QuantIQ1_S_Impl(pSrc, Dest, n_row, qWeights, 1);
  QuantIQ1_S_Internal(pSrc, Dest, n_row, qWeights, cfgQK.rmseType);
end;

procedure QuantIQ1_S_Impl3(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
begin
  QuantIQ1_S_Impl1(pSrc, Dest, n_row, qWeights, QP_PROF_IMPL3);
end;

procedure QuantIQ1_S_Impl4(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
begin
  QuantIQ1_S_Impl1(pSrc, Dest, n_row, qWeights, QP_PROF_IMPL4);
end;

procedure QuantIQ1_S_Impl5(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
begin
  QuantIQ1_S_Impl1(pSrc, Dest, n_row, qWeights, QP_PROF_IMPL5);
end;

end.

