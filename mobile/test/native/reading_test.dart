import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:wine_tap_mobile/native/reading.dart';
import 'package:wine_tap_mobile/server/events.dart';
import 'package:wine_tap_mobile/server/remote_scan.dart';
import 'package:wine_tap_mobile/services/nfc_service.dart';

/// NFC reader answered by the test.
class FakeNfc implements NfcService {
  Completer<NfcReadResult>? pending;

  void answer(String? tag, [String? error]) =>
      pending!.complete((tag: tag, error: error));

  @override
  Future<NfcReadResult> readTag() =>
      (pending = Completer<NfcReadResult>()).future;

  @override
  Future<void> cancel() async {
    if (pending != null && !pending!.isCompleted) {
      pending!.complete((tag: null, error: 'cancelled'));
    }
  }

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<void> restartSession() async {}

  @override
  NfcState get state => NfcState.ready;
}

void main() {
  late FakeNfc nfc;
  late RemoteScan remote;
  late ReadingController c;
  late List<Map<String, Object?>> sent;

  setUp(() {
    nfc = FakeNfc();
    sent = [];
    remote = _RecordingScan(sent);
    c = ReadingController(nfc, remote);
  });

  test('local read returns the tag after showing « Tag lu »', () async {
    final f = c.readLocal('consommer');
    await Future<void>.delayed(Duration.zero);
    expect(c.current?.purpose, 'consommer');
    nfc.answer('04A32BFF');
    await Future<void>.delayed(Duration.zero);
    expect(c.current?.state, ReadingState.read);
    expect(await f, '04A32BFF');
    expect(c.current, isNull);
  });

  test('cancel returns null', () async {
    final f = c.readLocal('identifier');
    await Future<void>.delayed(Duration.zero);
    await c.cancel();
    expect(await f, isNull);
    expect(c.current, isNull);
  });

  test('a failed read shows the error, then retry works', () async {
    final f = c.readLocal('entree');
    await Future<void>.delayed(Duration.zero);
    nfc.answer(null, 'timeout');
    await Future<void>.delayed(Duration.zero);
    expect(c.current?.state, ReadingState.error);
    c.retry();
    await Future<void>.delayed(Duration.zero);
    expect(c.current?.state, ReadingState.waiting);
    nfc.answer('04BB');
    expect(await f, '04BB');
  });

  test('a read requested by a computer is reported back', () async {
    var notified = false;
    c.onSentToComputer = () => notified = true;
    final r = remote.start('entree', null);
    await Future<void>.delayed(Duration.zero);
    expect(c.current?.fromComputer, isTrue);
    nfc.answer('04CC');
    await Future<void>.delayed(const Duration(milliseconds: 1000));
    expect(sent.single, {'id': r.id, 'statut': 'lu', 'tag_id': '04CC'});
    expect(notified, isTrue);
    expect(remote.current, isNull);
  });

  test('the computer cancels: N-E4 closes', () async {
    final r = remote.start('recherche', null);
    await Future<void>.delayed(Duration.zero);
    remote.cancel(r.id);
    await Future<void>.delayed(Duration.zero);
    expect(c.current, isNull);
  });

  test('a local read during a remote one is refused', () async {
    remote.start('entree', null);
    await Future<void>.delayed(Duration.zero);
    expect(await c.readLocal('consommer'), isNull);
  });
}

/// RemoteScan that records the results it would send to browsers.
class _RecordingScan extends RemoteScan {
  _RecordingScan(this.sent) : super(_NoEvents());

  final List<Map<String, Object?>> sent;

  @override
  void complete(String id, String tagId) {
    sent.add({'id': id, 'statut': 'lu', 'tag_id': tagId});
    super.complete(id, tagId);
  }
}

class _NoEvents extends EventHub {
  _NoEvents() : super(isAuthorized: (_) => false);
}
