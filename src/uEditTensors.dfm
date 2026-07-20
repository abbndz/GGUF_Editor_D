object frmEditTensors: TfrmEditTensors
  Left = 0
  Top = 0
  Caption = 'GGUF Editor D++'
  ClientHeight = 464
  ClientWidth = 676
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  Menu = MainMenu1
  OnClose = FormClose
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  OnShow = FormShow
  DesignSize = (
    676
    464)
  TextHeight = 13
  object pnlTopInp0: TPanel
    Left = 0
    Top = 0
    Width = 676
    Height = 35
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 0
    object btnViewTensor: TButton
      Left = 12
      Top = 4
      Width = 100
      Height = 25
      Action = ActViewTensors
      TabOrder = 0
    end
    object btnViewMetaData: TButton
      Left = 118
      Top = 4
      Width = 100
      Height = 25
      Action = ActViewKVs
      TabOrder = 1
    end
    object btnShowSetting: TButton
      Left = 224
      Top = 4
      Width = 100
      Height = 25
      Action = ActSettings
      TabOrder = 2
    end
    object btnShowLogs: TButton
      Left = 330
      Top = 4
      Width = 100
      Height = 25
      Action = ActShowLogs
      TabOrder = 3
    end
  end
  object PageControl1: TPageControl
    Left = 0
    Top = 35
    Width = 676
    Height = 375
    Margins.Left = 12
    Margins.Right = 12
    ActivePage = TabSheetModInA
    Align = alClient
    TabOrder = 1
    OnChange = PageControl1Change
    object TabSheetModInA: TTabSheet
      Caption = 'Model A (Input 1 gguf)'
      object lvTensors1: TListView
        AlignWithMargins = True
        Left = 8
        Top = 75
        Width = 652
        Height = 197
        Margins.Left = 8
        Margins.Right = 8
        Align = alClient
        Checkboxes = True
        Columns = <>
        DragMode = dmAutomatic
        RowSelect = True
        PopupMenu = pmInputTensor
        TabOrder = 0
        ViewStyle = vsReport
        OnAdvancedCustomDrawItem = lvTensors1AdvancedCustomDrawItem
        OnSelectItem = lvTensorSelectItem
      end
      object PanBotEdit1: TPanel
        Left = 0
        Top = 275
        Width = 668
        Height = 72
        Align = alBottom
        BevelOuter = bvNone
        TabOrder = 1
        DesignSize = (
          668
          72)
        object lblName1: TLabel
          Left = 12
          Top = 17
          Width = 37
          Height = 13
          Caption = 'Tensor:'
        end
        object edtName1: TEdit
          Left = 55
          Top = 11
          Width = 221
          Height = 21
          Anchors = [akLeft, akTop, akRight]
          TabOrder = 0
        end
        object cbDType1: TComboBox
          Left = 282
          Top = 11
          Width = 80
          Height = 21
          Style = csDropDownList
          Anchors = [akTop, akRight]
          Enabled = False
          TabOrder = 1
        end
        object btnTransferToOut1: TButton
          Left = 368
          Top = 9
          Width = 80
          Height = 25
          Hint = 'Transfer To Model Out'
          Anchors = [akTop, akRight]
          Caption = 'Transfer >'
          TabOrder = 2
          OnClick = btnTransferToOut1Click
        end
        object chkAllLayers1: TCheckBox
          Left = 368
          Top = 42
          Width = 74
          Height = 17
          Hint = 'Appliquer a toutes les couches (meme nom de tenseur)'
          Anchors = [akTop, akRight]
          Caption = 'All Layers'
          TabOrder = 3
          OnClick = chkAllLayers1Click
        end
        object cbLayersFrom1: TComboBox
          Left = 455
          Top = 40
          Width = 59
          Height = 21
          Anchors = [akTop, akRight]
          TabOrder = 4
          Text = '0'
          Items.Strings = (
            '0'
            '1'
            '2'
            '3'
            '4'
            '6'
            '8'
            '12'
            '16')
        end
        object cbLayersTo1: TComboBox
          Left = 520
          Top = 40
          Width = 59
          Height = 21
          Anchors = [akTop, akRight]
          TabOrder = 5
          Text = '999'
          Items.Strings = (
            '4'
            '6'
            '8'
            '12'
            '16'
            '32'
            '64'
            '128'
            '512'
            '1024')
        end
        object cbLayersMod1: TComboBox
          Left = 585
          Top = 40
          Width = 59
          Height = 21
          Anchors = [akTop, akRight]
          ItemIndex = 0
          TabOrder = 6
          Text = 'All'
          Items.Strings = (
            'All'
            'Odd'
            'Even'
            'Mod3'
            'Mod4'
            'Mod5'
            'Mod6'
            'Mod7'
            'Mod8')
        end
        object btnTransferAll1: TButton
          Left = 454
          Top = 9
          Width = 93
          Height = 25
          Anchors = [akTop, akRight]
          Caption = 'Transfer All >'
          TabOrder = 7
          OnClick = btnTransferAll1Click
        end
      end
      object pnlTopInp1: TPanel
        Left = 0
        Top = 0
        Width = 668
        Height = 72
        Align = alTop
        BevelOuter = bvNone
        TabOrder = 2
        DesignSize = (
          668
          72)
        object lblSrc1: TLabel
          Left = 12
          Top = 16
          Width = 43
          Height = 13
          Caption = 'Source1:'
        end
        object lbFilter1: TLabel
          Left = 12
          Top = 45
          Width = 31
          Height = 13
          Caption = 'Filter :'
        end
        object btnLoad1: TButton
          Left = 580
          Top = 9
          Width = 80
          Height = 25
          Action = ActLoadSrcA1
          Anchors = [akTop, akRight]
          TabOrder = 0
        end
        object btnBrowseSrc1: TButton
          Left = 494
          Top = 9
          Width = 80
          Height = 25
          Action = ActBrowseSrcA1
          Anchors = [akTop, akRight]
          TabOrder = 1
        end
        object edtSrc1: TEdit
          Left = 61
          Top = 11
          Width = 427
          Height = 21
          Anchors = [akLeft, akTop, akRight]
          TabOrder = 2
        end
        object btnClearFText1: TButton
          Left = 287
          Top = 40
          Width = 26
          Height = 25
          Anchors = [akTop, akRight]
          Caption = 'x'
          TabOrder = 3
          OnClick = btnClearFText1Click
        end
        object edtFilter1: TEdit
          Left = 61
          Top = 42
          Width = 220
          Height = 21
          Anchors = [akLeft, akTop, akRight]
          TabOrder = 4
          OnChange = edtFilter1Change
        end
        object btnShowMappedNames1: TButton
          Left = 634
          Top = 40
          Width = 26
          Height = 25
          Anchors = [akTop, akRight]
          Caption = '+'
          TabOrder = 5
          OnClick = btnShowMappedNames1Click
        end
        object cbMappedNames1: TComboBox
          Left = 494
          Top = 42
          Width = 134
          Height = 21
          Anchors = [akTop, akRight]
          TabOrder = 6
          OnChange = cbMappedNames1Change
        end
        object chkUseIgnoredPrefixes1: TCheckBox
          Left = 328
          Top = 44
          Width = 160
          Height = 17
          Anchors = [akTop, akRight]
          Caption = 'Use Ignored Prefixes'
          TabOrder = 7
          OnClick = chkUseIgnoredPrefixes1Click
        end
      end
    end
    object TabSheetModInB: TTabSheet
      Caption = 'Model B (Input 2 gguf)'
      ImageIndex = 1
      object lvTensors2: TListView
        AlignWithMargins = True
        Left = 8
        Top = 75
        Width = 652
        Height = 197
        Margins.Left = 8
        Margins.Right = 8
        Align = alClient
        Checkboxes = True
        Columns = <>
        RowSelect = True
        PopupMenu = pmInputTensor
        TabOrder = 0
        ViewStyle = vsReport
        OnSelectItem = lvTensorSelectItem
      end
      object PanBotEdit2: TPanel
        Left = 0
        Top = 275
        Width = 668
        Height = 72
        Align = alBottom
        BevelOuter = bvNone
        TabOrder = 1
        DesignSize = (
          668
          72)
        object lblName2: TLabel
          Left = 12
          Top = 15
          Width = 37
          Height = 13
          Caption = 'Tensor:'
        end
        object edtName2: TEdit
          Left = 55
          Top = 11
          Width = 221
          Height = 21
          Anchors = [akLeft, akTop, akRight]
          TabOrder = 0
        end
        object cbDType2: TComboBox
          Left = 282
          Top = 11
          Width = 80
          Height = 21
          Style = csDropDownList
          Anchors = [akTop, akRight]
          Enabled = False
          TabOrder = 1
        end
        object btnTransferToOut2: TButton
          Left = 368
          Top = 9
          Width = 80
          Height = 25
          Hint = 'Transfer To Model Out'
          Anchors = [akTop, akRight]
          Caption = 'Transfer >'
          TabOrder = 2
          OnClick = btnTransferToOut2Click
        end
        object cbLayersMod2: TComboBox
          Left = 585
          Top = 40
          Width = 59
          Height = 21
          Anchors = [akTop, akRight]
          ItemIndex = 0
          TabOrder = 3
          Text = 'All'
          Items.Strings = (
            'All'
            'Odd'
            'Even'
            'Mod3'
            'Mod4'
            'Mod5'
            'Mod6'
            'Mod7'
            'Mod8')
        end
        object cbLayersTo2: TComboBox
          Left = 520
          Top = 40
          Width = 59
          Height = 21
          Anchors = [akTop, akRight]
          TabOrder = 4
          Text = '999'
          Items.Strings = (
            '4'
            '6'
            '8'
            '12'
            '16'
            '32'
            '64'
            '128'
            '512'
            '1024')
        end
        object cbLayersFrom2: TComboBox
          Left = 455
          Top = 40
          Width = 59
          Height = 21
          Anchors = [akTop, akRight]
          TabOrder = 5
          Text = '0'
          Items.Strings = (
            '0'
            '1'
            '2'
            '3'
            '4'
            '6'
            '8'
            '12'
            '16')
        end
        object chkAllLayers2: TCheckBox
          Left = 368
          Top = 42
          Width = 74
          Height = 17
          Hint = 'Appliquer a toutes les couches (meme nom de tenseur)'
          Anchors = [akTop, akRight]
          Caption = 'All Layers'
          TabOrder = 6
          OnClick = chkAllLayers2Click
        end
        object btnTransferAll2: TButton
          Left = 454
          Top = 9
          Width = 93
          Height = 25
          Anchors = [akTop, akRight]
          Caption = 'Transfer All >'
          TabOrder = 7
          OnClick = btnTransferAll2Click
        end
      end
      object pnlTopInp2: TPanel
        Left = 0
        Top = 0
        Width = 668
        Height = 72
        Align = alTop
        BevelOuter = bvNone
        TabOrder = 2
        DesignSize = (
          668
          72)
        object lblSrc2: TLabel
          Left = 12
          Top = 16
          Width = 43
          Height = 13
          Caption = 'Source2:'
        end
        object lbFilter2: TLabel
          Left = 12
          Top = 45
          Width = 31
          Height = 13
          Caption = 'Filter :'
        end
        object edtSrc2: TEdit
          Left = 61
          Top = 11
          Width = 427
          Height = 21
          Anchors = [akLeft, akTop, akRight]
          TabOrder = 0
        end
        object btnBrowseSrc2: TButton
          Left = 494
          Top = 9
          Width = 80
          Height = 25
          Action = ActBrowseSrcB2
          Anchors = [akTop, akRight]
          TabOrder = 1
        end
        object btnLoad2: TButton
          Left = 580
          Top = 9
          Width = 80
          Height = 25
          Action = ActLoadSrcB2
          Anchors = [akTop, akRight]
          TabOrder = 2
        end
        object btnClearFText2: TButton
          Left = 287
          Top = 40
          Width = 26
          Height = 25
          Anchors = [akTop, akRight]
          Caption = 'x'
          TabOrder = 3
          OnClick = btnClearFText2Click
        end
        object edtFilter2: TEdit
          Left = 61
          Top = 42
          Width = 220
          Height = 21
          Anchors = [akLeft, akTop, akRight]
          TabOrder = 4
          OnChange = edtFilter2Change
        end
        object btnShowMappedNames2: TButton
          Left = 634
          Top = 40
          Width = 26
          Height = 25
          Anchors = [akTop, akRight]
          Caption = '+'
          TabOrder = 5
          OnClick = btnShowMappedNames2Click
        end
        object cbMappedNames2: TComboBox
          Left = 494
          Top = 42
          Width = 134
          Height = 21
          Anchors = [akTop, akRight]
          TabOrder = 6
          OnChange = cbMappedNames2Change
        end
        object chkUseIgnoredPrefixes2: TCheckBox
          Left = 328
          Top = 44
          Width = 160
          Height = 17
          Anchors = [akTop, akRight]
          Caption = 'Use Ignored Prefixes'
          TabOrder = 7
          OnClick = chkUseIgnoredPrefixes2Click
        end
      end
    end
    object TabSheetModInS: TTabSheet
      Caption = 'Model S (Input Safe)'
      object lvTensorsS: TListView
        AlignWithMargins = True
        Left = 8
        Top = 75
        Width = 652
        Height = 197
        Margins.Left = 8
        Margins.Right = 8
        Align = alClient
        Checkboxes = True
        Columns = <>
        OwnerData = True
        RowSelect = True
        PopupMenu = pmInputTensor
        TabOrder = 0
        ViewStyle = vsReport
        OnCustomDrawSubItem = lvTensorsSCustomDrawSubItem
        OnData = lvTensorsSData
        OnSelectItem = lvTensorSelectItem
      end
      object PanBotEditS: TPanel
        Left = 0
        Top = 275
        Width = 668
        Height = 72
        Align = alBottom
        BevelOuter = bvNone
        TabOrder = 1
        DesignSize = (
          668
          72)
        object lblNameS: TLabel
          Left = 12
          Top = 15
          Width = 37
          Height = 13
          Caption = 'Tensor:'
        end
        object edtNameS: TEdit
          Left = 55
          Top = 11
          Width = 221
          Height = 21
          Anchors = [akLeft, akTop, akRight]
          TabOrder = 0
        end
        object cbDTypeS: TComboBox
          Left = 282
          Top = 11
          Width = 80
          Height = 21
          Style = csDropDownList
          Anchors = [akTop, akRight]
          Enabled = False
          TabOrder = 1
        end
        object btnTransferToOutS: TButton
          Left = 368
          Top = 9
          Width = 80
          Height = 25
          Hint = 'Transfer To Model Out'
          Anchors = [akTop, akRight]
          Caption = 'Transfer >'
          TabOrder = 2
          OnClick = btnTransferToOutSClick
        end
        object cbLayersModS: TComboBox
          Left = 585
          Top = 40
          Width = 59
          Height = 21
          Anchors = [akTop, akRight]
          ItemIndex = 0
          TabOrder = 3
          Text = 'All'
          Items.Strings = (
            'All'
            'Odd'
            'Even'
            'Mod3'
            'Mod4'
            'Mod5'
            'Mod6'
            'Mod7'
            'Mod8')
        end
        object cbLayersToS: TComboBox
          Left = 520
          Top = 40
          Width = 59
          Height = 21
          Anchors = [akTop, akRight]
          TabOrder = 4
          Text = '999'
          Items.Strings = (
            '4'
            '6'
            '8'
            '12'
            '16'
            '32'
            '64'
            '128'
            '512'
            '1024')
        end
        object cbLayersFromS: TComboBox
          Left = 455
          Top = 40
          Width = 59
          Height = 21
          Anchors = [akTop, akRight]
          TabOrder = 5
          Text = '0'
          Items.Strings = (
            '0'
            '1'
            '2'
            '3'
            '4'
            '6'
            '8'
            '12'
            '16')
        end
        object chkAllLayersS: TCheckBox
          Left = 368
          Top = 42
          Width = 74
          Height = 17
          Hint = 'Appliquer a toutes les couches (meme nom de tenseur)'
          Anchors = [akTop, akRight]
          Caption = 'All Layers'
          TabOrder = 6
          OnClick = chkAllLayersSClick
        end
        object btnTranspose: TButton
          Left = 553
          Top = 9
          Width = 75
          Height = 25
          Anchors = [akTop, akRight]
          Caption = 'Transpose'
          TabOrder = 7
          OnClick = btnTransposeClick
        end
        object btnClearTransposition: TButton
          Left = 634
          Top = 9
          Width = 26
          Height = 25
          Anchors = [akTop, akRight]
          Caption = 'x'
          TabOrder = 8
          OnClick = btnClearTranspositionClick
        end
        object btnTransferAllS: TButton
          Left = 454
          Top = 9
          Width = 93
          Height = 25
          Anchors = [akTop, akRight]
          Caption = 'Transfer All >'
          TabOrder = 9
          OnClick = btnTransferAllSClick
        end
      end
      object pnlTopInpS: TPanel
        Left = 0
        Top = 0
        Width = 668
        Height = 72
        Align = alTop
        BevelOuter = bvNone
        TabOrder = 2
        DesignSize = (
          668
          72)
        object lblSrcS: TLabel
          Left = 12
          Top = 16
          Width = 43
          Height = 13
          Caption = 'SourceS:'
        end
        object lbFilterS: TLabel
          Left = 12
          Top = 46
          Width = 31
          Height = 13
          Caption = 'Filter :'
        end
        object edtSrcS: TEdit
          Left = 61
          Top = 11
          Width = 427
          Height = 21
          Anchors = [akLeft, akTop, akRight]
          TabOrder = 0
        end
        object btnBrowseSrcS: TButton
          Left = 494
          Top = 9
          Width = 80
          Height = 25
          Action = ActBrowseSrcS
          Anchors = [akTop, akRight]
          TabOrder = 1
        end
        object btnLoadS: TButton
          Left = 580
          Top = 9
          Width = 80
          Height = 25
          Action = ActLoadSrcS
          Anchors = [akTop, akRight]
          TabOrder = 2
        end
        object btnClearFTextS: TButton
          Left = 287
          Top = 40
          Width = 26
          Height = 25
          Anchors = [akTop, akRight]
          Caption = 'x'
          TabOrder = 3
          OnClick = btnClearFTextSClick
        end
        object edtFilterS: TEdit
          Left = 61
          Top = 42
          Width = 220
          Height = 21
          Anchors = [akLeft, akTop, akRight]
          TabOrder = 4
          OnChange = edtFilterSChange
        end
        object btnShowMappedNamesS: TButton
          Left = 634
          Top = 40
          Width = 26
          Height = 25
          Anchors = [akTop, akRight]
          Caption = '+'
          TabOrder = 5
          OnClick = btnShowMappedNamesSClick
        end
        object cbMappedNamesS: TComboBox
          Left = 494
          Top = 42
          Width = 134
          Height = 21
          Anchors = [akTop, akRight]
          TabOrder = 6
          OnChange = cbMappedNamesSChange
        end
        object chkUseIgnoredPrefixesS: TCheckBox
          Left = 328
          Top = 44
          Width = 160
          Height = 17
          Anchors = [akTop, akRight]
          Caption = 'Use Ignored Prefixes'
          TabOrder = 7
          OnClick = chkUseIgnoredPrefixesSClick
        end
      end
    end
    object TabSheetModOut: TTabSheet
      Caption = 'Model Out (Prepare)'
      ImageIndex = 2
      object lvTensorsOut: TListView
        AlignWithMargins = True
        Left = 8
        Top = 75
        Width = 652
        Height = 197
        Margins.Left = 8
        Margins.Right = 8
        Align = alClient
        Checkboxes = True
        Columns = <>
        RowSelect = True
        PopupMenu = pmOutTensor
        TabOrder = 0
        ViewStyle = vsReport
        OnAdvancedCustomDrawSubItem = lvTensorsOutAdvancedCustomDrawSubItem
        OnSelectItem = lvTensorSelectItem
        OnItemChecked = lvTensorsOutItemChecked
      end
      object PanBotEditOut: TPanel
        Left = 0
        Top = 275
        Width = 668
        Height = 72
        Align = alBottom
        BevelOuter = bvNone
        TabOrder = 1
        DesignSize = (
          668
          72)
        object lblNameOut: TLabel
          Left = 12
          Top = 15
          Width = 37
          Height = 13
          Caption = 'Tensor:'
        end
        object edtNameOut: TEdit
          Left = 55
          Top = 11
          Width = 221
          Height = 21
          Anchors = [akLeft, akTop, akRight]
          ParentShowHint = False
          ShowHint = True
          TabOrder = 0
        end
        object cbDTypeOut: TComboBox
          Left = 362
          Top = 11
          Width = 74
          Height = 21
          Style = csDropDownList
          Anchors = [akTop, akRight]
          ParentShowHint = False
          ShowHint = True
          TabOrder = 1
          OnChange = cbDTypeOutChange
        end
        object cbSrcModelOut1: TComboBox
          Left = 282
          Top = 11
          Width = 74
          Height = 21
          Style = csDropDownList
          Anchors = [akTop, akRight]
          ItemIndex = 0
          ParentShowHint = False
          ShowHint = True
          TabOrder = 2
          Text = 'Model 1'
          OnChange = cbSrcModelOut1Change
          Items.Strings = (
            'Model 1'
            'Model 2'
            'Model S')
        end
        object cbLayersModOut: TComboBox
          Left = 585
          Top = 40
          Width = 59
          Height = 21
          Anchors = [akTop, akRight]
          ItemIndex = 0
          ParentShowHint = False
          ShowHint = True
          TabOrder = 3
          Text = 'All'
          Items.Strings = (
            'All'
            'Odd'
            'Even'
            'Mod3'
            'Mod4'
            'Mod5'
            'Mod6'
            'Mod7'
            'Mod8')
        end
        object cbLayersToOut: TComboBox
          Left = 520
          Top = 40
          Width = 59
          Height = 21
          Anchors = [akTop, akRight]
          ParentShowHint = False
          ShowHint = True
          TabOrder = 4
          Text = '999'
          Items.Strings = (
            '4'
            '6'
            '8'
            '12'
            '16'
            '32'
            '64'
            '128'
            '512'
            '1024')
        end
        object cbLayersFromOut: TComboBox
          Left = 455
          Top = 40
          Width = 59
          Height = 21
          Anchors = [akTop, akRight]
          ParentShowHint = False
          ShowHint = True
          TabOrder = 5
          Text = '0'
          Items.Strings = (
            '0'
            '1'
            '2'
            '3'
            '4'
            '6'
            '8'
            '12'
            '16')
        end
        object chkAllLayersOut: TCheckBox
          Left = 368
          Top = 42
          Width = 74
          Height = 17
          Hint = 'Appliquer a toutes les couches (meme nom de tenseur)'
          Anchors = [akTop, akRight]
          Caption = 'All Layers'
          ParentShowHint = False
          ShowHint = True
          TabOrder = 6
          OnClick = chkAllLayersOutClick
        end
      end
      object pnlTopOut: TPanel
        Left = 0
        Top = 0
        Width = 668
        Height = 72
        Align = alTop
        BevelOuter = bvNone
        TabOrder = 2
        DesignSize = (
          668
          72)
        object lblOut: TLabel
          Left = 12
          Top = 16
          Width = 32
          Height = 13
          Caption = 'Sortie:'
        end
        object lbFilterOut: TLabel
          Left = 12
          Top = 45
          Width = 31
          Height = 13
          Caption = 'Filter :'
        end
        object edtOut: TEdit
          Left = 61
          Top = 11
          Width = 406
          Height = 21
          Anchors = [akLeft, akTop, akRight]
          TabOrder = 0
        end
        object btnBrowseOut: TButton
          Left = 473
          Top = 9
          Width = 80
          Height = 25
          Action = ActBrowseOut
          Anchors = [akTop, akRight]
          TabOrder = 1
        end
        object btnSave: TButton
          Left = 559
          Top = 9
          Width = 70
          Height = 25
          Action = ActSaveOut
          Anchors = [akTop, akRight]
          TabOrder = 2
        end
        object btnCancel: TButton
          Left = 635
          Top = 9
          Width = 25
          Height = 25
          Anchors = [akTop, akRight]
          Caption = 'x'
          Enabled = False
          TabOrder = 3
          OnClick = btnCancelClick
        end
        object btnClearFTextO: TButton
          Left = 287
          Top = 40
          Width = 26
          Height = 25
          Anchors = [akTop, akRight]
          Caption = 'x'
          TabOrder = 4
          OnClick = btnClearFTextOClick
        end
        object edtFilterO: TEdit
          Left = 61
          Top = 42
          Width = 220
          Height = 21
          Anchors = [akLeft, akTop, akRight]
          ParentShowHint = False
          ShowHint = True
          TabOrder = 5
          OnChange = edtFilterOChange
        end
      end
    end
  end
  object StatusBar1: TStatusBar
    Left = 0
    Top = 445
    Width = 676
    Height = 19
    Panels = <
      item
        Width = 400
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
  object ProgressBar1: TProgressBar
    Left = 457
    Top = 448
    Width = 200
    Height = 15
    Anchors = [akRight, akBottom]
    TabOrder = 3
    Visible = False
  end
  object PanBotSize: TPanel
    Left = 0
    Top = 410
    Width = 676
    Height = 35
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 4
    object edtSizeOut: TEdit
      Left = 580
      Top = 8
      Width = 70
      Height = 21
      Hint = 'Model Out File Size'
      Enabled = False
      ParentShowHint = False
      ReadOnly = True
      ShowHint = True
      TabOrder = 0
    end
    object edtSizeIn2: TEdit
      Left = 427
      Top = 8
      Width = 70
      Height = 21
      Hint = 'Model B File Size'
      Enabled = False
      ParentShowHint = False
      ReadOnly = True
      ShowHint = True
      TabOrder = 1
    end
    object edtSizeIn1: TEdit
      Left = 351
      Top = 8
      Width = 70
      Height = 21
      Hint = 'Model A File Size'
      Enabled = False
      ParentShowHint = False
      ReadOnly = True
      ShowHint = True
      TabOrder = 2
    end
    object chkUseDLL: TCheckBox
      Left = 16
      Top = 12
      Width = 117
      Height = 17
      Hint = 'Use external llama.cpp DLL'
      Caption = 'Use DLL'
      ParentShowHint = False
      ShowHint = True
      TabOrder = 3
      OnClick = chkUseDLLClick
    end
    object edtSizeInS: TEdit
      Left = 504
      Top = 8
      Width = 70
      Height = 21
      Hint = 'Model S File Size'
      Enabled = False
      ParentShowHint = False
      ReadOnly = True
      ShowHint = True
      TabOrder = 4
    end
    object chkUseImpl: TCheckBox
      Left = 139
      Top = 12
      Width = 144
      Height = 17
      Hint = 
        'Utiliser Impl :  haute qualit'#233' avec optimisation RMSE  (ou D'#233'coc' +
        'h'#233' Ref : R'#233'f'#233'rence : Algorithme d'#233'terministe (sans optimisation ' +
        'RMSE))'
      Caption = 'Use "Impl" (or "Ref")'
      ParentShowHint = False
      ShowHint = True
      TabOrder = 5
      OnClick = chkUseImplClick
    end
  end
  object ProgressBar2: TProgressBar
    Left = 351
    Top = 448
    Width = 100
    Height = 15
    Anchors = [akRight, akBottom]
    TabOrder = 5
    Visible = False
  end
  object OpenDialog1: TOpenDialog
    Filter = 'GGUF (*.gguf)|*.gguf|All (*.*)|*.*'
    Left = 460
    Top = 160
  end
  object SaveDialog1: TSaveDialog
    Filter = 'GGUF (*.gguf)|*.gguf|All (*.*)|*.*'
    Left = 540
    Top = 160
  end
  object ActionList1: TActionList
    Left = 384
    Top = 160
    object ActBrowseSrcA1: TAction
      Caption = 'Parcourir...'
      OnExecute = ActBrowseSrcA1Execute
    end
    object ActLoadSrcA1: TAction
      Caption = 'Charger'
      OnExecute = ActLoadSrcA1Execute
    end
    object ActBrowseSrcB2: TAction
      Caption = 'Parcourir...'
      OnExecute = ActBrowseSrcB2Execute
    end
    object ActLoadSrcB2: TAction
      Caption = 'Charger'
      OnExecute = ActLoadSrcB2Execute
    end
    object ActBrowseSrcS: TAction
      Caption = 'Parcourir...'
      OnExecute = ActBrowseSrcSExecute
    end
    object ActLoadSrcS: TAction
      Caption = 'Charger'
      OnExecute = ActLoadSrcSExecute
    end
    object ActSaveOut: TAction
      Caption = 'Save'
      OnExecute = ActSaveOutExecute
    end
    object ActBrowseOut: TAction
      Caption = 'Parcourir...'
      OnExecute = ActBrowseOutExecute
    end
    object ActViewKVs: TAction
      Caption = 'View KVs'
      OnExecute = ActViewKVsExecute
    end
    object ActViewTensors: TAction
      Caption = 'View Tensors'
      OnExecute = ActViewTensorsExecute
    end
    object ActSettings: TAction
      Caption = 'Settings'
      OnExecute = ActSettingsExecute
    end
    object ActSplitMerge: TAction
      Caption = 'Split / Merge'
      OnExecute = ActSplitMergeExecute
    end
    object ActShowLogs: TAction
      Caption = 'Show Logs'
      OnExecute = ActShowLogsExecute
    end
    object ActAbout: TAction
      Caption = #192' propos'
      OnExecute = ActAboutExecute
    end
    object ActHelp: TAction
      Caption = 'Aide'
      OnExecute = ActHelpExecute
    end
  end
  object MainMenu1: TMainMenu
    Left = 312
    Top = 160
    object mnuFile: TMenuItem
      AutoHotkeys = maManual
      AutoLineReduction = maManual
      Caption = 'Fichier'
      object mnuModelA: TMenuItem
        AutoHotkeys = maManual
        AutoLineReduction = maManual
        Caption = 'Model A (Input 1 gguf)'
        object Parcourir1: TMenuItem
          Action = ActBrowseSrcA1
        end
        object Charger1: TMenuItem
          Action = ActLoadSrcA1
        end
      end
      object mnuModelB: TMenuItem
        AutoHotkeys = maManual
        Caption = 'Model B (Input 2 gguf)'
        object Parcourir2: TMenuItem
          Action = ActBrowseSrcB2
          AutoHotkeys = maManual
        end
        object Charger2: TMenuItem
          Action = ActLoadSrcB2
          AutoHotkeys = maManual
        end
      end
      object mnuModelS: TMenuItem
        AutoHotkeys = maManual
        Caption = 'Model S (Input Safetensors)'
        object Parcourir3: TMenuItem
          Action = ActBrowseSrcS
          AutoHotkeys = maManual
        end
        object Charger3: TMenuItem
          Action = ActLoadSrcS
          AutoHotkeys = maManual
        end
      end
      object mnuSep1: TMenuItem
        Caption = '-'
      end
      object mnuModelOut: TMenuItem
        AutoHotkeys = maManual
        Caption = 'Model Out (Prepare)'
        object Parcourir4: TMenuItem
          Action = ActBrowseOut
        end
        object Save1: TMenuItem
          Action = ActSaveOut
        end
      end
      object mnuSep2: TMenuItem
        Caption = '-'
      end
      object mnuExit: TMenuItem
        AutoHotkeys = maManual
        Caption = '&Quitter'
        OnClick = mnuExitClick
      end
    end
    object mnuView: TMenuItem
      AutoHotkeys = maManual
      Caption = 'V&ue'
      object mnuKVs: TMenuItem
        Action = ActViewKVs
        AutoHotkeys = maManual
      end
      object mnuTensorVisu: TMenuItem
        Action = ActViewTensors
        AutoHotkeys = maManual
      end
      object mnuSep3: TMenuItem
        Caption = '-'
      end
      object mnuLogs: TMenuItem
        Action = ActShowLogs
        AutoHotkeys = maManual
      end
    end
    object mnuTools: TMenuItem
      AutoHotkeys = maManual
      Caption = 'Outils'
      object mnuSettings: TMenuItem
        Action = ActSettings
        AutoHotkeys = maManual
        Caption = 'P&aram'#232'tres'
      end
      object MmLangue11: TMenuItem
        AutoHotkeys = maManual
        Caption = 'Language'
      end
      object mnuSep4: TMenuItem
        Caption = '-'
      end
      object mnuSplitMerge: TMenuItem
        Action = ActSplitMerge
        AutoHotkeys = maManual
      end
    end
    object mnuHelpDoc: TMenuItem
      AutoHotkeys = maManual
      Caption = 'Aide'
      object mnuDocs: TMenuItem
        Action = ActHelp
        AutoHotkeys = maManual
      end
      object mnuSep5: TMenuItem
        Caption = '-'
      end
      object mnuAbout: TMenuItem
        Action = ActAbout
        AutoHotkeys = maManual
      end
    end
  end
  object pmOutTensor: TPopupMenu
    AutoHotkeys = maManual
    Left = 204
    Top = 163
    object mnuQuant: TMenuItem
      Caption = 'Quant'
    end
    object mnuSourceOut: TMenuItem
      Caption = 'Source'
      object mnuSourceOutM1: TMenuItem
        Caption = 'Model 1'
        OnClick = mnuSourceOutClick
      end
      object mnuSourceOutM2: TMenuItem
        Tag = 1
        Caption = 'Model 2'
        OnClick = mnuSourceOutClick
      end
      object mnuSourceOutM3: TMenuItem
        Tag = 2
        Caption = 'Model S'
        OnClick = mnuSourceOutClick
      end
    end
  end
  object pmInputTensor: TPopupMenu
    Left = 108
    Top = 163
    object miTransferSelected: TMenuItem
      Caption = 'Transfer Selected '
      OnClick = miTransferSelectedClick
    end
    object miTransferAll: TMenuItem
      Caption = 'Transfer All >'
      OnClick = miTransferAllClick
    end
  end
end
