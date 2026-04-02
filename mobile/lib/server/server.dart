import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

import 'consume_tracker.dart';
import 'database.dart';
import 'handlers/backup.dart';
import 'handlers/bottles.dart';
import 'handlers/completions.dart';
import 'handlers/cuvees.dart';
import 'handlers/designations.dart';
import 'handlers/domains.dart';
import 'handlers/scan.dart';
import 'middleware/wakelock.dart';
import 'scan_coordinator.dart';

/// Starts the shelf HTTP server on port 8080.
///
/// Database and ScanCoordinator are passed as parameters — no globals.
/// [dbFile] is the resolved path to the SQLite database file (for backup/restore).
/// [restartDb] is called after a successful restore to reinitialize the database.
/// Set [enableWakelock] to false in tests (WakelockPlus needs platform channels).
/// Returns the running [HttpServer] instance.
Future<HttpServer> startServer(
  AppDatabase db,
  ScanCoordinator coordinator,
  File dbFile,
  Future<void> Function() restartDb,
  ConsumeTracker consumeTracker, {
  bool enableWakelock = true,
  int port = 8080,
}) async {
  final router = Router();

  // Health check
  router.get('/', (Request request) {
    return Response.ok(
      '{"status":"ok","last_consumed_at":${consumeTracker.lastConsumedAt}}',
      headers: {'Content-Type': 'application/json'},
    );
  });

  // Catalog REST API (Story 5.3)
  router.mount('/designations', designationsRouter(db).call);
  router.mount('/domains', domainsRouter(db).call);
  router.mount('/cuvees', cuveesRouter(db).call);
  router.mount('/bottles', bottlesRouter(db, consumeTracker).call);
  router.mount('/completions', completionsRouter(db).call);
  router.mount('/scan', scanRouter(coordinator).call);

  // Data resilience (Story 8.1)
  router.get('/backup',
      (Request req) => handleBackup(req, db, dbFile));
  router.post('/restore',
      (Request req) => handleRestore(req, db, dbFile, restartDb));

  var pipeline = const Pipeline();
  if (enableWakelock) {
    pipeline = pipeline.addMiddleware(wakelockMiddleware());
  }
  final handler = pipeline.addHandler(router.call);

  final server = await shelf_io.serve(
    handler,
    InternetAddress.anyIPv4,
    port,
    shared: true,
  );
  server.idleTimeout = const Duration(seconds: 60);
  return server;
}
