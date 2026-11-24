unit uTensorsNamesMan;

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections, System.Contnrs,
  uGGUFModel, uGGUFTypes, uAppConfig, uMath,uStrUtils, uLog;

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
function GetMappedNamesStrings(sFN: String; out MappingEngine: TMappingEngine): boolean;

function  ApplyMappingToModel(AModel: TGGUFFile; const MappingEngine: TMappingEngine; UseMappedNames: boolean) : Int64;
function CalculateAllPatternSizes(M: TGGUFFile): Int64;

// Initialisation centralisée après cfgLoadSettings
procedure InitializeNamesSystem(var Cfg: TGlobalConfig);

// Instances globales
var
  gMapping1, gMapping2, gMapping3, gMappingS: TMappingEngine;
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
      Continue; // ligne sans '=' : on ignore (au lieu de '' = whole line)

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
      FDirectMappings.AddOrSetValue(Pattern, Template);
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
  SLF: TStringList;
  Line: string;
  I: Integer;
begin
  sFN := GetLayersPrefixFN();

  SLF := TStringList.Create;
  Result := TStringList.Create;
  try
    try
      SLF.LoadFromFile(sFN, TEncoding.UTF8);
      for I := 0 to SLF.Count - 1 do
      begin
        Line := SLF[I];
        if (Line = '') or (Line[1] in ['#', ';']) then
          Continue;
        Result.Add(Line);
      end;
    except
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
  SLF: TStringList;
  Line, sPr: string;
  I: Integer;
begin
  sFN := GetIgnoredPrefixFN();
  SLF := TStringList.Create;
  Result := TStringList.Create;
  try
    try
      SLF.LoadFromFile(sFN, TEncoding.UTF8);
      for I := 0 to SLF.Count - 1 do
      begin
        Line := Trim(SLF[I]);
        if (Length(Line) < 3) then
          Continue;
        if (Line[1] in ['#', ';']) then
          Continue;
        Result.Add(Line);
      end;
    except
    end;
  finally
    SLF.Free;
  end;

  FIgnoredPrefixesCount := 0;
  SetLength(FIgnoredPrefixesList, Result.Count);
  for I := 0 to Result.Count - 1 do
  begin
    sPr := Trim(Result[I]);
    if sPr = '' then
      Continue;
    FIgnoredPrefixesList[FIgnoredPrefixesCount].Prefix := sPr;
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

function GetMappedNamesStrings(sFN: String; out MappingEngine: TMappingEngine): boolean;
var
  SLF: TStringList;
  sDir, Line: string;
  I, EqPos: Integer;
  SL: TStringList;
begin
  Result := False;
  SL := TStringList.Create ;

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
  GetMappedNamesStrings(Cfg.MappingFile1, gMapping1);

  FreeAndNil(gMapping2);
  GetMappedNamesStrings(Cfg.MappingFile2, gMapping2);

  FreeAndNil(gMapping3);
  GetMappedNamesStrings(Cfg.MappingFile3, gMapping3);

  FreeAndNil(gMappingS);
  GetMappedNamesStrings(Cfg.MappingFileS, gMappingS);
end;

{ Application & Calculs }

function ApplyMappingToModel(AModel: TGGUFFile; const MappingEngine: TMappingEngine; UseMappedNames: boolean) : Int64;
var
  I: Integer;
  T: TGGUFTensorInfo;
  Mapped: String;
  smName: TGgufStr;
begin
  Result := 0;
  if not Assigned(AModel) or not Assigned(MappingEngine) then
    Exit;
  for I := 0 to AModel.Tensors.Count - 1 do
  begin
    try
      T := TGGUFTensorInfo(AModel.Tensors[I]);
      if UseMappedNames then
      begin
        if T.IsNameMapped  then
        begin
          Result := Result + 1;
          Continue
        end;
        Mapped := MappingEngine.MapName(string(T.NameOrg));
        if (Mapped <> '') and (Mapped <> string(T.NameOrg)) then
        begin
          T.Name := U8ToA(Mapped);
          T.IsNameMapped := True;
          Result := Result + 1;
          // le nom a changé -> pattern + couche à recalculer
          T.TensorPatternName := GetTensorPatternName(string(T.Name));
          GetLayerPrefixIndx(string(T.Name), T.LayerIndex);
        end
        else
        begin
          T.Name := T.NameOrg;
          T.IsNameMapped := False;
        end;
      end
      else
      begin
        T.Name := T.NameOrg;
        T.IsNameMapped := False;
      end;
    except
      on e: Exception do
      //LogMsg('[MAP] ApplyMappingToModel Exception : ' + E.Message, lvWarn);
        LogW('[MAP] ApplyMappingToModel aborted after %d tensor(s): %s', [I, E.Message]);
    end;
  end;
end;

function CalculateAllPatternSizes(M: TGGUFFile): Int64;
var
  ii, jj, SizeIdx: Integer;
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
  for ii := 0 to M.Tensors.Count - 1 do
  begin
    T := TGGUFTensorInfo(M.Tensors[ii]);
    if not T.Keep then
      Continue;
    if T.IsConverted then
      CurrSize := T.ByteSize
    else
      CurrSize := T.ByteSizeOrg;
    Inc(Result, CurrSize);
    Pattern := T.TensorPatternName;

    SizeIdx := -1;
    for jj := 0 to gPatternCache.Count - 1 do
    begin
      if gPatternCache.Patterns[jj] = Pattern then
      begin
        SizeIdx := jj;
        Break;
      end;
    end;

    // Si non trouvé, on l'ajoute au cache
    if (SizeIdx = -1) or (jj >= gPatternCache.Count) then
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
  for ii := 0 to M.Tensors.Count - 1 do
  begin
    T := TGGUFTensorInfo(M.Tensors[ii]);
    if not T.Keep then
      Continue;
    Pattern := T.TensorPatternName;

    SizeIdx := -1;
    for jj := 0 to gPatternCache.Count - 1 do
    begin
      if gPatternCache.Patterns[jj] = Pattern then
      begin
        // LogMsg(IntToStr(jj) + ' : ' + T.Name);
        SizeIdx := jj;
        Break;
      end;
    end;
    if (SizeIdx <> -1) then
      T.PatternGlobalSize := gPatternCache.Sizes[SizeIdx]
    else
      T.PatternGlobalSize := T.ByteSize;
  end;
end;

initialization

// Initialisation propre : tout est nil. Le vrai chargement se fait via InitializeNamesSystem.
gMapping1 := nil;
gMapping2 := nil;
gMapping3 := nil;
gMappingS := nil;
FillChar(gPatternCache, SizeOf(gPatternCache), 0);
FTensorsLayersPrefixesCount := 0;

finalization

FreeAndNil(gMapping1);
FreeAndNil(gMapping2);
FreeAndNil(gMapping3);
FreeAndNil(gMappingS);
SetLength(gPatternCache.Patterns, 0);
SetLength(gPatternCache.Sizes, 0);
SetLength(FTensorsLayersPrefixesList, 0);

end.
