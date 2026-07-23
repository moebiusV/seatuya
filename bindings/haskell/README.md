# Haskell FFI Bindings for libseatuya

Binding using `Foreign.Ptr`, `Foreign.C`, and `foreign import ccall` declarations. The opaque C pointer is wrapped in a `ForeignPtr` for automatic resource cleanup. Requires GHC 8.0+ and libseatuya installed. Set `SEATUYA_LIB` to a custom library path, or use `LD_LIBRARY_PATH`/`DYLD_LIBRARY_PATH`.

```haskell
import Seatuya
dev <- create "id" "192.168.1.100" "key" "3.4"
turnOn dev 1 >>= putStrLn; destroy dev
```
