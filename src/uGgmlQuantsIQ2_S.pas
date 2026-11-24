unit uGgmlQuantsIQ2_S;

interface

uses
  SysUtils, Classes, uGGMLTypes, uGGMLConstants, uMath, uLog, uAppConfig,
  uGgmlQuantsFP16;

{$POINTERMATH ON}
{$O+}
{$ALIGN 8}
procedure DequantIQ2_S(const Data: PByte; Dest: PSingle; n_row: Integer);

procedure QuantIQ2_S_Ref(pSrc: PSingle; Dest: PByte; n_row: Integer);

procedure QuantIQ2_S_Impl1(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil; iQk: Integer = QP_PROF_IMPL1);
procedure QuantIQ2_S_Impl2(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
procedure QuantIQ2_S_Impl3(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights:  PSingle = nil);
procedure QuantIQ2_S_Impl4(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights:  PSingle = nil);
procedure QuantIQ2_S_Impl5(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights:  PSingle = nil);

implementation

uses
  uGgmlQuantsIQGRIDs;

procedure DequantIQ2_S(const Data: PByte; Dest: PSingle; n_row: Integer);
var
  nb, i, ib32, l, j: Integer;
  B: PBlockIQ2_S;
  d, dl, s: Single;
  db: array[0..1] of Single;
  qs, qh, signs, gridPtr: PByte;
  gridIdx: Cardinal;
begin
  // Assert(n_row mod QK_K = 0, 'n_row doit être un multiple de QK_K (256)');
  nb := n_row div QK_K;

  for i := 0 to nb - 1 do
  begin
    B := PBlockIQ2_S(Data + Int64(i) * SizeOf(TBlockIQ2_S));
    d := FP16ToFP32(B.d);
    qs := @B.qs[0];
    qh := @B.qh[0];
    signs := @B.qs[QK_K div 8]; // signes stockés après les 32 octets de quants

    for ib32 := 0 to (QK_K div 32) - 1 do
    begin
      db[0] := d * (0.5 + (B.scales[ib32] and $0F)) * 0.25;
      db[1] := d * (0.5 + (B.scales[ib32] shr 4)) * 0.25;

      for l := 0 to 3 do
      begin
        dl := db[l div 2];
        gridIdx := Cardinal(qs[l]) or ((Cardinal(qh[ib32]) shl (8 - 2 * l)) and $300);
        gridPtr := PByte(@IQ2S_GRID[gridIdx]);

        for j := 0 to 7 do
        begin
          if (signs[l] and KMASK_IQ2XS[j]) <> 0 then
            s := -1.0
          else
            s := 1.0;
          Dest^ := dl * gridPtr[j] * s;
          Inc(Dest);
        end;
      end;
      Inc(qs, 4);
      Inc(signs, 4);
    end;
  end;
end;

procedure QuantIQ2_S_Ref(pSrc: PSingle; Dest: PByte; n_row: Integer);
const
  kMaxQ = 3;
var
  nbl, ibl, ib, i, k, is_idx, grid_index, i8, l_val, n_not_ongrid: Integer;
  y: PBlockIQ2_S;
  xbl, xb: PSingle;
  scales, weight, xval, waux: array[0..15] of Single;
  l, Laux: array[0..15] of ShortInt;
  is_on_grid, is_on_grid_aux: array[0..1] of Boolean;
  block_signs: array[0..1] of Byte;
  sumx2, sigma2, max_val, best, scale, id, this_scale, sumqx, sumq2, w, q, d,
    max_scale: Single;
  s_byte: Byte;
  u: UInt16;
  neighbours_ptr: PUInt16;
begin
  if not iq2s_initialized then
    InitIQ2SGrid;
  // Assert(n_row mod QK_K = 0);
  nbl := n_row div QK_K;
  y := PBlockIQ2_S(Dest);
  for ibl := 0 to nbl - 1 do
  begin
    FillChar(y[ibl], SizeOf(TBlockIQ2_S), 0);
    max_scale := 0;
    xbl := @pSrc[QK_K * ibl];
    sumx2 := 0;
    for i := 0 to QK_K - 1 do
      sumx2 := sumx2 + (xbl[i] * xbl[i]);
    sigma2 := 2 * sumx2 / QK_K;

    for ib := 0 to (QK_K div 16) - 1 do
    begin
      xb := xbl + 16 * ib;
      for i := 0 to 15 do
        weight[i] := 0.25 * sigma2 + xb[i] * xb[i];

      for i := 0 to 15 do
        waux[i] := Sqrt(weight[i]);

      for k := 0 to 1 do
      begin
        s_byte := 0;
        for i := 0 to 7 do
          if xb[8 * k + i] >= 0 then
            xval[8 * k + i] := xb[8 * k + i]
          else
          begin
            xval[8 * k + i] := (-xb[8 * k + i]);
            s_byte := s_byte or (1 shl i);
          end;
        block_signs[k] := s_byte;
      end;

      max_val := xval[0];
      for i := 1 to 15 do
        if xval[i] > max_val then
          max_val := xval[i];
      FillChar(l, SizeOf(l), 0);
      if max_val < GROUP_MAX_EPS_IQ2_S then
      begin
        scales[ib] := 0;
        Continue;
      end;

      best := 0;
      scale := max_val / (2 * kMaxQ - 1);
      is_on_grid[0] := True;
      is_on_grid[1] := True;

      for is_idx := -9 to 9 do
      begin
        id := ((2 * kMaxQ - 1) + (is_idx * 0.1)) / max_val;
        this_scale := 1 / id;

        for k := 0 to 1 do
        begin
          for i := 0 to 7 do
          begin
            l_val := Round(0.5 * ((id * xval[8 * k + i]) - 1));
            Laux[8 * k + i] := MAX(0, MIN(kMaxQ - 1, l_val));
          end;
          u := 0;
          for i := 0 to 7 do
            u := u or (UInt16(Laux[8 * k + i]) shl (2 * i));
          grid_index := kmap_q2xs[u];
          is_on_grid_aux[k] := True;
          if grid_index < 0 then
          begin
            is_on_grid_aux[k] := False;
            neighbours_ptr := @kneighbors_q2xs[-grid_index - 1];
            grid_index := FindBestNeighbourIQ2(neighbours_ptr, PUInt64(kgrid_q2xs),
              @xval[8 * k], @waux[8 * k], this_scale, @Laux[8 * k]);
          end;
        end;

        sumqx := 0;
        sumq2 := 0;
        for i := 0 to 15 do
        begin
          w := weight[i];
          q := 2 * Laux[i] + 1;
          sumqx := sumqx + ((w * xval[i]) * q);
          sumq2 := sumq2 + (w * (q * q));
        end;
        if (sumq2 > 0) and ((sumqx * sumqx) > (best * sumq2)) then
        begin
          scale := sumqx / sumq2;
          best := scale * sumqx;
          for i := 0 to 15 do
            l[i] := Laux[i];
          is_on_grid[0] := is_on_grid_aux[0];
          is_on_grid[1] := is_on_grid_aux[1];
        end;
      end;

      n_not_ongrid := 0;
      for k := 0 to 1 do
        if not is_on_grid[k] then
          Inc(n_not_ongrid);

      if (n_not_ongrid > 0) and (scale > 0) then
      begin
        id := 1 / scale;
        for k := 0 to 1 do
        begin
          if is_on_grid[k] then
            Continue;
          u := 0;
          for i := 0 to 7 do
          begin
            l_val := Round(0.5 * ((id * xval[8 * k + i]) - 1));
            l_val := MAX(0, MIN(kMaxQ - 1, l_val));
            u := u or (UInt16(l_val) shl (2 * i));
            l[8 * k + i] := l_val;
          end;
          grid_index := kmap_q2xs[u];
          if grid_index < 0 then
          begin
            neighbours_ptr := @kneighbors_q2xs[-grid_index - 1];
            grid_index := FindBestNeighbourIQ2(neighbours_ptr, PUInt64(kgrid_q2xs),
              @xval[8 * k], @waux[8 * k], scale, @l[8 * k]);
          end;
        end;
        sumqx := 0;
        sumq2 := 0;
        for i := 0 to 15 do
        begin
          w := weight[i];
          q := 2 * l[i] + 1;
          sumqx := sumqx + ((w * xval[i]) * q);
          sumq2 := sumq2 + (w * (q * q));
        end;
        if sumq2 > 0 then
          scale := sumqx / sumq2;
      end;

      if scale < 0 then
      begin
        scale := -scale;
        for k := 0 to 1 do
          block_signs[k] := not block_signs[k];
      end;

      for k := 0 to 1 do
      begin
        u := 0;
        for i := 0 to 7 do
          u := u or (UInt16(l[8 * k + i]) shl (2 * i));
        grid_index := kmap_q2xs[u];
        if grid_index < 0 then
          raise EGGML.CreateFmt('Oops: point %u hors grille IQ2_S', [u]);
        i8 := 2 * ib + k;
        y[ibl].qs[i8] := grid_index and 255;
        y[ibl].qh[i8 div 4] := y[ibl].qh[i8 div 4] or Byte((grid_index shr 8)
          shl (2 * (i8 mod 4)));
        y[ibl].qs[(QK_K div 8) + i8] := block_signs[k];
      end;

      scales[ib] := scale;
      if scale > max_scale then
        max_scale := scale;
    end;

    if max_scale = 0 then
      Continue;

    d := max_scale / 31;
    y[ibl].d := FP32ToFP16((d * (0.9875)));
    id := 1 / d;
    for ib := 0 to (QK_K div 16) - 1 do
    begin
      l_val := Round(0.5 * ((id * scales[ib]) - 1));
      l_val := MAX(0, MIN(15, l_val));
      if (ib mod 2) = 0 then
        y[ibl].scales[ib div 2] := l_val
      else
        y[ibl].scales[ib div 2] := y[ibl].scales[ib div 2] or Byte(l_val shl 4);
    end;
  end;
end;

procedure QuantIQ2_S_Impl1(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil; iQk: Integer = QP_PROF_IMPL1);
const
  kBlock = 16;
  kMaxQ = 4;
  kMaxQ1 = kMaxQ - 1;
  kHalf = 8;
  qtab: array[0..kMaxQ1] of Single = (1.0, 3.0, 5.0, 7.0);
var
  nbl, ibl, ib, i, k, is_idx, grid_index, i8, l_val, n_not_ongrid: Integer;
  y: PBlockIQ2_S;
  xbl, xb, qw: PSingle;
  kmapPtr: PInteger;
  kneiPtr: PUInt16;
  kgridPtr: PUInt64;
  scales, weight, xval, waux: array[0..kBlock - 1] of Single;
  l, Laux: array[0..kBlock - 1] of ShortInt;
  is_on_grid, is_on_grid_aux: array[0..1] of Boolean;
  block_signs: array[0..1] of Byte;
  sumx2, sigma2, xv, max_val, best, scale, id, this_scale, ww, sumqx, sumq2, w,
    q, d, max_scale: Single;
  s_byte: Byte;
  u: Word;
  neighbours_ptr: PUInt16;
  cfgQK: TQuantPreset;
begin
  cfgQK := cfg.ggmlReg.GetPreset(GGML_TYPE_IQ2_S, iQk);

  if not iq2s_initialized then
    InitIQ2SGrid;

  kmapPtr := @kmap_q2xs[0];
  kneiPtr := @kneighbors_q2xs[0];
  kgridPtr := @kgrid_q2xs[0];

  nbl := n_row div QK_K;
  y := PBlockIQ2_S(Dest);

  for ibl := 0 to nbl - 1 do
  begin
    FillChar(y[ibl], SizeOf(TBlockIQ2_S), 0);

    max_scale := 0;
    xbl := pSrc + Int64(QK_K) * ibl;

    sumx2 := 0;
    for i := 0 to QK_K - 1 do
      sumx2 := sumx2 + (xbl[i] * xbl[i]);

    sigma2 := 2 * sumx2 / QK_K;

    for ib := 0 to (QK_K div kBlock) - 1 do
    begin
      xb := xbl + Int64(kBlock) * ib;

      // =====================================================================
      // Poids : calcul hoisté hors des boucles internes.
      // Comportement conservé par rapport à ton QuantIQ2_S_Impl actuel.
      // =====================================================================
      if qWeights <> nil then
      begin
        qw := qWeights + Int64(QK_K) * ibl + Int64(kBlock) * ib;
        for i := 0 to kBlock - 1 do
        begin
          xv := xb[i];
          weight[i] := qw[i] * Sqrt(sigma2 + (xv * xv));
        end;
      end
      else
      begin
        case cfgQK.RmseType of
          0:
            begin
              for i := 0 to kBlock - 1 do
              begin
                xv := xb[i];
                weight[i] := xv * xv;
              end;
            end;

          1:
            begin
              for i := 0 to kBlock - 1 do
              begin
                xv := xb[i];
                weight[i] := Sqrt(sigma2 + (xv * xv));
              end;
            end;

          2:
            begin
              for i := 0 to kBlock - 1 do
              begin
                xv := xb[i];
                weight[i] := Sqrt(Abs(xv)) * Sqrt(sigma2 + (xv * xv));
              end;
            end;

          3:
            begin
              for i := 0 to kBlock - 1 do
              begin
                xv := xb[i];
                weight[i] := Abs(xv) * Sqrt(sigma2 + (xv * xv));
              end;
            end;

          4:
            begin
              for i := 0 to kBlock - 1 do
              begin
                xv := xb[i];
                weight[i] := (xv * xv) * Sqrt(sigma2 + (xv * xv));
              end;
            end;
        else
          begin
            for i := 0 to kBlock - 1 do
            begin
              xv := xb[i];
              weight[i] := Sqrt(sigma2 + (xv * xv));
            end;
          end;
        end;
      end;

      for i := 0 to kBlock - 1 do
        waux[i] := Sqrt(weight[i]);

      // =====================================================================
      // Signes + max en une seule passe.
      // =====================================================================
      max_val := 0;

      for k := 0 to 1 do
      begin
        s_byte := 0;

        for i := 0 to 7 do
        begin
          xv := xb[8 * k + i];

          if xv >= 0 then
          begin
            xval[8 * k + i] := xv;
            if xv > max_val then
              max_val := xv;
          end
          else
          begin
            xv := -xv;
            xval[8 * k + i] := xv;
            if xv > max_val then
              max_val := xv;
            s_byte := s_byte or (1 shl i);
          end;
        end;

        block_signs[k] := s_byte;
      end;

      FillChar(l, SizeOf(l), 0);

      if max_val < GROUP_MAX_EPS_IQ2_S then
      begin
        scales[ib] := 0;
        Continue;
      end;

      best := 0;
      scale := max_val / kMaxQ;

      is_on_grid[0] := True;
      is_on_grid[1] := True;

      // for is_idx := -9 to 9 do
      for is_idx := -cfgQK.Nstep to cfgQK.Nstep do
      begin
      // id := ((2 * kMaxQ - 1) + (is_idx * 0.1)) / max_val;
        id := (kMaxQ + (is_idx * cfgQK.Rdelta)) / max_val;
        this_scale := 1 / id;

        for k := 0 to 1 do
        begin
          u := 0;

          for i := 0 to 7 do
          begin
            l_val := Round(0.5 * ((id * xval[8 * k + i]) - 1));

            if l_val < 0 then
              l_val := 0
            else if l_val > kMaxQ1 - 1 then
              l_val := kMaxQ1 - 1;

            Laux[8 * k + i] := ShortInt(l_val);
            u := u or (Word(l_val) shl (2 * i));
          end;

          grid_index := kmapPtr[u];
          is_on_grid_aux[k] := True;

          if grid_index < 0 then
          begin
            is_on_grid_aux[k] := False;
            neighbours_ptr := @kneiPtr[(-grid_index) - 1];

            grid_index := FindBestNeighbourIQ2(neighbours_ptr, kgridPtr, @xval[8
              * k], @waux[8 * k], this_scale, @Laux[8 * k]);
          end;
        end;

        sumqx := 0;
        sumq2 := 0;

        for i := 0 to kBlock - 1 do
        begin
          w := weight[i];
          q := qtab[Laux[i]];

          sumqx := sumqx + ((w * xval[i]) * q);
          sumq2 := sumq2 + (w * (q * q));
        end;

        if (sumq2 > 0) and ((sumqx * sumqx) > (best * sumq2)) then
        begin
          scale := sumqx / sumq2;
          best := scale * sumqx;

          for i := 0 to kBlock - 1 do
            l[i] := Laux[i];

          for k := 0 to 1 do
            is_on_grid[k] := is_on_grid_aux[k];
        end;
      end;

      n_not_ongrid := 0;
      for k := 0 to 1 do
        if not is_on_grid[k] then
          Inc(n_not_ongrid);

      if (n_not_ongrid > 0) and (scale > 0) then
      begin
        id := 1 / scale;

        for k := 0 to 1 do
        begin
          if is_on_grid[k] then
            Continue;

          u := 0;

          for i := 0 to 7 do
          begin
            l_val := Round(0.5 * ((id * xval[8 * k + i]) - 1));

            if l_val < 0 then
              l_val := 0
            else if l_val > kMaxQ1 - 1 then
              l_val := kMaxQ1 - 1;

            u := u or (Word(l_val) shl (2 * i));
            l[8 * k + i] := ShortInt(l_val);
          end;

          grid_index := kmapPtr[u];

          if grid_index < 0 then
          begin
            neighbours_ptr := @kneiPtr[(-grid_index) - 1];

            grid_index := FindBestNeighbourIQ2(neighbours_ptr, kgridPtr, @xval[8
              * k], @waux[8 * k], scale, @l[8 * k]);
          end;
        end;

        sumqx := 0;
        sumq2 := 0;

        for i := 0 to kBlock - 1 do
        begin
          w := weight[i];
          q := qtab[l[i]];

          sumqx := sumqx + ((w * xval[i]) * q);
          sumq2 := sumq2 + (w * (q * q));
        end;

        if sumq2 > 0 then
          scale := sumqx / sumq2;
      end;

      if scale < 0 then
      begin
        scale := -scale;

        for k := 0 to 1 do
          block_signs[k] := not block_signs[k];
      end;

      for k := 0 to 1 do
      begin
        u := 0;

        for i := 0 to 7 do
          u := u or (Word(l[8 * k + i]) shl (2 * i));

        grid_index := kmapPtr[u];

        if grid_index < 0 then
          raise EGGML.CreateFmt('Oops: point %u hors grille IQ2_S', [u]);

        i8 := (ib shl 1) + k;

        y[ibl].qs[i8] := Byte(grid_index and 255);
        y[ibl].qh[i8 shr 2] := Byte(y[ibl].qh[i8 shr 2] or ((grid_index shr 8)
          shl (2 * (i8 and 3))));
        y[ibl].qs[(QK_K div 8) + i8] := block_signs[k];
      end;

      scales[ib] := scale;

      if scale > max_scale then
        max_scale := scale;
    end;

    if max_scale = 0 then
      Continue;

    d := max_scale / 31;
    y[ibl].d := FP32ToFP16(d * 0.9875);

    id := 1 / d;

    for ib := 0 to (QK_K div kBlock) - 1 do
    begin
      l_val := Round(0.5 * ((id * scales[ib]) - 1));

      if l_val < 0 then
        l_val := 0
      else if l_val > 15 then
        l_val := 15;

      if (ib and 1) = 0 then
        y[ibl].scales[ib shr 1] := Byte(l_val)
      else
        y[ibl].scales[ib shr 1] := Byte(y[ibl].scales[ib shr 1] or (l_val shl 4));
    end;
  end;
end;

procedure QuantIQ2_S_Impl2(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights:
  PSingle = nil);
begin
  QuantIQ2_S_Impl1(pSrc, Dest, n_row, qWeights, QP_PROF_IMPL2);
end;

procedure QuantIQ2_S_Impl3(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights:
  PSingle = nil);
begin
  QuantIQ2_S_Impl1(pSrc, Dest, n_row, qWeights, QP_PROF_IMPL3);
end;

procedure QuantIQ2_S_Impl4(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights:
  PSingle = nil);
begin
  QuantIQ2_S_Impl1(pSrc, Dest, n_row, qWeights, QP_PROF_IMPL4);
end;

procedure QuantIQ2_S_Impl5(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights:
  PSingle = nil);
begin
  QuantIQ2_S_Impl1(pSrc, Dest, n_row, qWeights, QP_PROF_IMPL5);
end;

end.

