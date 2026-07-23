// seatuya.v -- V FFI bindings for libseatuya.
//
// Uses V's built-in C interop.  Link with: v -cflags '-L/path/to/lib' program.v
// Set SEATUYA_LIB at build time for a custom library path.
//
// Usage:
//   import seatuya
//   dev := seatuya.create(device_id, ip, local_key, ver) or { panic(err) }
//   println(seatuya.turn_on(dev, 1) or { 'error' })
//   seatuya.destroy(dev)

module seatuya

// Link against libseatuya.  At build time you can override:
//   v -cflags '-L/usr/local/lib' -cflags '-lseatuya' program.v
#flag -l seatuya

// -- Type aliases --

// Opaque device handle
pub type Device = voidptr

// -- C function declarations --

fn C.tuya_version() &char

fn C.tuya_create(device_id &char, address &char, local_key &char, version &char) voidptr
fn C.tuya_alloc(version &char) voidptr
fn C.tuya_destroy(dev voidptr)

fn C.tuya_set_credentials(dev voidptr, device_id &char, local_key &char)
fn C.tuya_get_device_id(dev voidptr) &char
fn C.tuya_get_local_key(dev voidptr) &char
fn C.tuya_get_ip(dev voidptr) &char

fn C.tuya_connect(dev voidptr, hostname &char) bool
fn C.tuya_disconnect(dev voidptr)
fn C.tuya_is_connected(dev voidptr) bool
fn C.tuya_reconnect(dev voidptr) bool

fn C.tuya_set_retry_limit(dev voidptr, limit int)
fn C.tuya_set_retry_delay(dev voidptr, delay_ms int)
fn C.tuya_get_retry_limit(dev voidptr) int
fn C.tuya_get_retry_delay(dev voidptr) int

fn C.tuya_negotiate_session(dev voidptr, local_key &char) bool
fn C.tuya_negotiate_session_start(dev voidptr, local_key &char) bool
fn C.tuya_negotiate_session_finalize(dev voidptr, buf voidptr, size int, local_key &char) bool

fn C.tuya_get_protocol(dev voidptr) int
fn C.tuya_get_session_state(dev voidptr) int
fn C.tuya_get_socket_state(dev voidptr) int
fn C.tuya_get_last_error(dev voidptr) int

fn C.tuya_set_async_mode(dev voidptr, async bool)
fn C.tuya_is_socket_readable(dev voidptr) bool
fn C.tuya_is_socket_writable(dev voidptr) bool
fn C.tuya_set_session_ready(dev voidptr) bool

fn C.tuya_build_message(dev voidptr, buf voidptr, cmd int, payload &char, key &char) int
fn C.tuya_decode_message(dev voidptr, buf voidptr, size int, key &char) &char
fn C.tuya_generate_payload(dev voidptr, cmd int, device_id &char, datapoints &char) &char

fn C.tuya_send(dev voidptr, buf voidptr, size int) int
fn C.tuya_receive(dev voidptr, buf voidptr, maxsize int, minsize int) int

fn C.tuya_set_value_bool(dev voidptr, dp int, value bool) &char
fn C.tuya_set_value_int(dev voidptr, dp int, value int) &char
fn C.tuya_set_value_string(dev voidptr, dp int, value &char) &char
fn C.tuya_set_value_float(dev voidptr, dp int, value f64) &char

fn C.tuya_turn_on(dev voidptr, switch_dp int) &char
fn C.tuya_turn_off(dev voidptr, switch_dp int) &char
fn C.tuya_status(dev voidptr) &char
fn C.tuya_heartbeat(dev voidptr) &char

fn C.tuya_free_string(str &char)
fn C.tuya_set_device22(dev voidptr, null_dps_json &char)
fn C.tuya_is_device22(dev voidptr) bool

// -- Internal helpers --

// consume_cstr copies a malloc'd C string into a V string, then frees the C
// buffer.  Returns none if the pointer is null.
fn consume_cstr(ptr &char) ?string {
	if isnil(ptr) {
		return none
	}
	result := unsafe { string_from_c(ptr) }
	C.tuya_free_string(ptr)
	return result
}

// string_from_c wraps string construction from a C char pointer.
fn string_from_c(ptr &char) string {
	return string(ptr)
}

// -- Lifecycle --

[inline]
pub fn version() string {
	return string(C.tuya_version())
}

pub fn create(device_id string, address string, local_key string, version string) ?Device {
	ptr := C.tuya_create(device_id.str, address.str, local_key.str, version.str)
	if isnil(ptr) {
		return none
	}
	return ptr
}

pub fn alloc(version string) ?Device {
	ptr := C.tuya_alloc(version.str)
	if isnil(ptr) {
		return none
	}
	return ptr
}

pub fn destroy(dev Device) {
	C.tuya_destroy(dev)
}

// -- Credentials --

pub fn set_credentials(dev Device, device_id string, local_key string) {
	C.tuya_set_credentials(dev, device_id.str, local_key.str)
}

pub fn get_device_id(dev Device) string {
	ptr := C.tuya_get_device_id(dev)
	if isnil(ptr) {
		return ''
	}
	return string(ptr)
}

pub fn get_local_key(dev Device) string {
	ptr := C.tuya_get_local_key(dev)
	if isnil(ptr) {
		return ''
	}
	return string(ptr)
}

pub fn get_ip(dev Device) string {
	ptr := C.tuya_get_ip(dev)
	if isnil(ptr) {
		return ''
	}
	return string(ptr)
}

// -- Connection --

pub fn connect(dev Device, hostname string) bool {
	return C.tuya_connect(dev, hostname.str)
}

pub fn disconnect(dev Device) {
	C.tuya_disconnect(dev)
}

pub fn is_connected(dev Device) bool {
	return C.tuya_is_connected(dev)
}

pub fn reconnect(dev Device) bool {
	return C.tuya_reconnect(dev)
}

// -- Retry --

pub fn set_retry_limit(dev Device, limit int) {
	C.tuya_set_retry_limit(dev, limit)
}

pub fn set_retry_delay(dev Device, delay_ms int) {
	C.tuya_set_retry_delay(dev, delay_ms)
}

pub fn get_retry_limit(dev Device) int {
	return C.tuya_get_retry_limit(dev)
}

pub fn get_retry_delay(dev Device) int {
	return C.tuya_get_retry_delay(dev)
}

// -- Session negotiation --

pub fn negotiate_session(dev Device, local_key string) bool {
	return C.tuya_negotiate_session(dev, local_key.str)
}

pub fn negotiate_session_start(dev Device, local_key string) bool {
	return C.tuya_negotiate_session_start(dev, local_key.str)
}

pub fn negotiate_session_finalize(dev Device, buf &byte, size int, local_key string) bool {
	return C.tuya_negotiate_session_finalize(dev, buf, size, local_key.str)
}

// -- State queries --

pub fn get_protocol(dev Device) int {
	return C.tuya_get_protocol(dev)
}

pub fn get_session_state(dev Device) int {
	return C.tuya_get_session_state(dev)
}

pub fn get_socket_state(dev Device) int {
	return C.tuya_get_socket_state(dev)
}

pub fn get_last_error(dev Device) int {
	return C.tuya_get_last_error(dev)
}

// -- Async mode --

pub fn set_async_mode(dev Device, async bool) {
	C.tuya_set_async_mode(dev, async)
}

pub fn is_socket_readable(dev Device) bool {
	return C.tuya_is_socket_readable(dev)
}

pub fn is_socket_writable(dev Device) bool {
	return C.tuya_is_socket_writable(dev)
}

pub fn set_session_ready(dev Device) bool {
	return C.tuya_set_session_ready(dev)
}

// -- Low-level message operations --

pub fn build_message(dev Device, cmd int, payload string, key string) ?[]byte {
	mut buf := []byte{len: 1024}
	n := C.tuya_build_message(dev, buf.data, cmd, payload.str, key.str)
	if n <= 0 {
		return none
	}
	return buf[..n]
}

pub fn decode_message(dev Device, buf []byte, key string) ?string {
	ptr := C.tuya_decode_message(dev, buf.data, buf.len, key.str)
	return consume_cstr(ptr)
}

pub fn generate_payload(dev Device, cmd int, device_id string, datapoints string) ?string {
	ptr := C.tuya_generate_payload(dev, cmd, device_id.str, datapoints.str)
	return consume_cstr(ptr)
}

pub fn send_frame(dev Device, buf []byte) ?int {
	n := C.tuya_send(dev, buf.data, buf.len)
	if n < 0 {
		return none
	}
	return n
}

pub fn receive_frame(dev Device, maxsize int, minsize int) ?[]byte {
	if maxsize <= 0 {
		maxsize = 1024
	}
	mut buf := []byte{len: maxsize}
	n := C.tuya_receive(dev, buf.data, maxsize, minsize)
	if n <= 0 {
		return none
	}
	return buf[..n]
}

// -- Type-aware set-value dispatcher --

pub fn set_value_bool(dev Device, dp int, value bool) ?string {
	ptr := C.tuya_set_value_bool(dev, dp, value)
	return consume_cstr(ptr)
}

pub fn set_value_int(dev Device, dp int, value int) ?string {
	ptr := C.tuya_set_value_int(dev, dp, value)
	return consume_cstr(ptr)
}

pub fn set_value_string(dev Device, dp int, value string) ?string {
	ptr := C.tuya_set_value_string(dev, dp, value.str)
	return consume_cstr(ptr)
}

pub fn set_value_float(dev Device, dp int, value f64) ?string {
	ptr := C.tuya_set_value_float(dev, dp, value)
	return consume_cstr(ptr)
}

// -- High-level convenience --

pub fn turn_on(dev Device, switch_dp int) ?string {
	ptr := C.tuya_turn_on(dev, switch_dp)
	return consume_cstr(ptr)
}

pub fn turn_off(dev Device, switch_dp int) ?string {
	ptr := C.tuya_turn_off(dev, switch_dp)
	return consume_cstr(ptr)
}

pub fn status(dev Device) ?string {
	ptr := C.tuya_status(dev)
	return consume_cstr(ptr)
}

pub fn heartbeat(dev Device) ?string {
	ptr := C.tuya_heartbeat(dev)
	return consume_cstr(ptr)
}

// -- device22 --

pub fn set_device22(dev Device, null_dps_json string) {
	C.tuya_set_device22(dev, null_dps_json.str)
}

pub fn is_device22(dev Device) bool {
	return C.tuya_is_device22(dev)
}

// -- Constants --

pub const (
	Command = {
		'udp':                   0
		'ap_config':             1
		'active':                2
		'bind':                  3
		'rename_gw':             4
		'rename_device':         5
		'unbind':                6
		'control':               7
		'status':                8
		'heart_beat':            9
		'dp_query':              10
		'query_wifi':            11
		'token_bind':            12
		'control_new':           13
		'enable_wifi':           14
		'dp_query_new':          16
		'scene_execute':         17
		'updatedps':             18
		'udp_new':               19
		'ap_config_new':         20
		'get_local_time':        28
		'weather_open':          32
		'weather_data':          33
		'state_upload_syn':      34
		'state_upload_syn_recv': 35
		'heart_beat_stop':       37
		'stream_trans':          38
		'get_wifi_status':       43
		'wifi_connect_test':     44
		'get_mac':               45
		'get_ir_status':         46
		'ir_tx_rx_test':         47
		'lan_gw_active':         240
		'lan_sub_dev_request':   241
		'lan_delete_sub_dev':    242
		'lan_report_sub_dev':    243
		'lan_scene':             244
		'lan_publish_cloud_config': 245
		'lan_publish_app_config':   246
		'lan_export_app_config':    247
		'lan_publish_scene_panel':  248
		'lan_remove_gw':            249
		'lan_check_gw_update':      250
		'lan_gw_update':            251
		'lan_set_gw_channel':       252
	}
	Protocol   = map{'v31': 0, 'v33': 1, 'v34': 2, 'v35': 3}
	SessionState = map{
		'invalid':    0
		'starting':   1
		'finalizing': 2
		'established': 3
	}
	SocketState = map{
		'no_such_host':   0
		'no_sock_avail':  1
		'failed':         2
		'disconnected':   3
		'connecting':     4
		'connected':      5
		'ready':          6
		'receiving':      7
	}
	DEFAULT_PORT       = 6668
	BUFSIZE            = 1024
	DEFAULT_RETRY_LIMIT    = 5
	DEFAULT_RETRY_DELAY_MS = 100
)
