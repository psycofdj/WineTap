package screen

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"strings"

	qt "github.com/mappu/miqt/qt6"
	"github.com/mappu/miqt/qt6/mainthread"

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
	f.baseForm = newBaseForm("Nom", "Remplir automatiquement la description via une recherche IA", true, nil)

	f.autoBtn.OnClicked(func() {
		name := f.Name()
		if name == "" {
			return
		}
		f.descEdit.Clear()
		f.startAuto()

		go func() {
			prompt := fmt.Sprintf(
				"Tu es un expert en vins français. Rédige une courte description (3 à 4 phrases) "+
					"du domaine viticole « %s » : appellation, style des vins, réputation. "+
					"Tu peux chercher sur des sites web de critique de vin tels que vivino, vinsolite, buveurdevin ou autre."+
					"Je veux aussi l'adresse postale et le numéro de téléphone. "+
					"Répond moi sous forme d'un JSON: description, adresse, telephone. "+
					"Si tu ne connais pas l'un de ces champs, mets la valeur \"NC\".",
				name,
			)
			slog.Debug("chatgpt domain query", "prompt", prompt)
			raw, err := chatGPTQuery(prompt)
			slog.Debug("chatgpt domain query result", "raw", raw, "err", err)

			mainthread.Start(func() {
				f.finishAuto()
				if err != nil {
					qt.QMessageBox_Warning(nil, "Recherche échouée", err.Error())
					return
				}

				type domainInfo struct {
					Description string `json:"description"`
					Adresse     string `json:"adresse"`
					Telephone   string `json:"telephone"`
				}

				jsonStr := extractJSONObject(raw)
				var info domainInfo
				if jsonStr == "" || json.Unmarshal([]byte(jsonStr), &info) != nil {
					f.descEdit.SetPlainText(raw)
					return
				}

				var parts []string
				if info.Description != "" && info.Description != "NC" {
					parts = append(parts, info.Description)
				}
				if info.Adresse != "" && info.Adresse != "NC" {
					parts = append(parts, "Adresse : "+info.Adresse)
				}
				if info.Telephone != "" && info.Telephone != "NC" {
					parts = append(parts, "Tél. : "+info.Telephone)
				}
				f.descEdit.SetPlainText(strings.Join(parts, "\n\n"))
			})
		}()
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
