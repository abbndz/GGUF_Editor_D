unit uGgmlQuantsQ8K;

interface

uses
  SysUtils, Classes, uGGMLTypes, uGGMLConstants, uGGMLQuantUtils, uMath, uAppConfig;

{$B-}
{$R-}
{$POINTERMATH ON}
{$J-}
{$O+}
{$ALIGN 8}
{$R-}
// DÉCLARATIONS PUBLIQUES : DÉQUANTISATION & QUANTISATION
// Format Q8_K : 8 bits/paramètre. Super-bloc de 256 éléments.
// Formule : x = d * q, où q ∈ [-127, 127], d ∈ FP32 (stocké comme Single pour précision)
procedure DequantQ8_K(const Data: PByte; Dest: PSingle; n_row: Integer);
procedure QuantQ8_K_Ref(pSrc: PSingle; Dest: PByte; n_row: Integer);
procedure QuantQ8_K_Impl1(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil; iQk: Integer = QP_PROF_IMPL1);
procedure QuantQ8_K_Impl2(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
procedure QuantQ8_K_Impl3(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
procedure QuantQ8_K_Impl4(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
procedure QuantQ8_K_Impl5(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);

implementation

uses uGgmlQuantsFP16;

procedure DequantQ8_K(const Data: PByte; Dest: PSingle; n_row: Integer);
var
  nb, i, j: Integer;
  B: PBlockQ8_K;
  d: Single;
begin
  nb := n_row div QK_K;
  B := PBlockQ8_K(Data);
  for i := 0 to nb - 1 do
  begin
    d := B^.d;
    for j := 0 to QK_K - 1 do
      Dest[j] := d * B^.qs[j];
    Inc(Dest, QK_K);
    Inc(B);
  end;
end;

// REF : replique de quantize_row_q8_K_ref
procedure QuantQ8_K_Ref(pSrc: PSingle; Dest: PByte; n_row: Integer);
var
  nb, ib, i, j, v, s: Integer;
  B: PBlockQ8_K;
  amax, maxVal, d, id: Single;
begin
  nb := n_row div QK_K;
  B := PBlockQ8_K(Dest);

  for ib := 0 to nb - 1 do
  begin
    amax := 0.0;
    maxVal := 0.0;

    // 1. Recherche du maximum absolu ET de sa valeur signée
    for i := 0 to QK_K - 1 do
    begin
      if Abs(pSrc[i]) > amax then
      begin
        amax := Abs(pSrc[i]);
        maxVal := pSrc[i];
      end;
    end;

    // 2. Gestion du cas nul / seuil epsilon
    if amax < GROUP_EPS then
    begin
      FillChar(B^, SizeOf(TBlockQ8_K), 0);
      Inc(B);
      Inc(pSrc, QK_K);
      Continue;
    end;

    // 3. Calcul de l'échelle : id = -127 / maxVal, D = 1 / id
    id := -127.0 / maxVal;
    d := 1.0 / id;
    B^.d := d;

    // 4. Quantification & Clampage [-127, 127]
    for i := 0 to QK_K - 1 do
    begin
      v := ClampInt(NearestInt(id * pSrc[i]), -127, 127);
      B^.qs[i] := ShortInt(v);
    end;

    // 5. Calcul des sommes de blocs (16 éléments) pour précision déquantisation
    for i := 0 to QK_K div 16 - 1 do
    begin
      s := 0;
      for j := 0 to 15 do
        s := s + B^.qs[i * 16 + j];
      B^.bsums[i] := s;
    end;

    Inc(B);
    Inc(pSrc, QK_K);
  end;
end;

procedure QuantQ8_K_Impl1(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil; iQk: Integer = QP_PROF_IMPL1);
var
  nb, ib, i, j, s: Integer;
  d: Single;
  pBlock: PBlockQ8_K;
  weights: array [0 .. QK_K - 1] of Single;
  L: array [0 .. QK_K - 1] of ShortInt;
  cfgQK: PQuantPreset;
begin
  cfgQK := cfg.ggmlReg.GetPPreset(GGML_TYPE_Q8_K, iQk);
  nb := n_row div QK_K;
  pBlock := PBlockQ8_K(Dest);
  pSrc := pSrc;

  for ib := 0 to nb - 1 do
  begin
    FillWeights(pSrc, qWeights, @weights[0], QK_K, cfgQK.RmseType);

    d := MakeQxQuants(QK_K, 127, pSrc, @L[0], cfgQK.RmseType, @weights[0], cfgQK.Rdelta, cfgQK.nstep);
    pBlock^.d := d;

    // Conversion [-127, 126] : MakeQxQuants stocke en [0, 253], on soustrait 127
    for j := 0 to QK_K - 1 do
    begin
      pBlock^.qs[j] := ShortInt(L[j] - 127);
    end;

    // 5. Calcul des sommes de blocs (16 éléments) pour précision déquantisation
    for i := 0 to QK_K div 16 - 1 do
    begin
      s := 0;
      for j := 0 to 15 do
        s := s + pBlock^.qs[i * 16 + j];
      pBlock^.bsums[i] := s;
    end;

    Inc(pBlock);
    Inc(pSrc, QK_K);
    if qWeights <> nil then
      Inc(qWeights, QK_K);
  end;
end;

procedure QuantQ8_K_Impl2(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
begin
  QuantQ8_K_Impl1(pSrc, Dest, n_row, qWeights, QP_PROF_IMPL2);
end;

procedure QuantQ8_K_Impl3(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
begin
  QuantQ8_K_Impl1(pSrc, Dest, n_row, qWeights, QP_PROF_IMPL3);
end;

procedure QuantQ8_K_Impl4(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
begin
  QuantQ8_K_Impl1(pSrc, Dest, n_row, qWeights, QP_PROF_IMPL4);
end;

procedure QuantQ8_K_Impl5(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
begin
  QuantQ8_K_Impl1(pSrc, Dest, n_row, qWeights, QP_PROF_IMPL5);
end;

end.
