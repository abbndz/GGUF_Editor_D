unit uFrmAbout;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ExtCtrls, Winapi.ShellAPI;

type
  TFrmAbout = class(TForm)
    pnlHeader: TPanel;
    lblVersion: TLabel;
    pnlMain: TPanel;
    lblDescription: TLabel;
    lblCredits: TLabel;
    pnlDonate: TPanel;
    lblDonation: TLabel;
    lblPayPal: TLabel;
    lblKafeMe: TLabel;
    lblBuildInfo: TLabel;
    pnlBot: TPanel;
    btnOk: TButton;
    procedure btnOkClick(Sender: TObject);

    procedure lblLinkMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure lblKafeMeClick(Sender: TObject);
    procedure FormShow(Sender: TObject);
  private
    procedure OpenLink(const URL: string);
  public
    { Déclarations publiques }
  end;

var
  frmAbout: TFrmAbout;

implementation

uses uAppConfig, uLangManager;

{$R *.dfm}

procedure TFrmAbout.OpenLink(const URL: string);
begin
  try
    ShellExecute(0, 'open', PChar(URL), nil, nil, SW_SHOWNORMAL);
  except
    on E: Exception do
      // ShowMessage('Impossible d'#39#39262'rouvrir le lien : ' + E.Message);
      MessageDlg(mLang.gMsgFmt('FAB.OpenLinkError', [E.Message]), mtError, [mbOK], 0);
  end;
end;

//

procedure TFrmAbout.FormShow(Sender: TObject);
begin
  lblVersion.Caption := 'GGUF Editor D++ v' + APP_VERSION;
  lblBuildInfo.Caption := 'Build: ' + APP_BUILD_DATE;

  lblPayPal.Caption := 'PayPal : abbndz@gmail.com';
  lblKafeMe.Caption := 'ko-fi.com/abbndz';
end;

procedure TFrmAbout.lblKafeMeClick(Sender: TObject);
begin
  OpenLink('https://ko-fi.com/abbndz');
end;

procedure TFrmAbout.lblLinkMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
begin
  if Sender is TLabel then
    TLabel(Sender).Cursor := crHandPoint;
end;

procedure TFrmAbout.btnOkClick(Sender: TObject);
begin
  Close;
end;

end.
