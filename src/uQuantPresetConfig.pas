unit uQuantPresetConfig;

interface

uses System.SysUtils, System.Classes, uGGMLConstants;

const
  // PROFIL DLL : aucun tuning, mémorise seulement le RmseType (poids passés à la DLL)
  CDefaultDLL_PRESET: TQuantPreset = (
    {Name: '';} Rmin: 0; Rdelta: 0; Nstep: 0; QpStep: 0; QpNStep: 0; QcIter: 0;
    RmseType: 2; UseMAD: False; RadiusLs: 0; RadiusLm: 0;
    EnabledFields: [efRmseType]);

  // PROFIL 0 : OFFICIEL LLAMA.CPP (Référence)
  // Q1_0 : 1 seul degre de libre (l'echelle) : grille + MAD + poids
  CDefaultQ1_0_PRESET1: TQuantPreset = ({Name: 'Q1_0';} Rmin: 0; Rdelta: 0; Nstep: 0;
    QpStep: 0; QpNStep: 3; QcIter: 0; RmseType: 1; UseMAD: False; RadiusLs: 0; RadiusLm: 0;
    EnabledFields: [efQpSteps, efQcIter, efRmseType, efUseMAD]);
  // Q2_0 : recherche de pas + recalage LS (QpNStep = iterations de recalage)
  //(Rmin = 0.55, Nstep = 60 → grille 0.55…2.35 × amax : le 1.0 est couvert,
  // et la zone utile d'un uniforme 4-niveaux est typiquement 0.6–0.9 × amax.)
  CDefaultQ2_0_PRESET1: TQuantPreset = ({Name: 'Q2_0';} Rmin: 0; Rdelta: 0; Nstep: 0;
    QpStep: 0; QpNStep: 15; QcIter: 3; RmseType: 2; UseMAD: False; RadiusLs: 0; RadiusLm: 0;
    EnabledFields: [efQpSteps, efQcIter, efRmseType, efUseMAD]);

  CDefaultQ4_0_PRESET1: TQuantPreset = ({Name: 'Q4_0';} Rmin: 0.0; Rdelta: 0.1; Nstep: 9; QpStep: 0; QpNStep: 0;
   QcIter: 0; RmseType: 1; UseMAD: False; EnabledFields: [efRdelta, efNstep, efRmseType, efUseMAD]);
  CDefaultQ4_0_PRESET2: TQuantPreset = ({Name: 'Q4_0';} Rmin: 0.0; Rdelta: 0.33; Nstep: 8; QpStep: 0; QpNStep: 0;
    QcIter: 0; RmseType: 2; UseMAD: False; EnabledFields: [efRdelta, efNstep, efRmseType, efUseMAD]);
  CDefaultQ4_0_PRESET3: TQuantPreset = ({Name: 'Q4_0';} Rmin: 0.0; Rdelta: 0.33; Nstep: 16; QpStep: 0; QpNStep: 0;
    QcIter: 0; RmseType: 2; UseMAD: False; EnabledFields: [efRdelta, efNstep, efRmseType, efUseMAD]);

  CDefaultQ5_0_PRESET1: TQuantPreset = ({Name: 'Q5_0';} Rmin: 0.0; Rdelta: 0.1; Nstep: 9; QpStep: 0; QpNStep: 0;
  QcIter: 0;  RmseType: 2; UseMAD: False; EnabledFields: [efRdelta, efNstep, efRmseType, efUseMAD]);
  CDefaultQ5_0_PRESET2: TQuantPreset = ({Name: 'Q5_0';} Rmin: 0.0; Rdelta: 0.2; Nstep: 16; QpStep: 0; QpNStep: 0;
    QcIter: 0; RmseType: 2; UseMAD: False; EnabledFields: [efRdelta, efNstep, efRmseType, efUseMAD]);
  CDefaultQ5_0_PRESET3: TQuantPreset = ({Name: 'Q5_0';} Rmin: 0.0; Rdelta: 0.2; Nstep: 24; QpStep: 0; QpNStep: 0;
    QcIter: 0; RmseType: 2; UseMAD: False; EnabledFields: [efRdelta, efNstep, efRmseType, efUseMAD]);

  CDefaultQ4_1_PRESET1: TQuantPreset = ({Name: 'Q4_1';} Rmin: 0.9; Rdelta: 0.05; Nstep: 36; QpStep: 0; QpNStep: 0;
    QcIter: 0; RmseType: 2; UseMAD: False; EnabledFields: [efRmin, efRdelta, efNstep, efRmseType, efUseMAD]);
  CDefaultQ4_1_PRESET2: TQuantPreset = ({Name: 'Q4_1';} Rmin: 1.9; Rdelta: 0.1; Nstep: 48; QpStep: 0; QpNStep: 0;
    QcIter: 0; RmseType: 2; UseMAD: False; EnabledFields: [efRmin, efRdelta, efNstep, efRmseType, efUseMAD]);
  CDefaultQ4_1_PRESET3: TQuantPreset = ({Name: 'Q4_1';} Rmin: 2.9; Rdelta: 0.1; Nstep: 56; QpStep: 0; QpNStep: 0;
    QcIter: 0; RmseType: 2; UseMAD: False; EnabledFields: [efRmin, efRdelta, efNstep, efRmseType, efUseMAD]);

  CDefaultQ5_1_PRESET1: TQuantPreset = ({Name: 'Q5_1';} Rmin: 0.9; Rdelta: 0.05; Nstep: 36; QpStep: 0; QpNStep: 0;
    QcIter: 0; RmseType: 2; UseMAD: False; EnabledFields: [efRmin, efRdelta, efNstep, efRmseType, efUseMAD]);
  CDefaultQ5_1_PRESET2: TQuantPreset = ({Name: 'Q5_1';} Rmin: 1.9; Rdelta: 0.1; Nstep: 48; QpStep: 0; QpNStep: 0;
    QcIter: 0; RmseType: 2; UseMAD: False; EnabledFields: [efRmin, efRdelta, efNstep, efRmseType, efUseMAD]);
  CDefaultQ5_1_PRESET3: TQuantPreset = ({Name: 'Q5_1';} Rmin: 2.9; Rdelta: 0.1; Nstep: 56; QpStep: 0; QpNStep: 0;
    QcIter: 0; RmseType: 2; UseMAD: False; EnabledFields: [efRmin, efRdelta, efNstep, efRmseType, efUseMAD]);

  CDefaultQ8_0_PRESET1: TQuantPreset = ({Name: 'Q8_0';} Rmin: 0; Rdelta: 0.1; Nstep: 9; QpStep: 0; QpNStep: 0;
  QcIter: 0;  RmseType: 3; UseMAD: False; EnabledFields: [efRdelta, efNstep, efRmseType, efUseMAD]);
  CDefaultQ8_0_PRESET2: TQuantPreset = ({Name: 'Q8_0';} Rmin: 0; Rdelta: 0.33; Nstep: 16; QpStep: 0; QpNStep: 0;
    QcIter: 0; RmseType: 3; UseMAD: False; EnabledFields: [efRdelta, efNstep, efRmseType, efUseMAD]);
  CDefaultQ8_0_PRESET3: TQuantPreset = ({Name: 'Q8_0';} Rmin: 0; Rdelta: 0.33; Nstep: 32; QpStep: 0; QpNStep: 0;
    QcIter: 0; RmseType: 3; UseMAD: False; EnabledFields: [efRdelta, efNstep, efRmseType, efUseMAD]);

  CDefaultQ8_1_PRESET1: TQuantPreset = ({Name: 'Q8_1';} Rmin: 0; Rdelta: 0; Nstep: 0; QpStep: 0; QpNStep: 0; QcIter: 0;
    RmseType: 0; UseMAD: False; EnabledFields: [efRmseType, efUseMAD]);
  CDefaultQ8_1_PRESET2: TQuantPreset = ({Name: 'Q8_1';} Rmin: 0; Rdelta: 0; Nstep: 0; QpStep: 0; QpNStep: 0; QcIter: 0;
    RmseType: 2; UseMAD: False; EnabledFields: [efRmseType, efUseMAD]);
  CDefaultQ8_1_PRESET3: TQuantPreset = ({Name: 'Q8_1';} Rmin: 0; Rdelta: 0; Nstep: 0; QpStep: 0; QpNStep: 0; QcIter: 0;
    RmseType: 2; UseMAD: False; EnabledFields: [efRmseType, efUseMAD]);

  CDefaultQ2_K_PRESET1: TQuantPreset = ({Name: 'Q2_K';} Rmin: 0.9; Rdelta: 0.05; Nstep: 36; QpStep: 0.1; QpNStep: 4;
    QcIter: 4; RmseType: 1; UseMAD: False; RadiusLs: 0; RadiusLm: 0;
    EnabledFields: [efRmin, efRdelta, efNstep, efQpStep, efQpSteps, efQcIter, efRmseType, efUseMAD, efRadiusLs, efRadiusLm]);
  CDefaultQ2_K_PRESET2: TQuantPreset = ({Name: 'Q2_K';} Rmin: 0.6; Rdelta: 0.1; Nstep: 42; QpStep: 0.33; QpNStep: 8;
    QcIter: 4; RmseType: 1; UseMAD: False; RadiusLs: 3; RadiusLm: 5;
    EnabledFields: [efRmin, efRdelta, efNstep, efQpStep, efQpSteps, efQcIter, efRmseType, efUseMAD, efRadiusLs, efRadiusLm]);
  CDefaultQ2_K_PRESET3: TQuantPreset = ({Name: 'Q2_K';} Rmin: 0.6; Rdelta: 0.1; Nstep: 56; QpStep: 0.33; QpNStep: 8;
    QcIter: 4; RmseType: 1; UseMAD: False; RadiusLs: 5; RadiusLm: 7;
    EnabledFields: [efRmin, efRdelta, efNstep, efQpStep, efQpSteps, efQcIter, efRmseType, efUseMAD, efRadiusLs, efRadiusLm]);

  CDefaultQ3_K_PRESET1: TQuantPreset = ({Name: 'Q3_K';} Rmin: 0.0; Rdelta: 0.1; Nstep: 9; QpStep: 0.1; QpNStep: 9;
    QcIter: 0; RmseType: 1; UseMAD: False; EnabledFields: [efRdelta, efNstep, efQpStep, efQpSteps, efRmseType,
      efUseMAD]);
  CDefaultQ3_K_PRESET2: TQuantPreset = ({Name: 'Q3_K';} Rmin: 0.0; Rdelta: 0.1; Nstep: 5; QpStep: 0.05; QpNStep: 16;
    QcIter: 0; RmseType: 1; UseMAD: False; EnabledFields: [efRdelta, efNstep, efQpStep, efQpSteps, efRmseType,
      efUseMAD]);
  CDefaultQ3_K_PRESET3: TQuantPreset = ({Name: 'Q3_K';} Rmin: 0.0; Rdelta: 0.1; Nstep: 16; QpStep: 0.05; QpNStep: 24;
    QcIter: 0; RmseType: 2; UseMAD: False; EnabledFields: [efRdelta, efNstep, efQpStep, efQpSteps, efRmseType,
      efUseMAD]);

  CDefaultQ4_K_PRESET1: TQuantPreset = ({Name: 'Q4_K';} Rmin: 0.9; Rdelta: 0.05; Nstep: 36; QpStep: 0.1; QpNStep: 4;
    QcIter: 4; RmseType: 3; UseMAD: False; RadiusLs: 0; RadiusLm: 0;
    EnabledFields: [efRmin, efRdelta, efNstep, efQpStep, efQpSteps, efQcIter, efRmseType, efUseMAD, efRadiusLs,
      efRadiusLm]);
  CDefaultQ4_K_PRESET2: TQuantPreset = ({Name: 'Q4_K';} Rmin: 1.6; Rdelta: 0.25; Nstep: 16; QpStep: 0.33; QpNStep: 16;
    QcIter: 4; RmseType: 2; UseMAD: False; RadiusLs: 3; RadiusLm: 3;
    EnabledFields: [efRmin, efRdelta, efNstep, efQpStep, efQpSteps, efQcIter, efRmseType, efUseMAD, efRadiusLs,
      efRadiusLm]);
  CDefaultQ4_K_PRESET3: TQuantPreset = ({Name: 'Q4_K';} Rmin: 2.6; Rdelta: 0.33; Nstep: 16; QpStep: 0.33; QpNStep: 16;
    QcIter: 4; RmseType: 2; UseMAD: False; RadiusLs: 5; RadiusLm: 7;
    EnabledFields: [efRmin, efRdelta, efNstep, efQpStep, efQpSteps, efQcIter, efRmseType, efUseMAD, efRadiusLs,
      efRadiusLm]);

  // PROFIL 0 : OFFICIEL -> nominal, aucune passe
  CDefaultQ5_K_PRESET1: TQuantPreset = ({Name: 'Q5_K';} Rmin: 0.9; Rdelta: 0.05; Nstep: 36; QpStep: 0.1; QpNStep: 4;
    QcIter: 4; RmseType: 2; UseMAD: False; RadiusLs: 0; RadiusLm: 0;
    EnabledFields: [efRmin, efRdelta, efNstep, efQpStep, efQpSteps, efQcIter, efRmseType, efUseMAD, efRadiusLs,
      efRadiusLm]);
  CDefaultQ5_K_PRESET2: TQuantPreset = ({Name: 'Q5_K';} Rmin: 1.6; Rdelta: 0.25; Nstep: 16; QpStep: 0.33; QpNStep: 12;
    QcIter: 4; RmseType: 2; UseMAD: False; RadiusLs: 3; RadiusLm: 3;
    EnabledFields: [efRmin, efRdelta, efNstep, efQpStep, efQpSteps, efQcIter, efRmseType, efUseMAD, efRadiusLs,
      efRadiusLm]);
  CDefaultQ5_K_PRESET3: TQuantPreset = ({Name: 'Q5_K';} Rmin: 2.9; Rdelta: 0.25; Nstep: 24; QpStep: 0.25; QpNStep: 16;
    QcIter: 4; RmseType: 2; UseMAD: False; RadiusLs: 5; RadiusLm: 7;
    EnabledFields: [efRmin, efRdelta, efNstep, efQpStep, efQpSteps, efQcIter, efRmseType, efUseMAD, efRadiusLs,
      efRadiusLm]);

  CDefaultQ6_K_PRESET1: TQuantPreset = ({Name: 'Q6_K';} Rmin: 0.0; Rdelta: 0.1; Nstep: 9; QpStep: 0.0; QpNStep: 0;
    QcIter: 0; RmseType: 2; UseMAD: False; EnabledFields: [efRdelta, efNstep, efRmseType, efUseMAD]);
  CDefaultQ6_K_PRESET2: TQuantPreset = ({Name: 'Q6_K';} Rmin: 0.0; Rdelta: 0.33; Nstep: 16; QpStep: 0.0; QpNStep: 0;
    QcIter: 0; RmseType: 2; UseMAD: False; EnabledFields: [efRdelta, efNstep, efRmseType, efUseMAD]);
  CDefaultQ6_K_PRESET3: TQuantPreset = ({Name: 'Q6_K';} Rmin: 0.0; Rdelta: 0.33; Nstep: 24; QpStep: 0.0; QpNStep: 0;
    QcIter: 0; RmseType: 2; UseMAD: False; EnabledFields: [efRdelta, efNstep, efRmseType, efUseMAD]);

  CDefaultQ8_K_PRESET1: TQuantPreset = ({Name: 'Q8_K';} Rmin: 0.0; Rdelta: 0.1; Nstep: 9; QpStep: 0.0; QpNStep: 0;
    QcIter: 0; RmseType: 2; UseMAD: False; EnabledFields: [efRdelta, efNstep, efRmseType, efUseMAD]);
  CDefaultQ8_K_PRESET2: TQuantPreset = ({Name: 'Q8_K';} Rmin: 0.0; Rdelta: 0.33; Nstep: 8; QpStep: 0.0; QpNStep: 0;
    QcIter: 0; RmseType: 2; UseMAD: False; EnabledFields: [efRdelta, efNstep, efRmseType, efUseMAD]);
  CDefaultQ8_K_PRESET3: TQuantPreset = ({Name: 'Q8_K';} Rmin: 0.0; Rdelta: 0.33; Nstep: 24; QpStep: 0.0; QpNStep: 0;
    QcIter: 0; RmseType: 2; UseMAD: False; EnabledFields: [efRdelta, efNstep, efRmseType, efUseMAD]);

  CDefaultMXFP4_PRESET: TQuantPreset = ({Name: 'MXFP4';} Rmin: 0.0; Rdelta: 0.0; Nstep: 1; QpStep: 0.0; QpNStep: 0;
    QcIter: 0; RmseType: 2; UseMAD: False; EnabledFields: [efNstep, efRmseType]);

  CDefaultNVFP4_PRESET: TQuantPreset = ({Name: 'NVFP4';} Rmin: 0.0; Rdelta: 0.0; Nstep: 6; QpStep: 0.0; QpNStep: 0;
    QcIter: 0; RmseType: 2; UseMAD: False; EnabledFields: [efNstep, efRmseType]);

  CDefaultIQ1_PRESET: TQuantPreset = ({Name: 'IQ1_S';} Rmin: 0.0; Rdelta: 0.0; Nstep: 0; QpStep: 0.0; QpNStep: 0;
    QcIter: 0; RmseType: 2; UseMAD: False; EnabledFields: [efRmseType]);

  CDefaultIQXS_PRESET1: TQuantPreset = ({Name: 'IQX*_S';} Rmin: 0.0; Rdelta: 0.66; Nstep: 3; QpStep: 0.0; QpNStep: 0;
    QcIter: 0; RmseType: 1; UseMAD: False; EnabledFields: [efRdelta, efNstep, efRmseType]);
  CDefaultIQXS_PRESET2: TQuantPreset = ({Name: 'IQX*_S';} Rmin: 0.0; Rdelta: 0.33; Nstep: 6; QpStep: 0.0; QpNStep: 0;
    QcIter: 0; RmseType: 1; UseMAD: False; EnabledFields: [efRdelta, efNstep, efRmseType]);
  CDefaultIQXS_PRESET3: TQuantPreset = ({Name: 'IQX*_S';} Rmin: 0.0; Rdelta: 0.33; Nstep: 9; QpStep: 0.0; QpNStep: 0;
    QcIter: 0; RmseType: 1; UseMAD: False; EnabledFields: [efRdelta, efNstep, efRmseType]);

  CDefaultIQ2XXS_PRESET: TQuantPreset = ({Name: 'IQ2_XXS';} Rmin: 0.0; Rdelta: 0.33; Nstep: 6; QpStep: 0.25; QpNStep: 4;
    QcIter: 4; RmseType: 3; UseMAD: False; EnabledFields: [efRdelta, efNstep, efQpStep, efQpSteps, efQcIter,
      efRmseType]);

  CDefaultIQ3XXS_PRESET: TQuantPreset = ({Name: 'IQ3_*S';} Rmin: 0.0; Rdelta: 0.66; Nstep: 12; QpStep: 0; QpNStep: 0;
    QcIter: 0; RmseType: 1; UseMAD: False; EnabledFields: [efRdelta, efNstep, efRmseType]);

  CDefaultIQ4_PRESET: TQuantPreset = ({Name: 'IQ4_*';} Rmin: 0.0; Rdelta: 0.0; Nstep: 15; QpStep: 0.0; QpNStep: 2;
    QcIter: 0; RmseType: 3; UseMAD: False; EnabledFields: [efNstep, efQpSteps, efRmseType]);

  CDefaultQX_X_PRESET: TQuantPreset = ({Name: 'QX_X';} Rmin: 0; Rdelta: 0.0; Nstep: 0; QpStep: 0; QpNStep: 0;
    QcIter: 0; RmseType: 0; UseMAD: False; EnabledFields: [efRmseType, efUseMAD]);

function GetDefaultPresetByCode(AType: Integer; AProfile: Integer): TQuantPreset;

function DLLDefaultRmseType(AType: Integer): Integer; // défaut RmseType du profil DLL
function QP_ProfileOfUseImpl(AUseImpl: Integer): Integer; inline;
function QP_HasPreset(AUseImpl: Integer): Boolean; inline;

implementation

uses
  uAppConfig, uGGMLTypes;

function DLLDefaultRmseType(AType: Integer): Integer;
begin
  // 1 :  Uniform (1.0) , 2 : Sqrt |x|,  3 : Magnitude (|x|) , 4 : x²
  case AType of
    GGML_TYPE_Q1_0:
      Result := 4;
    GGML_TYPE_Q2_0:
      Result := 3;
    GGML_TYPE_Q4_0:
      Result := 2;
    GGML_TYPE_Q4_1:
      Result := 2;
    GGML_TYPE_Q5_0:
      Result := 2;
    GGML_TYPE_Q5_1:
      Result := 2;
    GGML_TYPE_Q8_0:
      Result := 1;
    GGML_TYPE_Q8_1:
      Result := 1;
    GGML_TYPE_Q2_K:
      Result := 2;
    GGML_TYPE_Q3_K:
      Result := 2;
    GGML_TYPE_Q4_K:
      Result := 2;
    GGML_TYPE_Q5_K:
      Result := 2;
    GGML_TYPE_Q6_K:
      Result := 2;
    GGML_TYPE_Q8_K:
      Result := 1;
    GGML_TYPE_MXFP4:
      Result := 1;
    GGML_TYPE_NVFP4:
      Result := 1;
    GGML_TYPE_IQ1_S, GGML_TYPE_IQ1_M:
        Result := 1;
    GGML_TYPE_IQ2_S, GGML_TYPE_IQ2_XS :
        Result := 1;
    GGML_TYPE_IQ3_S :
        Result := 3;
    GGML_TYPE_IQ2_XXS:
      Result := 2;
    GGML_TYPE_IQ3_XXS:
      Result := 3;
    GGML_TYPE_IQ4_NL, GGML_TYPE_IQ4_XS:
        Result := 3;
    else
      Result := 2;
  end;
end;

function QP_ProfileOfUseImpl(AUseImpl: Integer): Integer;
begin
  case AUseImpl of
    2:
      Result := QP_PROF_DLL0; // 0
    3, 4, 5, 6, 7:
      Result := AUseImpl - 2; // 1,2,3,4,5
    else
      Result := QP_PROF_NONE; // 0,1 (Ref) -> aucun preset
  end;
end;

function QP_HasPreset(AUseImpl: Integer): Boolean;
begin
  Result := QP_ProfileOfUseImpl(AUseImpl) <> QP_PROF_NONE;
end;

function GetDefaultPresetByCode(AType: Integer; AProfile: Integer): TQuantPreset;
begin
  // PROFIL DLL : pas de tuning, juste un RmseType par type (persistant)
  if AProfile = QP_PROF_DLL0 then
    begin
      Result := CDefaultDLL_PRESET;
      //Result.Name := GGMLTypeToStr(AType);
      Result.RmseType := DLLDefaultRmseType(AType);
      Exit;
    end;
  // Profil 1 : Officiel
  if AProfile = 1 then
    begin
      case AType of
        GGML_TYPE_Q1_0:
          Result := CDefaultQ1_0_PRESET1;
        GGML_TYPE_Q2_0:
          Result := CDefaultQ2_0_PRESET1;
        GGML_TYPE_Q4_0:
          Result := CDefaultQ4_0_PRESET1;
        GGML_TYPE_Q4_1:
          Result := CDefaultQ4_1_PRESET1;
        GGML_TYPE_Q5_0:
          Result := CDefaultQ5_0_PRESET1;
        GGML_TYPE_Q5_1:
          Result := CDefaultQ5_1_PRESET1;
        GGML_TYPE_Q8_0:
          Result := CDefaultQ8_0_PRESET1;
        GGML_TYPE_Q8_1:
          Result := CDefaultQ8_1_PRESET1;
        GGML_TYPE_Q2_K:
          Result := CDefaultQ2_K_PRESET1;
        GGML_TYPE_Q3_K:
          Result := CDefaultQ3_K_PRESET1;
        GGML_TYPE_Q4_K:
          Result := CDefaultQ4_K_PRESET1;
        GGML_TYPE_Q5_K:
          Result := CDefaultQ5_K_PRESET1;
        GGML_TYPE_Q6_K:
          Result := CDefaultQ6_K_PRESET1;
        GGML_TYPE_Q8_K:
          Result := CDefaultQ8_K_PRESET1;
        GGML_TYPE_MXFP4:
          Result := CDefaultMXFP4_PRESET;
        GGML_TYPE_NVFP4:
          Result := CDefaultNVFP4_PRESET;
        GGML_TYPE_IQ1_S, GGML_TYPE_IQ1_M:
            Result := CDefaultIQ1_PRESET;
        GGML_TYPE_IQ2_S, GGML_TYPE_IQ2_XS:
            Result := CDefaultIQXS_PRESET1;
        GGML_TYPE_IQ2_XXS:
          Result := CDefaultIQ2XXS_PRESET;
        GGML_TYPE_IQ3_XXS, GGML_TYPE_IQ3_S:
          Result := CDefaultIQ3XXS_PRESET;
        GGML_TYPE_IQ4_NL, GGML_TYPE_IQ4_XS:
            Result := CDefaultIQ4_PRESET;
        else
        begin
          Result := CDefaultQX_X_PRESET;
          Result.RmseType := cfg.RmseType;//  cfg initialisé dans .dpr
        end;
      end;
    end
  // Profil 2 : Experimental1
  else if AProfile = 2 then
    begin
      case AType of
        GGML_TYPE_Q1_0:
          Result := CDefaultQ1_0_PRESET1;
        GGML_TYPE_Q2_0:
          Result := CDefaultQ2_0_PRESET1;
        GGML_TYPE_Q4_0:
          Result := CDefaultQ4_0_PRESET2;
        GGML_TYPE_Q4_1:
          Result := CDefaultQ4_1_PRESET2;
        GGML_TYPE_Q5_0:
          Result := CDefaultQ5_0_PRESET2;
        GGML_TYPE_Q5_1:
          Result := CDefaultQ5_1_PRESET2;
        GGML_TYPE_Q8_0:
          Result := CDefaultQ8_0_PRESET2;
        GGML_TYPE_Q8_1:
          Result := CDefaultQ8_1_PRESET2;
        GGML_TYPE_Q2_K:
          Result := CDefaultQ2_K_PRESET2;
        GGML_TYPE_Q3_K:
          Result := CDefaultQ3_K_PRESET2;
        GGML_TYPE_Q4_K:
          Result := CDefaultQ4_K_PRESET2;
        GGML_TYPE_Q5_K:
          Result := CDefaultQ5_K_PRESET2;
        GGML_TYPE_Q6_K:
          Result := CDefaultQ6_K_PRESET2;
        GGML_TYPE_Q8_K:
          Result := CDefaultQ8_K_PRESET2;
        GGML_TYPE_MXFP4:
          Result := CDefaultMXFP4_PRESET;
        GGML_TYPE_NVFP4:
          Result := CDefaultNVFP4_PRESET;
        GGML_TYPE_IQ1_S, GGML_TYPE_IQ1_M:
            Result := CDefaultIQ1_PRESET;
        GGML_TYPE_IQ2_S, GGML_TYPE_IQ2_XS:
            Result := CDefaultIQXS_PRESET2;
        GGML_TYPE_IQ2_XXS:
          Result := CDefaultIQ2XXS_PRESET;
        GGML_TYPE_IQ3_XXS, GGML_TYPE_IQ3_S:
          Result := CDefaultIQ3XXS_PRESET;
        GGML_TYPE_IQ4_NL, GGML_TYPE_IQ4_XS:
            Result := CDefaultIQ4_PRESET;
        else
        begin
          Result := CDefaultQX_X_PRESET;
          Result.RmseType := cfg.RmseType;//  cfg initialisé dans .dpr
        end;
      end;
    end
  // Profil 3,4,5 : Experimental2
  else
    begin
      case AType of
        GGML_TYPE_Q1_0:
          Result := CDefaultQ1_0_PRESET1;
        GGML_TYPE_Q2_0:
          Result := CDefaultQ2_0_PRESET1;
        GGML_TYPE_Q4_0:
          Result := CDefaultQ4_0_PRESET3;
        GGML_TYPE_Q4_1:
          Result := CDefaultQ4_1_PRESET3;
        GGML_TYPE_Q5_0:
          Result := CDefaultQ5_0_PRESET3;
        GGML_TYPE_Q5_1:
          Result := CDefaultQ5_1_PRESET3;
        GGML_TYPE_Q8_0:
          Result := CDefaultQ8_0_PRESET3;
        GGML_TYPE_Q8_1:
          Result := CDefaultQ8_1_PRESET3;
        GGML_TYPE_Q2_K:
          Result := CDefaultQ2_K_PRESET3;
        GGML_TYPE_Q3_K:
          Result := CDefaultQ3_K_PRESET3;
        GGML_TYPE_Q4_K:
          Result := CDefaultQ4_K_PRESET3;
        GGML_TYPE_Q5_K:
          Result := CDefaultQ5_K_PRESET3;
        GGML_TYPE_Q6_K:
          Result := CDefaultQ6_K_PRESET3;
        GGML_TYPE_Q8_K:
          Result := CDefaultQ8_K_PRESET3;
        GGML_TYPE_MXFP4:
          Result := CDefaultMXFP4_PRESET;
        GGML_TYPE_NVFP4:
          Result := CDefaultNVFP4_PRESET;
        GGML_TYPE_IQ1_S, GGML_TYPE_IQ1_M:
            Result := CDefaultIQ1_PRESET;
        GGML_TYPE_IQ2_S, GGML_TYPE_IQ2_XS:
            Result := CDefaultIQXS_PRESET3;
        GGML_TYPE_IQ2_XXS:
          Result := CDefaultIQ2XXS_PRESET;
        GGML_TYPE_IQ3_XXS, GGML_TYPE_IQ3_S:
          Result := CDefaultIQ3XXS_PRESET;
        GGML_TYPE_IQ4_NL, GGML_TYPE_IQ4_XS:
            Result := CDefaultIQ4_PRESET;
        else
        begin
          Result := CDefaultQX_X_PRESET;
          Result.RmseType := cfg.RmseType;
        end;
      end;
    end;
    //Result.Name := GGMLTypeToStr(AType);
end;

end.
