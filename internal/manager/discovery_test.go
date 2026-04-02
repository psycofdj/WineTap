package manager

import (
	"context"
	"log/slog"
	"os"
	"path/filepath"
	"testing"
	"time"

	"gopkg.in/yaml.v3"
)

// TestDiscoverPhone_Timeout verifies that DiscoverPhone returns ("", nil)
// when no _winetap._tcp service is found within the timeout.
func TestDiscoverPhone_Timeout(t *testing.T) {
	log := slog.New(slog.NewTextHandler(os.Stderr, &slog.HandlerOptions{Level: slog.LevelError}))
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	addr, err := DiscoverPhone(ctx, log)
	if err != nil {
		t.Fatalf("expected nil error, got: %v", err)
	}
	// In a test environment with no phone, we expect empty address.
	// (If a phone happens to be on the network this may find it — that's OK.)
	if addr != "" {
		t.Logf("phone discovered at %s (real device on network)", addr)
	}
}

// TestDiscoverPhone_ContextCancelled verifies that DiscoverPhone returns
// promptly when its parent context is already cancelled.
func TestDiscoverPhone_ContextCancelled(t *testing.T) {
	log := slog.New(slog.NewTextHandler(os.Stderr, &slog.HandlerOptions{Level: slog.LevelError}))
	ctx, cancel := context.WithCancel(context.Background())
	cancel() // already cancelled

	start := time.Now()
	addr, err := DiscoverPhone(ctx, log)
	elapsed := time.Since(start)

	// Should return quickly (well under the 3s internal timeout).
	if elapsed > 500*time.Millisecond {
		t.Errorf("expected fast return on cancelled context, took %v", elapsed)
	}
	if err != nil {
		t.Fatalf("expected nil error on cancelled context, got: %v", err)
	}
	if addr != "" {
		t.Errorf("expected empty address on cancelled context, got %q", addr)
	}
}

// TestConfig_PhoneAddressRoundTrip verifies that PhoneAddress survives a
// save/load cycle through the YAML config file.
func TestConfig_PhoneAddressRoundTrip(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "config.yaml")

	original := Config{
		Server:       "localhost:50051",
		PhoneAddress: "http://192.168.1.42:8080",
		LogLevel:     "info",
		LogFormat:    "text",
	}

	if err := saveConfig(path, original); err != nil {
		t.Fatalf("saveConfig: %v", err)
	}

	f, err := os.Open(path)
	if err != nil {
		t.Fatalf("open config: %v", err)
	}
	defer f.Close()

	var loaded Config
	if err := yaml.NewDecoder(f).Decode(&loaded); err != nil {
		t.Fatalf("decode config: %v", err)
	}

	if loaded.PhoneAddress != original.PhoneAddress {
		t.Errorf("PhoneAddress: got %q, want %q", loaded.PhoneAddress, original.PhoneAddress)
	}
	if loaded.Server != original.Server {
		t.Errorf("Server: got %q, want %q", loaded.Server, original.Server)
	}
}

