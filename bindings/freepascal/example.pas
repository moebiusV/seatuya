{
  example.pas -- FreePascal example using libseatuya bindings.

  Compile:
    fpc -oseatuya_example example.pas

  Run:
    ./seatuya_example

  Environment variables: DEVICE_ID, DEVICE_IP, LOCAL_KEY, VERSION
}

program seatuya_example;

{$mode objfpc}{$H+}

uses
  Classes, SysUtils, seatuya;

var
  dev: PTuyaDevice;
  resp: PChar;
  dev_id, addr, key, ver: String;

begin
  dev_id := GetEnvironmentVariable('DEVICE_ID');
  if dev_id = '' then dev_id := '0123456789abcdef0123';

  addr := GetEnvironmentVariable('DEVICE_IP');
  if addr = '' then addr := '192.168.1.100';

  key := GetEnvironmentVariable('LOCAL_KEY');
  if key = '' then key := '0123456789abcdef';

  ver := GetEnvironmentVariable('VERSION');
  if ver = '' then ver := '3.3';

  WriteLn('seatuya version: ', StrPas(tuya_version));

  dev := tuya_create(PChar(dev_id), PChar(addr), PChar(key), PChar(ver));
  if dev = nil then begin
    WriteLn(StdErr, 'Failed to create device');
    Halt(1);
  end;
  WriteLn('Device created');

  { Turn on DP 1 }
  resp := tuya_turn_on(dev, 1);
  if resp <> nil then begin
    WriteLn('Turn ON response: ', StrPas(resp));
    tuya_free_string(resp);
  end else
    WriteLn('Turn ON failed');

  { Query status }
  resp := tuya_status(dev);
  if resp <> nil then begin
    WriteLn('Device status: ', StrPas(resp));
    tuya_free_string(resp);
  end else
    WriteLn('Status query failed');

  { Turn off DP 1 }
  resp := tuya_turn_off(dev, 1);
  if resp <> nil then begin
    WriteLn('Turn OFF response: ', StrPas(resp));
    tuya_free_string(resp);
  end else
    WriteLn('Turn OFF failed');

  tuya_destroy(dev);
  WriteLn('Device destroyed');
end.
