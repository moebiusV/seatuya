-- seatuya_test.adb -- test driver for the Ada bindings
--
-- Build: gnatmake -I. seatuya_test.adb -largs -L../../src/.libs -lseatuya
--
-- Demonstrates creating a device handle, turning a switch on/off,
-- querying status, and shutting down.

with Ada.Text_IO;
with Ada.Command_Line;
with Ada.Environment_Variables;
with Seatuya; use Seatuya;

procedure Seatuya_Test is
   package TIO renames Ada.Text_IO;
   package CLI renames Ada.Command_Line;
   package ENV renames Ada.Environment_Variables;

   Device_Id : constant String :=
     (if ENV.Exists ("TUYA_DEVICE_ID") then ENV.Value ("TUYA_DEVICE_ID")
      else "0123456789abcdef01234567");
   Local_Key : constant String :=
     (if ENV.Exists ("TUYA_LOCAL_KEY") then ENV.Value ("TUYA_LOCAL_KEY")
      else "0123456789abcdef");
   Ip : constant String :=
     (if ENV.Exists ("TUYA_IP") then ENV.Value ("TUYA_IP")
      else "192.168.1.100");
   Version_Str : constant String :=
     (if ENV.Exists ("TUYA_VERSION") then ENV.Value ("TUYA_VERSION")
      else "3.4");
begin
   TIO.Put_Line ("seatuya version: " & Version);

   -- All-in-one create
   declare
      Dev : Tuya_Device_Access := Create (Device_Id, Ip, Local_Key, Version_Str);
   begin
      if Dev = null then
         TIO.Put_Line ("ERROR: Could not create device handle");
         CLI.Set_Exit_Status (CLI.Failure);
         return;
      end if;

      TIO.Put_Line ("Connected: " & Boolean'Image (Is_Connected (Dev)));
      TIO.Put_Line ("Protocol: " & Tuya_Protocol'Image (Get_Protocol (Dev)));

      -- Turn on switch (data point 1)
      TIO.Put_Line ("turn_on: " & Turn_On (Dev, 1));

      -- Query all data points
      TIO.Put_Line ("status: " & Status (Dev));

      -- Turn off switch
      TIO.Put_Line ("turn_off: " & Turn_Off (Dev, 1));

      -- Cardiac signal
      TIO.Put_Line ("heartbeat: " & Heartbeat (Dev));

      Destroy (Dev);
      TIO.Put_Line ("Done.");
   end;
exception
   when others =>
      TIO.Put_Line ("Unexpected error");
      CLI.Set_Exit_Status (CLI.Failure);
end Seatuya_Test;
