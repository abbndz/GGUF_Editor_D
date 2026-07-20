object frmViewTensors: TfrmViewTensors
  Left = 0
  Top = 0
  Caption = 'Diagnostic et Visualisation des Tensors'
  ClientHeight = 640
  ClientWidth = 915
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poScreenCenter
  OnClose = FormClose
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  OnKeyDown = FormKeyDown
  OnShow = FormShow
  DesignSize = (
    915
    640)
  TextHeight = 15
  object Splitter4: TSplitter
    Left = 245
    Top = 10
    Width = 6
    Height = 611
    ExplicitTop = 5
    ExplicitHeight = 569
  end
  object PanelTop: TPanel
    Left = 0
    Top = 0
    Width = 915
    Height = 10
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 0
  end
  object StatusBar1: TStatusBar
    Left = 0
    Top = 621
    Width = 915
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
      end
      item
        Width = 120
      end>
    ExplicitTop = 620
  end
  object PanelLeft: TPanel
    Left = 0
    Top = 10
    Width = 245
    Height = 611
    Align = alLeft
    BevelOuter = bvNone
    Caption = 'PanelBottom'
    ShowCaption = False
    TabOrder = 2
    object Splitter3: TSplitter
      Left = 0
      Top = 473
      Width = 245
      Height = 5
      Cursor = crVSplit
      Align = alBottom
      ExplicitLeft = 4
      ExplicitTop = 392
    end
    object PanelLeftBot2: TPanel
      Left = 0
      Top = 479
      Width = 245
      Height = 132
      Align = alBottom
      BevelOuter = bvNone
      Caption = 'PanelBottom'
      ShowCaption = False
      TabOrder = 0
      object lvSeries: TListView
        AlignWithMargins = True
        Left = 8
        Top = 3
        Width = 234
        Height = 126
        Margins.Left = 8
        Align = alClient
        Columns = <>
        ColumnClick = False
        TabOrder = 0
        ViewStyle = vsList
        OnAdvancedCustomDrawItem = lvSeriesAdvancedCustomDrawItem
        ExplicitHeight = 109
      end
    end
    object PanelLeftTop: TPanel
      Left = 0
      Top = 0
      Width = 245
      Height = 473
      Align = alClient
      BevelOuter = bvNone
      TabOrder = 1
      ExplicitHeight = 489
      object ChListBoxTensors: TCheckListBox
        AlignWithMargins = True
        Left = 8
        Top = 95
        Width = 234
        Height = 375
        Margins.Left = 8
        Align = alClient
        ItemHeight = 17
        TabOrder = 0
        OnClickCheck = ChListBoxTensorsClickCheck
        ExplicitHeight = 391
      end
      object pnlFilters: TPanel
        Left = 0
        Top = 0
        Width = 245
        Height = 92
        Align = alTop
        BevelOuter = bvNone
        TabOrder = 1
        DesignSize = (
          245
          92)
        object Label1: TLabel
          AlignWithMargins = True
          Left = 8
          Top = 11
          Width = 117
          Height = 15
          Margins.Top = 8
          Caption = 'S'#233'lection des Tensors :'
        end
        object cbFilterV: TComboBox
          Left = 8
          Top = 37
          Width = 159
          Height = 23
          Anchors = [akLeft, akTop, akRight]
          TabOrder = 0
          Text = 'Tous'
          OnChange = cbFilterVChange
        end
        object chkM1: TCheckBox
          Left = 7
          Top = 68
          Width = 32
          Height = 17
          Caption = 'A'
          Checked = True
          State = cbChecked
          TabOrder = 1
          OnClick = chkMOutClick
        end
        object chkM2: TCheckBox
          Left = 45
          Top = 68
          Width = 32
          Height = 17
          Caption = 'B'
          Checked = True
          State = cbChecked
          TabOrder = 2
          OnClick = chkMOutClick
        end
        object chkMOut: TCheckBox
          Left = 121
          Top = 68
          Width = 46
          Height = 17
          Caption = 'Out'
          Checked = True
          State = cbChecked
          TabOrder = 3
          OnClick = chkMOutClick
        end
        object chkT1vT2: TCheckBox
          Left = 173
          Top = 68
          Width = 54
          Height = 17
          Caption = 'T1-T2'
          TabOrder = 4
          OnClick = chkT1vT2Click
        end
        object brnClearAllSelected: TButton
          Left = 173
          Top = 36
          Width = 66
          Height = 25
          Anchors = [akTop, akRight]
          Caption = 'Clear'
          TabOrder = 5
          OnClick = brnClearAllSelectedClick
        end
        object chkMS: TCheckBox
          Left = 83
          Top = 68
          Width = 32
          Height = 17
          Caption = 'S'
          Checked = True
          State = cbChecked
          TabOrder = 6
          OnClick = chkMOutClick
        end
        object cbNbrSelect: TComboBox
          Left = 173
          Top = 8
          Width = 66
          Height = 23
          ItemIndex = 0
          TabOrder = 7
          Text = 'One Only'
          OnChange = cbNbrSelectChange
          Items.Strings = (
            'One Only'
            '2'
            '3'
            '4'
            '6'
            '8'
            'ALL')
        end
      end
    end
    object PanelLeftBot1: TPanel
      Left = 0
      Top = 478
      Width = 245
      Height = 1
      Align = alBottom
      BevelOuter = bvNone
      Caption = 'PanelBottom'
      ShowCaption = False
      TabOrder = 2
      ExplicitTop = 573
    end
  end
  object pnlBase00: TPanel
    Left = 251
    Top = 10
    Width = 664
    Height = 611
    Align = alClient
    BevelOuter = bvNone
    Caption = 'PanelBottom'
    ShowCaption = False
    TabOrder = 3
    object pnlBaseBot0: TPanel
      Left = 0
      Top = 573
      Width = 664
      Height = 38
      Align = alBottom
      BevelOuter = bvNone
      Caption = 'PanelBottom'
      ShowCaption = False
      TabOrder = 0
      object pnlBaseBotLeft: TPanel
        Left = 0
        Top = 0
        Width = 187
        Height = 38
        Align = alLeft
        BevelOuter = bvNone
        Caption = 'PanelBottom'
        ShowCaption = False
        TabOrder = 0
        ExplicitHeight = 42
        object btnResetZoom: TButton
          Left = 152
          Top = 6
          Width = 30
          Height = 25
          Caption = 'R'
          TabOrder = 0
          OnClick = btnResetZoomClick
        end
        object btnZoomOut: TButton
          Left = 116
          Top = 6
          Width = 30
          Height = 25
          Caption = '-'
          TabOrder = 1
          OnClick = btnZoomOutClick
        end
        object btnZoomIn: TButton
          Left = 80
          Top = 6
          Width = 30
          Height = 25
          Caption = '+'
          TabOrder = 2
          OnClick = btnZoomInClick
        end
        object btnNavRight: TButton
          Left = 44
          Top = 6
          Width = 30
          Height = 25
          Caption = '>'
          TabOrder = 3
          OnClick = btnNavRightClick
        end
        object btnNavLeft: TButton
          Left = 8
          Top = 6
          Width = 30
          Height = 25
          Caption = '<'
          TabOrder = 4
          OnClick = btnNavLeftClick
        end
      end
      object pnlBaseBotSlider: TPanel
        AlignWithMargins = True
        Left = 193
        Top = 6
        Width = 459
        Height = 24
        Margins.Left = 6
        Margins.Top = 6
        Margins.Right = 12
        Margins.Bottom = 8
        Align = alClient
        BevelOuter = bvLowered
        ShowCaption = False
        TabOrder = 1
        ExplicitHeight = 28
        object pnlRangeSlider1: TPanel
          AlignWithMargins = True
          Left = 4
          Top = 4
          Width = 451
          Height = 16
          Align = alClient
          BevelOuter = bvSpace
          ShowCaption = False
          TabOrder = 0
          ExplicitHeight = 20
        end
      end
    end
    object PageControl1: TPageControl
      Left = 0
      Top = 0
      Width = 664
      Height = 573
      ActivePage = TabGraph
      Align = alClient
      TabOrder = 1
      ExplicitHeight = 569
      object TabGraph: TTabSheet
        Caption = 'S'#233'ries Temporelles (Aper'#231'u)'
        object Chart1: TChart
          Left = 0
          Top = 38
          Width = 656
          Height = 505
          AllowPanning = pmNone
          Title.Text.Strings = (
            'Valeurs FP32 des Tensors')
          Title.Visible = False
          OnUndoZoom = Chart1UndoZoom
          BottomAxis.Title.Caption = 'Index de l '#233'l'#233'ment'
          BottomAxis.Title.Visible = False
          LeftAxis.Title.Caption = 'Valeur'
          LeftAxis.Title.Visible = False
          Panning.InsideBounds = True
          Panning.MouseWheel = pmwNone
          TopAxis.Title.Visible = False
          View3D = False
          Zoom.Pen.Color = clBlack
          Zoom.Pen.Mode = pmNotXor
          Align = alClient
          TabOrder = 0
          OnMouseDown = Chart1MouseDown
          OnMouseMove = Chart1MouseMove
          OnMouseUp = Chart1MouseUp
          OnMouseWheelDown = Chart1MouseWheelDown
          OnMouseWheelUp = Chart1MouseWheelUp
          ExplicitHeight = 501
          DefaultCanvas = 'TGDIPlusCanvas'
          ColorPaletteIndex = 13
        end
        object PanChart1Top: TPanel
          Left = 0
          Top = 0
          Width = 656
          Height = 38
          Align = alTop
          BevelOuter = bvNone
          TabOrder = 1
          object edtYMax: TEdit
            Left = 343
            Top = 6
            Width = 58
            Height = 23
            TabOrder = 0
            Text = '0,1'
            OnKeyPress = edtYMinKeyPress
          end
          object edtYMin: TEdit
            Left = 279
            Top = 6
            Width = 58
            Height = 23
            TabOrder = 1
            Text = '-0,1'
            OnKeyPress = edtYMinKeyPress
          end
          object chkYAxisAuto: TCheckBox
            Left = 212
            Top = 9
            Width = 62
            Height = 17
            Caption = 'Y-Auto'
            Checked = True
            State = cbChecked
            TabOrder = 2
            OnClick = chkYAxisAutoClick
          end
          object btnApply1: TButton
            Left = 136
            Top = 5
            Width = 70
            Height = 25
            Caption = 'Appliquer'
            TabOrder = 3
            OnClick = btnApply1Click
          end
          object edtXMax: TEdit
            Left = 536
            Top = 6
            Width = 58
            Height = 23
            TabOrder = 4
            Text = '4096'
            OnKeyPress = edtXMinKeyPress
          end
          object edtXMin: TEdit
            Left = 472
            Top = 6
            Width = 58
            Height = 23
            TabOrder = 5
            Text = '0'
            OnKeyPress = edtXMinKeyPress
          end
          object chkXAxisAuto: TCheckBox
            Left = 407
            Top = 9
            Width = 62
            Height = 17
            Caption = 'X-Auto'
            Checked = True
            State = cbChecked
            TabOrder = 6
            OnClick = chkXAxisAutoClick
          end
          object chkUseImpl: TCheckBox
            Left = 74
            Top = 9
            Width = 52
            Height = 17
            Hint = 
              'Utiliser Impl :  haute qualit'#233' avec optimisation RMSE  (ou D'#233'coc' +
              'h'#233' Ref : R'#233'f'#233'rence : Algorithme d'#233'terministe (sans optimisation ' +
              'RMSE))'
            Caption = 'Impl'
            TabOrder = 7
            OnClick = chkUseImplClick
          end
          object chkUseDLL: TCheckBox
            Left = 16
            Top = 9
            Width = 52
            Height = 17
            Hint = 'Use external llama.cpp DLL'
            Caption = 'DLL'
            TabOrder = 8
            OnClick = chkUseDLLClick
          end
        end
      end
      object TabHist: TTabSheet
        Caption = 'Distribution (Histogramme)'
        ImageIndex = 1
        object Chart2: TChart
          Left = 0
          Top = 38
          Width = 656
          Height = 505
          Title.Text.Strings = (
            'Histogramme des valeurs')
          Title.Visible = False
          BottomAxis.Title.Caption = 'Intervalles de Valeurs'
          BottomAxis.Title.Visible = False
          LeftAxis.Title.Caption = 'Fr'#233'quence'
          TopAxis.Visible = False
          View3D = False
          Align = alClient
          TabOrder = 0
          ExplicitHeight = 501
          DefaultCanvas = 'TGDIPlusCanvas'
          ColorPaletteIndex = 13
        end
        object PanChart2Top: TPanel
          Left = 0
          Top = 0
          Width = 656
          Height = 38
          Align = alTop
          BevelOuter = bvNone
          TabOrder = 1
          object btnHistogram: TButton
            Left = 16
            Top = 7
            Width = 90
            Height = 25
            Caption = 'Histogramme'
            TabOrder = 0
            OnClick = btnHistogramClick
          end
          object btnResetZoom2: TButton
            Left = 369
            Top = 7
            Width = 96
            Height = 25
            Caption = 'Reset Zoom'
            TabOrder = 1
            OnClick = btnResetZoom2Click
          end
        end
      end
    end
  end
  object ProgressBar1: TProgressBar
    Left = 746
    Top = 623
    Width = 150
    Height = 17
    Anchors = [akRight, akBottom]
    TabOrder = 4
    Visible = False
  end
  object ProgressBar2: TProgressBar
    Left = 662
    Top = 623
    Width = 78
    Height = 17
    Anchors = [akRight, akBottom]
    TabOrder = 5
    Visible = False
  end
  object SaveDialog1: TSaveDialog
    Left = 920
    Top = 40
  end
end
