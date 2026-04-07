import 'package:flutter_test/flutter_test.dart';
import 'package:wine_tap_mobile/services/nfc_exceptions.dart';
import 'package:wine_tap_mobile/services/nfc_service.dart';

/// A NfcService subclass that doesn't auto-complete reads,
/// allowing tests to control when tags are "discovered".
class ManualNfcService extends NoOpNfcService {
  int readStartCount = 0;
  int readStopCount = 0;
  int teardownCount = 0;

  @override
  void onReadStart() {
    readStartCount++;
    // Don't auto-complete — let the test drive completion.
  }

  @override
  void onReadStop() {
    readStopCount++;
  }

  @override
  Future<void> teardownSession() async {
    teardownCount++;
  }
}

/// Lets the async readTagId body run past `await teardownSession()`.
Future<void> pump() => Future<void>.delayed(Duration.zero);

void main() {
  late ManualNfcService nfc;

  setUp(() {
    nfc = ManualNfcService();
  });

  test('readTagId cancels pending read when called again', () async {
    final first = nfc.readTagId();
    await pump();
    expect(nfc.readStartCount, 1);

    // Register error expectation BEFORE the second read cancels the first,
    // so the async error is caught by the test framework.
    final firstCancelled =
        expectLater(first, throwsA(isA<NfcSessionCancelledException>()));

    // Second readTagId should cancel the first.
    final second = nfc.readTagId();
    await pump();
    expect(nfc.readStartCount, 2);
    expect(nfc.teardownCount, 2);

    await firstCancelled;

    // Second read should still be active — complete it manually.
    nfc.completeRead('AABB1122');
    expect(await second, 'AABB1122');
  });

  test('readTagId does not call onReadStop when no read is pending', () async {
    final future = nfc.readTagId();
    await pump();
    expect(nfc.readStopCount, 0);

    nfc.completeRead('AABB1122');
    await future;
  });

  test('stopReading cancels pending read without error', () async {
    nfc.readTagId();
    await pump();
    await nfc.stopReading();

    expect(nfc.readStopCount, 1);

    // Start a fresh read to confirm service is reusable.
    final second = nfc.readTagId();
    await pump();
    nfc.completeRead('CCDD3344');
    expect(await second, 'CCDD3344');
  });
}
