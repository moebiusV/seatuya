! example.f90 — demonstrate libseatuya via Fortran ISO_C_BINDING
!
! Build: gfortran -lseatuya seatuya.f90 example.f90 -o example

program example
  use, intrinsic :: iso_c_binding
  use seatuya
  implicit none

  character(len=256) :: device_id, local_key, ip, ver
  type(c_ptr) :: dev

  call get_env_default("TUYA_DEVICE_ID", "0123456789abcdef01234567", device_id)
  call get_env_default("TUYA_LOCAL_KEY", "0123456789abcdef", local_key)
  call get_env_default("TUYA_IP",        "192.168.1.100", ip)
  call get_env_default("TUYA_VERSION",    "3.4", ver)

  print *, "seatuya version: ", seatuya_version()

  dev = seatuya_create(trim(device_id), trim(ip), trim(local_key), trim(ver))
  if (.not. c_associated(dev)) then
    write(0,*) "ERROR: Could not create device handle"
    stop 1
  end if

  print *, "Connected: ", seatuya_is_connected(dev)
  print *, "turn_on: ", seatuya_turn_on(dev, 1)
  print *, "status: ", seatuya_status(dev)
  print *, "turn_off: ", seatuya_turn_off(dev, 1)

  call seatuya_destroy(dev)
  print *, "Done."

contains
  subroutine get_env_default(name, def, val)
    character(len=*), intent(in) :: name, def
    character(len=256), intent(out) :: val
    call get_environment_variable(name, val)
    if (len_trim(val) == 0) val = def
  end subroutine
end program
