object frmLogs: TfrmLogs
  Left = 0
  Top = 0
  Caption = 'Logs'
  ClientHeight = 441
  ClientWidth = 674
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  OnClose = FormClose
  OnShow = FormShow
  TextHeight = 15
  object pnlLogTop: TPanel
    Left = 0
    Top = 0
    Width = 674
    Height = 36
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 0
    ExplicitWidth = 624
    DesignSize = (
      674
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
      Left = 587
      Top = 8
      Width = 75
      Height = 25
      Anchors = [akTop, akRight]
      Caption = 'Clear'
      TabOrder = 0
      OnClick = btnClearLogClick
      ExplicitLeft = 537
    end
    object chkLogToFile: TCheckBox
      Left = 337
      Top = 12
      Width = 90
      Height = 17
      Anchors = [akTop, akRight]
      Caption = 'Log To File'
      TabOrder = 1
      OnClick = chkLogToFileClick
    end
    object chkLogToMemo: TCheckBox
      Left = 241
      Top = 12
      Width = 90
      Height = 17
      Anchors = [akTop, akRight]
      Caption = 'Log'
      TabOrder = 2
      OnClick = chkLogToMemoClick
    end
    object cbLogLevel: TComboBox
      Left = 151
      Top = 10
      Width = 84
      Height = 23
      Anchors = [akTop, akRight]
      ItemIndex = 4
      TabOrder = 3
      Text = 'Notice'
      OnClick = cbLogLevelClick
      Items.Strings = (
        'Trace'
        'Debug'
        'Info'
        'Warn'
        'Notice'
        'Error')
    end
    object chkThrottle: TCheckBox
      Left = 433
      Top = 12
      Width = 90
      Height = 17
      Anchors = [akTop, akRight]
      Caption = 'Throttle (10ms)'
      TabOrder = 4
      OnClick = chkThrottleClick
    end
    object chkTimestamp: TCheckBox
      Left = 531
      Top = 12
      Width = 50
      Height = 17
      Hint = 'Toggles the inclusion of the current time in log messages.'
      Anchors = [akTop, akRight]
      Caption = 'Time'
      ParentShowHint = False
      ShowHint = True
      TabOrder = 5
      OnClick = chkTimestampClick
    end
  end
  object StatusBar1: TStatusBar
    Left = 0
    Top = 422
    Width = 674
    Height = 19
    Panels = <>
    ExplicitWidth = 624
  end
  object MemoLogs: TMemo
    AlignWithMargins = True
    Left = 12
    Top = 39
    Width = 650
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
    ScrollBars = ssVertical
    TabOrder = 2
    WantTabs = True
    ExplicitWidth = 600
  end
end
