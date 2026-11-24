unit uEditKVFileTypeDlg;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls,
  uGGUFTypes, uGGMLTypes;

type
  TfrmEditKVFileTypeDlg = class(TForm)
    cbType: TComboBox;
    btnOK: TButton;
    btnCancel: TButton;
    Edit1: TEdit;
    lblDescription: TLabel;
    procedure FormCreate(Sender: TObject);
    procedure cbTypeChange(Sender: TObject);
    procedure btnOKClick(Sender: TObject);
    procedure btnCancelClick(Sender: TObject);
  private
    { Déclarations privées }
    FValue: TGGUFValue; // On stocke le clone ici
    FCurKey: String;
    FSelectedValue: UInt32;
    function GetTypeName(AValue: UInt32): string;
  public
    { D�clarations publiques }
    function Execute(var AValue: TGGUFValue; CurKey: String): Boolean;
  end;

var
  frmEditKVFileTypeDlg: TfrmEditKVFileTypeDlg;

implementation

{$R *.dfm}

//ggml.h
// model file types enum ggml_ftype
{       GGML_FTYPE_UNKNOWN        = -1,
        GGML_FTYPE_ALL_F32        = 0,
        GGML_FTYPE_MOSTLY_F16     = 1,  // except 1d tensors
        GGML_FTYPE_MOSTLY_Q4_0    = 2,  // except 1d tensors
        GGML_FTYPE_MOSTLY_Q4_1    = 3,  // except 1d tensors
        GGML_FTYPE_MOSTLY_Q4_1_SOME_F16 = 4, // tok_embeddings.weight and output.weight are F16
        GGML_FTYPE_MOSTLY_Q8_0    = 7,  // except 1d tensors
        GGML_FTYPE_MOSTLY_Q5_0    = 8,  // except 1d tensors
        GGML_FTYPE_MOSTLY_Q5_1    = 9,  // except 1d tensors
        GGML_FTYPE_MOSTLY_Q2_K    = 10, // except 1d tensors
        GGML_FTYPE_MOSTLY_Q3_K    = 11, // except 1d tensors
        GGML_FTYPE_MOSTLY_Q4_K    = 12, // except 1d tensors
        GGML_FTYPE_MOSTLY_Q5_K    = 13, // except 1d tensors
        GGML_FTYPE_MOSTLY_Q6_K    = 14, // except 1d tensors
        GGML_FTYPE_MOSTLY_IQ2_XXS = 15, // except 1d tensors
        GGML_FTYPE_MOSTLY_IQ2_XS  = 16, // except 1d tensors
        GGML_FTYPE_MOSTLY_IQ3_XXS = 17, // except 1d tensors
        GGML_FTYPE_MOSTLY_IQ1_S   = 18, // except 1d tensors
        GGML_FTYPE_MOSTLY_IQ4_NL  = 19, // except 1d tensors
        GGML_FTYPE_MOSTLY_IQ3_S   = 20, // except 1d tensors
        GGML_FTYPE_MOSTLY_IQ2_S   = 21, // except 1d tensors
        GGML_FTYPE_MOSTLY_IQ4_XS  = 22, // except 1d tensors
        GGML_FTYPE_MOSTLY_IQ1_M   = 23, // except 1d tensors
        GGML_FTYPE_MOSTLY_BF16    = 24, // except 1d tensors
        GGML_FTYPE_MOSTLY_MXFP4   = 25, // except 1d tensors
        GGML_FTYPE_MOSTLY_NVFP4   = 26, // except 1d tensors
        GGML_FTYPE_MOSTLY_Q1_0    = 27, // except 1d tensors
        GGML_FTYPE_MOSTLY_Q2_0    = 28, // except 1d tensors
        GGML_FTYPE_MOSTLY_F8_E4M3 = 29, // except 1d tensors } //;

// llama.h // model file types : enum llama_ftype
{       LLAMA_FTYPE_ALL_F32              = 0,
        LLAMA_FTYPE_MOSTLY_F16           = 1,  // except 1d tensors
        LLAMA_FTYPE_MOSTLY_Q4_0          = 2,  // except 1d tensors
        LLAMA_FTYPE_MOSTLY_Q4_1          = 3,  // except 1d tensors
        // LLAMA_FTYPE_MOSTLY_Q4_1_SOME_F16 = 4,  // tok_embeddings.weight and output.weight are F16
        // LLAMA_FTYPE_MOSTLY_Q4_2       = 5,  // support has been removed
        // LLAMA_FTYPE_MOSTLY_Q4_3       = 6,  // support has been removed
        LLAMA_FTYPE_MOSTLY_Q8_0          = 7,  // except 1d tensors
        LLAMA_FTYPE_MOSTLY_Q5_0          = 8,  // except 1d tensors
        LLAMA_FTYPE_MOSTLY_Q5_1          = 9,  // except 1d tensors
        LLAMA_FTYPE_MOSTLY_Q2_K          = 10, // except 1d tensors
        LLAMA_FTYPE_MOSTLY_Q3_K_S        = 11, // except 1d tensors
        LLAMA_FTYPE_MOSTLY_Q3_K_M        = 12, // except 1d tensors
        LLAMA_FTYPE_MOSTLY_Q3_K_L        = 13, // except 1d tensors
        LLAMA_FTYPE_MOSTLY_Q4_K_S        = 14, // except 1d tensors
        LLAMA_FTYPE_MOSTLY_Q4_K_M        = 15, // except 1d tensors
        LLAMA_FTYPE_MOSTLY_Q5_K_S        = 16, // except 1d tensors
        LLAMA_FTYPE_MOSTLY_Q5_K_M        = 17, // except 1d tensors
        LLAMA_FTYPE_MOSTLY_Q6_K          = 18, // except 1d tensors
        LLAMA_FTYPE_MOSTLY_IQ2_XXS       = 19, // except 1d tensors
        LLAMA_FTYPE_MOSTLY_IQ2_XS        = 20, // except 1d tensors
        LLAMA_FTYPE_MOSTLY_Q2_K_S        = 21, // except 1d tensors
        LLAMA_FTYPE_MOSTLY_IQ3_XS        = 22, // except 1d tensors
        LLAMA_FTYPE_MOSTLY_IQ3_XXS       = 23, // except 1d tensors
        LLAMA_FTYPE_MOSTLY_IQ1_S         = 24, // except 1d tensors
        LLAMA_FTYPE_MOSTLY_IQ4_NL        = 25, // except 1d tensors
        LLAMA_FTYPE_MOSTLY_IQ3_S         = 26, // except 1d tensors
        LLAMA_FTYPE_MOSTLY_IQ3_M         = 27, // except 1d tensors
        LLAMA_FTYPE_MOSTLY_IQ2_S         = 28, // except 1d tensors
        LLAMA_FTYPE_MOSTLY_IQ2_M         = 29, // except 1d tensors
        LLAMA_FTYPE_MOSTLY_IQ4_XS        = 30, // except 1d tensors
        LLAMA_FTYPE_MOSTLY_IQ1_M         = 31, // except 1d tensors
        LLAMA_FTYPE_MOSTLY_BF16          = 32, // except 1d tensors
        //LLAMA_FTYPE_MOSTLY_Q4_0_4_4      = 33, // removed from gguf files, use Q4_0 and runtime repack
        //LLAMA_FTYPE_MOSTLY_Q4_0_4_8      = 34, // removed from gguf files, use Q4_0 and runtime repack
        //LLAMA_FTYPE_MOSTLY_Q4_0_8_8      = 35, // removed from gguf files, use Q4_0 and runtime repack
        LLAMA_FTYPE_MOSTLY_TQ1_0         = 36, // except 1d tensors
        LLAMA_FTYPE_MOSTLY_TQ2_0         = 37, // except 1d tensors
        LLAMA_FTYPE_MOSTLY_MXFP4_MOE     = 38, // except 1d tensors
        LLAMA_FTYPE_MOSTLY_NVFP4         = 39, // except 1d tensors
        LLAMA_FTYPE_MOSTLY_Q1_0          = 40, // except 1d tensors
        LLAMA_FTYPE_MOSTLY_Q2_0          = 41, // except 1d tensors
        LLAMA_FTYPE_MOSTLY_F8_E4M3       = 42, // except 1d tensors

        LLAMA_FTYPE_GUESSED = 1024, // not specified in the model file
// llama-model-loader.cpp : switch ((enum llama_ftype) (ftype & ~LLAMA_FTYPE_GUESSED))
{       case LLAMA_FTYPE_ALL_F32:          name = LLAMA_FTYPE_PREFIX "all F32"; break;
        case LLAMA_FTYPE_MOSTLY_F16:       name = LLAMA_FTYPE_PREFIX "F16"; break;
        case LLAMA_FTYPE_MOSTLY_BF16:      name = LLAMA_FTYPE_PREFIX "BF16"; break;
        case LLAMA_FTYPE_MOSTLY_Q1_0:      name = LLAMA_FTYPE_PREFIX "Q1_0"; break;
        case LLAMA_FTYPE_MOSTLY_Q2_0:      name = LLAMA_FTYPE_PREFIX "Q2_0"; break;
        case LLAMA_FTYPE_MOSTLY_F8_E4M3:   name = LLAMA_FTYPE_PREFIX "F8_E4M3"; break;
        case LLAMA_FTYPE_MOSTLY_Q4_0:      name = LLAMA_FTYPE_PREFIX "Q4_0"; break;
        case LLAMA_FTYPE_MOSTLY_Q4_1:      name = LLAMA_FTYPE_PREFIX "Q4_1"; break;
        case LLAMA_FTYPE_MOSTLY_Q5_0:      name = LLAMA_FTYPE_PREFIX "Q5_0"; break;
        case LLAMA_FTYPE_MOSTLY_Q5_1:      name = LLAMA_FTYPE_PREFIX "Q5_1"; break;
        case LLAMA_FTYPE_MOSTLY_Q8_0:      name = LLAMA_FTYPE_PREFIX "Q8_0"; break;
        case LLAMA_FTYPE_MOSTLY_MXFP4_MOE: name = LLAMA_FTYPE_PREFIX "MXFP4 MoE"; break;
        case LLAMA_FTYPE_MOSTLY_NVFP4:     name = LLAMA_FTYPE_PREFIX "NVFP4"; break;
        case LLAMA_FTYPE_MOSTLY_Q2_K:      name = LLAMA_FTYPE_PREFIX "Q2_K - Medium"; break;
        case LLAMA_FTYPE_MOSTLY_Q2_K_S:    name = LLAMA_FTYPE_PREFIX "Q2_K - Small"; break;
        case LLAMA_FTYPE_MOSTLY_Q3_K_S:    name = LLAMA_FTYPE_PREFIX "Q3_K - Small"; break;
        case LLAMA_FTYPE_MOSTLY_Q3_K_M:    name = LLAMA_FTYPE_PREFIX "Q3_K - Medium"; break;
        case LLAMA_FTYPE_MOSTLY_Q3_K_L:    name = LLAMA_FTYPE_PREFIX "Q3_K - Large"; break;
        case LLAMA_FTYPE_MOSTLY_Q4_K_S:    name = LLAMA_FTYPE_PREFIX "Q4_K - Small"; break;
        case LLAMA_FTYPE_MOSTLY_Q4_K_M:    name = LLAMA_FTYPE_PREFIX "Q4_K - Medium"; break;
        case LLAMA_FTYPE_MOSTLY_Q5_K_S:    name = LLAMA_FTYPE_PREFIX "Q5_K - Small"; break;
        case LLAMA_FTYPE_MOSTLY_Q5_K_M:    name = LLAMA_FTYPE_PREFIX "Q5_K - Medium"; break;
        case LLAMA_FTYPE_MOSTLY_Q6_K:      name = LLAMA_FTYPE_PREFIX "Q6_K"; break;
        case LLAMA_FTYPE_MOSTLY_TQ1_0:     name = LLAMA_FTYPE_PREFIX "TQ1_0 - 1.69 bpw ternary"; break;
        case LLAMA_FTYPE_MOSTLY_TQ2_0:     name = LLAMA_FTYPE_PREFIX "TQ2_0 - 2.06 bpw ternary"; break;
        case LLAMA_FTYPE_MOSTLY_IQ2_XXS:   name = LLAMA_FTYPE_PREFIX "IQ2_XXS - 2.0625 bpw"; break;
        case LLAMA_FTYPE_MOSTLY_IQ2_XS:    name = LLAMA_FTYPE_PREFIX "IQ2_XS - 2.3125 bpw"; break;
        case LLAMA_FTYPE_MOSTLY_IQ2_S:     name = LLAMA_FTYPE_PREFIX "IQ2_S - 2.5 bpw"; break;
        case LLAMA_FTYPE_MOSTLY_IQ2_M:     name = LLAMA_FTYPE_PREFIX "IQ2_M - 2.7 bpw"; break;
        case LLAMA_FTYPE_MOSTLY_IQ3_XS:    name = LLAMA_FTYPE_PREFIX "IQ3_XS - 3.3 bpw"; break;
        case LLAMA_FTYPE_MOSTLY_IQ3_XXS:   name = LLAMA_FTYPE_PREFIX "IQ3_XXS - 3.0625 bpw"; break;
        case LLAMA_FTYPE_MOSTLY_IQ1_S:     name = LLAMA_FTYPE_PREFIX "IQ1_S - 1.5625 bpw"; break;
        case LLAMA_FTYPE_MOSTLY_IQ1_M:     name = LLAMA_FTYPE_PREFIX "IQ1_M - 1.75 bpw"; break;
        case LLAMA_FTYPE_MOSTLY_IQ4_NL:    name = LLAMA_FTYPE_PREFIX "IQ4_NL - 4.5 bpw"; break;
        case LLAMA_FTYPE_MOSTLY_IQ4_XS:    name = LLAMA_FTYPE_PREFIX "IQ4_XS - 4.25 bpw"; break;
        case LLAMA_FTYPE_MOSTLY_IQ3_S:     name = LLAMA_FTYPE_PREFIX "IQ3_S - 3.4375 bpw"; break;
        case LLAMA_FTYPE_MOSTLY_IQ3_M:     name = LLAMA_FTYPE_PREFIX "IQ3_S mix - 3.66 bpw"; break;
        default:                           name = LLAMA_FTYPE_PREFIX "unknown, may not work"; break;


{ Mapping basé sur le code C fourni }
function TfrmEditKVFileTypeDlg.GetTypeName(AValue: UInt32): string;
begin
  case AValue of
    0: Result := 'all F32';
    1: Result := 'F16';
    2: Result := 'Q4_0';
    3: Result := 'Q4_1';
    7: Result := 'Q8_0';
    8: Result := 'Q5_0';
    9: Result := 'Q5_1';
    10:Result := 'Q2_K - Medium';
    11:Result := 'Q3_K_S - Small';
    12:Result := 'Q3_K_M - Medium';
    13:Result := 'Q3_K_L - Large';
    14:Result := 'Q4_K_S - Small';
    15:Result := 'Q4_K_M - Medium';
    16:Result := 'Q5_K_S - Small';
    17:Result := 'Q5_K_M - Medium';
    18:Result := 'Q6_K';
    19:Result := 'IQ2_XXS - 2.0625 bpw';
    20:Result := 'IQ2_XS - 2.3125 bpw';
    21:Result := 'Q2_K_S - Small';
    22:Result := 'IQ3_XS - 3.3 bpw';
    23:Result := 'IQ3_XXS - 3.0625 bpw';
    24:Result := 'IQ1_S - 1.5625 bpw';
    25:Result := 'IQ4_NL - 4.5 bpw';
    26:Result := 'IQ3_S - 3.4375 bpw';
    27:Result := 'IQ3_M IQ3_S mix - 3.66 bpw';
    28:Result := 'IQ2_S - 2.5 bpw';
    29:Result := 'IQ2_M - 2.7 bpw';
    30:Result := 'IQ4_XS - 4.25 bpw';
    31:Result := 'IQ1_M - 1.75 bpw';
    32:Result := 'BF16';
    36:Result := 'TQ1_0 - 1.69 bpw ternary';
    37:Result := 'TQ2_0 - 2.06 bpw ternary';
    38:Result := 'MXFP4 MoE';
    39:Result := 'NVFP4';
    40:Result := 'Q1_0';
    41:Result := 'Q2_0';
    42:Result := 'F8_E4M3';
  else
      Result := 'Unknown Type';
  end;
end;

procedure TfrmEditKVFileTypeDlg.btnCancelClick(Sender: TObject);
begin
  ModalResult := mrCancel;
end;

procedure TfrmEditKVFileTypeDlg.btnOKClick(Sender: TObject);
begin
  ModalResult := mrOk;
end;

procedure TfrmEditKVFileTypeDlg.cbTypeChange(Sender: TObject);
begin
  if cbType.ItemIndex <> -1 then
  begin
    FSelectedValue := StrToIntDef(cbType.Text, 0);
    lblDescription.Caption := GetTypeName(FSelectedValue);
  end;
end;

procedure TfrmEditKVFileTypeDlg.FormCreate(Sender: TObject);
var
  i: Integer;
begin
  cbType.Items.Clear;
  // On remplit la combo avec les valeurs numériques 0 à 41 (selon l'enum C)
  for i := 0 to 42 do
    cbType.Items.Add(IntToStr(i));
end;

function TfrmEditKVFileTypeDlg.Execute(var AValue: TGGUFValue; CurKey: String): Boolean;
begin
  Result := False;
  if not Assigned(AValue) then
    Exit;

  // Vérification de sécurité du type
  // if (AValue.ValueType <> gvt_UINT32) then
  // begin
  // // On pourrait lever une exception ou afficher un message
  // Exit;
  // end;

  FValue := AValue.Clone; // On clone l'original
  FCurKey := CurKey;

  // Initialisation de la combo avec la valeur actuelle
  cbType.ItemIndex := cbType.Items.IndexOf(IntToStr(FValue.VU32));
  if cbType.ItemIndex = -1 then
    cbType.ItemIndex := 0;
  lblDescription.Caption := GetTypeName(FValue.VU32);

  if ShowModal = mrOk then
  begin
    // IMPORTANT : On applique la nouvelle valeur au clone avant le swap
    FValue.VU32 := StrToIntDef(cbType.Text, 0);

    // Pattern de remplacement (identique à votre uEditStringDlg)
    AValue.Free;
    AValue := FValue;
    Result := True;
  end
  else
    FValue.Free;
end;

end.
