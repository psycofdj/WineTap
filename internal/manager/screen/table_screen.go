package screen

import (
	"strings"

	qt "github.com/mappu/miqt/qt6"
)

// tableScreenCfg configures a tableScreen.
type tableScreenCfg struct {
	// ── Left panel ────────────────────────────────────────────────────────────

	ScreenTitle       string
	Headers           []string
	SearchPlaceholder string
	// SearchCols is the set of source-model column indices searched by the text
	// box.  nil/empty defaults to [0].
	SearchCols     []int
	InitialSortCol int

	// ExtraToolbar is an optional widget placed between the screen title and the
	// search box in the left panel.  Use it for per-screen toolbar controls.
	ExtraToolbar *qt.QWidget

	// FilterCols are column indices that show a popup instead of toggling sort
	// when clicked.  OnFilterCol receives the clicked column index.
	FilterCols  []int
	OnFilterCol func(col int)

	// ExtraFilterAccepts is called by the proxy filter after the search-text
	// check.  src is the source model; srcRow is the source row.  Return false
	// to hide the row.  nil = accept all rows.
	ExtraFilterAccepts func(src *qt.QStandardItemModel, srcRow int) bool

	// LessThanOverride replaces the default foldAccents / col-0 tie-break sort.
	// Use this when a column requires a non-text sort key (e.g. a numeric role).
	LessThanOverride func(src *qt.QStandardItemModel, left, right *qt.QModelIndex) bool

	// ── Callbacks ─────────────────────────────────────────────────────────────

	OnAdd    func()
	OnDelete func()
	// OnCopy, when non-nil, adds a "Copier" (warning) button next to Delete.
	OnCopy func()

	// ExtraActionBtns are additional pre-built buttons appended to the action
	// button row after the copy button.  The caller owns the buttons and their
	// click handlers.
	ExtraActionBtns []*qt.QPushButton

	// OnSelectionChange receives the source row, or -1 when selection is empty.
	OnSelectionChange func(srcRow int)

	// ── Right panel ───────────────────────────────────────────────────────────

	// FormContent is the widget placed in the right panel body.
	// nil → no right panel / no splitter.
	FormContent        *qt.QWidget
	RightPanelMinWidth int // 0 → 420

	OnSave   func()
	OnCancel func() // nil → default: HideRight()
}

// tableScreen is the reusable left-table + right-panel layout used by all
// catalogue and inventory screens.
type tableScreen struct {
	Widget          *qt.QWidget // root widget; add to QStackedWidget
	TableView       *qt.QTableView
	SrcModel        *qt.QStandardItemModel
	Proxy           *qt.QSortFilterProxyModel
	SearchEdit      *qt.QLineEdit
	RightPanel      *qt.QWidget     // nil when FormContent was nil
	rightPanelInner *qt.QScrollArea // shown/hidden by ShowRight/HideRight
	AddBtn          *qt.QPushButton
	DelBtn          *qt.QPushButton
	CopyBtn         *qt.QPushButton // nil when OnCopy was not set
	SaveBtn         *qt.QPushButton
	CancelBtn       *qt.QPushButton

	sortCol   int
	sortOrder qt.SortOrder

	// filterLists maps column index → filter list widget.
	// Registered by makeFilterPopup; used to highlight active-filter headers.
	filterLists map[int]*qt.QListWidget
}

// SetSaveEnabled enables or disables the save button (no-op when there is none).
func (ts *tableScreen) SetSaveEnabled(enabled bool) {
	if ts.SaveBtn != nil {
		ts.SaveBtn.SetEnabled(enabled)
	}
}

// ShowRight shows the right panel contents.
// The form title is managed by the form itself (baseForm.SetTitle).
func (ts *tableScreen) ShowRight() {
	if ts.rightPanelInner != nil {
		ts.rightPanelInner.Show()
	}
	if ts.RightPanel != nil {
		setWidgetRole(ts.RightPanel, "form-panel")
		ts.RightPanel.Style().Unpolish(ts.RightPanel)
		ts.RightPanel.Style().Polish(ts.RightPanel)
		ts.RightPanel.Update()
	}
}

// HideRight hides the right panel contents and clears the table selection.
// The panel widget itself stays in the splitter so the layout doesn't shift.
func (ts *tableScreen) HideRight() {
	if ts.rightPanelInner != nil {
		ts.rightPanelInner.Hide()
	}
	if ts.RightPanel != nil {
		setWidgetRole(ts.RightPanel, "")
		ts.RightPanel.Style().Unpolish(ts.RightPanel)
		ts.RightPanel.Style().Polish(ts.RightPanel)
		ts.RightPanel.Update()
	}
	ts.TableView.ClearSelection()
}

// SelectedSourceRow returns the source-model row of the current selection,
// or -1 if nothing is selected.
func (ts *tableScreen) SelectedSourceRow() int {
	idx := ts.TableView.QAbstractItemView.CurrentIndex()
	if !idx.IsValid() {
		return -1
	}
	return ts.Proxy.MapToSource(idx).Row()
}

// refreshFilterHeaders checks each registered filter list and highlights
// columns where a filter is active (not all items checked).
func (ts *tableScreen) refreshFilterHeaders() {
	for col, list := range ts.filterLists {
		item := ts.SrcModel.HorizontalHeaderItem(col)
		if item == nil {
			continue
		}
		if isFilterActive(list) {
			item.SetForeground(qt.NewQBrush3(qt.NewQColor6("#e67e22")))
		} else {
			item.SetForeground(qt.NewQBrush3(qt.NewQColor6("#000000")))
		}
	}
}

// isFilterActive returns true when the filter list has at least one item
// unchecked, meaning the user has narrowed the view.
func isFilterActive(list *qt.QListWidget) bool {
	if list == nil || list.Count() == 0 {
		return false
	}
	count := 0
	for i := 0; i < list.Count(); i++ {
		if list.Item(i).CheckState() != qt.Checked {
			count++
		}
	}
	// none or all items unchecked → no filter
	return (count != 0) && (count != list.Count())
}

// Sort updates sort state, the header indicator, and the proxy.
// Used by filter-popup sort buttons that live outside the generic widget.
func (ts *tableScreen) Sort(col int, order qt.SortOrder) {
	ts.sortCol = col
	ts.sortOrder = order
	ts.TableView.HorizontalHeader().SetSortIndicator(col, order)
	ts.Proxy.Sort(col, order)
}

// ShowPopup positions popup under the header of col and shows it.
func (ts *tableScreen) ShowPopup(col int, popup *qt.QWidget) {
	hdr := ts.TableView.HorizontalHeader()
	hdrWidget := hdr.QAbstractItemView.QAbstractScrollArea.QFrame.QWidget
	x := hdr.SectionViewportPosition(col)
	y := hdrWidget.Height()
	globalPos := hdrWidget.MapToGlobalWithQPoint(qt.NewQPoint2(x, y))
	popup.AdjustSize()
	popup.MoveWithQPoint(globalPos)
	popup.Show()
}

// newTableScreen builds the screen widget according to cfg.
func newTableScreen(cfg tableScreenCfg) *tableScreen {
	ts := &tableScreen{
		sortCol:   cfg.InitialSortCol,
		sortOrder: qt.AscendingOrder,
	}

	// ── Outer widget ──────────────────────────────────────────────────────────
	ts.Widget = qt.NewQWidget2()
	root := qt.NewQVBoxLayout(ts.Widget)
	root.SetContentsMargins(24, 24, 24, 24)
	root.SetSpacing(8)

	titleLbl := qt.NewQLabel3(cfg.ScreenTitle)
	setWidgetRole(titleLbl.QFrame.QWidget, "screen-title")
	root.AddWidget(titleLbl.QWidget)

	// ── Model + proxy ─────────────────────────────────────────────────────────
	ts.SrcModel = qt.NewQStandardItemModel2(0, len(cfg.Headers))
	ts.SrcModel.SetHorizontalHeaderLabels(cfg.Headers)

	ts.Proxy = qt.NewQSortFilterProxyModel()
	ts.Proxy.SetSourceModel(ts.SrcModel.QAbstractItemModel)

	searchCols := cfg.SearchCols
	if len(searchCols) == 0 {
		searchCols = []int{0}
	}

	ts.Proxy.OnFilterAcceptsRow(func(_ func(int, *qt.QModelIndex) bool, srcRow int, _ *qt.QModelIndex) bool {
		if q := foldAccents(strings.TrimSpace(ts.SearchEdit.Text())); q != "" {
			matched := false
			for _, col := range searchCols {
				if strings.Contains(foldAccents(ts.SrcModel.Item2(srcRow, col).Text()), q) {
					matched = true
					break
				}
			}
			if !matched {
				return false
			}
		}
		if cfg.ExtraFilterAccepts != nil {
			return cfg.ExtraFilterAccepts(ts.SrcModel, srcRow)
		}
		return true
	})

	ts.Proxy.OnLessThan(func(_ func(*qt.QModelIndex, *qt.QModelIndex) bool, left, right *qt.QModelIndex) bool {
		if cfg.LessThanOverride != nil {
			return cfg.LessThanOverride(ts.SrcModel, left, right)
		}
		col := left.Column()
		lText := foldAccents(ts.SrcModel.Item2(left.Row(), col).Text())
		rText := foldAccents(ts.SrcModel.Item2(right.Row(), col).Text())
		if lText != rText {
			return lText < rText
		}
		if col != 0 {
			return foldAccents(ts.SrcModel.Item2(left.Row(), 0).Text()) <
				foldAccents(ts.SrcModel.Item2(right.Row(), 0).Text())
		}
		return false
	})

	// ── Search edit ───────────────────────────────────────────────────────────
	ph := cfg.SearchPlaceholder
	if ph == "" {
		ph = "Rechercher…"
	}
	ts.SearchEdit = qt.NewQLineEdit2()
	ts.SearchEdit.SetPlaceholderText(ph)
	ts.SearchEdit.SetClearButtonEnabled(true)
	setWidgetRole(ts.SearchEdit.QWidget, "search")
	ts.SearchEdit.OnTextChanged(func(_ string) { ts.Proxy.InvalidateFilter() })

	// ── Table view ────────────────────────────────────────────────────────────
	ts.TableView = qt.NewQTableView2()
	ts.TableView.SetModel(ts.Proxy.QAbstractProxyModel.QAbstractItemModel)
	ts.TableView.SetSortingEnabled(false)
	ts.TableView.HorizontalHeader().SetSectionResizeMode(qt.QHeaderView__Stretch)
	ts.TableView.HorizontalHeader().SetSortIndicatorShown(true)
	ts.TableView.HorizontalHeader().SetSortIndicator(ts.sortCol, ts.sortOrder)
	ts.TableView.SetSelectionBehavior(qt.QAbstractItemView__SelectRows)
	ts.TableView.SetSelectionMode(qt.QAbstractItemView__SingleSelection)
	ts.TableView.SetEditTriggers(qt.QAbstractItemView__NoEditTriggers)
	ts.TableView.SetAlternatingRowColors(true)
	ts.TableView.VerticalHeader().SetVisible(false)

	ts.Proxy.Sort(ts.sortCol, ts.sortOrder)

	// ── Header click ──────────────────────────────────────────────────────────
	filterColSet := make(map[int]bool, len(cfg.FilterCols))
	for _, c := range cfg.FilterCols {
		filterColSet[c] = true
	}
	ts.TableView.HorizontalHeader().OnSectionClicked(func(col int) {
		if filterColSet[col] && cfg.OnFilterCol != nil {
			cfg.OnFilterCol(col)
			return
		}
		if ts.sortCol == col && ts.sortOrder == qt.AscendingOrder {
			ts.sortOrder = qt.DescendingOrder
		} else {
			ts.sortCol = col
			ts.sortOrder = qt.AscendingOrder
		}
		ts.TableView.HorizontalHeader().SetSortIndicator(ts.sortCol, ts.sortOrder)
		ts.Proxy.Sort(ts.sortCol, ts.sortOrder)
	})

	// ── Row interaction ───────────────────────────────────────────────────────
	sm := ts.TableView.SelectionModel()
	sm.OnSelectionChanged(func(_, _ *qt.QItemSelection) {
		rows := ts.TableView.SelectionModel().SelectedRows()
		selected := len(rows) == 1
		ts.DelBtn.SetEnabled(selected)
		if ts.CopyBtn != nil {
			ts.CopyBtn.SetEnabled(selected)
		}
		// Hide the right-panel content without clearing the table selection;
		// the OnSelectionChange callback may re-show it for the new row.
		if ts.rightPanelInner != nil {
			ts.rightPanelInner.Hide()
		}
		if ts.RightPanel != nil {
			setWidgetRole(ts.RightPanel, "")
			ts.RightPanel.Style().Unpolish(ts.RightPanel)
			ts.RightPanel.Style().Polish(ts.RightPanel)
			ts.RightPanel.Update()
		}
		if cfg.OnSelectionChange != nil {
			if selected {
				cfg.OnSelectionChange(ts.Proxy.MapToSource(&rows[0]).Row())
			} else {
				cfg.OnSelectionChange(-1)
			}
		}
	})

	// ── Left panel layout ─────────────────────────────────────────────────────
	leftWidget := qt.NewQWidget2()
	setWidgetRole(leftWidget, "table-panel")
	ll := qt.NewQVBoxLayout(leftWidget)
	ll.SetContentsMargins(8, 8, 8, 8)
	ll.SetSpacing(6)
	if cfg.ExtraToolbar != nil {
		ll.AddWidget(cfg.ExtraToolbar)
	}
	ll.AddWidget(ts.SearchEdit.QWidget)
	ll.AddWidget2(ts.TableView.QAbstractItemView.QAbstractScrollArea.QFrame.QWidget, 1)

	ts.AddBtn = newStdBtn("add")
	if cfg.OnAdd != nil {
		ts.AddBtn.OnClicked(func() { cfg.OnAdd() })
	}
	ts.DelBtn = newStdBtn("delete")
	ts.DelBtn.SetEnabled(false)
	if cfg.OnDelete != nil {
		ts.DelBtn.OnClicked(func() { cfg.OnDelete() })
	}
	btnRow := qt.NewQHBoxLayout2()
	btnRow.AddWidget(ts.AddBtn.QAbstractButton.QWidget)
	btnRow.AddWidget(ts.DelBtn.QAbstractButton.QWidget)
	if cfg.OnCopy != nil {
		ts.CopyBtn = newStdBtn("copy")
		ts.CopyBtn.SetEnabled(false)
		ts.CopyBtn.OnClicked(func() { cfg.OnCopy() })
		btnRow.AddWidget(ts.CopyBtn.QAbstractButton.QWidget)
	}
	for _, btn := range cfg.ExtraActionBtns {
		btnRow.AddWidget(btn.QAbstractButton.QWidget)
	}
	btnRow.AddWidget2(qt.NewQWidget2(), 1)
	ll.AddLayout(btnRow.QBoxLayout.QLayout)

	// ── Splitter or plain layout ───────────────────────────────────────────────
	if cfg.FormContent == nil {
		root.AddWidget2(leftWidget, 1)
		return ts
	}

	splitter := qt.NewQSplitter3(qt.Horizontal)
	splitter.SetChildrenCollapsible(false)
	splitter.AddWidget(leftWidget)
	splitter.SetStretchFactor(0, 1)
	root.AddWidget2(splitter.QFrame.QWidget, 1)

	// ── Right panel ───────────────────────────────────────────────────────────
	minW := cfg.RightPanelMinWidth
	if minW == 0 {
		minW = 550
	}
	ts.RightPanel = qt.NewQWidget2()
	ts.RightPanel.SetMinimumWidth(minW)

	ts.rightPanelInner = qt.NewQScrollArea2()
	ts.rightPanelInner.SetWidgetResizable(true)
	ts.rightPanelInner.SetFrameShape(qt.QFrame__NoFrame)
	scrollContent := qt.NewQWidget2()
	bodyLayout := qt.NewQVBoxLayout(scrollContent)
	bodyLayout.SetContentsMargins(16, 16, 16, 16)
	bodyLayout.SetSpacing(10)
	ts.rightPanelInner.SetWidget(scrollContent)
	rpLayout := qt.NewQVBoxLayout(ts.RightPanel)
	rpLayout.SetContentsMargins(0, 0, 0, 0)
	rpLayout.SetSpacing(0)
	rpLayout.AddWidget(ts.rightPanelInner.QAbstractScrollArea.QFrame.QWidget)

	bodyLayout.AddWidget(cfg.FormContent)
	bodyLayout.AddWidget2(qt.NewQWidget2(), 1) // spacer

	ts.SaveBtn = newStdBtn("save")
	ts.SaveBtn.SetEnabled(false)
	ts.SaveBtn.SetFocusPolicy(qt.StrongFocus)
	ts.SaveBtn.SetAutoDefault(true)
	ts.SaveBtn.SetDefault(true)
	if cfg.OnSave != nil {
		ts.SaveBtn.OnClicked(func() { cfg.OnSave() })
	}
	ts.CancelBtn = newStdBtn("cancel")
	if cfg.OnCancel != nil {
		ts.CancelBtn.OnClicked(func() { cfg.OnCancel() })
	} else {
		ts.CancelBtn.OnClicked(func() { ts.HideRight() })
	}
	panelBtnRow := qt.NewQHBoxLayout2()
	panelBtnRow.AddWidget(ts.SaveBtn.QAbstractButton.QWidget)
	panelBtnRow.AddWidget(ts.CancelBtn.QAbstractButton.QWidget)
	panelBtnRow.AddWidget2(qt.NewQWidget2(), 1)
	bodyLayout.AddLayout(panelBtnRow.QBoxLayout.QLayout)

	splitter.AddWidget(ts.RightPanel)
	splitter.SetStretchFactor(1, 0)
	ts.ShowRight()

	return ts
}
