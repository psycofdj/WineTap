import 'dart:developer' as dev;
import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

import 'database.dart';

/// Result of [inspectBackup].
class BackupInfo {
  const BackupInfo(this.inStock);

  /// Number of in-stock bottles in the file.
  final int inStock;
}

/// Tables a WineTap database file must contain (schema unchanged, C-01).
const _requiredTables = {'designations', 'domains', 'cuvees', 'bottles'};

/// Highest schema version this app can open.
const _maxSchemaVersion = 2;

/// Checks that [bytes] are a WineTap database. Returns null otherwise.
///
/// The file is written to a temporary path and opened read-only: nothing is
/// modified.
Future<BackupInfo?> inspectBackup(List<int> bytes) async {
  const magic = 'SQLite format 3\x00';
  if (bytes.length < 100 ||
      String.fromCharCodes(bytes.sublist(0, 16)) != magic) {
    return null;
  }
  final dir = await Directory.systemTemp.createTemp('winetap-inspect');
  final file = File('${dir.path}/backup.db');
  try {
    await file.writeAsBytes(bytes, flush: true);
    final db = sqlite3.open(file.path, mode: OpenMode.readOnly);
    try {
      final tables = db
          .select("SELECT name FROM sqlite_master WHERE type = 'table'")
          .map((r) => r['name'] as String)
          .toSet();
      if (!tables.containsAll(_requiredTables)) return null;
      if (db.userVersion > _maxSchemaVersion) return null;
      final count = db.select(
        'SELECT COUNT(*) AS n FROM bottles WHERE consumed_at IS NULL',
      );
      return BackupInfo(count.first['n'] as int);
    } finally {
      db.close();
    }
  } catch (e) {
    dev.log('inspectBackup: $e', name: 'DbHolder');
    return null;
  } finally {
    try {
      await dir.delete(recursive: true);
    } catch (_) {}
  }
}

/// Holds the open database; the database can be replaced in place by a
/// restore, without restarting the app.
class DbHolder {
  DbHolder(this._db, this.dbFile, this._open);

  AppDatabase _db;
  final File dbFile;
  final AppDatabase Function() _open;

  AppDatabase get db => _db;

  /// Integrates the WAL into the main file and returns its content.
  Future<List<int>> backup() async {
    await _db.customStatement('PRAGMA wal_checkpoint(TRUNCATE)');
    return dbFile.readAsBytes();
  }

  /// Replaces the database file with [bytes] (already checked by
  /// [inspectBackup]) and reopens it. Migrations run on reopening.
  Future<void> replace(List<int> bytes) async {
    final tmp = File('${dbFile.path}.tmp');
    final bak = File('${dbFile.path}.bak');
    await tmp.writeAsBytes(bytes, flush: true);
    await _db.close();
    try {
      if (await dbFile.exists()) await dbFile.rename(bak.path);
      await tmp.rename(dbFile.path);
      for (final suffix in ['-wal', '-shm']) {
        final f = File('${dbFile.path}$suffix');
        if (await f.exists()) await f.delete();
      }
      if (await bak.exists()) await bak.delete();
    } catch (e) {
      dev.log('replace failed, restoring original: $e', name: 'DbHolder');
      if (!await dbFile.exists() && await bak.exists()) {
        await bak.rename(dbFile.path);
      }
      if (await tmp.exists()) await tmp.delete();
      _db = _open();
      rethrow;
    }
    _db = _open();
    // Materialize the connection so migrations run now.
    await _db.customSelect('SELECT 1').get();
  }
}
