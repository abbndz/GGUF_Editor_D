unit uMath;

interface

uses SysUtils;

{$B-}
{$R-}
{$POINTERMATH ON}
{$J-}
{$O+}
{$Q-}
{$ALIGN 8}

const { Ranges of the IEEE floating point types, including denormals }

  MinSingle = 1.1754943508222875080E-38;
  MinSingleDenormal = 1.4012984643248170709E-45;
  MaxSingle = 340282346638528859811704183484516925440.0;
  MinDouble = 2.2250738585072013831E-308;
  MinDoubleDenormal = 4.9406564584124654418E-324;
  MaxDouble = 1.7976931348623157081E+308;
  MinExtended80 = 3.36210314311209350625E-4932;
  MinExtended80Denormal = 3.64519953188247460253E-4951;
  MaxExtended80 = 1.18973149535723176505E+4932;
  MinExtended = MinDouble;
  MinExtendedDenormal = MinDoubleDenormal;
  MaxExtended = MaxDouble;
  MinComp = -9223372036854775807;
  MaxComp = 9223372036854775807;

  NaN = 0.0 / 0.0;
  Infinity = 1.0 / 0.0;
  NegInfinity = -1.0 / 0.0;

function Log10(const X: Single): Single;

function IsValidFiniteSingle(const v: Single): Boolean; inline;
function Sign(const AValue: Single): Integer; inline;

function IntPower(const Base: Extended; const Exponent: Integer): Extended;
function Power(const Base, Exponent: Extended): Extended; overload; inline;
function Ldexp(const X: Single; const P: Integer): Single; inline;

function Min(const A, B: Integer): Integer; overload; inline;
function Min(const A, B: Cardinal): Cardinal; overload; inline;
function Min(const A, B: Int64): Int64; overload; inline;
function Min(const A, B: UInt64): UInt64; overload; inline;
function Min(const A, B: Single): Single; overload; inline;

function Max(const A, B: Integer): Integer; overload; inline;
function Max(const A, B: Cardinal): Cardinal; overload; inline;
function Max(const A, B: Int64): Int64; overload; inline;
function Max(const A, B: UInt64): UInt64; overload; inline;
function Max(const A, B: Single): Single; overload; inline;
function Max(const A, B: Double): Double; overload; inline;
function Min(const A, B: Double): Double; overload; inline;

function Ceil(const X: Single): Integer;
function CeilInt64(const X: Double): Int64;

function Gcd64(A, B: Int64): Int64;
function Lcm64(A, B: Int64): Int64;
function AlignUpI64(const A, M: Int64): Int64;
procedure AxisMargin(var Mn, Mx: Double; Frac: Double = 0.025);


{ roundf() du C : arrondi loin de zero (Trunc/Round Delphi ne le font pas) }
function CRound1(const X: Single): Integer; inline;

{ Extreme testing }

// Like an infinity, a NaN double value has an exponent of 7FF, but the NaN
// values have a fraction field that is not 0.
function IsNan(const AValue: Single): Boolean; overload;
function IsNan(const AValue: Double): Boolean; overload;
function IsNan(const AValue: Extended): Boolean; overload;

// Like a NaN, an infinity double value has an exponent of 7FF, but the
// infinity values have a fraction field of 0. Infinity values can be positive
// or negative, which is specified in the high-order, sign bit.
function IsInfinite(const AValue: Single): Boolean; overload;
function IsInfinite(const AValue: Double): Boolean; overload;
function IsInfinite(const AValue: Extended): Boolean; overload;

function NearestInt(const X: Single): Integer; inline;
function ClampInt(const Value, MinVal, MaxVal: Integer): Integer; inline;
function ClampSingle(const Value, MinVal, MaxVal: Single): Single; inline;

implementation


function Log10(const X: Single): Single;
  { Log.10(X) := Ln(X) / Ln(10) }
const
  InvLn10: Cardinal = $3EDE5BD9; // 1/Ln(10)
begin
  FClearExcept;
  Result := Ln(X) * PSingle(@InvLn10)^;
  FCheckExcept;
end;



function IsValidFiniteSingle(const v: Single): Boolean;
begin
  Result := (v = v) and (Abs(v) < 1E30);
end;

function Sign(const AValue: Single): Integer;
begin
  if (AValue < 0) then
    Result := -1
  else
    Result := 1;
end;

function IntPower(const Base: Extended; const Exponent: Integer): Extended;
var
  Y: Integer;
  LBase: Extended;
begin
  FClearExcept;
  Y := Abs(Exponent);
  LBase := Base;
  Result := 1.0;
  while Y > 0 do
  begin
    while not Odd(Y) do
    begin
      Y := Y shr 1;
      LBase := LBase * LBase
    end;
    Dec(Y);
    Result := Result * LBase
  end;
  if Exponent < 0 then
    Result := 1.0 / Result;
  FCheckExcept;
end;

function Power(const Base, Exponent: Extended): Extended;
begin
  if Exponent = 0.0 then
    Result := 1.0 { n**0 = 1 }
  else if (Base = 0.0) and (Exponent > 0.0) then
    Result := 0.0 { 0**n = 0, n > 0 }
  else if (Frac(Exponent) = 0.0) and (Abs(Exponent) <= MaxInt) then
    Result := IntPower(Base, Integer(Trunc(Exponent)))
  else if Base < 0 then
  begin
    FRaiseExcept(feeINVALID);
    Result := NaN; // Return NaN (not a number) if base is less than zero and Exponent is not natural number
  end
  else
    Result := Exp(Exponent * Ln(Base));
end;

function Ldexp(const X: Single; const P: Integer): Single;
{ Result := X * (2^P) }
var
  T: Single;
  I: Integer;
const
  MaxExp = 127;
  MinExp = -126;
  FractionOfOne = $00800000;
begin
  T := X;
  Result := X;
  case T.SpecialType of
    fsDenormal, fsNDenormal, fsPositive, fsNegative:
      begin
        FClearExcept;
        I := P;
        if I > MaxExp then
        begin
          T.BuildUp(False, FractionOfOne, MaxExp);
          Result := Result * T;
          I := I - MaxExp;
          if I > MaxExp then
            I := MaxExp;
        end
        else if I < MinExp then
        begin
          T.BuildUp(False, FractionOfOne, MinExp);
          Result := Result * T;
          I := I - MinExp;
          if I < MinExp then
            I := MinExp;
        end;
        if I <> 0 then
        begin
          T.BuildUp(False, FractionOfOne, I);
          Result := Result * T;
        end;
        if Result.SpecialType in [fsDenormal, fsNDenormal] then
          FRaiseExcept(feeUNDERFLOW);
        FCheckExcept;
      end;
    // fsZero,
    // fsNZero,
    // fsInf,
    // fsNInf,
    // fsNaN:
  else
    ;
  end;
end;

function Min(const A, B: Integer): Integer; inline;
begin
  if A < B then
    Result := A
  else
    Result := B;
end;

function Min(const A, B: Cardinal): Cardinal; inline;
begin
  if A < B then
    Result := A
  else
    Result := B;
end;

function Min(const A, B: Int64): Int64; inline;
begin
  if A < B then
    Result := A
  else
    Result := B;
end;

function Min(const A, B: UInt64): UInt64; inline;
begin
  if A < B then
    Result := A
  else
    Result := B;
end;

function Min(const A, B: Single): Single; inline;
begin
  if A < B then
    Result := A
  else
    Result := B;
end;

function Max(const A, B: Integer): Integer; inline;
begin
  if A > B then
    Result := A
  else
    Result := B;
end;

function Max(const A, B: Cardinal): Cardinal; inline;
begin
  if A > B then
    Result := A
  else
    Result := B;
end;

function Max(const A, B: Int64): Int64; inline;
begin
  if A > B then
    Result := A
  else
    Result := B;
end;

function Max(const A, B: UInt64): UInt64; inline;
begin
  if A > B then
    Result := A
  else
    Result := B;
end;

function Max(const A, B: Single): Single; inline;
begin
  if A > B then
    Result := A
  else
    Result := B;
end;

function Max(const A, B: Double): Double; inline;
begin
  if A > B then
    Result := A
  else
    Result := B;
end;

function Min(const A, B: Double): Double; inline;
begin
  if A < B then
    Result := A
  else
    Result := B;
end;

{ roundf() C : away-from-zero. Utilise uniquement la ou llama.cpp fait (int)roundf(). }
function CRound1(const X: Single): Integer;
begin
  if (X <> X) or (X > 2147483520.0) then
    Exit(MaxInt);
  if X < -2147483520.0 then
    Exit(-2147483520);
  if X >= 0.0 then
    Result := Integer(Trunc(X + 0.5))
  else
    Result := Integer(Trunc(X - 0.5));
end;

function Ceil(const X: Single): Integer;
var
  i64: Int64;
begin
  i64 := Trunc(X);
  if Frac(X) > 0 then
    Inc(i64);
  Result := i64; // ClampInt64To32(i64);
end;

function CeilInt64(const X: Double): Int64;
var
  i64: Int64;
begin
  i64 := Trunc(X);
  if Frac(X) > 0 then
    Inc(i64);
  Result := i64; // ClampInt64To32(i64);
end;

function Ceil1(const X: Single): Integer;
begin
  Result := Integer(Trunc(X));
  if Frac(X) > 0 then
    Inc(Result);
end;


// PGCD 64 bits (algorithme d'Euclide) ; valeurs absolues
function Gcd64(A, B: Int64): Int64;
var t: Int64;
begin
  if A < 0 then A := -A;
  if B < 0 then B := -B;
  while B <> 0 do
  begin
    t := A mod B; A := B; B := t;
  end;
  Result := A;
end;

// PPC 64 bits = (A / PGCD) * B ; 0 si entree invalide
function Lcm64(A, B: Int64): Int64;
var g: Int64;
begin
  if (A <= 0) or (B <= 0) then
    Exit(0);
  g := Gcd64(A, B);
  if g = 0 then
    Exit(0);
  Result := (A div g) * B;
end;


/// Arrondi SUPERIEUR de A au multiple de M (M > 0)
function AlignUpI64(const A, M: Int64): Int64;
begin
  if M <= 0 then Exit(A);
  Result := ((A + M - 1) div M) * M;
end;

// Marge proportionnelle a l'ETENDUE (le Mn*1.025 / Mx*1.025 actuel rogne si Mn>0
// et ne fait rien sur [0..N] en frequences).
procedure AxisMargin(var Mn, Mx: Double; Frac: Double = 0.025);
var span: Double;
begin
  if not (Mx > Mn) then Exit;
  span := Mx - Mn;
  if span = 0 then begin Mn := Mn - 0.5; Mx := Mx + 0.5; Exit; end;
  Mn := Mn - Frac * span;
  Mx := Mx + Frac * span;
end;


function IsNan(const AValue: Single): Boolean;
begin
  Result := AValue.SpecialType = TFloatSpecial.fsNaN;
end;

function IsNan(const AValue: Double): Boolean;
begin
  Result := AValue.SpecialType = TFloatSpecial.fsNaN;
end;

function IsNan(const AValue: Extended): Boolean;
begin
  Result := AValue.SpecialType = TFloatSpecial.fsNaN;
end;

function IsInfinite(const AValue: Single): Boolean;
begin
  Result := AValue.SpecialType in [TFloatSpecial.fsInf, TFloatSpecial.fsNInf];
end;

function IsInfinite(const AValue: Double): Boolean;
begin
  Result := AValue.SpecialType in [TFloatSpecial.fsInf, TFloatSpecial.fsNInf];
end;

function IsInfinite(const AValue: Extended): Boolean;
begin
  Result := AValue.SpecialType in [TFloatSpecial.fsInf, TFloatSpecial.fsNInf];
end;

function ClampInt(const Value, MinVal, MaxVal: Integer): Integer; inline;
// Utilitaire : contraint une valeur entière entre MinVal et MaxVal
begin
  Result := Value;
  if Result < MinVal then
    Result := MinVal;
  if Result > MaxVal then
    Result := MaxVal;
end;

function ClampSingle(const Value, MinVal, MaxVal: Single): Single; inline;
begin
  Result := Value;
  if Result < MinVal then
    Result := MinVal;
  if Result > MaxVal then
    Result := MaxVal;
end;

// test [18:56:02.258] [DIFF-Best1] token_embd.weight-BF16 MB vs token_embd.weight-Q3_K | P:[0..402653183] | E:32768 | RMS=... ⏱ 221,00 ms
function NearestInt(const X: Single): Integer; inline;
begin
  { if (X <> X) or (X > 2147483520.0) then
    Exit(MaxInt); // NaN / +inf
    if X < -2147483520.0 then // MinInt
    Exit(-2147483520); }
  Result := Round(X);
end;

// test [18:46:53.712] [DIFF-Best1] token_embd.weight-BF16 vs token_embd.weight-Q3_K | P:[0..402653183] | E:32768 | RMS=... ⏱ 312,00 ms
// test  [19:00:18.802] [DIFF-Best1] token_embd.weight-BF16 vs token_embd.weight-Q3_KB | P:[0..402653183] | E:32768 | RMS=... ⏱ 297,00 ms
function NearestInt1(const X: Single): Integer; inline;
var
  Val: Single;
  IntVal: Cardinal;
begin
  // 12582912.0 = 2^23 (bias standard pour Single)
  if X >= 0.0 then
  begin
    Val := X + 12582912.0;
    Move(Val, IntVal, SizeOf(IntVal));
    Result := Integer((IntVal and $007FFFFF) - $00400000);
  end
  else
  begin
    Val := -X + 12582912.0;
    Move(Val, IntVal, SizeOf(IntVal));
    Result := -Integer((IntVal and $007FFFFF) - $00400000);
  end;
end;

{ Fonction utilitaire pour imiter le roundf() de la librairie math.h en C }
function CRound2(const X: Single): Integer;
begin
  if X >= 0 then
    Result := Trunc(X + 0.5)
  else
    Result := Trunc(X - 0.5);
end;

end.
