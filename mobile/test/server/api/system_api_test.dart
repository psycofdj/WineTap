import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wine_tap_mobile/server/database.dart';
import 'package:wine_tap_mobile/server/static_site.dart';

import 'harness.dart';

void main() {
  late Harness h;
  setUp(() async => h = await Harness.create());
  tearDown(() => h.dispose());

  group('Settings', () {
    test('assistant is shared and defaults to Claude', () async {
      expect(await Harness.body(await h.call('GET', '/api/reglages')), {
        'assistant': 'claude',
      });
      await h.call('PUT', '/api/reglages', json: {'assistant': 'chatgpt'});
      expect(h.ctx.settings.assistant, 'chatgpt');
    });
  });

  group('Remote scan', () {
    test('one at a time; the result goes out as an event', () async {
      final events = await h.call('GET', '/api/events');
      final collect = collectEvents(events);
      final r = await h.call('POST', '/api/scan', json: {'objet': 'entree'});
      expect(r.statusCode, 202);
      final id = (await Harness.body(r))['id'] as String;
      expect(h.ctx.scan.current?.purpose, 'entree');
      expect(
        (await h.call(
          'POST',
          '/api/scan',
          json: {'objet': 'recherche'},
        )).statusCode,
        409,
      );
      h.ctx.scan.complete(id, '04A32BFF');
      expect(h.ctx.scan.current, isNull);
      final text = await collect;
      expect(text, contains('event: scan'));
      expect(text, contains('"tag_id":"04A32BFF"'));
      expect(text, contains('"statut":"lu"'));
    });

    test('cancelled by the computer', () async {
      final id = (await Harness.body(
        await h.call('POST', '/api/scan', json: {'objet': 'recherche'}),
      ))['id'];
      expect((await h.call('DELETE', '/api/scan/$id')).statusCode, 204);
      expect(h.ctx.scan.current, isNull);
    });
  });

  group('Backup and restore', () {
    test('backup is the database file', () async {
      await h.domain('Domaine Huet');
      final r = await h.call('GET', '/api/sauvegarde');
      expect(
        r.headers['content-disposition'],
        matches(RegExp(r'winetap-\d{4}-\d{2}-\d{2}\.db')),
      );
      final bytes = await r.read().expand((x) => x).toList();
      expect(String.fromCharCodes(bytes.sublist(0, 15)), 'SQLite format 3');
    });

    test('a file that is not a WineTap database is refused', () async {
      final r = await h.call(
        'POST',
        '/api/restauration/examen',
        bytes: 'photos-vacances.zip'.codeUnits,
      );
      expect(r.statusCode, 400);
      expect((await Harness.body(r))['erreur'], 'fichier_invalide');
    });

    test('examine then restore another cave, without restarting', () async {
      // Une autre cave : 2 bouteilles en stock, 1 consommée.
      final other = File('${h.dir.path}/autre.sqlite');
      final db2 = AppDatabase.forTesting(NativeDatabase(other));
      final dom = await db2.insertDomain(
        DomainsCompanion.insert(name: 'Domaine Tempier'),
      );
      final cuv = await db2.insertCuvee(
        CuveesCompanion.insert(name: 'Bandol rosé', domainId: dom),
      );
      for (final consumed in [null, null, '2026-01-01T00:00:00Z']) {
        await db2.insertBottle(
          BottlesCompanion.insert(
            cuveeId: cuv,
            vintage: 2023,
            addedAt: '2025-01-01T00:00:00Z',
            consumedAt: Value(consumed),
          ),
        );
      }
      await db2.customStatement('PRAGMA wal_checkpoint(TRUNCATE)');
      await db2.close();
      final bytes = await other.readAsBytes();

      await h.domain('Domaine à remplacer');
      final ex = await h.call('POST', '/api/restauration/examen', bytes: bytes);
      expect(await Harness.body(ex), {'en_stock': 2});

      final r = await h.call('POST', '/api/restauration', bytes: bytes);
      expect(r.statusCode, 200);
      final doms =
          await Harness.body(await h.call('GET', '/api/domaines')) as List;
      expect(doms.map((d) => d['nom']), ['Domaine Tempier']);
      expect(
        await Harness.body(await h.call('GET', '/api/bouteilles')),
        hasLength(2),
      );
    });
  });

  group('Site', () {
    test('index.html is served to everyone, without the bridge', () async {
      final r = await h.call('GET', '/', app: false);
      expect(r.statusCode, 200);
      expect(r.headers['content-type'], startsWith('text/html'));
      expect(await r.readAsString(), isNot(contains('winetapBridge')));
    });

    test(
      'the app token sets the cookie, then the bridge is injected',
      () async {
        final r = await h.call('GET', '/?jeton=${h.appToken}', app: false);
        expect(r.statusCode, 302);
        final cookie = r.headers['set-cookie']!.split(';').first;
        expect(cookie, startsWith('wt_app='));
        final page = await h.call('GET', '/', app: false, cookie: cookie);
        final html = await page.readAsString();
        expect(html, contains('window.winetapBridge'));
        expect(html, contains(h.appToken));
        expect(bridgeScript('x'), contains('WineTapNative.postMessage'));
      },
    );

    test('a wrong token is refused', () async {
      expect((await h.call('GET', '/?jeton=faux', app: false)).statusCode, 403);
    });

    test('hashed assets are cached; unknown files are 404', () async {
      final js = await h.call('GET', '/assets/index-abc.js', app: false);
      expect(js.headers['content-type'], startsWith('text/javascript'));
      expect(js.headers['cache-control'], contains('immutable'));
      expect((await h.call('GET', '/nope.js', app: false)).statusCode, 404);
      expect((await h.call('GET', '/../secret', app: false)).statusCode, 404);
    });

    test('unknown API routes answer JSON 404', () async {
      final r = await h.call('GET', '/api/nope');
      expect(r.statusCode, 404);
      expect((await Harness.body(r))['erreur'], 'introuvable');
    });
  });
}
