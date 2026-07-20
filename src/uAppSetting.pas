unit uAppSetting;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, uAppConfig, System.Math, Vcl.ComCtrls, uTensorsNamesMan;

type
  TfrmSettings = class(TForm)
    PageControl1: TPageControl;
    TabSheet1: TTabSheet;
    TabSheet2: TTabSheet;
    chkSaveMetaSeparate: TCheckBox;
    lblSplitHint: TLabel;
    cmbSplitSize: TComboBox;
    chkUseDLL: TCheckBox;
    chkUseImpl: TCheckBox;
    lblDiffScale: TLabel;
    edtDiffScale: TEdit;
    edtHistStride: TEdit;
    edtHistBins: TEdit;
    LabelHistBins: TLabel;
    edtPtsPerBin: TEdit;
    edtNumBins: TEdit;
    chkShowBlockS: TCheckBox;
    lblNumBins: TLabel;
    lblPtsPerBin: TLabel;
    lblHistBins: TLabel;
    lblHistStride: TLabel;
    lblNVFP4Hint: TLabel;
    edtNVFP4: TEdit;
    edtExportDelim: TEdit;
    lblDelimiter: TLabel;
    btnApply: TButton;
    btnSave: TButton;
    btnCancel: TButton;
    lblSamplingBins: TLabel;
    chkShowOutlierS: TCheckBox;
    chkAutoSignature: TCheckBox;
    edtSignatureText: TEdit;
    procedure FormShow(Sender: TObject);
    procedure chkSaveMetaSeparateClick(Sender: TObject);
    procedure chkUseDLLClick(Sender: TObject);
    procedure chkUseImplClick(Sender: TObject);
    procedure chkShowBlockSClick(Sender: TObject);
    procedure btnSaveClick(Sender: TObject);
    procedure btnApplyClick(Sender: TObject);
    procedure btnCancelClick(Sender: TObject);
  private
    { D�clarations priv�es }
    procedure Log(const S: string);
    procedure SetCfgFromUi(var c: TGlobalConfig);
    procedure SetUiFromCfg(var c: TGlobalConfig);
  public
    { D�clarations publiques }
  end;

var
  frmSettings: TfrmSettings;

implementation

uses uLog, uEditTensors, uLangManager;

{$R *.dfm}

procedure TfrmSettings.SetCfgFromUi(var c: TGlobalConfig);
begin
  // GENERAL
  c.UseFDLL := chkUseDLL.Checked;
  c.UseFImpl := chkUseImpl.Checked;
  c.SaveMetaSeparate := chkSaveMetaSeparate.Checked;
  c.SplitSizeMbGbStr := cmbSplitSize.Text;
  c.SplitSizeMBytes := UnFormatSizeStrMbGb(c.SplitSizeMbGbStr);

  c.UseAutoSignature := chkAutoSignature.Checked;
  c.AutoSignatureTemplate := edtSignatureText.Text;

  c.NVFP4_Scale := StrToFloatDef(edtNVFP4.Text, 0.000081380208333);

  // VISUALISATION
  c.TVNumBins := StrToIntDef(edtNumBins.Text, 2048);
  c.TVPtsPerBin := StrToIntDef(edtPtsPerBin.Text, 16);
  c.HistBins := StrToIntDef(edtHistBins.Text, 128);
  c.HistStride := StrToIntDef(edtHistStride.Text, 32);

  c.bShowOutlierS := chkShowOutlierS.Checked;

  c.bShowBlockS := chkShowBlockS.Checked;

  c.ExportDelimiter := edtExportDelim.Text;
  c.DiffAmplificationFactor := Max(0.1, StrToFloatDef(edtDiffScale.Text, 1.0));

  frmEditTensors.SetUiFromCfg(c);
end;

procedure TfrmSettings.SetUiFromCfg(var c: TGlobalConfig);
begin
  // GENERAL
  chkUseDLL.Checked := c.UseFDLL;
  chkUseImpl.Checked := c.UseFImpl;
  chkSaveMetaSeparate.Checked := c.SaveMetaSeparate;

  cmbSplitSize.Text := c.SplitSizeMbGbStr;
  edtDiffScale.Text := FloatToStr(c.DiffAmplificationFactor);

  chkAutoSignature.Checked := c.UseAutoSignature;
  edtSignatureText.Text := c.AutoSignatureTemplate;

  // VISUALISATION
  edtNumBins.Text := IntToStr(c.TVNumBins);
  edtPtsPerBin.Text := IntToStr(c.TVPtsPerBin);

  // ANALYSE
  edtHistBins.Text := IntToStr(c.HistBins);
  edtHistStride.Text := IntToStr(c.HistStride);

  chkShowOutlierS.Checked := c.bShowOutlierS;
  chkShowBlockS.Checked := c.bShowBlockS;

  edtNVFP4.Text := FloatToStr(c.NVFP4_Scale);

  // MISC
  edtExportDelim.Text := c.ExportDelimiter;
end;

procedure TfrmSettings.FormShow(Sender: TObject);
begin
  SetUiFromCfg(cfg);
end;

procedure TfrmSettings.Log(const S: string);
begin
  // StatusBar1.Panels[0].Text := S;
  if Assigned(frmLogs) then
    LogMsg(S);
end;

procedure TfrmSettings.btnApplyClick(Sender: TObject);
begin
  SetCfgFromUi(cfg);
  cfgSaveSettings(cfg);
  eLogMsg(mLang.gMsg('FST.SettingsApplied'));
end;

procedure TfrmSettings.btnCancelClick(Sender: TObject);
begin
  Close;
end;

procedure TfrmSettings.btnSaveClick(Sender: TObject);
begin
  SetCfgFromUi(cfg);
  cfgSaveSettings(cfg);
  Close;
end;

procedure TfrmSettings.chkShowBlockSClick(Sender: TObject);
begin
  cfg.bShowOutlierS := chkShowOutlierS.Checked;
  cfg.bShowBlockS := chkShowBlockS.Checked;
end;

procedure TfrmSettings.chkSaveMetaSeparateClick(Sender: TObject);
begin
  cfg.SaveMetaSeparate := chkSaveMetaSeparate.Checked;
end;

procedure TfrmSettings.chkUseDLLClick(Sender: TObject);
begin
  frmEditTensors.SetUseDLLCfgFromUi(chkUseDLL.Checked);
end;

procedure TfrmSettings.chkUseImplClick(Sender: TObject);
begin
  frmEditTensors.SetUseImplCfgFromUi(chkUseImpl.Checked);
end;

end.
