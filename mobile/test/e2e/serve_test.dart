// Serveur v3 réel avec le site construit (mobile/assets/site), pour des essais
// de bout en bout dans un navigateur. Ignoré sauf si WINETAP_E2E=1 :
//
//   ../scripts/build_web.sh
//   WINETAP_E2E=1 WINETAP_E2E_SECONDES=300 flutter test test/e2e/serve_test.dart
//
// Puis http://127.0.0.1:8099/ (les demandes d'autorisation sont acceptées
// d'office, sauf avec WINETAP_E2E_AUTORISER=0) ou http://localhost:8099/?jeton=<jeton affiché> pour la WebView.
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wine_tap_mobile/server/api/context.dart';
import 'package:wine_tap_mobile/server/database.dart';
import 'package:wine_tap_mobile/server/db_holder.dart';
import 'package:wine_tap_mobile/server/dev_seed.dart';
import 'package:wine_tap_mobile/server/events.dart';
import 'package:wine_tap_mobile/server/preferences.dart';
import 'package:wine_tap_mobile/server/remote_scan.dart';
import 'package:wine_tap_mobile/server/seed_data.dart';
import 'package:wine_tap_mobile/server/server.dart';
import 'package:wine_tap_mobile/server/sessions.dart';

void main() {
  final enabled = Platform.environment['WINETAP_E2E'] == '1';

  test(
    'serve the site and the API',
    () async {
      final dir = await Directory.systemTemp.createTemp('winetap-e2e');
      final file = File('${dir.path}/winetap.sqlite');
      AppDatabase open() => AppDatabase.forTesting(NativeDatabase(file));
      final db = open();
      await seedDatabase(db);
      await seedDevDataIfNeeded(db, isDev: () async => true);

      final store = MemoryStore();
      final sessions = SessionStore(store, appToken: 'jeton-e2e')..load();
      final events = EventHub(isAuthorized: sessions.isAuthorized);
      final scan = RemoteScan(events);
      final ctx = ApiContext(
        dbs: DbHolder(db, file, open),
        sessions: sessions,
        events: events,
        scan: scan,
        settings: Settings(store),
        phone: PhoneInfo(name: 'iPhone', localAddress: () async => '127.0.0.1'),
        port: 8099,
      );

      // Le « téléphone » accepte toutes les demandes (sauf WINETAP_E2E_AUTORISER=0)
      // et lit un tag en 1,5 s.
      final autoriser = Platform.environment['WINETAP_E2E_AUTORISER'] != '0';
      sessions.changes.listen((_) async {
        if (!autoriser) return;
        for (final p in sessions.pending) {
          await sessions.decide(p.hash, allow: true);
          events.session(p.hash, 'autorisee');
        }
      });
      scan.changes.listen((r) {
        if (r == null) return;
        Future<void>.delayed(
          const Duration(milliseconds: 1500),
          () => scan.complete(r.id, '04E2E001'),
        );
      });

      final server = await startServer(
        ctx,
        enableWakelock: false,
        loadSite: (path) async {
          final f = File('assets/site/$path');
          return await f.exists() ? f.readAsBytes() : null;
        },
      );
      final secondes =
          int.tryParse(Platform.environment['WINETAP_E2E_SECONDES'] ?? '') ??
          120;
      // ignore: avoid_print
      print(
        'Serveur sur http://127.0.0.1:${server.port}/ — jeton : ${sessions.appToken}',
      );
      await Future<void>.delayed(Duration(seconds: secondes));
      await server.close(force: true);
      await db.close();
      await dir.delete(recursive: true);
    },
    skip: enabled
        ? false
        : 'WINETAP_E2E=1 pour lancer le serveur de bout en bout',
    timeout: const Timeout(Duration(hours: 1)),
  );
}
