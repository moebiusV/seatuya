// Seatuya.cs — C# / .NET P/Invoke bindings for libseatuya
//
// Pure C# bindings using [DllImport] for every function in libseatuya.
// Includes a SafeHandle wrapper for automatic cleanup and strongly-typed
// enums matching the C header.
//
// Usage:
//   using var dev = Seatuya.Create(deviceId, "192.168.1.100", localKey, "3.4");
//   Console.WriteLine(Seatuya.TurnOn(dev, 1));
//   Console.WriteLine(Seatuya.Status(dev));
//   Seatuya.TurnOff(dev, 1);

using System;
using System.Runtime.InteropServices;

namespace Seatuya
{
    // --- Enums ---
    public enum TuyaCommand
    {
        CmdUdp                = 0,
        CmdApConfig           = 1,
        CmdActive             = 2,
        CmdBind               = 3,
        CmdRenameGw           = 4,
        CmdRenameDevice       = 5,
        CmdUnbind             = 6,
        CmdControl            = 7,
        CmdStatus             = 8,
        CmdHeartBeat          = 9,
        CmdDpQuery            = 10,
        CmdQueryWifi          = 11,
        CmdTokenBind          = 12,
        CmdControlNew         = 13,
        CmdEnableWifi         = 14,
        CmdDpQueryNew         = 16,
        CmdSceneExecute       = 17,
        CmdUpdateDps          = 18,
        CmdUdpNew             = 19,
        CmdApConfigNew        = 20,
        CmdGetLocalTime       = 28,
        CmdWeatherOpen        = 32,
        CmdWeatherData        = 33,
        CmdStateUploadSyn     = 34,
        CmdStateUploadSynRecv = 35,
        CmdHeartBeatStop      = 37,
        CmdStreamTrans        = 38,
        CmdGetWifiStatus      = 43,
        CmdWifiConnectTest    = 44,
        CmdGetMac             = 45,
        CmdGetIrStatus        = 46,
        CmdIrTxRxTest         = 47,
        CmdLanGwActive        = 240,
        CmdLanSubDevRequest   = 241,
        CmdLanDeleteSubDev    = 242,
        CmdLanReportSubDev    = 243,
        CmdLanScene           = 244,
        CmdLanPubCloudCfg     = 245,
        CmdLanPubAppCfg       = 246,
        CmdLanExportAppCfg    = 247,
        CmdLanPubScenePanel   = 248,
        CmdLanRemoveGw        = 249,
        CmdLanCheckGwUpdate   = 250,
        CmdLanGwUpdate        = 251,
        CmdLanSetGwChannel    = 252,
    }

    public enum TuyaProtocol  { V31, V33, V34, V35 }
    public enum SessionState  { Invalid, Starting, Finalizing, Established }
    public enum SocketState   { NoSuchHost, NoSockAvail, Failed, Disconnected,
                                Connecting, Connected, Ready, Receiving }

    // --- SafeHandle for automatic cleanup ---
    public sealed class TuyaDevice : SafeHandle
    {
        public TuyaDevice() : base(IntPtr.Zero, true) { }
        public override bool IsInvalid => handle == IntPtr.Zero;
        protected override bool ReleaseHandle()
        {
            SeatuyaNative.tuya_destroy(handle);
            return true;
        }
    }

    // --- Native interop ---
    internal static class SeatuyaNative
    {
        const string Lib = "libseatuya.so";

        [DllImport(Lib)] internal static extern IntPtr tuya_version();
        [DllImport(Lib)] internal static extern IntPtr tuya_create(
            string deviceId, string address, string localKey, string version);
        [DllImport(Lib)] internal static extern IntPtr tuya_alloc(string version);
        [DllImport(Lib)] internal static extern void tuya_destroy(IntPtr dev);
        [DllImport(Lib)] internal static extern void tuya_set_credentials(
            IntPtr dev, string deviceId, string localKey);
        [DllImport(Lib)] internal static extern IntPtr tuya_get_device_id(IntPtr dev);
        [DllImport(Lib)] internal static extern IntPtr tuya_get_local_key(IntPtr dev);
        [DllImport(Lib)] internal static extern IntPtr tuya_get_ip(IntPtr dev);
        [DllImport(Lib)] internal static extern bool tuya_connect(IntPtr dev, string hostname);
        [DllImport(Lib)] internal static extern void tuya_disconnect(IntPtr dev);
        [DllImport(Lib)] internal static extern bool tuya_is_connected(IntPtr dev);
        [DllImport(Lib)] internal static extern bool tuya_reconnect(IntPtr dev);
        [DllImport(Lib)] internal static extern void tuya_set_retry_limit(IntPtr dev, int limit);
        [DllImport(Lib)] internal static extern void tuya_set_retry_delay(IntPtr dev, int ms);
        [DllImport(Lib)] internal static extern int tuya_get_retry_limit(IntPtr dev);
        [DllImport(Lib)] internal static extern int tuya_get_retry_delay(IntPtr dev);
        [DllImport(Lib)] internal static extern bool tuya_negotiate_session(IntPtr dev, string key);
        [DllImport(Lib)] internal static extern bool tuya_negotiate_session_start(IntPtr dev, string key);
        [DllImport(Lib)] internal static extern bool tuya_negotiate_session_finalize(
            IntPtr dev, byte[] buf, int size, string key);
        [DllImport(Lib)] internal static extern int tuya_get_protocol(IntPtr dev);
        [DllImport(Lib)] internal static extern int tuya_get_session_state(IntPtr dev);
        [DllImport(Lib)] internal static extern int tuya_get_socket_state(IntPtr dev);
        [DllImport(Lib)] internal static extern int tuya_get_last_error(IntPtr dev);
        [DllImport(Lib)] internal static extern void tuya_set_async_mode(IntPtr dev, bool flag);
        [DllImport(Lib)] internal static extern bool tuya_is_socket_readable(IntPtr dev);
        [DllImport(Lib)] internal static extern bool tuya_is_socket_writable(IntPtr dev);
        [DllImport(Lib)] internal static extern bool tuya_set_session_ready(IntPtr dev);
        [DllImport(Lib)] internal static extern int tuya_build_message(
            IntPtr dev, byte[] buf, int cmd, string payload, string key);
        [DllImport(Lib)] internal static extern IntPtr tuya_decode_message(
            IntPtr dev, byte[] buf, int size, string key);
        [DllImport(Lib)] internal static extern IntPtr tuya_generate_payload(
            IntPtr dev, int cmd, string deviceId, string datapoints);
        [DllImport(Lib)] internal static extern int tuya_send(IntPtr dev, byte[] buf, int size);
        [DllImport(Lib)] internal static extern int tuya_receive(
            IntPtr dev, byte[] buf, int maxsize, int minsize);
        [DllImport(Lib)] internal static extern IntPtr tuya_set_value_bool(
            IntPtr dev, int dp, bool value);
        [DllImport(Lib)] internal static extern IntPtr tuya_set_value_int(
            IntPtr dev, int dp, int value);
        [DllImport(Lib)] internal static extern IntPtr tuya_set_value_string(
            IntPtr dev, int dp, string value);
        [DllImport(Lib)] internal static extern IntPtr tuya_set_value_float(
            IntPtr dev, int dp, double value);
        [DllImport(Lib)] internal static extern IntPtr tuya_turn_on(IntPtr dev, int dp);
        [DllImport(Lib)] internal static extern IntPtr tuya_turn_off(IntPtr dev, int dp);
        [DllImport(Lib)] internal static extern IntPtr tuya_status(IntPtr dev);
        [DllImport(Lib)] internal static extern IntPtr tuya_heartbeat(IntPtr dev);
        [DllImport(Lib)] internal static extern void tuya_free_string(IntPtr str);
        [DllImport(Lib)] internal static extern void tuya_set_device22(
            IntPtr dev, string nullDpsJson);
        [DllImport(Lib)] internal static extern bool tuya_is_device22(IntPtr dev);
    }

    // --- Public API ---
    public static class SeatuyaApi
    {
        private static string MarshalString(IntPtr ptr)
        {
            if (ptr == IntPtr.Zero) return null;
            var s = Marshal.PtrToStringAnsi(ptr);
            SeatuyaNative.tuya_free_string(ptr);
            return s;
        }

        public static string Version =>
            Marshal.PtrToStringAnsi(SeatuyaNative.tuya_version());

        public static TuyaDevice Create(string deviceId, string address,
                                         string localKey, string version)
        {
            var handle = SeatuyaNative.tuya_create(deviceId, address, localKey, version);
            if (handle == IntPtr.Zero) return null;
            var dev = new TuyaDevice();
            typeof(SafeHandle).GetField("handle",
                System.Reflection.BindingFlags.NonPublic |
                System.Reflection.BindingFlags.Instance)?.SetValue(dev, handle);
            return dev;
        }

        public static TuyaDevice Alloc(string version)
        {
            var handle = SeatuyaNative.tuya_alloc(version);
            if (handle == IntPtr.Zero) return null;
            var dev = new TuyaDevice();
            typeof(SafeHandle).GetField("handle",
                System.Reflection.BindingFlags.NonPublic |
                System.Reflection.BindingFlags.Instance)?.SetValue(dev, handle);
            return dev;
        }

        // Credentials
        public static void SetCredentials(TuyaDevice dev, string id, string key)
            => SeatuyaNative.tuya_set_credentials(dev.DangerousGetHandle(), id, key);
        public static string GetDeviceId(TuyaDevice dev)
            => Marshal.PtrToStringAnsi(SeatuyaNative.tuya_get_device_id(dev.DangerousGetHandle()));
        public static string GetLocalKey(TuyaDevice dev)
            => Marshal.PtrToStringAnsi(SeatuyaNative.tuya_get_local_key(dev.DangerousGetHandle()));
        public static string GetIp(TuyaDevice dev)
            => Marshal.PtrToStringAnsi(SeatuyaNative.tuya_get_ip(dev.DangerousGetHandle()));

        // Connection
        public static bool Connect(TuyaDevice dev, string hostname)
            => SeatuyaNative.tuya_connect(dev.DangerousGetHandle(), hostname);
        public static void Disconnect(TuyaDevice dev)
            => SeatuyaNative.tuya_disconnect(dev.DangerousGetHandle());
        public static bool IsConnected(TuyaDevice dev)
            => SeatuyaNative.tuya_is_connected(dev.DangerousGetHandle());
        public static bool Reconnect(TuyaDevice dev)
            => SeatuyaNative.tuya_reconnect(dev.DangerousGetHandle());

        // Retry
        public static void SetRetryLimit(TuyaDevice dev, int limit)
            => SeatuyaNative.tuya_set_retry_limit(dev.DangerousGetHandle(), limit);
        public static void SetRetryDelay(TuyaDevice dev, int ms)
            => SeatuyaNative.tuya_set_retry_delay(dev.DangerousGetHandle(), ms);
        public static int GetRetryLimit(TuyaDevice dev)
            => SeatuyaNative.tuya_get_retry_limit(dev.DangerousGetHandle());
        public static int GetRetryDelay(TuyaDevice dev)
            => SeatuyaNative.tuya_get_retry_delay(dev.DangerousGetHandle());

        // Session
        public static bool NegotiateSession(TuyaDevice dev, string key)
            => SeatuyaNative.tuya_negotiate_session(dev.DangerousGetHandle(), key);

        // State queries
        public static TuyaProtocol GetProtocol(TuyaDevice dev)
            => (TuyaProtocol)SeatuyaNative.tuya_get_protocol(dev.DangerousGetHandle());
        public static SessionState GetSessionState(TuyaDevice dev)
            => (SessionState)SeatuyaNative.tuya_get_session_state(dev.DangerousGetHandle());
        public static SocketState GetSocketState(TuyaDevice dev)
            => (SocketState)SeatuyaNative.tuya_get_socket_state(dev.DangerousGetHandle());
        public static int GetLastError(TuyaDevice dev)
            => SeatuyaNative.tuya_get_last_error(dev.DangerousGetHandle());

        // Async
        public static void SetAsyncMode(TuyaDevice dev, bool flag)
            => SeatuyaNative.tuya_set_async_mode(dev.DangerousGetHandle(), flag);

        // High-level round-trip
        public static string SetValueBool(TuyaDevice dev, int dp, bool value)
            => MarshalString(SeatuyaNative.tuya_set_value_bool(dev.DangerousGetHandle(), dp, value));
        public static string SetValueInt(TuyaDevice dev, int dp, int value)
            => MarshalString(SeatuyaNative.tuya_set_value_int(dev.DangerousGetHandle(), dp, value));
        public static string SetValueString(TuyaDevice dev, int dp, string value)
            => MarshalString(SeatuyaNative.tuya_set_value_string(dev.DangerousGetHandle(), dp, value));
        public static string SetValueFloat(TuyaDevice dev, int dp, double value)
            => MarshalString(SeatuyaNative.tuya_set_value_float(dev.DangerousGetHandle(), dp, value));
        public static string TurnOn(TuyaDevice dev, int switchDp = 1)
            => MarshalString(SeatuyaNative.tuya_turn_on(dev.DangerousGetHandle(), switchDp));
        public static string TurnOff(TuyaDevice dev, int switchDp = 1)
            => MarshalString(SeatuyaNative.tuya_turn_off(dev.DangerousGetHandle(), switchDp));
        public static string Status(TuyaDevice dev)
            => MarshalString(SeatuyaNative.tuya_status(dev.DangerousGetHandle()));
        public static string Heartbeat(TuyaDevice dev)
            => MarshalString(SeatuyaNative.tuya_heartbeat(dev.DangerousGetHandle()));

        // device22
        public static void SetDevice22(TuyaDevice dev, string nullDpsJson)
            => SeatuyaNative.tuya_set_device22(dev.DangerousGetHandle(), nullDpsJson);
        public static bool IsDevice22(TuyaDevice dev)
            => SeatuyaNative.tuya_is_device22(dev.DangerousGetHandle());
    }

    // --- Example program ---
    public static class Example
    {
        public static int Main()
        {
            var deviceId  = Environment.GetEnvironmentVariable("TUYA_DEVICE_ID") ?? "0123456789abcdef01234567";
            var localKey  = Environment.GetEnvironmentVariable("TUYA_LOCAL_KEY") ?? "0123456789abcdef";
            var ip        = Environment.GetEnvironmentVariable("TUYA_IP")        ?? "192.168.1.100";
            var version   = Environment.GetEnvironmentVariable("TUYA_VERSION")   ?? "3.4";

            Console.WriteLine($"seatuya version: {SeatuyaApi.Version}");

            using var dev = SeatuyaApi.Create(deviceId, ip, localKey, version);
            if (dev == null)
            {
                Console.Error.WriteLine("ERROR: Could not create device handle");
                return 1;
            }

            Console.WriteLine($"Connected: {SeatuyaApi.IsConnected(dev)}");
            Console.WriteLine($"turn_on: {SeatuyaApi.TurnOn(dev, 1)}");
            Console.WriteLine($"status: {SeatuyaApi.Status(dev)}");
            Console.WriteLine($"turn_off: {SeatuyaApi.TurnOff(dev, 1)}");
            Console.WriteLine("Done.");
            return 0;
        }
    }
}
