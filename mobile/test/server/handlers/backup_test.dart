import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shelf/shelf.dart';
import 'package:wine_tap_mobile/server/database.dart';
import 'package:wine_tap_mobile/server/handlers/backup.dart';

void main() {
  late Directory tempDir;
  late File dbFile;
  late AppDatabase db;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('winetap_backup_test');
    dbFile = File('${tempDir.path}/winetap.db');
    db = AppDatabase.forTesting(NativeDatabase(dbFile));
    // Ensure schema is created by performing a query.
    await db.listDesignations();
  });

  tearDown(() async {
    // db may already be closed by restore handler; ignore double-close.
    try {
      await db.close();
    } catch (_) {}
    await tempDir.delete(recursive: true);
  });

  Future<Response> getBackup() => handleBackup(
        Request('GET', Uri.parse('http://localhost/backup')),
        db,
        dbFile,
      );

  Future<Response> postRestore(List<int> bytes,
      {Future<void> Function()? restartDb}) {
    return handleRestore(
      Request('POST', Uri.parse('http://localhost/restore'), body: bytes),
      db,
      dbFile,
      restartDb ?? () async {},
    );
  }

  group('GET /backup', () {
    test('returns 200 with application/octet-stream content-type', () async {
      final response = await getBackup();
      expect(response.statusCode, 200);
      expect(response.headers['content-type'], 'application/octet-stream');
    });

    test('returns correct content-disposition header', () async {
      final response = await getBackup();
      expect(response.headers['content-disposition'],
          'attachment; filename="winetap.db"');
    });

    test('returns content-length header matching body size', () async {
      final response = await getBackup();
      final bytes = await response.read().fold<List<int>>(
            <int>[],
            (prev, chunk) => prev..addAll(chunk),
          );
      expect(response.headers['content-length'], '${bytes.length}');
    });

    test('returned bytes are non-empty', () async {
      final response = await getBackup();
      final bytes = await response.read().fold<List<int>>(
            <int>[],
            (prev, chunk) => prev..addAll(chunk),
          );
      expect(bytes, isNotEmpty);
    });

    test('returned bytes start with SQLite magic header', () async {
      await db.customStatement('PRAGMA wal_checkpoint(TRUNCATE)');
      final response = await getBackup();
      final bytes = await response.read().fold<List<int>>(
            <int>[],
            (prev, chunk) => prev..addAll(chunk),
          );
      expect(bytes.length, greaterThanOrEqualTo(16));
      expect(String.fromCharCodes(bytes.sublist(0, 15)), 'SQLite format 3');
    });

    test('returns 503 when database file does not exist', () async {
      final missingFile = File('${tempDir.path}/nonexistent.db');
      final response = await handleBackup(
        Request('GET', Uri.parse('http://localhost/backup')),
        db,
        missingFile,
      );
      expect(response.statusCode, 503);
      final body =
          jsonDecode(await response.readAsString()) as Map<String, dynamic>;
      expect(body['error'], 'unavailable');
    });

    test('performance: 500-row database backup completes in < 10s', () async {
      // Insert 500 designations to approximate a populated database.
      for (var i = 0; i < 500; i++) {
        await db.into(db.designations).insert(
              DesignationsCompanion.insert(name: 'Designation $i'),
            );
      }
      final start = DateTime.now();
      final response = await getBackup();
      final bytes = await response.read().fold<List<int>>(
            <int>[],
            (prev, chunk) => prev..addAll(chunk),
          );
      final elapsed = DateTime.now().difference(start);
      expect(response.statusCode, 200);
      expect(bytes, isNotEmpty);
      expect(elapsed.inSeconds, lessThan(10));
    });
  });

  group('POST /restore', () {
    test('returns 200 with {status: restored} when given a valid SQLite file',
        () async {
      // Back up current db to use as a valid restore file.
      await db.customStatement('PRAGMA wal_checkpoint(TRUNCATE)');
      final validBytes = await dbFile.readAsBytes();

      var restartCalled = false;
      final response = await postRestore(
        validBytes,
        restartDb: () async {
          restartCalled = true;
        },
      );

      expect(response.statusCode, 200);
      final body =
          jsonDecode(await response.readAsString()) as Map<String, dynamic>;
      expect(body['status'], 'restored');
      expect(restartCalled, isTrue);
    });

    test('calls restartDb callback after successful restore', () async {
      await db.customStatement('PRAGMA wal_checkpoint(TRUNCATE)');
      final validBytes = await dbFile.readAsBytes();

      var restartCalled = false;
      await postRestore(
        validBytes,
        restartDb: () async {
          restartCalled = true;
        },
      );

      expect(restartCalled, isTrue);
    });

    test('returns 400 for empty body', () async {
      final response = await postRestore([]);
      expect(response.statusCode, 400);
      final body =
          jsonDecode(await response.readAsString()) as Map<String, dynamic>;
      expect(body['error'], 'invalid_argument');
    });

    test('returns 400 for non-SQLite bytes', () async {
      final response = await postRestore(
          List<int>.filled(100, 0x42)); // 'B' repeated — not SQLite
      expect(response.statusCode, 400);
      final body =
          jsonDecode(await response.readAsString()) as Map<String, dynamic>;
      expect(body['error'], 'invalid_argument');
    });

    test('returns 400 for bytes shorter than 16 (too short for magic header)',
        () async {
      final response = await postRestore([0x53, 0x51, 0x4c, 0x69]); // "SQLi"
      expect(response.statusCode, 400);
      final body =
          jsonDecode(await response.readAsString()) as Map<String, dynamic>;
      expect(body['error'], 'invalid_argument');
    });

    test('error message does not expose internal exception details', () async {
      final response = await postRestore(List<int>.filled(100, 0xFF));
      expect(response.statusCode, 400);
      final body =
          jsonDecode(await response.readAsString()) as Map<String, dynamic>;
      // Message must not contain stack traces, file paths, or exception types.
      expect(body.containsKey('message'), isTrue);
      final message = body['message'] as String;
      expect(message, isNot(contains('Exception')));
      expect(message, isNot(contains('Error')));
      expect(message, isNot(contains('/')));
    });

    test('existing database is not corrupted on invalid upload', () async {
      // Insert a designation before the bad restore attempt.
      await db.into(db.designations).insert(
            DesignationsCompanion.insert(name: 'Madiran'),
          );

      // Attempt restore with garbage bytes.
      final response = await postRestore(List<int>.filled(100, 0xFF));
      expect(response.statusCode, 400);

      // Database still intact.
      final designations = await db.listDesignations();
      expect(designations.any((d) => d.name == 'Madiran'), isTrue);
    });

    test('recovers original database (.bak) if restore fails mid-way',
        () async {
      // Insert a designation to confirm the original db is preserved.
      await db.into(db.designations).insert(
            DesignationsCompanion.insert(name: 'Cahors'),
          );
      await db.customStatement('PRAGMA wal_checkpoint(TRUNCATE)');
      final originalBytes = await dbFile.readAsBytes();

      // Simulate a restore that passes validation but then the restartDb throws.
      final response = await postRestore(
        originalBytes,
        restartDb: () async {
          throw Exception('simulated restart failure');
        },
      );

      expect(response.statusCode, 500);
      // Original database should have been recovered from .bak.
      expect(await dbFile.exists(), isTrue);
    });
  });
}
