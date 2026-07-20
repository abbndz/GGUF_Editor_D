unit uEditKVsGGUFNewKey;

interface

uses
  Windows, Messages, SysUtils, Classes, Controls, Forms, Dialogs, StdCtrls,
  ExtCtrls, uGGUFTypes, uGGUFModel, uKVsGGUFConst, uGgufStrUtils, System.StrUtils;

type
  TfrmEditNewKV = class(TForm)
    pnlTop: TPanel;
    lblKey: TLabel;
    lblType: TLabel;
    cbType: TComboBox;
    pnlBottom: TPanel;
    btnOK: TButton;
    btnCancel: TButton;
    memoValue: TMemo;
    cbKeyFamily: TComboBox;
    cbKey: TComboBox;
    btnAdd: TButton;
    cbArrType: TComboBox;
    lblArrType: TLabel;
    procedure btnOKClick(Sender: TObject);
    procedure btnCancelClick(Sender: TObject);
    procedure cbTypeChange(Sender: TObject);
    procedure cbKeyFamilyChange(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure btnAddClick(Sender: TObject);
  private
    function AddKeyValue(): boolean;

  public
    procedure SetKeyValue(AKey: AnsiString; AValue: TGGUFValue);
    procedure UpdateKeyListFromFamily;
  end;

var
  frmEditNewKV: TfrmEditNewKV;

implementation

uses uEditKVsGGUF, uLangManager;

{$R *.dfm}

procedure TfrmEditNewKV.FormShow(Sender: TObject);
var
  i, VT: Integer;
begin
  cbType.Items.Clear;
  { TGGUFValueType = (gvt_None = -1, gvt_UINT8 = 0, gvt_INT8 = 1, gvt_UINT16 = 2, gvt_INT16 = 3, gvt_UINT32 = 4,
    gvt_INT32 = 5, gvt_FLOAT32 = 6, gvt_BOOL = 7, gvt_STRING = 8, gvt_ARRAY = 9, gvt_UINT64 = 10, gvt_INT64 = 11,
    gvt_FLOAT64 = 12); }
  cbType.Items.Clear;
  for VT := Integer(Low(TGGUFValueType)) to Integer(High(TGGUFValueType)) do
    cbType.Items.Add(GGUFTypeToStr(TGGUFValueType(VT)));
  cbType.ItemIndex := cbType.Items.IndexOf('STRING');

  for VT := Integer(Low(TGGUFValueType)) to Integer(High(TGGUFValueType)) do
    if (VT <> Integer(gvt_None)) and (VT <> Integer(gvt_ARRAY)) then
      cbArrType.Items.Add(GGUFTypeToStr(TGGUFValueType(VT)));
  // Initialisation de la liste des familles si vide
  if cbKeyFamily.Items.Count = 0 then
  begin
    cbKeyFamily.Items.Assign(TGGUFKeyManager.GetFamilyNames);
    cbKeyFamily.ItemIndex := 1; // "General" par défaut
  end;
  UpdateKeyListFromFamily;
end;

procedure TfrmEditNewKV.UpdateKeyListFromFamily;
var
  SL: TStringList;
  FamilyIdx: Integer;
  Family: TGGUFKeyFamily;
  archKV: TGGUFKeyValue;
  Arch: string;
begin
  FamilyIdx := cbKeyFamily.ItemIndex;
  // Index 0 est "(Autre)", donc kfCustom. Index 1 est kfGeneral.
  if FamilyIdx = 0 then
    Family := kfCustom
  else
    Family := TGGUFKeyFamily(FamilyIdx);

  Arch := '';
  if Assigned(frmEditKVsGGUF.ModelOut) then
  begin
    archKV := frmEditKVsGGUF.ModelOut.FindKV('general.architecture');
    if Assigned(archKV) then
      Arch := archKV.Val.AsStrPrev;
  end;

  cbKey.Items.Clear;
  if Family = kfCustom then
    cbKey.Items.Add('custom.key.name')
  else
  begin
    SL := TGGUFKeyManager.GetKeysForFamily(Family, Arch);
    try
      cbKey.Items.Assign(SL);
    finally
      SL.Free;
    end;
  end;
  // cbKey.Items.Assign(TGGUFKeyManager.GetKeysForFamily(Family, Arch));
  if cbKey.Items.Count > 0 then
    cbKey.ItemIndex := 0;
end;

procedure TfrmEditNewKV.SetKeyValue(AKey: AnsiString; AValue: TGGUFValue);
begin
  cbKey.Text := AKey;
  cbType.Text := GGUFTypeToStr(AValue.ValueType);
  memoValue.Text := AValue.AsStrFull;
end;

function TfrmEditNewKV.AddKeyValue(): boolean;
var
  sKey, sValue: AnsiString;
  newKV: TGGUFKeyValue;
  newGGUFValue: TGGUFValue;
  VT: TGGUFValueType;
begin
  result := false;
  sKey := Trim(cbKey.Text);
  if sKey = '' then
  begin
    // MessageDlg('Key empty.', mtWarning, [mbOK], 0);
    MessageDlg(mLang.gMsg('FKV.KeyEmptyNew'), mtWarning, [mbOK], 0);
    Exit;
  end;

  sValue := Trim(memoValue.Text);
  if sValue = '' then
  begin
    // MessageDlg('Value empty.', mtWarning, [mbOK], 0);
    MessageDlg(mLang.gMsg('FKV.ValueEmptyNew'), mtWarning, [mbOK], 0);
    Exit;
  end;

  VT := StrToGGUFType(cbType.Text);

  if VT = gvt_ARRAY then
  begin
    newGGUFValue := TGGUFValue.Create;
    newGGUFValue.ValueType := gvt_ARRAY;
    newGGUFValue.VArr := TGGUFArray.Create;
    newGGUFValue.VArr.ElemType := TGGUFValueType(cbArrType.ItemIndex);
    newGGUFValue.VArr.LoadFromText(sValue);
  end
  else
  begin
    if not ParseStringValue(sValue, VT, newGGUFValue) then
      // raise Exception.Create('Format de valeur invalide pour le type sélectionné.');
      raise Exception.Create(mLang.gMsg('FKV.InvalidValueFormat'));
  end;

  if not Assigned(newGGUFValue) then
    Exit;

  newKV := TGGUFKeyValue.Create;
  newKV.Key := AnsiString(sKey);
  newKV.Val := newGGUFValue;
  newKV.Keep := True;

  // Retourner au formulaire parent
  if Assigned(frmEditKVsGGUF) then
    frmEditKVsGGUF.AddNewKeyValue(newKV);
  result := True;
end;

procedure TfrmEditNewKV.btnOKClick(Sender: TObject);
begin
  if AddKeyValue then
    Close;
end;

procedure TfrmEditNewKV.btnAddClick(Sender: TObject);
begin
  AddKeyValue();
end;

procedure TfrmEditNewKV.btnCancelClick(Sender: TObject);
begin
  Close;
end;

procedure TfrmEditNewKV.cbKeyFamilyChange(Sender: TObject);
begin
  UpdateKeyListFromFamily;
end;

procedure TfrmEditNewKV.cbTypeChange(Sender: TObject);
var
  isArrType: boolean;
begin
  isArrType := cbType.Text = 'ARRAY';
  lblArrType.Visible := isArrType;
  cbArrType.Visible := isArrType;
end;

end.
