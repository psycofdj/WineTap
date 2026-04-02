package manager

import (
	"context"
	"log/slog"
	"os"
	"sync"
	"time"

	qt "github.com/mappu/miqt/qt6"
	"github.com/mappu/miqt/qt6/mainthread"

	"winetap/internal/client"
	"winetap/internal/manager/assets"
	"winetap/internal/manager/screen"
)

// Manager owns the Qt application, HTTP client, NFC scanner, and all screens.
type Manager struct {
	log        *slog.Logger
	logHandler *SwappableHandler

	// HTTP client (v2 phone REST API)
	httpClient *client.WineTapHTTPClient

	// NFC scanner (via phone server)
	scanner *NFCScanner

	DebugMode bool

	// Config
	appCfg     Config
	appCfgPath string

	// Qt
	app              *qt.QApplication
	defaultStyleName string // style name captured at startup, used to restore system default
	window           *qt.QMainWindow
	stack            *qt.QStackedWidget
	notifBar         *qt.QPushButton

	// Screens
	inv   *screen.InventoryScreen
	desig *screen.DesignationsScreen
	doms  *screen.DomainsScreen
	cuvs  *screen.CuveesScreen
	cfg   *screen.SettingsScreen
	dash  *screen.DashboardScreen

	// Screen indices in the stacked widget
	idxInv   int
	idxDesig int
	idxDoms  int
	idxCuvs  int
	idxCfg   int
	idxDash  int

	// mu protects appCfg.PhoneAddress, which is written by httpHealthLoop and
	// read/written by the Qt main thread (updateNotifBar, GetSettings, SaveSettings).
	mu sync.Mutex

	// Notification state — only accessed from the Qt main thread
	serverOK         bool
	serverConnecting bool // true while awaiting first health-check confirmation
}

// New creates the Qt application, initialises all components from cfg, and builds the UI.
// Must be called from the main OS thread.
func New(cfg Config, cfgPath string, log *slog.Logger, logHandler *SwappableHandler) (*Manager, error) {
	app := qt.NewQApplication(os.Args)
	defaultStyleName := qt.QApplication_Style().ObjectName()
	if cfg.QtStyle != "" {
		if style := qt.QStyleFactory_Create(cfg.QtStyle); style != nil {
			qt.QApplication_SetStyle(style)
		}
	}
	app.SetStyleSheet(assets.Stylesheet)

	qt.QCoreApplication_SetApplicationName("winetap")
	qt.QGuiApplication_SetDesktopFileName("winetap")
	pm := qt.NewQPixmap()
	pm.LoadFromDataWithData(assets.Icon)
	qt.QGuiApplication_SetWindowIcon(qt.NewQIcon2(pm))

	// mDNS discovery: try to find the phone on the local network.
	discCtx, discCancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer discCancel()
	if addr, discErr := DiscoverPhone(discCtx, log); discErr != nil {
		log.Warn("mDNS discovery error", "error", discErr)
	} else if addr != "" {
		cfg.PhoneAddress = addr
		if saveErr := saveConfig(cfgPath, cfg); saveErr != nil {
			log.Warn("save config after discovery", "error", saveErr)
		}
	}
	// Fall back to cached address from YAML if discovery found nothing.
	if cfg.PhoneAddress != "" {
		log.Info("phone address resolved", "address", cfg.PhoneAddress)
	} else {
		log.Warn("phone address unknown — manual configuration required")
	}
	httpClient := client.NewWineTapHTTPClient(cfg.PhoneAddress)

	nfcScanner := NewNFCScanner(httpClient, log)

	m := &Manager{
		log:              log,
		logHandler:       logHandler,
		app:              app,
		defaultStyleName: defaultStyleName,
		httpClient:       httpClient,
		scanner:          nfcScanner,
		appCfg:           cfg,
		appCfgPath:       cfgPath,
		serverOK:         false,
		serverConnecting: cfg.PhoneAddress != "",
		DebugMode:        log.Enabled(context.Background(), slog.LevelDebug),
	}

	m.buildUI()
	return m, nil
}

// Run starts background goroutines, shows the window, and enters the Qt event loop.
// Blocks until the window is closed or ctx is cancelled.
func (m *Manager) Run(ctx context.Context) {
	m.updateNotifBar() // apply initial serverConnecting/serverOK state before window appears
	go m.httpHealthLoop(ctx)

	go func() {
		<-ctx.Done()
		mainthread.Start(qt.QCoreApplication_Quit)
	}()

	if m.appCfg.PhoneAddress == "" {
		m.navigate(m.idxCfg) // no phone found — go straight to settings
	} else {
		m.navigate(m.idxInv)
	}
	m.window.Show()
	// On X11 the WM only honors ShowMaximized after the window is mapped.
	// A 50-ms single-shot timer defers the call to the first event-loop tick.
	maxTimer := qt.NewQTimer()
	maxTimer.SetSingleShot(true)
	maxTimer.OnTimeout(func() { m.window.ShowMaximized() })
	maxTimer.Start(50)
	qt.QApplication_Exec()
}

// Close releases the NFC scanner.
func (m *Manager) Close() {
	m.scanner.Close()
}

// ── HTTP health loop ──────────────────────────────────────────────────────────

// httpHealthLoop periodically health-checks the phone via GET /.
// On failure it re-runs mDNS discovery to find the phone's new address.
// Replaces the gRPC subscribeEvents health-check for v2 HTTP connectivity.
func (m *Manager) httpHealthLoop(ctx context.Context) {
	ticker := time.NewTicker(5 * time.Second)
	defer ticker.Stop()

	var lastConsumedAt int64

	for {
		hr, err := m.httpClient.HealthCheck(ctx)
		if err != nil {
			m.log.Warn("phone health check failed", "error", err)
			mainthread.Start(func() { m.setServerStatus(false) }) // no mutex held here

			// Attempt mDNS re-discovery.
			discCtx, discCancel := context.WithTimeout(ctx, 5*time.Second)
			addr, discErr := DiscoverPhone(discCtx, m.log)
			discCancel()
			if discErr != nil {
				m.log.Warn("mDNS re-discovery error", "error", discErr)
			} else if addr != "" {
				m.log.Info("phone re-discovered", "address", addr)
				m.httpClient.SetBaseURL(addr) // internally mutex-protected
				m.mu.Lock()
				m.appCfg.PhoneAddress = addr
				cfgSnapshot := m.appCfg
				m.mu.Unlock()
				if saveErr := saveConfig(m.appCfgPath, cfgSnapshot); saveErr != nil {
					m.log.Warn("save config after re-discovery", "error", saveErr)
				}
			}
		} else {
			mainthread.Start(func() { m.setServerStatus(true) }) // no mutex held here

			// Detect new consume events on the phone and refresh inventory.
			if hr.LastConsumedAt != 0 && hr.LastConsumedAt != lastConsumedAt {
				m.log.Info("phone consumed a bottle, refreshing inventory",
					"last_consumed_at", hr.LastConsumedAt)
				lastConsumedAt = hr.LastConsumedAt
				mainthread.Start(func() { m.inv.OnActivate() })
			}
		}

		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
		}
	}
}

func (m *Manager) setServerStatus(ok bool) {
	m.serverOK = ok
	m.serverConnecting = false // definitive result received
	m.updateNotifBar()
}

func (m *Manager) updateNotifBar() {
	notifBarErrorStyle := "background:#e74c3c;color:white;padding:6px;text-align:left;border:none;"
	notifBarWarnStyle := "background:#e67e22;color:white;padding:6px;text-align:left;border:none;"

	if !m.serverOK {
		if m.serverConnecting {
			m.notifBar.SetText("⏳  Connexion au téléphone en cours…")
			m.notifBar.SetStyleSheet(notifBarWarnStyle)
			m.notifBar.Show()
			return
		}
		m.mu.Lock()
		phoneAddr := m.appCfg.PhoneAddress
		m.mu.Unlock()
		if phoneAddr == "" {
			m.notifBar.SetText("⚠  Téléphone introuvable — configurez l'adresse manuellement")
		} else {
			m.notifBar.SetText("⚠  Téléphone inaccessible")
		}
		m.notifBar.SetStyleSheet(notifBarErrorStyle)
		m.notifBar.Show()
		return
	}
	m.notifBar.Hide()
}

// ── Screen context ────────────────────────────────────────────────────────────

// makeCtx builds the screen.Ctx that is passed to every screen constructor.
func (m *Manager) makeCtx() *screen.Ctx {
	return &screen.Ctx{
		Client: m.httpClient,
		Log:    m.log,
		Scanner: screen.Scanner{
			OnTagScanned: m.scanner.OnTagScanned,
			OnScanError:  m.scanner.OnScanError,
			StartScan: func() error {
				return m.scanner.StartScan(context.Background())
			},
			StopScan: func() error { return m.scanner.StopScan() },
		},
		GetSettings: func() screen.SettingsData {
			m.mu.Lock()
			phoneAddr := m.appCfg.PhoneAddress
			m.mu.Unlock()
			return screen.SettingsData{
				PhoneAddress: phoneAddr,
				LogLevel:     m.appCfg.LogLevel,
				LogFormat:    m.appCfg.LogFormat,
				QtStyle:      m.appCfg.QtStyle,
			}
		},
		SaveSettings: func(d screen.SettingsData) error {
			m.mu.Lock()
			m.appCfg.PhoneAddress = d.PhoneAddress
			m.appCfg.LogLevel = d.LogLevel
			m.appCfg.LogFormat = d.LogFormat
			m.appCfg.QtStyle = d.QtStyle
			cfgSnapshot := m.appCfg
			m.mu.Unlock()

			m.httpClient.SetBaseURL(d.PhoneAddress)

			// Apply log level/format immediately by swapping the handler.
			if m.logHandler != nil {
				m.logHandler.Swap(NewHandler(d.LogLevel, d.LogFormat))
				slog.SetDefault(m.log) // keep package-level default in sync
			}

			// Apply Qt style immediately (runs on the Qt main thread).
			styleName := d.QtStyle
			if styleName == "" {
				styleName = m.defaultStyleName
			}
			qt.QApplication_SetStyleWithStyle(styleName)
			m.app.SetStyleSheet(assets.Stylesheet)

			return saveConfig(m.appCfgPath, cfgSnapshot)
		},
		NavigateToInventoryWithFilter: func(filterType, filterValue string) {
			m.navigate(m.idxInv)
			m.inv.SetFilter(filterType, filterValue)
		},
	}
}

// ── Navigation ────────────────────────────────────────────────────────────────

func (m *Manager) navigate(idx int) {
	m.scanner.StopScan()
	m.stack.SetCurrentIndex(idx)
	switch idx {
	case m.idxInv:
		m.inv.OnActivate()
	case m.idxDesig:
		m.desig.OnActivate()
	case m.idxDoms:
		m.doms.OnActivate()
	case m.idxCuvs:
		m.cuvs.OnActivate()
	case m.idxCfg:
		m.cfg.OnActivate()
	case m.idxDash:
		m.dash.OnActivate()
	}
}

// buildUI constructs the main window, sidebar, stacked widget, and notification bar.
// Must be called from the Qt main thread (inside New).
func (m *Manager) buildUI() {
	m.window = qt.NewQMainWindow2()
	m.window.QWidget.SetWindowTitle("WineTap")

	// Set application and window icon from embedded PNG.
	pm := qt.NewQPixmap()
	pm.LoadFromDataWithData(assets.Icon)
	icon := qt.NewQIcon2(pm)
	qt.QGuiApplication_SetWindowIcon(icon)
	m.window.QWidget.SetWindowIcon(icon)

	central := qt.NewQWidget(m.window.QWidget)
	root := qt.NewQVBoxLayout(central)
	root.SetContentsMargins(0, 0, 0, 0)
	root.SetSpacing(0)

	// Notification bar (hidden by default).
	m.notifBar = qt.NewQPushButton3("")
	m.notifBar.Hide()
	root.AddWidget(m.notifBar.QAbstractButton.QWidget)

	// Body: sidebar + main content.
	body := qt.NewQWidget(central)
	bodyLayout := qt.NewQHBoxLayout(body)
	bodyLayout.SetContentsMargins(0, 0, 0, 0)
	bodyLayout.SetSpacing(0)

	sidebar := m.buildSidebar(body)
	bodyLayout.AddWidget(sidebar)

	m.stack = qt.NewQStackedWidget(body)
	bodyLayout.AddWidget2(m.stack.QFrame.QWidget, 1)

	root.AddWidget2(body, 1)
	m.window.SetCentralWidget(central)

	// Build screens and add to stack.
	ctx := m.makeCtx()
	m.inv = screen.BuildInventoryScreen(ctx)
	m.desig = screen.BuildDesignationsScreen(ctx)
	m.doms = screen.BuildDomainsScreen(ctx)
	m.cuvs = screen.BuildCuveesScreen(ctx)
	m.cfg = screen.BuildSettingsScreen(ctx)
	m.dash = screen.BuildDashboardScreen(ctx)

	m.idxInv = m.stack.AddWidget(m.inv.Widget)
	m.idxDesig = m.stack.AddWidget(m.desig.Widget)
	m.idxDoms = m.stack.AddWidget(m.doms.Widget)
	m.idxCuvs = m.stack.AddWidget(m.cuvs.Widget)
	m.idxCfg = m.stack.AddWidget(m.cfg.Widget)
	m.idxDash = m.stack.AddWidget(m.dash.Widget)
}

func (m *Manager) buildSidebar(parent *qt.QWidget) *qt.QWidget {
	sidebar := qt.NewQWidget(parent)
	sidebar.QObject.SetProperty("role", qt.NewQVariant11("sidebar"))
	sidebar.SetAttribute2(qt.WA_AlwaysShowToolTips, true)

	layout := qt.NewQVBoxLayout(sidebar)
	layout.SetContentsMargins(0, 12, 0, 12)
	layout.SetSpacing(0)

	addSection := func(label string) {
		lbl := qt.NewQLabel3(label)
		lbl.QObject.SetProperty("role", qt.NewQVariant11("sidebar-section"))
		layout.AddWidget(lbl.QWidget)
	}

	addItem := func(label string, fn func()) {
		btn := qt.NewQPushButton3(label)
		btn.QAbstractButton.QWidget.QObject.SetProperty("role", qt.NewQVariant11("sidebar-item"))
		btn.OnClicked(func() { fn() })
		layout.AddWidget(btn.QAbstractButton.QWidget)
	}

	addSection("Catalogue")
	addItem("Appellations", func() { m.navigate(m.idxDesig) })
	addItem("Domaines", func() { m.navigate(m.idxDoms) })
	addItem("Cuvées", func() { m.navigate(m.idxCuvs) })

	addSection("Cave")
	addItem("Tableau de bord", func() { m.navigate(m.idxDash) })
	addItem("Inventaire", func() { m.navigate(m.idxInv) })

	layout.AddWidget2(qt.NewQWidget2(), 1) // spacer

	addSection("Système")
	addItem("Paramètres", func() { m.navigate(m.idxCfg) })

	return sidebar
}
