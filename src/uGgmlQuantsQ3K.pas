unit uGgmlQuantsQ3K;

interface

uses
  SysUtils, Classes, uGGMLTypes, uGGMLConstants, uGGMLQuantUtils, uMath, uAppConfig;

{$B-}
{$R-}

{$POINTERMATH ON}
{$J-}
{$O+}
{$ALIGN 8}

// DÉQUANTISATION Q3_K
// Format : 3.4375 bits/poids. Super-bloc de 256 éléments.
// Structure : 16 sous-blocs de 16 éléments. Chaque sous-bloc a son propre scale.
// Les scales sont compressés sur 6 bits et regroupés dans un tableau de 12 octets.
// Les poids quantifiés sont stockés sur 2 bits (0-3) + 1 bit de masque (hmask).
procedure DequantQ3_K(const Data: PByte; Dest: PSingle; n_row: Integer);

// QUANTISATION Q3_K (RÉFÉRENCE)
// Algorithme déterministe (sans optimisation RMSE).
// Étape 1 : Pour chaque sous-bloc de 16 éléments, trouver le scale optimal.
// Étape 2 : Quantifier les 16 scales sur 6 bits et les packer dans y[i].scales.
// Étape 3 : Reconstruct les valeurs à partir des scales packés pour générer les poids L.
// Étape 4 : Stocker les bits de poids dans qs et les masques dans hmask.
procedure QuantQ3_K_Ref(pSrc: PSingle; Dest: PByte; n_row: Integer);

// QUANTISATION Q3_K (HAUTE QUALITÉ / RMSE)
// Utilise des poids internes (quant_weights) ou une estimation σ² pour optimiser MSE.
// Étape 1 : Calcul σ² global sur la ligne.
// Étape 2 : Pour chaque sous-bloc, optimiser scale + poids L via MakeQxQuants.
// Étape 3 : Optimiser les 16 scales ensemble via MakeQxQuants (super-scale).
// Étape 4 : Packer les scales sur 6 bits et requantifier L pour correspondre aux scales finaux.
procedure QuantQ3_K_Impl1(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil; iQk: Integer = QP_PROF_IMPL1);
procedure QuantQ3_K_Impl2(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
procedure QuantQ3_K_Impl3(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
procedure QuantQ3_K_Impl4(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
procedure QuantQ3_K_Impl5(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);

implementation

uses uGgmlQuants, uGgmlQuantsFP16;

// DÉQUANTISATION Q3_K
procedure DequantQ3_K(const Data: PByte; Dest: PSingle; n_row: Integer);
var
  nb, i, n_chunk, j, l, shift, is_idx: Integer;
  pBlock: PBlockQ3_K;
  d_all, dl: Single;
  m: Byte;
  sub_off: Integer;
  aux: array [0 .. 3] of Cardinal;
  scales_unpacked: array [0 .. 15] of ShortInt absolute aux;
  tmp: Cardinal;
begin
  // Découpage en super-blocs de 256 éléments
  nb := n_row div QK_K;
  pBlock := PBlockQ3_K(Data);

  for i := 0 to nb - 1 do
  begin
    // Échelle globale du super-bloc (FP16 -> FP32)
    d_all := FP16ToFP32(pBlock.d);

    // Dé-packing des 16 scales sur 6 bits depuis 12 octets
    // Les 12 octets contiennent les scales packés 4 par 4.
    // Cette étape décompresse les bits pour obtenir les 16 valeurs [-32, +31].
    FillChar(aux, SizeOf(aux), 0);
    Move(pBlock.scales[0], aux[0], 12);
    tmp := aux[2];
    aux[2] := ((aux[0] shr 4) and $0F0F0F0F) or (((tmp shr 4) and $03030303) shl 4);
    aux[3] := ((aux[1] shr 4) and $0F0F0F0F) or (((tmp shr 6) and $03030303) shl 4);
    aux[0] := (aux[0] and $0F0F0F0F) or (((tmp shr 0) and $03030303) shl 4);
    aux[1] := (aux[1] and $0F0F0F0F) or (((tmp shr 2) and $03030303) shl 4);

    is_idx := 0;
    m := 1; // Masque pour hmask (bit 0 à bit 7 sur 8 sous-blocs)

    // Traitement par chunk de 128 éléments (moitié haute / moitié basse)
    for n_chunk := 0 to 1 do
    begin
      shift := 0;
      for j := 0 to 3 do
      begin
        // --- Première moitié du chunk (16 éléments) ---
        // Scale local = d_all * (scale_packed - 32)
        dl := d_all * (scales_unpacked[is_idx] - 32);
        Inc(is_idx);
        for l := 0 to 15 do
        begin
          // Le poids quantifié est (qs[2 bits] - 4) si hmask=0, sinon (qs[2 bits])
          // hmask indique si le poids original était >= 4 (donc besoin du 3ème bit caché)
          if (pBlock.hmask[l] and m) = 0 then
            sub_off := 4
          else
            sub_off := 0;
          // Ajout du décalage (n_chunk * 32) pour lire la bonne moitié de qs
          Dest[n_chunk * 128 + j * 32 + l] := dl * (Integer((pBlock.qs[n_chunk * 32 + l] shr shift) and 3) - sub_off);
        end;

        // Seconde moitié du chunk (16 éléments)
        dl := d_all * (scales_unpacked[is_idx] - 32);
        Inc(is_idx);
        for l := 0 to 15 do
        begin
          if (pBlock.hmask[l + 16] and m) = 0 then
            sub_off := 4
          else
            sub_off := 0;
          // Idem pour la seconde partie
          Dest[n_chunk * 128 + j * 32 + 16 + l] := dl * (Integer((pBlock.qs[n_chunk * 32 + 16 + l] shr shift) and 3)
            - sub_off);
        end;

        Inc(shift, 2);
        m := m shl 1;
      end;
    end;

    // Avance au super-bloc suivant (256 éléments déquantisés)
    Inc(Dest, QK_K);
    Inc(pBlock);
  end;
end;

procedure QuantQ3_K_Ref(pSrc: PSingle; Dest: PByte; n_row: Integer);
var
  nb, i, j, l, m, base, dest_base, l_val: Integer;
  pBlock: PBlockQ3_K;
  max_scale, amax, scale, iscale, d_val: Single;
  scales: array [0 .. 15] of Single;
  LLq: array [0 .. QK_K - 1] of ShortInt;
  sc: ShortInt;
  hm: Byte;
begin
  nb := n_row div QK_K;
  pBlock := PBlockQ3_K(Dest);

  for i := 0 to nb - 1 do
  begin
    max_scale := 0.0;
    amax := 0.0;

    // Optimisation scale par sous-bloc de 16 éléments (référence)
    for j := 0 to 15 do
    begin
      // make_q3_quants renvoie le scale optimal et remplit L_arr avec les poids quantifiés [-4, +3]
      scale := MakeQ3Quants(16, 4, @pSrc[16 * j], @LLq[16 * j], True, 4);
      scales[j] := scale;
      if Abs(scale) > amax then
      begin
        amax := Abs(scale);
        max_scale := scale;
      end;
    end;
    // Initialisation du tableau de scales packés
    FillChar(pBlock.scales[0], 12, 0);

    // 3. Quantification des 16 scales sur 6 bits (valeur -32 à +31)
    if max_scale <> 0.0 then
    begin
      iscale := -32.0 / max_scale;
      for j := 0 to 15 do
      begin
        l_val := ClampInt(NearestInt(iscale * scales[j]), -32, 31) + 32; // 0..63
        if j < 8 then
          pBlock.scales[j] := l_val and $0F
        else
          pBlock.scales[j - 8] := pBlock.scales[j - 8] or ((l_val and $0F) shl 4);

        l_val := l_val shr 4;
        pBlock.scales[j mod 4 + 8] := pBlock.scales[j mod 4 + 8] or ((l_val and 3) shl (2 * (j div 4)));
      end;
      pBlock.d := FP32ToFP16(1.0 / iscale);
    end
    else
      pBlock.d := FP32ToFP16(0.0);

    // Reconstruction des poids finaux L (0-7) à partir des scales packés
    for j := 0 to 15 do
    begin
      if j < 8 then
        sc := pBlock.scales[j] and $0F
      else
        sc := pBlock.scales[j - 8] shr 4;
      sc := (sc or (((pBlock.scales[8 + j mod 4] shr (2 * (j div 4))) and 3) shl 4)) - 32;
      d_val := FP16ToFP32(pBlock.d) * sc;
      if (Abs(d_val) <= GROUP_EPS) then // if d_val = 0.0 then
      begin
        // Fallback : si scale nul, on force les poids à la valeur neutre (4 = 0 après déquantisation)
        for l := 0 to 15 do
          LLq[16 * j + l] := 4;
        Continue;
      end;
      for l := 0 to 15 do
        LLq[16 * j + l] := ClampInt(NearestInt(pSrc[16 * j + l] / d_val), -4, 3) + 4;
    end;
    // Extraction des masques (hmask) et finalisation des poids
    FillChar(pBlock.hmask[0], 32, 0);
    m := 0;
    hm := 1;
    for j := 0 to QK_K - 1 do
    begin
      if LLq[j] > 3 then // Si poids >= 4, on active le masque et on soustrait 4
      begin
        pBlock.hmask[m] := pBlock.hmask[m] or hm;
        LLq[j] := LLq[j] - 4;
      end;
      Inc(m);
      if m = 32 then
      begin
        m := 0;
        hm := hm shl 1;
      end;
    end;

    // Packing des 2 bits de poids sur 32 octets (qs)
    for j := 0 to 1 do
    begin
      base := j * 128;
      dest_base := j * 32;
      for l := 0 to 31 do
      begin
        // Chaque octet qs contient 4 poids de 2 bits (l, l+32, l+64, l+96)
        // "and 3" pour empêcher la pollution des bits supérieurs
        pBlock.qs[dest_base + l] := (Byte(LLq[base + l]) and 3) or ((Byte(LLq[base + l + 32]) and 3) shl 2) or
          ((Byte(LLq[base + l + 64]) and 3) shl 4) or ((Byte(LLq[base + l + 96]) and 3) shl 6);
      end;
    end;
    Inc(pSrc, QK_K);
    Inc(pBlock);
  end;
end;

// QUANTISATION Q3_K (HAUTE QUALITÉ / RMSE)
procedure QuantQ3_K_Impl1(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil; iQk: Integer = QP_PROF_IMPL1);
var
  nb, sb, j, l, m, base, dest_base, l_val: Integer;
  pBlock: PBlockQ3_K;
  d_block, dl: Single;
  weights: array [0 .. QK_K - 1] of Single;
  scales, sw: array [0 .. 15] of Single;
  LLq: array [0 .. QK_K - 1] of ShortInt;
  LLs: array [0 .. 15] of ShortInt;
  sc: ShortInt;
  hm: Byte;
  cfgQK: PQuantPreset;
begin
  cfgQK := cfg.ggmlReg.GetPPreset(GGML_TYPE_Q3_K, iQk);
  nb := n_row div QK_K;
  pBlock := PBlockQ3_K(Dest);

  for sb := 0 to nb - 1 do
  begin
    FillWeights(pSrc, qWeights, @weights[0], QK_K, cfgQK.RmseType, True, True);

    FillChar(LLq, SizeOf(LLq), 0);
    FillChar(LLs, SizeOf(LLs), 0);

    // Optimisation par sous-bloc de 16 éléments
    for j := 0 to 15 do
    begin
      sw[j] := 0.0;
      for l := 0 to 15 do
        sw[j] := sw[j] + weights[j * 16 + l];
      scales[j] := MakeQxQuants(16, 4, @pSrc[j * 16], @LLq[j * 16], cfgQK.RmseType, @weights[j * 16], cfgQK.Rdelta,
        cfgQK.Nstep);
    end;
    // Super-scale
    d_block := MakeQxQuants(16, 32, @scales[0], @LLs[0], cfgQK.RmseType, @sw[0], cfgQK.QpStep, cfgQK.QpNStep);
    pBlock.d := FP32ToFP16(d_block);

    // Packing des scales sur 6 bits
    FillChar(pBlock.scales[0], 12, 0);

    for j := 0 to 15 do
    begin
      l_val := ClampInt(LLs[j], 0, 63);
      if j < 8 then
        pBlock.scales[j] := l_val and $0F
      else
        pBlock.scales[j - 8] := pBlock.scales[j - 8] or ((l_val and $0F) shl 4);
      l_val := l_val shr 4;
      pBlock.scales[j mod 4 + 8] := pBlock.scales[j mod 4 + 8] or ((l_val and 3) shl (2 * (j div 4)));
    end;

    // Reconstruction & Quantification finale
    for j := 0 to 15 do
    begin
      if j < 8 then
        sc := pBlock.scales[j] and $0F
      else
        sc := pBlock.scales[j - 8] shr 4;
      sc := (sc or (((pBlock.scales[8 + j mod 4] shr (2 * (j div 4))) and 3) shl 4)) - 32;
      dl := FP16ToFP32(pBlock.d) * sc;
      // if (dl <> dl) or (dl = 0) then
      if (dl <> dl) or (Abs(dl) <= GROUP_EPS) then // if dl = 0.0 then
      begin
        for l := 0 to 15 do
          LLq[16 * j + l] := 4; // ou 0;
        Continue;
      end;
      for l := 0 to 15 do
        LLq[16 * j + l] := ClampInt(NearestInt(pSrc[j * 16 + l] / dl), -4, 3) + 4;
    end;

    // hmask & Packing qs
    FillChar(pBlock.hmask[0], 32, 0);
    m := 0;
    hm := 1;
    for j := 0 to QK_K - 1 do
    begin
      if LLq[j] > 3 then
      begin
        pBlock.hmask[m] := pBlock.hmask[m] or hm;
        LLq[j] := LLq[j] - 4;
      end;
      Inc(m);
      if m = 32 then
      begin
        m := 0;
        hm := hm shl 1;
      end;
    end;

    for j := 0 to 1 do
    begin
      base := j * 128;
      dest_base := j * 32;
      for l := 0 to 31 do
        pBlock.qs[dest_base + l] := (Byte(LLq[base + l]) and 3) or ((Byte(LLq[base + l + 32]) and 3) shl 2) or
          ((Byte(LLq[base + l + 64]) and 3) shl 4) or ((Byte(LLq[base + l + 96]) and 3) shl 6);
    end;

    Inc(pBlock);
    Inc(pSrc, QK_K);
    if qWeights <> nil then
      Inc(qWeights, QK_K);
  end;
end;

// QUANTISATION Q3_K (HAUTE QUALITÉ / RMSE) Custum
procedure QuantQ3_K_Impl2(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
begin
  // Q3_K n'a pas de min : la requant des L absorbe toute variation d'échelle.
  // Raffinage de codes / refit de d_all = 0 gain mesuré (voir benchmark , version 1.2 (32.232f7).
  QuantQ3_K_Impl1(pSrc, Dest, n_row, qWeights, QP_PROF_IMPL2);
end;

procedure QuantQ3_K_Impl3(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
begin
  QuantQ3_K_Impl1(pSrc, Dest, n_row, qWeights, QP_PROF_IMPL3);
end;

procedure QuantQ3_K_Impl4(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
begin
  QuantQ3_K_Impl1(pSrc, Dest, n_row, qWeights, QP_PROF_IMPL4);
end;

procedure QuantQ3_K_Impl5(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
begin
  QuantQ3_K_Impl1(pSrc, Dest, n_row, qWeights, QP_PROF_IMPL5);
end;

end.
