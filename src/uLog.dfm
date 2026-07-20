object frmLogs: TfrmLogs
  Left = 0
  Top = 0
  Caption = 'Logs'
  ClientHeight = 441
  ClientWidth = 624
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  OnShow = FormShow
  TextHeight = 15
  object pnlLogTop: TPanel
    Left = 0
    Top = 0
    Width = 624
    Height = 36
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 0
    DesignSize = (
      624
      36)
    object lblInfoLogs: TLabel
      AlignWithMargins = True
      Left = 12
      Top = 14
      Width = 122
      Height = 15
      Caption = 'Rapport de diagnostic :'
    end
    object btnClearLog: TButton
      Left = 537
      Top = 8
      Width = 75
      Height = 25
      Anchors = [akTop, akRight]
      Caption = 'Clear'
      TabOrder = 0
      OnClick = btnClearLogClick
    end
    object chkLogToFile: TCheckBox
      Left = 410
      Top = 14
      Width = 120
      Height = 17
      Anchors = [akTop, akRight]
      Caption = 'Log To File'
      TabOrder = 1
      OnClick = chkLogToFileClick
    end
    object chkLogToMemo: TCheckBox
      Left = 284
      Top = 12
      Width = 120
      Height = 17
      Anchors = [akTop, akRight]
      Caption = 'Log'
      TabOrder = 2
      OnClick = chkLogToMemoClick
    end
  end
  object StatusBar1: TStatusBar
    Left = 0
    Top = 422
    Width = 624
    Height = 19
    Panels = <>
  end
  object MemoLogs: TMemo
    AlignWithMargins = True
    Left = 12
    Top = 39
    Width = 600
    Height = 380
    Margins.Left = 12
    Margins.Right = 12
    Align = alClient
    Font.Charset = ANSI_CHARSET
    Font.Color = clWindowText
    Font.Height = -12
    Font.Name = 'Consolas'
    Font.Style = []
    ParentFont = False
    ReadOnly = True
    ScrollBars = ssVertical
    TabOrder = 2
  end
end
