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
	regionDC   *debouncedCompleter
	picLabel   *qt.QLabel
	picBytes   []byte
	picFull    *qt.QPixmap
}

func newDesignationForm(cli *client.WineTapHTTPClient) *designationForm {
	f := &designationForm{cli: cli}
	f.baseForm = newBaseForm("Nom", false, nil)

	// Region.
	f.regionEdit = qt.NewQLineEdit2()
	f.addBody("Région", f.regionEdit.QWidget, true)
	f.regionDC = newDebouncedCompleter(nil, f.regionEdit.QWidget,
		func() string { return f.regionEdit.Text() },
		func(s string) { f.regionEdit.SetText(s) },
	)
	f.regionEdit.OnTextChanged(func(_ string) { f.regionDC.trigger() })

	// Picture — placed in footer after description.
	f.picLabel = qt.NewQLabel2()
	f.picLabel.SetAlignment(qt.AlignCenter)
	f.picLabel.SetMinimumSize2(300, 300)
	f.picLabel.SetSizePolicy2(
		qt.QSizePolicy__Policy(qt.QSizePolicy__Expanding),
		qt.QSizePolicy__Policy(qt.QSizePolicy__Expanding),
	)
	f.picLabel.SetStyleSheet("border:1px solid #ced4da;color: #6c757d;")
	f.picLabel.SetText("Aucune image")
	f.picLabel.OnResizeEvent(func(super func(event *qt.QResizeEvent), event *qt.QResizeEvent) {
		super(event)
		if f.picFull != nil && event.Size().Width() != event.OldSize().Width() {
			f.showPicture(f.picFull)
		}
	})
	f.picLabel.OnMouseDoubleClickEvent(func(super func(event *qt.QMouseEvent), event *qt.QMouseEvent) {
		super(event)
		if f.picFull != nil {
			showImageLightbox(f.picLabel.QFrame.QWidget, f.picFull)
		}
	})
	browseBtn := qt.NewQPushButton3("Choisir une image…")
	browseBtn.SetFixedWidth(300)
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
			f.showPicture(pm)
		}
	})
	pasteBtn := qt.NewQPushButton3("Coller depuis le presse-papier")
	pasteBtn.SetFixedWidth(300)
	pasteBtn.OnClicked(func() {
		cb := qt.QGuiApplication_Clipboard()
		img := cb.Image()
		if img.IsNull() {
			qt.QMessageBox_Warning(nil, "Erreur", "Le presse-papier ne contient pas d'image.")
			return
		}
		buf := qt.NewQBuffer()
		buf.Open(qt.QIODeviceBase__WriteOnly)
		img.Save4(buf.QIODevice, "PNG")
		data := buf.Data()
		f.picBytes = data
		pm := qt.NewQPixmap()
		if pm.LoadFromDataWithData(data) {
			f.showPicture(pm)
		}
	})

	btnCol := qt.NewQWidget2()
	btnVL := qt.NewQVBoxLayout(btnCol)
	btnVL.SetContentsMargins(0, 0, 0, 0)
	btnVL.SetSpacing(4)
	btnVL.AddWidget(browseBtn.QAbstractButton.QWidget)
	btnVL.AddWidget(pasteBtn.QAbstractButton.QWidget)

	btnRow := qt.NewQWidget2()
	btnHL := qt.NewQHBoxLayout(btnRow)
	btnHL.SetContentsMargins(0, 0, 0, 0)
	btnHL.AddStretch()
	btnHL.AddWidget(btnCol)
	btnHL.AddStretch()

	picV := qt.NewQWidget2()
	picVL := qt.NewQVBoxLayout(picV)
	picVL.SetContentsMargins(0, 0, 0, 0)
	picVL.SetSpacing(4)
	picVL.AddWidget(f.picLabel.QFrame.QWidget)
	picVL.AddWidget(btnRow)

	picH := qt.NewQWidget2()
	picHL := qt.NewQHBoxLayout(picH)
	picHL.SetContentsMargins(0, 0, 0, 0)
	picHL.AddWidget(picV)

	f.addFooter("Carte", picH, false)

	designPrompt := func() string {
		return fmt.Sprintf(`
			Tu es un expert en vins français. 
			Rédige une courte description (3 à 4 phrases) de l'appellation « %s »: caractéristiques
			gustatives et géographiques. Je veux aussi la région viticole associée. 

			Tu peux chercher sur des sites web de critique de vin tels que vivino,
			vinsolite, buveurdevin ou autre.

			Dans ta réponse:
			- n'affiche que du texte
			- supprime les balises de citation
			- supprime les titres de paragraphes

			Donne moi aussi une image d'un carte pour situer géographiquement cette appellation.
			`,
			f.Name(),
		)
	}

	f.chatGPTBtn.OnClicked(func() {
		if f.Name() == "" {
			return
		}
		openAIChat(f.aiProvider(), designPrompt())
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
	f.picFull = nil
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

// setRegionCompletions replaces the region autocomplete candidates.
func (f *designationForm) setRegionCompletions(regions []string) {
	f.regionDC.setItems(regions, f.regionEdit.QWidget,
		func(s string) { f.regionEdit.SetText(s) },
	)
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
			f.showPicture(pm)
		} else {
			f.picFull = nil
			f.picLabel.Clear()
			f.picLabel.SetText("Aucune image")
		}
	} else {
		f.picFull = nil
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
	f.picFull = nil
	f.picLabel.Clear()
	f.picLabel.SetText("Aucune image")
}

// showPicture stores the full-size pixmap and scales it to fit the label width.
func (f *designationForm) showPicture(pm *qt.QPixmap) {
	f.picFull = pm
	maxW := f.picLabel.Width()
	if maxW < 300 {
		maxW = 300
	}
	scaled := pm.Scaled3(maxW, 9999, qt.KeepAspectRatio, qt.SmoothTransformation)
	f.picLabel.SetPixmap(scaled)
}

func (f *designationForm) Region() string  { return strings.TrimSpace(f.regionEdit.Text()) }
func (f *designationForm) Picture() []byte { return f.picBytes }
