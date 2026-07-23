# Seatuya.pm — Perl FFI bindings for libseatuya
#
# Pure Perl binding using FFI::Platypus for every function in libseatuya.
# Requires: cpanm FFI::Platypus
#
# Usage:
#   use Seatuya;
#   my $dev = Seatuya::create($device_id, "192.168.1.100", $local_key, "3.4");
#   say Seatuya::turn_on($dev, 1);
#   Seatuya::destroy($dev);

package Seatuya;
use strict; use warnings;
use FFI::Platypus;

my $ffi = FFI::Platypus->new(api => 1);

# Library discovery
my $lib = $ENV{SEATUYA_LIB} ||
  ($^O eq 'darwin' ? 'libseatuya.dylib' :
   $^O eq 'MSWin32' ? 'seatuya.dll' :
   'libseatuya.so');

$ffi->lib($lib);

# Type definitions
$ffi->type('opaque' => 'tuya_device_t');
$ffi->type('string' => 'cstring');
$ffi->type('int'    => 'sint32');
$ffi->type('bool'   => 'sint8');  # C99 _Bool

# Attach all functions
$ffi->attach(tuya_version        => [] => 'string');
$ffi->attach(tuya_create         => ['string','string','string','string'] => 'opaque');
$ffi->attach(tuya_alloc          => ['string'] => 'opaque');
$ffi->attach(tuya_destroy        => ['opaque']);
$ffi->attach(tuya_set_credentials => ['opaque','string','string']);
$ffi->attach(tuya_get_device_id  => ['opaque'] => 'string');
$ffi->attach(tuya_get_local_key  => ['opaque'] => 'string');
$ffi->attach(tuya_get_ip         => ['opaque'] => 'string');
$ffi->attach(tuya_connect        => ['opaque','string'] => 'bool');
$ffi->attach(tuya_disconnect     => ['opaque']);
$ffi->attach(tuya_is_connected   => ['opaque'] => 'bool');
$ffi->attach(tuya_reconnect      => ['opaque'] => 'bool');
$ffi->attach(tuya_set_retry_limit => ['opaque','int']);
$ffi->attach(tuya_set_retry_delay => ['opaque','int']);
$ffi->attach(tuya_get_retry_limit => ['opaque'] => 'int');
$ffi->attach(tuya_get_retry_delay => ['opaque'] => 'int');
$ffi->attach(tuya_negotiate_session => ['opaque','string'] => 'bool');
$ffi->attach(tuya_negotiate_session_start => ['opaque','string'] => 'bool');
$ffi->attach(tuya_negotiate_session_finalize => ['opaque','opaque','int','string'] => 'bool');
$ffi->attach(tuya_get_protocol    => ['opaque'] => 'int');
$ffi->attach(tuya_get_session_state => ['opaque'] => 'int');
$ffi->attach(tuya_get_socket_state => ['opaque'] => 'int');
$ffi->attach(tuya_get_last_error  => ['opaque'] => 'int');
$ffi->attach(tuya_set_async_mode  => ['opaque','bool']);
$ffi->attach(tuya_is_socket_readable => ['opaque'] => 'bool');
$ffi->attach(tuya_is_socket_writable => ['opaque'] => 'bool');
$ffi->attach(tuya_set_session_ready => ['opaque'] => 'bool');
$ffi->attach(tuya_build_message   => ['opaque','opaque','int','string','string'] => 'int');
$ffi->attach(tuya_decode_message  => ['opaque','opaque','int','string'] => 'string');
$ffi->attach(tuya_generate_payload => ['opaque','int','string','string'] => 'string');
$ffi->attach(tuya_send            => ['opaque','opaque','int'] => 'int');
$ffi->attach(tuya_receive         => ['opaque','opaque','int','int'] => 'int');
$ffi->attach(tuya_set_value_bool  => ['opaque','int','bool'] => 'string');
$ffi->attach(tuya_set_value_int   => ['opaque','int','int'] => 'string');
$ffi->attach(tuya_set_value_string => ['opaque','int','string'] => 'string');
$ffi->attach(tuya_set_value_float => ['opaque','int','double'] => 'string');
$ffi->attach(tuya_turn_on         => ['opaque','int'] => 'string');
$ffi->attach(tuya_turn_off        => ['opaque','int'] => 'string');
$ffi->attach(tuya_status          => ['opaque'] => 'string');
$ffi->attach(tuya_heartbeat       => ['opaque'] => 'string');
$ffi->attach(tuya_free_string     => ['string']);
$ffi->attach(tuya_set_device22    => ['opaque','string']);
$ffi->attach(tuya_is_device22     => ['opaque'] => 'bool');

# --- Constants ---
use constant {
    CMD_CONTROL  => 7,  CMD_DP_QUERY => 10, CMD_HEART_BEAT => 9,
    CMD_CONTROL_NEW => 13, CMD_DP_QUERY_NEW => 16, CMD_STATUS => 8,
    CMD_UDP => 0, CMD_HEART_BEAT_STOP => 37,
    PROTO_V31 => 0, PROTO_V33 => 1, PROTO_V34 => 2, PROTO_V35 => 3,
    DEFAULT_PORT => 6668, BUFSIZE => 1024,
    DEFAULT_RETRY_LIMIT => 5, DEFAULT_RETRY_DELAY_MS => 100,
};

# --- Convenience wrappers ---
sub version { tuya_version() }

sub create {
    my ($id, $addr, $key, $ver) = @_;
    my $dev = tuya_create($id, $addr, $key, $ver);
    return $dev;
}

sub alloc {
    my ($ver) = @_;
    return tuya_alloc($ver);
}

sub destroy { tuya_destroy($_[0]) }
sub set_credentials { tuya_set_credentials(@_) }
sub get_device_id { tuya_get_device_id($_[0]) }
sub get_local_key { tuya_get_local_key($_[0]) }
sub get_ip { tuya_get_ip($_[0]) }
sub connect { tuya_connect(@_) }
sub disconnect { tuya_disconnect($_[0]) }
sub is_connected { tuya_is_connected($_[0]) }
sub reconnect { tuya_reconnect($_[0]) }
sub negotiate_session { tuya_negotiate_session(@_) }
sub set_async_mode { tuya_set_async_mode(@_) }

sub set_value {
    my ($dev, $dp, $value) = @_;
    if (!defined $value) { return tuya_set_value_bool($dev, $dp, 0) }
    my $ref = ref $value;
    if (!$ref) {
        return tuya_set_value_int($dev, $dp, $value)  if $value =~ /^-?\d+$/;
        return tuya_set_value_float($dev, $dp, $value) if $value =~ /^-?\d+\.?\d*$/;
        return tuya_set_value_string($dev, $dp, $value);
    }
    return tuya_set_value_bool($dev, $dp, $value ? 1 : 0);
}

sub turn_on  { tuya_turn_on($_[0], $_[1] // 1) }
sub turn_off { tuya_turn_off($_[0], $_[1] // 1) }
sub status   { tuya_status($_[0]) }
sub heartbeat { tuya_heartbeat($_[0]) }
sub set_device22 { tuya_set_device22(@_) }
sub is_device22  { tuya_is_device22($_[0]) }

# Low-level helpers
sub build_message {
    my ($dev, $cmd, $payload, $key) = @_;
    my $buf = "\0" x 1024;
    my $n = tuya_build_message($dev, $buf, $cmd, $payload, $key);
    return $n > 0 ? substr($buf, 0, $n) : undef;
}

sub decode_message {
    my ($dev, $buf, $key) = @_;
    my $s = tuya_decode_message($dev, $buf, length($buf), $key);
    $s ? (my $copy = $s, tuya_free_string($s), $copy) : undef;
}

sub send_frame { tuya_send($_[0], $_[1], length($_[1])) }

sub receive_frame {
    my ($dev, $maxsize, $minsize) = @_;
    $maxsize //= 1024; $minsize //= 0;
    my $buf = "\0" x $maxsize;
    my $n = tuya_receive($dev, $buf, $maxsize, $minsize);
    return $n > 0 ? substr($buf, 0, $n) : undef;
}

1;
