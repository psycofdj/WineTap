package manager

import (
	"context"
	"log/slog"
	"os"
	"strings"
	"sync"
)

// SwappableHandler is a slog.Handler whose underlying handler can be replaced
// at runtime without changing the *slog.Logger pointer held by all screens.
type SwappableHandler struct {
	mu sync.RWMutex
	h  slog.Handler
}

func (s *SwappableHandler) Enabled(ctx context.Context, level slog.Level) bool {
	s.mu.RLock()
	defer s.mu.RUnlock()
	return s.h.Enabled(ctx, level)
}

func (s *SwappableHandler) Handle(ctx context.Context, r slog.Record) error {
	s.mu.RLock()
	defer s.mu.RUnlock()
	return s.h.Handle(ctx, r)
}

func (s *SwappableHandler) WithAttrs(attrs []slog.Attr) slog.Handler {
	s.mu.RLock()
	defer s.mu.RUnlock()
	return s.h.WithAttrs(attrs)
}

func (s *SwappableHandler) WithGroup(name string) slog.Handler {
	s.mu.RLock()
	defer s.mu.RUnlock()
	return s.h.WithGroup(name)
}

// Swap replaces the underlying handler; safe to call from any goroutine.
func (s *SwappableHandler) Swap(h slog.Handler) {
	s.mu.Lock()
	s.h = h
	s.mu.Unlock()
}

// NewHandler builds a slog.Handler for the given level and format strings.
func NewHandler(level, format string) slog.Handler {
	var l slog.Level
	switch strings.ToLower(level) {
	case "debug":
		l = slog.LevelDebug
	case "warn", "warning":
		l = slog.LevelWarn
	case "error":
		l = slog.LevelError
	default:
		l = slog.LevelInfo
	}
	opts := &slog.HandlerOptions{Level: l}
	if strings.ToLower(format) == "json" {
		return slog.NewJSONHandler(os.Stderr, opts)
	}
	return slog.NewTextHandler(os.Stderr, opts)
}

// SetupLogger creates a *slog.Logger backed by a SwappableHandler so that
// the log level and format can be changed at runtime without changing the
// logger pointer held by all screens.  Pass the returned handler to New so
// that SaveSettings can swap it live.
func SetupLogger(level, format string) (*slog.Logger, *SwappableHandler) {
	sh := &SwappableHandler{h: NewHandler(level, format)}
	return slog.New(sh), sh
}
