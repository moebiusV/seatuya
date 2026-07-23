# Ada/SPARK Bindings for libseatuya

Pure Ada binding using `pragma Import(C, ...)` for every function
in libseatuya.  The package spec (`seatuya.ads`) declares all types,
enums, and subprograms; the body (`seatuya.adb`) provides convenience
wrappers that handle string ownership (malloc'd C strings are consumed
into Ada strings).

## Prerequisites

- GNAT (GNU Ada compiler) 2020 or later
- libseatuya installed (`make install`)

## Building the test

```sh
gnatmake -I. seatuya_test.adb -largs -lseatuya
```

## Usage

```ada
with Seatuya; use Seatuya;

Dev : Tuya_Device_Access := Create(Device_Id, Ip, Local_Key, "3.4");

-- Typed setters
Ada.Text_IO.Put_Line (Set_Value_Bool (Dev, 1, True));
Ada.Text_IO.Put_Line (Set_Value_Int (Dev, 2, 25));
Ada.Text_IO.Put_Line (Set_Value_String (Dev, 3, "hello"));
Ada.Text_IO.Put_Line (Set_Value_Float (Dev, 4, 23.5));

-- Convenience wrappers
Ada.Text_IO.Put_Line (Turn_On (Dev, 1));
Ada.Text_IO.Put_Line (Status (Dev));
Ada.Text_IO.Put_Line (Turn_Off (Dev, 1));

Destroy (Dev);
```

## API

See the [seatuya(3)](../../seatuya.3) manpage for the full C API reference.
Every C function is declared in the Ada spec with corresponding types.
String ownership is managed: functions returning `String` are safe Ada
strings (the underlying malloc'd C string is automatically freed).
