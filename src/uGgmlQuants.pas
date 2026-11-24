unit uGgmlQuants;

interface

uses
  SysUtils, Classes, System.Threading, uGGMLTypes,  System.Diagnostics,
  uGGMLConstants, uMath, uLog, uStrUtils;

{$B-}
{$R-}

{$POINTERMATH ON}
{$J-}
{$O+}
{$ALIGN 8}


type
  TPasQuantProc = procedure(pSrc: PSingle; Dest: PByte; n_row: Integer; qWeights: PSingle);

// index [type, 0..5] ; 0 = Ref (via petit wrapper), 1..5 = Impl1..5    todo
//const
//  QP_PAS: array [0 .. 42, 0 .. 5] of TPasQuantProc = (
//    { F32     } (nil, nil, nil, nil, nil, nil),
//    { F16     } (nil, nil, nil, nil, nil, nil),
//    { Q4_0    } (QuantQ4_0_RefW, QuantQ4_0_Impl1, QuantQ4_0_Impl2, QuantQ4_0_Impl3, QuantQ4_0_Impl4, QuantQ4_0_Impl5),
//    { Q4_1    } (...),
//    ...
//    { Q4_K    } (QuantQ4_K_RefW, QuantQ4_K_Impl1W, QuantQ4_K_Impl2, QuantQ4_K_Impl3, QuantQ4_K_Impl4, QuantQ4_K_Impl5),
//  );


// Formats entiers/floats standards
procedure DequantF16(const Data: PByte; Dest: PSingle; n_row: Int64);
procedure QuantF16(const src: PSingle; Dest: PByte; n_row: Int64);
procedure DequantBF16(const Data: PByte; Dest: PSingle; n_row: Int64);
procedure QuantBF16(const src: PSingle; Dest: PByte; n_row: Int64);

// ============================================================================
// DISPATCHERS GÉNÉRIQUES & UTILITAIRES
// ============================================================================
// Routeur de déquantisation : tente DLL → fallback Delphi → raise si inconnu
procedure DeQuant(const Data: PByte; Dest: PSingle; n_row: Int64; SrcType: Integer; UseDLL: Boolean = False);

// Routeur de quantisation : applique Ref ou Impl selon cfg.UseFImpl
procedure Quant(const src: PSingle; Dest: PByte; n_row: Int64;  DstType: Integer; UseImpl: Integer = 2; RmseType: Integer = 3);

// Convertisseur de tenseurs via espace intermédiaire F32
function ConvertTensorData(const SrcData: TBytes; SrcType, DstType: Integer; Rows, Cols: Int64; out DstData: TBytes;
  UseImpl: Integer = 2; RmseType: Integer = 3; OnProgress: TOnProgressEvent1 = nil): Boolean;

implementation

uses
  uAppConfig, uGGMLQuantUtils, uGgmlQuantsFP16, uGgmlQuantsFP8_E4M3,
  uGgmlQuantsQ20, uGgmlQuantsQ40, uGgmlQuantsQ50, uGgmlQuantsQ80, uGgmlQuantsQ2K,
  uGgmlQuantsQ3K, uGgmlQuantsQ4K, uGgmlQuantsQ5K, uGgmlQuantsQ6K, uGgmlQuantsQ8K,
  uGgmlQuantsIQ4nl, uGgmlQuantsIQ4_XS, uGgmlQuantsNVFP4, uGgmlQuantsMXFP4,
  uGgmlQuantsiq2_s, uGgmlQuantsiq3_s, uGgmlQuantsIQ2_XS, uGgmlQuantsIQ2_XXS,
  uGgmlQuantsIQ3_XXS, uGgmlQuantsiq1_S, uGgmlQuantsiq1_M, uGgmlQuantsIQGRIDs,
  uGgmlQuantsTQ2; //

procedure DequantF16(const Data: PByte; Dest: PSingle; n_row: Int64);
var
  i: Integer;
begin
  for i := 0 to n_row - 1 do
    Dest[i] := FP16ToFP32(PWord(Data + (i * 2))^);
end;

procedure QuantF16(const src: PSingle; Dest: PByte; n_row: Int64);
var
  i: Integer;
begin
  for i := 0 to n_row - 1 do
    PWord(Dest + (i * 2))^ := FP32ToFP16(src[i]);
end;

procedure DequantBF16(const Data: PByte; Dest: PSingle; n_row: Int64);
var
  i: Integer;
begin
  for i := 0 to n_row - 1 do
    Dest[i] := BF16ToFP32(PWord(Data + (i * 2))^);
end;

procedure QuantBF16(const src: PSingle; Dest: PByte; n_row: Int64);
var
  i: Integer;
begin
  for i := 0 to n_row - 1 do
    PWord(Dest + (i * 2))^ := FP32ToBF16(src[i]);
end;

procedure DeQuant(const Data: PByte; Dest: PSingle; n_row: Int64;  SrcType: Integer; UseDLL: Boolean = False);
var
  Proc: TDequantProc;
begin
  // if SrcType = GGML_TYPE_IQ4_XS then  UseDLL := True;
  // if SrcType = GGML_TYPE_Q8_K then  UseDLL := True;

  // 1. Tentative d'appel DLL optimisée (Si activée et type supporté)
  if UseDLL and (SrcType <> GGML_TYPE_F32) and (SrcType <> GGML_TYPE_F16) and (SrcType <> GGML_TYPE_BF16) and
    (SrcType < GGMLTypeCountDLL) then
  begin
    Proc := GetDequantProc(SrcType);
    if Assigned(Proc) then
    begin
      Proc(Data, Dest, n_row);
      Exit; // Succès, on sort prématurément
    end else
    begin
     // LogMsg('DLL non chargée -> fallback Delphi', lvWarn);
     if LogIsOn(lvWarn) then
     if LogOnce(FOnceDeq, 'DQ'+IntToStr(SrcType)) then
      LogW('DQ-NODLL: ' + IntToStr(SrcType) + Format(' [DEQUANT] no DLL routine for %s -> native Delphi path (slower)', [GGMLTypeToStr(SrcType)]), []);
    end;
  end;

  // 2. Fallback natif Delphi selon le type GGML
  case SrcType of
    GGML_TYPE_F32:
      Move(Data^, Dest^, n_row * SizeOf(Single));
    GGML_TYPE_F16:
      DequantF16(Data, Dest, n_row);
    GGML_TYPE_BF16:
      DequantBF16(Data, Dest, n_row);

    GGML_TYPE_Q1_0:
      DequantQ1_0(Data, Dest, n_row);
    GGML_TYPE_Q2_0:
      DequantQ2_0(Data, Dest, n_row);

    GGML_TYPE_Q4_0:
      DequantQ4_0(Data, Dest, n_row);
    GGML_TYPE_Q4_1:
      DequantQ4_1(Data, Dest, n_row);
    GGML_TYPE_Q5_0:
      DequantQ5_0(Data, Dest, n_row);
    GGML_TYPE_Q5_1:
      DequantQ5_1(Data, Dest, n_row);
    GGML_TYPE_Q8_0:
      DequantQ8_0(Data, Dest, n_row);
    GGML_TYPE_Q8_1:
      DequantQ8_1(Data, Dest, n_row);

    GGML_TYPE_Q2_K:
      DequantQ2_K(Data, Dest, n_row);
    GGML_TYPE_Q3_K:
      DequantQ3_K(Data, Dest, n_row);
    GGML_TYPE_Q4_K:
      DequantQ4_K(Data, Dest, n_row);
    GGML_TYPE_Q5_K:
      DequantQ5_K(Data, Dest, n_row);
    GGML_TYPE_Q6_K:
      DequantQ6_K(Data, Dest, n_row);
    GGML_TYPE_Q8_K:
      DequantQ8_K(Data, Dest, n_row);

    GGML_TYPE_IQ4_NL:
      DequantIQ4_NL(Data, Dest, n_row);

    GGML_TYPE_IQ4_XS:
      DequantIQ4_XS(Data, Dest, n_row);

    GGML_TYPE_MXFP4:
      DequantMXFP4(Data, Dest, n_row);
    GGML_TYPE_NVFP4:
      DequantNVFP4(Data, Dest, n_row);

    GGML_TYPE_TQ1_0:
      DequantTQ1_0(Data, Dest, n_row);

    GGML_TYPE_TQ2_0:
      DequantTQ2_0(Data, Dest, n_row);

    GGML_TYPE_IQ1_S:
      DequantIQ1_S(Data, Dest, n_row);

    GGML_TYPE_IQ1_M:
      DequantIQ1_M(Data, Dest, n_row);

    GGML_TYPE_IQ2_XS:
      DequantIQ2_XS(Data, Dest, n_row);

    GGML_TYPE_IQ2_XXS:
      DequantIQ2_XXS(Data, Dest, n_row);

    GGML_TYPE_IQ3_XXS:
      DequantIQ3_XXS(Data, Dest, n_row);

    GGML_TYPE_IQ2_S:
      DequantIQ2_S(Data, Dest, n_row);
    GGML_TYPE_IQ3_S:
      DequantIQ3_S(Data, Dest, n_row);

    GGML_TYPE_F8_E4M3:
      DequantFP8_E4M3(Data, Dest, n_row);

    GGML_TYPE_I8:
      DequantI8(Data, Dest, n_row);
    GGML_TYPE_I16:
      DequantI16(Data, Dest, n_row);
    GGML_TYPE_I32:
      DequantI32(Data, Dest, n_row);
    GGML_TYPE_I64:
      DequantI64(Data, Dest, n_row);
    GGML_TYPE_F64:
      DequantF64(Data, Dest, n_row);
  else
    // Types FP8 / futurs formats (NVFP4, etc.)
    if SrcType = GGML_TYPE_F8_E5M2 then
      DequantFP8_E5M2(Data, Dest, n_row)
    else if SrcType = GGML_TYPE_F8_E4M3FN then
      DequantFP8_E4M3(Data, Dest, n_row)
    else if SrcType = GGML_TYPE_F8_E5M2FN then
      DequantFP8_E5M2(Data, Dest, n_row)
    else
      raise Exception.CreateFmt('Déquantisation non disponible pour type : %d (%s)', [SrcType, GGMLTypeToStr(SrcType)]);
  end;
end;

// NULL n'est permis que la ou le C ne l'asserte pas
function DllAcceptsNullWeights(t: TGGMLType): Boolean;
begin
  Result := (t = GGML_TYPE_IQ1_M) or (t in [GGML_TYPE_Q4_0 .. GGML_TYPE_Q8_K]); // + Q4_0..a verifier
end;

procedure Quant(const src: PSingle; Dest: PByte; n_row: Int64;  DstType: Integer; UseImpl: Integer = 2; RmseType: Integer = 3);
var
  ProcRef: TQuantRefProc;
  ProcImpl: TQuantImplProc;
  weights: array of Single;
  l, UseFImpl: Integer;
  UseDLL: Boolean;
begin
  UseDLL := (UseImpl = 0) or (UseImpl = 2); // UseImpl < 2;
  UseFImpl := UseImpl - 2;
  if FfrmEditTensorsFormClose then
    exit;

  // if DstType = GGML_TYPE_IQ4_XS then  UseDLL := True;
  // if DstType = GGML_TYPE_IQ4_NL then UseDLL := True;
  // if DstType = GGML_TYPE_Q8_K then   UseDLL := True;


  // UseDLL := UseDLL or (not(DstType in [GGML_TYPE_Q4_0 .. GGML_TYPE_Q8_K]));
  // UseDLL := UseDLL or (not(DstType in [GGML_TYPE_Q4_0 .. GGML_TYPE_Q8_K]) and (DstType <> GGML_TYPE_IQ4_NL) and
  // (DstType <> GGML_TYPE_IQ4_XS) and (DstType <> GGML_TYPE_MXFP4) and (DstType <> GGML_TYPE_NVFP4) and
  // (DstType <> GGML_TYPE_Q1_0) and (DstType <> GGML_TYPE_Q2_0));

  if UseDLL and (DstType <> GGML_TYPE_F32) and (DstType <> GGML_TYPE_F16) and (DstType <> GGML_TYPE_BF16) and
    (DstType < GGMLTypeCountDLL) then
  begin
    ProcRef := GetQuantRefProc(DstType);
    ProcImpl := GetQuantImplProc(DstType);
    if ( Assigned(ProcRef) and (UseImpl = 0)) or ( Assigned(ProcImpl) and (UseImpl = 2)) then
    begin
      try
        if (Assigned(ProcRef) and (UseImpl = 0)) then
          ProcRef(src, Dest, n_row, 1)
        else
        begin
          if (RmseType = 0) and DllAcceptsNullWeights(DstType) then
            ProcImpl(src, Dest, 1, n_row, nil)
          else
          begin
            SetLength(weights, n_row);
          // case cfgQK.RmseType of
            case RmseType of
              0:
                for l := 0 to n_row - 1 do
                  weights[l] := 1.0; // uniforme NULL interdit
              1:
                for l := 0 to n_row - 1 do
                  weights[l] := 1.0;
              2:
                for l := 0 to n_row - 1 do
                  weights[l] := Sqrt(Abs(src[l]));
              3:
                for l := 0 to n_row - 1 do
                  weights[l] := Abs(src[l]);
              4:
                for l := 0 to n_row - 1 do
                  weights[l] := Sqr(src[l]);
            else
              for l := 0 to n_row - 1 do
                weights[l] := Abs(src[l]);
            end;
            ProcImpl(src, Dest, 1, n_row, @weights[0]);
          end;
        end;
        Exit;
      except
        on E: Exception do
        begin
          LogMsg('ERREUR DLL Quant: ' + E.Message);
          raise Exception.Create('ERREUR DLL Quant: ' + E.Message);
        end;
      end;
    end else begin
    if LogIsOn(lvWarn) then
    if LogOnce(FOnceDeq, 'Q'+IntToStr(DstType)) then
      LogW('Q-NODLL: ' + IntToStr(DstType) + Format('[QUANT] DLL path requested but no routine for %s -> Delphi implementation (bit-exactness vs llama.cpp not guaranteed)', [GGMLTypeToStr(DstType)]), []);
    end;
  end;

  // Fallback natif Delphi : choix entre Ref (déterministe) et Impl (RMSE)
  case DstType of
    GGML_TYPE_F32:
      Move(src^, Dest^, n_row * SizeOf(Single));
    GGML_TYPE_F16:
      QuantF16(src, Dest, n_row);
    GGML_TYPE_BF16:
      QuantBF16(src, Dest, n_row);

    GGML_TYPE_Q1_0:
      if UseFImpl = QP_PROF_IMPL1 then
        QuantQ1_0_Impl1(src, Dest, n_row)
      else if UseFImpl = QP_PROF_IMPL2 then
        QuantQ1_0_Impl2(src, Dest, n_row)
      else if UseFImpl = QP_PROF_IMPL3 then
        QuantQ1_0_Impl3(src, Dest, n_row)
      else if UseFImpl = QP_PROF_IMPL4 then
        QuantQ1_0_Impl4(src, Dest, n_row)
      else if UseFImpl = QP_PROF_IMPL5 then
        QuantQ1_0_Impl5(src, Dest, n_row)
      else
        QuantQ1_0_Ref(src, Dest, n_row);

    GGML_TYPE_Q2_0:
      if UseFImpl = QP_PROF_IMPL1 then
        QuantQ2_0_Impl1(src, Dest, n_row)
      else if UseFImpl = QP_PROF_IMPL2 then
        QuantQ2_0_Impl2(src, Dest, n_row)
      else if UseFImpl = QP_PROF_IMPL3 then
        QuantQ2_0_Impl3(src, Dest, n_row)
      else if UseFImpl = QP_PROF_IMPL4 then
        QuantQ2_0_Impl4(src, Dest, n_row)
      else if UseFImpl = QP_PROF_IMPL5 then
        QuantQ2_0_Impl5(src, Dest, n_row)
      else
        QuantQ2_0_Ref(src, Dest, n_row);

    GGML_TYPE_Q4_0:
      if UseFImpl = QP_PROF_IMPL1 then
        QuantQ4_0_Impl1(src, Dest, n_row)
      else if UseFImpl = QP_PROF_IMPL2 then
        QuantQ4_0_Impl2(src, Dest, n_row)
      else if UseFImpl = QP_PROF_IMPL3 then
        QuantQ4_0_Impl3(src, Dest, n_row)
      else if UseFImpl = QP_PROF_IMPL4 then
        QuantQ4_0_Impl4(src, Dest, n_row)
      else if UseFImpl = QP_PROF_IMPL5 then
        QuantQ4_0_Impl5(src, Dest, n_row)
      else
        QuantQ4_0_Ref(src, Dest, n_row);

    GGML_TYPE_Q4_1:
      if UseFImpl = QP_PROF_IMPL1 then
        QuantQ4_1_Impl1(src, Dest, n_row)
      else if UseFImpl = QP_PROF_IMPL2 then
        QuantQ4_1_Impl2(src, Dest, n_row)
      else if UseFImpl = QP_PROF_IMPL3 then
        QuantQ4_1_Impl3(src, Dest, n_row)
      else if UseFImpl = QP_PROF_IMPL4 then
        QuantQ4_1_Impl4(src, Dest, n_row)
      else if UseFImpl = QP_PROF_IMPL5 then
        QuantQ4_1_Impl5(src, Dest, n_row)
      else
        QuantQ4_1_Ref(src, Dest, n_row);

    GGML_TYPE_Q5_0:
      if UseFImpl = QP_PROF_IMPL1 then
        QuantQ5_0_Impl1(src, Dest, n_row)
      else if UseFImpl = QP_PROF_IMPL2 then
        QuantQ5_0_Impl2(src, Dest, n_row)
      else if UseFImpl = QP_PROF_IMPL3 then
        QuantQ5_0_Impl3(src, Dest, n_row)
      else if UseFImpl = QP_PROF_IMPL4 then
        QuantQ5_0_Impl4(src, Dest, n_row)
      else if UseFImpl = QP_PROF_IMPL5 then
        QuantQ5_0_Impl5(src, Dest, n_row)
      else
        QuantQ5_0_Ref(src, Dest, n_row);

    GGML_TYPE_Q5_1:
      if UseFImpl = QP_PROF_IMPL1 then
        QuantQ5_1_Impl1(src, Dest, n_row)
      else if UseFImpl = QP_PROF_IMPL2 then
        QuantQ5_1_Impl2(src, Dest, n_row)
      else if UseFImpl = QP_PROF_IMPL3 then
        QuantQ5_1_Impl3(src, Dest, n_row)
      else if UseFImpl = QP_PROF_IMPL4 then
        QuantQ5_1_Impl4(src, Dest, n_row)
      else if UseFImpl = QP_PROF_IMPL5 then
        QuantQ5_1_Impl5(src, Dest, n_row)
      else
        QuantQ5_1_Ref(src, Dest, n_row);

    GGML_TYPE_Q8_0:
      if UseFImpl = QP_PROF_IMPL1 then
        QuantQ8_0_Impl1(src, Dest, n_row)
      else if UseFImpl = QP_PROF_IMPL2 then
        QuantQ8_0_Impl2(src, Dest, n_row)
      else if UseFImpl = QP_PROF_IMPL3 then
        QuantQ8_0_Impl3(src, Dest, n_row)
      else if UseFImpl = QP_PROF_IMPL4 then
        QuantQ8_0_Impl4(src, Dest, n_row)
      else if UseFImpl = QP_PROF_IMPL5 then
        QuantQ8_0_Impl5(src, Dest, n_row)
      else
        QuantQ8_0_Ref(src, Dest, n_row);

    GGML_TYPE_Q2_K:
      if UseFImpl = QP_PROF_IMPL1 then
        QuantQ2_K_Impl1(src, Dest, n_row)
      else if UseFImpl = QP_PROF_IMPL2 then
        QuantQ2_K_Impl2(src, Dest, n_row)
      else if UseFImpl = QP_PROF_IMPL3 then
        QuantQ2_K_Impl3(src, Dest, n_row)
      else if UseFImpl = QP_PROF_IMPL4 then
        QuantQ2_K_Impl4(src, Dest, n_row)
      else if UseFImpl = QP_PROF_IMPL5 then
        QuantQ2_K_Impl5(src, Dest, n_row)
      else
        QuantQ2_K_Ref(src, Dest, n_row);

    GGML_TYPE_Q3_K:
      if UseFImpl = QP_PROF_IMPL1 then
        QuantQ3_K_Impl1(src, Dest, n_row)
      else if UseFImpl = QP_PROF_IMPL2 then
        QuantQ3_K_Impl2(src, Dest, n_row)
      else if UseFImpl = QP_PROF_IMPL3 then
        QuantQ3_K_Impl3(src, Dest, n_row)
      else if UseFImpl = QP_PROF_IMPL4 then
        QuantQ3_K_Impl4(src, Dest, n_row)
      else if UseFImpl = QP_PROF_IMPL5 then
        QuantQ3_K_Impl5(src, Dest, n_row)
      else
        QuantQ3_K_Ref(src, Dest, n_row);

    GGML_TYPE_Q4_K: // Ref, Impl, Fast, Impl1, Impl1
      if UseFImpl = QP_PROF_IMPL1 then
        QuantQ4_K_Impl1(src, Dest, n_row)
      else if UseFImpl = QP_PROF_IMPL2 then
        QuantQ4_K_Impl2(src, Dest, n_row)
      else if UseFImpl = QP_PROF_IMPL3 then
        QuantQ4_K_Impl3(src, Dest, n_row)
      else if UseFImpl = QP_PROF_IMPL4 then
        QuantQ4_K_Impl4(src, Dest, n_row)
      else if UseFImpl = QP_PROF_IMPL5 then
        QuantQ4_K_Impl5(src, Dest, n_row)
      else
        QuantQ4_K_Ref(src, Dest, n_row);

    GGML_TYPE_Q5_K:
      if UseFImpl = QP_PROF_IMPL1 then
        QuantQ5_K_Impl1(src, Dest, n_row)
      else if UseFImpl = QP_PROF_IMPL2 then
        QuantQ5_K_Impl2(src, Dest, n_row)
      else if UseFImpl = QP_PROF_IMPL3 then
        QuantQ5_K_Impl3(src, Dest, n_row)
      else if UseFImpl = QP_PROF_IMPL4 then
        QuantQ5_K_Impl4(src, Dest, n_row)
      else if UseFImpl = QP_PROF_IMPL5 then
        QuantQ5_K_Impl5(src, Dest, n_row)
      else
        QuantQ5_K_Ref(src, Dest, n_row);

    GGML_TYPE_Q6_K:
      if UseFImpl = QP_PROF_IMPL1 then
        QuantQ6_K_Impl1(src, Dest, n_row)
      else if UseFImpl = QP_PROF_IMPL2 then
        QuantQ6_K_Impl2(src, Dest, n_row)
      else if UseFImpl = QP_PROF_IMPL3 then
        QuantQ6_K_Impl3(src, Dest, n_row)
      else if UseFImpl = QP_PROF_IMPL4 then
        QuantQ6_K_Impl4(src, Dest, n_row)
      else if UseFImpl = QP_PROF_IMPL5 then
        QuantQ6_K_Impl5(src, Dest, n_row)
      else
        QuantQ6_K_Ref(src, Dest, n_row);

    GGML_TYPE_Q8_K:
      if UseFImpl = QP_PROF_IMPL1 then
        QuantQ8_K_Impl1(src, Dest, n_row)
      else if UseFImpl = QP_PROF_IMPL2 then
        QuantQ8_K_Impl2(src, Dest, n_row)
      else if UseFImpl = QP_PROF_IMPL3 then
        QuantQ8_K_Impl3(src, Dest, n_row)
      else if UseFImpl = QP_PROF_IMPL4 then
        QuantQ8_K_Impl4(src, Dest, n_row)
      else if UseFImpl = QP_PROF_IMPL5 then
        QuantQ8_K_Impl5(src, Dest, n_row)
      else
        QuantQ8_K_Ref(src, Dest, n_row);

    GGML_TYPE_IQ4_NL:
      if UseFImpl = QP_PROF_IMPL1 then
        QuantIQ4_NL_Impl1(src, Dest, n_row)
      else if UseFImpl = QP_PROF_IMPL2 then
        QuantIQ4_NL_Impl2(src, Dest, n_row)
      else if UseFImpl = QP_PROF_IMPL3 then
        QuantIQ4_NL_Impl3(src, Dest, n_row)
      else if UseFImpl = QP_PROF_IMPL4 then
        QuantIQ4_NL_Impl4(src, Dest, n_row)
      else if UseFImpl = QP_PROF_IMPL5 then
        QuantIQ4_NL_Impl5(src, Dest, n_row)
      else
        QuantIQ4_NL_Ref(src, Dest, n_row);

    GGML_TYPE_IQ4_XS:
      if UseFImpl = QP_PROF_IMPL1 then
        QuantIQ4_XS_Impl1(src, Dest, n_row)
      else if UseFImpl = QP_PROF_IMPL2 then
        QuantIQ4_XS_Impl2(src, Dest, n_row)
      else if UseFImpl = QP_PROF_IMPL3 then
        QuantIQ4_XS_Impl3(src, Dest, n_row)
      else if UseFImpl = QP_PROF_IMPL4 then
        QuantIQ4_XS_Impl4(src, Dest, n_row)
      else if UseFImpl = QP_PROF_IMPL5 then
        QuantIQ4_XS_Impl5(src, Dest, n_row)
      else
        QuantIQ4_XS_Ref(src, Dest, n_row);

    GGML_TYPE_MXFP4:
      if UseFImpl = QP_PROF_IMPL1 then
        QuantMXFP4_Impl1(src, Dest, n_row)
      else if UseFImpl = QP_PROF_IMPL2 then
        QuantMXFP4_Impl2(src, Dest, n_row)
      else if UseFImpl = QP_PROF_IMPL3 then
        QuantMXFP4_Impl3(src, Dest, n_row)
      else if UseFImpl = QP_PROF_IMPL4 then
        QuantMXFP4_Impl4(src, Dest, n_row)
      else if UseFImpl = QP_PROF_IMPL5 then
        QuantMXFP4_Impl5(src, Dest, n_row)
      else
        QuantMXFP4_Ref(src, Dest, n_row);
    GGML_TYPE_NVFP4:
      if UseFImpl = QP_PROF_IMPL1 then
        QuantNVFP4_Impl1(src, Dest, n_row)
      else if UseFImpl = QP_PROF_IMPL2 then
        QuantNVFP4_Impl2(src, Dest, n_row)
      else if UseFImpl = QP_PROF_IMPL3 then
        QuantNVFP4_Impl3(src, Dest, n_row)
      else if UseFImpl = QP_PROF_IMPL4 then
        QuantNVFP4_Impl4(src, Dest, n_row)
      else if UseFImpl = QP_PROF_IMPL5 then
        QuantNVFP4_Impl5(src, Dest, n_row)
      else
        QuantNVFP4_Ref(src, Dest, n_row);

    GGML_TYPE_TQ1_0:
      if UseFImpl = QP_PROF_IMPL1 then
        QuantTQ1_0_Impl1(src, Dest, n_row)
      else if UseFImpl = QP_PROF_IMPL2 then
        QuantTQ1_0_Impl2(src, Dest, n_row)
      else if UseFImpl = QP_PROF_IMPL3 then
        QuantTQ1_0_Impl3(src, Dest, n_row)
      else if UseFImpl = QP_PROF_IMPL4 then
        QuantTQ1_0_Impl4(src, Dest, n_row)
      else if UseFImpl = QP_PROF_IMPL5 then
        QuantTQ1_0_Impl5(src, Dest, n_row)
      else
        QuantTQ1_0_Ref(src, Dest, n_row);

    GGML_TYPE_TQ2_0:
      if UseFImpl = QP_PROF_IMPL1 then
        QuantTQ2_0_Impl1(src, Dest, n_row)
      else if UseFImpl = QP_PROF_IMPL2 then
        QuantTQ2_0_Impl2(src, Dest, n_row)
      else if UseFImpl = QP_PROF_IMPL3 then
        QuantTQ2_0_Impl3(src, Dest, n_row)
      else if UseFImpl = QP_PROF_IMPL4 then
        QuantTQ2_0_Impl4(src, Dest, n_row)
      else if UseFImpl = QP_PROF_IMPL5 then
        QuantTQ2_0_Impl5(src, Dest, n_row)
      else
        QuantTQ2_0_Ref(src, Dest, n_row);

    GGML_TYPE_IQ1_S:
      if UseFImpl = QP_PROF_IMPL1 then
        QuantIQ1_S_Impl1(src, Dest, n_row)
      else if UseFImpl = QP_PROF_IMPL2 then
        QuantIQ1_S_Impl2(src, Dest, n_row)
      else if UseFImpl = QP_PROF_IMPL3 then
        QuantIQ1_S_Impl3(src, Dest, n_row)
      else if UseFImpl = QP_PROF_IMPL4 then
        QuantIQ1_S_Impl4(src, Dest, n_row)
      else if UseFImpl = QP_PROF_IMPL5 then
        QuantIQ1_S_Impl5(src, Dest, n_row)
      else
        QuantIQ1_S_Ref(src, Dest, n_row);

    GGML_TYPE_IQ1_M:
      if UseFImpl = QP_PROF_IMPL1 then
        QuantIQ1_M_Impl1(src, Dest, n_row)
      else if UseFImpl = QP_PROF_IMPL2 then
        QuantIQ1_M_Impl2(src, Dest, n_row)
      else if UseFImpl = QP_PROF_IMPL3 then
        QuantIQ1_M_Impl3(src, Dest, n_row)
      else if UseFImpl = QP_PROF_IMPL4 then
        QuantIQ1_M_Impl4(src, Dest, n_row)
      else if UseFImpl = QP_PROF_IMPL5 then
        QuantIQ1_M_Impl5(src, Dest, n_row)
      else
        QuantIQ1_M_Ref(src, Dest, n_row);

    GGML_TYPE_IQ2_XS:
      if UseFImpl = QP_PROF_IMPL1 then
        QuantIQ2_XS_Impl1(src, Dest, n_row)
      else if UseFImpl = QP_PROF_IMPL2 then
        QuantIQ2_XS_Impl2(src, Dest, n_row)
      else if UseFImpl = QP_PROF_IMPL3 then
        QuantIQ2_XS_Impl3(src, Dest, n_row)
      else if UseFImpl = QP_PROF_IMPL4 then
        QuantIQ2_XS_Impl4(src, Dest, n_row)
      else if UseFImpl = QP_PROF_IMPL5 then
        QuantIQ2_XS_Impl5(src, Dest, n_row)
      else
        QuantIQ2_XS_Ref(src, Dest, n_row);

    GGML_TYPE_IQ2_XXS:
      if UseFImpl = QP_PROF_IMPL1 then
        QuantIQ2_XXS_Impl1(src, Dest, n_row)
      else if UseFImpl = QP_PROF_IMPL2 then
        QuantIQ2_XXS_Impl2(src, Dest, n_row)
      else if UseFImpl = QP_PROF_IMPL3 then
        QuantIQ2_XXS_Impl3(src, Dest, n_row)
      else if UseFImpl = QP_PROF_IMPL4 then
        QuantIQ2_XXS_Impl4(src, Dest, n_row)
      else if UseFImpl = QP_PROF_IMPL5 then
        QuantIQ2_XXS_Impl5(src, Dest, n_row)
      else
        QuantIQ2_XXS_Ref(src, Dest, n_row);

    GGML_TYPE_IQ3_XXS:
      if UseFImpl = QP_PROF_IMPL1 then
        QuantIQ3_XXS_Impl1(src, Dest, n_row)
      else if UseFImpl = QP_PROF_IMPL2 then
        QuantIQ3_XXS_Impl2(src, Dest, n_row)
      else if UseFImpl = QP_PROF_IMPL3 then
        QuantIQ3_XXS_Impl3(src, Dest, n_row)
      else if UseFImpl = QP_PROF_IMPL4 then
        QuantIQ3_XXS_Impl4(src, Dest, n_row)
      else if UseFImpl = QP_PROF_IMPL5 then
        QuantIQ3_XXS_Impl5(src, Dest, n_row)
      else
        QuantIQ3_XXS_Ref(src, Dest, n_row);

    GGML_TYPE_IQ2_S:
      if UseFImpl = QP_PROF_IMPL1 then
        QuantIQ2_S_Impl1(src, Dest, n_row)
      else if UseFImpl = QP_PROF_IMPL2 then
        QuantIQ2_S_Impl2(src, Dest, n_row)
      else if UseFImpl = QP_PROF_IMPL3 then
        QuantIQ2_S_Impl3(src, Dest, n_row)
      else if UseFImpl = QP_PROF_IMPL4 then
        QuantIQ2_S_Impl4(src, Dest, n_row)
      else if UseFImpl = QP_PROF_IMPL5 then
        QuantIQ2_S_Impl5(src, Dest, n_row)
      else
        QuantIQ2_S_Ref(src, Dest, n_row);

    GGML_TYPE_IQ3_S:
      if UseFImpl = QP_PROF_IMPL1 then
        QuantIQ3_S_Impl1(src, Dest, n_row)
      else if UseFImpl = QP_PROF_IMPL2 then
        QuantIQ3_S_Impl2(src, Dest, n_row)
      else if UseFImpl = QP_PROF_IMPL3 then
        QuantIQ3_S_Impl3(src, Dest, n_row)
      else if UseFImpl = QP_PROF_IMPL4 then
        QuantIQ3_S_Impl4(src, Dest, n_row)
      else if UseFImpl = QP_PROF_IMPL5 then
        QuantIQ3_S_Impl5(src, Dest, n_row)
      else
        QuantIQ3_S_Ref(src, Dest, n_row);

    GGML_TYPE_F8_E4M3:
      QuantFP8_E4M3(src, Dest, n_row);

    GGML_TYPE_I8:
      QuantI8(src, Dest, n_row);
    GGML_TYPE_I16:
      QuantI16(src, Dest, n_row);
    GGML_TYPE_I32:
      QuantI32(src, Dest, n_row);
    GGML_TYPE_I64:
      QuantI64(src, Dest, n_row);
    GGML_TYPE_F64:
      QuantF64(src, Dest, n_row);
  else
    if DstType = GGML_TYPE_F8_E5M2 then
      QuantFP8_E5M2(src, Dest, n_row)
    else if DstType = GGML_TYPE_F8_E4M3FN then
      QuantFP8_E4M3(src, Dest, n_row)
    else if DstType = GGML_TYPE_F8_E5M2FN then
      QuantFP8_E5M2(src, Dest, n_row)
    else
      raise Exception.CreateFmt('Quantisation non disponible pour type : %d (%s)', [DstType, GGMLTypeToStr(DstType)]);
  end;
end;

procedure InitIQPasGrid(DstType: Integer);
begin

  { GGML_TYPE_IQ2_XXS = 16;
    GGML_TYPE_IQ2_XS = 17;
    GGML_TYPE_IQ3_XXS = 18;
    GGML_TYPE_IQ1_S = 19;
    GGML_TYPE_IQ4_NL = 20;
    GGML_TYPE_IQ3_S = 21;
    GGML_TYPE_IQ2_S = 22; }
  case DstType of
    GGML_TYPE_IQ2_XXS:
      begin
        if not iq2xxs_initialized then
          InitIQ2XXSGrid;
      end;
    GGML_TYPE_IQ2_XS:
      begin
        if not iq2xs_initialized then
          InitIQ2XSGrid;
      end;
    GGML_TYPE_IQ3_XXS:
      begin
        if not iq3xxs_initialized then
          InitIQ3XXSGrid;
      end;
    GGML_TYPE_IQ1_S, GGML_TYPE_IQ1_M:
      begin
        if not iq1s_initialized then
          InitIQ1SGrid;
      end;
    GGML_TYPE_IQ3_S:
      begin
        if not iq3s_initialized then
          InitIQ3SGrid;
      end;
    GGML_TYPE_IQ2_S:
      begin
        if not iq2s_initialized then
          InitIQ2SGrid;
      end;
  end;
end;

function ConvertTensorData(const SrcData: TBytes; SrcType, DstType: Integer; Rows, Cols: Int64; out DstData: TBytes;
  UseImpl: Integer = 2; RmseType: Integer = 3; OnProgress: TOnProgressEvent1 = nil): Boolean;
var
  F32Buf: array of Single;
  ProcRef : TQuantRefProc;
  ProcImpl : TQuantImplProc;
  NumChunks,QK, BS, Blocks, BytesSize: Integer;
  ProcCount: Integer;
  UseDLL: Boolean;
  ActualChunkSize: Int64;
  pDstBase: PByte;
  SW: TStopwatch;
begin
  Result := False;
  SW := TStopwatch.StartNew;
  try
    if (Cols <= 0) or (Length(SrcData) = 0) then
      Exit;

    if (Rows <> 1) then
      raise Exception.CreateFmt('ConvertTensorData: Rows=%d non supporté (attend SrcData ligne à ligne)', [Rows]);

    UseDLL := (UseImpl = 0) or (UseImpl = 2);

    InitIQPasGrid(DstType);
    if UseDLL then
      ProcRef := GetQuantRefProc(DstType); // InitIQDllSGrid avant TParallel.For

    SetLength(F32Buf, Cols);
    // Déquantisation séquentielle (HORS du bloc parallèle)
    DeQuant(@SrcData[0], @F32Buf[0], Cols, SrcType, UseDLL);

    QK := GGML_BlockElems(DstType);
    BS := GGML_BlockBytes(DstType);
    if (QK <= 0) or (BS <= 0) then
      raise Exception.Create('ConvertTensorData: type destination inconnu');
    if Cols mod QK <> 0 then
      raise Exception.CreateFmt('ConvertTensorData: %s exige Cols multiple de %d (Cols=%d)', [GGMLTypeToStr(DstType), QK, Cols]);

    ActualChunkSize := QK_K * 8; // 8= 2048 , 16= 4096 (Cols div ProcCount);
    if ActualChunkSize mod QK <> 0 then
      ActualChunkSize := ((ActualChunkSize + QK - 1) div QK) * QK; // >= 2048, multiple de QK
    if ActualChunkSize > Cols then
      ActualChunkSize := Cols;
    NumChunks := (Cols + ActualChunkSize - 1) div ActualChunkSize;

    ProcCount := TThread.ProcessorCount;
    if ProcCount < 1 then
      ProcCount := 1;
    if NumChunks < 1 then
      NumChunks := 1;

    // Allocation du buffer de sortie (taille exacte pour Cols éléments)

    Blocks := (Cols + QK - 1) div QK;
    BytesSize := Blocks * BS;

    SetLength(DstData, BytesSize);
    pDstBase := @DstData[0];

    LogT('[CONV] %s->%s | cols=%d | QK=%d BS=%d | blocks=%d | out=%s | chunks=%d x %d elems | procs=%d', //
      [GGMLTypeToStr(SrcType), GGMLTypeToStr(DstType), Cols, QK, BS, Blocks, FormatBytes2f(BytesSize), //
      NumChunks, ActualChunkSize, ProcCount]);

    // pas de parallèle pour les petits buffers
    if (Cols < 8192) or (ProcCount = 1) then
    begin
      Quant(@F32Buf[0], pDstBase, Cols, DstType, UseImpl, RmseType);
      LogT('[CONV] sequential path (cols=%d < 8192 or single CPU)', [Cols]);
      Exit(True);
    end;

    // Quantisation parallèle par chunks
    // Chaque thread travaille sur une plage.
    // F32Buf est en READ-ONLY. DstData est écrit sur des offsets calculés à l'avance.
    TParallel.For(0, NumChunks - 1,
      procedure(chunkIdx: Integer)
      var
        Start, EndIdx, ChunkSize, NBlocks: Int64;
        StartBlock: Int64;
        DestPtr: PByte;
      begin
        // Calcul de la plage de colonnes pour ce thread
        Start := chunkIdx * ActualChunkSize;
        EndIdx := (chunkIdx + 1) * ActualChunkSize - 1;
        if EndIdx >= Cols then
          EndIdx := Cols - 1;
        if Start > EndIdx then
          Exit;
        ChunkSize := EndIdx - Start + 1;
        NBlocks := Start div QK;
        StartBlock := NBlocks * BS;
        // BaseOffset := GGML_RowSize(DstType, Start);
        DestPtr := PByte(NativeUInt(pDstBase) + StartBlock);
        Quant(@F32Buf[Start], DestPtr, Integer(ChunkSize), DstType, UseImpl, RmseType);
      end);

    // 6. Callback de progression
    if Assigned(OnProgress) then
      OnProgress('Traitement terminé', 1, 1);
    Result := True;
  except
    on E: Exception do
    begin
      Result := False;
      SetLength(DstData, 0);
      //LogMsg('ConvertTensorData ' + GGMLTypeToStr(SrcType) + '->' + GGMLTypeToStr(DstType) + ': ' + E.Message);
      LogE('[CONV] %s->%s cols=%d FAILED: %s', [GGMLTypeToStr(SrcType), GGMLTypeToStr(DstType), Cols, E.Message]);
      if Assigned(OnProgress) then
        OnProgress('Error: ' + E.Message, 0, 1);
      raise; // ou False + out EMsg
    end;
  end;
  LogT('[CONV] done in %s (%s)', [FormatDurationMs(SW.ElapsedMilliseconds), FormatPctF(BytesSize, Int64(Cols) * 4)]);
end;

end.
