package manager

import (
	"context"
	"fmt"
	"log/slog"
	"time"

	"github.com/grandcat/zeroconf"
)

// DiscoverPhone browses mDNS for the _winetap._tcp service and returns the
// first found address as "http://host:port".  Returns empty string (no error)
// if no phone is found within the 3-second timeout.
func DiscoverPhone(ctx context.Context, log *slog.Logger) (string, error) {
	resolver, err := zeroconf.NewResolver(nil)
	if err != nil {
		return "", fmt.Errorf("create mDNS resolver: %w", err)
	}

	entries := make(chan *zeroconf.ServiceEntry)

	discoverCtx, cancel := context.WithTimeout(ctx, 3*time.Second)
	defer cancel()

	go func() {
		if err := resolver.Browse(discoverCtx, "_winetap._tcp", "local.", entries); err != nil {
			log.Warn("mDNS browse error", "error", err)
		}
	}()

	for {
		select {
		case entry, ok := <-entries:
			if !ok {
				log.Debug("mDNS: phone not found within timeout")
				return "", nil
			}
			if len(entry.AddrIPv4) > 0 {
				addr := fmt.Sprintf("http://%s:%d", entry.AddrIPv4[0], entry.Port)
				log.Info("mDNS: phone discovered", "address", addr)
				return addr, nil
			}
		case <-discoverCtx.Done():
			log.Debug("mDNS: phone not found within timeout")
			return "", nil
		}
	}
}
