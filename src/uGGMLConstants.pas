unit uGGMLConstants;

interface

uses
  SysUtils, Classes, Generics.Collections, Math;

{$POINTERMATH ON}

// CONSTANTES D'IDENTIFIANTS GGML (Statiques)
const
  QK4_0 = 32;
  QK4_1 = 32;
  QK5_0 = 32;
  QK5_1 = 32;
  QK8_0 = 32;
  QK8_1 = 32;
  QK_K = 256;

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

var
  GGML_TYPE_F8_E4M3, GGML_TYPE_F8_E5M2, GGML_TYPE_F8_E4M3FN, GGML_TYPE_F8_E5M2FN: Integer;

  // GGML_TYPE_F8_E4M3 = 42;
  // GGML_TYPE_F8_E5M2 = 43;
const
  CDefaultGGMLTypeNames: array [0 .. 41] of string = ('F32', 'F16', 'Q4_0', 'Q4_1', 'Q4_2', 'Q4_3', 'Q5_0', 'Q5_1',
    'Q8_0', 'Q8_1', 'Q2_K', 'Q3_K', 'Q4_K', 'Q5_K', 'Q6_K', 'Q8_K', 'IQ2_XXS', 'IQ2_XS', 'IQ3_XXS', 'IQ1_S', 'IQ4_NL',
    'IQ3_S', 'IQ2_S', 'IQ4_XS', 'I8', 'I16', 'I32', 'I64', 'F64', 'IQ1_M', 'BF16', 'Q4_0_4_4', 'Q4_0_4_8', 'Q4_0_8_8',
    'TQ1_0', 'TQ2_0', 'IQ4_NL_4_4', 'IQ4_NL_4_8', 'IQ4_NL_8_8', 'MXFP4', 'NVFP4', 'Q1_0');

  CDefaultGGMLTypeScalarSizes: array [0 .. 41] of Integer = (4 { F32 } , 2 { F16 } , 0 { Q4_0 } , 0 { Q4_1 } ,
    0 { Q4_2 } , 0 { Q4_3 } , 0 { Q5_0 } , 0 { Q5_1 } , 0 { Q8_0 } , 0 { Q8_1 } , 0 { Q2_K } , 0 { Q3_K } , 0 { Q4_K } ,
    0 { Q5_K } , 0 { Q6_K } , 0 { Q8_K } , 0 { IQ2_XXS } , 0 { IQ2_XS } , 0 { IQ3_XXS } , 0 { IQ1_S } , 0 { IQ4_NL } ,
    0 { IQ3_S } , 0 { IQ2_S } , 0 { IQ4_XS } , 1 { I8 } , 2 { I16 } , 4 { I32 } , 8 { I64 } , 8 { F64 } , 0 { IQ1_M } ,
    2 { BF16 } , 0 { Q4_0_4_4 } , 0 { Q4_0_4_8 } , 0 { Q4_0_8_8 } , 0 { TQ1_0 } , 0 { TQ2_0 } , 0 { IQ4_NL_4_4 } ,
    0 { IQ4_NL_4_8 } , 0 { IQ4_NL_8_8 } , 0 { MXFP4 } , 0 { NVFP4 } , 0 { Q1_0 }
    );

  CDefaultGGMLTypeIsQuant: array [0 .. 41] of Boolean = (False { F32 } , False { F16 } , True { Q4_0 } , True { Q4_1 } ,
    True { Q4_2 } , True { Q4_3 } , True { Q5_0 } , True { Q5_1 } , True { Q8_0 } , True { Q8_1 } , True { Q2_K } ,
    True { Q3_K } , True { Q4_K } , True { Q5_K } , True { Q6_K } , True { Q8_K } , True { IQ2_XXS } , True { IQ2_XS } ,
    True { IQ3_XXS } , True { IQ1_S } , True { IQ4_NL } , True { IQ3_S } , True { IQ2_S } , True { IQ4_XS } ,
    False { I8 } , False { I16 } , False { I32 } , False { I64 } , False { F64 } , True { IQ1_M } , False { BF16 } ,
    True { Q4_0_4_4 } , True { Q4_0_4_8 } , True { Q4_0_8_8 } , True { TQ1_0 } , True { TQ2_0 } , True { IQ4_NL_4_4 } ,
    True { IQ4_NL_4_8 } , True { IQ4_NL_8_8 } , True { MXFP4 } , True { NVFP4 } , True { Q1_0 }
    );

  CDefaultGGMLTypeBlockElems: array [0 .. 41] of Integer = (0 { F32 } , 0 { F16 } , 32 { Q4_0 } , 32 { Q4_1 } ,
    0 { Q4_2 } , 0 { Q4_3 } , 32 { Q5_0 } , 32 { Q5_1 } , 32 { Q8_0 } , 32 { Q8_1 } , 256 { Q2_K } , 256 { Q3_K } ,
    256 { Q4_K } , 256 { Q5_K } , 256 { Q6_K } , 256 { Q8_K } , 256 { IQ2_XXS } , 256 { IQ2_XS } , 256 { IQ3_XXS } ,
    256 { IQ1_S } , 32 { IQ4_NL } , 256 { IQ3_S } , 256 { IQ2_S } , 256 { IQ4_XS } , 0 { I8 } , 0 { I16 } , 0 { I32 } ,
    0 { I64 } , 0 { F64 } , 256 { IQ1_M } , 0 { BF16 } , 0 { Q4_0_4_4 } , 0 { Q4_0_4_8 } , 0 { Q4_0_8_8 } ,
    256 { TQ1_0 } , 256 { TQ2_0 } , 0 { IQ4_NL_4_4 } , 0 { IQ4_NL_4_8 } , 0 { IQ4_NL_8_8 } , 32 { MXFP4 } ,
    64 { NVFP4 } , 128 { Q1_0 }
    );

  CDefaultGGMLTypeBlockBytes: array [0 .. 41] of Integer = (0 { F32 } , 0 { F16 } , 18 { Q4_0 } , 20 { Q4_1 } ,
    0 { Q4_2 } , 0 { Q4_3 } , 22 { Q5_0 } , 24 { Q5_1 } , 34 { Q8_0 } , 36 { Q8_1 } , 84 { Q2_K } , 110 { Q3_K } ,
    144 { Q4_K } , 176 { Q5_K } , 210 { Q6_K } , 258 { Q8_K } , 66 { IQ2_XXS } , 74 { IQ2_XS } , 98 { IQ3_XXS } ,
    50 { IQ1_S } , 18 { IQ4_NL } , 110 { IQ3_S } , 72 { IQ2_S } , 136 { IQ4_XS } , 0 { I8 } , 0 { I16 } , 0 { I32 } ,
    0 { I64 } , 0 { F64 } , 56 { IQ1_M } , 0 { BF16 } , 0 { Q4_0_4_4 } , 0 { Q4_0_4_8 } , 0 { Q4_0_8_8 } ,
    54 { TQ1_0 } , 66 { TQ2_0 } , 0 { IQ4_NL_4_4 } , 0 { IQ4_NL_4_8 } , 0 { IQ4_NL_8_8 } , 17 { MXFP4 } , 36 { NVFP4 } ,
    18 { Q1_0 }
    );

const
  CStrGGMLDLLName = 'ggml-base.dll';

  CDefaultGGMLTypeDLLFunDequant: array [0 .. 41] of string = ( //
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
    'dequantize_row_q1_0' // 41: Q1_0
    );

  CDefaultGGMLTypeDLLFunQuant: array [0 .. 41] of string = ( //
    '', // 0: F32
    '', // 1: F16
    'quantize_q4_0', // 2: Q4_0
    'quantize_q4_1', // 3: Q4_1
    '', // 4: Q4_2
    '', // 5: Q4_3
    'quantize_q5_0', // 6: Q5_0
    'quantize_q5_1', // 7: Q5_1
    'quantize_q8_0', // 8: Q8_0
    '', // 'quantize_q8_1', // 9: Q8_1
    'quantize_q2_K', // 10: Q2_K
    'quantize_q3_K', // 11: Q3_K
    'quantize_q4_K', // 12: Q4_K
    'quantize_q5_K', // 13: Q5_K
    'quantize_q6_K', // 14: Q6_K
    '', // 'quantize_q8_K', // 15: Q8_K
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
    'quantize_q1_0' // 41: Q1_0
    );

type
  // --- Types de base ---
  //Tggml_half = Word; // uint16_t
  //Tggml_half2 = Cardinal; // uint32_t

  // Q1_0
  TBlockQ1_0 = packed record
    d: Word; // uint16_t;
    qs: array [0 .. 15] of Byte; // QK1_0 / 8 = 128 / 8 = 16
  end;

  PBlockQ1_0 = ^TBlockQ1_0;

  // Structure GGML Q4_0 (packed pour éviter le padding)
  // Q4_0
  TBlockQ4_0 = packed record
    d: Word; // uint16_t;
    qs: array [0 .. 15] of Byte; // QK4_0 / 2 = 32 / 2 = 16
  end;

  PBlockQ4_0 = ^TBlockQ4_0;

  // Q4_1 (Utilise une Union pour d et m)
  TBlockQ4_1 = packed record
    d: Word; // uint16_t;
    m: Word; // uint16_t;
    qs: array [0 .. 15] of Byte; // QK4_1 / 2 = 16
  end;

  PBlockQ4_1 = ^TBlockQ4_1;

  // MXFP4
  TBlockMXFP4 = packed record
    e: Byte;
    qs: array [0 .. 15] of Byte; // QK_MXFP4 / 2 = 16
  end;

  PBlockMXFP4 = ^TBlockMXFP4;

  // NVFP4
  TBlockNVFP4 = packed record
    d: array [0 .. 3] of Byte; // QK_NVFP4 / QK_NVFP4_SUB = 64 / 16 = 4
    qs: array [0 .. 31] of Byte; // QK_NVFP4 / 2 = 32
  end;

  PBlockNVFP4 = ^TBlockNVFP4;

  // Q5_0
  TBlockQ5_0 = packed record
    d: Word; // uint16_t; // delta
    qh: Cardinal; // 5-th bit of quants (uint32_t)
    qs: array [0 .. 15] of Byte; // nibbles
  end;

  PBlockQ5_0 = ^TBlockQ5_0;

  // Q5_1
  TBlockQ5_1 = packed record
    d: Word; // fp16 scale
    m: Word; // fp16 min
    qh: Cardinal; // 5-th bit of quants (uint32_t)
    qs: array [0 .. 15] of Byte; // nibbles
  end;

  PBlockQ5_1 = ^TBlockQ5_1;

  TBlockQ8_0 = packed record
    d: Word; // uint16_t; // fp16 scale
    qs: array [0 .. 31] of ShortInt; // int8_t
  end;

  PBlockQ8_0 = ^TBlockQ8_0;

  TBlockQ8_1 = packed record
    d: Word; // uint16_t;
    s: Word; // uint16_t;
    qs: array [0 .. 31] of ShortInt;
  end;

  PBlockQ8_1 = ^TBlockQ8_1;

  // Super-blocks (K-Quantization)

  // Q2_K
  TBlockQ2_K = packed record
    d: Word; // uint16_t;
    dmin: Word; // uint16_t;
    scales: array [0 .. 15] of Byte; // QK_K / 16 = 16
    qs: array [0 .. 63] of Byte; // QK_K / 4 = 64
  end;

  PBlockQ2_K = ^TBlockQ2_K;

  // Q3_K
  TBlockQ3_K = packed record
    scales: array [0 .. 11] of Byte; // 12 octets contenant 16 échelles sur 6-bits
    hmask: array [0 .. 31] of Byte; // QK_K / 8 = 32 (Bits de poids fort)
    qs: array [0 .. 63] of Byte; // QK_K / 4 = 64 (2 bits de poids faible)
    d: Word; // uint16_t; // Échelle globale du super-bloc (FP16)
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

  { ============================================================================
    TBlockQ5_K - Super-block de quantisation Q5_K (256 éléments = 176 octets)
    Layout : d(2) + dmin(2) + scales(12) + qh(32) + qs(128) = 176 octets
    ============================================================================ }
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
    qs: array [0 .. 255] of Byte; // int8_t qs[QK_K]
    bsums: array [0 .. 15] of Byte; // int16_t bsums[QK_K/16]
  end;

  PBlockQ8_K = ^TBlockQ8_K;

type
  // CONSTANTES DE BLOC (Utilisées par la logique de calcul

  // TYPES DE DONNÉES UTILITAIRES
  TUInt16 = Word;
  TUInt32 = Cardinal;


implementation




end.
