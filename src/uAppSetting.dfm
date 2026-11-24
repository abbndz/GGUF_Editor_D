object frmSettings: TfrmSettings
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  Caption = 'Param'#232'tres'
  ClientHeight = 367
  ClientWidth = 398
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  Position = poOwnerFormCenter
  OnShow = FormShow
  TextHeight = 13
  object PageControl1: TPageControl
    Left = 8
    Top = 8
    Width = 377
    Height = 313
    ActivePage = TabSheet1
    TabOrder = 0
    object TabSheet1: TTabSheet
      Hint = 'Options G'#233'n'#233'rales et Format de sortie'
      Caption = 'G'#233'n'#233'ral '
      DesignSize = (
        369
        285)
      object lblSplitHint: TLabel
        Left = 16
        Top = 88
        Width = 169
        Height = 13
        Caption = 'Taille maximale par fichier de split  :'
      end
      object lblNVFP4Hint: TLabel
        Left = 16
        Top = 209
        Width = 89
        Height = 13
        Caption = 'NVFP4 Scale (F8) :'
      end
      object lblUseImpl: TLabel
        Left = 16
        Top = 150
        Width = 76
        Height = 13
        Caption = 'Utiliser DLL/Impl'
      end
      object lblRmseType: TLabel
        Left = 16
        Top = 177
        Width = 111
        Height = 13
        Caption = 'Pond'#233'ration RmseType'
      end
      object lblDelimiter: TLabel
        Left = 16
        Top = 245
        Width = 89
        Height = 13
        Caption = 'D'#233'limiteur Export :'
      end
      object chkSaveMetaSeparate: TCheckBox
        Left = 16
        Top = 53
        Width = 297
        Height = 17
        Caption = 'Sauvegarder les KVs (Metadata) dans un fichier s'#233'par'#233
        TabOrder = 0
        OnClick = chkSaveMetaSeparateClick
      end
      object cmbSplitSize: TComboBox
        Left = 191
        Top = 85
        Width = 162
        Height = 21
        ItemIndex = 0
        TabOrder = 1
        Text = 'None (One File)'
        Items.Strings = (
          'None (One File)'
          '650 MB'
          '2 GB'
          '4 GB'
          '6 GB'
          '8 GB'
          '10 GB'
          '12 GB'
          '14 GB'
          '16 GB'
          '20 GB'
          '24 GB'
          '32 GB'
          '64 GB')
      end
      object edtNVFP4: TEdit
        Left = 191
        Top = 206
        Width = 162
        Height = 21
        TabOrder = 2
        Text = '0.00008138'
      end
      object chkAutoSignature: TCheckBox
        Left = 16
        Top = 117
        Width = 97
        Height = 17
        Caption = 'Auto Signature'
        TabOrder = 3
      end
      object edtSignatureText: TEdit
        Left = 191
        Top = 115
        Width = 162
        Height = 21
        TabOrder = 4
        Text = 'GGUF Editor D++'
      end
      object cbUseImpl: TComboBox
        Left = 191
        Top = 147
        Width = 162
        Height = 21
        Hint = 
          'Utiliser Impl :  haute qualit'#233' avec optimisation RMSE  (ou D'#233'coc' +
          'h'#233' Ref : R'#233'f'#233'rence : Algorithme d'#233'terministe (sans optimisation ' +
          'RMSE))'
        ItemIndex = 2
        ParentShowHint = False
        ShowHint = True
        TabOrder = 5
        Text = 'DLL-Impl0'
        OnChange = cbUseImplChange
        Items.Strings = (
          'DLL-Ref'
          'Pas-Ref'
          'DLL-Impl0'
          'Pas-Impl1'
          'Pas-Impl2'
          'Pas-Impl3'
          'Pas-Impl4'
          'Pas-Impl5')
      end
      object cbRmseType: TComboBox
        Left = 191
        Top = 174
        Width = 162
        Height = 21
        Hint = 'Rmse Type'
        ItemIndex = 3
        ParentShowHint = False
        ShowHint = True
        TabOrder = 6
        Text = '3: Magnitude (|x|)'
        OnChange = cbRmseTypeChange
        Items.Strings = (
          '0: Simple (no optimization)'
          '1: Uniform (1.0)'
          '2: Sqrt Magnitude ('#8730'|x|)'
          '3: Magnitude (|x|)'
          '4: Variance (x'#178')')
      end
      object edtExportDelim: TEdit
        Left = 191
        Top = 237
        Width = 162
        Height = 21
        TabOrder = 7
        Text = ';'
      end
      object cbGgmlDll: TComboBox
        Left = 16
        Top = 16
        Width = 289
        Height = 21
        Hint = 'DLL de quantification (ggml-base.dll)'
        TabOrder = 8
        Text = 'ggml-base.dll'
      end
      object btnDllBrowse: TButton
        Left = 311
        Top = 14
        Width = 42
        Height = 25
        Anchors = [akTop, akRight]
        Caption = '...'
        TabOrder = 9
        OnClick = btnDllBrowseClick
      end
    end
    object TabSheet2: TTabSheet
      Caption = 'Visualisation '
      ImageIndex = 1
      object lblDiffScale: TLabel
        Left = 16
        Top = 253
        Width = 144
        Height = 13
        Caption = 'Amplification des diff'#233'rences :'
      end
      object lblNumBins: TLabel
        Left = 16
        Top = 37
        Width = 81
        Height = 13
        Caption = 'Nombre de Bins :'
      end
      object lblPtsPerBin: TLabel
        Left = 16
        Top = 64
        Width = 72
        Height = 13
        Caption = 'Points par Bin :'
      end
      object lblHistStride: TLabel
        Left = 16
        Top = 91
        Width = 69
        Height = 13
        Caption = 'Hist MaxBars :'
      end
      object lblSamplingBins: TLabel
        Left = 16
        Top = 16
        Width = 115
        Height = 13
        Caption = #201'chantillonnage (S'#233'ries)'
      end
      object lblChunkKb: TLabel
        Left = 17
        Top = 172
        Width = 45
        Height = 13
        Caption = 'Chunk Kb'
      end
      object lblReaderMode: TLabel
        Left = 17
        Top = 118
        Width = 64
        Height = 13
        Caption = 'Reader Mode'
      end
      object edtDiffScale: TEdit
        Left = 192
        Top = 250
        Width = 147
        Height = 21
        TabOrder = 0
        Text = '1.0'
      end
      object edtHistBars: TEdit
        Left = 192
        Top = 88
        Width = 147
        Height = 21
        ParentShowHint = False
        ShowHint = True
        TabOrder = 1
        Text = '32'
      end
      object edtPtsPerBin: TEdit
        Left = 192
        Top = 61
        Width = 147
        Height = 21
        Hint = 'Points/Bin'
        ParentShowHint = False
        ShowHint = True
        TabOrder = 2
        Text = '32'
      end
      object edtNumBins: TEdit
        Left = 192
        Top = 34
        Width = 147
        Height = 21
        Hint = #201'chantillons (Bins):'
        ParentShowHint = False
        ShowHint = True
        TabOrder = 3
        Text = '1024'
      end
      object chkShowBlockS: TCheckBox
        Left = 16
        Top = 194
        Width = 231
        Height = 17
        Caption = 'Afficher un marqueur de Block (32, 256)'
        TabOrder = 4
        OnClick = chkShowBlockSClick
      end
      object chkShowOutlierS: TCheckBox
        Left = 16
        Top = 221
        Width = 231
        Height = 17
        Caption = 'Afficher un marqueur Outlier'
        TabOrder = 5
        OnClick = chkShowOutlierSClick
      end
      object cbReaderMode: TComboBox
        Left = 192
        Top = 115
        Width = 147
        Height = 21
        Hint = 'Rmse Type'
        ItemIndex = 0
        ParentShowHint = False
        ShowHint = True
        TabOrder = 6
        Text = 'Auto'
        OnChange = cbRmseTypeChange
        Items.Strings = (
          'Auto'
          'Mmap'
          'Stream')
      end
      object edtChunkKb: TEdit
        Left = 192
        Top = 169
        Width = 147
        Height = 21
        TabOrder = 7
        Text = '0'
      end
      object edtCapMb: TEdit
        Left = 192
        Top = 142
        Width = 147
        Height = 21
        TabOrder = 8
        Text = '0'
      end
      object chkCapAuto: TCheckBox
        Left = 17
        Top = 144
        Width = 169
        Height = 17
        Caption = 'Cap Auto'
        TabOrder = 9
        OnClick = chkCapAutoClick
      end
    end
  end
  object btnApply: TButton
    Left = 80
    Top = 330
    Width = 75
    Height = 25
    Caption = 'Apply'
    TabOrder = 1
    OnClick = btnApplyClick
  end
  object btnSave: TButton
    Left = 161
    Top = 330
    Width = 75
    Height = 25
    Caption = 'OK'
    TabOrder = 2
    OnClick = btnSaveClick
  end
  object btnCancel: TButton
    Left = 242
    Top = 330
    Width = 75
    Height = 25
    Caption = 'Cancel'
    TabOrder = 3
    OnClick = btnCancelClick
  end
end
