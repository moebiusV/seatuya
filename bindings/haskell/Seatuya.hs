-- Seatuya.hs -- Haskell FFI bindings for libseatuya
--
-- Uses Foreign.Ptr, Foreign.C, and Foreign.Storable for C interop.
-- The opaque tuya_device_t* is wrapped in a ForeignPtr for GC safety.
-- Set SEATUYA_LIB to a custom library path, or use LD_LIBRARY_PATH.
--
-- Usage:
--   import Seatuya
--   dev <- create "id" "192.168.1.100" "key" "3.4"
--   turnOn dev 1 >>= putStrLn
--   destroy dev

{-# LANGUAGE ForeignFunctionInterface #-}
module Seatuya
    ( TuyaDevice
    , version, create, alloc, destroy
    , setCredentials, getDeviceId, getLocalKey, getIp
    , connect, disconnect, isConnected, reconnect
    , setRetryLimit, setRetryDelay, getRetryLimit, getRetryDelay
    , negotiateSession, negotiateSessionStart, negotiateSessionFinalize
    , getProtocol, getSessionState, getSocketState, getLastError
    , setAsyncMode, isSocketReadable, isSocketWritable, setSessionReady
    , buildMessage, decodeMessage, generatePayload, send, receive
    , setValueBool, setValueInt, setValueString, setValueFloat
    , turnOn, turnOff, status, heartbeat
    , setDevice22, isDevice22
    , setValue
    , Command(..), Protocol(..), SessionState(..), SocketState(..)
    , defaultPort, bufSize, defaultRetryLimit, defaultRetryDelay
    ) where

import Foreign
import Foreign.C.String
import Foreign.C.Types
import System.Environment (lookupEnv)
import Control.Monad (when)
import Data.Int (Int32)
import System.IO.Unsafe (unsafePerformIO)

-- ---------------------------------------------------------------------------
-- Device handle with automatic finalization
-- ---------------------------------------------------------------------------

data TuyaDevice = TuyaDevice (ForeignPtr ())

-- ---------------------------------------------------------------------------
-- Foreign imports (link-time)
-- ---------------------------------------------------------------------------

foreign import ccall "tuya_version"  c_version :: IO CString
foreign import ccall "tuya_create"   c_create  :: CString -> CString -> CString -> CString -> IO (Ptr ())
foreign import ccall "tuya_alloc"    c_alloc   :: CString -> IO (Ptr ())
foreign import ccall "tuya_destroy"  c_destroy :: Ptr () -> IO ()
foreign import ccall "&tuya_destroy" c_destroy_finalizer :: FunPtr (Ptr () -> IO ())

foreign import ccall "tuya_set_credentials" c_set_creds   :: Ptr () -> CString -> CString -> IO ()
foreign import ccall "tuya_get_device_id"   c_get_devid   :: Ptr () -> IO CString
foreign import ccall "tuya_get_local_key"   c_get_key     :: Ptr () -> IO CString
foreign import ccall "tuya_get_ip"          c_get_ip      :: Ptr () -> IO CString

foreign import ccall "tuya_connect"       c_connect       :: Ptr () -> CString -> IO CInt
foreign import ccall "tuya_disconnect"    c_disconnect    :: Ptr () -> IO ()
foreign import ccall "tuya_is_connected"  c_is_connected  :: Ptr () -> IO CInt
foreign import ccall "tuya_reconnect"     c_reconnect     :: Ptr () -> IO CInt

foreign import ccall "tuya_set_retry_limit" c_set_retry_limit :: Ptr () -> CInt -> IO ()
foreign import ccall "tuya_set_retry_delay" c_set_retry_delay :: Ptr () -> CInt -> IO ()
foreign import ccall "tuya_get_retry_limit" c_get_retry_limit :: Ptr () -> IO CInt
foreign import ccall "tuya_get_retry_delay" c_get_retry_delay :: Ptr () -> IO CInt

foreign import ccall "tuya_negotiate_session"         c_neg_sess   :: Ptr () -> CString -> IO CInt
foreign import ccall "tuya_negotiate_session_start"    c_neg_start  :: Ptr () -> CString -> IO CInt
foreign import ccall "tuya_negotiate_session_finalize" c_neg_final  :: Ptr () -> Ptr CChar -> CInt -> CString -> IO CInt

foreign import ccall "tuya_get_protocol"       c_get_proto    :: Ptr () -> IO CInt
foreign import ccall "tuya_get_session_state"  c_get_sess     :: Ptr () -> IO CInt
foreign import ccall "tuya_get_socket_state"   c_get_sock     :: Ptr () -> IO CInt
foreign import ccall "tuya_get_last_error"     c_get_err      :: Ptr () -> IO CInt

foreign import ccall "tuya_set_async_mode"       c_set_async  :: Ptr () -> CInt -> IO ()
foreign import ccall "tuya_is_socket_readable"   c_readable   :: Ptr () -> IO CInt
foreign import ccall "tuya_is_socket_writable"   c_writable   :: Ptr () -> IO CInt
foreign import ccall "tuya_set_session_ready"    c_set_ready  :: Ptr () -> IO CInt

foreign import ccall "tuya_build_message"    c_build :: Ptr () -> Ptr CChar -> CInt -> CString -> CString -> CInt
foreign import ccall "tuya_decode_message"   c_decode :: Ptr () -> Ptr CChar -> CInt -> CString -> IO CString
foreign import ccall "tuya_generate_payload" c_gen :: Ptr () -> CInt -> CString -> CString -> IO CString
foreign import ccall "tuya_send"    c_send    :: Ptr () -> Ptr CChar -> CInt -> IO CInt
foreign import ccall "tuya_receive" c_receive :: Ptr () -> Ptr CChar -> CInt -> CInt -> IO CInt

foreign import ccall "tuya_set_value_bool"   c_set_bool   :: Ptr () -> CInt -> CInt -> IO CString
foreign import ccall "tuya_set_value_int"    c_set_int    :: Ptr () -> CInt -> CInt -> IO CString
foreign import ccall "tuya_set_value_string" c_set_str    :: Ptr () -> CInt -> CString -> IO CString
foreign import ccall "tuya_set_value_float"  c_set_float  :: Ptr () -> CInt -> CDouble -> IO CString

foreign import ccall "tuya_turn_on"    c_turn_on    :: Ptr () -> CInt -> IO CString
foreign import ccall "tuya_turn_off"   c_turn_off   :: Ptr () -> CInt -> IO CString
foreign import ccall "tuya_status"     c_status     :: Ptr () -> IO CString
foreign import ccall "tuya_heartbeat"  c_heartbeat  :: Ptr () -> IO CString

foreign import ccall "tuya_free_string" c_free_str :: CString -> IO ()

foreign import ccall "tuya_set_device22" c_set_d22 :: Ptr () -> CString -> IO ()
foreign import ccall "tuya_is_device22"  c_is_d22  :: Ptr () -> IO CInt

-- ---------------------------------------------------------------------------
-- Constants
-- ---------------------------------------------------------------------------

-- | Tuya command types (43 values matching enum tuya_command).
data Command = CmdUDP | CmdApConfig | CmdActive | CmdBind | CmdRenameGw
             | CmdRenameDevice | CmdUnbind | CmdControl | CmdStatus
             | CmdHeartBeat | CmdDpQuery | CmdQueryWifi | CmdTokenBind
             | CmdControlNew | CmdEnableWifi | CmdDpQueryNew | CmdSceneExecute
             | CmdUpdateDps | CmdUdpNew | CmdApConfigNew | CmdGetLocalTime
             | CmdWeatherOpen | CmdWeatherData | CmdStateUploadSyn
             | CmdStateUploadSynRecv | CmdHeartBeatStop | CmdStreamTrans
             | CmdGetWifiStatus | CmdWifiConnectTest | CmdGetMac
             | CmdGetIrStatus | CmdIrTxRxTest | CmdLanGwActive
             | CmdLanSubDevRequest | CmdLanDeleteSubDev | CmdLanReportSubDev
             | CmdLanScene | CmdLanPublishCloudConfig | CmdLanPublishAppConfig
             | CmdLanExportAppConfig | CmdLanPublishScenePanel | CmdLanRemoveGw
             | CmdLanCheckGwUpdate | CmdLanGwUpdate | CmdLanSetGwChannel
             deriving (Show, Eq, Enum)

cmdVal :: Command -> CInt
cmdVal c = fromIntegral (fromEnum c)

cmdCtrl, cmdDpQuery, cmdHeartBeat, cmdStatus, cmdCtrlNew, cmdDpQueryNew :: CInt
cmdCtrl     = cmdVal CmdControl
cmdDpQuery  = cmdVal CmdDpQuery
cmdHeartBeat = cmdVal CmdHeartBeat
cmdStatus   = cmdVal CmdStatus
cmdCtrlNew  = cmdVal CmdControlNew
cmdDpQueryNew = cmdVal CmdDpQueryNew

-- | Protocol version.
data Protocol = ProtoV31 | ProtoV33 | ProtoV34 | ProtoV35
              deriving (Show, Eq, Enum)

protoFromInt :: CInt -> Protocol
protoFromInt 0 = ProtoV31; protoFromInt 1 = ProtoV33
protoFromInt 2 = ProtoV34; protoFromInt _ = ProtoV35

-- | Session state.
data SessionState = SessInvalid | SessStarting | SessFinalizing | SessEstablished
                  deriving (Show, Eq, Enum)

sessFromInt :: CInt -> SessionState
sessFromInt 0 = SessInvalid; sessFromInt 1 = SessStarting
sessFromInt 2 = SessFinalizing; sessFromInt _ = SessEstablished

-- | Socket state.
data SocketState = SockNoSuchHost | SockNoSockAvail | SockFailed
                 | SockDisconnected | SockConnecting | SockConnected
                 | SockReady | SockReceiving
                 deriving (Show, Eq, Enum)

sockFromInt :: CInt -> SocketState
sockFromInt 0 = SockNoSuchHost; sockFromInt 1 = SockNoSockAvail
sockFromInt 2 = SockFailed; sockFromInt 3 = SockDisconnected
sockFromInt 4 = SockConnecting; sockFromInt 5 = SockConnected
sockFromInt 6 = SockReady; sockFromInt _ = SockReceiving

defaultPort, bufSize, defaultRetryLimit, defaultRetryDelay :: Int
defaultPort = 6668
bufSize = 1024
defaultRetryLimit = 5
defaultRetryDelay = 100

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

toBool :: CInt -> Bool
toBool 0 = False; toBool _ = True

consume :: CString -> IO String
consume p = do
    s <- peekCString p
    c_free_str p
    return s

withDevice :: TuyaDevice -> (Ptr () -> IO a) -> IO a
withDevice (TuyaDevice fp) f = withForeignPtr fp f

-- ---------------------------------------------------------------------------
-- Public API -- Version
-- ---------------------------------------------------------------------------

version :: IO String
version = c_version >>= peekCString

-- ---------------------------------------------------------------------------
-- Lifecycle
-- ---------------------------------------------------------------------------

create :: String -> String -> String -> String -> IO (Maybe TuyaDevice)
create did addr key ver =
    withCString did  $ \cdid ->
    withCString addr $ \caddr ->
    withCString key  $ \ckey ->
    withCString ver  $ \cver  -> do
        p <- c_create cdid caddr ckey cver
        if p == nullPtr then return Nothing
        else Just <$> (TuyaDevice <$> newForeignPtr c_destroy_finalizer p)

alloc :: String -> IO (Maybe TuyaDevice)
alloc ver = withCString ver $ \cv -> do
    p <- c_alloc cv
    if p == nullPtr then return Nothing
    else Just <$> (TuyaDevice <$> newForeignPtr c_destroy_finalizer p)

destroy :: TuyaDevice -> IO ()
destroy (TuyaDevice fp) = withForeignPtr fp $ \p -> c_destroy p

-- ---------------------------------------------------------------------------
-- Credentials
-- ---------------------------------------------------------------------------

setCredentials :: TuyaDevice -> String -> String -> IO ()
setCredentials dev did key = withDevice dev $ \d ->
    withCString did $ \cd -> withCString key $ \ck -> c_set_creds d cd ck

getDeviceId :: TuyaDevice -> IO String
getDeviceId dev = withDevice dev $ \d -> c_get_devid d >>= peekCString

getLocalKey :: TuyaDevice -> IO String
getLocalKey dev = withDevice dev $ \d -> c_get_key d >>= peekCString

getIp :: TuyaDevice -> IO String
getIp dev = withDevice dev $ \d -> c_get_ip d >>= peekCString

-- ---------------------------------------------------------------------------
-- Connection
-- ---------------------------------------------------------------------------

connect :: TuyaDevice -> String -> IO Bool
connect dev host = withDevice dev $ \d ->
    withCString host $ fmap toBool . c_connect d

disconnect :: TuyaDevice -> IO ()
disconnect dev = withDevice dev c_disconnect

isConnected :: TuyaDevice -> IO Bool
isConnected dev = withDevice dev $ fmap toBool . c_is_connected

reconnect :: TuyaDevice -> IO Bool
reconnect dev = withDevice dev $ fmap toBool . c_reconnect

-- ---------------------------------------------------------------------------
-- Retry
-- ---------------------------------------------------------------------------

setRetryLimit :: TuyaDevice -> Int -> IO ()
setRetryLimit dev n = withDevice dev $ \d -> c_set_retry_limit d (fromIntegral n)

setRetryDelay :: TuyaDevice -> Int -> IO ()
setRetryDelay dev ms = withDevice dev $ \d -> c_set_retry_delay d (fromIntegral ms)

getRetryLimit :: TuyaDevice -> IO Int
getRetryLimit dev = withDevice dev $ fmap fromIntegral . c_get_retry_limit

getRetryDelay :: TuyaDevice -> IO Int
getRetryDelay dev = withDevice dev $ fmap fromIntegral . c_get_retry_delay

-- ---------------------------------------------------------------------------
-- Session negotiation
-- ---------------------------------------------------------------------------

negotiateSession :: TuyaDevice -> String -> IO Bool
negotiateSession dev key = withDevice dev $ \d ->
    withCString key $ fmap toBool . c_neg_sess d

negotiateSessionStart :: TuyaDevice -> String -> IO Bool
negotiateSessionStart dev key = withDevice dev $ \d ->
    withCString key $ fmap toBool . c_neg_start d

negotiateSessionFinalize :: TuyaDevice -> Ptr CChar -> Int -> String -> IO Bool
negotiateSessionFinalize dev buf sz key = withDevice dev $ \d ->
    withCString key $ \ck -> fmap toBool $ c_neg_final d buf (fromIntegral sz) ck

-- ---------------------------------------------------------------------------
-- State queries
-- ---------------------------------------------------------------------------

getProtocol :: TuyaDevice -> IO Protocol
getProtocol dev = withDevice dev $ fmap (protoFromInt . fromIntegral) . c_get_proto

getSessionState :: TuyaDevice -> IO SessionState
getSessionState dev = withDevice dev $ fmap (sessFromInt . fromIntegral) . c_get_sess

getSocketState :: TuyaDevice -> IO SocketState
getSocketState dev = withDevice dev $ fmap (sockFromInt . fromIntegral) . c_get_sock

getLastError :: TuyaDevice -> IO Int
getLastError dev = withDevice dev $ fmap fromIntegral . c_get_err

-- ---------------------------------------------------------------------------
-- Async mode
-- ---------------------------------------------------------------------------

setAsyncMode :: TuyaDevice -> Bool -> IO ()
setAsyncMode dev b = withDevice dev $ \d -> c_set_async d (if b then 1 else 0)

isSocketReadable :: TuyaDevice -> IO Bool
isSocketReadable dev = withDevice dev $ fmap toBool . c_readable

isSocketWritable :: TuyaDevice -> IO Bool
isSocketWritable dev = withDevice dev $ fmap toBool . c_writable

setSessionReady :: TuyaDevice -> IO Bool
setSessionReady dev = withDevice dev $ fmap toBool . c_set_ready

-- ---------------------------------------------------------------------------
-- Low-level message building and decoding
-- ---------------------------------------------------------------------------

buildMessage :: TuyaDevice -> CInt -> String -> String -> IO CInt
buildMessage dev cmd payload key = withDevice dev $ \d ->
    allocaBytes bufSize $ \buf ->
        withCString payload $ \cp ->
        withCString key $ \ck ->
            c_build d buf cmd cp ck

decodeMessage :: TuyaDevice -> Ptr CChar -> Int -> String -> IO (Maybe String)
decodeMessage dev buf sz key = withDevice dev $ \d ->
    withCString key $ \ck -> do
        ptr <- c_decode d buf (fromIntegral sz) ck
        if ptr == nullPtr then return Nothing
        else Just <$> consume ptr

generatePayload :: TuyaDevice -> CInt -> String -> String -> IO (Maybe String)
generatePayload dev cmd devId dps = withDevice dev $ \d ->
    withCString devId $ \cd ->
    withCString dps $ \cdps -> do
        ptr <- c_gen d cmd cd cdps
        if ptr == nullPtr then return Nothing
        else Just <$> consume ptr

send :: TuyaDevice -> Ptr CChar -> Int -> IO Int
send dev buf sz = withDevice dev $ \d ->
    fmap fromIntegral $ c_send d buf (fromIntegral sz)

receive :: TuyaDevice -> Ptr CChar -> Int -> Int -> IO Int
receive dev buf maxsz minsz = withDevice dev $ \d ->
    fmap fromIntegral $ c_receive d buf (fromIntegral maxsz) (fromIntegral minsz)

-- ---------------------------------------------------------------------------
-- High-level round-trip operations
-- ---------------------------------------------------------------------------

setValueBool :: TuyaDevice -> Int -> Bool -> IO String
setValueBool dev dp v = withDevice dev $ \d ->
    consume =<< c_set_bool d (fromIntegral dp) (if v then 1 else 0)

setValueInt :: TuyaDevice -> Int -> Int -> IO String
setValueInt dev dp v = withDevice dev $ \d ->
    consume =<< c_set_int d (fromIntegral dp) (fromIntegral v)

setValueString :: TuyaDevice -> Int -> String -> IO String
setValueString dev dp v = withDevice dev $ \d ->
    withCString v $ \cv -> consume =<< c_set_str d (fromIntegral dp) cv

setValueFloat :: TuyaDevice -> Int -> Double -> IO String
setValueFloat dev dp v = withDevice dev $ \d ->
    consume =<< c_set_float d (fromIntegral dp) (realToFrac v)

turnOn :: TuyaDevice -> Int -> IO String
turnOn dev dp = withDevice dev $ \d -> consume =<< c_turn_on d (fromIntegral dp)

turnOff :: TuyaDevice -> Int -> IO String
turnOff dev dp = withDevice dev $ \d -> consume =<< c_turn_off d (fromIntegral dp)

status :: TuyaDevice -> IO String
status dev = withDevice dev $ \d -> consume =<< c_status d

heartbeat :: TuyaDevice -> IO String
heartbeat dev = withDevice dev $ \d -> consume =<< c_heartbeat d

-- | Type-aware dispatcher: Bool, Int, Double, or String.
data SVal = SBool Bool | SInt Int | SFloat Double | SString String

setValue :: TuyaDevice -> Int -> SVal -> IO String
setValue dev dp (SBool   v) = setValueBool dev dp v
setValue dev dp (SInt    v) = setValueInt  dev dp v
setValue dev dp (SFloat  v) = setValueFloat dev dp v
setValue dev dp (SString v) = setValueString dev dp v

-- ---------------------------------------------------------------------------
-- Device22
-- ---------------------------------------------------------------------------

setDevice22 :: TuyaDevice -> Maybe String -> IO ()
setDevice22 dev Nothing  = withDevice dev $ \d -> c_set_d22 d nullPtr
setDevice22 dev (Just s) = withDevice dev $ \d ->
    withCString s $ c_set_d22 d

isDevice22 :: TuyaDevice -> IO Bool
isDevice22 dev = withDevice dev $ fmap toBool . c_is_d22
