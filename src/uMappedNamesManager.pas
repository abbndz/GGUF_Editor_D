unit uMappedNamesManager;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ComCtrls,
  Vcl.Grids, Vcl.ExtCtrls, Vcl.Menus, System.Generics.Collections, uAppConfig, uTensorsNamesMan,
  uGgufStrUtils, uGGUFModel, uGGUFTypes;

type
  TFrmMappedNamesManager = class(TForm)
    PageControl1: TPageControl;
    tsMappedNames: TTabSheet;
    tsTensorPrefixes: TTabSheet;
    tsTensorIgnored: TTabSheet;
    lblIgnoredHint: TLabel;

    // Page MappedNames
    cmbMappingFile: TComboBox;
    btnNewRow: TButton;
    btnSaveMapping: TButton;
    btnReloadMapping: TButton;
    StringGrid1: TStringGrid;
    mnuGrid: TPopupMenu;
    miAddRow: TMenuItem;
    miDeleteRow: TMenuItem;
    miClearAll: TMenuItem;

    // Page Prefixes & Ignored
    edtAddPrefix: TEdit;
    edtAddIgnored: TEdit;
    btnAddPrefix: TButton;
    btnDeletePrefix: TButton;
    btnSavePrefixes: TButton;
    btnAddIgnored: TButton;
    btnDeleteIgnored: TButton;
    btnSaveIgnored: TButton;
    lvPrefixes: TListView;
    lvIgnored: TListView;
    StatusBar1: TStatusBar;
    lblPrefixHint: TLabel;
    btnDeleteRow: TButton;

    procedure FormShow(Sender: TObject);
    procedure cmbMappingFileChange(Sender: TObject);
    procedure btnSaveMappingClick(Sender: TObject);
    procedure miClearAllClick(Sender: TObject);
    procedure btnAddPrefixClick(Sender: TObject);
    procedure btnDeletePrefixClick(Sender: TObject);
    procedure btnSavePrefixesClick(Sender: TObject);
    procedure btnAddIgnoredClick(Sender: TObject);
    procedure btnDeleteIgnoredClick(Sender: TObject);
    procedure btnSaveIgnoredClick(Sender: TObject);
    procedure lvPrefixesSelectItem(Sender: TObject; Item: TListItem; Selected: Boolean);
    procedure lvIgnoredSelectItem(Sender: TObject; Item: TListItem; Selected: Boolean);
    procedure btnNewRowClick(Sender: TObject);
    procedure btnReloadMappingClick(Sender: TObject);
    procedure btnDeleteRowClick(Sender: TObject);
  private
    FCurrentMappingFile: string;
    procedure btnClearGridMapping();
    procedure LoadMappingFilesToCombo;
    procedure LoadCurrentMappingToGrid;
    // procedure SaveCurrentMappingFromFile;
    procedure LoadPrefixesToListView;
    procedure LoadIgnoredToListView;
    procedure UpdateGlobalEngines;
  public
    procedure RefreshAll;
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  end;

  // Helpers pour le reste de l'application
procedure frmEditTensorsApplyMappedNames1(sMappedNames: String);
procedure frmEditTensorsApplyMappedNames2(sMappedNames: String);
procedure frmEditTensorsApplyMappedNamesS(sMappedNames: String);

var
  frmMappedNamesManager: TFrmMappedNamesManager;

implementation

uses uEditTensors, uEditTensorsIO, uLangManager;

// Accès aux membres protégés de TStringGrid
type
  TStringGridAccess = class(TStringGrid);

{$R *.dfm}

procedure frmEditTensorsApplyMappedNames1(sMappedNames: String);
begin
  cfg.MappingFile1 := sMappedNames;
  if (sMappedNames <> 'NoMappedNames') then
  begin
    // LogMsg('Mappage "' + cfg.MappingFile1 + '" activé pour FModelInp1.');
    eLogMsg(mLang.gMsgFmt('FTE.MappingEnabled', [cfg.MappingFile1, 'Model A']))
  end
  else
  begin
    // LogMsg('Mappage désactivé pour FModelInp1.');
    eLogMsg(mLang.gMsgFmt('FTE.MappingDisabled', ['Model A']));
  end;
  // Appliquer immédiatement si modèle chargé
  GetMappedNamesStrings(cfg.MappingFile1, cfg.TensorMappings1, gMapping1);
  if Assigned(frmEditTensors.FModelInp1) then
  begin
    ApplyMappingToModel(frmEditTensors.FModelInp1, gMapping1, (sMappedNames <> 'NoMappedNames'));
    frmEditTensorsRebuildView1;
    frmEditTensorsRebuildViewOut;
  end;
  cfgSaveSettings(cfg);
end;

procedure frmEditTensorsApplyMappedNames2(sMappedNames: String);
begin
  cfg.MappingFile2 := sMappedNames;
  if (sMappedNames <> 'NoMappedNames') then
  begin
    // LogMsg('Mappage "' + cfg.MappingFile2 + '" activé pour FModelInp2.');
    eLogMsg(mLang.gMsgFmt('FTE.MappingEnabled', [cfg.MappingFile2, 'Model B']))
  end
  else
  begin
    // LogMsg('Mappage désactivé pour FModelInp2.');
    eLogMsg(mLang.gMsgFmt('FTE.MappingDisabled', ['Model B']));
  end;
  if Assigned(frmEditTensors.FModelInp2) then
  begin
    GetMappedNamesStrings(cfg.MappingFile2, cfg.TensorMappings2, gMapping2);
    ApplyMappingToModel(frmEditTensors.FModelInp2, gMapping2, (sMappedNames <> 'NoMappedNames'));
    frmEditTensorsRebuildView2;
    frmEditTensorsRebuildViewOut;
  end;
  cfgSaveSettings(cfg);
end;

procedure frmEditTensorsApplyMappedNamesS(sMappedNames: String);
begin
  cfg.MappingFileS := sMappedNames;
  if (sMappedNames <> 'NoMappedNames') then
  begin
    // LogMsg('Mappage "' + cfg.MappingFileS + '" activé pour FModelInpS.');
    eLogMsg(mLang.gMsgFmt('FTE.MappingEnabled', [cfg.MappingFileS, 'Model S']))
  end
  else
  begin
    // LogMsg('Mappage désactivé pour FModelInpS.');
    eLogMsg(mLang.gMsgFmt('FTE.MappingDisabled', ['Model S']));
  end;

  if Assigned(frmEditTensors.FModelInpS) then
  begin
    GetMappedNamesStrings(cfg.MappingFileS, cfg.TensorMappingsS, gMappingS);
    ApplyMappingToModel(frmEditTensors.FModelInpS, gMappingS, (sMappedNames <> 'NoMappedNames'));
    frmEditTensorsRebuildViewS;
    frmEditTensorsRebuildViewOut;
  end;
  cfgSaveSettings(cfg);
end;

{ TFrmMappedNamesManager }

constructor TFrmMappedNamesManager.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
end;

destructor TFrmMappedNamesManager.Destroy;
begin
  inherited Destroy;
end;

procedure TFrmMappedNamesManager.FormShow(Sender: TObject);
begin
  LoadMappingFilesToCombo;
  LoadPrefixesToListView;
  LoadIgnoredToListView;
  LoadCurrentMappingToGrid;
  StatusBar1.Panels[0].Text := 'Prêt';
end;

// GESTION DES MAPPAGES (TAB 1)
procedure TFrmMappedNamesManager.LoadMappingFilesToCombo;
var
  SR: TSearchRec;
  Dir, sMappingFile: string;
begin
  sMappingFile := cmbMappingFile.Text;
  cmbMappingFile.Items.Clear;
  cmbMappingFile.Items.Add('NoMappedNames');
  Dir := GetMappingDir;
  if DirectoryExists(Dir) then
  begin
    if FindFirst(Dir + '*.txt', faAnyFile, SR) = 0 then
      try
        repeat
          if (SR.Attr and faDirectory) = 0 then
            cmbMappingFile.Items.Add(ChangeFileExt(SR.Name, ''));
        until FindNext(SR) <> 0;
      finally
        FindClose(SR);
      end;
  end;
  cmbMappingFile.Text := sMappingFile;
end;

procedure TFrmMappedNamesManager.cmbMappingFileChange(Sender: TObject);
begin
  LoadCurrentMappingToGrid;
end;

procedure TFrmMappedNamesManager.LoadCurrentMappingToGrid;
var
  SL: TStringList;
  i: Integer;
  sDir, Line: string;
  EqPos: Integer;
begin
  FCurrentMappingFile := cmbMappingFile.Text;
  sDir := GetMappingDir();
  StringGrid1.RowCount := 2; // Header + 1 vide
  StringGrid1.Cells[0, 0] := 'Pattern';
  StringGrid1.Cells[1, 0] := 'Template';
  StringGrid1.Enabled := (FCurrentMappingFile <> 'NoMappedNames');

  if FCurrentMappingFile = 'NoMappedNames' then
    exit;

  SL := TStringList.Create;
  try
    if FileExists(sDir + FCurrentMappingFile + '.txt') then
    begin
      SL.LoadFromFile(sDir + FCurrentMappingFile + '.txt', TEncoding.UTF8);
      StringGrid1.RowCount := SL.Count + 1;
      for i := 0 to SL.Count - 1 do
      begin
        Line := SL[i];
        EqPos := Pos('=', Line);
        if EqPos > 0 then
        begin
          StringGrid1.Cells[0, i + 1] := Copy(Line, 1, EqPos - 1);
          StringGrid1.Cells[1, i + 1] := Copy(Line, EqPos + 1, MaxInt);
        end
        else
          StringGrid1.Cells[0, i + 1] := Line;
      end;
    end;
  finally
    SL.Free;
  end;
end;

procedure TFrmMappedNamesManager.btnSaveMappingClick(Sender: TObject);
var
  SL: TStringList;
  i: Integer;
  SavePath, ConfirmMsg, sDir: string;
  SaveDlg: TSaveDialog;
  IsOverwrite: Boolean;
begin
  sDir := GetMappingDir();
  if (FCurrentMappingFile = 'NoMappedNames') or not FileExists(sDir) then
  begin
    // Mode Nouveau : Forcer le "Enregistrer sous"
    SaveDlg := TSaveDialog.Create(Self);
    try
      SaveDlg.Filter := 'Fichier de mapping (*.txt)|*.txt';
      SaveDlg.DefaultExt := 'txt';
      if not SaveDlg.Execute then
        exit;
      FCurrentMappingFile := ChangeFileExt(ExtractFileName(SaveDlg.FileName), '');
    finally
      SaveDlg.Free;
    end;
  end;
  // Calcul du chemin final
  SavePath := sDir + FCurrentMappingFile + '.txt';

  // Vérification écrasement
  if FileExists(SavePath) then
  begin
    // if MessageDlg('Le fichier "' + FCurrentMappingFile + '" existe déjà. Voulez-vous l''écraser ?', mtConfirmation,
    // [mbYes, mbNo], 0) <> mrYes then
    // if MessageDlg(mLang.gMsg('FMN.FileExistsOverwrite'), mtConfirmation, [mbYes, mbNo], 0) <> mrYes then
    if MessageDlg(mLang.gMsgFmt('FMN.FileExistsOverwrite', [FCurrentMappingFile]), mtConfirmation, [mbYes, mbNo], 0) <> mrYes
    then
      exit;
  end;

  // Construction et écriture
  SL := TStringList.Create;
  try
    for i := 1 to StringGrid1.RowCount - 1 do
    begin
      if (StringGrid1.Cells[0, i] <> '') and (StringGrid1.Cells[1, i] <> '') then
        SL.Add(StringGrid1.Cells[0, i] + '=' + StringGrid1.Cells[1, i])
      else if (StringGrid1.Cells[0, i] <> '') and (StringGrid1.Cells[1, i] = '') then
        SL.Add(StringGrid1.Cells[0, i]);
    end;
    SL.SaveToFile(SavePath, TEncoding.UTF8);
    // Sync
    LoadMappingFilesToCombo;
    cmbMappingFile.Text := FCurrentMappingFile;
    LoadCurrentMappingToGrid;
    UpdateGlobalEngines;

    // StatusBar1.Panels[0].Text := 'Sauvegarde effectuée.';
    // MessageDlg('Mappage enregistré.', mtInformation, [mbOK], 0);
    StatusBar1.Panels[0].Text := mLang.gMsg('FMN.Saved');
    MessageDlg(mLang.gMsg('FMN.MappingSaved'), mtInformation, [mbOK], 0);
  finally
    SL.Free;
  end;
end;

procedure TFrmMappedNamesManager.btnClearGridMapping();
begin
  StringGrid1.RowCount := 2;
  StringGrid1.Cells[0, 1] := '';
  StringGrid1.Cells[1, 1] := '';
end;

procedure TFrmMappedNamesManager.miClearAllClick(Sender: TObject);
begin
  // if MessageDlg('Effacer tout le contenu du mappage ?', mtConfirmation, [mbYes, mbNo], 0) = mrYes then
  // btnClearMappingClick;
end;

procedure TFrmMappedNamesManager.LoadPrefixesToListView;
var
  SL: TStringList;
  i: Integer;
begin
  lvPrefixes.Items.BeginUpdate;
  try
    lvPrefixes.Items.Clear;
    SL := GetLayersPrefixList();
    try
      for i := 0 to SL.Count - 1 do
      begin
        if SL[i] <> '' then
        begin
          with lvPrefixes.Items.Add do
          begin
            Caption := IntToStr(i + 1);
            SubItems.Add(SL[i]);
          end;
        end;
      end;
    finally
      SL.Free;
    end;
  finally
    lvPrefixes.Items.EndUpdate;
  end;
end;

procedure TFrmMappedNamesManager.btnAddPrefixClick(Sender: TObject);
begin
  if Trim(edtAddPrefix.Text) <> '' then
  begin
    with lvPrefixes.Items.Add do
    begin
      Caption := IntToStr(lvPrefixes.Items.Count);
      SubItems.Add(Trim(edtAddPrefix.Text));
    end;
    edtAddPrefix.Clear;
  end;
end;

procedure TFrmMappedNamesManager.btnDeletePrefixClick(Sender: TObject);
begin
  if Assigned(lvPrefixes.Selected) then
    lvPrefixes.Items.Delete(lvPrefixes.Selected.Index);
end;

procedure TFrmMappedNamesManager.btnDeleteRowClick(Sender: TObject);
begin
  if StringGrid1.RowCount > 2 then
    TStringGridAccess(StringGrid1).DeleteRow(StringGrid1.Row);
end;

procedure TFrmMappedNamesManager.btnNewRowClick(Sender: TObject);
begin
  // Ajoute simplement une ligne vide à la fin
  StringGrid1.RowCount := StringGrid1.RowCount + 1;
  StringGrid1.Cells[0, StringGrid1.RowCount - 1] := '';
  StringGrid1.Cells[1, StringGrid1.RowCount - 1] := '';
  // StringGrid1.SelectCell(0, StringGrid1.RowCount - 1, True);
  TStringGridAccess(StringGrid1).SelectCell(0, StringGrid1.RowCount - 1);
end;

procedure TFrmMappedNamesManager.btnReloadMappingClick(Sender: TObject);
var
  OpenDlg: TOpenDialog;
  TargetFile, ImportDest: string;
  NewName: string;
begin
  // Cas 1 : Aucun fichier chargé -> On en importe un nouveau
  NewName := GetMappingDir() + cmbMappingFile.Text + '.txt';
  if (cmbMappingFile.Text = 'NoMappedNames') or (not FileExists(NewName)) then
  begin
    OpenDlg := TOpenDialog.Create(Self);
    try
      OpenDlg.Filter := 'Fichier de mapping (*.txt)|*.txt';
      OpenDlg.InitialDir := GetMappingDir();
      if OpenDlg.Execute then
      begin
        TargetFile := OpenDlg.FileName;
        NewName := ChangeFileExt(ExtractFileName(TargetFile), '');
        ImportDest := GetMappingDir + NewName + '.txt';

        // Pour que le fichier soit disponible dans le combo, on le copie dans le dossier Mapping
        if not FileExists(ImportDest) then
          if not CopyFile(PChar(TargetFile), PChar(ImportDest), false) then
          begin
            // MessageDlg('Impossible de copier le fichier dans le dossier de configuration.', mtError, [mbOK], 0);
            MessageDlg(mLang.gMsg('FMN.CopyError'), mtError, [mbOK], 0);
            exit;
          end;
        FCurrentMappingFile := NewName;
        cmbMappingFile.Text := NewName;
        LoadCurrentMappingToGrid;
        UpdateGlobalEngines;
        // StatusBar1.Panels[0].Text := 'Importation réussie : ' + NewName;
        StatusBar1.Panels[0].Text := mLang.gMsgFmt('FMN.ImportSuccess', [NewName]);
      end;
    finally
      OpenDlg.Free;
    end;
  end
  // Cas 2 : Un fichier est déjà chargé -> On recharge simplement le fichier du disque
  else
  begin
    LoadCurrentMappingToGrid;
    // StatusBar1.Panels[0].Text := 'Grille rechargée depuis le disque.';
    StatusBar1.Panels[0].Text := mLang.gMsg('FMN.Reloaded');
  end;
end;

procedure TFrmMappedNamesManager.btnSavePrefixesClick(Sender: TObject);
var
  SL: TStringList;
  i: Integer;
begin
  SL := TStringList.Create();
  for i := 0 to lvPrefixes.Items.Count - 1 do
  begin
    SL.Add(Trim(lvPrefixes.Items[i].SubItems[0]));
  end;
  SL.SaveToFile(GetLayersPrefixFN());
  cfgSaveSettings(cfg);
  LoadPrefixesToListView; // Refresh
  // StatusBar1.Panels[0].Text := 'Prefixes mis à jour.';
  StatusBar1.Panels[0].Text := mLang.gMsg('FMN.PrefixesUpdated');
end;

procedure TFrmMappedNamesManager.lvPrefixesSelectItem(Sender: TObject; Item: TListItem; Selected: Boolean);
begin
  if Selected then
    edtAddPrefix.Text := Item.SubItems[0];
end;

// GESTION IGNORED (TAB 3)
procedure TFrmMappedNamesManager.LoadIgnoredToListView;
var
  SL: TStringList;
  i: Integer;
begin
  lvIgnored.Items.BeginUpdate;
  try
    lvIgnored.Items.Clear;
    SL := GetIgnoredPrefixList();
    try
      for i := 0 to SL.Count - 1 do
      begin
        if SL[i] <> '' then
        begin
          with lvIgnored.Items.Add do
          begin
            Caption := IntToStr(i + 1);
            SubItems.Add(SL[i]);
          end;
        end;
      end;
    finally
      SL.Free;
    end;
  finally
    lvIgnored.Items.EndUpdate;
  end;
end;

procedure TFrmMappedNamesManager.btnAddIgnoredClick(Sender: TObject);
begin
  if Trim(edtAddIgnored.Text) <> '' then
  begin
    with lvIgnored.Items.Add do
    begin
      Caption := IntToStr(lvIgnored.Items.Count);
      SubItems.Add(Trim(edtAddIgnored.Text));
    end;
    edtAddIgnored.Clear;
  end;
end;

procedure TFrmMappedNamesManager.btnDeleteIgnoredClick(Sender: TObject);
begin
  if Assigned(lvIgnored.Selected) then
    lvIgnored.Items.Delete(lvIgnored.Selected.Index);
end;

procedure TFrmMappedNamesManager.btnSaveIgnoredClick(Sender: TObject);
var
  SL: TStringList;
  i: Integer;
begin
  SL := TStringList.Create();
  for i := 0 to lvIgnored.Items.Count - 1 do
  begin
    SL.Add(Trim(lvIgnored.Items[i].SubItems[0]));
  end;
  SL.SaveToFile(GetIgnoredPrefixFN());
  // cfgSaveSettings(cfg);
  LoadIgnoredToListView; // Refresh
  // StatusBar1.Panels[0].Text := 'Ignored patterns mis à jour.';
  StatusBar1.Panels[0].Text := mLang.gMsg('FMN.IgnoredUpdated');
end;

procedure TFrmMappedNamesManager.lvIgnoredSelectItem(Sender: TObject; Item: TListItem; Selected: Boolean);
begin
  if Selected then
    edtAddIgnored.Text := Item.SubItems[0];
end;

// SYNCHRONISATION GLOBALE

procedure TFrmMappedNamesManager.UpdateGlobalEngines;
var
  SL1, SL2, SLS: TStringList;
begin
  GetLayersPrefixList();
  GetIgnoredPrefixList();

  FreeAndNil(gMapping1);
  GetMappedNamesStrings(cfg.MappingFile1, cfg.TensorMappings1, gMapping1);
  // gMapping1 := TMappingEngine.Create(cfg.TensorMappings1);
  FreeAndNil(gMapping2);
  GetMappedNamesStrings(cfg.MappingFile2, cfg.TensorMappings2, gMapping2);
  // gMapping2 := TMappingEngine.Create(cfg.TensorMappings2);
  FreeAndNil(gMappingS);
  GetMappedNamesStrings(cfg.MappingFileS, cfg.TensorMappingsS, gMappingS);
  // gMappingS := TMappingEngine.Create(cfg.TensorMappingsS);

  frmEditTensors.cbMappedNames1.Items.Assign(GetAvailableMappedNames);
  frmEditTensors.cbMappedNames2.Items.Assign(frmEditTensors.cbMappedNames1.Items);
  frmEditTensors.cbMappedNamesS.Items.Assign(frmEditTensors.cbMappedNames1.Items);
end;

procedure TFrmMappedNamesManager.RefreshAll;
begin
  LoadMappingFilesToCombo;
  LoadPrefixesToListView;
  LoadIgnoredToListView;
  UpdateGlobalEngines;
end;

end.
