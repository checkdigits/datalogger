{
  ********************************************************************************

  Github - https://github.com/dliocode/datalogger

  ********************************************************************************

  MIT License

  Copyright (c) 2023 Danilo Lucas

  Permission is hereby granted, free of charge, to any person obtaining a copy
  of this software and associated documentation files (the "Software"), to deal
  in the Software without restriction, including without limitation the rights
  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
  copies of the Software, and to permit persons to whom the Software is
  furnished to do so, subject to the following conditions:

  The above copyright notice and this permission notice shall be included in all
  copies or substantial portions of the Software.

  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
  SOFTWARE.

  ********************************************************************************
}

unit DataLogger.Provider.Email;

interface

uses
  DataLogger.Provider, DataLogger.Types,
  IdSMTP, IdMessage,
  System.SysUtils, System.Classes, System.JSON;

type
  TProviderEmail = class(TDataLoggerProvider<TProviderEmail>)
  private
    FIdSMTP: TIdSMTP;
    FFromAddress: string;
    FToAddress: string;
    FSubject: string;
  protected
    procedure Save(const ACache: TArray<TLoggerItem>); override;
  public
    function IdSMTP(const AValue: TIdSMTP): TProviderEmail; overload;
    function FromAddress(const AValue: string): TProviderEmail;
    function ToAddress(const AValue: string): TProviderEmail;
    function Subject(const AValue: string): TProviderEmail;

    procedure LoadFromJSON(const AJSON: string); override;
    function ToJSON(const AFormat: Boolean = False): string; override;

    constructor Create;
  end;

implementation

{ TProviderEmail }

constructor TProviderEmail.Create;
begin
  inherited Create;

  IdSMTP(nil);
  FromAddress('');
  ToAddress('');
  Subject('');
end;

function TProviderEmail.IdSMTP(const AValue: TIdSMTP): TProviderEmail;
begin
  Result := Self;
  FIdSMTP := AValue;
end;

function TProviderEmail.FromAddress(const AValue: string): TProviderEmail;
begin
  Result := Self;
  FFromAddress := AValue;
end;

function TProviderEmail.ToAddress(const AValue: string): TProviderEmail;
begin
  Result := Self;
  FToAddress := AValue;
end;

function TProviderEmail.Subject(const AValue: string): TProviderEmail;
begin
  Result := Self;
  FSubject := AValue;
end;

procedure TProviderEmail.LoadFromJSON(const AJSON: string);
var
  LJO: TJSONObject;
begin
  if AJSON.Trim.IsEmpty then
    Exit;

  try
    LJO := TJSONObject.ParseJSONValue(AJSON) as TJSONObject;
  except
    on E: Exception do
      Exit;
  end;

  if not Assigned(LJO) then
    Exit;

  try
    FromAddress(LJO.GetValue<string>('from_address', FFromAddress));
    ToAddress(LJO.GetValue<string>('to_address', FToAddress));
    Subject(LJO.GetValue<string>('subject', FSubject));

    SetJSONInternal(LJO);
  finally
    LJO.Free;
  end;
end;

function TProviderEmail.ToJSON(const AFormat: Boolean): string;
var
  LJO: TJSONObject;
begin
  LJO := TJSONObject.Create;
  try
    LJO.AddPair('from_address', TJSONString.Create(FFromAddress));
    LJO.AddPair('to_address', TJSONString.Create(FToAddress));
    LJO.AddPair('subject', TJSONString.Create(FSubject));

    ToJSONInternal(LJO);

    Result := TLoggerJSON.Format(LJO, AFormat);
  finally
    LJO.Free;
  end;
end;

procedure TProviderEmail.Save(const ACache: TArray<TLoggerItem>);
var
  LIdMessage: TIdMessage;
  LToAddress: TArray<string>;
  LEmail: string;
  LRetriesCount: Integer;
  LItem: TLoggerItem;
  LLog: string;
  LString: TStringList;
begin
  if not Assigned(FIdSMTP) then
    raise EDataLoggerException.Create('IdSMTP not defined!');

  if (Length(ACache) = 0) then
    Exit;

  LIdMessage := TIdMessage.Create;
  try
    LIdMessage.From.Text := FFromAddress;

    LToAddress := FToAddress.Trim.Split([';']);
    for LEmail in LToAddress do
      LIdMessage.Recipients.Add.Text := LEmail.Trim;

    LIdMessage.Subject := FSubject;

    LString := TStringList.Create;
    try
      for LItem in ACache do
      begin
        if LItem.InternalItem.IsSlinebreak then
          Continue;

        LLog := TLoggerSerializeItem.AsString(FLogFormat, LItem, FFormatTimestamp, FIgnoreLogFormat, FIgnoreLogFormatSeparator, FIgnoreLogFormatIncludeKey, FIgnoreLogFormatIncludeKeySeparator);
        LString.Add(LLog);
      end;

      LIdMessage.Body.Text := LString.Text;
    finally
      LString.Free;
    end;

    LRetriesCount := 0;

    while True do
      try
        if (csDestroying in FIdSMTP.ComponentState) then
          Exit;

        if not FIdSMTP.Connected then
          FIdSMTP.Connect;

        FIdSMTP.Send(LIdMessage);

        Break;
      except
        on E: Exception do
        begin
          Inc(LRetriesCount);

          Sleep(50);

          if Assigned(FLogException) then
            FLogException(Self, LItem, E, LRetriesCount);

          if Self.Terminated then
            Exit;

          if (LRetriesCount <= 0) then
            Break;

          if (LRetriesCount >= FMaxRetries) then
            Break;
        end;
      end;

    try
      if FIdSMTP.Connected then
        FIdSMTP.Disconnect(False);
    except
    end;
  finally
    LIdMessage.Free;
  end;
end;

procedure ForceReferenceToClass(C: TClass);
begin
end;

initialization

ForceReferenceToClass(TProviderEmail);

end.
