import 'package:drift/isolate.dart' show DriftRemoteException;
import 'package:sqlite3/sqlite3.dart' show SqliteException;

/// Extended result codes from SQLite (https://sqlite.org/rescode.html).
const sqliteConstraintUnique = 2067;
const sqliteConstraintPrimaryKey = 1555;
const sqliteConstraintForeignKey = 787;

/// Extracts a [SqliteException] from [error], which may be thrown directly
/// (in-memory / same isolate) or wrapped in a [DriftRemoteException]
/// (background isolate via `driftDatabase`).
SqliteException? extractSqliteException(Object error) {
  if (error is SqliteException) return error;
  if (error is DriftRemoteException) {
    final cause = error.remoteCause;
    if (cause is SqliteException) return cause;
  }
  return null;
}
