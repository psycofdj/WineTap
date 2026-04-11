// Package screen contains the Qt screen widgets for the winetap manager UI.
// Each screen is self-contained and communicates with the rest of the application
// through the Ctx struct, which holds callbacks and shared resources.  This
// avoids a circular import between the screen and manager packages.
package screen

import (
	"log/slog"

	"winetap/internal/client"
)

// SettingsData is the view of the application config that the settings screen
// reads and writes.  It mirrors manager.Config but lives here to avoid a
// circular import.
type SettingsData struct {
	PhoneAddress string // "http://host:port"; empty = not yet discovered
	LogLevel     string
	LogFormat    string
	QtStyle      string // Qt widget style name; empty = system default
	AIProvider   string // "chatgpt" or "claude"; empty defaults to "chatgpt"
}

// Filter type constants for dashboard drill-down navigation.
const (
	FilterByColor       = "color"
	FilterByDesignation = "designation"
	FilterByRegion      = "region"
)

// Scanner mirrors the manager.Scanner interface using function fields to avoid
// circular imports between screen and manager packages.
// Every scan is a single read — the manager loops for bulk intake.
type Scanner struct {
	OnTagScanned func(callback func(tagID string))
	OnScanError  func(callback func(err error))
	StartScan    func() error
	StopScan     func() error
}

// Ctx is passed to every screen constructor.  Use function fields rather than
// a direct *manager.Manager pointer so that the screen package never imports
// the manager package.
type Ctx struct {
	Client  *client.WineTapHTTPClient
	Log     *slog.Logger
	Scanner Scanner

	GetSettings  func() SettingsData
	SaveSettings func(SettingsData) error

	// Dashboard drill-down: navigates to inventory with a pre-applied filter.
	NavigateToInventoryWithFilter func(filterType, filterValue string)
}
