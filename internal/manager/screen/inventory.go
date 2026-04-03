package screen

import (
	"context"
	"fmt"
	"log/slog"
	"math/rand"
	"sort"
	"strings"
	"time"

	qt "github.com/mappu/miqt/qt6"
	"github.com/mappu/miqt/qt6/mainthread"

	"winetap/internal/client"
)

// Column indices for the inventory table.
const (
	invColCouleur     = 0
	invColRegion      = 1
	invColCuvee       = 2
	invColAppell      = 3
	invColMillesime   = 4
	invColDrinkBefore = 5
	invColQte         = 6
	invColAddedAt     = 7
)

// colorIdentifiers maps Color int32 constant to the lowercase identifier used by the dashboard.
var colorIdentifiers = map[int32]string{
	client.ColorRouge:        "rouge",
	client.ColorBlanc:        "blanc",
	client.ColorRose:         "rose",
	client.ColorEffervescent: "effervescent",
	client.ColorAutre:        "autre",
}

type InventoryScreen struct {
	Widget *qt.QWidget
	ts     *tableScreen
	ctx    *Ctx

	allBottles   []client.Bottle
	grouped      bool
	showConsumed bool

	// Filter list widgets
	regionList *qt.QListWidget
	colorList  *qt.QListWidget
	millesList *qt.QListWidget
	desigList  *qt.QListWidget

	// Filter popups (built after ts is set)
	regionPopup *qt.QWidget
	colorPopup  *qt.QWidget
	millesPopup *qt.QWidget
	desigPopup  *qt.QWidget

	viewTabs  *qt.QTabBar
	searchBtn *qt.QPushButton
	warnBtn   *qt.QPushButton

	bottleForm *inventoryBottleForm

	// Right panel: stacked widget switching between wait and form views.
	rightStack    *qt.QStackedWidget
	waitWidget    *qt.QWidget // page 0 — shown during NFC scan
	waitTitle     *qt.QLabel  // title inside the wait widget
	onSimulateTag func(tagID string)

	// Dashboard drill-down filter — consumed after refresh, then cleared.
	pendingFilterType  string
	pendingFilterValue string
}

func BuildInventoryScreen(ctx *Ctx) *InventoryScreen {
	s := &InventoryScreen{ctx: ctx}

	// ── Filter list widgets ───────────────────────────────────────────────────
	s.colorList = qt.NewQListWidget2()
	for _, c := range colorOrder {
		item := qt.NewQListWidgetItem2(colorNames[c])
		item.SetFlags(qt.ItemIsUserCheckable | qt.ItemIsEnabled)
		item.SetCheckState(qt.Checked)
		s.colorList.AddItemWithItem(item)
	}
	s.regionList = qt.NewQListWidget2()
	s.millesList = qt.NewQListWidget2()
	s.desigList = qt.NewQListWidget2()

	// ── Bottle form ───────────────────────────────────────────────────────────
	s.bottleForm = newInventoryBottleForm(ctx)

	// ── Wait widget (shown while waiting for NFC scan) ────────────────────────
	s.waitWidget = qt.NewQWidget2()
	waitOuter := qt.NewQVBoxLayout(s.waitWidget)
	waitOuter.SetContentsMargins(0, 0, 0, 0)
	waitOuter.SetSpacing(0)

	s.waitTitle = qt.NewQLabel3("")
	setWidgetRole(s.waitTitle.QFrame.QWidget, "form-title")
	waitOuter.AddWidget(s.waitTitle.QWidget)

	waitSep := qt.NewQFrame2()
	waitSep.SetFrameShape(qt.QFrame__HLine)
	setWidgetRole(waitSep.QWidget, "sep")
	waitOuter.AddWidget(waitSep.QWidget)

	waitBody := qt.NewQWidget2()
	waitBodyVL := qt.NewQVBoxLayout(waitBody)
	waitBodyVL.SetSpacing(12)
	waitBodyVL.AddStretch()
	waitLabel := qt.NewQLabel3("En attente d'un scan NFC…")
	waitLabel.SetStyleSheet("font-size:14px;color:#888;")
	waitLabel.SetAlignment(qt.AlignCenter)
	waitBodyVL.AddWidget(waitLabel.QWidget)
	if slog.Default().Enabled(context.Background(), slog.LevelDebug) {
		genBtn := qt.NewQPushButton3("Générer un tag")
		genBtn.OnClicked(func() {
			tagID := fmt.Sprintf("AABBCCDD%08x", rand.Int31())
			_ = ctx.Scanner.StopScan()
			if s.onSimulateTag != nil {
				s.onSimulateTag(tagID)
			}
		})
		waitBodyVL.AddWidget(genBtn.QAbstractButton.QWidget)
	}
	waitBodyVL.AddStretch()
	waitOuter.AddWidget2(waitBody, 1)

	// ── Stacked widget: wait (0) | form (1) ──────────────────────────────────
	s.rightStack = qt.NewQStackedWidget2()
	s.rightStack.AddWidget(s.waitWidget)
	s.rightStack.AddWidget(s.bottleForm.widget)

	// ── View tab bar ──────────────────────────────────────────────────────────
	// Tab 0 — Synthèse  : grouped, in-stock only
	// Tab 1 — Détail    : flat,    in-stock only
	// Tab 2 — Historique: flat,    all (consumed included)
	s.viewTabs = qt.NewQTabBar2()
	s.viewTabs.AddTab("Par bouteille")
	s.viewTabs.SetTabToolTip(1, "Une ligne par bouteille, stock en cave uniquement")
	s.viewTabs.AddTab("Par référence")
	s.viewTabs.SetTabToolTip(0, "Stock en cave groupé par cuvée et millésime, avec les quantités")
	s.viewTabs.AddTab("Historique")
	s.viewTabs.SetTabToolTip(2, "Toutes les bouteilles, y compris celles déjà bues")
	s.viewTabs.OnCurrentChanged(func(idx int) {
		s.grouped = idx == 1
		s.showConsumed = idx == 2
		s.ts.HideRight()
		s.ts.TableView.SetColumnHidden(invColDrinkBefore, s.grouped)
		s.ts.TableView.SetColumnHidden(invColQte, !s.grouped)
		s.ts.TableView.SetColumnHidden(invColAddedAt, s.grouped)
		s.refresh()
	})

	groupToolbar := qt.NewQWidget2()
	gtl := qt.NewQHBoxLayout(groupToolbar)
	gtl.SetContentsMargins(0, 0, 0, 0)
	gtl.AddWidget(s.viewTabs.QWidget)
	gtl.AddWidget2(qt.NewQWidget2(), 1)

	// ── Search button ─────────────────────────────────────────────────────────
	s.searchBtn = newStdBtn("search")
	s.searchBtn.OnClicked(func() { s.onSearchByTag() })

	// ── Warn / consume button ─────────────────────────────────────────────────
	s.warnBtn = newStdBtn("warning")
	s.warnBtn.SetEnabled(false)
	s.warnBtn.OnClicked(func() { s.onConsumeBottle() })

	// ── tableScreen ───────────────────────────────────────────────────────────
	s.ts = newTableScreen(tableScreenCfg{
		ScreenTitle:       "Inventaire",
		Headers:           []string{"Couleur", "Région", "Cuvée", "Appellation", "Millésime", "À boire avant", "Quantité", "Ajoutée le"},
		ExtraToolbar:      groupToolbar,
		SearchPlaceholder: "Rechercher…",
		SearchCols:        []int{invColCuvee, invColAppell},
		InitialSortCol:    invColCuvee,
		FilterCols:        []int{invColCouleur, invColRegion, invColAppell, invColMillesime},
		OnFilterCol:       func(col int) { s.showFilterPopup(col) },
		ExtraFilterAccepts: func(_ *qt.QStandardItemModel, srcRow int) bool {
			if checked := s.checkedItems(s.regionList); len(checked) > 0 {
				if _, ok := checked[s.ts.SrcModel.Item2(srcRow, invColRegion).Text()]; !ok {
					return false
				}
			}
			if checked := s.checkedItems(s.colorList); len(checked) > 0 {
				if _, ok := checked[s.ts.SrcModel.Item2(srcRow, invColCouleur).Text()]; !ok {
					return false
				}
			}
			if checked := s.checkedItems(s.desigList); len(checked) > 0 {
				if _, ok := checked[s.ts.SrcModel.Item2(srcRow, invColAppell).Text()]; !ok {
					return false
				}
			}
			if checked := s.checkedItems(s.millesList); len(checked) > 0 {
				if _, ok := checked[s.ts.SrcModel.Item2(srcRow, invColMillesime).Text()]; !ok {
					return false
				}
			}
			return true
		},
		LessThanOverride: func(src *qt.QStandardItemModel, left, right *qt.QModelIndex) bool {
			col := left.Column()
			lRow, rRow := left.Row(), right.Row()
			if col == invColMillesime || col == invColDrinkBefore || col == invColQte || col == invColAddedAt {
				lKey := src.Item2(lRow, col).Data(sortRole).ToString()
				rKey := src.Item2(rRow, col).Data(sortRole).ToString()
				if lKey != rKey {
					return lKey < rKey
				}
			} else {
				lText := foldAccents(src.Item2(lRow, col).Text())
				rText := foldAccents(src.Item2(rRow, col).Text())
				if lText != rText {
					return lText < rText
				}
			}
			return foldAccents(src.Item2(lRow, invColCuvee).Text()) <
				foldAccents(src.Item2(rRow, invColCuvee).Text())
		},
		OnSelectionChange: func(srcRow int) {
			if s.grouped {
				// Grouped rows represent many bottles: copy is OK (picks first),
				// but delete and consume are not meaningful.
				s.ts.DelBtn.SetEnabled(false)
				s.warnBtn.SetEnabled(false)
				s.ts.HideRight()
				return
			}
			selected := srcRow >= 0
			canConsume := false
			if selected {
				if b := s.bottleAtSourceRow(srcRow); b != nil {
					canConsume = b.ConsumedAt == nil
				}
			}
			s.warnBtn.SetEnabled(canConsume)
			if selected {
				s.openEditForm(srcRow)
			} else {
				s.ts.HideRight()
			}
		},
		FormContent: s.rightStack.QFrame.QWidget,
		OnSave:      func() { s.onSave() },
		OnCancel: func() {
			_ = s.ctx.Scanner.StopScan()
			s.ts.HideRight()
		},
		OnAdd:    func() { s.openAddForm() },
		OnDelete: func() { s.onDelete() },
		OnCopy: func() {
			row := s.ts.SelectedSourceRow()
			var b *client.Bottle
			if s.grouped {
				b = s.firstBottleAtGroupedRow(row)
			} else {
				b = s.bottleAtSourceRow(row)
			}
			if b != nil {
				s.addBottleFrom(*b)
			}
		},
		ExtraActionBtns: []*qt.QPushButton{s.searchBtn, s.warnBtn},
	})
	s.Widget = s.ts.Widget

	// Default view is Synthèse (tab 0): grouped, Qte visible, AddedAt hidden.
	s.grouped = false
	s.ts.TableView.SetColumnHidden(invColDrinkBefore, false)
	s.ts.TableView.SetColumnHidden(invColQte, true)
	s.ts.TableView.SetColumnHidden(invColAddedAt, false)

	// ── Filter popups (built after ts is set) ─────────────────────────────────
	s.regionPopup = s.makeFilterPopup(invColRegion, s.regionList)
	s.colorPopup = s.makeFilterPopup(invColCouleur, s.colorList)
	s.desigPopup = s.makeFilterPopup(invColAppell, s.desigList)
	s.millesPopup = s.makeFilterPopup(invColMillesime, s.millesList)

	// Validation: save enabled when a cuvée is typed (user interaction).
	s.bottleForm.nameEdit.OnTextChanged(func(text string) {
		s.ts.SetSaveEnabled(strings.TrimSpace(text) != "")
	})

	return s
}

func (s *InventoryScreen) showFilterPopup(col int) {
	var popup *qt.QWidget
	switch col {
	case invColRegion:
		popup = s.regionPopup
	case invColCouleur:
		popup = s.colorPopup
	case invColAppell:
		popup = s.desigPopup
	case invColMillesime:
		popup = s.millesPopup
	}
	if popup != nil {
		s.ts.ShowPopup(col, popup)
	}
}

// makeFilterPopup delegates to the package-level helper.
// Must be called after s.ts is set.
func (s *InventoryScreen) makeFilterPopup(col int, list *qt.QListWidget) *qt.QWidget {
	list.SetMinimumWidth(160)
	return makeFilterPopup(s.ts, col, list)
}

func (s *InventoryScreen) OnActivate() {
	_ = s.ctx.Scanner.StopScan()
	s.ts.HideRight()
	s.refresh()
}

func (s *InventoryScreen) refresh() {
	s.refreshThen(nil)
}

func (s *InventoryScreen) refreshThen(then func()) {
	includeConsumed := s.showConsumed
	go func() {
		bottles, err := s.ctx.Client.ListBottles(context.Background(), includeConsumed)
		if err != nil {
			s.ctx.Log.Error("list bottles", "error", err)
			return
		}
		mainthread.Start(func() {
			s.allBottles = bottles
			s.populate(bottles)
			// Apply pending dashboard filter by syncing the filter popups.
			if s.pendingFilterType != "" {
				s.applyPendingFilter()
			}
			if then != nil {
				then()
			}
		})
	}()
}

// SetFilter stores a pending filter that will be applied after the next refresh.
// Called by the manager when navigating from the dashboard drill-down.
// The pending filter is consumed by refreshThen's main-thread callback, avoiding
// a second ListBottles call (OnActivate already triggers refresh via navigate).
// The filter is one-shot — cleared after application.
func (s *InventoryScreen) SetFilter(filterType, filterValue string) {
	s.pendingFilterType = filterType
	s.pendingFilterValue = filterValue
}

func (s *InventoryScreen) populate(bottles []client.Bottle) {
	root := qt.NewQModelIndex()
	s.ts.SrcModel.RemoveRows(0, s.ts.SrcModel.RowCount(root), root)

	// Rebuild filter lists before appending rows so that filterAcceptsRow sees
	// up-to-date entries when each row is inserted into the proxy model.
	s.rebuildRegionList(bottles)
	s.rebuildDesigList(bottles)
	s.rebuildMillesList(bottles)

	now := time.Now()
	year := now.Year()

	if s.grouped {
		s.populateGrouped(bottles, year)
	} else {
		s.populateFlat(bottles, year)
	}

	s.ts.refreshFilterHeaders()
	s.ts.HideRight()
}

func (s *InventoryScreen) populateFlat(bottles []client.Bottle, year int) {
	for _, b := range bottles {
		cuveeName := b.Cuvee.Name
		desigName := b.Cuvee.DesignationName
		region := b.Cuvee.Region
		color := b.Cuvee.Color
		if region == "" {
			region = "—"
		}
		if desigName == "" {
			desigName = "Sans appellation"
		}

		millesime := fmt.Sprintf("%d", b.Vintage)
		millesSortKey := fmt.Sprintf("%06d", b.Vintage)

		var addedAtText, addedAtSortKey string
		if b.AddedAt != "" {
			if t, err := time.Parse(time.RFC3339, b.AddedAt); err == nil {
				addedAtText = t.Local().Format("02/01/2006")
				addedAtSortKey = t.UTC().Format(time.RFC3339)
			}
		}

		var bg *qt.QBrush
		if b.ConsumedAt != nil {
			bg = qt.NewQBrush3(qt.NewQColor6("#d5d8dc"))
		} else if b.DrinkBefore != nil {
			db := int(*b.DrinkBefore)
			if db < year {
				bg = qt.NewQBrush3(qt.NewQColor6("#f5b1b8"))
			} else if db < year+1 {
				bg = qt.NewQBrush3(qt.NewQColor6("#f4e2a8"))
			}
		}

		var drinkBeforeText, drinkBeforeSortKey string
		if b.DrinkBefore != nil {
			drinkBeforeText = fmt.Sprintf("%d", *b.DrinkBefore)
			drinkBeforeSortKey = fmt.Sprintf("%06d", *b.DrinkBefore)
		}

		texts := []string{colorNames[color], region, cuveeName, desigName, millesime, drinkBeforeText, "", addedAtText}
		items := make([]*qt.QStandardItem, 8)
		for col, text := range texts {
			item := nonEditableItem(text)
			if col == invColCouleur {
				item.SetData(qt.NewQVariant6(b.ID), userRole)
			}
			if col == invColMillesime {
				item.SetData(qt.NewQVariant11(millesSortKey), sortRole)
			}
			if col == invColDrinkBefore && drinkBeforeSortKey != "" {
				item.SetData(qt.NewQVariant11(drinkBeforeSortKey), sortRole)
			}
			if col == invColAddedAt && addedAtSortKey != "" {
				item.SetData(qt.NewQVariant11(addedAtSortKey), sortRole)
			}
			if bg != nil {
				item.SetBackground(bg)
			}
			items[col] = item
		}
		s.ts.SrcModel.AppendRow(items)
	}
}

type groupKey struct {
	color, region, cuvee, desig string
	vintage                     int32
}

type groupVal struct {
	count  int
	urgent int // 0 = none, 1 = drink-soon (yellow), 2 = overdue (red)
}

func (s *InventoryScreen) populateGrouped(bottles []client.Bottle, year int) {
	groups := make(map[groupKey]*groupVal)
	var keys []groupKey

	for _, b := range bottles {
		cuveeName := b.Cuvee.Name
		desigName := b.Cuvee.DesignationName
		region := b.Cuvee.Region
		color := b.Cuvee.Color
		if region == "" {
			region = "—"
		}
		if desigName == "" {
			desigName = "Sans appellation"
		}
		k := groupKey{colorNames[color], region, cuveeName, desigName, b.Vintage}
		v, ok := groups[k]
		if !ok {
			v = &groupVal{}
			groups[k] = v
			keys = append(keys, k)
		}
		v.count++
		if b.DrinkBefore != nil {
			db := int(*b.DrinkBefore)
			if db < year && v.urgent < 2 {
				v.urgent = 2
			} else if db < year+1 && v.urgent < 1 {
				v.urgent = 1
			}
		}
	}

	for _, k := range keys {
		v := groups[k]
		millesime := fmt.Sprintf("%d", k.vintage)
		millesSortKey := fmt.Sprintf("%06d", k.vintage)
		qteSortKey := fmt.Sprintf("%09d", v.count)

		var bg *qt.QBrush
		switch v.urgent {
		case 2:
			bg = qt.NewQBrush3(qt.NewQColor6("#f5b1b8"))
		case 1:
			bg = qt.NewQBrush3(qt.NewQColor6("#f4e2a8"))
		}

		texts := []string{k.color, k.region, k.cuvee, k.desig, millesime, "", fmt.Sprintf("%d", v.count), ""}
		items := make([]*qt.QStandardItem, 8)
		for col, text := range texts {
			item := nonEditableItem(text)
			if col == invColMillesime {
				item.SetData(qt.NewQVariant11(millesSortKey), sortRole)
			}
			if col == invColQte {
				item.SetData(qt.NewQVariant11(qteSortKey), sortRole)
			}
			if bg != nil {
				item.SetBackground(bg)
			}
			items[col] = item
		}
		s.ts.SrcModel.AppendRow(items)
	}
}

func (s *InventoryScreen) setWaiting(waiting bool, title string) {
	if waiting {
		s.waitTitle.SetText(title)
		s.rightStack.SetCurrentIndex(0)
	} else {
		s.rightStack.SetCurrentIndex(1)
	}
}

func (s *InventoryScreen) openAddForm() {
	s.ts.TableView.ClearSelection()
	s.bottleForm.clearFields()
	s.setWaiting(true, "En attente d'un scan NFC…")
	s.ts.SetSaveEnabled(false)
	s.ts.ShowRight()
	fillAdd := func(tagID string) {
		s.bottleForm.SetEPC(tagID)
		s.bottleForm.loadData(nil)
		s.setWaiting(false, "")
		s.ts.SetSaveEnabled(false) // nameEdit is still empty
		s.bottleForm.SetTitle("Nouvelle bouteille")
		s.ts.ShowRight()
	}
	s.ctx.Scanner.OnTagScanned(func(tagID string) {
		_ = s.ctx.Scanner.StopScan()
		fillAdd(tagID)
	})
	s.onSimulateTag = fillAdd
	s.ctx.Scanner.OnScanError(func(err error) {
		s.setWaiting(false, "")
		s.bottleForm.loadData(nil)
		s.bottleForm.SetTitle("Nouvelle bouteille")
		s.ts.ShowRight()
		s.ctx.Log.Error("scan error during add", "error", err)
		qt.QMessageBox_Warning(nil, "Erreur de scan", "Téléphone inaccessible — entrez le tag manuellement ou réessayez.")
	})
	if err := s.ctx.Scanner.StartScan(); err != nil {
		s.setWaiting(false, "")
		s.bottleForm.loadData(nil)
		s.bottleForm.SetTitle("Nouvelle bouteille")
		s.ts.ShowRight()
		s.ctx.Log.Error("scan start failed during add", "error", err)
		qt.QMessageBox_Warning(nil, "Erreur de scan", "Téléphone inaccessible — entrez le tag manuellement ou réessayez.")
	}
}

func (s *InventoryScreen) openEditForm(srcRow int) {
	b := s.bottleAtSourceRow(srcRow)
	if b == nil {
		return
	}
	_ = s.ctx.Scanner.StopScan()
	s.ts.SetSaveEnabled(false)
	s.setWaiting(false, "")
	s.rightStack.Hide()
	s.bottleForm.loadData(func() {
		s.rightStack.Show()
		s.bottleForm.loadBottle(*b)
		s.bottleForm.SetTitle(fmt.Sprintf("Modifier « %s »", func() string {
			if b.Cuvee.ID != 0 {
				return b.Cuvee.Name
			}
			return fmt.Sprintf("#%d", b.ID)
		}()))
		s.ts.SetSaveEnabled(b.ConsumedAt == nil) // consumed bottles are read-only
		s.ts.ShowRight()
	})
}

// addBottleFrom starts the add-bottle flow pre-filled from template.
// Each scan is a single read — after saving, the manager sends a new scan
// request for the next bottle.
func (s *InventoryScreen) addBottleFrom(template client.Bottle) {
	s.ts.TableView.ClearSelection()
	s.bottleForm.clearFields()
	s.setWaiting(true, "En attente d'un scan NFC…")
	s.ts.SetSaveEnabled(false)
	s.ts.ShowRight()

	fillFromTemplate := func(tagID string) {
		s.setWaiting(false, "")
		s.bottleForm.loadData(func() {
			s.bottleForm.loadBottle(template)
			s.bottleForm.setReadOnly(false)
			s.bottleForm.editBottleID = 0
			s.bottleForm.SetEPC(tagID)
			s.ts.SetSaveEnabled(true)
		})
		s.bottleForm.SetTitle("Nouvelle bouteille")
		s.ts.ShowRight()
	}

	s.ctx.Scanner.OnTagScanned(func(tagID string) {
		_ = s.ctx.Scanner.StopScan()
		fillFromTemplate(tagID)
	})
	s.onSimulateTag = fillFromTemplate

	s.ctx.Scanner.OnScanError(func(err error) {
		s.setWaiting(false, "")
		s.bottleForm.loadData(func() {
			s.bottleForm.loadBottle(template)
			s.bottleForm.setReadOnly(false)
			s.bottleForm.editBottleID = 0
		})
		s.bottleForm.SetTitle("Nouvelle bouteille")
		s.ts.ShowRight()
		s.ctx.Log.Error("scan error during intake", "error", err)
		qt.QMessageBox_Warning(nil, "Erreur de scan", "Téléphone inaccessible — entrez le tag manuellement ou réessayez.")
	})

	if err := s.ctx.Scanner.StartScan(); err != nil {
		s.setWaiting(false, "")
		s.bottleForm.loadData(func() {
			s.bottleForm.loadBottle(template)
			s.bottleForm.setReadOnly(false)
			s.bottleForm.editBottleID = 0
		})
		s.bottleForm.SetTitle("Nouvelle bouteille")
		s.ts.ShowRight()
		s.ctx.Log.Error("scan start failed during intake", "error", err)
		qt.QMessageBox_Warning(nil, "Erreur de scan", "Téléphone inaccessible — entrez le tag manuellement ou réessayez.")
	}
}

func (s *InventoryScreen) onSave() {
	f := s.bottleForm
	cuveeID := f.selectedCuveeID()

	if cuveeID == 0 && f.cuveeSect.Widget.IsVisible() {
		s.createInlineCuveeThenSave()
		return
	}

	if cuveeID == 0 {
		qt.QMessageBox_Warning(nil, "Erreur", "Veuillez sélectionner une cuvée existante.")
		return
	}

	if f.editBottleID != 0 {
		s.updateBottle(cuveeID)
	} else {
		s.addBottle(cuveeID)
	}
}

func (s *InventoryScreen) createInlineCuveeThenSave() {
	f := s.bottleForm
	cf := f.cuveeForm
	if cf.Name() == "" || cf.DomainText() == "" || cf.DesignText() == "" {
		qt.QMessageBox_Warning(nil, "Erreur", "Le nom, le domaine et l'appellation sont obligatoires pour la nouvelle cuvée.")
		return
	}
	editBottleID := f.editBottleID

	go func() {
		cuvee, err := cf.save(context.Background())
		if err != nil {
			s.ctx.Log.Error("add cuvee on-the-fly (inventory)", "error", err)
			mainthread.Start(func() {
				qt.QMessageBox_Warning(nil, "Erreur", "Impossible de créer la cuvée : "+err.Error())
			})
			return
		}

		label := fmt.Sprintf("%s — %s", cuvee.Name, cuvee.DomainName)
		mainthread.Start(func() {
			f.allCuvees = append(f.allCuvees, cuvee)
			f.cuveeLabels = append(f.cuveeLabels, label)
			f.rebuildCompleter()
			f.nameEdit.BlockSignals(true)
			f.nameEdit.SetText(label)
			f.nameEdit.BlockSignals(false)
			f.cuveeSect.Widget.Hide()
			cf.clearFields()
		})

		if editBottleID != 0 {
			s.updateBottle(cuvee.ID)
		} else {
			s.addBottle(cuvee.ID)
		}
	}()
}

func (s *InventoryScreen) addBottle(cuveeID int64) {
	f := s.bottleForm
	tagID := f.epc
	req := client.CreateBottle{
		CuveeID:     cuveeID,
		Vintage:     int32(f.vintageSpin.Value()),
		Description: f.Description(),
	}
	if tagID != "" {
		req.TagID = &tagID
	}
	if p := parseOptFloat(f.priceEdit.Text()); p != nil {
		req.PurchasePrice = p
	}
	if v := f.drinkSpin.Value(); v > 0 {
		v32 := int32(v)
		req.DrinkBefore = &v32
	}

	// Build a template for the automatic addBottleFrom chain.
	var templateCuvee client.Cuvee
	for _, c := range f.allCuvees {
		if c.ID == cuveeID {
			templateCuvee = c
			break
		}
	}
	template := client.Bottle{
		Vintage:       req.Vintage,
		Description:   req.Description,
		PurchasePrice: req.PurchasePrice,
		DrinkBefore:   req.DrinkBefore,
		Cuvee:         templateCuvee,
	}

	go func() {
		bottle, err := s.ctx.Client.AddBottle(context.Background(), req)
		if err != nil {
			s.ctx.Log.Error("add bottle", "error", err)
			mainthread.Start(func() {
				qt.QMessageBox_Warning(nil, "Erreur", "Impossible d'ajouter la bouteille : "+err.Error())
			})
			return
		}
		s.ctx.Log.Info("bottle added", "bottle_id", bottle.ID)
		mainthread.Start(func() {
			s.refreshThen(func() {
				// Start a new single scan for the next bottle.
				s.addBottleFrom(template)
			})
		})
	}()
}

func (s *InventoryScreen) updateBottle(cuveeID int64) {
	f := s.bottleForm
	updates := map[string]any{
		"cuvee_id":    cuveeID,
		"vintage":     int32(f.vintageSpin.Value()),
		"description": f.Description(),
	}

	if p := parseOptFloat(f.priceEdit.Text()); p != nil {
		updates["purchase_price"] = *p
	} else {
		updates["purchase_price"] = nil // explicit null = clear
	}

	if v := f.drinkSpin.Value(); v > 0 {
		updates["drink_before"] = int32(v)
	} else {
		updates["drink_before"] = nil // explicit null = clear
	}

	id := f.editBottleID
	doAsync(s.ctx.Log, "update bottle", "Impossible de modifier la bouteille", func() error {
		_, err := s.ctx.Client.UpdateBottle(context.Background(), id, updates)
		return err
	}, func() {
		s.ts.HideRight()
		s.refresh()
	})
}

func (s *InventoryScreen) onDelete() {
	rows := s.ts.TableView.SelectionModel().SelectedRows()
	if len(rows) != 1 {
		return
	}
	srcRow := s.ts.Proxy.MapToSource(&rows[0]).Row()
	b := s.bottleAtSourceRow(srcRow)
	if b == nil {
		return
	}
	var label string
	if b.Cuvee.ID != 0 {
		label = fmt.Sprintf("%s — %s %d", b.Cuvee.DomainName, b.Cuvee.Name, b.Vintage)
	} else {
		label = fmt.Sprintf("#%d", b.ID)
	}
	if !showQuestion(s.Widget, "Supprimer", fmt.Sprintf("Supprimer la bouteille « %s » ? Attention, les bouteilles ne devraient pas être supprimées du stock mais plutôt marquée comme consommées.", label)) {
		return
	}
	doAsync(s.ctx.Log, "delete bottle", "Suppression échouée", func() error {
		return s.ctx.Client.DeleteBottle(context.Background(), b.ID)
	}, func() {
		s.ts.HideRight()
		s.refresh()
	})
}

func (s *InventoryScreen) rebuildRegionList(bottles []client.Bottle) {
	s.regionList.BlockSignals(true)
	s.regionList.Clear()
	seen := map[string]struct{}{}
	var values []string
	for _, b := range bottles {
		r := "—"
		if b.Cuvee.Region != "" {
			r = b.Cuvee.Region
		}
		if _, ok := seen[r]; !ok {
			seen[r] = struct{}{}
			values = append(values, r)
		}
	}
	sort.Strings(values)
	for _, v := range values {
		item := qt.NewQListWidgetItem2(v)
		item.SetFlags(qt.ItemIsUserCheckable | qt.ItemIsEnabled)
		item.SetCheckState(qt.Checked)
		s.regionList.AddItemWithItem(item)
	}
	s.regionList.BlockSignals(false)
}

func (s *InventoryScreen) rebuildMillesList(bottles []client.Bottle) {
	s.millesList.BlockSignals(true)
	s.millesList.Clear()
	seen := map[string]struct{}{}
	var values []string
	for _, b := range bottles {
		v := fmt.Sprintf("%d", b.Vintage)
		if _, ok := seen[v]; !ok {
			seen[v] = struct{}{}
			values = append(values, v)
		}
	}
	sort.Sort(sort.Reverse(sort.StringSlice(values)))
	for _, v := range values {
		item := qt.NewQListWidgetItem2(v)
		item.SetFlags(qt.ItemIsUserCheckable | qt.ItemIsEnabled)
		item.SetCheckState(qt.Checked)
		s.millesList.AddItemWithItem(item)
	}
	s.millesList.BlockSignals(false)
}

func (s *InventoryScreen) rebuildDesigList(bottles []client.Bottle) {
	s.desigList.BlockSignals(true)
	s.desigList.Clear()
	seen := map[string]struct{}{}
	var values []string
	for _, b := range bottles {
		d := b.Cuvee.DesignationName
		if d == "" {
			d = "Sans appellation"
		}
		if _, ok := seen[d]; !ok {
			seen[d] = struct{}{}
			values = append(values, d)
		}
	}
	sort.Strings(values)
	for _, v := range values {
		item := qt.NewQListWidgetItem2(v)
		item.SetFlags(qt.ItemIsUserCheckable | qt.ItemIsEnabled)
		item.SetCheckState(qt.Checked)
		s.desigList.AddItemWithItem(item)
	}
	s.desigList.BlockSignals(false)
}

// applyPendingFilter syncs the filter popup check-state to match the
// dashboard drill-down filter, then invalidates the proxy so that
// the data-table reflects the selection. The filter is one-shot.
func (s *InventoryScreen) applyPendingFilter() {
	filterType := s.pendingFilterType
	filterValue := s.pendingFilterValue
	s.pendingFilterType = ""
	s.pendingFilterValue = ""

	switch filterType {
	case FilterByColor:
		// filterValue is the lowercase identifier ("rouge"); translate to
		// the display name used in the color list ("Rouge").
		var displayName string
		for enumVal, id := range colorIdentifiers {
			if id == filterValue {
				displayName = colorNames[enumVal]
				break
			}
		}
		uncheckAllExcept(s.colorList, displayName)
	case FilterByDesignation:
		// filterValue is the exact designation name or "Sans appellation".
		uncheckAllExcept(s.desigList, filterValue)
	case FilterByRegion:
		// filterValue is the exact region name or "Sans région".
		displayName := filterValue
		if displayName == "Sans région" {
			displayName = "—"
		}
		uncheckAllExcept(s.regionList, displayName)
	}
	s.ts.Proxy.InvalidateFilter()
	s.ts.refreshFilterHeaders()
}

// uncheckAllExcept unchecks every item in list except the one whose text
// matches keep. If keep is empty or not found, all items stay checked.
func uncheckAllExcept(list *qt.QListWidget, keep string) {
	if keep == "" {
		return
	}
	found := false
	for i := 0; i < list.Count(); i++ {
		if list.Item(i).Text() == keep {
			found = true
			break
		}
	}
	if !found {
		return
	}
	list.BlockSignals(true)
	for i := 0; i < list.Count(); i++ {
		item := list.Item(i)
		if item.Text() == keep {
			item.SetCheckState(qt.Checked)
		} else {
			item.SetCheckState(qt.Unchecked)
		}
	}
	list.BlockSignals(false)
}

// firstBottleAtGroupedRow returns the first bottle in allBottles whose
// color/cuvée/vintage matches the grouped summary row at srcRow.
func (s *InventoryScreen) firstBottleAtGroupedRow(srcRow int) *client.Bottle {
	colorText := s.ts.SrcModel.Item2(srcRow, invColCouleur).Text()
	cuveeText := s.ts.SrcModel.Item2(srcRow, invColCuvee).Text()
	millesimeText := s.ts.SrcModel.Item2(srcRow, invColMillesime).Text()
	for i := range s.allBottles {
		b := &s.allBottles[i]
		if colorNames[b.Cuvee.Color] == colorText &&
			b.Cuvee.Name == cuveeText &&
			fmt.Sprintf("%d", b.Vintage) == millesimeText {
			return b
		}
	}
	return nil
}

func (s *InventoryScreen) bottleAtSourceRow(row int) *client.Bottle {
	item := s.ts.SrcModel.Item2(row, invColCouleur)
	if item == nil {
		return nil
	}
	id := item.Data(userRole).ToLongLong()
	for i := range s.allBottles {
		if s.allBottles[i].ID == id {
			return &s.allBottles[i]
		}
	}
	return nil
}

func (s *InventoryScreen) checkedItems(list *qt.QListWidget) map[string]struct{} {
	out := map[string]struct{}{}
	if list == nil {
		return out
	}
	for i := 0; i < list.Count(); i++ {
		item := list.Item(i)
		if item.CheckState() == qt.Checked {
			out[item.Text()] = struct{}{}
		}
	}
	return out
}

// ── Consume bottle ────────────────────────────────────────────────────────────

func (s *InventoryScreen) onConsumeBottle() {
	row := s.ts.SelectedSourceRow()
	b := s.bottleAtSourceRow(row)
	if b == nil {
		return
	}
	if b.TagID == nil || *b.TagID == "" {
		qt.QMessageBox_Warning(nil, "Impossible", "Cette bouteille n'a pas de tag NFC associé.")
		return
	}
	label := fmt.Sprintf("#%d", b.ID)
	if b.Cuvee.ID != 0 {
		label = fmt.Sprintf("%s — %s %d", b.Cuvee.DomainName, b.Cuvee.Name, b.Vintage)
	}
	if !showQuestion(s.Widget, "Marquer comme bue", fmt.Sprintf("Marquer « %s » comme bue ?", label)) {
		return
	}
	epc := *b.TagID
	doAsync(s.ctx.Log, "consume bottle", "Impossible de marquer la bouteille", func() error {
		_, err := s.ctx.Client.ConsumeBottle(context.Background(), epc)
		return err
	}, func() {
		s.ts.HideRight()
		s.refresh()
	})
}

// ── Search by NFC tag ─────────────────────────────────────────────────────────

func (s *InventoryScreen) onSearchByTag() {
	s.ts.TableView.ClearSelection()
	s.setWaiting(true, "Recherche par tag NFC")
	s.ts.ShowRight()
	s.ctx.Scanner.OnTagScanned(func(tagID string) {
		_ = s.ctx.Scanner.StopScan()

		var found *client.Bottle
		for i := range s.allBottles {
			if s.allBottles[i].TagID != nil && *s.allBottles[i].TagID == tagID {
				found = &s.allBottles[i]
				break
			}
		}

		if found == nil {
			s.setWaiting(false, "")
			s.ts.HideRight()
			qt.QMessageBox_Information(nil, "Introuvable",
				fmt.Sprintf("Aucune bouteille avec le tag « %s ».", tagID))
			return
		}

		// Find the source row for this bottle, select it, and scroll it into view.
		for row := 0; row < s.ts.SrcModel.RowCount(qt.NewQModelIndex()); row++ {
			item := s.ts.SrcModel.Item2(row, invColCouleur)
			if item != nil && item.Data(userRole).ToLongLong() == found.ID {
				proxyIdx := s.ts.Proxy.MapFromSource(s.ts.SrcModel.IndexFromItem(s.ts.SrcModel.Item2(row, 0)))
				s.ts.TableView.SetCurrentIndex(proxyIdx)
				s.ts.TableView.QAbstractItemView.ScrollTo(proxyIdx, qt.QAbstractItemView__EnsureVisible)
				break
			}
		}
		s.setWaiting(false, "")
	})
	s.ctx.Scanner.OnScanError(func(err error) {
		s.setWaiting(false, "")
		s.ts.HideRight()
		s.ctx.Log.Error("scan error during search", "error", err)
		qt.QMessageBox_Warning(nil, "Erreur de scan", "Téléphone inaccessible — réessayez.")
	})
	if err := s.ctx.Scanner.StartScan(); err != nil {
		s.setWaiting(false, "")
		s.ts.HideRight()
		s.ctx.Log.Error("scan start failed during search", "error", err)
		qt.QMessageBox_Warning(nil, "Erreur de scan", "Téléphone inaccessible — réessayez.")
	}
}
