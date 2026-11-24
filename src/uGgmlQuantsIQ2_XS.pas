unit uGgmlQuantsIQ2_XS;

{ IQ2_XS  (2.3125 bpw) — déquantisation + quantisation
  Bloc (TBlockIQ2_XS dans uGGMLConstants) = 74 octets pour QK_K = 256 :
  d      :  2 octets  FP16 (échelle globale, AUCUN fudge factor en IQ2_XS)
  qs     : 64 octets = 32 mots de 16 bits
  bit  0..8  : index dans iq2xs_grid (512 entrées)
  bit  9..15 : index dans ksigns_iq2xs (7 bits de signe, 128 motifs)
  scales :  8 octets  (2 sous-échelles 4 bits par octet, 16 sous-blocs de 16)

  IMPORTANT :
  * La table de recherche est la grille de réseau (lattice) construite depuis
  kgrid_2bit_512 (octets = 2*l + 1), PAS IQ2XS_GRID (valeurs apprises).
  D'ou des globals distincts : kgrid_iq2xs / kmap_iq2xs / kneighbors_iq2xs.
  * sigma2 = sumx2/QK_K  (sans facteur 2 : contrairement à IQ2_S et IQ3_S).
  * Signs avec correction de parité (nflip impair -> on reflip le |x|²*w min),
  et block_signs sur 7 bits (& 127) : contrairement à IQ3_S / IQ2_S.
  * Le C fait GGML_ASSERT(quant_weights) : il n'existe pas de ref IQ2_XS côté
  ggml. Le mode Ref fourni utilise la même chute sans poids que IQ2_S
  (weight = 0.25*sigma2 + x^2) : léger écart assumé avec la DLL. }

interface

uses
  SysUtils, Math, Generics.Defaults, Generics.Collections,
  uGGMLTypes, uGGMLConstants, uMath, uGgmlQuantsFP16, uAppConfig, uGgmlQuantsIQGRIDs;

{$POINTERMATH ON}
{$O+}
{$ALIGN 8}
procedure DequantIQ2_XS(const Data: PByte; Dest: PSingle; n_row: Integer);
procedure QuantIQ2_XS_Ref(pSrc: PSingle; Dest: PByte; n_row: Integer);
procedure QuantIQ2_XS_Impl1(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil; iQk: Integer = QP_PROF_IMPL1);
procedure QuantIQ2_XS_Impl2(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
procedure QuantIQ2_XS_Impl3(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
procedure QuantIQ2_XS_Impl4(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
procedure QuantIQ2_XS_Impl5(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);

implementation

uses
  uLog;

// x = d * (0.5 + L) * 0.25 * grid[idx] * signe   (L = sous-échelle 4 bits)
procedure DequantIQ2_XS(const Data: PByte; Dest: PSingle; n_row: Integer);
var
  nb, i, ib32, l, j: Integer;
  B: PBlockIQ2_XS;
  d, dl, s: Single;
  db: array [0 .. 1] of Single;
  gridPtr: PByte;
  qw: Word;
  signs: Byte;
begin
  // Assert(n_row mod QK_K = 0, 'n_row doit être un multiple de QK_K (256)');
  nb := n_row div QK_K;

  for i := 0 to nb - 1 do
  begin
    B := PBlockIQ2_XS(Data + Int64(i) * SizeOf(TBlockIQ2_XS));
    d := FP16ToFP32(B.d);

    for ib32 := 0 to (QK_K div 32) - 1 do
    begin
      db[0] := (d * (0.5 + (B.scales[ib32] and $0F)) * 0.25);
      db[1] := (d * (0.5 + (B.scales[ib32] shr 4)) * 0.25);

      for l := 0 to 3 do
      begin
        qw := B.qs[4 * ib32 + l]; // mot 16 bits : 9 bits grille + 7 bits signes
        gridPtr := PByte(@IQ2XS_GRID[qw and $1FF]);
        signs := KSIGNS_IQ2XS[qw shr 9]; // 0..127
        dl := db[l div 2];

        for j := 0 to 7 do
        begin
          if (signs and KMASK_IQ2XS[j]) <> 0 then
            s := -1.0
          else
            s := 1.0;
          Dest^ := dl * gridPtr[j] * s;
          Inc(Dest);
        end;
      end;
    end;
  end;
end;

procedure QuantIQ2_XS_Ref(pSrc: PSingle; Dest: PByte; n_row: Integer);
const
  kMaxQ = 3;
var
  nbl, ibl, ib, i, k, is_idx, grid_index, l_val, n_not_ongrid, imin, nflip: Integer;
  y: PBlockIQ2_XS;
  xbl, xb: PSingle;
  scales, weight, xval, waux, wMin, wAx: array [0 .. 15] of Single;
  l, Laux: array [0 .. 15] of ShortInt;
  is_on_grid, is_on_grid_aux: array [0 .. 1] of Boolean;
  block_signs: array [0 .. 1] of Byte;
  sumx2, sigma2, max_val, best, scale, id, this_scale, sumqx, sumq2, w, q, d, max_scale: Single;
  s_byte: Byte;
  u: UInt16;
  neighbours_ptr: PUInt16;
  g8: PUInt64;
begin
  if not iq2xs_initialized then
    InitIQ2XSGrid;

  // Assert(n_row mod QK_K = 0);
  nbl := n_row div QK_K;
  y := PBlockIQ2_XS(Dest);
  g8 := @kgrid_iq2xs[0];

  for ibl := 0 to nbl - 1 do
  begin
    FillChar(y[ibl], SizeOf(TBlockIQ2_XS), 0); // y.d = 0, qs = 0 (q2 du C), scales = 0
    max_scale := 0;
    xbl := @pSrc[QK_K * ibl];

    sumx2 := 0;
    for i := 0 to QK_K - 1 do
      sumx2 := (sumx2 + (xbl[i] * xbl[i]));
    sigma2 := (sumx2 / QK_K); // PAS de facteur 2 ici (iq2_xs / iq2_xxs)

    for ib := 0 to (QK_K div 16) - 1 do
    begin
      xb := xbl + 16 * ib;
      for i := 0 to 15 do
        weight[i] := (Sqrt((sigma2 + (xb[i] * xb[i]))));
      // for i := 0 to 15 do  weight[i] := ((0.25 * sigma2) + (xb[i] * xb[i]));

      for i := 0 to 15 do
        waux[i] := (Sqrt(weight[i]));

      for k := 0 to 1 do
      begin
        s_byte := 0;
        nflip := 0;
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
          wMin[0] := (weight[8 * k] * (xb[8 * k] * xb[8 * k]));
          for i := 1 to 7 do
          begin
            wAx[i] := (weight[8 * k + i] * (xb[8 * k + i] * xb[8 * k + i]));
            if wAx[i] < wMin[0] then
            begin
              wMin[0] := wAx[i];
              imin := i;
            end;
          end;
          xval[8 * k + imin] := (-xval[8 * k + imin]);
          s_byte := s_byte xor (1 shl imin);
        end;
        block_signs[k] := s_byte and 127;
      end;

      max_val := xval[0];
      for i := 1 to 15 do
        if xval[i] > max_val then
          max_val := xval[i];
      FillChar(l, SizeOf(l), 0);
      if max_val < GROUP_MAX_EPS_IQ2_XS then
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
            Laux[8 * k + i] := uMath.MAX(0, uMath.min(kMaxQ - 1, l_val));
          end;
          u := 0;
          for i := 0 to 7 do
            u := u or (UInt16(Laux[8 * k + i]) shl (2 * i));
          grid_index := kmap_iq2xs[u];
          is_on_grid_aux[k] := True;
          if grid_index < 0 then
          begin
            is_on_grid_aux[k] := False;
            neighbours_ptr := @kneighbors_iq2xs[-grid_index - 1];
            grid_index := FindBestNeighbourIQ2(neighbours_ptr, g8, @xval[8 * k], @waux[8 * k], this_scale,
              @Laux[8 * k]);
          end;
        end;

        sumqx := 0;
        sumq2 := 0;
        for i := 0 to 15 do
        begin
          w := weight[i];
          q := 2 * Laux[i] + 1;
          sumqx := (sumqx + ((w * xval[i]) * q));
          sumq2 := (sumq2 + (w * (q * q)));
        end;
        if (sumq2 > 0) and ((sumqx * sumqx) > (best * sumq2)) then
        begin
          scale := (sumqx / sumq2);
          best := (scale * sumqx);
          for i := 0 to 15 do
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
            l_val := Round((0.5) * ((id * xval[8 * k + i]) - 1));
            l_val := uMath.MAX(0, uMath.min(kMaxQ - 1, l_val));
            u := u or (UInt16(l_val) shl (2 * i));
            l[8 * k + i] := l_val;
          end;
          grid_index := kmap_iq2xs[u];
          if grid_index < 0 then
          begin
            neighbours_ptr := @kneighbors_iq2xs[-grid_index - 1];
            grid_index := FindBestNeighbourIQ2(neighbours_ptr, g8, @xval[8 * k], @waux[8 * k], scale, @l[8 * k]);
          end;
        end;
        sumqx := 0;
        sumq2 := 0;
        for i := 0 to 15 do
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
        scale := (-scale);
        for k := 0 to 1 do
          block_signs[k] := not block_signs[k] and 127; // & 127 : IQ2_XS/IQ2_XXS
      end;

      for k := 0 to 1 do
      begin
        u := 0;
        for i := 0 to 7 do
          u := u or (UInt16(l[8 * k + i]) shl (2 * i));
        grid_index := kmap_iq2xs[u];
        if grid_index < 0 then
          raise EGGML.CreateFmt('Oops: point %u hors grille IQ2_XS', [u]);
        // q2[2*ib+k] = grid_index | (block_signs[k] << 9)
        y[ibl].qs[2 * ib + k] := UInt16(grid_index or (block_signs[k] shl 9));
      end;

      scales[ib] := scale;
      if scale > max_scale then
        max_scale := scale;
    end;

    if max_scale = 0 then
    begin
      // C : memset(y[ibl].qs, 0, QK_K/4) puis continue (scales deja a 0)
      FillChar(y[ibl].qs[0], QK_K div 4, 0);
      Continue;
    end;

    d := (max_scale / 31);
    y[ibl].d := FP32ToFP16(d); // AUCUN fudge factor en IQ2_XS (0.9875 en IQ2_S, 1.033 en IQ3_S)
    id := (1 / d);
    for ib := 0 to (QK_K div 16) - 1 do
    begin
      l_val := Round((0.5) * ((id * scales[ib]) - 1));
      l_val := uMath.MAX(0, uMath.min(15, l_val));
      if (ib mod 2) = 0 then
        y[ibl].scales[ib div 2] := Byte(l_val)
      else
        y[ibl].scales[ib div 2] := y[ibl].scales[ib div 2] or Byte(l_val shl 4);
    end;
  end;
end;

procedure QuantIQ2_XS_Impl1(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil; iQk: Integer = QP_PROF_IMPL1);
const
  kMaxQ = 3;
var
  nbl, ibl, ib, i, k, is_idx, grid_index, l_val, n_not_ongrid, imin, nflip: Integer;
  y: PBlockIQ2_XS;
  xbl, xb, qw: PSingle;
  scales, weight, xval, waux, wMin, wAx: array [0 .. 15] of Single;
  l, Laux: array [0 .. 15] of ShortInt;
  is_on_grid, is_on_grid_aux: array [0 .. 1] of Boolean;
  block_signs: array [0 .. 1] of Byte;
  sumx2, sigma2, max_val, best, scale, id, this_scale, sumqx, sumq2, ww, w, q, d, max_scale: Single;
  s_byte: Byte;
  u: UInt16;
  neighbours_ptr: PUInt16;
  g8: PUInt64;
  cfgQK: PQuantPreset;
begin
  cfgQK := cfg.ggmlReg.GetPPreset(GGML_TYPE_IQ2_XS, iQk);

  if not iq2xs_initialized then
    InitIQ2XSGrid;

  // Assert(n_row mod QK_K = 0);
  nbl := n_row div QK_K;
  y := PBlockIQ2_XS(Dest);
  g8 := @kgrid_iq2xs[0];

  for ibl := 0 to nbl - 1 do
  begin
    FillChar(y[ibl], SizeOf(TBlockIQ2_XS), 0); // y.d = 0, qs = 0 (q2 du C), scales = 0
    max_scale := 0;
    xbl := @pSrc[QK_K * ibl];

    sumx2 := 0;
    for i := 0 to QK_K - 1 do
      sumx2 := (sumx2 + (xbl[i] * xbl[i]));
    sigma2 := (sumx2 / QK_K); // PAS de facteur 2 ici (iq2_xs / iq2_xxs)

    for ib := 0 to 15 do
    begin
      xb := @xbl[16 * ib];
      if qWeights <> nil then
      begin
        qw := @qWeights[QK_K * ibl + 16 * ib];
        for i := 0 to 15 do
          weight[i] := (qw[i] * Sqrt((sigma2 + (xb[i] * xb[i]))));
      end
      else
      begin
        for i := 0 to 15 do
        begin
          case cfgQK.RmseType of
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
          if cfgQK.RmseType = 0 then
            weight[i] := Sqr(xb[i])
          else
            weight[i] := ww * Sqrt(sigma2 + (xb[i] * xb[i]));
        end; // après test OK

        // for i := 0 to 15 do weight[i] := ((0.25 * sigma2) + (xb[i] * xb[i]));
      end;

      for i := 0 to 15 do
        waux[i] := (Sqrt(weight[i]));

      // Signes + correction de parite (nflip impair => re-flip du plus petit w*x^2)
      for k := 0 to 1 do
      begin
        s_byte := 0;
        nflip := 0;
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
          wMin[0] := (weight[8 * k] * (xb[8 * k] * xb[8 * k]));
          for i := 1 to 7 do
          begin
            wAx[i] := (weight[8 * k + i] * (xb[8 * k + i] * xb[8 * k + i]));
            if wAx[i] < wMin[0] then
            begin
              wMin[0] := wAx[i];
              imin := i;
            end;
          end;
          xval[8 * k + imin] := (-xval[8 * k + imin]);
          s_byte := s_byte xor (1 shl imin);
        end;
        block_signs[k] := s_byte and 127;
      end;

      max_val := xval[0];
      for i := 1 to 15 do
        if xval[i] > max_val then
          max_val := xval[i];
      FillChar(l, SizeOf(l), 0);
      if max_val < GROUP_MAX_EPS_IQ2_XS then
      begin
        scales[ib] := 0;
        Continue;
      end;

      best := 0;
      scale := (max_val / (2 * kMaxQ - 1));
      is_on_grid[0] := True;
      is_on_grid[1] := True;

      // for is_idx := -9 to 9 do
      for is_idx := -cfgQK.Nstep to cfgQK.Nstep do
      begin
        // id := (( (2 * kMaxQ - 1) + (is_idx * 0.1) ) / max_val);
        id := (((2 * kMaxQ - 1) + (is_idx * cfgQK.Rdelta)) / max_val);
        this_scale := 1 / id;

        for k := 0 to 1 do
        begin
          for i := 0 to 7 do
          begin
            l_val := Round(0.5 * ((id * xval[8 * k + i]) - 1));
            Laux[8 * k + i] := uMath.MAX(0, uMath.min(kMaxQ - 1, l_val));
          end;
          u := 0;
          for i := 0 to 7 do
            u := u or (UInt16(Laux[8 * k + i]) shl (2 * i));
          grid_index := kmap_iq2xs[u];
          is_on_grid_aux[k] := True;
          if grid_index < 0 then
          begin
            is_on_grid_aux[k] := False;
            neighbours_ptr := @kneighbors_iq2xs[-grid_index - 1];
            grid_index := FindBestNeighbourIQ2(neighbours_ptr, g8, @xval[8 * k], @waux[8 * k], this_scale,
              @Laux[8 * k]);
          end;
        end;

        sumqx := 0;
        sumq2 := 0;
        for i := 0 to 15 do
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
          for i := 0 to 15 do
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
            Continue; // actif en IQ2_XS (commente en IQ3_S)
          u := 0;
          for i := 0 to 7 do
          begin
            l_val := Round(0.5 * ((id * xval[8 * k + i]) - 1));
            l_val := uMath.MAX(0, uMath.min(kMaxQ - 1, l_val));
            u := u or (UInt16(l_val) shl (2 * i));
            l[8 * k + i] := l_val;
          end;
          grid_index := kmap_iq2xs[u];
          if grid_index < 0 then
          begin
            neighbours_ptr := @kneighbors_iq2xs[-grid_index - 1];
            grid_index := FindBestNeighbourIQ2(neighbours_ptr, g8, @xval[8 * k], @waux[8 * k], scale, @l[8 * k]);
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
          block_signs[k] := not block_signs[k] and 127; // & 127 : comme IQ2_XS/IQ2_XXS
      end;

      for k := 0 to 1 do
      begin
        u := 0;
        for i := 0 to 7 do
          u := u or (UInt16(l[8 * k + i]) shl (2 * i));
        grid_index := kmap_iq2xs[u];
        if grid_index < 0 then
          raise EGGML.CreateFmt('Oops: point %u hors grille IQ2_XS', [u]);
        // q2[2*ib+k] = grid_index | (block_signs[k] << 9)
        y[ibl].qs[2 * ib + k] := UInt16(grid_index or (block_signs[k] shl 9));
      end;

      scales[ib] := scale;
      if scale > max_scale then
        max_scale := scale;
    end;

    if max_scale = 0 then
    begin
      // C : memset(y[ibl].qs, 0, QK_K/4) puis continue (scales deja a 0)
      FillChar(y[ibl].qs[0], QK_K div 4, 0);
      Continue;
    end;

    d := max_scale / 31;
    y[ibl].d := FP32ToFP16(d); // AUCUN fudge factor en IQ2_XS (0.9875 en IQ2_S, 1.033 en IQ3_S)
    id := 1 / d;
    for ib := 0 to (QK_K div 16) - 1 do
    begin
      l_val := Round(0.5 * ((id * scales[ib]) - 1));
      l_val := uMath.MAX(0, uMath.min(15, l_val));
      if (ib mod 2) = 0 then
        y[ibl].scales[ib div 2] := Byte(l_val)
      else
        y[ibl].scales[ib div 2] := y[ibl].scales[ib div 2] or Byte(l_val shl 4);
    end;
  end;
end;

procedure QuantIQ2_XS_Impl2(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
begin
  QuantIQ2_XS_Impl1(pSrc, Dest, n_row, qWeights, QP_PROF_IMPL2);
end;

procedure QuantIQ2_XS_Impl3(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
begin
  QuantIQ2_XS_Impl1(pSrc, Dest, n_row, qWeights, QP_PROF_IMPL3);
end;

procedure QuantIQ2_XS_Impl4(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
begin
  QuantIQ2_XS_Impl1(pSrc, Dest, n_row, qWeights, QP_PROF_IMPL4);
end;

procedure QuantIQ2_XS_Impl5(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
begin
  QuantIQ2_XS_Impl1(pSrc, Dest, n_row, qWeights, QP_PROF_IMPL5);
end;

initialization

finalization

FreeIQ2XSGrid;

end.
