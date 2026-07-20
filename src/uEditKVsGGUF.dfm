object frmEditKVsGGUF: TfrmEditKVsGGUF
  Left = 0
  Top = 0
  Caption = 'Edit GGUF KVs'
  ClientHeight = 442
  ClientWidth = 624
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  OnShow = FormShow
  DesignSize = (
    624
    442)
  TextHeight = 13
  object PageControl1: TPageControl
    Left = 0
    Top = 0
    Width = 624
    Height = 423
    ActivePage = TabSheetModelOut
    Align = alClient
    TabOrder = 0
    OnChange = PageControl1Change
    object TabSheetModel1: TTabSheet
      Caption = 'Model A (Input 1)'
      object grpFilter1: TGroupBox
        AlignWithMargins = True
        Left = 3
        Top = 3
        Width = 610
        Height = 46
        Align = alTop
        Caption = 'Filtre'
        TabOrder = 0
        DesignSize = (
          610
          46)
        object lblFilter1: TLabel
          Left = 12
          Top = 20
          Width = 46
          Height = 13
          Caption = 'Contains:'
        end
        object edtFilter1: TEdit
          Left = 70
          Top = 16
          Width = 337
          Height = 21
          Anchors = [akLeft, akTop, akRight]
          TabOrder = 0
          OnChange = edtFilterChange
        end
        object btnClearFText1: TButton
          Left = 413
          Top = 14
          Width = 26
          Height = 25
          Anchors = [akTop, akRight]
          Caption = 'x'
          TabOrder = 1
          OnClick = btnClearFText1Click
        end
      end
      object lvKVs1: TListView
        AlignWithMargins = True
        Left = 3
        Top = 55
        Width = 610
        Height = 288
        Align = alClient
        Checkboxes = True
        Columns = <>
        RowSelect = True
        TabOrder = 1
        ViewStyle = vsReport
        OnCustomDrawItem = lvKVs1CustomDrawItem
        OnCustomDrawSubItem = lvKVs1CustomDrawSubItem
        OnSelectItem = lvKVsSelectItem
      end
      object pnlTransfer1: TPanel
        Left = 0
        Top = 346
        Width = 616
        Height = 49
        Align = alBottom
        BevelOuter = bvNone
        TabOrder = 2
        object btnTransferAll1: TButton
          Left = 14
          Top = 12
          Width = 120
          Height = 25
          Caption = 'Transfer All >'
          TabOrder = 0
          OnClick = btnTransferAllClick
        end
        object btnTransferSel1: TButton
          Left = 140
          Top = 12
          Width = 120
          Height = 25
          Caption = 'Transfer Selected >'
          TabOrder = 1
          OnClick = btnTransferSelClick
        end
      end
    end
    object TabSheetModel2: TTabSheet
      Caption = 'Model B (Input 2)'
      object grpFilter2: TGroupBox
        AlignWithMargins = True
        Left = 3
        Top = 3
        Width = 610
        Height = 46
        Align = alTop
        Caption = 'Filtre'
        TabOrder = 0
        DesignSize = (
          610
          46)
        object lblFilter2: TLabel
          Left = 12
          Top = 20
          Width = 46
          Height = 13
          Caption = 'Contains:'
        end
        object edtFilter2: TEdit
          Left = 70
          Top = 16
          Width = 337
          Height = 21
          Anchors = [akLeft, akTop, akRight]
          TabOrder = 0
          OnChange = edtFilterChange
        end
        object btnClearFText2: TButton
          Left = 413
          Top = 14
          Width = 26
          Height = 25
          Anchors = [akTop, akRight]
          Caption = 'x'
          TabOrder = 1
          OnClick = btnClearFText2Click
        end
      end
      object lvKVs2: TListView
        AlignWithMargins = True
        Left = 3
        Top = 55
        Width = 610
        Height = 288
        Align = alClient
        Checkboxes = True
        Columns = <>
        RowSelect = True
        TabOrder = 1
        ViewStyle = vsReport
        OnCustomDrawItem = lvKVs1CustomDrawItem
        OnCustomDrawSubItem = lvKVs2CustomDrawSubItem
        OnSelectItem = lvKVsSelectItem
      end
      object pnlTransfer2: TPanel
        Left = 0
        Top = 346
        Width = 616
        Height = 49
        Align = alBottom
        BevelOuter = bvNone
        TabOrder = 2
        object btnTransferAll2: TButton
          Left = 14
          Top = 12
          Width = 120
          Height = 25
          Caption = 'Transfer All >'
          TabOrder = 0
          OnClick = btnTransferAllClick
        end
        object btnTransferSel2: TButton
          Left = 140
          Top = 12
          Width = 120
          Height = 25
          Caption = 'Transfer Selected >'
          TabOrder = 1
          OnClick = btnTransferSelClick
        end
      end
    end
    object TabSheetModelOut: TTabSheet
      Caption = 'Model Out (Prepare)'
      object Splitter1: TSplitter
        Left = 0
        Top = 242
        Width = 616
        Height = 3
        Cursor = crVSplit
        Align = alBottom
        ExplicitTop = 52
        ExplicitWidth = 193
      end
      object grpFilterOut: TGroupBox
        AlignWithMargins = True
        Left = 3
        Top = 3
        Width = 610
        Height = 46
        Align = alTop
        Caption = 'Filtre'
        TabOrder = 0
        DesignSize = (
          610
          46)
        object lblFilterOut: TLabel
          Left = 12
          Top = 20
          Width = 46
          Height = 13
          Caption = 'Contains:'
        end
        object edtFilterOut: TEdit
          Left = 70
          Top = 16
          Width = 337
          Height = 21
          Anchors = [akLeft, akTop, akRight]
          TabOrder = 0
          OnChange = edtFilterChange
        end
        object btnClearFTextO: TButton
          Left = 413
          Top = 15
          Width = 26
          Height = 25
          Anchors = [akTop, akRight]
          Caption = 'x'
          TabOrder = 1
          OnClick = btnClearFTextOClick
        end
      end
      object lvKVsOut: TListView
        AlignWithMargins = True
        Left = 3
        Top = 55
        Width = 610
        Height = 184
        Align = alClient
        Checkboxes = True
        Columns = <>
        RowSelect = True
        TabOrder = 1
        ViewStyle = vsReport
        OnAdvancedCustomDrawSubItem = lvKVsOutAdvancedCustomDrawSubItem
        OnCustomDrawItem = lvKVsOutCustomDrawItem
        OnSelectItem = lvKVsSelectItem
        OnItemChecked = lvKVsOutItemChecked
      end
      object grpEdit: TGroupBox
        AlignWithMargins = True
        Left = 3
        Top = 248
        Width = 610
        Height = 144
        Align = alBottom
        Caption = 'Edition / Ajout'
        Constraints.MinHeight = 110
        TabOrder = 2
        DesignSize = (
          610
          144)
        object lblKey: TLabel
          Left = 12
          Top = 23
          Width = 22
          Height = 13
          Caption = 'Key:'
        end
        object lblType: TLabel
          Left = 413
          Top = 23
          Width = 28
          Height = 13
          Anchors = [akTop, akRight]
          Caption = 'Type:'
          ExplicitLeft = 438
        end
        object cbType: TComboBox
          Left = 447
          Top = 20
          Width = 152
          Height = 21
          Style = csDropDownList
          Anchors = [akTop, akRight]
          TabOrder = 0
        end
        object memoValue: TMemo
          Left = 12
          Top = 47
          Width = 395
          Height = 88
          Anchors = [akLeft, akTop, akRight, akBottom]
          ScrollBars = ssBoth
          TabOrder = 1
          WordWrap = False
        end
        object btnUpsert: TButton
          Left = 509
          Top = 78
          Width = 90
          Height = 25
          Anchors = [akTop, akRight]
          Caption = 'Apply'
          TabOrder = 2
          OnClick = btnUpsertClick
        end
        object btnEditStrArray: TButton
          Left = 413
          Top = 47
          Width = 90
          Height = 25
          Anchors = [akTop, akRight]
          Caption = 'Edit ...'
          TabOrder = 3
          OnClick = btnEditStrArrayClick
        end
        object btnAdd: TButton
          Left = 413
          Top = 78
          Width = 90
          Height = 25
          Anchors = [akTop, akRight]
          Caption = 'Add New'
          TabOrder = 4
          OnClick = btnAddClick
        end
        object btnUncheck: TButton
          Left = 509
          Top = 47
          Width = 90
          Height = 25
          Anchors = [akTop, akRight]
          Caption = 'Uncheck'
          TabOrder = 5
          OnClick = btnUncheckClick
        end
        object btnImportKVs: TButton
          Left = 413
          Top = 109
          Width = 90
          Height = 25
          Anchors = [akTop, akRight]
          Caption = 'Import KVs'
          TabOrder = 6
          OnClick = btnImportKVsClick
        end
        object btnExportKVs: TButton
          Left = 509
          Top = 109
          Width = 90
          Height = 25
          Anchors = [akTop, akRight]
          Caption = 'Export KVs'
          TabOrder = 7
          OnClick = btnExportKVsClick
        end
        object edtKey: TEdit
          Left = 70
          Top = 20
          Width = 336
          Height = 21
          ReadOnly = True
          TabOrder = 8
        end
      end
    end
  end
  object StatusBar1: TStatusBar
    Left = 0
    Top = 423
    Width = 624
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
        Width = 120
      end>
  end
  object ProgressBar1: TProgressBar
    Left = 409
    Top = 427
    Width = 197
    Height = 13
    Anchors = [akRight, akBottom]
    TabOrder = 2
    Visible = False
  end
  object OpenDialog1: TOpenDialog
    Left = 564
    Top = 120
  end
  object SaveDialog1: TSaveDialog
    Filter = 'GGUF (*.gguf)|*.gguf|All (*.*)|*.*'
    Left = 556
    Top = 200
  end
end
