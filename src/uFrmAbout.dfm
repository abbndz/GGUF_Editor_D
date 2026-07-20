object FrmAbout: TFrmAbout
  Left = 0
  Top = 0
  BorderIcons = [biSystemMenu]
  BorderStyle = bsDialog
  Caption = 'GGUF Editor ++ - '#192' propos'
  ClientHeight = 386
  ClientWidth = 408
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poOwnerFormCenter
  OnShow = FormShow
  TextHeight = 15
  object pnlHeader: TPanel
    Left = 0
    Top = 0
    Width = 408
    Height = 84
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 0
    object lblVersion: TLabel
      AlignWithMargins = True
      Left = 3
      Top = 3
      Width = 402
      Height = 49
      Align = alClient
      Alignment = taCenter
      AutoSize = False
      Caption = 'GGUF Editor D++ v'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clBlue
      Font.Height = -20
      Font.Name = 'Segoe UI'
      Font.Style = [fsBold]
      ParentFont = False
      Layout = tlCenter
      ExplicitHeight = 42
    end
    object lblBuildInfo: TLabel
      AlignWithMargins = True
      Left = 3
      Top = 58
      Width = 402
      Height = 23
      Align = alBottom
      Alignment = taCenter
      AutoSize = False
      Caption = #39'Build: 1.0.32.112 (05/07/2026)'#39
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clBtnText
      Font.Height = -12
      Font.Name = 'Segoe UI'
      Font.Style = []
      ParentFont = False
      Layout = tlCenter
      ExplicitTop = 3
      ExplicitWidth = 78
    end
  end
  object pnlMain: TPanel
    Left = 0
    Top = 155
    Width = 408
    Height = 189
    Align = alClient
    BevelOuter = bvNone
    TabOrder = 1
    ExplicitHeight = 190
    object lblDescription: TLabel
      AlignWithMargins = True
      Left = 3
      Top = 3
      Width = 402
      Height = 92
      Align = alTop
      Alignment = taCenter
      AutoSize = False
      Caption = 
        'Outil avanc'#233'd'#233'dition, de fusion et de visualisation de mod'#232'les L' +
        'LM au format GGUF et SafeTensors. '#13#10'Prend en charge la quotinti'#233 +
        'isation multi-niveaux (Q4_K, Q6_K, Q8_0, NVFP4...), l'#39#233'chantillo' +
        'nnage temps r'#233'el, la comparaison de tenseurs et l'#39#233'dition de m'#233't' +
        'adonn'#233'es.'
      WordWrap = True
    end
    object lblCredits: TLabel
      AlignWithMargins = True
      Left = 3
      Top = 101
      Width = 402
      Height = 85
      Align = alClient
      Alignment = taCenter
      AutoSize = False
      Caption = 
        '- D'#233'velopp'#233' sous Delphi 10/11/12 '#13#10'- Moteur de d'#233'quantisation DL' +
        'L/Impl (haute pr'#233'cision RMSE) '#13#10'- Support multi-sources (GGUF, S' +
        'afeTensors) '#13#10'- Interface optimis'#233'e pour l'#39'analyse des mod'#232'les L' +
        'LM '#13#10'- Open Sourceet Communautaire'
      WordWrap = True
      ExplicitHeight = 92
    end
  end
  object pnlDonate: TPanel
    Left = 0
    Top = 84
    Width = 408
    Height = 71
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 2
    object lblDonation: TLabel
      Left = 0
      Top = 0
      Width = 408
      Height = 17
      Align = alTop
      Alignment = taCenter
      Caption = 
        'Si ce logiciel vous est utile, pensez '#224' soutenir le d'#233'veloppemen' +
        't !'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -13
      Font.Name = 'Segoe UI'
      Font.Style = []
      ParentFont = False
      ExplicitWidth = 379
    end
    object lblPayPal: TLabel
      Left = 39
      Top = 42
      Width = 151
      Height = 15
      Cursor = crHandPoint
      Alignment = taRightJustify
      Caption = 'PayPal : abbndz@gmail.com'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clBlue
      Font.Height = -12
      Font.Name = 'Segoe UI'
      Font.Style = [fsUnderline]
      ParentFont = False
      OnMouseMove = lblLinkMouseMove
    end
    object lblKafeMe: TLabel
      Left = 210
      Top = 42
      Width = 96
      Height = 15
      Cursor = crHandPoint
      Caption = 'ko-fi.com/abbndz'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clBlue
      Font.Height = -12
      Font.Name = 'Segoe UI'
      Font.Style = [fsUnderline]
      ParentFont = False
      OnClick = lblKafeMeClick
      OnMouseMove = lblLinkMouseMove
    end
  end
  object pnlBot: TPanel
    Left = 0
    Top = 344
    Width = 408
    Height = 42
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 3
    ExplicitTop = 345
    object btnOk: TButton
      Left = 158
      Top = 5
      Width = 100
      Height = 28
      Caption = 'Fermer'
      Default = True
      ModalResult = 1
      TabOrder = 0
      OnClick = btnOkClick
    end
  end
end
