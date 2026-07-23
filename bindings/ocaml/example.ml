(* example.ml -- demonstrate libseatuya via OCaml ctypes *)

let () =
  let did = try Sys.getenv "TUYA_DEVICE_ID" with _ -> "0123456789abcdef01234567" in
  let key = try Sys.getenv "TUYA_LOCAL_KEY" with _ -> "0123456789abcdef" in
  let ip  = try Sys.getenv "TUYA_IP"        with _ -> "192.168.1.100" in
  let ver = try Sys.getenv "TUYA_VERSION"    with _ -> "3.4" in

  Printf.printf "seatuya version: %s\n" (Seatuya.version ());

  match Seatuya.create did ip key ver with
  | None ->
      Printf.eprintf "ERROR: Could not create device handle\n";
      exit 1
  | Some dev ->
      Printf.printf "Connected: %B\n" (Seatuya.is_connected dev);
      Printf.printf "turn_on: %s\n" (Seatuya.turn_on dev 1);
      Printf.printf "status: %s\n" (Seatuya.status dev);
      Printf.printf "turn_off: %s\n" (Seatuya.turn_off dev 1);

      (* Type-aware dispatcher *)
      ignore (Seatuya.set_value dev 1 (Bool true));
      ignore (Seatuya.set_value dev 2 (Int 25));
      ignore (Seatuya.set_value dev 3 (String "hello"));
      ignore (Seatuya.set_value dev 4 (Float 23.5));

      Seatuya.destroy dev;
      Printf.printf "Done.\n"
