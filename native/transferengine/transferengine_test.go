package transferengine

import (
	"bytes"
	"math/rand"
	"testing"
)

func TestEncryptedPayloadRoundTrip(t *testing.T) {
	input := make([]byte, 8000)
	random := rand.New(rand.NewSource(42))
	_, _ = random.Read(input)
	chunks, err := EncodePayload(input, "transfer-1", "correct horse battery staple", 1800, true)
	if err != nil {
		t.Fatal(err)
	}
	if len(chunks) < 2 {
		t.Fatal("expected multiple chunks")
	}
	decoded, err := DecodePayload(chunks, "correct horse battery staple")
	if err != nil {
		t.Fatal(err)
	}
	if !bytes.Equal(decoded, input) {
		t.Fatal("decoded payload differs")
	}
}

func TestChunkWireFormatRoundTrip(t *testing.T) {
	wire, err := (Chunk{TransferID: "id", ProtocolVersion: ProtocolVersion, Index: 0, Total: 1, CipherText: []byte{1, 2, 3}, Encrypted: false}).Bytes()
	if err != nil {
		t.Fatal(err)
	}
	chunk, err := ParseChunk(wire)
	if err != nil {
		t.Fatal(err)
	}
	if chunk.TransferID != "id" || !bytes.Equal(chunk.CipherText, []byte{1, 2, 3}) || chunk.Encrypted {
		t.Fatalf("unexpected chunk: %#v", chunk)
	}
}

func TestRenderPacketsCreatesCameraFriendlySequence(t *testing.T) {
	frames, err := RenderPackets([][]byte{[]byte("one"), []byte("two"), []byte("three"), []byte("four")}, RenderOptions{MaxLayersPerCode: 2, PadWithDummies: true})
	if err != nil {
		t.Fatal(err)
	}
	if len(frames) != 2 || frames[0].QRVersion < 1 || frames[0].Width < frames[0].Height || len(frames[0].PixelsRGB) != frames[0].Width*frames[0].Height*3 {
		t.Fatalf("unexpected frames: %#v", frames)
	}
}
