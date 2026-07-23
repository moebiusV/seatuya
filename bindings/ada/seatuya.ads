-- seatuya.ads -- Ada/SPARK binding for libseatuya
--
-- Pure Ada package spec using pragma Import(C, ...) for every
-- public function in libseatuya.  All C types are mapped to
-- Ada types; no C++ types cross the boundary.
--
-- Usage:
--   with Seatuya; use Seatuya;
--   Dev : Tuya_Device_Access := Create(Id, Addr, Key, Ver);
--   Response := Turn_On(Dev, 1);
--   Destroy(Dev);

with Interfaces.C;
with Interfaces.C.Strings;
with System;

package Seatuya is

   package C renames Interfaces.C;

   -- Opaque device handle
   type Tuya_Device is private;
   type Tuya_Device_Access is access all Tuya_Device;
   pragma Convention (C, Tuya_Device_Access);

   -- Enums (matching seatuya.h)
   type Tuya_Command is
     (Cmd_UDP,
      Cmd_AP_Config,
      Cmd_Active,
      Cmd_Bind,
      Cmd_Rename_GW,
      Cmd_Rename_Device,
      Cmd_Unbind,
      Cmd_Control,
      Cmd_Status,
      Cmd_Heart_Beat,
      Cmd_DP_Query,
      Cmd_Query_WiFi,
      Cmd_Token_Bind,
      Cmd_Control_New,
      Cmd_Enable_WiFi,
      Cmd_DP_Query_New,
      Cmd_Scene_Execute,
      Cmd_UpdateDPS,
      Cmd_UDP_New,
      Cmd_AP_Config_New,
      Cmd_Get_Local_Time,
      Cmd_Weather_Open,
      Cmd_Weather_Data,
      Cmd_State_Upload_Syn,
      Cmd_State_Upload_Syn_Recv,
      Cmd_Heart_Beat_Stop,
      Cmd_Stream_Trans,
      Cmd_Get_WiFi_Status,
      Cmd_WiFi_Connect_Test,
      Cmd_Get_MAC,
      Cmd_Get_IR_Status,
      Cmd_IR_TX_RX_Test,
      Cmd_LAN_GW_Active,
      Cmd_LAN_Sub_Dev_Request,
      Cmd_LAN_Delete_Sub_Dev,
      Cmd_LAN_Report_Sub_Dev,
      Cmd_LAN_Scene,
      Cmd_LAN_Publish_Cloud_Config,
      Cmd_LAN_Publish_App_Config,
      Cmd_LAN_Export_App_Config,
      Cmd_LAN_Publish_Scene_Panel,
      Cmd_LAN_Remove_GW,
      Cmd_LAN_Check_GW_Update,
      Cmd_LAN_GW_Update,
      Cmd_LAN_Set_GW_Channel);
   for Tuya_Command use
     (Cmd_UDP                       => 0,
      Cmd_AP_Config                  => 1,
      Cmd_Active                     => 2,
      Cmd_Bind                       => 3,
      Cmd_Rename_GW                  => 4,
      Cmd_Rename_Device              => 5,
      Cmd_Unbind                     => 6,
      Cmd_Control                    => 7,
      Cmd_Status                     => 8,
      Cmd_Heart_Beat                 => 9,
      Cmd_DP_Query                   => 10,
      Cmd_Query_WiFi                 => 11,
      Cmd_Token_Bind                 => 12,
      Cmd_Control_New                => 13,
      Cmd_Enable_WiFi                => 14,
      Cmd_DP_Query_New               => 16,
      Cmd_Scene_Execute              => 17,
      Cmd_UpdateDPS                  => 18,
      Cmd_UDP_New                    => 19,
      Cmd_AP_Config_New              => 20,
      Cmd_Get_Local_Time             => 28,
      Cmd_Weather_Open               => 32,
      Cmd_Weather_Data               => 33,
      Cmd_State_Upload_Syn           => 34,
      Cmd_State_Upload_Syn_Recv      => 35,
      Cmd_Heart_Beat_Stop            => 37,
      Cmd_Stream_Trans               => 38,
      Cmd_Get_WiFi_Status            => 43,
      Cmd_WiFi_Connect_Test          => 44,
      Cmd_Get_MAC                    => 45,
      Cmd_Get_IR_Status              => 46,
      Cmd_IR_TX_RX_Test              => 47,
      Cmd_LAN_GW_Active              => 240,
      Cmd_LAN_Sub_Dev_Request        => 241,
      Cmd_LAN_Delete_Sub_Dev         => 242,
      Cmd_LAN_Report_Sub_Dev         => 243,
      Cmd_LAN_Scene                  => 244,
      Cmd_LAN_Publish_Cloud_Config   => 245,
      Cmd_LAN_Publish_App_Config     => 246,
      Cmd_LAN_Export_App_Config      => 247,
      Cmd_LAN_Publish_Scene_Panel    => 248,
      Cmd_LAN_Remove_GW              => 249,
      Cmd_LAN_Check_GW_Update        => 250,
      Cmd_LAN_GW_Update              => 251,
      Cmd_LAN_Set_GW_Channel         => 252);
   pragma Convention (C, Tuya_Command);

   type Tuya_Protocol is (Proto_V31, Proto_V33, Proto_V34, Proto_V35);
   for Tuya_Protocol use (Proto_V31 => 0, Proto_V33 => 1, Proto_V34 => 2, Proto_V35 => 3);
   pragma Convention (C, Tuya_Protocol);

   type Tuya_Session_State is (Session_Invalid, Session_Starting,
                                Session_Finalizing, Session_Established);
   for Tuya_Session_State use (Session_Invalid => 0, Session_Starting => 1,
                                Session_Finalizing => 2, Session_Established => 3);
   pragma Convention (C, Tuya_Session_State);

   type Tuya_Socket_State is (Sock_No_Such_Host, Sock_No_Sock_Avail,
                               Sock_Failed, Sock_Disconnected,
                               Sock_Connecting, Sock_Connected,
                               Sock_Ready, Sock_Receiving);
   for Tuya_Socket_State use (Sock_No_Such_Host => 0, Sock_No_Sock_Avail => 1,
                               Sock_Failed => 2, Sock_Disconnected => 3,
                               Sock_Connecting => 4, Sock_Connected => 5,
                               Sock_Ready => 6, Sock_Receiving => 7);
   pragma Convention (C, Tuya_Socket_State);

   -- Constants
   Default_Port        : constant := 6668;
   Recommended_Bufsize : constant := 1024;
   Default_Retry_Limit : constant := 5;
   Default_Retry_Delay : constant := 100;

   -- Lifecycle
   function Version return String;
   function Create (Device_Id, Address, Local_Key, Ver : String)
                    return Tuya_Device_Access;
   function Alloc (Ver : String) return Tuya_Device_Access;
   procedure Destroy (Dev : in out Tuya_Device_Access);

   -- Credentials
   procedure Set_Credentials (Dev : Tuya_Device_Access;
                              Device_Id, Local_Key : String);
   function Get_Device_Id (Dev : Tuya_Device_Access) return String;
   function Get_Local_Key (Dev : Tuya_Device_Access) return String;
   function Get_IP (Dev : Tuya_Device_Access) return String;

   -- Connection
   function Connect (Dev : Tuya_Device_Access; Hostname : String)
                     return Boolean;
   procedure Disconnect (Dev : Tuya_Device_Access);
   function Is_Connected (Dev : Tuya_Device_Access) return Boolean;
   function Reconnect (Dev : Tuya_Device_Access) return Boolean;

   -- Retry settings
   procedure Set_Retry_Limit (Dev : Tuya_Device_Access; Limit : Integer);
   procedure Set_Retry_Delay (Dev : Tuya_Device_Access; Delay_Ms : Integer);
   function Get_Retry_Limit (Dev : Tuya_Device_Access) return Integer;
   function Get_Retry_Delay (Dev : Tuya_Device_Access) return Integer;

   -- Session negotiation
   function Negotiate_Session (Dev : Tuya_Device_Access; Key : String)
                               return Boolean;
   function Negotiate_Session_Start (Dev : Tuya_Device_Access; Key : String)
                                     return Boolean;
   function Negotiate_Session_Finalize (Dev : Tuya_Device_Access;
                                        Buf : C.Strings.chars_ptr;
                                        Size : Integer; Key : String)
                                        return Boolean;

   -- State queries
   function Get_Protocol (Dev : Tuya_Device_Access) return Tuya_Protocol;
   function Get_Session_State (Dev : Tuya_Device_Access)
                               return Tuya_Session_State;
   function Get_Socket_State (Dev : Tuya_Device_Access)
                              return Tuya_Socket_State;
   function Get_Last_Error (Dev : Tuya_Device_Access) return Integer;

   -- Async mode
   procedure Set_Async_Mode (Dev : Tuya_Device_Access; Flag : Boolean);
   function Is_Socket_Readable (Dev : Tuya_Device_Access) return Boolean;
   function Is_Socket_Writable (Dev : Tuya_Device_Access) return Boolean;
   function Set_Session_Ready (Dev : Tuya_Device_Access) return Boolean;

   -- Message building / decoding
   function Build_Message (Dev : Tuya_Device_Access;
                           Buf : out C.Strings.chars_ptr;
                           Cmd : Tuya_Command;
                           Payload, Key : String) return Integer;
   function Decode_Message (Dev : Tuya_Device_Access;
                            Buf : C.Strings.chars_ptr;
                            Size : Integer; Key : String) return String;
   function Generate_Payload (Dev : Tuya_Device_Access;
                              Cmd : Tuya_Command;
                              Device_Id, Datapoints : String)
                              return String;

   -- Raw send / receive
   function Send_Frame (Dev : Tuya_Device_Access;
                        Buf : C.Strings.chars_ptr;
                        Size : Integer) return Integer;
   function Receive_Frame (Dev : Tuya_Device_Access;
                           Buf : out C.Strings.chars_ptr;
                           Maxsize, Minsize : Integer) return Integer;

   -- High-level round-trip
   function Set_Value_Bool (Dev : Tuya_Device_Access; Dp : Integer;
                            Value : Boolean) return String;
   function Set_Value_Int (Dev : Tuya_Device_Access; Dp, Value : Integer)
                           return String;
   function Set_Value_String (Dev : Tuya_Device_Access; Dp : Integer;
                              Value : String) return String;
   function Set_Value_Float (Dev : Tuya_Device_Access; Dp : Integer;
                             Value : Long_Float) return String;
   function Turn_On (Dev : Tuya_Device_Access; Switch_Dp : Integer)
                     return String;
   function Turn_Off (Dev : Tuya_Device_Access; Switch_Dp : Integer)
                      return String;
   function Status (Dev : Tuya_Device_Access) return String;
   function Heartbeat (Dev : Tuya_Device_Access) return String;

   -- Memory management
   procedure Free_String (Str : in out C.Strings.chars_ptr);

   -- device22 mode
   procedure Set_Device22 (Dev : Tuya_Device_Access;
                           Null_Dps_Json : String);
   function Is_Device22 (Dev : Tuya_Device_Access) return Boolean;

private

   type Tuya_Device is null record;  -- opaque; actual struct in C
   pragma Convention (C_Pass_By_Copy, Tuya_Device);

end Seatuya;
