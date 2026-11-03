package logging

import (
	"bytes"
	"log/slog"
	"strings"
	"testing"
)

func TestLoggerKeepsTransferMetadataWithoutPayloadSecrets(t *testing.T) {
	var output bytes.Buffer
	logger := New(&output, slog.LevelInfo)
	logger.Info("transfer.encode", "chunks", 4, "encrypted", true)

	value := output.String()
	if !strings.Contains(value, "transfer.encode") || !strings.Contains(value, "chunks=4") {
		t.Fatalf("missing structured metadata: %q", value)
	}
	if strings.Contains(value, "passphrase") || strings.Contains(value, "health") {
		t.Fatalf("logger emitted sensitive fields: %q", value)
	}
}
