program GGUF_Editor;

uses
  Forms,
  uEditTensors in 'uEditTensors.pas' {frmEditTensors} ,
  uViewTensors in 'uViewTensors.pas' {frmViewTensors} ,
  uEditKVsGGUF in 'uEditKVsGGUF.pas' {frmEditKVsGGUF} ,
  uEditStringDlg in 'uEditStringDlg.pas' {frmEditStringDlg} ,
  uEditArrayDlg in 'uEditArrayDlg.pas' {frmEditArrayDlg} ,
  uAppSetting in 'uAppSetting.pas' {frmSettings} ,
  uSplitMerge in 'uSplitMerge.pas' {frmSplitMerge} ,
  uFrmAbout in 'uFrmAbout.pas' {FrmAbout} ,
  uMappedNamesManager in 'uMappedNamesManager.pas' {FrmMappedNamesManager} ,
  uEditKVsGGUFNewKey in 'uEditKVsGGUFNewKey.pas' {frmEditNewKV} ,
  uLog in 'uLog.pas' {frmLogs} ,
  uGGUFModel in 'uGGUFModel.pas',
  uGGMLTypes in 'uGGMLTypes.pas',
  uGGMLConstants in 'uGGMLConstants.pas',
  uGgmlQuants in 'uGgmlQuants.pas',
  uGGUFTypes in 'uGGUFTypes.pas',
  uGGUFReader in 'uGGUFReader.pas',
  uGGUFWriter in 'uGGUFWriter.pas',
  uGgufStrUtils in 'uGgufStrUtils.pas',
  uGGUFParts in 'uGGUFParts.pas',
  uBinIO in 'uBinIO.pas',
  uGgmlQuantsQ4K in 'uGgmlQuantsQ4K.pas',
  uGgmlQuantsQ6K in 'uGgmlQuantsQ6K.pas',
  uGGMLQuantUtils in 'uGGMLQuantUtils.pas',
  uSafeTensors in 'uSafeTensors.pas',
  uMiniJSON in 'uMiniJSON.pas',
  uTensorTranspose in 'uTensorTranspose.pas',
  uRangeSlider in 'uRangeSlider.pas',
  uMath in 'uMath.pas',
  uAppConfig in 'uAppConfig.pas',
  uLangManager in 'uLangManager.pas',
  uEditTensorsMan in 'uEditTensorsMan.pas',
  uEditTensorsIO in 'uEditTensorsIO.pas',
  uTensorsNamesMan in 'uTensorsNamesMan.pas',
  uKVsGGUFConst in 'uKVsGGUFConst.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;

  Application.CreateForm(TfrmEditTensors, frmEditTensors);
  Application.CreateForm(TfrmViewTensors, frmViewTensors);
  Application.CreateForm(TfrmEditNewKV, frmEditNewKV);
  Application.CreateForm(TfrmEditStringDlg, frmEditStringDlg);
  Application.CreateForm(TfrmEditArrayDlg, frmEditArrayDlg); // doit être avant  frmEditKVsGGUF
  Application.CreateForm(TfrmEditKVsGGUF, frmEditKVsGGUF);
  Application.CreateForm(TfrmSettings, frmSettings);
  Application.CreateForm(TfrmSplitMerge, frmSplitMerge);
  Application.CreateForm(TFrmAbout, FrmAbout);
  Application.CreateForm(TFrmMappedNamesManager, FrmMappedNamesManager);
  Application.CreateForm(TfrmLogs, frmLogs);

  Application.Run;

end.
