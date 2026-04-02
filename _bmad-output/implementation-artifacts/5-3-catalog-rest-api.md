# Story 5.3: Catalog REST API (Designations, Domains, Cuvées)

Status: review

## Story

As a user,
I want the phone to serve CRUD endpoints for designations, domains, and cuvées,
So that the manager can manage the wine catalog.

## Acceptance Criteria

1. **Given** `handlers/designations.dart`, `handlers/domains.dart`, `handlers/cuvees.dart`
   **When** any CRUD operation is performed
   **Then** GET/POST/PUT/DELETE for each entity works per `docs/rest-api-contracts.md`

2. **Given** a POST or PUT request with a duplicate name
   **Then** 409 is returned with `{"error": "already_exists", "message": "..."}`

3. **Given** a DELETE request on an entity referenced by children
   **Then** 412 is returned with `{"error": "failed_precondition", "message": "..."}`

4. **Given** any request with a missing or invalid required field
   **Then** 400 is returned with `{"error": "invalid_argument", "message": "..."}`

5. **Given** a GET/PUT/DELETE by ID where the entity does not exist
   **Then** 404 is returned with `{"error": "not_found", "message": "..."}`

6. **Given** all JSON responses
   **Then** all fields use `snake_case` matching `docs/rest-api-contracts.md`

7. **Given** the server architecture
   **Then** handlers call drift directly — no service layer
   **And** `AppDatabase` is passed as parameter — no global state

8. **Given** the server is running
   **Then** `flutter analyze` passes and `flutter test` passes

## Tasks / Subtasks

- [x] Task 1: Create designations handler (AC: #1, #2, #3, #4, #5, #6, #7)
  - [x] Create `mobile/lib/server/handlers/designations.dart`
  - [x] Export `Router designationsRouter(AppDatabase db)` function
  - [x] `GET /` — call `db.listDesignations()`, return 200 + JSON array
  - [x] `POST /` — validate `name` required, call `db.insertDesignation()`, fetch by ID, return 201 + JSON
  - [x] `PUT /<id>` — parse id, validate name, call `db.getDesignationById()` (→ 404 on StateError), call `db.updateDesignation()`, return 200 + updated JSON
  - [x] `DELETE /<id>` — parse id, call `db.deleteDesignation()` (→ 404 if count=0), return 204
  - [x] Catch `SqliteException` for UNIQUE constraint violations → 409
  - [x] Catch `SqliteException` for FOREIGN KEY constraint on DELETE → 412

- [x] Task 2: Create domains handler (AC: #1, #2, #3, #4, #5, #6, #7)
  - [x] Create `mobile/lib/server/handlers/domains.dart`
  - [x] Export `Router domainsRouter(AppDatabase db)` function
  - [x] `GET /` → list, `POST /` → create 201, `PUT /<id>` → update 200, `DELETE /<id>` → 204
  - [x] Same error handling pattern as designations

- [x] Task 3: Create cuvees handler (AC: #1, #2, #3, #4, #5, #6, #7)
  - [x] Create `mobile/lib/server/handlers/cuvees.dart`
  - [x] Export `Router cuveesRouter(AppDatabase db)` function
  - [x] `GET /` — call `db.listCuvees()`, return 200 + JSON array (CuveeWithNames)
  - [x] `POST /` — validate `name`, `domain_id`, `color` required; call `db.insertCuvee()`, fetch by ID (`db.getCuveeById()`), return 201 + JSON
  - [x] `PUT /<id>` — validate required fields, call `db.getCuveeById()` (→ 404 on StateError), call `db.updateCuvee()`, re-fetch, return 200 + JSON
  - [x] `DELETE /<id>` — call `db.deleteCuvee()` (→ 404 if count=0), return 204
  - [x] For INSERT with invalid `domain_id` FK → catch SqliteException FOREIGN KEY → 400 (not 412)
  - [x] For DELETE with bottles referencing cuvee → catch SqliteException FOREIGN KEY → 412

- [x] Task 4: Mount routes in server.dart (AC: #1)
  - [x] Add imports for `handlers/designations.dart`, `handlers/domains.dart`, `handlers/cuvees.dart`
  - [x] In `startServer()`, after the health check route, mount:
    - `router.mount('/designations', designationsRouter(db).call)`
    - `router.mount('/domains', domainsRouter(db).call)`
    - `router.mount('/cuvees', cuveesRouter(db).call)`

- [x] Task 5: Write tests (AC: #8)
  - [x] Create `mobile/test/server/handlers/designations_test.dart`
    - [x] list returns 200 with array
    - [x] create returns 201 with correct JSON; duplicate name → 409
    - [x] update returns 200; not-found id → 404; duplicate name → 409
    - [x] delete returns 204; not-found id → 404; FK violation (add domain referencing designation via cuvee) → 412
    - [x] missing name on create/update → 400
  - [x] Create `mobile/test/server/handlers/domains_test.dart`
    - [x] Same pattern: list 200, create 201/409, update 200/404/409, delete 204/404/412
  - [x] Create `mobile/test/server/handlers/cuvees_test.dart`
    - [x] list returns 200 with denormalized CuveeWithNames
    - [x] create returns 201 with domain_name/designation_name denormalized
    - [x] create with non-existent domain_id → 400
    - [x] update returns 200; not-found → 404
    - [x] delete returns 204; not-found → 404
    - [x] designation_id optional (defaults to 0, unassigned)

- [x] Task 6: Verification (AC: #8)
  - [x] Run `flutter analyze` — no issues
  - [x] Run `flutter test` — all tests pass (50 tests, no regressions)
  - [x] Run `flutter build apk --debug` — builds successfully

## Dev Notes

### Handler File Structure

Each handler exports a single function returning a `Router`. The `db` parameter is closed over:

```dart
// mobile/lib/server/handlers/designations.dart
import 'dart:convert';
import 'dart:developer' as dev;

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:sqlite3/sqlite3.dart' show SqliteException;

import '../database.dart';

Router designationsRouter(AppDatabase db) {
  final router = Router();

  router.get('/', (Request req) async {
    final list = await db.listDesignations();
    return _json(200, list.map((d) => d.toJson()).toList());
  });

  router.post('/', (Request req) async {
    final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
    final name = body['name'] as String?;
    if (name == null || name.trim().isEmpty) {
      return _error(400, 'invalid_argument', 'name is required');
    }
    try {
      final id = await db.insertDesignation(DesignationsCompanion.insert(
        name: name.trim(),
        region: Value((body['region'] as String?)?.trim() ?? ''),
        description: Value((body['description'] as String?)?.trim() ?? ''),
      ));
      final d = await db.getDesignationById(id);
      return _json(201, d.toJson());
    } on SqliteException catch (e) {
      if (e.message.contains('UNIQUE constraint')) {
        return _error(409, 'already_exists', 'designation "$name" already exists');
      }
      dev.log('insertDesignation error: $e', name: 'designations');
      return _error(500, 'internal', e.toString());
    }
  });

  router.put('/<id>', (Request req, String id) async {
    final intId = int.tryParse(id);
    if (intId == null) return _error(400, 'invalid_argument', 'id must be an integer');

    final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
    final name = body['name'] as String?;
    if (name == null || name.trim().isEmpty) {
      return _error(400, 'invalid_argument', 'name is required');
    }

    try {
      await db.getDesignationById(intId); // throws StateError if not found
    } on StateError {
      return _error(404, 'not_found', 'designation $intId not found');
    }

    try {
      await db.updateDesignation(DesignationsCompanion(
        id: Value(intId),
        name: Value(name.trim()),
        region: Value((body['region'] as String?)?.trim() ?? ''),
        description: Value((body['description'] as String?)?.trim() ?? ''),
      ));
      final d = await db.getDesignationById(intId);
      return _json(200, d.toJson());
    } on SqliteException catch (e) {
      if (e.message.contains('UNIQUE constraint')) {
        return _error(409, 'already_exists', 'designation "$name" already exists');
      }
      dev.log('updateDesignation error: $e', name: 'designations');
      return _error(500, 'internal', e.toString());
    }
  });

  router.delete('/<id>', (Request req, String id) async {
    final intId = int.tryParse(id);
    if (intId == null) return _error(400, 'invalid_argument', 'id must be an integer');

    try {
      final count = await db.deleteDesignation(intId);
      if (count == 0) return _error(404, 'not_found', 'designation $intId not found');
      return Response(204);
    } on SqliteException catch (e) {
      if (e.message.contains('FOREIGN KEY constraint')) {
        return _error(412, 'failed_precondition',
            'designation $intId is referenced by cuvées and cannot be deleted');
      }
      dev.log('deleteDesignation error: $e', name: 'designations');
      return _error(500, 'internal', e.toString());
    }
  });

  return router;
}

Response _json(int status, Object body) => Response(
      status,
      body: jsonEncode(body),
      headers: {'Content-Type': 'application/json'},
    );

Response _error(int status, String code, String message) =>
    _json(status, {'error': code, 'message': message});
```

Domains handler follows the identical pattern — same routes, `Domain.toJson()`, `db.insertDomain/updateDomain/deleteDomain`.

### Mounting in server.dart

Add after the health check route in `startServer()`:

```dart
import 'handlers/designations.dart';
import 'handlers/domains.dart';
import 'handlers/cuvees.dart';

// Inside startServer():
router.mount('/designations', designationsRouter(db).call);
router.mount('/domains', domainsRouter(db).call);
router.mount('/cuvees', cuveesRouter(db).call);
```

`router.mount('/designations', ...)` strips the `/designations` prefix before forwarding — the inner router sees `/`, `/<id>`, etc.

### SqliteException Import

`SqliteException` comes from the `sqlite3` package (transitive dep via drift):

```dart
import 'package:sqlite3/sqlite3.dart' show SqliteException;
```

**UNIQUE constraint** → message contains `'UNIQUE constraint'` → 409  
**FOREIGN KEY constraint** → message contains `'FOREIGN KEY constraint'` → 412 (on DELETE) or 400 (on INSERT with invalid FK parent)

### 404 Handling

`db.getDesignationById(id)`, `getDomainById(id)`, `getCuveeById(id)` all use `.getSingle()` internally, which throws `StateError` when no row is found. **Catch `StateError` → return 404.**

`db.deleteDesignation(id)` returns `int` (rows deleted). If 0 → 404 (no FK violation was thrown, so it simply didn't exist).

`db.updateDesignation(entry)` returns `bool` (true = updated, false = not found). However, since we need to return the updated entity anyway, the pattern in the template above is: fetch first (404 if not found), then update.

### Cuvees-Specific Notes

**Required fields**: `name`, `domain_id`, `color`  
**Optional**: `designation_id` (defaults to 0 = unassigned), `description`

**CuveeWithNames result class** (from database.dart):
```dart
class CuveeWithNames {
  final Cuvee cuvee;
  final String domainName;    // denormalized
  final String designationName; // '' if designation_id=0
  final String region;        // '' if designation_id=0
}
// toJson() extension already exists in database.dart
```

**Companion for insert**:
```dart
CuveesCompanion.insert(
  name: name,
  domainId: domainId,
  designationId: Value(designationId ?? 0),
  color: Value(color),
  description: Value(description ?? ''),
)
```

**Companion for update** (must include `id`):
```dart
CuveesCompanion(
  id: Value(intId),
  name: Value(name),
  domainId: Value(domainId),
  designationId: Value(designationId ?? 0),
  color: Value(color),
  description: Value(description ?? ''),
)
```

**FK error on INSERT** (e.g., `domain_id` doesn't exist) → `SqliteException` FOREIGN KEY → return **400** `invalid_argument` (not 412 — that's for DELETE violations).

**FK error on DELETE** (bottles reference cuvee) → **412** `failed_precondition`.

**After insert**: call `db.getCuveeById(newId)` to return the full denormalized CuveeWithNames.

**After update**: re-fetch with `db.getCuveeById(intId)` to return updated denormalized JSON.

### Response JSON Shapes (from docs/rest-api-contracts.md)

**Designation**: `{"id":1,"name":"Madiran","region":"Sud-Ouest","description":""}`  
**Domain**: `{"id":1,"name":"Domaine Brumont","description":""}`  
**Cuvee**: `{"id":1,"name":"Château Montus","domain_id":1,"designation_id":3,"color":1,"description":"","domain_name":"Domaine Brumont","designation_name":"Madiran","region":"Sud-Ouest"}`

All `toJson()` extensions already live in `mobile/lib/server/database.dart` — use them, do NOT write new serialization.

### Handler Test Pattern

Build the router directly and call it with a shelf `Request`:

```dart
// mobile/test/server/handlers/designations_test.dart
import 'dart:convert';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shelf/shelf.dart';
import 'package:wine_tap_mobile/server/database.dart';
import 'package:wine_tap_mobile/server/handlers/designations.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  group('GET /designations', () {
    test('returns 200 with empty array when no designations', () async {
      final router = designationsRouter(db);
      final response = await router(Request('GET', Uri.parse('http://localhost/')));
      expect(response.statusCode, 200);
      final body = jsonDecode(await response.readAsString());
      expect(body, isA<List>());
      // Note: sentinel designation (id=0) is NOT returned by listDesignations
      // because listDesignations is used for the API — verify this:
      expect(body, isEmpty);
    });
  });

  group('POST /designations', () {
    test('creates and returns designation with 201', () async {
      final router = designationsRouter(db);
      final response = await router(Request(
        'POST',
        Uri.parse('http://localhost/'),
        body: jsonEncode({'name': 'Madiran', 'region': 'Sud-Ouest'}),
        headers: {'Content-Type': 'application/json'},
      ));
      expect(response.statusCode, 201);
      final body = jsonDecode(await response.readAsString());
      expect(body['name'], 'Madiran');
      expect(body['region'], 'Sud-Ouest');
      expect(body['id'], isA<int>());
    });

    test('returns 409 on duplicate name', () async {
      // ... insert same name twice
    });

    test('returns 400 when name is missing', () async {
      // ... post without name
    });
  });

  // ... PUT, DELETE groups
}
```

**⚠️ isNull/isNotNull collision**: In test files using both drift and flutter_test, hide drift's matchers:
```dart
import 'package:flutter_test/flutter_test.dart' hide isNull, isNotNull;
```
This was needed in `database_test.dart` (5.1 learning) — may not apply to handler tests, but keep in mind.

### Sentinel Designation (id=0)

Designation id=0 (`'(unassigned)'`) is seeded in `onCreate` and should never be deleted. It is NOT returned by `listDesignations()` since `orderBy name` will include it (name='(unassigned)'). **However, it should be excluded from the GET /designations list.** Add a `where` clause to filter out id=0:

```dart
// In the GET / handler, or add a new query to database.dart:
// db.listDesignations() currently includes id=0 — verify this behaviour.
```

**Action**: Check if `listDesignations()` returns id=0. If yes, filter it in the handler:
```dart
final list = await db.listDesignations();
final filtered = list.where((d) => d.id != 0).toList();
```

DELETE of id=0 should return 412 if cuvees reference it (FK protects naturally). If no cuvees exist, deletion succeeds — add an explicit guard: if `intId == 0`, return 412 `failed_precondition` ("sentinel designation cannot be deleted").

### What NOT to Do

- Do NOT create bottle endpoints — Story 5.4
- Do NOT add completions endpoint — Story 5.4
- Do NOT create scan coordination endpoints — Story 7.1
- Do NOT rewrite ScanProvider or IntakeProvider — Stories 5.5 and 7.2
- Do NOT remove gRPC code — Story 5.6
- Do NOT use `print()` — use `dart:developer` `log()`
- Do NOT use global state — pass `db` as parameter
- Do NOT add a service layer — handlers call drift directly
- Do NOT add `GET /designations/:id`, `GET /domains/:id`, `GET /cuvees/:id` — not in the API contract

### Previous Story Intelligence

**Stories 5.1 + 5.2 established:**
- `mobile/lib/server/database.dart` — all drift query methods are ready, do NOT reimplement:
  - `db.listDesignations()`, `db.getDesignationById(id)`, `db.insertDesignation(companion)`, `db.updateDesignation(companion)`, `db.deleteDesignation(id)`
  - `db.listDomains()`, `db.getDomainById(id)`, `db.insertDomain(companion)`, `db.updateDomain(companion)`, `db.deleteDomain(id)`
  - `db.listCuvees()`, `db.getCuveeById(id)`, `db.insertCuvee(companion)`, `db.updateCuvee(companion)`, `db.deleteCuvee(id)`
- `toJson()` extensions for all entities in `database.dart` — use them
- `AppDatabase.forTesting(NativeDatabase.memory())` for test setup
- `mobile/lib/server/server.dart` — existing file, ADD routes to it (do NOT recreate)
- `import 'package:drift/native.dart'` for test in-memory DB

**Review learnings:**
- `isNull`/`isNotNull` collision: `import 'package:flutter_test/flutter_test.dart' hide isNull, isNotNull` if needed
- `StateError` from `.getSingle()` on missing row → catch it → 404
- FK enforcement is active (`PRAGMA foreign_keys = ON` in `beforeOpen`)
- Sentinel designation id=0 — filter from list response, guard against deletion

**Deferred from 5.1 code review (addressed here):**
> `getById` methods use `.getSingle()` which throws `StateError` on missing rows. Handler layer (Stories 5.3/5.4) should catch `StateError` and map to HTTP 404.

### References

- [Source: docs/rest-api-contracts.md] — exact routes, request/response shapes, status codes
- [Source: _bmad-output/planning-artifacts/architecture-mobile-v2.md] — handler pattern, anti-patterns, file structure
- [Source: _bmad-output/planning-artifacts/epics-mobile-v2.md] — Story 5.3 acceptance criteria
- [Source: _bmad-output/implementation-artifacts/5-1-drift-database-and-schema.md] — drift query methods, toJson extensions, FK patterns
- [Source: _bmad-output/implementation-artifacts/5-2-shelf-http-server-and-middleware.md] — server.dart structure, test patterns

## Dev Agent Record

### Agent Model Used

claude-sonnet-4-6

### Debug Log References

None — clean implementation, no runtime errors encountered.

### Completion Notes List

- `sqlite3: ^3.2.0` added as direct dependency in `pubspec.yaml` (was transitive via drift, needed for explicit `SqliteException` import)
- Sentinel designation (id=0) filtered from GET list via `.where((d) => d.id != 0)` in handler; DELETE guarded with explicit `if (intId == 0) return 412` before drift call
- FK on INSERT (invalid parent) → 400 `invalid_argument`; FK on DELETE (child exists) → 412 `failed_precondition`
- `StateError` from drift `.getSingle()` on missing row → caught → 404 `not_found`
- Test for "bottles referencing cuvee → 412 on DELETE" omitted: no bottle table yet (Story 5.4); test file has DELETE 204/404 coverage only
- 50 tests total (16 domains, 17 designations, 17 cuvees), all passing; `flutter analyze` clean

### File List

- mobile/lib/server/handlers/designations.dart (new)
- mobile/lib/server/handlers/domains.dart (new)
- mobile/lib/server/handlers/cuvees.dart (new)
- mobile/lib/server/server.dart (modified — mount new routers)
- mobile/test/server/handlers/designations_test.dart (new)
- mobile/test/server/handlers/domains_test.dart (new)
- mobile/test/server/handlers/cuvees_test.dart (new)

### Change Log

- 2026-04-01: Story created
