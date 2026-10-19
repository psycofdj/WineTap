import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wine_tap_mobile/native/address_screen.dart';
import 'package:wine_tap_mobile/native/auth_sheet.dart';
import 'package:wine_tap_mobile/native/connections_screen.dart';
import 'package:wine_tap_mobile/native/nfc_screen.dart';
import 'package:wine_tap_mobile/native/reading.dart';
import 'package:wine_tap_mobile/native/theme.dart';
import 'package:wine_tap_mobile/server/events.dart';
import 'package:wine_tap_mobile/server/preferences.dart';
import 'package:wine_tap_mobile/server/remote_scan.dart';
import 'package:wine_tap_mobile/server/sessions.dart';

import 'reading_test.dart' show FakeNfc;

/// Loads the bundled fonts, so that renders look like the app.
Future<void> loadFonts() async {
  final families = {
    'Newsreader': ['Regular', 'Medium', 'SemiBold', 'Italic'],
    'IBM Plex Sans': ['Regular', 'Medium', 'SemiBold'],
    'IBM Plex Mono': ['Medium'],
  };
  for (final e in families.entries) {
    final loader = FontLoader(e.key);
    final base = e.key.replaceAll(' ', '');
    for (final style in e.value) {
      final bytes = File('assets/fonts/$base-$style.ttf').readAsBytesSync();
      loader.addFont(Future.value(ByteData.view(bytes.buffer)));
    }
    await loader.load();
  }
}

ClientInfo firefox() => ClientInfo(
  browser: 'Firefox',
  browserVersion: '131',
  os: 'macOS',
  ip: '192.168.1.27',
  requestedAt: DateTime.utc(2026, 10, 18, 18, 14),
);

/// Pumps [child] at the size of a phone, and compares with a golden image when
/// run with --update-goldens (images used for review, not kept).
Future<void> render(
  WidgetTester t,
  Widget child,
  String name, {
  Brightness b = Brightness.light,
}) async {
  t.view.physicalSize = const Size(390 * 2, 844 * 2);
  t.view.devicePixelRatio = 2;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: winetapTheme(b),
      home: child,
    ),
  );
  await t.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 100)),
  );
  await t.pump();
  if (autoUpdateGoldenFiles) {
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('rendus/$name.png'),
    );
  }
}

void main() {
  setUpAll(loadFonts);

  late FakeNfc nfc;
  late EventHub events;
  late RemoteScan remote;
  late ReadingController reading;

  setUp(() {
    nfc = FakeNfc();
    events = EventHub(isAuthorized: (_) => true);
    remote = RemoteScan(events);
    reading = ReadingController(nfc, remote);
  });

  testWidgets('N-E4 — attente, depuis ce téléphone', (t) async {
    reading.readLocal('consommer');
    await render(
      t,
      Scaffold(body: NfcScreen(controller: reading)),
      'ne4-attente',
    );
    expect(find.text('Présentez le tag'), findsOneWidget);
    expect(find.text('CONSOMMER UNE BOUTEILLE'), findsOneWidget);
    expect(find.text('Depuis ce téléphone'), findsOneWidget);
    await reading.cancel();
  });

  testWidgets('N-E4 — demandé par un ordinateur, lecture impossible', (
    t,
  ) async {
    remote.start('entree', firefox());
    await t.pump();
    nfc.answer(null, 'erreur');
    await t.pump();
    await render(
      t,
      Scaffold(body: NfcScreen(controller: reading)),
      'ne4-erreur',
      b: Brightness.dark,
    );
    expect(find.text('Lecture impossible'), findsOneWidget);
    expect(
      find.textContaining('Demandé par un ordinateur · Firefox sur macOS'),
      findsOneWidget,
    );
    expect(find.text('Réessayer'), findsOneWidget);
  });

  testWidgets('N-E2 — demande d’autorisation', (t) async {
    final req = AccessRequest('h', firefox(), 'en_attente');
    await render(
      t,
      Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => showAuthSheet(context, req),
              child: const Text('ouvrir'),
            ),
          ),
        ),
      ),
      'ne2-avant',
    );
    await t.tap(find.text('ouvrir'));
    await t.pumpAndSettle();
    if (autoUpdateGoldenFiles) {
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('rendus/ne2.png'),
      );
    }
    expect(find.text('Autoriser cette connexion ?'), findsOneWidget);
    expect(find.text('Firefox 131'), findsOneWidget);
    expect(find.text('192.168.1.27'), findsOneWidget);
  });

  testWidgets('N-E1 — adresse', (t) async {
    await render(t, AddressScreen(port: 8080, onConnections: () {}), 'ne1');
    // L'adresse vient des interfaces de la machine de test : l'un des deux états s'affiche.
    expect(find.text('Connexions autorisées'), findsOneWidget);
  });

  testWidgets('N-E3 — connexions autorisées', (t) async {
    final store = MemoryStore();
    final sessions = SessionStore(store);
    final now = DateTime.now().toUtc();
    store.values['v3.sessions'] =
        '[{"hash":"a","browser":"Firefox","os":"macOS","ip":"192.168.1.27","authorizedAt":"2026-10-12T10:00:00Z","lastSeen":"${now.toIso8601String()}"},'
        '{"hash":"b","browser":"Chrome","os":"Windows","ip":"192.168.1.54","authorizedAt":"2026-09-03T10:00:00Z","lastSeen":"2026-09-28T10:00:00Z"}]';
    sessions.load();
    await render(
      t,
      ConnectionsScreen(sessions: sessions, events: events, onMessage: (_) {}),
      'ne3',
    );
    expect(find.text('Firefox sur macOS'), findsOneWidget);
    expect(find.text('Révoquer'), findsNWidgets(2));
    await t.tap(find.text('Révoquer').first);
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await t.pump();
    expect(sessions.authorized, hasLength(1));
  });
}
