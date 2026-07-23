# Go cgo Bindings for libseatuya

Go binding using `cgo` for direct C interop.  The opaque C pointer is
wrapped in a `Device` struct with methods for every API function.

## Prerequisites

- Go 1.21+
- libseatuya installed (`make install`)

## Build and run

```sh
go build -o example example.go
./example
```

Or run directly (requires CGO_ENABLED=1):
```sh
CGO_ENABLED=1 go run example.go
```

## Usage

```go
import "seatuya"

dev, err := seatuya.Create(deviceID, "192.168.1.100", localKey, "3.4")
defer dev.Destroy()

fmt.Println(dev.TurnOn(1))
fmt.Println(dev.Status())
fmt.Println(dev.TurnOff(1))
```

## API

See the [seatuya(3)](../../seatuya.3) manpage.  All functions are methods
on the `Device` struct.  Go `bool` ↔ C `bool` conversion is automatic.
