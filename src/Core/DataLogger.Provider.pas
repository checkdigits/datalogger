{
  *************************************
  Created by Danilo Lucas
  Github - https://github.com/dliocode
  *************************************
}

unit DataLogger.Provider;

interface

uses
  DataLogger.Types,
  System.SysUtils, System.Classes, System.SyncObjs, System.Generics.Collections;

type
  TDataLoggerProvider = class(TThread)
  private
    FCriticalSection: TCriticalSection;
    FEvent: TEvent;
    FListLoggerBase: TList<TLoggerItem>;
    FListTransaction: TObjectDictionary<Integer, TList<TLoggerItem>>;
    FListLoggerItem: TList<TLoggerItem>;

    FLogLevel: TLoggerType;
    FDisableLogType: TLoggerTypes;
    FOnlyLogType: TLoggerTypes;

    FUseTransaction: Boolean;
    FAutoCommit: TLoggerTypes;
    FTypeAutoCommit: TLoggerTypeAutoCommit;
    FInTransaction: Boolean;
    FInitialMessage: string;
    FFinalMessage: string;

    function ExtractCache: TArray<TLoggerItem>;
  protected
    FLogFormat: string;
    FFormatTimestamp: string;
    FLogException: TOnLogException;
    FMaxRetry: Integer;

    procedure Execute; override;
    procedure Save(const ACache: TArray<TLoggerItem>); virtual; abstract;

    procedure Lock;
    procedure UnLock;
  public
    function SetLogFormat(const ALogFormat: string): TDataLoggerProvider;
    function SetFormatTimestamp(const AFormatTimestamp: string): TDataLoggerProvider;
    function SetLogLevel(const ALogLevel: TLoggerType): TDataLoggerProvider;
    function SetDisableLogType(const ALogTypes: TLoggerTypes): TDataLoggerProvider;
    function SetOnlyLogType(const ALogTypes: TLoggerTypes): TDataLoggerProvider;
    function SetLogException(const AException: TOnLogException): TDataLoggerProvider;
    function SetMaxRetry(const AMaxRetry: Integer): TDataLoggerProvider;
    function SetInitialMessage(const AMessage: string): TDataLoggerProvider;
    function SetFinalMessage(const AMessage: string): TDataLoggerProvider;

    function UseTransaction(const AUseTransaction: Boolean): TDataLoggerProvider;
    function AutoCommit(const ALogTypes: TLoggerTypes; const ATypeAutoCommit: TLoggerTypeAutoCommit = tcBlock): TDataLoggerProvider;
    function StartTransaction(const AUseLock: Boolean = True): TDataLoggerProvider;
    function CommitTransaction(const ATypeCommit: TLoggerTypeAutoCommit = tcBlock; const AUseLock: Boolean = True): TDataLoggerProvider;
    function RollbackTransaction(const ATypeCommit: TLoggerTypeAutoCommit = tcBlock): TDataLoggerProvider;
    function InTransaction: Boolean;
    function CountTransaction: Integer;

    function Clear: TDataLoggerProvider;
    function CountLogInCache: Int64;

    function AddCache(const AValues: TArray<TLoggerItem>): TDataLoggerProvider; overload;
    function AddCache(const AValue: TLoggerItem): TDataLoggerProvider; overload;
    function NotifyEvent: TDataLoggerProvider;

    constructor Create;
    procedure AfterConstruction; override; final;
    procedure BeforeDestruction; override; final;
  end;

implementation

{ TDataLoggerProvider }

constructor TDataLoggerProvider.Create;
begin
  inherited Create(True);
  FreeOnTerminate := False;
end;

procedure TDataLoggerProvider.AfterConstruction;
begin
  inherited;

  FCriticalSection := TCriticalSection.Create;
  FEvent := TEvent.Create;
  FListLoggerBase := TList<TLoggerItem>.Create;
  FListLoggerItem := FListLoggerBase;
  FListTransaction := TObjectDictionary < Integer, TList < TLoggerItem >>.Create([doOwnsValues]);

  FInTransaction := False;

  SetLogFormat(TLoggerFormat.DEFAULT_LOG_FORMAT);
  SetFormatTimestamp('yyyy-mm-dd hh:nn:ss:zzz');
  SetLogLevel(TLoggerType.All);
  SetDisableLogType([]);
  SetOnlyLogType([TLoggerType.All]);
  SetLogException(nil);
  SetMaxRetry(5);
  UseTransaction(False);
  AutoCommit([], tcBlock);

  Start;
end;

procedure TDataLoggerProvider.BeforeDestruction;
begin
  Terminate;
  FEvent.SetEvent;
  WaitFor;

  Lock;
  try
    FListTransaction.Free;
    FListLoggerBase.Free;
    FEvent.Free;
  finally
    UnLock;
  end;

  FCriticalSection.Free;

  inherited;
end;

procedure TDataLoggerProvider.Execute;
var
  LCache: TArray<TLoggerItem>;
begin
  while not Terminated do
  begin
    FEvent.WaitFor(INFINITE);
    FEvent.ResetEvent;

    LCache := ExtractCache;
    if Length(LCache) = 0 then
      Continue;

    Save(LCache);
  end;
end;

function TDataLoggerProvider.SetLogFormat(const ALogFormat: string): TDataLoggerProvider;
begin
  Result := Self;
  FLogFormat := ALogFormat;
end;

function TDataLoggerProvider.SetFormatTimestamp(const AFormatTimestamp: string): TDataLoggerProvider;
begin
  Result := Self;
  FFormatTimestamp := AFormatTimestamp;
end;

function TDataLoggerProvider.SetLogLevel(const ALogLevel: TLoggerType): TDataLoggerProvider;
begin
  Result := Self;
  FLogLevel := ALogLevel;
end;

function TDataLoggerProvider.SetDisableLogType(const ALogTypes: TLoggerTypes): TDataLoggerProvider;
begin
  Result := Self;
  FDisableLogType := ALogTypes;
end;

function TDataLoggerProvider.SetOnlyLogType(const ALogTypes: TLoggerTypes): TDataLoggerProvider;
begin
  Result := Self;
  FOnlyLogType := ALogTypes;
end;

function TDataLoggerProvider.SetLogException(const AException: TOnLogException): TDataLoggerProvider;
begin
  Result := Self;
  FLogException := AException;
end;

function TDataLoggerProvider.SetMaxRetry(const AMaxRetry: Integer): TDataLoggerProvider;
begin
  Result := Self;
  FMaxRetry := AMaxRetry;
end;

function TDataLoggerProvider.SetInitialMessage(const AMessage: string): TDataLoggerProvider;
begin
  Result := Self;
  FInitialMessage := AMessage;
end;

function TDataLoggerProvider.SetFinalMessage(const AMessage: string): TDataLoggerProvider;
begin
  Result := Self;
  FFinalMessage := AMessage;
end;

function TDataLoggerProvider.Clear: TDataLoggerProvider;
begin
  Result := Self;

  Lock;
  try
    FListLoggerItem.Clear;
    FListLoggerItem.TrimExcess;
  finally
    UnLock;
  end;
end;

function TDataLoggerProvider.UseTransaction(const AUseTransaction: Boolean): TDataLoggerProvider;
begin
  Result := Self;
  FUseTransaction := AUseTransaction;
end;

function TDataLoggerProvider.AutoCommit(const ALogTypes: TLoggerTypes; const ATypeAutoCommit: TLoggerTypeAutoCommit = tcBlock): TDataLoggerProvider;
begin
  Result := Self;
  FAutoCommit := ALogTypes;
  FTypeAutoCommit := ATypeAutoCommit;
end;

function TDataLoggerProvider.StartTransaction(const AUseLock: Boolean = True): TDataLoggerProvider;
var
  LCountTransaction: Integer;
begin
  Result := Self;

  if not FUseTransaction then
    Exit;

  if AUseLock then
    Lock;
  try
    LCountTransaction := FListTransaction.Count;

    if LCountTransaction = 0 then
      FInTransaction := True;

    FListLoggerItem := TList<TLoggerItem>.Create;
    FListTransaction.Add(LCountTransaction + 1, FListLoggerItem);
  finally
    if AUseLock then
      UnLock;
  end;
end;

function TDataLoggerProvider.CommitTransaction(const ATypeCommit: TLoggerTypeAutoCommit = tcBlock; const AUseLock: Boolean = True): TDataLoggerProvider;
var
  LCountTransaction: Integer;
  LCurrent: TList<TLoggerItem>;
  LCurrentValues: TArray<TLoggerItem>;
begin
  Result := Self;

  if not FUseTransaction then
    Exit;

  if AUseLock then
    Lock;
  try
    while True do
    begin
      LCountTransaction := FListTransaction.Count;

      if LCountTransaction = 0 then
        Exit;

      FListTransaction.TryGetValue(LCountTransaction, LCurrent);
      LCurrentValues := LCurrent.ToArray;

      if LCountTransaction > 1 then
      begin
        FListTransaction.TryGetValue(LCountTransaction - 1, FListLoggerItem);
        FListLoggerItem.AddRange(LCurrentValues);
      end;

      FListTransaction.Remove(LCountTransaction);

      if LCountTransaction = 1 then
      begin
        FListLoggerItem := FListLoggerBase;
        FListLoggerItem.AddRange(LCurrentValues);
        FEvent.SetEvent;

        FInTransaction := False;

        Break;
      end;

      if ATypeCommit = tcBlock then
        Break;
    end;
  finally
    if AUseLock then
      UnLock;
  end;
end;

function TDataLoggerProvider.RollbackTransaction(const ATypeCommit: TLoggerTypeAutoCommit = tcBlock): TDataLoggerProvider;
var
  LCountTransaction: Integer;
begin
  Result := Self;

  if not FUseTransaction then
    Exit;

  Lock;
  try
    while True do
    begin
      LCountTransaction := FListTransaction.Count;

      if LCountTransaction = 0 then
        Exit;

      if LCountTransaction > 1 then
        FListTransaction.TryGetValue(LCountTransaction - 1, FListLoggerItem);

      FListTransaction.Remove(LCountTransaction);

      if LCountTransaction = 1 then
      begin
        FListLoggerItem := FListLoggerBase;
        FEvent.SetEvent;

        FInTransaction := False;

        Break;
      end;

      if ATypeCommit = tcBlock then
        Break;
    end;
  finally
    UnLock;
  end;
end;

function TDataLoggerProvider.InTransaction: Boolean;
begin
  Lock;
  try
    Result := FInTransaction;
  finally
    UnLock;
  end;
end;

function TDataLoggerProvider.CountTransaction: Integer;
begin
  Lock;
  try
    Result := FListTransaction.Count;
  finally
    UnLock;
  end;
end;

function TDataLoggerProvider.CountLogInCache: Int64;
begin
  Lock;
  try
    Result := FListLoggerItem.Count;
  finally
    UnLock;
  end;
end;

function TDataLoggerProvider.NotifyEvent: TDataLoggerProvider;
begin
  Result := Self;

  Lock;
  try
    FEvent.SetEvent;
  finally
    UnLock;
  end;
end;

procedure TDataLoggerProvider.Lock;
begin
  FCriticalSection.Acquire;
end;

procedure TDataLoggerProvider.UnLock;
begin
  FCriticalSection.Release;
end;

function TDataLoggerProvider.AddCache(const AValues: TArray<TLoggerItem>): TDataLoggerProvider;
var
  I: Integer;
  LItem: TLoggerItem;
  LMessage: string;
begin
  Result := Self;

  Lock;
  try
    try
      for I := Low(AValues) to High(AValues) do
      begin
        LItem := AValues[I];

        if (TLoggerType.All in FDisableLogType) or (LItem.&Type in FDisableLogType) then
          Continue;

        if not(TLoggerType.All in FOnlyLogType) and not(LItem.&Type in FOnlyLogType) then
          Continue;

        if not(LItem.&Type in FOnlyLogType) then
          if Ord(FLogLevel) > Ord(LItem.&Type) then
            Continue;

        LMessage := LItem.Message;
        try
          if not FInitialMessage.Trim.IsEmpty then
            LMessage := FInitialMessage + LMessage;

          if not FFinalMessage.Trim.IsEmpty then
            LMessage := LMessage + FFinalMessage;
        finally
          LItem.Message := LMessage;
        end;

        FListLoggerItem.Add(LItem);

        if FUseTransaction and FInTransaction then
          if LItem.&Type in FAutoCommit then
          begin
            CommitTransaction(FTypeAutoCommit, False);
            StartTransaction(False);
          end;
      end;
    finally
      if not FUseTransaction or not FInTransaction then
        FEvent.SetEvent;
    end;
  finally
    UnLock;
  end;
end;

function TDataLoggerProvider.AddCache(const AValue: TLoggerItem): TDataLoggerProvider;
begin
  Result := AddCache([AValue]);
end;

function TDataLoggerProvider.ExtractCache: TArray<TLoggerItem>;
begin
  Lock;
  try
    Result := FListLoggerItem.ToArray;

    FListLoggerItem.Clear;
    FListLoggerItem.TrimExcess;
  finally
    UnLock;
  end;
end;

end.
