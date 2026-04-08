package screen

import (
	"context"
	"fmt"

	qt "github.com/mappu/miqt/qt6"

	"winetap/internal/client"
)

// domainForm is a self-contained form for creating and editing a domain.
// It holds its own CRUD logic via the client and tracks whether it is in add
// or edit mode through editingID.  It supports four usage contexts:
//   - standalone add   (loadForAdd)
//   - standalone edit  (loadForEdit)
//   - inline add       (loadForInlineAdd)  — name hidden, driven by a combo
//   - inline edit      (loadForInlineEdit) — name read-only, shown alongside parent
type domainForm struct {
	*baseForm
	cli       *client.WineTapHTTPClient
	editingID int64
}

func newDomainForm(cli *client.WineTapHTTPClient) *domainForm {
	f := &domainForm{cli: cli}
	f.baseForm = newBaseForm("Nom", true, nil)

	domainPrompt := func() string {
		return fmt.Sprintf(`
			Tu es un expert en vins français. 
			Rédige une courte description (3 à 4 phrases) du domaine viticole « %s »: Appellation, style des vins, réputation. 
			Tu peux chercher sur des sites web de critique de vin tels que 
			vivino, vinsolite, buveurdevin ou autre. 
			Je veux aussi l'adresse postale et le numéro de téléphone. 
			Répond moi sous forme de 3 paragraphes séparés par deux sauts de ligne:
			- description du domaine
			- description des méthodes de production
			- adresse et téléphone 
			Ne mets pas d'intitulé de paragraphe.
			`,
			f.Name(),
		)
	}

	f.chatGPTBtn.OnClicked(func() {
		if f.Name() == "" {
			return
		}
		openChatGPT(domainPrompt())
	})

	f.alignLabels()
	chainTabOrder([]*qt.QWidget{
		f.nameEdit.QWidget,
		f.descEdit.QAbstractScrollArea.QFrame.QWidget,
	})
	return f
}

// loadForAdd prepares the form for standalone creation.
func (f *domainForm) loadForAdd() {
	f.editingID = 0
	f.nameEdit.SetReadOnly(false)
	f.showName(true)
	f.nameEdit.Clear()
	f.descEdit.Clear()
}

// loadForEdit prepares the form for standalone editing.
func (f *domainForm) loadForEdit(d client.Domain) {
	f.editingID = d.ID
	f.nameEdit.SetReadOnly(false)
	f.showName(true)
	f.nameEdit.SetText(d.Name)
	f.descEdit.SetPlainText(d.Description)
}

// loadForInlineAdd prepares the form for inline creation inside a parent form.
// The name row is hidden; name is set internally so the AI button can use it.
func (f *domainForm) loadForInlineAdd(name string) {
	f.editingID = 0
	f.nameEdit.SetReadOnly(false)
	f.showName(false)
	f.nameEdit.SetText(name)
	f.descEdit.Clear()
}

// loadForInlineEdit prepares the form for inline editing of an existing domain
// inside a parent form.  The name row is visible but read-only.
func (f *domainForm) loadForInlineEdit(d client.Domain) {
	f.editingID = d.ID
	f.nameEdit.SetReadOnly(true)
	f.showName(true)
	f.nameEdit.SetText(d.Name)
	f.descEdit.SetPlainText(d.Description)
}

// save creates a new domain (editingID == 0) or updates an existing one.
func (f *domainForm) save(ctx context.Context) (client.Domain, error) {
	req := client.CreateDomain{Name: f.Name(), Description: f.Description()}
	if f.editingID == 0 {
		return f.cli.AddDomain(ctx, req)
	}
	return f.cli.UpdateDomain(ctx, f.editingID, req)
}
