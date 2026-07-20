object frmEditArrayDlg: TfrmEditArrayDlg
  Left = 0
  Top = 0
  Caption = #201'diteur de Valeur GGUF'
  ClientHeight = 392
  ClientWidth = 467
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OnCreate = FormCreate
  OnShow = FormShow
  TextHeight = 13
  object StatusBar1: TStatusBar
    Left = 0
    Top = 367
    Width = 467
    Height = 25
    Panels = <
      item
        Width = 200
      end
      item
        Width = 150
      end>
  end
  object pnlStrArrBot: TPanel
    Left = 0
    Top = 317
    Width = 467
    Height = 50
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 1
    DesignSize = (
      467
      50)
    object btnStrSaveAs: TButton
      Left = 101
      Top = 14
      Width = 90
      Height = 30
      Caption = 'Sauver sous...'
      TabOrder = 0
      OnClick = btnStrSaveAsClick
    end
    object btnArrCancel: TButton
      Left = 380
      Top = 14
      Width = 75
      Height = 30
      Anchors = [akTop, akRight]
      Cancel = True
      Caption = 'Annuler'
      TabOrder = 1
      OnClick = btnArrCancelClick
    end
    object btnArrOk: TButton
      Left = 299
      Top = 14
      Width = 75
      Height = 30
      Anchors = [akTop, akRight]
      Caption = 'OK'
      Default = True
      TabOrder = 2
      OnClick = btnArrOkClick
    end
    object btnArrLoad: TButton
      Left = 20
      Top = 14
      Width = 75
      Height = 30
      Caption = 'Charger'
      TabOrder = 3
      OnClick = btnArrLoadClick
    end
  end
  object pnlArrTop: TPanel
    Left = 0
    Top = 0
    Width = 467
    Height = 60
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 2
    DesignSize = (
      467
      60)
    object lblArrType: TLabel
      Left = 318
      Top = 19
      Width = 31
      Height = 13
      Anchors = [akTop, akRight]
      Caption = 'Type :'
      Visible = False
      ExplicitLeft = 451
    end
    object grpNav: TGroupBox
      Left = 10
      Top = 6
      Width = 295
      Height = 40
      TabOrder = 0
      DesignSize = (
        295
        40)
      object lblPage: TLabel
        Left = 129
        Top = 13
        Width = 12
        Height = 13
        Caption = 'de'
      end
      object lblTotalPages: TLabel
        Left = 145
        Top = 13
        Width = 6
        Height = 13
        Caption = '1'
      end
      object btnPrevAll: TButton
        Left = 10
        Top = 8
        Width = 30
        Height = 25
        Caption = '<<'
        TabOrder = 0
        OnClick = btnPrevAllClick
      end
      object btnPrev: TButton
        Left = 46
        Top = 8
        Width = 30
        Height = 25
        Caption = '<'
        TabOrder = 1
        OnClick = btnPrevClick
      end
      object edtPageNum: TEdit
        Left = 82
        Top = 10
        Width = 42
        Height = 21
        TabOrder = 2
        Text = '1'
        OnKeyUp = edtPageNumKeyUp
      end
      object btnNext: TButton
        Left = 216
        Top = 8
        Width = 30
        Height = 25
        Anchors = [akTop, akRight]
        Caption = '>'
        TabOrder = 3
        OnClick = btnNextClick
      end
      object btnNextAll: TButton
        Left = 252
        Top = 8
        Width = 30
        Height = 25
        Anchors = [akTop, akRight]
        Caption = '>>'
        TabOrder = 4
        OnClick = btnNextAllClick
      end
    end
    object cbArrType1: TComboBox
      Left = 355
      Top = 16
      Width = 100
      Height = 21
      Style = csDropDownList
      Anchors = [akTop, akRight]
      TabOrder = 1
      Visible = False
    end
  end
  object sgArray: TStringGrid
    AlignWithMargins = True
    Left = 12
    Top = 63
    Width = 443
    Height = 251
    Margins.Left = 12
    Margins.Right = 12
    Align = alClient
    ColCount = 2
    DefaultColWidth = 180
    RowCount = 1000
    Options = [goFixedVertLine, goFixedHorzLine, goVertLine, goHorzLine, goRangeSelect, goDrawFocusSelected, goEditing, goAlwaysShowEditor]
    TabOrder = 3
    OnSelectCell = sgArraySelectCell
    OnSetEditText = sgArraySetEditText
    RowHeights = (
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24
      24)
  end
  object OpenDialog1: TOpenDialog
    Left = 620
    Top = 320
  end
  object SaveDialog1: TSaveDialog
    Left = 644
    Top = 416
  end
end
