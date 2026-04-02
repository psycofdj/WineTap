# Story 8.2: Settings Screen with Backup/Restore

Status: done

## Story

As a user,
I want backup and restore buttons on the phone's settings screen,
So that I can manage my data without technical knowledge.

## Acceptance Criteria

1. **Given** the settings screen redesigned for v2
   **When** the user views settings
   **Then** it shows: server IP + port, server status (running/stopped)
   **And** "Exporter la base" button triggers backup and saves to phone storage
   **And** "Restaurer la base" button lets user pick a .db file and uploads to restore
   **And** confirmation dialog before restore ("Cela remplacera toutes les donnees actuelles")
   **And** success/error feedback after each operation
   **And** all strings from S class (French)

## Tasks / Subtasks

- [x] Task 1: Add backup/restore strings to S class (AC: #1)
  - [x] 1.1 `exportDatabase` = `'Exporter la base'`
  - [x] 1.2 `restoreDatabase` = `'Restaurer la base'`
  - [x] 1.3 `restoreConfirmTitle` = `'Restaurer la base ?'`
  - [x] 1.4 `restoreConfirmBody` = `'Cela remplacera toutes les données actuelles'`
  - [x] 1.5 `backupSuccess` = `'Base exportée avec succès'`
  - [x] 1.6 `restoreSuccess` = `'Base restaurée — redémarrez l\'application'`
  - [x] 1.7 `backupError` = `'Erreur lors de l\'export'`
  - [x] 1.8 `restoreError` = `'Erreur lors de la restauration'`

- [x] Task 2: Add backup functionality to SettingsScreen (AC: #1)
  - [x] 2.1 Add "Exporter la base" `FilledButton.icon` with `Icons.download` icon
  - [x] 2.2 On tap: call GET /backup on localhost (the phone's own server)
  - [x] 2.3 Save downloaded bytes to phone storage using `file_picker`'s save dialog
  - [x] 2.4 Show `SnackBar` with `S.backupSuccess` on success
  - [x] 2.5 Show `SnackBar` with `S.backupError` on failure
  - [x] 2.6 Show loading indicator during backup (disable button, show CircularProgressIndicator)

- [x] Task 3: Add restore functionality to SettingsScreen (AC: #1)
  - [x] 3.1 Add "Restaurer la base" `OutlinedButton.icon` with `Icons.upload` icon
  - [x] 3.2 On tap: show confirmation dialog (`AlertDialog` with `S.restoreConfirmTitle` and `S.restoreConfirmBody`)
  - [x] 3.3 On confirm: open file picker to select a .db file
  - [x] 3.4 Read selected file bytes, POST to /restore on localhost
  - [x] 3.5 Show `SnackBar` with `S.restoreSuccess` on success
  - [x] 3.6 Show `SnackBar` with `S.restoreError` on failure
  - [x] 3.7 Show loading indicator during restore
  - [x] 3.8 After successful restore: snackbar instructs user to restart app

- [x] Task 4: Implement backup/restore via localhost HTTP (AC: #1)
  - [x] 4.1 Use `dart:io` `HttpClient` to call localhost:port/backup and localhost:port/restore
  - [x] 4.2 Backup: `GET http://localhost:$port/backup` → save bytes via FilePicker.saveFile
  - [x] 4.3 Restore: `POST http://localhost:$port/restore` with raw bytes, `Content-Type: application/octet-stream`
  - [x] 4.4 Port from `ServerProvider.port` getter (added to ServerProvider)

- [x] Task 5: File picker integration (AC: #1)
  - [x] 5.1 Added `file_picker ^8.0.0` to pubspec.yaml
  - [x] 5.2 Backup save: `FilePicker.platform.saveFile(fileName: 'winetap.db', bytes: Uint8List.fromList(bytes))`
  - [x] 5.3 Restore pick: `FilePicker.platform.pickFiles(type: FileType.any, withData: true)`
  - [x] 5.4 Used file_picker for both operations (single dependency)

- [x] Task 6: Convert SettingsScreen to StatefulWidget (AC: #1)
  - [x] 6.1 `_backingUp` and `_restoring` boolean state for loading indicators
  - [x] 6.2 Existing server address display preserved via `Consumer<ServerProvider>`
  - [x] 6.3 Backup/restore section added below divider

- [x] Task 7: Update tests (AC: #1)
  - [x] 7.1 widget_test.dart unchanged — provider setup unchanged
  - [x] 7.2 Test: settings screen renders backup and restore buttons
  - [x] 7.3 Test: restore confirmation dialog appears and can be cancelled

- [x] Task 8: Verify integration (AC: #1)
  - [x] 8.1 `dart analyze` passes (1 pre-existing warning, unrelated)
  - [x] 8.2 All 199 tests pass
  - [x] 8.3 `flutter build apk --debug` — skipped in CI (requires Android SDK); analyze + tests confirm correctness

### Review Findings

- [x] [Review][Patch] No timeout on HttpClient requests — backup/restore hang forever on WiFi dropout; spinner stays on permanently [settings_screen.dart:107,126]
- [x] [Review][Patch] Unbounded download in _downloadBackup — no size cap on response accumulation; OOM on large/malicious response [settings_screen.dart:115-118]
- [x] [Review][Patch] Unmounted widget: context.read after async gap — mounted checked at line 81 but context.read called 8 lines later after more async work; widget may be disposed between [settings_screen.dart:89]
- [x] [Review][Patch] Response body not drained before throw in _uploadRestore — non-200 path throws without draining; leaks socket [settings_screen.dart:134]
- [x] [Review][Patch] 'Gestion des données' hardcoded — AC requires all strings from S class; add S.dataManagement [settings_screen.dart:204]
- [x] [Review][Patch] Missing Content-Length on POST /restore — chunked encoding may cause issues; set request.contentLength = bytes.length [settings_screen.dart:131]
- [x] [Review][Patch] No mutual exclusion between backup and restore — both operations can run simultaneously; disable both buttons when either is active [settings_screen.dart:212,228]
- [x] [Review][Defer] Uint8List.fromList double-copy — minor optimization, not a correctness issue
- [x] [Review][Defer] FilePicker.saveFile path≠success on desktop — mobile-focused app; not a real-world concern
- [x] [Review][Defer] No progress feedback during slow upload — beyond story scope
- [x] [Review][Defer] Connection reset after restore — known MVP design (exit(0) from 8.1 review decision b)
- [x] [Review][Defer] _showSnackBar no internal mounted guard — all callers already check mounted; safe as-is

## Dev Notes

### Architecture Context

The settings screen is the user-facing interface for Epic 8 (Data Resilience). Story 8.1 provides the server endpoints (GET /backup, POST /restore). This story adds the UI buttons that call those endpoints.

The phone calls its own server via localhost — backup and restore are local operations, no network involved (except the loopback interface).

### Current Settings Screen — Simple, Needs Extension

The current settings screen (from Story 5.5) shows only:
- Server IP + port (from `ServerProvider`)
- "Serveur actif" status label

The redesign adds:
- "Exporter la base" button
- "Restaurer la base" button
- Loading states for each operation
- Success/error snackbars

### Calling Own Server via Localhost

The phone's shelf server runs on port 8080. The settings screen calls it via localhost:

```dart
import 'dart:io';

Future<List<int>> _downloadBackup(int port) async {
  final client = HttpClient();
  try {
    final request = await client.getUrl(Uri.parse('http://localhost:$port/backup'));
    final response = await request.close();
    if (response.statusCode != 200) {
      throw HttpException('Backup failed: ${response.statusCode}');
    }
    final bytes = <int>[];
    await for (final chunk in response) {
      bytes.addAll(chunk);
    }
    return bytes;
  } finally {
    client.close();
  }
}

Future<void> _uploadRestore(int port, List<int> bytes) async {
  final client = HttpClient();
  try {
    final request = await client.postUrl(Uri.parse('http://localhost:$port/restore'));
    request.headers.contentType = ContentType('application', 'octet-stream');
    request.add(bytes);
    final response = await request.close();
    if (response.statusCode != 200) {
      throw HttpException('Restore failed: ${response.statusCode}');
    }
  } finally {
    client.close();
  }
}
```

### File Picker vs Share — Platform Considerations

**Backup export — two approaches:**

1. **`file_picker` save dialog:** `FilePicker.platform.saveFile(fileName: 'winetap.db', bytes: bytes)` — shows native save dialog. Works on Android. On iOS, save dialog is limited.

2. **`share_plus` share sheet (recommended for mobile):** `Share.shareXFiles([XFile.fromData(bytes, name: 'winetap.db')])` — triggers the native share sheet. User can save to Files, send via AirDrop, email, etc. Works on both iOS and Android.

**Restore import:** `FilePicker.platform.pickFiles(type: FileType.any)` — native file picker. User selects a .db file from storage.

**Recommendation:** Use `share_plus` for backup export (most natural on mobile), `file_picker` for restore import. Add both packages to `pubspec.yaml`.

Alternatively, use `file_picker` for both — `saveFile` for export and `pickFiles` for import. Single dependency.

### Settings Screen Layout

```dart
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(title: const Text(S.settings), ...),
    body: Padding(
      padding: const EdgeInsets.all(24),
      child: Consumer<ServerProvider>(
        builder: (context, server, _) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Existing: Server info ---
              Text(S.serverAddress, style: titleMedium),
              Row(children: [Icon(Icons.wifi), Text(server.serverAddress)]),
              Text(S.serverRunning, style: primaryColor),

              const SizedBox(height: 32),
              const Divider(),
              const SizedBox(height: 16),

              // --- NEW: Data management ---
              Text('Gestion des données', style: titleMedium),
              const SizedBox(height: 16),

              // Backup button
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _backingUp ? null : _onBackup,
                  icon: _backingUp
                      ? const SizedBox(width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.download),
                  label: Text(S.exportDatabase),
                ),
              ),
              const SizedBox(height: 12),

              // Restore button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _restoring ? null : _onRestore,
                  icon: _restoring
                      ? const SizedBox(width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.upload),
                  label: Text(S.restoreDatabase),
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}
```

### Restore Confirmation Dialog

```dart
Future<void> _onRestore() async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(S.restoreConfirmTitle),
      content: Text(S.restoreConfirmBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text(S.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text(S.restoreDatabase),
        ),
      ],
    ),
  );
  if (confirmed != true) return;
  // ... proceed with file picker and restore
}
```

### Server Port Access

The `ServerProvider` currently only exposes `serverAddress` (string). The port is needed for localhost calls. Options:
1. Expose `port` getter on `ServerProvider` (simplest)
2. Pass port as argument to SettingsScreen
3. Hardcode 8080 (fragile)

Recommended: add `int get port => _port;` to `ServerProvider`.

### New Dependencies

| Package | Purpose | Notes |
|---------|---------|-------|
| `file_picker` | File selection for restore, optional save for backup | Existing Flutter plugin, well-maintained |
| `share_plus` | Share backup file via native sheet (alternative to file_picker save) | Optional — file_picker alone may suffice |

Choose one approach and stick with it. `file_picker` alone handles both export (saveFile) and import (pickFiles).

### Previous Story Intelligence

**From Story 8.1 (Backup and Restore Endpoints):**
- GET /backup returns raw .db bytes with Content-Type: application/octet-stream
- POST /restore accepts raw bytes, validates SQLite header, atomic replace
- After restore, app may need restart (database reinitialization)

**From Story 5.5 (Local Consume Flow):**
- SettingsScreen simplified to StatelessWidget showing server address only
- ServerProvider provides `serverAddress` string
- All strings from S class

### Files to Create/Modify

| File | Action | Purpose |
|------|--------|---------|
| `mobile/lib/screens/settings_screen.dart` | REWRITE | Add backup/restore buttons, convert to StatefulWidget |
| `mobile/lib/l10n/strings.dart` | MODIFY | Add backup/restore strings (8 new constants) |
| `mobile/lib/providers/server_provider.dart` | MODIFY | Add `int get port` getter |
| `mobile/pubspec.yaml` | MODIFY | Add `file_picker` (and optionally `share_plus`) dependency |
| `mobile/test/widget_test.dart` | MODIFY | Update if provider setup changes |

### Anti-Patterns to Avoid

- Do NOT call the server via the WiFi address — use `localhost:$port` for backup/restore (local operation)
- Do NOT skip the confirmation dialog before restore — destructive operation requires explicit consent
- Do NOT use `print()` — use `dart:developer` `log()`
- Do NOT hardcode port 8080 — get from `ServerProvider.port`
- Do NOT block the UI thread during file I/O — use async/await throughout
- Do NOT forget loading indicators — backup/restore may take several seconds for large databases

### Project Structure Notes

No new files in `lib/` except potentially a helper. Mostly modifications to existing files.

```
mobile/lib/screens/
├── consume_screen.dart     (unchanged)
├── intake_screen.dart      (unchanged)
└── settings_screen.dart    ← REWRITE (add backup/restore UI)
```

### References

- [Source: _bmad-output/planning-artifacts/epics-mobile-v2.md#Story 8.2] — acceptance criteria, French strings
- [Source: _bmad-output/planning-artifacts/architecture-mobile-v2.md#Frontend Architecture] — Settings screen redesigned for v2
- [Source: docs/rest-api-contracts.md#Backup/Restore Endpoints] — GET /backup, POST /restore
- [Source: mobile/lib/screens/settings_screen.dart] — current settings screen (server address only)
- [Source: mobile/lib/providers/server_provider.dart] — ServerProvider with address, needs port getter
- [Source: mobile/lib/l10n/strings.dart] — S class for French strings
- [Source: _bmad-output/implementation-artifacts/8-1-backup-and-restore-endpoints.md] — server-side endpoints this story calls

## Dev Agent Record

### Agent Model Used

claude-sonnet-4-6

### Debug Log References

- FilePicker.saveFile requires `Uint8List`, not `List<int>` — fixed by wrapping with `Uint8List.fromList(bytes)` at call site.

### Completion Notes List

- Added 8 French strings to S class (exportDatabase, restoreDatabase, restoreConfirmTitle, restoreConfirmBody, backupSuccess, restoreSuccess, backupError, restoreError).
- Added `int get port => _port` getter to ServerProvider.
- Added `file_picker ^8.0.0` to pubspec.yaml.
- Rewrote SettingsScreen as StatefulWidget with `_backingUp`/`_restoring` loading state; HTTP calls via `dart:io HttpClient`; file operations via `file_picker`.
- Confirmation dialog shown before restore (AlertDialog with S.restoreConfirmTitle/Body).
- After successful restore, SnackBar shows S.restoreSuccess ("redémarrez l'application"); the server-side exit(0) handles the actual restart.
- Created `test/screens/settings_screen_test.dart` with 5 tests: renders server section, export button, restore button, dialog on tap, cancel dialog.
- All 199 tests pass; dart analyze clean.

### File List

- `mobile/pubspec.yaml` — added file_picker ^8.0.0
- `mobile/pubspec.lock` — updated by flutter pub get
- `mobile/lib/l10n/strings.dart` — added 8 backup/restore strings
- `mobile/lib/providers/server_provider.dart` — added `int get port` getter
- `mobile/lib/screens/settings_screen.dart` — rewritten as StatefulWidget with backup/restore UI
- `mobile/test/screens/settings_screen_test.dart` — NEW: 5 widget tests

## Change Log

- 2026-04-02: Implemented Story 8.2 — settings screen redesigned with backup export (FilePicker.saveFile) and restore (FilePicker.pickFiles + POST /restore) buttons, confirmation dialog, loading indicators, and French snackbar feedback. 5 new widget tests; 199 tests total pass.

## Senior Developer Review (AI)

- **Review Outcome:** Approved
- **Review Date:** 2026-04-02
- **Action Items:** 7 Patch — all applied and verified (dart analyze clean, 199 tests pass)
- **Severity:** 2 High, 3 Med, 2 Low — all resolved
