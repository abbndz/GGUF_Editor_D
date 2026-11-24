object frmEditKVFileTypeDlg: TfrmEditKVFileTypeDlg
  Left = 0
  Top = 0
  BorderIcons = [biSystemMenu]
  BorderStyle = bsDialog
  Caption = 'general.file_type'
  ClientHeight = 119
  ClientWidth = 280
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poOwnerFormCenter
  OnCreate = FormCreate
  TextHeight = 15
  object lblDescription: TLabel
    Left = 26
    Top = 49
    Width = 60
    Height = 15
    Caption = 'Description'
  end
  object cbType: TComboBox
    Left = 193
    Top = 17
    Width = 72
    Height = 23
    TabOrder = 0
    Text = 'cbType'
    OnChange = cbTypeChange
  end
  object btnOK: TButton
    Left = 59
    Top = 79
    Width = 75
    Height = 25
    Caption = 'OK'
    TabOrder = 1
    OnClick = btnOKClick
  end
  object btnCancel: TButton
    Left = 140
    Top = 79
    Width = 75
    Height = 25
    Caption = 'Cancel'
    TabOrder = 2
    OnClick = btnCancelClick
  end
  object Edit1: TEdit
    Left = 26
    Top = 17
    Width = 161
    Height = 23
    ReadOnly = True
    TabOrder = 3
    Text = 'general.file_type'
  end
end
