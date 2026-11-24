unit uGgmlQuantsiq1_M;

{ ============================================================================
  IQ1_M (1.75 bpw) - dequantisation + quantisation
  Portage de ggml-quants.c :
  - dequantize_row_iq1_m()
  - quantize_row_iq1_m_impl()   (IQ1M_BLOCK_SIZE = 16)

  Bloc (TBlockIQ1_M) = 56 octets pour QK_K = 256  (AUCUN champ d:Word !) :
  qs     [0..31] : index de grille, bits 0..7   (2 par bloc de 16)
  qh     [0..15] : 1 octet par bloc de 16
  bits 0..2 : index grille groupe 0 (bits 8..10)
  bit     3 : delta groupe 0 (1 => -delta)
  bits 4..6 : index grille groupe 1 (bits 8..10)
  bit     7 : delta groupe 1 (1 => -delta)
  scales [0..7 ] : 4 uint16.  Chaque uint16 = 4 echelles de 3 bits (12 bits)
  + 1 nibble de l'FP16 super-block (bits 12..15).

  Une echelle de 3 bits par bloc de 16 (contre 4 bits par bloc de 32 en IQ1_S)
  + 2 deltas independants par bloc de 16 (contre 1 seul pour les 32 en IQ1_S)
  = +0.1875 bpw, utilises la ou ils rapportent le plus.

  Grille : la MEME que IQ1_S (C : iq2_data_index(IQ1_M) == gindex de IQ1_S,
  nwant = 3) -> kgrid_q1s / kmap_q1s / kneighbors_q1s / InitIQ1SGrid.
  NB : le C lit les valeurs via la LATTICE (octets 1,3,5) pour (pg-1)/2, et
  les valeurs reelles (-1,0,+1) via iq1s_grid en dequant.  Le delta dequant
  utilise IQ1S_DELTA (egalement 0.125) : conserve tel quel.
  ============================================================================ }

interface

uses
  SysUtils, Classes, uGGMLTypes, Generics.Defaults, Generics.Collections, uGGMLConstants, uMath, uLog, uAppConfig,
  uGgmlQuantsFP16;

{$POINTERMATH ON}
{$O+}
{$ALIGN 8}
procedure DequantIQ1_M(const Data: PByte; Dest: PSingle; n_row: Integer);
procedure QuantIQ1_M_Ref(pSrc: PSingle; Dest: PByte; n_row: Integer);
procedure QuantIQ1_M_Impl1(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil; iQk: Integer = QP_PROF_IMPL1);
procedure QuantIQ1_M_Impl2(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
procedure QuantIQ1_M_Impl3(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
procedure QuantIQ1_M_Impl4(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
procedure QuantIQ1_M_Impl5(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);

implementation

uses uGgmlQuantsIQGRIDs, uGgmlQuantsiq1_S; // TValIdx / CmpValIdx partages

const
  IQ1M_BLOCK_SIZE = 16; // C : #define IQ1M_BLOCK_SIZE 16
  IQ1M_MASKS: array [0 .. 3] of Byte = ($00, $80, $08, $88); // bits delta qh

  // ============================== DEQUANTISATION ==============================
procedure DequantIQ1_M(const Data: PByte; Dest: PSingle; n_row: Integer);
var
  nb, i, ib, l, j, l16: Integer;
  qhA, qhB: Byte;
  B: PBlockIQ1_M;
  sc: PWord; // scales[8] viewed as 4 uint16
  s16: Word;
  d, dl1, dl2: Single;
  qs: PByte;
  qh: PByte; // 1 octet par bloc de 16
  grid: PShortInt;
  delta: array [0 .. 3] of Single;
  idx: array [0 .. 3] of Word;
begin
  // Assert(n_row mod QK_K = 0);
  nb := n_row div QK_K;

  for i := 0 to nb - 1 do
  begin
    B := PBlockIQ1_M(Data + Int64(i) * SizeOf(TBlockIQ1_M));
    sc := PWord(@B.scales[0]);

    // Reconstitution du FP16 du super-block : un nibble dans chaque uint16
    s16 := (sc[0] shr 12) or ((sc[1] shr 8) and $00F0) or ((sc[2] shr 4) and $0F00) or (sc[3] and $F000);
    d := FP16ToFP32(s16);

    qs := @B.qs[0];
    qh := @B.qh[0];

    for ib := 0 to (QK_K div 32) - 1 do // 8 blocs de 32
    begin
      l16 := 6 * (ib and 1);
      dl1 := d * (2 * ((sc[ib shr 1] shr l16) and 7) + 1); // 16 premiers
      dl2 := d * (2 * ((sc[ib shr 1] shr (l16 + 3)) and 7) + 1); // 16 derniers

      // idx0 := qs[2 * ib]; // bloc de 16 n0 = 2*ib
      // idx1 := qs[2 * ib + 1];
      // C : qs += 4 / qh += 2 par bloc de 32  => index absolus 4*ib et 2*ib
      qhA := qh[2 * ib]; // octet qh du bloc de 16 n 2*ib  (16 premiers)
      qhB := qh[2 * ib + 1]; // octet qh du bloc de 16 n 2*ib+1 (16 derniers)

      idx[0] := qs[4 * ib + 0] or ((qhA shl 8) and $700);
      idx[1] := qs[4 * ib + 1] or ((qhA shl 4) and $700);
      idx[2] := qs[4 * ib + 2] or ((qhB shl 8) and $700); // PAS qs[4*ib+0] !
      idx[3] := qs[4 * ib + 3] or ((qhB shl 4) and $700); // PAS qs[4*ib+1] !

      if (qhA and $08) <> 0 then
        delta[0] := -IQ1S_DELTA
      else
        delta[0] := IQ1S_DELTA;
      if (qhA and $80) <> 0 then
        delta[1] := -IQ1S_DELTA
      else
        delta[1] := IQ1S_DELTA;
      if (qhB and $08) <> 0 then
        delta[2] := -IQ1S_DELTA
      else
        delta[2] := IQ1S_DELTA;
      if (qhB and $80) <> 0 then
        delta[3] := -IQ1S_DELTA
      else
        delta[3] := IQ1S_DELTA;

      for l := 0 to 1 do // 16 elements -> dl1
      begin
        grid := PShortInt(@IQ1S_GRID[idx[l]]);
        for j := 0 to 7 do
        begin
          Dest^ := dl1 * (grid[j] + delta[l]);
          Inc(Dest);
        end;
      end;
      for l := 2 to 3 do // 16 elements -> dl2
      begin
        grid := PShortInt(@IQ1S_GRID[idx[l]]);
        for j := 0 to 7 do
        begin
          Dest^ := dl2 * (grid[j] + delta[l]);
          Inc(Dest);
        end;
      end;
    end;
  end;
end;

// groupe k = 0 -> 8 premiers  -> table = x_m ssi best_k >= 2   (bit 1)
// groupe k = 1 -> 8 derniers  -> table = x_m ssi best_k   = 1  (bit 0)
function UseM(best_k, k: Integer): Boolean; inline;
begin
  if k = 0 then
      Result := best_k >= 2
  else
    Result := (best_k and 1) <> 0;
end;


function IQ1M_UseXm(const best_k, k: Integer): Boolean; inline;
begin
  // k = 0 : premier groupe de 8 -> signe de la première moitié
  // k = 1 : deuxième groupe de 8 -> signe de la deuxième moitié
  if k = 0 then
    Result := best_k >= 2     // 2 ou 3 -> x_m pour les 8 premiers
  else
    Result := (best_k and 1) <> 0; // 1 ou 3 -> x_m pour les 8 derniers
end;

function IQ1M_ClampNearestL(v: Single): Integer; inline;
begin
  // Équivalent de nearest_int(v) puis clamp 0..7, mais sans gros Trunc inutile.
  // Le C utilise roundf : .5 -> away from zero.
  if v <= 0 then
    Result := 0
  else if v >= 6.5 then
    Result := 7
  else
    Result := Trunc(v + 0.5);
end;

// ================================ QUANTISATION ==============================
// rmseType = -1 : mode Ref.  Attention, ici Ref == exactement le chemin
// "quant_weights == NULL" du C (le GGML_ASSERT est commente en amont) :
// weight[i] = xb[i]^2, sans aucun terme correctif.
// rmseType >= 0 : qWeights si fourni, sinon ponderation rmse * sqrt(sigma2+x^2).
procedure QuantIQ1_M_Internal(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle; rmseType: Integer);
const
  block_size = IQ1M_BLOCK_SIZE;       // 16
  nHalf = block_size div 2;           // 8
  nsub = QK_K div IQ1M_BLOCK_SIZE;    // 16 sous-blocs de 16
var
  x_p, x_m: array [0 .. 2] of Single;
  nbl, ibl, ib, i, j, t, k, g, i1, i2, grid_index: Integer;
  y: PBlockIQ1_M;
  sc: PWord;
  s16: Word;
  xbl, xb, qw: PSingle;
  qhP: PByte;
  kmapPtr: PInteger;
  kneiPtr: PUInt16;
  kgridPtr: PUInt64;

  weights: array [0 .. QK_K - 1] of Single;
  wBase: PSingle;

  scales: array [0 .. nsub - 1] of Single;
  shifts: array [0 .. nsub - 1] of ShortInt;

  pairs: array [0 .. block_size - 1] of TValIdx;
  tmpPair: TValIdx;

  L: array [0 .. block_size - 1] of ShortInt;
  index: array [0 .. (block_size div 8) - 1] of Word;

  // Contributions par groupe (0,1,2), par variante k (0..3), par position triee t
  cQx: array [0 .. 3, 0 .. 2, 0 .. block_size - 1] of Single;
  cQ2: array [0 .. 3, 0 .. 2, 0 .. block_size - 1] of Single;

  initQx, initQ2: array [0 .. 3] of Single;
  curQx, curQ2: array [0 .. 3] of Single;
  totalC2x, totalC2q2: array [0 .. 3] of Single;

  sqx, sq2: Single;

  sumx2, sigma2, xx, base: Single;
  max_val: Single;
  best_score, scale: Single;
  d, id, max_scale: Single;

  w, xv, a: Single;
  xp, xm, bp, bm, axp, axm: Single;

  sumqx_f, sumq2_f: Single;
  q: Single;

  besti1, besti2, best_k: Integer;
  l_val: Integer;
  scaleMul: Integer;
  idxGrid: Integer;

  all_on_grid: Boolean;
  u: Word;
  neighbours_ptr: PUInt16;
  grid: PShortInt;
  xg: PSingle;
begin
  Assert(SizeOf(TBlockIQ1_M) = 56);
  Assert((n_row mod QK_K) = 0);

  if not iq1s_initialized then
    InitIQ1SGrid;

  kmapPtr := @kmap_q1s[0];
  kneiPtr := @kneighbors_q1s[0];
  kgridPtr := @kgrid_q1s[0];

  x_p[0] := -1 + IQ1M_DELTA;
  x_p[1] := IQ1M_DELTA;
  x_p[2] := 1 + IQ1M_DELTA;

  x_m[0] := -1 - IQ1M_DELTA;
  x_m[1] := -IQ1M_DELTA;
  x_m[2] := 1 - IQ1M_DELTA;

  nbl := n_row div QK_K;
  y := PBlockIQ1_M(Dest);

  for ibl := 0 to nbl - 1 do
  begin
    FillChar(y[ibl], SizeOf(TBlockIQ1_M), 0);

    xbl := @pSrc[QK_K * ibl];

    // sigma2 sur tout le super-bloc de 256
    sumx2 := 0;
    for i := 0 to QK_K - 1 do
    begin
      xx := xbl[i];
      sumx2 := sumx2 + xx * xx;
    end;
    sigma2 := 2 * sumx2 / QK_K;

    // ==========================================================================
    // Optimisation principale :
    // calcul des weights UNE SEULE FOIS pour tout le super-bloc.
    // Le C les recalcule pendant la recherche puis encore dans la boucle finale.
    // ==========================================================================
    if rmseType < 0 then
    begin
      // Chemin Ref / C avec quant_weights == NULL : weight = x^2
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
      // rmseType >= 0 sans quant_weights externe.
      // On sort le case des boucles internes.
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

      if max_val < GROUP_MAX_EPS_IQ1_M then
      begin
        scales[ib] := 0;
        shifts[ib] := 0;
        Continue;
      end;

      // Tri des valeurs par ordre croissant.
      // Le C utilise qsort, mais sur 16 elements un tri par insertion est souvent plus rapide.
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

      // ==========================================================================
      // Optimisation algorithmique :
      // Au lieu de recalculer les 4 variantes de somme pour chaque i1,i2,j,
      // on precalcule les contributions par groupe et on met a jour les sommes
      // par incrément.
      // ==========================================================================
      FillChar(totalC2x, SizeOf(totalC2x), 0);
      FillChar(totalC2q2, SizeOf(totalC2q2), 0);

      for t := 0 to block_size - 1 do
      begin
        i := pairs[t].i;
        w := wBase[i];
        xv := xb[i];
        a := w * xv;

        for g := 0 to 2 do
        begin
          xp := x_p[g];
          xm := x_m[g];

          bp := w * xp * xp;
          bm := w * xm * xm;
          axp := a * xp;
          axm := a * xm;

          if i < nHalf then
          begin
            // Première moitié du bloc de 16
            // k = 0 : + ; k = 1 : + ; k = 2 : - ; k = 3 : -
            cQx[0, g, t] := axp;
            cQx[1, g, t] := axp;
            cQx[2, g, t] := axm;
            cQx[3, g, t] := axm;

            cQ2[0, g, t] := bp;
            cQ2[1, g, t] := bp;
            cQ2[2, g, t] := bm;
            cQ2[3, g, t] := bm;
          end
          else
          begin
            // Seconde moitié du bloc de 16
            // k = 0 : + ; k = 1 : - ; k = 2 : + ; k = 3 : -
            cQx[0, g, t] := axp;
            cQx[1, g, t] := axm;
            cQx[2, g, t] := axp;
            cQx[3, g, t] := axm;

            cQ2[0, g, t] := bp;
            cQ2[1, g, t] := bm;
            cQ2[2, g, t] := bp;
            cQ2[3, g, t] := bm;
          end;

          if g = 2 then
            for k := 0 to 3 do
            begin
              totalC2x[k] := totalC2x[k] + cQx[k, 2, t];
              totalC2q2[k] := totalC2q2[k] + cQ2[k, 2, t];
            end;
        end;
      end;

      for k := 0 to 3 do
      begin
        initQx[k] := totalC2x[k];
        initQ2[k] := totalC2q2[k];
      end;

      best_score := -Single.MaxValue;
      scale := max_val;
      besti1 := -1;
      besti2 := -1;
      best_k := -1;

      // Recherche exhaustive optimisée.
      // i1 / i2 sont les deux frontieres de tri.
      // k est la combinaison de signes :
      // 0 : (+,+)
      // 1 : (+,-)
      // 2 : (-,+)
      // 3 : (-,-)
      for i1 := 0 to block_size do
      begin
        curQx[0] := initQx[0];
        curQx[1] := initQx[1];
        curQx[2] := initQx[2];
        curQx[3] := initQx[3];

        curQ2[0] := initQ2[0];
        curQ2[1] := initQ2[1];
        curQ2[2] := initQ2[2];
        curQ2[3] := initQ2[3];

        for i2 := i1 to block_size do
        begin
          for k := 0 to 3 do
          begin
            sq2 := curQ2[k];
            if sq2 > 0 then
            begin
              sqx := curQx[k];

              // Evite le -FLT_MAX * sumq2 potentiellement problématique.
              if (best_score < 0) or (sqx * sqx > best_score * sq2) then
              begin
                scale := sqx / sq2;
                best_score := scale * sqx;
                besti1 := i1;
                besti2 := i2;
                best_k := k;
              end;
            end;
          end;

          if i2 < block_size then
          begin
            // Passe l'element i2 du groupe 2 vers le groupe 1.
            for k := 0 to 3 do
            begin
              curQx[k] := curQx[k] + cQx[k, 1, i2] - cQx[k, 2, i2];
              curQ2[k] := curQ2[k] + cQ2[k, 1, i2] - cQ2[k, 2, i2];
            end;
          end;
        end;

        if i1 < block_size then
        begin
          // Passe l'element i1 du groupe 2 vers le groupe 0
          // pour initialiser le prochain i1.
          for k := 0 to 3 do
          begin
            initQx[k] := initQx[k] + cQx[k, 0, i1] - cQx[k, 2, i1];
            initQ2[k] := initQ2[k] + cQ2[k, 0, i1] - cQ2[k, 2, i1];
          end;
        end;
      end;

      if (besti1 < 0) or (besti2 < 0) or (best_k < 0) then
      begin
        scales[ib] := 0;
        shifts[ib] := 0;
        Continue;
      end;

      // Application des frontieres optimales.
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

        if best_k = 0 then
          best_k := 3
        else if best_k = 1 then
          best_k := 2
        else if best_k = 2 then
          best_k := 1
        else
          best_k := 0;
      end;

      // Ancrage grille + voisinage.
      all_on_grid := True;

      for k := 0 to (block_size div 8) - 1 do
      begin
        u := 0;
        for j := 0 to 7 do
          u := Word(u or (Word(L[8 * k + j]) shl (2 * j)));

        grid_index := kmapPtr[u];

        if grid_index < 0 then
        begin
          all_on_grid := False;
          neighbours_ptr := @kneiPtr[(-grid_index) - 1];

          if IQ1M_UseXm(best_k, k) then
            xg := @x_m[0]
          else
            xg := @x_p[0];

          grid_index := FindBestNeighbourIQ1(
            neighbours_ptr,
            kgridPtr,
            @xb[8 * k],
            @wBase[8 * k],
            scale,
            xg,
            @L[8 * k],
            NGRID_IQ1S
          );
        end;

        index[k] := Word(grid_index);
      end;

      // Recal de scale si un sous-groupe de 8 n'était pas exactement sur la grille.
      if not all_on_grid then
      begin
        sumqx_f := 0;
        sumq2_f := 0;

        for k := 0 to (block_size div 8) - 1 do
        begin
          if IQ1M_UseXm(best_k, k) then
            xg := @x_m[0]
          else
            xg := @x_p[0];

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

      y[ibl].qs[2 * ib + 0] := Byte(index[0] and $FF);
      y[ibl].qs[2 * ib + 1] := Byte(index[1] and $FF);
      y[ibl].qh[ib] := Byte((index[0] shr 8) or ((index[1] shr 8) shl 4));

      Assert(scale >= 0);

      scales[ib] := scale;
      shifts[ib] := ShortInt(best_k);

      if scale > max_scale then
        max_scale := scale;
    end;

    if max_scale = 0 then
      Continue;

    sc := PWord(@y[ibl].scales[0]);
    qhP := @y[ibl].qh[0];

    d := max_scale / 15;

    if d <> 0 then
      id := 1 / d
    else
      id := 0;

    sumqx_f := 0;
    sumq2_f := 0;

    for ib := 0 to nsub - 1 do
    begin
      l_val := IQ1M_ClampNearestL(0.5 * (id * scales[ib] - 1));

      sc[ib shr 2] := sc[ib shr 2] or Word(l_val shl (3 * (ib and 3)));
      y[ibl].qh[ib] := Byte(y[ibl].qh[ib] or IQ1M_MASKS[shifts[ib]]);

      xb := @xbl[block_size * ib];
      wBase := @weights[block_size * ib];

      scaleMul := 2 * l_val + 1;

      for k := 0 to (block_size div 8) - 1 do
      begin
        if IQ1M_UseXm(shifts[ib], k) then
          xg := @x_m[0]
        else
          xg := @x_p[0];

        idxGrid := y[ibl].qs[2 * ib + k] + ((qhP[ib] shl (8 - 4 * k)) and $700);
        grid := PShortInt(PByte(kgridPtr) + idxGrid * 8);

        for j := 0 to 7 do
        begin
          w := wBase[8 * k + j];
          q := xg[(grid[j] - 1) div 2] * scaleMul;

          sumqx_f := sumqx_f + w * q * xb[8 * k + j];
          sumq2_f := sumq2_f + w * q * q;
        end;
      end;
    end;

    if sumq2_f > 0 then
      d := sumqx_f / sumq2_f;

    // Echelle FP16 super-bloc : 1 nibble dans chacun des 4 uint16
    s16 := FP32ToFP16(d * 1.1125);

    sc[0] := sc[0] or Word((s16 and $000F) shl 12);
    sc[1] := sc[1] or Word((s16 and $00F0) shl 8);
    sc[2] := sc[2] or Word((s16 and $0F00) shl 4);
    sc[3] := sc[3] or Word(s16 and $F000);
  end;
end;



procedure QuantIQ1_M_Ref(pSrc: PSingle; Dest: PByte; n_row: Integer);
begin
  QuantIQ1_M_Internal(pSrc, Dest, n_row, nil, -1);
end;

procedure QuantIQ1_M_Impl1(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil; iQk: Integer = QP_PROF_IMPL1);
var cfgQK: PQuantPreset;
begin
  cfgQK := cfg.ggmlReg.GetPPreset(GGML_TYPE_IQ1_M, iQk);
  QuantIQ1_M_Internal(pSrc, Dest, n_row, qWeights, cfgQK.rmseType);
end;


procedure QuantIQ1_M_Impl2(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
var cfgQK: PQuantPreset;
begin
  cfgQK := cfg.ggmlReg.GetPPreset(GGML_TYPE_IQ1_M, QP_PROF_IMPL2);
  QuantIQ1_M_Internal(pSrc, Dest, n_row, qWeights, cfgQK.rmseType);
end;

procedure QuantIQ1_M_Impl3(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
var cfgQK: PQuantPreset;
begin
  cfgQK := cfg.ggmlReg.GetPPreset(GGML_TYPE_IQ1_M, QP_PROF_IMPL3);
  QuantIQ1_M_Internal(pSrc, Dest, n_row, qWeights, cfgQK.rmseType);
end;

procedure QuantIQ1_M_Impl4(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
var cfgQK: PQuantPreset;
begin
  cfgQK := cfg.ggmlReg.GetPPreset(GGML_TYPE_IQ1_M, QP_PROF_IMPL4);
  QuantIQ1_M_Internal(pSrc, Dest, n_row, qWeights, cfgQK.rmseType);
end;

procedure QuantIQ1_M_Impl5(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
var cfgQK: PQuantPreset;
begin
  cfgQK := cfg.ggmlReg.GetPPreset(GGML_TYPE_IQ1_M, QP_PROF_IMPL5);
  QuantIQ1_M_Internal(pSrc, Dest, n_row, qWeights, cfgQK.rmseType);
end;

end.
