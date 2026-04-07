import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wine_tap_mobile/providers/intake_provider.dart';
import 'package:wine_tap_mobile/providers/scan_provider.dart';
import 'package:wine_tap_mobile/server/consume_tracker.dart';
import 'package:wine_tap_mobile/server/database.dart';
import 'package:wine_tap_mobile/server/scan_coordinator.dart';
import 'package:wine_tap_mobile/services/nfc_exceptions.dart';
import 'package:wine_tap_mobile/services/nfc_service.dart';

/// Mock NfcService that allows controlling NFC reads from tests.
class MockNfcService implements NfcService {
  Completer<String>? _readCompleter;
  bool stopReadingCalled = false;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<String> readTagId() {
    _readCompleter = Completer<String>();
    return _readCompleter!.future;
  }

  void completeRead(String tagId) => _readCompleter?.complete(tagId);
  void failRead(Object error) => _readCompleter?.completeError(error);

  @override
  Future<void> stopReading() async {
    stopReadingCalled = true;
  }
}

void main() {
  late ScanCoordinator coordinator;
  late MockNfcService mockNfc;
  late IntakeProvider provider;

  setUp(() {
    coordinator = ScanCoordinator(timeout: const Duration(milliseconds: 100));
    mockNfc = MockNfcService();
    provider = IntakeProvider(coordinator, nfcService: mockNfc);
  });

  tearDown(() {
    provider.dispose();
  });

  test('startListening sets state to waitingForRequest', () {
    provider.startListening();
    expect(provider.state, IntakeState.waitingForRequest);
  });

  test('stopListening sets state to idle', () {
    provider.startListening();
    provider.stopListening();
    expect(provider.state, IntakeState.idle);
  });

  // --- shouldShowIntakeScreen navigation flag ---
  test('shouldShowIntakeScreen is false when idle or waitingForRequest', () {
    expect(provider.shouldShowIntakeScreen, false);
    provider.startListening();
    expect(provider.shouldShowIntakeScreen, false);
  });

  test('shouldShowIntakeScreen is true when scanning', () async {
    provider.startListening();
    coordinator.request();
    await Future<void>.delayed(const Duration(milliseconds: 600));
    expect(provider.state, IntakeState.scanning);
    expect(provider.shouldShowIntakeScreen, true);
  });

  // --- Auto-scan on request detection ---
  test('poll detects scan request and auto-transitions to scanning', () async {
    provider.startListening();
    expect(provider.state, IntakeState.waitingForRequest);

    coordinator.request();
    await Future<void>.delayed(const Duration(milliseconds: 600));
    expect(provider.state, IntakeState.scanning);
  });

  // --- Single read flow ---
  test('tag scanned transitions to tagSent then back to waitingForRequest',
      () async {
    provider.startListening();
    coordinator.request();
    await Future<void>.delayed(const Duration(milliseconds: 600));
    expect(provider.state, IntakeState.scanning);

    mockNfc.completeRead('04AABBCC');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(provider.state, IntakeState.tagSent);
    expect(provider.lastTagId, '04AABBCC');

    // Wait for reset timer (1s)
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    expect(provider.state, IntakeState.waitingForRequest);
    expect(provider.shouldShowIntakeScreen, false);
  });

  // --- Manager cancel ---
  test('manager cancel transitions to waitingForRequest', () async {
    provider.startListening();
    coordinator.request();
    await Future<void>.delayed(const Duration(milliseconds: 600));
    expect(provider.state, IntakeState.scanning);

    coordinator.cancel();
    await Future<void>.delayed(const Duration(milliseconds: 600));
    expect(provider.state, IntakeState.waitingForRequest);
  });

  // --- NFC errors auto-retry ---
  test('NFC session cancelled shows brief error then returns to scanning',
      () async {
    provider.startListening();
    coordinator.request();
    await Future<void>.delayed(const Duration(milliseconds: 600));
    expect(provider.state, IntakeState.scanning);

    mockNfc.failRead(NfcSessionCancelledException());
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(provider.state, IntakeState.error);
    expect(provider.errorMessage, isNotNull);

    // Wait for brief error timeout (2s) — should auto-retry scanning
    await Future<void>.delayed(const Duration(milliseconds: 2100));
    expect(provider.state, IntakeState.scanning);
  });

  test('NFC read timeout shows brief error then returns to scanning',
      () async {
    provider.startListening();
    coordinator.request();
    await Future<void>.delayed(const Duration(milliseconds: 600));

    mockNfc.failRead(NfcReadTimeoutException());
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(provider.state, IntakeState.error);

    await Future<void>.delayed(const Duration(milliseconds: 2100));
    expect(provider.state, IntakeState.scanning);
  });

  // --- cancelScan ---
  test('cancelScan returns to waitingForRequest', () async {
    provider.startListening();
    coordinator.request();
    await Future<void>.delayed(const Duration(milliseconds: 600));
    expect(provider.state, IntakeState.scanning);

    await provider.cancelScan();
    expect(provider.state, IntakeState.waitingForRequest);
    expect(provider.shouldShowIntakeScreen, false);
  });

  // --- Intake-over-consume priority (FR19b) ---
  group('intake-over-consume priority', () {
    late ScanProvider scanProvider;

    setUp(() {
      provider.dispose();
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      scanProvider = ScanProvider(db, ConsumeTracker(), nfcService: MockNfcService());
      provider = IntakeProvider(coordinator,
          nfcService: mockNfc, scanProvider: scanProvider);
    });

    test('intake request calls cancelForIntake on scan provider', () async {
      scanProvider.startScan();
      expect(scanProvider.state, ScanState.scanning);

      provider.startListening();
      coordinator.request();
      await Future<void>.delayed(const Duration(milliseconds: 600));

      expect(scanProvider.state, ScanState.idle);
      expect(provider.state, IntakeState.scanning);
    });
  });
}
