#!/usr/bin/env Rscript
#
# Example: create a Tuya device, turn DP 1 on, print status, turn off.
#
# Run:
#   Rscript example.R
#
# Environment variables: DEVICE_ID, DEVICE_IP, LOCAL_KEY, VERSION
#

source("seatuya.R")
seatuya.init()

dev_id <- Sys.getenv("DEVICE_ID",  unset = "0123456789abcdef0123")
addr   <- Sys.getenv("DEVICE_IP",  unset = "192.168.1.100")
key    <- Sys.getenv("LOCAL_KEY",  unset = "0123456789abcdef")
ver    <- Sys.getenv("VERSION",    unset = "3.3")

cat("seatuya version:", tuya_version(), "\n")

dev <- tuya_create(dev_id, addr, key, ver)
if (is.null(dev)) {
  stop("Failed to create device")
}
cat("Device created\n")

# Turn on DP 1
resp <- tuya_turn_on(dev, 1)
cat("Turn ON response:", resp, "\n")

# Query status
st <- tuya_status(dev)
cat("Device status:", st, "\n")

# Turn off DP 1
resp <- tuya_turn_off(dev, 1)
cat("Turn OFF response:", resp, "\n")

# Cleanup
tuya_destroy(dev)
cat("Device destroyed\n")
