package screen

import (
	"context"
	"fmt"
	"strings"
	"time"

	qt "github.com/mappu/miqt/qt6"
	"github.com/mappu/miqt/qt6/mainthread"

	"winetap/internal/client"
)

// inventoryBottleForm is the field widget for adding or editing a bottle.
// It embeds baseForm: the name field is used as the cuvée selector, bottle-
// specific fields go in the body, and description lives in the footer.
// The inline cuvée form is a foldable child section that recursively displays
// domain and designation sub-forms.
//
// It has no own buttons, scroll area, or title — those are provided by tableScreen.
type inventoryBottleForm struct {
	*baseForm
	ctx *Ctx

	editBottleID int64  // 0 = add mode; non-zero = edit mode
	epc          string // optional NFC tag ID sent with AddBottle

	allCuvees   []client.Cuvee
	cuveeLabels []string // "CuveeName — DomainName", parallel to allCuvees

	epcLabel        *qt.QLabel // read-only EPC display
	addedAtLabel    *qt.QLabel // read-only added_at (edit mode only)
	consumedAtLabel *qt.QLabel // read-only consumed_at (consumed bottles only)

	vintageSpin *qt.QSpinBox
	drinkSpin   *qt.QSpinBox
	priceEdit   *qt.QLineEdit

	// Inline cuvée creation / editing — shown based on typed text.
	cuveeForm *cuveeForm
	cuveeSect *foldableSection
}

func newInventoryBottleForm(ctx *Ctx) *inventoryBottleForm {
	f := &inventoryBottleForm{ctx: ctx}
	f.baseForm = newBaseForm("Cuvée", "", true, nil)

	// Hide the auto-fill row — bottles have no AI auto-fill.
	f.autoContainer.Hide()

	// Configure the name field as a cuvée selector with completer.
	f.nameEdit.SetPlaceholderText("Nom de la cuvée")
	f.nameEdit.SetClearButtonEnabled(true)

	// ── Header: read-only metadata ────────────────────────────────────────────
	f.epcLabel = qt.NewQLabel3("—")
	f.epcLabel.SetStyleSheet("color:#888;font-family:monospace;")
	f.addHeader("EPC", f.epcLabel.QFrame.QWidget, false)

	f.addedAtLabel = qt.NewQLabel3("—")
	f.addedAtLabel.SetStyleSheet("color:#888;")
	f.addHeader("Ajoutée le", f.addedAtLabel.QFrame.QWidget, false)

	f.consumedAtLabel = qt.NewQLabel3("—")
	f.consumedAtLabel.SetStyleSheet("color:#888;")
	f.addHeader("Bue le", f.consumedAtLabel.QFrame.QWidget, false)

	// Initially hidden; shown by loadBottle.
	f.header.SetRowVisible2(f.addedAtLabel.QWidget, false)
	f.header.SetRowVisible2(f.consumedAtLabel.QWidget, false)

	// ── Body: editable bottle fields ──────────────────────────────────────────
	currentYear := time.Now().Year()

	f.vintageSpin = qt.NewQSpinBox2()
	f.vintageSpin.SetMinimum(1900)
	f.vintageSpin.SetMaximum(currentYear + 5)
	f.vintageSpin.SetValue(currentYear - 1)
	f.addBody("Millésime", f.vintageSpin.QWidget, true)

	f.drinkSpin = qt.NewQSpinBox2()
	f.drinkSpin.SetMinimum(0)
	f.drinkSpin.SetMaximum(2200)
	f.drinkSpin.SetSpecialValueText("Non défini")
	f.drinkSpin.SetValue(currentYear + 5)
	f.addBody("À boire avant", f.drinkSpin.QWidget, false)

	f.priceEdit = qt.NewQLineEdit2()
	f.priceEdit.SetPlaceholderText("Optionnel")
	priceValidator := qt.NewQDoubleValidator2(0, 99999.99, 2)
	priceValidator.SetNotation(qt.QDoubleValidator__StandardNotation)
	f.priceEdit.SetValidator(priceValidator.QValidator)
	f.addBody("Prix (€)", f.priceEdit.QWidget, false)

	// ── Footer: description is managed by baseForm ────────────────────────────
	f.descEdit.SetPlaceholderText("Optionnel")

	// ── Child section: inline cuvée form ──────────────────────────────────────
	f.cuveeForm = newCuveeForm(ctx.Client)
	f.cuveeForm.loadForInlineAdd("")
	f.cuveeSect = f.addChildSection("Cuvée", f.cuveeForm.baseForm)

	// Show/hide inline cuvée form as the user types.
	f.nameEdit.OnTextChanged(func(text string) {
		text = strings.TrimSpace(text)
		if text == "" {
			f.cuveeSect.Widget.Hide()
			return
		}
		if !f.cuveeExists(text) {
			f.cuveeSect.SetTitle("Nouvelle cuvée")
			f.cuveeForm.loadForInlineAdd(text)
			f.cuveeSect.SetExpanded(true)
			f.cuveeSect.Widget.Show()
			return
		}
		// Existing cuvée: show inline-edit panel only when editing a bottle.
		if f.editBottleID != 0 {
			for i, label := range f.cuveeLabels {
				if strings.EqualFold(label, text) {
					f.cuveeSect.SetTitle("Modifier la cuvée")
					f.cuveeForm.loadForInlineEdit(f.allCuvees[i])
					f.cuveeSect.SetExpanded(false)
					f.cuveeSect.Widget.Show()
					return
				}
			}
		}
		f.cuveeSect.Widget.Hide()
	})

	f.alignLabels()
	chainTabOrder([]*qt.QWidget{
		f.nameEdit.QWidget,
		f.vintageSpin.QWidget,
		f.drinkSpin.QWidget,
		f.priceEdit.QWidget,
		f.descEdit.QAbstractScrollArea.QFrame.QWidget,
	})
	return f
}

// SetEPC sets the NFC tag ID that will be sent with the next AddBottle request.
func (f *inventoryBottleForm) SetEPC(epc string) {
	f.epc = epc
	if epc != "" {
		f.epcLabel.SetText(epc)
	} else {
		f.epcLabel.SetText("—")
	}
}

// parseRFC3339 parses an RFC 3339 timestamp string, returning zero time on error.
func parseRFC3339(s string) time.Time {
	t, _ := time.Parse(time.RFC3339, s)
	return t
}

// loadBottle switches the form to edit mode and pre-fills all fields from b.
// loadData should be called first (or concurrently) to populate the cuvée list.
func (f *inventoryBottleForm) loadBottle(b client.Bottle) {
	f.editBottleID = b.ID

	if b.TagID != nil && *b.TagID != "" {
		f.epcLabel.SetText(*b.TagID)
	} else {
		f.epcLabel.SetText("—")
	}

	if b.AddedAt != "" {
		f.addedAtLabel.SetText(parseRFC3339(b.AddedAt).Local().Format("02/01/2006 15:04"))
	} else {
		f.addedAtLabel.SetText("—")
	}
	f.header.SetRowVisible2(f.addedAtLabel.QWidget, true)

	var label string
	if b.Cuvee.ID != 0 {
		label = fmt.Sprintf("%s — %s", b.Cuvee.Name, b.Cuvee.DomainName)
	}
	f.nameEdit.BlockSignals(true)
	f.nameEdit.SetText(label)
	f.nameEdit.BlockSignals(false)

	// Manually update cuvée section (signals were blocked above).
	if b.Cuvee.ID != 0 {
		f.cuveeSect.SetTitle("Modifier la cuvée")
		f.cuveeForm.loadForInlineEdit(b.Cuvee)
		f.cuveeSect.SetExpanded(false)
		f.cuveeSect.Widget.Show()
	} else {
		f.cuveeSect.Widget.Hide()
	}

	f.vintageSpin.SetValue(int(b.Vintage))
	if b.DrinkBefore != nil {
		f.drinkSpin.SetValue(int(*b.DrinkBefore))
	} else {
		f.drinkSpin.SetValue(0)
	}
	if b.PurchasePrice != nil {
		f.priceEdit.SetText(fmt.Sprintf("%.2f", *b.PurchasePrice))
	} else {
		f.priceEdit.Clear()
	}
	f.SetDescription(b.Description)

	consumed := b.ConsumedAt != nil
	if consumed {
		f.consumedAtLabel.SetText(parseRFC3339(*b.ConsumedAt).Local().Format("02/01/2006 15:04"))
	}
	f.header.SetRowVisible2(f.consumedAtLabel.QWidget, consumed)
	f.setReadOnly(consumed)
}

// loadData fetches cuvées, domains and designations concurrently, then calls then()
// on the main thread once all three have returned.
func (f *inventoryBottleForm) loadData(then func()) {
	go func() {
		cuvees, cuveesErr := f.ctx.Client.ListCuvees(context.Background())
		doms, domsErr := f.ctx.Client.ListDomains(context.Background())
		desigs, desigErr := f.ctx.Client.ListDesignations(context.Background())
		mainthread.Start(func() {
			if cuveesErr == nil {
				f.setCuvees(cuvees)
			}
			if domsErr == nil {
				f.cuveeForm.setDomains(doms)
			}
			if desigErr == nil {
				f.cuveeForm.setDesignations(desigs)
			}
			if then != nil {
				then()
			}
		})
	}()
}

// setCuvees stores the known cuvée list used for matching and inline-form visibility.
func (f *inventoryBottleForm) setCuvees(cuvees []client.Cuvee) {
	f.allCuvees = cuvees
	f.cuveeLabels = make([]string, len(cuvees))
	for i, c := range cuvees {
		f.cuveeLabels[i] = fmt.Sprintf("%s — %s", c.Name, c.DomainName)
	}
	f.rebuildCompleter()
}

// rebuildCompleter recreates the QCompleter attached to nameEdit from the current cuveeLabels.
func (f *inventoryBottleForm) rebuildCompleter() {
	comp := qt.NewQCompleter3(f.cuveeLabels)
	comp.SetCompletionMode(qt.QCompleter__PopupCompletion)
	comp.SetFilterMode(qt.MatchContains)
	comp.SetCaseSensitivity(qt.CaseInsensitive)
	f.nameEdit.SetCompleter(comp)
}

// clearFields resets all fields to their default empty (add) state.
func (f *inventoryBottleForm) clearFields() {
	f.editBottleID = 0
	f.epc = ""
	f.epcLabel.SetText("—")
	f.header.SetRowVisible2(f.addedAtLabel.QWidget, false)
	f.header.SetRowVisible2(f.consumedAtLabel.QWidget, false)
	f.setReadOnly(false)
	f.nameEdit.BlockSignals(true)
	f.nameEdit.Clear()
	f.nameEdit.BlockSignals(false)
	f.vintageSpin.SetValue(time.Now().Year() - 1)
	f.drinkSpin.SetValue(time.Now().Year() + 5)
	f.priceEdit.Clear()
	f.ClearDescription()
	f.cuveeSect.Widget.Hide()
	f.cuveeForm.clearFields()
}

// setReadOnly enables or disables editing on all editable fields.
// Call with true for consumed bottles (view-only), false for normal edit/add.
func (f *inventoryBottleForm) setReadOnly(ro bool) {
	f.nameEdit.SetReadOnly(ro)
	f.vintageSpin.QAbstractSpinBox.SetReadOnly(ro)
	f.drinkSpin.QAbstractSpinBox.SetReadOnly(ro)
	f.priceEdit.SetReadOnly(ro)
	f.descEdit.SetReadOnly(ro)
	if ro {
		f.cuveeSect.Widget.Hide()
	}
}

func (f *inventoryBottleForm) cuveeExists(label string) bool {
	for _, l := range f.cuveeLabels {
		if strings.EqualFold(l, label) {
			return true
		}
	}
	return false
}

func (f *inventoryBottleForm) selectedCuveeID() int64 {
	text := strings.TrimSpace(f.nameEdit.Text())
	for i, label := range f.cuveeLabels {
		if strings.EqualFold(label, text) {
			return f.allCuvees[i].ID
		}
	}
	return 0
}
