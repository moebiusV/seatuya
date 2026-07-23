import Seatuya
import System.Environment (lookupEnv)
import System.Exit (exitFailure)
import System.IO (hPutStrLn, stderr)

main :: IO ()
main = do
    did <- maybe "0123456789abcdef01234567" id <$> lookupEnv "TUYA_DEVICE_ID"
    key <- maybe "0123456789abcdef" id <$> lookupEnv "TUYA_LOCAL_KEY"
    ip  <- maybe "192.168.1.100" id <$> lookupEnv "TUYA_IP"
    ver <- maybe "3.4" id <$> lookupEnv "TUYA_VERSION"

    v <- version
    putStrLn $ "seatuya version: " ++ v

    mdev <- create did ip key ver
    case mdev of
        Nothing -> hPutStrLn stderr "ERROR: Could not create device handle" >> exitFailure
        Just dev -> do
            c <- isConnected dev
            putStrLn $ "Connected: " ++ show c
            r1 <- turnOn dev 1
            putStrLn $ "turn_on: " ++ r1
            r2 <- status dev
            putStrLn $ "status: " ++ r2
            r3 <- turnOff dev 1
            putStrLn $ "turn_off: " ++ r3

            -- Type-aware dispatcher
            _ <- setValue dev 1 (SBool True)
            _ <- setValue dev 2 (SInt 25)
            _ <- setValue dev 3 (SString "hello")
            _ <- setValue dev 4 (SFloat 23.5)

            destroy dev
            putStrLn "Done."
