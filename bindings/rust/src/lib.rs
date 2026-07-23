// lib.rs — Rust FFI bindings for libseatuya
//
// Pure Rust binding using raw `extern "C"` declarations.  The opaque
// pointer is wrapped in a `Device` struct that owns the handle and
// drops it automatically.
//
// Usage:
//   use seatuya::Device;
//   let dev = Device::create(device_id, "192.168.1.100", local_key, "3.4")?;
//   println!("{}", dev.turn_on(1)?);
//   println!("{}", dev.status()?);

use std::ffi::{CStr, CString, NulError};
use std::fmt;
use std::os::raw::c_char;
use std::os::raw::c_int;
use std::os::raw::c_uchar;
use std::os::raw::c_void;
use std::ptr;

// ── Error type ──
#[derive(Debug)]
pub enum Error {
    Nul(NulError),
    Lib(String),
}

impl fmt::Display for Error {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        match self {
            Error::Nul(e) => write!(f, "nul byte in string: {}", e),
            Error::Lib(s) => write!(f, "{}", s),
        }
    }
}

impl From<NulError> for Error {
    fn from(e: NulError) -> Self { Error::Nul(e) }
}

impl std::error::Error for Error {}

type Result<T> = std::result::Result<T, Error>;

// ── Raw FFI declarations ──
extern "C" {
    fn tuya_version() -> *const c_char;
    fn tuya_create(device_id: *const c_char, address: *const c_char,
                   local_key: *const c_char, version: *const c_char) -> *mut c_void;
    fn tuya_alloc(version: *const c_char) -> *mut c_void;
    fn tuya_destroy(dev: *mut c_void);
    fn tuya_set_credentials(dev: *mut c_void, device_id: *const c_char, local_key: *const c_char);
    fn tuya_get_device_id(dev: *mut c_void) -> *const c_char;
    fn tuya_get_local_key(dev: *mut c_void) -> *const c_char;
    fn tuya_get_ip(dev: *mut c_void) -> *const c_char;
    fn tuya_connect(dev: *mut c_void, hostname: *const c_char) -> c_int;
    fn tuya_disconnect(dev: *mut c_void);
    fn tuya_is_connected(dev: *mut c_void) -> c_int;
    fn tuya_reconnect(dev: *mut c_void) -> c_int;
    fn tuya_set_retry_limit(dev: *mut c_void, limit: c_int);
    fn tuya_set_retry_delay(dev: *mut c_void, delay_ms: c_int);
    fn tuya_get_retry_limit(dev: *mut c_void) -> c_int;
    fn tuya_get_retry_delay(dev: *mut c_void) -> c_int;
    fn tuya_negotiate_session(dev: *mut c_void, key: *const c_char) -> c_int;
    fn tuya_negotiate_session_start(dev: *mut c_void, key: *const c_char) -> c_int;
    fn tuya_negotiate_session_finalize(dev: *mut c_void, buf: *mut c_uchar,
                                        size: c_int, key: *const c_char) -> c_int;
    fn tuya_get_protocol(dev: *mut c_void) -> c_int;
    fn tuya_get_session_state(dev: *mut c_void) -> c_int;
    fn tuya_get_socket_state(dev: *mut c_void) -> c_int;
    fn tuya_get_last_error(dev: *mut c_void) -> c_int;
    fn tuya_set_async_mode(dev: *mut c_void, flag: c_int);
    fn tuya_is_socket_readable(dev: *mut c_void) -> c_int;
    fn tuya_is_socket_writable(dev: *mut c_void) -> c_int;
    fn tuya_set_session_ready(dev: *mut c_void) -> c_int;
    fn tuya_build_message(dev: *mut c_void, buf: *mut c_uchar, cmd: c_int,
                           payload: *const c_char, key: *const c_char) -> c_int;
    fn tuya_decode_message(dev: *mut c_void, buf: *mut c_uchar, size: c_int,
                            key: *const c_char) -> *mut c_char;
    fn tuya_generate_payload(dev: *mut c_void, cmd: c_int,
                              device_id: *const c_char, datapoints: *const c_char) -> *mut c_char;
    fn tuya_send(dev: *mut c_void, buf: *mut c_uchar, size: c_int) -> c_int;
    fn tuya_receive(dev: *mut c_void, buf: *mut c_uchar, maxsize: c_int, minsize: c_int) -> c_int;
    fn tuya_set_value_bool(dev: *mut c_void, dp: c_int, value: c_int) -> *mut c_char;
    fn tuya_set_value_int(dev: *mut c_void, dp: c_int, value: c_int) -> *mut c_char;
    fn tuya_set_value_string(dev: *mut c_void, dp: c_int, value: *const c_char) -> *mut c_char;
    fn tuya_set_value_float(dev: *mut c_void, dp: c_int, value: f64) -> *mut c_char;
    fn tuya_turn_on(dev: *mut c_void, switch_dp: c_int) -> *mut c_char;
    fn tuya_turn_off(dev: *mut c_void, switch_dp: c_int) -> *mut c_char;
    fn tuya_status(dev: *mut c_void) -> *mut c_char;
    fn tuya_heartbeat(dev: *mut c_void) -> *mut c_char;
    fn tuya_free_string(str: *mut c_char);
    fn tuya_set_device22(dev: *mut c_void, null_dps_json: *const c_char);
    fn tuya_is_device22(dev: *mut c_void) -> c_int;
}

// ── Helpers ──
fn to_bool(v: c_int) -> bool { v != 0 }

unsafe fn consume_str(ptr: *mut c_char) -> Option<String> {
    if ptr.is_null() { return None; }
    let s = CStr::from_ptr(ptr).to_string_lossy().into_owned();
    tuya_free_string(ptr);
    Some(s)
}

unsafe fn to_str(ptr: *const c_char) -> Option<String> {
    if ptr.is_null() { return None; }
    Some(CStr::from_ptr(ptr).to_string_lossy().into_owned())
}

// ── Constants ──
pub const DEFAULT_PORT: i32 = 6668;
pub const BUFSIZE: usize = 1024;
pub const DEFAULT_RETRY_LIMIT: i32 = 5;
pub const DEFAULT_RETRY_DELAY: i32 = 100;

#[repr(i32)]
pub enum Command { Udp = 0, ApConfig = 1, Active = 2, Bind = 3, RenameGw = 4,
    RenameDevice = 5, Unbind = 6, Control = 7, Status = 8, HeartBeat = 9,
    DpQuery = 10, QueryWifi = 11, TokenBind = 12, ControlNew = 13,
    EnableWifi = 14, DpQueryNew = 16, SceneExecute = 17, UpdateDps = 18,
    UdpNew = 19, ApConfigNew = 20, GetLocalTime = 28, WeatherOpen = 32,
    WeatherData = 33, StateUploadSyn = 34, StateUploadSynRecv = 35,
    HeartBeatStop = 37, StreamTrans = 38, GetWifiStatus = 43,
    WifiConnectTest = 44, GetMac = 45, GetIrStatus = 46, IrTxRxTest = 47,
    LanGwActive = 240, LanSubDevRequest = 241, LanDeleteSubDev = 242,
    LanReportSubDev = 243, LanScene = 244, LanPubCloudCfg = 245,
    LanPubAppCfg = 246, LanExportAppCfg = 247, LanPubScenePanel = 248,
    LanRemoveGw = 249, LanCheckGwUpdate = 250, LanGwUpdate = 251,
    LanSetGwChannel = 252 }

#[repr(i32)]
pub enum Protocol { V31 = 0, V33 = 1, V34 = 2, V35 = 3 }

#[repr(i32)]
pub enum SessionState { Invalid = 0, Starting = 1, Finalizing = 2, Established = 3 }

#[repr(i32)]
pub enum SocketState { NoSuchHost = 0, NoSockAvail = 1, Failed = 2, Disconnected = 3,
    Connecting = 4, Connected = 5, Ready = 6, Receiving = 7 }

// ── Device handle ──
pub struct Device {
    handle: *mut c_void,
}

impl Device {
    pub fn version() -> String {
        unsafe { CStr::from_ptr(tuya_version()).to_string_lossy().into_owned() }
    }

    pub fn create(device_id: &str, address: &str, local_key: &str, version: &str) -> Result<Self> {
        let c_id = CString::new(device_id)?;
        let c_addr = CString::new(address)?;
        let c_key = CString::new(local_key)?;
        let c_ver = CString::new(version)?;
        let handle = unsafe {
            tuya_create(c_id.as_ptr(), c_addr.as_ptr(), c_key.as_ptr(), c_ver.as_ptr())
        };
        if handle.is_null() {
            return Err(Error::Lib("tuya_create failed".into()));
        }
        Ok(Device { handle })
    }

    pub fn alloc(version: &str) -> Result<Self> {
        let c_ver = CString::new(version)?;
        let handle = unsafe { tuya_alloc(c_ver.as_ptr()) };
        if handle.is_null() {
            return Err(Error::Lib("tuya_alloc failed".into()));
        }
        Ok(Device { handle })
    }

    pub fn set_credentials(&self, device_id: &str, local_key: &str) -> Result<()> {
        let c_id = CString::new(device_id)?;
        let c_key = CString::new(local_key)?;
        unsafe { tuya_set_credentials(self.handle, c_id.as_ptr(), c_key.as_ptr()); }
        Ok(())
    }

    pub fn device_id(&self) -> Option<String> { unsafe { to_str(tuya_get_device_id(self.handle)) } }
    pub fn local_key(&self) -> Option<String> { unsafe { to_str(tuya_get_local_key(self.handle)) } }
    pub fn ip(&self) -> Option<String> { unsafe { to_str(tuya_get_ip(self.handle)) } }

    pub fn connect(&self, hostname: &str) -> Result<bool> {
        let c_host = CString::new(hostname)?;
        Ok(unsafe { to_bool(tuya_connect(self.handle, c_host.as_ptr())) })
    }

    pub fn disconnect(&self) { unsafe { tuya_disconnect(self.handle); } }
    pub fn is_connected(&self) -> bool { unsafe { to_bool(tuya_is_connected(self.handle)) } }
    pub fn reconnect(&self) -> bool { unsafe { to_bool(tuya_reconnect(self.handle)) } }

    pub fn set_retry_limit(&self, limit: i32) { unsafe { tuya_set_retry_limit(self.handle, limit); } }
    pub fn set_retry_delay(&self, ms: i32) { unsafe { tuya_set_retry_delay(self.handle, ms); } }
    pub fn retry_limit(&self) -> i32 { unsafe { tuya_get_retry_limit(self.handle) } }
    pub fn retry_delay(&self) -> i32 { unsafe { tuya_get_retry_delay(self.handle) } }

    pub fn negotiate_session(&self, key: &str) -> Result<bool> {
        let c_key = CString::new(key)?;
        Ok(unsafe { to_bool(tuya_negotiate_session(self.handle, c_key.as_ptr())) })
    }

    pub fn protocol(&self) -> Protocol { unsafe { std::mem::transmute(tuya_get_protocol(self.handle)) } }
    pub fn session_state(&self) -> SessionState { unsafe { std::mem::transmute(tuya_get_session_state(self.handle)) } }
    pub fn socket_state(&self) -> SocketState { unsafe { std::mem::transmute(tuya_get_socket_state(self.handle)) } }
    pub fn last_error(&self) -> i32 { unsafe { tuya_get_last_error(self.handle) } }
    pub fn set_async_mode(&self, flag: bool) { unsafe { tuya_set_async_mode(self.handle, flag as c_int); } }

    // High-level round-trip
    pub fn set_value_bool(&self, dp: i32, value: bool) -> Option<String> {
        unsafe { consume_str(tuya_set_value_bool(self.handle, dp, value as c_int)) }
    }

    pub fn set_value_int(&self, dp: i32, value: i32) -> Option<String> {
        unsafe { consume_str(tuya_set_value_int(self.handle, dp, value)) }
    }

    pub fn set_value_string(&self, dp: i32, value: &str) -> Option<String> {
        let c_val = CString::new(value).ok()?;
        unsafe { consume_str(tuya_set_value_string(self.handle, dp, c_val.as_ptr())) }
    }

    pub fn set_value_float(&self, dp: i32, value: f64) -> Option<String> {
        unsafe { consume_str(tuya_set_value_float(self.handle, dp, value)) }
    }

    pub fn turn_on(&self, switch_dp: i32) -> Option<String> {
        unsafe { consume_str(tuya_turn_on(self.handle, switch_dp)) }
    }

    pub fn turn_off(&self, switch_dp: i32) -> Option<String> {
        unsafe { consume_str(tuya_turn_off(self.handle, switch_dp)) }
    }

    pub fn status(&self) -> Option<String> {
        unsafe { consume_str(tuya_status(self.handle)) }
    }

    pub fn heartbeat(&self) -> Option<String> {
        unsafe { consume_str(tuya_heartbeat(self.handle)) }
    }

    pub fn set_device22(&self, null_dps_json: &str) -> Result<()> {
        let c_json = CString::new(null_dps_json)?;
        unsafe { tuya_set_device22(self.handle, c_json.as_ptr()); }
        Ok(())
    }

    pub fn is_device22(&self) -> bool {
        unsafe { to_bool(tuya_is_device22(self.handle)) }
    }

    pub fn as_ptr(&self) -> *mut c_void { self.handle }
}

impl Drop for Device {
    fn drop(&mut self) {
        if !self.handle.is_null() {
            unsafe { tuya_destroy(self.handle); }
        }
    }
}
