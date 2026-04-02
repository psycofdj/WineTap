import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wine_tap_mobile/server/consume_tracker.dart';
import 'package:wine_tap_mobile/server/database.dart';
import 'package:wine_tap_mobile/server/scan_coordinator.dart';
import 'package:wine_tap_mobile/server/server.dart';

void main() {
  late AppDatabase db;
  late ScanCoordinator coordinator;
  late HttpServer server;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    coordinator = ScanCoordinator(
      timeout: const Duration(milliseconds: 100),
    );
    final dbFile = File('/dev/null'); // unused in server tests
    server = await startServer(db, coordinator, dbFile, () async {},
        ConsumeTracker(),
        enableWakelock: false, port: 0);
  });

  tearDown(() async {
    await server.close(force: true);
    await db.close();
  });

  group('Server', () {
    test('health check returns 200 with status ok', () async {
      final client = HttpClient();
      try {
        final request =
            await client.get('localhost', server.port, '/');
        final response = await request.close();
        expect(response.statusCode, 200);

        final body =
            jsonDecode(await response.transform(utf8.decoder).join());
        expect(body['status'], 'ok');
        expect(body['last_consumed_at'], 0);
      } finally {
        client.close();
      }
    });

    test('unknown route returns 404', () async {
      final client = HttpClient();
      try {
        final request =
            await client.get('localhost', server.port, '/nonexistent');
        final response = await request.close();
        expect(response.statusCode, 404);
      } finally {
        client.close();
      }
    });

    test('server idle timeout is at least 60s', () {
      expect(
        server.idleTimeout!.inSeconds,
        greaterThanOrEqualTo(60),
      );
    });
  });
}
