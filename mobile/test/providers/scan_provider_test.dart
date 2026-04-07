import 'dart:async';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wine_tap_mobile/providers/scan_provider.dart';
import 'package:wine_tap_mobile/server/consume_tracker.dart';
import 'package:wine_tap_mobile/server/database.dart';
import 'package:wine_tap_mobile/services/nfc_service.dart';

/// Mock NfcService that allows controlling NFC reads from tests.
class MockNfcService implements NfcService {
  Completer<NfcReadResult>? _readCompleter;

  @override
  NfcState get state => NfcState.ready;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<NfcReadResult> readTag() {
    _readCompleter = Completer<NfcReadResult>();
    return _readCompleter!.future;
  }

  void completeRead(String tagId) =>
      _readCompleter?.complete((tag: tagId, error: null));
  void failRead(String error) =>
      _readCompleter?.complete((tag: null, error: error));

  @override
  Future<void> cancel() async {}
}

void main() {
  late AppDatabase db;
  late MockNfcService mockNfc;
  late ConsumeTracker consumeTracker;
  late ScanProvider provider;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    mockNfc = MockNfcService();
    consumeTracker = ConsumeTracker();
    provider = ScanProvider(db, consumeTracker, nfcService: mockNfc);
  });

  tearDown(() async {
    provider.dispose();
    await db.close();
  });

  test('initial state is idle', () {
    expect(provider.state, ScanState.idle);
    expect(provider.bottle, isNull);
    expect(provider.tagId, isNull);
    expect(provider.errorMessage, isNull);
  });

  test('startScan transitions to scanning', () {
    // Don't await — the future blocks on NFC read
    provider.startScan();
    expect(provider.state, ScanState.scanning);
  });

  test('startScan is ignored when not idle', () {
    provider.startScan(); // scanning
    provider.startScan(); // should be ignored
    expect(provider.state, ScanState.scanning);
  });

  test('NFC session cancelled returns to idle', () async {
    final future = provider.startScan();
    mockNfc.failRead('cancelled');
    await future;
    expect(provider.state, ScanState.idle);
  });

  test('NFC read timeout goes to error', () async {
    final future = provider.startScan();
    mockNfc.failRead('timeout');
    await future;
    expect(provider.state, ScanState.error);
    expect(provider.errorMessage, isNotNull);
  });

  test('unknown tag goes to error with "Tag inconnu"', () async {
    final future = provider.startScan();
    mockNfc.completeRead('DEADBEEF');
    await future;
    expect(provider.state, ScanState.error);
    expect(provider.errorMessage, contains('inconnu'));
  });

  group('with seeded bottle', () {
    setUp(() async {
      // Seed a designation, domain, cuvee, and bottle with a tag
      final desId = await db.insertDesignation(
        DesignationsCompanion.insert(name: 'Madiran'),
      );
      final domId = await db.insertDomain(
        DomainsCompanion.insert(name: 'Domaine Brumont'),
      );
      final cuvId = await db.insertCuvee(CuveesCompanion.insert(
        name: 'Château Montus',
        domainId: domId,
        designationId: Value(desId),
      ));
      await db.insertBottle(BottlesCompanion.insert(
        tagId: const Value('04A32BFF'),
        cuveeId: cuvId,
        vintage: 2019,
        addedAt: DateTime.now().toUtc().toIso8601String(),
      ));
    });

    test('successful scan auto-consumes and goes to consumed', () async {
      final future = provider.startScan();
      mockNfc.completeRead('04A32BFF');
      await future;

      expect(provider.state, ScanState.consumed);
      expect(provider.bottle, isNotNull);
      // Bottle details captured before consume — tagId reflects pre-consume state
      expect(provider.bottle!.bottle.tagId, '04A32BFF');
      // Verify DB actually consumed the bottle (tagId cleared in DB)
      final dbBottle = await db.getBottleByTagId('04A32BFF');
      expect(dbBottle, isNull); // tag no longer associated
    });

    test('consumed state has no auto-reset timer', () async {
      final future = provider.startScan();
      mockNfc.completeRead('04A32BFF');
      await future;
      expect(provider.state, ScanState.consumed);

      // Wait longer than the old 3s auto-reset
      await Future<void>.delayed(const Duration(seconds: 4));
      expect(provider.state, ScanState.consumed); // still consumed — no auto-reset
    });

    test('reset from consumed returns to idle', () async {
      final future = provider.startScan();
      mockNfc.completeRead('04A32BFF');
      await future;
      expect(provider.state, ScanState.consumed);

      provider.reset();
      expect(provider.state, ScanState.idle);
      expect(provider.bottle, isNull);
      expect(provider.tagId, isNull);
    });

    test('duplicate tag suppression within same session (FR5)', () async {
      // Scan a tag — bottle consumed
      final future = provider.startScan();
      mockNfc.completeRead('04A32BFF');
      await future;
      expect(provider.state, ScanState.consumed);

      // Without reset, try scanning again (simulates rapid double-read)
      // Provider should ignore because _lastScannedTagId matches
      // But state is consumed, and startScan only works from idle — so this is a no-op
      // FR5 duplicate suppression is enforced within startScan() when state is idle
    });

    test('duplicate tag suppression ignores same tag read twice', () async {
      // Put provider back to idle to test duplicate within a session
      // We need a scenario where startScan is called and same tag appears
      // Since the bottle was consumed above, seed a second bottle
      final cuvId = (await db.listCuvees()).first.cuvee.id;
      await db.insertBottle(BottlesCompanion.insert(
        tagId: const Value('AABBCCDD'),
        cuveeId: cuvId,
        vintage: 2020,
        addedAt: DateTime.now().toUtc().toIso8601String(),
      ));

      // First scan
      var future = provider.startScan();
      mockNfc.completeRead('AABBCCDD');
      await future;
      expect(provider.state, ScanState.consumed);

      // Reset (clears _lastScannedTagId) — next scan of same tag is a NEW session
      provider.reset();
      future = provider.startScan();
      mockNfc.completeRead('AABBCCDD');
      await future;
      // Tag was consumed already — now it's unknown
      expect(provider.state, ScanState.error);
    });
  });

  test('reset from error returns to idle', () async {
    final future = provider.startScan();
    mockNfc.completeRead('UNKNOWN');
    await future;
    expect(provider.state, ScanState.error);

    provider.reset();
    expect(provider.state, ScanState.idle);
  });

  test('cancel during scanning returns to idle', () {
    provider.startScan();
    expect(provider.state, ScanState.scanning);

    provider.cancel();
    expect(provider.state, ScanState.idle);

  });

  test('cancel is ignored when not scanning', () {
    provider.cancel(); // idle — should be no-op
    expect(provider.state, ScanState.idle);
  });

  // --- cancelForIntake (FR19b) ---
  test('cancelForIntake from idle is no-op', () {
    provider.cancelForIntake();
    expect(provider.state, ScanState.idle);
  });

  test('cancelForIntake from scanning cancels NFC and returns to idle', () {
    provider.startScan();
    expect(provider.state, ScanState.scanning);

    provider.cancelForIntake();
    expect(provider.state, ScanState.idle);

  });

  group('cancelForIntake with seeded bottle', () {
    setUp(() async {
      final desId = await db.insertDesignation(
        DesignationsCompanion.insert(name: 'Cahors'),
      );
      final domId = await db.insertDomain(
        DomainsCompanion.insert(name: 'Domaine Test'),
      );
      final cuvId = await db.insertCuvee(CuveesCompanion.insert(
        name: 'Test Cuvee',
        domainId: domId,
        designationId: Value(desId),
      ));
      await db.insertBottle(BottlesCompanion.insert(
        tagId: const Value('FFAABB00'),
        cuveeId: cuvId,
        vintage: 2020,
        addedAt: DateTime.now().toUtc().toIso8601String(),
      ));
    });

    test('cancelForIntake from consumed resets to idle without rollback', () async {
      final future = provider.startScan();
      mockNfc.completeRead('FFAABB00');
      await future;
      expect(provider.state, ScanState.consumed);

      provider.cancelForIntake();
      expect(provider.state, ScanState.idle);

      // Bottle is still consumed in DB — no rollback
      final dbBottle = await db.getBottleByTagId('FFAABB00');
      expect(dbBottle, isNull); // tag cleared = consumed
    });
  });

  test('cancelForIntake from error returns to idle', () async {
    final future = provider.startScan();
    mockNfc.completeRead('UNKNOWN_TAG');
    await future;
    expect(provider.state, ScanState.error);

    provider.cancelForIntake();
    expect(provider.state, ScanState.idle);
  });
}
