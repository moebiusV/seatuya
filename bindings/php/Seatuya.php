<?php
/**
 * Seatuya.php — PHP FFI bindings for libseatuya
 *
 * PHP 7.4+ FFI binding using the built-in FFI class.  Declares every
 * C function and type from seatuya.h via FFI::cdef(), then wraps them
 * in a static class with automatic string management.
 *
 * Usage:
 *   require_once 'Seatuya.php';
 *   $dev = Seatuya::create($deviceId, '192.168.1.100', $localKey, '3.4');
 *   echo Seatuya::turnOn($dev, 1), "\n";
 *   Seatuya::destroy($dev);
 */

declare(strict_types=1);

final class Seatuya
{
    private static ?FFI $ffi = null;

    private static function ffi(): FFI
    {
        if (self::$ffi === null) {
            $lib = getenv('SEATUYA_LIB') ?: (
                PHP_OS_FAMILY === 'Darwin' ? 'libseatuya.dylib' :
                (PHP_OS_FAMILY === 'Windows' ? 'seatuya.dll' : 'libseatuya.so')
            );
            self::$ffi = FFI::cdef('
                typedef struct tuya_device tuya_device_t;
                enum { TUYA_DEFAULT_PORT = 6668, TUYA_RECOMMENDED_BUFSIZE = 1024,
                       TUYA_DEFAULT_RETRY_LIMIT = 5, TUYA_DEFAULT_RETRY_DELAY_MS = 100 };
                const char *tuya_version(void);
                tuya_device_t *tuya_create(const char*, const char*, const char*, const char*);
                tuya_device_t *tuya_alloc(const char*);
                void tuya_destroy(tuya_device_t*);
                void tuya_set_credentials(tuya_device_t*, const char*, const char*);
                const char *tuya_get_device_id(tuya_device_t*);
                const char *tuya_get_local_key(tuya_device_t*);
                const char *tuya_get_ip(tuya_device_t*);
                bool tuya_connect(tuya_device_t*, const char*);
                void tuya_disconnect(tuya_device_t*);
                bool tuya_is_connected(tuya_device_t*);
                bool tuya_reconnect(tuya_device_t*);
                void tuya_set_retry_limit(tuya_device_t*, int);
                void tuya_set_retry_delay(tuya_device_t*, int);
                int tuya_get_retry_limit(tuya_device_t*);
                int tuya_get_retry_delay(tuya_device_t*);
                bool tuya_negotiate_session(tuya_device_t*, const char*);
                bool tuya_negotiate_session_start(tuya_device_t*, const char*);
                bool tuya_negotiate_session_finalize(tuya_device_t*, unsigned char*, int, const char*);
                int tuya_get_protocol(tuya_device_t*);
                int tuya_get_session_state(tuya_device_t*);
                int tuya_get_socket_state(tuya_device_t*);
                int tuya_get_last_error(tuya_device_t*);
                void tuya_set_async_mode(tuya_device_t*, bool);
                bool tuya_is_socket_readable(tuya_device_t*);
                bool tuya_is_socket_writable(tuya_device_t*);
                bool tuya_set_session_ready(tuya_device_t*);
                int tuya_build_message(tuya_device_t*, unsigned char*, int, const char*, const char*);
                char *tuya_decode_message(tuya_device_t*, unsigned char*, int, const char*);
                char *tuya_generate_payload(tuya_device_t*, int, const char*, const char*);
                int tuya_send(tuya_device_t*, unsigned char*, int);
                int tuya_receive(tuya_device_t*, unsigned char*, int, int);
                char *tuya_set_value_bool(tuya_device_t*, int, bool);
                char *tuya_set_value_int(tuya_device_t*, int, int);
                char *tuya_set_value_string(tuya_device_t*, int, const char*);
                char *tuya_set_value_float(tuya_device_t*, int, double);
                char *tuya_turn_on(tuya_device_t*, int);
                char *tuya_turn_off(tuya_device_t*, int);
                char *tuya_status(tuya_device_t*);
                char *tuya_heartbeat(tuya_device_t*);
                void tuya_free_string(char*);
                void tuya_set_device22(tuya_device_t*, const char*);
                bool tuya_is_device22(const tuya_device_t*);
            ', $lib);
        }
        return self::$ffi;
    }

    // ── Constants ──
    public const int CMD_CONTROL = 7;
    public const int CMD_DP_QUERY = 10;
    public const int CMD_HEART_BEAT = 9;
    public const int CMD_STATUS = 8;
    public const int CMD_CONTROL_NEW = 13;
    public const int CMD_DP_QUERY_NEW = 16;
    public const int PROTO_V31 = 0;
    public const int PROTO_V33 = 1;
    public const int PROTO_V34 = 2;
    public const int PROTO_V35 = 3;
    public const int DEFAULT_PORT = 6668;
    public const int BUFSIZE = 1024;
    public const int DEFAULT_RETRY_LIMIT = 5;
    public const int DEFAULT_RETRY_DELAY_MS = 100;

    // ── Helper ──
    private static function consume(?string $ptr): ?string
    {
        if ($ptr === null) return null;
        $s = $ptr;
        self::ffi()->tuya_free_string($ptr);
        return $s;
    }

    // ── Lifecycle ──
    public static function version(): string { return self::ffi()->tuya_version(); }

    public static function create(string $deviceId, string $address,
                                   string $localKey, string $version): ?FFI\CData
    {
        $dev = self::ffi()->tuya_create($deviceId, $address, $localKey, $version);
        return $dev === null ? null : $dev;
    }

    public static function alloc(string $version): ?FFI\CData
    {
        $dev = self::ffi()->tuya_alloc($version);
        return $dev === null ? null : $dev;
    }

    public static function destroy(?FFI\CData $dev): void
    {
        if ($dev !== null) self::ffi()->tuya_destroy($dev);
    }

    // ── Credentials ──
    public static function setCredentials(FFI\CData $dev, string $id, string $key): void
    { self::ffi()->tuya_set_credentials($dev, $id, $key); }
    public static function getDeviceId(FFI\CData $dev): string { return self::ffi()->tuya_get_device_id($dev); }
    public static function getLocalKey(FFI\CData $dev): string { return self::ffi()->tuya_get_local_key($dev); }
    public static function getIp(FFI\CData $dev): string { return self::ffi()->tuya_get_ip($dev); }

    // ── Connection ──
    public static function connect(FFI\CData $dev, string $host): bool { return self::ffi()->tuya_connect($dev, $host); }
    public static function disconnect(FFI\CData $dev): void { self::ffi()->tuya_disconnect($dev); }
    public static function isConnected(FFI\CData $dev): bool { return self::ffi()->tuya_is_connected($dev); }
    public static function reconnect(FFI\CData $dev): bool { return self::ffi()->tuya_reconnect($dev); }

    // ── Retry ──
    public static function setRetryLimit(FFI\CData $dev, int $limit): void { self::ffi()->tuya_set_retry_limit($dev, $limit); }
    public static function setRetryDelay(FFI\CData $dev, int $ms): void { self::ffi()->tuya_set_retry_delay($dev, $ms); }
    public static function getRetryLimit(FFI\CData $dev): int { return self::ffi()->tuya_get_retry_limit($dev); }
    public static function getRetryDelay(FFI\CData $dev): int { return self::ffi()->tuya_get_retry_delay($dev); }

    // ── Session ──
    public static function negotiateSession(FFI\CData $dev, string $key): bool { return self::ffi()->tuya_negotiate_session($dev, $key); }

    // ── State ──
    public static function getProtocol(FFI\CData $dev): int { return self::ffi()->tuya_get_protocol($dev); }
    public static function getSessionState(FFI\CData $dev): int { return self::ffi()->tuya_get_session_state($dev); }
    public static function getSocketState(FFI\CData $dev): int { return self::ffi()->tuya_get_socket_state($dev); }
    public static function getLastError(FFI\CData $dev): int { return self::ffi()->tuya_get_last_error($dev); }

    // ── Async ──
    public static function setAsyncMode(FFI\CData $dev, bool $flag): void { self::ffi()->tuya_set_async_mode($dev, $flag); }

    // ── High-level round-trip ──
    public static function setValue(FFI\CData $dev, int $dp, mixed $value): ?string
    {
        return match (true) {
            is_bool($value)   => self::consume(self::ffi()->tuya_set_value_bool($dev, $dp, $value)),
            is_int($value)    => self::consume(self::ffi()->tuya_set_value_int($dev, $dp, $value)),
            is_float($value)  => self::consume(self::ffi()->tuya_set_value_float($dev, $dp, $value)),
            default           => self::consume(self::ffi()->tuya_set_value_string($dev, $dp, (string)$value)),
        };
    }

    public static function turnOn(FFI\CData $dev, int $dp = 1): ?string
    { return self::consume(self::ffi()->tuya_turn_on($dev, $dp)); }

    public static function turnOff(FFI\CData $dev, int $dp = 1): ?string
    { return self::consume(self::ffi()->tuya_turn_off($dev, $dp)); }

    public static function status(FFI\CData $dev): ?string
    { return self::consume(self::ffi()->tuya_status($dev)); }

    public static function heartbeat(FFI\CData $dev): ?string
    { return self::consume(self::ffi()->tuya_heartbeat($dev)); }

    // ── Device22 ──
    public static function setDevice22(FFI\CData $dev, string $json): void
    { self::ffi()->tuya_set_device22($dev, $json); }

    public static function isDevice22(FFI\CData $dev): bool
    { return self::ffi()->tuya_is_device22($dev); }
}
