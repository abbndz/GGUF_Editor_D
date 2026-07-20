unit uLangManager;

interface

uses
  SysUtils, Classes, IniFiles, Forms, Controls, ComCtrls, Menus, StdCtrls, Dialogs, ExtCtrls, Windows, Variants;

type
  TLangManager = class
  private
    FLangDir: string;
    LangCount: Integer;
    FLangCodes: TStringList;
    FCurrentLang: string;
    FIni, FIniFallback: TMemIniFile;
    FCurrentIniFile: string;
    FFallbackLang: string; // 'fr' ou 'en'
    procedure LoadIniFallback;
    procedure LoadIni;
    procedure ScanLanguages;

    function GetCompKey(AFormName, ACompName: string): string;
    procedure TranslateComponent(AComp: TComponent; AFormName: string);
    procedure TranslateMenu(AMenu: TMainMenu);

  public
    constructor Create(const ALangDir: string = '');
    destructor Destroy; override;

    function gMsg(const AKey: string; const ASection: string = 'Messages'): string;
    function gMsgFmt(const AKey: string; const Args: array of const; const ASection: string = 'Messages'): string;

    /// <summary>
    /// Retourne une liste de noms natifs (ex: 'العربية', 'Français').
    /// L'index dans cette liste correspond à l'ISO code via GetISOCodeByIndex.
    /// </summary>
    function GetListLangues: TStrings;
    function GetLangCount: Integer;

    /// <summary>
    /// Récupère le code ISO correspondant à un natif nanguage name.
    /// </summary>
    function GetISOCodeByNativeLanguageName(langName: string): string;

    /// <summary>
    /// Convertit un code ISO en nom natif. Fallback: retourne le code lui-même.
    /// Supporte 25+ langues.
    /// </summary>
    function GetNativeLanguageName(const ISOCode: string): string;

    /// <summary>
    /// Définit la langue active (Stub : à connecter avec votre chargement INI)
    /// </summary>
    procedure SetLanguage(const ISOCode: string);

    /// <summary>
    /// Applique les traductions sur un formulaire (Stub : à implémenter)
    /// </summary>
    procedure Translate(AForm: TForm);

    function GetMissingTranslations(AForm: TForm): TStrings;

    procedure GenerateFile(AForm: TForm; const ALang: string);

  end;

function GetSystemLanguageISO: string;

var
  mLang: TLangManager;

implementation

{ TLangManager }

constructor TLangManager.Create(const ALangDir: string);
begin
  inherited Create;
  LangCount := 0;
  FLangCodes := TStringList.Create;
  if ALangDir = '' then
    FLangDir := IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0))) + 'lang\'
  else
    FLangDir := IncludeTrailingPathDelimiter(ALangDir);
  ScanLanguages;
  // Détection fallback EN/FR
  if FLangCodes.IndexOf('EN') >= 0 then
    FFallbackLang := 'EN'
  else if FLangCodes.IndexOf('FR') >= 0 then
    FFallbackLang := 'FR'
  else
    FFallbackLang := 'EN';
  LoadIniFallback;
end;

destructor TLangManager.Destroy;
begin
  FIni.Free;
  FIniFallback.Free;
  FLangCodes.Free;
  inherited;
end;

procedure TLangManager.ScanLanguages;
var
  SR: TSearchRec;
  ISOCode: string;
begin
  FLangCodes.Clear;
  if not DirectoryExists(FLangDir) then
    Exit;

  if FindFirst(FLangDir + '*.ini', faAnyFile, SR) = 0 then
    try
      repeat
        if (SR.Attr and faDirectory) = 0 then
        begin
          // Extrait le code ISO (ex: lang/fr.ini -> FR)
          ISOCode := UpperCase(ChangeFileExt(ExtractFileName(SR.Name), ''));
          FLangCodes.Add(ISOCode);
        end;
      until FindNext(SR) <> 0;
    finally
      SysUtils.FindClose(SR);
      LangCount := FLangCodes.Count;
    end;
end;

function TLangManager.GetLangCount: Integer;
begin
  result := 0;
  if Assigned(FLangCodes) then
    result := FLangCodes.Count;
end;

// Fonction helper pour mapper le Language ID Windows vers format ISO
// Cette fonction doit être en phase avec GetNativeLanguageName
function GetSystemLanguageISO: string;
var
  LangID: Word;
begin
  // GetUserDefaultUILanguage retourne un Word (ex: $040C pour le Français)
  LangID := GetUserDefaultUILanguage;

  // On utilise le masque $FFF0 pour ignorer la région (ex: $040C pour FR, $080C pour Canada)
  // et ne garder que la langue principale.
  case LangID and $FFF0 of
    $0401:
      result := 'ar'; // Arabic
    $0403:
      result := 'cs'; // Czech
    $0407:
      result := 'de'; // German
    $0408:
      result := 'it'; // Italian
    $0409:
      result := 'en'; // English
    $040A:
      result := 'es'; // Spanish
    $040C:
      result := 'fr'; // French
    $040D:
      result := 'he'; // Hebrew
    $0411:
      result := 'ja'; // Japanese
    $0412:
      result := 'ko'; // Korean
    $0413:
      result := 'nl'; // Dutch
    $0415:
      result := 'pl'; // Polish
    $0416:
      result := 'pt'; // Portuguese
    $0419:
      result := 'ru'; // Russian
    $041A:
      result := 'sv'; // Swedish
    $041B:
      result := 'uk'; // Ukrainian
    $041E:
      result := 'hi'; // Hindi (Note: $041E est aussi utilisé pour Hungarian dans certains contextes)
    $041F:
      result := 'tr'; // Turkish
    $0421:
      result := 'id'; // Indonesian
    $042A:
      result := 'vi'; // Vietnamese
    $042C:
      result := 'fi'; // Finnish
    $0440:
      result := 'el'; // Greek
    $0464:
      result := 'da'; // Danish
    $042F:
      result := 'fa'; // Persian
    $042E:
      result := 'hu'; // Hungarian (Alternative ID selon les versions de Windows)
    $0E01:
      result := 'th'; // Thai
    // Gestion spécifique du Chinois
    $0804:
      result := 'zh_cn'; // Chinese (Simplified)
    $0C04:
      result := 'zh_tw'; // Chinese (Traditional)

  else
    // Si la langue n'est pas reconnue, on retourne 'en' par défaut
    result := 'en';
  end;
end;

function TLangManager.GetNativeLanguageName(const ISOCode: string): string;
var
  Code: string;
begin
  Code := LowerCase(ISOCode);

  if Code = 'ar' then
    result := 'العربية'
  else if Code = 'zh_cn' then
    result := '中文(简体)'
  else if Code = 'zh_tw' then
    result := '中文(繁體)'
  else if Code = 'cs' then
    result := 'Čeština'
  else if Code = 'da' then
    result := 'Dansk'
  else if Code = 'nl' then
    result := 'Nederlands'
  else if Code = 'en' then
    result := 'English'
  else if Code = 'fi' then
    result := 'Suomi'
  else if Code = 'fr' then
    result := 'Français'
  else if Code = 'de' then
    result := 'Deutsch'
  else if Code = 'el' then
    result := 'Ελληνικά'
  else if Code = 'he' then
    result := 'עברית'
  else if Code = 'hi' then
    result := 'हिन्दी'
  else if Code = 'hu' then
    result := 'Magyar'
  else if Code = 'id' then
    result := 'Bahasa Indonesia'
  else if Code = 'it' then
    result := 'Italiano'
  else if Code = 'ja' then
    result := '日本語'
  else if Code = 'ko' then
    result := '한국어'
  else if Code = 'pl' then
    result := 'Polski'
  else if Code = 'pt' then
    result := 'Português'
  else if Code = 'ru' then
    result := 'Русский'
  else if Code = 'es' then
    result := 'Español'
  else if Code = 'sv' then
    result := 'Svenska'
  else if Code = 'th' then
    result := 'ไทย'
  else if Code = 'tr' then
    result := 'Türkçe'
  else if Code = 'uk' then
    result := 'Українська'
  else if Code = 'vi' then
    result := 'Tiếng Việt'
  else if Code = 'fa' then
    result := 'فارسی'
  else
    result := ISOCode; // Fallback : retourne le code fourni
end;

function TLangManager.GetListLangues: TStrings;
var
  i: Integer;
begin
  result := TStringList.Create;
  for i := 0 to FLangCodes.Count - 1 do
    result.Add(GetNativeLanguageName(FLangCodes[i]));
end;

function TLangManager.GetISOCodeByNativeLanguageName(langName: string): string;
begin
  if pos('العربية', langName) > 0 then
    result := 'ar'
  else if pos('Čeština', langName) > 0 then
    result := 'cs'
  else if langName = 'Dansk' then
    result := 'da'
  else if langName = 'Nederlands' then
    result := 'nl'
  else if langName = 'English' then
    result := 'en'
  else if langName = 'Suomi' then
    result := 'fi'
  else if langName = 'Français' then
    result := 'fr'
  else if langName = 'Deutsch' then
    result := 'de'
  else if pos('Ελληνικά', langName) > 0 then
    result := 'el'
  else if pos('עברית', langName) > 0 then
    result := 'he'
  else if pos('हिन्दी', langName) > 0 then
    result := 'hi'
  else if langName = 'Magyar' then
    result := 'hu'
  else if langName = 'Bahasa Indonesia' then
    result := 'id'
  else if langName = 'Italiano' then
    result := 'it'
  else if pos('日本語', langName) > 0 then
    result := 'ja'
  else if pos('한국어', langName) > 0 then
    result := 'ko'
  else if langName = 'Polski' then
    result := 'pl'
  else if langName = 'Português' then
    result := 'pt'
  else if langName = 'Русский' then
    result := 'ru'
  else if langName = 'Español' then
    result := 'es'
  else if langName = 'Svenska' then
    result := 'sv'
  else if pos('ไทย', langName) > 0 then
    result := 'th'
  else if pos('Türkçe', langName) > 0 then
    result := 'tr'
  else if pos('Українська', langName) > 0 then
    result := 'uk'
  else if pos('Tiếng Việt', langName) > 0 then
    result := 'vi'
  else if pos('فارسی', langName) > 0 then
    result := 'fa'
  else if (pos('中文', langName) > 0) and (pos('简体', langName) > 0) then
    result := 'zh_cn'
  else if (pos('中文', langName) > 0) and (pos('繁體)', langName) > 0) then
    result := 'zh_tw'
  else if (pos('中文', langName) > 0) then
    result := 'zh'
  else
    result := langName;
end;

procedure TLangManager.LoadIniFallback;
var
  FallbackFile: string;
begin
  if Assigned(FIniFallback) then
    FIniFallback.Free;
  FallbackFile := FLangDir + FFallbackLang + '.ini';
  if FileExists(FallbackFile) then
    FIniFallback := TMemIniFile.Create(FallbackFile, TEncoding.UTF8)
  else
    FIniFallback := TMemIniFile.Create(FLangDir + 'default.ini', TEncoding.UTF8);
end;

procedure TLangManager.LoadIni;
begin
  if Assigned(FIni) then
  begin
    // FIni.CloseFile;
    // FIni.UpdateFile
    FIni.Free;
    FIni := nil;
  end;
  LoadIniFallback;
  FCurrentIniFile := FLangDir + FCurrentLang + '.ini';
  if FileExists(FCurrentIniFile) then
    FIni := TMemIniFile.Create(FCurrentIniFile, TEncoding.UTF8)
  else if Assigned(FIni) then
  begin
    // FIni.CloseFile;
    // FIni.UpdateFile
    FIni.Free;
    FIni := nil;
  end;
end;

procedure TLangManager.SetLanguage(const ISOCode: string);
begin
  if FCurrentLang <> ISOCode then
  begin
    FCurrentLang := ISOCode;
    LoadIni;
  end;
end;

function TLangManager.GetCompKey(AFormName, ACompName: string): string;
begin
  result := AFormName + '.' + ACompName;
end;

procedure TLangManager.TranslateComponent(AComp: TComponent; AFormName: string);
var
  Section, Caption, Hint: string;
begin
  if (FIni = nil) then
    Exit;

  Section := GetCompKey(AFormName, AComp.Name);

  // Gestion Caption
  Caption := FIni.ReadString(Section, 'Caption', '');
  if Caption <> '' then
  begin
    // REMPLACER le délimiteur personnalisé par un vrai retour à la ligne
    Caption := StringReplace(Caption, '\n', sLineBreak, [rfReplaceAll]);
    Caption := StringReplace(Caption, '\r', sLineBreak, [rfReplaceAll]);

    if AComp is TLabel then
      TLabel(AComp).Caption := Caption
    else if AComp is TButton then
      TButton(AComp).Caption := Caption
    else if AComp is TCheckBox then
      TCheckBox(AComp).Caption := Caption
    else if AComp is TRadioButton then
      TRadioButton(AComp).Caption := Caption
    else if AComp is TGroupBox then
      TGroupBox(AComp).Caption := Caption
    else if AComp is TMenuItem then
    begin
      TMenuItem(AComp).Caption := Caption;
    end
    else if AComp is TStaticText then
      TStaticText(AComp).Caption := Caption
    else if AComp is TForm then
      TForm(AComp).Caption := Caption
    else if AComp is TTabSheet then
      TTabSheet(AComp).Caption := Caption;
  end;
  // Gestion Hint avec support \n et \r
  Hint := FIni.ReadString(Section, 'Hint', '');
  if Hint = '' then
    Hint := Caption;
  if Hint <> '' then
  begin
    Hint := StringReplace(Hint, '\n', sLineBreak, [rfReplaceAll]);
    Hint := StringReplace(Hint, '\r', sLineBreak, [rfReplaceAll]);
    // AComp.Hint := Hint;
    if AComp is TLabel then
    begin
      TLabel(AComp).Hint := Hint;
      TLabel(AComp).ShowHint := True;
    end
    else if AComp is TButton then
    begin
      TButton(AComp).Hint := Hint;
      TButton(AComp).ShowHint := True;
    end
    else if AComp is TCheckBox then
    begin
      TCheckBox(AComp).Hint := Hint;
      TCheckBox(AComp).ShowHint := True;
    end
    else if AComp is TRadioButton then
    begin
      TRadioButton(AComp).Hint := Hint;
      TRadioButton(AComp).ShowHint := True;
    end
    else if AComp is TGroupBox then
    begin
      TGroupBox(AComp).Hint := Hint;
      TGroupBox(AComp).ShowHint := True;
    end
    else if AComp is TMenuItem then
    begin
      TMenuItem(AComp).Hint := Hint;
      // TMenuItem(AComp).ShowHint := True;
    end
    else if AComp is TStaticText then
    begin
      TStaticText(AComp).Hint := Hint;
      TStaticText(AComp).ShowHint := True;
    end
    else if AComp is TEdit then
    begin
      TEdit(AComp).Hint := Hint;
      TEdit(AComp).ShowHint := True;
    end
    else if AComp is TComboBox then
    begin
      TComboBox(AComp).Hint := Hint;
      TComboBox(AComp).ShowHint := True;
    end
    else if AComp is TCustomLabel then
    begin
      TCustomLabel(AComp).Hint := Hint;
      TCustomLabel(AComp).ShowHint := True
    end
    else if AComp is TCustomEdit then
    begin
      TCustomEdit(AComp).Hint := Hint;
      TCustomEdit(AComp).ShowHint := True
    end
    else if AComp is TCustomComboBox then
    begin
      TCustomComboBox(AComp).Hint := Hint;
      TCustomComboBox(AComp).ShowHint := True
    end
    else if AComp is TCustomButton then
    begin
      TCustomButton(AComp).Hint := Hint;
      TCustomButton(AComp).ShowHint := True
    end
    else if AComp is TTabSheet then
    begin
      TTabSheet(AComp).Hint := Hint;
      TTabSheet(AComp).ShowHint := True;
    end
    else if AComp is TCustomCheckBox then
    begin
      TCustomCheckBox(AComp).Hint := Hint;
      TCustomCheckBox(AComp).ShowHint := True;
    end;
  end;
end;

procedure TLangManager.TranslateMenu(AMenu: TMainMenu);
var
  i: Integer;
  procedure RecurseMenu(AMenuItem: TMenuItem; const AFormName: string);
  var
    i: Integer;
  begin
    TranslateComponent(AMenuItem, AFormName);
    for i := 0 to AMenuItem.Count - 1 do
      RecurseMenu(AMenuItem.Items[i], AFormName);
  end;

begin
  if AMenu = nil then
    Exit;
  for i := 0 to AMenu.Items.Count - 1 do
    RecurseMenu(AMenu.Items[i], AMenu.Owner.ClassName);
end;

procedure TLangManager.Translate(AForm: TForm);
var
  i: Integer;
  Comp: TComponent;
begin
  if (FIni = nil) then
    Exit;
  // 1. Traduire la Form elle-même
  TranslateComponent(AForm, AForm.ClassName);
  // 2. Traduire tous les composants (y compris dans les Panels/Groupbox)
  for i := -1 to AForm.ComponentCount - 1 do
  begin
    if i = -1 then
      Comp := AForm
    else
      Comp := AForm.Components[i];
    // On ne traduit que si le composant appartient physiquement à la fiche
    if (Comp.Owner = AForm) or (Comp is TForm) then
    begin
      TranslateComponent(Comp, AForm.ClassName);
      // Si c'est un menu, on traite récursivement les sous-items
      if Comp is TMainMenu then
        TranslateMenu(TMainMenu(Comp));
    end;
  end;
end;

function TLangManager.gMsg(const AKey: string; const ASection: string = 'Messages'): string;
begin
  // result := AKey; Exit;
  result := '';
  if Assigned(FIni) then
    result := FIni.ReadString(ASection, AKey, '');
  if (result = '') and Assigned(FIniFallback) then
    result := FIniFallback.ReadString(ASection, AKey, '');
  if result = '' then
    result := AKey; // Fallback debug
  if result <> '' then
  begin
    result := StringReplace(result, '\n', sLineBreak, [rfReplaceAll]);
    result := StringReplace(result, '\r', sLineBreak, [rfReplaceAll]);
  end;
end;

function TLangManager.gMsgFmt(const AKey: string; const Args: array of const;
  const ASection: string = 'Messages'): string;
var
  i: Integer;
  Placeholder: string;
  ValueStr: string;
  Rec: TVarRec;
begin
  // result := AKey; Exit;
  result := '';
  result := gMsg(AKey, ASection);
  if result = AKey then
    Exit;
  for i := 0 to High(Args) do
  begin
    Placeholder := '{' + IntToStr(i) + '}';
    Rec := Args[i];
    ValueStr := '';
    case Rec.VType of
      // --- LES VALEURS DIRECTES (Pas de pointeur) ---
      vtInteger:
        ValueStr := IntToStr(Rec.VInteger);
      vtBoolean:
        ValueStr := BoolToStr(Rec.VBoolean, True);
      vtChar:
        ValueStr := Rec.VChar;
      // --- LES POINTEURS (On doit utiliser ^ pour lire la valeur) ---
      vtInt64:
        ValueStr := IntToStr(Rec.VInt64^);
      // Pour les strings, on cast le pointeur vers le bon type de chaîne, puis on déréférence
      vtString:
        ValueStr := string(Rec.VString^);
      vtAnsiString:
        ValueStr := string(PAnsiString(Rec.VAnsiString^));
      vtUnicodeString:
        ValueStr := string(PWideChar(Rec.VPWideChar));
      // Pour les nombres flottants (souvent des pointeurs dans TVarRec)
      vtExtended:
        ValueStr := FloatToStr(Rec.VExtended^);
      { vtDouble:
        ValueStr := FloatToStr(Rec.VDouble^); }
    else
      ValueStr := '';
    end;
    if Placeholder <> '' then
      result := StringReplace(result, Placeholder, ValueStr, [rfReplaceAll]);
  end;
end;

function TLangManager.GetMissingTranslations(AForm: TForm): TStrings;
var
  i: Integer;
  Comp: TComponent;
  Section, Cap, Hnt, ACap, AHnt: string;
  FormName: string;
begin
  result := TStringList.Create;
  FormName := AForm.ClassName;
  // if (FIni = nil) or (FIni.IniLoaded = False) then Exit;
  if (FIni = nil) then
    Exit;

  for i := -1 to AForm.ComponentCount - 1 do
  begin
    if i = -1 then
      Comp := AForm
    else
      Comp := AForm.Components[i];
    if Comp.Owner = AForm then
    begin
      // Pour la Form elle-même
      if Comp is TForm then
        Section := Comp.Name
      else
        Section := GetCompKey(FormName, Comp.Name);

      // Vérifier Caption
      if Comp is TForm then
        Cap := TForm(Comp).Caption
      else if Comp is TLabel then
        Cap := TLabel(Comp).Caption
      else if Comp is TButton then
        Cap := TButton(Comp).Caption
      else if Comp is TCheckBox then
        Cap := TCheckBox(Comp).Caption
      else if Comp is TGroupBox then
        Cap := TGroupBox(Comp).Caption
      else if Comp is TMenuItem then
        Cap := TMenuItem(Comp).Caption
      else if Comp is TStaticText then
        Cap := TStaticText(Comp).Caption
      else if Comp is TRadioButton then
        Cap := TRadioButton(Comp).Caption;
      ACap := FIni.ReadString(Section, 'Caption', '');
      if (ACap = '') and (Cap <> '') then
        result.Add('[Caption] ' + Comp.Name);
      // Vérifier Hint
      AHnt := FIni.ReadString(Section, 'Hint', '');
      if Comp is TLabel then
        Hnt := TLabel(Comp).Hint
      else if Comp is TButton then
        Hnt := TButton(Comp).Hint
      else if Comp is TCheckBox then
        Hnt := TCheckBox(Comp).Hint
      else if Comp is TGroupBox then
        Hnt := TGroupBox(Comp).Hint
      else if Comp is TMenuItem then
        Hnt := TMenuItem(Comp).Hint
      else if Comp is TStaticText then
        Hnt := TStaticText(Comp).Hint
      else if Comp is TEdit then
        Hnt := TEdit(Comp).Hint
      else if Comp is TComboBox then
        Hnt := TComboBox(Comp).Hint;
      // if (Hint = '') and (Comp.Hint <> '') then
      if (AHnt = '') and (Hnt <> '') then
        result.Add('[Hint] ' + Comp.Name);
    end;
  end;
end;

procedure TLangManager.GenerateFile(AForm: TForm; const ALang: string);
var
  Ini: TMemIniFile;
  LangDir, FileName, Section: string;
  i: Integer;
  Comp: TComponent;
  Cap, Hnt: string;
  OwnerName: string;
begin
  LangDir := IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0))) + 'lang\';
  if not DirectoryExists(LangDir) then
    ForceDirectories(LangDir);
  FileName := LangDir + ALang + '.ini';

  Ini := TMemIniFile.Create(FileName, TEncoding.UTF8);
  try

    for i := -1 to AForm.ComponentCount - 1 do
    begin
      if i = -1 then
        Comp := AForm
      else
        Comp := AForm.Components[i];
      // On ignore les composants qui ne sont pas rattachés à la fiche (ex: DataModules)
      if (Comp.Owner = nil) then
        Continue;
      if ((Comp.Owner.ClassName <> AForm.ClassName) and not(Comp is TMenuItem)) and not(Comp is TForm) then
        Continue;
      // Gestion du propriétaire pour la section
      if Comp is TForm then
        OwnerName := Comp.ClassName
      else if Comp is TMenuItem then
        OwnerName := Comp.Owner.ClassName
      else
        OwnerName := Comp.Owner.ClassName;
      Section := OwnerName + '.' + Comp.Name;
      Cap := '';
      Hnt := '';
      // Extraction de la Caption selon le type
      if Comp is TForm then
        Cap := TForm(Comp).Caption
      else if Comp is TLabel then
        Cap := TLabel(Comp).Caption
      else if Comp is TButton then
        Cap := TButton(Comp).Caption
      else if Comp is TCheckBox then
        Cap := TCheckBox(Comp).Caption
      else if Comp is TGroupBox then
        Cap := TGroupBox(Comp).Caption
      else if Comp is TMenuItem then
        Cap := TMenuItem(Comp).Caption
      else if Comp is TStaticText then
        Cap := TStaticText(Comp).Caption
      else if Comp is TRadioButton then
        Cap := TRadioButton(Comp).Caption
      else if Comp is TStaticText then
        Cap := TStaticText(Comp).Caption;

      // Extraction du Hint
      if Comp is TLabel then
        Hnt := TLabel(Comp).Hint
      else if Comp is TButton then
        Hnt := TButton(Comp).Hint
      else if Comp is TCheckBox then
        Hnt := TCheckBox(Comp).Hint
      else if Comp is TGroupBox then
        Hnt := TGroupBox(Comp).Hint
      else if Comp is TMenuItem then
        Hnt := TMenuItem(Comp).Hint
      else if Comp is TStaticText then
        Hnt := TStaticText(Comp).Hint
      else if Comp is TEdit then
        Hnt := TEdit(Comp).Hint
      else if Comp is TComboBox then
        Hnt := TComboBox(Comp).Hint;

      // Écriture seulement si nécessaire
      if (Cap <> '') or (Hnt <> '') then
      begin
        if Cap <> '' then
        begin
          // REMPLACER le délimiteur personnalisé par un vrai retour à la ligne
          Cap := StringReplace(Cap, #10, '\n', [rfReplaceAll]);
          Cap := StringReplace(Cap, #13, '\r', [rfReplaceAll]);
          Ini.WriteString(Section, 'Caption', Cap);
        end;
        if Hnt <> '' then
        begin
          Hnt := StringReplace(Hnt, #10, '\n', [rfReplaceAll]);
          Hnt := StringReplace(Hnt, #13, '\r', [rfReplaceAll]);
          Ini.WriteString(Section, 'Hint', Hnt);
        end;
      end;
    end;
    // ShowMessage('Génération terminée : ' + FileName);
  finally
    Ini.UpdateFile;
    Ini.Free;
  end;
end;

end.
