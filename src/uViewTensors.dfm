object frmViewTensors: TfrmViewTensors
  Left = 0
  Top = 0
  Caption = 'Diagnostic et Visualisation des Tensors'
  ClientHeight = 574
  ClientWidth = 999
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poDesigned
  OnClose = FormClose
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  OnKeyDown = FormKeyDown
  OnResize = FormResize
  OnShow = FormShow
  DesignSize = (
    999
    574)
  TextHeight = 15
  object Splitter4: TSplitter
    Left = 265
    Top = 10
    Width = 6
    Height = 545
    ExplicitLeft = 245
    ExplicitTop = 5
    ExplicitHeight = 569
  end
  object PanelTop: TPanel
    Left = 0
    Top = 0
    Width = 999
    Height = 10
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 0
  end
  object stBar1: TStatusBar
    Left = 0
    Top = 555
    Width = 999
    Height = 19
    Panels = <
      item
        Width = 420
      end
      item
        Width = 110
      end
      item
        Width = 110
      end
      item
        Width = 110
      end
      item
        Width = 110
      end
      item
        Width = 110
      end>
  end
  object PanelLeft: TPanel
    Left = 0
    Top = 10
    Width = 265
    Height = 545
    Align = alLeft
    BevelOuter = bvNone
    Caption = 'PanelBottom'
    ShowCaption = False
    TabOrder = 2
    object Splitter3: TSplitter
      Left = 0
      Top = 407
      Width = 265
      Height = 5
      Cursor = crVSplit
      Align = alBottom
      ExplicitLeft = 4
      ExplicitTop = 392
      ExplicitWidth = 245
    end
    object PanelLeftBot2: TPanel
      Left = 0
      Top = 413
      Width = 265
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
        Width = 254
        Height = 126
        Margins.Left = 8
        Align = alClient
        Columns = <>
        ColumnClick = False
        TabOrder = 0
        ViewStyle = vsList
        OnAdvancedCustomDrawItem = lvSeriesAdvancedCustomDrawItem
      end
    end
    object PanelLeftTop: TPanel
      Left = 0
      Top = 0
      Width = 265
      Height = 407
      Align = alClient
      BevelOuter = bvNone
      TabOrder = 1
      object ChListBoxTensors: TCheckListBox
        AlignWithMargins = True
        Left = 8
        Top = 95
        Width = 254
        Height = 309
        Margins.Left = 8
        Align = alClient
        ItemHeight = 17
        TabOrder = 0
        OnClickCheck = ChListBoxTensorsClickCheck
      end
      object pnlFilters: TPanel
        Left = 0
        Top = 0
        Width = 265
        Height = 92
        Align = alTop
        BevelOuter = bvNone
        TabOrder = 1
        DesignSize = (
          265
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
          Width = 179
          Height = 23
          Anchors = [akLeft, akTop, akRight]
          TabOrder = 0
          Text = 'Tous'
          OnChange = cbFilterVChange
        end
        object chkM1: TCheckBox
          Left = 7
          Top = 68
          Width = 30
          Height = 17
          Caption = 'A'
          Checked = True
          State = cbChecked
          TabOrder = 1
          OnClick = chkMOutClick
        end
        object chkM2: TCheckBox
          Left = 40
          Top = 68
          Width = 30
          Height = 17
          Caption = 'B'
          Checked = True
          State = cbChecked
          TabOrder = 2
          OnClick = chkMOutClick
        end
        object chkMOut: TCheckBox
          Left = 139
          Top = 68
          Width = 30
          Height = 17
          Caption = 'O'
          Checked = True
          State = cbChecked
          TabOrder = 3
          OnClick = chkMOutClick
        end
        object chkT1vT2: TCheckBox
          Left = 172
          Top = 68
          Width = 42
          Height = 17
          Caption = 'T1-2'
          TabOrder = 4
          OnClick = chkT1vT2Click
        end
        object btnClearAllSelected: TButton
          Left = 193
          Top = 36
          Width = 66
          Height = 25
          Anchors = [akTop, akRight]
          Caption = 'Clear'
          TabOrder = 5
          OnClick = btnClearAllSelectedClick
        end
        object chkMS: TCheckBox
          Left = 106
          Top = 68
          Width = 30
          Height = 17
          Caption = 'S'
          Checked = True
          State = cbChecked
          TabOrder = 6
          OnClick = chkMOutClick
        end
        object cbNbrSelect: TComboBox
          Left = 160
          Top = 6
          Width = 99
          Height = 23
          TabOrder = 7
          Text = '2-ByName'
          OnChange = cbNbrSelectChange
          Items.Strings = (
            'One Only'
            '2:ByName'
            '2'
            '3'
            '4'
            '6'
            '8'
            'ALL')
        end
        object chkT1dT2: TCheckBox
          Left = 217
          Top = 68
          Width = 42
          Height = 17
          Caption = 'T1/2'
          TabOrder = 8
          OnClick = chkT1dT2Click
        end
        object chkM3: TCheckBox
          Left = 73
          Top = 68
          Width = 30
          Height = 17
          Caption = 'C'
          Checked = True
          State = cbChecked
          TabOrder = 9
          OnClick = chkMOutClick
        end
      end
    end
    object PanelLeftBot1: TPanel
      Left = 0
      Top = 412
      Width = 265
      Height = 1
      Align = alBottom
      BevelOuter = bvNone
      Caption = 'PanelBottom'
      ShowCaption = False
      TabOrder = 2
    end
  end
  object pnlBase00: TPanel
    Left = 271
    Top = 10
    Width = 728
    Height = 545
    Align = alClient
    BevelOuter = bvNone
    Caption = 'PanelBottom'
    ShowCaption = False
    TabOrder = 3
    object pnlBaseBot0: TPanel
      Left = 0
      Top = 507
      Width = 728
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
        Width = 523
        Height = 24
        Margins.Left = 6
        Margins.Top = 6
        Margins.Right = 12
        Margins.Bottom = 8
        Align = alClient
        BevelOuter = bvLowered
        ShowCaption = False
        TabOrder = 1
        object pnlRangeSlider1: TPanel
          AlignWithMargins = True
          Left = 4
          Top = 4
          Width = 515
          Height = 16
          Align = alClient
          BevelOuter = bvSpace
          ShowCaption = False
          TabOrder = 0
        end
      end
    end
    object PageControl1: TPageControl
      Left = 0
      Top = 0
      Width = 728
      Height = 507
      ActivePage = TabGraph
      Align = alClient
      TabOrder = 1
      object TabGraph: TTabSheet
        Caption = 'S'#233'ries Temporelles (Aper'#231'u)'
        object Chart1: TChart
          Left = 0
          Top = 72
          Width = 720
          Height = 405
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
          DefaultCanvas = 'TGDIPlusCanvas'
          ColorPaletteIndex = 13
        end
        object PanChart1Top: TPanel
          Left = 0
          Top = 0
          Width = 720
          Height = 72
          Align = alTop
          BevelOuter = bvNone
          TabOrder = 1
          object lblUseImpl: TLabel
            Left = 11
            Top = 9
            Width = 58
            Height = 15
            Caption = 'DLL/Pascal'
          end
          object edtYMax: TEdit
            Left = 423
            Top = 6
            Width = 52
            Height = 23
            TabOrder = 0
            Text = '0,1'
            OnKeyPress = edtYMinKeyPress
          end
          object edtYMin: TEdit
            Left = 365
            Top = 6
            Width = 52
            Height = 23
            TabOrder = 1
            Text = '-0,1'
            OnKeyPress = edtYMinKeyPress
          end
          object chkYAxisAuto: TCheckBox
            Left = 299
            Top = 9
            Width = 60
            Height = 17
            Caption = 'Y-Auto'
            Checked = True
            State = cbChecked
            TabOrder = 2
            OnClick = chkYAxisAutoClick
          end
          object btnApply: TButton
            Left = 215
            Top = 5
            Width = 70
            Height = 25
            Caption = 'Appliquer'
            TabOrder = 3
            OnClick = btnApplyClick
          end
          object edtXMax: TEdit
            Left = 629
            Top = 6
            Width = 76
            Height = 23
            TabOrder = 4
            Text = '4096'
            OnKeyPress = edtXMinKeyPress
          end
          object edtXMin: TEdit
            Left = 547
            Top = 6
            Width = 76
            Height = 23
            TabOrder = 5
            Text = '0'
            OnKeyPress = edtXMinKeyPress
          end
          object chkXAxisAuto: TCheckBox
            Left = 481
            Top = 9
            Width = 60
            Height = 17
            Caption = 'X-Auto'
            Checked = True
            State = cbChecked
            TabOrder = 6
            OnClick = chkXAxisAutoClick
          end
          object chkUseMAD: TCheckBox
            Left = 333
            Top = 42
            Width = 64
            Height = 17
            Hint = 'use_mad  ( MakeQkx2Quant0s )'
            Caption = 'UseMAD'
            ParentShowHint = False
            ShowHint = True
            TabOrder = 7
          end
          object edtNstep: TEdit
            Left = 299
            Top = 39
            Width = 28
            Height = 23
            Hint = 'nstep (Qx2GridSteps MakeQkx2Quant0s )'
            ParentShowHint = False
            ShowHint = True
            TabOrder = 8
            Text = '36'
            OnKeyPress = edtNstepKeyPress
          end
          object edtRdelta: TEdit
            Left = 257
            Top = 39
            Width = 36
            Height = 23
            Hint = 'rdelta  (Qx2GridStepSize MakeQkx2Quants )'
            ParentShowHint = False
            ShowHint = True
            TabOrder = 9
            Text = '0,05'
            OnKeyPress = edtNstepKeyPress
          end
          object edtRmin: TEdit
            Left = 215
            Top = 39
            Width = 36
            Height = 23
            Hint = 'Rmin (MakeQkx2Quants)'
            ParentShowHint = False
            ShowHint = True
            TabOrder = 10
            Text = '0,9'
            OnKeyPress = edtNstepKeyPress
          end
          object edtQpSteps: TEdit
            Left = 445
            Top = 39
            Width = 28
            Height = 23
            Hint = 'nstep (QpGridSteps  MakeQxQuants )'
            ParentShowHint = False
            ShowHint = True
            TabOrder = 11
            Text = '2'
            OnKeyPress = edtNstepKeyPress
          end
          object edtQpStep: TEdit
            Left = 403
            Top = 39
            Width = 36
            Height = 23
            Hint = 'QpGridStepSize'
            ParentShowHint = False
            ShowHint = True
            TabOrder = 12
            Text = '0,33'
            OnKeyPress = edtNstepKeyPress
          end
          object edtQCIter: TEdit
            Left = 479
            Top = 39
            Width = 28
            Height = 23
            Hint = 'QpCoordDescentIter'
            ParentShowHint = False
            ShowHint = True
            TabOrder = 13
            Text = '2'
            OnKeyPress = edtNstepKeyPress
          end
          object btnToggleSection: TButton
            Left = 181
            Top = 5
            Width = 28
            Height = 25
            Caption = '[+]'
            TabOrder = 14
            OnClick = btnToggleSectionClick
          end
          object cbRmseType: TComboBox
            Left = 81
            Top = 39
            Width = 128
            Height = 23
            Hint = 'Rmse Type'
            ItemIndex = 3
            ParentShowHint = False
            ShowHint = True
            TabOrder = 15
            Text = '3: Magnitude (|x|)'
            OnClick = cbRmseTypeClick
            Items.Strings = (
              '0: Simple (no optimization)'
              '1: Uniform (1.0)'
              '2: Sqrt Magnitude ('#8730'|x|)'
              '3: Magnitude (|x|)'
              '4: Variance (x'#178')')
          end
          object cbDTypeOut: TComboBox
            Left = 11
            Top = 39
            Width = 64
            Height = 23
            Hint = 'Selcted Qunat Type'
            ItemIndex = 8
            ParentShowHint = False
            ShowHint = True
            TabOrder = 16
            Text = 'Q4_K'
            OnClick = cbDTypeOutClick
            Items.Strings = (
              'Q4_0'
              'Q4_1'
              'Q5_0'
              'Q5_1'
              'Q8_0'
              'Q8_1'
              'Q2_K'
              'Q3_K'
              'Q4_K'
              'Q5_K'
              'Q6_K')
          end
          object cbUseImpl: TComboBox
            Left = 81
            Top = 6
            Width = 94
            Height = 23
            Hint = 
              'Utiliser Impl :  haute qualit'#233' avec optimisation RMSE  (ou D'#233'coc' +
              'h'#233' Ref : R'#233'f'#233'rence : Algorithme d'#233'terministe (sans optimisation ' +
              'RMSE))'
            ItemIndex = 2
            ParentShowHint = False
            ShowHint = True
            TabOrder = 17
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
          object btnRestoreQuantPreset: TButton
            Left = 581
            Top = 38
            Width = 70
            Height = 25
            Hint = 'Restore Quant Preset Default'
            Caption = 'Rest Preset'
            TabOrder = 18
            OnClick = btnRestoreQuantPresetClick
          end
          object edtRadiusLm: TEdit
            Left = 547
            Top = 39
            Width = 28
            Height = 23
            Hint = 'Radius Lm'
            ParentShowHint = False
            ShowHint = True
            TabOrder = 19
            Text = '3'
            OnKeyPress = edtNstepKeyPress
          end
          object edtRadiusLs: TEdit
            Left = 513
            Top = 39
            Width = 28
            Height = 23
            Hint = 'Radius Ls'
            ParentShowHint = False
            ShowHint = True
            TabOrder = 20
            Text = '3'
            OnKeyPress = edtNstepKeyPress
          end
        end
      end
      object TabHist: TTabSheet
        Caption = 'Distribution (Histogramme)'
        ImageIndex = 1
        object Chart2: TChart
          Left = 0
          Top = 36
          Width = 720
          Height = 441
          Title.Text.Strings = (
            'Histogramme des valeurs')
          Title.Visible = False
          BottomAxis.Title.Caption = 'Intervalles de Valeurs'
          BottomAxis.Title.Visible = False
          LeftAxis.Title.Caption = 'Fr'#233'quence'
          LeftAxis.Title.Visible = False
          TopAxis.Visible = False
          View3D = False
          Align = alClient
          TabOrder = 0
          DefaultCanvas = 'TGDIPlusCanvas'
          ColorPaletteIndex = 13
        end
        object PanChart2Top: TPanel
          Left = 0
          Top = 0
          Width = 720
          Height = 36
          Align = alTop
          BevelOuter = bvNone
          TabOrder = 1
          object btnHistogramFast: TButton
            Left = 11
            Top = 8
            Width = 56
            Height = 25
            Caption = 'Fast'
            TabOrder = 0
            OnClick = btnHistogramFastClick
          end
          object btnHistogramFull: TButton
            Left = 73
            Top = 8
            Width = 42
            Height = 25
            Caption = 'Full'
            TabOrder = 1
            OnClick = btnHistogramFullClick
          end
          object btnHistogramCancel: TButton
            Left = 121
            Top = 8
            Width = 24
            Height = 25
            Caption = 'X'
            Enabled = False
            TabOrder = 2
            OnClick = btnHistogramCancelClick
          end
          object chkVAuto: TCheckBox
            Left = 151
            Top = 12
            Width = 64
            Height = 17
            Caption = 'V-Auto'
            Checked = True
            State = cbChecked
            TabOrder = 3
            OnClick = chkVAutoClick
          end
          object chkCntAuto: TCheckBox
            Left = 497
            Top = 13
            Width = 64
            Height = 17
            Caption = 'N-Auto'
            Checked = True
            State = cbChecked
            TabOrder = 4
            OnClick = chkCntAutoClick
          end
          object edtCntMin: TEdit
            Left = 567
            Top = 9
            Width = 54
            Height = 23
            TabOrder = 5
            Text = '0'
            OnKeyPress = edtCntMinKeyPress
          end
          object edtCntMax: TEdit
            Left = 627
            Top = 9
            Width = 54
            Height = 23
            TabOrder = 6
            Text = '1000'
            OnKeyPress = edtCntMinKeyPress
          end
          object edtValMax: TEdit
            Left = 426
            Top = 9
            Width = 64
            Height = 23
            Color = clBtnFace
            ReadOnly = True
            TabOrder = 7
            Text = '--'
          end
          object edtValMin: TEdit
            Left = 356
            Top = 9
            Width = 64
            Height = 23
            Color = clBtnFace
            ReadOnly = True
            TabOrder = 8
            Text = '--'
            OnKeyPress = edtValMinKeyPress
          end
          object edtWinMax: TEdit
            Left = 286
            Top = 9
            Width = 64
            Height = 23
            TabOrder = 9
            Text = '0.1'
          end
          object edtWinMin: TEdit
            Left = 216
            Top = 9
            Width = 64
            Height = 23
            TabOrder = 10
            Text = '-0.1'
          end
        end
      end
    end
  end
  object ProgressBar1: TProgressBar
    Left = 830
    Top = 557
    Width = 150
    Height = 17
    Anchors = [akRight, akBottom]
    TabOrder = 4
    Visible = False
    OnMouseDown = ProgressBar1MouseDown
  end
  object ProgressBar2: TProgressBar
    Left = 746
    Top = 557
    Width = 78
    Height = 17
    Anchors = [akRight, akBottom]
    TabOrder = 5
    Visible = False
  end
  object SaveDialog1: TSaveDialog
    Left = 856
    Top = 192
  end
  object FSliderTimer: TTimer
    Enabled = False
    Interval = 150
    OnTimer = FSliderTimerTimer
    Left = 747
    Top = 196
  end
end
