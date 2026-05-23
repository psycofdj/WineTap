---
title: 'Dev-mode auto-seed of test bottles when bottles table is empty'
type: 'feature'
created: '2026-05-23'
status: 'done'
baseline_commit: 'c394cf4ed5d7e6a4bc27adcc2671633ea502a614'
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Local dev builds always start with zero bottles, forcing the developer to scan NFC tags or hand-insert rows before any UI flow (consume / identify / tasting history) can be exercised.

**Approach:** At app startup, after the DB is materialized but before `runApp`, run a guarded one-shot seeder that inserts a realistic catalog of cuvées and bottles (a mix of consumed and in-stock, spanning every color) **only** when both gating conditions hold:
1. `bottles` table is empty.
2. The full app version string `'${info.version}+${info.buildNumber}'` contains the substring `+dev`.

The seeder reuses the designations and domains already inserted by the existing `seedDatabase` (see [mobile/lib/server/seed_data.dart](mobile/lib/server/seed_data.dart)) — it looks them up by name; it does not insert duplicates.

## Boundaries & Constraints

**Always:**
- Both gates must pass; either alone is a no-op.
- Look up `designation_id` and `domain_id` by name from existing seed data. Skip silently (with a `dev.log` warning) if a referenced name is missing — never insert designations or domains.
- Wine color enum mapping must match [BottleDetailsCard._colorLabel](mobile/lib/widgets/bottle_details_card.dart): 1=Rouge, 2=Blanc, 3=Rosé, 4=Effervescent, 5=Autre. At least one cuvée per color.
- Generate ≥20 consumed bottles total so the paginated tasting history is exercised.
- Run the seeder inside a single drift `transaction` — either all inserts commit, or none do.
- For consumed bottles, follow the existing invariant from [database.dart consumeBottle](mobile/lib/server/database.dart): `consumedAt` is set, `tagId` is null. For in-stock dev bottles, `tagId` is null too (these are not associated with real NFC tags).
- `addedAt` and `consumedAt` are ISO-8601 UTC strings, deterministically derived (no `DateTime.now()` inside the seeder so dev DBs are reproducible across cold starts).
- The seeder file is a self-contained module with one public entry point. It logs via `dart:developer`'s `log` (name: `DevSeed`) at start, success, and skip.

**Ask First:**
- Adding any new package.
- Inserting new designations or domains.
- Any production / non-dev code path that depends on `+dev`.

**Never:**
- Do not run on release builds — `+dev` is the only trigger.
- Do not delete or modify existing rows; the seeder is purely additive and only ever runs when bottles count is zero.
- Do not rely on `package_info_plus`'s `appName` or any field other than `version` and `buildNumber`.
- Do not couple this to `AppDatabase.onCreate` — the gate must be checked on every startup, not only on first DB creation.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Dev build, fresh DB | version="0.0.0", build="dev", `bottles` count == 0 | Seeder runs; ~20 cuvées + ~60 bottles inserted; ≥20 consumed; log "seeded N bottles" | Per-cuvée lookup failure → log + skip that cuvée; partial seed acceptable |
| Dev build, bottles already present | build="dev", `bottles` count > 0 | Skip; log "skipped: bottles already present" | N/A |
| Release build, fresh DB | build="1", `bottles` count == 0 | Skip; log "skipped: not a dev build" | N/A |
| Release build, populated DB | build="1", `bottles` count > 0 | Skip silently | N/A |
| Designation/domain missing | Referenced name not found in seed | That single cuvée is skipped with a warning; other cuvées still seeded | Caught locally |
| Transaction failure mid-seed | DB error during inserts | Whole transaction rolls back; log error; app continues to boot | Caught at outer seeder boundary |
| `package_info_plus` throws | `PackageInfo.fromPlatform()` rejects | Treat as non-dev → skip; do not crash startup | Caught locally |

</frozen-after-approval>

## Code Map

- [mobile/lib/main.dart:22](mobile/lib/main.dart#L22) -- entry point; insert seeder call after `db` materializes and before `runApp` (around the existing `customSelect('SELECT 1')` warm-up).
- [mobile/lib/server/seed_data.dart](mobile/lib/server/seed_data.dart) -- existing onCreate seed of designations + domains; reference data the new seeder relies on.
- [mobile/lib/server/database.dart](mobile/lib/server/database.dart) -- holds `Designations`, `Domains`, `Cuvees`, `Bottles` tables and `transaction()` helper; the new seeder writes through this.
- [mobile/lib/widgets/bottle_details_card.dart](mobile/lib/widgets/bottle_details_card.dart) -- canonical wine-color enum mapping (1..5).
- [mobile/lib/screens/consume_screen.dart:22](mobile/lib/screens/consume_screen.dart#L22) -- existing use of `PackageInfo.fromPlatform()` (same call shape we'll reuse in main).

## Tasks & Acceptance

**Execution:**
- [x] `mobile/lib/server/dev_seed.dart` (new) -- exports two functions: `Future<bool> isDevBuild()` returning `'${info.version}+${info.buildNumber}'.contains('+dev')` (catching any `PackageInfo` errors and returning false); and `Future<void> seedDevDataIfNeeded(AppDatabase db)` which: (a) returns immediately unless `isDevBuild()` is true; (b) returns immediately if `bottles` has any row; (c) inside `db.transaction(...)`, inserts a curated catalog reusing names from `seed_data.dart`. Catalog target: ~10 domains (looked up), ~20 cuvées spanning every color (1..5), ~60 bottles with realistic varied vintages (2008–2022), of which ≥20 are consumed (consumedAt set, tagId null) with consumption timestamps spread over the last ~18 months relative to a fixed reference instant (e.g. `DateTime.utc(2026, 5, 1)`), and the remainder in-stock. Around 30% of bottles carry a non-empty `description` (tasting note), some carry `purchasePrice` and `drinkBefore`. Use `into(table).insertOnConflictUpdate` or plain insert — duplicates are impossible since the table starts empty. -- Self-contained, deterministic seed module.
- [x] `mobile/lib/main.dart` -- after the existing `await db.customSelect('SELECT 1').get();` warm-up and before `startServer`, call `await seedDevDataIfNeeded(db);` inside a `try/catch` that logs and continues (seeder must never block app startup). Add the import. -- Wire the seeder into boot.
- [x] `mobile/test/server/dev_seed_test.dart` (new) -- using `AppDatabase.forTesting` with an in-memory db that has been pre-populated by running `seedDatabase` (so designations/domains exist), assert: (a) calling `seedDevDataIfNeeded` from a dev gate inserts ≥20 cuvées and ≥60 bottles with ≥20 having `consumedAt != null`; (b) calling it a second time is a no-op (bottle count unchanged); (c) the post-seed `listConsumedBottles(limit: 20, offset: 0)` returns 20 rows ordered DESC. Tests inject the dev-gate decision rather than calling `PackageInfo`. -- Cover the gate, idempotence, and pagination interplay.

**Acceptance Criteria:**
- Given a freshly installed dev build (version string contains `+dev`) and an empty bottles table, when the app starts, then the bottles table is populated with the dev catalog before the UI renders.
- Given a dev build with bottles already present, when the app starts, then no new rows are inserted.
- Given a release build with an empty bottles table, when the app starts, then no rows are inserted.
- Given the seeder ran, when the user opens the tasting history screen, then the first page shows 20 cards and the rest load as they scroll.
- Given the seeder catalog, when inspected, then every wine color value (1..5) appears at least once across the cuvées.

## Spec Change Log

### 2026-05-23 — Patch findings applied post-review (no spec/intent change)

Source: step-04 review (auditor ACCEPT; blind hunter + edge case hunter findings).

Auto-fixed patches (no spec re-derivation needed):
- `addedAt` was built with `DateTime(year, month, day)` (local) then `.toUtc()` — non-deterministic across host timezones. Switched to `DateTime.utc(...)` so the seeded catalog is byte-identical regardless of machine, honoring the spec's "deterministically derived" invariant.
- Emptiness check now hits the DB with `..limit(1)` instead of materializing every row of `bottles`.
- Emptiness check moved *inside* the drift `transaction` so a re-entrant call (e.g. on app resume) cannot double-seed.
- `consumedAt` is now derived from `addedAt + N days` (rather than `_refInstant - N days`), guaranteeing `consumedAt > addedAt` for every consumed bottle — closes a "looks real" gap.
- Misleading `main.dart` comment "Never blocks startup" rewritten to clarify that we *intentionally* await (so the UI sees seeded data on first paint) and that only crashes are swallowed.
- Renamed misleading local `priceCents` → `price` (values are euros, not cents).

Deferred (real but out of this story's scope) — moved to `deferred-work.md` under "spec-dev-mode-test-data-seeding": `kDebugMode` belt-and-braces against CI shipping a `+dev` pubspec to production; no fail-loud signal when a catalog cuvée is silently skipped; undocumented `purchasePrice` unit on the schema.

KEEP: deterministic timestamps anchored to `_refInstant`; single drift transaction; reuse of seeded designations/domains by name (per spec); test-injectable `isDev` parameter for the gate; `tagId` null for dev bottles (consumed and in-stock alike); coverage of all 5 wine colors.

## Verification

**Commands:**
- `cd mobile && flutter analyze lib/server/dev_seed.dart lib/main.dart test/server/dev_seed_test.dart` -- expected: no new warnings/errors on changed files.
- `cd mobile && flutter test test/server/dev_seed_test.dart` -- expected: all green.

**Manual checks:**
- With local pubspec at `version: 0.0.0+dev`, delete the on-device DB, cold-launch the app, open the tasting history screen — expect ≥20 consumed bottles spanning multiple colors.
- Temporarily set pubspec to `version: 0.0.0+1`, repeat — expect an empty tasting history.

## Suggested Review Order

**Entry point**

- Boot wiring — awaited so first paint shows seeded data; failures logged, never crash.
  [`main.dart:43`](../../mobile/lib/main.dart#L43)

**Gate**

- `isDevBuild()` — version contains "+dev"; PackageInfo failure treated as non-dev.
  [`dev_seed.dart:16`](../../mobile/lib/server/dev_seed.dart#L16)

- `seedDevDataIfNeeded()` — gate + transactional emptiness re-check + dispatch.
  [`dev_seed.dart:30`](../../mobile/lib/server/dev_seed.dart#L30)

**Determinism**

- `_refInstant` is the anchor — all addedAt/consumedAt derive from it, no wall clock.
  [`dev_seed.dart:11`](../../mobile/lib/server/dev_seed.dart#L11)

- `DateTime.utc(...)` for addedAt and `addedInstant + N days` for consumedAt — TZ-independent, `consumedAt > addedAt`.
  [`dev_seed.dart:190`](../../mobile/lib/server/dev_seed.dart#L190)

**Catalog**

- The curated cuvée catalog — 20 entries, all 5 wine colors, lookups by name against the existing seed.
  [`dev_seed.dart:62`](../../mobile/lib/server/dev_seed.dart#L62)

**Tests**

- Gate (dev/non-dev, populated/empty), idempotence, catalog coverage, pagination interplay.
  [`dev_seed_test.dart`](../../mobile/test/server/dev_seed_test.dart)
