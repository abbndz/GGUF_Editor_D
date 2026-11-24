unit uGgmlQuantsTQ2;

{ ============================================================================
  TQ1_0 (1.6875 bpw) et TQ2_0 (2.0625 bpw) : Ternary quants (BitNet b1.58, TriLMs)
    - dequantize_row_tq1_0() / quantize_row_tq1_0_ref()
    - dequantize_row_tq2_0() / quantize_row_tq2_0_ref()

  Blocs (uGGMLConstants) :
    TBlockTQ1_0 = qs[0..47] + qh[0..3] + d:Word   -> 54 octets  (256 elem)
    TBlockTQ2_0 = qs[0..63]          + d:Word     -> 66 octets  (256 elem)
  Controlles par Assert (54/66) : 54*8/256 = 1.6875, 66*8/256 = 2.0625 bpw.

  FIDELITE BIT-A-BIT (a ne pas « ameliorer ») :
   1) TQLRound = lroundf (.5 loin de zero). Round() de Delphi = banker's rounding
      -> fichiers NON comparables a llama.cpp.
   2) TQ1 dequant : 'Byte(qs * 3^n)' : le WRAP modulo 256 n'est pas un bug,
      c'est lui qui extrait le trit. Le Word() qui suit lit le octet TRONQUE.
   3) TQ1 : 3 boucles d'octets  32 (160 elem) -> 16 (80 elem) -> qh (16 elem),
      avec avance du pointeur x de 160, 80, 16 (total 256).
   4) id = 1/amax en float ; seul y.d passe en FP16 (asymetrie assument du C).
   5) AUCUN clamp de xi : |x*id| <= 1 + 1ulp -> lroundf(x*id) in [-1,1].
   6) NaN : MAX(0, fabsf(NaN)) = 0 -> d = 0 -> id = 0 -> tout a 0 (idem C).
   7) les poids ne servent pas ((void)quant_weights dans le C).
  ============================================================================ }

interface

uses
  SysUtils, Classes, uMath, uGGMLTypes, uGGMLConstants, uGgmlQuantsFP16,
  uAppConfig;

{$B-}
{$R-}
{$POINTERMATH ON}
{$J-}
{$Q-}          // le wrap modulo 256 du C est VOLONTAIRE -> pas d'overflow check
{$O+}
{$ALIGN 8}

const
  // expressions du C (ggml-common.h), QK_K = 256
  TQ1_QS_LEN = ( QK_K - 4 * (QK_K div 64)) div 5;  // 48 octets (5 elements/octet)
  TQ1_QH_LEN = QK_K div 64;                       //  4 octets (4 elements/octet)
  TQ1_QS_32 = TQ1_QS_LEN - (TQ1_QS_LEN mod 32);  // 32 octets traites "le long de 32"
  TQ2_QS_LEN = QK_K div 4;                        // 64 octets (2 bits/element)

  TQ_TRITS = 243;                               // 3^5
  TQ_CEIL_NUM = 256;                               // ceil(q*256/243)

// Dequantisation

procedure DequantTQ1_0(const Data: PByte; Dest: PSingle; n_row: Integer);

procedure DequantTQ2_0(const Data: PByte; Dest: PSingle; n_row: Integer);

// Quantisation de reference (deterministe, identique a llama.cpp)
procedure QuantTQ1_0_Ref(pSrc: PSingle; Dest: PByte; n_row: Integer);

procedure QuantTQ2_0_Ref(pSrc: PSingle; Dest: PByte; n_row: Integer);

// Variantes d'interface : les presets de tuning n'ont AUCUN effet sur les ternary
// quants (le C ignore quant_weights). Elles n'existent que pour la compatibilite
// du dispatcher / de l'UI (cbUseImpl, profils QP_PROF_*). Aucun champ edt utile :
// EnabledFields = [] dans uQuantPresetConfig.
procedure QuantTQ1_0_Impl(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil; iQk: Integer = QP_PROF_IMPL1);

procedure QuantTQ1_0_Impl1(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil; iQk: Integer = QP_PROF_IMPL1);

procedure QuantTQ1_0_Impl2(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);

procedure QuantTQ1_0_Impl3(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
procedure QuantTQ1_0_Impl4(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
procedure QuantTQ1_0_Impl5(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);

procedure QuantTQ2_0_Impl(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil; iQk: Integer = QP_PROF_IMPL1);

procedure QuantTQ2_0_Impl1(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil; iQk: Integer = QP_PROF_IMPL1);
procedure QuantTQ2_0_Impl2(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
procedure QuantTQ2_0_Impl3(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
procedure QuantTQ2_0_Impl4(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);
procedure QuantTQ2_0_Impl5(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);

// Autotest (optionnel, ne doit pas etre appele en production)
function TQSelfTest: Boolean;

implementation

uses
  uQuantPresetConfig;

const
  // C : static const uint8_t pow3[6] = {1, 3, 9, 27, 81, 243};
  POW3: array[0..5] of Byte = (1, 3, 9, 27, 81, 243);

// C : lroundf -> arrondi a l'entier le plus proche, .5 LOIN de zero
function TQLRound(f: Single): Integer; inline;
begin
  if not (f = f) then            // NaN -> 0 (comme le C avec d = 0)
    Exit(0);
  if f >= 0 then
    Result := Trunc(f + 0.5)
  else
    Result := -Trunc(-f + 0.5);
end;

// ceil(q * 256 / 243) : C ((uint16_t)q * 256 + (243-1)) / 243
function TQScaleUp(q: Integer): Byte; inline;
begin
  Result := Byte((q * TQ_CEIL_NUM + (TQ_TRITS - 1)) div TQ_TRITS);
end;

// trit depuis un octet deja compacte : q = Byte(octet * 3^n) PUIS xi = (q*3) shr 8
function TQTrit(octet, n: Integer): Integer; inline;
begin
  Result := (Word(Byte(octet * POW3[n])) * 3) shr 8;   // wrap 256 VOLONTAIRE
end;

// ================================ DEQUANTISATION ============================

procedure DequantTQ1_0(const Data: PByte; Dest: PSingle; n_row: Integer);
var
  nb, i, j, n, m: Integer;
  B: PBlockTQ1_0;
  d: Single;
begin
  Assert(SizeOf(TBlockTQ1_0) = 54);
  Assert((n_row mod QK_K) = 0);
  nb := n_row div QK_K;

  for i := 0 to nb - 1 do
  begin
    B := PBlockTQ1_0(Data + Int64(i) * SizeOf(TBlockTQ1_0));
    d := FP16ToFP32(B.d);

    // 5 elements par octet, le long de 32 octets  -> 160 elements
    j := 0;
    while j < TQ1_QS_32 do
    begin
      for n := 0 to 4 do
        for m := 0 to 31 do
        begin
          Dest^ := Single(TQTrit(B.qs[j + m], n) - 1) * d;
          Inc(Dest);
        end;
      Inc(j, 32);
    end;

    // 5 elements par octet, le long de 16 octets  -> 80 elements
    while j < TQ1_QS_LEN do
    begin
      for n := 0 to 4 do
        for m := 0 to 15 do
        begin
          Dest^ := Single(TQTrit(B.qs[j + m], n) - 1) * d;
          Inc(Dest);
        end;
      Inc(j, 16);
    end;

    // 4 elements par octet dans qh                -> 16 elements
    for n := 0 to 3 do
      for j := 0 to TQ1_QH_LEN - 1 do
      begin
        Dest^ := Single(TQTrit(B.qh[j], n) - 1) * d;
        Inc(Dest);
      end;
  end;
end;

procedure DequantTQ2_0(const Data: PByte; Dest: PSingle; n_row: Integer);
var
  nb, i, j, l, m, q: Integer;
  B: PBlockTQ2_0;
  d: Single;
begin
  Assert(SizeOf(TBlockTQ2_0) = 66);
  Assert((n_row mod QK_K) = 0);
  nb := n_row div QK_K;

  for i := 0 to nb - 1 do
  begin
    B := PBlockTQ2_0(Data + Int64(i) * SizeOf(TBlockTQ2_0));
    d := FP16ToFP32(B.d);

    j := 0;
    while j < TQ2_QS_LEN do          // 64 octets, pas de 32
    begin
      for l := 0 to 3 do             // 2 bits / element, 4 elements par octet
        for m := 0 to 31 do
        begin
          q := (B.qs[j + m] shr (l * 2)) and 3;    // 0,1,2 -> -1,0,+1
          Dest^ := Single(q - 1) * d;
          Inc(Dest);
        end;
      Inc(j, 32);
    end;
  end;
end;

// ================================= QUANTISATION =============================

procedure QuantTQ1_0_Ref(pSrc: PSingle; Dest: PByte; n_row: Integer);
var
  nb, i, j, n, m: Integer;
  y: PBlockTQ1_0;
  amax, d, id, v: Single;
  q, xi: Integer;
begin
  Assert(SizeOf(TBlockTQ1_0) = 54);
  Assert((n_row mod QK_K) = 0);
  nb := n_row div QK_K;

  for i := 0 to nb - 1 do
  begin
    y := PBlockTQ1_0(Dest + Int64(i) * SizeOf(TBlockTQ1_0));

    amax := 0.0;
    for j := 0 to QK_K - 1 do
    begin
      v := Abs(pSrc[j]);
      if v > amax then
        amax := v;         // MAX(amax, fabsf(v)) : NaN ignore
    end;
    d := amax;                            // NB : d float, PAS le FP16
    if d <> 0 then
      id := 1 / d
    else
      id := 0;
    y.d := FP32ToFP16(d);

    // 32 octets / 5 elements -> 160 elements
    j := 0;
    while j < TQ1_QS_32 do
    begin
      for m := 0 to 31 do
      begin
        q := 0;
        for n := 0 to 4 do                // n = 0 : trit le plus significatif
        begin
          xi := TQLRound(pSrc[m + n * 32] * id) + 1;   // -1,0,1 -> 0,1,2
          q := q * 3 + xi;
        end;
        y.qs[j + m] := TQScaleUp(q);
      end;
      Inc(pSrc, 5 * 32);                  // 160
      Inc(j, 32);
    end;

    // 16 octets / 5 elements -> 80 elements
    while j < TQ1_QS_LEN do
    begin
      for m := 0 to 15 do
      begin
        q := 0;
        for n := 0 to 4 do
        begin
          xi := TQLRound(pSrc[m + n * 16] * id) + 1;
          q := q * 3 + xi;
        end;
        y.qs[j + m] := TQScaleUp(q);
      end;
      Inc(pSrc, 5 * 16);                  // 80
      Inc(j, 16);
    end;

    // qh : 4 elements par octet -> 16 elements
    for j := 0 to TQ1_QH_LEN - 1 do
    begin
      q := 0;
      for m := 0 to 3 do
      begin
        xi := TQLRound(pSrc[j + m * TQ1_QH_LEN] * id) + 1;
        q := q * 3 + xi;
      end;
      q := q * 3;                         // 1er trit en position la plus significative
      y.qh[j] := TQScaleUp(q);
    end;
    Inc(pSrc, 4 * TQ1_QH_LEN);            // 16   (total 160+80+16 = 256)
  end;
end;

procedure QuantTQ2_0_Ref(pSrc: PSingle; Dest: PByte; n_row: Integer);
var
  nb, i, j, n, m: Integer;
  y: PBlockTQ2_0;
  amax, d, id, v: Single;
  q, xi: Integer;
begin
  Assert(SizeOf(TBlockTQ2_0) = 66);
  Assert((n_row mod QK_K) = 0);
  nb := n_row div QK_K;

  for i := 0 to nb - 1 do
  begin
    y := PBlockTQ2_0(Dest + Int64(i) * SizeOf(TBlockTQ2_0));

    amax := 0.0;
    for j := 0 to QK_K - 1 do
    begin
      v := Abs(pSrc[j]);
      if v > amax then
        amax := v;
    end;
    d := amax;
    if d <> 0 then
      id := 1 / d
    else
      id := 0;
    y.d := FP32ToFP16(d);

    j := 0;
    while j < TQ2_QS_LEN do               // 2 iterations de 32 octets (128 + 128)
    begin
      for m := 0 to 31 do
      begin
        q := 0;
        for n := 0 to 3 do
        begin
          xi := TQLRound(pSrc[m + n * 32] * id) + 1;    // -1,0,1 -> 0,1,2
          q := q or ((xi and 3) shl (2 * n));
        end;
        y.qs[j + m] := Byte(q);
      end;
      Inc(pSrc, 4 * 32);                  // 128
      Inc(j, 32);
    end;
  end;
end;

// ---- wrappers : presets inapplicables aux ternary quants (voir en-tete) ----

procedure QuantTQ1_0_Impl(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle; iQk: Integer);
begin
  QuantTQ1_0_Ref(pSrc, Dest, n_row);
end;

procedure QuantTQ1_0_Impl1(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle; iQk: Integer);
begin
  QuantTQ1_0_Ref(pSrc, Dest, n_row);
end;

procedure QuantTQ1_0_Impl2(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle);
begin
  QuantTQ1_0_Ref(pSrc, Dest, n_row);
end;

procedure QuantTQ1_0_Impl3(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle);
begin
  QuantTQ1_0_Ref(pSrc, Dest, n_row);
end;

procedure QuantTQ1_0_Impl4(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle);
begin
  QuantTQ1_0_Ref(pSrc, Dest, n_row);
end;

procedure QuantTQ1_0_Impl5(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle);
begin
  QuantTQ1_0_Ref(pSrc, Dest, n_row);
end;

procedure QuantTQ2_0_Impl(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle; iQk: Integer);
begin
  QuantTQ2_0_Ref(pSrc, Dest, n_row);
end;

procedure QuantTQ2_0_Impl1(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle; iQk: Integer);
begin
  QuantTQ2_0_Ref(pSrc, Dest, n_row);
end;

procedure QuantTQ2_0_Impl2(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle);
begin
  QuantTQ2_0_Ref(pSrc, Dest, n_row);
end;

procedure QuantTQ2_0_Impl3(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle);
begin
  QuantTQ2_0_Ref(pSrc, Dest, n_row);
end;

procedure QuantTQ2_0_Impl4(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle);
begin
  QuantTQ2_0_Ref(pSrc, Dest, n_row);
end;

procedure QuantTQ2_0_Impl5(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle);
begin
  QuantTQ2_0_Ref(pSrc, Dest, n_row);
end;

// ============================== AUTOTEST (optionnel) ========================
// Verifie (a) le round-trip des 243 compactages TQ1_0 vers {-1,0,+1},
// (b) 3^4 pour TQ2_0 sur 8 elements, (c) l'arrondi de TQLRound.
function TQSelfTest: Boolean;
var
  blk : TBlockTQ1_0;
  b2: TBlockTQ2_0;
  q, n, xi: Integer;
  src, outv: array[0..QK_K - 1] of Single;
  i, err: Integer;
begin
  Result := False;

  // (c) arrondi type lroundf
  if (TQLRound(0.5) <> 1) or (TQLRound(-0.5) <> -1) or (TQLRound(1.5) <> 2) then
    Exit;

  // (a) tous les compactages possibles : q in [0, 242]
  for q := 0 to TQ_TRITS - 1 do
  begin
    FillChar(blk, SizeOf(blk), 0);
    blk.d := FP32ToFP16(1.0);
    blk.qs[0] := TQScaleUp(q);
    for n := 0 to 4 do
    begin
      xi := TQTrit(blk.qs[0], n);
      if (xi < 0) or (xi > 2) then
        Exit;
      // le trit lu doit etre le trit n de q (base 3, MSB d'abord)
      if xi <> ((q div POW3[4 - n]) mod 3) then
        Exit;
    end;
  end;

  // (b) TQ2_0 : paquets de 4 trits
  for q := 0 to 80 do
  begin
    FillChar(b2, SizeOf(b2), 0);
    b2.d := FP32ToFP16(1.0);
    b2.qs[0] := Byte(q and 3 or ((q shr 2) and 3) shl 2 or ((q shr 4) and 3) shl 4 or ((q shr 6) and 3) shl 6);
    for n := 0 to 3 do
      if ((b2.qs[0] shr (2 * n)) and 3) <> ((q shr (2 * n)) and 3) then
        Exit;
  end;

  // (d) quant/dequant complete sur un signal connu
  for i := 0 to QK_K - 1 do
    src[i] := Cos(i * 0.07) * 1.3;
  QuantTQ1_0_Ref(@src[0], @blk, QK_K);
  DequantTQ1_0(@blk, @outv[0], QK_K);
  err := 0;
  for i := 0 to QK_K - 1 do
    if (outv[i] <> -1.0 * FP16ToFP32(blk.d)) and (outv[i] <> 0.0) and (outv[i] <> FP16ToFP32(blk.d)) then
      Inc(err);
  if err <> 0 then
    Exit;                            // sortie hors {-d,0,+d}

  QuantTQ2_0_Ref(@src[0], @b2, QK_K);
  DequantTQ2_0(@b2, @outv[0], QK_K);
  err := 0;
  for i := 0 to QK_K - 1 do
    if (outv[i] <> -1.0 * FP16ToFP32(b2.d)) and (outv[i] <> 0.0) and (outv[i] <> FP16ToFP32(b2.d)) then
      Inc(err);
  Result := (err = 0);
end;

end.

