{
  *************************************
  Created by Danilo Lucas
  Github - https://github.com/dliocode
  *************************************
}

unit DataLogger.Provider.Events;

interface

uses
  DataLogger.Provider, DataLogger.Types,
  System.SysUtils;

type
  TLoggerItem = DataLogger.Types.TLoggerItem;

  TExecuteEvents = reference to procedure(const ALogFormat: string; const AItem: TLoggerItem; const AFormatTimestamp: string);

  TEventsConfig = class
  private
    FOnAny: TExecuteEvents;
    FOnTrace: TExecuteEvents;
    FOnDebug: TExecuteEvents;
    FOnInfo: TExecuteEvents;
    FOnSuccess: TExecuteEvents;
    FOnWarn: TExecuteEvents;
    FOnError: TExecuteEvents;
    FOnFatal: TExecuteEvents;
    procedure Init;
  public
    function OnAny(const AEvent: TExecuteEvents): TEventsConfig;
    function OnTrace(const AEvent: TExecuteEvents): TEventsConfig;
    function OnDebug(const AEvent: TExecuteEvents): TEventsConfig;
    function OnInfo(const AEvent: TExecuteEvents): TEventsConfig;
    function OnSuccess(const AEvent: TExecuteEvents): TEventsConfig;
    function OnWarn(const AEvent: TExecuteEvents): TEventsConfig;
    function OnError(const AEvent: TExecuteEvents): TEventsConfig;
    function OnFatal(const AEvent: TExecuteEvents): TEventsConfig;

    constructor Create;
    destructor Destroy; override;
  end;

  TProviderEvents = class(TDataLoggerProvider)
  private
    FConfig: TEventsConfig;
  protected
    procedure Save(const ACache: TArray<TLoggerItem>); override;
  public
    property Config: TEventsConfig read FConfig write FConfig;

    constructor Create(const AConfig: TEventsConfig);
    destructor Destroy; override;
  end;

implementation

{ TProviderEvents }

constructor TProviderEvents.Create(const AConfig: TEventsConfig);
begin
  inherited Create;
  FConfig := AConfig;
end;

destructor TProviderEvents.Destroy;
begin
  if Assigned(FConfig) then
    FConfig.Free;
  inherited;
end;

procedure TProviderEvents.Save(const ACache: TArray<TLoggerItem>);
  procedure _Execute(const AEvent: TExecuteEvents; const AItem: TLoggerItem);
  begin
    if Assigned(AEvent) then
      AEvent(FLogFormat, AItem, FFormatTimestamp);
  end;

var
  LRetryCount: Integer;
  LItem: TLoggerItem;
begin
  if not Assigned(FConfig) then
    raise EDataLoggerException.Create('Config not defined!');

  if Length(ACache) = 0 then
    Exit;

  for LItem in ACache do
  begin
    if LItem.&Type = TLoggerType.All then
      Continue;

    LRetryCount := 0;

    while True do
      try
        case LItem.&Type of
          TLoggerType.Trace:
            _Execute(FConfig.FOnTrace, LItem);
          TLoggerType.Debug:
            _Execute(FConfig.FOnDebug, LItem);
          TLoggerType.Info:
            _Execute(FConfig.FOnInfo, LItem);
          TLoggerType.Warn:
            _Execute(FConfig.FOnWarn, LItem);
          TLoggerType.Error:
            _Execute(FConfig.FOnError, LItem);
          TLoggerType.Success:
            _Execute(FConfig.FOnSuccess, LItem);
          TLoggerType.Fatal:
            _Execute(FConfig.FOnFatal, LItem);
        end;

        _Execute(FConfig.FOnAny, LItem);

        Break;
      except
        on E: Exception do
        begin
          Inc(LRetryCount);

          if Assigned(FLogException) then
            FLogException(Self, LItem, E, LRetryCount);

          if Self.Terminated then
            Exit;

          if LRetryCount >= FMaxRetry then
            Break;
        end;
      end
  end;
end;

{ TEventsConfig }

constructor TEventsConfig.Create;
begin
  Init;
end;

destructor TEventsConfig.Destroy;
begin
  Init;
  inherited;
end;

procedure TEventsConfig.Init;
begin
  FOnAny := nil;
  FOnTrace := nil;
  FOnDebug := nil;
  FOnInfo := nil;
  FOnWarn := nil;
  FOnError := nil;
  FOnSuccess := nil;
  FOnFatal := nil;
end;

function TEventsConfig.OnAny(const AEvent: TExecuteEvents): TEventsConfig;
begin
  Result := Self;
  FOnAny := AEvent;
end;

function TEventsConfig.OnTrace(const AEvent: TExecuteEvents): TEventsConfig;
begin
  Result := Self;
  FOnTrace := AEvent;
end;

function TEventsConfig.OnDebug(const AEvent: TExecuteEvents): TEventsConfig;
begin
  Result := Self;
  FOnDebug := AEvent;
end;

function TEventsConfig.OnInfo(const AEvent: TExecuteEvents): TEventsConfig;
begin
  Result := Self;
  FOnInfo := AEvent;
end;

function TEventsConfig.OnWarn(const AEvent: TExecuteEvents): TEventsConfig;
begin
  Result := Self;
  FOnWarn := AEvent;
end;

function TEventsConfig.OnError(const AEvent: TExecuteEvents): TEventsConfig;
begin
  Result := Self;
  FOnError := AEvent;
end;

function TEventsConfig.OnSuccess(const AEvent: TExecuteEvents): TEventsConfig;
begin
  Result := Self;
  FOnSuccess := AEvent;
end;

function TEventsConfig.OnFatal(const AEvent: TExecuteEvents): TEventsConfig;
begin
  Result := Self;
  FOnFatal := AEvent;
end;

end.
