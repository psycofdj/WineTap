import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wine_tap_mobile/native/bridge.dart';
import 'package:wine_tap_mobile/native/reading.dart';
import 'package:wine_tap_mobile/server/database.dart';
import 'package:wine_tap_mobile/server/db_holder.dart';
import 'package:wine_tap_mobile/server/events.dart';
import 'package:wine_tap_mobile/server/remote_scan.dart';

import 'reading_test.dart' show FakeNfc;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.winetap.mobile/file_io');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late Directory dir;
  late AppDatabase db;
  late Bridge bridge;
  late List<String> replies;
  late List<MethodCall> calls;
  Object? picked;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('winetap-bridge');
    final file = File('${dir.path}/winetap.sqlite');
    AppDatabase open() => AppDatabase.forTesting(NativeDatabase(file));
    db = open();
    await db.insertDomain(DomainsCompanion.insert(name: 'Domaine Huet'));
    replies = [];
    calls = [];
    picked = null;
    final events = EventHub(isAuthorized: (_) => true);
    bridge = Bridge(
      reading: ReadingController(FakeNfc(), RemoteScan(events)),
      dbs: DbHolder(db, file, open),
      reply: (js) async => replies.add(js),
      openNative: (_) {},
    );
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return call.method == 'saveFile' ? true : picked;
    });
  });

  tearDown(() async {
    messenger.setMockMethodCallHandler(channel, null);
    await db.close();
    await dir.delete(recursive: true);
  });

  /// Sends a message as the page would, and decodes the answer.
  Future<Object?> send(String method, [List<Object?> args = const []]) async {
    await bridge.handle(jsonEncode({'id': 7, 'methode': method, 'args': args}));
    final m = RegExp(
      r'^window\.__wtRetour\(7, (.*)\)$',
    ).firstMatch(replies.last)!;
    return jsonDecode(m.group(1)!);
  }

  test('pickFile hands the chosen file to the page, in base64', () async {
    picked = Uint8List.fromList('SQLite format 3\x00...'.codeUnits);
    final r = await send('pickFile') as Map;
    expect(calls.single.method, 'pickFileBytes');
    expect(base64Decode(r['base64'] as String), picked);
  });

  test('pickFile cancelled', () async {
    expect(await send('pickFile'), {'annule': true});
  });

  test('saveBackup saves the database file through the system', () async {
    final r = await send('saveBackup') as Map;
    expect(r['enregistre'], true);
    expect(r['nom'], matches(RegExp(r'^winetap-\d{4}-\d{2}-\d{2}\.db$')));
    final args = calls.single.arguments as Map;
    final bytes = args['bytes'] as Uint8List;
    expect(String.fromCharCodes(bytes.sublist(0, 15)), 'SQLite format 3');
    expect(args['name'], r['nom']);
  });

  test('unknown method', () async {
    expect(await send('formatC'), {'erreur': 'méthode inconnue'});
  });
}
