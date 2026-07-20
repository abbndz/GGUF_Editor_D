object frmEditNewKV: TfrmEditNewKV
  Left = 0
  Top = 0
  Caption = 'New Key'
  ClientHeight = 218
  ClientWidth = 397
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poOwnerFormCenter
  OnShow = FormShow
  TextHeight = 15
  object pnlTop: TPanel
    Left = 0
    Top = 0
    Width = 397
    Height = 72
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 0
    DesignSize = (
      397
      72)
    object lblKey: TLabel
      Left = 10
      Top = 12
      Width = 25
      Height = 15
      Caption = 'Key :'
    end
    object lblType: TLabel
      Left = 10
      Top = 41
      Width = 30
      Height = 15
      Caption = 'Type :'
    end
    object cbType: TComboBox
      Left = 60
      Top = 38
      Width = 84
      Height = 23
      Style = csDropDownList
      TabOrder = 0
      OnChange = cbTypeChange
    end
    object cbKeyFamily: TComboBox
      Left = 150
      Top = 38
      Width = 230
      Height = 23
      Style = csDropDownList
      Anchors = [akLeft, akTop, akRight]
      TabOrder = 1
      OnChange = cbKeyFamilyChange
    end
    object cbKey: TComboBox
      Left = 60
      Top = 9
      Width = 320
      Height = 23
      Anchors = [akLeft, akTop, akRight]
      TabOrder = 2
    end
  end
  object pnlBottom: TPanel
    Left = 0
    Top = 178
    Width = 397
    Height = 40
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 1
    object lblArrType: TLabel
      Left = 10
      Top = 12
      Width = 30
      Height = 15
      Caption = 'Type :'
      Visible = False
    end
    object btnOK: TButton
      Left = 231
      Top = 8
      Width = 75
      Height = 25
      Caption = 'OK'
      Default = True
      TabOrder = 0
      OnClick = btnOKClick
    end
    object btnCancel: TButton
      Left = 312
      Top = 8
      Width = 75
      Height = 25
      Caption = 'Annuler'
      TabOrder = 1
      OnClick = btnCancelClick
    end
    object btnAdd: TButton
      Left = 150
      Top = 8
      Width = 75
      Height = 25
      Caption = 'Add'
      TabOrder = 2
      OnClick = btnAddClick
    end
    object cbArrType: TComboBox
      Left = 60
      Top = 9
      Width = 84
      Height = 23
      Style = csDropDownList
      TabOrder = 3
      Visible = False
      OnChange = cbTypeChange
    end
  end
  object memoValue: TMemo
    AlignWithMargins = True
    Left = 10
    Top = 72
    Width = 377
    Height = 103
    Margins.Left = 10
    Margins.Top = 0
    Margins.Right = 10
    Align = alClient
    TabOrder = 2
  end
end
