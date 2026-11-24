unit uSaveProgress;

interface

uses
  Windows, System.SysUtils, System.Math;

type
  TSaveCtx = record
    CurActive: Boolean;
    CurIdx: Integer;
    CurTot: Integer;
    CurName: string;
    CurStartTick: UInt64;
    CurSize: Int64;
    CurDone: Int64;
    LiveTick: UInt64;

    PartNo: Integer;
    PartTot: Integer;
    IsMetaPart: Boolean;

    LastGlobalBytes: Int64;
    LastPartBytes: Int64;
    LastLog: string;
  end;

type
  TProgressKind = (pkInfo, // message général
    pkHeader, // début de fichier cible
    pkTensorStart, // début d'un tenseur
    pkTensorProg, // progression dans le tenseur
    pkPartDone, // part (ou fichier unique) écrite
    pkDone, // job terminé
    pkCancelled // job annulé
    );

  TProgressInfo = record
    Kind: TProgressKind;
    Msg: string;

    TensorIdx: Integer; // 1-based
    TensorTotal: Integer;
    TensorBytesDone: Int64;
    TensorBytesTotal: Int64;

    GlobalBytesDone: Int64;
    GlobalBytesTotal: Int64;

    PartNo: Integer; // 1-based
    PartTot: Integer;
    IsMetaPart: Boolean;
    PartBytes: Int64;

    ElapsedMs: Int64;
    SourceFile: string; // fichier cible en cours d'écriture
  end;

  TOnSaveProgressEvent = reference to procedure(const Info: TProgressInfo);

function NewProgress(AKind: TProgressKind): TProgressInfo;
procedure FillProgressBase(var Info: TProgressInfo; APartNo, APartTot: Integer; AIsMetaPart: Boolean;
  AGlobalDone, AGlobalTotal: Int64; const ASourceFile: string);
function ElapsedSince(AStartTick: UInt64): Int64;

implementation

function NewProgress(AKind: TProgressKind): TProgressInfo;
begin
  Result := Default (TProgressInfo);
  Result.Kind := AKind;
end;

procedure FillProgressBase(var Info: TProgressInfo; APartNo, APartTot: Integer; AIsMetaPart: Boolean;
  AGlobalDone, AGlobalTotal: Int64; const ASourceFile: string);
begin
  Info.PartNo := APartNo;
  Info.PartTot := APartTot;
  Info.IsMetaPart := AIsMetaPart;
  Info.GlobalBytesDone := AGlobalDone;
  Info.GlobalBytesTotal := AGlobalTotal;
  Info.SourceFile := ASourceFile;
end;


function ElapsedSince(AStartTick: UInt64): Int64;
begin
  Result := Int64(GetTickCount64 - AStartTick);
end;

end.
