package transferengine

import (
	"log/slog"
	"time"

	"regelmaessig/native/transferengine/internal/logging"
	"regelmaessig/native/transferengine/internal/payload"
	"regelmaessig/native/transferengine/internal/protocol"
)

const ProtocolVersion = protocol.ProtocolVersion

type Chunk = protocol.Chunk

type Engine struct {
	logger *slog.Logger
}

func NewEngine(logger *slog.Logger) *Engine {
	if logger == nil {
		logger = logging.NewDiscard()
	}
	return &Engine{logger: logger}
}

var defaultEngine = NewEngine(nil)

func ParseChunk(input []byte) (Chunk, error) {
	return protocol.ParseChunk(input)
}

func EncodePayload(input []byte, transferID, passphrase string, chunkSize int, encrypted bool) ([]Chunk, error) {
	return defaultEngine.EncodePayload(input, transferID, passphrase, chunkSize, encrypted)
}

func DecodePayload(chunks []Chunk, passphrase string) ([]byte, error) {
	return defaultEngine.DecodePayload(chunks, passphrase)
}

func (e *Engine) EncodePayload(input []byte, transferID, passphrase string, chunkSize int, encrypted bool) ([]Chunk, error) {
	started := time.Now()
	chunks, err := payload.Encode(input, transferID, passphrase, chunkSize, encrypted)
	e.logger.Info("transfer.encode", "duration_ms", time.Since(started).Milliseconds(), "payload_bytes", len(input), "chunks", len(chunks), "encrypted", encrypted, "success", err == nil)
	return chunks, err
}

func (e *Engine) DecodePayload(chunks []Chunk, passphrase string) ([]byte, error) {
	started := time.Now()
	clear, err := payload.Decode(chunks, passphrase)
	e.logger.Info("transfer.decode", "duration_ms", time.Since(started).Milliseconds(), "chunks", len(chunks), "payload_bytes", len(clear), "success", err == nil)
	return clear, err
}
