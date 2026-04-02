# Story 1.2: Designation Breakdown Aggregation

Status: review

## Story

As a developer,
I want pure aggregation functions that compute bottle breakdowns by designation,
so that the dashboard can display appellation distribution data.

## Acceptance Criteria

1. `AggregateByDesignation` returns a `BreakdownResult` with entries sorted by count descending
2. Each entry has a color from the `designationPalette` cycling palette
3. Bottles with null/empty designation are grouped under "Sans appellation"
4. More than 8 distinct designations: top 8 by count returned individually, remaining summed into "Autres" entry with color `#95a5a6`
5. 8 or fewer distinct designations: all returned individually, no "Autres" grouping
6. `Total` equals sum of all entry counts (learned from Story 1.1 code review)
7. "Autres" entry `Identifier` is empty string (non-clickable by design per architecture)
8. Unit tests cover: zero bottles, null designation, exactly 8, 9+ designations, single designation, all same designation

## Tasks / Subtasks

- [x] Task 1: Implement AggregateByDesignation function (AC: #1, #2, #3, #4, #5, #6, #7)
  - [x] Add `func AggregateByDesignation(bottles []*v1.Bottle) BreakdownResult` to `aggregate.go`
  - [x] Iterate bottles, read designation from `bottle.GetCuvee().GetDesignationName()` — use "Sans appellation" if empty string or nil cuvee
  - [x] Count bottles per designation string
  - [x] Sort designations by count descending
  - [x] If ≤8 distinct designations: build entries for all, assign colors from `designationPalette` by index
  - [x] If >8 distinct designations: build entries for top 8, sum remaining into "Autres" entry with color `#95a5a6` and empty `Identifier`
  - [x] Compute `Total` as sum of entry counts (NOT `len(bottles)` — lesson from Story 1.1 review)
  - [x] Add `import "sort"` to aggregate.go

- [x] Task 2: Write unit tests (AC: #8)
  - [x] Add tests to existing `aggregate_test.go` (reuse `makeBottle` helper)
  - [x] Test: empty bottle list → Total=0, empty entries
  - [x] Test: single designation → 1 entry, correct count and palette color
  - [x] Test: bottles with empty designation → grouped as "Sans appellation"
  - [x] Test: bottles with nil cuvee → grouped as "Sans appellation"
  - [x] Test: exactly 8 distinct designations → 8 entries, no "Autres", all palette colors used
  - [x] Test: 9+ distinct designations → 8 individual + 1 "Autres", "Autres" count = sum of remaining, "Autres" color = #95a5a6, "Autres" Identifier = ""
  - [x] Test: all bottles same designation → 1 entry, Total correct
  - [x] Test: entries sorted by count descending
  - [x] Run tests: `go test ./internal/manager/widget/...`

## Dev Notes

### Previous Story Intelligence (from Story 1.1)

**CRITICAL learnings from code review:**
1. **Total must be sum of entry counts, NOT `len(bottles)`** — Story 1.1 was patched for this. Apply same pattern: accumulate `total += cnt` while building entries.
2. **Validate against known values, not just zero-check** — Story 1.1 was patched to check `wineColorHex` map for known colors. For designations, the equivalent is checking for empty string (no enum to validate).

**Established patterns in aggregate.go:**
- Function signature: `func AggregateByXxx(bottles []*v1.Bottle) BreakdownResult`
- Returns `BreakdownResult{Entries, Total}` where Total = sum of entry counts
- Proto getter chain: `bottle.GetCuvee().GetDesignationName()` — nil-safe, returns "" for nil cuvee

**Existing code to reuse:**
- `BreakdownEntry`, `BreakdownResult` types (defined in Story 1.1)
- `maxDesignationSlices = 8` constant (defined in Story 1.1)
- `designationPalette` slice with 8 hex colors (defined in Story 1.1)
- `makeBottle(color v1.Color, designation string)` test helper (in aggregate_test.go)

### Architecture Requirements

**File:** `internal/manager/widget/aggregate.go` — append to existing file (do NOT create a new file)
**Tests:** `internal/manager/widget/aggregate_test.go` — append to existing file
**Pure Go:** No miqt/Qt imports. Only `winetap/gen/winetap/v1`, `sort`, and standard library.

**"Autres" entry is non-clickable:** Per architecture validation, the synthetic "Autres" grouping has `Identifier: ""` (empty string). The dashboard screen will check for empty Identifier and skip click/hover callbacks. Do NOT use "autres" as the Identifier.

### Proto Type Reference

```go
// Accessing designation from a Bottle:
designation := bottle.GetCuvee().GetDesignationName() // string, may be ""
// Safe: GetCuvee() returns zero-value Cuvee if nil, GetDesignationName() returns ""
```

### Sorting Approach

```go
sort.Slice(entries, func(i, j int) bool {
    return entries[i].Count > entries[j].Count
})
```

### References

- [Source: _bmad-output/planning-artifacts/architecture.md#Aggregation Types & Constants]
- [Source: _bmad-output/planning-artifacts/architecture.md#Null & Edge Case Handling Rules]
- [Source: _bmad-output/planning-artifacts/architecture.md#Final Clarifications — "Autres" non-clickable]
- [Source: _bmad-output/implementation-artifacts/1-1-aggregation-types-and-color-breakdown.md#Review Findings]
- [Source: _bmad-output/planning-artifacts/epics.md#Story 1.2]

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (1M context)

### Debug Log References

### Completion Notes List

- Implemented AggregateByDesignation in existing aggregate.go — appended, not new file
- Empty designation / nil cuvee → "Sans appellation"
- Sort by count descending with alphabetical tie-break for stability
- ≤8 designations: all shown with cycling palette colors
- >8 designations: top 8 + "Autres" (Identifier="" for non-clickable, color=#95a5a6)
- Total computed as sum of entry counts (Story 1.1 lesson applied)
- 8 unit tests: empty, single, empty designation, nil cuvee, exactly 8, 9+, all same, sort order
- All 16 widget tests pass (8 color + 8 designation), full regression passes

### Change Log

- 2026-03-30: Story 1.2 implemented — AggregateByDesignation with top-N grouping and full test coverage

### File List

- `internal/manager/widget/aggregate.go` (MODIFIED — added AggregateByDesignation, added sort import)
- `internal/manager/widget/aggregate_test.go` (MODIFIED — added 8 designation tests)
