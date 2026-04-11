package screen

import (
	qt "github.com/mappu/miqt/qt6"
)

// SettingsScreen is the application settings page.
type SettingsScreen struct {
	Widget *qt.QWidget
	ctx    *Ctx

	phoneAddressEdit *qt.QLineEdit
	discoveryLbl     *qt.QLabel
	logLevelCombo    *qt.QComboBox
	logFormatCombo   *qt.QComboBox
	qtStyleCombo     *qt.QComboBox
	qtStyleKeys      []string // ordered list matching combo indices; index 0 = system default
	aiProviderCombo  *qt.QComboBox
}

// BuildSettingsScreen constructs the settings screen.
func BuildSettingsScreen(ctx *Ctx) *SettingsScreen {
	s := &SettingsScreen{ctx: ctx}

	s.Widget = qt.NewQWidget2()
	root := qt.NewQVBoxLayout(s.Widget)
	root.SetContentsMargins(24, 24, 24, 24)
	root.SetSpacing(12)

	title := qt.NewQLabel3("Paramètres")
	setWidgetRole(title.QFrame.QWidget, "screen-title")
	root.AddWidget(title.QWidget)

	// ── Connection settings ───────────────────────────────────────────────
	connGroup := qt.NewQLabel3("Connexion")
	setWidgetRole(connGroup.QFrame.QWidget, "section-header")
	root.AddWidget(connGroup.QWidget)

	form := qt.NewQFormLayout2()

	s.phoneAddressEdit = qt.NewQLineEdit2()
	s.phoneAddressEdit.SetPlaceholderText("http://192.168.1.x:8080")
	form.AddRow3("Adresse du téléphone:", s.phoneAddressEdit.QWidget)

	s.discoveryLbl = qt.NewQLabel3("")
	s.discoveryLbl.SetStyleSheet("color:#888;font-size:11px;")
	form.AddRow3("", s.discoveryLbl.QWidget)

	root.AddLayout(form.QLayout)

	// ── Log settings ──────────────────────────────────────────────────────
	logGroup := qt.NewQLabel3("Journal")
	setWidgetRole(logGroup.QFrame.QWidget, "section-header")
	root.AddWidget(logGroup.QWidget)

	logForm := qt.NewQFormLayout2()

	s.logLevelCombo = qt.NewQComboBox2()
	for _, l := range []string{"debug", "info", "warn", "error"} {
		s.logLevelCombo.AddItem(l)
	}
	logForm.AddRow3("Niveau:", s.logLevelCombo.QWidget)

	s.logFormatCombo = qt.NewQComboBox2()
	for _, f := range []string{"text", "json"} {
		s.logFormatCombo.AddItem(f)
	}
	logForm.AddRow3("Format:", s.logFormatCombo.QWidget)

	root.AddLayout(logForm.QLayout)

	// ── Appearance settings ───────────────────────────────────────────────
	appearGroup := qt.NewQLabel3("Apparence")
	setWidgetRole(appearGroup.QFrame.QWidget, "section-header")
	root.AddWidget(appearGroup.QWidget)

	appearForm := qt.NewQFormLayout2()

	s.qtStyleCombo = qt.NewQComboBox2()
	s.qtStyleKeys = append([]string{""}, qt.QStyleFactory_Keys()...)
	s.qtStyleCombo.AddItem("(système par défaut)")
	for _, k := range qt.QStyleFactory_Keys() {
		s.qtStyleCombo.AddItem(k)
	}
	appearForm.AddRow3("Style Qt :", s.qtStyleCombo.QWidget)

	root.AddLayout(appearForm.QLayout)

	// ── AI assistant settings ─────────────────────────────────────────────
	aiGroup := qt.NewQLabel3("Assistant IA")
	setWidgetRole(aiGroup.QFrame.QWidget, "section-header")
	root.AddWidget(aiGroup.QWidget)

	aiForm := qt.NewQFormLayout2()

	s.aiProviderCombo = qt.NewQComboBox2()
	for _, p := range []string{"ChatGPT", "Claude"} {
		s.aiProviderCombo.AddItem(p)
	}
	aiForm.AddRow3("Fournisseur :", s.aiProviderCombo.QWidget)

	root.AddLayout(aiForm.QLayout)

	saveBtn := qt.NewQPushButton3("Sauvegarder")
	setBtnClass(saveBtn, "success")
	saveBtn.OnClicked(func() { s.onSave() })
	root.AddWidget(saveBtn.QAbstractButton.QWidget)

	root.AddWidget2(qt.NewQWidget2(), 1) // spacer
	return s
}

// OnActivate fills the form from the current config.
func (s *SettingsScreen) OnActivate() {
	cfg := s.ctx.GetSettings()
	s.phoneAddressEdit.SetText(cfg.PhoneAddress)
	if cfg.PhoneAddress != "" {
		s.discoveryLbl.SetText("Découvert automatiquement")
	} else {
		s.discoveryLbl.SetText("Configuration manuelle requise")
	}
	for i, l := range []string{"debug", "info", "warn", "error"} {
		if l == cfg.LogLevel {
			s.logLevelCombo.SetCurrentIndex(i)
			break
		}
	}
	for i, f := range []string{"text", "json"} {
		if f == cfg.LogFormat {
			s.logFormatCombo.SetCurrentIndex(i)
			break
		}
	}
	s.qtStyleCombo.SetCurrentIndex(0) // default: system
	for i, k := range s.qtStyleKeys {
		if k == cfg.QtStyle {
			s.qtStyleCombo.SetCurrentIndex(i)
			break
		}
	}
	if cfg.AIProvider == "claude" {
		s.aiProviderCombo.SetCurrentIndex(1)
	} else {
		s.aiProviderCombo.SetCurrentIndex(0)
	}
}

func (s *SettingsScreen) onSave() {
	aiProvider := "chatgpt"
	if s.aiProviderCombo.CurrentIndex() == 1 {
		aiProvider = "claude"
	}
	d := SettingsData{
		PhoneAddress: s.phoneAddressEdit.Text(),
		LogLevel:     s.logLevelCombo.CurrentText(),
		LogFormat:    s.logFormatCombo.CurrentText(),
		QtStyle:      s.qtStyleKeys[s.qtStyleCombo.CurrentIndex()],
		AIProvider:   aiProvider,
	}
	if err := s.ctx.SaveSettings(d); err != nil {
		s.ctx.Log.Error("save config", "error", err)
		qt.QMessageBox_Warning(nil, "Erreur", "Impossible de sauvegarder les paramètres : "+err.Error())
		return
	}
	qt.QMessageBox_Information(nil, "Paramètres", "Paramètres sauvegardés.")
}
