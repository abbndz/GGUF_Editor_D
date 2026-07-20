object frmEditStringDlg: TfrmEditStringDlg
  Left = 0
  Top = 0
  Caption = #201'diteur de Valeur GGUF'
  ClientHeight = 254
  ClientWidth = 468
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  TextHeight = 13
  object StatusBar1: TStatusBar
    Left = 0
    Top = 229
    Width = 468
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
    Top = 179
    Width = 468
    Height = 50
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 1
    DesignSize = (
      468
      50)
    object btnStrLoad: TButton
      Left = 10
      Top = 10
      Width = 90
      Height = 30
      Caption = 'Charger...'
      TabOrder = 0
      OnClick = btnStrLoadClick
    end
    object btnStrSaveAs: TButton
      Left = 110
      Top = 10
      Width = 90
      Height = 30
      Caption = 'Sauver sous...'
      TabOrder = 1
      OnClick = btnStrSaveAsClick
    end
    object btnStrOK: TButton
      Left = 292
      Top = 10
      Width = 80
      Height = 30
      Anchors = [akTop, akRight]
      Caption = 'OK'
      Default = True
      TabOrder = 2
      OnClick = btnStrOKClick
    end
    object btnStrCancel: TButton
      Left = 378
      Top = 10
      Width = 80
      Height = 30
      Anchors = [akTop, akRight]
      Cancel = True
      Caption = 'Annuler'
      TabOrder = 3
      OnClick = btnStrCancelClick
    end
  end
  object memoEditor: TRichEdit
    AlignWithMargins = True
    Left = 10
    Top = 10
    Width = 448
    Height = 166
    Margins.Left = 10
    Margins.Top = 10
    Margins.Right = 10
    Align = alClient
    Font.Charset = 254
    Font.Color = clWindowText
    Font.Height = -13
    Font.Name = 'Consolas'
    Font.Style = []
    ParentFont = False
    ScrollBars = ssBoth
    TabOrder = 2
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
