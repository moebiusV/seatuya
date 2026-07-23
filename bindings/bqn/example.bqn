# example.bqn — demonstrate libseatuya via BQN FFI (CBQN)
#
# Usage: dbqn example.bqn
# Set TUYA_DEVICE_ID, TUYA_LOCAL_KEY, TUYA_IP env vars before running.

⟨seatuya⟩ ← •Import "seatuya.bqn"

device_id ← {("TUYA_DEVICE_ID"•env) ? "0123456789abcdef01234567"}
local_key ← {("TUYA_LOCAL_KEY"•env) ? "0123456789abcdef"}
ip        ← {("TUYA_IP"•env)        ? "192.168.1.100"}
ver       ← {("TUYA_VERSION"•env)    ? "3.4"}

•Show "seatuya version: "∾seatuya.Version

dev ← seatuya.Create device_id ip local_key ver
{dev=@ ? •Show "ERROR: Could not create device handle" ⋄ •Exit 1 ; @}

•Show "Connected: "∾•Fmt seatuya.IsConnected dev

•Show "turn_on: "∾seatuya.TurnOn dev 1
•Show "status: "∾seatuya.Status dev
•Show "turn_off: "∾seatuya.TurnOff dev 1

seatuya.Destroy dev
•Show "Done."
