# Perl FFI Bindings for libseatuya

Pure Perl binding using [FFI::Platypus](https://metacpan.org/pod/FFI::Platypus).
Every C function is attached with proper type signatures.

## Prerequisites

```sh
cpanm FFI::Platypus
```

libseatuya must be installed (`make install`).

## Usage

```perl
use Seatuya;

my $dev = Seatuya::create($device_id, "192.168.1.100", $local_key, "3.4");
say Seatuya::turn_on($dev, 1);
say Seatuya::status($dev);
Seatuya::destroy($dev);
```

## API

See the [seatuya(3)](../../seatuya.3) manpage. All functions exported as
`Seatuya::function_name`. Perl scalars auto-convert: integers, floats,
and strings dispatch to the correct typed C setter.
