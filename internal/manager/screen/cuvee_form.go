package screen

import (
	"context"
	"fmt"
	"log/slog"
	"strings"

	qt "github.com/mappu/miqt/qt6"
	"github.com/mappu/miqt/qt6/mainthread"

	"winetap/internal/client"
)

// cuveeForm is a self-contained form for creating and editing a cuvée.
// It composes a domainForm and a designationForm to handle the linked entities
// inline.  A single instance of each sub-form is reused across all contexts:
//   - inline add  — shown when the combo text doesn't match any existing entity
//   - inline edit — shown when editing an existing cuvée (one per linked entity)
//
// The form tracks its own editingID; the screens no longer need to.
type cuveeForm struct {
	*baseForm
	cli       *client.WineTapHTTPClient
	editingID int64

	colorCombo *qt.QComboBox

	domainCombo *qt.QComboBox
	domainSect  *foldableSection
	domainForm  *domainForm // single instance — switches between add/edit mode

	designCombo *qt.QComboBox
	designSect  *foldableSection
	designForm  *designationForm

	allDomains []client.Domain
	allDesig   []client.Designation
}

func newCuveeForm(cli *client.WineTapHTTPClient) *cuveeForm {
	f := &cuveeForm{cli: cli}
	// canEnable: button requires name + domain + designation all non-empty.
	f.baseForm = newBaseForm("Nom", "Remplir automatiquement la description via une recherche IA", true,
		func() bool {
			return strings.TrimSpace(f.nameEdit.Text()) != "" &&
				strings.TrimSpace(f.domainCombo.CurrentText()) != "" &&
				strings.TrimSpace(f.designCombo.CurrentText()) != ""
		})

	f.colorCombo = qt.NewQComboBox2()
	for _, c := range colorOrder {
		f.colorCombo.AddItem(colorNames[c])
	}
	f.addBody("Couleur", f.colorCombo.QWidget, true)

	f.domainCombo = qt.NewQComboBox2()
	f.domainCombo.SetEditable(true)
	f.domainCombo.SetInsertPolicy(qt.QComboBox__NoInsert)
	f.domainCombo.SetPlaceholderText("Domaine (obligatoire)")
	f.addBody("Domaine", f.domainCombo.QWidget, true)

	f.designCombo = qt.NewQComboBox2()
	f.designCombo.SetEditable(true)
	f.designCombo.SetInsertPolicy(qt.QComboBox__NoInsert)
	f.designCombo.SetPlaceholderText("Appellation (obligatoire)")
	f.addBody("Appellation", f.designCombo.QWidget, true)

	cuveePrompt := func() string {
		return fmt.Sprintf(
			"Tu es un expert en vins français. Recherches sur internet puis rédige un court résumé "+
				"(5 à 6 phrases) à propos de la cuvée « %s » du domaine « %s » de l'appellation « %s » "+
				"en « %s ». Je cherche les arômes du vin, les plats avec lesquels ils s'accorde bien, "+
				"et combien de temps puis-je espérer le conserver pour maximiser son goût. "+
				"Tu peux chercher sur des sites web de critique de vin tels que vivino, vinsolite, buveurdevin ou autre."+
				"Si tu ne connais pas tu répond \"NC\". "+
				"Donne juste la réponse, pas d'intriduction type \"Voici un résumé...\" "+
				"et pas de conclusion du type \"Si tu veux...\".",
			f.Name(),
			strings.TrimSpace(f.domainCombo.CurrentText()),
			strings.TrimSpace(f.designCombo.CurrentText()),
			colorNames[f.Color()],
		)
	}

	f.chatGPTBtn.OnClicked(func() {
		if f.Name() == "" || strings.TrimSpace(f.domainCombo.CurrentText()) == "" || strings.TrimSpace(f.designCombo.CurrentText()) == "" {
			return
		}
		openChatGPT(cuveePrompt())
	})

	f.autoBtn.OnClicked(func() {
		if f.Name() == "" || strings.TrimSpace(f.domainCombo.CurrentText()) == "" || strings.TrimSpace(f.designCombo.CurrentText()) == "" {
			return
		}
		f.descEdit.Clear()
		f.startAuto()

		go func() {
			prompt := cuveePrompt()
			slog.Debug("chatgpt cuvee query", "prompt", prompt)
			raw, err := chatGPTQuery(prompt)
			slog.Debug("chatgpt cuvee query result", "raw", raw, "err", err)

			mainthread.Start(func() {
				f.finishAuto()
				if err != nil {
					qt.QMessageBox_Warning(nil, "Recherche échouée", err.Error())
					return
				}
				f.descEdit.SetPlainText(raw)
			})
		}()
	})

	// Domain inline panel — single domainForm instance, hidden by default.
	f.domainForm = newDomainForm(cli)
	f.domainSect = f.addChildSection("Domaine", f.domainForm.baseForm)

	// Designation inline panel — single designationForm instance, hidden by default.
	f.designForm = newDesignationForm(cli)
	f.designSect = f.addChildSection("Appellation", f.designForm.baseForm)

	// Combo text-change handler — drives domain inline panel mode.
	// recheckAuto is merged in here to avoid duplicate signal connections.
	f.domainCombo.OnCurrentTextChanged(func(text string) {
		f.recheckAuto()
		text = strings.TrimSpace(text)
		if text == "" {
			f.domainSect.Widget.Hide()
			return
		}
		if !f.domainExists(text) {
			f.domainSect.SetTitle("Nouveau domaine")
			f.domainForm.loadForInlineAdd(text)
			f.domainSect.SetExpanded(true)
			f.domainSect.Widget.Show()
			return
		}
		// Existing domain: show inline-edit panel only when editing a cuvée.
		if f.editingID != 0 {
			for _, d := range f.allDomains {
				if strings.EqualFold(d.Name, text) {
					f.domainSect.SetTitle("Modifier le domaine")
					f.domainForm.loadForInlineEdit(d)
					f.domainSect.SetExpanded(false)
					f.domainSect.Widget.Show()
					return
				}
			}
		}
		f.domainSect.Widget.Hide()
	})

	// Same for designation.
	f.designCombo.OnCurrentTextChanged(func(text string) {
		f.recheckAuto()
		text = strings.TrimSpace(text)
		if text == "" {
			f.designSect.Widget.Hide()
			return
		}
		if !f.designExists(text) {
			f.designSect.SetTitle("Nouvelle appellation")
			f.designForm.loadForInlineAdd(text)
			f.designSect.SetExpanded(true)
			f.designSect.Widget.Show()
			return
		}
		if f.editingID != 0 {
			for _, d := range f.allDesig {
				if strings.EqualFold(d.Name, text) {
					f.designSect.SetTitle("Modifier l'appellation")
					f.designForm.loadForInlineEdit(d)
					f.designSect.SetExpanded(false)
					f.designSect.Widget.Show()
					return
				}
			}
		}
		f.designSect.Widget.Hide()
	})

	f.alignLabels()
	chainTabOrder([]*qt.QWidget{
		f.nameEdit.QWidget,
		f.colorCombo.QWidget,
		f.domainCombo.QWidget,
		f.designCombo.QWidget,
		f.descEdit.QAbstractScrollArea.QFrame.QWidget,
	})
	return f
}

// loadForAdd resets the form for creating a new cuvée.
func (f *cuveeForm) loadForAdd() {
	f.editingID = 0
	f.nameEdit.SetReadOnly(false)
	f.showName(true)
	f.clearFields()
}

// loadForInlineAdd prepares the form for inline cuvée creation inside a parent
// form (e.g. the inventory screen).  The name row is hidden; name is set
// internally so that the AI button and save logic can use it.
func (f *cuveeForm) loadForInlineAdd(name string) {
	f.editingID = 0
	f.nameEdit.SetReadOnly(false)
	f.showName(false)
	f.nameEdit.SetText(name)
	f.colorCombo.SetCurrentIndex(0)
	// Do NOT clear domain/designation combos or descEdit here — the user may
	// have already filled them in.  The caller manages visibility of the box.
}

// loadForInlineEdit prepares the form for inline editing of an existing cuvée
// inside a parent form.  The name row is visible but read-only.
func (f *cuveeForm) loadForInlineEdit(c client.Cuvee) {
	f.editingID = c.ID
	f.nameEdit.SetReadOnly(true)
	f.showName(true)
	f.nameEdit.SetText(c.Name)
	f.setColor(c.Color)
	// Setting the combo texts fires OnCurrentTextChanged, which shows the
	// inline domain/designation panels in edit mode (editingID is already set).
	f.domainCombo.SetCurrentText(c.DomainName)
	f.designCombo.SetCurrentText(c.DesignationName)
	f.descEdit.SetPlainText(c.Description)
}

// clearFields resets all editable fields without touching name visibility or mode.
func (f *cuveeForm) clearFields() {
	f.nameEdit.Clear()
	f.colorCombo.SetCurrentIndex(0)
	f.domainCombo.SetCurrentText("")
	f.designCombo.SetCurrentText("")
	f.descEdit.Clear()
	f.domainSect.Widget.Hide()
	f.designSect.Widget.Hide()
}

// loadForCopy populates the form as a copy of an existing cuvée (no editingID).
func (f *cuveeForm) loadForCopy(c client.Cuvee) {
	f.editingID = 0
	f.nameEdit.Clear() // name must be unique; user fills it in
	f.setColor(c.Color)
	f.domainCombo.SetCurrentText(c.DomainName)
	f.designCombo.SetCurrentText(c.DesignationName)
	f.descEdit.SetPlainText(c.Description)
	f.domainSect.Widget.Hide()
	f.designSect.Widget.Hide()
}

// loadForEdit populates the form for editing an existing cuvée, including the
// inline domain and designation edit panels.
func (f *cuveeForm) loadForEdit(c client.Cuvee) {
	f.editingID = c.ID
	f.nameEdit.SetText(c.Name)
	f.setColor(c.Color)
	// Setting the combo texts will fire OnCurrentTextChanged, which shows the
	// inline panels via the handler wired in newCuveeForm.
	f.domainCombo.SetCurrentText(c.DomainName)
	f.designCombo.SetCurrentText(c.DesignationName)
	f.descEdit.SetPlainText(c.Description)
}

// save orchestrates create/update for the domain, designation, and cuvée.
// Domain and designation panels are only saved when visible.
func (f *cuveeForm) save(ctx context.Context) (client.Cuvee, error) {
	domainID := f.domainIDFor(f.DomainText())
	if f.domainSect.Widget.IsVisible() {
		dom, err := f.domainForm.save(ctx)
		if err != nil {
			return client.Cuvee{}, fmt.Errorf("domaine : %w", err)
		}
		domainID = dom.ID
	}

	designID := f.designationIDFor(f.DesignText())
	if f.designSect.Widget.IsVisible() {
		desig, err := f.designForm.save(ctx)
		if err != nil {
			return client.Cuvee{}, fmt.Errorf("appellation : %w", err)
		}
		designID = desig.ID
	}

	req := client.CreateCuvee{
		Name:          f.Name(),
		DomainID:      domainID,
		Color:         f.Color(),
		DesignationID: designID,
		Description:   f.Description(),
	}
	if f.editingID == 0 {
		return f.cli.AddCuvee(ctx, req)
	}
	return f.cli.UpdateCuvee(ctx, f.editingID, req)
}

// setDomains repopulates the domain combo with case-insensitive autocomplete.
func (f *cuveeForm) setDomains(domains []client.Domain) {
	f.allDomains = domains
	f.domainCombo.BlockSignals(true)
	f.domainCombo.Clear()
	names := make([]string, 0, len(domains))
	for _, d := range domains {
		f.domainCombo.AddItem(d.Name)
		names = append(names, d.Name)
	}
	c := qt.NewQCompleter3(names)
	c.SetCompletionMode(qt.QCompleter__PopupCompletion)
	c.SetFilterMode(qt.MatchContains)
	c.SetCaseSensitivity(qt.CaseInsensitive)
	f.domainCombo.SetCompleter(c)
	f.domainCombo.BlockSignals(false)
}

// setDesignations repopulates the designation combo with case-insensitive autocomplete.
func (f *cuveeForm) setDesignations(desigs []client.Designation) {
	f.allDesig = desigs
	f.designCombo.BlockSignals(true)
	f.designCombo.Clear()
	names := make([]string, 0, len(desigs))
	seen := make(map[string]struct{})
	var regions []string
	for _, d := range desigs {
		f.designCombo.AddItem(d.Name)
		names = append(names, d.Name)
		if d.Region != "" {
			if _, ok := seen[d.Region]; !ok {
				seen[d.Region] = struct{}{}
				regions = append(regions, d.Region)
			}
		}
	}
	c := qt.NewQCompleter3(names)
	c.SetCompletionMode(qt.QCompleter__PopupCompletion)
	c.SetFilterMode(qt.MatchContains)
	c.SetCaseSensitivity(qt.CaseInsensitive)
	f.designCombo.SetCompleter(c)
	f.designCombo.BlockSignals(false)

	f.designForm.setRegionCompletions(regions)
}

func (f *cuveeForm) DomainText() string { return strings.TrimSpace(f.domainCombo.CurrentText()) }
func (f *cuveeForm) DesignText() string { return strings.TrimSpace(f.designCombo.CurrentText()) }

func (f *cuveeForm) Color() int32 {
	if idx := f.colorCombo.CurrentIndex(); idx >= 0 && idx < len(colorOrder) {
		return colorOrder[idx]
	}
	return colorOrder[0]
}

func (f *cuveeForm) setColor(color int32) {
	for i, c := range colorOrder {
		if c == color {
			f.colorCombo.SetCurrentIndex(i)
			return
		}
	}
}

func (f *cuveeForm) domainExists(name string) bool {
	for _, d := range f.allDomains {
		if strings.EqualFold(d.Name, name) {
			return true
		}
	}
	return false
}

func (f *cuveeForm) designExists(name string) bool {
	for _, d := range f.allDesig {
		if strings.EqualFold(d.Name, name) {
			return true
		}
	}
	return false
}

func (f *cuveeForm) domainIDFor(name string) int64 {
	for _, d := range f.allDomains {
		if strings.EqualFold(d.Name, name) {
			return d.ID
		}
	}
	return 0
}

func (f *cuveeForm) designationIDFor(name string) int64 {
	for _, d := range f.allDesig {
		if strings.EqualFold(d.Name, name) {
			return d.ID
		}
	}
	return 0
}
