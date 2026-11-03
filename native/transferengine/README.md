# Native Transfer Engine

The module is named `transferengine` because it owns transfer compression,
encryption, chunking, MLQR rendering, and the FFI seam.

This module is an in-process, offline Go engine for the Flutter transfer flow.
It does not open sockets, read the SQLite database, or make network requests.

Flutter owns the local SQLCipher database and the `TrackingSnapshot`. The Go
engine receives in-memory snapshot bytes, compresses and encrypts them, creates
compatible `RGT1` chunks, and renders MLQR display rasters.

## Local build

```sh
GOCACHE=/tmp/regelmaessig-go-cache ./native/transferengine/scripts/build_native.sh host /tmp/regelmaessig-native
```

Mobile builds require the platform toolchains and must bundle the resulting
library as `libregelmaessig_transfer.so` on Android or as an iOS framework/
static archive. Flutter automatically falls back to the Dart implementation if
the native library is not present.

The exported functions are intentionally small C ABI seams:

- `regelmaessig_transfer_encode`: compress, encrypt, chunk
- `regelmaessig_mlqr_encode`: render packet groups into MLQR rasters
- `regelmaessig_transfer_free`: release Go-owned output buffers
