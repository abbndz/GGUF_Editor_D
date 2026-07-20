unit uRangeSlider;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes, Vcl.Controls,
  Vcl.ExtCtrls, Vcl.Graphics, System.Math;

type
  TRangeMode = (rmNone, rmResizingStart, rmResizingEnd, rmPanning);

  TRangeSlider = class(TPanel)
  private
    FMinVal, FMaxVal: Int64;
    FStartIdx, FEndIdx: Int64;
    FMode: TRangeMode;
    FLastMouseX: Integer;
    FOnChange: TNotifyEvent;

    procedure SetMin(const AMin: Int64);
    procedure SetMax(const AMax: Int64);
    procedure SetRange(const AMin, AMax: Int64);
    procedure SetStartIdx(const AValue: Int64);
    procedure SetEndIdx(const AValue: Int64);
    function ValueToPos(AValue: Int64): Integer;
    function PosToValue(APos: Integer): Int64;
  protected
    procedure Paint; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
  public
    constructor Create(AOwner: TComponent); override;
    property MinVal: Int64 read FMinVal write SetMin;
    property MaxVal: Int64 read FMaxVal write SetMax;
    property StartIdx: Int64 read FStartIdx write SetStartIdx;
    property EndIdx: Int64 read FEndIdx write SetEndIdx;
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
  end;

implementation

{ TRangeSlider }

constructor TRangeSlider.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  DoubleBuffered := True;
  FMinVal := 0;
  FMaxVal := 2048;
  FStartIdx := 0;
  FEndIdx := 2048;
  FMode := rmNone;
end;

procedure TRangeSlider.SetMin(const AMin: Int64);
begin
  FMinVal := AMin;
  if FMaxVal < FMinVal then
    FMaxVal := FMinVal;
  Invalidate;
end;

procedure TRangeSlider.SetMax(const AMax: Int64);
begin
  FMaxVal := AMax;
  if FMinVal > FMaxVal then
    FMinVal := FMaxVal;
  Invalidate;
end;

procedure TRangeSlider.SetRange(const AMin, AMax: Int64);
begin
  FMinVal := AMin;
  FMaxVal := AMax;
  Invalidate;
end;

procedure TRangeSlider.SetStartIdx(const AValue: Int64);
begin
  FStartIdx := Max(FMinVal, Min(FEndIdx - 1, AValue));
  Invalidate;
end;

procedure TRangeSlider.SetEndIdx(const AValue: Int64);
begin
  FEndIdx := Min(FMaxVal, Max(FStartIdx + 1, AValue));
  Invalidate;
end;

function TRangeSlider.ValueToPos(AValue: Int64): Integer;
begin
  if FMaxVal = FMinVal then
    Result := ClientWidth
  else
    Result := Round((AValue - FMinVal) / (FMaxVal - FMinVal) * ClientWidth);
end;

function TRangeSlider.PosToValue(APos: Integer): Int64;
var
  Ratio: Double;
begin
  if ClientWidth = 0 then
    Result := FMinVal
  else
  begin
    Ratio := APos / ClientWidth;
    Result := FMinVal + Round(Ratio * (FMaxVal - FMinVal));
  end;
end;

procedure TRangeSlider.Paint;
var
  RStart, REnd: Integer;
  SColor, HColor: TColor;
begin
  // 1. Fond (la piste)
  Canvas.Brush.Color := clBtnFace;
  Canvas.FillRect(ClientRect);

  RStart := ValueToPos(FStartIdx) - 1;
  REnd := ValueToPos(FEndIdx) + 1;

  // 2. Dessiner la zone sélectionnée (la fenêtre)
  SColor := $00FFD700; // Or/Jaune pour la zone
  Canvas.Brush.Color := SColor;
  Canvas.FillRect(Rect(RStart, 0, REnd, ClientHeight));

  // 3. Dessiner les deux curseurs (Handles)
  HColor := clHighlight;
  Canvas.Brush.Color := HColor;
  Canvas.Pen.Color := clWhite;
  Canvas.Rectangle(RStart - 3, 0, RStart + 3, ClientHeight);
  Canvas.Rectangle(REnd - 3, 0, REnd + 3, ClientHeight);
end;

procedure TRangeSlider.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  RStart, REnd, aRStart, aREnd: Integer;
begin
  inherited MouseDown(Button, Shift, X, Y);
  if FStartIdx = FEndIdx then
    FEndIdx := FEndIdx + 1;
  RStart := ValueToPos(FStartIdx);
  REnd := ValueToPos(FEndIdx);
  aRStart := Abs(X - RStart);
  aREnd := Abs(X - REnd);

  // Déterminer si on clique sur un curseur ou sur la zone
  if (aRStart <= 3) or (aREnd <= 3) then
  begin
    if aRStart < aREnd then
      FMode := rmResizingStart
    else
      FMode := rmResizingEnd
  end
  else if (X > RStart) and (X < REnd) then
    FMode := rmPanning
  else
    FMode := rmNone;

  FLastMouseX := X;
  if FMode <> rmNone then
  begin
    // Capture := True;
    Invalidate;
  end;
end;

procedure TRangeSlider.MouseMove(Shift: TShiftState; X, Y: Integer);
var
  Delta: Integer;
  ValDelta: Int64;
begin
  if FMode = rmNone then
  begin
    inherited MouseMove(Shift, X, Y);
    Exit;
  end;

  Delta := X - FLastMouseX;
  FLastMouseX := X;

  // Calcul du déplacement en valeur brute
  ValDelta := Round((Delta / ClientWidth) * (FMaxVal - FMinVal));
  if ValDelta = 0 then
    Exit; // Évite un rafraîchissement inutile

  case FMode of
    rmResizingStart:
      StartIdx := StartIdx + ValDelta;
    rmResizingEnd:
      EndIdx := EndIdx + ValDelta;
    rmPanning:
      begin
        StartIdx := StartIdx + ValDelta;
        EndIdx := EndIdx + ValDelta;
      end;
  end;

  // Clamp les valeurs pour respecter les bornes
  if StartIdx < FMinVal then
    StartIdx := FMinVal;
  if EndIdx > FMaxVal then
    EndIdx := FMaxVal;
  if StartIdx >= EndIdx then
    StartIdx := EndIdx - 1;

  Invalidate;
  if Assigned(FOnChange) then
    FOnChange(Self);
end;

procedure TRangeSlider.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseUp(Button, Shift, X, Y);
  FMode := rmNone;
  // Capture := False;
end;

end.
