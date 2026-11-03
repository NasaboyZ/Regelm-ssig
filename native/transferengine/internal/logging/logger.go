package logging

import (
	"io"
	"log/slog"
	"os"
)

func New(writer io.Writer, level slog.Level) *slog.Logger {
	return slog.New(slog.NewTextHandler(writer, &slog.HandlerOptions{Level: level}))
}

func NewDebug() *slog.Logger {
	return New(os.Stderr, slog.LevelDebug)
}

func NewDiscard() *slog.Logger {
	return New(io.Discard, slog.LevelError)
}
