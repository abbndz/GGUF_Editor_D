unit uTensorsNamesMan;

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections,
  uGGUFModel, uGGUFTypes, uAppConfig, uMath, uLog;

type
  TMappingRule = packed record
    Prefix, Suffix, Template: string;
    PrefixLen, SuffixLen: Integer;
  end;

  TMappingEngine = class
  private
    FDirectMappings: TDictionary<string, string>;
    FPatternRules: TArray<TMappingRule>;
    FPatternCount: Integer;
  public
    constructor Create(AMappings: TStringList);
    destructor Destroy; override;
    function MapName(const AName: string): string;
    property PatternCount: Integer read FPatternCount;
  end;

  TPrefixInfo = packed record
    Prefix: string;
    PrefixEt: string;
    PrefixLen: Integer;
  end;

  TPatternCache = packed record
    Patterns: TArray<string>;
    Sizes: TArray<Int64>;
    Count: Integer;
  end;

  // Fonctions publiques
function GetLayersPrefixFN(): String;
function GetLayersPrefixList(): TStringList;
function GetIgnoredPrefixFN(): String;
function GetIgnoredPrefixList(): TStringList;
function GetLayerPrefixIndx(const Name: string; out LIdx: Integer): boolean;
function IsIgnoredPrefix(const Name: string): boolean;

function GetTensorPatternName(const Name: string): string;

function GetMappingDir: string;
function GetAvailableMappedNames: TStringList;
function GetMappedNamesStrings(sFN: String; out SL: TStringList; out MappingEngine: TMappingEngine): boolean;

procedure ApplyMappingToModel(AModel: TGGUFFile; const MappingEngine: TMappingEngine; UseMappedNames: boolean);
function CalculateAllPatternSizes(M: TGGUFFile): Int64;

// Initialisation centralisée après cfgLoadSettings
procedure InitializeNamesSystem(var Cfg: TGlobalConfig);

// Instances globales
var
  gMapping1, gMapping2, gMappingS: TMappingEngine;
  gPatternCache: TPatternCache;

  FTensorsLayersPrefixesList: TArray<TPrefixInfo>;
  FTensorsLayersPrefixesCount: Integer;

  FIgnoredPrefixesList: TArray<TPrefixInfo>;
  FIgnoredPrefixesCount: Integer;

implementation

{ TMappingEngine }

constructor TMappingEngine.Create(AMappings: TStringList);
var
  I, EqPos: Integer;
  Line, Pattern, Template, Prefix, Suffix: string;
begin
  FDirectMappings := TDictionary<string, string>.Create(Max(AMappings.Count div 2, 16));
  FPatternCount := 0;
  SetLength(FPatternRules, 0);

  for I := 0 to AMappings.Count - 1 do
  begin
    Line := AMappings[I];
    EqPos := Pos('=', Line);
    if EqPos = 0 then
      Continue;

    Pattern := Copy(Line, 1, EqPos - 1);
    Template := Copy(Line, EqPos + 1, MaxInt);

    if Pos('{}', Pattern) > 0 then
    begin
      SetLength(FPatternRules, FPatternCount + 1);
      Prefix := Copy(Pattern, 1, Pos('{}', Pattern) - 1);
      Suffix := Copy(Pattern, Pos('{}', Pattern) + 2, MaxInt);

      FPatternRules[FPatternCount].Prefix := Prefix;
      FPatternRules[FPatternCount].PrefixLen := Length(Prefix);
      FPatternRules[FPatternCount].Suffix := Suffix;
      FPatternRules[FPatternCount].SuffixLen := Length(Suffix);
      FPatternRules[FPatternCount].Template := Template;
      Inc(FPatternCount);
    end
    else
      FDirectMappings.Add(Pattern, Template);
    // FDirectMappings[Pattern] := Template;
  end;
end;

destructor TMappingEngine.Destroy;
begin
  FDirectMappings.Free;
  inherited;
end;

function TMappingEngine.MapName(const AName: string): string;
var
  I, IdxInt: Integer;
  IdxStr, Prefix, Suffix: string;
begin
  Result := AName;
  if FPatternCount <= 0 then
    Exit;

  // 1. Dictionnaire direct
  if FDirectMappings.TryGetValue(AName, Result) then
    Exit;
  Result := AName;

  // 2. Patterns pré-découpés
  for I := 0 to FPatternCount - 1 do
  begin
    Prefix := FPatternRules[I].Prefix;
    Suffix := FPatternRules[I].Suffix;
    if (Pos(Prefix, AName) = 1) and (Length(AName) > FPatternRules[I].PrefixLen + FPatternRules[I].SuffixLen) then
      if (Copy(AName, Length(AName) - FPatternRules[I].SuffixLen + 1, FPatternRules[I].SuffixLen) = Suffix) then
      begin
        IdxStr := Copy(AName, FPatternRules[I].PrefixLen + 1, Length(AName) - FPatternRules[I].PrefixLen -
          FPatternRules[I].SuffixLen);
        if TryStrToInt(IdxStr, IdxInt) then
        begin
          Result := StringReplace(FPatternRules[I].Template, '{}', IdxStr, [rfReplaceAll]);
          Exit;
        end;
      end;
  end;
end;

{ --- Gestion des Préfixes & Patterns --- }
function GetLayersPrefixFN(): String;
begin
  Result := IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0))) + 'TensorLPrefixes.txt';
end;

function GetLayersPrefixList(): TStringList;
var
  sFN: string;
  Raw: string;
  SLF: TStringList;
  sDir, Line: string;
  I, EqPos: Integer;
begin
  sFN := GetLayersPrefixFN();

  SLF := TStringList.Create;
  Result := TStringList.Create;
  try
    SLF.LoadFromFile(sFN, TEncoding.UTF8);
    for I := 0 to SLF.Count - 1 do
    begin
      Line := SLF[I];
      if (Line = '') or (Line[1] in ['#', ';']) then
        Continue;
      Result.Add(Line);
    end;
  finally
    SLF.Free;
  end;
  FTensorsLayersPrefixesCount := 0;
  SetLength(FTensorsLayersPrefixesList, Result.Count);
  for I := 0 to Result.Count - 1 do
  begin
    FTensorsLayersPrefixesList[FTensorsLayersPrefixesCount].Prefix := Trim(Result[I]);
    FTensorsLayersPrefixesList[FTensorsLayersPrefixesCount].PrefixLen :=
      Length(FTensorsLayersPrefixesList[FTensorsLayersPrefixesCount].Prefix);
    Inc(FTensorsLayersPrefixesCount);
  end;
end;

function GetIgnoredPrefixFN(): String;
begin
  Result := IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0))) + 'TensorsIgnored.txt';
end;

function GetIgnoredPrefixList(): TStringList;
var
  sFN: string;
  Raw: string;
  SLF: TStringList;
  sDir, Line: string;
  I, EqPos: Integer;
begin
  sFN := GetIgnoredPrefixFN();
  SLF := TStringList.Create;
  Result := TStringList.Create;
  try
    SLF.LoadFromFile(sFN, TEncoding.UTF8);
    for I := 0 to SLF.Count - 1 do
    begin
      Line := SLF[I];
      if (Line = '') or (Line[1] in ['#', ';']) then
        Continue;
      Result.Add(Line);
    end;
  finally
    SLF.Free;
  end;

  FIgnoredPrefixesCount := 0;
  SetLength(FIgnoredPrefixesList, Result.Count);
  for I := 0 to Result.Count - 1 do
  begin
    FIgnoredPrefixesList[FIgnoredPrefixesCount].Prefix := Trim(Result[I]);
    if FIgnoredPrefixesList[FIgnoredPrefixesCount].Prefix[1] = '*' then
      FIgnoredPrefixesList[FIgnoredPrefixesCount].PrefixEt :=
        Copy(FIgnoredPrefixesList[FIgnoredPrefixesCount].Prefix, 2)
    else
      FIgnoredPrefixesList[FIgnoredPrefixesCount].PrefixEt := '';
    FIgnoredPrefixesList[FIgnoredPrefixesCount].PrefixLen := Length(FIgnoredPrefixesList[FIgnoredPrefixesCount].Prefix);
    Inc(FIgnoredPrefixesCount);
  end;
end;

function GetLayerPrefixIndx(const Name: string; out LIdx: Integer): boolean;
var
  I, DotPos: Integer;
  Remainder: string;
begin
  Result := False;
  LIdx := -1;
  for I := 0 to FTensorsLayersPrefixesCount - 1 do
  begin
    if (Length(Name) > FTensorsLayersPrefixesList[I].PrefixLen) then
      if (Pos(FTensorsLayersPrefixesList[I].Prefix, Name) = 1) then
      begin
        Remainder := Copy(Name, FTensorsLayersPrefixesList[I].PrefixLen + 1, MaxInt);
        DotPos := Pos('.', Remainder);
        if DotPos > 0 then
        begin
          if TryStrToInt(Copy(Remainder, 1, DotPos - 1), LIdx) then
          begin
            Result := True;
            Exit;
          end;
        end;
      end;
  end;
end;

function IsIgnoredPrefix(const Name: string): boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 0 to FIgnoredPrefixesCount - 1 do
  begin
    if (Length(Name) >= FIgnoredPrefixesList[I].PrefixLen) then
      if FIgnoredPrefixesList[I].Prefix[1] = '*' then
      begin
        if (Pos(FIgnoredPrefixesList[I].PrefixEt, Name) > 0) then
        begin
          Result := True;
          Exit;
        end;
      end
      else if (Pos(FIgnoredPrefixesList[I].Prefix, Name) = 1) then
      begin
        Result := True;
        Exit;
      end;
  end;
end;

// Extrait le nom du tenseur sans l'index de couche
// Ex: "blk.10.attn_norm.weight" -> "attn_norm.weight"
function GetTensorPatternName(const Name: string): string;
var
  I, DotPos: Integer;
  Remainder: string;
begin
  Result := Name;
  for I := 0 to FTensorsLayersPrefixesCount - 1 do
  begin
    if (Length(Name) > FTensorsLayersPrefixesList[I].PrefixLen) then
      if (Pos(FTensorsLayersPrefixesList[I].Prefix, Name) = 1) then
      begin
        Remainder := Copy(Name, FTensorsLayersPrefixesList[I].PrefixLen + 1, MaxInt);
        DotPos := Pos('.', Remainder);
        if DotPos > 0 then
        begin
          Result := Copy(Remainder, DotPos + 1, MaxInt);
          Exit;
        end;
      end;
  end;
end;

{ Gestion des Fichiers de Mapping }

function GetMappingDir: string;
begin
  Result := IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0))) + 'TNMap\';
  if not DirectoryExists(Result) then
    ForceDirectories(Result);
end;

function GetAvailableMappedNames: TStringList;
var
  Dir: string;
  SR: TSearchRec;
begin
  Result := TStringList.Create;
  Result.Add('NoMappedNames');
  Dir := GetMappingDir;
  if DirectoryExists(Dir) and (FindFirst(Dir + '*.txt', faAnyFile, SR) = 0) then
    try
      repeat
        if (SR.Attr and faDirectory) = 0 then
          Result.Add(ChangeFileExt(SR.Name, ''));
      until FindNext(SR) <> 0;
    finally
      FindClose(SR);
    end;
end;

function GetMappedNamesStrings(sFN: String; out SL: TStringList; out MappingEngine: TMappingEngine): boolean;
var
  SLF: TStringList;
  sDir, Line: string;
  I, EqPos: Integer;
begin
  Result := False;
  if not Assigned(SL) then
    SL := TStringList.Create
  else
    SL.Clear;

  sDir := GetMappingDir;
  sFN := sDir + sFN + '.txt';
  if not FileExists(sFN) then
  begin
    FreeAndNil(MappingEngine);
    MappingEngine := TMappingEngine.Create(SL);
    Exit;
  end;

  SLF := TStringList.Create;
  try
    SLF.LoadFromFile(sFN, TEncoding.UTF8);
    for I := 0 to SLF.Count - 1 do
    begin
      Line := SLF[I];
      if (Line = '') or (Line[1] in ['#', ';']) then
        Continue;
      EqPos := Pos('=', Line);
      if EqPos > 0 then
        SL.Add(Copy(Line, 1, EqPos - 1) + '=' + Copy(Line, EqPos + 1, MaxInt));
    end;
    Result := True;
  finally
    SLF.Free;
  end;

  FreeAndNil(MappingEngine);
  MappingEngine := TMappingEngine.Create(SL);
end;

{ --- Initialisation Centralisée --- }
procedure InitializeNamesSystem(var Cfg: TGlobalConfig);
begin
  // 1. Préfixes de couches (utilisé par GetLayerInfo / GetTensorPatternName)
  // if Assigned(Cfg.LayersPrefixList) then
  // FreeAndNil(Cfg.LayersPrefixList);
  // Cfg.LayersPrefixList :=
  GetLayersPrefixList();

  // 2. Préfixes ignorés
  // if Assigned(Cfg.IgnoredPrefixesList) then
  // FreeAndNil(Cfg.IgnoredPrefixesList);
  // Cfg.IgnoredPrefixesList :=
  GetIgnoredPrefixList();

  // 3. Moteurs de Mapping (Libère l'ancien, charge le fichier, crée le nouveau)
  FreeAndNil(gMapping1);
  GetMappedNamesStrings(Cfg.MappingFile1, Cfg.TensorMappings1, gMapping1);

  FreeAndNil(gMapping2);
  GetMappedNamesStrings(Cfg.MappingFile2, Cfg.TensorMappings2, gMapping2);

  FreeAndNil(gMappingS);
  GetMappedNamesStrings(Cfg.MappingFileS, Cfg.TensorMappingsS, gMappingS);
end;

{ Application & Calculs }

procedure ApplyMappingToModel(AModel: TGGUFFile; const MappingEngine: TMappingEngine; UseMappedNames: boolean);
var
  I: Integer;
  T: TGGUFTensorInfo;
begin
  if not Assigned(AModel) or not Assigned(MappingEngine) then
    Exit;
  try
    for I := 0 to AModel.Tensors.Count - 1 do
    begin
      T := TGGUFTensorInfo(AModel.Tensors[I]);
      if UseMappedNames then
      begin
        T.NameMap := MappingEngine.MapName(string(T.Name));
        T.Name := T.NameMap;
        T.IsNameMapped := T.Name <> T.NameOrg;
      end
      else
      begin
        T.Name := T.NameOrg;
        T.IsNameMapped := False;
      end;
    end;
  except
    // Log silencieux pour éviter de casser le chargement en cas d'erreur mineure
    // OutputDebugString(PChar('[TensorsNamesMan] ApplyMappingToModel: ' + Exception(ExceptObject).Message));
  end;
end;

function CalculateAllPatternSizes(M: TGGUFFile): Int64;
var
  I, SizeIdx: Integer;
  T: TGGUFTensorInfo;
  Pattern: string;
  CurrSize: Int64;
begin
  Result := 0;
  if not Assigned(M) then
    Exit;

  SetLength(gPatternCache.Patterns, 0);
  SetLength(gPatternCache.Sizes, 0);
  gPatternCache.Count := 0;

  // 1ère passe : construction du cache
  for I := 0 to M.Tensors.Count - 1 do
  begin
    T := TGGUFTensorInfo(M.Tensors[I]);
    if T.IsConverted then
      CurrSize := T.ByteSize
    else
      CurrSize := T.ByteSizeOrg;
    Inc(Result, CurrSize);
    Pattern := T.TensorPatternName;

    SizeIdx := -1;
    for SizeIdx := 0 to gPatternCache.Count - 1 do
    begin
      if gPatternCache.Patterns[SizeIdx] = Pattern then
        Break;
    end;

    // Si non trouvé, on l'ajoute au cache
    if (SizeIdx = -1) or (SizeIdx >= gPatternCache.Count) then
    begin
      SizeIdx := gPatternCache.Count;
      SetLength(gPatternCache.Patterns, SizeIdx + 1);
      SetLength(gPatternCache.Sizes, SizeIdx + 1);
      gPatternCache.Patterns[SizeIdx] := Pattern;
      gPatternCache.Sizes[SizeIdx] := 0;
      Inc(gPatternCache.Count);
    end;
    Inc(gPatternCache.Sizes[SizeIdx], CurrSize);
  end;

  // 2ème passe : attribution des tailles globales
  for I := 0 to M.Tensors.Count - 1 do
  begin
    T := TGGUFTensorInfo(M.Tensors[I]);
    Pattern := T.TensorPatternName;

    SizeIdx := -1;
    for SizeIdx := 0 to gPatternCache.Count - 1 do
    begin
      if gPatternCache.Patterns[SizeIdx] = Pattern then
      begin
        LogMsg(IntToStr(SizeIdx) + ' : ' + T.Name);
        Break;
      end;
    end;
    if SizeIdx <> -1 then
      T.PatternGlobalSize := gPatternCache.Sizes[SizeIdx]
    else
      T.PatternGlobalSize := T.ByteSize;
  end;
end;

initialization

// Initialisation propre : tout est nil. Le vrai chargement se fait via InitializeNamesSystem.
gMapping1 := nil;
gMapping2 := nil;
gMappingS := nil;
FillChar(gPatternCache, SizeOf(gPatternCache), 0);
FTensorsLayersPrefixesCount := 0;

finalization

FreeAndNil(gMapping1);
FreeAndNil(gMapping2);
FreeAndNil(gMappingS);
SetLength(gPatternCache.Patterns, 0);
SetLength(gPatternCache.Sizes, 0);
SetLength(FTensorsLayersPrefixesList, 0);

end.
