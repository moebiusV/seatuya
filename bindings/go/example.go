package main

import (
	"fmt"
	"os"
	seatuya "seatuya"
)

func main() {
	deviceID := envOr("TUYA_DEVICE_ID", "0123456789abcdef01234567")
	localKey := envOr("TUYA_LOCAL_KEY", "0123456789abcdef")
	ip       := envOr("TUYA_IP",        "192.168.1.100")
	ver      := envOr("TUYA_VERSION",    "3.4")

	fmt.Println("seatuya version:", seatuya.Version())

	dev, err := seatuya.Create(deviceID, ip, localKey, ver)
	if err != nil {
		fmt.Fprintln(os.Stderr, "ERROR:", err)
		os.Exit(1)
	}
	defer dev.Destroy()

	fmt.Println("Connected:", dev.IsConnected())
	fmt.Println("turn_on:", dev.TurnOn(1))
	fmt.Println("status:", dev.Status())
	fmt.Println("turn_off:", dev.TurnOff(1))
	fmt.Println("Done.")
}

func envOr(key, fallback string) string {
	if v, ok := os.LookupEnv(key); ok { return v }
	return fallback
}
