package screen

import (
	"context"
	"errors"
	"fmt"

	qt "github.com/mappu/miqt/qt6"
	"github.com/mappu/miqt/qt6/mainthread"

	"winetap/internal/client"
)

// crudBase[T] provides the OnActivate / refresh / onDelete boilerplate shared
// by all three catalogue screens (Domains, Designations, Cuvées).
//
// Embed crudBase[T] by value in a concrete screen struct.  After creating the
// embedded value, set popFn = s.populate so that refresh can call the
// screen-specific populate method.
type crudBase[T any] struct {
	Widget *qt.QWidget
	ts     *tableScreen
	ctx    *Ctx

	all     []T
	listFn  func(context.Context) ([]T, error)
	popFn   func()
	delMsg  func(T) string
	delFn   func(context.Context, T) error
	nameFn  func(T) string // human-readable name of the item
	name    string         // used in log messages, e.g. "domain"
	refMsg  string         // French message shown on FK violation
}

// OnActivate hides the right panel and refreshes the list.
func (b *crudBase[T]) OnActivate() {
	b.ts.HideRight()
	b.refresh()
}

// refresh fetches the full list in a goroutine and calls popFn on the main thread.
func (b *crudBase[T]) refresh() {
	go func() {
		items, err := b.listFn(context.Background())
		if err != nil {
			b.ctx.Log.Error("list "+b.name, "error", err)
			return
		}
		mainthread.Start(func() {
			b.all = items
			b.popFn()
			b.ts.SelectFirstRow()
		})
	}()
}

// onDelete confirms and deletes the selected item.
func (b *crudBase[T]) onDelete() {
	row := b.ts.SelectedSourceRow()
	if row < 0 || row >= len(b.all) {
		return
	}
	item := b.all[row]
	if !showQuestion(b.Widget, "Supprimer", fmt.Sprintf("%s ?", b.delMsg(item))) {
		return
	}
	go func() {
		if err := b.delFn(context.Background(), item); err != nil {
			b.ctx.Log.Error("delete "+b.name, "error", err)
			msg := "Suppression échouée"
			var apiErr *client.APIError
			if errors.As(err, &apiErr) && apiErr.Code == "referenced" {
				msg = fmt.Sprintf("Impossible de supprimer « %s » : %s",
					b.nameFn(item), b.refMsg)
			}
			mainthread.Start(func() {
				qt.QMessageBox_Warning(nil, "Erreur", msg)
			})
			return
		}
		mainthread.Start(func() {
			b.ts.HideRight()
			b.refresh()
		})
	}()
}
