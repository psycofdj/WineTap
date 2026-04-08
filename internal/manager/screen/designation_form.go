package screen

import (
	"context"
	"fmt"
	"os"
	"strings"

	qt "github.com/mappu/miqt/qt6"

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
	f.baseForm = newBaseForm("Nom", false, nil)

	// Region.
	f.regionEdit = qt.NewQLineEdit2()
	f.addBody("Région", f.regionEdit.QWidget, true)

	// Picture — placed in footer after description.
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
	pasteBtn := qt.NewQPushButton3("Coller depuis le presse-papier")
	pasteBtn.SetFixedWidth(200)
	pasteBtn.OnClicked(func() {
		cb := qt.QGuiApplication_Clipboard()
		img := cb.Image()
		if img.IsNull() {
			qt.QMessageBox_Warning(nil, "Erreur", "Le presse-papier ne contient pas d'image.")
			return
		}
		buf := qt.NewQBuffer()
		buf.Open(qt.QIODeviceBase__WriteOnly)
		img.Save4(&buf.QIODevice, "PNG")
		data := buf.Data()
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
	picVL.AddWidget(pasteBtn.QAbstractButton.QWidget)

	picH := qt.NewQWidget2()
	picHL := qt.NewQHBoxLayout(picH)
	picHL.SetContentsMargins(0, 0, 0, 0)
	picHL.AddStretch()
	picHL.AddWidget(picV)
	picHL.AddStretch()

	f.addFooter("Carte", picH, false)

	designPrompt := func() string {
		return fmt.Sprintf(`
			Tu es un expert en vins français. 
			Rédige une courte description (3 à 4 phrases) de l'appellation « %s »: caractéristiques
			gustatives et géographiques. Je veux aussi la région viticole associée. 
			Tu peux chercher sur des sites web de critique de vin tels que vivino, vinsolite, buveurdevin ou autre.
			La région doit être dans la liste: Alsace, Beaujolais, Bordeaux, Bourgogne, Champagne, Corse, Jura,
			Languedoc, Loire, Provence, Rhône, Roussillon, Savoie, Sud-Ouest.
			Donne moi aussi une image d'un carte pour situer géographiquement cette appellation.`,
			f.Name(),
		)
	}

	f.chatGPTBtn.OnClicked(func() {
		if f.Name() == "" {
			return
		}
		openChatGPT(designPrompt())
	})

	f.alignLabels()
	chainTabOrder([]*qt.QWidget{
		f.nameEdit.QWidget,
		f.regionEdit.QWidget,
		f.descEdit.QAbstractScrollArea.QFrame.QWidget,
	})
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
		Picture:     f.picBytes,
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
func (f *designationForm) populate(d client.Designation) {
	f.nameEdit.SetText(d.Name)
	f.regionEdit.SetText(d.Region)
	f.descEdit.SetPlainText(d.Description)
	f.picBytes = d.Picture
	if len(d.Picture) > 0 {
		pm := qt.NewQPixmap()
		if pm.LoadFromDataWithData(d.Picture) {
			f.picLabel.SetPixmap(pm)
		} else {
			f.picLabel.Clear()
			f.picLabel.SetText("Aucune image")
		}
	} else {
		f.picLabel.Clear()
		f.picLabel.SetText("Aucune image")
	}
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
