unit uGGMLQuantUtils;
// Unité utilitaire pour l'optimisation RMSE (MSE) des quantifications GGML
// Fournit les algorithmes de recherche d'échelle, d'offset et d'optimisation de poids

interface

uses
  SysUtils, Classes, uMath, uGGMLConstants, uLog, uStrUtils;

{$B-}
{$R-}
{$POINTERMATH ON}
{$J-}
{$O+}
{$ALIGN 8}
{$R-}
// FillWeights
{
  Remplit un tableau de poids locaux.
  Paramètres :
  - src : pointeur vers les données source
  - weights : tableau de sortie à remplir
  - Count : nombre d'éléments
  - pWeight : poids externes optionnels (nil si poids internes)
  - sigma2 : variance globale optionnelle (utilisée si pWeight <> nil)
  - RmseType : mode de pondération
  0 => none (0) => uniforme w = 1.0 !
  1 => uniforme (1)
  2 => racine (sqrt(|x|))
  3 => magnitude (|x|)
  4 => variance (x²)
}
procedure FillWeights(const pSrc: PSingle; qWeights: PSingle; pWeight: PSingle; Count: Integer; RmseType: Integer;
  sigma2x2: Boolean = False; DoqWeights2: Boolean = False);

// Optimisation RMSE générique pour formats 2 à 6 bits. Recherche l'échelle qui minimise l'erreur quadratique moyenne pondérée.
// Q40, Q50, Q80, Q81, Q3K , Q6K    Rdelta, Nstep
function MakeQxQuants(n, nmax: Integer; const X: PSingle; L: PShortInt; rmse_type: Integer; const qw: PSingle;
  Rdelta: Single = 0.1; Nstep: Integer = 9): Single;

// Optimisation spécifique Q3_K (3 bits, range [-4, 3]). Utilise une descente de coordonnées itérative.
// Q3K  : QuantQ3_K_Ref
function MakeQ3Quants(n, nmax: Integer; const X: PSingle; L: PShortInt; do_rmse: Boolean; Q3Iter: Integer = 4): Single;

{ Optimisation conjointe Échelle + Offset (Minimum) pour les formats K (Q4_K, Q5_K, Q6_K).
  Résout une régression pondérée pour trouver d et min optimaux.
  Q41, Q51, Q2K , Q4K, Q5K   : Rmin, Rdelta ; Nstep
  Passes alternées : chaque passe reconstruit la grille a partir du min ACCEPTE
  (range adapte) et ne garde que ce qui ameliore le meilleur global -> monotone.
  AltPasses = 1 : comportement equivalent a une boucle de grille simple. AltPasses = 2..3 : ~+0.1..0.4% }
function MakeQkx2aQuants(n, nmax: Integer; const X: PSingle; const weights: PSingle; L: PByte; out MinVal: Single;
  Laux: PByte; Rmin, Rdelta: Single; Nstep: Integer; UseMAD: Boolean = False; ForcePositiveMin: Boolean = True): Single;

function MakeQkx2Quants(n, nmax: Integer; const X: PSingle; const weights: PSingle; L: PByte; out MinVal: Single;
  Laux: PByte; Rmin, Rdelta: Single; Nstep: Integer; UseMAD: Boolean = False; ForcePositiveMin: Boolean = True;
  AltPasses: Integer = 1): Single;

// Optimisation des super-paramètres (super-scales ou super-mins).
// Q2K , Q4K, Q5K : QpStep=0.1; QpSteps=4, QpIter=4
function MakeQpQuants(n, nmax: Integer; const X, weights: PSingle; L: PByte; QpStep: Single = 0.1; QpSteps: Integer = 4;
  QpIter: Integer = 4; UseMAD: Boolean = False): Single;

function MakeQpQuantsC(n, nmax: Integer; const X, quant_weights: PSingle; L: PByte): Single;

{ Raffine les codes (CodeS,CodeM) d'un sous-bloc pour l'objectif FINAL reellement ecrit,
  a (dS,dM) FP16 figes. Contrainte de format stricte :
  CodeMax : max des codes d'echelle  -> 63 (Q4_K,Q5_K) / 15 (Q2_K)
  QMax    : max des POIDS quantifies  -> 15 (Q4_K) / 31 (Q5_K) / 3 (Q2_K)
  x_rec = (dS*CodeS)*q - (dM*CodeM),  q = clamp(round((x+effM)/effS), 0, QMax)
  (kx,ky)=(0,0) inclus => ne peut pas empirer de facon non controlee. }
procedure RefineScaleMinCodes(var CodeS, CodeM: Byte; n, CodeMax, QMax, RadLs, RadLm: Integer;
  const X, weights: PSingle; L: PByte; dS, dM: Single);


// Décode un scale et un min packés sur 6 bits depuis le tableau de 12 octets du format Q4_K/Q5_K.
// procedure GetScaleMinK4(j: Integer; const scales: PByte; out sc, m: Byte); inline;

implementation

uses uGgmlQuantsFP16;

// FILL WEIGHTS
procedure FillWeights(const pSrc: PSingle; qWeights: PSingle; pWeight: PSingle; Count: Integer; RmseType: Integer;
  sigma2x2: Boolean = False; DoqWeights2: Boolean = False);
var
  ii: Integer;
  ww, sigma2, sumx2: Single;
begin
  if (Count <= 0) or (pSrc = nil) or (pWeight = nil) then
    Exit;

  // VARIANCE GLOBALE
  if (qWeights <> nil) or DoqWeights2 then
  begin
    sumx2 := 0.0;
    for ii := 0 to Count - 1 do
      sumx2 := sumx2 + Sqr(pSrc[ii]);
    if sigma2x2 then
      sigma2 := 2.0 * sumx2 / Count
    else
      sigma2 := sumx2 / Count;
  end;
  for ii := 0 to Count - 1 do
  begin
    if qWeights <> nil then
    begin
      // w = pWeight * sqrt(sigma2 + x²)
      ww := qWeights[ii] * Sqrt(sigma2 + Sqr(pSrc[ii]));
    end
    else
    begin
      // Pondération interne selon RmseType
      case RmseType of
        1, 0:
          ww := 1.0;
        2:
          ww := Sqrt(Abs(pSrc[ii]));
        3:
          ww := Abs(pSrc[ii]);
        4:
          ww := Sqr(pSrc[ii]);
      else
        ww := Abs(pSrc[ii]);
      end;
      if DoqWeights2 then
        ww := ww * Sqrt(sigma2 + Sqr(pSrc[ii]))
    end;
    // Sécurité : poids non fini ou négatif => fallback uniforme
    if (ww <= 0.0) or IsInfinite(ww) or IsNan(ww) then
      ww := 1.0;
    pWeight[ii] := ww;
  end;
end;

function MakeQxQuants0(n, nmax: Integer; const X: PSingle; L: PShortInt; rmse_type: Integer; const qw: PSingle;
  Rdelta: Single = 0.1; Nstep: Integer = 9): Single;
var
  ii, j, l_val: Integer;
  amax, MaxVal, iscale, iscale_init, Scale, best_iscale, sumlx, suml2, ww, best, new_score: Single;
  return_early: Boolean;
begin
  amax := 0.0;
  MaxVal := 0.0;
  for ii := 0 to n - 1 do
    if Abs(X[ii]) > amax then
    begin
      amax := Abs(X[ii]);
      MaxVal := X[ii];
    end;

  if amax < GROUP_EPS then
  begin
    for ii := 0 to n - 1 do
      L[ii] := 0; // ou 0 ! ? nmax , le C => L[i] = 0;
    Exit(0.0);
  end;

  iscale := -nmax / MaxVal;
  // if iscale < 0.0 then // cas MaxVal < 0 : moitié de grille perdue  : après test Q3, Q6 => dégradation !
  // iscale := nmax / amax; // fallback magnitude (l_val garde son signe)

  best_iscale := iscale;
  iscale_init := iscale;

  if rmse_type = 0 then
  begin
    for ii := 0 to n - 1 do
    begin
      l_val := NearestInt(iscale * X[ii]);
      L[ii] := nmax + ClampInt(l_val, -nmax, nmax - 1);
    end;
    Exit(1.0 / iscale);
  end;

  return_early := False;
  if rmse_type < 0 then
  begin
    rmse_type := -rmse_type;
    return_early := True;
  end;

  sumlx := 0.0;
  suml2 := 0.0;
  for ii := 0 to n - 1 do
  begin
    l_val := NearestInt(iscale * X[ii]);
    l_val := ClampInt(l_val, -nmax, nmax - 1);
    L[ii] := l_val + nmax;
    ww := qw[ii];
    sumlx := sumlx + ww * X[ii] * l_val;
    suml2 := suml2 + ww * l_val * l_val;
  end;

  if Abs(suml2) < EPS_SCALE then
  // if (suml2 <> suml2) or (suml2 = 0) then
  begin
    Scale := 0.0;
    best := 0.0;
  end
  else
  begin
    Scale := sumlx / suml2;
    best := Scale * sumlx;
  end;
  if return_early then
  begin
    if Abs(suml2) > EPS_SCALE then
      Exit(0.5 * (Scale + 1.0 / iscale))
    else
      Exit(1.0 / iscale);
  end;

  for ii := -Nstep to Nstep do // for (int is = -9; is <= 9; ++is) {
  begin
    if ii = 0 then
      Continue;
    iscale := -(nmax + Rdelta * ii) / MaxVal;
    sumlx := 0.0;
    suml2 := 0.0;

    for j := 0 to n - 1 do
    begin
      l_val := NearestInt(iscale * X[j]);
      l_val := ClampInt(l_val, -nmax, nmax - 1);
      // if qw <> nil then
      ww := qw[j];
      // else ww := 1;
      sumlx := sumlx + ww * X[j] * l_val;
      suml2 := suml2 + ww * l_val * l_val;
    end;

    if (Abs(suml2) > EPS_SCALE) then
    begin
      new_score := (sumlx * sumlx) / suml2;
      if new_score > best then
      begin
        best := new_score;
        Scale := sumlx / suml2;
        best_iscale := iscale;
      end;
    end;
  end;
  if best_iscale <> iscale_init then
    for j := 0 to n - 1 do
    begin
      L[j] := ClampInt(NearestInt(best_iscale * X[j]), -nmax, nmax - 1) + nmax;
    end;
  Result := Scale;
end;

function MakeQxQuants(n, nmax: Integer; const X: PSingle; L: PShortInt; rmse_type: Integer; const qw: PSingle;
  Rdelta: Single = 0.1; Nstep: Integer = 9): Single;
var
  ii, j, l_val: Integer;
  amax, MaxVal, iscale, iscale_init, best_iscale: Single;
  Scale, best, new_score: Single;
  return_early: Boolean;
  sumlx, suml2, ww, xv: Single;
begin
  amax := 0.0;
  MaxVal := 0.0;
  for ii := 0 to n - 1 do
    if Abs(X[ii]) > amax then
    begin
      amax := Abs(X[ii]);
      MaxVal := X[ii];
    end;

  if amax < GROUP_EPS then
  begin
    for ii := 0 to n - 1 do
      L[ii] := 0;
    Exit(0.0);
  end;

  iscale := -nmax / MaxVal;

  best_iscale := iscale;
  iscale_init := iscale;

  if rmse_type = 0 then
  begin
    for ii := 0 to n - 1 do
    begin
      l_val := NearestInt(iscale * X[ii]);
      L[ii] := nmax + ClampInt(l_val, -nmax, nmax - 1);
    end;
    Exit(1.0 / iscale);
  end;

  return_early := False;
  if rmse_type < 0 then
  begin
    rmse_type := -rmse_type;
    return_early := True;
  end;

  sumlx := 0.0;
  suml2 := 0.0;
  for ii := 0 to n - 1 do
  begin
    l_val := NearestInt(iscale * X[ii]);
    l_val := ClampInt(l_val, -nmax, nmax - 1);
    L[ii] := l_val + nmax;
    xv := X[ii];
    if (xv <> xv) then
      xv := 0.0;
    ww := qw[ii];
    if (ww <> ww) or (ww < 0.0) then
      ww := 1.0;
    sumlx := sumlx + ww * xv * l_val;
    suml2 := suml2 + ww * l_val * l_val;
  end;

  if Abs(suml2) < EPS_SCALE then
  begin
    Scale := 0.0;
    best := 0.0;
  end
  else
  begin
    Scale := sumlx / suml2;
    best := Scale * sumlx;
  end;
  if return_early then
  begin
    if Abs(suml2) > EPS_SCALE then
      Exit(Single(0.5 * (Scale + 1.0 / iscale)))
    else
      Exit(1.0 / iscale);
  end;

  for ii := -Nstep to Nstep do
  begin
    if ii = 0 then
      Continue;
    iscale := -(nmax + Rdelta * ii) / MaxVal;
    sumlx := 0.0;
    suml2 := 0.0;

    for j := 0 to n - 1 do
    begin
      l_val := NearestInt(iscale * X[j]);
      l_val := ClampInt(l_val, -nmax, nmax - 1);
      ww := qw[j];
      if (ww <> ww) or (ww < 0.0) then
        ww := 1.0;
      xv := X[j];
      if (xv <> xv) then
        xv := 0.0;
      sumlx := sumlx + ww * xv * l_val;
      suml2 := suml2 + ww * l_val * l_val;
    end;

    if Abs(suml2) > EPS_SCALE then
    begin
      new_score := (sumlx * sumlx) / suml2;
      if new_score > best then
      begin
        best := new_score;
        Scale := sumlx / suml2;
        best_iscale := iscale;
      end;
    end;
  end;
  if best_iscale <> iscale_init then
    for j := 0 to n - 1 do
      L[j] := ClampInt(NearestInt(best_iscale * X[j]), -nmax, nmax - 1) + nmax;
  Result := Single(Scale);
  {$IFDEF DEBUG}
  if LogIsOn(lvTrace) then
    LogT('[QUANT] MakeQx n=%d nmax=%d rmse=%d | scale=%.6f | bestScore=%.6f | iscale0=%.6f -> %.6f', //
      [n, nmax, rmse_type, Scale, best, iscale_init, best_iscale]);
  {$ENDIF}
end;

function MakeQ3Quants0(n, nmax: Integer; const X: PSingle; L: PShortInt; do_rmse: Boolean; Q3Iter: Integer = 4): Single;
var
  i, l_val, itry, n_changed, new_l: Integer;
  amax, MaxVal, iscale, sumlx, suml2, W, slx, sl2, new_slx, new_sl2, new_score, best_score: Single;
begin
  // Recherche du maximum absolu et de sa valeur signée
  amax := 0.0;
  MaxVal := 0.0;
  for i := 0 to n - 1 do
    if Abs(X[i]) > amax then
    begin
      amax := Abs(X[i]);
      MaxVal := X[i];
    end;
  // Fallback bloc nul
  if amax < GROUP_EPS then
  begin
    // FillChar(L^, n * SizeOf(ShortInt), 0);   // FillChar(L^, n, 0);
    for i := 0 to n - 1 do
      L[i] := nmax; // nmax ou 0 ; // q = 0 => L = q + nmax
    Exit(0.0);
  end;

  iscale := -nmax / MaxVal;

  if do_rmse then
  begin
    // Paramètre configurable pour la descente de coordonnées
    if Q3Iter <= 0 then
      Q3Iter := 4;

    // Initialisation des poids et calcul des sommes pondérées
    sumlx := 0.0;
    suml2 := 0.0;
    for i := 0 to n - 1 do
    begin
      l_val := NearestInt(iscale * X[i]);
      l_val := ClampInt(l_val, -nmax, nmax - 1);
      L[i] := l_val;
      W := X[i] * X[i]; // Pondération par variance (standard Q3_K)
      sumlx := sumlx + W * X[i] * l_val;
      suml2 := suml2 + W * l_val * l_val;
    end;

    // Calcul du score initial : S_xl² / S_ll (proportionnel à -MSE pondéré)
    if suml2 > 0 then
      best_score := (sumlx * sumlx) / suml2
    else
      best_score := 0.0;

    // Descente de coordonnées itérative (Gauss-Seidel)
    for itry := 0 to Q3Iter - 1 do
    begin
      n_changed := 0;
      for i := 0 to n - 1 do
      begin
        W := X[i] * X[i];
        // Soustraction de la contribution actuelle de L[I]
        slx := sumlx - W * X[i] * L[i];

        // Note GGML : la condition slx > 0.0 est conservée pour la stabilité
        // spécifique de la décomposition Q3_K.
        if slx > 0.0 then
        begin
          sl2 := suml2 - W * L[i] * L[i];
          if sl2 > 0.0 then
          begin
            // Proposition de nouveau poids
            new_l := ClampInt(NearestInt(X[i] * sl2 / slx), -nmax, nmax - 1);
            if new_l <> L[i] then
            begin
              // Calcul du score avec la proposition
              new_slx := slx + W * X[i] * new_l;
              new_sl2 := sl2 + W * new_l * new_l;
              new_score := (new_slx * new_slx) / new_sl2;

              // Validation alignée sur le pattern best_score
              if new_score > best_score then
              begin
                L[i] := new_l;
                sumlx := new_slx;
                suml2 := new_sl2;
                best_score := new_score;
                Inc(n_changed);
              end;
            end;
          end;
        end;
      end;
      if n_changed = 0 then
        Break; // Convergence atteinte
    end;

    // Décalage pour stockage non signé (Q3_K)
    for i := 0 to n - 1 do
      L[i] := L[i] + nmax;

    Result := 0.0;
    if suml2 > 0.0 then
      Result := sumlx / suml2;
  end
  else
  // Mode classique : quantification directe sans optimisation
  begin
    for i := 0 to n - 1 do
    begin
      l_val := NearestInt(iscale * X[i]);
      L[i] := ClampInt(l_val, -nmax, nmax - 1) + nmax;
    end;
    Result := 1.0 / iscale;
  end;
end;

function MakeQ3Quants(n, nmax: Integer; const X: PSingle; L: PShortInt; do_rmse: Boolean; Q3Iter: Integer = 4): Single;
var
  i, l_val, itry, n_changed, new_l: Integer;
  amax, MaxVal, iscale: Single;
  sumlx, suml2, W, slx, sl2, new_slx, new_sl2, new_score, best_score: Single;
  xv: Single;
begin
  amax := 0.0;
  MaxVal := 0.0;
  for i := 0 to n - 1 do
    if Abs(X[i]) > amax then
    begin
      amax := Abs(X[i]);
      MaxVal := X[i];
    end;

  if amax < GROUP_EPS then
  begin
    for i := 0 to n - 1 do
      L[i] := nmax;
    Exit(0.0);
  end;

  iscale := -nmax / MaxVal;

  if do_rmse then
  begin
    if Q3Iter <= 0 then
      Q3Iter := 4;

    sumlx := 0.0;
    suml2 := 0.0;
    for i := 0 to n - 1 do
    begin
      l_val := NearestInt(iscale * X[i]);
      l_val := ClampInt(l_val, -nmax, nmax - 1);
      L[i] := l_val;
      xv := X[i];
      if xv <> xv then
        xv := 0.0;
      W := xv * xv; // Pondération par variance (standard Q3_K)
      sumlx := sumlx + W * xv * l_val;
      suml2 := suml2 + W * l_val * l_val;
    end;

    if suml2 > 0 then
      best_score := (sumlx * sumlx) / suml2
    else
      best_score := 0.0;

    for itry := 0 to Q3Iter - 1 do
    begin
      n_changed := 0;
      for i := 0 to n - 1 do
      begin
        xv := X[i];
        if xv <> xv then
          xv := 0.0;
        W := xv * xv;
        slx := sumlx - W * xv * L[i];
        if slx > 0.0 then
        begin
          sl2 := suml2 - W * L[i] * L[i];
          if sl2 > 0.0 then
          begin
            new_l := ClampInt(NearestInt(Single(xv * sl2 / slx)), -nmax, nmax - 1);
            if new_l <> L[i] then
            begin
              new_slx := slx + W * xv * new_l;
              new_sl2 := sl2 + W * new_l * new_l;
              new_score := (new_slx * new_slx) / new_sl2;
              if new_score > best_score then
              begin
                L[i] := new_l;
                sumlx := new_slx;
                suml2 := new_sl2;
                best_score := new_score;
                Inc(n_changed);
              end;
            end;
          end;
        end;
      end;
      if n_changed = 0 then
        Break;
    end;

    for i := 0 to n - 1 do
      L[i] := L[i] + nmax;

    Result := 0.0;
    if suml2 > 0.0 then
      Result := Single(sumlx / suml2);
  end
  else
  begin
    for i := 0 to n - 1 do
    begin
      l_val := NearestInt(iscale * X[i]);
      L[i] := ClampInt(l_val, -nmax, nmax - 1) + nmax;
    end;
    Result := 1.0 / iscale;
  end;
end;

function MakeQkx2aQuants(n, nmax: Integer; const X: PSingle; const weights: PSingle; L: PByte; out MinVal: Single;
  Laux: PByte; Rmin, Rdelta: Single; Nstep: Integer; UseMAD: Boolean = False; ForcePositiveMin: Boolean = True): Single;
var
  i, l_val, is_step: Integer;
  loVal, hiVal, Range, baseLoVal, bestLoVal, sum_w, sum_x, iscale, Scale, best_error, diff, ww: Single;
  sum_l, sum_l2, sum_xl, d, this_scale, this_min, cur_error: Single;
begin
  // 1. Bornes du sous-bloc
  loVal := X[0];
  hiVal := X[0];
  ww := weights[0];
  sum_w := ww;
  sum_x := sum_w * X[0];
  for i := 1 to n - 1 do
  begin
    ww := weights[i];
    if X[i] < loVal then
      loVal := X[i];
    if X[i] > hiVal then
      hiVal := X[i];
    sum_w := sum_w + ww;
    sum_x := sum_x + ww * X[i];
  end;

  if ForcePositiveMin and (loVal > 0.0) then
    loVal := 0.0;
  Range := hiVal - loVal;
  if (hiVal <= loVal) or (Range < GROUP_EPS) then
  begin
    FillChar(L^, n * SizeOf(Byte), 0);
    MinVal := -loVal;
    Exit(0.0);
  end;
  // 3. Échelle initiale & erreur de référence
  iscale := nmax / (Range);
  Scale := 1.0 / iscale;
  best_error := 0.0;
  for i := 0 to n - 1 do
  begin
    l_val := ClampInt(NearestInt(iscale * (X[i] - loVal)), 0, nmax);
    L[i] := Byte(l_val);
    diff := Scale * l_val + loVal - X[i];
    if UseMAD then
      diff := Abs(diff)
    else
      diff := diff * diff;
    ww := weights[i];
    best_error := best_error + ww * diff;
  end;

  if Nstep < 1 then
  begin
    MinVal := -loVal;
    Result := Scale;
    Exit();
  end;
  // 4. Recherche de grille (Rmin -> Rmin + Nstep*Rdelta)
  baseLoVal := loVal;
  bestLoVal := loVal;

  for is_step := 0 to Nstep -1 do
  begin
    iscale := (Rmin + Rdelta * is_step + nmax) / (hiVal - loVal); // après test ko
    // iscale := (Rmin + Rdelta * is_step + nmax) / (hiVal - baseLoVal); // après test ok
    if iscale <= 0.0 then
      Continue;

    sum_l := 0.0;
    sum_l2 := 0.0;
    sum_xl := 0.0;

    for i := 0 to n - 1 do
    begin
      l_val := ClampInt(NearestInt(iscale * (X[i] - loVal)), 0, nmax); // après test ok
      // l_val := ClampInt(NearestInt(iscale * (X[i] - baseLoVal)), 0, nmax);  // après test ko
      Laux[i] := Byte(l_val);
      ww := weights[i];
      sum_l := sum_l + ww * l_val;
      sum_l2 := sum_l2 + ww * l_val * l_val;
      sum_xl := sum_xl + ww * l_val * X[i];
    end;

    d := sum_w * sum_l2 - sum_l * sum_l;
    if d > EPS_SUM then
    begin
      this_scale := (sum_w * sum_xl - sum_x * sum_l) / d;
      this_min := (sum_l2 * sum_x - sum_l * sum_xl) / d;

      if ForcePositiveMin and (this_min > 0.0) then
      begin
        this_min := 0.0;
        this_scale := sum_xl / Max(sum_l2, EPS_SUM);
      end;

      cur_error := 0.0;
      for i := 0 to n - 1 do
      begin
        diff := this_scale * Laux[i] + this_min - X[i];
        if UseMAD then
          diff := Abs(diff)
        else
          diff := diff * diff;
        cur_error := cur_error + weights[i] * diff;
      end;

      if cur_error < best_error then
      begin
        Move(Laux[0], L[0], n);
        best_error := cur_error;
        Scale := this_scale;
        // loVal := this_min;
        bestLoVal := this_min;
      end;
    end;
    loVal := bestLoVal; // apres test : c'est correct ok
  end;
  MinVal := -bestLoVal;
  if ForcePositiveMin and (MinVal < 0.0) then
    MinVal := 0.0;
  Result := Scale;
end;

function MakeQkx2Quants(n, nmax: Integer; const X: PSingle; const weights: PSingle; L: PByte; out MinVal: Single;
  Laux: PByte; Rmin, Rdelta: Single; Nstep: Integer; UseMAD: Boolean = False; ForcePositiveMin: Boolean = True;
  AltPasses: Integer = 1): Single;

  function ErrOf(aScale, aMin: Single; const C: PByte): Single;
  var
    j: Integer;
    e: Single;
  begin
    Result := 0.0;
    for j := 0 to n - 1 do
    begin
      e := aScale * C[j] + aMin - X[j];
      if UseMAD then
        e := Abs(e)
      else
        e := e * e;
      Result := Result + weights[j] * e;
    end;
    if Result <> Result then
      Result := MaxSingle;
  end;

var
  i, l_val, is_step, pass: Integer;
  loVal, hiVal, Range, baseLoVal, bestLoVal, sum_w, sum_x, iscale, Scale, best_error, diff: Single;
  sum_l, sum_l2, sum_xl, det, this_scale, this_min, inv, s3, cur_error: Single;
  improved: Boolean;
begin
  loVal := X[0];
  hiVal := X[0];
  sum_w := weights[0];
  sum_x := sum_w * X[0];
  for i := 1 to n - 1 do
  begin
    if X[i] < loVal then
      loVal := X[i];
    if X[i] > hiVal then
      hiVal := X[i];
    sum_w := sum_w + weights[i];
    sum_x := sum_x + weights[i] * X[i];
  end;

  if ForcePositiveMin and (loVal > 0.0) then
    loVal := 0.0;
  Range := hiVal - loVal;
  if (Range < GROUP_EPS) or (sum_w <= 0.0) then
  begin
    FillChar(L^, n, 0);
    MinVal := -loVal;
    Exit(0.0);
  end;

  // erreur de reference
  iscale := nmax / Range;
  Scale := 1.0 / iscale;
  best_error := 0.0;
  for i := 0 to n - 1 do
  begin
    l_val := ClampInt(NearestInt(iscale * (X[i] - loVal)), 0, nmax); // C: roundf -> NearestInt
    L[i] := Byte(l_val);
    diff := Scale * l_val + loVal - X[i];
    if UseMAD then
      diff := Abs(diff)
    else
      diff := diff * diff;
    best_error := best_error + weights[i] * diff;
  end;

  // recherche de grille (comportement d'origine preserve si Nstep<1) ---
  if Nstep >= 1 then
  begin
    baseLoVal := loVal;
    bestLoVal := loVal;
    for is_step := 0 to Nstep do
    begin
      iscale := (Rmin + Rdelta * is_step + nmax) / (hiVal - baseLoVal);
      if iscale <= 0.0 then
        Continue;
      sum_l := 0.0;
      sum_l2 := 0.0;
      sum_xl := 0.0;
      for i := 0 to n - 1 do
      begin
        l_val := ClampInt(NearestInt(iscale * (X[i] - loVal)), 0, nmax);
        Laux[i] := Byte(l_val);
        sum_l := sum_l + weights[i] * l_val;
        sum_l2 := sum_l2 + weights[i] * l_val * l_val;
        sum_xl := sum_xl + weights[i] * l_val * X[i];
      end;
      det := sum_w * sum_l2 - sum_l * sum_l;
      if det > Max(EPS_SUM, 1E-12 * sum_w * sum_l2) then // seuil invariant d'echelle
      begin
        this_scale := (sum_w * sum_xl - sum_x * sum_l) / det;
        this_min := (sum_l2 * sum_x - sum_l * sum_xl) / det;
        if ForcePositiveMin and (this_min > 0.0) then
        begin
          this_min := 0.0;
          this_scale := sum_xl / Max(sum_l2, EPS_SUM);
        end;
        if this_scale > 0.0 then
        begin
          cur_error := ErrOf(this_scale, this_min, Laux);
          if cur_error < best_error then
          begin
            Move(Laux[0], L[0], n);
            best_error := cur_error;
            Scale := this_scale;
            bestLoVal := this_min;
          end;
        end;
      end;
      loVal := bestLoVal;
    end;
  end;

  // passes alternees code <-> LSQ : chaque mouvement est optimal a paramètres
  // fixes, et l'acceptation est stricte => l'erreur ne peut que baisser
  for pass := 1 to AltPasses do
  begin
    improved := False;

    // (a) codes optimaux pour (Scale, min) figes
    if Scale > GROUP_EPS then
    begin
      inv := 1.0 / Scale;
      for i := 0 to n - 1 do
        L[i] := Byte(ClampInt(NearestInt((X[i] - bestLoVal) * inv), 0, nmax));
      cur_error := ErrOf(Scale, bestLoVal, L);
      if cur_error < best_error then
      begin
        best_error := cur_error;
        improved := True;
      end;
    end;

    // sommes sur les codes courants
    sum_l := 0.0;
    sum_l2 := 0.0;
    sum_xl := 0.0;
    for i := 0 to n - 1 do
    begin
      l_val := L[i];
      sum_l := sum_l + weights[i] * l_val;
      sum_l2 := sum_l2 + weights[i] * l_val * l_val;
      sum_xl := sum_xl + weights[i] * l_val * X[i];
    end;

    // (b) refit conjoint (scale, min) a codes figes
    det := sum_w * sum_l2 - sum_l * sum_l;
    if det > Max(EPS_SUM, 1E-12 * sum_w * sum_l2) then
    begin
      this_scale := (sum_w * sum_xl - sum_x * sum_l) / det;
      this_min := (sum_l2 * sum_x - sum_l * sum_xl) / det;
      if ForcePositiveMin and (this_min > 0.0) then
      begin
        this_min := 0.0;
        this_scale := sum_xl / Max(sum_l2, EPS_SUM);
      end;
      if this_scale > 0.0 then
      begin
        cur_error := ErrOf(this_scale, this_min, L);
        if cur_error < best_error then
        begin
          Scale := this_scale;
          bestLoVal := this_min;
          best_error := cur_error;
          improved := True;
        end;
      end;
    end;

    // (c) refit d'echelle seule, min fige (utile quand min=0 est actif)
    if sum_l2 > EPS_SUM then
    begin
      s3 := (sum_xl - bestLoVal * sum_l) / sum_l2;
      if s3 > 0.0 then
      begin
        cur_error := ErrOf(s3, bestLoVal, L);
        if cur_error < best_error then
        begin
          Scale := s3;
          best_error := cur_error;
          improved := True;
         {$IFDEF DEBUG}
          if LogIsOn(lvTrace) then
            LogT('[QUANT] MakeQkx2 n=%d | scale=%.6f min=%.6f | err=%.6g | steps=%d passes=%d | MAD=%s',  //
              [n, Scale, bestLoVal, best_error, Nstep, pass, sStrBool(UseMAD)]);
         {$ENDIF}
        end;
      end;
    end;

    if not improved then
      Break;
  end;

  // (d) L coherent avec le couple (Result, MinVal) reellement renvoye
  if (AltPasses > 0) and (Scale > GROUP_EPS) then
  begin
    inv := 1.0 / Scale;
    for i := 0 to n - 1 do
      L[i] := Byte(ClampInt(NearestInt((X[i] - bestLoVal) * inv), 0, nmax));
  end;

  MinVal := -bestLoVal;
  if ForcePositiveMin and (MinVal < 0.0) then
    MinVal := 0.0;
  Result := Scale;
end;

function MakeQpQuants(n, nmax: Integer; const X, weights: PSingle; L: PByte; QpStep: Single = 0.1; QpSteps: Integer = 4;
  QpIter: Integer = 4; UseMAD: Boolean = False): Single;
var
  i, is_step, l_val, new_l, itry, n_changed: Integer;
  hiVal, iscale, Scale, iscale_is, scale_is: Single;
  sumlx, suml2, slx, sl2, new_slx, new_sl2, new_score, best_score: Single;
  ww, xv: Single;
begin
  if QpSteps <= 0 then
    QpSteps := 4;
  if QpStep <= 0 then
    QpStep := 0.1;
  if QpIter <= 0 then
    QpIter := 4;

  // 2. Recherche du maximum
  hiVal := 0.0;
  for i := 0 to n - 1 do
    if X[i] > hiVal then
      hiVal := X[i];

  if (hiVal <= 0.0) or (hiVal <> hiVal) then
  begin
    FillChar(L[0], n * SizeOf(Byte), 0);
    Exit(0.0);
  end;

  // 3. Quantification initiale & sommes pondérées
  iscale := nmax / hiVal;
  Scale := 1.0 / iscale;
  sumlx := 0.0;
  suml2 := 0.0;
  for i := 0 to n - 1 do
  begin
    l_val := NearestInt(iscale * X[i]);
    if l_val < 0 then
      l_val := 0;
    if l_val > nmax then
      l_val := nmax;

    L[i] := Byte(l_val);
    ww := weights[i];
    if (ww <> ww) or (ww < 0.0) or IsInfinite(ww) or IsNan(ww) then
      ww := 0.0;
    xv := X[i];
    if (xv <> xv) or IsInfinite(xv) or IsNan(xv) then
      xv := 0.0;
    sumlx := sumlx + ww * xv * l_val;
    suml2 := suml2 + ww * l_val * l_val;
  end;

  if suml2 > 0 then
    best_score := (sumlx * sumlx) / suml2
  else
    best_score := 0.0;

  // 4. Recherche de grille
  for is_step := -QpSteps to QpSteps do
  begin
    if is_step = 0 then
      Continue;
    iscale_is := (QpStep * is_step + nmax) / hiVal;
    scale_is := 1.0 / iscale_is;

    new_slx := 0.0;
    new_sl2 := 0.0;
    for i := 0 to n - 1 do
    begin
      l_val := ClampInt(NearestInt(iscale_is * X[i]), 0, nmax);
      ww := weights[i];
      if (ww <> ww) or (ww < 0.0) then
        ww := 0.0;
      xv := X[i];
      if xv <> xv then
        xv := 0.0;
      new_slx := new_slx + ww * xv * l_val;
      new_sl2 := new_sl2 + ww * l_val * l_val;
    end;

    if new_sl2 > 0.0 then
    begin
      new_score := (new_slx * new_slx) / new_sl2;
      if new_score > best_score then
      begin
        best_score := new_score;
        iscale := iscale_is;
        Scale := scale_is;
        for i := 0 to n - 1 do
          L[i] := Byte(ClampInt(NearestInt(iscale * X[i]), 0, nmax));
        sumlx := new_slx;
        suml2 := new_sl2;
      end;
    end;
  end;

  // 5. Descente de coordonnées
  for itry := 0 to QpIter do
  begin
    n_changed := 0;
    for i := 0 to n - 1 do
    begin
      ww := weights[i];
      xv := X[i];
      if xv <> xv then
        xv := 0.0;

      slx := sumlx - ww * xv * L[i];
      sl2 := suml2 - ww * L[i] * L[i];

      if (slx <= 1.0E-12) or (sl2 <= 1.0E-12) then
        Continue;
      new_l := NearestInt(Single(xv * sl2 / slx));
      if new_l < 0 then
        new_l := 0;
      if new_l > nmax then
        new_l := nmax;
      if new_l = L[i] then
        Continue;

      new_slx := slx + ww * xv * new_l;
      new_sl2 := sl2 + ww * new_l * new_l;
      if new_sl2 <= 1.0E-12 then
        Continue;
      new_score := (new_slx * new_slx) / new_sl2;

      if new_score > best_score then
      begin
        L[i] := Byte(new_l);
        sumlx := new_slx;
        suml2 := new_sl2;
        best_score := new_score;
        Inc(n_changed);
      end;
    end;
    if n_changed = 0 then
      Break;
  end;

  // 6. Échelle finale optimale
  Result := 0.0;
  if suml2 > 0.0 then
    Result := Single(sumlx / suml2);
end;

function MakeQpQuantsC(n, nmax: Integer; const X, quant_weights: PSingle; L: PByte): Single;
var
  i, iis, itry, ll, new_l, n_changed: Integer;
  cMax, iscale, iscale_is, Scale, scale_is, mse, best_mse, slx, sl2: Single;
  sumlx, suml2: Single;
begin
  cMax := 0.0;
  for i := 0 to n - 1 do
    if X[i] > cMax then
      cMax := X[i];
  if cMax < GROUP_EPS then
  begin
    for i := 0 to n - 1 do
      L[i] := 0;
    Exit(0.0);
  end;

  iscale := nmax / cMax;
  for i := 0 to n - 1 do
    L[i] := Byte(NearestInt(iscale * X[i])); // PAS de clamp
  Scale := 1.0 / iscale;
  best_mse := 0.0;
  for i := 0 to n - 1 do
    best_mse := best_mse + quant_weights[i] * Sqr(X[i] - Scale * L[i]);

  for iis := -4 to 4 do
  begin
    if iis = 0 then
      Continue;
    iscale_is := (0.1 * iis + nmax) / cMax;
    scale_is := 1.0 / iscale_is;
    mse := 0.0;
    for i := 0 to n - 1 do
    begin
      ll := MIN(nmax, NearestInt(iscale_is * X[i]));
      mse := mse + quant_weights[i] * Sqr(X[i] - scale_is * ll);
    end;
    if mse < best_mse then
    begin
      best_mse := mse;
      iscale := iscale_is;
    end;
  end;

  sumlx := 0.0;
  suml2 := 0.0;
  for i := 0 to n - 1 do
  begin
    ll := MIN(nmax, NearestInt(iscale * X[i]));
    L[i] := Byte(ll);
    sumlx := sumlx + quant_weights[i] * X[i] * ll;
    suml2 := suml2 + quant_weights[i] * ll * ll;
  end;
  for itry := 0 to 4 do
  begin
    n_changed := 0;
    for i := 0 to n - 1 do
    begin
      slx := sumlx - quant_weights[i] * X[i] * L[i];
      sl2 := suml2 - quant_weights[i] * L[i] * L[i];
      if (slx > 0.0) and (sl2 > 0.0) then
      begin
        new_l := MIN(nmax, NearestInt(X[i] * sl2 / slx));
        if new_l <> L[i] then
        begin
          slx := slx + quant_weights[i] * X[i] * new_l;
          sl2 := sl2 + quant_weights[i] * new_l * new_l;
          if (slx * slx * suml2 > sumlx * sumlx * sl2) then
          begin
            L[i] := Byte(new_l);
            sumlx := slx;
            suml2 := sl2;
            Inc(n_changed);
          end;
        end;
      end;
    end;
    if n_changed = 0 then
      Break;
  end;
  if suml2 > 0.0 then
    Result := sumlx / suml2
  else
    Result := 0.0;
end;

procedure RefineScaleMinCodes(var CodeS, CodeM: Byte; n, CodeMax, QMax, RadLs, RadLm: Integer;
  const X, weights: PSingle; L: PByte; dS, dM: Single);
var
  ii, kLs, kLm, bkLs, bkLm, s0, m0, cS, cM, lv: Integer;
  effS, effM, inv: Single;
  W, err, best, diff: Single;
begin
  s0 := CodeS;
  m0 := CodeM;
  best := MaxSingle;
  bkLs := 0;
  bkLm := 0;
  for kLm := -RadLm to RadLm do
  begin
    for kLs := -RadLs to RadLs do
    begin
      cS := s0 + kLs;
      cM := m0 + kLm;
      if (cS < 0) or (cS > CodeMax) or (cM < 0) or (cM > CodeMax) then
        Continue;

      effS := dS * cS;
      effM := dM * cM;
      err := 0.0;

      if Abs(effS) > GROUP_EPS then
      begin
        inv := 1.0 / effS;
        for ii := 0 to n - 1 do
        begin
          lv := ClampInt(NearestInt((X[ii] + effM) * inv), 0, QMax); // <-- QMax, pas CodeMax
          diff := effS * lv - effM - X[ii];
          W := weights[ii];
          if W > 0.0 then
            err := err + W * (diff * diff);
        end;
      end
      else
        for ii := 0 to n - 1 do
        begin
          diff := -effM - X[ii];
          W := weights[ii];
          if W > 0.0 then
            err := err + W * (diff * diff);
        end;

      if err < best then
      begin
        best := err;
        bkLs := kLs;
        bkLm := kLm;
        //if LogIsOn(lvTrace) then
        //  LogT('[QUANT] refineCodes (%d,%d)->(%d,%d) err %.6g | radius %d/%d', //
        //  [s0, m0, CodeS, CodeM, best, RadLs, RadLm]);
      end;
    end;
  end;
  // Application : codes + poids finaux, bornes de format respectees
  CodeS := Byte(ClampInt(s0 + bkLs, 0, CodeMax));
  CodeM := Byte(ClampInt(m0 + bkLm, 0, CodeMax));
  effS := dS * CodeS;
  effM := dM * CodeM;
  if Abs(effS) > GROUP_EPS then
  begin
    inv := 1.0 / effS;
    for ii := 0 to n - 1 do
      L[ii] := Byte(ClampInt(NearestInt((X[ii] + effM) * inv), 0, QMax));
  end
  else
    FillChar(L[0], n, 0);
end;

end.
