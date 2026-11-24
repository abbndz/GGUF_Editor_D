unit uDiffStats;

interface

uses
  SysUtils, Math, uGGUFModel;

type
  TDiffWeightMode = (wmNone, wmAbs, wmSq, wmSqrtAbs, wmImatrix);
  TDiffRefSel = (wrV1, wrV2, wrMaxAbs);

  TDiffWeights = record
    Mode: TDiffWeightMode;
    Imatrix: array of Single; // poids d'importance par NE[0] (imatrix.dat), vide = non
    RefSel: TDiffRefSel; // source du poids quand Mode <> wmImatrix
    Cols: Int64; // ne[0] du tenseur de reference (indexation imatrix)
  end;

 TDiffStats = record
    Count, MaxIdx, MinIdx: Int64;
    Mean, RMS, MAE, MaxDiff, MinDiff: Double;
    WRMSE: Double; // sqrt( sum(w*d^2) / sum(w) )
    WRMSERel: Double; // sqrt( sum(w*d^2) / sum(w*xref^2) )  -> comparable entre tenseurs
    WSum: Double; // sum(w)           (0 => metrique degeneree)
    WCnt: Int64; // nb d'elements avec w > 0 et finis
    NEff: Double; // (sum w)^2 / sum(w^2) : taille d'echantillon effective
    WValid: Boolean; // False -> afficher '—' (jamais 0 ni NaN)
    FElapsedMs: Int64;
  end;


  TDiffAcc = record
    Count: Int64;
    MaxIdx, MinIdx: Int64;
    SumD, SumD2, SumAbs: Double;
    MaxDif, MinDif: Double;
    // MaxI, MinI: Int64;
    WCnt: Int64; // nb d'elements avec w > 0 et finis
    WSum: Double; // sum(w)           (0 => metrique degeneree)
    WSumD2, WSumX2, WSum2: Double;

    MinVal0, MaxVal0: Double;
    MinVal1, MaxVal1: Double;
    MinVal2, MaxVal2: Double;

    WValid: Boolean; // False -> afficher '—' (jamais 0 ni NaN)

    procedure Reset;
    procedure Merge(const Other: TDiffAcc);
    // SubMode = True -> V1 - V2 ; False -> ratio V1/V2
    procedure Add(V1, V2: Single; Idx: Int64; SubMode: Boolean; const WT: TDiffWeights);
    function RMS: Double;
    function WRMSE: Double; // sqrt( sum(w*d^2) / sum(w) )
    function WRMSERel: Double; // sqrt( sum(w*d^2) / sum(w*xref^2) )  -> comparable entre tenseurs
    function MAE: Double;
    function Mean: Double;
    function NEff: Double; // (sum w)^2 / sum(w^2) : taille d'echantillon effective
  end;

function NaN64: Double;
function WModeToStr(M: TDiffWeightMode): string;
/// Poids pour les stats de difference (mode courant : wmAbs / wrV1)
procedure BuildDiffWeights(T1: TGGUFTensorInfo; out WT: TDiffWeights);
procedure CopyStatsFromAcc(var St: TDiffStats; const A: TDiffAcc; AElapsedMs: Int64);

implementation

const
  W_FLOOR = 1E-38; // evite w = 0 sur denormaux FP16/BF16
  cNaNBits: array [0 .. 7] of Byte = ($00, $00, $00, $00, $00, $00, $F8, $7F);

function NaN64: Double;
begin
  Result := PDouble(@cNaNBits)^;
end;

{ ============================================================================
  Poids pour les stats de difference (mode courant : wmAbs / wrV1)
============================================================================ }
procedure BuildDiffWeights(T1: TGGUFTensorInfo; out WT: TDiffWeights);
begin
  WT.Mode := wmAbs;    // cfg.TVDiffWMode (option 11 = off : poids |x|)
  WT.RefSel := wrV1;   // le poids est porte par le tenseur de reference
  WT.Cols := 0;
  if T1 <> nil then
    WT.Cols := T1.Cols; // indexation colonne de l'imatrix, si utilisee
end;


procedure CopyStatsFromAcc(var St: TDiffStats; const A: TDiffAcc; AElapsedMs: Int64);
begin
  St.Count := A.Count;
  St.MaxIdx := A.MaxIdx;
  St.MinIdx := A.MinIdx;
  if A.Count > 0 then
  begin
    St.Mean := A.Mean;
    St.RMS := A.RMS;
    St.MAE := A.MAE;
    St.NEff := A.NEff;
    St.MaxDiff := A.MaxDif;
    St.MinDiff := A.MinDif;
  end
  else
  begin
    FillChar(St, SizeOf(St), 0);
    //St.Mean := NaN64;
    //St.RMS := NaN64;
    //St.MAE := NaN64;
    //St.MaxDiff := NaN64;
    //St.MinDiff := NaN64;
  end;
  with St do
  begin
    WRMSE := A.WRMSE;
    WRMSERel := A.WRMSERel;
    WSum := A.WSum;
    WCnt := A.WCnt;
    NEff := A.NEff;
    WValid := (A.WSum > 0) and (A.WCnt > 0);
  end;
  St.FElapsedMs := AElapsedMs;
end;

function WModeToStr(M: TDiffWeightMode): string;
begin
  case M of
    wmNone:
      Result := 'w=1';
    wmAbs:
      Result := 'w=|x|';
    wmSq:
      Result := 'w=x2';
    wmSqrtAbs:
      Result := 'w=sqrt|x|';
    wmImatrix:
      Result := 'w=imatrix';
  end;
end;

{ ---------------- TDiffAcc ---------------- }

procedure TDiffAcc.Reset;
begin
  Count := 0;
  SumD := 0;
  SumD2 := 0;
  SumAbs := 0;
  MaxDif := -MaxSingle;
  MinDif := MaxSingle;
  MaxIdx := -1;
  MinIdx := -1;
  WCnt := 0;
  WSum := 0;
  WSumD2 := 0;
  WSumX2 := 0;
  WSum2 := 0;
  MinVal0 := MaxSingle;
  MaxVal0 := -MaxSingle;
  MinVal1 := MaxSingle;
  MaxVal1 := -MaxSingle;
  MinVal2 := MaxSingle;
  MaxVal2 := -MaxSingle;
  WValid := False;
end;


{ Fusionne Other dans Self (addition des sommes, min/max, index extrêmes).
  Other ignoré s'il est vide.  L'ordre de fusion est celui du tableau de
  briques (croissant), donc le résultat est IDENTIQUE d'un run à l'autre. }
procedure TDiffAcc.Merge(const Other: TDiffAcc);
begin
  if (Other.Count <= 0) and (Other.WCnt <= 0) then
    Exit;

  SumD   := SumD   + Other.SumD;
  SumD2  := SumD2  + Other.SumD2;
  SumAbs := SumAbs + Other.SumAbs;
  WSum   := WSum   + Other.WSum;
  WSumD2 := WSumD2 + Other.WSumD2;
  WSumX2 := WSumX2 + Other.WSumX2;
  WSum2  := WSum2  + Other.WSum2;

  Inc(Count, Other.Count);
  Inc(WCnt,  Other.WCnt);

  if Other.MaxDif > MaxDif then begin MaxDif := Other.MaxDif; MaxIdx := Other.MaxIdx; end;
  if Other.MinDif < MinDif then begin MinDif := Other.MinDif; MinIdx := Other.MinIdx; end;

  if Other.MinVal0 < MinVal0 then MinVal0 := Other.MinVal0;
  if Other.MaxVal0 > MaxVal0 then MaxVal0 := Other.MaxVal0;
  if Other.MinVal1 < MinVal1 then MinVal1 := Other.MinVal1;
  if Other.MaxVal1 > MaxVal1 then MaxVal1 := Other.MaxVal1;
  if Other.MinVal2 < MinVal2 then MinVal2 := Other.MinVal2;
  if Other.MaxVal2 > MaxVal2 then MaxVal2 := Other.MaxVal2;
end;


function TDiffAcc.RMS: Double;
begin
  if Count > 0 then
    Result := Sqrt(SumD2 / Count)
  else
    Result := NaN64;
end;

function TDiffAcc.MAE: Double;
begin
  if Count > 0 then
    Result := SumAbs / Count
  else
    Result := NaN64;
end;

function TDiffAcc.Mean: Double;
begin
  if Count > 0 then
    Result := SumD / Count
  else
    Result := NaN64;
end;

function TDiffAcc.WRMSE: Double;
begin
  if WSum > 0 then
    Result := Sqrt(WSumD2 / WSum)
  else
    Result := NaN64;
end;

function TDiffAcc.WRMSERel: Double;
begin
  if WSumX2 > 0 then
    Result := Sqrt(WSumD2 / WSumX2)
  else
    Result := NaN64;
end;

function TDiffAcc.NEff: Double;
begin
  if (WSum2 > 0) and (WSum > 0) then
    Result := Sqr(WSum) / WSum2
  else
    Result := 0;
end;

procedure TDiffAcc.Add(V1, V2: Single; Idx: Int64; SubMode: Boolean; const WT: TDiffWeights);
var
  D, w, ax, b, xr: Double;
  c: Int64;
begin
  // 1. erreur, (points non finis ignores)
  if SubMode then
    D := V1 - V2
  else
  begin
    if (Abs(V1) > 1E-6) and (Abs(V2) > 1E-6) then
      D := V1 / V2
    else
      D := 1.0;
  end;
  if IsNan(D) or IsInfinite(D) then
    Exit;

  Inc(Count);
  if V1 > MaxVal1 then
    MaxVal1 := V1
  else if V1 < MinVal1 then
    MinVal1 := V1;

  if V2 > MaxVal2 then
    MaxVal2 := V2
  else if V2 < MinVal2 then
    MinVal2 := V2;

  SumD := SumD + D;
  SumD2 := SumD2 + D * D;
  SumAbs := SumAbs + Abs(D);

  if D > MaxDif then
  begin
    MaxDif := D;
    MaxIdx := Idx;
  end else
  if D < MinDif then
  begin
    MinDif := D;
    MinIdx := Idx;
  end;

  // 2. poids : en mode ratio, erreur d'interet = (ratio - 1),
  // et un poids x^2 n'a plus de sens -> on force l'activite |xref|
  if SubMode then
    xr := V1
  else
    xr := V1; // reference = V1 dans les deux cas

  if WT.RefSel = wrV2 then
    xr := V2
  else if WT.RefSel = wrMaxAbs then
    if Abs(V2) > Abs(V1) then
      xr := V2;

  w := 1.0;
  if WT.Mode = wmImatrix then
  begin
    if Length(WT.Imatrix) > 0 then
    begin
      c := Idx;
      if WT.Cols > 0 then
        c := c mod WT.Cols; // ne[0] = dimension la plus rapide
      if (c >= 0) and (c < Length(WT.Imatrix)) then
        w := WT.Imatrix[c];
    end;
  end
  else if SubMode then
  begin
    ax := Abs(xr);
    case WT.Mode of
      wmNone:
        w := 1.0;
      wmAbs:
        w := ax;
      wmSq:
        w := ax * ax;
      wmSqrtAbs:
        w := Sqrt(ax);
    end;
  end
  else
    w := Abs(xr); // mode ratio : importance = activite

  if IsNan(w) or IsInfinite(w) or (w < W_FLOOR) then
    Exit;

  // en ratio, on pondere l'erreur relative (D-1)
  if not SubMode then
    b := D - 1.0
  else
    b := D;

  Inc(WCnt);
  WSum := WSum + w;
  WSumD2 := WSumD2 + w * b * b;
  WSumX2 := WSumX2 + w * xr * xr;
  WSum2 := WSum2 + w * w; // pour NEff

end;

end.
