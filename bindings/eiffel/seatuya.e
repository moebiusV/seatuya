-- seatuya.e — Eiffel FFI bindings for libseatuya
--
-- Eiffel uses the `external` keyword for C interop.  Each C function
-- is declared as a frozen external feature in a class.
-- The opaque tuya_device_t* is stored as a POINTER.
--
-- Usage:
--   create dev.make
--   dev.create_with("id", "192.168.1.100", "key", "3.4")
--   print(dev.turn_on(1))
--   dev.destroy

class SEATUYA_DEVICE

feature {NONE} -- Implementation
    c_lib: STRING
        once
            Result := (execution_environment.item("SEATUYA_LIB")).out
            if Result.is_empty then
                Result := "libseatuya.so"
            end
        end

feature -- Access
    handle: POINTER

    version: STRING
        external "C [macro <seatuya/seatuya.h>] : char* | tuya_version()"
        alias "tuya_version"
        end

feature -- Initialization
    make
        do
            handle := default_pointer
        end

    create_with (device_id, address, local_key, version_str: STRING): BOOLEAN
        external "C signature (char*, char*, char*, char*): EIF_POINTER | tuya_create"
        alias "tuya_create"
        end

feature -- Destruction
    destroy
        external "C signature (EIF_POINTER): void | tuya_destroy"
        alias "tuya_destroy"
        end

feature -- Connection
    connect (hostname: STRING): BOOLEAN
        external "C signature (EIF_POINTER, char*): int | tuya_connect"
        alias "tuya_connect"
        end

    disconnect
        external "C signature (EIF_POINTER): void | tuya_disconnect"
        alias "tuya_disconnect"
        end

    is_connected: BOOLEAN
        external "C signature (EIF_POINTER): int | tuya_is_connected"
        alias "tuya_is_connected"
        end

    reconnect: BOOLEAN
        external "C signature (EIF_POINTER): int | tuya_reconnect"
        alias "tuya_reconnect"
        end

feature -- Credentials
    set_credentials (device_id, local_key: STRING)
        external "C signature (EIF_POINTER, char*, char*): void | tuya_set_credentials"
        alias "tuya_set_credentials"
        end

    device_id: STRING
        external "C signature (EIF_POINTER): char* | tuya_get_device_id"
        alias "tuya_get_device_id"
        end

    local_key: STRING
        external "C signature (EIF_POINTER): char* | tuya_get_local_key"
        alias "tuya_get_local_key"
        end

    ip: STRING
        external "C signature (EIF_POINTER): char* | tuya_get_ip"
        alias "tuya_get_ip"
        end

feature -- State
    protocol: INTEGER
        external "C signature (EIF_POINTER): int | tuya_get_protocol"
        alias "tuya_get_protocol"
        end

    last_error: INTEGER
        external "C signature (EIF_POINTER): int | tuya_get_last_error"
        alias "tuya_get_last_error"
        end

feature -- Async
    set_async_mode (flag: BOOLEAN)
        external "C signature (EIF_POINTER, int): void | tuya_set_async_mode"
        alias "tuya_set_async_mode"
        end

feature -- High-level
    turn_on (dp: INTEGER): STRING
        external "C signature (EIF_POINTER, int): char* | tuya_turn_on"
        alias "tuya_turn_on"
        end

    turn_off (dp: INTEGER): STRING
        external "C signature (EIF_POINTER, int): char* | tuya_turn_off"
        alias "tuya_turn_off"
        end

    status: STRING
        external "C signature (EIF_POINTER): char* | tuya_status"
        alias "tuya_status"
        end

    heartbeat: STRING
        external "C signature (EIF_POINTER): char* | tuya_heartbeat"
        alias "tuya_heartbeat"
        end

    set_value_bool (dp: INTEGER; value: BOOLEAN): STRING
        external "C signature (EIF_POINTER, int, int): char* | tuya_set_value_bool"
        alias "tuya_set_value_bool"
        end

    set_value_int (dp, value: INTEGER): STRING
        external "C signature (EIF_POINTER, int, int): char* | tuya_set_value_int"
        alias "tuya_set_value_int"
        end

    set_value_string (dp: INTEGER; value: STRING): STRING
        external "C signature (EIF_POINTER, int, char*): char* | tuya_set_value_string"
        alias "tuya_set_value_string"
        end

    set_value_float (dp: INTEGER; value: REAL_64): STRING
        external "C signature (EIF_POINTER, int, double): char* | tuya_set_value_float"
        alias "tuya_set_value_float"
        end

feature -- Device22
    set_device22 (null_dps_json: STRING)
        external "C signature (EIF_POINTER, char*): void | tuya_set_device22"
        alias "tuya_set_device22"
        end

    is_device22: BOOLEAN
        external "C signature (EIF_POINTER): int | tuya_is_device22"
        alias "tuya_is_device22"
        end

feature -- Constants
    cmd_control: INTEGER = 7
    cmd_dp_query: INTEGER = 10
    cmd_heart_beat: INTEGER = 9
    cmd_status: INTEGER = 8
    cmd_control_new: INTEGER = 13
    cmd_dp_query_new: INTEGER = 16
    default_port: INTEGER = 6668
    buf_size: INTEGER = 1024

end
