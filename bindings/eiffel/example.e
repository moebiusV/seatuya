class SEATUYA_EXAMPLE

create make

feature {NONE} -- Initialization
    make
        local
            dev: SEATUYA_DEVICE
            did, key, ip_addr, ver: STRING
        do
            did := execution_environment.item("TUYA_DEVICE_ID")
            if did.is_empty then did := "0123456789abcdef01234567" end
            key := execution_environment.item("TUYA_LOCAL_KEY")
            if key.is_empty then key := "0123456789abcdef" end
            ip_addr := execution_environment.item("TUYA_IP")
            if ip_addr.is_empty then ip_addr := "192.168.1.100" end
            ver := execution_environment.item("TUYA_VERSION")
            if ver.is_empty then ver := "3.4" end

            print("seatuya version: " + (create {SEATUYA_DEVICE}).version + "%N")

            create dev.make
            dev.handle := dev.create_with(did, ip_addr, key, ver)
            if dev.handle = default_pointer then
                io.error.put_string("ERROR: Could not create device handle%N")
                {EXIT}.die_with_code(1)
            end

            print("Connected: " + dev.is_connected.out + "%N")
            print("turn_on: " + dev.turn_on(1) + "%N")
            print("status: " + dev.status + "%N")
            print("turn_off: " + dev.turn_off(1) + "%N")

            dev.destroy
            print("Done.%N")
        end
end
