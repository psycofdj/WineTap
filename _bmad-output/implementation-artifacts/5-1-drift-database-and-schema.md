# Story 5.1: Drift Database and Schema

Status: done

## Story

As a developer,
I want the phone to have a SQLite database with the complete wine cellar schema,
So that all subsequent server endpoints and the consume flow have a data foundation.

## Acceptance Criteria

1. **Given** `server/database.dart` defines all drift tables (designations, domains, cuvees, bottles)
   **When** `dart run build_runner build` is run
   **Then** `database.g.dart` generates without errors

2. **Given** the drift table definitions
   **Then** all tables use `snake_case` column names matching the existing RPi schema exactly

3. **Given** `toJson()` extensions exist for all entities
   **Then** JSON output uses `snake_case` keys matching `docs/rest-api-contracts.md`

4. **Given** the schema
   **Then** foreign key constraints match: cuvees→domains, cuvees→designations, bottles→cuvees

5. **Given** the database is created on app launch
   **Then** `flutter analyze` passes and `flutter test` passes

## Tasks / Subtasks

- [x] Task 1: Add drift dependencies to pubspec.yaml
  - [x] Add `drift: ^2.32.0`, `drift_flutter: ^0.3.0` to dependencies
  - [x] Add `drift_dev: ^2.32.0`, `build_runner: ^2.4.0` to dev_dependencies
  - [x] Run `flutter pub get`
- [x] Task 2: Create drift table definitions (AC: #1, #2, #4)
  - [x] Create `mobile/lib/server/database.dart`
  - [x] Define `Designations` table: id (autoIncrement), name (text, unique), region (text), description (text)
  - [x] Define `Domains` table: id (autoIncrement), name (text, unique), description (text)
  - [x] Define `Cuvees` table: id (autoIncrement), name (text), domain_id (int, FK→domains), designation_id (int, default 0 = unassigned), color (int), description (text)
  - [x] Define `Bottles` table: id (autoIncrement), tag_id (text, nullable, unique), cuvee_id (int, FK→cuvees), vintage (int), description (text), purchase_price (real, nullable), drink_before (int, nullable), added_at (text), consumed_at (text, nullable)
  - [x] Define `AppDatabase` class extending `_$AppDatabase` with `schemaVersion = 1`
  - [x] All column names must be `snake_case` (drift default)
- [x] Task 3: Generate drift code (AC: #1)
  - [x] Run `dart run build_runner build`
  - [x] Verify `database.g.dart` generates without errors
- [x] Task 4: Create toJson() extensions (AC: #3)
  - [x] `DesignationToJson` extension: id, name, region, description
  - [x] `DomainToJson` extension: id, name, description
  - [x] `CuveeWithNamesToJson` extension: id, name, domain_id, designation_id, color, description + denormalized domain_name, designation_name, region
  - [x] `BottleWithCuveeToJson` extension: id, tag_id, cuvee_id, vintage, description, purchase_price, drink_before, added_at, consumed_at + nested cuvee object
  - [x] All keys `snake_case` matching `docs/rest-api-contracts.md`
  - [x] Nullable fields omitted when null (not `"field": null`)
- [x] Task 5: Create database query methods
  - [x] Designations: list (ordered by name), getById, insert, update, delete
  - [x] Domains: list (ordered by name), getById, insert, update, delete
  - [x] Cuvees: list (ordered by domain then name, with JOINs for denormalized fields), getById, insert, update, delete
  - [x] Bottles: list (with include_consumed flag, JOINs for cuvee), getById, getByTagId (in-stock only), insert, consume (set consumed_at + clear tag_id), update (partial), bulkUpdate, delete, setTagId
  - [x] Completions: search by prefix for designation/domain/cuvee names
- [x] Task 6: Verification (AC: #5)
  - [x] Run `flutter analyze` — no issues
  - [x] Run `flutter test` — all tests pass (42 tests, 0 failures)
  - [x] Run `flutter build apk --debug` — builds successfully

### Review Findings

- [x] [Review][Decision] `cuvees→designations` FK constraint restored — seeded sentinel designation (id=0, name='(unassigned)') in onCreate migration
- [x] [Review][Patch] `consumeBottle` re-fetch by timestamp → fixed to use bottle ID; wrapped in `transaction()`
- [x] [Review][Patch] `bulkUpdateBottles([])` → guarded with early return of 0
- [x] [Review][Patch] Nested cuvee in `BottleWithCuveeToJson` → added `designation_id` key
- [x] [Review][Patch] LIKE wildcards → escaped via `_escapeLike()` + SQLite `LIKE()` function with ESCAPE clause
- [x] [Review][Patch] `listBottles` → added `orderBy` (domain name, cuvee name, vintage)
- [x] [Review][Defer] `getById` methods throw opaque `StateError` on missing row — handler layer (Stories 5.3/5.4) should catch and map to 404. Pre-existing pattern, not actionable in DB layer alone.

## Dev Notes

### drift Table Pattern

Per architecture spec — all tables in one `database.dart` file:

```dart
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'database.g.dart';

class Designations extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().unique()();
  TextColumn get region => text().withDefault(const Constant(''))();
  TextColumn get description => text().withDefault(const Constant(''))();
}

class Domains extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().unique()();
  TextColumn get description => text().withDefault(const Constant(''))();
}

class Cuvees extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  IntColumn get domainId => integer().references(Domains, #id)();
  IntColumn get designationId => integer().references(Designations, #id).withDefault(const Constant(0))();
  IntColumn get color => integer().withDefault(const Constant(0))();
  TextColumn get description => text().withDefault(const Constant(''))();
}

class Bottles extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get tagId => text().nullable().unique()();
  IntColumn get cuveeId => integer().references(Cuvees, #id)();
  IntColumn get vintage => integer()();
  TextColumn get description => text().withDefault(const Constant(''))();
  RealColumn get purchasePrice => real().nullable()();
  IntColumn get drinkBefore => integer().nullable()();
  TextColumn get addedAt => text()();
  TextColumn get consumedAt => text().nullable()();
}

@DriftDatabase(tables: [Designations, Domains, Cuvees, Bottles])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 1;
}
```

**Note on column names:** drift auto-generates `snake_case` SQL column names from `camelCase` Dart getters. So `tagId` becomes `tag_id` in SQL, `cuveeId` becomes `cuvee_id`, etc. This matches the RPi schema exactly.

### toJson() Extensions

Per architecture spec — manual JSON serialization with `snake_case` keys:

```dart
extension DesignationToJson on Designation {
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'region': region,
    'description': description,
  };
}
```

For Bottles, the toJson needs the denormalized cuvee. This requires a custom query result class:

```dart
class BottleWithCuvee {
  final Bottle bottle;
  final Cuvee cuvee;
  final String domainName;
  final String designationName;
  final String region;
  // toJson() includes nested cuvee object
}
```

### Existing Schema Reference (RPi)

The existing RPi database has these columns (after v1 migration 0002 rename):

- `designations`: id, name, region, description, picture
- `domains`: id, name, description
- `cuvees`: id, name, domain_id, designation_id, color, description
- `bottles`: id, tag_id, cuvee_id, vintage, description, purchase_price, drink_before, added_at, consumed_at

**Note:** `picture` column on designations is excluded for MVP (deferred). The drift schema omits it.

**Note:** `color` in the RPi schema is stored as TEXT but the proto used an int enum. The REST contract uses int. Use `IntColumn` in drift to match the REST contract.

### Query Methods

The `getByTagId` method must filter for in-stock bottles only:

```dart
Future<BottleWithCuvee?> getBottleByTagId(String tagId) {
  // SELECT ... FROM bottles b
  // JOIN cuvees c ON c.id = b.cuvee_id
  // JOIN domains d ON d.id = c.domain_id
  // JOIN designations des ON des.id = c.designation_id
  // WHERE b.tag_id = ? AND b.consumed_at IS NULL
}
```

The `consume` method sets `consumed_at` and clears `tag_id`:

```dart
Future<void> consumeBottle(String tagId) {
  // UPDATE bottles SET consumed_at = ?, tag_id = NULL WHERE tag_id = ? AND consumed_at IS NULL
}
```

### What NOT to Do

- Do NOT create the shelf HTTP server — that's Story 5.2
- Do NOT modify `main.dart` — database wiring to the app comes in Story 5.2
- Do NOT remove gRPC code — that's Story 5.6
- Do NOT create handlers — Stories 5.3 and 5.4
- Do NOT use raw SQL — use drift query builder
- Do NOT put tables in separate files — all in `database.dart` per architecture decision

### Previous Story Intelligence

This is the first v2 story. The Flutter project exists from v1 with:
- `nfc_manager` v4, `provider`, `shared_preferences`, `bonsoir` already in pubspec
- `grpc`, `protobuf`, `fixnum` still in pubspec (removed in Story 5.6)
- NFC service, providers, screens all exist from v1 (adapted in later stories)

### References

- [Source: docs/data-models.md] — existing RPi schema (tables, columns, types, constraints)
- [Source: docs/rest-api-contracts.md] — JSON shapes and field names for toJson()
- [Source: _bmad-output/planning-artifacts/architecture-mobile-v2.md] — drift patterns, snake_case convention, toJson extensions, database.dart single-file approach
- [Source: _bmad-output/planning-artifacts/epics-mobile-v2.md] — Story 5.1 acceptance criteria

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (1M context)

### Debug Log References

- drift_flutter ^0.2.0 incompatible with drift ^2.32.0 (sqlite3 version conflict) — upgraded to ^0.3.0
- FK enforcement enabled via `PRAGMA foreign_keys = ON` in `beforeOpen` migration
- designation_id uses default 0 (unassigned) without FK constraint; leftOuterJoin handles the relationship in queries since id=0 has no matching designation row
- `isNull`/`isNotNull` name collision between drift and flutter_test resolved via `hide` import

### Completion Notes List

- Created drift database with 4 tables (Designations, Domains, Cuvees, Bottles) matching RPi schema
- All column names auto-generate as snake_case via drift convention
- FK constraints: cuvees→domains, bottles→cuvees enforced; designation_id uses 0=unassigned pattern
- toJson() extensions output snake_case keys matching docs/rest-api-contracts.md; nullable fields omitted when null
- CuveeWithNames and BottleWithCuvee result classes provide denormalized query results
- Complete CRUD + completions query methods implemented in AppDatabase
- 32 new database tests + 10 existing tests = 42 total, all passing
- flutter analyze clean, debug APK builds successfully

### File List

- mobile/pubspec.yaml (modified — added drift, drift_flutter, drift_dev, build_runner)
- mobile/lib/server/database.dart (new — table definitions, toJson extensions, query methods)
- mobile/lib/server/database.g.dart (generated — drift codegen output)
- mobile/test/server/database_test.dart (new — 32 tests covering schema, queries, toJson)

### Change Log

- 2026-04-01: Implemented Story 5.1 — Drift database schema, toJson extensions, query methods, and tests
- 2026-04-01: Code review — fixed 6 patch items (consumeBottle race, bulkUpdate guard, missing designation_id in JSON, LIKE escaping, listBottles ordering, FK restoration with sentinel row). 1 item deferred to Stories 5.3/5.4.
