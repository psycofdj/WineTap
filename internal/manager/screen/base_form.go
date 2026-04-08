package screen

import (
	"net/url"
	"os/exec"
	"runtime"
	"strings"

	qt "github.com/mappu/miqt/qt6"
)

// baseForm provides the structural skeleton shared by all catalogue forms.
//
// The layout is split into three vertical sections:
//
//   - header: magic auto-fill button + name field (managed by baseForm)
//   - body  : empty QFormLayout — subclasses add their specific fields here
//   - footer: description QTextEdit (managed by baseForm); subclasses may
//     append extra rows (e.g. picture)
//
// Field labels are tracked so that alignLabels can set them all to the same
// width.  Use addHeader / addBody / addFooter to add labelled rows, then call
// alignLabels once all rows have been added.
type baseForm struct {
	widget        *qt.QWidget
	vl            *qt.QVBoxLayout // top-level layout; child sections appended here
	titleLabel    *qt.QLabel      // form title; set via SetTitle
	titleSep      *qt.QFrame      // separator below titleLabel
	header        *qt.QFormLayout // auto button + name field
	form          *qt.QFormLayout // body — subclass fields go here
	footer        *qt.QFormLayout // description + extra footer rows
	labels        []*qt.QLabel    // all field labels; used by alignLabels
	nameLabel     *qt.QLabel
	nameEdit      *qt.QLineEdit
	autoContainer *qt.QWidget // row containing chatGPTBtn; hide to remove the row
	chatGPTBtn    *qt.QPushButton
	descEdit      *qt.QTextEdit
	formBox       *qt.QWidget // rounded container for header+body+footer
	canEnable     func() bool // nil → enabled whenever nameEdit is non-empty
}

// newBaseForm builds the common skeleton.
// canEnable, if non-nil, is called by recheckAuto to determine whether the
// ChatGPT button should be enabled (use this when more than the name matters).
func newBaseForm(nameLabel string, nameRequired bool, canEnable func() bool) *baseForm {
	f := &baseForm{canEnable: canEnable}

	f.widget = qt.NewQWidget2()
	f.vl = qt.NewQVBoxLayout(f.widget)
	f.vl.SetContentsMargins(0, 0, 0, 0)
	f.vl.SetSpacing(10)

	// ── Title ─────────────────────────────────────────────────────────────────
	f.titleLabel = qt.NewQLabel3("")
	setWidgetRole(f.titleLabel.QFrame.QWidget, "form-title")
	f.vl.AddWidget(f.titleLabel.QWidget)

	f.titleSep = qt.NewQFrame2()
	f.titleSep.SetFrameShape(qt.QFrame__HLine)
	setWidgetRole(f.titleSep.QWidget, "sep")
	f.vl.AddWidget(f.titleSep.QWidget)

	// ── Rounded container for header + body + footer ─────────────────────────
	f.formBox = qt.NewQWidget2()
	formBox := f.formBox
	setWidgetRole(formBox, "inline-box")
	formBoxVL := qt.NewQVBoxLayout(formBox)
	formBoxVL.SetContentsMargins(8, 8, 8, 8)
	formBoxVL.SetSpacing(10)

	// ── Header section (auto button + name) ───────────────────────────────────
	f.header = qt.NewQFormLayout2()
	f.header.SetRowWrapPolicy(qt.QFormLayout__WrapLongRows)

	f.chatGPTBtn = qt.NewQPushButton3("💬 Demander à ChatGPT")
	f.chatGPTBtn.SetToolTip("Ouvrir ChatGPT dans le navigateur")
	f.chatGPTBtn.SetEnabled(false)
	f.chatGPTBtn.SetSizePolicy2(qt.QSizePolicy__Expanding, qt.QSizePolicy__Fixed)

	f.autoContainer = qt.NewQWidget2()
	autoVL := qt.NewQVBoxLayout(f.autoContainer)
	autoVL.SetContentsMargins(0, 0, 0, 0)
	autoVL.SetSpacing(2)
	autoVL.AddWidget(f.chatGPTBtn.QAbstractButton.QWidget)
	f.header.AddRowWithWidget(f.autoContainer)

	f.nameLabel = f.addHeader(nameLabel, f.nameEdit_init(), nameRequired)

	formBoxVL.AddLayout(f.header.QLayout)

	// ── Body section (subclass fields) ────────────────────────────────────────
	f.form = qt.NewQFormLayout2()
	f.form.SetRowWrapPolicy(qt.QFormLayout__WrapLongRows)
	formBoxVL.AddLayout(f.form.QLayout)

	// ── Footer section (description + extras) ─────────────────────────────────
	f.footer = qt.NewQFormLayout2()
	f.footer.SetRowWrapPolicy(qt.QFormLayout__WrapLongRows)

	f.descEdit = qt.NewQTextEdit2()
	f.descEdit.SetPlaceholderText("Description (optionnel)")
	f.descEdit.SetVerticalScrollBarPolicy(qt.ScrollBarAsNeeded)
	f.descEdit.SetTabChangesFocus(true)
	f.addFooter("Description", f.descEdit.QAbstractScrollArea.QFrame.QWidget, false)

	f.descEdit.OnTextChanged(func() { f.adjustDescHeight() })

	formBoxVL.AddLayout(f.footer.QLayout)
	f.vl.AddWidget(formBox)

	return f
}

// nameEdit_init creates the name QLineEdit and wires its signal.
// Separated so the widget exists before addHeader is called.
func (f *baseForm) nameEdit_init() *qt.QWidget {
	f.nameEdit = qt.NewQLineEdit2()
	f.nameEdit.OnTextChanged(func(_ string) { f.recheckAuto() })
	return f.nameEdit.QWidget
}

// ── Add labelled rows ─────────────────────────────────────────────────────────

// addHeader adds a labelled row to the header section and returns the label.
// Required labels are styled with font-weight 200 to distinguish them.
func (f *baseForm) addHeader(fieldName string, w *qt.QWidget, required bool) *qt.QLabel {
	return f.addRow(f.header, fieldName, w, required)
}

// addBody adds a labelled row to the body section and returns the label.
func (f *baseForm) addBody(fieldName string, w *qt.QWidget, required bool) *qt.QLabel {
	return f.addRow(f.form, fieldName, w, required)
}

// addFooter adds a labelled row to the footer section and returns the label.
func (f *baseForm) addFooter(fieldName string, w *qt.QWidget, required bool) *qt.QLabel {
	return f.addRow(f.footer, fieldName, w, required)
}

func (f *baseForm) addRow(layout *qt.QFormLayout, fieldName string, w *qt.QWidget, required bool) *qt.QLabel {
	lbl := qt.NewQLabel3(fieldName)
	if required {
		lbl.QFrame.QWidget.SetStyleSheet("font-weight: 500;")
	}
	f.labels = append(f.labels, lbl)
	layout.AddRow(lbl.QWidget, w)
	return lbl
}

// alignLabels sets all tracked labels to the same fixed width, based on the
// widest label text.  Call this once at the end of each form constructor after
// all rows have been added.
func (f *baseForm) alignLabels() {
	if len(f.labels) == 0 {
		return
	}
	fm := f.labels[0].QFrame.QWidget.FontMetrics()
	maxW := 0
	for _, lbl := range f.labels {
		w := fm.HorizontalAdvance(lbl.Text())
		if w > maxW {
			maxW = w
		}
	}
	maxW += 8 // breathing room
	for _, lbl := range f.labels {
		lbl.QFrame.QWidget.SetFixedWidth(maxW)
	}
}

// adjustDescHeight resizes the description QTextEdit so that:
//   - when empty: collapses to a single line height
//   - when has text: grows to fit content without scrollbar, capped at 5 lines
func (f *baseForm) adjustDescHeight() {
	w := f.descEdit.QAbstractScrollArea.QFrame.QWidget
	fm := w.FontMetrics()
	lineH := fm.LineSpacing()
	frame := f.descEdit.QAbstractScrollArea.QFrame.FrameWidth() * 2
	docMargin := int(f.descEdit.Document().DocumentMargin()) * 2
	extra := frame + docMargin
	//maxH := lineH*5 + extra

	if strings.TrimSpace(f.descEdit.ToPlainText()) == "" {
		w.SetMinimumHeight(lineH + extra)
		w.SetMaximumHeight(lineH + extra)
		return
	}

	docH := int(f.descEdit.Document().Size().Height()) + frame
	if docH < lineH+extra {
		docH = lineH + extra
	}

	w.SetMinimumHeight(docH)
	w.SetMaximumHeight(docH)
}

// recheckAuto enables or disables the ChatGPT button based on canEnable / name.
func (f *baseForm) recheckAuto() {
	var enabled bool
	if f.canEnable != nil {
		enabled = f.canEnable()
	} else {
		enabled = f.nameEdit.Text() != ""
	}
	f.chatGPTBtn.SetEnabled(enabled)
}

// showName shows or hides the name row.
func (f *baseForm) showName(show bool) {
	f.nameLabel.SetVisible(show)
	f.nameEdit.SetVisible(show)
}

// chainTabOrder sets the tab order for a sequence of widgets.
// Each widget in the list will tab to the next one.
func chainTabOrder(widgets []*qt.QWidget) {
	for i := 0; i < len(widgets)-1; i++ {
		qt.QWidget_SetTabOrder(widgets[i], widgets[i+1])
	}
}

// openChatGPT opens the default browser to chatgpt.com with the given query.
func openChatGPT(query string) {
	u := "https://chatgpt.com/?q=" + url.QueryEscape(query)
	var cmd *exec.Cmd
	switch runtime.GOOS {
	case "darwin":
		cmd = exec.Command("open", u)
	case "windows":
		cmd = exec.Command("rundll32", "url.dll,FileProtocolHandler", u)
	default:
		cmd = exec.Command("xdg-open", u)
	}
	_ = cmd.Start()
}

func (f *baseForm) Name() string            { return strings.TrimSpace(f.nameEdit.Text()) }
func (f *baseForm) SetTitle(t string)       { f.titleLabel.SetText(t) }
func (f *baseForm) Description() string     { return strings.TrimSpace(f.descEdit.ToPlainText()) }
func (f *baseForm) ClearDescription()       { f.descEdit.Clear() }
func (f *baseForm) SetDescription(t string) { f.descEdit.SetPlainText(t) }

// foldableSection is a collapsible wrapper that embeds a child widget under a
// clickable header button.  The header shows ▶ when folded and ▼ when expanded.
// Create instances via baseForm.addChildSection; do not construct directly.
type foldableSection struct {
	Widget    *qt.QWidget
	headerBtn *qt.QPushButton
	content   *qt.QWidget
	title     string
	expanded  bool
	form      *baseForm
	child     *baseForm
}

// SetTitle updates the displayed title and refreshes the header button text.
func (s *foldableSection) SetTitle(title string) {
	s.title = title
	s.refreshHeader()
}

// SetExpanded shows or hides the content area and updates the arrow icon.
func (s *foldableSection) SetExpanded(expanded bool) {
	s.expanded = expanded
	s.refreshHeader()
	if expanded {
		s.content.Show()
		if s.child != nil {
			s.child.adjustDescHeight()
		}
	} else {
		s.content.Hide()
	}
}

func (s *foldableSection) toggle() { s.SetExpanded(!s.expanded) }

func (s *foldableSection) refreshHeader() {
	arrow := "▶"
	if s.expanded {
		arrow = "▼"
	}
	s.headerBtn.SetText(arrow + " " + s.title)
}

// addChildSection creates a foldable section containing child, appends it to
// the form's VBoxLayout, and returns the section handle.  The section is hidden
// by default; call Widget.Show() when relevant.
func (f *baseForm) addChildSection(title string, child *baseForm) *foldableSection {
	s := &foldableSection{title: title, form: f, child: child}

	// Remove the border on the embedded form's container so we don't get
	// a nested border inside the foldable section's own inline-box.
	child.formBox.SetProperty("role", qt.NewQVariant11(""))

	s.Widget = qt.NewQWidget2()
	setWidgetRole(s.Widget, "inline-box")
	vl := qt.NewQVBoxLayout(s.Widget)
	vl.SetContentsMargins(0, 0, 0, 0)
	vl.SetSpacing(0)

	s.headerBtn = qt.NewQPushButton3("")
	s.headerBtn.SetFlat(true)
	setWidgetRole(s.headerBtn.QWidget, "form-title")
	s.headerBtn.OnClicked(func() { s.toggle() })
	vl.AddWidget(s.headerBtn.QAbstractButton.QWidget)

	s.content = qt.NewQWidget2()
	contentVL := qt.NewQVBoxLayout(s.content)
	contentVL.SetContentsMargins(8, 4, 8, 8)
	contentVL.SetSpacing(4)
	contentVL.AddWidget(child.widget)
	vl.AddWidget(s.content)

	s.refreshHeader()
	s.Widget.Hide()
	f.vl.AddWidget(s.Widget)
	return s
}
