package manager

import "context"

// Scanner is the abstraction for NFC tag scanning via phone coordination.
// Every scan is a single read — the manager loops for bulk intake.
type Scanner interface {
	// OnTagScanned registers a callback invoked on the Qt main thread when
	// a tag is detected. Must be called before StartScan.
	OnTagScanned(callback func(tagID string))

	// StartScan begins a single scan session. Returns immediately;
	// the tag is delivered via the OnTagScanned callback.
	StartScan(ctx context.Context) error

	// StopScan cancels any active scan.
	StopScan() error
}
