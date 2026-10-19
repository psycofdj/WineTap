import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

void main() {
  late Harness h;
  late int cuvee;
  setUp(() async {
    h = await Harness.create(year: 2026);
    cuvee = await h.cuvee('Grand Vin', await h.domain('Château Margaux'));
  });
  tearDown(() => h.dispose());

  group('Creation', () {
    test('maps the fields of the unchanged schema', () async {
      final r = await h.call(
        'POST',
        '/api/bouteilles',
        json: {
          'cuvee_id': cuvee,
          'millesime': 2015,
          'tag_id': '04:a3:2b:ff',
          'prix': 650,
          'a_boire_avant': 2045,
          'commentaire': ' Cadeau ',
        },
      );
      expect(r.statusCode, 201);
      final b = await Harness.body(r);
      expect(b['tag_id'], '04A32BFF');
      expect(b['millesime'], 2015);
      expect(b['prix'], 650.0);
      expect(b['a_boire_avant'], 2045);
      expect(b['commentaire'], 'Cadeau');
      expect(b['consommee_le'], isNull);
      expect(DateTime.parse(b['entree_le'] as String).isUtc, isTrue);
    });

    test('millésime is required, between 1900 and the current year', () async {
      for (final m in [null, 0, 1899, 2027, '2015']) {
        final r = await h.call(
          'POST',
          '/api/bouteilles',
          json: {'cuvee_id': cuvee, 'millesime': m},
        );
        expect(r.statusCode, 400, reason: 'millésime $m');
      }
    });

    test('a tag already on an in-stock bottle is refused', () async {
      final first = await h.bottle(cuvee, tag: '04AA');
      final r = await h.call(
        'POST',
        '/api/bouteilles',
        json: {'cuvee_id': cuvee, 'millesime': 2015, 'tag_id': '04aa'},
      );
      expect(r.statusCode, 409);
      final b = await Harness.body(r);
      expect(b['erreur'], 'tag_utilise');
      expect(b['bouteille_id'], first['id']);
    });
  });

  group('Update', () {
    test('is partial; tag_id null removes the tag', () async {
      final b = await h.bottle(cuvee, tag: '04BB');
      final r = await h.call(
        'PUT',
        '/api/bouteilles/${b['id']}',
        json: {'prix': 12.5, 'tag_id': null},
      );
      final u = await Harness.body(r);
      expect(u['prix'], 12.5);
      expect(u['tag_id'], isNull);
      expect(u['millesime'], b['millesime']);
      expect(u['entree_le'], b['entree_le']);
    });

    test('keeping its own tag is allowed', () async {
      final b = await h.bottle(cuvee, tag: '04BB');
      final r = await h.call(
        'PUT',
        '/api/bouteilles/${b['id']}',
        json: {'tag_id': '04BB'},
      );
      expect(r.statusCode, 200);
    });
  });

  group('Consumption', () {
    test('by tag: consumed, tag freed, then « déjà consommée »', () async {
      final b = await h.bottle(cuvee, tag: '04CC');
      var r = await h.call('POST', '/api/consommer', json: {'tag_id': '04:cc'});
      expect(r.statusCode, 200);
      final c = (await Harness.body(r))['bouteille'];
      expect(c['id'], b['id']);
      expect(c['tag_id'], isNull);
      expect(c['consommee_le'], isNotNull);

      r = await h.call('POST', '/api/consommer', json: {'tag_id': '04CC'});
      expect(r.statusCode, 409);
      final err = await Harness.body(r);
      expect(err['erreur'], 'deja_consommee');
      expect(err['bouteille']['id'], b['id']);
    });

    test('unknown tag', () async {
      final r = await h.call(
        'POST',
        '/api/consommer',
        json: {'tag_id': '04DD'},
      );
      expect(r.statusCode, 404);
      expect((await Harness.body(r))['erreur'], 'tag_inconnu');
    });

    test('a freed tag put on a new bottle consumes the new one', () async {
      await h.bottle(cuvee, tag: '04EE');
      await h.call('POST', '/api/consommer', json: {'tag_id': '04EE'});
      final again = await h.bottle(cuvee, tag: '04EE');
      expect(again['tag_id'], '04EE');
      final r = await h.call(
        'POST',
        '/api/consommer',
        json: {'tag_id': '04EE'},
      );
      expect(r.statusCode, 200);
      expect((await Harness.body(r))['bouteille']['id'], again['id']);
    });

    test('without tag; twice is refused', () async {
      final b = await h.bottle(cuvee);
      expect(
        (await h.call(
          'POST',
          '/api/bouteilles/${b['id']}/consommer',
        )).statusCode,
        200,
      );
      expect(
        (await h.call(
          'POST',
          '/api/bouteilles/${b['id']}/consommer',
        )).statusCode,
        409,
      );
    });

    test('lookup by tag does not consume', () async {
      final b = await h.bottle(cuvee, tag: '04FF');
      final r = await h.call('GET', '/api/bouteilles/tag/04FF');
      expect((await Harness.body(r))['id'], b['id']);
      final list =
          await Harness.body(await h.call('GET', '/api/bouteilles')) as List;
      expect(list, hasLength(1));
    });
  });

  group('Lists', () {
    test('in stock by default, consumed on request', () async {
      final a = await h.bottle(cuvee);
      await h.bottle(cuvee);
      await h.call('POST', '/api/bouteilles/${a['id']}/consommer');
      expect(
        await Harness.body(await h.call('GET', '/api/bouteilles')),
        hasLength(1),
      );
      expect(
        await Harness.body(await h.call('GET', '/api/bouteilles?consommees=1')),
        hasLength(2),
      );
    });

    test('tastings: most recent first, paginated', () async {
      final ids = <int>[];
      for (var i = 0; i < 5; i++) {
        final b = await h.bottle(cuvee);
        await h.call('POST', '/api/bouteilles/${b['id']}/consommer');
        ids.add(b['id'] as int);
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      final p1 = await Harness.body(
        await h.call('GET', '/api/degustations?depuis=0&nombre=2'),
      );
      expect(p1['total'], 5);
      expect((p1['bouteilles'] as List).map((b) => b['id']), [ids[4], ids[3]]);
      final p3 = await Harness.body(
        await h.call('GET', '/api/degustations?depuis=4&nombre=2'),
      );
      expect((p3['bouteilles'] as List).map((b) => b['id']), [ids[0]]);
    });
  });

  test('delete', () async {
    final b = await h.bottle(cuvee);
    expect(
      (await h.call('DELETE', '/api/bouteilles/${b['id']}')).statusCode,
      204,
    );
    expect(
      (await h.call('DELETE', '/api/bouteilles/${b['id']}')).statusCode,
      404,
    );
  });
}
