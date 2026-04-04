package screen

import (
	"context"
	"fmt"

	qt "github.com/mappu/miqt/qt6"

	"winetap/internal/client"
)

type DomainsScreen struct {
	crudBase[client.Domain]
	domForm *domainForm
}

func BuildDomainsScreen(ctx *Ctx) *DomainsScreen {
	s := &DomainsScreen{}
	s.ctx = ctx
	s.name = "domain"
	s.listFn = func(c context.Context) ([]client.Domain, error) {
		return ctx.Client.ListDomains(c)
	}
	s.delMsg = func(d client.Domain) string {
		return fmt.Sprintf("Supprimer le domaine « %s »", d.Name)
	}
	s.delFn = func(c context.Context, d client.Domain) error {
		return ctx.Client.DeleteDomain(c, d.ID)
	}
	s.nameFn = func(d client.Domain) string { return d.Name }
	s.refMsg = "ce domaine est encore utilisé par une ou plusieurs cuvées"

	s.domForm = newDomainForm(ctx.Client)

	s.ts = newTableScreen(tableScreenCfg{
		ScreenTitle:       "Domaines",
		Headers:           []string{"Nom", "Description"},
		SearchPlaceholder: "Rechercher par nom…",
		FormContent:       s.domForm.widget,
		OnSelectionChange: func(srcRow int) {
			if srcRow >= 0 && srcRow < len(s.all) {
				d := s.all[srcRow]
				s.domForm.loadForEdit(d)
				s.domForm.SetTitle(fmt.Sprintf("Modifier « %s »", d.Name))
				s.ts.ShowRight()
				s.domForm.nameEdit.SetFocus()
			} else {
				s.ts.HideRight()
			}
		},
		OnAdd: func() {
			s.ts.TableView.ClearSelection()
			s.domForm.loadForAdd()
			s.domForm.SetTitle("Nouveau domaine")
			s.ts.ShowRight()
			s.domForm.nameEdit.SetFocus()
		},
		OnDelete: func() { s.onDelete() },
		OnSave:   func() { s.onSave() },
	})
	s.Widget = s.ts.Widget
	s.popFn = s.populate

	// Validation: save enabled only when name is non-empty.
	s.domForm.nameEdit.OnTextChanged(func(_ string) {
		s.ts.SetSaveEnabled(s.domForm.Name() != "")
	})

	return s
}

func (s *DomainsScreen) populate() {
	root := qt.NewQModelIndex()
	s.ts.SrcModel.RemoveRows(0, s.ts.SrcModel.RowCount(root), root)
	for _, d := range s.all {
		s.ts.SrcModel.AppendRow([]*qt.QStandardItem{
			nonEditableItem(d.Name),
			nonEditableItem(d.Description),
		})
	}
}

func (s *DomainsScreen) onSave() {
	if s.domForm.Name() == "" {
		qt.QMessageBox_Warning(nil, "Erreur", "Le nom est obligatoire.")
		return
	}
	doAsync(s.ctx.Log, "save domain", "Impossible d'enregistrer", func() error {
		_, err := s.domForm.save(context.Background())
		return err
	}, func() {
		s.ts.HideRight()
		s.refresh()
	})
}
