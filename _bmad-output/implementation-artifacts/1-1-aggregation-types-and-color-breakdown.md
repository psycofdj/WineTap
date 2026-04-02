# Story 1.1: Aggregation Types and Color Breakdown

Status: done

## Story

As a developer,
I want pure aggregation functions that compute bottle breakdowns by color,
so that the dashboard can display color distribution data from raw bottle lists.

## Acceptance Criteria

1. `aggregate.go` defines `BreakdownEntry` and `BreakdownResult` types with no miqt/Qt imports
2. `AggregateByColor` returns a `BreakdownResult` with one entry per wine color (rouge, blanc, rosé, effervescent, autre) with correct counts and hex color strings
3. Bottles with null/empty color are counted as "autre"
4. `Total` field equals the sum of all entry counts
5. Zero-count colors are included in results (all 5 colors always present)
6. Empty bottle list returns `BreakdownResult` with `Total: 0` and all five color entries at `Count: 0`
7. `maxDesignationSlices` constant and `designationPalette` are defined (used by Story 1.2)
8. All aggregation code is pure Go — no miqt, Qt, or color package imports

## Tasks / Subtasks

- [x] Task 1: Create widget package and define types (AC: #1, #7, #8)
  - [x] Create `internal/manager/widget/` directory
  - [x] Create `aggregate.go` with package declaration `package widget`
  - [x] Define `BreakdownEntry` struct: `Label string`, `Identifier string`, `Count int`, `Color string`
  - [x] Define `BreakdownResult` struct: `Entries []BreakdownEntry`, `Total int`
  - [x] Define `const maxDesignationSlices = 8`
  - [x] Define `var designationPalette = []string{"#7eb26d", "#eab839", "#6ed0e0", "#ef843c", "#e24d42", "#1f78c4", "#ba43a9", "#705da0"}`
  - [x] Define wine color hex map: `var wineColorHex = map[v1.Color]string{...}` mapping each Color enum to its hex value
  - [x] Verify: only imports are `winetap/gen/winetap/v1` and standard library — no miqt/Qt imports

- [x] Task 2: Implement AggregateByColor function (AC: #2, #3, #4, #5, #6)
  - [x] Implement `func AggregateByColor(bottles []*v1.Bottle) BreakdownResult`
  - [x] Iterate bottles, read color from `bottle.GetCuvee().GetColor()` — use `Color_COLOR_AUTRE` if cuvee is nil or color is `Color_COLOR_UNSPECIFIED`
  - [x] Count bottles per color enum value
  - [x] Build entries for ALL 5 colors in fixed order: rouge, blanc, rosé, effervescent, autre
  - [x] Each entry: `Label` = French display name (e.g., "Rouge"), `Identifier` = proto enum name lowercase (e.g., "rouge"), `Count` = count, `Color` = hex from wineColorHex map
  - [x] Set `Total` = sum of all counts
  - [x] Zero-count colors get `Count: 0` entries (always 5 entries returned)

- [x] Task 3: Write unit tests (AC: #2, #3, #5, #6)
  - [x] Create `aggregate_test.go` in `internal/manager/widget/`
  - [x] Test: empty bottle list → Total=0, all 5 entries with Count=0
  - [x] Test: single rouge bottle → Rouge=1, others=0, Total=1
  - [x] Test: mixed colors → correct counts per color
  - [x] Test: bottle with nil cuvee → counted as "autre"
  - [x] Test: bottle with `Color_COLOR_UNSPECIFIED` → counted as "autre"
  - [x] Test: all bottles same color → single non-zero entry, Total correct
  - [x] Run tests: `go test ./internal/manager/widget/...`

### Review Findings

- [x] [Review][Patch] Total computed from len(bottles) instead of sum of entry counts — fixed: Total now computed as sum of entry counts [aggregate.go:73]
- [x] [Review][Patch] Unknown future Color enum values silently dropped — fixed: unknown colors now fall through to "autre" via wineColorHex map lookup [aggregate.go:66-69]

## Dev Notes

### Architecture Requirements

**Package location:** `internal/manager/widget/` — new package, one-way dependency (screen imports widget, never reverse).

**Pure Go constraint:** `aggregate.go` must have ZERO miqt/Qt imports. Only allowed imports:
- `winetap/gen/winetap/v1` (for proto Bottle/Cuvee/Color types)
- Standard library (`sort`, `strings`, etc. if needed)

**Widget data lifecycle:** This story creates the types that all widgets will consume. Widgets (Stories 1.3-1.5) will call `SetData(BreakdownResult)` — this pattern is established here.

### Proto Type Reference

**Accessing color from a Bottle:**
```go
// bottle.GetCuvee() returns *v1.Cuvee (may be nil)
// cuvee.GetColor() returns v1.Color (int32 enum)
color := bottle.GetCuvee().GetColor()
// Safe: GetCuvee() returns zero-value Cuvee if nil, GetColor() returns COLOR_UNSPECIFIED (0)
```

**Color enum values (from proto):**
```go
v1.Color_COLOR_UNSPECIFIED  // 0 — treat as "autre"
v1.Color_COLOR_ROUGE        // 1
v1.Color_COLOR_BLANC        // 2
v1.Color_COLOR_ROSE         // 3
v1.Color_COLOR_EFFERVESCENT // 4
v1.Color_COLOR_AUTRE        // 5
```

**Accessing designation from a Bottle:**
```go
// Used in Story 1.2, but relevant context:
designation := bottle.GetCuvee().GetDesignationName() // string, may be ""
```

### Wine Color Hex Values (from UX spec)

| Color | Hex | Label |
|---|---|---|
| Rouge | `#c0392b` | "Rouge" |
| Blanc | `#f1c40f` | "Blanc" |
| Rosé | `#e8a0bf` | "Rosé" |
| Effervescent | `#3498db` | "Effervescent" |
| Autre | `#95a5a6` | "Autre" |

### Testing Standards

- Tests co-located: `internal/manager/widget/aggregate_test.go`
- Use standard `testing` package
- Create helper to build test bottles: `func makeBottle(color v1.Color, designation string) *v1.Bottle`
- Run with: `go test ./internal/manager/widget/...`

### Project Structure Notes

- This is the FIRST file in a NEW package — `internal/manager/widget/`
- Follow existing Go conventions: `snake_case.go` files, `PascalCase` exported types
- No `init()` functions, no package-level state beyond constants and the palette slice

### References

- [Source: _bmad-output/planning-artifacts/architecture.md#Aggregation Types & Constants]
- [Source: _bmad-output/planning-artifacts/architecture.md#Null & Edge Case Handling Rules]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#Visual Design Foundation - Color System]
- [Source: proto/winetap/v1/winetap.proto — Color enum, Bottle message, Cuvee message]
- [Source: _bmad-output/planning-artifacts/epics.md#Story 1.1]

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (1M context)

### Debug Log References

### Completion Notes List

- Created `internal/manager/widget/` package — first file in new package
- Defined BreakdownEntry, BreakdownResult types, maxDesignationSlices constant, designationPalette
- Defined colorOrder, wineColorHex, wineColorLabel, wineColorIdentifier maps for color enum → display data
- Implemented AggregateByColor: always returns 5 entries in fixed order, nil cuvee/unspecified → autre
- 7 unit tests: empty list, single color, mixed, nil cuvee, unspecified color, all same color, field values
- All tests pass, full regression suite passes (0 failures)
- Pure Go — only import is `winetap/gen/winetap/v1`

### Change Log

- 2026-03-30: Story 1.1 implemented — aggregation types and AggregateByColor function with full test coverage

### File List

- `internal/manager/widget/aggregate.go` (NEW)
- `internal/manager/widget/aggregate_test.go` (NEW)
