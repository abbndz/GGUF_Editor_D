unit uEditArrayDlg;

interface

uses
  Windows, Messages, SysUtils, Classes, Controls, Forms, Dialogs, StdCtrls, Grids, ExtCtrls, RichEdit, System.IOUtils,
  System.UITypes, Vcl.ComCtrls, uGGUFTypes, uGGMLTypes, uMath, uLangManager, Vcl.Menus;

type
  TStringGridAccess = class(TStringGrid);

  TfrmEditArrayDlg = class(TForm)
    StatusBar1: TStatusBar;
    OpenDialog1: TOpenDialog;
    SaveDialog1: TSaveDialog;
    pnlStrArrBot: TPanel;
    btnStrSaveAs: TButton;
    btnArrCancel: TButton;
    btnArrOk: TButton;
    pnlArrTop: TPanel;
    grpNav: TGroupBox;
    lblPage: TLabel;
    lblTotalPages: TLabel;
    btnPrevAll: TButton;
    btnPrev: TButton;
    edtPageNum: TEdit;
    btnNext: TButton;
    btnNextAll: TButton;
    sgArray: TStringGrid;
    cbArrType: TComboBox;
    lblArrType: TLabel;
    btnArrLoad: TButton;
    procedure FormCreate(Sender: TObject);
    procedure btnStrSaveAsClick(Sender: TObject);
    procedure btnArrLoadClick(Sender: TObject);
    procedure btnArrOkClick(Sender: TObject);
    procedure btnArrCancelClick(Sender: TObject);
    procedure btnNextClick(Sender: TObject);
    procedure btnNextAllClick(Sender: TObject);
    procedure btnPrevClick(Sender: TObject);
    procedure btnPrevAllClick(Sender: TObject);
    procedure edtPageNumKeyUp(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure sgArraySelectCell(Sender: TObject; ACol, ARow: Integer; var CanSelect: Boolean);
    procedure sgArraySetEditText(Sender: TObject; ACol, ARow: Integer; const Value: string);
    procedure FormShow(Sender: TObject);
    procedure cbArrTypeChange(Sender: TObject);
    procedure cbArrTypeChange0(Sender: TObject);
  private
    FValue: TGGUFValue;
    FCurKey: String;
    FPageIndex: Integer;
    procedure LoadPage;
    function GetTotalPages: Integer;
    function GetActualIndex(ARow: Integer): Integer;
  public
    function Execute(var AValue: TGGUFValue; CurKey: String): Boolean;
  end;

var
  frmEditArrayDlg: TfrmEditArrayDlg;

const
  PAGE_SIZE = 2000;

implementation

uses uAppConfig, uLog, uStrUtils;

{$R *.dfm}

function TfrmEditArrayDlg.Execute(var AValue: TGGUFValue; CurKey: String): Boolean;
begin
  Result := False;
  if not Assigned(AValue) then
    Exit;
  FValue := AValue.Clone;
  FCurKey := CurKey;
  FPageIndex := 0;

  // Afficher le type actuel et peupler la combo
  cbArrType.ItemIndex := cbArrType.Items.IndexOf(GGUFTypeToStr(FValue.VArr.ElemType));
  if cbArrType.ItemIndex < 0 then
    cbArrType.ItemIndex := 0;
  lblArrType.Visible := True;
  cbArrType.Visible := True;

  LoadPage;
  if ShowModal = mrOk then
  begin
    AValue.Free;
    AValue := FValue;
    Result := True;
  end
  else
    FValue.Free;
end;

procedure TfrmEditArrayDlg.FormCreate(Sender: TObject);
var
  VT: Integer;
begin
  FPageIndex := 0;
  FValue := nil;
  sgArray.RowCount := 1;
  sgArray.ColCount := 2;
  sgArray.FixedCols := 1;
  sgArray.Options := sgArray.Options + [goEditing];
  sgArray.DefaultColWidth := 180;
  sgArray.RowHeights[0] := 24;

  // Peupler cbArrType avec tous les types GGUF
  cbArrType.Items.Clear;
  for VT := Integer(Low(TGGUFValueType)) to Integer(High(TGGUFValueType)) do
    if (VT <> Integer(gvt_None)) and (VT <> Integer(gvt_ARRAY)) then
      cbArrType.Items.Add(GGUFTypeToStr(TGGUFValueType(VT)));
end;

procedure TfrmEditArrayDlg.FormShow(Sender: TObject);
begin
  LoadPage;
end;

procedure TfrmEditArrayDlg.cbArrTypeChange0(Sender: TObject);
var
  NewType, OldType: TGGUFValueType;
  i, OldCount, ConvertedCount, ByteSize: Integer;
  StrVal: string;
  OldVal, NewVal: TGGUFValue;
  ElemSize: Integer;
begin
  if not Assigned(FValue) or not Assigned(FValue.VArr) then
    Exit;

  NewType := StrToGGUFType(cbArrType.Text);
  if (NewType = gvt_None) or (NewType = FValue.VArr.ElemType) then
    Exit; // Aucun changement

  OldVal := FValue.Clone;
  OldType := FValue.VArr.ElemType;
  OldCount := FValue.VArr.Count;

  // 1. Calculer la taille en octets du nouveau type
  case NewType of
    gvt_UINT8, gvt_INT8, gvt_BOOL:
      ElemSize := 1;
    gvt_UINT16, gvt_INT16:
      ElemSize := 2;
    gvt_UINT32, gvt_INT32, gvt_FLOAT32:
      ElemSize := 4;
    gvt_UINT64, gvt_INT64, gvt_FLOAT64:
      ElemSize := 8;
  else
    ElemSize := 1;
  end;

  // 2. Allouer le nouveau stockage
  if NewType = gvt_STRING then
  begin
    FValue.VArr.StrItems := TStringList.Create;
    FValue.VArr.StrItems.Capacity := OldCount;
    FValue.VArr.IsStringArray := True;
  end
  else
  begin
    ByteSize := OldCount * ElemSize;
    SetLength(FValue.VArr.DatItems, ByteSize); // Delphi initialise automatiquement à 0
    FValue.VArr.IsStringArray := False;
  end;

  // 3. Conversion élément par élément (pont universel via String)
  ConvertedCount := 0;
  NewVal := TGGUFValue.Create;
  try
    for i := 0 to OldCount - 1 do
    begin
      // Récupérer la valeur actuelle sous forme de texte lisible
      StrVal := OldVal.VArr.GetItemAsString(i);
      // Tenter la conversion vers le nouveau type
      if ParseStringValue(StrVal, NewType, NewVal) then
      begin
        if NewType = gvt_STRING then
          FValue.VArr.StrItems.Add(string(NewVal.VStr))
        else
        begin
          case NewType of
            gvt_UINT8:
              FValue.VArr.DatItems[i] := NewVal.VU8;
            gvt_INT8:
              FValue.VArr.DatItems[i] := Byte(NewVal.VI8);
            gvt_UINT16:
              Move(NewVal.VU16, FValue.VArr.DatItems[i * 2], 2);
            gvt_INT16:
              Move(NewVal.VI16, FValue.VArr.DatItems[i * 2], 2);
            gvt_UINT32:
              Move(NewVal.VU32, FValue.VArr.DatItems[i * 4], 4);
            gvt_INT32:
              Move(NewVal.VI32, FValue.VArr.DatItems[i * 4], 4);
            gvt_UINT64:
              Move(NewVal.VU64, FValue.VArr.DatItems[i * 8], 8);
            gvt_INT64:
              Move(NewVal.VI64, FValue.VArr.DatItems[i * 8], 8);
            gvt_FLOAT32:
              Move(NewVal.VF32, FValue.VArr.DatItems[i * 4], 4);
            gvt_FLOAT64:
              Move(NewVal.VF64, FValue.VArr.DatItems[i * 8], 8);
            gvt_BOOL:
              FValue.VArr.DatItems[i] := Byte(NewVal.VBool);
          end;
        end;
        Inc(ConvertedCount);
      end
      else
      begin
        LogMsg('[Conversion] Échec de parsing : ' + GGUFTypeToStr(OldType) + '->' + GGUFTypeToStr(NewType))
      end;
    end;
  finally
    NewVal.Free;
  end;
  // Mettre à jour les métadonnées
  FValue.VArr.ElemType := NewType;
  LogMsg(Format('[Conversion] ✅ Terminée: %d/%d éléments convertis vers %s', [ConvertedCount, OldCount,
   GGUFTypeToStr(NewType)]));
  LoadPage; // Recharger l'UI avec le nouveau type et les données converties
end;

procedure TfrmEditArrayDlg.cbArrTypeChange(Sender: TObject);
var
  NewType : TGGUFValueType;
  i, OldCount, NewElemSize, ByteSize: Integer;
  StrValues: TArray<string>; // Tampon temporaire
  NewVal: TGGUFValue;
begin
  if not Assigned(FValue) or not Assigned(FValue.VArr) then
    Exit;
  if FValue.VArr.Count = 0 then
    Exit; // Rien à convertir

  NewType := StrToGGUFType(cbArrType.Text);
  if (NewType = gvt_None) or (NewType = FValue.VArr.ElemType) then
    Exit;

  // OldType := FValue.VArr.ElemType;
  OldCount := FValue.VArr.Count;

  // EXTRAIRE TOUTES les valeurs en texte AVANT de toucher à la mémoire
  SetLength(StrValues, OldCount);
  for i := 0 to OldCount - 1 do
    StrValues[i] := FValue.VArr.GetItemAsString(i); // Lit depuis l'ancien buffer (type/size anciens)

  // LIBÉRER l'ancien stockage
  if FValue.VArr.IsStringArray then
    FValue.VArr.StrItems.Free
  else
    FValue.VArr.DatItems := nil; // Libère la mémoire du tableau old
  FValue.VArr.IsStringArray := False;

  case NewType of
    gvt_UINT8, gvt_INT8, gvt_BOOL:
      NewElemSize := 1;
    gvt_UINT16, gvt_INT16:
      NewElemSize := 2;
    gvt_UINT32, gvt_INT32, gvt_FLOAT32:
      NewElemSize := 4;
    gvt_UINT64, gvt_INT64, gvt_FLOAT64:
      NewElemSize := 8;
  else
    NewElemSize := 1;
  end;

  if NewType = gvt_STRING then
  begin
    FValue.VArr.StrItems := TStringList.Create;
    FValue.VArr.StrItems.Capacity := OldCount;
    FValue.VArr.IsStringArray := True;
  end
  else
  begin
    ByteSize := OldCount * NewElemSize;
    SetLength(FValue.VArr.DatItems, ByteSize);
    FValue.VArr.IsStringArray := False;
  end;

  NewVal := TGGUFValue.Create;
  try
    for i := 0 to OldCount - 1 do
    begin
      if ParseStringValue(StrValues[i], NewType, NewVal) then
      begin
        if NewType = gvt_STRING then
          FValue.VArr.StrItems.Add(string(NewVal.VStr))
        else
        begin
          case NewType of
            gvt_UINT8:
              FValue.VArr.DatItems[i] := NewVal.VU8;
            gvt_INT8:
              FValue.VArr.DatItems[i] := Byte(NewVal.VI8);
            gvt_UINT16:
              Move(NewVal.VU16, FValue.VArr.DatItems[i * 2], 2);
            gvt_INT16:
              Move(NewVal.VI16, FValue.VArr.DatItems[i * 2], 2);
            gvt_UINT32:
              Move(NewVal.VU32, FValue.VArr.DatItems[i * 4], 4);
            gvt_INT32:
              Move(NewVal.VI32, FValue.VArr.DatItems[i * 4], 4);
            gvt_UINT64:
              Move(NewVal.VU64, FValue.VArr.DatItems[i * 8], 8);
            gvt_INT64:
              Move(NewVal.VI64, FValue.VArr.DatItems[i * 8], 8);
            gvt_FLOAT32:
              Move(NewVal.VF32, FValue.VArr.DatItems[i * 4], 4);
            gvt_FLOAT64:
              Move(NewVal.VF64, FValue.VArr.DatItems[i * 8], 8);
            gvt_BOOL:
              FValue.VArr.DatItems[i] := Byte(NewVal.VBool);
          end;
        end;
      end;
    end;
  finally
    NewVal.Free;
    SetLength(StrValues, 0);
  end;

  FValue.VArr.ElemType := NewType;
  LoadPage;
end;

procedure TfrmEditArrayDlg.LoadPage;
var
  i, startIdx, endIdx, Count: Integer;
begin
  if not Assigned(FValue) or not Assigned(FValue.VArr) then
    Exit;

  Count := FValue.VArr.Count;
  startIdx := FPageIndex * PAGE_SIZE;
  if startIdx >= Count then
  begin
    FPageIndex := 0;
    startIdx := 0;
  end;
  endIdx := startIdx + PAGE_SIZE - 1;
  if endIdx >= Count then
    endIdx := Count - 1;

  sgArray.BeginUpdate;
  try
    sgArray.RowCount := (endIdx - startIdx + 1) + 1;
    sgArray.Cells[0, 0] := '#';
    sgArray.Cells[1, 0] := 'Value';
    for i := 0 to (endIdx - startIdx) do
    begin
      sgArray.Cells[0, i + 1] := IntToStr(startIdx + i);
      sgArray.Cells[1, i + 1] := EscapeJSONString(FValue.VArr.GetItemAsString(startIdx + i));
    end;
  finally
    sgArray.EndUpdate;
  end;

  lblTotalPages.Caption := IntToStr(GetTotalPages);
  edtPageNum.Text := IntToStr(FPageIndex + 1);
  StatusBar1.Panels[0].Text := Format('Page %d/%d (%d items) | Type: %s', [FPageIndex + 1, GetTotalPages, Count,
    GGUFTypeToStr(FValue.VArr.ElemType)]);
end;

function TfrmEditArrayDlg.GetTotalPages: Integer;
begin
  if Assigned(FValue.VArr) then
    Result := Max(1, Ceil(FValue.VArr.Count / PAGE_SIZE))
  else
    Result := 1;
end;

function TfrmEditArrayDlg.GetActualIndex(ARow: Integer): Integer;
begin
  Result := (FPageIndex * PAGE_SIZE) + (ARow - 1);
end;

procedure TfrmEditArrayDlg.sgArraySelectCell(Sender: TObject; ACol, ARow: Integer; var CanSelect: Boolean);
begin
  if (ARow > 0) and Assigned(FValue.VArr) and (ARow > FValue.VArr.Count - (FPageIndex * PAGE_SIZE)) then
    CanSelect := False;
end;

procedure TfrmEditArrayDlg.sgArraySetEditText(Sender: TObject; ACol, ARow: Integer; const Value: string);
var
  RealIdx: Integer;
begin
  if (ARow > 0) and Assigned(FValue.VArr) then
  begin
    RealIdx := (FPageIndex * PAGE_SIZE) + (ARow - 1);
    if (RealIdx >= 0) and (RealIdx < FValue.VArr.Count) then
      FValue.VArr.SetItemValue(RealIdx, Value);
  end;
end;

procedure TfrmEditArrayDlg.btnStrSaveAsClick(Sender: TObject);
begin
  if not Assigned(FValue) or not Assigned(FValue.VArr) then
    Exit;
  SaveDialog1.InitialDir := ExtractFilePath(cfg.edtSrc1);
  // SaveDialog1.FileName := cfg.edtSrc1 + FCurKey + '.txt';
  SaveDialog1.FileName := cfg.edtSrc1 + SafeFileName(FCurKey) + '.txt';
  if SaveDialog1.Execute then
  begin
    try
      // Export au format simple TStrings (une valeur par ligne)
      TFile.WriteAllText(SaveDialog1.FileName, FValue.VArr.SaveToText, TEncoding.UTF8);
    except
      on E: Exception do
        // MessageDlg('Erreur de sauvegarde : ' + E.Message, mtError, [mbOK], 0);
        MessageDlg(mLang.gMsgFmt('FKV.ArraySaveErr', [E.Message]), mtError, [mbOK], 0);
    end;
  end;
end;

procedure TfrmEditArrayDlg.btnArrOkClick(Sender: TObject);
begin
  ModalResult := mrOk;
end;

procedure TfrmEditArrayDlg.btnArrCancelClick(Sender: TObject);
begin
  ModalResult := mrCancel;
end;

procedure TfrmEditArrayDlg.btnArrLoadClick(Sender: TObject);
var
  S: string;
begin
  if not OpenDialog1.Execute then
    Exit;
  try
    S := TFile.ReadAllText(OpenDialog1.FileName, TEncoding.UTF8);
    S := Trim(S);
    if S = '' then
      Exit;
    // Import au format simple TStrings
    if Assigned(FValue) and Assigned(FValue.VArr) then
      FValue.VArr.LoadFromText(S);
    // Synchroniser le type avec la combo
    cbArrType.ItemIndex := cbArrType.Items.IndexOf(GGUFTypeToStr(FValue.VArr.ElemType));
    LoadPage;
  except
    on E: Exception do
      // MessageDlg('Erreur d''importation : ' + E.Message, mtError, [mbOK], 0);
      MessageDlg(mLang.gMsgFmt('FKV.ArrayImportErr', [E.Message]), mtError, [mbOK], 0);
  end;
end;

procedure TfrmEditArrayDlg.btnNextClick(Sender: TObject);
begin
  if FPageIndex < GetTotalPages - 1 then
  begin
    Inc(FPageIndex);
    LoadPage;
  end;
end;

procedure TfrmEditArrayDlg.btnNextAllClick(Sender: TObject);
begin
  FPageIndex := GetTotalPages - 1;
  LoadPage;
end;

procedure TfrmEditArrayDlg.btnPrevClick(Sender: TObject);
begin
  if FPageIndex > 0 then
  begin
    Dec(FPageIndex);
    LoadPage;
  end;
end;

procedure TfrmEditArrayDlg.btnPrevAllClick(Sender: TObject);
begin
  FPageIndex := 0;
  LoadPage;
end;

procedure TfrmEditArrayDlg.edtPageNumKeyUp(Sender: TObject; var Key: Word; Shift: TShiftState);
var
  NewPage: Integer;
begin
  if Key = VK_RETURN then
  begin
    NewPage := StrToIntDef(edtPageNum.Text, 1) - 1;
    if (NewPage >= 0) and (NewPage < GetTotalPages) then
    begin
      FPageIndex := NewPage;
      LoadPage;
    end;
  end;
end;

end.
