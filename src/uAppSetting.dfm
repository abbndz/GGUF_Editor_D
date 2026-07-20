object frmSettings: TfrmSettings
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  Caption = 'Param'#232'tres'
  ClientHeight = 370
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
    Height = 322
    ActivePage = TabSheet1
    TabOrder = 0
    object TabSheet1: TTabSheet
      Hint = 'Options G'#233'n'#233'rales et Format de sortie'
      Caption = 'G'#233'n'#233'ral '
      object lblSplitHint: TLabel
        Left = 16
        Top = 59
        Width = 169
        Height = 13
        Caption = 'Taille maximale par fichier de split  :'
      end
      object lblNVFP4Hint: TLabel
        Left = 16
        Top = 221
        Width = 89
        Height = 13
        Caption = 'NVFP4 Scale (F8) :'
      end
      object lblDelimiter: TLabel
        Left = 16
        Top = 252
        Width = 89
        Height = 13
        Caption = 'D'#233'limiteur Export :'
      end
      object chkSaveMetaSeparate: TCheckBox
        Left = 16
        Top = 24
        Width = 297
        Height = 17
        Caption = 'Sauvegarder les KVs (Metadata) dans un fichier s'#233'par'#233
        TabOrder = 0
        OnClick = chkSaveMetaSeparateClick
      end
      object cmbSplitSize: TComboBox
        Left = 191
        Top = 56
        Width = 147
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
      object chkUseDLL: TCheckBox
        Left = 16
        Top = 157
        Width = 224
        Height = 17
        Hint = 'Use external llama.cpp DLL'
        Caption = 'Utiliser DLL Quant/Dequant (Llama.cpp)'
        TabOrder = 2
        OnClick = chkUseDLLClick
      end
      object chkUseImpl: TCheckBox
        Left = 16
        Top = 185
        Width = 224
        Height = 17
        Hint = 
          'Utiliser Impl :  haute qualit'#233' avec optimisation RMSE  (ou D'#233'coc' +
          'h'#233' Ref : R'#233'f'#233'rence : Algorithme d'#233'terministe (sans optimisation ' +
          'RMSE))'
        Caption = 'Utiliser Impl (ou D'#233'coch'#233' Ref)'
        TabOrder = 3
        OnClick = chkUseImplClick
      end
      object edtNVFP4: TEdit
        Left = 191
        Top = 218
        Width = 147
        Height = 21
        TabOrder = 4
        Text = '0.00008138'
      end
      object edtExportDelim: TEdit
        Left = 191
        Top = 249
        Width = 147
        Height = 21
        TabOrder = 5
        Text = ';'
      end
      object chkAutoSignature: TCheckBox
        Left = 16
        Top = 88
        Width = 97
        Height = 17
        Caption = 'Auto Signature'
        TabOrder = 6
      end
      object edtSignatureText: TEdit
        Left = 191
        Top = 86
        Width = 147
        Height = 21
        TabOrder = 7
        Text = 'GGUF Editor D++'
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
      object LabelHistBins: TLabel
        Left = 16
        Top = 114
        Width = 47
        Height = 13
        Caption = 'Hist Bins :'
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
      object lblHistBins: TLabel
        Left = 16
        Top = 92
        Width = 116
        Height = 13
        Caption = 'Histogramme et Analyse'
      end
      object lblHistStride: TLabel
        Left = 16
        Top = 141
        Width = 56
        Height = 13
        Caption = 'Hist Stride :'
      end
      object lblSamplingBins: TLabel
        Left = 16
        Top = 16
        Width = 115
        Height = 13
        Caption = #201'chantillonnage (S'#233'ries)'
      end
      object edtDiffScale: TEdit
        Left = 192
        Top = 250
        Width = 121
        Height = 21
        TabOrder = 0
        Text = '1.0'
      end
      object edtHistStride: TEdit
        Left = 165
        Top = 138
        Width = 47
        Height = 21
        ParentShowHint = False
        ShowHint = True
        TabOrder = 1
        Text = '10'
      end
      object edtHistBins: TEdit
        Left = 165
        Top = 111
        Width = 47
        Height = 21
        Hint = 'R'#233'solution histogramme (ex: 50)'
        ParentShowHint = False
        ShowHint = True
        TabOrder = 2
        Text = '2000'
      end
      object edtPtsPerBin: TEdit
        Left = 165
        Top = 61
        Width = 47
        Height = 21
        Hint = 'Points/Bin'
        ParentShowHint = False
        ShowHint = True
        TabOrder = 3
        Text = '10'
      end
      object edtNumBins: TEdit
        Left = 165
        Top = 34
        Width = 47
        Height = 21
        Hint = #201'chantillons (Bins):'
        ParentShowHint = False
        ShowHint = True
        TabOrder = 4
        Text = '2000'
      end
      object chkShowBlockS: TCheckBox
        Left = 16
        Top = 174
        Width = 231
        Height = 17
        Caption = 'Afficher un marqueur de Block (32, 256)'
        TabOrder = 5
        OnClick = chkShowBlockSClick
      end
      object chkShowOutlierS: TCheckBox
        Left = 16
        Top = 206
        Width = 231
        Height = 17
        Caption = 'Afficher un marqueur Outlier'
        TabOrder = 6
        OnClick = chkShowBlockSClick
      end
    end
  end
  object btnApply: TButton
    Left = 80
    Top = 337
    Width = 75
    Height = 25
    Caption = 'Apply'
    TabOrder = 1
    OnClick = btnApplyClick
  end
  object btnSave: TButton
    Left = 161
    Top = 337
    Width = 75
    Height = 25
    Caption = 'OK'
    TabOrder = 2
    OnClick = btnSaveClick
  end
  object btnCancel: TButton
    Left = 242
    Top = 337
    Width = 75
    Height = 25
    Caption = 'Cancel'
    TabOrder = 3
    OnClick = btnCancelClick
  end
end
