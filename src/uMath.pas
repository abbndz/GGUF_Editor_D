unit uMath;

interface

uses SysUtils;

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
  { The following constants should not be used for comparison, only
    assignments. For comparison please use the IsNan and IsInfinity functions
    provided below. }
  NaN = 0.0 / 0.0;
  Infinity = 1.0 / 0.0;
  NegInfinity = -1.0 / 0.0;

function IntPower(const Base: Extended; const Exponent: Integer): Extended;
function Power(const Base, Exponent: Extended): Extended; overload; inline;

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

function Ceil(const X: Single): Integer;

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

function CRound(const X: Single): Integer; inline;
function NearestInt(const X: Single): Integer; inline;
function CRound10(const X: Single): Integer; inline;
function ClampInt(const Value, MinVal, MaxVal: Integer): Integer; inline;
function ClampSingle(const Value, MinVal, MaxVal: Single): Single; inline;

implementation

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

function Ceil(const X: Single): Integer;
begin
  Result := Integer(Trunc(X));
  if Frac(X) > 0 then
    Inc(Result);
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

function CRound(const X: Single): Integer; inline;
begin
  Result := Trunc(Single(X + 0.5)); // Équivalent C: floor(x+0.5f)
end;

function NearestInt(const X: Single): Integer; inline;
var
  Val: Single;
  IntVal: Cardinal;
begin
  Val := X + 12582912.0;
  Move(Val, IntVal, SizeOf(IntVal));
  Result := Integer((IntVal and $007FFFFF) - $00400000);
end;

function CRound10(const X: Single): Integer;
var
  Val: Single;
  IntVal: Cardinal;
begin
  Val := X + 12582912.0;
  Move(Val, IntVal, SizeOf(IntVal));
  Result := Integer((IntVal and $007FFFFF) - $00400000);
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
