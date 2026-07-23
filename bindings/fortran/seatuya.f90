! seatuya.f90 — Fortran 2003+ ISO_C_BINDING for libseatuya
!
! Pure Fortran binding using the standard iso_c_binding module.
! Requires Fortran 2003 or later (gfortran 4.3+, ifort 11+, etc.).
!
! Usage:
!   use seatuya
!   type(c_ptr) :: dev
!   dev = seatuya_create("id"//c_null_char, "192.168.1.100"//c_null_char, &
!                        "key"//c_null_char, "3.4"//c_null_char)
!   print *, seatuya_turn_on(dev, 1)
!   call seatuya_destroy(dev)

module seatuya
  use, intrinsic :: iso_c_binding
  implicit none

  ! ── Interface declarations ──
  interface
    function c_tuya_version() bind(c, name="tuya_version")
      import :: c_ptr
      type(c_ptr) :: c_tuya_version
    end function

    function c_tuya_create(did, addr, key, ver) bind(c, name="tuya_create")
      import :: c_ptr, c_char
      character(kind=c_char), intent(in) :: did(*), addr(*), key(*), ver(*)
      type(c_ptr) :: c_tuya_create
    end function

    function c_tuya_alloc(ver) bind(c, name="tuya_alloc")
      import :: c_ptr, c_char
      character(kind=c_char), intent(in) :: ver(*)
      type(c_ptr) :: c_tuya_alloc
    end function

    subroutine c_tuya_destroy(dev) bind(c, name="tuya_destroy")
      import :: c_ptr
      type(c_ptr), value :: dev
    end subroutine

    function c_tuya_connect(dev, host) bind(c, name="tuya_connect")
      import :: c_ptr, c_int, c_char
      type(c_ptr), value :: dev
      character(kind=c_char), intent(in) :: host(*)
      integer(c_int) :: c_tuya_connect
    end function

    subroutine c_tuya_disconnect(dev) bind(c, name="tuya_disconnect")
      import :: c_ptr
      type(c_ptr), value :: dev
    end subroutine

    function c_tuya_is_connected(dev) bind(c, name="tuya_is_connected")
      import :: c_ptr, c_int
      type(c_ptr), value :: dev
      integer(c_int) :: c_tuya_is_connected
    end function

    function c_tuya_reconnect(dev) bind(c, name="tuya_reconnect")
      import :: c_ptr, c_int
      type(c_ptr), value :: dev
      integer(c_int) :: c_tuya_reconnect
    end function

    subroutine c_tuya_set_credentials(dev, did, key) bind(c, name="tuya_set_credentials")
      import :: c_ptr, c_char
      type(c_ptr), value :: dev
      character(kind=c_char), intent(in) :: did(*), key(*)
    end subroutine

    function c_tuya_get_device_id(dev) bind(c, name="tuya_get_device_id")
      import :: c_ptr
      type(c_ptr), value :: dev
      type(c_ptr) :: c_tuya_get_device_id
    end function

    function c_tuya_get_local_key(dev) bind(c, name="tuya_get_local_key")
      import :: c_ptr
      type(c_ptr), value :: dev
      type(c_ptr) :: c_tuya_get_local_key
    end function

    function c_tuya_get_ip(dev) bind(c, name="tuya_get_ip")
      import :: c_ptr
      type(c_ptr), value :: dev
      type(c_ptr) :: c_tuya_get_ip
    end function

    subroutine c_tuya_set_retry_limit(dev, limit) bind(c, name="tuya_set_retry_limit")
      import :: c_ptr, c_int
      type(c_ptr), value :: dev
      integer(c_int), value :: limit
    end subroutine

    subroutine c_tuya_set_retry_delay(dev, ms) bind(c, name="tuya_set_retry_delay")
      import :: c_ptr, c_int
      type(c_ptr), value :: dev
      integer(c_int), value :: ms
    end subroutine

    function c_tuya_get_retry_limit(dev) bind(c, name="tuya_get_retry_limit")
      import :: c_ptr, c_int
      type(c_ptr), value :: dev
      integer(c_int) :: c_tuya_get_retry_limit
    end function

    function c_tuya_get_retry_delay(dev) bind(c, name="tuya_get_retry_delay")
      import :: c_ptr, c_int
      type(c_ptr), value :: dev
      integer(c_int) :: c_tuya_get_retry_delay
    end function

    function c_tuya_negotiate_session(dev, key) bind(c, name="tuya_negotiate_session")
      import :: c_ptr, c_int, c_char
      type(c_ptr), value :: dev
      character(kind=c_char), intent(in) :: key(*)
      integer(c_int) :: c_tuya_negotiate_session
    end function

    function c_tuya_get_protocol(dev) bind(c, name="tuya_get_protocol")
      import :: c_ptr, c_int
      type(c_ptr), value :: dev
      integer(c_int) :: c_tuya_get_protocol
    end function

    function c_tuya_get_session_state(dev) bind(c, name="tuya_get_session_state")
      import :: c_ptr, c_int
      type(c_ptr), value :: dev
      integer(c_int) :: c_tuya_get_session_state
    end function

    function c_tuya_get_socket_state(dev) bind(c, name="tuya_get_socket_state")
      import :: c_ptr, c_int
      type(c_ptr), value :: dev
      integer(c_int) :: c_tuya_get_socket_state
    end function

    function c_tuya_get_last_error(dev) bind(c, name="tuya_get_last_error")
      import :: c_ptr, c_int
      type(c_ptr), value :: dev
      integer(c_int) :: c_tuya_get_last_error
    end function

    subroutine c_tuya_set_async_mode(dev, flag) bind(c, name="tuya_set_async_mode")
      import :: c_ptr, c_int
      type(c_ptr), value :: dev
      integer(c_int), value :: flag
    end subroutine

    function c_tuya_set_value_bool(dev, dp, val) bind(c, name="tuya_set_value_bool")
      import :: c_ptr, c_int
      type(c_ptr), value :: dev
      integer(c_int), value :: dp, val
      type(c_ptr) :: c_tuya_set_value_bool
    end function

    function c_tuya_set_value_int(dev, dp, val) bind(c, name="tuya_set_value_int")
      import :: c_ptr, c_int
      type(c_ptr), value :: dev
      integer(c_int), value :: dp, val
      type(c_ptr) :: c_tuya_set_value_int
    end function

    function c_tuya_set_value_string(dev, dp, val) bind(c, name="tuya_set_value_string")
      import :: c_ptr, c_int, c_char
      type(c_ptr), value :: dev
      integer(c_int), value :: dp
      character(kind=c_char), intent(in) :: val(*)
      type(c_ptr) :: c_tuya_set_value_string
    end function

    function c_tuya_set_value_float(dev, dp, val) bind(c, name="tuya_set_value_float")
      import :: c_ptr, c_int, c_double
      type(c_ptr), value :: dev
      integer(c_int), value :: dp
      real(c_double), value :: val
      type(c_ptr) :: c_tuya_set_value_float
    end function

    function c_tuya_turn_on(dev, dp) bind(c, name="tuya_turn_on")
      import :: c_ptr, c_int
      type(c_ptr), value :: dev
      integer(c_int), value :: dp
      type(c_ptr) :: c_tuya_turn_on
    end function

    function c_tuya_turn_off(dev, dp) bind(c, name="tuya_turn_off")
      import :: c_ptr, c_int
      type(c_ptr), value :: dev
      integer(c_int), value :: dp
      type(c_ptr) :: c_tuya_turn_off
    end function

    function c_tuya_status(dev) bind(c, name="tuya_status")
      import :: c_ptr
      type(c_ptr), value :: dev
      type(c_ptr) :: c_tuya_status
    end function

    function c_tuya_heartbeat(dev) bind(c, name="tuya_heartbeat")
      import :: c_ptr
      type(c_ptr), value :: dev
      type(c_ptr) :: c_tuya_heartbeat
    end function

    subroutine c_tuya_free_string(str) bind(c, name="tuya_free_string")
      import :: c_ptr
      type(c_ptr), value :: str
    end subroutine

    subroutine c_tuya_set_device22(dev, json) bind(c, name="tuya_set_device22")
      import :: c_ptr, c_char
      type(c_ptr), value :: dev
      character(kind=c_char), intent(in) :: json(*)
    end subroutine

    function c_tuya_is_device22(dev) bind(c, name="tuya_is_device22")
      import :: c_ptr, c_int
      type(c_ptr), value :: dev
      integer(c_int) :: c_tuya_is_device22
    end function
  end interface

  ! ── Constants ──
  integer, parameter :: CMD_CONTROL = 7, CMD_DP_QUERY = 10, CMD_HEART_BEAT = 9
  integer, parameter :: CMD_STATUS = 8, CMD_CONTROL_NEW = 13, CMD_DP_QUERY_NEW = 16
  integer, parameter :: PROTO_V31 = 0, PROTO_V33 = 1, PROTO_V34 = 2, PROTO_V35 = 3
  integer, parameter :: DEFAULT_PORT = 6668, BUFSIZE = 1024
  integer, parameter :: DEFAULT_RETRY_LIMIT = 5, DEFAULT_RETRY_DELAY = 100

  ! ── Helper: C string to Fortran string ──
  interface
    function c_strlen(s) bind(c, name="strlen")
      import :: c_ptr, c_size_t
      type(c_ptr), value :: s
      integer(c_size_t) :: c_strlen
    end function
  end interface

contains

  function c_to_f_string(cptr) result(s)
    type(c_ptr), intent(in) :: cptr
    character(len=:), allocatable :: s
    character(kind=c_char), pointer :: fptr(:)
    integer(c_size_t) :: n
    integer :: i
    if (.not. c_associated(cptr)) then
      s = ""
      return
    end if
    n = c_strlen(cptr)
    allocate(character(len=n) :: s)
    call c_f_pointer(cptr, fptr, [n])
    do i = 1, n
      s(i:i) = fptr(i)
    end do
  end function

  function seatuya_version() result(s)
    type(c_ptr) :: cp
    character(len=:), allocatable :: s
    cp = c_tuya_version()
    s = c_to_f_string(cp)
  end function

  function seatuya_create(did, addr, key, ver) result(dev)
    character(len=*), intent(in) :: did, addr, key, ver
    type(c_ptr) :: dev
    dev = c_tuya_create(trim(did)//c_null_char, trim(addr)//c_null_char, &
                        trim(key)//c_null_char, trim(ver)//c_null_char)
  end function

  function seatuya_alloc(ver) result(dev)
    character(len=*), intent(in) :: ver
    type(c_ptr) :: dev
    dev = c_tuya_alloc(trim(ver)//c_null_char)
  end function

  subroutine seatuya_destroy(dev)
    type(c_ptr), intent(in) :: dev
    call c_tuya_destroy(dev)
  end subroutine

  function seatuya_connect(dev, host) result(ok)
    type(c_ptr), intent(in) :: dev
    character(len=*), intent(in) :: host
    logical :: ok
    ok = c_tuya_connect(dev, trim(host)//c_null_char) /= 0
  end function

  function seatuya_is_connected(dev) result(ok)
    type(c_ptr), intent(in) :: dev
    logical :: ok
    ok = c_tuya_is_connected(dev) /= 0
  end function

  function seatuya_turn_on(dev, dp) result(json)
    type(c_ptr), intent(in) :: dev
    integer, intent(in) :: dp
    character(len=:), allocatable :: json
    type(c_ptr) :: cp
    cp = c_tuya_turn_on(dev, int(dp, c_int))
    json = c_to_f_string(cp)
    if (c_associated(cp)) call c_tuya_free_string(cp)
  end function

  function seatuya_turn_off(dev, dp) result(json)
    type(c_ptr), intent(in) :: dev
    integer, intent(in) :: dp
    character(len=:), allocatable :: json
    type(c_ptr) :: cp
    cp = c_tuya_turn_off(dev, int(dp, c_int))
    json = c_to_f_string(cp)
    if (c_associated(cp)) call c_tuya_free_string(cp)
  end function

  function seatuya_status(dev) result(json)
    type(c_ptr), intent(in) :: dev
    character(len=:), allocatable :: json
    type(c_ptr) :: cp
    cp = c_tuya_status(dev)
    json = c_to_f_string(cp)
    if (c_associated(cp)) call c_tuya_free_string(cp)
  end function

  function seatuya_heartbeat(dev) result(json)
    type(c_ptr), intent(in) :: dev
    character(len=:), allocatable :: json
    type(c_ptr) :: cp
    cp = c_tuya_heartbeat(dev)
    json = c_to_f_string(cp)
    if (c_associated(cp)) call c_tuya_free_string(cp)
  end function

  function seatuya_set_value_bool(dev, dp, val) result(json)
    type(c_ptr), intent(in) :: dev
    integer, intent(in) :: dp
    logical, intent(in) :: val
    character(len=:), allocatable :: json
    type(c_ptr) :: cp
    integer(c_int) :: iv
    iv = merge(1_c_int, 0_c_int, val)
    cp = c_tuya_set_value_bool(dev, int(dp, c_int), iv)
    json = c_to_f_string(cp)
    if (c_associated(cp)) call c_tuya_free_string(cp)
  end function

  function seatuya_set_value_int(dev, dp, val) result(json)
    type(c_ptr), intent(in) :: dev
    integer, intent(in) :: dp, val
    character(len=:), allocatable :: json
    type(c_ptr) :: cp
    cp = c_tuya_set_value_int(dev, int(dp, c_int), int(val, c_int))
    json = c_to_f_string(cp)
    if (c_associated(cp)) call c_tuya_free_string(cp)
  end function

  function seatuya_set_value_float(dev, dp, val) result(json)
    type(c_ptr), intent(in) :: dev
    integer, intent(in) :: dp
    real(8), intent(in) :: val
    character(len=:), allocatable :: json
    type(c_ptr) :: cp
    cp = c_tuya_set_value_float(dev, int(dp, c_int), real(val, c_double))
    json = c_to_f_string(cp)
    if (c_associated(cp)) call c_tuya_free_string(cp)
  end function

  function seatuya_set_value_string(dev, dp, val) result(json)
    type(c_ptr), intent(in) :: dev
    integer, intent(in) :: dp
    character(len=*), intent(in) :: val
    character(len=:), allocatable :: json
    type(c_ptr) :: cp
    cp = c_tuya_set_value_string(dev, int(dp, c_int), trim(val)//c_null_char)
    json = c_to_f_string(cp)
    if (c_associated(cp)) call c_tuya_free_string(cp)
  end function

  subroutine seatuya_set_credentials(dev, did, key)
    type(c_ptr), intent(in) :: dev
    character(len=*), intent(in) :: did, key
    call c_tuya_set_credentials(dev, trim(did)//c_null_char, trim(key)//c_null_char)
  end subroutine

  subroutine seatuya_set_device22(dev, json)
    type(c_ptr), intent(in) :: dev
    character(len=*), intent(in) :: json
    call c_tuya_set_device22(dev, trim(json)//c_null_char)
  end subroutine

  function seatuya_is_device22(dev) result(ok)
    type(c_ptr), intent(in) :: dev
    logical :: ok
    ok = c_tuya_is_device22(dev) /= 0
  end function

end module seatuya
