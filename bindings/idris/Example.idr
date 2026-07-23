||| Example.idr -- demonstrate libseatuya via Idris 2 FFI bindings
|||
||| Usage:
|||   idris2 -o example Example.idr
|||   LD_LIBRARY_PATH=/usr/local/lib ./build/exec/example

module Main

import Seatuya
import System
import System.Environment

partial
main : IO ()
main = do
  -- Read environment variables with defaults
  deviceId <- getDefault "TUYA_DEVICE_ID" "0123456789abcdef01234567"
  localKey <- getDefault "TUYA_LOCAL_KEY" "0123456789abcdef"
  ip       <- getDefault "TUYA_IP"        "192.168.1.100"
  ver      <- getDefault "TUYA_VERSION"    "3.4"

  -- Initialise library (needed only if SEATUYA_LIB is set)
  Seatuya.initLib

  putStrLn $ "seatuya version: " ++ tuyaVersion

  let dev = tuyaCreate deviceId ip localKey ver
  when (dev == prim__null) $ do
    putStrLn "ERROR: Could not create device handle"
    exit 1

  putStrLn $ "Connected: " ++ show (toBool (tuyaIsConnected dev))
  putStrLn $ "turn_on: "  ++ show (turnOn dev 1)
  putStrLn $ "status: "   ++ show (status dev)
  putStrLn $ "turn_off: " ++ show (turnOff dev 1)

  -- Type-aware dispatcher
  putStrLn $ "setValue(bool):   " ++ show (setValue dev 1 (TBool True))
  putStrLn $ "setValue(int):    " ++ show (setValue dev 2 (TInt 25))
  putStrLn $ "setValue(float):  " ++ show (setValue dev 3 (TFloat 23.5))
  putStrLn $ "setValue(string): " ++ show (setValue dev 4 (TString "hello"))

  tuyaDestroy dev
  putStrLn "Done."

||| Read an env var with a fallback default.
private
getDefault : String -> String -> IO String
getDefault name fallback = do
  mp <- lookupEnv name
  pure $ case mp of
    Nothing  => fallback
    Just val => val
