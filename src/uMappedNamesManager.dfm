object FrmMappedNamesManager: TFrmMappedNamesManager
  Left = 0
  Top = 0
  Caption = 'Gestionnaire de Mappages & Pr'#233'fixes'
  ClientHeight = 375
  ClientWidth = 620
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  Position = poOwnerFormCenter
  OnShow = FormShow
  TextHeight = 13
  object PageControl1: TPageControl
    Left = 0
    Top = 0
    Width = 620
    Height = 355
    ActivePage = tsMappedNames
    Align = alClient
    TabOrder = 0
    object tsMappedNames: TTabSheet
      Caption = 'Mappages de Noms'
      DesignSize = (
        612
        327)
      object cmbMappingFile: TComboBox
        Left = 10
        Top = 10
        Width = 300
        Height = 21
        Anchors = [akLeft, akTop, akRight]
        TabOrder = 0
        OnChange = cmbMappingFileChange
      end
      object btnNewRow: TButton
        Left = 318
        Top = 10
        Width = 40
        Height = 21
        Anchors = [akTop, akRight]
        Caption = '+'
        TabOrder = 1
        OnClick = btnNewRowClick
      end
      object btnSaveMapping: TButton
        Left = 510
        Top = 10
        Width = 90
        Height = 21
        Anchors = [akTop, akRight]
        Caption = 'Sauvegarder'
        TabOrder = 2
        OnClick = btnSaveMappingClick
      end
      object btnReloadMapping: TButton
        Left = 414
        Top = 10
        Width = 90
        Height = 21
        Anchors = [akTop, akRight]
        Caption = 'Reload Mapping'
        TabOrder = 3
        OnClick = btnReloadMappingClick
      end
      object StringGrid1: TStringGrid
        AlignWithMargins = True
        Left = 10
        Top = 40
        Width = 590
        Height = 281
        Margins.Left = 10
        Margins.Top = 40
        Margins.Right = 12
        Margins.Bottom = 6
        Align = alClient
        ColCount = 2
        DefaultColWidth = 295
        DefaultRowHeight = 23
        FixedCols = 0
        Options = [goFixedVertLine, goFixedHorzLine, goVertLine, goHorzLine, goRangeSelect, goDrawFocusSelected, goEditing, goAlwaysShowEditor]
        PopupMenu = mnuGrid
        TabOrder = 4
      end
      object btnDeleteRow: TButton
        Left = 364
        Top = 10
        Width = 40
        Height = 21
        Anchors = [akTop, akRight]
        Caption = '-'
        TabOrder = 5
        OnClick = btnDeleteRowClick
      end
    end
    object tsTensorPrefixes: TTabSheet
      Caption = 'Tensor Prefixes'
      ImageIndex = 1
      DesignSize = (
        612
        327)
      object lblPrefixHint: TLabel
        Left = 10
        Top = 10
        Width = 75
        Height = 13
        Caption = 'Tensor Prefixes'
      end
      object edtAddPrefix: TEdit
        Left = 10
        Top = 35
        Width = 290
        Height = 21
        Anchors = [akLeft, akTop, akRight]
        TabOrder = 0
      end
      object btnAddPrefix: TButton
        Left = 308
        Top = 33
        Width = 94
        Height = 25
        Anchors = [akTop, akRight]
        Caption = 'Ajouter'
        TabOrder = 1
        OnClick = btnAddPrefixClick
      end
      object lvPrefixes: TListView
        AlignWithMargins = True
        Left = 10
        Top = 65
        Width = 592
        Height = 256
        Margins.Left = 10
        Margins.Top = 65
        Margins.Right = 10
        Margins.Bottom = 6
        Align = alClient
        Columns = <
          item
            Caption = '#'
            Width = 40
          end
          item
            Caption = 'Prefix'
            Width = 430
          end>
        TabOrder = 2
        ViewStyle = vsReport
        OnSelectItem = lvPrefixesSelectItem
        ExplicitTop = 66
      end
      object btnDeletePrefix: TButton
        Left = 408
        Top = 33
        Width = 94
        Height = 25
        Anchors = [akTop, akRight]
        Caption = 'Supprimer'
        TabOrder = 3
        OnClick = btnDeletePrefixClick
      end
      object btnSavePrefixes: TButton
        Left = 508
        Top = 33
        Width = 94
        Height = 25
        Anchors = [akTop, akRight]
        Caption = 'Sauvegarder'
        TabOrder = 4
        OnClick = btnSavePrefixesClick
      end
    end
    object tsTensorIgnored: TTabSheet
      Caption = 'Tenseurs Ignor'#233's'
      ImageIndex = 2
      DesignSize = (
        612
        327)
      object lblIgnoredHint: TLabel
        Left = 10
        Top = 10
        Width = 214
        Height = 13
        Caption = 'Patterns de tenseurs exclure du chargement'
      end
      object edtAddIgnored: TEdit
        Left = 10
        Top = 35
        Width = 290
        Height = 21
        Anchors = [akLeft, akTop, akRight]
        TabOrder = 0
      end
      object btnAddIgnored: TButton
        Left = 308
        Top = 33
        Width = 94
        Height = 25
        Anchors = [akTop, akRight]
        Caption = 'Ajouter'
        TabOrder = 1
        OnClick = btnAddIgnoredClick
      end
      object lvIgnored: TListView
        AlignWithMargins = True
        Left = 10
        Top = 65
        Width = 592
        Height = 256
        Margins.Left = 10
        Margins.Top = 65
        Margins.Right = 10
        Margins.Bottom = 6
        Align = alClient
        Columns = <
          item
            Caption = '#'
            Width = 40
          end
          item
            Caption = 'Ignored Pattern'
            Width = 430
          end>
        TabOrder = 2
        ViewStyle = vsReport
        OnSelectItem = lvIgnoredSelectItem
      end
      object btnDeleteIgnored: TButton
        Left = 408
        Top = 33
        Width = 94
        Height = 25
        Anchors = [akTop, akRight]
        Caption = 'Supprimer'
        TabOrder = 3
        OnClick = btnDeleteIgnoredClick
      end
      object btnSaveIgnored: TButton
        Left = 508
        Top = 33
        Width = 94
        Height = 25
        Anchors = [akTop, akRight]
        Caption = 'Sauvegarder'
        TabOrder = 4
        OnClick = btnSaveIgnoredClick
      end
    end
  end
  object StatusBar1: TStatusBar
    Left = 0
    Top = 355
    Width = 620
    Height = 20
    Panels = <
      item
        Width = 600
      end
      item
        Width = 20
      end>
    SimplePanel = True
  end
  object mnuGrid: TPopupMenu
    Left = 480
    Top = 150
    object miAddRow: TMenuItem
      Caption = 'Ajouter Ligne'
    end
    object miDeleteRow: TMenuItem
      Caption = 'Supprimer Ligne'
    end
    object miClearAll: TMenuItem
      Caption = 'Tout Effacer'
      OnClick = miClearAllClick
    end
  end
end
