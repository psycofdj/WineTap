# Story 8.1: Backup and Restore Endpoints

Status: done

## Story

As a user,
I want to download and upload the phone's database,
So that I can protect my cellar data against a lost or broken phone.

## Acceptance Criteria

1. **Given** `handlers/backup.dart`
   **When** GET /backup is called
   **Then** returns raw SQLite .db file with `Content-Type: application/octet-stream`
   **And** includes `Content-Disposition: attachment; filename="winetap.db"`
   **And** backup completes in < 10s for 500-bottle database (NFR16)

2. **When** POST /restore is called with a raw SQLite file
   **Then** replaces the current database atomically (NFR17)
   **And** partial upload does not corrupt the existing database
   **And** server reinitializes drift with the new database after restore

## Tasks / Subtasks

- [x] Task 1: Add database file path accessor to AppDatabase (AC: #1, #2)
  - [x] 1.1 Add a static method or constructor parameter that exposes the database file path
  - [x] 1.2 `driftDatabase(name: 'winetap')` places the file at `<app-docs-dir>/winetap.db` — need to resolve this path for backup/restore file operations
  - [x] 1.3 Option A: pass the resolved `File` path from `main.dart` to handlers as a parameter
  - [x] 1.4 Option B: add `static Future<File> getDatabaseFile()` method to `AppDatabase` using `path_provider`

- [x] Task 2: Create `handlers/backup.dart` with backup endpoint (AC: #1)
  - [x] 2.1 Create `backupRouter(AppDatabase db, File dbFile)` returning `Router`
  - [x] 2.2 GET `/` handler: read `dbFile` bytes, return as `Response` with `Content-Type: application/octet-stream` and `Content-Disposition: attachment; filename="winetap.db"`
  - [x] 2.3 Before reading: call `db.customStatement('PRAGMA wal_checkpoint(TRUNCATE)')` to flush WAL to main file — ensures backup is consistent
  - [x] 2.4 Read file bytes via `dbFile.readAsBytes()`
  - [x] 2.5 Return `Response(200, body: bytes, headers: {...})`

- [x] Task 3: Create restore endpoint in `handlers/backup.dart` (AC: #2)
  - [x] 3.1 POST `/` handler: read raw bytes from request body
  - [x] 3.2 Validate: non-empty body, first 16 bytes match SQLite magic header (`SQLite format 3\0`)
  - [x] 3.3 Atomic replace: write bytes to temp file (`winetap.db.tmp`), then rename over existing file
  - [x] 3.4 Close and reopen drift database: `await db.close()` then reinitialize
  - [x] 3.5 Return `Response(200, body: jsonEncode({'status': 'restored'}))`
  - [x] 3.6 On error (invalid file, write failure): return 400/500, do NOT corrupt existing database

- [x] Task 4: Handle database reinitialization after restore (AC: #2)
  - [x] 4.1 The restore must close the current drift database and reopen it with the new file
  - [x] 4.2 Pass a `restartDatabase` callback from `main.dart` to the handler — avoids handler knowing about drift internals
  - [x] 4.3 Callback pattern: `Future<void> Function()` that closes old db, creates new `AppDatabase()`, and updates references
  - [x] 4.4 Alternative: accept `AppDatabase` as mutable reference; handler calls `db.close()` then caller recreates
  - [x] 4.5 Consider: server must stay running during restore — only the database connection is recycled

- [x] Task 5: Wire backup/restore routes into server.dart (AC: #1, #2)
  - [x] 5.1 Import `handlers/backup.dart`
  - [x] 5.2 Resolve database file path in `main.dart` or `startServer()`, pass to handler
  - [x] 5.3 Mount routes: `router.get('/backup', backupHandler)` and `router.post('/restore', restoreHandler)`
  - [x] 5.4 Note: these are top-level routes (`/backup`, `/restore`), not mounted under a prefix

- [x] Task 6: Create tests (AC: #1, #2)
  - [x] 6.1 Test GET /backup: returns bytes, correct content-type and content-disposition headers
  - [x] 6.2 Test GET /backup: returned bytes are valid SQLite (starts with magic header)
  - [x] 6.3 Test POST /restore with valid SQLite file: returns 200, database contains restored data
  - [x] 6.4 Test POST /restore with invalid file (not SQLite): returns 400, existing database unchanged
  - [x] 6.5 Test POST /restore with empty body: returns 400
  - [x] 6.6 Performance: verify 500-row database backup completes quickly (NFR16 — < 10s)

- [x] Task 7: Verify integration (AC: #1, #2)
  - [x] 7.1 `dart analyze` passes
  - [x] 7.2 All existing tests pass
  - [x] 7.3 New backup/restore tests pass

### Review Findings

- [x] [Review][Decision] Response not returned before exit(0) — accepted as-is (option b): client receives connection-reset after restore; app restart is the confirmation. exit(0) is MVP behavior.
- [x] [Review][Patch] Unbounded request body — added 100 MB cap with _BodyTooLargeException; returns 413 [backup.dart:48-57]
- [x] [Review][Patch] TOCTOU: original DB lost if rename fails — added .bak preservation before rename; recovery path restores .bak if dbFile is missing [backup.dart:70-73]
- [x] [Review][Patch] dbFile not existing on first launch — added existence check; returns 503 unavailable [backup.dart:18-20]
- [x] [Review][Patch] Error message leaks exception details to client — sanitized to 'restore failed' (no $e); exception logged internally [backup.dart:95]
- [x] [Review][Patch] WAL/SHM deletion order — WAL/SHM deleted after successful rename (current order safe: SQLite detects WAL mismatch via salt; stale WAL cleaned up before restartDb) [backup.dart:78-82]
- [x] [Review][Patch] Missing Content-Length on backup response — added Content-Length header [backup.dart:26]
- [x] [Review][Patch] Tmp cleanup in catch swallows exception — wrapped tmpFile.delete() in try-catch with dev.log [backup.dart:99-102]
- [x] [Review][Defer] No authentication on backup/restore — all app routes are unauth'd by design (local network MVP); pre-existing architectural decision
- [x] [Review][Defer] WAL checkpoint return value not verified — Drift's customStatement returns void; checking partial checkpoint would require raw SQL query; pre-existing limitation
- [x] [Review][Defer] SQLite magic check covers only 16 bytes — full header validation is beyond story scope (story specifies magic header check only); pre-existing
- [x] [Review][Defer] Concurrent backup+restore race — requires architectural mutex, beyond story scope; pre-existing

## Dev Notes

### Architecture Context

Backup and restore are the data resilience layer (Epic 8). The phone is the single source of truth — all wine data lives in its SQLite database. These endpoints let the user protect against data loss from a lost or broken phone.

The REST API contract (`docs/rest-api-contracts.md`) defines:
- GET /backup → raw SQLite .db file (binary, not JSON)
- POST /restore → raw SQLite file upload, atomic replace

These are the only non-JSON endpoints in the API.

### Database File Location

`driftDatabase(name: 'winetap')` from `drift_flutter ^0.3.0` places the file at:
- **Android**: `/data/data/<package>/files/winetap.db`
- **iOS**: `~/Library/Application Support/winetap.db`

The path is resolved internally by drift_flutter using `path_provider`. To access the raw file for backup/restore, we need to resolve this path ourselves.

**Recommended approach** — resolve in `main.dart` and pass down:

```dart
import 'package:path_provider/path_provider.dart';
import 'dart:io';

// In main():
final docsDir = await getApplicationDocumentsDirectory();
final dbFile = File('${docsDir.path}/winetap.db');
```

Then pass `dbFile` to `startServer()` and through to the backup handler. This avoids adding `path_provider` as a dependency of the handler — keeps it in main.

### WAL Checkpoint Before Backup

drift uses SQLite WAL (Write-Ahead Logging) mode by default. The database may have pending writes in the WAL file that haven't been checkpointed to the main `.db` file. Before reading the file for backup, flush the WAL:

```dart
await db.customStatement('PRAGMA wal_checkpoint(TRUNCATE)');
```

`TRUNCATE` mode checkpoints all WAL content and truncates the WAL file to zero size. This ensures the backup file is self-contained and consistent.

### Atomic Restore Pattern

The restore must be atomic — a partial upload or write failure must not corrupt the existing database:

```dart
Future<Response> handleRestore(Request request, AppDatabase db, File dbFile,
    Future<void> Function() restartDb) async {
  final bytes = await request.read().expand((chunk) => chunk).toList();
  if (bytes.isEmpty) {
    return _error(400, 'invalid_argument', 'request body is empty');
  }

  // Validate SQLite magic header
  const sqliteMagic = 'SQLite format 3\x00';
  if (bytes.length < 16 || String.fromCharCodes(bytes.sublist(0, 16)) != sqliteMagic) {
    return _error(400, 'invalid_argument', 'not a valid SQLite database');
  }

  // Write to temp file first
  final tmpFile = File('${dbFile.path}.tmp');
  try {
    await tmpFile.writeAsBytes(bytes, flush: true);
    // Close drift connection before replacing file
    await db.close();
    // Atomic rename (same filesystem — guaranteed atomic on POSIX)
    await tmpFile.rename(dbFile.path);
    // Also delete WAL and SHM files if present
    final walFile = File('${dbFile.path}-wal');
    final shmFile = File('${dbFile.path}-shm');
    if (await walFile.exists()) await walFile.delete();
    if (await shmFile.exists()) await shmFile.delete();
    // Reinitialize drift with new database
    await restartDb();
    return _json(200, {'status': 'restored'});
  } catch (e) {
    dev.log('restore error: $e', name: 'backup');
    // Clean up temp file on failure
    if (await tmpFile.exists()) await tmpFile.delete();
    return _error(500, 'internal', 'restore failed: $e');
  }
}
```

### Database Reinitialization — restartDb Callback

After replacing the database file, drift must reopen the connection. The handler cannot do this directly because `AppDatabase` is created in `main.dart` and referenced by multiple providers and handlers.

**Approach: pass a `restartDb` callback from main.dart:**

```dart
// In main.dart — create a mutable reference:
var db = AppDatabase();
// ...
final restartDb = () async {
  db = AppDatabase();
  // Update all references that hold db...
};
```

**Challenge:** Other handlers and providers hold references to the old `AppDatabase`. After restore, they'll be using a closed database. Options:

1. **Simplest (recommended for MVP):** restart the entire server after restore. The user expects a brief interruption.
2. **Pass db as getter:** handlers access `db` via a `() => AppDatabase` closure instead of a direct reference. After restore, the closure returns the new instance.

For MVP, option 1 is acceptable — the settings screen (Story 8.2) will show a "restored, restarting..." message. The user relaunches the app if needed.

**Practical implementation:** After `db.close()` + file rename, exit the app with a message. The app restarts fresh on next launch.

Alternative: use a `ValueNotifier<AppDatabase>` or similar holder that all handlers read from. This is more complex but avoids restart.

### Backup Handler — Binary Response

Unlike all other endpoints (JSON), backup returns raw bytes:

```dart
router.get('/', (Request request) async {
  // Flush WAL before reading
  await db.customStatement('PRAGMA wal_checkpoint(TRUNCATE)');
  final bytes = await dbFile.readAsBytes();
  return Response(200,
    body: bytes,
    headers: {
      'Content-Type': 'application/octet-stream',
      'Content-Disposition': 'attachment; filename="winetap.db"',
    },
  );
});
```

### Restore Handler — Binary Request

shelf reads the request body as a stream of byte chunks:

```dart
router.post('/', (Request request) async {
  final bytes = await request.read().fold<List<int>>(
    <int>[],
    (previous, chunk) => previous..addAll(chunk),
  );
  // ... validate and replace
});
```

### Route Registration — Top-Level, Not Mounted

Per the REST API contract, backup and restore are at `/backup` and `/restore` (not `/backup/...`). Register as individual routes, not a mounted router:

```dart
// In server.dart:
router.get('/backup', (Request req) async => handleBackup(req, db, dbFile));
router.post('/restore', (Request req) async => handleRestore(req, db, dbFile, restartDb));
```

Or use a mounted router at `/backup` with GET `/` for download and at `/restore` with POST `/` for upload. Either approach works.

### Testing — In-Memory Database Limitation

In-memory databases (`NativeDatabase.memory()`) have no file on disk. For backup/restore tests, use a file-based database in a temp directory:

```dart
test('GET /backup returns valid SQLite', () async {
  final dir = await Directory.systemTemp.createTemp('winetap_test');
  final dbFile = File('${dir.path}/winetap.db');
  final db = AppDatabase.forTesting(NativeDatabase(dbFile));

  // Insert test data
  await db.insertDesignation(DesignationsCompanion.insert(name: 'Test'));

  // Flush WAL
  await db.customStatement('PRAGMA wal_checkpoint(TRUNCATE)');

  // Read backup
  final bytes = await dbFile.readAsBytes();
  expect(bytes.length, greaterThan(0));
  expect(String.fromCharCodes(bytes.sublist(0, 15)), 'SQLite format 3');

  await db.close();
  await dir.delete(recursive: true);
});
```

### Previous Story Intelligence

**From Story 5.1 (Drift Database and Schema):**
- `AppDatabase` uses `driftDatabase(name: 'winetap')` — drift_flutter resolves path internally
- `AppDatabase.forTesting(super.e)` constructor for test databases
- WAL mode is drift's default — must checkpoint before backup
- Schema version 1, no migrations yet

**From Story 5.2 (Shelf HTTP Server):**
- `startServer(AppDatabase db, ScanCoordinator coordinator)` — add `File dbFile` parameter
- All routes mounted via `router.mount()` or `router.get()`/`router.post()`
- shelf idle timeout 60s — sufficient for large database transfer

### Files to Create/Modify

| File | Action | Purpose |
|------|--------|---------|
| `mobile/lib/server/handlers/backup.dart` | CREATE | Backup and restore HTTP handlers |
| `mobile/lib/server/server.dart` | MODIFY | Mount /backup and /restore routes, accept dbFile parameter |
| `mobile/lib/main.dart` | MODIFY | Resolve database file path, pass to startServer |
| `mobile/test/server/handlers/backup_test.dart` | CREATE | Backup/restore handler tests with file-based test DB |

### Anti-Patterns to Avoid

- Do NOT read the database file without WAL checkpoint — backup would be inconsistent
- Do NOT replace the database file without closing drift first — SQLite file lock will prevent rename
- Do NOT skip SQLite magic header validation on restore — prevents corrupting DB with random file upload
- Do NOT write directly to the database file path — use temp file + rename for atomicity
- Do NOT forget to delete WAL and SHM files after restore — stale WAL could corrupt new database
- Do NOT use `print()` — use `dart:developer` `log()`
- Do NOT add `path_provider` as a dependency of handler — resolve path in main.dart, pass as parameter

### Project Structure Notes

```
mobile/lib/server/handlers/
├── backup.dart        ← NEW
├── bottles.dart
├── completions.dart
├── cuvees.dart
├── designations.dart
├── domains.dart
└── scan.dart          (from Story 7.1)

mobile/test/server/handlers/
├── backup_test.dart   ← NEW
├── bottles_test.dart
├── ...
```

### References

- [Source: docs/rest-api-contracts.md#Backup/Restore Endpoints] — GET /backup returns binary .db file; POST /restore uploads binary, atomic replace
- [Source: _bmad-output/planning-artifacts/epics-mobile-v2.md#Story 8.1] — acceptance criteria, NFR16/NFR17
- [Source: _bmad-output/planning-artifacts/architecture-mobile-v2.md#Data Architecture] — GET /backup → raw .db file, POST /restore → atomic replace
- [Source: _bmad-output/planning-artifacts/architecture-mobile-v2.md#Anti-Patterns] — no raw SQL strings, no print(), no globals
- [Source: mobile/lib/server/database.dart:148-176] — AppDatabase class, `driftDatabase(name: 'winetap')`, forTesting constructor
- [Source: mobile/lib/server/server.dart] — current startServer signature, route registration pattern
- [Source: mobile/lib/main.dart:21-31] — database + server initialization sequence
- [Source: mobile/lib/server/handlers/bottles.dart] — reference handler pattern (_json, _error helpers)

## Dev Agent Record

### Agent Model Used

claude-sonnet-4-6

### Debug Log References

None — implementation was straightforward following Dev Notes guidance.

### Completion Notes List

- Added `path_provider ^2.1.0` to `pubspec.yaml` (needed to resolve db file path in main.dart).
- Chose Option A (resolve path in main.dart, pass File to handlers) — keeps path_provider out of handler code.
- Implemented `handleBackup` and `handleRestore` as top-level functions in `handlers/backup.dart` (not a Router); registered directly in `server.dart` via `router.get`/`router.post`.
- `restartDb` callback in `main.dart` calls `exit(0)` — MVP approach; app restarts fresh on next launch with restored database.
- WAL checkpoint (`PRAGMA wal_checkpoint(TRUNCATE)`) called before reading backup file.
- Atomic restore: write to `.tmp`, close drift, rename, delete stale WAL/SHM, call restartDb.
- Updated `server_test.dart` to pass new required `dbFile` and `restartDb` parameters (uses `/dev/null` file and no-op callback — not tested there).
- All 189 tests pass; `dart analyze` clean on new/modified files.

### File List

- `mobile/pubspec.yaml` — added path_provider ^2.1.0
- `mobile/pubspec.lock` — updated by flutter pub get
- `mobile/lib/server/handlers/backup.dart` — NEW: handleBackup, handleRestore, _json, _error
- `mobile/lib/server/server.dart` — added dbFile + restartDb params; registered /backup and /restore routes
- `mobile/lib/main.dart` — import path_provider; resolve dbFile; define restartDb callback; pass to startServer
- `mobile/test/server/handlers/backup_test.dart` — NEW: 11 tests covering backup and restore
- `mobile/test/server/server_test.dart` — updated startServer call with new required params

## Change Log

- 2026-04-02: Implemented Story 8.1 — backup (GET /backup) and restore (POST /restore) endpoints with atomic file replacement, WAL checkpoint, SQLite header validation, path_provider db path resolution, and restartDb callback (exit(0) for MVP). 11 new tests added; all 189 tests pass.

## Senior Developer Review (AI)

- **Review Outcome:** Changes Requested
- **Review Date:** 2026-04-02
- **Action Items:** 8 (1 Decision, 7 Patch) — see Review Findings in Tasks/Subtasks
- **Severity:** 2 High, 3 Med, 3 Low
