unit uAppConfig;

interface

uses
  Winapi.Windows, System.SysUtils, System.IniFiles, System.Classes;

const
  APP_VERSION = '1.0';
  APP_BUILD_DATE = '1.0.32.112 (14/07/2026)';

type
  // Structure Globale
  TGlobalConfig = record
    UseFDLL, UseFImpl, // use Impl ou Ref ex : QuantQ4_K_Impl(src, Dest, n_row) else  QuantQ4_K_Ref(src, Dest, n_row);
    SaveMetaSeparate: Boolean;
    SplitSizeMbGbStr: string;
    SplitSizeMBytes: Int64; // 0 = Aucun split, sinon index dans la liste d'options

    UseAutoSignature: Boolean;
    AutoSignatureTemplate: string;

    NVFP4_Scale: Double;
    edtSrc1, edtSrc2, edtSrcS, edtOut, sLang: string;
    edtFilter1, edtFilter2, edtFilterS, edtFilterO: string;

    LogToMemo, LogToFile: Boolean; // Active/désactive les logs et l'écriture fichier

    // Chemins et mappages gérés directement dans uEditTensorsGGUF / uMappedNames
    TensorMappings1, TensorMappings2, TensorMappingsS: TStringList; // Contient "pattern=template" pour FModelInpX
    MappingFile1, MappingFile2, MappingFileS: string; // Chemin relatif du mappage pour FModelInpX
    UseIgnoredPrefixes1, UseIgnoredPrefixes2, UseIgnoredPrefixesS: Boolean;

    // Paramètres Graphique (uViewTensors)
    TVNumBins, TVPtsPerBin, HistBins: Integer; // Résolution histogramme (ex: 50)
    HistStride: Integer; // Pas de lecture pour l'estimation Min/Max (ex: 50)
    cbFilterV: string; // Filtre texte
    chkYAxisAuto, chkXAxisAuto, chkT1vT2: Boolean;
    YAxisMinMan, YAxisMaxMan: Single;
    XStartIdxMan, XEndIdxMan: Int64;
    MinXAxisRang: Integer;
    iTensorsPerChart: Integer;
    sTensorsPerChart: string;

    DiffAmplificationFactor: Single; // Facteur d'amplification de la différence (Delta)
    bShowBlockS, bShowOutlierS: Boolean;
    ExportDelimiter: string; // ';' ou ','

  end;

const
  SAFETY_MAX_TENSORS = 32; // Limite absolue pour stabilité graphique

function FormatBytes(Bytes: Int64): string;
function UnFormatSizeStrMbGb(sSizeStr: string): Int64;
procedure cfgSaveSettings(var c: TGlobalConfig);
procedure cfgLoadSettings(var c: TGlobalConfig);
function GetTmpDir: string;

var
  cfg: TGlobalConfig;

implementation

uses
  uLangManager, uViewTensors, uEditTensors, uMappedNamesManager, uGgufStrUtils, uTensorsNamesMan;

function FormatBytes(Bytes: Int64): string;
const
  KB = 1024;
  MB = 1024 * KB;
var
  TB, GB: Double;
begin
  GB := 1024 * MB;
  TB := 1024 * GB;
  if Bytes >= TB then
    Result := Format('%.2f TB', [Bytes / TB])
  else if Bytes >= GB then
    Result := Format('%.2f GB', [Bytes / GB])
  else if Bytes >= MB then
    Result := Format('%.2f MB', [Bytes / MB])
  else if Bytes >= KB then
    Result := Format('%.2f KB', [Bytes / KB])
  else
    Result := IntToStr(Bytes) + ' B';
end;

function UnFormatSizeStrMbGb(sSizeStr: string): Int64;
const
  MB = 1048576; // 1024 * 1024;
var
  GB: Double;
  xMbGb: Int64;
begin
  GB := 1024 * MB;
  xMbGb := 1;
  Result := Trunc(GB);
  sSizeStr := UpperCase(sSizeStr);
  if Pos('GB', sSizeStr) > 0 then
  begin
    xMbGb := Trunc(GB);
    sSizeStr := StringReplace(sSizeStr, 'GB', '', [rfReplaceAll]);
  end
  else if Pos('MB', sSizeStr) > 0 then
  begin
    xMbGb := MB;
    sSizeStr := StringReplace(sSizeStr, 'MB', '', [rfReplaceAll]);
  end;
  Result := StrToInt64Def(Trim(sSizeStr), 0) * xMbGb;
end;

function GetTmpDir: string;
var
  Dir: string;
begin
  Dir := IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0))) + 'tmp';
  if not DirectoryExists(Dir) then
    ForceDirectories(Dir);
  Result := Dir;
end;

procedure cfgSaveSettings(var c: TGlobalConfig);
var
  Ini: TMemIniFile;
  IniPath: string;
  i, Count: Integer;
  S: string;
begin
  IniPath := ChangeFileExt(ExtractFileName(ParamStr(0)), '') + '.ini';
  IniPath := IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0))) + IniPath;
  Ini := TMemIniFile.Create(IniPath, TEncoding.UTF8);
  try
    Ini.WriteBool('CfgBase', 'UseFDLL', c.UseFDLL);
    Ini.WriteBool('CfgBase', 'UseFImpl', c.UseFImpl);

    Ini.WriteBool('CfgBase', 'LogToMemo', c.LogToMemo);
    Ini.WriteBool('CfgBase', 'LogToFile', c.LogToFile);
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
    Ini.WriteString('ModelPaths', 'SrcS', c.edtSrcS);
    Ini.WriteString('ModelPaths', 'Out', c.edtOut);

    Ini.WriteString('TensorEdit', 'FilterText1', c.edtFilter1);
    Ini.WriteString('TensorEdit', 'FilterText2', c.edtFilter2);
    Ini.WriteString('TensorEdit', 'FilterTextS', c.edtFilterS);
    Ini.WriteString('TensorEdit', 'FilterTextO', c.edtFilterO);
    // Sauvegarde du Mapping
    Ini.WriteBool('DisplaySettings', 'UseIgnoredPrefixes1', c.UseIgnoredPrefixes1);
    Ini.WriteBool('DisplaySettings', 'UseIgnoredPrefixes2', c.UseIgnoredPrefixes2);
    Ini.WriteBool('DisplaySettings', 'UseIgnoredPrefixesS', c.UseIgnoredPrefixesS);

    Ini.WriteString('DisplaySettings', 'MappingFile1', c.MappingFile1);
    Ini.WriteString('DisplaySettings', 'MappingFile2', c.MappingFile2);
    Ini.WriteString('DisplaySettings', 'MappingFileS', c.MappingFileS);

    // SECTION GRAPHIQUE / VISUALISATION
    Ini.WriteInteger('TensorView', 'TVNumBins', c.TVNumBins);
    Ini.WriteInteger('TensorView', 'TVPtsPerBin', c.TVPtsPerBin);
    Ini.WriteInteger('TensorView', 'HistBins', c.HistBins);
    Ini.WriteInteger('TensorView', 'HistStride', c.HistStride);

    Ini.WriteString('TensorView', 'FilterText', c.cbFilterV);
    Ini.WriteBool('TensorView', 'YAxisAuto', c.chkYAxisAuto);
    Ini.WriteFloat('TensorView', 'YAxisMinMan', c.YAxisMinMan);
    Ini.WriteFloat('TensorView', 'YAxisMaxMan', c.YAxisMaxMan);

    Ini.WriteString('TensorView', 'sTensorsPerChart', c.sTensorsPerChart);
    Ini.WriteBool('TensorView', 'chkT1vT2', c.chkT1vT2);
    Ini.WriteBool('TensorView', 'XAxisAuto', c.chkXAxisAuto);
    Ini.WriteString('TensorView', 'XStartIdxMan', IntToStr(c.XStartIdxMan));
    Ini.WriteString('TensorView', 'XEndIdxMan', IntToStr(c.XEndIdxMan));

    Ini.WriteString('TensorView', 'ExportDelimiter', c.ExportDelimiter);
    Ini.WriteBool('TensorView', 'bShowBlockS', c.bShowBlockS);
    Ini.WriteBool('TensorView', 'bShowOutlierS', c.bShowOutlierS);
    Ini.WriteFloat('TensorView', 'DiffAmplificationFactor', c.DiffAmplificationFactor);
    Ini.WriteFloat('CfgBase', 'NVFP4_Scale', c.NVFP4_Scale);
  finally
    Ini.UpdateFile;
    Ini.Free;
  end;
end;

procedure cfgLoadSettings(var c: TGlobalConfig);
var
  Ini: TMemIniFile;
  IniPath: string;
  i, Count: Integer;
  S: string;
begin
  IniPath := ChangeFileExt(ExtractFileName(ParamStr(0)), '') + '.ini';
  IniPath := IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0))) + IniPath;

  Ini := TMemIniFile.Create(IniPath, TEncoding.UTF8);
  try
    c.sLang := Ini.ReadString('CfgBase', 'sLang', '');
    if c.sLang = '' then
    begin
      c.sLang := GetSystemLanguageISO;
    end;

    c.UseFDLL := Ini.ReadBool('CfgBase', 'UseFDLL', True);
    c.UseFImpl := Ini.ReadBool('CfgBase', 'UseFImpl', True);

    c.LogToMemo := Ini.ReadBool('CfgBase', 'LogToMemo', True);
    c.LogToFile := Ini.ReadBool('CfgBase', 'LogToFile', False);

    c.UseAutoSignature := Ini.ReadBool('SaveOptions', 'UseAutoSignature', True);
    c.AutoSignatureTemplate := Ini.ReadString('SaveOptions', 'AutoSignatureTemplate',
      'GGUF Editor D++v' + APP_VERSION);
    if c.AutoSignatureTemplate = '' then
      c.AutoSignatureTemplate := 'GGUF Editor D++v' + APP_VERSION;
      //KV :  general.edited_by =  GGUF Editor D++v1.0 2026-07-18 14-30-05
    // Chemins
    c.edtSrc1 := Ini.ReadString('ModelPaths', 'Src1', '');
    c.edtSrc2 := Ini.ReadString('ModelPaths', 'Src2', '');
    c.edtSrcS := Ini.ReadString('ModelPaths', 'SrcS', '');
    c.edtOut := Ini.ReadString('ModelPaths', 'Out', '');

    c.edtFilter1 := Ini.ReadString('TensorEdit', 'FilterText1', '');
    c.edtFilter2 := Ini.ReadString('TensorEdit', 'FilterText2', '');
    c.edtFilterS := Ini.ReadString('TensorEdit', 'FilterTextS', '');
    c.edtFilterO := Ini.ReadString('TensorEdit', 'FilterTextO', '');

    c.UseIgnoredPrefixes1 := Ini.ReadBool('DisplaySettings', 'UseIgnoredPrefixes1', False);
    c.UseIgnoredPrefixes2 := Ini.ReadBool('DisplaySettings', 'UseIgnoredPrefixes2', False);
    c.UseIgnoredPrefixesS := Ini.ReadBool('DisplaySettings', 'UseIgnoredPrefixesS', False);

    c.MappingFile1 := Ini.ReadString('DisplaySettings', 'MappingFile1', 'NoMappedNames');
    c.MappingFile2 := Ini.ReadString('DisplaySettings', 'MappingFile2', 'NoMappedNames');
    c.MappingFileS := Ini.ReadString('DisplaySettings', 'MappingFileS', 'NoMappedNames');

    // SECTION PARAMÈTRES DE SAUVEGARD
    c.SaveMetaSeparate := Ini.ReadBool('SaveOptions', 'SaveMetaSeparate', False);
    c.SplitSizeMbGbStr := Ini.ReadString('SaveOptions', 'SplitSizeMbGbStr', 'None (One File)');
    if (c.SplitSizeMbGbStr = '') then
      c.SplitSizeMbGbStr := 'None (One File)';

    c.SplitSizeMBytes := UnFormatSizeStrMbGb(c.SplitSizeMbGbStr);

    c.TVNumBins := Ini.ReadInteger('TensorView', 'TVNumBins', 2048);
    if (c.TVNumBins > 64000) or (c.TVNumBins < 32) then
      c.TVNumBins := 2048;
    c.TVPtsPerBin := Ini.ReadInteger('TensorView', 'TVPtsPerBin', 16);
    if (c.TVPtsPerBin > 2048) or (c.TVPtsPerBin < 2) then
      c.TVPtsPerBin := 16;

    c.HistBins := Ini.ReadInteger('TensorView', 'HistBins', 64);
    if (c.HistBins > 64000) or (c.HistBins < 1) then
      c.HistBins := 64;
    c.HistStride := Ini.ReadInteger('TensorView', 'HistStride', 32);
    if (c.HistStride > 2048) or (c.HistStride < 1) then
      c.HistStride := 16;

    c.cbFilterV := Ini.ReadString('TensorView', 'FilterText', '');
    c.chkYAxisAuto := Ini.ReadBool('TensorView', 'YAxisAuto', True);
    c.YAxisMinMan := Ini.ReadFloat('TensorView', 'YAxisMinMan', -0.1);
    c.YAxisMaxMan := Ini.ReadFloat('TensorView', 'YAxisMaxMan', 0.1);

    c.sTensorsPerChart := UpperCase(Ini.ReadString('TensorView', 'sTensorsPerChart', '2'));
    if c.sTensorsPerChart = 'ONE' then
      c.iTensorsPerChart := 1
    else if c.sTensorsPerChart = 'ONE ONLY' then
      c.iTensorsPerChart := 1
    else if c.sTensorsPerChart = 'ALL' then
      c.iTensorsPerChart := SAFETY_MAX_TENSORS
    else
      c.iTensorsPerChart := StrToInt64Def(c.sTensorsPerChart, 2);

    c.chkT1vT2 := Ini.ReadBool('TensorView', 'chkT1vT2', False);

    c.chkXAxisAuto := Ini.ReadBool('TensorView', 'XAxisAuto', False);
    c.XStartIdxMan := StrToInt64Def(Ini.ReadString('TensorView', 'XStartIdxMan', '0'), 0);
    c.XEndIdxMan := StrToInt64Def(Ini.ReadString('TensorView', 'XEndIdxMan', '1024'), 1024);

    c.MinXAxisRang := 32;

    c.ExportDelimiter := Ini.ReadString('TensorView', 'ExportDelimiter', ';');
    if (c.ExportDelimiter = '') then
      c.ExportDelimiter := ';';
    c.bShowBlockS := Ini.ReadBool('TensorView', 'bShowBlockS', True);
    c.bShowOutlierS := Ini.ReadBool('TensorView', 'bShowOutlierS', True);
    c.DiffAmplificationFactor := Ini.ReadFloat('TensorView', 'DiffAmplificationFactor', 1.0);
    if (c.DiffAmplificationFactor > 64) or (c.DiffAmplificationFactor < 0.1) then
      c.DiffAmplificationFactor := 1.0;

    c.NVFP4_Scale := Ini.ReadFloat('CfgBase', 'NVFP4_Scale', 0.000081380208333);
    if (c.NVFP4_Scale > 64000) or (c.NVFP4_Scale = 0.0) then
      c.NVFP4_Scale := 0.000081380208333;
  finally
    Ini.Free;
  end;
  InitializeNamesSystem(c);
end;

initialization

finalization

FreeAndNil(cfg.TensorMappings1);
FreeAndNil(cfg.TensorMappings2);
FreeAndNil(cfg.TensorMappingsS);

end.
