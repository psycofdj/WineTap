package screen

import (
	"context"
	"fmt"

	qt "github.com/mappu/miqt/qt6"
	"github.com/mappu/miqt/qt6/mainthread"

	"winetap/internal/client"
)

type CuveesScreen struct {
	crudBase[client.Cuvee]

	filterPopup  *qt.QWidget
	colorListPop *qt.QListWidget

	cuvForm *cuveeForm
}

func BuildCuveesScreen(ctx *Ctx) *CuveesScreen {
	s := &CuveesScreen{}
	s.ctx = ctx
	s.name = "cuvee"
	s.listFn = func(c context.Context) ([]client.Cuvee, error) {
		return ctx.Client.ListCuvees(c)
	}
	s.delMsg = func(c client.Cuvee) string {
		return fmt.Sprintf("Supprimer la cuvée « %s »", c.Name)
	}
	s.delFn = func(c context.Context, cv client.Cuvee) error {
		return ctx.Client.DeleteCuvee(c, cv.ID)
	}
	s.nameFn = func(c client.Cuvee) string { return c.Name }
	s.refMsg = "cette cuvée est encore utilisée par une ou plusieurs bouteilles"

	s.cuvForm = newCuveeForm(ctx.Client)

	s.ts = newTableScreen(tableScreenCfg{
		ScreenTitle:       "Cuvées",
		Headers:           []string{"Nom", "Domaine", "Appellation", "Couleur"},
		SearchPlaceholder: "Rechercher par nom…",
		FilterCols:        []int{3},
		OnFilterCol:       func(_ int) { s.ts.ShowPopup(3, s.filterPopup) },
		ExtraFilterAccepts: func(_ *qt.QStandardItemModel, srcRow int) bool {
			checked := checkedItems(s.colorListPop)
			if len(checked) == 0 {
				return true
			}
			_, ok := checked[s.ts.SrcModel.Item2(srcRow, 3).Text()]
			return ok
		},
		FormContent: s.cuvForm.widget,
		OnSelectionChange: func(srcRow int) {
			if srcRow >= 0 && srcRow < len(s.all) {
				s.openEditForm(s.all[srcRow])
			} else {
				s.ts.HideRight()
			}
		},
		OnAdd:    func() { s.openAddForm() },
		OnDelete: func() { s.onDelete() },
		OnCopy: func() {
			row := s.ts.SelectedSourceRow()
			if row >= 0 && row < len(s.all) {
				s.openCopyForm(s.all[row])
			}
		},
		OnSave: func() { s.onSave() },
	})
	s.Widget = s.ts.Widget
	s.popFn = s.populate

	// Build filter popup after ts is set (it references ts.Proxy).
	s.colorListPop = qt.NewQListWidget2()
	s.colorListPop.SetMinimumWidth(180)
	for _, col := range colorOrder {
		item := qt.NewQListWidgetItem2(colorNames[col])
		item.SetFlags(qt.ItemIsUserCheckable | qt.ItemIsEnabled)
		item.SetCheckState(qt.Checked)
		s.colorListPop.AddItemWithItem(item)
	}
	s.filterPopup = makeFilterPopup(s.ts, 3, s.colorListPop)

	// Validation: save enabled only when name, domain, and designation are non-empty.
	revalidate := func() {
		s.ts.SetSaveEnabled(
			s.cuvForm.Name() != "" &&
				s.cuvForm.DomainText() != "" &&
				s.cuvForm.DesignText() != "",
		)
	}
	s.cuvForm.nameEdit.OnTextChanged(func(_ string) { revalidate() })
	s.cuvForm.domainCombo.OnCurrentTextChanged(func(_ string) { revalidate() })
	s.cuvForm.designCombo.OnCurrentTextChanged(func(_ string) { revalidate() })

	return s
}

func (s *CuveesScreen) populate() {
	root := qt.NewQModelIndex()
	s.ts.SrcModel.RemoveRows(0, s.ts.SrcModel.RowCount(root), root)
	for _, c := range s.all {
		nameItem := nonEditableItem(c.Name)
		nameItem.SetData(qt.NewQVariant6(c.ID), userRole)
		s.ts.SrcModel.AppendRow([]*qt.QStandardItem{
			nameItem,
			nonEditableItem(c.DomainName),
			nonEditableItem(c.DesignationName),
			nonEditableItem(colorNames[c.Color]),
		})
	}
}

func (s *CuveesScreen) loadCombos(then func()) {
	go func() {
		doms, domErr := s.ctx.Client.ListDomains(context.Background())
		desigs, desigErr := s.ctx.Client.ListDesignations(context.Background())
		mainthread.Start(func() {
			if domErr == nil {
				s.cuvForm.setDomains(doms)
			} else {
				s.cuvForm.setDomains(nil)
			}
			if desigErr == nil {
				s.cuvForm.setDesignations(desigs)
			} else {
				s.cuvForm.setDesignations(nil)
			}
			if then != nil {
				then()
			}
		})
	}()
}

func (s *CuveesScreen) openAddForm() {
	s.ts.TableView.ClearSelection()
	s.loadCombos(func() {
		s.cuvForm.loadForAdd()
		s.cuvForm.SetTitle("Nouvelle cuvée")
		s.ts.ShowRight()
		s.cuvForm.nameEdit.SetFocus()
	})
}

func (s *CuveesScreen) openCopyForm(c client.Cuvee) {
	s.ts.TableView.ClearSelection()
	s.loadCombos(func() {
		s.cuvForm.loadForCopy(c)
		s.cuvForm.SetTitle(fmt.Sprintf("Copie de « %s »", c.Name))
		s.ts.ShowRight()
		s.cuvForm.nameEdit.SetFocus()
	})
}

func (s *CuveesScreen) openEditForm(c client.Cuvee) {
	s.loadCombos(func() {
		s.cuvForm.loadForEdit(c)
		s.cuvForm.SetTitle(fmt.Sprintf("Modifier « %s »", c.Name))
		s.ts.ShowRight()
		s.cuvForm.nameEdit.SetFocus()
	})
}

func (s *CuveesScreen) onSave() {
	if s.cuvForm.Name() == "" || s.cuvForm.DomainText() == "" || s.cuvForm.DesignText() == "" {
		qt.QMessageBox_Warning(nil, "Erreur", "Le nom, le domaine et l'appellation sont obligatoires.")
		return
	}
	go func() {
		_, err := s.cuvForm.save(context.Background())
		mainthread.Start(func() {
			if err != nil {
				qt.QMessageBox_Warning(nil, "Erreur", err.Error())
				return
			}
			s.ts.HideRight()
			s.refresh()
		})
	}()
}
