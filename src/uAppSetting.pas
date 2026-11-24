unit uAppSetting;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants,
  System.Classes, Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs,
  Vcl.StdCtrls, uAppConfig, Vcl.ComCtrls, uMath, uTensorsNamesMan;

type
  TfrmSettings = class(TForm)
    PageControl1: TPageControl;
    TabSheet1: TTabSheet;
    TabSheet2: TTabSheet;
    chkSaveMetaSeparate: TCheckBox;
    lblSplitHint: TLabel;
    cmbSplitSize: TComboBox;
    lblDiffScale: TLabel;
    edtDiffScale: TEdit;
    edtHistBars: TEdit;
    edtPtsPerBin: TEdit;
    edtNumBins: TEdit;
    chkShowBlockS: TCheckBox;
    lblNumBins: TLabel;
    lblPtsPerBin: TLabel;
    lblHistStride: TLabel;
    lblNVFP4Hint: TLabel;
    edtNVFP4: TEdit;
    btnApply: TButton;
    btnSave: TButton;
    btnCancel: TButton;
    lblSamplingBins: TLabel;
    chkShowOutlierS: TCheckBox;
    chkAutoSignature: TCheckBox;
    edtSignatureText: TEdit;
    cbUseImpl: TComboBox;
    lblUseImpl: TLabel;
    cbRmseType: TComboBox;
    lblRmseType: TLabel;
    cbReaderMode: TComboBox;
    edtChunkKb: TEdit;
    edtCapMb: TEdit;
    chkCapAuto: TCheckBox;
    lblChunkKb: TLabel;
    lblReaderMode: TLabel;
    edtExportDelim: TEdit;
    lblDelimiter: TLabel;
    cbGgmlDll: TComboBox;
    btnDllBrowse: TButton;
    procedure FormShow(Sender: TObject);
    procedure chkSaveMetaSeparateClick(Sender: TObject);
    procedure chkShowBlockSClick(Sender: TObject);
    procedure btnSaveClick(Sender: TObject);
    procedure btnApplyClick(Sender: TObject);
    procedure btnCancelClick(Sender: TObject);
    procedure chkShowOutlierSClick(Sender: TObject);
    procedure cbRmseTypeChange(Sender: TObject);
    procedure cbUseImplChange(Sender: TObject);
    procedure chkCapAutoClick(Sender: TObject);
    procedure btnDllBrowseClick(Sender: TObject);
  private
    procedure SetCfgFromUi(var c: TGlobalConfig);
    procedure SetUiFromCfg(var c: TGlobalConfig);
    /// Remplit cbGgmlDll depuis cfg.GgmlDllHistory et selectionne le nom courant
    procedure GgmlDllFill;
  public
    { D�clarations publiques }
  end;

var
  frmSettings: TfrmSettings;

implementation

uses uLog, uStrUtils, uEditTensors, uLangManager, uTensorStreamReader,
uViewTensors, uFullDiffPipeline, uGGMLTypes, uGGMLConstants;

{$R *.dfm}


{ ============================================================================
  Chemin de la DLL ggml.  L'ecriture se fait dans cfg_ggml_type.ini
  ([General] DLLName) : c'est LA cle lue par TGGMLRegistry.LoadFromIni au
  demarrage -> effet au PROCHAIN LANCEMENT, aucun rechargement a chaud (donc
  aucun risque de FreeLibrary sous un Dequant/Quant en cours).
  cbGgmlDll n'est qu'un raccourci vers l'historique (cfg.GgmlDllHistory).
============================================================================ }

procedure TfrmSettings.GgmlDllFill;
var
  i: Integer;
  Cur: string;
begin
  Cur := cfgGgmlDllName;
  cbGgmlDll.Items.BeginUpdate;
  try
    cbGgmlDll.Items.Clear;
    cbGgmlDll.Items.Add(Cur);            // le courant toujours en tete
    if cfg.GgmlDllHistory <> nil then
      for i := 0 to cfg.GgmlDllHistory.Count - 1 do
        if cbGgmlDll.Items.IndexOf(cfg.GgmlDllHistory[i]) < 0 then
          cbGgmlDll.Items.Add(cfg.GgmlDllHistory[i]);
  finally
    cbGgmlDll.Items.EndUpdate;
  end;
  cbGgmlDll.ItemIndex := 0;
  if cfg.ggmlReg.IsDllLoaded then
    cbGgmlDll.Hint := 'chargée : ' + cfg.ggmlReg.DllResolved +
      #13'Toute modification est appliquée au prochain lancement.'
  else
    cbGgmlDll.Hint := 'DLL non chargée -> mode natif Delphi.' +
      #13'Toute modification est appliquée au prochain lancement.';
end;

procedure TfrmSettings.SetCfgFromUi(var c: TGlobalConfig);
begin
  c.UseImpl := cbUseImpl.ItemIndex;
  c.RmseType := cbRmseType.ItemIndex;
  if c.UseImpl < 0 then
    c.UseImpl := 2;
  if c.RmseType < 0 then
    c.RmseType := 3;

  c.SaveMetaSeparate := chkSaveMetaSeparate.Checked;
  c.SplitSizeMbGbStr := cmbSplitSize.Text;
  c.SplitSizeMBytes := UnFormatSizeStrMbGb(c.SplitSizeMbGbStr);

  c.UseAutoSignature := chkAutoSignature.Checked;
  c.AutoSignatureTemplate := edtSignatureText.Text;

  c.VFP_Scale := StrToFloatDef(edtNVFP4.Text, 0.000081380208333);

  // VISUALISATION
  c.TVNumBins := StrToIntDef(edtNumBins.Text, 1024);
  c.TVNumBins   := ClampInt(c.TVNumBins, 32, 16384);
  c.TVPtsPerBin := StrToIntDef(edtPtsPerBin.Text, 32);
  c.TVPtsPerBin := ClampInt(c.TVPtsPerBin, 2, 2048);

  c.HistMaxBars := StrToIntDef(edtHistBars.Text, 64);


  c.bShowOutlierS := chkShowOutlierS.Checked;

  c.bShowBlockS := chkShowBlockS.Checked;

  c.ExportDelimiter := edtExportDelim.Text;
  c.DiffAmplificationFactor := Max(0.1, StrToFloatDef(edtDiffScale.Text, 1.0));

  c.IOReaderMode := TCombo_GetSel(cbReaderMode, 0);
  if chkCapAuto.Checked then c.IOMapCapMb := 0
  else c.IOMapCapMb := ClampInt(TEdit_ReadInt(edtCapMb, 0), 16, 262144);
  c.IOChunkKb := ClampInt(TEdit_ReadInt(edtChunkKb, 0), 0, 65536);

end;

procedure TfrmSettings.SetUiFromCfg(var c: TGlobalConfig);
begin
  // GENERAL
  if c.UseImpl < 0 then
    c.UseImpl := 2;
  if c.RmseType < 0 then
    c.RmseType := 3;

  cbUseImpl.ItemIndex := Max(0, Min(c.UseImpl, cbUseImpl.Items.Count - 1));
  cbRmseType.ItemIndex := Max(0, Min(c.RmseType, cbRmseType.Items.Count - 1));

  chkSaveMetaSeparate.Checked := c.SaveMetaSeparate;

  cmbSplitSize.Text := c.SplitSizeMbGbStr;
  edtDiffScale.Text := FloatToStr(c.DiffAmplificationFactor);

  chkAutoSignature.Checked := c.UseAutoSignature;
  edtSignatureText.Text := c.AutoSignatureTemplate;

  // VISUALISATION
  edtNumBins.Text := IntToStr(c.TVNumBins);
  edtPtsPerBin.Text := IntToStr(c.TVPtsPerBin);

  // ANALYSE
  edtHistBars.Text := IntToStr(c.HistMaxBars);

  chkShowOutlierS.Checked := c.bShowOutlierS;
  chkShowBlockS.Checked := c.bShowBlockS;

  edtNVFP4.Text := FloatToStr(c.VFP_Scale);

  // MISC
  edtExportDelim.Text := c.ExportDelimiter;

  cbReaderMode.ItemIndex := ClampInt(c.IOReaderMode, 0, cbReaderMode.Items.Count - 1);
  chkCapAuto.Checked := (c.IOMapCapMb <= 0);
  edtCapMb.Enabled := not chkCapAuto.Checked;  edtCapMb.ReadOnly := chkCapAuto.Checked;
  TEdit_WriteInt(edtCapMb, RecommendedMmapCapBytes shr 20);  // plafond courant en Mo
  TEdit_WriteInt(edtChunkKb, c.IOChunkKb);

  GgmlDllFill;
end;

procedure TfrmSettings.FormShow(Sender: TObject);
begin
  SetUiFromCfg(cfg);
end;

procedure TfrmSettings.btnApplyClick(Sender: TObject);
begin
  SetCfgFromUi(cfg);
  cfgSetGgmlDllName(cbGgmlDll.Text);   //cfgGgmlDllName // enregistre le nom courant dans cfg_ggml_type.ini
  cfgSaveSettings(cfg);
  eLogMsg(mLang.gMsg('FST.SettingsApplied'));
  edtCapMb.Enabled := not chkCapAuto.Checked;
  edtCapMb.ReadOnly := chkCapAuto.Checked;

  SetReaderMode(ReaderModeFromInt(cfg.IOReaderMode), cfg.IOMapCapMb);   // effet immediat
  if cfg.IOChunkKb > 0 then
    GFullChunkBytes := cfg.IOChunkKb shl 10 // Ko -> octets
  else
    GFullChunkBytes := 4 shl 20 {4 Mo};
  if (frmViewTensors <> nil) and frmViewTensors.Showing then
    frmViewTensors.RefreshActiveView(False);
end;

procedure TfrmSettings.btnCancelClick(Sender: TObject);
begin
  Close;
end;

procedure TfrmSettings.btnDllBrowseClick(Sender: TObject);
var
  Dlg: TOpenDialog;
  S: string;
begin
  Dlg := TOpenDialog.Create(nil);
  try
    Dlg.Title := 'ggml-base.dll';
    Dlg.Filter := 'DLL ggml (ggml-base*.dll)|ggml-base*.dll|Toutes les DLL (*.dll)|*.dll|Tous les fichiers (*.*)|*.*';
    Dlg.Options := Dlg.Options + [ofFileMustExist, ofPathMustExist];
    S := ExtractFilePath(cfgGgmlDllName);
    if (S = '') or not DirectoryExists(S) then
      S := ExtractFilePath(ParamStr(0));
    Dlg.InitialDir := S;
    Dlg.FileName := CStrGGMLDLLName;
    if not Dlg.Execute then
      Exit;

    if not GgmlDllUsable(Dlg.FileName) then
    begin
      eLogMsg('[SETTINGS] DLL injoignable : ' + Dlg.FileName, -1, -1, lvWarn);
      Exit;
    end;

    if not cfgSetGgmlDllName(Dlg.FileName) then
    begin
      eLogMsg('[SETTINGS] échec écriture de ' + CCFG_TYPE_INI + ' (dossier en lecture seule ?)', -1, -1, lvError);
      Exit;
    end;

    GgmlDllFill;                                  // le nouveau chemin prend la tete
    eLogMsg('[SETTINGS] DLL ggml -> ' + Dlg.FileName + '  (appliqué au prochain lancement)', -1, -1, lvNotice);
  finally
    Dlg.Free;
  end;
end;

procedure TfrmSettings.btnSaveClick(Sender: TObject);
begin
  SetCfgFromUi(cfg);
  cfgSetGgmlDllName(cbGgmlDll.Text);//  cfgGgmlDllName
  cfgSaveSettings(cfg);
  Close;
end;

procedure TfrmSettings.chkShowBlockSClick(Sender: TObject);
begin
  cfg.bShowBlockS := chkShowBlockS.Checked;
end;

procedure TfrmSettings.chkShowOutlierSClick(Sender: TObject);
begin
  cfg.bShowOutlierS := chkShowOutlierS.Checked;
end;

procedure TfrmSettings.chkCapAutoClick(Sender: TObject);
begin
  edtCapMb.Enabled := not chkCapAuto.Checked;
  edtCapMb.ReadOnly := chkCapAuto.Checked;
end;

procedure TfrmSettings.chkSaveMetaSeparateClick(Sender: TObject);
begin
  cfg.SaveMetaSeparate := chkSaveMetaSeparate.Checked;
end;

procedure TfrmSettings.cbRmseTypeChange(Sender: TObject);
begin
  if cbRmseType.ItemIndex < 0 then
    cbRmseType.ItemIndex := 3;
 // frmEditTensors.SetRmseTypeCfgFromUi(cbRmseType.ItemIndex);
end;

procedure TfrmSettings.cbUseImplChange(Sender: TObject);
begin
  if cbUseImpl.ItemIndex < 0 then
    cbUseImpl.ItemIndex := 2;
 // frmEditTensors.SetUseImplCfgFromUi(cbUseImpl.ItemIndex);
end;

end.
