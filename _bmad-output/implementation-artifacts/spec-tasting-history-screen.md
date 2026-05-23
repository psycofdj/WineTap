---
title: 'Tasting history screen ("Mes dégustations") with editable comments'
type: 'feature'
created: '2026-05-23'
status: 'done'
baseline_commit: 'c394cf4ed5d7e6a4bc27adcc2671633ea502a614'
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Once a bottle is consumed, there is no way to revisit it in the app — users cannot see what they have drunk, when, or revisit/refine the tasting note they left at consume time.

**Approach:** Add a third button "Mes dégustations" to the consume screen's idle state that opens a new screen listing all consumed bottles (ordered by `consumed_at` desc) as cards. Tapping a card opens a detail view with an editable comment textarea that reads/writes `Bottles.description`.

## Boundaries & Constraints

**Always:**
- Reuse the existing `Bottles.description` column for comments (no schema migration).
- French UI strings live in [strings.dart](mobile/lib/l10n/strings.dart); never inline French text in widgets.
- Read consumed bottles via a new paginated `AppDatabase` query that filters `consumedAt IS NOT NULL`, orders `consumedAt DESC`, and accepts `limit` + `offset` — do not filter or slice in Dart over the full inventory.
- Page size = 20. First load fetches 20 rows; further pages are appended as the user scrolls near the bottom (infinite scroll). Stop requesting when a page returns fewer than 20 rows.
- Comment save trims whitespace; an empty/whitespace-only input clears the comment (writes empty string), matching the spirit of `resetWithComment` which only writes when non-empty but tolerating clearing here since the user is explicitly editing.
- Date display uses the device locale, format `dd/MM/yyyy HH:mm` (parse the stored ISO-8601 UTC string, convert to local).

**Ask First:**
- Anything that requires adding a new package to `pubspec.yaml` (e.g. `intl`) — propose first.
- Any schema migration.
- Renaming or repurposing `Bottles.description`.

**Never:**
- Do not add a new column for comments.
- Do not change the existing consume flow comment behaviour ([scan_provider.dart:137](mobile/lib/providers/scan_provider.dart#L137)).
- Do not add search, filtering, or sort controls in this iteration.
- Do not pre-fetch all rows then slice client-side; pagination must hit the DB per page.
- Do not expose un-consume / delete / un-do actions.
- Do not add NFC interactions on this screen.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| List, no consumed bottles | `Bottles` has zero rows with `consumedAt != NULL` | Empty-state message centered, e.g. "Aucune bouteille consommée" | N/A |
| First page load | N ≥ 20 consumed rows | First 20 rendered in `consumedAt DESC` order; each card shows designation, domain, cuvée, millésime, formatted consumption date | N/A |
| Scroll near bottom, more rows exist | User scrolls within `pageSize` items of the end; more pages remain | Next page (limit 20, offset = current count) is fetched and appended; small bottom progress indicator while loading | DB error → snackbar `S.databaseError`; existing items remain; retry on next scroll trigger |
| Scroll to end, no more rows | Last fetched page returned < 20 rows | No further requests issued; no spinner at the bottom | N/A |
| Concurrent scroll triggers | Multiple scroll events during one fetch | Only one in-flight page request at a time (guard flag) | N/A |
| Open detail, no prior comment | Bottle row with `description = ''` | Detail screen shows empty textarea + bottle summary + Save button (disabled until edited) | N/A |
| Open detail, existing comment | Bottle row with `description = 'lovely with steak'` | Textarea pre-filled with that text | N/A |
| Save comment | User edits textarea, taps Save | `Bottles.description` updated via existing `updateBottleFields`; navigator pops; list refreshes to reflect new state | DB error → snackbar `S.databaseError`, screen stays open |
| Bottle with malformed `consumedAt` | ISO parse fails | Card still renders, date cell shows raw string fallback (no crash) | Caught locally |

</frozen-after-approval>

## Code Map

- [mobile/lib/main.dart](mobile/lib/main.dart) -- entry; defines `HomeScreen` wrapping `ConsumeScreen` — no changes expected.
- [mobile/lib/screens/consume_screen.dart](mobile/lib/screens/consume_screen.dart) -- idle state renders two buttons; add a third `OutlinedButton.icon` pointing to the new screen.
- [mobile/lib/screens/identify_screen.dart](mobile/lib/screens/identify_screen.dart) -- template for a pushed screen with appbar + body switch — pattern to mirror.
- [mobile/lib/widgets/bottle_details_card.dart](mobile/lib/widgets/bottle_details_card.dart) -- existing "label : value" presentation widget — reuse in detail view.
- [mobile/lib/server/database.dart:369](mobile/lib/server/database.dart#L369) -- `listBottles({includeConsumed})` is unsuitable (orders by domain/cuvée, includes in-stock); add a dedicated paginated `listConsumedBottles({limit, offset})`.
- [mobile/lib/server/database.dart:422](mobile/lib/server/database.dart#L422) -- `updateBottleFields(id, fields)` is the existing write path for comment edits.
- [mobile/lib/l10n/strings.dart](mobile/lib/l10n/strings.dart) -- add new French strings.

## Tasks & Acceptance

**Execution:**
- [x] `mobile/lib/server/database.dart` -- add `Future<List<BottleWithCuvee>> listConsumedBottles({int limit = 20, int offset = 0})` that joins like `_bottleWithCuveeQuery`, filters `bottles.consumedAt.isNotNull()`, orders `OrderingTerm.desc(bottles.consumedAt)`, applies `..limit(limit, offset: offset)`. -- Single source of truth for the new screen's data, keeps ordering + paging in SQL.
- [x] `mobile/lib/l10n/strings.dart` -- add strings: `tastingHistoryButton = 'Mes dégustations'`, `tastingHistoryTitle = 'Dégustations'`, `noTastings = 'Aucune bouteille consommée'`, `labelConsumedAt = 'Consommée le'`, `save = 'Enregistrer'`, `commentHint = 'Notes de dégustation'`. -- Centralized i18n.
- [x] `mobile/lib/screens/tasting_history_screen.dart` -- new `StatefulWidget` managing: `List<BottleWithCuvee> _items`, `bool _loading`, `bool _hasMore`, a `ScrollController`. `initState` loads page 0 (offset 0, limit 20). Scroll listener triggers `_loadMore()` when `position.pixels >= maxScrollExtent - 400` and `!_loading && _hasMore`; `_loadMore` sets `_loading=true`, fetches `listConsumedBottles(limit: 20, offset: _items.length)`, appends, sets `_hasMore = page.length == 20`. Renders empty state when `_items.isEmpty && !_loading`; otherwise `ListView.builder` of `_ConsumedBottleCard` items + a trailing footer item that is either a small `CircularProgressIndicator` (when `_loading && _hasMore`) or `SizedBox.shrink()`. Each card shows designation, domain, cuvée, millésime, formatted date; `onTap` pushes `TastingDetailScreen` and on pop with `true`, resets the list and re-fetches page 0 to reflect the edit. -- Paginated infinite-scroll list view. -- Page size is a single named const at top of the file (e.g. `const _pageSize = 20`).
- [x] `mobile/lib/screens/tasting_detail_screen.dart` -- new `StatefulWidget` taking a `BottleWithCuvee`; uses `BottleDetailsCard` for the summary, a `TextField` (multiline, ~5 lines) bound to a controller initialised from `bottle.bottle.description`, and a `FilledButton` "Enregistrer" that calls `db.updateBottleFields(id, BottlesCompanion(description: Value(trimmed)))` then `Navigator.pop(context, true)` so the list can refresh. Save button disabled when text equals initial value. -- Edit comment in isolation.
- [x] `mobile/lib/screens/consume_screen.dart` -- in `_buildIdle`, add a third `OutlinedButton.icon` below the Identify button with `Icons.menu_book` (or `Icons.history_edu`) and label `S.tastingHistoryButton`, navigating via `MaterialPageRoute` to `TastingHistoryScreen`. -- Surface the feature.
- [x] `mobile/test/server/database_test.dart` -- add tests for `listConsumedBottles`: returns empty when none; returns only consumed rows; returns rows in `consumedAt DESC` order; respects `limit` and `offset` (seed >20 rows, assert page 0 has 20, page 1 returns the remainder). -- Cover the new query.
- [x] `mobile/test/screens/tasting_history_screen_test.dart` (new) -- widget tests for: empty state; first-page render shows 20 cards when 25 rows exist; scrolling to the end appends the remaining 5 cards (uses `AppDatabase.forTesting` with in-memory drift, mirroring existing test patterns). -- Cover the screen.

**Acceptance Criteria:**
- Given the app is launched and the user is on the home (consume) screen idle state, when they look at the body, then a third button labeled "Mes dégustations" appears below "Identifier une bouteille".
- Given there are no consumed bottles, when the user taps "Mes dégustations", then the screen shows the empty-state text and no cards.
- Given two bottles were consumed at different times, when the screen loads, then the most recently consumed appears first.
- Given more than 20 consumed bottles exist, when the screen first opens, then exactly 20 cards are rendered and the rest load as the user scrolls near the bottom.
- Given the last fetched page returned fewer than 20 rows, when the user scrolls further, then no additional DB query is fired and no spinner is shown at the bottom.
- Given a bottle with an existing comment, when the user taps its card and saves an edited comment, then the database is updated and the list (after pop) reflects the change on next open.
- Given the user opens the detail screen, when they make no edits, then the Save button is disabled.

## Spec Change Log

### 2026-05-23 — Patch findings applied post-review (no spec/intent change)

Source: step-04 review (auditor: ACCEPT; blind hunter + edge case hunter findings).

Auto-fixed patches (no spec re-derivation needed):
- TastingHistoryScreen: set `_loading=true` synchronously before the async `setState` to close a same-frame re-entrancy window when initState + scroll-listener fire together.
- TastingHistoryScreen: added a `_generation` token so any in-flight `_loadMore` whose generation no longer matches discards its result; this also collapses `_refresh` into a single synchronous reset (no empty-state flash).
- TastingHistoryScreen: `_openDetail` guarded with `_opening` flag to prevent double-tap from pushing two detail routes (and triggering two refreshes).
- TastingHistoryScreen `_ConsumedBottleCard`: when `designationName` is empty the title falls back to `cuvée name`; the subtitle now drops the duplicated cuvée and shows just the vintage.
- TastingDetailScreen: dirty check now compares `text.trim() != _initialTrimmed` so trailing-whitespace edits don't trigger a save (and an unnecessary parent refresh).
- TastingDetailScreen: replaced per-keystroke `setState(() {})` with a `ValueListenableBuilder` scoped to the save button — typing no longer rebuilds the entire screen (including `BottleDetailsCard`).

Deferred (real but out of this story's scope) — moved to `deferred-work.md` under "spec-tasting-history-screen": offset-vs-keyset pagination instability across concurrent mutations; missing `PopScope` unsaved-changes guard; missing `maxLength` on comment field; `BottleDetailsCard` rendering `drinkBefore` for consumed bottles; locale-agnostic date formatting.

KEEP: page size constant at top of file; single in-flight load guard; existing `_pageSize == page.length` stop condition (matches the spec's "stop when a page returns fewer than 20 rows"); reuse of `BottleDetailsCard` and `updateBottleFields`.

## Verification

**Commands:**
- `cd mobile && flutter analyze` -- expected: no new warnings/errors.
- `cd mobile && flutter test test/server/database_test.dart test/screens/tasting_history_screen_test.dart` -- expected: all green.
- `cd mobile && flutter test` -- expected: full suite green.

**Manual checks:**
- Run the app, consume a bottle (or seed via existing seed), tap "Mes dégustations", verify card content and ordering.
- Tap a card, edit the textarea, save, reopen, verify persistence.

## Suggested Review Order

**Entry point & user-visible surface**

- New third button wired into the consume screen idle state — surfaces the feature.
  [`consume_screen.dart:123`](../../mobile/lib/screens/consume_screen.dart#L123)

- Centralized French strings for button, screen title, empty state, save action.
  [`strings.dart:67`](../../mobile/lib/l10n/strings.dart#L67)

**Data layer — paginated query**

- New `listConsumedBottles({limit, offset})` — filter, DESC order, limit/offset all in SQL.
  [`database.dart:382`](../../mobile/lib/server/database.dart#L382)

**History screen — pagination state machine**

- `_loadMore` sets `_loading` synchronously to close same-frame re-entrancy.
  [`tasting_history_screen.dart:51`](../../mobile/lib/screens/tasting_history_screen.dart#L51)

- Scroll listener fires `_loadMore` only when not loading and more rows remain.
  [`tasting_history_screen.dart:42`](../../mobile/lib/screens/tasting_history_screen.dart#L42)

- `_refresh` bumps a generation token so in-flight loads discard their results.
  [`tasting_history_screen.dart:79`](../../mobile/lib/screens/tasting_history_screen.dart#L79)

- `_openDetail` guarded against double-tap, triggers refresh on `true` pop.
  [`tasting_history_screen.dart:88`](../../mobile/lib/screens/tasting_history_screen.dart#L88)

- Card layout falls back cleanly when designation is missing (no duplicated cuvée).
  [`tasting_history_screen.dart:153`](../../mobile/lib/screens/tasting_history_screen.dart#L153)

**Detail screen — comment edit**

- Dirty check compares trimmed text so whitespace-only edits don't enable Save.
  [`tasting_detail_screen.dart:40`](../../mobile/lib/screens/tasting_detail_screen.dart#L40)

- `_save` writes trimmed value via `updateBottleFields`, pops with `true`, snackbar on error.
  [`tasting_detail_screen.dart:42`](../../mobile/lib/screens/tasting_detail_screen.dart#L42)

- `ValueListenableBuilder` scopes per-keystroke rebuilds to just the save button.
  [`tasting_detail_screen.dart:88`](../../mobile/lib/screens/tasting_detail_screen.dart#L88)

**Tests**

- DB query: empty, consumed-only, DESC order, limit/offset boundary at 25 rows.
  [`database_test.dart`](../../mobile/test/server/database_test.dart)

- Screen: empty state, first-page-of-20, scroll-to-load remainder.
  [`tasting_history_screen_test.dart`](../../mobile/test/screens/tasting_history_screen_test.dart)
