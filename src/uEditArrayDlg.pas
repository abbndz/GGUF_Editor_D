unit uEditArrayDlg;

interface

uses
  Windows, Messages, SysUtils, Classes, Controls, Forms, Dialogs, StdCtrls, Grids, ExtCtrls, RichEdit, System.IOUtils,
  Vcl.ComCtrls, uGGUFTypes, uGGMLTypes, uMath, uLangManager, Vcl.Menus;

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
    cbArrType1: TComboBox;
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

uses uAppConfig;

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
  cbArrType1.ItemIndex := cbArrType1.Items.IndexOf(GGUFTypeToStr(FValue.VArr.ElemType));
  if cbArrType1.ItemIndex < 0 then
    cbArrType1.ItemIndex := 0;
  lblArrType.Visible := True;
  cbArrType1.Visible := True;

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
  cbArrType1.Items.Clear;
  for VT := Integer(Low(TGGUFValueType)) to Integer(High(TGGUFValueType)) do
    if (VT <> Integer(gvt_None)) and (VT <> Integer(gvt_ARRAY)) then
      cbArrType1.Items.Add(GGUFTypeToStr(TGGUFValueType(VT)));
end;

procedure TfrmEditArrayDlg.FormShow(Sender: TObject);
begin
  LoadPage;
end;

procedure TfrmEditArrayDlg.cbArrTypeChange(Sender: TObject);
begin
  if Assigned(FValue) and Assigned(FValue.VArr) then
  begin
    FValue.VArr.ElemType := StrToGGUFType(cbArrType1.Text);
    LoadPage; // Recharge pour appliquer le type au preview
  end;
end;

procedure TfrmEditArrayDlg.LoadPage;
var
  i, startIdx, endIdx, Count: Integer;
begin
  if not Assigned(FValue) or not Assigned(FValue.VArr) then
    Exit;
  Count := FValue.VArr.Items.Count;
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
      sgArray.Cells[1, i + 1] := FValue.VArr.Items[startIdx + i];
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
    Result := Max(1, Ceil(FValue.VArr.Items.Count / PAGE_SIZE))
  else
    Result := 1;
end;

function TfrmEditArrayDlg.GetActualIndex(ARow: Integer): Integer;
begin
  Result := (FPageIndex * PAGE_SIZE) + (ARow - 1);
end;

procedure TfrmEditArrayDlg.sgArraySelectCell(Sender: TObject; ACol, ARow: Integer; var CanSelect: Boolean);
begin
  if (ARow > 0) and Assigned(FValue.VArr) and (ARow > FValue.VArr.Items.Count - (FPageIndex * PAGE_SIZE)) then
    CanSelect := False;
end;

procedure TfrmEditArrayDlg.sgArraySetEditText(Sender: TObject; ACol, ARow: Integer; const Value: string);
var
  RealIdx: Integer;
begin
  if (ARow > 0) and Assigned(FValue.VArr) then
  begin
    RealIdx := (FPageIndex * PAGE_SIZE) + (ARow - 1);
    if (RealIdx >= 0) and (RealIdx < FValue.VArr.Items.Count) then
      FValue.VArr.Items[RealIdx] := Value;
  end;
end;

procedure TfrmEditArrayDlg.btnStrSaveAsClick(Sender: TObject);
begin
  if not Assigned(FValue) or not Assigned(FValue.VArr) then
    Exit;
  SaveDialog1.FileName := cfg.edtSrc1 + FCurKey + '.txt';
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
    cbArrType1.ItemIndex := cbArrType1.Items.IndexOf(GGUFTypeToStr(FValue.VArr.ElemType));
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
