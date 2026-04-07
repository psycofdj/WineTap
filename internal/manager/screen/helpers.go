package screen

import (
	"errors"
	"log/slog"
	"strconv"
	"strings"
	"unicode"

	qt "github.com/mappu/miqt/qt6"
	"github.com/mappu/miqt/qt6/mainthread"
	"golang.org/x/text/unicode/norm"

	"winetap/internal/client"
)

// ── Accent folding ────────────────────────────────────────────────────────────

// foldAccents returns s lowercased with diacritics stripped,
// so that accented French letters sort alongside their base letter.
func foldAccents(s string) string {
	t := norm.NFD.String(strings.ToLower(s))
	var b strings.Builder
	for _, r := range t {
		if unicode.Is(unicode.Mn, r) {
			continue
		}
		b.WriteRune(r)
	}
	return b.String()
}

// ── Item helpers ──────────────────────────────────────────────────────────────

const userRole = 256 // Qt::UserRole
const sortRole = 257 // Qt::UserRole + 1, used for numeric sort keys

// nonEditableItem creates a read-only QStandardItem.
func nonEditableItem(text string) *qt.QStandardItem {
	item := qt.NewQStandardItem2(text)
	item.SetEditable(false)
	return item
}

// ── Color helpers ─────────────────────────────────────────────────────────────

var colorNames = map[int32]string{
	client.ColorRouge:        "Rouge",
	client.ColorBlanc:        "Blanc",
	client.ColorRose:         "Rosée",
	client.ColorEffervescent: "Effervescent",
	client.ColorAutre:        "Autre",
}

// colorOrder is the canonical display order for color combo boxes.
var colorOrder = []int32{
	client.ColorBlanc,
	client.ColorRouge,
	client.ColorRose,
	client.ColorEffervescent,
	client.ColorAutre,
}

// ── Button and widget helpers ─────────────────────────────────────────────────

// setBtnClass assigns a cssClass dynamic property to btn so the global
// application stylesheet can target it with QPushButton[cssClass="…"].
func setBtnClass(btn *qt.QPushButton, class string) {
	btn.QAbstractButton.QWidget.QObject.SetProperty("cssClass", qt.NewQVariant11(class))
}

// stdBtnShortcuts maps semantic button classes to their shortcut hint text.
// Used to append shortcut info to tooltips.
var stdBtnShortcuts = map[string]string{
	"add":     "Ctrl+A",
	"delete":  "Ctrl+Suppr",
	"copy":    "Ctrl+D",
	"search":  "Ctrl+T",
	"warning": "Ctrl+B",
}

// newStdBtn creates a standard action button from a semantic class name.
func newStdBtn(class string) *qt.QPushButton {
	type def struct{ symbol, tooltip string }
	defs := map[string]def{
		"add":           {"＋", "Ajouter"},
		"delete":        {"−", "Supprimer"},
		"copy":          {"⧉", "Copier"},
		"save":          {"✔", "Enregistrer"},
		"save-continue": {"✔➜", "Enregistrer et continuer"},
		"cancel":        {"✕", "Annuler"},
		"search":        {"⌕", "Rechercher"},
		"warning":       {"🍷", "Marquée comme bue"},
	}
	d := defs[class]
	btn := qt.NewQPushButton3(d.symbol + " " + d.tooltip)
	setBtnClass(btn, class)
	tip := d.tooltip
	if sc, ok := stdBtnShortcuts[class]; ok {
		tip += "  (" + sc + ")"
	}
	btn.SetToolTip(tip)
	btn.SetFixedHeight(36)
	return btn
}

// addShortcut creates a QShortcut on parent for the given key sequence string
// (e.g. "Ctrl+A", "Alt+D") and connects it to fn.
func addShortcut(parent *qt.QWidget, keySeq string, fn func()) {
	sc := qt.NewQShortcut2(qt.NewQKeySequence2(keySeq), parent.QObject)
	sc.SetContext(qt.WidgetWithChildrenShortcut)
	sc.OnActivated(fn)
}

// addShortcutInt creates a QShortcut on parent using an integer key combination
// (e.g. int(qt.ControlModifier)|int(qt.Key_1)) and connects it to fn.
func addShortcutInt(parent *qt.QWidget, key int, fn func()) {
	sc := qt.NewQShortcut2(qt.NewQKeySequence3(key), parent.QObject)
	sc.SetContext(qt.WidgetWithChildrenShortcut)
	sc.OnActivated(fn)
}

// setWidgetRole assigns a "role" dynamic property to any widget so the global
// stylesheet can target it with QWidget[role="…"], QLabel[role="…"] etc.
func setWidgetRole(w *qt.QWidget, role string) {
	w.QObject.SetProperty("role", qt.NewQVariant11(role))
}

// ── Stylesheets ───────────────────────────────────────────────────────────────

// filterPopupStyle is the common stylesheet for filter/sort popup windows.
const filterPopupStyle = "QWidget { background:#fff; border:1px solid #bdc3c7; border-radius:4px; }" +
	"QPushButton { padding:3px 10px; }"

// ── Field helpers ─────────────────────────────────────────────────────────────

// parseOptFloat parses a string as float64, returning nil on empty or error.
func parseOptFloat(s string) *float64 {
	if s == "" {
		return nil
	}
	v, err := strconv.ParseFloat(s, 64)
	if err != nil {
		return nil
	}
	return &v
}

// ── Error helper ──────────────────────────────────────────────────────────────

// showQuestion shows a "Oui/Non" confirmation dialog with proper window
// decorations. parent should be the closest ancestor QWidget so the compositor
// can attach decorations and center the dialog relative to the parent window.
// Must be called from the main thread.
func showQuestion(parent *qt.QWidget, title, text string) bool {
	mb := qt.NewQMessageBox6(
		qt.QMessageBox__Question, title, text,
		qt.QMessageBox__Yes|qt.QMessageBox__No, parent,
	)
	return mb.QDialog.Exec() == int(qt.QMessageBox__Yes)
}

// showErr shows a Qt warning dialog.  Must be called from the main thread.
// When the error is an APIError it displays only the human-readable message
// (e.g. "domain 5 is referenced by cuvées and cannot be deleted") instead of
// the raw "code: message" string.
func showErr(msg string, err error) {
	detail := err.Error()
	var apiErr *client.APIError
	if errors.As(err, &apiErr) {
		detail = apiErr.Message
	}
	qt.QMessageBox_Warning(nil, "Erreur", msg+" : "+detail)
}

// ── Async helper ──────────────────────────────────────────────────────────────

// doAsync runs work in a goroutine.  On error it logs logMsg and shows a
// warning dialog with uiMsg; on success it calls then on the Qt main thread.
func doAsync(log *slog.Logger, logMsg, uiMsg string, work func() error, then func()) {
	go func() {
		if err := work(); err != nil {
			log.Error(logMsg, "error", err)
			mainthread.Start(func() { showErr(uiMsg, err) })
			return
		}
		if then != nil {
			mainthread.Start(then)
		}
	}()
}

// ── Filter popup helpers ──────────────────────────────────────────────────────

// checkedItems returns the text of every checked item in list.
func checkedItems(list *qt.QListWidget) map[string]struct{} {
	out := map[string]struct{}{}
	for i := 0; i < list.Count(); i++ {
		item := list.Item(i)
		if item.CheckState() == qt.Checked {
			out[item.Text()] = struct{}{}
		}
	}
	return out
}

// setAllChecked checks or unchecks all items in list.
func setAllChecked(list *qt.QListWidget, check bool) {
	state := qt.Checked
	if !check {
		state = qt.Unchecked
	}
	for i := 0; i < list.Count(); i++ {
		list.Item(i).SetCheckState(state)
	}
}

// makeFilterPopup builds a standard sort+filter popup for col.
// The popup contains "A→Z / Z→A" sort buttons wired to ts, Tout/Aucun quick
// buttons, and the provided list widget (with OnItemChanged connected to
// ts.Proxy.InvalidateFilter).
func makeFilterPopup(ts *tableScreen, col int, list *qt.QListWidget) *qt.QWidget {
	popup := qt.NewQWidget2()
	popup.SetWindowFlags(qt.Popup)
	popup.SetStyleSheet(filterPopupStyle)
	layout := qt.NewQVBoxLayout(popup)
	layout.SetContentsMargins(6, 6, 6, 6)
	layout.SetSpacing(4)

	sortAscBtn := qt.NewQPushButton3("↑  Trier A → Z")
	setWidgetRole(sortAscBtn.QAbstractButton.QWidget, "sort")
	sortAscBtn.OnClicked(func() { ts.Sort(col, qt.AscendingOrder); popup.Hide() })
	sortDescBtn := qt.NewQPushButton3("↓  Trier Z → A")
	setWidgetRole(sortDescBtn.QAbstractButton.QWidget, "sort")
	sortDescBtn.OnClicked(func() { ts.Sort(col, qt.DescendingOrder); popup.Hide() })
	layout.AddWidget(sortAscBtn.QAbstractButton.QWidget)
	layout.AddWidget(sortDescBtn.QAbstractButton.QWidget)

	sep1 := qt.NewQFrame2()
	sep1.SetFrameShape(qt.QFrame__HLine)
	setWidgetRole(sep1.QWidget, "popup-sep")
	layout.AddWidget(sep1.QWidget)

	quickRow := qt.NewQHBoxLayout2()
	allBtn := qt.NewQPushButton3("Tout")
	allBtn.OnClicked(func() { setAllChecked(list, true) })
	noneBtn := qt.NewQPushButton3("Aucun")
	noneBtn.OnClicked(func() { setAllChecked(list, false) })
	quickRow.AddWidget(allBtn.QAbstractButton.QWidget)
	quickRow.AddWidget(noneBtn.QAbstractButton.QWidget)
	quickRow.AddWidget2(qt.NewQWidget2(), 1)
	layout.AddLayout(quickRow.QBoxLayout.QLayout)

	sep2 := qt.NewQFrame2()
	sep2.SetFrameShape(qt.QFrame__HLine)
	setWidgetRole(sep2.QWidget, "popup-sep")
	layout.AddWidget(sep2.QWidget)

	list.SetFrameShape(qt.QFrame__NoFrame)
	list.OnItemChanged(func(_ *qt.QListWidgetItem) {
		ts.Proxy.InvalidateFilter()
		ts.refreshFilterHeaders()
	})
	layout.AddWidget2(list.QListView.QAbstractItemView.QAbstractScrollArea.QFrame.QWidget, 1)

	// Register this list so refreshFilterHeaders can check it.
	if ts.filterLists == nil {
		ts.filterLists = make(map[int]*qt.QListWidget)
	}
	ts.filterLists[col] = list

	return popup
}
