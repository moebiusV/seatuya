# seatuya.l -- PicoLisp FFI bindings for libseatuya
#
# PicoLisp has a built-in (native ...) function for calling shared
# libraries.  This module imports every public function and provides
# convenience wrappers that handle string ownership and type dispatch.
#
# Usage:
#   (load "seatuya.l")
#   (setq Dev (seatuya~>create "3.3"))
#   (seatuya~>set-credentials Dev "device-id" "local-key")
#   (seatuya~>connect Dev "192.168.1.50")
#   (seatuya~>set-value Dev 1 T)
#   (seatuya~>destroy Dev)

### Library path ###
(setq *SeatuyaLib
   (or (sys "SEATUYA_LIB")
       (case (car (sys "uname"))
         (Darwin "libseatuya.dylib")
         (T "libseatuya.so") ) ) )

### Raw C imports ###

(native *SeatuyaLib "tuya_version" 'S)

(native *SeatuyaLib "tuya_create" 'N "tuya_create" 'S 'S 'S 'S)
(native *SeatuyaLib "tuya_alloc" 'N "tuya_alloc" 'S)
(native *SeatuyaLib "tuya_destroy" NIL "tuya_destroy" 'N)

(native *SeatuyaLib "tuya_set_credentials" NIL "tuya_set_credentials" 'N 'S 'S)
(native *SeatuyaLib "tuya_get_device_id" 'S "tuya_get_device_id" 'N)
(native *SeatuyaLib "tuya_get_local_key" 'S "tuya_get_local_key" 'N)
(native *SeatuyaLib "tuya_get_ip" 'S "tuya_get_ip" 'N)

(native *SeatuyaLib "tuya_connect" 'I "tuya_connect" 'N 'S)
(native *SeatuyaLib "tuya_disconnect" NIL "tuya_disconnect" 'N)
(native *SeatuyaLib "tuya_is_connected" 'I "tuya_is_connected" 'N)
(native *SeatuyaLib "tuya_reconnect" 'I "tuya_reconnect" 'N)

(native *SeatuyaLib "tuya_set_retry_limit" NIL "tuya_set_retry_limit" 'N 'I)
(native *SeatuyaLib "tuya_set_retry_delay" NIL "tuya_set_retry_delay" 'N 'I)
(native *SeatuyaLib "tuya_get_retry_limit" 'I "tuya_get_retry_limit" 'N)
(native *SeatuyaLib "tuya_get_retry_delay" 'I "tuya_get_retry_delay" 'N)

(native *SeatuyaLib "tuya_negotiate_session" 'I "tuya_negotiate_session" 'N 'S)
(native *SeatuyaLib "tuya_negotiate_session_start" 'I "tuya_negotiate_session_start" 'N 'S)
(native *SeatuyaLib "tuya_negotiate_session_finalize" 'I "tuya_negotiate_session_finalize" 'N 'B 'I 'S)

(native *SeatuyaLib "tuya_get_protocol" 'I "tuya_get_protocol" 'N)
(native *SeatuyaLib "tuya_get_session_state" 'I "tuya_get_session_state" 'N)
(native *SeatuyaLib "tuya_get_socket_state" 'I "tuya_get_socket_state" 'N)
(native *SeatuyaLib "tuya_get_last_error" 'I "tuya_get_last_error" 'N)

(native *SeatuyaLib "tuya_set_async_mode" NIL "tuya_set_async_mode" 'N 'I)
(native *SeatuyaLib "tuya_is_socket_readable" 'I "tuya_is_socket_readable" 'N)
(native *SeatuyaLib "tuya_is_socket_writable" 'I "tuya_is_socket_writable" 'N)
(native *SeatuyaLib "tuya_set_session_ready" 'I "tuya_set_session_ready" 'N)

(native *SeatuyaLib "tuya_build_message" 'I "tuya_build_message" 'N 'B 'I 'S 'S)
(native *SeatuyaLib "tuya_decode_message" 'S "tuya_decode_message" 'N 'B 'I 'S)
(native *SeatuyaLib "tuya_generate_payload" 'S "tuya_generate_payload" 'N 'I 'S 'S)

(native *SeatuyaLib "tuya_send" 'I "tuya_send" 'N 'B 'I)
(native *SeatuyaLib "tuya_receive" 'I "tuya_receive" 'N 'B 'I 'I)

(native *SeatuyaLib "tuya_set_value_bool" 'S "tuya_set_value_bool" 'N 'I 'I)
(native *SeatuyaLib "tuya_set_value_int" 'S "tuya_set_value_int" 'N 'I 'I)
(native *SeatuyaLib "tuya_set_value_string" 'S "tuya_set_value_string" 'N 'I 'S)
(native *SeatuyaLib "tuya_set_value_float" 'S "tuya_set_value_float" 'N 'I 'F)

(native *SeatuyaLib "tuya_turn_on" 'S "tuya_turn_on" 'N 'I)
(native *SeatuyaLib "tuya_turn_off" 'S "tuya_turn_off" 'N 'I)
(native *SeatuyaLib "tuya_status" 'S "tuya_status" 'N)
(native *SeatuyaLib "tuya_heartbeat" 'S "tuya_heartbeat" 'N)

(native *SeatuyaLib "tuya_free_string" NIL "tuya_free_string" 'S)

(native *SeatuyaLib "tuya_set_device22" NIL "tuya_set_device22" 'N 'S)
(native *SeatuyaLib "tuya_is_device22" 'I "tuya_is_device22" 'N)

### Constants ###

(setq
   *CmdUDP                  0
   *CmdAPConfig             1
   *CmdActive               2
   *CmdBind                 3
   *CmdRenameGW             4
   *CmdRenameDevice         5
   *CmdUnbind               6
   *CmdControl              7
   *CmdStatus               8
   *CmdHeartBeat            9
   *CmdDPQuery             10
   *CmdQueryWiFi           11
   *CmdTokenBind           12
   *CmdControlNew          13
   *CmdEnableWiFi          14
   *CmdDPQueryNew          16
   *CmdSceneExecute        17
   *CmdUpdateDPS           18
   *CmdUDPNew              19
   *CmdAPConfigNew         20
   *CmdGetLocalTime        28
   *CmdWeatherOpen         32
   *CmdWeatherData         33
   *CmdStateUploadSyn      34
   *CmdStateUploadSynRecv  35
   *CmdHeartBeatStop       37
   *CmdStreamTrans         38
   *CmdGetWiFiStatus       43
   *CmdWiFiConnectTest     44
   *CmdGetMAC              45
   *CmdGetIRStatus         46
   *CmdIRTXTest            47
   *CmdLanGWActive        240
   *CmdLanSubDevRequest   241
   *CmdLanDeleteSubDev    242
   *CmdLanReportSubDev    243
   *CmdLanScene           244
   *CmdLanPubCloudCfg     245
   *CmdLanPubAppCfg       246
   *CmdLanExportAppCfg    247
   *CmdLanPubScenePanel   248
   *CmdLanRemoveGW        249
   *CmdLanCheckGWUpdate   250
   *CmdLanGWUpdate        251
   *CmdLanSetGWChannel    252 )

### Convenience wrappers ###

(class +Seatuya)

(dm version> ()
   (tuya_version) )

(dm create> (DeviceId Address LocalKey Version)
   (let (Ptr (tuya_create DeviceId Address LocalKey Version))
      (if (=0 Ptr) NIL Ptr) ) )

(dm alloc> (Version)
   (let (Ptr (tuya_alloc Version))
      (if (=0 Ptr) NIL Ptr) ) )

(dm destroy> (Dev)
   (tuya_destroy Dev) )

(dm set-credentials> (Dev DeviceId LocalKey)
   (tuya_set_credentials Dev DeviceId LocalKey) )

(dm get-device-id> (Dev)
   (tuya_get_device_id Dev) )

(dm get-local-key> (Dev)
   (tuya_get_local_key Dev) )

(dm get-ip> (Dev)
   (tuya_get_ip Dev) )

(dm connect> (Dev Hostname)
   (not (=0 (tuya_connect Dev Hostname))) )

(dm disconnect> (Dev)
   (tuya_disconnect Dev) )

(dm is-connected> (Dev)
   (not (=0 (tuya_is_connected Dev))) )

(dm reconnect> (Dev)
   (not (=0 (tuya_reconnect Dev))) )

(dm set-retry-limit> (Dev Limit)
   (tuya_set_retry_limit Dev Limit) )

(dm set-retry-delay> (Dev MS)
   (tuya_set_retry_delay Dev MS) )

(dm get-retry-limit> (Dev)
   (tuya_get_retry_limit Dev) )

(dm get-retry-delay> (Dev)
   (tuya_get_retry_delay Dev) )

(dm negotiate-session> (Dev Key)
   (not (=0 (tuya_negotiate_session Dev Key))) )

(dm negotiate-session-start> (Dev Key)
   (not (=0 (tuya_negotiate_session_start Dev Key))) )

(dm negotiate-session-finalize> (Dev Buf Key)
   (not (=0 (tuya_negotiate_session_finalize Dev Buf (length Buf) Key))) )

(dm get-protocol> (Dev)
   (tuya_get_protocol Dev) )

(dm get-session-state> (Dev)
   (tuya_get_session_state Dev) )

(dm get-socket-state> (Dev)
   (tuya_get_socket_state Dev) )

(dm get-last-error> (Dev)
   (tuya_get_last_error Dev) )

### Low-level message functions ###

(dm build-message> (Dev Cmd Payload Key)
   (let (Buf (need 1024 0)
         N   (tuya_build_message Dev Buf Cmd Payload Key))
      (if (> N 0) (head N Buf) NIL) ) )

(dm decode-message> (Dev Buf Key)
   (tuya_decode_message Dev Buf (length Buf) Key) )

(dm generate-payload> (Dev Cmd DeviceId Dps)
   (tuya_generate_payload Dev Cmd DeviceId (or Dps "")) )

(dm send> (Dev Buf)
   (tuya_send Dev Buf (length Buf)) )

(dm receive> (Dev MaxSize MinSize)
   (let (Buf (need (or MaxSize 1024) 0)
         N   (tuya_receive Dev Buf (or MaxSize 1024) (or MinSize 0)))
      (if (> N 0) (head N Buf) NIL) ) )

### High-level round-trip functions ###

(dm set-value> (Dev Dp Value)
   (let (Ptr
      (cond
         ((=T Value)    (tuya_set_value_bool Dev Dp 1))
         ((not Value)   (tuya_set_value_bool Dev Dp 0))
         ((num? Value)  (if (flg? Value)
                           (tuya_set_value_float Dev Dp Value)
                           (tuya_set_value_int Dev Dp Value) ))
         (T             (tuya_set_value_string Dev Dp Value)) ) )
      (if (=0 Ptr) NIL (prog1 (str Ptr) (tuya_free_string Ptr))) ) )

(dm turn-on> (Dev SwitchDp)
   (let (Ptr (tuya_turn_on Dev (or SwitchDp 1)))
      (if (=0 Ptr) NIL (prog1 (str Ptr) (tuya_free_string Ptr))) ) )

(dm turn-off> (Dev SwitchDp)
   (let (Ptr (tuya_turn_off Dev (or SwitchDp 1)))
      (if (=0 Ptr) NIL (prog1 (str Ptr) (tuya_free_string Ptr))) ) )

(dm status> (Dev)
   (let (Ptr (tuya_status Dev))
      (if (=0 Ptr) NIL (prog1 (str Ptr) (tuya_free_string Ptr))) ) )

(dm heartbeat> (Dev)
   (let (Ptr (tuya_heartbeat Dev))
      (if (=0 Ptr) NIL (prog1 (str Ptr) (tuya_free_string Ptr))) ) )

(dm set-device22> (Dev NullDpsJson)
   (tuya_set_device22 Dev (or NullDpsJson NIL)) )

(dm is-device22> (Dev)
   (not (=0 (tuya_is_device22 Dev))) )

(dm set-async-mode> (Dev Flag)
   (tuya_set_async_mode Dev (if Flag 1 0)) )

(dm is-readable> (Dev)
   (not (=0 (tuya_is_socket_readable Dev))) )

(dm is-writable> (Dev)
   (not (=0 (tuya_is_socket_writable Dev))) )

(dm session-ready> (Dev)
   (not (=0 (tuya_set_session_ready Dev))) )

### Singleton instance for use as seatuya~>function ###
(setq seatuya (new '+Seatuya))
