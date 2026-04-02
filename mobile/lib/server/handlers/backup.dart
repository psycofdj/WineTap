import 'dart:convert';
import 'dart:developer' as dev;
import 'dart:io';

import 'package:shelf/shelf.dart';

import '../database.dart';

/// Maximum allowed upload size for POST /restore (100 MB).
const _maxRestoreBytes = 100 * 1024 * 1024;

/// GET /backup — returns the raw SQLite .db file.
///
/// Flushes the WAL before reading to ensure backup is self-contained.
/// Returns 503 if the database file does not yet exist (fresh install).
Future<Response> handleBackup(
    Request request, AppDatabase db, File dbFile) async {
  if (!await dbFile.exists()) {
    return _error(503, 'unavailable', 'database not yet initialized');
  }
  await db.customStatement('PRAGMA wal_checkpoint(TRUNCATE)');
  final bytes = await dbFile.readAsBytes();
  return Response(
    200,
    body: bytes,
    headers: {
      'Content-Type': 'application/octet-stream',
      'Content-Disposition': 'attachment; filename="winetap.db"',
      'Content-Length': '${bytes.length}',
    },
  );
}

/// POST /restore — replaces the current database atomically.
///
/// Validates the SQLite magic header, writes to a temp file, preserves the
/// original as `.bak` before replacing so it can be recovered if the rename
/// fails, then calls [restartDb] to reinitialize the database connection.
///
/// On any error: returns 400/500 and attempts to restore the original database.
Future<Response> handleRestore(
  Request request,
  AppDatabase db,
  File dbFile,
  Future<void> Function() restartDb,
) async {
  // Read with 100 MB cap to prevent OOM from oversized uploads.
  final List<int> bytes;
  try {
    bytes = await request.read().fold<List<int>>(
      <int>[],
      (buf, chunk) {
        if (buf.length + chunk.length > _maxRestoreBytes) {
          throw const _BodyTooLargeException();
        }
        return buf..addAll(chunk);
      },
    );
  } on _BodyTooLargeException {
    return _error(413, 'payload_too_large', 'upload exceeds 100 MB limit');
  }

  if (bytes.isEmpty) {
    return _error(400, 'invalid_argument', 'request body is empty');
  }

  const sqliteMagic = 'SQLite format 3\x00';
  if (bytes.length < 16 ||
      String.fromCharCodes(bytes.sublist(0, 16)) != sqliteMagic) {
    return _error(400, 'invalid_argument', 'not a valid SQLite database');
  }

  final tmpFile = File('${dbFile.path}.tmp');
  final bakFile = File('${dbFile.path}.bak');
  try {
    await tmpFile.writeAsBytes(bytes, flush: true);
    await db.close();
    // Preserve original as .bak — allows recovery if the rename below fails.
    if (await dbFile.exists()) await dbFile.rename(bakFile.path);
    await tmpFile.rename(dbFile.path);
    // Remove stale WAL and SHM files — they belong to the old database.
    final walFile = File('${dbFile.path}-wal');
    final shmFile = File('${dbFile.path}-shm');
    if (await walFile.exists()) await walFile.delete();
    if (await shmFile.exists()) await shmFile.delete();
    // Clean up backup file before restart.
    try {
      if (await bakFile.exists()) await bakFile.delete();
    } catch (e) {
      dev.log('bak cleanup failed (non-fatal): $e', name: 'backup');
    }
    await restartDb();
    return _json(200, {'status': 'restored'});
  } catch (e) {
    dev.log('restore error: $e', name: 'backup');
    // Attempt to recover original database from .bak if dbFile was displaced.
    if (!await dbFile.exists() && await bakFile.exists()) {
      try {
        await bakFile.rename(dbFile.path);
        dev.log('original database recovered from .bak', name: 'backup');
      } catch (re) {
        dev.log('recovery rename failed: $re', name: 'backup');
      }
    }
    try {
      if (await tmpFile.exists()) await tmpFile.delete();
    } catch (ce) {
      dev.log('tmp cleanup failed: $ce', name: 'backup');
    }
    return _error(500, 'internal', 'restore failed');
  }
}

Response _json(int status, Object body) => Response(
      status,
      body: jsonEncode(body),
      headers: {'Content-Type': 'application/json'},
    );

Response _error(int status, String code, String message) =>
    _json(status, {'error': code, 'message': message});

class _BodyTooLargeException implements Exception {
  const _BodyTooLargeException();
}
