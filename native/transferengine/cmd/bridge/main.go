package main

// #include <stdint.h>
// #include <stdlib.h>
import "C"

import (
	"unsafe"

	transfer "regelmaessig/native/transferengine"
	"regelmaessig/native/transferengine/internal/ffi"
	"regelmaessig/native/transferengine/internal/logging"
)

var engine = transfer.NewEngine(logging.NewDebug())

// Input format: u32 packet count, followed by repeated u32 byte length + bytes.
// The result is a versioned binary response containing display rasters.
//
//export regelmaessig_mlqr_encode
func regelmaessig_mlqr_encode(input *C.uchar, inputLength C.int, maxLayers C.int, resultLength *C.int) *C.uchar {
	packets, ok := ffi.ParsePackets(C.GoBytes(unsafe.Pointer(input), inputLength))
	if !ok {
		*resultLength = 0
		return nil
	}
	frames, err := engine.RenderPackets(packets, transfer.RenderOptions{MaxLayersPerCode: int(maxLayers), PadWithDummies: true})
	if err != nil {
		*resultLength = 0
		return nil
	}
	output := ffi.EncodeFrames(frames)
	result := C.CBytes(output)
	*resultLength = C.int(len(output))
	return (*C.uchar)(result)
}

//export regelmaessig_transfer_free
func regelmaessig_transfer_free(pointer unsafe.Pointer) {
	C.free(pointer)
}

//export regelmaessig_transfer_encode
func regelmaessig_transfer_encode(input *C.uchar, inputLength C.int, transferID *C.uchar, transferIDLength C.int, passphrase *C.uchar, passphraseLength C.int, chunkSize C.int, encrypted C.int, resultLength *C.int) *C.uchar {
	payload := C.GoBytes(unsafe.Pointer(input), inputLength)
	id := string(C.GoBytes(unsafe.Pointer(transferID), transferIDLength))
	password := string(C.GoBytes(unsafe.Pointer(passphrase), passphraseLength))
	chunks, err := engine.EncodePayload(payload, id, password, int(chunkSize), encrypted != 0)
	if err != nil {
		*resultLength = 0
		return nil
	}
	output, err := ffi.EncodeChunks(chunks)
	if err != nil {
		*resultLength = 0
		return nil
	}
	result := C.CBytes(output)
	*resultLength = C.int(len(output))
	return (*C.uchar)(result)
}

//export regelmaessig_transfer_decode
func regelmaessig_transfer_decode(input *C.uchar, inputLength C.int, passphrase *C.uchar, passphraseLength C.int, resultLength *C.int) *C.uchar {
	chunks, ok := ffi.ParseChunks(C.GoBytes(unsafe.Pointer(input), inputLength))
	if !ok {
		*resultLength = 0
		return nil
	}
	password := string(C.GoBytes(unsafe.Pointer(passphrase), passphraseLength))
	clear, err := engine.DecodePayload(chunks, password)
	if err != nil {
		*resultLength = 0
		return nil
	}
	result := C.CBytes(clear)
	*resultLength = C.int(len(clear))
	return (*C.uchar)(result)
}

func main() {}
