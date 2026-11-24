unit uGgmlQuantsQ80;

interface

uses
  SysUtils, Classes, System.Threading, uGGMLTypes, uGGMLConstants, uGGMLQuantUtils, uMath, uLog,
  uAppConfig;

{$B-}
{$R-}
{$POINTERMATH ON}
{$J-}
{$O+}
{$ALIGN 8}

// Format Q8_0 : 8 bits/paramètre. Bloc de 32 éléments.
// Formule : x = d * q, où q : [-128, 127], d : FP16
procedure DequantQ8_0(const Data: PByte; Dest: PSingle; n_row: Int64); // testé OK
procedure QuantQ8_0(pSrc: PSingle; Dest: PByte; n_row: Int64);
procedure QuantQ8_0_Ref(pSrc: PSingle; Dest: PByte; n_row: Int64);
procedure QuantQ8_0_Impl1(pSrc: PSingle; Dest: PByte; n_row: Int64; qWeights: PSingle = nil; iQk: Integer = QP_PROF_IMPL1);
procedure QuantQ8_0_Impl2(pSrc: PSingle; Dest: PByte; n_row: Int64; qWeights: PSingle = nil);
procedure QuantQ8_0_Impl3(pSrc: PSingle; Dest: PByte; n_row: Int64; qWeights: PSingle = nil);
procedure QuantQ8_0_Impl4(pSrc: PSingle; Dest: PByte; n_row: Int64; qWeights: PSingle = nil);
procedure QuantQ8_0_Impl5(pSrc: PSingle; Dest: PByte; n_row: Int64; qWeights: PSingle = nil);

procedure DequantQ8_1(const Data: PByte; Dest: PSingle; n_row: Int64);

// test :
// a : Mean=0,000000 | RMS=0,000158 | MAE=0,000132
// b : Mean=-0,000002 | RMS=0,000136 | MAE=0,000112
// c : Mean=0,000001 | RMS=0,000146 | MAE=0,000119

implementation

uses uGgmlQuantsFP16;

procedure DequantQ8_0(const Data: PByte; Dest: PSingle; n_row: Int64);
var
  nb, i, j: Integer;
  pBlock: PBlockQ8_0;
  pDest: PSingle;
  D: Single;
begin
  nb := n_row div QK8_0;
  pBlock := PBlockQ8_0(Data);
  pDest := Dest;
  for i := 0 to nb - 1 do
  begin
    D := FP16ToFP32(pBlock^.D);
    for j := 0 to 31 do
    begin
      // Dest[i * QK8_0 + j] := pBlock^.qs[j] * D; // x = d * q
      pDest^ := pBlock^.qs[j] * D;
      Inc(pDest);
    end;
    Inc(pBlock);
  end;
end;

procedure QuantQ8_0(pSrc: PSingle; Dest: PByte; n_row: Int64);
var
  nb, i, j: Integer;
  B: PByte;
  D, id, amax: Single;
  V: Integer;
begin
  nb := n_row div QK8_0;
  B := Dest;
  for i := 0 to nb - 1 do
  begin
    amax := 0.0;
    for j := 0 to QK8_0 - 1 do
      if Abs(pSrc[i * QK8_0 + j]) > amax then
        amax := Abs(pSrc[i * QK8_0 + j]);

    D := amax / 127.0;
    id := 0.0;
    if D <> 0 then
      id := 1.0 / D;

    PWord(B)^ := FP32ToFP16(D);
    Inc(B, 2);

    for j := 0 to QK8_0 - 1 do
    begin
      V := NearestInt(pSrc[i * QK8_0 + j] * id);
      // Note : GGML standard autorise -128. Ce code clamp à -127 pour compatibilité avec certains modèles.
      PShortInt(B + j)^ := Max(-127, Min(127, V));
    end;
    Inc(B, 32);
  end;
end;

procedure QuantQ8_0_Ref(pSrc: PSingle; Dest: PByte; n_row: Int64);
var
  nb, i, j: Integer;
  pBlock: PBlockQ8_0;
  amax, D, id: Single;
  Val: Integer;
begin
  nb := n_row div QK8_0;
  pBlock := PBlockQ8_0(Dest);

  for i := 0 to nb - 1 do
  begin
    amax := 0.0;
    for j := 0 to QK8_0 - 1 do
    begin
      if Abs(pSrc[i * QK8_0 + j]) > amax then
      begin
        amax := Abs(pSrc[i * QK8_0 + j]);
      end;
    end;

    D := amax / 127.0;
    if D <> 0 then
      id := 1.0 / D
    else
      id := 0.0;
    pBlock^.D := FP32ToFP16(D);

    for j := 0 to QK8_0 - 1 do
    begin
      Val := NearestInt(pSrc[i * QK8_0 + j] * id);
      if Val > 127 then
        Val := 127
      else if Val < -128 then
        Val := -128;
      PShortInt(PByte(@pBlock^.qs[j]))^ := Val;
    end;
    Inc(pBlock);
  end;
end;

procedure QuantQ8_0_Impl1(pSrc: PSingle; Dest: PByte; n_row: Int64; qWeights: PSingle = nil; iQk: Integer = QP_PROF_IMPL1);
var
  nb, ib, j: Integer;
  D: Single;
  pBlock: PBlockQ8_0;
  weights: array [0 .. QK8_0 - 1] of Single;
  L: array [0 .. QK8_0 - 1] of ShortInt;
  cfgQK: PQuantPreset;
begin
  cfgQK := cfg.ggmlReg.GetPPreset(GGML_TYPE_Q8_0, iQk);
  nb := n_row div QK8_0;
  pBlock := PBlockQ8_0(Dest);

  for ib := 0 to nb - 1 do
  begin
    FillWeights(pSrc, qWeights, @weights[0], QK8_0, cfgQK.RmseType);//   ,false, cfgQK.UseMAD

    D := MakeQxQuants(QK8_0, 127, pSrc, @L[0], cfgQK.RmseType, @weights[0], cfgQK.Rdelta, cfgQK.nstep);
    pBlock^.D := FP32ToFP16(D);

    // Conversion [-127, 126] : MakeQxQuants stocke en [0, 253], on soustrait 127
    for j := 0 to QK8_0 - 1 do
      pBlock^.qs[j] := L[j] - 127;

    Inc(pBlock);
    Inc(pSrc, QK8_0);
    if qWeights <> nil then
      Inc(qWeights, QK8_0);
  end;
end;

procedure QuantQ8_0_Impl2(pSrc: PSingle; Dest: PByte; n_row: Int64; qWeights: PSingle = nil);
begin
  QuantQ8_0_Impl1(pSrc, Dest, n_row, qWeights, QP_PROF_IMPL2);
end;

procedure QuantQ8_0_Impl3(pSrc: PSingle; Dest: PByte; n_row: Int64; qWeights: PSingle = nil);
begin
  QuantQ8_0_Impl1(pSrc, Dest, n_row, qWeights, QP_PROF_IMPL3);
end;

procedure QuantQ8_0_Impl4(pSrc: PSingle; Dest: PByte; n_row: Int64; qWeights: PSingle = nil);
begin
  QuantQ8_0_Impl1(pSrc, Dest, n_row, qWeights, QP_PROF_IMPL4);
end;

procedure QuantQ8_0_Impl5(pSrc: PSingle; Dest: PByte; n_row: Int64; qWeights: PSingle = nil);
begin
  QuantQ8_0_Impl1(pSrc, Dest, n_row, qWeights, QP_PROF_IMPL5);
end;


procedure DequantQ8_1(const Data: PByte; Dest: PSingle; n_row: Int64);
var
  nb, i, j: Integer;
  B: PBlockQ8_1;
  d: Single;
begin
  nb := n_row div QK8_1;
  B := PBlockQ8_1(Data);
  for i := 0 to nb - 1 do
  begin
    d := FP16ToFP32(B^.d);
    for j := 0 to QK8_1 - 1 do
      Dest[j] := d * B^.qs[j];
    Inc(Dest, QK8_1);
    Inc(B);
  end;
end;



end.
