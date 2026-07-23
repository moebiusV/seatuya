||| Seatuya.idr -- Idris 2 FFI bindings for libseatuya
|||
||| Pure Idris 2 binding using %foreign for C interop with the
||| Chez Scheme backend.
|||
||| Usage:
|||   import Seatuya
|||
|||   main : IO ()
|||   main = do
|||     dev <- tuyaCreate deviceId ip localKey ver
|||     case dev of
|||       Nothing => putStrLn "ERROR"
|||       Just d  => do turnOn d 1 >>= print
|||                     tuyaDestroy d
|||
||| Compile: idris2 -o example Example.idr

module Seatuya

import System.Environment

%default total

-- ==================================================================
--  Library loading
-- ==================================================================

||| Initialise the library binding.  Must be called before any other
||| function if the SEATUYA_LIB environment variable is set.
||| On Linux the default library name libseatuya.so is found
||| automatically; on macOS create a symlink or set SEATUYA_LIB.
export
initLib : IO ()
initLib = do
  mp <- lookupEnv "SEATUYA_LIB"
  case mp of
    Nothing     => pure ()
    Just path   => do loadLib path
                      pure ()

private
loadLib : String -> IO ()
loadLib path = do
  _ <- primIO (prim__dlopen path (rtldNow + rtldGlobal))
  pure ()

%foreign "C:dlopen,libc"
prim__dlopen : String -> Int -> Ptr

private
rtldNow : Int
rtldNow = 2

private
rtldGlobal : Int
rtldGlobal = 256

-- ==================================================================
--  Helper: consume a malloc'd C string
-- ==================================================================

||| Helper: copy a C string from a Ptr into an Idris String and free
||| the original allocation via tuya_free_string.
private
consumePtr : Ptr -> Maybe String
consumePtr ptr =
  if ptr == prim__null
  then Nothing
  else let s  = prim__getString ptr
           _  = tuya_free_string ptr
       in Just s

||| Null pointer constant.
private
prim__null : Ptr
prim__null = believe_me 0

-- ==================================================================
--  Version
-- ==================================================================

%foreign "C:tuya_version,libseatuya.so"
export
tuyaVersion : String

-- ==================================================================
--  Lifecycle
-- ==================================================================

%foreign "C:tuya_create,libseatuya.so"
export
tuyaCreate : String -> String -> String -> String -> Ptr

%foreign "C:tuya_alloc,libseatuya.so"
export
tuyaAlloc : String -> Ptr

%foreign "C:tuya_destroy,libseatuya.so"
export
tuyaDestroy : Ptr -> ()

-- ==================================================================
--  Credentials
-- ==================================================================

%foreign "C:tuya_set_credentials,libseatuya.so"
export
tuyaSetCredentials : Ptr -> String -> String -> ()

%foreign "C:tuya_get_device_id,libseatuya.so"
export
tuyaGetDeviceId : Ptr -> String

%foreign "C:tuya_get_local_key,libseatuya.so"
export
tuyaGetLocalKey : Ptr -> String

%foreign "C:tuya_get_ip,libseatuya.so"
export
tuyaGetIp : Ptr -> String

-- ==================================================================
--  Connection
-- ==================================================================

%foreign "C:tuya_connect,libseatuya.so"
export
tuyaConnect : Ptr -> String -> Int

%foreign "C:tuya_disconnect,libseatuya.so"
export
tuyaDisconnect : Ptr -> ()

%foreign "C:tuya_is_connected,libseatuya.so"
export
tuyaIsConnected : Ptr -> Int

%foreign "C:tuya_reconnect,libseatuya.so"
export
tuyaReconnect : Ptr -> Int

-- ==================================================================
--  Retry
-- ==================================================================

%foreign "C:tuya_set_retry_limit,libseatuya.so"
export
tuyaSetRetryLimit : Ptr -> Int -> ()

%foreign "C:tuya_set_retry_delay,libseatuya.so"
export
tuyaSetRetryDelay : Ptr -> Int -> ()

%foreign "C:tuya_get_retry_limit,libseatuya.so"
export
tuyaGetRetryLimit : Ptr -> Int

%foreign "C:tuya_get_retry_delay,libseatuya.so"
export
tuyaGetRetryDelay : Ptr -> Int

-- ==================================================================
--  Session negotiation
-- ==================================================================

%foreign "C:tuya_negotiate_session,libseatuya.so"
export
tuyaNegotiateSession : Ptr -> String -> Int

%foreign "C:tuya_negotiate_session_start,libseatuya.so"
export
tuyaNegotiateSessionStart : Ptr -> String -> Int

%foreign "C:tuya_negotiate_session_finalize,libseatuya.so"
export
tuyaNegotiateSessionFinalize : Ptr -> Ptr -> Int -> String -> Int

-- ==================================================================
--  State queries
-- ==================================================================

%foreign "C:tuya_get_protocol,libseatuya.so"
export
tuyaGetProtocol : Ptr -> Int

%foreign "C:tuya_get_session_state,libseatuya.so"
export
tuyaGetSessionState : Ptr -> Int

%foreign "C:tuya_get_socket_state,libseatuya.so"
export
tuyaGetSocketState : Ptr -> Int

%foreign "C:tuya_get_last_error,libseatuya.so"
export
tuyaGetLastError : Ptr -> Int

-- ==================================================================
--  Async mode
-- ==================================================================

%foreign "C:tuya_set_async_mode,libseatuya.so"
export
tuyaSetAsyncMode : Ptr -> Int -> ()

%foreign "C:tuya_is_socket_readable,libseatuya.so"
export
tuyaIsSocketReadable : Ptr -> Int

%foreign "C:tuya_is_socket_writable,libseatuya.so"
export
tuyaIsSocketWritable : Ptr -> Int

%foreign "C:tuya_set_session_ready,libseatuya.so"
export
tuyaSetSessionReady : Ptr -> Int

-- ==================================================================
--  Message building and decoding
-- ==================================================================

%foreign "C:tuya_build_message,libseatuya.so"
export
tuyaBuildMessage : Ptr -> Ptr -> Int -> String -> String -> Int

%foreign "C:tuya_decode_message,libseatuya.so"
export
tuyaDecodeMessage : Ptr -> Ptr -> Int -> String -> Ptr

%foreign "C:tuya_generate_payload,libseatuya.so"
export
tuyaGeneratePayload : Ptr -> Int -> String -> String -> Ptr

-- ==================================================================
--  Raw send/receive
-- ==================================================================

%foreign "C:tuya_send,libseatuya.so"
export
tuyaSend : Ptr -> Ptr -> Int -> Int

%foreign "C:tuya_receive,libseatuya.so"
export
tuyaReceive : Ptr -> Ptr -> Int -> Int -> Int

-- ==================================================================
--  device22 mode
-- ==================================================================

%foreign "C:tuya_set_device22,libseatuya.so"
export
tuyaSetDevice22 : Ptr -> String -> ()

%foreign "C:tuya_is_device22,libseatuya.so"
export
tuyaIsDevice22 : Ptr -> Int

-- ==================================================================
--  High-level round-trip operations
-- ==================================================================

%foreign "C:tuya_set_value_bool,libseatuya.so"
export
tuyaSetValueBool : Ptr -> Int -> Int -> Ptr

%foreign "C:tuya_set_value_int,libseatuya.so"
export
tuyaSetValueInt : Ptr -> Int -> Int -> Ptr

%foreign "C:tuya_set_value_string,libseatuya.so"
export
tuyaSetValueString : Ptr -> Int -> String -> Ptr

%foreign "C:tuya_set_value_float,libseatuya.so"
export
tuyaSetValueFloat : Ptr -> Int -> Double -> Ptr

%foreign "C:tuya_turn_on,libseatuya.so"
export
tuyaTurnOn : Ptr -> Int -> Ptr

%foreign "C:tuya_turn_off,libseatuya.so"
export
tuyaTurnOff : Ptr -> Int -> Ptr

%foreign "C:tuya_status,libseatuya.so"
export
tuyaStatus : Ptr -> Ptr

%foreign "C:tuya_heartbeat,libseatuya.so"
export
tuyaHeartbeat : Ptr -> Ptr

-- ==================================================================
--  Memory management
-- ==================================================================

%foreign "C:tuya_free_string,libseatuya.so"
export
tuya_free_string : Ptr -> ()

-- ==================================================================
--  Convenience: toBool, consumeStr
-- ==================================================================

||| Convert C int (0/1) to Bool.
export
toBool : Int -> Bool
toBool 0 = False
toBool _ = True

||| Consume a malloc'd response string from a high-level operation.
||| Returns Nothing on null pointer (error).
export
consumeResponse : Ptr -> Maybe String
consumeResponse = consumePtr

-- ==================================================================
--  Type-aware setValue dispatcher
-- ==================================================================

||| Tagged union for the setValue dispatcher.
export
data TuyaVal = TBool Bool | TInt Int | TFloat Double | TString String

||| Type-aware dispatcher for setting data point values.
export
setValue : Ptr -> Int -> TuyaVal -> Maybe String
setValue dev dp (TBool v)   = consumePtr (tuyaSetValueBool dev dp (if v then 1 else 0))
setValue dev dp (TInt v)    = consumePtr (tuyaSetValueInt dev dp v)
setValue dev dp (TFloat v)  = consumePtr (tuyaSetValueFloat dev dp v)
setValue dev dp (TString v) = consumePtr (tuyaSetValueString dev dp v)

||| Turn on a device DP.  Returns JSON response or Nothing on error.
export
turnOn : Ptr -> Int -> Maybe String
turnOn dev dp = consumePtr (tuyaTurnOn dev dp)

||| Turn off a device DP.  Returns JSON response or Nothing on error.
export
turnOff : Ptr -> Int -> Maybe String
turnOff dev dp = consumePtr (tuyaTurnOff dev dp)

||| Query device status.  Returns JSON or Nothing on error.
export
status : Ptr -> Maybe String
status dev = consumePtr (tuyaStatus dev)

||| Send heartbeat.  Returns JSON or Nothing on error.
export
heartbeat : Ptr -> Maybe String
heartbeat dev = consumePtr (tuyaHeartbeat dev)

-- ==================================================================
--  Constants
-- ==================================================================

||| Tuya command types (43 values).
export
cmdUDP                : Int; cmdUDP                = 0
export
cmdApConfig           : Int; cmdApConfig           = 1
export
cmdActive             : Int; cmdActive             = 2
export
cmdBind               : Int; cmdBind               = 3
export
cmdRenameGw           : Int; cmdRenameGw           = 4
export
cmdRenameDevice       : Int; cmdRenameDevice       = 5
export
cmdUnbind             : Int; cmdUnbind             = 6
export
cmdControl            : Int; cmdControl            = 7
export
cmdStatus             : Int; cmdStatus             = 8
export
cmdHeartBeat          : Int; cmdHeartBeat          = 9
export
cmdDpQuery            : Int; cmdDpQuery            = 10
export
cmdQueryWifi          : Int; cmdQueryWifi          = 11
export
cmdTokenBind          : Int; cmdTokenBind          = 12
export
cmdControlNew         : Int; cmdControlNew         = 13
export
cmdEnableWifi         : Int; cmdEnableWifi         = 14
export
cmdDpQueryNew         : Int; cmdDpQueryNew         = 16
export
cmdSceneExecute       : Int; cmdSceneExecute       = 17
export
cmdUpdatedps          : Int; cmdUpdatedps          = 18
export
cmdUdpNew             : Int; cmdUdpNew             = 19
export
cmdApConfigNew        : Int; cmdApConfigNew        = 20
export
cmdGetLocalTime       : Int; cmdGetLocalTime       = 28
export
cmdWeatherOpen        : Int; cmdWeatherOpen        = 32
export
cmdWeatherData        : Int; cmdWeatherData        = 33
export
cmdStateUploadSyn     : Int; cmdStateUploadSyn     = 34
export
cmdStateUploadSynRecv : Int; cmdStateUploadSynRecv = 35
export
cmdHeartBeatStop      : Int; cmdHeartBeatStop      = 37
export
cmdStreamTrans        : Int; cmdStreamTrans        = 38
export
cmdGetWifiStatus      : Int; cmdGetWifiStatus      = 43
export
cmdWifiConnectTest    : Int; cmdWifiConnectTest    = 44
export
cmdGetMac             : Int; cmdGetMac             = 45
export
cmdGetIrStatus        : Int; cmdGetIrStatus        = 46
export
cmdIrTxRxTest         : Int; cmdIrTxRxTest         = 47
export
cmdLanGwActive        : Int; cmdLanGwActive        = 240
export
cmdLanSubDevRequest   : Int; cmdLanSubDevRequest   = 241
export
cmdLanDeleteSubDev    : Int; cmdLanDeleteSubDev    = 242
export
cmdLanReportSubDev    : Int; cmdLanReportSubDev    = 243
export
cmdLanScene           : Int; cmdLanScene           = 244
export
cmdLanPublishCloudConfig : Int; cmdLanPublishCloudConfig = 245
export
cmdLanPublishAppConfig   : Int; cmdLanPublishAppConfig   = 246
export
cmdLanExportAppConfig    : Int; cmdLanExportAppConfig    = 247
export
cmdLanPublishScenePanel  : Int; cmdLanPublishScenePanel  = 248
export
cmdLanRemoveGw        : Int; cmdLanRemoveGw        = 249
export
cmdLanCheckGwUpdate   : Int; cmdLanCheckGwUpdate   = 250
export
cmdLanGwUpdate        : Int; cmdLanGwUpdate        = 251
export
cmdLanSetGwChannel    : Int; cmdLanSetGwChannel    = 252

||| Protocol versions.
export
protoV31 : Int; protoV31 = 0
export
protoV33 : Int; protoV33 = 1
export
protoV34 : Int; protoV34 = 2
export
protoV35 : Int; protoV35 = 3

||| Session states.
export
sessionInvalid    : Int; sessionInvalid    = 0
export
sessionStarting   : Int; sessionStarting   = 1
export
sessionFinalizing : Int; sessionFinalizing = 2
export
sessionEstablished : Int; sessionEstablished = 3

||| Socket states.
export
sockNoSuchHost  : Int; sockNoSuchHost  = 0
export
sockNoSockAvail : Int; sockNoSockAvail = 1
export
sockFailed      : Int; sockFailed      = 2
export
sockDisconnected : Int; sockDisconnected = 3
export
sockConnecting  : Int; sockConnecting  = 4
export
sockConnected   : Int; sockConnected   = 5
export
sockReady       : Int; sockReady       = 6
export
sockReceiving   : Int; sockReceiving   = 7

||| General.
export
defaultPort       : Int; defaultPort       = 6668
export
bufsize           : Int; bufsize           = 1024
export
defaultRetryLimit : Int; defaultRetryLimit = 5
export
defaultRetryDelay : Int; defaultRetryDelay = 100
