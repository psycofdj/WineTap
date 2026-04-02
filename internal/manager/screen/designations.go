package screen

import (
	"context"
	"fmt"
	"strings"

	qt "github.com/mappu/miqt/qt6"

	"winetap/internal/client"
)

type DesignationsScreen struct {
	crudBase[client.Designation]

	filterPopup   *qt.QWidget
	regionListPop *qt.QListWidget

	desigForm *designationForm
}

func BuildDesignationsScreen(ctx *Ctx) *DesignationsScreen {
	s := &DesignationsScreen{}
	s.ctx = ctx
	s.name = "designation"
	s.listFn = func(c context.Context) ([]client.Designation, error) {
		return ctx.Client.ListDesignations(c)
	}
	s.delMsg = func(d client.Designation) string {
		return fmt.Sprintf("Supprimer l'appellation « %s »", d.Name)
	}
	s.delFn = func(c context.Context, d client.Designation) error {
		return ctx.Client.DeleteDesignation(c, d.ID)
	}

	s.desigForm = newDesignationForm(ctx.Client)

	s.ts = newTableScreen(tableScreenCfg{
		ScreenTitle:       "Appellations",
		Headers:           []string{"Nom", "Région"},
		SearchPlaceholder: "Rechercher par nom…",
		FilterCols:        []int{1},
		OnFilterCol:       func(_ int) { s.ts.ShowPopup(1, s.filterPopup) },
		ExtraFilterAccepts: func(_ *qt.QStandardItemModel, srcRow int) bool {
			checked := checkedItems(s.regionListPop)
			if len(checked) == 0 {
				return true
			}
			_, ok := checked[s.ts.SrcModel.Item2(srcRow, 1).Text()]
			return ok
		},
		FormContent: s.desigForm.widget,
		OnSelectionChange: func(srcRow int) {
			if srcRow >= 0 && srcRow < len(s.all) {
				d := s.all[srcRow]
				s.desigForm.loadForEdit(d, s.regionCompletions())
				s.desigForm.SetTitle(fmt.Sprintf("Modifier « %s »", d.Name))
				s.ts.ShowRight()
				s.desigForm.regionEdit.SetFocus()
			} else {
				s.ts.HideRight()
			}
		},
		OnAdd: func() {
			s.ts.TableView.ClearSelection()
			s.desigForm.loadForAdd(s.regionCompletions())
			s.desigForm.SetTitle("Nouvelle appellation")
			s.ts.ShowRight()
			s.desigForm.nameEdit.SetFocus()
		},
		OnDelete: func() { s.onDelete() },
		OnSave:   func() { s.onSave() },
	})
	s.Widget = s.ts.Widget
	s.popFn = s.populate

	// Build filter popup after ts is set (it references ts.Proxy).
	s.regionListPop = qt.NewQListWidget2()
	s.regionListPop.SetMinimumWidth(200)
	s.filterPopup = makeFilterPopup(s.ts, 1, s.regionListPop)

	// Validation: save enabled only when name and region are non-empty.
	revalidate := func() {
		s.ts.SetSaveEnabled(s.desigForm.Name() != "" && s.desigForm.Region() != "")
	}
	s.desigForm.nameEdit.OnTextChanged(func(_ string) { revalidate() })
	s.desigForm.regionEdit.OnTextChanged(func(_ string) { revalidate() })

	return s
}

func (s *DesignationsScreen) populate() {
	root := qt.NewQModelIndex()
	s.ts.SrcModel.RemoveRows(0, s.ts.SrcModel.RowCount(root), root)

	regionSet := map[string]struct{}{}
	for _, d := range s.all {
		s.ts.SrcModel.AppendRow([]*qt.QStandardItem{
			nonEditableItem(d.Name),
			nonEditableItem(d.Region),
		})
		if d.Region != "" {
			regionSet[d.Region] = struct{}{}
		}
	}
	s.rebuildRegionPopup(regionSet)
	s.ts.refreshFilterHeaders()
}

func (s *DesignationsScreen) rebuildRegionPopup(regions map[string]struct{}) {
	wasChecked := checkedItems(s.regionListPop)
	s.regionListPop.BlockSignals(true)
	s.regionListPop.Clear()

	sorted := make([]string, 0, len(regions))
	for r := range regions {
		sorted = append(sorted, r)
	}
	for i := 1; i < len(sorted); i++ {
		for j := i; j > 0 && strings.ToLower(sorted[j-1]) > strings.ToLower(sorted[j]); j-- {
			sorted[j-1], sorted[j] = sorted[j], sorted[j-1]
		}
	}
	for _, r := range sorted {
		item := qt.NewQListWidgetItem2(r)
		item.SetFlags(qt.ItemIsEnabled | qt.ItemIsUserCheckable)
		if _, ok := wasChecked[r]; ok {
			item.SetCheckState(qt.Checked)
		} else {
			item.SetCheckState(qt.Unchecked)
		}
		s.regionListPop.AddItemWithItem(item)
	}
	itemH := 22
	h := s.regionListPop.Count() * itemH
	if h > 10*itemH {
		h = 10 * itemH
	}
	s.regionListPop.SetFixedHeight(h + 4)
	s.regionListPop.BlockSignals(false)
}

func (s *DesignationsScreen) regionCompletions() []string {
	regions := make([]string, 0, s.regionListPop.Count())
	for i := 0; i < s.regionListPop.Count(); i++ {
		regions = append(regions, s.regionListPop.Item(i).Text())
	}
	return regions
}

func (s *DesignationsScreen) onSave() {
	if s.desigForm.Name() == "" || s.desigForm.Region() == "" {
		qt.QMessageBox_Warning(nil, "Erreur", "Le nom et la région sont obligatoires.")
		return
	}
	doAsync(s.ctx.Log, "save designation", "Impossible d'enregistrer", func() error {
		_, err := s.desigForm.save(context.Background())
		return err
	}, func() {
		s.ts.HideRight()
		s.refresh()
	})
}
