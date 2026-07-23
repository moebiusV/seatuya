// seatuya.go — Go cgo bindings for libseatuya
//
// Go binding using cgo for direct C interop.  Requires libseatuya
// installed on the system.  The opaque pointer is wrapped as an
// unsafe.Pointer typed through the Device struct.
//
// Usage:
//   import "seatuya"
//   dev := seatuya.Create(deviceId, "192.168.1.100", localKey, "3.4")
//   defer dev.Destroy()
//   fmt.Println(dev.TurnOn(1))
//   fmt.Println(dev.Status())

package seatuya

/*
#cgo LDFLAGS: -lseatuya
#include <stdlib.h>
#include <seatuya/seatuya.h>
*/
import "C"
import (
	"fmt"
	"unsafe"
)

// ── Enums ──
type Command int
const (
	CmdUDP Command = iota
	CmdAPConfig
	CmdActive
	CmdBind
	CmdRenameGW
	CmdRenameDevice
	CmdUnbind
	CmdControl
	CmdStatus
	CmdHeartBeat
	CmdDPQuery
	CmdQueryWiFi
	CmdTokenBind
	CmdControlNew
	CmdEnableWiFi
	_ // 15 gap
	CmdDPQueryNew = 16
	CmdSceneExecute = 17
	CmdUpdateDPS = 18
	CmdUDPNew = 19
	CmdAPConfigNew = 20
	// ... gaps ...
	CmdGetLocalTime = 28
	CmdWeatherOpen = 32
	CmdWeatherData = 33
	CmdStateUploadSyn = 34
	CmdStateUploadSynRecv = 35
	CmdHeartBeatStop = 37
	CmdStreamTrans = 38
	CmdGetWiFiStatus = 43
	CmdWiFiConnectTest = 44
	CmdGetMAC = 45
	CmdGetIRStatus = 46
	CmdIRTXTest = 47
	CmdLanGWActive = 240
	CmdLanSubDevRequest = 241
	CmdLanDeleteSubDev = 242
	CmdLanReportSubDev = 243
	CmdLanScene = 244
	CmdLanPubCloudCfg = 245
	CmdLanPubAppCfg = 246
	CmdLanExportAppCfg = 247
	CmdLanPubScenePanel = 248
	CmdLanRemoveGW = 249
	CmdLanCheckGWUpdate = 250
	CmdLanGWUpdate = 251
	CmdLanSetGWChannel = 252
)

type Protocol int
const (
	ProtoV31 Protocol = iota
	ProtoV33
	ProtoV34
	ProtoV35
)

type SessionState int
const (
	SessionInvalid SessionState = iota
	SessionStarting
	SessionFinalizing
	SessionEstablished
)

type SocketState int
const (
	SockNoSuchHost SocketState = iota
	SockNoSockAvail
	SockFailed
	SockDisconnected
	SockConnecting
	SockConnected
	SockReady
	SockReceiving
)

// ── Constants ──
const (
	DefaultPort       = 6668
	Bufsize           = 1024
	DefaultRetryLimit = 5
	DefaultRetryDelay = 100
)

// ── Device handle ──
type Device struct {
	handle *C.tuya_device_t
}

// Version returns the library version string.
func Version() string {
	return C.GoString(C.tuya_version())
}

// Create allocates, connects, and negotiates a session in one call.
func Create(deviceID, address, localKey, version string) (*Device, error) {
	cID := C.CString(deviceID); defer C.free(unsafe.Pointer(cID))
	cAddr := C.CString(address); defer C.free(unsafe.Pointer(cAddr))
	cKey := C.CString(localKey); defer C.free(unsafe.Pointer(cKey))
	cVer := C.CString(version); defer C.free(unsafe.Pointer(cVer))

	h := C.tuya_create(cID, cAddr, cKey, cVer)
	if h == nil {
		return nil, fmt.Errorf("tuya_create failed")
	}
	return &Device{handle: h}, nil
}

// Destroy frees the device handle and all resources.
func (d *Device) Destroy() {
	if d.handle != nil {
		C.tuya_destroy(d.handle)
		d.handle = nil
	}
}

// ── Credentials ──
func (d *Device) SetCredentials(deviceID, localKey string) {
	cID := C.CString(deviceID); defer C.free(unsafe.Pointer(cID))
	cKey := C.CString(localKey); defer C.free(unsafe.Pointer(cKey))
	C.tuya_set_credentials(d.handle, cID, cKey)
}

func (d *Device) DeviceID() string {
	return C.GoString(C.tuya_get_device_id(d.handle))
}

func (d *Device) LocalKey() string {
	return C.GoString(C.tuya_get_local_key(d.handle))
}

func (d *Device) IP() string {
	return C.GoString(C.tuya_get_ip(d.handle))
}

// ── Connection ──
func (d *Device) Connect(hostname string) bool {
	cHost := C.CString(hostname); defer C.free(unsafe.Pointer(cHost))
	return bool(C.tuya_connect(d.handle, cHost))
}

func (d *Device) Disconnect() {
	C.tuya_disconnect(d.handle)
}

func (d *Device) IsConnected() bool {
	return bool(C.tuya_is_connected(d.handle))
}

func (d *Device) Reconnect() bool {
	return bool(C.tuya_reconnect(d.handle))
}

// ── Retry ──
func (d *Device) SetRetryLimit(limit int) {
	C.tuya_set_retry_limit(d.handle, C.int(limit))
}

func (d *Device) SetRetryDelay(ms int) {
	C.tuya_set_retry_delay(d.handle, C.int(ms))
}

func (d *Device) RetryLimit() int {
	return int(C.tuya_get_retry_limit(d.handle))
}

func (d *Device) RetryDelay() int {
	return int(C.tuya_get_retry_delay(d.handle))
}

// ── Session ──
func (d *Device) NegotiateSession(key string) bool {
	cKey := C.CString(key); defer C.free(unsafe.Pointer(cKey))
	return bool(C.tuya_negotiate_session(d.handle, cKey))
}

// ── State queries ──
func (d *Device) Protocol() Protocol {
	return Protocol(C.tuya_get_protocol(d.handle))
}

func (d *Device) SessionState() SessionState {
	return SessionState(C.tuya_get_session_state(d.handle))
}

func (d *Device) SocketState() SocketState {
	return SocketState(C.tuya_get_socket_state(d.handle))
}

func (d *Device) LastError() int {
	return int(C.tuya_get_last_error(d.handle))
}

// ── Async ──
func (d *Device) SetAsyncMode(flag bool) {
	C.tuya_set_async_mode(d.handle, C.bool(flag))
}

// ── High-level round-trip ──
func (d *Device) SetValueBool(dp int, value bool) string {
	return C.GoString(C.tuya_set_value_bool(d.handle, C.int(dp), C.bool(value)))
}

func (d *Device) SetValueInt(dp, value int) string {
	return C.GoString(C.tuya_set_value_int(d.handle, C.int(dp), C.int(value)))
}

func (d *Device) SetValueString(dp int, value string) string {
	cVal := C.CString(value); defer C.free(unsafe.Pointer(cVal))
	return C.GoString(C.tuya_set_value_string(d.handle, C.int(dp), cVal))
}

func (d *Device) SetValueFloat(dp int, value float64) string {
	return C.GoString(C.tuya_set_value_float(d.handle, C.int(dp), C.double(value)))
}

func (d *Device) SetValue(dp int, value interface{}) string {
	switch v := value.(type) {
	case bool:   return d.SetValueBool(dp, v)
	case int:    return d.SetValueInt(dp, v)
	case float64: return d.SetValueFloat(dp, v)
	case string:  return d.SetValueString(dp, v)
	default:     return d.SetValueString(dp, fmt.Sprint(v))
	}
}

func (d *Device) TurnOn(switchDp int) string {
	return C.GoString(C.tuya_turn_on(d.handle, C.int(switchDp)))
}

func (d *Device) TurnOff(switchDp int) string {
	return C.GoString(C.tuya_turn_off(d.handle, C.int(switchDp)))
}

func (d *Device) Status() string {
	return C.GoString(C.tuya_status(d.handle))
}

func (d *Device) Heartbeat() string {
	return C.GoString(C.tuya_heartbeat(d.handle))
}

// ── device22 ──
func (d *Device) SetDevice22(nullDPSJson string) {
	cJSON := C.CString(nullDPSJson); defer C.free(unsafe.Pointer(cJSON))
	C.tuya_set_device22(d.handle, cJSON)
}

func (d *Device) IsDevice22() bool {
	return bool(C.tuya_is_device22(d.handle))
}
