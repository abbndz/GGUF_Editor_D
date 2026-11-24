unit uGgmlQuantsIQ3_XXS;

{ IQ3_XXS (3.0625 bpw) — déquantisation + quantisation
  Portage fidèle de ggml-quants.c :
  - dequantize_row_iq3_xxs()
  - quantize_row_iq3_xxs_impl(grid_size = 256, ...)
  - iq3xs_init_impl(256) / iq3_find_best_neighbour()

  Bloc (TBlockIQ3_XXS dans uGGMLConstants) = 98 octets pour QK_K = 256 :
  qs[0  ..63] : 64 index de grille 8 bits (0..255) -> 4 valeurs / index (1 octet / valeur)
  qs[64 ..95] : 8 Cardinal (little endian) "scales_and_signs"
  bits  0..27 : 4 x 7 bits de signes   (un champ de 7 bits par groupe k)
  bits 28..31 : sous-échelle 4 bits du sous-bloc de 32
  d           : FP16 (échelle globale, fudge factor 1.0125)

  Grille :
  * Déquantisation : IQ3XXS_GRID (valeurs apprises 4,12,20,28,36,44,52,62).
  * Recherche quantif : grille D4 "2*l+1" (1,3,5,..,15).  Comme kgrid_256[k]
  et IQ3XXS_GRID[k] décrivent le même index (octet = v[l]), la grille de
  recherche est DERIVEE de IQ3XXS_GRID => pas besoin de recopier kgrid_256.
  (Assert(GRID256OK) vérifie ce postulat à l'init.) }

interface

uses
  SysUtils, Math, Generics.Defaults, Generics.Collections,
  uGGMLTypes, uGGMLConstants, uGgmlQuantsFP16, uGgmlQuantsIQGRIDs, uAppConfig;

{$POINTERMATH ON}
{$O+}
{$ALIGN 8}
procedure DequantIQ3_XXS(const Data: PByte; Dest: PSingle; n_row: Integer);
procedure QuantIQ3_XXS_Ref(pSrc: PSingle; Dest: PByte; n_row: Integer);
procedure QuantIQ3_XXS_Impl1(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil; iQk: Integer = QP_PROF_IMPL1);
procedure QuantIQ3_XXS_Impl2(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
procedure QuantIQ3_XXS_Impl3(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
procedure QuantIQ3_XXS_Impl4(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
procedure QuantIQ3_XXS_Impl5(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);

implementation

uses
  uLog;

// x = d * (0.5 + L) * 0.5 * grille8 * signe   (L = échelle 4 bits, 7 bits de signes / k)
procedure DequantIQ3_XXS(const Data: PByte; Dest: PSingle; n_row: Integer);
var
  nb, i, ib32, l, j: Integer;
  B: PBlockIQ3_XXS;
  d, db, s: Single;
  aux32: Cardinal;
  qs: PByte;
  scales_and_signs: PCu32;
  g1, g2: PByte;
  signs: Byte;
begin
  // Assert(n_row mod QK_K = 0, 'n_row doit être un multiple de QK_K (256)');
  nb := n_row div QK_K;

  for i := 0 to nb - 1 do
  begin
    B := PBlockIQ3_XXS(Data + Int64(i) * SizeOf(TBlockIQ3_XXS));
    d := FP16ToFP32(B.d);
    qs := @B.qs[0];
    scales_and_signs := PCu32(@B.qs[QK_K div 4]); // octet 64 : 8 x Cardinal

    for ib32 := 0 to (QK_K div 32) - 1 do
    begin
      aux32 := scales_and_signs^;
      Inc(scales_and_signs);
      db := ((d * (0.5 + (aux32 shr 28))) * 0.5);

      for l := 0 to 3 do
      begin
        signs := KSIGNS_IQ2XS[(aux32 shr (7 * l)) and 127];
        g1 := PByte(@IQ3XXS_GRID[qs[2 * l + 0]]);
        g2 := PByte(@IQ3XXS_GRID[qs[2 * l + 1]]);

        for j := 0 to 3 do
        begin
          if (signs and KMASK_IQ2XS[j]) <> 0 then
            s := -1.0
          else
            s := 1.0;
          Dest^ := db * g1[j] * s;
          Inc(Dest);
        end;

        for j := 0 to 3 do
        begin
          if (signs and KMASK_IQ2XS[j + 4]) <> 0 then
            s := -1.0
          else
            s := 1.0;
          Dest^ := db * g2[j] * s;
          Inc(Dest);
        end;
      end;
      Inc(qs, 8);
    end;
  end;
end;

// ================================ QUANTISATION ==============================
// grid_size = 256, kMaxQ = 8, sous-blocs de 32 (8 par super-bloc), is  de -15..15 (pas 0.2)
procedure QuantIQ3_XXS_Ref(pSrc: PSingle; Dest: PByte; n_row: Integer);
const
  kMaxQ = 8;
  BS = 32; // sous-bloc IQ3_XXS
  BS4 = 8; // groupes de 4 valeurs
  BS8 = 4; // groupes de 8 valeurs (octets de signes)
var
  nbl, ibl, ib, i, k, is_idx, grid_index, nflip, imin, l_val, n_not_ongrid: Integer;
  y: PBlockIQ3_XXS;
  xbl, xb: PSingle;
  scales_and_signs: PCu32;
  grid: PUInt32;
  pg: PShortInt;
  scales, weight, xval, waux: array [0 .. BS - 1] of Single;
  l, Laux: array [0 .. BS - 1] of ShortInt;
  is_on_grid, is_on_grid_aux: array [0 .. BS4 - 1] of Boolean;
  block_signs: array [0 .. BS8 - 1] of Byte;
  sumx2, sigma2, max_val, min_w, ax, best, scale, id, this_scale, sumqx, sumq2, w, q, d, max_scale: Single;
  s_byte: Byte;
  u: UInt16;
  neighbours_ptr: PUInt16;
begin
  if not iq3xxs_initialized then
    InitIQ3XXSGrid;

  // Assert(n_row mod QK_K = 0);
  nbl := n_row div QK_K;
  y := PBlockIQ3_XXS(Dest);
  grid := PUInt32(@kgrid_q3xxs[0]); // grille de recherche (2*l+1)

  for ibl := 0 to nbl - 1 do
  begin
    // C : dh[0] = FP32_TO_FP16(0) + memset(q3) + memcpy final
    // Comme aucune écriture n'a lieu quand max_scale = 0, le zéro complet équivaut.
    FillChar(y[ibl], SizeOf(TBlockIQ3_XXS), 0);
    max_scale := 0;
    xbl := pSrc + QK_K * ibl;

    sumx2 := 0;
    for i := 0 to QK_K - 1 do
      sumx2 := sumx2 + xbl[i] * xbl[i];
    sigma2 := 2 * sumx2 / QK_K;

    for ib := 0 to 7 do
    begin
      xb := @xbl[BS * ib];
      scales_and_signs := PCu32(@y[ibl].qs[64 + 4 * ib]);

      for i := 0 to 31 do
        weight[i] := xb[i] * xb[i];

      for i := 0 to 31 do
        waux[i] := Sqrt(weight[i]);

      // Signes avec correction de parité (nflip impair -> on repousse le |x|² pondéré minimal)
      for k := 0 to BS8 - 1 do
      begin
        nflip := 0;
        s_byte := 0;
        for i := 0 to 7 do
          if xb[8 * k + i] >= 0 then
            xval[8 * k + i] := xb[8 * k + i]
          else
          begin
            xval[8 * k + i] := -xb[8 * k + i];
            Inc(nflip);
            s_byte := s_byte or (1 shl i);
          end;
        if (nflip mod 2) <> 0 then
        begin
          imin := 0;
          min_w := weight[8 * k] * (xb[8 * k] * xb[8 * k]);
          for i := 1 to 7 do
          begin
            ax := weight[8 * k + i] * (xb[8 * k + i] * xb[8 * k + i]);
            if ax < min_w then
            begin
              min_w := ax;
              imin := i;
            end;
          end;
          xval[8 * k + imin] := -xval[8 * k + imin];
          s_byte := s_byte xor (1 shl imin);
        end;
        block_signs[k] := s_byte and 127;
      end;

      max_val := xval[0];
      for i := 1 to BS - 1 do
        if xval[i] > max_val then
          max_val := xval[i];
      FillChar(l, SizeOf(l), 0);
      if max_val < GROUP_MAX_EPS_IQ3_XXS then // ici un vrai seuil (contrairement à IQ3_S)
      begin
        scales[ib] := 0;
        Continue;
      end;

      best := 0;
      scale := (max_val / (2 * kMaxQ - 1));
      for k := 0 to BS4 - 1 do
        is_on_grid[k] := True; // IQ3_XXS : TRUE (IQ3_S : FALSE)

      for is_idx := -15 to 15 do // 31 essais (IQ3_S : -9..9)
      begin
        id := ((2 * kMaxQ - 1) + (is_idx * 0.2)) / max_val;
        this_scale := 1 / id;

        for k := 0 to BS4 - 1 do
        begin
          for i := 0 to 3 do
          begin
            l_val := Round(0.5 * ((id * xval[4 * k + i]) - 1));
            Laux[4 * k + i] := MAX(0, MIN(kMaxQ - 1, l_val));
          end;
          u := 0;
          for i := 0 to 3 do
            u := u or (UInt16(Laux[4 * k + i]) shl (3 * i));
          grid_index := kmap_q3xxs[u];
          is_on_grid_aux[k] := True;
          if grid_index < 0 then
          begin
            is_on_grid_aux[k] := False;
            neighbours_ptr := @kneighbors_q3xxs[-grid_index - 1];
            grid_index := FindBestNeighbourIQ3XXS(neighbours_ptr, grid, @xval[4 * k], @waux[4 * k], this_scale,
              @Laux[4 * k]);
          end;
        end;

        sumqx := 0;
        sumq2 := 0;
        for i := 0 to BS - 1 do
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
          for i := 0 to BS - 1 do
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
          if is_on_grid[k] then // actif en IQ3_XXS (commenté en IQ3_S)
            Continue;
          u := 0;
          for i := 0 to 3 do
          begin
            l_val := Round(0.5 * ((id * xval[4 * k + i]) - 1));
            l_val := MAX(0, MIN(kMaxQ - 1, l_val));
            u := u or (UInt16(l_val) shl (3 * i));
          end;
          grid_index := kmap_q3xxs[u];
          if grid_index < 0 then
          begin
            neighbours_ptr := @kneighbors_q3xxs[-grid_index - 1];
            grid_index := FindBestNeighbourIQ3XXS(neighbours_ptr, grid, @xval[4 * k], @waux[4 * k], scale, @l[4 * k]);
          end;
          pg := PShortInt(PByte(grid) + grid_index * 4);
          for i := 0 to 3 do
            l[4 * k + i] := (pg[i] - 1) div 2;
        end;

        sumqx := 0;
        sumq2 := 0;
        for i := 0 to BS - 1 do
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
        for k := 0 to BS8 - 1 do
          block_signs[k] := (not block_signs[k]) and 127; // le C : (~s) & 127
      end;

      for k := 0 to BS4 - 1 do
      begin
        u := 0;
        for i := 0 to 3 do
          u := u or (UInt16(l[4 * k + i]) shl (3 * i));
        grid_index := kmap_q3xxs[u];
        if grid_index < 0 then
          raise EGGML.CreateFmt('Oops: point %u hors grille IQ3_XXS', [u]);
        y[ibl].qs[8 * ib + k] := Byte(grid_index and 255); // 8 bits, pas de qh en IQ3_XXS
      end;
      scales_and_signs^ := Cardinal(block_signs[0]) or (Cardinal(block_signs[1]) shl 7) or
        (Cardinal(block_signs[2]) shl 14) or (Cardinal(block_signs[3]) shl 21);

      // GGML_ASSERT(scale >= 0)
      scales[ib] := scale;
      if scale > max_scale then
        max_scale := scale;
    end;

    if max_scale = 0 then
      Continue; // bloc déjà entièrement à zéro

    d := max_scale / 31;
    y[ibl].d := FP32ToFP16(d * 1.0125); // fudge factor IQ3_XXS (id avec d non fudgé)
    id := 1 / d;
    scales_and_signs := PCu32(@y[ibl].qs[64]);
    for ib := 0 to NBLOCK32_IQ3_XXS - 1 do
    begin
      l_val := Round(0.5 * ((id * scales[ib]) - 1));
      l_val := MAX(0, MIN(15, l_val));
      scales_and_signs^ := scales_and_signs^ or (Cardinal(l_val) shl 28);
      Inc(scales_and_signs);
    end;
  end;
end;

procedure QuantIQ3_XXS_Impl1(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil; iQk: Integer = QP_PROF_IMPL1);
const
  kMaxQ = 8;
  BS = 32; // sous-bloc IQ3_XXS
  BS4 = 8; // groupes de 4 valeurs
  BS8 = 4; // groupes de 8 valeurs (octets de signes)
var
  nbl, ibl, ib, i, k, is_idx, grid_index, nflip, imin, l_val, n_not_ongrid: Integer;
  y: PBlockIQ3_XXS;
  xbl, xb, qw: PSingle;
  scales_and_signs: PCu32;
  grid: PUInt32;
  pg: PShortInt;
  scales, weight, xval, waux: array [0 .. BS - 1] of Single;
  l, Laux: array [0 .. BS - 1] of ShortInt;
  is_on_grid, is_on_grid_aux: array [0 .. BS4 - 1] of Boolean;
  block_signs: array [0 .. BS8 - 1] of Byte;
  sumx2, sigma2, max_val, min_w, ax, best, scale, id, this_scale, sumqx, sumq2, w, q, d, max_scale: Single;
  s_byte: Byte;
  u: UInt16;
  neighbours_ptr: PUInt16;
  cfgQK: PQuantPreset;
begin
  cfgQK := cfg.ggmlReg.GetPPreset(GGML_TYPE_IQ3_XXS, iQk);
  if not iq3xxs_initialized then
    InitIQ3XXSGrid;

  // Assert(n_row mod QK_K = 0);
  nbl := n_row div QK_K;
  y := PBlockIQ3_XXS(Dest);
  grid := PUInt32(@kgrid_q3xxs[0]); // grille de recherche (2*l+1)

  for ibl := 0 to nbl - 1 do
  begin
    FillChar(y[ibl], SizeOf(TBlockIQ3_XXS), 0);
    max_scale := 0;
    xbl := @pSrc[QK_K * ibl];

    sumx2 := 0;
    for i := 0 to QK_K - 1 do
      sumx2 := sumx2 + xbl[i] * xbl[i];
    sigma2 := 2 * sumx2 / QK_K;

    for ib := 0 to 7 do
    begin
      xb := xbl + BS * ib;
      scales_and_signs := PCu32(@y[ibl].qs[64 + 4 * ib]);

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
              w := Sqrt(Abs(xb[i]));
            3:
              w := Abs(xb[i]);
            4:
              w := Sqr(xb[i]);
          else
            w := 1.0;
          end;
          if cfgQK.RmseType = 0 then
            weight[i] := Sqr(xb[i])
          else
            weight[i] := w * Sqrt(sigma2 + (xb[i] * xb[i]));
          // weight[i] := w; // w * Sqrt(sigma2 + (xb[i] * xb[i]));
        end;
      end;

      for i := 0 to BS - 1 do
        waux[i] := Sqrt(weight[i]);

      // Signes avec correction de parité (nflip impair -> on repousse le |x|² pondéré minimal)
      for k := 0 to BS8 - 1 do
      begin
        nflip := 0;
        s_byte := 0;
        for i := 0 to 7 do
          if xb[8 * k + i] >= 0 then
            xval[8 * k + i] := xb[8 * k + i]
          else
          begin
            xval[8 * k + i] := -xb[8 * k + i];
            Inc(nflip);
            s_byte := s_byte or (1 shl i);
          end;
        if (nflip mod 2) <> 0 then
        begin
          imin := 0;
          min_w := weight[8 * k] * (xb[8 * k] * xb[8 * k]);
          for i := 1 to 7 do
          begin
            ax := weight[8 * k + i] * (xb[8 * k + i] * xb[8 * k + i]);
            if ax < min_w then
            begin
              min_w := ax;
              imin := i;
            end;
          end;
          xval[8 * k + imin] := -xval[8 * k + imin];
          s_byte := s_byte xor (1 shl imin);
        end;
        block_signs[k] := s_byte and 127;
      end;

      max_val := xval[0];
      for i := 1 to BS - 1 do
        if xval[i] > max_val then
          max_val := xval[i];
      FillChar(l, SizeOf(l), 0);
      if max_val < GROUP_MAX_EPS_IQ3_XXS then // ici un vrai seuil (contrairement à IQ3_S)
      begin
        scales[ib] := 0;
        Continue;
      end;

      best := 0;
      scale := (max_val / (2 * kMaxQ - 1));
      for k := 0 to BS4 - 1 do
        is_on_grid[k] := True; // IQ3_XXS : TRUE (IQ3_S : FALSE)

      // for is_idx := -15 to 15 do // 31 essais (IQ3_S : -9..9)
      for is_idx := -cfgQK.Nstep to cfgQK.Nstep do
      begin
        // id := ((2 * kMaxQ - 1) + (is_idx * 0.2)) / max_val;
        id := (((2 * kMaxQ - 1) + (is_idx * cfgQK.Rdelta)) / max_val);

        this_scale := 1 / id;

        for k := 0 to BS4 - 1 do
        begin
          for i := 0 to 3 do
          begin
            l_val := Round(0.5 * ((id * xval[4 * k + i]) - 1));
            Laux[4 * k + i] := MAX(0, MIN(kMaxQ - 1, l_val));
          end;
          u := 0;
          for i := 0 to 3 do
            u := u or (UInt16(Laux[4 * k + i]) shl (3 * i));
          grid_index := kmap_q3xxs[u];
          is_on_grid_aux[k] := True;
          if grid_index < 0 then
          begin
            is_on_grid_aux[k] := False;
            neighbours_ptr := @kneighbors_q3xxs[-grid_index - 1];
            grid_index := FindBestNeighbourIQ3XXS(neighbours_ptr, grid, @xval[4 * k], @waux[4 * k], this_scale,
              @Laux[4 * k]);
          end;
        end;

        sumqx := 0;
        sumq2 := 0;
        for i := 0 to BS - 1 do
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
          for i := 0 to BS - 1 do
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
          if is_on_grid[k] then // actif en IQ3_XXS (commenté en IQ3_S)
            Continue;
          u := 0;
          for i := 0 to 3 do
          begin
            l_val := Round(0.5 * ((id * xval[4 * k + i]) - 1));
            l_val := MAX(0, MIN(kMaxQ - 1, l_val));
            u := u or (UInt16(l_val) shl (3 * i));
          end;
          grid_index := kmap_q3xxs[u];
          if grid_index < 0 then
          begin
            neighbours_ptr := @kneighbors_q3xxs[-grid_index - 1];
            grid_index := FindBestNeighbourIQ3XXS(neighbours_ptr, grid, @xval[4 * k], @waux[4 * k], scale, @l[4 * k]);
          end;
          pg := PShortInt(PByte(grid) + grid_index * 4);
          for i := 0 to 3 do
            l[4 * k + i] := (pg[i] - 1) div 2;
        end;

        sumqx := 0;
        sumq2 := 0;
        for i := 0 to BS - 1 do
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
        for k := 0 to BS8 - 1 do
          block_signs[k] := (not block_signs[k]) and 127; // le C : (~s) & 127
      end;

      for k := 0 to BS4 - 1 do
      begin
        u := 0;
        for i := 0 to 3 do
          u := u or (UInt16(l[4 * k + i]) shl (3 * i));
        grid_index := kmap_q3xxs[u];
        if grid_index < 0 then
          raise EGGML.CreateFmt('Oops: point %u hors grille IQ3_XXS', [u]);
        y[ibl].qs[8 * ib + k] := Byte(grid_index and 255); // 8 bits, pas de qh en IQ3_XXS
      end;
      scales_and_signs^ := Cardinal(block_signs[0]) or (Cardinal(block_signs[1]) shl 7) or
        (Cardinal(block_signs[2]) shl 14) or (Cardinal(block_signs[3]) shl 21);

      // GGML_ASSERT(scale >= 0)
      scales[ib] := scale;
      if scale > max_scale then
        max_scale := scale;
    end;

    if max_scale = 0 then
      Continue; // bloc déjà entièrement à zéro

    d := max_scale / 31;
    y[ibl].d := FP32ToFP16(d * 1.0125); // fudge factor IQ3_XXS (id avec d non fudgé)
    id := 1 / d;
    scales_and_signs := PCu32(@y[ibl].qs[64]);
    for ib := 0 to NBLOCK32_IQ3_XXS - 1 do
    begin
      l_val := Round(0.5 * ((id * scales[ib]) - 1));
      l_val := MAX(0, MIN(15, l_val));
      scales_and_signs^ := scales_and_signs^ or (Cardinal(l_val) shl 28);
      Inc(scales_and_signs);
    end;
  end;
end;

procedure QuantIQ3_XXS_Impl2(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
begin
  QuantIQ3_XXS_Impl1(pSrc, Dest, n_row, qWeights, QP_PROF_IMPL2);
end;

procedure QuantIQ3_XXS_Impl3(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
begin
  QuantIQ3_XXS_Impl1(pSrc, Dest, n_row, qWeights, QP_PROF_IMPL3);
end;

procedure QuantIQ3_XXS_Impl4(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
begin
  QuantIQ3_XXS_Impl1(pSrc, Dest, n_row, qWeights, QP_PROF_IMPL4);
end;

procedure QuantIQ3_XXS_Impl5(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
begin
  QuantIQ3_XXS_Impl1(pSrc, Dest, n_row, qWeights, QP_PROF_IMPL5);
end;

initialization

finalization

FreeIQ3XXSGrid;

end.
