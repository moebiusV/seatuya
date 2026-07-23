-- seatuya.adb -- Ada convenience wrappers for libseatuya
--
-- Thin wrappers around the C imports that handle string ownership
-- (malloc'd C strings → Ada strings, with automatic free).

with Ada.Text_IO;
with Interfaces.C.Strings;

package body Seatuya is

   package CS renames Interfaces.C.Strings;

   -- Helper: consume a malloc'd C string into an Ada String, freeing it
   function Consume_C_String (Ptr : CS.chars_ptr) return String is
   begin
      if Ptr = CS.Null_Ptr then
         return "";
      end if;
      declare
         Result : constant String := CS.Value (Ptr);
      begin
         CS.Free (Ptr);
         return Result;
      end;
   end Consume_C_String;

   -- Low-level C imports
   function C_tuya_version return CS.chars_ptr
      with Import, Convention => C, External_Name => "tuya_version";

   function C_tuya_create (Device_Id, Address, Local_Key, Ver : CS.chars_ptr)
                           return Tuya_Device_Access
      with Import, Convention => C, External_Name => "tuya_create";

   function C_tuya_alloc (Ver : CS.chars_ptr) return Tuya_Device_Access
      with Import, Convention => C, External_Name => "tuya_alloc";

   procedure C_tuya_destroy (Dev : Tuya_Device_Access)
      with Import, Convention => C, External_Name => "tuya_destroy";

   procedure C_tuya_set_credentials (Dev : Tuya_Device_Access;
                                     Device_Id, Local_Key : CS.chars_ptr)
      with Import, Convention => C, External_Name => "tuya_set_credentials";

   function C_tuya_get_device_id (Dev : Tuya_Device_Access) return CS.chars_ptr
      with Import, Convention => C, External_Name => "tuya_get_device_id";

   function C_tuya_get_local_key (Dev : Tuya_Device_Access) return CS.chars_ptr
      with Import, Convention => C, External_Name => "tuya_get_local_key";

   function C_tuya_get_ip (Dev : Tuya_Device_Access) return CS.chars_ptr
      with Import, Convention => C, External_Name => "tuya_get_ip";

   function C_tuya_connect (Dev : Tuya_Device_Access; Hostname : CS.chars_ptr)
                            return C.int
      with Import, Convention => C, External_Name => "tuya_connect";

   procedure C_tuya_disconnect (Dev : Tuya_Device_Access)
      with Import, Convention => C, External_Name => "tuya_disconnect";

   function C_tuya_is_connected (Dev : Tuya_Device_Access) return C.int
      with Import, Convention => C, External_Name => "tuya_is_connected";

   function C_tuya_reconnect (Dev : Tuya_Device_Access) return C.int
      with Import, Convention => C, External_Name => "tuya_reconnect";

   procedure C_tuya_set_retry_limit (Dev : Tuya_Device_Access; Limit : C.int)
      with Import, Convention => C, External_Name => "tuya_set_retry_limit";

   procedure C_tuya_set_retry_delay (Dev : Tuya_Device_Access; Delay_Ms : C.int)
      with Import, Convention => C, External_Name => "tuya_set_retry_delay";

   function C_tuya_get_retry_limit (Dev : Tuya_Device_Access) return C.int
      with Import, Convention => C, External_Name => "tuya_get_retry_limit";

   function C_tuya_get_retry_delay (Dev : Tuya_Device_Access) return C.int
      with Import, Convention => C, External_Name => "tuya_get_retry_delay";

   function C_tuya_negotiate_session (Dev : Tuya_Device_Access; Key : CS.chars_ptr)
                                      return C.int
      with Import, Convention => C, External_Name => "tuya_negotiate_session";

   function C_tuya_negotiate_session_start (Dev : Tuya_Device_Access;
                                            Key : CS.chars_ptr) return C.int
      with Import, Convention => C, External_Name => "tuya_negotiate_session_start";

   function C_tuya_negotiate_session_finalize (Dev : Tuya_Device_Access;
                                               Buf : CS.chars_ptr;
                                               Size : C.int;
                                               Key : CS.chars_ptr) return C.int
      with Import, Convention => C, External_Name => "tuya_negotiate_session_finalize";

   function C_tuya_get_protocol (Dev : Tuya_Device_Access) return C.int
      with Import, Convention => C, External_Name => "tuya_get_protocol";

   function C_tuya_get_session_state (Dev : Tuya_Device_Access) return C.int
      with Import, Convention => C, External_Name => "tuya_get_session_state";

   function C_tuya_get_socket_state (Dev : Tuya_Device_Access) return C.int
      with Import, Convention => C, External_Name => "tuya_get_socket_state";

   function C_tuya_get_last_error (Dev : Tuya_Device_Access) return C.int
      with Import, Convention => C, External_Name => "tuya_get_last_error";

   procedure C_tuya_set_async_mode (Dev : Tuya_Device_Access; Flag : C.int)
      with Import, Convention => C, External_Name => "tuya_set_async_mode";

   function C_tuya_is_socket_readable (Dev : Tuya_Device_Access) return C.int
      with Import, Convention => C, External_Name => "tuya_is_socket_readable";

   function C_tuya_is_socket_writable (Dev : Tuya_Device_Access) return C.int
      with Import, Convention => C, External_Name => "tuya_is_socket_writable";

   function C_tuya_set_session_ready (Dev : Tuya_Device_Access) return C.int
      with Import, Convention => C, External_Name => "tuya_set_session_ready";

   function C_tuya_build_message (Dev : Tuya_Device_Access;
                                  Buf : CS.chars_ptr;
                                  Cmd : C.int;
                                  Payload, Key : CS.chars_ptr) return C.int
      with Import, Convention => C, External_Name => "tuya_build_message";

   function C_tuya_decode_message (Dev : Tuya_Device_Access;
                                   Buf : CS.chars_ptr;
                                   Size : C.int;
                                   Key : CS.chars_ptr) return CS.chars_ptr
      with Import, Convention => C, External_Name => "tuya_decode_message";

   function C_tuya_generate_payload (Dev : Tuya_Device_Access;
                                     Cmd : C.int;
                                     Device_Id, Datapoints : CS.chars_ptr)
                                     return CS.chars_ptr
      with Import, Convention => C, External_Name => "tuya_generate_payload";

   function C_tuya_send (Dev : Tuya_Device_Access; Buf : CS.chars_ptr;
                         Size : C.int) return C.int
      with Import, Convention => C, External_Name => "tuya_send";

   function C_tuya_receive (Dev : Tuya_Device_Access;
                            Buf : CS.chars_ptr;
                            Maxsize, Minsize : C.int) return C.int
      with Import, Convention => C, External_Name => "tuya_receive";

   function C_tuya_set_value_bool (Dev : Tuya_Device_Access;
                                   Dp : C.int; Value : C.int)
                                   return CS.chars_ptr
      with Import, Convention => C, External_Name => "tuya_set_value_bool";

   function C_tuya_set_value_int (Dev : Tuya_Device_Access;
                                  Dp, Value : C.int) return CS.chars_ptr
      with Import, Convention => C, External_Name => "tuya_set_value_int";

   function C_tuya_set_value_string (Dev : Tuya_Device_Access;
                                     Dp : C.int; Value : CS.chars_ptr)
                                     return CS.chars_ptr
      with Import, Convention => C, External_Name => "tuya_set_value_string";

   function C_tuya_set_value_float (Dev : Tuya_Device_Access;
                                    Dp : C.int; Value : C.double)
                                    return CS.chars_ptr
      with Import, Convention => C, External_Name => "tuya_set_value_float";

   function C_tuya_turn_on (Dev : Tuya_Device_Access; Switch_Dp : C.int)
                            return CS.chars_ptr
      with Import, Convention => C, External_Name => "tuya_turn_on";

   function C_tuya_turn_off (Dev : Tuya_Device_Access; Switch_Dp : C.int)
                             return CS.chars_ptr
      with Import, Convention => C, External_Name => "tuya_turn_off";

   function C_tuya_status (Dev : Tuya_Device_Access) return CS.chars_ptr
      with Import, Convention => C, External_Name => "tuya_status";

   function C_tuya_heartbeat (Dev : Tuya_Device_Access) return CS.chars_ptr
      with Import, Convention => C, External_Name => "tuya_heartbeat";

   procedure C_tuya_free_string (Str : CS.chars_ptr)
      with Import, Convention => C, External_Name => "tuya_free_string";

   procedure C_tuya_set_device22 (Dev : Tuya_Device_Access;
                                  Null_Dps_Json : CS.chars_ptr)
      with Import, Convention => C, External_Name => "tuya_set_device22";

   function C_tuya_is_device22 (Dev : Tuya_Device_Access) return C.int
      with Import, Convention => C, External_Name => "tuya_is_device22";

   -- Public implementations

   function Version return String is
   begin
      return CS.Value (C_tuya_version);
   end Version;

   function Create (Device_Id, Address, Local_Key, Ver : String)
                    return Tuya_Device_Access is
   begin
      return C_tuya_create
        (CS.New_String (Device_Id),
         CS.New_String (Address),
         CS.New_String (Local_Key),
         CS.New_String (Ver));
   end Create;

   function Alloc (Ver : String) return Tuya_Device_Access is
   begin
      return C_tuya_alloc (CS.New_String (Ver));
   end Alloc;

   procedure Destroy (Dev : in out Tuya_Device_Access) is
   begin
      C_tuya_destroy (Dev);
      Dev := null;
   end Destroy;

   procedure Set_Credentials (Dev : Tuya_Device_Access;
                              Device_Id, Local_Key : String) is
   begin
      C_tuya_set_credentials (Dev,
         CS.New_String (Device_Id), CS.New_String (Local_Key));
   end Set_Credentials;

   function Get_Device_Id (Dev : Tuya_Device_Access) return String is
   begin
      return CS.Value (C_tuya_get_device_id (Dev));
   end Get_Device_Id;

   function Get_Local_Key (Dev : Tuya_Device_Access) return String is
   begin
      return CS.Value (C_tuya_get_local_key (Dev));
   end Get_Local_Key;

   function Get_IP (Dev : Tuya_Device_Access) return String is
   begin
      return CS.Value (C_tuya_get_ip (Dev));
   end Get_IP;

   function Connect (Dev : Tuya_Device_Access; Hostname : String)
                     return Boolean is
   begin
      return C_tuya_connect (Dev, CS.New_String (Hostname)) /= 0;
   end Connect;

   procedure Disconnect (Dev : Tuya_Device_Access) is
   begin
      C_tuya_disconnect (Dev);
   end Disconnect;

   function Is_Connected (Dev : Tuya_Device_Access) return Boolean is
   begin
      return C_tuya_is_connected (Dev) /= 0;
   end Is_Connected;

   function Reconnect (Dev : Tuya_Device_Access) return Boolean is
   begin
      return C_tuya_reconnect (Dev) /= 0;
   end Reconnect;

   procedure Set_Retry_Limit (Dev : Tuya_Device_Access; Limit : Integer) is
   begin
      C_tuya_set_retry_limit (Dev, C.int (Limit));
   end Set_Retry_Limit;

   procedure Set_Retry_Delay (Dev : Tuya_Device_Access; Delay_Ms : Integer) is
   begin
      C_tuya_set_retry_delay (Dev, C.int (Delay_Ms));
   end Set_Retry_Delay;

   function Get_Retry_Limit (Dev : Tuya_Device_Access) return Integer is
   begin
      return Integer (C_tuya_get_retry_limit (Dev));
   end Get_Retry_Limit;

   function Get_Retry_Delay (Dev : Tuya_Device_Access) return Integer is
   begin
      return Integer (C_tuya_get_retry_delay (Dev));
   end Get_Retry_Delay;

   function Negotiate_Session (Dev : Tuya_Device_Access; Key : String)
                               return Boolean is
   begin
      return C_tuya_negotiate_session (Dev, CS.New_String (Key)) /= 0;
   end Negotiate_Session;

   function Negotiate_Session_Start (Dev : Tuya_Device_Access; Key : String)
                                     return Boolean is
   begin
      return C_tuya_negotiate_session_start (Dev, CS.New_String (Key)) /= 0;
   end Negotiate_Session_Start;

   function Negotiate_Session_Finalize (Dev : Tuya_Device_Access;
                                        Buf : CS.chars_ptr;
                                        Size : Integer; Key : String)
                                        return Boolean is
   begin
      return C_tuya_negotiate_session_finalize
               (Dev, Buf, C.int (Size), CS.New_String (Key)) /= 0;
   end Negotiate_Session_Finalize;

   function Get_Protocol (Dev : Tuya_Device_Access) return Tuya_Protocol is
   begin
      return Tuya_Protocol'Val (C_tuya_get_protocol (Dev));
   end Get_Protocol;

   function Get_Session_State (Dev : Tuya_Device_Access)
                               return Tuya_Session_State is
   begin
      return Tuya_Session_State'Val (C_tuya_get_session_state (Dev));
   end Get_Session_State;

   function Get_Socket_State (Dev : Tuya_Device_Access)
                              return Tuya_Socket_State is
   begin
      return Tuya_Socket_State'Val (C_tuya_get_socket_state (Dev));
   end Get_Socket_State;

   function Get_Last_Error (Dev : Tuya_Device_Access) return Integer is
   begin
      return Integer (C_tuya_get_last_error (Dev));
   end Get_Last_Error;

   procedure Set_Async_Mode (Dev : Tuya_Device_Access; Flag : Boolean) is
   begin
      C_tuya_set_async_mode (Dev, Boolean'Pos (Flag));
   end Set_Async_Mode;

   function Is_Socket_Readable (Dev : Tuya_Device_Access) return Boolean is
   begin
      return C_tuya_is_socket_readable (Dev) /= 0;
   end Is_Socket_Readable;

   function Is_Socket_Writable (Dev : Tuya_Device_Access) return Boolean is
   begin
      return C_tuya_is_socket_writable (Dev) /= 0;
   end Is_Socket_Writable;

   function Set_Session_Ready (Dev : Tuya_Device_Access) return Boolean is
   begin
      return C_tuya_set_session_ready (Dev) /= 0;
   end Set_Session_Ready;

   function Build_Message (Dev : Tuya_Device_Access;
                           Buf : out CS.chars_ptr;
                           Cmd : Tuya_Command;
                           Payload, Key : String) return Integer is
      B : constant CS.chars_ptr := CS.New_Char_Array
            ((1 .. Recommended_Bufsize => C.nul));
   begin
      Buf := B;
      return Integer (C_tuya_build_message (Dev, B, C.int (Tuya_Command'Pos (Cmd)),
                      CS.New_String (Payload), CS.New_String (Key)));
   end Build_Message;

   function Decode_Message (Dev : Tuya_Device_Access;
                            Buf : CS.chars_ptr;
                            Size : Integer; Key : String) return String is
   begin
      return Consume_C_String
        (C_tuya_decode_message (Dev, Buf, C.int (Size), CS.New_String (Key)));
   end Decode_Message;

   function Generate_Payload (Dev : Tuya_Device_Access;
                              Cmd : Tuya_Command;
                              Device_Id, Datapoints : String)
                              return String is
   begin
      return Consume_C_String
        (C_tuya_generate_payload (Dev, C.int (Tuya_Command'Pos (Cmd)),
         CS.New_String (Device_Id), CS.New_String (Datapoints)));
   end Generate_Payload;

   function Send_Frame (Dev : Tuya_Device_Access;
                        Buf : CS.chars_ptr;
                        Size : Integer) return Integer is
   begin
      return Integer (C_tuya_send (Dev, Buf, C.int (Size)));
   end Send_Frame;

   function Receive_Frame (Dev : Tuya_Device_Access;
                           Buf : out CS.chars_ptr;
                           Maxsize, Minsize : Integer) return Integer is
      B : constant CS.chars_ptr := CS.New_Char_Array
            ((1 .. Maxsize => C.nul));
   begin
      Buf := B;
      return Integer (C_tuya_receive (Dev, B, C.int (Maxsize), C.int (Minsize)));
   end Receive_Frame;

   function Set_Value_Bool (Dev : Tuya_Device_Access; Dp : Integer;
                            Value : Boolean) return String is
   begin
      return Consume_C_String
        (C_tuya_set_value_bool (Dev, C.int (Dp), Boolean'Pos (Value)));
   end Set_Value_Bool;

   function Set_Value_Int (Dev : Tuya_Device_Access; Dp, Value : Integer)
                           return String is
   begin
      return Consume_C_String
        (C_tuya_set_value_int (Dev, C.int (Dp), C.int (Value)));
   end Set_Value_Int;

   function Set_Value_String (Dev : Tuya_Device_Access; Dp : Integer;
                              Value : String) return String is
   begin
      return Consume_C_String
        (C_tuya_set_value_string (Dev, C.int (Dp), CS.New_String (Value)));
   end Set_Value_String;

   function Set_Value_Float (Dev : Tuya_Device_Access; Dp : Integer;
                             Value : Long_Float) return String is
   begin
      return Consume_C_String
        (C_tuya_set_value_float (Dev, C.int (Dp), C.double (Value)));
   end Set_Value_Float;

   function Turn_On (Dev : Tuya_Device_Access; Switch_Dp : Integer)
                     return String is
   begin
      return Consume_C_String (C_tuya_turn_on (Dev, C.int (Switch_Dp)));
   end Turn_On;

   function Turn_Off (Dev : Tuya_Device_Access; Switch_Dp : Integer)
                      return String is
   begin
      return Consume_C_String (C_tuya_turn_off (Dev, C.int (Switch_Dp)));
   end Turn_Off;

   function Status (Dev : Tuya_Device_Access) return String is
   begin
      return Consume_C_String (C_tuya_status (Dev));
   end Status;

   function Heartbeat (Dev : Tuya_Device_Access) return String is
   begin
      return Consume_C_String (C_tuya_heartbeat (Dev));
   end Heartbeat;

   procedure Free_String (Str : in out CS.chars_ptr) is
   begin
      C_tuya_free_string (Str);
      Str := CS.Null_Ptr;
   end Free_String;

   procedure Set_Device22 (Dev : Tuya_Device_Access;
                           Null_Dps_Json : String) is
   begin
      C_tuya_set_device22 (Dev, CS.New_String (Null_Dps_Json));
   end Set_Device22;

   function Is_Device22 (Dev : Tuya_Device_Access) return Boolean is
   begin
      return C_tuya_is_device22 (Dev) /= 0;
   end Is_Device22;

end Seatuya;
