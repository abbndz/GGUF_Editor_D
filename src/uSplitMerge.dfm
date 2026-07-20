object frmSplitMerge: TfrmSplitMerge
  Left = 0
  Top = 0
  Caption = 'Split / Merge GGUF'
  ClientHeight = 404
  ClientWidth = 558
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OnCreate = FormCreate
  DesignSize = (
    558
    404)
  TextHeight = 13
  object grpSplit: TGroupBox
    Left = 0
    Top = 0
    Width = 558
    Height = 130
    Align = alTop
    Caption = 'Split'
    TabOrder = 0
    DesignSize = (
      558
      130)
    object lblSrc: TLabel
      Left = 15
      Top = 21
      Width = 37
      Height = 13
      Caption = 'Source:'
    end
    object lblBaseOut: TLabel
      Left = 15
      Top = 78
      Width = 45
      Height = 13
      Caption = 'BaseOut:'
    end
    object edtSrc: TEdit
      Left = 14
      Top = 40
      Width = 426
      Height = 21
      Anchors = [akLeft, akTop, akRight]
      TabOrder = 0
    end
    object btnBrowseSrc: TButton
      Left = 446
      Top = 38
      Width = 100
      Height = 25
      Anchors = [akTop, akRight]
      Caption = 'Parcourir...'
      TabOrder = 1
      OnClick = btnBrowseSrcClick
    end
    object edtSplitOut: TEdit
      Left = 14
      Top = 97
      Width = 426
      Height = 21
      Anchors = [akLeft, akTop, akRight]
      TabOrder = 2
    end
    object btnSplit: TButton
      Left = 446
      Top = 89
      Width = 100
      Height = 29
      Anchors = [akTop, akRight]
      Caption = 'Split'
      TabOrder = 3
      OnClick = btnSplitClick
    end
    object edtPrefixSplit: TEdit
      Left = 343
      Top = 70
      Width = 97
      Height = 21
      Anchors = [akTop, akRight]
      TabOrder = 4
    end
  end
  object grpMerge: TGroupBox
    Left = 0
    Top = 130
    Width = 558
    Height = 208
    Align = alTop
    Caption = 'Merge'
    TabOrder = 1
    DesignSize = (
      558
      208)
    object lblParts: TLabel
      Left = 15
      Top = 20
      Width = 29
      Height = 13
      Caption = 'Parts:'
    end
    object lblOut: TLabel
      Left = 18
      Top = 152
      Width = 32
      Height = 13
      Caption = 'Sortie:'
    end
    object lbParts: TListBox
      Left = 14
      Top = 39
      Width = 426
      Height = 100
      Anchors = [akLeft, akTop, akRight]
      ItemHeight = 13
      TabOrder = 0
    end
    object btnAddParts: TButton
      Left = 446
      Top = 39
      Width = 100
      Height = 25
      Anchors = [akTop, akRight]
      Caption = 'Ajouter...'
      TabOrder = 1
      OnClick = btnAddPartsClick
    end
    object btnClearParts: TButton
      Left = 446
      Top = 69
      Width = 100
      Height = 25
      Anchors = [akTop, akRight]
      Caption = 'Vider'
      TabOrder = 2
      OnClick = btnClearPartsClick
    end
    object edtMergeOut: TEdit
      Left = 18
      Top = 172
      Width = 422
      Height = 21
      Anchors = [akLeft, akTop, akRight]
      TabOrder = 3
    end
    object btnBrowseOut: TButton
      Left = 446
      Top = 135
      Width = 100
      Height = 25
      Anchors = [akTop, akRight]
      Caption = 'Parcourir...'
      TabOrder = 4
      OnClick = btnBrowseOutClick
    end
    object btnMerge: TButton
      Left = 446
      Top = 166
      Width = 100
      Height = 25
      Anchors = [akTop, akRight]
      Caption = 'Merge'
      TabOrder = 5
      OnClick = btnMergeClick
    end
    object edtPrefixMerge: TEdit
      Left = 343
      Top = 145
      Width = 97
      Height = 21
      Anchors = [akTop, akRight]
      TabOrder = 6
    end
  end
  object pnlBottom: TPanel
    Left = 0
    Top = 343
    Width = 558
    Height = 42
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 2
    DesignSize = (
      558
      42)
    object btnClose: TButton
      Left = 447
      Top = 6
      Width = 99
      Height = 25
      Anchors = [akTop, akRight]
      Caption = 'Fermer'
      TabOrder = 0
      OnClick = btnCloseClick
    end
  end
  object StatusBar1: TStatusBar
    Left = 0
    Top = 385
    Width = 558
    Height = 19
    Panels = <
      item
        Width = 300
      end
      item
        Width = 120
      end
      item
        Width = 120
      end
      item
        Width = 50
      end>
  end
  object ProgressBar2: TProgressBar
    Left = 231
    Top = 388
    Width = 100
    Height = 15
    Anchors = [akRight, akBottom]
    TabOrder = 4
    Visible = False
  end
  object ProgressBar1: TProgressBar
    Left = 337
    Top = 388
    Width = 200
    Height = 15
    Anchors = [akRight, akBottom]
    TabOrder = 5
    Visible = False
  end
  object OpenDialog1: TOpenDialog
    Left = 440
    Top = 192
  end
  object OpenDialogParts: TOpenDialog
    Left = 64
    Top = 184
  end
  object SaveDialog1: TSaveDialog
    Left = 224
    Top = 184
  end
end
