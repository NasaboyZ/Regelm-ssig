package ffi

import (
	"encoding/binary"

	"regelmaessig/native/transferengine/internal/mlqr"
	"regelmaessig/native/transferengine/internal/protocol"
)

func ParsePackets(input []byte) ([][]byte, bool) {
	if len(input) < 4 {
		return nil, false
	}
	count := int(binary.BigEndian.Uint32(input[:4]))
	if count < 1 || count > mlqr.MaxLayers {
		return nil, false
	}
	input = input[4:]
	packets := make([][]byte, count)
	for index := range packets {
		if len(input) < 4 {
			return nil, false
		}
		length := int(binary.BigEndian.Uint32(input[:4]))
		input = input[4:]
		if length < 0 || length > len(input) {
			return nil, false
		}
		packets[index] = append([]byte(nil), input[:length]...)
		input = input[length:]
	}
	return packets, len(input) == 0
}

func ParseChunks(input []byte) ([]protocol.Chunk, bool) {
	if len(input) < 4 {
		return nil, false
	}
	count := int(binary.BigEndian.Uint32(input[:4]))
	if count < 1 || count > protocol.MaxChunks {
		return nil, false
	}
	offset := 4
	chunks := make([]protocol.Chunk, 0, count)
	for index := 0; index < count; index++ {
		if offset+4 > len(input) {
			return nil, false
		}
		length := int(binary.BigEndian.Uint32(input[offset:]))
		offset += 4
		if length < 0 || offset+length > len(input) {
			return nil, false
		}
		chunk, err := protocol.ParseChunk(input[offset : offset+length])
		if err != nil {
			return nil, false
		}
		chunks = append(chunks, chunk)
		offset += length
	}
	return chunks, offset == len(input)
}

func EncodeChunks(chunks []protocol.Chunk) ([]byte, error) {
	output := make([]byte, 4)
	binary.BigEndian.PutUint32(output, uint32(len(chunks)))
	for _, chunk := range chunks {
		wire, err := chunk.Bytes()
		if err != nil {
			return nil, err
		}
		var length [4]byte
		binary.BigEndian.PutUint32(length[:], uint32(len(wire)))
		output = append(output, length[:]...)
		output = append(output, wire...)
	}
	return output, nil
}

func EncodeFrames(frames []mlqr.Raster) []byte {
	length := 4
	for _, frame := range frames {
		length += 20 + len(frame.PixelsRGB)
	}
	output := make([]byte, length)
	binary.BigEndian.PutUint32(output[:4], uint32(len(frames)))
	offset := 4
	for _, frame := range frames {
		binary.BigEndian.PutUint32(output[offset:], uint32(frame.Width))
		binary.BigEndian.PutUint32(output[offset+4:], uint32(frame.Height))
		binary.BigEndian.PutUint32(output[offset+8:], uint32(frame.QRVersion))
		binary.BigEndian.PutUint32(output[offset+12:], uint32(frame.Payloads))
		binary.BigEndian.PutUint32(output[offset+16:], uint32(len(frame.PixelsRGB)))
		offset += 20
		copy(output[offset:], frame.PixelsRGB)
		offset += len(frame.PixelsRGB)
	}
	return output
}
