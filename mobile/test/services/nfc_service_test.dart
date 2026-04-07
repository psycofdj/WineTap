import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wine_tap_mobile/services/nfc_service.dart';

/// A testable NfcService where tag discovery and cancellation are
/// triggered externally via [simulateTagDiscovered] and [simulateCanceled].
class FakeNfcService extends NfcServiceBase {
  void Function(String tagId)? pendingOnTagDiscovered;
  void Function()? pendingOnCanceled;
  int startScanCount = 0;
  int stopScanCount = 0;

  @override
  Future<bool> isAvailable() async => true;

  @override
  void platformStartScan({
    required void Function(String tagId) onTagDiscovered,
    required void Function() onCanceled,
  }) {
    startScanCount++;
    pendingOnTagDiscovered = onTagDiscovered;
    pendingOnCanceled = onCanceled;
  }

  @override
  Future<void> platformStopScan() async {
    stopScanCount++;
    pendingOnTagDiscovered = null;
    pendingOnCanceled = null;
  }

  void simulateTagDiscovered(String tagId) {
    pendingOnTagDiscovered?.call(tagId);
  }

  void simulateCanceled() {
    pendingOnCanceled?.call();
  }
}

void main() {
  late FakeNfcService nfc;

  setUp(() {
    nfc = FakeNfcService();
  });

  group('initial state', () {
    test('starts in ready state', () {
      expect(nfc.state, NfcState.ready);
    });
  });

  group('readTag from ready', () {
    test('returns tag on successful scan', () async {
      final future = nfc.readTag();
      expect(nfc.state, NfcState.scanning);
      expect(nfc.startScanCount, 1);

      nfc.simulateTagDiscovered('AABB1122');
      expect(nfc.state, NfcState.postScanning);

      final result = await future;
      expect(result.tag, 'AABB1122');
      expect(result.error, isNull);
    });

    test('returns cancelled error on platform cancel', () async {
      final future = nfc.readTag();
      expect(nfc.state, NfcState.scanning);

      nfc.simulateCanceled();
      expect(nfc.state, NfcState.postScanning);

      final result = await future;
      expect(result.tag, isNull);
      expect(result.error, 'cancelled');
    });
  });

  group('readTag from scanning', () {
    test('cancels current scan, waits, then starts new scan', () {
      fakeAsync((async) {
        // First readTag puts us in scanning.
        final first = nfc.readTag();
        expect(nfc.state, NfcState.scanning);

        // Second readTag while scanning: should cancel + waitReady + rescan.
        final second = nfc.readTag();

        // First should have been cancelled internally.
        NfcReadResult? firstResult;
        first.then((v) => firstResult = v);
        async.flushMicrotasks();
        // The first readTag's internal scan was cancelled, but readTag catches
        // it and returns the result — however the first readTag is now orphaned
        // since the second readTag took over. The first scan completer gets
        // cancelled by _cancel(). The readTag wrapping it catches the exception.
        // Note: first readTag completes with cancelled error since _cancel
        // errors out its completer which readTag catches.
        expect(firstResult?.error, 'cancelled');

        // Still in postScanning waiting for the 5s delay.
        expect(nfc.state, NfcState.postScanning);

        // Advance past the 5s waitReady delay.
        async.elapse(const Duration(seconds: 5));

        // Now should be scanning again.
        expect(nfc.state, NfcState.scanning);
        expect(nfc.startScanCount, 2);

        // Complete the second scan.
        nfc.simulateTagDiscovered('CCDD');

        NfcReadResult? secondResult;
        second.then((v) => secondResult = v);
        async.flushMicrotasks();
        expect(secondResult?.tag, 'CCDD');
      });
    });
  });

  group('readTag from postScanning', () {
    test('waits for ready then starts new scan', () {
      fakeAsync((async) {
        // Get to postScanning.
        final first = nfc.readTag();
        nfc.simulateTagDiscovered('1111');

        NfcReadResult? firstResult;
        first.then((v) => firstResult = v);
        async.flushMicrotasks();
        expect(firstResult?.tag, '1111');
        expect(nfc.state, NfcState.postScanning);

        // readTag from postScanning should waitReady then scan.
        final second = nfc.readTag();

        // Still in postScanning waiting for the 5s delay.
        expect(nfc.state, NfcState.postScanning);

        // Advance past the 5s waitReady delay.
        async.elapse(const Duration(seconds: 5));

        expect(nfc.state, NfcState.scanning);
        expect(nfc.startScanCount, 2);

        nfc.simulateTagDiscovered('2222');

        NfcReadResult? secondResult;
        second.then((v) => secondResult = v);
        async.flushMicrotasks();
        expect(secondResult?.tag, '2222');
      });
    });
  });

  group('late callbacks ignored', () {
    test('tag discovered after internal cancel is ignored', () {
      fakeAsync((async) {
        final first = nfc.readTag();
        // Save callback reference before cancel clears it.
        final savedCallback = nfc.pendingOnTagDiscovered;
        expect(nfc.state, NfcState.scanning);

        // Trigger a second readTag which internally cancels the first.
        final second = nfc.readTag();

        NfcReadResult? firstResult;
        first.then((v) => firstResult = v);
        async.flushMicrotasks();
        expect(firstResult?.error, 'cancelled');
        expect(nfc.state, NfcState.postScanning);

        // Late callback from platform — should be ignored (state guard).
        savedCallback?.call('LATE_TAG');
        expect(nfc.state, NfcState.postScanning);

        // Advance past waitReady, complete second scan.
        async.elapse(const Duration(seconds: 5));
        nfc.simulateTagDiscovered('REAL_TAG');

        NfcReadResult? secondResult;
        second.then((v) => secondResult = v);
        async.flushMicrotasks();
        expect(secondResult?.tag, 'REAL_TAG');
      });
    });
  });

  group('NoOpNfcService', () {
    test('readTag returns a fake tag ID immediately', () async {
      final noOp = NoOpNfcService();
      final result = await noOp.readTag();
      expect(result.tag, isNotNull);
      expect(result.tag, startsWith('FFFF'));
      expect(result.tag!.length, 12);
      expect(result.error, isNull);
      expect(noOp.state, NfcState.postScanning);
    });

    test('isAvailable returns true', () async {
      final noOp = NoOpNfcService();
      expect(await noOp.isAvailable(), isTrue);
    });
  });
}
