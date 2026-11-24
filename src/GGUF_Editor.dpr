program GGUF_Editor;

uses
  Forms,
  uEditTensors in 'uEditTensors.pas' {frmEditTensors},
  uEditTensorsMan in 'uEditTensorsMan.pas',
  uEditTensorsIO in 'uEditTensorsIO.pas',
  uViewTensors in 'uViewTensors.pas' {frmViewTensors},
  uEditKVsGGUF in 'uEditKVsGGUF.pas' {frmEditKVsGGUF},
  uEditStringDlg in 'uEditStringDlg.pas' {frmEditStringDlg},
  uEditArrayDlg in 'uEditArrayDlg.pas' {frmEditArrayDlg},
  uAppSetting in 'uAppSetting.pas' {frmSettings},
  uSplitMerge in 'uSplitMerge.pas' {frmSplitMerge},
  uFrmAbout in 'uFrmAbout.pas' {FrmAbout},
  uMappedNamesManager in 'uMappedNamesManager.pas' {FrmMappedNamesManager},
  uEditKVsGGUFNewKey in 'uEditKVsGGUFNewKey.pas' {frmEditNewKV},
  uEditKVFileTypeDlg in 'uEditKVFileTypeDlg.pas' {frmEditKVFileTypeDlg},
  uLog in 'uLog.pas' {frmLogs},
  uGGUFModel in 'uGGUFModel.pas',
  uGGMLTypes in 'uGGMLTypes.pas',
  uGGMLConstants in 'uGGMLConstants.pas',
  uGgmlQuants in 'uGgmlQuants.pas',
  uKVsGGUFConst in 'uKVsGGUFConst.pas',
  uGGMLQuantUtils in 'uGGMLQuantUtils.pas',
  uGgmlQuantsQ20 in 'uGgmlQuantsQ20.pas',
  uGgmlQuantsQ40 in 'uGgmlQuantsQ40.pas',
  uGgmlQuantsQ50 in 'uGgmlQuantsQ50.pas',
  uGgmlQuantsQ80 in 'uGgmlQuantsQ80.pas',
  uGgmlQuantsFP16 in 'uGgmlQuantsFP16.pas',
  uGgmlQuantsQ2K in 'uGgmlQuantsQ2K.pas',
  uGgmlQuantsQ3K in 'uGgmlQuantsQ3K.pas',
  uGgmlQuantsQ5K in 'uGgmlQuantsQ5K.pas',
  uGgmlQuantsQ4K in 'uGgmlQuantsQ4K.pas',
  uGgmlQuantsQ6K in 'uGgmlQuantsQ6K.pas',
  uGgmlQuantsQ8K in 'uGgmlQuantsQ8K.pas',
  uGgmlQuantsIQ4nl in 'uGgmlQuantsIQ4nl.pas',
  uGgmlQuantsIQ4_XS in 'uGgmlQuantsIQ4_XS.pas',
  uGgmlQuantsMXFP4 in 'uGgmlQuantsMXFP4.pas',
  uGgmlQuantsNVFP4 in 'uGgmlQuantsNVFP4.pas',
  uGgmlQuantsIQ1_S in 'uGgmlQuantsIQ1_S.pas',
  uGgmlQuantsIQ1_M in 'uGgmlQuantsIQ1_M.pas',
  uGgmlQuantsIQ2_S in 'uGgmlQuantsIQ2_S.pas',
  uGgmlQuantsIQ3_S in 'uGgmlQuantsIQ3_S.pas',
  uGgmlQuantsIQ2_XS in 'uGgmlQuantsIQ2_XS.pas',
  uGgmlQuantsIQ2_XXS in 'uGgmlQuantsIQ2_XXS.pas',
  uGgmlQuantsIQ3_XXS in 'uGgmlQuantsIQ3_XXS.pas',
  uGgmlQuantsIQGRIDs in 'uGgmlQuantsIQGRIDs.pas',
  uQuantPresetConfig in 'uQuantPresetConfig.pas',
  uGGUFTypes in 'uGGUFTypes.pas',
  uGGUFReader in 'uGGUFReader.pas',
  uGGUFWriter in 'uGGUFWriter.pas',
  uStrUtils in 'uStrUtils.pas',
  uGGUFParts in 'uGGUFParts.pas',
  uBinIO in 'uBinIO.pas',
  uSafeTensors in 'uSafeTensors.pas',
  uTensorTranspose in 'uTensorTranspose.pas',
  uMiniJSON in 'uMiniJSON.pas',
  uRangeSlider in 'uRangeSlider.pas',
  uMath in 'uMath.pas',
  uAppConfig in 'uAppConfig.pas',
  uLangManager in 'uLangManager.pas',
  uTensorsNamesMan in 'uTensorsNamesMan.pas',
  uMMAPReader in 'uMMAPReader.pas',
  uViewTensorsChart in 'uViewTensorsChart.pas',
  uViewTensorsHisto in 'uViewTensorsHisto.pas',
  uViewTensorsListMan in 'uViewTensorsListMan.pas',
  uEditTensorsView in 'uEditTensorsView.pas',
  uDiffStats in 'uDiffStats.pas',
  uSaveProgress in 'uSaveProgress.pas',
  uGgmlQuantsTQ2 in 'uGgmlQuantsTQ2.pas',
  uTensorStreamReader in 'uTensorStreamReader.pas',
  uGgmlQuantsFP8_E4M3 in 'uGgmlQuantsFP8_E4M3.pas',
  uFullDiffPipeline in 'uFullDiffPipeline.pas';

{$R *.res}

begin
  cfgLoadSettings(cfg);

  Application.Initialize;

  Application.MainFormOnTaskbar := True;

  Application.CreateForm(TfrmEditTensors, frmEditTensors);
  Application.CreateForm(TfrmViewTensors, frmViewTensors);
  Application.CreateForm(TfrmEditNewKV, frmEditNewKV);
  Application.CreateForm(TfrmEditStringDlg, frmEditStringDlg);
  Application.CreateForm(TfrmEditArrayDlg, frmEditArrayDlg);
  Application.CreateForm(TfrmEditKVsGGUF, frmEditKVsGGUF);
  Application.CreateForm(TfrmSettings, frmSettings);
  Application.CreateForm(TfrmSplitMerge, frmSplitMerge);
  Application.CreateForm(TFrmAbout, FrmAbout);
  Application.CreateForm(TfrmEditKVFileTypeDlg, frmEditKVFileTypeDlg);
  Application.CreateForm(TFrmMappedNamesManager, FrmMappedNamesManager);
  Application.CreateForm(TfrmLogs, frmLogs);

  //ReportMemoryLeaksOnShutdown := True  ;

  Application.Run;

end.
