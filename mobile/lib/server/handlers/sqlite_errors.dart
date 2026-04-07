import 'dart:convert';
import 'dart:developer' as dev;

import 'package:drift/isolate.dart' show DriftRemoteException;
import 'package:shelf/shelf.dart';
import 'package:sqlite3/sqlite3.dart' show SqliteException;

/// Extended result codes from SQLite.
/// See https://sqlite.org/rescode.html
const _sqliteConstraintUnique = 2067;
const _sqliteConstraintPrimaryKey = 1555;
const _sqliteConstraintForeignKey = 787;

/// Extracts a [SqliteException] from [error], which may be thrown directly
/// (in-memory / same-isolate) or wrapped in a [DriftRemoteException]
/// (background isolate via [driftDatabase]).
SqliteException? extractSqliteException(Object error) {
  if (error is SqliteException) return error;
  if (error is DriftRemoteException) {
    final cause = error.remoteCause;
    if (cause is SqliteException) return cause;
  }
  return null;
}

/// Wraps a database operation and maps SQLite constraint errors to HTTP
/// error responses with the appropriate status code and error code.
///
/// - UNIQUE / PRIMARY KEY violation → 400 `already_exists`
/// - FOREIGN KEY violation → 412 `referenced`
/// - Any other error → 500 `internal` (logged via [logTag])
Future<Response> guardDb(
  Future<Response> Function() action, {
  required String logTag,
}) async {
  try {
    return await action();
  } catch (e) {
    final sqlite = extractSqliteException(e);
    if (sqlite != null) {
      final code = sqlite.extendedResultCode;
      if (code == _sqliteConstraintUnique ||
          code == _sqliteConstraintPrimaryKey) {
        return _error(400, 'already_exists', sqlite.message);
      }
      if (code == _sqliteConstraintForeignKey) {
        return _error(412, 'referenced', sqlite.message);
      }
    }
    dev.log('$logTag error: $e', name: logTag);
    return _error(500, 'internal', e.toString());
  }
}

Response _error(int status, String code, String message) => Response(
      status,
      body: jsonEncode({'error': code, 'message': message}),
      headers: {'Content-Type': 'application/json'},
    );
