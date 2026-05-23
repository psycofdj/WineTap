---
title: 'Home-screen stock stats: count + color & region pie charts'
type: 'feature'
created: '2026-05-23'
status: 'done'
baseline_commit: 'd94036ee7293d30c828a675d377d1061d3bf4541'
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The home (idle state of ConsumeScreen) currently only shows three action buttons. The user has no at-a-glance view of what's actually in stock — how many bottles, what colors, what regions.

**Approach:** Below the existing action buttons on the idle state of [consume_screen.dart](mobile/lib/screens/consume_screen.dart), add a "Stock" panel showing (1) a large count of bottles in stock, (2) a pie chart of bottles by wine color, (3) a pie chart of bottles by region. Stats are computed from the local Drift DB. Use the `fl_chart` package for pies (approved separately). The panel reloads whenever the user returns to idle (i.e. after a consume completes), so the figures stay live.

## Boundaries & Constraints

**Always:**
- "In stock" = `bottles.consumedAt IS NULL`.
- Stats come from a single joined read over `bottles` + `cuvees` + `designations` — no N+1.
- Color `0` and empty/null region (including the sentinel `id=0` "(unassigned)" designation) bucket into "Inconnue" slices in their respective pies.
- Color labels reuse the canonical mapping from [bottle_details_card.dart](mobile/lib/widgets/bottle_details_card.dart) (1=Rouge, 2=Blanc, 3=Rosé, 4=Effervescent, 5=Autre).
- Panel renders only when `scan.state == ScanState.idle`.
- Panel reloads after each consume via a parent-supplied `revision: int` watched in `didUpdateWidget`.
- When `totalInStock == 0`, render `S.noBottlesInStock` and no charts.
- Color-pie slices use visually plausible tints (rouge ≈ deep red, blanc ≈ pale gold, rosé ≈ pink, effervescent ≈ soft gold, autre ≈ grey, inconnue ≈ neutral grey). Region pie cycles a deterministic palette keyed on sorted region name.
- All new UI strings go through [strings.dart](mobile/lib/l10n/strings.dart) — no literals in widgets.

**Ask First:**
- Replacing `fl_chart` with another chart lib.
- Changing the canonical color → label mapping.
- Adding caching/memoization beyond the per-mount fetch.

**Never:**
- Do not add the panel to ConsumeScreen states other than idle.
- Do not introduce a new database table or schema migration.
- Do not block the idle UI on the stats query — render the buttons immediately, show a `CircularProgressIndicator` of bounded size while stats load.
- Do not query in `build()` — fetch from `initState` / `didUpdateWidget` only.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Stock populated | ≥1 in-stock bottle across multiple colors/regions | Count text + 2 pies with legends rendered below buttons | N/A |
| Empty stock | bottles all consumed (or table empty) | "Aucune bouteille en stock" line, no charts | N/A |
| All same color / region | All in-stock bottles share one color or region | Single-slice pie (100%) with that label | N/A |
| Mixed unknowns | Some bottles have `color=0` or empty designation region | "Inconnue" slice appears alongside the known ones | N/A |
| Returning to idle after consume | User consumed a bottle, taps "Terminé" → idle | Stats reload; in-stock total has decremented by 1 | N/A |
| DB read failure | `getStockStats` throws | Inline error text "Erreur de base de données"; no crash; buttons still usable | Caught locally and logged via `dev.log` (name: `StockStatsPanel`) |

</frozen-after-approval>

## Code Map

- [mobile/lib/server/database.dart](mobile/lib/server/database.dart) -- add `getStockStats()` + `StockStats` value class.
- [mobile/lib/widgets/bottle_details_card.dart](mobile/lib/widgets/bottle_details_card.dart) -- canonical color → label mapping; expose `colorLabel(int)` publicly.
- [mobile/lib/widgets/stock_stats_panel.dart](mobile/lib/widgets/stock_stats_panel.dart) -- NEW; count + two pies + legends.
- [mobile/lib/screens/consume_screen.dart](mobile/lib/screens/consume_screen.dart) -- embed `StockStatsPanel(revision: _statsRevision)` below the buttons in `_buildIdle`; bump `_statsRevision` on transition into idle.
- [mobile/lib/l10n/strings.dart](mobile/lib/l10n/strings.dart) -- add the new French strings.
- [mobile/pubspec.yaml](mobile/pubspec.yaml) -- add `fl_chart`.

## Tasks & Acceptance

**Execution:**

- [x] `mobile/pubspec.yaml` -- add `fl_chart` (latest stable compatible with `sdk: ^3.11.4`); run `flutter pub get`.
- [x] `mobile/lib/server/database.dart` -- add `class StockStats { final int totalInStock; final Map<int,int> byColor; final Map<String,int> byRegion; }` and `Future<StockStats> getStockStats()`. One joined select over `bottles` + `cuvees` + `designations`, filtered by `consumedAt IS NULL`, aggregated in-memory. Empty/null region maps to key `S.statsInconnue`; color stays as raw int (UI handles 0 → "Inconnue" label).
- [x] `mobile/lib/l10n/strings.dart` -- add: `stockTitle = 'Stock'`, `bottlesInStock = 'bouteilles en stock'`, `noBottlesInStock = 'Aucune bouteille en stock'`, `statsInconnue = 'Inconnue'`, `byColor = 'Par couleur'`, `byRegion = 'Par région'`.
- [x] `mobile/lib/widgets/bottle_details_card.dart` -- expose top-level `String? colorLabel(int)`; delegate the private `_colorLabel` to it. Keep `null` for `color == 0`. Must land before the stats panel.
- [x] `mobile/lib/widgets/stock_stats_panel.dart` -- NEW StatefulWidget `StockStatsPanel({required int revision})`. Fetch via `context.read<AppDatabase>().getStockStats()` in `initState` and again on `didUpdateWidget` when `revision` changes. States: loading → bounded `CircularProgressIndicator`; error → text `S.databaseError`; empty stock → text `S.noBottlesInStock`; data → header `S.stockTitle`, big "$count ${S.bottlesInStock}", then two stacked pies (~200dp tall) titled `S.byColor` / `S.byRegion`, each with a legend (label · count) sorted by descending count, ties by label asc. Use `fl_chart` `PieChart`. Use `colorLabel` helper.
- [x] `mobile/lib/screens/consume_screen.dart` -- in `_ConsumeBodyState`: add `int _statsRevision = 0;` and `ScanState? _prevState;`; in `build`, if `_prevState != ScanState.idle && scan.state == ScanState.idle`, `_statsRevision++` (then update `_prevState`). In `_buildIdle`, append `Padding(padding: EdgeInsets.only(top: 32), child: StockStatsPanel(revision: _statsRevision))` to the existing button column. The outer `SingleChildScrollView` already lets it scroll.
- [x] `mobile/test/server/stock_stats_test.dart` -- using `AppDatabase.forTesting` seeded via `seedDatabase`, insert a handful of cuvées/bottles spanning colors 0/1/2 and regions 'Bordeaux' / empty. Assert: only `consumedAt == null` rows counted; `byColor` contains key `0` for unknown-color bottles; `byRegion` maps empty region to `S.statsInconnue`; consumed bottles are excluded.

**Acceptance Criteria:**
- Given the user is on the idle home screen with ≥1 in-stock bottle, when the screen renders, then below the three buttons appears a "Stock" section with the in-stock count and two pie charts (by color, by region) with legends.
- Given the user consumes a bottle and taps "Terminé", when they return to the idle screen, then the in-stock count has decremented by 1 and the affected color/region slice has shrunk accordingly.
- Given the bottles table contains zero in-stock rows, when the home screen renders, then the panel shows "Aucune bouteille en stock" and no pie charts.
- Given the user is in `scanning` / `consumed` / `error` state, then the stats panel is not rendered.
- Given some in-stock bottles have `color == 0` or empty designation region, when the pies render, then they include an "Inconnue" slice covering those bottles.

## Verification

**Commands:**
- `cd mobile && flutter pub get` -- expected: resolves `fl_chart` cleanly.
- `cd mobile && flutter analyze lib/server/database.dart lib/widgets/stock_stats_panel.dart lib/screens/consume_screen.dart lib/widgets/bottle_details_card.dart lib/l10n/strings.dart test/server/stock_stats_test.dart` -- expected: no new warnings/errors on changed files.
- `cd mobile && flutter test test/server/stock_stats_test.dart` -- expected: all green.

**Manual checks:**
- Cold-launch a dev build (seeded DB), observe the home screen — expect the count and both pies to render below the three buttons within ~1 second.
- Consume one bottle, tap "Terminé" — the count decrements; the matching color/region slice visibly shrinks.
- Force the DB to empty (delete bottles via DB Browser or restore an empty backup) — expect "Aucune bouteille en stock" and no charts.

## Suggested Review Order

**Data: aggregation contract**

- Value class returned to the UI — three numbers, no DB knowledge leaked.
  [`database.dart:76`](../../mobile/lib/server/database.dart#L76)

- Single joined read, in-memory bucketing, out-of-range color collapsed to 0.
  [`database.dart:464`](../../mobile/lib/server/database.dart#L464)

**UI: panel lifecycle and rendering**

- Widget contract: `revision`-driven refresh, keep prior chart on success, surface fresh errors.
  [`stock_stats_panel.dart:15`](../../mobile/lib/widgets/stock_stats_panel.dart#L15)

- Fetch on mount + on `revision` change; error wipes stale data per spec.
  [`stock_stats_panel.dart:43`](../../mobile/lib/widgets/stock_stats_panel.dart#L43)

- Render branches: error → spinner → empty → data.
  [`stock_stats_panel.dart:71`](../../mobile/lib/widgets/stock_stats_panel.dart#L71)

- Slice color, sort order, and per-slice title-text contrast.
  [`stock_stats_panel.dart:103`](../../mobile/lib/widgets/stock_stats_panel.dart#L103)

**Screen wiring: when to reload**

- Revision bump only on transition into idle, so each consume triggers exactly one refetch.
  [`consume_screen.dart:88`](../../mobile/lib/screens/consume_screen.dart#L88)

- Panel embedded below the existing buttons, idle-only by construction.
  [`consume_screen.dart:140`](../../mobile/lib/screens/consume_screen.dart#L140)

**Reusable label helper**

- `_colorLabel` promoted to public `colorLabel` so both card and panel share one mapping.
  [`bottle_details_card.dart:7`](../../mobile/lib/widgets/bottle_details_card.dart#L7)

**Peripherals**

- New French strings — all UI text in [strings.dart](../../mobile/lib/l10n/strings.dart).
  [`strings.dart:73`](../../mobile/lib/l10n/strings.dart#L73)

- Tests lock the query semantics (consumed exclusion, color 0 bucket, empty-region → Inconnue).
  [`stock_stats_test.dart`](../../mobile/test/server/stock_stats_test.dart)

- `fl_chart` dependency added (approved during planning).
  [`pubspec.yaml`](../../mobile/pubspec.yaml)
