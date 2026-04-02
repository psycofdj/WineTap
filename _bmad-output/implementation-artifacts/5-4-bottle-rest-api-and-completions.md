# Story 5.4: Bottle REST API + Completions

Status: done

## Story

As a user,
I want the phone to serve all bottle endpoints and autocomplete,
So that the manager can add, browse, update, and consume bottles.

## Acceptance Criteria

1. **Given** `handlers/bottles.dart` and `handlers/completions.dart`
   **When** any bottle or completion operation is performed
   **Then** all 9 bottle routes work per `docs/rest-api-contracts.md`:
   - `GET /bottles` — list (query: `include_consumed=true` for consumed bottles)
   - `GET /bottles/:id` — get by ID
   - `GET /bottles/by-tag/:tag_id` — get in-stock bottle by tag
   - `POST /bottles` — add new bottle
   - `POST /bottles/consume` — consume bottle by tag_id
   - `PUT /bottles/:id` — partial update
   - `PUT /bottles/bulk` — bulk partial update
   - `DELETE /bottles/:id` — hard delete
   - `PUT /bottles/:id/tag` — set/update tag ID

2. **Given** `GET /completions?field=designation&prefix=mad`
   **When** called with `field` = `designation`, `domain`, or `cuvee`
   **Then** returns `{"values": ["Madiran", ...]}` — matching names ordered alphabetically

3. **Given** `PUT /bottles/:id` or `PUT /bottles/bulk`
   **When** some fields are absent from the request body
   **Then** absent fields are not updated (use `body.containsKey('field')`)
   **And** explicit `null` in body clears the value (nullable fields only)

4. **Given** any endpoint accepting `tag_id`
   **Then** tag_id is normalized: strip colons/spaces/dashes, uppercase
   (e.g., `04:a3:2b:ff` → `04A32BFF`)

5. **Given** bottle responses
   **Then** the full denormalized cuvee is embedded: `domain_name`, `designation_name`, `region`
   **And** nullable fields (`tag_id`, `purchase_price`, `drink_before`, `consumed_at`) are omitted when null

6. **Given** all routes are mounted
   **Then** `router.mount('/bottles', bottlesRouter(db).call)` and `router.mount('/completions', completionsRouter(db).call)` in `server.dart`
   **And** `flutter analyze` passes and `flutter test` passes

## Tasks / Subtasks

- [x] Task 1: Create bottles handler (AC: #1, #3, #4, #5)
  - [x] Create `mobile/lib/server/handlers/bottles.dart`
  - [x] Register routes in correct order (see Dev Notes — route ordering is critical)
  - [x] `GET /` — `db.listBottles(includeConsumed: ...)` with `include_consumed` query param
  - [x] `GET /by-tag/<tag_id>` — normalize tag_id, call `db.getBottleByTagId()` → null = 404
  - [x] `GET /<id>` — `db.getBottleById()` → StateError = 404
  - [x] `POST /` — validate `cuvee_id`, `vintage` required; set `addedAt`; insert; re-fetch; 201
  - [x] `POST /consume` — normalize tag_id, call `db.consumeBottle()` → StateError = 404; return 200 + bottle
  - [x] `PUT /bulk` — parse `{"ids": [...], "fields": {...}}`; build partial companion; `db.bulkUpdateBottles()`; return `{"updated": N}`
  - [x] `PUT /<id>` — partial update via `db.bulkUpdateBottles([id], companion)`; count==0 → 404; re-fetch; 200
  - [x] `PUT /<id>/tag` — normalize tag_id; `db.setBottleTagId()` → StateError = 404; return 200
  - [x] `DELETE /<id>` — `db.deleteBottle()` → count==0 = 404; 204
  - [x] Catch `SqliteException` UNIQUE → 409 `already_exists` (tag_id in use)
  - [x] Catch `SqliteException` FOREIGN KEY on insert → 400 `invalid_argument` (invalid cuvee_id)

- [x] Task 2: Create completions handler (AC: #2)
  - [x] Create `mobile/lib/server/handlers/completions.dart`
  - [x] `GET /` — parse `field` and `prefix` query params; call appropriate `db.search*Names(prefix)` method; return `{"values": [...]}`
  - [x] Return 400 if `field` is missing or invalid

- [x] Task 3: Mount routes in server.dart (AC: #6)
  - [x] Add `router.mount('/bottles', bottlesRouter(db).call)` to `startServer()`
  - [x] Add `router.mount('/completions', completionsRouter(db).call)` to `startServer()`

- [x] Task 4: Write tests (AC: #1–#6)
  - [x] Create `mobile/test/server/handlers/bottles_test.dart`
    - [x] GET list: empty array, include_consumed param
    - [x] GET by-tag: found → 200 + bottle; not found → 404
    - [x] GET by-id: found → 200; not found → 404
    - [x] POST: creates bottle, addedAt set, cuvee embedded; missing cuvee_id/vintage → 400; invalid cuvee_id → 400
    - [x] POST consume: 200 + bottle (consumed_at set, tag_id null); not found → 404
    - [x] PUT partial: updates only provided fields; not found → 404
    - [x] PUT bulk: updates all listed IDs; returns `{"updated": N}`
    - [x] PUT tag: sets tag; duplicate tag → 409; bottle not found → 404
    - [x] DELETE: 204; not found → 404
    - [x] Tag normalization: `04:a3:2b:FF` → `04A32BFF` stored/returned
  - [x] Create `mobile/test/server/handlers/completions_test.dart`
    - [x] Returns matching names for each field type
    - [x] Empty prefix returns all names
    - [x] Missing field → 400; invalid field value → 400

- [x] Task 5: Verification
  - [x] Run `flutter analyze` — no issues
  - [x] Run `flutter test` — all tests pass (no regressions)
  - [x] Run `flutter build apk --debug` — builds successfully

## Dev Notes

### Database Methods — Use Exactly These (do NOT reimplement)

All methods live in `mobile/lib/server/database.dart`:

```dart
// Bottles
db.listBottles({bool includeConsumed = false})  → Future<List<BottleWithCuvee>>
db.getBottleById(int id)                        → Future<BottleWithCuvee>   // throws StateError if missing
db.getBottleByTagId(String tagId)               → Future<BottleWithCuvee?>  // null if not found (in-stock only)
db.insertBottle(BottlesCompanion entry)         → Future<int>               // returns new id
db.consumeBottle(String tagId)                  → Future<BottleWithCuvee>   // throws StateError if not found
db.bulkUpdateBottles(List<int> ids, BottlesCompanion fields) → Future<int>  // returns row count
db.deleteBottle(int id)                         → Future<int>               // returns row count (0 = not found)
db.setBottleTagId(int id, String tagId)         → Future<BottleWithCuvee>   // throws StateError if id missing

// Completions
db.searchDesignationNames(String prefix) → Future<List<String>>
db.searchDomainNames(String prefix)      → Future<List<String>>
db.searchCuveeNames(String prefix)       → Future<List<String>>
```

**`db.updateBottle()` uses `.replace()` (full row overwrite) — do NOT use it for `PUT /bottles/:id`. Use `db.bulkUpdateBottles([id], companion)` instead.**

### Route Registration Order — CRITICAL

In `bottlesRouter`, register routes in this exact order to prevent shelf_router capturing static
paths as `:id` parameters:

```dart
router.get('/by-tag/<tag_id>', ...);  // BEFORE /<id>
router.get('/', ...);
router.get('/<id>', ...);

router.post('/consume', ...);         // No conflict — POST /<id> doesn't exist
router.post('/', ...);

router.put('/bulk', ...);             // BEFORE /<id> — "bulk" is a valid /:id match
router.put('/<id>/tag', ...);         // BEFORE /<id> — different depth, but safer ordered first
router.put('/<id>', ...);

router.delete('/<id>', ...);
```

### Tag Normalization

Apply to ALL endpoints that accept `tag_id` (path params and body):

```dart
String _normalizeTagId(String tagId) =>
    tagId.replaceAll(RegExp(r'[:\s\-]'), '').toUpperCase();
```

Endpoints that require normalization:
- `GET /by-tag/<tag_id>` (path param)
- `POST /` body `tag_id` (optional)
- `POST /consume` body `tag_id`
- `PUT /<id>/tag` body `tag_id`

### Partial Update (`PUT /bottles/:id`)

Use `body.containsKey('field')` to distinguish absent (don't update) from explicit null (clear):

```dart
BottlesCompanion _buildPartialCompanion(Map<String, dynamic> body) {
  return BottlesCompanion(
    // Only updatable by client:
    cuveeId: body.containsKey('cuvee_id')
        ? Value(body['cuvee_id'] as int)
        : const Value.absent(),
    vintage: body.containsKey('vintage')
        ? Value(body['vintage'] as int)
        : const Value.absent(),
    description: body.containsKey('description')
        ? Value((body['description'] as String?)?.trim() ?? '')
        : const Value.absent(),
    purchasePrice: body.containsKey('purchase_price')
        ? Value(body['purchase_price'] as double?)
        : const Value.absent(),
    drinkBefore: body.containsKey('drink_before')
        ? Value(body['drink_before'] as int?)
        : const Value.absent(),
    // NEVER updatable via PUT — system-managed:
    // addedAt, consumedAt, tagId (use PUT /<id>/tag instead), id
  );
}
```

Then for single-bottle partial update:
```dart
final count = await db.bulkUpdateBottles([intId], companion);
if (count == 0) return _error(404, 'not_found', 'bottle $intId not found');
final b = await db.getBottleById(intId);
return _json(200, b.toJson());
```

### Bulk Update (`PUT /bottles/bulk`)

```dart
// Request: {"ids": [42, 43], "fields": {"cuvee_id": 2, "vintage": 2020}}
final ids = (body['ids'] as List<dynamic>).cast<int>();
final fields = body['fields'] as Map<String, dynamic>;
final companion = _buildPartialCompanion(fields);
final count = await db.bulkUpdateBottles(ids, companion);
return _json(200, {'updated': count});
```

### Bottle Insert — Required Fields

```dart
BottlesCompanion.insert(
  cuveeId: cuveeId,
  vintage: vintage,
  addedAt: DateTime.now().toUtc().toIso8601String(),  // REQUIRED — no default
  tagId: Value(normalizedTagId),    // Value(null) if absent
  description: Value(description ?? ''),
  purchasePrice: Value(purchasePrice),   // Value(null) if absent
  drinkBefore: Value(drinkBefore),       // Value(null) if absent
)
```

After insert, re-fetch with `db.getBottleById(newId)` and return 201.

### Error Mapping

| Exception | Cause | HTTP |
|-----------|-------|------|
| `StateError` from `getBottleById/getBottleByTagId/consumeBottle` | Missing row | 404 `not_found` |
| `SqliteException` UNIQUE constraint | Duplicate `tag_id` | 409 `already_exists` |
| `SqliteException` FOREIGN KEY on INSERT | Invalid `cuvee_id` | 400 `invalid_argument` |
| `db.deleteBottle()` returns 0 | Bottle not found | 404 `not_found` |
| `db.bulkUpdateBottles([id], ...)` returns 0 | Bottle not found | 404 `not_found` |

Note: `getBottleByTagId` returns `null` (not `StateError`) — check for null explicitly.

`consumeBottle` throws `StateError` with message `'No in-stock bottle with tag_id=$tagId'`. Catch `StateError` → 404.

### `setBottleTagId` — 404 check

`db.setBottleTagId(id, tagId)` calls `getBottleById` after writing, which throws `StateError` if id doesn't exist. Catch `StateError` → 404.

### Completions Handler

```dart
// GET /completions?field=designation&prefix=mad
final field = req.url.queryParameters['field'];
final prefix = req.url.queryParameters['prefix'] ?? '';
if (field == null) return _error(400, 'invalid_argument', 'field is required');
final List<String> values;
switch (field) {
  case 'designation': values = await db.searchDesignationNames(prefix);
  case 'domain':      values = await db.searchDomainNames(prefix);
  case 'cuvee':       values = await db.searchCuveeNames(prefix);
  default: return _error(400, 'invalid_argument', 'field must be designation, domain, or cuvee');
}
return _json(200, {'values': values});
```

Mount at root: `router.get('/', ...)` — completions has a single route.

### toJson() Extensions — Already Exist, Use Them

`BottleWithCuvee.toJson()` in `database.dart` handles all response serialization:
- Omits null fields (`tag_id`, `purchase_price`, `drink_before`, `consumed_at`)
- Embeds full `cuvee` object with `domain_name`, `designation_name`, `region`

Do NOT write new serialization.

### File Structure

```
mobile/lib/server/handlers/
  designations.dart  (5.3, done)
  domains.dart       (5.3, done)
  cuvees.dart        (5.3, done)
  bottles.dart       ← new this story
  completions.dart   ← new this story

mobile/test/server/handlers/
  designations_test.dart  (5.3, done)
  domains_test.dart       (5.3, done)
  cuvees_test.dart        (5.3, done)
  bottles_test.dart       ← new this story
  completions_test.dart   ← new this story
```

### Established Patterns from Story 5.3 (Follow Exactly)

1. Each handler file exports a single `Router fooRouter(AppDatabase db)` function
2. Two private helpers at file bottom: `_json(int, Object)` and `_error(int, String, String)`
3. Import `package:sqlite3/sqlite3.dart' show SqliteException;` for error handling
4. Import `dart:developer' as dev;` for `dev.log()` on 500 errors
5. `import 'package:flutter_test/flutter_test.dart' hide isNull, isNotNull;` in test files
6. Test pattern: call `bottlesRouter(db)(Request('GET', Uri.parse('http://localhost/')))` directly
7. Test setup: `AppDatabase.forTesting(NativeDatabase.memory())` with `drift/native.dart`

### What NOT to Do

- Do NOT implement `GET /bottles/:id` before `GET /by-tag/:tag_id` in route registration
- Do NOT implement `PUT /bottles/:id` before `PUT /bottles/bulk` in route registration
- Do NOT use `db.updateBottle()` for `PUT /bottles/:id` — it does full replace, not partial
- Do NOT set `addedAt` or `consumedAt` in `PUT /bottles/:id`
- Do NOT add scan coordination endpoints (`/scan/*`) — Story 7.1
- Do NOT add backup/restore endpoints — Story 8.1
- Do NOT use `print()` — use `dart:developer` `log()`
- Do NOT add a service layer — handlers call drift directly
- Do NOT create `GET /bottles/:id` that includes consumed bottles — only `GET /bottles` has `include_consumed`

### References

- `docs/rest-api-contracts.md` — exact routes, request/response shapes, status codes
- `mobile/lib/server/database.dart` — all drift query methods and toJson extensions
- `mobile/lib/server/server.dart` — add two new mounts after existing cuvees mount
- `mobile/lib/server/handlers/cuvees.dart` — reference for handler structure (follow exactly)
- `mobile/test/server/handlers/cuvees_test.dart` — reference for test structure

### Review Findings

- [x] [Review][Decision] tag_id has no clearing mechanism — resolved: support `{"tag_id": null}` in PUT /:id to explicitly clear it; `_buildPartialCompanion` updated accordingly
- [x] [Review][Patch] Unsafe cast `body['tag_id'] as String?` in POST /bottles → uncaught TypeError → 500 [`mobile/lib/server/handlers/bottles.dart:101`]
- [x] [Review][Patch] Unsafe cast `body['drink_before'] as int?` in POST / and `_buildPartialCompanion` → uncaught TypeError on float → 500 [`mobile/lib/server/handlers/bottles.dart:112, 259`]
- [x] [Review][Patch] Unsafe cast `body['cuvee_id'] as int` in `_buildPartialCompanion` → uncaught TypeError on non-int → 500 [`mobile/lib/server/handlers/bottles.dart:247`]
- [x] [Review][Patch] `designation_id` missing from embedded cuvee object — dismissed, already present at `database.dart:126`
- [x] [Review][Patch] Non-integer elements in `ids` array for PUT /bulk silently dropped via `whereType<int>()` → misleading 200 with wrong updated count [`mobile/lib/server/handlers/bottles.dart:141`]
- [x] [Review][Patch] Empty string tag_id after normalization stored as `""` in POST /bottles — fixed, now returns 400 [`mobile/lib/server/handlers/bottles.dart:101-102`]
- [x] [Review][Patch] Explicit `null` for non-nullable `description` field silently coerced to `""` instead of returning 400 — in POST / and `_buildPartialCompanion` [`mobile/lib/server/handlers/bottles.dart:110, 252-254`]
- [x] [Review][Patch] No test asserts embedded `cuvee` object shape (including `designation_id`) in PUT /:id response [`mobile/test/server/handlers/bottles_test.dart` PUT group]
- [x] [Review][Defer] `setBottleTagId` 404 detection is fragile — 404 fires via `StateError` from `getBottleById` after a silent no-op `update`, not from the write itself; correct outcome but breaks if `getBottleById` ever returns null instead of throwing [`mobile/lib/server/database.dart:363-367`] — deferred, pre-existing architecture in database.dart
- [x] [Review][Defer] Empty `ids: []` in PUT /bulk returns `200 {"updated": 0}` — technically correct but could mask upstream type-filter bug; no guard for empty list — deferred, design choice
- [x] [Review][Defer] Empty `fields: {}` in PUT /bulk is a silent no-op but returns correct matched-row count — Drift limitation, no practical fix without spec change — deferred, pre-existing

## Dev Agent Record

### Agent Model Used

claude-sonnet-4-6

### Debug Log References

None — clean implementation.

### Completion Notes List

- Route ordering: `GET /by-tag/<tag_id>` before `GET /<id>`; `PUT /bulk` and `PUT /<id>/tag` before `PUT /<id>`; `POST /consume` before `POST /` (no actual conflict on POST but ordered defensively)
- `db.updateBottle()` NOT used for `PUT /:id` — it does full `.replace()`; used `db.bulkUpdateBottles([id], companion)` with `Value.absent()` for absent fields instead
- `_buildPartialCompanion()` helper at file level handles partial update logic; `_toDouble()` helper normalizes int/double JSON numbers for `purchase_price`
- `getBottleByTagId` returns null (not StateError) — explicit null check → 404
- `setBottleTagId` internally calls `getBottleById` after write — StateError on missing bottle caught → 404
- `consumeBottle` throws StateError with message `'No in-stock bottle with tag_id=...'` — caught → 404
- sentinel `(unassigned)` is included in `searchDesignationNames('')` results; completions test adjusted to use `containsAll` not exact count
- 96 tests total across all handler test files, all passing; `flutter analyze` clean; APK builds

### File List

- mobile/lib/server/handlers/bottles.dart (new)
- mobile/lib/server/handlers/completions.dart (new)
- mobile/lib/server/server.dart (modified — mount new routers)
- mobile/test/server/handlers/bottles_test.dart (new)
- mobile/test/server/handlers/completions_test.dart (new)

### Change Log

- 2026-04-01: Story created
- 2026-04-01: Implementation complete — bottles handler, completions handler, server.dart mounts, tests
