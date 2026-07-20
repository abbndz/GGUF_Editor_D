unit uEditStringDlg;

interface

uses
  Windows, Messages, SysUtils, Classes, Controls, Forms, Dialogs, StdCtrls, Grids, ExtCtrls, RichEdit, System.IOUtils,
  Vcl.ComCtrls, uGGUFTypes, uGGMLTypes, uMath, Vcl.Menus;

type

  TfrmEditStringDlg = class(TForm)
    StatusBar1: TStatusBar;
    OpenDialog1: TOpenDialog;
    SaveDialog1: TSaveDialog;
    pnlStrArrBot: TPanel;
    btnStrLoad: TButton;
    btnStrSaveAs: TButton;
    btnStrOK: TButton;
    btnStrCancel: TButton;
    memoEditor: TRichEdit;
    procedure btnStrLoadClick(Sender: TObject);
    procedure btnStrSaveAsClick(Sender: TObject);
    procedure btnStrOKClick(Sender: TObject);
    procedure btnStrCancelClick(Sender: TObject);
  private
    FValue: TGGUFValue;
    FCurKey: String;
  public
    function Execute(var AValue: TGGUFValue; CurKey: String): Boolean;
    procedure LoadPage;
  end;

var
  frmEditStringDlg: TfrmEditStringDlg;

implementation

uses uEditKVsGGUF, uLangManager, uAppConfig;

{$R *.dfm}

{ TfrmEditStringDlg }
function TfrmEditStringDlg.Execute(var AValue: TGGUFValue; CurKey: String): Boolean;
begin
  Result := False;
  if not Assigned(AValue) then
    Exit;
  FValue := AValue.Clone;
  FCurKey := CurKey;

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

procedure TfrmEditStringDlg.LoadPage;
var
  i, startIdx, endIdx, Count: Integer;
begin
  if not Assigned(FValue) then
    Exit;
  memoEditor.Lines.BeginUpdate;
  try
    memoEditor.Text := FValue.AsStrFull;
  finally
    memoEditor.Lines.EndUpdate;
  end;
end;

procedure TfrmEditStringDlg.btnStrLoadClick(Sender: TObject);
var
  S: string;
begin
  if not OpenDialog1.Execute then
    Exit;
  try
    S := TFile.ReadAllText(OpenDialog1.FileName, TEncoding.UTF8);
    //S := Trim(S);
    if S = '' then
      Exit;
    if Assigned(FValue) then
      FValue.Free;
    FValue := nil;
    FValue := TGGUFValue.Create;
    FValue.ValueType := gvt_STRING;
    FValue.VStr := AnsiString(S);
    LoadPage;
  except
    on E: Exception do
    begin
      // MessageDlg('Erreur d''importation : ' + E.Message, mtError, [mbOK], 0);
      MessageDlg(mLang.gMsgFmt('FKV.StringImportErr', [E.Message]), mtError, [mbOK], 0);
    end;
  end;
end;

procedure TfrmEditStringDlg.btnStrSaveAsClick(Sender: TObject);
begin
  if not Assigned(FValue) then
    Exit;
  SaveDialog1.FileName := cfg.edtSrc1 + FCurKey + '.txt';
  if SaveDialog1.Execute then
  begin
    try
      TFile.WriteAllText(SaveDialog1.FileName, string(FValue.VStr), TEncoding.UTF8)
    except
      on E: Exception do
        // MessageDlg('Erreur de sauvegarde : ' + E.Message, mtError, [mbOK], 0);
        MessageDlg(mLang.gMsgFmt('FKV.StringSaveErr', [E.Message]), mtError, [mbOK], 0);
    end;
  end;
end;

procedure TfrmEditStringDlg.btnStrOKClick(Sender: TObject);
begin
  if (FValue.ValueType = gvt_STRING) then
  begin
    FValue.VStr := AnsiString(memoEditor.Text);
    ModalResult := mrOk;
  end;
end;

procedure TfrmEditStringDlg.btnStrCancelClick(Sender: TObject);
begin
  ModalResult := mrCancel;
end;

end.
