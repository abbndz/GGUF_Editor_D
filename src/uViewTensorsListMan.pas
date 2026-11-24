unit uViewTensorsListMan;

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections, System.Contnrs, Vcl.CheckLst, Vcl.ComCtrls,
  Vcl.StdCtrls, uMath,uStrUtils, uGGUFModel, uGGMLTypes, uAppConfig;

procedure vtPopulateTensorList;
procedure vtUpdateFilterTypeItems;

function vtFindAndAutoSelectMatchingTensor2ByName(const ASourceId: Integer; const AName: AnsiString;
  const ACli: Integer): Boolean;
procedure vtEnforceSelectionLimit;
function vtGetLimitFromCombo: Integer;

procedure vtChListBoxTensorsClickCheck();

implementation

uses
  uEditTensors, uViewTensorsChart, uViewTensorsHisto, uEditTensorsView, uViewTensors;
// Pour GetFormatTensorNameList

procedure vtPopulateTensorList;
var
  i: Integer;
  T: TGGUFTensorInfo;
  FilterText, TName: string;
  ShowM1, ShowM2, ShowM3, ShowMS, ShowMOut: Boolean;
  MatchT: Boolean;
  AllTensors: TList;
begin
  FilterText := LowerCase(Trim(frmViewTensors.cbFilterV.Text));
  ShowM1 := (frmViewTensors.chkM1.Checked) and Assigned(frmViewTensors.FModel1);
  ShowM2 := (frmViewTensors.chkM2.Checked) and Assigned(frmViewTensors.FModel2);
  ShowM3 := (frmViewTensors.chkM3.Checked) and Assigned(frmViewTensors.FModel3);
  ShowMS := (frmViewTensors.chkMS.Checked) and Assigned(frmViewTensors.FModelS);
  ShowMOut := (frmViewTensors.chkMOut.Checked) and Assigned(frmViewTensors.FModelOut);

  frmViewTensors.FSelectionOrder.Clear;
  frmViewTensors.FSelOutTensor := nil;

  AllTensors := TList.Create;
  try
    // 1. Collecte de TOUS les tenseurs des modèles activés
    if ShowM1 then
      for i := 0 to frmViewTensors.FModel1.Tensors.Count - 1 do
        AllTensors.Add(frmViewTensors.FModel1.Tensors[i]);

    if ShowM2 then
      for i := 0 to frmViewTensors.FModel2.Tensors.Count - 1 do
        AllTensors.Add(frmViewTensors.FModel2.Tensors[i]);

    if ShowM3 then
      for i := 0 to frmViewTensors.FModel3.Tensors.Count - 1 do
        AllTensors.Add(frmViewTensors.FModel3.Tensors[i]);

    if ShowMS then
      for i := 0 to frmViewTensors.FModelS.Tensors.Count - 1 do
        AllTensors.Add(frmViewTensors.FModelS.Tensors[i]);

    if ShowMOut then
      for i := 0 to frmViewTensors.FModelOut.Tensors.Count - 1 do
      begin
        T := TGGUFTensorInfo(frmViewTensors.FModelOut.Tensors[i]);
        if T.IsConverted then
          AllTensors.Add(frmViewTensors.FModelOut.Tensors[i]);
      end;

    // TRI ALPHABÉTIQUE (A-Z)
    AllTensors.Sort(@CompareTensorsByName);
    frmViewTensors.FGlobalMaxElems := 0;

    // Affichage dans le CheckListBox
    frmViewTensors.ChListBoxTensors.Items.BeginUpdate;
    try
      frmViewTensors.ChListBoxTensors.Items.Clear;
      for i := 0 to AllTensors.Count - 1 do
      begin
        T := TGGUFTensorInfo(AllTensors[i]);
        // Mise à jour du Max pour le slider
        frmViewTensors.FGlobalMaxElems := Max(frmViewTensors.FGlobalMaxElems, T.TotElems);

        // Filtrage par texte
        TName := LowerCase(string(T.Name));
        MatchT := (frmViewTensors.cbFilterV.ItemIndex = 0) or (FilterText = '') or (Pos(FilterText, TName) > 0);

        if MatchT then
        begin
          // On ajoute l'objet au CheckListBox pour pouvoir le retrouver
          // On utilise GetFormatTensorNameList pour un affichage propre (ex: name[A]-Type-Size)
          frmViewTensors.ChListBoxTensors.Items.AddObject(GetFormatTensorNameList(T), T);
        end;
      end;
    finally
      frmViewTensors.ChListBoxTensors.Items.EndUpdate;
    end;
    frmViewTensors.UpdateUIFromQuantPreset(nil);
  finally
    AllTensors.Free;
  end;
end;

procedure vtUpdateFilterTypeItems;
var
  Patterns: TStringList;
  i, j: Integer;
  T: TGGUFTensorInfo;
  ModelS: array of TGGUFFile;
  sFiter: String;
begin
  Patterns := TStringList.Create;
  try
    Patterns.Sorted := true;
    Patterns.Duplicates := dupIgnore;
    sFiter := frmViewTensors.cbFilterV.Text;

    // On met les modèles dans un tableau pour boucler facilement
    SetLength(ModelS, 5);
    ModelS[0] := frmViewTensors.FModel1;
    ModelS[1] := frmViewTensors.FModel2;
    ModelS[2] := frmViewTensors.FModel3;
    ModelS[3] := frmViewTensors.FModelS;
    ModelS[4] := frmViewTensors.FModelOut;

    for i := 0 to 4 do
    begin
      if Assigned(ModelS[i]) then
      begin
        for j := 0 to ModelS[i].Tensors.Count - 1 do
        begin
          T := TGGUFTensorInfo(ModelS[i].Tensors[j]);
          if T.TensorPatternName <> '' then
            Patterns.Add(T.TensorPatternName);
        end;
      end;
    end;

    frmViewTensors.cbFilterV.OnChange := nil;
    try
      frmViewTensors.cbFilterV.Items.Clear;
      frmViewTensors.cbFilterV.Items.Add(''); // Tous
      frmViewTensors.cbFilterV.Items.AddStrings(Patterns);
      frmViewTensors.cbFilterV.Text := sFiter;
    finally
      frmViewTensors.cbFilterV.OnChange := frmViewTensors.cbFilterVChange;
    end;
  finally
    Patterns.Free;
  end;
end;

function vtGetLimitFromCombo: Integer;
begin
  Result := 1;
  if not Assigned(frmViewTensors) then
    Exit;
  cfg.sTensorsPerChart := Trim(frmViewTensors.cbNbrSelect.Text);
  cfg.iTensorsPerChart := ParseTensorsPerChart(cfg.sTensorsPerChart);
  if cfg.iTensorsPerChart < 1 then
    cfg.iTensorsPerChart := 1;
  Result := cfg.iTensorsPerChart;

end;

procedure vtEnforceSelectionLimit;
var
  i, Limit: Integer;
begin
  frmViewTensors.FUpdatingChecks := True;
  try
    Limit := Min(vtGetLimitFromCombo, SAFETY_MAX_TENSORS);
    if frmViewTensors.FSelectionOrder.Count > Limit then
    begin
      frmViewTensors.ChListBoxTensors.Items.BeginUpdate;
      try
        while frmViewTensors.FSelectionOrder.Count > Limit do
        begin
          i := frmViewTensors.FSelectionOrder[0];
          if (i >= 0) and (i < frmViewTensors.ChListBoxTensors.Count) then
            frmViewTensors.ChListBoxTensors.Checked[i] := False;

          frmViewTensors.FSelectionOrder.Delete(0);
        end;
      finally
        frmViewTensors.ChListBoxTensors.Items.EndUpdate;
      end;
    end;
  finally
    frmViewTensors.FUpdatingChecks := false;
  end;
end;

function vtFindAndAutoSelectMatchingTensor2ByName(const ASourceId: Integer; const AName: AnsiString;
  const ACli: Integer): Boolean;
var
  i, j, k, MatchIdx: Integer;
  T: TGGUFTensorInfo;
  ModelS: array [1 .. 5] of TGGUFFile;
begin
  // 1. Définir les modèles sources à parcourir
  ModelS[1] := frmViewTensors.FModel1;
  ModelS[2] := frmViewTensors.FModel2;
  ModelS[3] := frmViewTensors.FModel3;
  ModelS[4] := frmViewTensors.FModelS;
  ModelS[5] := frmViewTensors.FModelOut;
  Result := False;

  // 2. Chercher le premier tenseur homonyme dans un modèle différent
  for i := Low(ModelS) to High(ModelS) do
  begin
    if (i = ASourceId) or (ModelS[i] = nil) then
      Continue;
    for j := 0 to ModelS[i].Tensors.Count - 1 do
    begin
      T := TGGUFTensorInfo(ModelS[i].Tensors[j]);
      if T = nil then
        Continue;

      if SameText(String(T.Name), String(AName)) then
      begin
        // 3. Trouver son index dans la ChListBox
        MatchIdx := -1;
        for k := 0 to frmViewTensors.ChListBoxTensors.Count - 1 do
        begin
          if k = ACli then
            Continue;
          if Assigned(frmViewTensors.ChListBoxTensors.Items.Objects[k]) then
          begin
            if SameText(String(TGGUFTensorInfo(frmViewTensors.ChListBoxTensors.Items.Objects[k]).Name), String(AName)) then
            begin
              MatchIdx := k;
              Break;
            end;
          end;
        end;

        if MatchIdx <> -1 then
        begin
          // On coche l'élément visuellement
          if not frmViewTensors.ChListBoxTensors.Checked[MatchIdx] then
          begin
            frmViewTensors.ChListBoxTensors.Checked[MatchIdx] := true;
            frmViewTensors.FSelectionOrder.Add(MatchIdx);
            T := TGGUFTensorInfo(frmViewTensors.ChListBoxTensors.Items.Objects[MatchIdx]);
            if T.IsConverted then
              frmViewTensors.FSelOutTensor := T;
          end;
          Result := true;
        end;
        Exit; // Premier match trouvé, on arrête la recherche
      end;
    end;
  end;
end;

// LOGIQUE DE COCHAGE (CHECKBOX)
procedure vtChListBoxTensorsClickCheck();
var
  clickedIdx, i, refIdx, SourceId: Integer;
  newTensor, refTensor: TGGUFTensorInfo;
  isTwoByName: Boolean;
begin
  if frmViewTensors.FUpdatingChecks then
    Exit;
  clickedIdx := frmViewTensors.ChListBoxTensors.ItemIndex;
  if clickedIdx = -1 then
    Exit;
  if clickedIdx > frmViewTensors.ChListBoxTensors.Items.Count - 1 then
    Exit;
  if not Assigned(frmViewTensors.ChListBoxTensors.Items.Objects[clickedIdx]) then
    Exit;
  frmViewTensors.FUpdatingChecks := true;
  isTwoByName := SameText(cfg.sTensorsPerChart, '2:BYNAME') and (cfg.iTensorsPerChart = 2);
  frmViewTensors.FSelOutTensor := nil;

  frmViewTensors.ChListBoxTensors.Items.BeginUpdate;
  try
    // CAS 1 : L'utilisateur décoche un élément
    if not frmViewTensors.ChListBoxTensors.Checked[clickedIdx] then
    begin
      // DÉSÉLECTION
      i := frmViewTensors.FSelectionOrder.IndexOf(clickedIdx);
      if i <> -1 then
      begin
        if i = 0 then
        begin
          // On a décoché la Référence : l'autre (s'il existe) devient la nouvelle Référence
          if frmViewTensors.FSelectionOrder.Count > 1 then
          begin
            refIdx := frmViewTensors.FSelectionOrder[1];
            frmViewTensors.FSelectionOrder[0] := refIdx; // Décale en position 0
            frmViewTensors.FSelectionOrder.Delete(1); // Supprime l'ancienne position 1
          end
          else
          begin
            frmViewTensors.FSelectionOrder.Delete(0);
          end;
        end
        else
        begin
          // On a décoché le second tenseur (Match)
          frmViewTensors.FSelectionOrder.Delete(i);
        end;
      end;
    end
    else
    begin
      // CAS 2 : L'utilisateur coche un élément
      if not isTwoByName then
      begin
        if frmViewTensors.FSelectionOrder.Count >= cfg.iTensorsPerChart then
        begin
          // On retire le plus ancien pour respecter la limite
          i := frmViewTensors.FSelectionOrder[0];
          frmViewTensors.ChListBoxTensors.Checked[i] := False;
          frmViewTensors.FSelectionOrder.Delete(0);
        end;
        frmViewTensors.FSelectionOrder.Add(clickedIdx);
      end
      else
      begin
        // LOGIQUE SPÉCIALE 2:BYNAME
        if frmViewTensors.FSelectionOrder.Count = 0 then
        begin
          // 1ère sélection : devient la Référence (index 0)
          frmViewTensors.FSelectionOrder.Add(clickedIdx);
          if Assigned(frmViewTensors.ChListBoxTensors.Items.Objects[clickedIdx]) then
          begin
            newTensor := TGGUFTensorInfo(frmViewTensors.ChListBoxTensors.Items.Objects[clickedIdx]);
            SourceId := newTensor.SourceId;
            if newTensor.IsConverted then
            begin
              SourceId := SRC_MODELO;
              frmViewTensors.FSelOutTensor := newTensor;
            end;
            vtFindAndAutoSelectMatchingTensor2ByName(SourceId, newTensor.Name, clickedIdx);
          end;
        end
        else if frmViewTensors.FSelectionOrder.Count = 1 then
        begin
          // 2ème sélection : on a déjà une Référence
          newTensor := TGGUFTensorInfo(frmViewTensors.ChListBoxTensors.Items.Objects[clickedIdx]);
          refIdx := frmViewTensors.FSelectionOrder[0];
          refTensor := TGGUFTensorInfo(frmViewTensors.ChListBoxTensors.Items.Objects[refIdx]);
          if assigned(newTensor) and assigned(refTensor) then
          begin
            if SameText(String(newTensor.Name), String(refTensor.Name)) then
            begin
              // Même nom : devient le Match (index 1)
              frmViewTensors.FSelectionOrder.Add(clickedIdx);
            end
            else
            begin
              // Nom différent : remplace la Référence (index 0)
              frmViewTensors.ChListBoxTensors.Checked[refIdx] := False;
              frmViewTensors.FSelectionOrder[0] := clickedIdx;
              SourceId := newTensor.SourceId;
              if newTensor.IsConverted then
              begin
                SourceId := SRC_MODELO;
                frmViewTensors.FSelOutTensor := newTensor;
              end;
              vtFindAndAutoSelectMatchingTensor2ByName(SourceId, newTensor.Name, clickedIdx);
            end;
          end;
        end
        else if frmViewTensors.FSelectionOrder.Count >= 2 then
        begin
          // 3ème sélection : on a déjà une Référence et un Match
          newTensor := TGGUFTensorInfo(frmViewTensors.ChListBoxTensors.Items.Objects[clickedIdx]);
          refIdx := frmViewTensors.FSelectionOrder[0];
          refTensor := TGGUFTensorInfo(frmViewTensors.ChListBoxTensors.Items.Objects[refIdx]);
          if assigned(newTensor) and assigned(refTensor) then
          begin
            if SameText(String(newTensor.Name), String(refTensor.Name)) then
            begin
              // Même nom : remplace le Match actuel (index 1)
              frmViewTensors.ChListBoxTensors.Checked[frmViewTensors.FSelectionOrder[1]] := False;
              frmViewTensors.FSelectionOrder[1] := clickedIdx;
            end
            else
            begin
              // Nom différent : remplace la Référence (index 0) et supprime le Match
              frmViewTensors.FSelectionOrder.Clear;
              for i := 0 to frmViewTensors.ChListBoxTensors.Items.Count - 1 do
                if i <> clickedIdx then
                  frmViewTensors.ChListBoxTensors.Checked[i] := False;
              frmViewTensors.FSelectionOrder.Add(clickedIdx);
              SourceId := newTensor.SourceId;
              if newTensor.IsConverted then
              begin
                SourceId := SRC_MODELO;
                frmViewTensors.FSelOutTensor := newTensor;
              end;
              vtFindAndAutoSelectMatchingTensor2ByName(SourceId, newTensor.Name, clickedIdx);
            end;
          end;
        end;
      end;
    end;
  finally
    frmViewTensors.ChListBoxTensors.Items.EndUpdate;
    frmViewTensors.FUpdatingChecks := False;
  end;

  frmViewTensors.UpdateRmseControlsState;

  if frmViewTensors.PageControl1.ActivePage = frmViewTensors.TabHist then
    GenerateHistogram(False)
  else
    RefreshChart(frmViewTensors.chkXAxisAuto.Checked);
end;

end.
