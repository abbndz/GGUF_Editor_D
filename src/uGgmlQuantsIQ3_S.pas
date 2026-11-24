unit uGgmlQuantsIQ3_S;

{ IQ3_S  (3.4375 bpw) — déquantisation + quantisation
  Bloc (TBlockIQ3_S dans uGGMLConstants) = 110 octets pour QK_K = 256 :
  d      :  2 octets  FP16  (échelle globale, fudge factor 1.033)
  qs     : 64 octets         bits 0..7 de l'index de grille (8 octets / 32 valeurs)
  qh     :  8 octets         bit 8 de l'index de grille (1 bit / groupe de 4 valeurs)
  signs  : 32 octets         1 bit de signe par valeur
  scales :  4 octets         2 sous-échelles 4 bits par octet (8 sous-blocs de 32)

  NB : pour IQ3, la grille de déquantification (IQ3S_GRID) est exactement la
  grille de recherche (kgrid_q3xs) construite par le C depuis kgrid_512
  (octets = 2*l + 1). On n'a donc qu'à construire kmap_q3xs + kneighbors_q3xs. }

interface

uses
  SysUtils, Math, Generics.Defaults, Generics.Collections, uGGMLTypes,
  uGGMLConstants, uMath, uGgmlQuantsFP16, uAppConfig, uGgmlQuantsIQGRIDs;

{$POINTERMATH ON}
{$O+}
{$ALIGN 8}
procedure DequantIQ3_S(const Data: PByte; Dest: PSingle; n_row: Integer);

procedure QuantIQ3_S_Ref(pSrc: PSingle; Dest: PByte; n_row: Integer);

procedure QuantIQ3_S_Impl1(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil; iQk: Integer = QP_PROF_IMPL1);

procedure QuantIQ3_S_Impl2(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);

procedure QuantIQ3_S_Impl3(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
procedure QuantIQ3_S_Impl4(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
procedure QuantIQ3_S_Impl5(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);

implementation

uses
  uLog;

// x[i] = d * (1 + 2*L) * grid[idx] * signe   (L = échelle 4 bits du sous-bloc)
procedure DequantIQ3_S(const Data: PByte; Dest: PSingle; n_row: Integer);
const
  SGN: array[Boolean] of Single = (1.0, -1.0); // False=+1, True=-1  (remplace le if/else)
var
  nb, i, ib32, l, j: Integer;
  B: PBlockIQ3_S;
  d, db1, db2: Single;
  qs, qh, signs, g: PByte;
  idx: Cardinal;
  sb: Byte;
begin
  // Assert(n_row mod QK_K = 0, 'n_row doit être un multiple de QK_K (256)');
  nb := n_row div QK_K;

  for i := 0 to nb - 1 do
  begin
    B := PBlockIQ3_S(Data + Int64(i) * SizeOf(TBlockIQ3_S));
    d := FP16ToFP32(B.d);
    qs := @B.qs[0];
    qh := @B.qh[0];
    signs := @B.signs[0];

    for ib32 := 0 to (QK_K div 64) - 1 do // 4 itérations de 64 valeurs
    begin
      db1 := d * (1 + 2 * (B.scales[ib32] and $0F));
      db2 := d * (1 + 2 * (B.scales[ib32] shr 4));

      // 32 valeurs : scale db1
      for l := 0 to 3 do
      begin
        sb := signs[l];

        idx := Cardinal(qs[2 * l + 0]) or ((Cardinal(qh[0]) shl (8 - 2 * l)) and $100);
        g := PByte(@IQ3S_GRID[idx]);
        for j := 0 to 3 do
        begin
          Dest^ := db1 * g[j] * SGN[((sb shr j) and 1) <> 0];
          Inc(Dest);
        end;

        idx := Cardinal(qs[2 * l + 1]) or ((Cardinal(qh[0]) shl (7 - 2 * l)) and $100);
        g := PByte(@IQ3S_GRID[idx]);
        for j := 0 to 3 do
        begin
          Dest^ := db1 * g[j] * SGN[((sb shr (j + 4)) and 1) <> 0];
          Inc(Dest);
        end;
      end;
      Inc(qs, 8);
      Inc(signs, 4);

      // 32 valeurs : scale db2
      for l := 0 to 3 do
      begin
        sb := signs[l];

        idx := Cardinal(qs[2 * l + 0]) or ((Cardinal(qh[1]) shl (8 - 2 * l)) and $100);
        g := PByte(@IQ3S_GRID[idx]);
        for j := 0 to 3 do
        begin
          Dest^ := db2 * g[j] * SGN[((sb shr j) and 1) <> 0];
          Inc(Dest);
        end;

        idx := Cardinal(qs[2 * l + 1]) or ((Cardinal(qh[1]) shl (7 - 2 * l)) and $100);
        g := PByte(@IQ3S_GRID[idx]);
        for j := 0 to 3 do
        begin
          Dest^ := db2 * g[j] * SGN[((sb shr (j + 4)) and 1) <> 0];
          Inc(Dest);
        end;
      end;
      Inc(qh, 2);
      Inc(qs, 8);
      Inc(signs, 4);
    end;
  end;
end;

// block_size = 32, kMaxQ = 8, grille 512 (D4 lattice), 8 sous-blocs / super-bloc
procedure QuantIQ3_S_Ref(pSrc: PSingle; Dest: PByte; n_row: Integer);
const
  kMaxQ = 8;
  IQ3S_BLOCK_SIZE = 32;
  BS4 = IQ3S_BLOCK_SIZE div 4; // 8 groupes de 4 valeurs
  BS8 = IQ3S_BLOCK_SIZE div 8; // 4 octets de signes
var
  nbl, ibl, ib, i, k, is_idx, grid_index, i8, l_val, l2, n_not_ongrid: Integer;
  y: PBlockIQ3_S;
  xbl, xb, qw: PSingle;
  grid: PUInt32;
  pg: PShortInt;
  scales, weight, xval, waux: array[0..IQ3S_BLOCK_SIZE - 1] of Single;
  l, Laux: array[0..IQ3S_BLOCK_SIZE - 1] of ShortInt;
  is_on_grid, is_on_grid_aux: array[0..BS4 - 1] of Boolean;
  block_signs: array[0..BS8 - 1] of Byte;
  sumx2, sigma2, max_val, best, scale, id, this_scale, sumqx, sumq2, w, q, d, max_scale: Single;
  s_byte: Byte;
  u: UInt16;
  neighbours_ptr: PUInt16;
begin
  if not iq3s_initialized then
    InitIQ3SGrid;

  // Assert(n_row mod QK_K = 0);
  nbl := n_row div QK_K;
  y := PBlockIQ3_S(Dest);
  grid := PUInt32(@IQ3S_GRID[0]);

  for ibl := 0 to nbl - 1 do
  begin
    FillChar(y[ibl], SizeOf(TBlockIQ3_S), 0); // y.d := FP32ToFP16(0) implicite
    max_scale := 0;
    xbl := @pSrc[QK_K * ibl];

    sumx2 := 0;
    for i := 0 to QK_K - 1 do
      sumx2 := sumx2 + xbl[i] * xbl[i];
    sigma2 := 2 * sumx2 / QK_K; // attention : facteur 2 (comme iq3_s, pas iq2_s)

    for ib := 0 to (QK_K div IQ3S_BLOCK_SIZE) - 1 do
    begin
      xb := xbl + IQ3S_BLOCK_SIZE * ib;

      for i := 0 to IQ3S_BLOCK_SIZE - 1 do
        weight[i] := xb[i] * xb[i]; // pas de 0.25*sigma2 ici (contrairement à IQ2_S)

      for i := 0 to IQ3S_BLOCK_SIZE - 1 do
        waux[i] := Sqrt(weight[i]);

      // Signes : pas de correction de parité en IQ3_S (différent de IQ2_XS / IQ3_XXS)
      for k := 0 to BS8 - 1 do
      begin
        s_byte := 0;
        for i := 0 to 7 do
          if xb[8 * k + i] >= 0 then
            xval[8 * k + i] := xb[8 * k + i]
          else
          begin
            xval[8 * k + i] := -xb[8 * k + i];
            s_byte := s_byte or (1 shl i);
          end;
        block_signs[k] := s_byte;
      end;

      max_val := xval[0];
      for i := 1 to IQ3S_BLOCK_SIZE - 1 do
        if xval[i] > max_val then
          max_val := xval[i];
      FillChar(l, SizeOf(l), 0);
      if max_val = 0 then // le C teste `if (!max)` pour iq3_s
      begin
        scales[ib] := 0;
        Continue;
      end;

      best := 0;
      scale := max_val / (2 * kMaxQ - 1);
      for k := 0 to BS4 - 1 do
        is_on_grid[k] := False; // le C initialise à FALSE ici (pas TRUE comme en IQ2_S)

      for is_idx := -9 to 9 do
      begin
        id := (((2 * kMaxQ - 1) + ((is_idx) * (0.2))) / max_val); // pas 0.1
        this_scale := 1 / id;

        for k := 0 to BS4 - 1 do
        begin
          for i := 0 to 3 do
          begin
            l_val := Round((0.5) * ((id * xval[4 * k + i]) - 1));
            Laux[4 * k + i] := uMath.MAX(0, uMath.MIN(kMaxQ - 1, l_val));
          end;
          u := 0;
          for i := 0 to 3 do
            u := u or (UInt16(Laux[4 * k + i]) shl (3 * i));
          grid_index := kmap_q3xs[u];
          is_on_grid_aux[k] := True;
          if grid_index < 0 then
          begin
            is_on_grid_aux[k] := False;
            neighbours_ptr := @kneighbors_q3xs[-grid_index - 1];
            grid_index := FindBestNeighbourIQ3(neighbours_ptr, grid, @xval[4 * k], @waux[4 * k], this_scale, @Laux[4 * k]);
          end;
        end;

        sumqx := 0;
        sumq2 := 0;
        for i := 0 to IQ3S_BLOCK_SIZE - 1 do
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
          for i := 0 to IQ3S_BLOCK_SIZE - 1 do
            l[i] := Laux[i];
          for k := 0 to BS4 - 1 do
            is_on_grid[k] := is_on_grid_aux[k];
        end;
      end;

      n_not_ongrid := 0;
      for k := 0 to BS4 - 1 do
        if not is_on_grid[k] then
          Inc(n_not_ongrid);

      if (n_not_ongrid > 0) and (scale > 0) then
      begin
        id := 1 / scale;
        for k := 0 to BS4 - 1 do
        begin
          // le C a commenté `if (is_on_grid[k]) continue;` => on reprojette TOUS les k
          u := 0;
          for i := 0 to 3 do
          begin
            l_val := Round((0.5) * ((id * xval[4 * k + i]) - 1));
            l_val := uMath.MAX(0, uMath.MIN(kMaxQ - 1, l_val));
            u := u or (UInt16(l_val) shl (3 * i));
          end;
          grid_index := kmap_q3xs[u];
          if grid_index < 0 then
          begin
            neighbours_ptr := @kneighbors_q3xs[-grid_index - 1];
            grid_index := FindBestNeighbourIQ3(neighbours_ptr, grid, @xval[4 * k], @waux[4 * k], scale, @l[4 * k]);
          end;
          pg := PShortInt(PByte(grid) + grid_index * 4);
          for i := 0 to 3 do
            l[4 * k + i] := (pg[i] - 1) div 2;
        end;

        sumqx := 0;
        sumq2 := 0;
        for i := 0 to IQ3S_BLOCK_SIZE - 1 do
        begin
          w := weight[i];
          q := (2 * l[i] + 1);
          sumqx := (sumqx + ((w * xval[i]) * q));
          sumq2 := (sumq2 + (w * (q * q)));
        end;
        if sumq2 > 0 then
          scale := (sumqx / sumq2);
      end;

      if scale < 0 then
      begin
        scale := (-scale);
        for k := 0 to BS8 - 1 do
          block_signs[k] := not block_signs[k]; // octet complet (pas & 127)
      end;

      for k := 0 to BS4 - 1 do
      begin
        u := 0;
        for i := 0 to 3 do
          u := u or (UInt16(l[4 * k + i]) shl (3 * i));
        grid_index := kmap_q3xs[u];
        if grid_index < 0 then
          raise EGGML.CreateFmt('Oops: point %u hors grille IQ3_S', [u]);
        i8 := ib * BS4 + k; // 0..63
        y[ibl].qs[i8] := Byte(grid_index and 255);
        y[ibl].qh[i8 shr 3] := y[ibl].qh[i8 shr 3] or Byte((grid_index shr 8) shl (i8 and 7));
      end;
      for k := 0 to BS8 - 1 do
        y[ibl].signs[ib * BS8 + k] := block_signs[k];

      scales[ib] := scale;
      if scale > max_scale then
        max_scale := scale;
    end;

    if max_scale = 0 then
      Continue;

    d := (max_scale / 31);
    y[ibl].d := FP32ToFP16((d * (1.033))); // fudge factor IQ3_S (id est calculé avec d non fudgé)
    id := 1 / d;
    ib := 0;
    while ib < (QK_K div IQ3S_BLOCK_SIZE) do
    begin
      l_val := Round((0.5) * ((id * scales[ib]) - 1));
      l_val := uMath.MAX(0, uMath.MIN(15, l_val));
      l2 := Round((0.5) * ((id * scales[ib + 1]) - 1));
      l2 := uMath.MAX(0, uMath.MIN(15, l2));
      y[ibl].scales[ib div 2] := Byte(l_val or (l2 shl 4));
      Inc(ib, 2);
    end;
  end;
end;

procedure QuantIQ3_S_Impl1(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle; iQk: Integer);
const
  kBlock = 32;
  kMaxQ = 8;
  kMaxQ1 = kMaxQ - 1;
  kBS4 = kBlock div 4; // 8
  kBS8 = kBlock div 8; // 4
  qtab: array[0..kMaxQ1] of Single = (1.0, 3.0, 5.0, 7.0, 9.0, 11.0, 13.0, 15.0);
var
  nbl, ibl, ib, i, k, is_idx, grid_index, i8, l2, l_val, n_not_ongrid: Integer;
  y: PBlockIQ3_S;
  xbl, xb, qw: PSingle;
  kmapPtr: PInteger;
  kneiPtr: PUInt16;
  kgridPtr: PUInt32;
  pg: PShortInt;
  scales, weight, xval, waux: array[0..kBlock - 1] of Single;
  l, Laux: array[0..kBlock - 1] of ShortInt;
  is_on_grid, is_on_grid_aux: array[0..kBS4 - 1] of Boolean;
  block_signs: array[0..kBS8 - 1] of Byte;
  sumx2, sigma2, xv, max_val, best, scale, id, this_scale, ww, sumqx, sumq2, w, q, d, max_scale: Single;
  s_byte: Byte;
  u: Word;
  neighbours_ptr: PUInt16;
  cfgQK: PQuantPreset;
begin
  cfgQK := cfg.ggmlReg.GetPPreset(GGML_TYPE_IQ3_S, iQk);

  if not iq3s_initialized then
    InitIQ3SGrid;

  kmapPtr := @kmap_q3xs[0];
  kneiPtr := @kneighbors_q3xs[0];
  kgridPtr := @IQ3S_GRID[0];

  nbl := n_row div QK_K;
  y := PBlockIQ3_S(Dest);

  for ibl := 0 to nbl - 1 do
  begin
    FillChar(y[ibl], SizeOf(TBlockIQ3_S), 0);

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
      // Comportement conservé par rapport à ton QuantIQ3_S_Impl actuel.
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

      for k := 0 to kBS8 - 1 do
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

      if max_val = 0 then
      begin
        scales[ib] := 0;
        Continue;
      end;

      best := 0;
      scale := max_val / (2 * kMaxQ1);

      for k := 0 to kBS4 - 1 do
        is_on_grid[k] := False;

      for is_idx := -cfgQK.Nstep to cfgQK.Nstep do
      begin
        id := ((2 * kMaxQ1) + (is_idx * cfgQK.Rdelta)) / max_val;
        this_scale := 1 / id;

        for k := 0 to kBS4 - 1 do
        begin
          u := 0;

          for i := 0 to 3 do
          begin
            l_val := Round(0.5 * ((id * xval[4 * k + i]) - 1));

            if l_val < 0 then
              l_val := 0
            else if l_val > kMaxQ1 then
              l_val := kMaxQ1;

            Laux[4 * k + i] := ShortInt(l_val);
            u := u or (Word(l_val) shl (3 * i));
          end;

          grid_index := kmapPtr[u];
          is_on_grid_aux[k] := True;

          if grid_index < 0 then
          begin
            is_on_grid_aux[k] := False;
            neighbours_ptr := @kneiPtr[(-grid_index) - 1];

            grid_index := FindBestNeighbourIQ3(neighbours_ptr, kgridPtr, @xval[4 * k], @waux[4 * k], this_scale, @Laux[4 * k]);
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

          for k := 0 to kBS4 - 1 do
            is_on_grid[k] := is_on_grid_aux[k];
        end;
      end;

      n_not_ongrid := 0;
      for k := 0 to kBS4 - 1 do
        if not is_on_grid[k] then
          Inc(n_not_ongrid);

      if (n_not_ongrid > 0) and (scale > 0) then
      begin
        id := 1 / scale;

        for k := 0 to kBS4 - 1 do
        begin
          u := 0;

          for i := 0 to 3 do
          begin
            l_val := Round(0.5 * ((id * xval[4 * k + i]) - 1));

            if l_val < 0 then
              l_val := 0
            else if l_val > kMaxQ1 then
              l_val := kMaxQ1;

            u := u or (Word(l_val) shl (3 * i));
          end;

          grid_index := kmapPtr[u];

          if grid_index < 0 then
          begin
            neighbours_ptr := @kneiPtr[(-grid_index) - 1];

            grid_index := FindBestNeighbourIQ3(neighbours_ptr, kgridPtr, @xval[4 * k], @waux[4 * k], scale, @l[4 * k]);
          end;

          pg := PShortInt(PByte(kgridPtr) + grid_index * 4);

          for i := 0 to 3 do
            l[4 * k + i] := ShortInt((pg[i] - 1) div 2);
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

        for k := 0 to kBS8 - 1 do
          block_signs[k] := not block_signs[k];
      end;

      for k := 0 to kBS4 - 1 do
      begin
        u := 0;

        for i := 0 to 3 do
          u := u or (Word(l[4 * k + i]) shl (3 * i));

        grid_index := kmapPtr[u];

        if grid_index < 0 then
          raise EGGML.CreateFmt('Oops: point %u hors grille IQ3_S', [u]);

        i8 := (ib shl 3) + k;

        y[ibl].qs[i8] := Byte(grid_index and 255);
        y[ibl].qh[i8 shr 3] := Byte(y[ibl].qh[i8 shr 3] or ((grid_index shr 8) shl (i8 and 7)));
      end;

      for k := 0 to kBS8 - 1 do
        y[ibl].signs[(ib shl 2) + k] := block_signs[k];

      scales[ib] := scale;

      if scale > max_scale then
        max_scale := scale;
    end;

    if max_scale = 0 then
      Continue;

    d := max_scale / 31;
    y[ibl].d := FP32ToFP16(d * 1.033);

    id := 1 / d;

    ib := 0;
    while ib < (QK_K div kBlock) do
    begin
      l_val := Round(0.5 * ((id * scales[ib]) - 1));
      if l_val < 0 then
        l_val := 0
      else if l_val > 15 then
        l_val := 15;

      l2 := Round(0.5 * ((id * scales[ib + 1]) - 1));
      if l2 < 0 then
        l2 := 0
      else if l2 > 15 then
        l2 := 15;

      y[ibl].scales[ib shr 1] := Byte(l_val or (l2 shl 4));
      Inc(ib, 2);
    end;
  end;
end;

procedure QuantIQ3_S_Impl2(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
begin
  QuantIQ3_S_Impl1(pSrc, Dest, n_row, qWeights, QP_PROF_IMPL2);
end;

procedure QuantIQ3_S_Impl3(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
begin
  QuantIQ3_S_Impl1(pSrc, Dest, n_row, qWeights, QP_PROF_IMPL3);
end;

procedure QuantIQ3_S_Impl4(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
begin
  QuantIQ3_S_Impl1(pSrc, Dest, n_row, qWeights, QP_PROF_IMPL4);
end;

procedure QuantIQ3_S_Impl5(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
begin
  QuantIQ3_S_Impl1(pSrc, Dest, n_row, qWeights, QP_PROF_IMPL5);
end;

initialization

finalization
  FreeIQ3SGrid;

end.

