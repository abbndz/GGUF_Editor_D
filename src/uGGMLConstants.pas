unit uGGMLConstants;

interface

uses
  SysUtils, Classes, Generics.Collections, Math;

{$POINTERMATH ON}

type
  PDouble = ^Double;

const
  // GROUP_EPS (zéros de scale), EPS_SUM (déterminants), EPS_SCALE (dénominateurs) :
  EPS_SCORE = 1E-15;
  EPS_SUM = 1E-15;
  EPS_SCALE = 1E-15;
  GROUP_EPS = 1E-15;
  GROUP_MAX_EPS_IQ2_S = 1E-8;
  GROUP_MAX_EPS_IQ2_XS = 1E-15; // C : GROUP_MAX_EPS
  GROUP_MAX_EPS_IQ2_XXS = 1E-15; // C : GROUP_MAX_EPS
  GROUP_MAX_EPS_IQ3_XXS = 1E-8;
  GROUP_MAX_EPS_IQ1_S = 1E-12; // C : GROUP_MAX_EPS_IQ1_S
  GROUP_MAX_EPS_IQ1_M = 1E-7; // C : GROUP_MAX_EPS_IQ1_M

  // Seuil en dessous duquel un bloc de poids est considéré comme vide/nul   #define GROUP_MAX_EPS 1e-15f

type
  EGGML = class(Exception); // Exception personnalisée pour erreurs de quantification GGML

  TGGMLShape = array of Int64; // Type générique pour stocker la dimension des tenseurs GGML

  // CONSTANTES D'IDENTIFIANTS GGML (Statiques)
const

  QK4_0 = 32;
  QK4_1 = 32;
  QK5_0 = 32;
  QK5_1 = 32;
  QK8_0 = 32;
  QK8_1 = 32;
  QK1_0 = 128; // Taille de bloc Q1_0
  QK2_0 = 64; // Taille de bloc Q2_0
  QK_K = 256;

  QK4_NL = 32;

  // MXFP4 (OCP MX : FP4 E2M1 + échelle E8M0 par bloc de 32)
  QK_MXFP4 = 32;

  // NVFP4 (FP4 E2M1 + 4 échelles UE4M3, sous-blocs de 16, super-bloc de 64)
  QK_NVFP4 = 64;
  QK_NVFP4_SUB = 16;

  // Dimensions de blocs
  // Q2_K
  Q2K_SUB = 16; // taille d’un sous-bloc Q2_K
  Q2K_NSUB = 16;
  Q2K_QMAX = 3; // q dans [0, 3]
  Q2K_SMAX = 15; // Ls/Lm dans [0, 15]
  Q2K_STORE = 0;
  Q2K_NMAXQ = 3; // max des POIDS 2 bits   (ce que clamp(round(...)) doit respecter)
  Q2K_SCALEMAX = 15; // max des CODES d'echelle 4 bits (différent de QMax !)

  // Q3_K
  Q3K_SUB = 16; // taille d’un sous-bloc Q3_K
  Q3K_NSUB = 16; // q dans [-4, 3]
  Q3K_QMAX = 3;
  Q3K_QOFFSET = 4; // stockage interne q + 4
  Q3K_SMAX = 63; // Ls dans [0, 63]
  Q3K_SMIN = 0;
  Q3K_SOFFSET = 32; // scale signé = Ls - 32
  Q3K_CODE_OFFSET = 32;
  Q3K_SCALE_CODE_MIN = 0;
  Q3K_SCALE_CODE_MAX = 63;
  Q3K_SCALE_CODE_ZERO = 32; // code - 32 = 0
  Q3K_QAMAX = 4; // |q| max, q in [-4, 3]
  Q3K_QMIN = -4;
  Q3K_LMAX = 7; // LLq in [0,7]
  Q3K_REQS_NITER = 2; // passes codes -> refit -> codes

  // Q4_K
  Q4K_SUB = 32; // taille d’un sous-bloc Q4_K
  Q4K_NSUB = 8;
  Q4K_NMAXQ = 15; // q dans [0, 15]
  Q4K_SCALEMAX = 63; // Ls/Lm dans [0, 63]
  Q4K_STORE = 0;
  // Q5_K
  Q5K_SUB = 32;
  Q5K_NSUB = 8;
  Q5K_NMAXQ = 31;
  Q5K_SCALEMAX = 63;
  Q5K_STORE = 0;
  // Q6_K
  Q6K_SUB = 16;
  Q6K_NSUB = 16;
  Q6K_QMIN = -32;
  Q6K_QMAX = 31;
  // Q6K_NMAXQ = 32;
  Q6K_SMIN = -128;
  Q6K_SMAX = 127;
  Q6K_STORE = 32;

  // Q4_1
  Q40_SUB = 32;
  Q40_QMAX = 7;
  Q40_SEMAX = 15;

  // Q4_1
  Q41_SUB = 32;
  Q41_NMAXQ = 15;

  // Q5_0
  Q50_SUB = 32;
  Q50_NMAXQ = 31;

const
  GGML_TYPE_F32 = 0;
  GGML_TYPE_F16 = 1;
  GGML_TYPE_Q4_0 = 2;
  GGML_TYPE_Q4_1 = 3;
  GGML_TYPE_Q4_2 = 4;
  GGML_TYPE_Q4_3 = 5;
  GGML_TYPE_Q5_0 = 6;
  GGML_TYPE_Q5_1 = 7;
  GGML_TYPE_Q8_0 = 8;
  GGML_TYPE_Q8_1 = 9;
  GGML_TYPE_Q2_K = 10;
  GGML_TYPE_Q3_K = 11;
  GGML_TYPE_Q4_K = 12;
  GGML_TYPE_Q5_K = 13;
  GGML_TYPE_Q6_K = 14;
  GGML_TYPE_Q8_K = 15;
  GGML_TYPE_IQ2_XXS = 16;
  GGML_TYPE_IQ2_XS = 17;
  GGML_TYPE_IQ3_XXS = 18;
  GGML_TYPE_IQ1_S = 19;
  GGML_TYPE_IQ4_NL = 20;
  GGML_TYPE_IQ3_S = 21;
  GGML_TYPE_IQ2_S = 22;
  GGML_TYPE_IQ4_XS = 23;
  GGML_TYPE_I8 = 24;
  GGML_TYPE_I16 = 25;
  GGML_TYPE_I32 = 26;
  GGML_TYPE_I64 = 27;
  GGML_TYPE_F64 = 28;
  GGML_TYPE_IQ1_M = 29;
  GGML_TYPE_BF16 = 30;
  GGML_TYPE_Q4_0_4_4 = 31;
  GGML_TYPE_Q4_0_4_8 = 32;
  GGML_TYPE_Q4_0_8_8 = 33;
  GGML_TYPE_TQ1_0 = 34;
  GGML_TYPE_TQ2_0 = 35;
  GGML_TYPE_IQ4_NL_4_4 = 36;
  GGML_TYPE_IQ4_NL_4_8 = 37;
  GGML_TYPE_IQ4_NL_8_8 = 38;
  GGML_TYPE_MXFP4 = 39;
  GGML_TYPE_NVFP4 = 40;
  GGML_TYPE_Q1_0 = 41;
  GGML_TYPE_Q2_0 = 42;
  GGML_TYPE_F8_E4M3 = 43;

const
  QP_PROF_NONE = -1;  // DLL-Ref (0) / Pas-Ref (1)
  QP_PROF_DLL0 = 0;   // Presets[0]  DLL-Impl0 (UseImpl 2)
  QP_PROF_IMPL1 = 1;   // Presets[1]  Pas-Impl1 (UseImpl 3)
  QP_PROF_IMPL2 = 2;   // Presets[2]  Pas-Impl2 (UseImpl 4)
  QP_PROF_IMPL3 = 3;   // Presets[3]  Pas-Impl3 (UseImpl 5)
  QP_PROF_IMPL4 = 4;   // Presets[4]  Pas-Impl3 (UseImpl 6)
  QP_PROF_IMPL5 = 5;   // Presets[5]  Pas-Impl3 (UseImpl 7)

  QP_USEIMPL_DLL_REF   = 0;
  QP_USEIMPL_PAS_REF   = 1;
  QP_USEIMPL_DLL_IMPL0 = 2;   // Profil 0 RmseType seulement
  QP_USEIMPL_PAS_IMPL1 = 3;   // Profil 1
  QP_USEIMPL_PAS_IMPL2 = 4;   // Profil 2
  QP_USEIMPL_PAS_IMPL3 = 5;   // Profil 3
  QP_USEIMPL_PAS_IMPL4 = 6;   // Profil 4
  QP_USEIMPL_PAS_IMPL5 = 7;   // Profil 5

  CQP_DEFAULT_RMSE = 2;   // Sqrt|x| par défaut pour types inconnus (ne dépend pas de cfg)

var
  GGML_TYPE_F8_E5M2, GGML_TYPE_F8_E4M3FN, GGML_TYPE_F8_E5M2FN: Integer;

const
  kvalues_mxfp4: array [0 .. 15] of Single = (0.0, 0.5, 1.0, 1.5, 2.0, 3.0, 4.0, 6.0, 0.0, -0.5, -1.0, -1.5, -2.0, -3.0,
    -4.0, -6.0);

  // GGML_TYPE_F8_E4M3 = 42;
  // GGML_TYPE_F8_E5M2 = 43;
const
  CDefaultGGMLTypeNames: array [0 .. 43] of string = ('F32', 'F16', 'Q4_0', 'Q4_1', 'Q4_2', 'Q4_3', 'Q5_0', 'Q5_1',
    'Q8_0', 'Q8_1', 'Q2_K', 'Q3_K', 'Q4_K', 'Q5_K', 'Q6_K', 'Q8_K', 'IQ2_XXS', 'IQ2_XS', 'IQ3_XXS', 'IQ1_S', 'IQ4_NL',
    'IQ3_S', 'IQ2_S', 'IQ4_XS', 'I8', 'I16', 'I32', 'I64', 'F64', 'IQ1_M', 'BF16', 'Q4_0_4_4', 'Q4_0_4_8', 'Q4_0_8_8',
    'TQ1_0', 'TQ2_0', 'IQ4_NL_4_4', 'IQ4_NL_4_8', 'IQ4_NL_8_8', 'MXFP4', 'NVFP4', 'Q1_0', 'Q2_0', 'F8_E4M3');

  GGMLTypePasImplExist: array [0 .. 43] of Boolean = (True { F32 } , True { F16 } , True { Q4_0 } , True { Q4_1 } ,
    False { Q4_2 } , False { Q4_3 } , True { Q5_0 } , True { Q5_1 } , True { Q8_0 } , False { Q8_1 } , True { Q2_K } ,
    True { Q3_K } , True { Q4_K } , True { Q5_K } , True { Q6_K } , True { Q8_K } , True { IQ2_XXS } , True { IQ2_XS } ,
    True { IQ3_XXS } , True { IQ1_S } , True { IQ4_NL } , True { IQ3_S } , True { IQ2_S } , True { IQ4_XS } ,
    False { I8 } , False { I16 } , False { I32 } , False { I64 } , False { F64 } , True { IQ1_M } , True { BF16 } ,
    False { Q4_0_4_4 } , False { Q4_0_4_8 } , False { Q4_0_8_8 } , False { TQ1_0 } , False { TQ2_0 } ,
    False { IQ4_NL_4_4 } , False { IQ4_NL_4_8 } , False { IQ4_NL_8_8 } , True { MXFP4 } , True { NVFP4 } ,
    True { Q1_0 } , True { Q2_0 } , True { F8_E4M3 }
    );

  CDefaultGGMLTypeIsQuant: array [0 .. 43] of Boolean = (False { F32 } , False { F16 } , True { Q4_0 } , True { Q4_1 } ,
    True { Q4_2 } , True { Q4_3 } , True { Q5_0 } , True { Q5_1 } , True { Q8_0 } , True { Q8_1 } , True { Q2_K } ,
    True { Q3_K } , True { Q4_K } , True { Q5_K } , True { Q6_K } , True { Q8_K } , True { IQ2_XXS } , True { IQ2_XS } ,
    True { IQ3_XXS } , True { IQ1_S } , True { IQ4_NL } , True { IQ3_S } , True { IQ2_S } , True { IQ4_XS } ,
    False { I8 } , False { I16 } , False { I32 } , False { I64 } , False { F64 } , True { IQ1_M } , False { BF16 } ,
    True { Q4_0_4_4 } , True { Q4_0_4_8 } , True { Q4_0_8_8 } , True { TQ1_0 } , True { TQ2_0 } , True { IQ4_NL_4_4 } ,
    True { IQ4_NL_4_8 } , True { IQ4_NL_8_8 } , True { MXFP4 } , True { NVFP4 } , True { Q1_0 } , True { Q2_0 }, False { F8_E4M3 }
    );

  CDefaultGGMLTypeBlockElems: array [0 .. 43] of Integer = (1 { F32 } , 1 { F16 } , 32 { Q4_0 } , 32 { Q4_1 } ,
    32 { Q4_2 } , 32 { Q4_3 } , 32 { Q5_0 } , 32 { Q5_1 } , 32 { Q8_0 } , 32 { Q8_1 } , 256 { Q2_K } , 256 { Q3_K } ,
    256 { Q4_K } , 256 { Q5_K } , 256 { Q6_K } , 256 { Q8_K } , 256 { IQ2_XXS } , 256 { IQ2_XS } , 256 { IQ3_XXS } ,
    256 { IQ1_S } , 32 { IQ4_NL } , 256 { IQ3_S } , 256 { IQ2_S } , 256 { IQ4_XS } , 1 { I8 } , 1 { I16 } , 1 { I32 } ,
    1 { I64 } , 1 { F64 } , 256 { IQ1_M } , 1 { BF16 } , 32 { Q4_0_4_4 } , 32 { Q4_0_4_8 } , 32 { Q4_0_8_8 } ,
    256 { TQ1_0 } , 256 { TQ2_0 } , 32 { IQ4_NL_4_4 } , 32 { IQ4_NL_4_8 } , 32 { IQ4_NL_8_8 } , 32 { MXFP4 } ,
    64 { NVFP4 } , 128 { Q1_0 } , 64 { Q2_0 }  , 1 { F8_E4M3 }
    );

  CDefaultGGMLTypeBlockBytes: array [0 .. 43] of Integer = (4 { F32 } , 2 { F16 } , 18 { Q4_0 } , 20 { Q4_1 } ,
    20 { Q4_2 } , 20 { Q4_3 } , 22 { Q5_0 } , 24 { Q5_1 } , 34 { Q8_0 } , 36 { Q8_1 } , 84 { Q2_K } , 110 { Q3_K } ,
    144 { Q4_K } , 176 { Q5_K } , 210 { Q6_K } , 292 { Q8_K } , 66 { IQ2_XXS } , 74 { IQ2_XS } , 98 { IQ3_XXS } ,
    50 { IQ1_S } , 18 { IQ4_NL } , 110 { IQ3_S } , 82 { IQ2_S } , 136 { IQ4_XS } , 1 { I8 } , 2 { I16 } , 4 { I32 } ,
    8 { I64 } , 8 { F64 } , 56 { IQ1_M } , 2 { BF16 } , 20 { Q4_0_4_4 } , 20 { Q4_0_4_8 } , 20 { Q4_0_8_8 } ,
    54 { TQ1_0 } , 66 { TQ2_0 } , 20 { IQ4_NL_4_4 } , 20 { IQ4_NL_4_8 } , 20 { IQ4_NL_8_8 } , 17 { MXFP4 } ,
    36 { NVFP4 } , 18 { Q1_0 } , 18 { Q2_0 }, 1 { F8_E4M3 }
    );

const
  CStrGGMLDLLName = 'ggml-base.dll';

  CDefaultGGMLTypeDLLFunDequant: array [0 .. 43] of string = ( //
    '', // 0: F32
    'ggml_fp16_to_fp32_row', // 1: F16
    'dequantize_row_q4_0', // 2: Q4_0
    'dequantize_row_q4_1', // 3: Q4_1
    '', // 4: Q4_2 (removed)
    '', // 5: Q4_3 (removed)
    'dequantize_row_q5_0', // 6: Q5_0
    'dequantize_row_q5_1', // 7: Q5_1
    'dequantize_row_q8_0', // 8: Q8_0
    'dequantize_row_q8_1', // 9: Q8_1
    'dequantize_row_q2_K', // 10: Q2_K
    'dequantize_row_q3_K', // 11: Q3_K
    'dequantize_row_q4_K', // 12: Q4_K
    'dequantize_row_q5_K', // 13: Q5_K
    'dequantize_row_q6_K', // 14: Q6_K
    'dequantize_row_q8_K', // 15: Q8_K
    'dequantize_row_iq2_xxs', // 16: IQ2_XXS
    'dequantize_row_iq2_xs', // 17: IQ2_XS
    'dequantize_row_iq3_xxs', // 18: IQ3_XXS
    'dequantize_row_iq1_s', // 19: IQ1_S
    'dequantize_row_iq4_nl', // 20: IQ4_NL
    'dequantize_row_iq3_s', // 21: IQ3_S
    'dequantize_row_iq2_s', // 22: IQ2_S
    'dequantize_row_iq4_xs', // 23: IQ4_XS
    '', // 24: I8
    '', // 25: I16
    '', // 26: I32
    '', // 27: I64
    '', // 28: F64
    'dequantize_row_iq1_m', // 29: IQ1_M
    'ggml_bf16_to_fp32_row', // 30: BF16
    '', // 31: Q4_0_4_4 (removed)
    '', // 32: Q4_0_4_8 (removed)
    '', // 33: Q4_0_8_8 (removed)
    'dequantize_row_tq1_0', // 34: TQ1_0
    'dequantize_row_tq2_0', // 35: TQ2_0
    '', // 36: IQ4_NL_4_4 (removed)
    '', // 37: IQ4_NL_4_8 (removed)
    '', // 38: IQ4_NL_8_8 (removed)
    'dequantize_row_mxfp4', // 39: MXFP4
    'dequantize_row_nvfp4', // 40: NVFP4
    'dequantize_row_q1_0', // 41: Q1_0
    'dequantize_row_q2_0', // 42: Q2_0
    'dequantize_row_f8_e4m3' // 43: f8_e4m3
    );

  CDefaultGGMLTypeDLLFunQuantImpl: array [0 .. 43] of string = ( //
    '', // 0: F32
    '', // 1: F16
    'quantize_q4_0', // 2: Q4_0
    'quantize_q4_1', // 3: Q4_1
    '', // 4: Q4_2
    '', // 5: Q4_3
    'quantize_q5_0', // 6: Q5_0
    'quantize_q5_1', // 7: Q5_1
    'quantize_q8_0', // 8: Q8_0
    'quantize_q8_1', // 9: Q8_1 ! Q8_1, pas de quantize_q8_1 optimisé exporté
    'quantize_q2_K', // 10: Q2_K
    'quantize_q3_K', // 11: Q3_K
    'quantize_q4_K', // 12: Q4_K
    'quantize_q5_K', // 13: Q5_K
    'quantize_q6_K', // 14: Q6_K
    'quantize_q8_K', // 15: Q8_K ! pas de quantize_q8_K optimisé exporté
    'quantize_iq2_xxs', // 16: IQ2_XXS
    'quantize_iq2_xs', // 17: IQ2_XS
    'quantize_iq3_xxs', // 18: IQ3_XXS
    'quantize_iq1_s', // 19: IQ1_S
    'quantize_iq4_nl', // 20: IQ4_NL
    'quantize_iq3_s', // 21: IQ3_S
    'quantize_iq2_s', // 22: IQ2_S
    'quantize_iq4_xs', // 23: IQ4_XS
    '', // 24: I8
    '', // 25: I16
    '', // 26: I32
    '', // 27: I64
    '', // 28: F64
    'quantize_iq1_m', // 29: IQ1_M
    'ggml_fp32_to_bf16_row', // 30: BF16
    '', // 31: Q4_0_4_4
    '', // 32: Q4_0_4_8
    '', // 33: Q4_0_8_8
    'quantize_tq1_0', // 34: TQ1_0
    'quantize_tq2_0', // 35: TQ2_0
    '', // 36: IQ4_NL_4_4
    '', // 37: IQ4_NL_4_8
    '', // 38: IQ4_NL_8_8
    'quantize_mxfp4', // 39: MXFP4
    'quantize_nvfp4', // 40: NVFP4
    'quantize_q1_0', // 41: Q1_0
    'quantize_q2_0', // 42: Q2_0
    'quantize_f8_e4m3' // 43: f8_e4m3
    );

  CDefaultGGMLTypeDLLFunQuantRef: array [0 .. 43] of string = ( //
    '', // 0: F32
    '', // 1: F16
    'quantize_row_q4_0_ref', // 2: Q4_0
    'quantize_row_q4_1_ref', // 3: Q4_1
    '', // 4: Q4_2
    '', // 5: Q4_3
    'quantize_row_q5_0_ref', // 6: Q5_0
    'quantize_row_q5_1_ref', // 7: Q5_1
    'quantize_row_q8_0_ref', // 8: Q8_0
    'quantize_row_q8_1_ref', // 9: Q8_1
    'quantize_row_q2_K_ref', // 10: Q2_K
    'quantize_row_q3_K_ref', // 11: Q3_K
    'quantize_row_q4_K_ref', // 12: Q4_K
    'quantize_row_q5_K_ref', // 13: Q5_K
    'quantize_row_q6_K_ref', // 14: Q6_K
    'quantize_row_q8_K_ref', // 15: Q8_K
    '', // 16: IQ2_XXS
    '', // 17: IQ2_XS
    'quantize_row_iq3_xxs_ref', // 18: IQ3_XXS
    '', // 19: IQ1_S
    'quantize_row_iq4_nl_ref', // 20: IQ4_NL
    'quantize_row_iq3_s_ref', // 21: IQ3_S
    'quantize_row_iq2_s_ref', // 22: IQ2_S
    'quantize_row_iq4_xs_ref', // 23: IQ4_XS
    '', // 24: I8
    '', // 25: I16
    '', // 26: I32
    '', // 27: I64
    '', // 28: F64
    '', // 29: IQ1_M
    'ggml_fp32_to_bf16_row', // 30: BF16
    '', // 31: Q4_0_4_4
    '', // 32: Q4_0_4_8
    '', // 33: Q4_0_8_8
    'quantize_row_tq1_0_ref', // 34: TQ1_0
    'quantize_row_tq2_0_ref', // 35: TQ2_0
    '', // 36: IQ4_NL_4_4
    '', // 37: IQ4_NL_4_8
    '', // 38: IQ4_NL_8_8
    'quantize_row_mxfp4_ref', // 39: MXFP4
    'quantize_row_nvfp4_ref', // 40: NVFP4
    'quantize_row_q1_0_ref', // 41: Q1_0
    'quantize_row_q2_0_ref', // 42: Q2_0
    'quantize_row_f8_e4m3_ref' // 43: f8_e4m3
    );

type
  // --- Types de base ---
  // Tggml_half = Word; // uint16_t
  // Tggml_half2 = Cardinal; // uint32_t

  // BLOCS STANDARD & SUPÉRIEURS (K-QUANTIZATION)
  // Q1_0
  TBlockQ1_0 = packed record
    d: Word; // ggml_half (delta)
    qs: array [0 .. 15] of Byte; // 16 * 8 = 128 bits / 1 = 128 w = 16 octets
  end;

  PBlockQ1_0 = ^TBlockQ1_0;

  TBlockQ2_0 = packed record
    d: Word; // ggml_half (delta)
    qs: array [0 .. 15] of Byte; // 16 * 8 = 128 bits / 2 = 64 w = 16 octets
  end;

  PBlockQ2_0 = ^TBlockQ2_0;

  // Structure GGML Q4_0 (packed pour éviter le padding)
  // Q4_0
  TBlockQ4_0 = packed record
    d: Word; // uint16_t;
    qs: array [0 .. 15] of Byte; // QK4_0 / 2 = 32 / 2 = 16 +2
  end;

  PBlockQ4_0 = ^TBlockQ4_0;

  // Q4_1 (Utilise une Union pour d et m)
  TBlockQ4_1 = packed record
    d: Word; // uint16_t;
    m: Word; // uint16_t;
    qs: array [0 .. 15] of Byte; // QK4_1 / 2 = 16
  end;

  PBlockQ4_1 = ^TBlockQ4_1;

  // Q5_0
  TBlockQ5_0 = packed record
    d: Word; // uint16_t; // delta
    qh: Cardinal; // 5-th bit of quants (uint32_t)
    // qh: array [0 .. 3] of Byte;
    qs: array [0 .. 15] of Byte;
  end;

  PBlockQ5_0 = ^TBlockQ5_0;

  // Q5_1
  TBlockQ5_1 = packed record
    d: Word; // fp16 scale
    m: Word; // fp16 min
    qh: Cardinal; // 5-th bit of quants (uint32_t)
    // qh: array [0 .. 3] of Byte;
    qs: array [0 .. 15] of Byte;
  end;

  PBlockQ5_1 = ^TBlockQ5_1;

  TBlockQ8_0 = packed record
    d: Word; // uint16_t; // fp16 scale
    qs: array [0 .. 31] of ShortInt; // int8_t
  end;

  PBlockQ8_0 = ^TBlockQ8_0;

  TBlockQ8_1 = packed record
    d, s: Word; // delta & sum(qs)
    qs: array [0 .. 31] of ShortInt; // 32 octets
  end;

  PBlockQ8_1 = ^TBlockQ8_1;

  // Ternary Quants

  TBlockTQ1_0 = packed record
    qs: array [0 .. 47] of Byte; // (256-16)/5 = 48 octets
    qh: array [0 .. 3] of Byte; // 256/64 = 4 octets
    d: Word; // delta
  end;

  PBlockTQ1_0 = ^TBlockTQ1_0;

  TBlockTQ2_0 = packed record
    qs: array [0 .. 63] of Byte; // 256/4 = 64 octets
    d: Word; // delta
  end;

  PBlockTQ2_0 = ^TBlockTQ2_0;

  // Super-blocks (K-Quantization)

  // Q2_K : ordre C = scales, qs, d, dmin
  TBlockQ2_K = packed record
    scales: array [0 .. 15] of Byte; // QK_K / 16 = 16 échelles + 16 mins (4-bits chacun)
    qs: array [0 .. 63] of Byte; // QK_K / 4 (2 bits = 1 weight, 4 weight = 1 byte ) = 64
    d: Word;
    dmin: Word;
  end;

  PBlockQ2_K = ^TBlockQ2_K;

  TBlockQ3_K = packed record
    hmask: array [0 .. 31] of Byte; // 32 octets
    qs: array [0 .. 63] of Byte; // 64 octets
    scales: array [0 .. 11] of Byte; // 12 octets
    d: Word; // fp16
  end;

  PBlockQ3_K = ^TBlockQ3_K;

  // Q4_K
  TBlockQ4_K = packed record
    d: Word; // uint16_t; // Échelle globale du super-bloc (FP16)
    dmin: Word; // uint16_t; // Minimum global du super-bloc (FP16)
    scales: array [0 .. 11] of Byte;
    // K_SCALE_SIZE = 12 // 12 octets contenant les 8 échelles et 8 mins (6-bits chacun)
    qs: array [0 .. 127] of Byte;
    // QK_K / 2 = 128 // 128 octets contenant les résidus de 4-bits (256 résidus 4-bits : 256 * 0.5 octet)
  end;

  PBlockQ4_K = ^TBlockQ4_K;

  // TBlockQ5_K - Super-block de quantisation Q5_K (256 éléments = 176 octets)
  // Layout : d(2) + dmin(2) + scales(12) + qh(32) + qs(128) = 176 octets
  TBlockQ5_K = packed record
    d: Word; // uint16_t; // 2 octets: échelle globale du super-bloc (FP16)
    dmin: Word; // uint16_t; // 2 octets: minimum global du super-bloc (FP16)
    scales: array [0 .. 11] of Byte; // 12 octets: 8 échelles + 8 mins (packés sur 6 bits)
    qh: array [0 .. 31] of Byte; // 32 octets: 5ème bit de chaque quantifié (1 bit par sous-bloc)
    qs: array [0 .. 127] of Byte; // 128 octets: 4 bits de poids faible des quantifiés (2 par octet)
  end;

  PBlockQ5_K = ^TBlockQ5_K;

  // Q6_K
  TBlockQ6_K = packed record
    ql: array [0 .. 127] of Byte; // QK_K / 2 = 128 (4 bits de poids faible)
    qh: array [0 .. 63] of Byte; // QK_K / 4 = 64  (2 bits de poids fort)
    scales: array [0 .. 15] of ShortInt; // QK_K / 16 = 16 (échelles locales signées 8-bit)
    d: Word; // uint16_t; // Échelle globale du super-bloc (FP16)
  end;

  PBlockQ6_K = ^TBlockQ6_K;

  // Q8_K
  TBlockQ8_K = packed record
    d: Single; // float d
    qs: array [0 .. 255] of ShortInt; // int8_t qs[QK_K]
    bsums: array [0 .. 15] of SmallInt; // int16_t bsums[QK_K/16]  = 292
  end;

  PBlockQ8_K = ^TBlockQ8_K;

  // BLOCS IQ (INTELLIGENCE QUANTIZATION)

  TBlockIQ2_XXS = packed record
    d: Word; // delta
    qs: array [0 .. 31] of Word; // 256/8 = 32 mots 16-bit
  end;

  PBlockIQ2_XXS = ^TBlockIQ2_XXS;

  TBlockIQ2_XS = packed record
    d: Word;
    qs: array [0 .. 31] of Word; // 32 mots  = 64 octets
    scales: array [0 .. 7] of Byte; // 256/32 = 8 octets = 74 octets
  end;

  PBlockIQ2_XS = ^TBlockIQ2_XS;

  TBlockIQ2_S = packed record
    d: Word; // Echelle globale (FP16)
    qs: array [0 .. 63] of Byte; // 64 octets: 32 octets de quants + 32 octets de signes
    qh: array [0 .. 7] of Byte; // 256/32 = 8 octets // 8 octets: bits de poids forts de la grille
    scales: array [0 .. 7] of Byte; // 8 octets = 82  octets    // 8 octets: sous-�chelles quantifi�es sur 4 bits
  end;

  PBlockIQ2_S = ^TBlockIQ2_S;

  TBlockIQ3_XXS = packed record
    d: Word;
    qs: array [0 .. 95] of Byte; // 3*256/8 = 96 octets
  end;

  PBlockIQ3_XXS = ^TBlockIQ3_XXS;

  TBlockIQ3_S = packed record
    d: Word;
    qs: array [0 .. 63] of Byte; // 64 octets
    qh: array [0 .. 7] of Byte; // 8 octets
    signs: array [0 .. 31] of Byte; // 32 octets
    scales: array [0 .. 3] of Byte; // 256/64 = 4 octets
  end;

  PBlockIQ3_S = ^TBlockIQ3_S;

  TBlockIQ1_S = packed record
    d: Word;
    qs: array [0 .. 31] of Byte; // 256/8 = 32 octets
    qh: array [0 .. 7] of Word; // 256/16 = 16 mots
  end;

  PBlockIQ1_S = ^TBlockIQ1_S;

  TBlockIQ1_M = packed record
    qs: array [0 .. 31] of Byte; // 32 octets
    qh: array [0 .. 15] of Byte; // 16 octets
    scales: array [0 .. 7] of Byte; // 8 octets
  end;

  PBlockIQ1_M = ^TBlockIQ1_M;

  // Non-linear & XS
  TBlockIQ4_NL = packed record
    d: Word;
    qs: array [0 .. 15] of Byte; // 32/2 = 16 octets
  end;

  PBlockIQ4_NL = ^TBlockIQ4_NL;

  TBlockIQ4_XS = packed record
    d: Word;
    scales_h: Word; // 16-bit high scales
    scales_l: array [0 .. 3] of Byte; // 256/64 = 4 octets
    qs: array [0 .. 127] of Byte; // 128 octets
  end;

  PBlockIQ4_XS = ^TBlockIQ4_XS;

  // FP4 Variants
  // MXFP4
  TBlockMXFP4 = packed record
    e: Byte; // E8M0 exponent
    qs: array [0 .. 15] of Byte; // 32/2 = 16 octets // QK_MXFP4 / 2 = 16
  end;

  PBlockMXFP4 = ^TBlockMXFP4;

  // NVFP4
  TBlockNVFP4 = packed record
    d: array [0 .. 3] of Byte; // UE4M3 scales (4 octets) // QK_NVFP4 / QK_NVFP4_SUB = 64 / 16 = 4
    qs: array [0 .. 31] of Byte; // 64/2 = 32 octets// QK_NVFP4 / 2 = 32
  end;

  PBlockNVFP4 = ^TBlockNVFP4;

type
  // CONSTANTES DE BLOC (Utilisées par la logique de calcul

  // TYPES DE DONNÉES UTILITAIRES
  TUInt16 = Word;
  TUInt32 = Cardinal;

type
  TQuantPreset = record
    //Name: string;
    Rmin, Rdelta: Single;
    Nstep: Integer;
    QpStep: Single;
    QpNStep: Integer;
    QcIter: Integer;
    RmseType: Integer;
    UseMAD: Boolean;

    RadiusLs: Integer; // 5 recommande (15 = +0.1% pour x2)  // 5/5 recommande (R>5 = mort)
    RadiusLm: Integer; // 5 recommande

    EnabledFields: set of (efRmin, efRdelta, efNstep, efQpStep, efQpSteps, efQcIter, efRmseType, efUseMAD, efRadiusLs,
      efRadiusLm);
  end;

  PQuantPreset = ^TQuantPreset;

const
  QUANT_PRESETS_INI = 'QuantPresets.ini';

  // Vérification binaire stricte
const
  _SZ_Q1_0 = SizeOf(TBlockQ1_0);
  _SZ_Q2_0 = SizeOf(TBlockQ2_0);
  _SZ_Q4_0 = SizeOf(TBlockQ4_0);
  _SZ_Q4_1 = SizeOf(TBlockQ4_1);
  _SZ_Q5_0 = SizeOf(TBlockQ5_0);
  _SZ_Q5_1 = SizeOf(TBlockQ5_1);
  _SZ_Q8_0 = SizeOf(TBlockQ8_0);
  _SZ_Q8_1 = SizeOf(TBlockQ8_1);
  _SZ_Q8_K = SizeOf(TBlockQ8_K); // 292
  _SZ_Q2_K = SizeOf(TBlockQ2_K); // 84
  _SZ_Q3_K = SizeOf(TBlockQ3_K); // 110
  _SZ_Q4_K = SizeOf(TBlockQ4_K); // 144
  _SZ_Q5_K = SizeOf(TBlockQ5_K); // 176
  _SZ_Q6_K = SizeOf(TBlockQ6_K); // 210
  _SZ_TQ1_0 = SizeOf(TBlockTQ1_0); // 54
  _SZ_TQ2_0 = SizeOf(TBlockTQ2_0); // 66
  _SZ_IQ2_XXS = SizeOf(TBlockIQ2_XXS); // 66
  _SZ_IQ2_XS = SizeOf(TBlockIQ2_XS); // 74
  _SZ_IQ2_S = SizeOf(TBlockIQ2_S); // 82
  _SZ_IQ3_XXS = SizeOf(TBlockIQ3_XXS); // 98
  _SZ_IQ3_S = SizeOf(TBlockIQ3_S); // 110
  _SZ_IQ1_S = SizeOf(TBlockIQ1_S); // 50
  _SZ_IQ1_M = SizeOf(TBlockIQ1_M); // 56
  _SZ_IQ4_NL = SizeOf(TBlockIQ4_NL); // 18
  _SZ_IQ4_XS = SizeOf(TBlockIQ4_XS); // 136
  _SZ_MXFP4 = SizeOf(TBlockMXFP4); // 17
  _SZ_NVFP4 = SizeOf(TBlockNVFP4); // 36

implementation

end.
