import 'package:flutter_test/flutter_test.dart';
import 'package:wine_tap_mobile/server/scan_coordinator.dart';

void main() {
  late ScanCoordinator coordinator;

  setUp(() {
    coordinator = ScanCoordinator(
      timeout: const Duration(milliseconds: 100),
    );
  });

  group('ScanCoordinator', () {
    test('starts with no pending request', () {
      expect(coordinator.hasPendingRequest, isFalse);
    });

    test('request sets pending state', () {
      coordinator.request();
      expect(coordinator.hasPendingRequest, isTrue);
    });

    test('request throws if already pending', () {
      coordinator.request();
      expect(
        () => coordinator.request(),
        throwsA(isA<StateError>()),
      );
    });

    test('submitResult completes waitForResult', () async {
      coordinator.request();
      final future = coordinator.waitForResult();
      coordinator.submitResult('04A32BFF');
      final result = await future;
      expect(result, '04A32BFF');
    });

    test('submitResult resets state', () async {
      coordinator.request();
      final future = coordinator.waitForResult();
      coordinator.submitResult('AABB');
      await future;
      expect(coordinator.hasPendingRequest, isFalse);
    });

    test('waitForResult returns null on timeout', () async {
      coordinator.request();
      final result = await coordinator.waitForResult();
      expect(result, isNull);
      // Request is still pending after timeout (caller retries).
      expect(coordinator.hasPendingRequest, isTrue);
    });

    test('cancel causes waitForResult to return null', () async {
      coordinator.request();
      final future = coordinator.waitForResult();
      coordinator.cancel();
      final result = await future;
      expect(result, isNull);
      expect(coordinator.hasPendingRequest, isFalse);
    });

    test('cancel resets state', () {
      coordinator.request();
      coordinator.cancel();
      expect(coordinator.hasPendingRequest, isFalse);
    });

    test('waitForResult throws if no pending request', () {
      expect(
        () => coordinator.waitForResult(),
        throwsA(isA<StateError>()),
      );
    });

    test('can request again after cancel', () {
      coordinator.request();
      coordinator.cancel();
      coordinator.request();
      expect(coordinator.hasPendingRequest, isTrue);
    });

    test('can request again after submit completes', () async {
      coordinator.request();
      final future = coordinator.waitForResult();
      coordinator.submitResult('XX');
      await future;

      coordinator.request();
      expect(coordinator.hasPendingRequest, isTrue);
    });
  });
}
