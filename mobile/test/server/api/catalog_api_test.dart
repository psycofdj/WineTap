import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

void main() {
  late Harness h;
  setUp(() async => h = await Harness.create());
  tearDown(() => h.dispose());

  group('Appellations', () {
    test('list hides the sentinel and is sorted', () async {
      await h.appellation('Margaux');
      await h.appellation('Bandol', region: 'Provence');
      final list =
          await Harness.body(await h.call('GET', '/api/appellations')) as List;
      expect(list.map((a) => a['nom']), ['Bandol', 'Margaux']);
      expect(list.first['region'], 'Provence');
      expect(list.first['a_image'], isFalse);
    });

    test('duplicate name is refused', () async {
      await h.appellation('Margaux');
      final r = await h.call(
        'POST',
        '/api/appellations',
        json: {'nom': 'Margaux'},
      );
      expect(r.statusCode, 400);
      expect((await Harness.body(r))['message'], contains('existe déjà'));
    });

    test('image is stored, served, kept, then removed', () async {
      final id = await h.appellation('Margaux');
      final png = [0x89, 0x50, 0x4E, 0x47, 1, 2, 3];
      var r = await h.call(
        'PUT',
        '/api/appellations/$id',
        json: {
          'nom': 'Margaux',
          'region': 'Bordeaux',
          'image': base64Encode(png),
        },
      );
      expect((await Harness.body(r))['a_image'], isTrue);
      final img = await h.call('GET', '/api/appellations/$id/image');
      expect(img.headers['content-type'], 'image/png');
      expect(await img.read().expand((x) => x).toList(), png);

      // Sans le champ image : l'image reste.
      r = await h.call(
        'PUT',
        '/api/appellations/$id',
        json: {'nom': 'Margaux', 'region': 'Bordeaux', 'description': 'Médoc'},
      );
      final kept = await Harness.body(r);
      expect(kept['a_image'], isTrue);
      expect(kept['description'], 'Médoc');

      r = await h.call(
        'PUT',
        '/api/appellations/$id',
        json: {'nom': 'Margaux', 'image': null},
      );
      expect((await Harness.body(r))['a_image'], isFalse);
      expect(
        (await h.call('GET', '/api/appellations/$id/image')).statusCode,
        404,
      );
    });

    test('deleting a used appellation is refused with the count', () async {
      final app = await h.appellation('Margaux');
      final dom = await h.domain('Château Margaux');
      await h.cuvee('Grand Vin', dom, appellationId: app);
      final r = await h.call('DELETE', '/api/appellations/$app');
      expect(r.statusCode, 409);
      final b = await Harness.body(r);
      expect(b['erreur'], 'referencee');
      expect(b['nombre'], 1);
    });

    test('the sentinel cannot be modified', () async {
      expect(
        (await h.call(
          'PUT',
          '/api/appellations/0',
          json: {'nom': 'X'},
        )).statusCode,
        404,
      );
      expect((await h.call('DELETE', '/api/appellations/0')).statusCode, 404);
    });
  });

  group('Domaines', () {
    test('create, update, delete', () async {
      final id = await h.domain('Domaine Tempier');
      var r = await h.call(
        'PUT',
        '/api/domaines/$id',
        json: {'nom': 'Domaine Tempier', 'description': 'Bandol'},
      );
      expect((await Harness.body(r))['description'], 'Bandol');
      r = await h.call('DELETE', '/api/domaines/$id');
      expect(r.statusCode, 204);
    });

    test('name is required', () async {
      final r = await h.call('POST', '/api/domaines', json: {'nom': '  '});
      expect(r.statusCode, 400);
    });
  });

  group('Cuvées', () {
    test('fields are mapped to the unchanged schema', () async {
      final dom = await h.domain('Bollinger');
      final app = await h.appellation('Champagne', region: 'Champagne');
      final id = await h.cuvee(
        'Special Cuvée',
        dom,
        appellationId: app,
        color: 4,
      );
      final c = (await Harness.body(await h.call('GET', '/api/cuvees')) as List)
          .first;
      expect(c, {
        'id': id,
        'nom': 'Special Cuvée',
        'domaine_id': dom,
        'appellation_id': app,
        'couleur': 4,
        'description': '',
      });
    });

    test('unknown domain, appellation or color is refused', () async {
      final dom = await h.domain('D');
      expect(
        (await h.call(
          'POST',
          '/api/cuvees',
          json: {'nom': 'X', 'domaine_id': 999},
        )).statusCode,
        400,
      );
      expect(
        (await h.call(
          'POST',
          '/api/cuvees',
          json: {'nom': 'X', 'domaine_id': dom, 'appellation_id': 999},
        )).statusCode,
        400,
      );
      expect(
        (await h.call(
          'POST',
          '/api/cuvees',
          json: {'nom': 'X', 'domaine_id': dom, 'couleur': 9},
        )).statusCode,
        400,
      );
    });

    test('a cuvée with bottles (even consumed) cannot be deleted', () async {
      final dom = await h.domain('D');
      final cuv = await h.cuvee('C', dom);
      final b = await h.bottle(cuv);
      await h.call('POST', '/api/bouteilles/${b['id']}/consommer');
      final r = await h.call('DELETE', '/api/cuvees/$cuv');
      expect(r.statusCode, 409);
    });
  });

  test('every write sends a « donnees » event', () async {
    final events = await h.call('GET', '/api/events');
    final collect = collectEvents(events);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await h.domain('Domaine Huet');
    final text = await collect;
    expect(text, contains('retry: 5000'));
    expect(text, contains('event: donnees'));
    expect(text, contains('"catalogue"'));
  });
}
