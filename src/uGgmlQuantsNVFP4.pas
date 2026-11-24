unit uGgmlQuantsNVFP4;

interface

uses
  SysUtils, Classes, uMath, uGGMLTypes, uGGMLConstants, uGgmlQuantsFP16, uAppConfig;

{$B-}
{$R-}
{$POINTERMATH ON}
{$J-}
{$O+}
{$ALIGN 8}

const
  QK_NV4 = 64;
  QK_NV4_SUB = 16;
  QK_NV4_SUBH = 8;

  // $7F -> 480 ; passez a $7E (448) si le C sature la (0x7F = NaN en E4M3)
  // UE4M3_MAX_CODE = $7F;
  // 0x7F est un NaN en E4M3 : max fini = 0x7E = 448 (GGML_UE4M3_MAX)
  UE4M3_MAX_CODE = $7E;

  NV4_MAX = 6.0;

type
  TGridFP4 = array [0 .. 15] of Single;
  TWeights = array [0 .. QK_NV4_SUB - 1] of Single;
  TQuants16 = array [0 .. QK_NV4_SUB - 1] of Byte;

  // Déquantisation NVFP4 (format NVIDIA déterministe, pas de preset)
procedure DequantNVFP4(const Data: PByte; Dest: PSingle; n_row: Integer);

// Quantisation NVFP4 (référence déterministe - identique au C quantize_row_nvfp4_ref)
// ue = round_ue4m3(amax/6) ; d = ue4m3(ue) ; qs = best_index_fp4(x, d)
procedure QuantNVFP4_Ref(pSrc: PSingle; Dest: PByte; n_row: Integer);

// Quantisation NVFP4 (optimisation RMSE par sous-bloc de 16)
// Pour chaque sous-bloc : recherche de l'échelle UE4M3 candidate (grille de
// ntry niveaux au-dessus de la référence) minimisant l'erreur quadratique
// pondérée : d_opt = sum(w*q*x) / sum(w*q²)
// qWeights : poids externes optionnels (mode expert) ; w = qWeights * sqrt(2*sigma2 + x²)
// RmseType : pondération interne sans qWeights (défaut 1 = x²)
procedure QuantNVFP4_Impl1(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil; iQk: Integer = QP_PROF_IMPL1);
procedure QuantNVFP4_Impl2(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
procedure QuantNVFP4_Impl3(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
procedure QuantNVFP4_Impl4(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
procedure QuantNVFP4_Impl5(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);

implementation

function UE4M3ToFP32o(const B: Byte): Single;
var
  I: Integer;
begin
  if (B and $78) = 0 then // E = 0 : sous-normal  m * 2^-9
    Result := (B and $07) * 0.001953125
  else
  begin
    // normal : 2^(e4-7) * (1 + m/8)  ->  champ expo FP32 = e4 + 120
    I := ((B shr 3) + 120) shl 23 or ((B and $07) shl 20);
    Move(I, Result, SizeOf(Result)); // bit-exact, 0 FP division
  end;
end;

function UE4M3ToFP32(const B: Byte): Single;
var
  I, bb: Cardinal;
begin
  bb := B and $7F; // UE4M3 = non signe
  if bb = $7F then
    Exit(448.0); // NaN en E4M3 -> saturation (ne doit plus jamais sortir)
  if (bb and $78) = 0 then // E = 0 : sous-normal m * 2^-9
    Result := (bb and $07) * 0.001953125
  else
  begin // normal : expo FP32 = e4 + 120
    I := ((bb shr 3) + 120) shl 23 or ((bb and $07) shl 20);
    Move(I, Result, SizeOf(Result)); // bit-exact
  end;
end;

function FP32ToUE4M3(const F: Single): Byte;
var
  U, Sig, Rem: Cardinal;
  E, e4, k, q, half: Integer;
  R: Cardinal;
  S: Boolean;
begin
  Move(F, U, 4);
  if (U and $80000000) <> 0 then
    Exit(0); // UE4M3 non signe : clamp(x<0)=0
  E := (U shr 23) and $FF;
  if E = $FF then
    Exit(UE4M3_MAX_CODE); // +Inf / NaN -> saturation
  if E = 0 then
    Exit(0); // FP32 denormal << 2^-9 : hors portee

  Sig := (U and $007FFFFF) or $00800000; // significande 24 bits (1 implicite inclus)
  e4 := Integer(E) - 127 + 7; // exposant UE4M3 cible

  if e4 >= 1 then
  begin
    if e4 > 15 then
      Exit(UE4M3_MAX_CODE); // > 448 -> saturation
    // ARRONDI UNIQUE 24 bits -> 4 bits (1+3), ties-to-even ----
    q := Sig shr 20; // 8..15
    R := (Sig shr 19) and 1;
    S := (Sig and $0007FFFF) <> 0;
    if (R = 1) and (S or ((q and 1) = 1)) then
    begin
      Inc(q);
      if q = 16 then // report : 1.111 -> 10.000
      begin
        q := 8;
        Inc(e4);
        if e4 > 15 then
          Exit(UE4M3_MAX_CODE);
      end;
    end;
    Result := Byte((e4 shl 3) or Integer(q - 8));
    if Result = $7F then
      Result := UE4M3_MAX_CODE; // 480 = NaN -> on sature a 448
    Exit;
  end;

  // v = Sig * 2^(e-23), e = E-127  =>  v/2^-9 = Sig >> (14-e) = Sig >> (141-E)
  k := 141 - Integer(E); // >= 21 ici (e4 <= 0)
  if k > 24 then
    Exit(0); // v < 0.5 * 2^-9  =>  code 0
  q := Sig shr k;
  Rem := Sig and ((Cardinal(1) shl k) - 1);
  half := Cardinal(1) shl (k - 1);
  if (Rem > half) or ((Rem = half) and ((q and 1) = 1)) then
    Inc(q);
  if q > 7 then
    Exit($08) // 8 = 1.000*2^-6 : premier normal
  else
    Exit(Byte(q));
end;

// Force l'arret en memoire (Single reel) -> meme tie-breaking que le C float
procedure MakeGrid(d: Single; out G: TGridFP4);
var
  I: Integer;
begin
  for I := 0 to 15 do
    G[I] := kvalues_mxfp4[I] * d;
end;

function BestIndexGrid(const G: TGridFP4; x: Single): Integer; inline;
var
  I: Integer;
  be, E: Single;
begin
  Result := 0;
  be := Abs(G[0] - x);
  for I := 1 to 15 do
  begin
    E := Abs(G[I] - x);
    if E < be then
    begin
      Result := I;
      be := E;
    end; // strict '<' => ties = plus petit index, comme C
  end;
end;

procedure DequantNVFP4(const Data: PByte; Dest: PSingle; n_row: Integer);
var
  ib, nb, S, j: Integer;
  pBlock: PBlockNVFP4;
  d: Single;
begin
  nb := n_row div QK_NVFP4;
  pBlock := PBlockNVFP4(Data);
  for ib := 0 to nb - 1 do
  begin
    for S := 0 to 3 do
    begin
      d := UE4M3ToFP32(pBlock^.d[S]);
      for j := 0 to QK_NV4_SUB div 2 - 1 do
      begin
        Dest[S * QK_NV4_SUB + j] := kvalues_mxfp4[pBlock^.qs[S * QK_NV4_SUBH + j] and $0F] * d;
        Dest[S * QK_NV4_SUB + j + QK_NV4_SUBH] := kvalues_mxfp4[pBlock^.qs[S * QK_NV4_SUBH + j] shr 4] * d;
      end;
    end;
    Inc(Dest, QK_NVFP4);
    Inc(pBlock);
  end;
end;

procedure QuantNVFP4_Ref(pSrc: PSingle; Dest: PByte; n_row: Integer);
var
  ib, nb, S, j: Integer;
  pBlock: PBlockNVFP4;
  amax, v: Single;
  G: TGridFP4;
begin
  nb := n_row div QK_NV4;
  pBlock := PBlockNVFP4(Dest);
  for ib := 0 to nb - 1 do
  begin
    for S := 0 to 3 do
    begin
      amax := 0.0;
      for j := 0 to QK_NV4_SUB - 1 do
      begin
        v := Abs(pSrc[S * QK_NV4_SUB + j]);
        if v > amax then
          amax := v;
      end;

      pBlock^.d[S] := FP32ToUE4M3(amax / NV4_MAX);
      MakeGrid(UE4M3ToFP32(pBlock^.d[S]), G); // d = 0 => G[i]=0 => tous les nibbles a 0 (comme le C)

      for j := 0 to QK_NV4_SUBH - 1 do
        pBlock^.qs[S * QK_NV4_SUBH + j] := BestIndexGrid(G, pSrc[S * QK_NV4_SUB + j]) or
          (BestIndexGrid(G, pSrc[S * QK_NV4_SUB + j + QK_NV4_SUBH]) shl 4);
    end;
    Inc(pSrc, QK_NV4);
    Inc(pBlock);
  end;
end;

// Erreur ponderee d'un candidat + quants correspondants
function Nvfp4Eval(x: PSingle; const w: TWeights; ue: Byte; out L: TQuants16): Single;
var
  j: Integer;
  d: Single;
  G: TGridFP4;
  E: Single;
begin
  d := UE4M3ToFP32(ue);
  MakeGrid(d, G);
  Result := 0.0;
  for j := 0 to QK_NV4_SUB - 1 do
  begin
    L[j] := Byte(BestIndexGrid(G, x[j]));
    E := G[L[j]] - x[j];
    Result := Result + w[j] * E * E;
  end;
  if IsNan(Result) or IsInfinite(Result) then
    Result := 1E30;
end;

procedure QuantNVFP4_Impl1(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil; iQk: Integer = QP_PROF_IMPL1);
var
  ib, S, j, nb, delta, ntry, RmseType, ue, ue_ref, ue_best: Integer;
  pBlock: PBlockNVFP4;
  px: PSingle;
  amax, v, sum2, sigma2, w: Single;
  weights: TWeights;
  Lbest, Lcur: TQuants16;
  err, best_err: Single;
  cfgNV: PQuantPreset;
begin
  cfgNV := cfg.ggmlReg.GetPPreset(GGML_TYPE_NVFP4, iQk);
  RmseType := cfgNV.RmseType;
  ntry := cfgNV.Nstep; // desormais : amplitude en CODES UE4M3 (pas en x2)
  if ntry < 0 then
    ntry := 0;
  if ntry > 8 then
    ntry := 8; // +-8 codes ~ +-100 % d'echelle : au-dela, inutile
  if (RmseType < 1) or (RmseType > 4) then
    RmseType := 1; // 0 = poids nuls -> interdit
  pBlock := PBlockNVFP4(Dest);
  nb := n_row div QK_NV4;
  for ib := 0 to nb - 1 do
  begin
    // sigma2 sur le bloc de 64 (convention ggml : super-bloc), pas sur 16
    sum2 := 0.0;
    for j := 0 to QK_NV4 - 1 do
      sum2 := sum2 + Sqr(pSrc[j]);
    sigma2 := 2.0 * sum2 / QK_NV4;

    for S := 0 to 3 do
    begin
      px := @pSrc[S * QK_NV4_SUB];

      amax := 0.0;
      for j := 0 to QK_NV4_SUB - 1 do
      begin
        v := Abs(px[j]);
        if v > amax then
          amax := v;
      end;

      if amax < GROUP_EPS then
      begin
        pBlock^.d[S] := 0;
        FillChar(pBlock^.qs[S * QK_NV4_SUBH], QK_NV4_SUBH, 0);
        Continue;
      end;

      // Poids : convention ggml -> qw*sqrt(sigma2+x^2) si qw, sinon pondération brute
      for j := 0 to QK_NV4_SUB - 1 do
      begin
        if qWeights <> nil then
          w := qWeights[S * QK_NV4_SUB + j] * Sqrt(sigma2 + Sqr(px[j]))
        else
          case RmseType of
            1:
              w := 1.0;
            2:
              w := Sqrt(Abs(px[j]));
            3:
              w := Abs(px[j]);
            4:
              w := Sqr(px[j]);
          else
            w := Abs(px[j]);
          end;
        if IsNan(w) or (w < 0.0) or IsInfinite(w) then
          w := 1.0; // w = 0 (x = 0) est legitime, on le garde
        weights[j] := w;
      end;

      ue_ref := FP32ToUE4M3(amax / NV4_MAX); // (= le candidat Ref)
      best_err := Nvfp4Eval(px, weights, Byte(ue_ref), Lbest);
      ue_best := ue_ref;

      for delta := -ntry to ntry do
      begin
        if delta = 0 then
          Continue;
        ue := ClampInt(ue_ref + delta, 0, UE4M3_MAX_CODE);
        if ue = ue_ref then
          Continue;
        err := Nvfp4Eval(px, weights, Byte(ue), Lcur);
        if err < best_err then
        begin
          best_err := err;
          ue_best := ue;
          Lbest := Lcur;
        end;
      end;

      pBlock^.d[S] := Byte(ue_best);
      for j := 0 to QK_NV4_SUBH - 1 do
        pBlock^.qs[S * QK_NV4_SUBH + j] := Lbest[j] or (Lbest[j + QK_NV4_SUBH] shl 4);
    end;

    Inc(pSrc, QK_NV4);
    Inc(pBlock);
    if qWeights <> nil then
      Inc(qWeights, QK_NV4);
  end;
end;

procedure QuantNVFP4_Impl2(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
begin
  QuantNVFP4_Impl1(pSrc, Dest, n_row, qWeights, QP_PROF_IMPL3);
end;

procedure QuantNVFP4_Impl3(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
begin
  QuantNVFP4_Impl1(pSrc, Dest, n_row, qWeights, QP_PROF_IMPL3);
end;

procedure QuantNVFP4_Impl4(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
begin
  QuantNVFP4_Impl1(pSrc, Dest, n_row, qWeights, QP_PROF_IMPL4);
end;

procedure QuantNVFP4_Impl5(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
begin
  QuantNVFP4_Impl1(pSrc, Dest, n_row, qWeights, QP_PROF_IMPL5);
end;

end.
