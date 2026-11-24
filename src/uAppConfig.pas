unit uAppConfig;

interface

uses
  Winapi.Windows, System.SysUtils, System.IniFiles, System.Classes, Vcl.Forms, uMath, uQuantPresetConfig,
  uGGMLConstants, uGGMLTypes, uLog;

const
  APP_VERSION = '1.2';
  APP_BUILD_DATE = '1.2.32.235 (20/11/2026)';

type
  // Structure Globale
  TGlobalConfig = record

    ShowToolbar: Boolean;

    UseImpl, RmseType: Integer;

    SaveMetaSeparate: Boolean;
    SplitSizeMbGbStr: string;
    SplitSizeMBytes: Int64; // 0 = Aucun split, sinon index dans la liste d'options

    UseAutoSignature: Boolean;
    AutoSignatureTemplate: string;

    VFP_Scale: Single;
    edtSrc1, edtSrc2, edtSrc3, edtSrcS, edtOut, sLang: string;
    edtFilter1, edtFilter2, edtFilter3, edtFilterS, edtFilterO: string;

    LogToMemo, LogToFile, LogThrottle, LogTimestamp: Boolean; // Active/désactive les logs et l'écriture fichier*
    LogLevel: TLogLevel;

    // Contient "pattern=template" pour FModelInpX
    MappingFile1, MappingFile2, MappingFile3, MappingFileS: string; // Chemin relatif du mappage pour FModelInpX
    UseIgnoredPrefixes1, UseIgnoredPrefixes2, UseIgnoredPrefixes3, UseIgnoredPrefixesS: Boolean;

    // Paramètres Graphique (uViewTensors)
    TVNumBins, TVPtsPerBin: Integer; // Résolution histogramme (ex: 50)
    HistMaxBars: Integer; // decimation d'affichage

    // HISTOGRAMME :
    bHistVAuto: Boolean; // axe VALEURS auto
    HistWMinMan, HistWMaxMan: Single; // fenetre imposee
    //HistVMinMan, HistVMaxMan: Single;
    bHistNAuto: Boolean; // axe FREQUENCES auto
    HistNMinMan, HistNMaxMan: Int64; //

    cbFilterV: string; // Filtre texte
    chkYAxisAuto, chkXAxisAuto1, chkT1sT2, chkT1dT2: Boolean;
    YAxisMinMan1, YAxisMaxMan: Single;
    XStartIdxMan, XEndIdxMan: Int64;
    MinXAxisRang: Integer;

    iTensorsPerChart: Integer;
    sTensorsPerChart: string;

    DiffAmplificationFactor: Single; // Facteur d'amplification de la différence (Delta)
    bShowBlockS, bShowOutlierS: Boolean;
    // HistModeFull: Boolean; // True = histogramme "Full", False = "ÉCHANTILLONNAGE (LOD)"
    ExportDelimiter: string; // ';' ou ','

    // Positions & Tailles des Fenêtres Principales
    FrmEditTensors_Left, FrmEditTensors_Top, FrmEditTensors_Width, FrmEditTensors_Height: Integer;
    FrmViewTensors_Left, FrmViewTensors_Top, FrmViewTensors_Width, FrmViewTensors_Height: Integer;
    FrmEditKVsGGUF_Left, FrmEditKVsGGUF_Top, FrmEditKVsGGUF_Width, FrmEditKVsGGUF_Height: Integer;
    FrmLogs_Left, FrmLogs_Top, FrmLogs_Width, FrmLogs_Height: Integer;

    ggmlReg: TGGMLRegistry;

    // E/S fichiers (TTensorReader / TFullDiffPipeline)
    IOReaderMode: Integer; // 0 = Auto (taille<=cap) | 1 = Mmap force | 2 = Stream force
    IOMapCapMb: Integer; // 0 = derive de la RAM (RAM/4) ; sinon plafond impose (Mo)
    IOChunkKb: Integer; // 0 = 4 Mo (brique du producteur FULL) ; Ko

    /// MRU des chemins de DLL (index 0 = le plus recent). Gere par cfgLoad/SaveSettings.
    GgmlDllHistory: TStringList;
  end;

const
  SAFETY_MAX_TENSORS = 32; // Limite absolue pour stabilité graphique
  // Historique des chemins de ggml-base.dll proposes au combo (uAppSetting).
  // CE N'EST PAS ce qui pilote le chargement : le nom utilisé est
  // cfg_ggml_type.ini [General] DLLName (cf. TGGMLRegistry.LoadFromIni).
  CGgmlDllHistoryMax = 5;

const
  SRC_MODEL1 = 1;
  SRC_MODEL2 = 2;
  SRC_MODEL3 = 3;
  SRC_MODELS = 4;
  SRC_MODELO = 5;
  // Ordre des items de cbSrcModelOut1 / mnuSourceOut
  CSourceIds: array [0 .. 3] of Integer = (SRC_MODEL1, SRC_MODEL2, SRC_MODEL3, SRC_MODELS);

  // Indices des panneaux de stBar1
  SB_STATUS = 0;
  SB_M1 = 1;
  SB_M2 = 2;
  SB_M3 = 3;
  SB_MS = 4;
  SB_MO = 5;

procedure cfgSaveSettings(var c: TGlobalConfig);
procedure cfgLoadSettings(var c: TGlobalConfig);
function GetTmpDir: string;
procedure ValidateFormBounds(var ALeft, ATop, AWidth, AHeight: Integer);

procedure WriteQuantPreset(var Ini: TMemIniFile; const Section: string; const P: TQuantPreset);
procedure ReadQuantPreset(var Ini: TMemIniFile; const Section: string; var P: TQuantPreset);


/// Charge la DLL dont le nom est dans cfg_ggml_type.ini. Un seul appel, a la fin de
/// cfgLoadSettings : cfg (LogLevel/LogToFile) doit etre connu avant les logs du registre.
procedure GgmlLoadDll;
/// Nom de DLL courant (= celui qui sera utilise au prochain lancement)
function cfgGgmlDllName: string;
/// Ecrit cfg_ggml_type.ini [General] DLLName + met le nom dans l'historique.
/// NE charge rien : effet au prochain lancement. False = INI non inscriptible.
function cfgSetGgmlDllName(const AName: string): Boolean;
/// Insertion en tete de l'historique (dedup insensible a la casse, borne a 5)
procedure cfgPushGgmlDll(const APath: string);

procedure GgmlDllEnsureList(var L: TStringList);



var
  cfg: TGlobalConfig;

implementation

uses
  uLangManager, uViewTensors, uEditTensors, uMappedNamesManager, uStrUtils,
  uTensorsNamesMan, uTensorStreamReader, uFullDiffPipeline;

function GetTmpDir: string;
var
  Dir: string;
begin
  Dir := IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0))) + 'tmp';
  if not DirectoryExists(Dir) then
    ForceDirectories(Dir);
  Result := Dir;
end;

procedure ValidateFormBounds(var ALeft, ATop, AWidth, AHeight: Integer);
var
  I, MaxW, MaxH, IntersectedMon: Integer;
  FormRect, MonRect, IntRect: TRect;
  PrimaryMon: TMonitor;
begin
  // Limiter la taille à l'écran le plus grand disponible (évite les débordements)
  MaxW := 0;
  MaxH := 0;
  for I := 0 to Screen.MonitorCount - 1 do
    begin
      if Screen.Monitors[I].Width > MaxW then
        MaxW := Screen.Monitors[I].Width;
      if Screen.Monitors[I].Height > MaxH then
        MaxH := Screen.Monitors[I].Height;
    end;

  if MaxW <= 0 then
    MaxW := 1024;
  if MaxH <= 0 then
    MaxH := 768;
  if AWidth > MaxW then
    AWidth := MaxW;
  if AHeight > MaxH then
    AHeight := MaxH;

  // On récupère la zone de travail de l'écran (Desktop - Taskbar)
  FormRect := Rect(ALeft, ATop, ALeft + AWidth, ATop + AHeight);
  IntersectedMon := -1;

  // Vérifier si le rectangle intersecte au moins un moniteur
  for I := 0 to Screen.MonitorCount - 1 do
    begin
      MonRect := Screen.Monitors[I].BoundsRect;
      // On utilise une copie de R_Requested car IntersectRect modifie le 1er paramètre
      IntRect := FormRect;
      if IntersectRect(IntRect, FormRect, MonRect) then
        // if IntersectRect(FormRect, MonRect, IntRect) then
        begin
          IntersectedMon := I;
          Break;
        end;
    end;

  // Si aucun moniteur détecté (désactivé/déconnecté), centrer sur le primaire
  if IntersectedMon = -1 then
    begin
      PrimaryMon := Screen.PrimaryMonitor;
      if Assigned(PrimaryMon) then
        begin
          ALeft := PrimaryMon.Left + (PrimaryMon.Width - AWidth) div 2;
          ATop := PrimaryMon.Top + (PrimaryMon.Height - AHeight) div 2;
        end
      else
        begin
          ALeft := 100;
          ATop := 100;
        end;
      FormRect := Rect(ALeft, ATop, ALeft + AWidth, ATop + AHeight);
    end;

  // Clamp aux limites du moniteur intersecté (évite le masquage partiel par le dock/taskbar)
  if IntersectedMon >= 0 then
    begin
      MonRect := Screen.Monitors[IntersectedMon].BoundsRect;
      if ALeft < MonRect.Left then
        ALeft := MonRect.Left;
      if ATop < MonRect.Top then
        ATop := MonRect.Top;
      if ALeft + AWidth > MonRect.Right then
        ALeft := MonRect.Right - AWidth;
      if ATop + AHeight > MonRect.Bottom then
        ATop := MonRect.Bottom - AHeight;
    end;
end;

procedure WriteQuantPreset(var Ini: TMemIniFile; const Section: string; const P: TQuantPreset);
begin
  Ini.WriteFloat(Section, 'Rmin', P.Rmin);
  Ini.WriteFloat(Section, 'Rdelta', P.Rdelta);
  Ini.WriteInteger(Section, 'Nstep', Round(P.Nstep));
  Ini.WriteFloat(Section, 'QpStep', P.QpStep);
  Ini.WriteInteger(Section, 'QpSteps', Round(P.QpNStep));
  Ini.WriteInteger(Section, 'QcIter', Round(P.QcIter));
  Ini.WriteInteger(Section, 'RmseType', P.RmseType);
  Ini.WriteBool(Section, 'UseMAD', P.UseMAD);

  Ini.WriteInteger(Section, 'RadiusLs', P.RadiusLs);
  Ini.WriteInteger(Section, 'RadiusLm', P.RadiusLm);
end;

procedure ReadQuantPreset(var Ini: TMemIniFile; const Section: string; var P: TQuantPreset);
begin
  P.Rmin := Ini.ReadFloat(Section, 'Rmin', P.Rmin);
  P.Rdelta := Ini.ReadFloat(Section, 'Rdelta', P.Rdelta);
  P.Nstep := Ini.ReadInteger(Section, 'Nstep', Round(P.Nstep));
  P.QpStep := Ini.ReadFloat(Section, 'QpStep', P.QpStep);
  P.QpNStep := Ini.ReadInteger(Section, 'QpSteps', Round(P.QpNStep));
  P.QcIter := Ini.ReadInteger(Section, 'QcIter', Round(P.QcIter));
  P.RmseType := Ini.ReadInteger(Section, 'RmseType', P.RmseType);
  P.UseMAD := Ini.ReadBool(Section, 'UseMAD', P.UseMAD);

  P.RadiusLs := Ini.ReadInteger(Section, 'RadiusLs', P.RadiusLs);
  P.RadiusLm := Ini.ReadInteger(Section, 'RadiusLm', P.RadiusLm);
end;

procedure WriteFloat(var Ini: TMemIniFile; const Sect, vars: string; var v: Single);
begin
  Ini.WriteString(Sect, vars, FloatToStrF(v, ffFixed, 17, 9, InvFS))
end;

function ReadFloat(var Ini: TMemIniFile; const Sect, vars: string; def: Single = 0): Single;
begin
  Result := pStrToFloat(Ini.ReadString(Sect, vars, FloatToStrF(def, ffFixed, 17, 9, InvFS)), def);
end;



procedure cfgSaveSettings(var c: TGlobalConfig);
var
  Ini: TMemIniFile;
  IniPath: string;
  i : Integer;
begin
  IniPath := ChangeFileExt(ExtractFileName(ParamStr(0)), '') + '.ini';
  IniPath := IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0))) + IniPath;
  Ini := TMemIniFile.Create(IniPath, TEncoding.UTF8);
  try

    Ini.WriteBool('CfgBase', 'ShowToolbar', c.ShowToolbar);

    Ini.WriteInteger('CfgBase', 'UseImpl', c.UseImpl);
    Ini.WriteInteger('CfgBase', 'RmseType', c.RmseType);


    Ini.WriteBool('CfgBase', 'LogToMemo', c.LogToMemo);
    Ini.WriteBool('CfgBase', 'LogToFile', c.LogToFile);
    Ini.WriteBool('CfgBase', 'LogThrottle', c.LogThrottle);
    Ini.WriteBool('CfgBase', 'LogTimestamp', c.LogTimestamp);

    Ini.WriteString('CfgBase', 'LogLevel', LogLevelToStr(c.LogLevel));

    Ini.WriteString('CfgBase', 'sLang', c.sLang);

    // SECTION PARAMÈTRES DE SAUVEGARD
    Ini.WriteBool('SaveOptions', 'SaveMetaSeparate', c.SaveMetaSeparate);
    Ini.WriteString('SaveOptions', 'SplitSizeMbGbStr', c.SplitSizeMbGbStr);
    c.SplitSizeMBytes := UnFormatSizeStrMbGb(c.SplitSizeMbGbStr);

    Ini.WriteBool('SaveOptions', 'UseAutoSignature', c.UseAutoSignature);
    Ini.WriteString('SaveOptions', 'AutoSignatureTemplate', c.AutoSignatureTemplate);

    // SECTION EDITOR (Paths)
    Ini.WriteString('ModelPaths', 'Src1', c.edtSrc1);
    Ini.WriteString('ModelPaths', 'Src2', c.edtSrc2);
    Ini.WriteString('ModelPaths', 'Src3', c.edtSrc3);
    Ini.WriteString('ModelPaths', 'SrcS', c.edtSrcS);
    Ini.WriteString('ModelPaths', 'Out', c.edtOut);

    Ini.WriteString('TensorEdit', 'FilterText1', c.edtFilter1);
    Ini.WriteString('TensorEdit', 'FilterText2', c.edtFilter2);
    Ini.WriteString('TensorEdit', 'FilterText3', c.edtFilter3);
    Ini.WriteString('TensorEdit', 'FilterTextS', c.edtFilterS);
    Ini.WriteString('TensorEdit', 'FilterTextO', c.edtFilterO);
    // Sauvegarde du Mapping
    Ini.WriteBool('DisplaySettings', 'UseIgnoredPrefixes1', c.UseIgnoredPrefixes1);
    Ini.WriteBool('DisplaySettings', 'UseIgnoredPrefixes2', c.UseIgnoredPrefixes2);
    Ini.WriteBool('DisplaySettings', 'UseIgnoredPrefixes3', c.UseIgnoredPrefixes3);
    Ini.WriteBool('DisplaySettings', 'UseIgnoredPrefixesS', c.UseIgnoredPrefixesS);

    Ini.WriteString('DisplaySettings', 'MappingFile1', c.MappingFile1);
    Ini.WriteString('DisplaySettings', 'MappingFile2', c.MappingFile2);
    Ini.WriteString('DisplaySettings', 'MappingFile3', c.MappingFile3);
    Ini.WriteString('DisplaySettings', 'MappingFileS', c.MappingFileS);

    // SECTION GRAPHIQUE / VISUALISATION
    Ini.WriteInteger('TensorView', 'TVNumBins', c.TVNumBins);
    Ini.WriteInteger('TensorView', 'TVPtsPerBin', c.TVPtsPerBin);
    Ini.WriteInteger('TensorView', 'HistMaxBars', c.HistMaxBars);

    // axe valeurs : memes cles que l'actuel (bHistXAuto veut bien dire "auto")
    Ini.WriteBool('TensorView', 'bHistVAuto', c.bHistVAuto);
    WriteFloat(Ini,'TensorView', 'HistWMinMan', c.HistWMinMan);
    WriteFloat(Ini,'TensorView', 'HistWMaxMan', c.HistWMaxMan);
    // axe frequences
    Ini.WriteBool('TensorView', 'bHistNAuto', c.bHistNAuto);
    Ini.WriteString('TensorView', 'HistNMinMan', IntToStr(c.HistNMinMan));
    Ini.WriteString('TensorView', 'HistNMaxMan', IntToStr(c.HistNMaxMan));

    // bins + echantillonnage stats

    Ini.WriteString('TensorView', 'FilterText', c.cbFilterV);
    Ini.WriteBool('TensorView', 'YAxisAuto', c.chkYAxisAuto);
    WriteFloat(Ini, 'TensorView', 'YAxisMinMan', c.YAxisMinMan1);
    WriteFloat(Ini, 'TensorView', 'YAxisMaxMan', c.YAxisMaxMan);

    Ini.WriteString('TensorView', 'sTensorsPerChart', c.sTensorsPerChart);
    Ini.WriteBool('TensorView', 'chkT1vT2', c.chkT1sT2);
    Ini.WriteBool('TensorView', 'chkT1dT2', c.chkT1dT2);
    Ini.WriteBool('TensorView', 'XAxisAuto', c.chkXAxisAuto1);
    Ini.WriteString('TensorView', 'XStartIdxMan', IntToStr(c.XStartIdxMan));
    Ini.WriteString('TensorView', 'XEndIdxMan', IntToStr(c.XEndIdxMan));

    Ini.WriteString('TensorView', 'ExportDelimiter', c.ExportDelimiter);
    Ini.WriteBool('TensorView', 'bShowBlockS', c.bShowBlockS);
    Ini.WriteBool('TensorView', 'bShowOutlierS', c.bShowOutlierS);

    WriteFloat(Ini,'TensorView', 'DiffAmplificationFactor', c.DiffAmplificationFactor);
    WriteFloat(Ini,'CfgBase', 'VFP_Scale', c.VFP_Scale);

    // Sauvegarde positions & tailles
    Ini.WriteInteger('FormPositions', 'EditTensors_Left', c.FrmEditTensors_Left);
    Ini.WriteInteger('FormPositions', 'EditTensors_Top', c.FrmEditTensors_Top);
    Ini.WriteInteger('FormPositions', 'EditTensors_Width', c.FrmEditTensors_Width);
    Ini.WriteInteger('FormPositions', 'EditTensors_Height', c.FrmEditTensors_Height);

    Ini.WriteInteger('FormPositions', 'ViewTensors_Left', c.FrmViewTensors_Left);
    Ini.WriteInteger('FormPositions', 'ViewTensors_Top', c.FrmViewTensors_Top);
    Ini.WriteInteger('FormPositions', 'ViewTensors_Width', c.FrmViewTensors_Width);
    Ini.WriteInteger('FormPositions', 'ViewTensors_Height', c.FrmViewTensors_Height);

    Ini.WriteInteger('FormPositions', 'EditKVs_Left', c.FrmEditKVsGGUF_Left);
    Ini.WriteInteger('FormPositions', 'EditKVs_Top', c.FrmEditKVsGGUF_Top);
    Ini.WriteInteger('FormPositions', 'EditKVs_Width', c.FrmEditKVsGGUF_Width);
    Ini.WriteInteger('FormPositions', 'EditKVs_Height', c.FrmEditKVsGGUF_Height);

    Ini.WriteInteger('FormPositions', 'FrmLogs_Left', c.FrmLogs_Left);
    Ini.WriteInteger('FormPositions', 'FrmLogs_Top', c.FrmLogs_Top);
    Ini.WriteInteger('FormPositions', 'FrmLogs_Width', c.FrmLogs_Width);
    Ini.WriteInteger('FormPositions', 'FrmLogs_Height', c.FrmLogs_Height);

    Ini.WriteInteger('IO', 'ReaderMode', c.IOReaderMode);
    Ini.WriteInteger('IO', 'MmapCapMb', c.IOMapCapMb);
    Ini.WriteInteger('IO', 'ChunkKb', c.IOChunkKb);

    // Historique DLL (simple liste de propositions pour le combo)
    GgmlDllEnsureList(c.GgmlDllHistory);
    for i := 0 to CGgmlDllHistoryMax - 1 do
      if i < c.GgmlDllHistory.Count then
        Ini.WriteString('GGML', 'DLLPath' + IntToStr(i), c.GgmlDllHistory[i])
      else
        Ini.WriteString('GGML', 'DLLPath' + IntToStr(i), '');

  finally
    try
      Ini.UpdateFile;
    except
      on E: Exception do
        LogE('Erreur critique : Impossible de sauvegarder la configuration : ' + E.Message);
    end;
    Ini.Free;
  end;
end;

procedure cfgLoadSettings(var c: TGlobalConfig);
var
  Ini: TMemIniFile;
  IniPath, s: string;
  i :integer;
begin
  IniPath := ChangeFileExt(ExtractFileName(ParamStr(0)), '') + '.ini';
  IniPath := IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0))) + IniPath;


  c.LogLevel := lvInfo;

  Ini := TMemIniFile.Create(IniPath, TEncoding.UTF8);
  try
    c.sLang := Ini.ReadString('CfgBase', 'sLang', '');
    if c.sLang = '' then
      begin
        c.sLang := GetSystemLanguageISO;
      end;

    c.ShowToolbar := Ini.ReadBool('CfgBase', 'ShowToolbar', False);

    c.UseImpl := Ini.ReadInteger('CfgBase', 'UseImpl', 2);
    c.RmseType := Ini.ReadInteger('CfgBase', 'RmseType', 3);
    if c.UseImpl < 0 then
      c.UseImpl := 2;
    if c.RmseType < 0 then
      c.RmseType := 3;

    c.LogToMemo := Ini.ReadBool('CfgBase', 'LogToMemo', True);
    c.LogToFile := Ini.ReadBool('CfgBase', 'LogToFile', False);
    c.LogThrottle := Ini.ReadBool('CfgBase', 'LogThrottle', True);
    c.LogTimestamp := Ini.ReadBool('CfgBase', 'LogTimestamp', True);
    c.LogLevel := LogLevelFromStr(Ini.ReadString('CfgBase', 'LogLevel', 'info'), lvInfo);

    c.UseAutoSignature := Ini.ReadBool('SaveOptions', 'UseAutoSignature', True);
    c.AutoSignatureTemplate := Ini.ReadString('SaveOptions', 'AutoSignatureTemplate', 'GGUF Editor D++v' + APP_VERSION);
    if c.AutoSignatureTemplate = '' then
      c.AutoSignatureTemplate := 'GGUF Editor D++v' + APP_VERSION;
    // KV :  general.edited_by =  GGUF Editor D++v1.2 2026-11-21 14-30-05
    // Chemins
    c.edtSrc1 := Ini.ReadString('ModelPaths', 'Src1', '');
    c.edtSrc2 := Ini.ReadString('ModelPaths', 'Src2', '');
    c.edtSrc3 := Ini.ReadString('ModelPaths', 'Src3', '');
    c.edtSrcS := Ini.ReadString('ModelPaths', 'SrcS', '');
    c.edtOut := Ini.ReadString('ModelPaths', 'Out', '');

    c.edtFilter1 := Ini.ReadString('TensorEdit', 'FilterText1', '');
    c.edtFilter2 := Ini.ReadString('TensorEdit', 'FilterText2', '');
    c.edtFilter3 := Ini.ReadString('TensorEdit', 'FilterText3', '');
    c.edtFilterS := Ini.ReadString('TensorEdit', 'FilterTextS', '');
    c.edtFilterO := Ini.ReadString('TensorEdit', 'FilterTextO', '');

    c.UseIgnoredPrefixes1 := Ini.ReadBool('DisplaySettings', 'UseIgnoredPrefixes1', False);
    c.UseIgnoredPrefixes2 := Ini.ReadBool('DisplaySettings', 'UseIgnoredPrefixes2', False);
    c.UseIgnoredPrefixes3 := Ini.ReadBool('DisplaySettings', 'UseIgnoredPrefixes3', False);
    c.UseIgnoredPrefixesS := Ini.ReadBool('DisplaySettings', 'UseIgnoredPrefixesS', False);

    c.MappingFile1 := Ini.ReadString('DisplaySettings', 'MappingFile1', 'NoMappedNames');
    c.MappingFile2 := Ini.ReadString('DisplaySettings', 'MappingFile2', 'NoMappedNames');
    c.MappingFile3 := Ini.ReadString('DisplaySettings', 'MappingFile3', 'NoMappedNames');
    c.MappingFileS := Ini.ReadString('DisplaySettings', 'MappingFileS', 'NoMappedNames');

    // SECTION PARAMÈTRES DE SAUVEGARD
    c.SaveMetaSeparate := Ini.ReadBool('SaveOptions', 'SaveMetaSeparate', False);
    c.SplitSizeMbGbStr := Ini.ReadString('SaveOptions', 'SplitSizeMbGbStr', 'None (One File)');
    if (c.SplitSizeMbGbStr = '') then
      c.SplitSizeMbGbStr := 'None (One File)';

    c.SplitSizeMBytes := UnFormatSizeStrMbGb(c.SplitSizeMbGbStr);

    // RESOLUTION / ECHANTILLONNAGE
    c.TVNumBins := Ini.ReadInteger('TensorView', 'TVNumBins', 1024);
    if (c.TVNumBins < 32) or (c.TVNumBins > 64000) then c.TVNumBins := 1024;
    c.TVPtsPerBin := Ini.ReadInteger('TensorView', 'TVPtsPerBin', 32);
    if (c.TVPtsPerBin < 2) or (c.TVPtsPerBin > 2048)  then c.TVPtsPerBin := 32;

    c.cbFilterV := Ini.ReadString('TensorView', 'FilterText', '');
    c.chkYAxisAuto := Ini.ReadBool('TensorView', 'YAxisAuto', True);
    c.YAxisMinMan1 := ReadFloat(Ini, 'TensorView', 'YAxisMinMan', -0.1);
    c.YAxisMaxMan := ReadFloat(Ini,'TensorView', 'YAxisMaxMan', 0.1);

    c.sTensorsPerChart := Ini.ReadString('TensorView', 'sTensorsPerChart', '2');
    c.iTensorsPerChart := ParseTensorsPerChart(c.sTensorsPerChart);

    c.chkT1sT2 := Ini.ReadBool('TensorView', 'chkT1vT2', False);
    c.chkT1dT2 := Ini.ReadBool('TensorView', 'chkT1dT2', False);

    c.chkXAxisAuto1 := Ini.ReadBool('TensorView', 'XAxisAuto', True);
    c.XStartIdxMan := StrToInt64Def(Ini.ReadString('TensorView', 'XStartIdxMan', '0'), 0);
    c.XEndIdxMan := StrToInt64Def(Ini.ReadString('TensorView', 'XEndIdxMan', '1024'), 1024);

    c.bHistVAuto := Ini.ReadBool('TensorView', 'bHistVAuto', True); // auto par defaut
    c.HistWMinMan := ReadFloat(Ini,'TensorView', 'HistWMinMan', -0.15);
    c.HistWMaxMan := ReadFloat(Ini,'TensorView', 'HistWMaxMan', 0.15);

    c.bHistNAuto := Ini.ReadBool('TensorView', 'bHistNAuto', True);
    c.HistNMinMan := StrToInt64Def(Ini.ReadString('TensorView', 'HistNMinMan', '0'), 0);
    c.HistNMaxMan := StrToInt64Def(Ini.ReadString('TensorView', 'HistNMaxMan', '1024'), 1024);

    c.HistMaxBars := Ini.ReadInteger('TensorView', 'HistMaxBars', 64);
    c.HistMaxBars := ClampInt(c.HistMaxBars, 4, 16384);

    if c.HistNMaxMan <= c.HistNMinMan then
    begin
      c.HistNMinMan := 0;
      c.HistNMaxMan := 1024;
    end;
    if c.HistWMaxMan <= c.HistWMinMan then
    begin
      c.HistWMinMan := -0.15;
      c.HistWMaxMan := 0.15;
    end;

    c.MinXAxisRang := 32;

    c.ExportDelimiter := Ini.ReadString('TensorView', 'ExportDelimiter', ';');
    if (c.ExportDelimiter = '') then
      c.ExportDelimiter := ';';
    c.bShowBlockS := Ini.ReadBool('TensorView', 'bShowBlockS', True);
    c.bShowOutlierS := Ini.ReadBool('TensorView', 'bShowOutlierS', True);

    c.DiffAmplificationFactor := ReadFloat(Ini,'TensorView', 'DiffAmplificationFactor', 1.0);
    if (c.DiffAmplificationFactor > 64) or (c.DiffAmplificationFactor < 0.1) then
      c.DiffAmplificationFactor := 1.0;

    c.VFP_Scale := ReadFloat(Ini,'CfgBase', 'VFP_Scale', 0.000081380208333);
    if (c.VFP_Scale > 64000) or (c.VFP_Scale = 0.0) then
      c.VFP_Scale := 0.000081380208333;

    // Restauration positions & tailles (valeurs par défaut si INI manquant)
    c.FrmEditTensors_Left := Ini.ReadInteger('FormPositions', 'EditTensors_Left', 150);
    c.FrmEditTensors_Top := Ini.ReadInteger('FormPositions', 'EditTensors_Top', 150);
    c.FrmEditTensors_Width := Ini.ReadInteger('FormPositions', 'EditTensors_Width', 700);
    c.FrmEditTensors_Height := Ini.ReadInteger('FormPositions', 'EditTensors_Height', 600);

    c.FrmViewTensors_Left := Ini.ReadInteger('FormPositions', 'ViewTensors_Left', 250);
    c.FrmViewTensors_Top := Ini.ReadInteger('FormPositions', 'ViewTensors_Top', 250);
    c.FrmViewTensors_Width := Ini.ReadInteger('FormPositions', 'ViewTensors_Width', 940);
    c.FrmViewTensors_Height := Ini.ReadInteger('FormPositions', 'ViewTensors_Height', 680);

    c.FrmEditKVsGGUF_Left := Ini.ReadInteger('FormPositions', 'EditKVs_Left', 275);
    c.FrmEditKVsGGUF_Top := Ini.ReadInteger('FormPositions', 'EditKVs_Top', 275);
    c.FrmEditKVsGGUF_Width := Ini.ReadInteger('FormPositions', 'EditKVs_Width', 640);
    c.FrmEditKVsGGUF_Height := Ini.ReadInteger('FormPositions', 'EditKVs_Height', 600);

    c.FrmLogs_Left := Ini.ReadInteger('FormPositions', 'FrmLogs_Left', 300);
    c.FrmLogs_Top := Ini.ReadInteger('FormPositions', 'FrmLogs_Top', 300);
    c.FrmLogs_Width := Ini.ReadInteger('FormPositions', 'FrmLogs_Width', 640);
    c.FrmLogs_Height := Ini.ReadInteger('FormPositions', 'FrmLogs_Height', 300);

    c.IOReaderMode := ClampInt(Ini.ReadInteger('IO', 'ReaderMode', 0), 0, 2);
    c.IOMapCapMb := ClampInt(Ini.ReadInteger('IO', 'MmapCapMb', 0), 0, 262144);
    c.IOChunkKb := ClampInt(Ini.ReadInteger('IO', 'ChunkKb', 0), 0, 65536);

    SetReaderMode(ReaderModeFromInt(c.IOReaderMode), c.IOMapCapMb);
    if cfg.IOChunkKb > 0 then GFullChunkBytes := cfg.IOChunkKb shl 10 { Ko } else GFullChunkBytes := 4 shl 20 { Mo } ;

    GgmlDllEnsureList(c.GgmlDllHistory);
    c.GgmlDllHistory.Clear;
    for i := 0 to CGgmlDllHistoryMax - 1 do
    begin
      s := Trim(Ini.ReadString('GGML', 'DLLPath' + IntToStr(i), ''));
      if (s <> '') and (c.GgmlDllHistory.IndexOf(s) < 0) then
        c.GgmlDllHistory.Add(s);
    end;
  finally
    Ini.Free;
  end;

  c.ggmlReg := TGGMLRegistry.InitGlobal('', False);

  InitializeNamesSystem(c);
  c.ggmlReg.LoadPresetsFromIni;

  GgmlLoadDll;
  cfgPushGgmlDll(cfgGgmlDllName);
end;



procedure GgmlDllEnsureList(var L: TStringList);
begin
  if L = nil then
  begin
    L := TStringList.Create;
    L.CaseSensitive := False;
    L.Sorted := False;       // l'ordre = l'ordre d'anciennete
  end;
end;

procedure cfgPushGgmlDll(const APath: string);
var
  S: string;
  i: Integer;
begin
  GgmlDllEnsureList(cfg.GgmlDllHistory);
  S := Trim(APath);
  if S = '' then
    Exit;
  i := cfg.GgmlDllHistory.IndexOf(S);
  if i = 0 then
    Exit;                          // deja en tete
  if i > 0 then
    cfg.GgmlDllHistory.Delete(i);
  cfg.GgmlDllHistory.Insert(0, S);
  while cfg.GgmlDllHistory.Count > CGgmlDllHistoryMax do
    cfg.GgmlDllHistory.Delete(cfg.GgmlDllHistory.Count - 1);
end;

function cfgGgmlDllName: string;
begin
  if cfg.ggmlReg <> nil then
    Result := cfg.ggmlReg.DllNameRaw
  else
    Result := CStrGGMLDLLName;
end;

procedure GgmlLoadDll;
begin
  if cfg.ggmlReg <> nil then
    cfg.ggmlReg.LoadLibraryNow;    // le nom vient de cfg_ggml_type.ini, pas de l'historique
end;

function cfgSetGgmlDllName(const AName: string): Boolean;
begin
  Result := GgmlWriteDllName(AName);

  if Result and (cfg.ggmlReg <> nil) then
    cfg.ggmlReg.SetDllName(AName);   // pour que l'affichage/reflet = ce qui est sur le disque

  if Result then
    cfgPushGgmlDll(cfgGgmlDllName);
end;


initialization


finalization

FreeAndNil(cfg.ggmlReg);
FreeAndNil(cfg.GgmlDllHistory);

end.
