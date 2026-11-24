object frmEditKVsGGUF: TfrmEditKVsGGUF
  Left = 0
  Top = 0
  Caption = 'Edit GGUF KVs'
  ClientHeight = 577
  ClientWidth = 612
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  Position = poDesigned
  OnClose = FormClose
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  OnShow = FormShow
  DesignSize = (
    612
    577)
  TextHeight = 13
  object PageControl1: TPageControl
    Left = 0
    Top = 0
    Width = 612
    Height = 558
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
        Width = 598
        Height = 46
        Align = alTop
        Caption = 'Filtre'
        TabOrder = 0
        DesignSize = (
          598
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
          Width = 325
          Height = 21
          Anchors = [akLeft, akTop, akRight]
          TabOrder = 0
          OnChange = edtFilterChange
        end
        object btnClearFText1: TButton
          Left = 401
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
        Width = 598
        Height = 434
        Align = alClient
        Checkboxes = True
        Columns = <>
        RowSelect = True
        PopupMenu = pmInputKVs
        TabOrder = 1
        ViewStyle = vsReport
        OnCustomDrawItem = lvKVs1CustomDrawItem
        OnCustomDrawSubItem = lvKVs1CustomDrawSubItem
        OnSelectItem = lvKVsSelectItem
      end
      object pnlTransfer1: TPanel
        Left = 0
        Top = 492
        Width = 604
        Height = 38
        Align = alBottom
        BevelOuter = bvNone
        TabOrder = 2
        DesignSize = (
          604
          38)
        object btnTransferAll1: TButton
          Left = 470
          Top = 7
          Width = 120
          Height = 25
          Anchors = [akTop, akRight]
          Caption = 'Transfer All >'
          TabOrder = 0
          OnClick = btnTransferAll1Click
        end
        object btnTransferSel1: TButton
          Left = 344
          Top = 7
          Width = 120
          Height = 25
          Anchors = [akTop, akRight]
          Caption = 'Transfer Selected >'
          TabOrder = 1
          OnClick = btnTransferSel1Click
        end
      end
    end
    object TabSheetModel2: TTabSheet
      Caption = 'Model B (Input 2)'
      object grpFilter2: TGroupBox
        AlignWithMargins = True
        Left = 3
        Top = 3
        Width = 598
        Height = 46
        Align = alTop
        Caption = 'Filtre'
        TabOrder = 0
        DesignSize = (
          598
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
          Width = 325
          Height = 21
          Anchors = [akLeft, akTop, akRight]
          TabOrder = 0
          OnChange = edtFilterChange
        end
        object btnClearFText2: TButton
          Left = 401
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
        Width = 598
        Height = 434
        Align = alClient
        Checkboxes = True
        Columns = <>
        RowSelect = True
        PopupMenu = pmInputKVs
        TabOrder = 1
        ViewStyle = vsReport
        OnCustomDrawItem = lvKVs1CustomDrawItem
        OnCustomDrawSubItem = lvKVs2CustomDrawSubItem
        OnSelectItem = lvKVsSelectItem
      end
      object pnlTransfer2: TPanel
        Left = 0
        Top = 492
        Width = 604
        Height = 38
        Align = alBottom
        BevelOuter = bvNone
        TabOrder = 2
        DesignSize = (
          604
          38)
        object btnTransferAll2: TButton
          Left = 470
          Top = 7
          Width = 120
          Height = 25
          Anchors = [akTop, akRight]
          Caption = 'Transfer All >'
          TabOrder = 0
          OnClick = btnTransferAll1Click
        end
        object btnTransferSel2: TButton
          Left = 344
          Top = 7
          Width = 120
          Height = 25
          Anchors = [akTop, akRight]
          Caption = 'Transfer Selected >'
          TabOrder = 1
          OnClick = btnTransferSel1Click
        end
      end
    end
    object TabSheetModel3: TTabSheet
      Caption = 'Model C (Input 3)'
      ImageIndex = 3
      object pnlTransfer3: TPanel
        Left = 0
        Top = 492
        Width = 604
        Height = 38
        Align = alBottom
        BevelOuter = bvNone
        TabOrder = 0
        DesignSize = (
          604
          38)
        object btnTransferAll3: TButton
          Left = 470
          Top = 7
          Width = 120
          Height = 25
          Anchors = [akTop, akRight]
          Caption = 'Transfer All >'
          TabOrder = 0
          OnClick = btnTransferAll1Click
        end
        object btnTransferSel3: TButton
          Left = 344
          Top = 7
          Width = 120
          Height = 25
          Anchors = [akTop, akRight]
          Caption = 'Transfer Selected >'
          TabOrder = 1
          OnClick = btnTransferSel1Click
        end
      end
      object lvKVs3: TListView
        AlignWithMargins = True
        Left = 3
        Top = 55
        Width = 598
        Height = 434
        Align = alClient
        Checkboxes = True
        Columns = <>
        RowSelect = True
        PopupMenu = pmInputKVs
        TabOrder = 1
        ViewStyle = vsReport
        OnCustomDrawItem = lvKVs1CustomDrawItem
        OnCustomDrawSubItem = lvKVs3CustomDrawSubItem
        OnSelectItem = lvKVsSelectItem
      end
      object grpFilter3: TGroupBox
        AlignWithMargins = True
        Left = 3
        Top = 3
        Width = 598
        Height = 46
        Align = alTop
        Caption = 'Filtre'
        TabOrder = 2
        DesignSize = (
          598
          46)
        object lblFilter3: TLabel
          Left = 12
          Top = 20
          Width = 46
          Height = 13
          Caption = 'Contains:'
        end
        object edtFilter3: TEdit
          Left = 70
          Top = 16
          Width = 325
          Height = 21
          Anchors = [akLeft, akTop, akRight]
          TabOrder = 0
          OnChange = edtFilterChange
        end
        object btnClearFText3: TButton
          Left = 401
          Top = 14
          Width = 26
          Height = 25
          Anchors = [akTop, akRight]
          Caption = 'x'
          TabOrder = 1
          OnClick = btnClearFText3Click
        end
      end
    end
    object TabSheetModelOut: TTabSheet
      Caption = 'Model Out (Prepare)'
      object Splitter1: TSplitter
        Left = 0
        Top = 377
        Width = 604
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
        Width = 598
        Height = 46
        Align = alTop
        Caption = 'Filtre'
        TabOrder = 0
        DesignSize = (
          598
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
          Width = 325
          Height = 21
          Anchors = [akLeft, akTop, akRight]
          TabOrder = 0
          OnChange = edtFilterChange
        end
        object btnClearFTextO: TButton
          Left = 401
          Top = 14
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
        Width = 598
        Height = 319
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
        Top = 383
        Width = 598
        Height = 144
        Align = alBottom
        Caption = 'Edition / Ajout'
        Constraints.MinHeight = 110
        TabOrder = 2
        DesignSize = (
          598
          144)
        object lblKey: TLabel
          Left = 12
          Top = 21
          Width = 22
          Height = 13
          Caption = 'Key:'
        end
        object lblType: TLabel
          Left = 401
          Top = 21
          Width = 28
          Height = 13
          Anchors = [akTop, akRight]
          Caption = 'Type:'
          ExplicitLeft = 413
        end
        object cbType: TComboBox
          Left = 435
          Top = 18
          Width = 152
          Height = 21
          Style = csDropDownList
          Anchors = [akTop, akRight]
          TabOrder = 0
        end
        object memoValue: TMemo
          Left = 12
          Top = 47
          Width = 383
          Height = 88
          Anchors = [akLeft, akTop, akRight, akBottom]
          ScrollBars = ssBoth
          TabOrder = 1
          WordWrap = False
        end
        object btnUpsert: TButton
          Left = 497
          Top = 78
          Width = 90
          Height = 25
          Anchors = [akTop, akRight]
          Caption = 'Apply'
          TabOrder = 2
          OnClick = btnUpsertClick
        end
        object btnEditStrArray: TButton
          Left = 401
          Top = 47
          Width = 90
          Height = 25
          Anchors = [akTop, akRight]
          Caption = 'Edit ...'
          TabOrder = 3
          OnClick = btnEditStrArrayClick
        end
        object btnAdd: TButton
          Left = 401
          Top = 78
          Width = 90
          Height = 25
          Anchors = [akTop, akRight]
          Caption = 'Add New'
          TabOrder = 4
          OnClick = btnAddClick
        end
        object btnUncheck: TButton
          Left = 497
          Top = 47
          Width = 90
          Height = 25
          Anchors = [akTop, akRight]
          Caption = 'Uncheck'
          TabOrder = 5
          OnClick = btnUncheckClick
        end
        object btnImportKVs: TButton
          Left = 401
          Top = 109
          Width = 90
          Height = 25
          Anchors = [akTop, akRight]
          Caption = 'Import KVs'
          TabOrder = 6
          OnClick = btnImportKVsClick
        end
        object btnExportKVs: TButton
          Left = 497
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
          Top = 18
          Width = 261
          Height = 21
          Anchors = [akLeft, akTop, akRight]
          ReadOnly = True
          TabOrder = 8
        end
        object btnUp: TButton
          Left = 337
          Top = 16
          Width = 26
          Height = 25
          Hint = 'Move selected KV pair up'
          Anchors = [akTop, akRight]
          Caption = #9650
          Font.Charset = DEFAULT_CHARSET
          Font.Color = clWindowText
          Font.Height = -11
          Font.Name = 'Tahoma'
          Font.Style = []
          ParentFont = False
          ParentShowHint = False
          ShowHint = True
          TabOrder = 9
          OnClick = btnUpClick
        end
        object btnDown: TButton
          Left = 369
          Top = 16
          Width = 26
          Height = 25
          Hint = 'Move selected KV pair down'
          Anchors = [akTop, akRight]
          Caption = #9660
          Font.Charset = DEFAULT_CHARSET
          Font.Color = clWindowText
          Font.Height = -11
          Font.Name = 'Tahoma'
          Font.Style = []
          ParentFont = False
          ParentShowHint = False
          ShowHint = True
          TabOrder = 10
          OnClick = btnDownClick
        end
      end
    end
  end
  object StatusBar1: TStatusBar
    Left = 0
    Top = 558
    Width = 612
    Height = 19
    Panels = <
      item
        Width = 360
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
    Left = 397
    Top = 562
    Width = 197
    Height = 13
    Anchors = [akRight, akBottom]
    TabOrder = 2
    Visible = False
  end
  object OpenDialog1: TOpenDialog
    Left = 476
    Top = 136
  end
  object SaveDialog1: TSaveDialog
    Filter = 'GGUF (*.gguf)|*.gguf|All (*.*)|*.*'
    Left = 388
    Top = 128
  end
  object pmInputKVs: TPopupMenu
    Left = 260
    Top = 123
    object miTransferSelected: TMenuItem
      Caption = 'Copy >'
      OnClick = miTransferSelectedClick
    end
    object miTransferAll: TMenuItem
      Caption = 'Copy All >>'
      OnClick = miTransferAllClick
    end
  end
end
