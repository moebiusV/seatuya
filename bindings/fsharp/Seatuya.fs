namespace Seatuya

open System
open System.Runtime.InteropServices

/// <summary>
/// F# P/Invoke bindings for libseatuya (Tuya local device control).
///
/// Set the SEATUYA_LIB environment variable to override the library path
/// (must point directly to the .so/.dylib file).  On .NET 5+ this uses
/// NativeLibrary.Load; on older Mono set LD_LIBRARY_PATH instead.
/// </summary>
module Seatuya =

    // ------------------------------------------------------------------
    //  Native library loading
    // ------------------------------------------------------------------

    module private Loader =

        [<DllImport("libdl", CallingConvention = CallingConvention.Cdecl)>
         ]
        extern IntPtr dlopen(string filename, int flags)

        [<Literal>]
        let RTLD_NOW = 2

        let tryLoad (path: string) : bool =
            try
                // .NET Core 3.1+ / .NET 5+
                NativeLibrary.Load path |> ignore
                true
            with _ ->
                try
                    // Fallback via dlopen (Mono / legacy)
                    let h = dlopen(path, RTLD_NOW)
                    h <> IntPtr.Zero
                with _ ->
                    false

        let initialize () =
            match Environment.GetEnvironmentVariable "SEATUYA_LIB" with
            | null | "" -> ()
            | path ->
                if not (tryLoad path) then
                    eprintfn "seatuya: warning: could not pre-load '%s'" path

    do Loader.initialize ()

    // ------------------------------------------------------------------
    //  Native C function declarations
    // ------------------------------------------------------------------

    module private Native =

        [<Literal>]
        let Lib = "libseatuya"

        [<DllImport(Lib, CallingConvention = CallingConvention.Cdecl,
                     CharSet = CharSet.Ansi)>]
        extern IntPtr tuya_create(string device_id, string address,
                                   string local_key, string version)

        [<DllImport(Lib, CallingConvention = CallingConvention.Cdecl,
                     CharSet = CharSet.Ansi)>]
        extern IntPtr tuya_alloc(string version)

        [<DllImport(Lib, CallingConvention = CallingConvention.Cdecl)>]
        extern tuya_destroy(IntPtr dev)

        [<DllImport(Lib, CallingConvention = CallingConvention.Cdecl,
                     CharSet = CharSet.Ansi)>]
        extern tuya_set_credentials(IntPtr dev, string device_id,
                                          string local_key)

        [<DllImport(Lib, CallingConvention = CallingConvention.Cdecl,
                     CharSet = CharSet.Ansi)>]
        extern IntPtr tuya_get_device_id(IntPtr dev)

        [<DllImport(Lib, CallingConvention = CallingConvention.Cdecl,
                     CharSet = CharSet.Ansi)>]
        extern IntPtr tuya_get_local_key(IntPtr dev)

        [<DllImport(Lib, CallingConvention = CallingConvention.Cdecl,
                     CharSet = CharSet.Ansi)>]
        extern IntPtr tuya_get_ip(IntPtr dev)

        [<DllImport(Lib, CallingConvention = CallingConvention.Cdecl,
                     CharSet = CharSet.Ansi)>]
        [<return: MarshalAs(UnmanagedType.I1)>]
        extern bool tuya_connect(IntPtr dev, string hostname)

        [<DllImport(Lib, CallingConvention = CallingConvention.Cdecl)>]
        extern tuya_disconnect(IntPtr dev)

        [<DllImport(Lib, CallingConvention = CallingConvention.Cdecl)>]
        [<return: MarshalAs(UnmanagedType.I1)>]
        extern bool tuya_is_connected(IntPtr dev)

        [<DllImport(Lib, CallingConvention = CallingConvention.Cdecl)>]
        [<return: MarshalAs(UnmanagedType.I1)>]
        extern bool tuya_reconnect(IntPtr dev)

        [<DllImport(Lib, CallingConvention = CallingConvention.Cdecl)>]
        extern tuya_set_retry_limit(IntPtr dev, int limit)

        [<DllImport(Lib, CallingConvention = CallingConvention.Cdecl)>]
        extern tuya_set_retry_delay(IntPtr dev, int delay_ms)

        [<DllImport(Lib, CallingConvention = CallingConvention.Cdecl)>]
        extern int tuya_get_retry_limit(IntPtr dev)

        [<DllImport(Lib, CallingConvention = CallingConvention.Cdecl)>]
        extern int tuya_get_retry_delay(IntPtr dev)

        [<DllImport(Lib, CallingConvention = CallingConvention.Cdecl,
                     CharSet = CharSet.Ansi)>]
        [<return: MarshalAs(UnmanagedType.I1)>]
        extern bool tuya_negotiate_session(IntPtr dev, string local_key)

        [<DllImport(Lib, CallingConvention = CallingConvention.Cdecl,
                     CharSet = CharSet.Ansi)>]
        [<return: MarshalAs(UnmanagedType.I1)>]
        extern bool tuya_negotiate_session_start(IntPtr dev, string local_key)

        [<DllImport(Lib, CallingConvention = CallingConvention.Cdecl)>]
        [<return: MarshalAs(UnmanagedType.I1)>]
        extern bool tuya_negotiate_session_finalize(IntPtr dev,
                                                     byte[] buf, int size,
                                                     string local_key)

        [<DllImport(Lib, CallingConvention = CallingConvention.Cdecl)>]
        extern int tuya_get_protocol(IntPtr dev)

        [<DllImport(Lib, CallingConvention = CallingConvention.Cdecl)>]
        extern int tuya_get_session_state(IntPtr dev)

        [<DllImport(Lib, CallingConvention = CallingConvention.Cdecl)>]
        extern int tuya_get_socket_state(IntPtr dev)

        [<DllImport(Lib, CallingConvention = CallingConvention.Cdecl)>]
        extern int tuya_get_last_error(IntPtr dev)

        [<DllImport(Lib, CallingConvention = CallingConvention.Cdecl)>]
        extern tuya_set_async_mode(IntPtr dev,
                                         [<MarshalAs(UnmanagedType.I1)>] bool async)

        [<DllImport(Lib, CallingConvention = CallingConvention.Cdecl)>]
        [<return: MarshalAs(UnmanagedType.I1)>]
        extern bool tuya_is_socket_readable(IntPtr dev)

        [<DllImport(Lib, CallingConvention = CallingConvention.Cdecl)>]
        [<return: MarshalAs(UnmanagedType.I1)>]
        extern bool tuya_is_socket_writable(IntPtr dev)

        [<DllImport(Lib, CallingConvention = CallingConvention.Cdecl)>]
        [<return: MarshalAs(UnmanagedType.I1)>]
        extern bool tuya_set_session_ready(IntPtr dev)

        [<DllImport(Lib, CallingConvention = CallingConvention.Cdecl,
                     CharSet = CharSet.Ansi)>]
        extern int tuya_build_message(IntPtr dev, byte[] buf, int cmd,
                                       string payload, string key)

        [<DllImport(Lib, CallingConvention = CallingConvention.Cdecl,
                     CharSet = CharSet.Ansi)>]
        extern IntPtr tuya_decode_message(IntPtr dev, byte[] buf, int size,
                                           string key)

        [<DllImport(Lib, CallingConvention = CallingConvention.Cdecl,
                     CharSet = CharSet.Ansi)>]
        extern IntPtr tuya_generate_payload(IntPtr dev, int cmd,
                                             string device_id,
                                             string datapoints)

        [<DllImport(Lib, CallingConvention = CallingConvention.Cdecl)>]
        extern int tuya_send(IntPtr dev, byte[] buf, int size)

        [<DllImport(Lib, CallingConvention = CallingConvention.Cdecl)>]
        extern int tuya_receive(IntPtr dev, byte[] buf, int maxsize, int minsize)

        [<DllImport(Lib, CallingConvention = CallingConvention.Cdecl,
                     CharSet = CharSet.Ansi)>]
        extern tuya_set_device22(IntPtr dev, string null_dps_json)

        [<DllImport(Lib, CallingConvention = CallingConvention.Cdecl)>]
        [<return: MarshalAs(UnmanagedType.I1)>]
        extern bool tuya_is_device22(IntPtr dev)

        [<DllImport(Lib, CallingConvention = CallingConvention.Cdecl)>]
        extern IntPtr tuya_set_value_bool(IntPtr dev, int dp,
                                           [<MarshalAs(UnmanagedType.I1)>] bool value)

        [<DllImport(Lib, CallingConvention = CallingConvention.Cdecl)>]
        extern IntPtr tuya_set_value_int(IntPtr dev, int dp, int value)

        [<DllImport(Lib, CallingConvention = CallingConvention.Cdecl,
                     CharSet = CharSet.Ansi)>]
        extern IntPtr tuya_set_value_string(IntPtr dev, int dp, string value)

        [<DllImport(Lib, CallingConvention = CallingConvention.Cdecl)>]
        extern IntPtr tuya_set_value_float(IntPtr dev, int dp, double value)

        [<DllImport(Lib, CallingConvention = CallingConvention.Cdecl)>]
        extern IntPtr tuya_turn_on(IntPtr dev, int switch_dp)

        [<DllImport(Lib, CallingConvention = CallingConvention.Cdecl)>]
        extern IntPtr tuya_turn_off(IntPtr dev, int switch_dp)

        [<DllImport(Lib, CallingConvention = CallingConvention.Cdecl)>]
        extern IntPtr tuya_status(IntPtr dev)

        [<DllImport(Lib, CallingConvention = CallingConvention.Cdecl)>]
        extern IntPtr tuya_heartbeat(IntPtr dev)

        [<DllImport(Lib, CallingConvention = CallingConvention.Cdecl)>]
        extern tuya_free_string(IntPtr str)

        [<DllImport(Lib, CallingConvention = CallingConvention.Cdecl,
                     CharSet = CharSet.Ansi)>]
        extern IntPtr tuya_version()

    // ------------------------------------------------------------------
    //  Helper: take a malloc'd C string, convert to F# string, free it.
    // ------------------------------------------------------------------

    let private takeString (ptr: IntPtr) : string =
        if ptr = IntPtr.Zero then null
        else
            let s = Marshal.PtrToStringAnsi ptr
            Native.tuya_free_string ptr |> ignore
            s

    let private ptrToBool (ptr: IntPtr) : bool = ptr <> IntPtr.Zero

    // ------------------------------------------------------------------
    //  Library handle type
    // ------------------------------------------------------------------

    /// Opaque handle wrapping a native tuya_device_t pointer.
    type Device = private { Handle: IntPtr }
    with
        override _.ToString() = sprintf "Seatuya.Device(%016x)" (int64 (unativeint {this}.Handle))

        interface IDisposable with
            member this.Dispose() =
                if this.Handle <> IntPtr.Zero then
                    Native.tuya_destroy this.Handle
                    {this with Handle = IntPtr.Zero} |> ignore

    let private makeDev ptr =
        if ptr = IntPtr.Zero then None
        else Some { Handle = ptr }

    // ------------------------------------------------------------------
    //  Public API
    // ------------------------------------------------------------------

    /// Get the libseatuya version string.
    let version () : string =
        let ptr = Native.tuya_version()
        Marshal.PtrToStringAnsi ptr

    /// Create a device, connect, and negotiate session.
    let create (deviceId: string) (address: string) (localKey: string)
               (version: string) : Device option =
        makeDev (Native.tuya_create(deviceId, address, localKey, version))

    /// Allocate a device handle without connecting.
    let alloc (version: string) : Device option =
        makeDev (Native.tuya_alloc(version))

    /// Destroy a device handle.
    let destroy (dev: Device) : unit =
        if dev.Handle <> IntPtr.Zero then
            Native.tuya_destroy dev.Handle

    /// Set device credentials.
    let setCredentials (dev: Device) (deviceId: string) (localKey: string) : unit =
        Native.tuya_set_credentials(dev.Handle, deviceId, localKey)

    /// Get the device ID.
    let getDeviceId (dev: Device) : string =
        let ptr = Native.tuya_get_device_id dev.Handle
        Marshal.PtrToStringAnsi ptr

    /// Get the local key.
    let getLocalKey (dev: Device) : string =
        let ptr = Native.tuya_get_local_key dev.Handle
        Marshal.PtrToStringAnsi ptr

    /// Get the device IP address.
    let getIp (dev: Device) : string =
        let ptr = Native.tuya_get_ip dev.Handle
        Marshal.PtrToStringAnsi ptr

    /// Connect to a device by hostname.
    let connect (dev: Device) (hostname: string) : bool =
        Native.tuya_connect(dev.Handle, hostname)

    /// Disconnect from the device.
    let disconnect (dev: Device) : unit =
        Native.tuya_disconnect dev.Handle

    /// Returns true if connected.
    let isConnected (dev: Device) : bool =
        Native.tuya_is_connected dev.Handle

    /// Reconnect if connection dropped.
    let reconnect (dev: Device) : bool =
        Native.tuya_reconnect dev.Handle

    /// Set connection retry limit.
    let setRetryLimit (dev: Device) (limit: int) : unit =
        Native.tuya_set_retry_limit(dev.Handle, limit)

    /// Set connection retry delay in ms.
    let setRetryDelay (dev: Device) (delayMs: int) : unit =
        Native.tuya_set_retry_delay(dev.Handle, delayMs)

    /// Get connection retry limit.
    let getRetryLimit (dev: Device) : int =
        Native.tuya_get_retry_limit dev.Handle

    /// Get connection retry delay in ms.
    let getRetryDelay (dev: Device) : int =
        Native.tuya_get_retry_delay dev.Handle

    /// Negotiate session (blocking).
    let negotiateSession (dev: Device) (key: string) : bool =
        Native.tuya_negotiate_session(dev.Handle, key)

    /// Start session negotiation (async-friendly).
    let negotiateSessionStart (dev: Device) (key: string) : bool =
        Native.tuya_negotiate_session_start(dev.Handle, key)

    /// Finalize session negotiation with device response data.
    let negotiateSessionFinalize (dev: Device) (buf: byte[]) (size: int)
                                 (key: string) : bool =
        Native.tuya_negotiate_session_finalize(dev.Handle, buf, size, key)

    /// Get protocol version.
    let getProtocol (dev: Device) : int =
        Native.tuya_get_protocol dev.Handle

    /// Get session state.
    let getSessionState (dev: Device) : int =
        Native.tuya_get_session_state dev.Handle

    /// Get socket state.
    let getSocketState (dev: Device) : int =
        Native.tuya_get_socket_state dev.Handle

    /// Get last error code.
    let getLastError (dev: Device) : int =
        Native.tuya_get_last_error dev.Handle

    /// Enable/disable async socket mode.
    let setAsyncMode (dev: Device) (async: bool) : unit =
        Native.tuya_set_async_mode(dev.Handle, async)

    /// Returns true if the socket has data available to read.
    let isSocketReadable (dev: Device) : bool =
        Native.tuya_is_socket_readable dev.Handle

    /// Returns true if the socket is ready for writing.
    let isSocketWritable (dev: Device) : bool =
        Native.tuya_is_socket_writable dev.Handle

    /// Mark the session as ready.
    let setSessionReady (dev: Device) : bool =
        Native.tuya_set_session_ready dev.Handle

    /// Build an encrypted Tuya protocol message.
    let buildMessage (dev: Device) (buf: byte[]) (cmd: int)
                     (payload: string) (key: string) : int =
        Native.tuya_build_message(dev.Handle, buf, cmd, payload, key)

    /// Decode a received Tuya protocol message.
    let decodeMessage (dev: Device) (buf: byte[]) (size: int)
                      (key: string) : string =
        takeString (Native.tuya_decode_message(dev.Handle, buf, size, key))

    /// Generate a JSON payload for a command.
    let generatePayload (dev: Device) (cmd: int) (deviceId: string)
                        (datapoints: string) : string =
        takeString (Native.tuya_generate_payload(dev.Handle, cmd,
                                                  deviceId, datapoints))

    /// Send raw bytes to the device.
    let send (dev: Device) (buf: byte[]) (size: int) : int =
        Native.tuya_send(dev.Handle, buf, size)

    /// Receive raw bytes from the device.
    let receive (dev: Device) (maxsize: int) (minsize: int) : byte[] * int =
        let buf = Array.zeroCreate maxsize
        let got = Native.tuya_receive(dev.Handle, buf, maxsize, minsize)
        if got < 0 then (Array.empty, got)
        else (buf.[0..got-1], got)

    /// Enable device22 mode.
    let setDevice22 (dev: Device) (nullDpsJson: string) : unit =
        Native.tuya_set_device22(dev.Handle, nullDpsJson)

    /// Returns true if device22 mode is enabled.
    let isDevice22 (dev: Device) : bool =
        Native.tuya_is_device22 dev.Handle

    /// Set a boolean DP value (full round-trip).
    let setValueBool (dev: Device) (dp: int) (value: bool) : string =
        takeString (Native.tuya_set_value_bool(dev.Handle, dp, value))

    /// Set an integer DP value (full round-trip).
    let setValueInt (dev: Device) (dp: int) (value: int) : string =
        takeString (Native.tuya_set_value_int(dev.Handle, dp, value))

    /// Set a string DP value (full round-trip).
    let setValueString (dev: Device) (dp: int) (value: string) : string =
        takeString (Native.tuya_set_value_string(dev.Handle, dp, value))

    /// Set a float DP value (full round-trip).
    let setValueFloat (dev: Device) (dp: int) (value: float) : string =
        takeString (Native.tuya_set_value_float(dev.Handle, dp, value))

    /// Turn on a switch DP.
    let turnOn (dev: Device) (switchDp: int) : string =
        takeString (Native.tuya_turn_on(dev.Handle, switchDp))

    /// Turn off a switch DP.
    let turnOff (dev: Device) (switchDp: int) : string =
        takeString (Native.tuya_turn_off(dev.Handle, switchDp))

    /// Query device status.
    let status (dev: Device) : string =
        takeString (Native.tuya_status(dev.Handle))

    /// Send a heartbeat.
    let heartbeat (dev: Device) : string =
        takeString (Native.tuya_heartbeat(dev.Handle))

    // ------------------------------------------------------------------
    //  Type-aware set_value dispatcher
    // ------------------------------------------------------------------

    /// Set a DP value, dispatching by type to the correct C setter.
    let setValue (dev: Device) (dp: int) (value: obj) : string =
        match value with
        | :? bool as b   -> setValueBool dev dp b
        | :? int as i    -> setValueInt dev dp i
        | :? float as f  -> setValueFloat dev dp f
        | :? string as s -> setValueString dev dp s
        | _              -> invalidArg "value"
                             (sprintf "unsupported type: %s" (value.GetType().Name))

    // ------------------------------------------------------------------
    //  Constants
    // ------------------------------------------------------------------

    module Commands =
        [<Literal>] let UDP                  = 0
        [<Literal>] let AP_CONFIG            = 1
        [<Literal>] let ACTIVE               = 2
        [<Literal>] let BIND                 = 3
        [<Literal>] let RENAME_GW            = 4
        [<Literal>] let RENAME_DEVICE        = 5
        [<Literal>] let UNBIND               = 6
        [<Literal>] let CONTROL              = 7
        [<Literal>] let STATUS               = 8
        [<Literal>] let HEART_BEAT           = 9
        [<Literal>] let DP_QUERY             = 10
        [<Literal>] let QUERY_WIFI           = 11
        [<Literal>] let TOKEN_BIND           = 12
        [<Literal>] let CONTROL_NEW          = 13
        [<Literal>] let ENABLE_WIFI          = 14
        [<Literal>] let DP_QUERY_NEW         = 16
        [<Literal>] let SCENE_EXECUTE        = 17
        [<Literal>] let UPDATEDPS            = 18
        [<Literal>] let UDP_NEW              = 19
        [<Literal>] let AP_CONFIG_NEW        = 20
        [<Literal>] let GET_LOCAL_TIME       = 28
        [<Literal>] let WEATHER_OPEN         = 32
        [<Literal>] let WEATHER_DATA         = 33
        [<Literal>] let STATE_UPLOAD_SYN     = 34
        [<Literal>] let STATE_UPLOAD_SYN_RECV = 35
        [<Literal>] let HEART_BEAT_STOP      = 37
        [<Literal>] let STREAM_TRANS         = 38
        [<Literal>] let GET_WIFI_STATUS      = 43
        [<Literal>] let WIFI_CONNECT_TEST    = 44
        [<Literal>] let GET_MAC              = 45
        [<Literal>] let GET_IR_STATUS        = 46
        [<Literal>] let IR_TX_RX_TEST        = 47
        [<Literal>] let LAN_GW_ACTIVE        = 240
        [<Literal>] let LAN_SUB_DEV_REQUEST  = 241
        [<Literal>] let LAN_DELETE_SUB_DEV   = 242
        [<Literal>] let LAN_REPORT_SUB_DEV   = 243
        [<Literal>] let LAN_SCENE            = 244
        [<Literal>] let LAN_PUBLISH_CLOUD_CONFIG = 245
        [<Literal>] let LAN_PUBLISH_APP_CONFIG   = 246
        [<Literal>] let LAN_EXPORT_APP_CONFIG    = 247
        [<Literal>] let LAN_PUBLISH_SCENE_PANEL  = 248
        [<Literal>] let LAN_REMOVE_GW        = 249
        [<Literal>] let LAN_CHECK_GW_UPDATE  = 250
        [<Literal>] let LAN_GW_UPDATE        = 251
        [<Literal>] let LAN_SET_GW_CHANNEL   = 252

    module Protocols =
        [<Literal>] let V31 = 0
        [<Literal>] let V33 = 1
        [<Literal>] let V34 = 2
        [<Literal>] let V35 = 3

    module SessionStates =
        [<Literal>] let INVALID     = 0
        [<Literal>] let STARTING    = 1
        [<Literal>] let FINALIZING  = 2
        [<Literal>] let ESTABLISHED = 3

    module SocketStates =
        [<Literal>] let NO_SUCH_HOST   = 0
        [<Literal>] let NO_SOCK_AVAIL  = 1
        [<Literal>] let FAILED         = 2
        [<Literal>] let DISCONNECTED   = 3
        [<Literal>] let CONNECTING     = 4
        [<Literal>] let CONNECTED      = 5
        [<Literal>] let READY          = 6
        [<Literal>] let RECEIVING      = 7

    module Constants =
        [<Literal>] let DEFAULT_PORT        = 6668
        [<Literal>] let BUFSIZE             = 1024
        [<Literal>] let DEFAULT_RETRY_LIMIT = 5
        [<Literal>] let DEFAULT_RETRY_DELAY_MS = 100
