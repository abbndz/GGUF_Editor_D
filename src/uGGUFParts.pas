unit uGGUFParts;

interface

uses
  Classes, SysUtils, Contnrs, uBinIO, uGGUFModel, uGGUFTypes, uGGMLTypes;

type
  TSplitIndex = class
  public
    Count: Integer;
    FilesByNo: TStringList; // Keys=split.no, Values=FileName
    constructor Create;
    destructor Destroy; override;
  end;

function BuildAndVerifySplitIndex(const PartFiles: TStringList; out MasterFile: string): TSplitIndex;

implementation

uses uGGUFReader;

function GetPartFileName(const BName: string; PNo, PTotal: Integer): string;
begin
  Result := Format('%s-%0.5d-of-%0.5d.gguf', [BName, PNo, PTotal]);
end;

function KVGetInt64(M: TGGUFFile; const Key: AnsiString; Default: Int64 = -1): Int64;
var
  KV: TGGUFKeyValue;
begin
  Result := Default;
  KV := M.FindKV(Key);
  if not Assigned(KV) then
    Exit;
  case KV.Val.ValueType of
    gvt_UINT8:
      Result := KV.Val.VU8;
    gvt_INT8:
      Result := KV.Val.VI8;
    gvt_UINT16:
      Result := KV.Val.VU16;
    gvt_INT16:
      Result := KV.Val.VI16;
    gvt_UINT32:
      Result := KV.Val.VU32;
    gvt_INT32:
      Result := KV.Val.VI32;
    gvt_UINT64:
      Result := Int64(KV.Val.VU64);
    gvt_INT64:
      Result := KV.Val.VI64;
  end;
end;

constructor TSplitIndex.Create;
begin
  inherited Create;
  FilesByNo := TStringList.Create;
  FilesByNo.Duplicates := dupError;
  FilesByNo.CaseSensitive := True;
  Count := -1;
end;

destructor TSplitIndex.Destroy;
begin
  FilesByNo.Free;
  inherited;
end;

// Retourne les fichiers dans l'ordre d'entrée, sans validation
function BuildAndVerifySplitIndex(const PartFiles: TStringList; out MasterFile: string): TSplitIndex;
var
  i: Integer;
begin
  Result := TSplitIndex.Create;
  MasterFile := '';
  for i := 0 to PartFiles.Count - 1 do
  begin
    if FileExists(PartFiles[i]) then
    begin
      Result.FilesByNo.Values[IntToStr(i)] := PartFiles[i];
      if MasterFile = '' then
        MasterFile := PartFiles[i];
    end;
  end;
  if MasterFile = '' then
    Result.Count := 0
  else
    Result.Count := Result.FilesByNo.Count;
end;

end.

