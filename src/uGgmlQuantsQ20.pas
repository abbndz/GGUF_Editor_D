unit uGgmlQuantsQ20;

{ ============================================================================
  Q1_0 / Q2_0

  * Ref  : portage fidele (comparable DLL-Ref).
  * Impl : MEME STRUCTURE (d fp16 par bloc, 1 bit / 2 bits, memes decodages),
           mais optimisation du seul degre de libre :
             Q1_0 : recherche de d (moyenne ponderee / mediane si MAD / grille
                    autour de la moyenne / amax), evaluation sur le d DECODE
                    (fp16) + balayage +-2 ulp fp16. Les signes restent
                    sign(x) : ils sont optimaux pour tout critere separable.
             Q2_0 : recherche du pas d sur la grille amax*(rmin+rdelta*k),
                    assignation plus-proche-voisin {-1,0,1,2), puis recalage
                    LS alterne d = Swxt / Swtt (nrefit iters), evaluation sur
                    le d decode + balayage +-2 ulp fp16.
           Le d du Ref est toujours dans la liste de candidats ->
           Impl <= Ref garanti (critere uniformes/poids selon RmseType).
  ============================================================================ }

interface

uses
  System.SysUtils, System.Classes, uGGMLTypes, uGGMLConstants, uGGMLQuantUtils,
  uMath, uLog, uAppConfig, uQuantPresetConfig;

{$B-} {$R-} {$POINTERMATH ON} {$J-} {$O+} {$ALIGN 8}

procedure DequantQ1_0(const Data: PByte; Dest: PSingle; n_row: Integer);

procedure QuantQ1_0_Ref(pSrc: PSingle; Dest: PByte; n_row: Integer);

procedure QuantQ1_0_Impl(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil; iQk: Integer = QP_PROF_IMPL1);

procedure QuantQ1_0_Impl1(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil; iQk: Integer = QP_PROF_IMPL1);

procedure QuantQ1_0_Impl2(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);

procedure QuantQ1_0_Impl3(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);

procedure QuantQ1_0_Impl4(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);

procedure QuantQ1_0_Impl5(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);

procedure DequantQ2_0(const Data: PByte; Dest: PSingle; n_row: Integer);

procedure QuantQ2_0_Ref(pSrc: PSingle; Dest: PByte; n_row: Integer);

procedure QuantQ2_0_Impl(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil; iQk: Integer = QP_PROF_IMPL1);

procedure QuantQ2_0_Impl1(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil; iQk: Integer = QP_PROF_IMPL1);

procedure QuantQ2_0_Impl2(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);

procedure QuantQ2_0_Impl3(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);

procedure QuantQ2_0_Impl4(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);

procedure QuantQ2_0_Impl5(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle = nil);

implementation

uses
  uGgmlQuantsFP16;

const
  Q10_EPS = 1e-8;
  Q20_EPS = 1e-8;
  Q20_BIG = 1e30;        // init bestE (evite toute dependance Math.MaxSingle)
  //Q20_LO = 1 / 16;         // echelle mini testee  : amax/16
  Q20_LO = 1 / 8;         // echelle mini testee  : amax/16
  Q20_Q = 1.25;         // PAS GEOMETRIQUE FIXE -> Grille(n)
 // Q20_Q = 1.25;         // PAS GEOMETRIQUE FIXE -> Grille(n) inclus dans Grille(n')
  Q20_TIE = 1e-6;         // tolérance : accepte +0.1% d'erreur pour réduire le BIAIS
  //Q20_TIE = 1e-3;         // tolérance : accepte +0.1% d'erreur pour réduire le BIAIS
  Q20_NSEED = 4;            // graines LS (multi-bassins : supprime la loterie nstep)
  //Q20_FIXSEEDS: array[0..7] of Single = (0.01, 0.05, 0.1, 0.25, 0.5, 0.75, 1, 1.5);  // graines si nstep = 0
  //Q20_FIXSEEDS: array[0..7] of Single = (0.125, 0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75);
  //Q20_FIXSEEDS: array[0..7] of Single = (0.75, 0.85, 0.90, 0.95, 1.0, 1.05, 1.15, 1.25);
  Q20_FIXSEEDS: array[0..7] of Single = (0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0);
  //Q20_FIXSEEDS: array[0..7] of Single = (0.133, 0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75);
  //Q20_FIXSEEDS: array [0..3] of Single = (0.5,1,1.5,2.0);  // graines si nstep = 0
  //Q20_FIXSEEDS: array [0..2] of Single = (0.5,1,2.0);  // graines si nstep = 0
  QP_ALLOW_NEG_D = True;       // False => uniquement d>0 (espace d'emission llama.cpp)

// ==================== helpers ponderation (mapping du dispatcher Quant) ======
// 0/1 -> 1.0 uniforme (des poids nuls rendraient les sommes de recalage
// degeneresces), 2 -> sqrt|x|, 3 -> |x|, 4 -> x*x ; * qWeights si fourni.

function QWeight(x: Single; rmseType: Integer): Single; inline;
begin
  case rmseType of
    2:
      Exit(Sqrt(Abs(x)));
    3:
      Exit(Abs(x));
    4:
      Exit(x * x);
  else
    Exit(1.0);
  end;
end;

// ============================ Q1_0 ==========================================

procedure DequantQ1_0(const Data: PByte; Dest: PSingle; n_row: Integer);
var
  nb, i, j: Integer;
  pBlock: PBlockQ1_0;
  pDest: PSingle;
  d, neg_d: Single;
  bit: Byte;
begin
  nb := n_row div QK1_0;
  pBlock := PBlockQ1_0(Data);
  pDest := Dest;
  for i := 0 to nb - 1 do
  begin
    d := FP16ToFP32(pBlock^.d);
    neg_d := -d;
    for j := 0 to QK1_0 - 1 do
    begin
      bit := (pBlock^.qs[j div 8] shr ((j mod 8))) and 1;
      if bit = 1 then
        pDest[j] := d
      else
        pDest[j] := neg_d;
    end;
    Inc(pBlock);
    Inc(pDest, QK1_0);
  end;
end;

procedure QuantQ1_0_Ref(pSrc: PSingle; Dest: PByte; n_row: Integer);
var
  nb, i, j: Integer;
  pBlock: PBlockQ1_0;
  sum_abs, d: Single;
begin
  nb := n_row div QK1_0;
  pBlock := PBlockQ1_0(Dest);
  for i := 0 to nb - 1 do
  begin
    sum_abs := 0.0;
    for j := 0 to QK1_0 - 1 do
      sum_abs := sum_abs + Abs(pSrc[j]);
    d := sum_abs / QK1_0;
    pBlock^.d := FP32ToFP16(d);
    FillChar(pBlock^.qs[0], QK1_0 div 8, 0);
    for j := 0 to QK1_0 - 1 do
      if pSrc[j] >= 0.0 then
        pBlock^.qs[j div 8] := pBlock^.qs[j div 8] or (1 shl (j mod 8));
    Inc(pSrc, QK1_0);
    Inc(pBlock);
  end;
end;

procedure QuantQ1_0_Internal(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle; rmseType: Integer; rmin, rdelta: Single; nstep: Integer; useMad: Boolean);
var
  nb, i, j, k: Integer;
  pB: PBlockQ1_0;
  pX: PSingle;
  qw: PSingle;
  w: array[0..QK1_0 - 1] of Single;
  tmp, aa: array[0..QK1_0 - 1] of Single; // |x| + copie pour la mediane
  sw, swa, amax, ax, dMean, dMed, dBest, eBest: Single;
  wrd: Word;

  // erreur decodée pour une echelle d (residus = |x| - d, signes figes)

  function Q10Err(a, w: PSingle; dDec: Single; useMad: Boolean): Single;
  var
    j: Integer;
    cc: Single;
    e: Single;
  begin
    e := 0;
    for j := 0 to QK1_0 - 1 do
    begin
      cc := a[j] - dDec;
      if useMad then
        e := e + w[j] * Abs(cc)
      else
        e := e + w[j] * (cc * cc);
    end;
    Result := e;
  end;

  function Q10BestOf(d, dBest, eBest: Single; a, w: PSingle; useMad: Boolean; var dOut, eOut: Single): Boolean; inline;
  var
    dDec: Single;
    e: Single;
  begin
    Result := False;
    if d < Q10_EPS then
      Exit;
    dDec := FP16ToFP32(FP32ToFP16(d)); // evaluation sur le d DECODE
    if dDec < Q10_EPS then
      Exit;
    e := Q10Err(a, w, dDec, useMad);
    if (e < eBest) then
    begin
      dOut := dDec;
      eOut := Single(e);
      Result := True;
    end;
  end;

  procedure Q10Sort(var A: array of Single; n: Integer); // insertion : n<=128
  var
    i, j: Integer;
    v: Single;
  begin
    for i := 1 to n - 1 do
    begin
      v := A[i];
      j := i - 1;
      while (j >= 0) and (A[j] > v) do
      begin
        A[j + 1] := A[j];
        Dec(j);
      end;
      A[j + 1] := v;
    end;
  end;

begin
  if nstep > 64 then
    nstep := 64;
  nb := n_row div QK1_0;
  for i := 0 to nb - 1 do
  begin
    pB := PBlockQ1_0(Dest + Int64(i) * SizeOf(TBlockQ1_0));
    pX := pSrc + Int64(i) * QK1_0;
    qw := nil;
    if qWeights <> nil then
      qw := qWeights + Int64(i) * QK1_0;

    amax := 0;
    sw := 0;
    swa := 0;
    for j := 0 to QK1_0 - 1 do
    begin
      ax := Abs(pX[j]);
      aa[j] := ax;
      if ax > amax then
        amax := ax;
      w[j] := QWeight(pX[j], rmseType);
      if qw <> nil then
        w[j] := w[j] * qw[j];
      sw := sw + w[j];
      swa := swa + w[j] * ax;
    end;

    if (amax < Q10_EPS) or (sw <= 0) then      // bloc nul : d = 0 -> decode 0
    begin
      pB^.d := 0;
      FillChar(pB^.qs[0], QK1_0 div 8, 0);
      Continue;
    end;

    dMean := swa / sw; // optimum LS (poids uniformes)
    dBest := dMean; // Ref == fp16(mean) : inclus ici
    eBest := Single(Q10Err(@aa[0], @w[0], FP16ToFP32(FP32ToFP16(dMean)), useMad));

      // mediane|x| : optimum du critere MAD (robuste outliers)
    if useMad then
    begin
      for j := 0 to QK1_0 - 1 do
        tmp[j] := aa[j]; // declarez: tmp: array[0..QK1_0-1] of Single;
      Q10Sort(tmp, QK1_0);
      if (QK1_0 and 1) = 0 then
        dMed := 0.5 * (tmp[QK1_0 div 2 - 1] + tmp[QK1_0 div 2])
      else
        dMed := tmp[QK1_0 div 2];
      Q10BestOf(dMed, dBest, eBest, @aa[0], @w[0], useMad, dBest, eBest);
    end;

      // amax : valeur "robuste" (bon pour WRel), toujours candidate
    Q10BestOf(amax, dBest, eBest, @aa[0], @w[0], useMad, dBest, eBest);

      // grille autour de l'optimum LS
    if (nstep > 0) and (rdelta > 0) then
      for k := 0 to nstep do
        Q10BestOf(dMean * (rmin + rdelta * k), dBest, eBest, @aa[0], @w[0], useMad, dBest, eBest);

      // balayage +-2 ulp fp16 autour du meilleur d
    wrd := FP32ToFP16(dBest);
    for j := -2 to 2 do
    begin
      if (j = 0) then
        Continue;
      if (Integer(wrd) + j <= 0) then
        Continue;
      Q10BestOf(FP16ToFP32(Word(wrd + j)), dBest, eBest, @aa[0], @w[0], useMad, dBest, eBest);
    end;

      // ecriture : d final + signes (figes, = optimum)
    pB^.d := FP32ToFP16(dBest);
    FillChar(pB^.qs[0], QK1_0 div 8, 0);
    for j := 0 to QK1_0 - 1 do
      if pX[j] >= 0.0 then
        pB^.qs[j div 8] := pB^.qs[j div 8] or (1 shl (j mod 8));
  end;
end;

procedure QuantQ1_0_Impl(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle; iQk: Integer);
var
  c: PQuantPreset;
begin
  c := cfg.ggmlReg.GetPPreset(GGML_TYPE_Q1_0, iQk);
  if c.Rmin < 0 then
    c.Rmin := 0.9;
  if c.Rdelta <= 0 then
    c.Rdelta := 0.05;
  if (c.Nstep < 0) or (c.Nstep > 64) then
    c.Nstep := 36;
  if (c.RmseType < 0) or (c.RmseType > 4) then
    c.RmseType := 1;

  LogMsg(Format('[Q1_0 Impl] prof=%d Rmin=%g Rdelta=%g Nstep=%d nrefit=%d rmse=%d mad=%d (n_row=%d)', [iQk, c.Rmin, c.Rdelta, c.Nstep, c.QpNStep, c.RmseType, Ord(c.UseMAD), n_row]));

  QuantQ1_0_Internal(pSrc, Dest, n_row, qWeights, c.RmseType, c.Rmin, c.Rdelta, c.Nstep, c.UseMAD);
end;

procedure QuantQ1_0_Impl1(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle; iQk: Integer);
begin

  QuantQ1_0_Impl(pSrc, Dest, n_row, qWeights, iQk);
end;

procedure QuantQ1_0_Impl2(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle);
begin
  QuantQ1_0_Impl(pSrc, Dest, n_row, qWeights, QP_PROF_IMPL2);
end;

procedure QuantQ1_0_Impl3(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle);
begin
  QuantQ1_0_Impl(pSrc, Dest, n_row, qWeights, QP_PROF_IMPL3);
end;

procedure QuantQ1_0_Impl4(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle);
begin
  QuantQ1_0_Impl(pSrc, Dest, n_row, qWeights, QP_PROF_IMPL4);
end;

procedure QuantQ1_0_Impl5(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle);
begin
  QuantQ1_0_Impl(pSrc, Dest, n_row, qWeights, QP_PROF_IMPL5);
end;


// ============================ Q2_0 ==========================================

procedure DequantQ2_0(const Data: PByte; Dest: PSingle; n_row: Integer);
var
  nb, i, j: Integer;
  pBlock: PBlockQ2_0;
  pDest: PSingle;
  d: Single;
  q: Byte;
begin
  nb := n_row div QK2_0;
  pBlock := PBlockQ2_0(Data);
  pDest := Dest;
  for i := 0 to nb - 1 do
  begin
    d := FP16ToFP32(pBlock^.d);
    for j := 0 to QK2_0 - 1 do
    begin
      q := (pBlock^.qs[j div 4] shr ((j mod 4) * 2)) and 3;
      pDest[j] := (q - 1) * d;
    end;
    Inc(pBlock);
    Inc(pDest, QK2_0);
  end;
end;

procedure QuantQ2_0_Ref(pSrc: PSingle; Dest: PByte; n_row: Integer);
var
  nb, i, j: Integer;
  pBlock: PBlockQ2_0;
  amax, d, id: Single;
  q: Integer;
begin
  nb := n_row div QK2_0;
  pBlock := PBlockQ2_0(Dest);
  for i := 0 to nb - 1 do
  begin
    amax := 0.0;
    for j := 0 to QK2_0 - 1 do
      if Abs(pSrc[j]) > amax then
        amax := Abs(pSrc[j]);
    d := amax;
    if d > 0.0 then
      id := 1.0 / d
    else
      id := 0.0;
    pBlock^.d := FP32ToFP16(d);
    FillChar(pBlock^.qs[0], QK2_0 div 4, 0);
    for j := 0 to QK2_0 - 1 do
    begin
      q := Round(pSrc[j] * id) + 1;
      if q < 0 then
        q := 0;
      if q > 3 then
        q := 3;
      pBlock^.qs[j div 4] := pBlock^.qs[j div 4] or (q shl ((j mod 4) * 2));
    end;
    Inc(pSrc, QK2_0);
    Inc(pBlock);
  end;
end;

// ---------------------------------------------------------------------------
// Q20Eval : echelle dDec DONNEE -> niveau t in {-1,0,1,2} le plus proche de
// chaque element, et erreur ponderee en Single (jamais de troncature Single :
// en rmse=4, E = Somme x^2*(x-t*d)^2 ~ 1e-9 et Single casse les comparaisons).
// dDec peut etre NEGATIF : u = x/d reste monotone, la regle est identique,
// les niveaux decodes sont simplement le miroir {+|d|,0,-|d|,-2|d|}.
//   sumWXT, sumWT2 : pour le recalage LS      d* = sumWXT / sumWT2
//   sumT           : pour le biais de Mean    contrib = sumX - d*sumT
// ---------------------------------------------------------------------------
function Q20Eval(pX, w: PSingle; dDec: Single; useMad: Boolean; tOut: PSmallInt; out sumWXT, sumWT2, sumT: Single): Single;
var
  j, t: Integer;
  inv, cc, u: Single;
  e: Single;
begin
  e := 0;
  sumWXT := 0;
  sumWT2 := 0;
  sumT := 0;

  if Abs(dDec) < Q20_EPS then
  begin                       // echelle nulle : tout decode a 0 -> t = 1 (niveau 0)
    for j := 0 to QK2_0 - 1 do
    begin
      tOut[j] := 1;
      cc := pX[j];
      if useMad then
        e := e + w[j] * Abs(cc)
      else
        e := e + w[j] * (cc * cc);
    end;
    Exit(e);
  end;

  inv := 1 / dDec;
  for j := 0 to QK2_0 - 1 do
  begin
    u := pX[j] * inv;                       // seuils proportionnels a d
    if u <= -0.5 then
      t := -1
    else if u >= 1.5 then
      t := 2
    else if u >= 0.5 then
      t := 1
    else
      t := 0;
    tOut[j] := t;

    cc := pX[j] - t * dDec;                 // residu reellement DECODE
    if useMad then
      e := e + w[j] * Abs(cc)
    else
      e := e + w[j] * (cc * cc);
    sumWXT := sumWXT + w[j] * pX[j] * t;
    sumWT2 := sumWT2 + w[j] * (t * t);
    sumT := sumT + t;
  end;
  Result := e;
end;

// QuantQ2_0_Internal
// nstep  : nombre de points de la grille geometrique amax*Q20_LO*Q20_Q^k
//          (pas FIXE : les grilles sont imbrirees -> balayage interpretable).
//          0 = pas de grille, utilise les 8 graines fixes.
// nrefit : iterations de recalage LS (0..4 ; au dela, gaspillage).
// useMad : critere Somme w*|residu| (MAE) sinon Somme w*residu^2.
// rmseType : mapping du dispatcher Quant() : 0/1 -> 1.0, 2 -> sqrt|x|, 3 -> |x|, 4 -> x*x.
// 4 phases, toutes evaluees par la MEME fonction, en Single :
//   P1 d = amax (+ miroir)         -> le Ref reste candidat : non-regression
//   P2 grille geometrique          -> selection de BASSIN (pas de resolution)
//   P3 LS alterne depuis le TOP-3 des graines -> optimum local de chaque bassin
//   P4 emission avec l'echelle finale
// A chaque candidate : magnitude ET miroir testes.
// Departage a erreur egale (+/- Q20_TIE) : biais |sumX - d*sumT| minimal,
procedure QuantQ2_0_Internal(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle; rmseType: Integer; nstep: Integer; nrefit: Integer; useMad: Boolean);
var
  nb, i, j, k, it, q, si, nRun, sgn: Integer;
  pB: PBlockQ2_0;
  pX: PSingle;
  qw: PSingle;
  w: array[0..QK2_0 - 1] of Single;
  tArr: array[0..QK2_0 - 1] of SmallInt;
  seed: array[0..Q20_NSEED - 1] of Single;       // graines de la phase P2
  runSeed: array[0..Q20_NSEED - 1] of Single;    // snapshot fige pour P3
  seedE: array[0..Q20_NSEED - 1] of Single;
  nSeed: Integer;
  Seeding: Boolean;                              // P3 ne doit plus empiler de graines
  amax, ax, sumX, d, dRefit, curD, dDec: Single;
  bestD: Single;
  bestW, mw: Word;
  s1, s2, sT: Single;
  bestE, bestBias, e, bias: Single;

  // empile la magnitude dans le top-N (tri croissant)
  procedure PushSeed(mag: Single; err: Single);
  var
    p, t: Integer;
  begin
    if not Seeding then
      Exit;
    if nSeed < Q20_NSEED then
      Inc(nSeed)
    else if err >= seedE[Q20_NSEED - 1] then
      Exit;
    p := nSeed - 1;
    while (p > 0) and (seedE[p - 1] > err) do
      Dec(p);
    for t := Min(nSeed, Q20_NSEED) - 1 downto p + 1 do
    begin
      seed[t] := seed[t - 1];
      seedE[t] := seedE[t - 1];
    end;
    seed[p] := mag;
    seedE[p] := err;
  end;

  // une candidate : magnitude magPos, avec et sans son miroir
  // Une seule conversion FP32->FP16, puis evaluation sur ce que le DECODEUR verra.
  procedure TrySigns(magPos: Single);
  var
    dd: Single;
    w16: Word;
    sgn, sMax: Integer;
  begin
    sMax := Ord(QP_ALLOW_NEG_D);
    for sgn := 0 to sMax do
    begin
      if sgn = 0 then
        dd := magPos
      else
        dd := -magPos;
      if Abs(dd) < Q20_EPS then
        Continue;
      w16 := FP32ToFP16(dd);
      dd := FP16ToFP32(w16);
      if Abs(dd) < Q20_EPS then
        Continue;        // 0 / sous-normal fp16 -> rejet

      e := Q20Eval(pX, @w[0], dd, useMad, @tArr[0], s1, s2, sT);
      bias := Abs(sumX - dd * sT);               // contribution locale au Mean

      if (e < bestE * (1 - Q20_TIE)) or ((e <= bestE * (1 + Q20_TIE)) and (bias < bestBias)) then
      begin
        bestE := e;
        bestBias := bias;
        bestW := w16;
        bestD := dd;
      end;
      if (abs(dd) > Q20_EPS) and (e < Q20_BIG) then
        PushSeed(dd, e);
    end;
  end;

begin
  if nstep < 0 then
    nstep := 0;
  if nstep > 31 then
    nstep := 31;              // > 64 : 0 gain, temps pur
  if nrefit < 0 then
    nrefit := 0;
  if nrefit > 4 then // 4
    nrefit := 4;

  nb := n_row div QK2_0;
  for i := 0 to nb - 1 do
  begin
    pB := PBlockQ2_0(Dest + Int64(i) * SizeOf(TBlockQ2_0));
    pX := pSrc + Int64(i) * QK2_0;
    qw := nil;
    if qWeights <> nil then
      qw := qWeights + Int64(i) * QK2_0;

    // P0 : amax, somme, poids (les poids ne dependent pas de d)
    amax := 0;
    sumX := 0;
    for j := 0 to QK2_0 - 1 do
    begin
      ax := Abs(pX[j]);
      if ax > amax then
        amax := ax;
      sumX := sumX + pX[j];
      w[j] := QWeight(pX[j], rmseType);
      if qw <> nil then
        w[j] := w[j] * qw[j];
    end;

    if amax < Q20_EPS then                        // bloc plat : tout a zero
    begin
      pB^.d := 0;
      FillChar(pB^.qs[0], QK2_0 div 4, 0);
      Continue;
    end;

    bestE := Q20_BIG;
    bestBias := Q20_BIG;
    bestW := 0;
    bestD := amax;
    nSeed := 0;
    Seeding := True;

    // P1 : l'echelle de la reference et son miroir (garde-fou)
    TrySigns(amax);

    // P2 : grille geometrique (selection de bassin)
    if nstep > 0 then
    begin
      d := amax * Q20_LO;
      for k := 1 to nstep do
      begin
        TrySigns(d);
        d := d * Q20_Q;                            // pas FIXE -> grilles imbrirees
      end;
    end
    else
      for k := 0 to High(Q20_FIXSEEDS) do          // 3 graines fixes : rien a regler
        TrySigns(amax * Q20_FIXSEEDS[k]);

    // snapshot : P3 ne doit pas muter le tableau de graines
    nRun := nSeed;
    if nRun < 1 then                               // securite (ne doit pas arriver)
    begin
      runSeed[0] := amax;
      nRun := 1;
    end
    else
      for si := 0 to nRun - 1 do
        runSeed[si] := seed[si];

    // P3 : LS alterne (codes <-> echelle) depuis CHAQUE graine
    // Le LS est mene en magnitude positive : avec d>0, t suit le signe de x,
    // donc sumWXT >= 0 et d* = sumWXT/sumWT2 reste positif. Les miroirs sont
    // couverts par TrySigns. curD est LOCAL a la graine (bestD n'est jamais
    // ecrase : TrySigns n'ecrit best* qu'en cas d'amelioration).
    Seeding := False;
    for si := 0 to nRun - 1 do
    begin
      curD := Abs(runSeed[si]);
      for it := 1 to nrefit do
      begin
        s1 := 0;
        s2 := 0;
        sT := 0;
        Q20Eval(pX, @w[0], curD, useMad, @tArr[0], s1, s2, sT);
        if s2 <= 0 then
          Break;                     // codes tous nuls : rien a refiter
        dRefit := s1 / s2;
        if Abs(dRefit) < Q20_EPS then
          Break;
        TrySigns(Abs(dRefit));
        // point fixe du LS : plus rien ne bouge -> graine suivante
        if Abs(dRefit - curD) <= curD * 0.001 then
          Break;
        curD := Abs(dRefit);
      end;
    end;

    // P4 : emission avec l'echelle FINALE (codes recalques)
    dDec := FP16ToFP32(bestW);
    Q20Eval(pX, @w[0], dDec, useMad, @tArr[0], s1, s2, sT);
    pB^.d := bestW;                                // peut etre negatif (fp16 signe)
    FillChar(pB^.qs[0], QK2_0 div 4, 0);
    for j := 0 to QK2_0 - 1 do
    begin
      q := tArr[j] + 1;                            // -1..2 -> 0..3
      pB^.qs[j div 4] := pB^.qs[j div 4] or ((q and 3) shl ((j mod 4) * 2));
    end;
  end;
end;

procedure QuantQ2_0_Impl(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle; iQk: Integer);
var
  c: TQuantPreset;
begin
  c := cfg.ggmlReg.GetPreset(GGML_TYPE_Q2_0, iQk);
//  LogMsg(Format('[Q2_0 Impl] prof=%d Rmin=%g Rdelta=%g Nstep=%d nrefit=%d rmse=%d mad=%d (n_row=%d)', [iQk, c.Rmin, c.Rdelta, c.Nstep, c.QpNStep, c.RmseType, Ord(c.UseMAD), n_row]));
  QuantQ2_0_Internal(pSrc, Dest, n_row, qWeights, c.RmseType, c.QpNStep, c.QcIter, c.UseMAD);
end;

procedure QuantQ2_0_Impl1(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle; iQk: Integer);
begin
  QuantQ2_0_Impl(pSrc, Dest, n_row, qWeights, iQk);
end;

procedure QuantQ2_0_Impl2(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle);
begin
  QuantQ2_0_Impl(pSrc, Dest, n_row, qWeights, QP_PROF_IMPL2);
end;

procedure QuantQ2_0_Impl3(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle);
begin
  QuantQ2_0_Impl(pSrc, Dest, n_row, qWeights, QP_PROF_IMPL3);
end;

procedure QuantQ2_0_Impl4(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle);
begin
  QuantQ2_0_Impl(pSrc, Dest, n_row, qWeights, QP_PROF_IMPL4);
end;

procedure QuantQ2_0_Impl5(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle);
begin
  QuantQ2_0_Impl(pSrc, Dest, n_row, qWeights, QP_PROF_IMPL5);
end;

end.

