package screen

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"os"
	"strings"

	qt "github.com/mappu/miqt/qt6"
	"github.com/mappu/miqt/qt6/mainthread"

	"winetap/internal/client"
)

// designationForm is a self-contained form for creating and editing a designation.
// It holds its own CRUD logic via the client and tracks whether it is in add
// or edit mode through editingID.  It supports four usage contexts:
//   - standalone add   (loadForAdd)
//   - standalone edit  (loadForEdit)
//   - inline add       (loadForInlineAdd)  — name hidden, driven by a combo
//   - inline edit      (loadForInlineEdit) — name read-only, shown alongside parent
type designationForm struct {
	*baseForm
	cli        *client.WineTapHTTPClient
	editingID  int64
	regionEdit *qt.QLineEdit
	picLabel   *qt.QLabel
	picBytes   []byte
}

func newDesignationForm(cli *client.WineTapHTTPClient) *designationForm {
	f := &designationForm{cli: cli}
	f.baseForm = newBaseForm("Nom", "Remplir automatiquement la description et la région via une recherche IA", false, nil)

	// Region.
	f.regionEdit = qt.NewQLineEdit2()
	f.addBody("Région", f.regionEdit.QWidget, true)

	// Picture (UI kept for future REST endpoint; currently non-functional).
	// Placed in footer after description.
	f.picLabel = qt.NewQLabel2()
	f.picLabel.SetFixedSize2(200, 120)
	f.picLabel.SetAlignment(qt.AlignCenter)
	f.picLabel.SetStyleSheet("border:1px solid #ced4da;color: #6c757d;")
	f.picLabel.SetText("Aucune image")
	f.picLabel.SetScaledContents(true)
	browseBtn := qt.NewQPushButton3("Choisir une image…")
	browseBtn.SetFixedWidth(200)
	browseBtn.OnClicked(func() {
		path := qt.QFileDialog_GetOpenFileName4(nil, "Choisir une image", "",
			"Images (*.png *.jpg *.jpeg *.bmp *.gif *.webp)")
		if path == "" {
			return
		}
		data, err := os.ReadFile(path)
		if err != nil {
			qt.QMessageBox_Warning(nil, "Erreur", "Impossible de lire le fichier : "+err.Error())
			return
		}
		f.picBytes = data
		pm := qt.NewQPixmap()
		if pm.LoadFromDataWithData(data) {
			f.picLabel.SetPixmap(pm)
		}
	})
	picV := qt.NewQWidget2()
	picVL := qt.NewQVBoxLayout(picV)
	picVL.SetContentsMargins(0, 0, 0, 0)
	picVL.SetSpacing(4)
	picVL.AddWidget(f.picLabel.QFrame.QWidget)
	picVL.AddWidget(browseBtn.QAbstractButton.QWidget)

	picH := qt.NewQWidget2()
	picHL := qt.NewQHBoxLayout(picH)
	picHL.SetContentsMargins(0, 0, 0, 0)
	picHL.AddStretch()
	picHL.AddWidget(picV)
	picHL.AddStretch()

	f.addFooter("Carte", picH, false)

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
					"de l'appellation « %s » : caractéristiques gustatives et géographiques. "+
					"Je veux aussi la région viticole associée. "+
					"Tu peux chercher sur des sites web de critique de vin tels que vivino, vinsolite, buveurdevin ou autre."+
					"La région doit être dans la liste : "+
					"Alsace, Beaujolais, Bordeaux, Bourgogne, Champagne, Corse, Jura, "+
					"Languedoc, Loire, Provence, Rhône, Roussillon, Savoie, Sud-Ouest. "+
					"Répond moi sous forme d'un JSON : description, region. "+
					"Si tu ne connais pas l'un de ces champs, mets la valeur \"NC\".",
				name,
			)
			slog.Debug("chatgpt designation query", "prompt", prompt)
			raw, err := chatGPTQuery(prompt)
			slog.Debug("chatgpt designation query result", "raw", raw, "err", err)

			mainthread.Start(func() {
				f.finishAuto()
				if err != nil {
					qt.QMessageBox_Warning(nil, "Recherche échouée", err.Error())
					return
				}

				type desigInfo struct {
					Description string `json:"description"`
					Region      string `json:"region"`
				}

				jsonStr := extractJSONObject(raw)
				var info desigInfo
				if jsonStr == "" || json.Unmarshal([]byte(jsonStr), &info) != nil {
					f.descEdit.SetPlainText(raw)
					return
				}

				if info.Description != "" && info.Description != "NC" {
					f.descEdit.SetPlainText(info.Description)
				}
				if info.Region != "" && !strings.EqualFold(info.Region, "nc") {
					f.regionEdit.SetText(info.Region)
				}
			})
		}()
	})

	f.alignLabels()
	return f
}

// loadForAdd prepares the form for standalone creation.
func (f *designationForm) loadForAdd(completions []string) {
	f.editingID = 0
	f.nameEdit.SetReadOnly(false)
	f.showName(true)
	f.clearFields()
	f.setRegionCompletions(completions)
}

// loadForEdit prepares the form for standalone editing.
func (f *designationForm) loadForEdit(d client.Designation, completions []string) {
	f.editingID = d.ID
	f.nameEdit.SetReadOnly(true)
	f.showName(true)
	f.populate(d)
	f.setRegionCompletions(completions)
}

// loadForInlineAdd prepares the form for inline creation inside a parent form.
// The name row is hidden; name is set internally so the AI button can use it.
func (f *designationForm) loadForInlineAdd(name string) {
	f.editingID = 0
	f.nameEdit.SetReadOnly(false)
	f.showName(false)
	f.nameEdit.SetText(name)
	f.regionEdit.Clear()
	f.descEdit.Clear()
	f.picBytes = nil
	f.picLabel.Clear()
	f.picLabel.SetText("Aucune image")
}

// loadForInlineEdit prepares the form for inline editing of an existing
// designation inside a parent form.  The name row is visible but read-only.
func (f *designationForm) loadForInlineEdit(d client.Designation) {
	f.editingID = d.ID
	f.nameEdit.SetReadOnly(true)
	f.showName(true)
	f.populate(d)
}

// save creates a new designation (editingID == 0) or updates an existing one.
func (f *designationForm) save(ctx context.Context) (client.Designation, error) {
	req := client.CreateDesignation{
		Name:        f.Name(),
		Region:      f.Region(),
		Description: f.Description(),
	}
	if f.editingID == 0 {
		return f.cli.AddDesignation(ctx, req)
	}
	return f.cli.UpdateDesignation(ctx, f.editingID, req)
}

// setRegionCompletions attaches a contains-matching autocomplete dropdown to the region field.
func (f *designationForm) setRegionCompletions(regions []string) {
	completer := qt.NewQCompleter3(regions)
	completer.SetCompletionMode(qt.QCompleter__PopupCompletion)
	completer.SetFilterMode(qt.MatchContains)
	completer.SetCaseSensitivity(qt.CaseInsensitive)
	f.regionEdit.SetCompleter(completer)
}

// populate fills all fields from an existing designation.
// Note: picture data is not in the REST API for MVP; picLabel is cleared.
func (f *designationForm) populate(d client.Designation) {
	f.nameEdit.SetText(d.Name)
	f.regionEdit.SetText(d.Region)
	f.descEdit.SetPlainText(d.Description)
	f.picBytes = nil
	f.picLabel.Clear()
	f.picLabel.SetText("Aucune image")
}

// clearFields resets all fields to their empty state.
func (f *designationForm) clearFields() {
	f.nameEdit.Clear()
	f.regionEdit.Clear()
	f.descEdit.Clear()
	f.picBytes = nil
	f.picLabel.Clear()
	f.picLabel.SetText("Aucune image")
}

func (f *designationForm) Region() string  { return strings.TrimSpace(f.regionEdit.Text()) }
func (f *designationForm) Picture() []byte { return f.picBytes }
