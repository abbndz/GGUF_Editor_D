object frmEditTensors: TfrmEditTensors
  Left = 0
  Top = 0
  Caption = 'GGUF Editor D++'
  ClientHeight = 408
  ClientWidth = 604
  Color = clBtnFace
  Constraints.MinHeight = 400
  Constraints.MinWidth = 620
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  Menu = MainMenu1
  Position = poDesigned
  OnClose = FormClose
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  OnResize = FormResize
  OnShow = FormShow
  DesignSize = (
    604
    408)
  TextHeight = 13
  object pnlTopInp0: TPanel
    Left = 0
    Top = 0
    Width = 604
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
    Width = 604
    Height = 351
    Margins.Left = 12
    Margins.Right = 12
    ActivePage = TabSheetModInA
    Align = alClient
    TabOrder = 1
    OnChange = PageControl1Change
    ExplicitHeight = 353
    object TabSheetModInA: TTabSheet
      Caption = 'Model A (Input 1 gguf)'
      object lvTensors1: TListView
        AlignWithMargins = True
        Left = 8
        Top = 75
        Width = 580
        Height = 207
        Margins.Left = 8
        Margins.Right = 8
        Align = alClient
        Columns = <
          item
            Caption = 'Tensor'
            Width = 180
          end
          item
            Caption = 'DType'
            Width = 64
          end
          item
            Caption = 'Shape'
            Width = 88
          end
          item
            Caption = 'Layer'
            Width = 26
          end
          item
            Caption = 'Size'
            Width = 56
          end
          item
            Caption = 'Size %'
            Width = 54
          end
          item
            Caption = 'TSize'
            Width = 56
          end
          item
            Caption = 'TSize %'
            Width = 54
          end
          item
            Caption = 'Off'
            Width = 0
          end
          item
            Caption = 'Src'
            Width = 24
          end
          item
            Caption = 'SrcDType'
            Width = 0
          end
          item
            Caption = 'Impl'
            Width = 0
          end
          item
            Caption = 'RmseType'
            Width = 0
          end>
        DragMode = dmAutomatic
        RowSelect = True
        PopupMenu = pmInputTensor
        TabOrder = 0
        ViewStyle = vsReport
        OnAdvancedCustomDrawItem = lvTensors1AdvancedCustomDrawItem
        OnAdvancedCustomDrawSubItem = lvTensors1AdvancedCustomDrawSubItem
        OnColumnClick = lvTensors1ColumnClick
        OnSelectItem = lvTensorSelectItem
        ExplicitHeight = 209
      end
      object PanBotEdit1: TPanel
        Left = 0
        Top = 285
        Width = 596
        Height = 38
        Align = alBottom
        BevelOuter = bvNone
        TabOrder = 1
        ExplicitTop = 287
        DesignSize = (
          596
          38)
        object edtName1: TEdit
          Left = 8
          Top = 9
          Width = 149
          Height = 21
          Anchors = [akLeft, akTop, akRight]
          TabOrder = 0
        end
        object cbDType1: TComboBox
          Left = 163
          Top = 9
          Width = 60
          Height = 21
          Style = csDropDownList
          Anchors = [akTop, akRight]
          Enabled = False
          TabOrder = 1
        end
        object btnTransferToOut1: TButton
          Left = 229
          Top = 7
          Width = 28
          Height = 25
          Hint = 'Transfer To Model Out'
          Anchors = [akTop, akRight]
          Caption = ' > '
          TabOrder = 2
          OnClick = btnTransferToOut1Click
        end
        object chkAllLayers1: TCheckBox
          Left = 297
          Top = 11
          Width = 120
          Height = 17
          Hint = 'Appliquer a toutes les couches (meme nom de tenseur)'
          Anchors = [akTop, akRight]
          Caption = 'All Layers'
          Checked = True
          State = cbChecked
          TabOrder = 4
          OnClick = chkAllLayers1Click
        end
        object cbLayersFrom1: TComboBox
          Left = 429
          Top = 9
          Width = 40
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
        object cbLayersTo1: TComboBox
          Left = 475
          Top = 9
          Width = 42
          Height = 21
          Anchors = [akTop, akRight]
          TabOrder = 6
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
          Left = 523
          Top = 9
          Width = 65
          Height = 21
          Anchors = [akTop, akRight]
          ItemIndex = 0
          TabOrder = 7
          Text = 'All'
          Items.Strings = (
            'All'
            'Odd'
            'Even'
            'Mod3'
            'Mod4'
            'Mod4+1'
            'Mod4+2'
            'Mod5'
            'Mod6'
            'Mod7'
            'Mod8')
        end
        object btnTransferAll1: TButton
          Left = 263
          Top = 7
          Width = 28
          Height = 25
          Anchors = [akTop, akRight]
          Caption = '>>'
          TabOrder = 3
          OnClick = btnTransferAll1Click
        end
      end
      object pnlTopInp1: TPanel
        Left = 0
        Top = 0
        Width = 596
        Height = 72
        Align = alTop
        BevelOuter = bvNone
        TabOrder = 2
        DesignSize = (
          596
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
          Left = 508
          Top = 9
          Width = 80
          Height = 25
          Action = ActLoadSrcA1
          Anchors = [akTop, akRight]
          TabOrder = 2
        end
        object btnBrowseSrc1: TButton
          Left = 422
          Top = 11
          Width = 80
          Height = 25
          Action = ActBrowseSrcA1
          Anchors = [akTop, akRight]
          TabOrder = 1
        end
        object edtSrc1: TEdit
          Left = 61
          Top = 11
          Width = 355
          Height = 21
          Anchors = [akLeft, akTop, akRight]
          TabOrder = 0
        end
        object btnClearFText1: TButton
          Left = 215
          Top = 40
          Width = 26
          Height = 25
          Anchors = [akTop, akRight]
          Caption = 'x'
          TabOrder = 4
          OnClick = btnClearFText1Click
        end
        object edtFilter1: TEdit
          Left = 61
          Top = 42
          Width = 148
          Height = 21
          Anchors = [akLeft, akTop, akRight]
          TabOrder = 3
          OnChange = edtFilter1Change
        end
        object btnShowMappedNames1: TButton
          Left = 562
          Top = 40
          Width = 26
          Height = 25
          Anchors = [akTop, akRight]
          Caption = '+'
          TabOrder = 7
          OnClick = btnShowMappedNames1Click
        end
        object cbMappedNames1: TComboBox
          Left = 422
          Top = 42
          Width = 134
          Height = 21
          Anchors = [akTop, akRight]
          TabOrder = 6
          OnClick = cbMappedNames1Click
        end
        object chkUseIgnoredPrefixes1: TCheckBox
          Left = 256
          Top = 44
          Width = 160
          Height = 17
          Anchors = [akTop, akRight]
          Caption = 'Use Ignored Prefixes'
          TabOrder = 5
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
        Width = 580
        Height = 207
        Margins.Left = 8
        Margins.Right = 8
        Align = alClient
        Columns = <
          item
            Caption = 'Tensor'
            Width = 180
          end
          item
            Caption = 'DType'
            Width = 64
          end
          item
            Caption = 'Shape'
            Width = 88
          end
          item
            Caption = 'Layer'
            Width = 26
          end
          item
            Caption = 'Size'
            Width = 56
          end
          item
            Caption = 'Size %'
            Width = 54
          end
          item
            Caption = 'TSize'
            Width = 56
          end
          item
            Caption = 'TSize %'
            Width = 54
          end
          item
            Caption = 'Off'
            Width = 0
          end
          item
            Caption = 'Src'
            Width = 24
          end
          item
            Caption = 'SrcDType'
            Width = 0
          end
          item
            Caption = 'Impl'
            Width = 0
          end
          item
            Caption = 'RmseType'
            Width = 0
          end>
        RowSelect = True
        PopupMenu = pmInputTensor
        TabOrder = 0
        ViewStyle = vsReport
        OnAdvancedCustomDrawItem = lvTensors1AdvancedCustomDrawItem
        OnAdvancedCustomDrawSubItem = lvTensors2AdvancedCustomDrawSubItem
        OnColumnClick = lvTensors2ColumnClick
        OnSelectItem = lvTensorSelectItem
      end
      object PanBotEdit2: TPanel
        Left = 0
        Top = 285
        Width = 596
        Height = 38
        Align = alBottom
        BevelOuter = bvNone
        TabOrder = 1
        ExplicitTop = 287
        DesignSize = (
          596
          38)
        object edtName2: TEdit
          Left = 8
          Top = 9
          Width = 149
          Height = 21
          Anchors = [akLeft, akTop, akRight]
          TabOrder = 0
        end
        object cbDType2: TComboBox
          Left = 163
          Top = 9
          Width = 60
          Height = 21
          Style = csDropDownList
          Anchors = [akTop, akRight]
          Enabled = False
          TabOrder = 1
        end
        object btnTransferToOut2: TButton
          Left = 229
          Top = 7
          Width = 28
          Height = 25
          Hint = 'Transfer To Model Out'
          Anchors = [akTop, akRight]
          Caption = '>'
          TabOrder = 2
          OnClick = btnTransferToOut2Click
        end
        object cbLayersMod2: TComboBox
          Left = 523
          Top = 9
          Width = 65
          Height = 21
          Anchors = [akTop, akRight]
          ItemIndex = 0
          TabOrder = 7
          Text = 'All'
          Items.Strings = (
            'All'
            'Odd'
            'Even'
            'Mod3'
            'Mod4'
            'Mod4+1'
            'Mod4+2'
            'Mod5'
            'Mod6'
            'Mod7'
            'Mod8')
        end
        object cbLayersTo2: TComboBox
          Left = 477
          Top = 9
          Width = 40
          Height = 21
          Anchors = [akTop, akRight]
          TabOrder = 6
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
          Left = 431
          Top = 9
          Width = 40
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
          Left = 297
          Top = 11
          Width = 120
          Height = 17
          Hint = 'Appliquer a toutes les couches (meme nom de tenseur)'
          Anchors = [akTop, akRight]
          Caption = 'All Layers'
          Checked = True
          State = cbChecked
          TabOrder = 4
          OnClick = chkAllLayers2Click
        end
        object btnTransferAll2: TButton
          Left = 263
          Top = 7
          Width = 28
          Height = 25
          Anchors = [akTop, akRight]
          Caption = '>>'
          TabOrder = 3
          OnClick = btnTransferAll2Click
        end
      end
      object pnlTopInp2: TPanel
        Left = 0
        Top = 0
        Width = 596
        Height = 72
        Align = alTop
        BevelOuter = bvNone
        TabOrder = 2
        DesignSize = (
          596
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
          Width = 355
          Height = 21
          Anchors = [akLeft, akTop, akRight]
          TabOrder = 0
        end
        object btnBrowseSrc2: TButton
          Left = 422
          Top = 9
          Width = 80
          Height = 25
          Action = ActBrowseSrcB2
          Anchors = [akTop, akRight]
          TabOrder = 1
        end
        object btnLoad2: TButton
          Left = 508
          Top = 9
          Width = 80
          Height = 25
          Action = ActLoadSrcB2
          Anchors = [akTop, akRight]
          TabOrder = 2
        end
        object btnClearFText2: TButton
          Left = 215
          Top = 40
          Width = 26
          Height = 25
          Anchors = [akTop, akRight]
          Caption = 'x'
          TabOrder = 4
          OnClick = btnClearFText2Click
        end
        object edtFilter2: TEdit
          Left = 61
          Top = 42
          Width = 148
          Height = 21
          Anchors = [akLeft, akTop, akRight]
          TabOrder = 3
          OnChange = edtFilter2Change
        end
        object btnShowMappedNames2: TButton
          Left = 562
          Top = 40
          Width = 26
          Height = 25
          Anchors = [akTop, akRight]
          Caption = '+'
          TabOrder = 7
          OnClick = btnShowMappedNames2Click
        end
        object cbMappedNames2: TComboBox
          Left = 422
          Top = 42
          Width = 134
          Height = 21
          Anchors = [akTop, akRight]
          TabOrder = 6
          OnClick = cbMappedNames2Click
        end
        object chkUseIgnoredPrefixes2: TCheckBox
          Left = 256
          Top = 44
          Width = 160
          Height = 17
          Anchors = [akTop, akRight]
          Caption = 'Use Ignored Prefixes'
          TabOrder = 5
          OnClick = chkUseIgnoredPrefixes2Click
        end
      end
    end
    object TabSheetModInC: TTabSheet
      Caption = 'Model C (Input 3 gguf)'
      ImageIndex = 4
      object lvTensors3: TListView
        AlignWithMargins = True
        Left = 8
        Top = 75
        Width = 580
        Height = 207
        Margins.Left = 8
        Margins.Right = 8
        Align = alClient
        Columns = <
          item
            Caption = 'Tensor'
            Width = 180
          end
          item
            Caption = 'DType'
            Width = 64
          end
          item
            Caption = 'Shape'
            Width = 88
          end
          item
            Caption = 'Layer'
            Width = 26
          end
          item
            Caption = 'Size'
            Width = 56
          end
          item
            Caption = 'Size %'
            Width = 54
          end
          item
            Caption = 'TSize'
            Width = 56
          end
          item
            Caption = 'TSize %'
            Width = 54
          end
          item
            Caption = 'Off'
            Width = 0
          end
          item
            Caption = 'Src'
            Width = 24
          end
          item
            Caption = 'SrcDType'
            Width = 0
          end
          item
            Caption = 'Impl'
            Width = 0
          end
          item
            Caption = 'RmseType'
            Width = 0
          end>
        RowSelect = True
        PopupMenu = pmInputTensor
        TabOrder = 0
        ViewStyle = vsReport
        OnAdvancedCustomDrawItem = lvTensors1AdvancedCustomDrawItem
        OnAdvancedCustomDrawSubItem = lvTensors3AdvancedCustomDrawSubItem
        OnColumnClick = lvTensors3ColumnClick
        OnSelectItem = lvTensorSelectItem
      end
      object PanBotEdit3: TPanel
        Left = 0
        Top = 285
        Width = 596
        Height = 38
        Align = alBottom
        BevelOuter = bvNone
        TabOrder = 1
        ExplicitTop = 287
        DesignSize = (
          596
          38)
        object edtName3: TEdit
          Left = 8
          Top = 9
          Width = 149
          Height = 21
          Anchors = [akLeft, akTop, akRight]
          TabOrder = 0
        end
        object cbDType3: TComboBox
          Left = 163
          Top = 9
          Width = 60
          Height = 21
          Style = csDropDownList
          Anchors = [akTop, akRight]
          Enabled = False
          TabOrder = 1
        end
        object btnTransferToOut3: TButton
          Left = 229
          Top = 7
          Width = 28
          Height = 25
          Hint = 'Transfer To Model Out'
          Anchors = [akTop, akRight]
          Caption = '>'
          TabOrder = 2
          OnClick = btnTransferToOut3Click
        end
        object cbLayersMod3: TComboBox
          Left = 523
          Top = 9
          Width = 65
          Height = 21
          Anchors = [akTop, akRight]
          TabOrder = 7
          Text = 'All'
          Items.Strings = (
            'All'
            'Odd'
            'Even'
            'Mod3'
            'Mod4'
            'Mod4+1'
            'Mod4+2'
            'Mod5'
            'Mod6'
            'Mod7'
            'Mod8')
        end
        object cbLayersTo3: TComboBox
          Left = 475
          Top = 9
          Width = 42
          Height = 21
          Anchors = [akTop, akRight]
          TabOrder = 6
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
        object cbLayersFrom3: TComboBox
          Left = 429
          Top = 9
          Width = 40
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
        object chkAllLayers3: TCheckBox
          Left = 297
          Top = 11
          Width = 120
          Height = 17
          Hint = 'Appliquer a toutes les couches (meme nom de tenseur)'
          Anchors = [akTop, akRight]
          Caption = 'All Layers'
          Checked = True
          State = cbChecked
          TabOrder = 4
          OnClick = chkAllLayers3Click
        end
        object btnTransferAll3: TButton
          Left = 263
          Top = 7
          Width = 28
          Height = 25
          Anchors = [akTop, akRight]
          Caption = '>>'
          TabOrder = 3
          OnClick = btnTransferAll3Click
        end
      end
      object pnlTopInp3: TPanel
        Left = 0
        Top = 0
        Width = 596
        Height = 72
        Align = alTop
        BevelOuter = bvNone
        TabOrder = 2
        DesignSize = (
          596
          72)
        object lblSrc3: TLabel
          Left = 12
          Top = 16
          Width = 43
          Height = 13
          Caption = 'Source3:'
        end
        object lbFilter3: TLabel
          Left = 12
          Top = 45
          Width = 31
          Height = 13
          Caption = 'Filter :'
        end
        object edtSrc3: TEdit
          Left = 61
          Top = 11
          Width = 355
          Height = 21
          Anchors = [akLeft, akTop, akRight]
          TabOrder = 0
        end
        object btnBrowseSrc3: TButton
          Left = 422
          Top = 9
          Width = 80
          Height = 25
          Action = ActBrowseSrcB2
          Anchors = [akTop, akRight]
          TabOrder = 1
          OnClick = ActBrowseSrcC3Execute
        end
        object btnLoad3: TButton
          Left = 508
          Top = 9
          Width = 80
          Height = 25
          Action = ActLoadSrcB2
          Anchors = [akTop, akRight]
          TabOrder = 2
          OnClick = ActLoadSrcC3Execute
        end
        object btnClearFText3: TButton
          Left = 215
          Top = 40
          Width = 26
          Height = 25
          Anchors = [akTop, akRight]
          Caption = 'x'
          TabOrder = 4
          OnClick = btnClearFText3Click
        end
        object edtFilter3: TEdit
          Left = 61
          Top = 42
          Width = 148
          Height = 21
          Anchors = [akLeft, akTop, akRight]
          TabOrder = 3
          OnChange = edtFilter3Change
        end
        object btnShowMappedNames3: TButton
          Left = 562
          Top = 40
          Width = 26
          Height = 25
          Anchors = [akTop, akRight]
          Caption = '+'
          TabOrder = 7
          OnClick = btnShowMappedNames3Click
        end
        object cbMappedNames3: TComboBox
          Left = 422
          Top = 42
          Width = 134
          Height = 21
          Anchors = [akTop, akRight]
          TabOrder = 6
          OnClick = cbMappedNames3Click
        end
        object chkUseIgnoredPrefixes3: TCheckBox
          Left = 256
          Top = 44
          Width = 160
          Height = 17
          Anchors = [akTop, akRight]
          Caption = 'Use Ignored Prefixes'
          TabOrder = 5
          OnClick = chkUseIgnoredPrefixes3Click
        end
      end
    end
    object TabSheetModInS: TTabSheet
      Caption = 'Model S (Input Safe)'
      object lvTensorsS: TListView
        AlignWithMargins = True
        Left = 8
        Top = 75
        Width = 580
        Height = 207
        Margins.Left = 8
        Margins.Right = 8
        Align = alClient
        Columns = <
          item
            Caption = 'Tensor'
            Width = 180
          end
          item
            Caption = 'DType'
            Width = 64
          end
          item
            Caption = 'Shape'
            Width = 88
          end
          item
            Caption = 'Layer'
            Width = 26
          end
          item
            Caption = 'Size'
            Width = 56
          end
          item
            Caption = 'Size %'
            Width = 54
          end
          item
            Caption = 'TSize'
            Width = 56
          end
          item
            Caption = 'TSize %'
            Width = 54
          end
          item
            Caption = 'Off'
            Width = 0
          end
          item
            Caption = 'Src'
            Width = 24
          end
          item
            Caption = 'SrcDType'
            Width = 0
          end
          item
            Caption = 'Impl'
            Width = 0
          end
          item
            Caption = 'RmseType'
            Width = 0
          end>
        OwnerData = True
        RowSelect = True
        PopupMenu = pmInputTensor
        TabOrder = 0
        ViewStyle = vsReport
        OnAdvancedCustomDrawItem = lvTensors1AdvancedCustomDrawItem
        OnColumnClick = lvTensorsSColumnClick
        OnCustomDrawSubItem = lvTensorsSCustomDrawSubItem
        OnData = lvTensorsSData
        OnSelectItem = lvTensorSelectItem
      end
      object PanBotEditS: TPanel
        Left = 0
        Top = 285
        Width = 596
        Height = 38
        Align = alBottom
        BevelOuter = bvNone
        TabOrder = 1
        ExplicitTop = 287
        DesignSize = (
          596
          38)
        object edtNameS: TEdit
          Left = 8
          Top = 9
          Width = 149
          Height = 21
          Anchors = [akLeft, akTop, akRight]
          TabOrder = 0
        end
        object cbDTypeS: TComboBox
          Left = 163
          Top = 9
          Width = 60
          Height = 21
          Style = csDropDownList
          Anchors = [akTop, akRight]
          Enabled = False
          TabOrder = 1
        end
        object btnTransferToOutS: TButton
          Left = 229
          Top = 7
          Width = 28
          Height = 25
          Hint = 'Transfer To Model Out'
          Anchors = [akTop, akRight]
          Caption = ' > '
          TabOrder = 2
          OnClick = btnTransferToOutSClick
        end
        object cbLayersModS: TComboBox
          Left = 529
          Top = 9
          Width = 59
          Height = 21
          Anchors = [akTop, akRight]
          TabOrder = 9
          Text = 'All'
          Items.Strings = (
            'All'
            'Odd'
            'Even'
            'Mod3'
            'Mod4'
            'Mod4+1'
            'Mod4+2'
            'Mod5'
            'Mod6'
            'Mod7'
            'Mod8')
        end
        object cbLayersToS: TComboBox
          Left = 481
          Top = 9
          Width = 42
          Height = 21
          Anchors = [akTop, akRight]
          TabOrder = 8
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
          Left = 435
          Top = 9
          Width = 40
          Height = 21
          Anchors = [akTop, akRight]
          TabOrder = 7
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
          Left = 365
          Top = 11
          Width = 65
          Height = 17
          Hint = 'Appliquer a toutes les couches (meme nom de tenseur)'
          Anchors = [akTop, akRight]
          Caption = 'All Layers'
          Checked = True
          State = cbChecked
          TabOrder = 6
          OnClick = chkAllLayersSClick
        end
        object btnTranspose: TButton
          Left = 297
          Top = 7
          Width = 28
          Height = 25
          Anchors = [akTop, akRight]
          Caption = 'T'
          TabOrder = 4
          OnClick = btnTransposeClick
        end
        object btnClearTransposition: TButton
          Left = 331
          Top = 7
          Width = 28
          Height = 25
          Anchors = [akTop, akRight]
          Caption = 'x'
          TabOrder = 5
          OnClick = btnClearTranspositionClick
        end
        object btnTransferAllS: TButton
          Left = 263
          Top = 7
          Width = 28
          Height = 25
          Anchors = [akTop, akRight]
          Caption = '>>'
          TabOrder = 3
          OnClick = btnTransferAllSClick
        end
      end
      object pnlTopInpS: TPanel
        Left = 0
        Top = 0
        Width = 596
        Height = 72
        Align = alTop
        BevelOuter = bvNone
        TabOrder = 2
        DesignSize = (
          596
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
          Width = 355
          Height = 21
          Anchors = [akLeft, akTop, akRight]
          TabOrder = 0
        end
        object btnBrowseSrcS: TButton
          Left = 422
          Top = 9
          Width = 80
          Height = 25
          Action = ActBrowseSrcS
          Anchors = [akTop, akRight]
          TabOrder = 1
        end
        object btnLoadS: TButton
          Left = 508
          Top = 9
          Width = 80
          Height = 25
          Action = ActLoadSrcS
          Anchors = [akTop, akRight]
          TabOrder = 2
        end
        object btnClearFTextS: TButton
          Left = 215
          Top = 40
          Width = 26
          Height = 25
          Anchors = [akTop, akRight]
          Caption = 'x'
          TabOrder = 4
          OnClick = btnClearFTextSClick
        end
        object edtFilterS: TEdit
          Left = 61
          Top = 42
          Width = 148
          Height = 21
          Anchors = [akLeft, akTop, akRight]
          TabOrder = 3
          OnChange = edtFilterSChange
        end
        object btnShowMappedNamesS: TButton
          Left = 562
          Top = 40
          Width = 26
          Height = 25
          Anchors = [akTop, akRight]
          Caption = '+'
          TabOrder = 7
          OnClick = btnShowMappedNamesSClick
        end
        object cbMappedNamesS: TComboBox
          Left = 422
          Top = 42
          Width = 134
          Height = 21
          Anchors = [akTop, akRight]
          TabOrder = 6
          OnClick = cbMappedNamesSClick
        end
        object chkUseIgnoredPrefixesS: TCheckBox
          Left = 256
          Top = 44
          Width = 160
          Height = 17
          Anchors = [akTop, akRight]
          Caption = 'Use Ignored Prefixes'
          TabOrder = 5
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
        Width = 580
        Height = 209
        Margins.Left = 8
        Margins.Right = 8
        Align = alClient
        Checkboxes = True
        Columns = <
          item
            Caption = 'Tensor'
            Width = 180
          end
          item
            Caption = 'DType'
            Width = 64
          end
          item
            Caption = 'Shape'
            Width = 88
          end
          item
            Caption = 'Layer'
            Width = 26
          end
          item
            Caption = 'Size'
            Width = 56
          end
          item
            Caption = 'Size %'
            Width = 54
          end
          item
            Caption = 'TSize'
            Width = 56
          end
          item
            Caption = 'TSize %'
            Width = 54
          end
          item
            Caption = 'Off'
            Width = 0
          end
          item
            Caption = 'Src'
            Width = 24
          end
          item
            Caption = 'SrcDType'
            Width = 64
          end
          item
            Caption = 'Impl'
            Width = 24
          end
          item
            Caption = 'RmseType'
            Width = 24
          end>
        RowSelect = True
        PopupMenu = pmOutTensor
        TabOrder = 0
        ViewStyle = vsReport
        OnAdvancedCustomDrawItem = lvTensors1AdvancedCustomDrawItem
        OnAdvancedCustomDrawSubItem = lvTensorsOutAdvancedCustomDrawSubItem
        OnColumnClick = lvTensorsOutColumnClick
        OnSelectItem = lvTensorSelectItem
        OnItemChecked = lvTensorsOutItemChecked
      end
      object PanBotEditOut: TPanel
        Left = 0
        Top = 287
        Width = 596
        Height = 36
        Align = alBottom
        BevelOuter = bvNone
        TabOrder = 1
        ExplicitTop = 289
        DesignSize = (
          596
          36)
        object cbDTypeOut: TComboBox
          Left = 229
          Top = 8
          Width = 60
          Height = 21
          Style = csDropDownList
          Anchors = [akTop, akRight]
          ParentShowHint = False
          ShowHint = True
          TabOrder = 1
          OnClick = cbDTypeOutClick
        end
        object cbSrcModelOut1: TComboBox
          Left = 163
          Top = 8
          Width = 60
          Height = 21
          Style = csDropDownList
          Anchors = [akTop, akRight]
          ItemIndex = 0
          ParentShowHint = False
          ShowHint = True
          TabOrder = 0
          Text = 'Model 1'
          OnChange = cbSrcModelOut1Change
          Items.Strings = (
            'Model 1'
            'Model 2'
            'Model 3'
            'Model S')
        end
        object cbLayersModOut: TComboBox
          Left = 523
          Top = 8
          Width = 65
          Height = 21
          Anchors = [akTop, akRight]
          ParentShowHint = False
          ShowHint = True
          TabOrder = 5
          Text = 'All'
          Items.Strings = (
            'All'
            'Odd'
            'Even'
            'Mod3'
            'Mod4'
            'Mod4+1'
            'Mod4+2'
            'Mod5'
            'Mod6'
            'Mod7'
            'Mod8')
        end
        object cbLayersToOut: TComboBox
          Left = 475
          Top = 8
          Width = 42
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
          Left = 429
          Top = 8
          Width = 40
          Height = 21
          Anchors = [akTop, akRight]
          ParentShowHint = False
          ShowHint = True
          TabOrder = 3
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
          Left = 297
          Top = 10
          Width = 130
          Height = 17
          Hint = 'Appliquer a toutes les couches (meme nom de tenseur)'
          Anchors = [akTop, akRight]
          Caption = 'All Layers'
          Checked = True
          ParentShowHint = False
          ShowHint = True
          State = cbChecked
          TabOrder = 2
          OnClick = chkAllLayersOutClick
        end
        object cbUseImpl: TComboBox
          Left = 8
          Top = 8
          Width = 101
          Height = 21
          Hint = 
            'Utiliser Impl :  haute qualit'#233' avec optimisation RMSE  (ou D'#233'coc' +
            'h'#233' Ref : R'#233'f'#233'rence : Algorithme d'#233'terministe (sans optimisation ' +
            'RMSE))'
          ItemIndex = 2
          ParentShowHint = False
          ShowHint = True
          TabOrder = 6
          Text = 'DLL-Impl0'
          OnClick = cbUseImplClick
          Items.Strings = (
            'DLL-Ref'
            'Pas-Ref'
            'DLL-Impl0'
            'Pas-Impl1'
            'Pas-Impl2'
            'Pas-Impl3'
            'Pas-Impl4'
            'Pas-Impl5')
        end
        object cbRmseType: TComboBox
          Left = 115
          Top = 8
          Width = 42
          Height = 21
          Hint = 'Rmse Type'
          Anchors = [akLeft, akTop, akRight]
          ItemIndex = 3
          ParentShowHint = False
          ShowHint = True
          TabOrder = 7
          Text = '3: Magnitude (|x|)'
          OnClick = cbRmseTypeClick
          Items.Strings = (
            '0: Simple (no optimization)'
            '1: Uniform (1.0)'
            '2: Sqrt Magnitude ('#8730'|x|)'
            '3: Magnitude (|x|)'
            '4: Variance (x'#178')')
        end
      end
      object pnlTopOut: TPanel
        Left = 0
        Top = 0
        Width = 596
        Height = 72
        Align = alTop
        BevelOuter = bvNone
        TabOrder = 2
        DesignSize = (
          596
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
          Width = 334
          Height = 21
          Anchors = [akLeft, akTop, akRight]
          TabOrder = 0
        end
        object btnBrowseOut: TButton
          Left = 401
          Top = 9
          Width = 80
          Height = 25
          Action = ActBrowseOut
          Anchors = [akTop, akRight]
          TabOrder = 1
        end
        object btnSave: TButton
          Left = 487
          Top = 9
          Width = 70
          Height = 25
          Action = ActSaveOut
          Anchors = [akTop, akRight]
          TabOrder = 2
        end
        object btnCancel: TButton
          Left = 563
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
          Left = 215
          Top = 40
          Width = 26
          Height = 25
          Anchors = [akTop, akRight]
          Caption = 'x'
          TabOrder = 5
          OnClick = btnClearFTextOClick
        end
        object edtFilterO: TEdit
          Left = 61
          Top = 42
          Width = 148
          Height = 21
          Anchors = [akLeft, akTop, akRight]
          ParentShowHint = False
          ShowHint = True
          TabOrder = 4
          OnChange = edtFilterOChange
        end
        object edtNameOut: TEdit
          Left = 248
          Top = 42
          Width = 340
          Height = 21
          Anchors = [akTop, akRight]
          ParentShowHint = False
          ShowHint = True
          TabOrder = 6
        end
      end
    end
  end
  object stBar1: TStatusBar
    Left = 0
    Top = 389
    Width = 604
    Height = 19
    Panels = <
      item
        Width = 380
      end
      item
        Width = 62
      end
      item
        Width = 62
      end
      item
        Width = 62
      end
      item
        Width = 62
      end
      item
        Width = 78
      end
      item
        Width = 68
      end>
    ExplicitTop = 391
  end
  object ProgressBar1: TProgressBar
    Left = 381
    Top = 392
    Width = 200
    Height = 15
    Anchors = [akRight, akBottom]
    TabOrder = 3
    Visible = False
    ExplicitTop = 394
  end
  object PanBotSize: TPanel
    Left = 0
    Top = 386
    Width = 604
    Height = 3
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 4
    ExplicitTop = 388
  end
  object ProgressBar2: TProgressBar
    Left = 275
    Top = 392
    Width = 100
    Height = 15
    Anchors = [akRight, akBottom]
    TabOrder = 5
    Visible = False
    ExplicitTop = 394
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
    Left = 424
    Top = 232
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
    object ActBrowseSrcC3: TAction
      Caption = 'Parcourir...'
      OnExecute = ActBrowseSrcC3Execute
    end
    object ActLoadSrcC3: TAction
      Caption = 'Charger'
      OnExecute = ActLoadSrcC3Execute
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
    Left = 536
    Top = 240
    object mnuFile: TMenuItem
      AutoHotkeys = maManual
      AutoLineReduction = maManual
      Caption = 'Fichier'
      object mnuModelA: TMenuItem
        AutoHotkeys = maManual
        AutoLineReduction = maManual
        Caption = 'Model A (Input 1 gguf)'
        object mmParcourir1: TMenuItem
          Action = ActBrowseSrcA1
        end
        object mmCharger1: TMenuItem
          Action = ActLoadSrcA1
        end
      end
      object mnuModelB: TMenuItem
        AutoHotkeys = maManual
        Caption = 'Model B (Input 2 gguf)'
        object mmParcourir2: TMenuItem
          Action = ActBrowseSrcB2
          AutoHotkeys = maManual
        end
        object mmCharger2: TMenuItem
          Action = ActLoadSrcB2
          AutoHotkeys = maManual
        end
      end
      object mnuModelC: TMenuItem
        Caption = 'Model C (Input 3 gguf)'
        object mmParcourir3: TMenuItem
          Action = ActBrowseSrcC3
        end
        object mmCharger3: TMenuItem
          Action = ActLoadSrcC3
        end
      end
      object mnuModelS: TMenuItem
        AutoHotkeys = maManual
        Caption = 'Model S (Input Safetensors)'
        object mmParcourirS: TMenuItem
          Action = ActBrowseSrcS
          AutoHotkeys = maManual
        end
        object mmChargerS: TMenuItem
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
        object mmParcourirO: TMenuItem
          Action = ActBrowseOut
        end
        object mmSaveO: TMenuItem
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
      object N1: TMenuItem
        Caption = '-'
      end
      object mnuShowToolbar: TMenuItem
        Caption = 'Show Toolbar'
        Checked = True
        OnClick = mnuShowToolbarClick
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
      object MmLangue1: TMenuItem
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
    Left = 292
    Top = 179
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
        Caption = 'Model 3'
        OnClick = mnuSourceOutClick
      end
      object mnuSourceOutMS: TMenuItem
        Tag = 3
        Caption = 'Model S'
        OnClick = mnuSourceOutClick
      end
    end
  end
  object pmInputTensor: TPopupMenu
    Left = 124
    Top = 187
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
