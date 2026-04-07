import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart' hide isNull;
import 'package:shelf/shelf.dart';
import 'package:wine_tap_mobile/server/consume_tracker.dart';
import 'package:wine_tap_mobile/server/database.dart';
import 'package:wine_tap_mobile/server/handlers/bottles.dart';
import 'package:wine_tap_mobile/server/handlers/cuvees.dart';
import 'package:wine_tap_mobile/server/handlers/domains.dart';
import 'package:wine_tap_mobile/server/handlers/designations.dart';

void main() {
  late AppDatabase db;
  late ConsumeTracker consumeTracker;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    consumeTracker = ConsumeTracker();
  });

  tearDown(() => db.close());

  Future<Response> get(String path) =>
      bottlesRouter(db, consumeTracker)(Request('GET', Uri.parse('http://localhost$path')));

  Future<Response> post(String path, Map<String, dynamic> body) =>
      bottlesRouter(db, consumeTracker)(Request(
        'POST',
        Uri.parse('http://localhost$path'),
        body: jsonEncode(body),
        headers: {'Content-Type': 'application/json'},
      ));

  Future<Response> put(String path, Map<String, dynamic> body) =>
      bottlesRouter(db, consumeTracker)(Request(
        'PUT',
        Uri.parse('http://localhost$path'),
        body: jsonEncode(body),
        headers: {'Content-Type': 'application/json'},
      ));

  Future<Response> delete(String path) =>
      bottlesRouter(db, consumeTracker)(Request('DELETE', Uri.parse('http://localhost$path')));

  Future<Map<String, dynamic>> jsonBody(Response r) async =>
      jsonDecode(await r.readAsString()) as Map<String, dynamic>;

  Future<List<dynamic>> jsonList(Response r) async =>
      jsonDecode(await r.readAsString()) as List<dynamic>;

  // Helpers to seed prerequisite data
  Future<Map<String, dynamic>> createDomain(String name) async =>
      jsonDecode(await (await domainsRouter(db)(Request(
        'POST',
        Uri.parse('http://localhost/'),
        body: jsonEncode({'name': name}),
        headers: {'Content-Type': 'application/json'},
      ))).readAsString()) as Map<String, dynamic>;

  Future<Map<String, dynamic>> createCuvee(
      int domainId, String name) async =>
      jsonDecode(await (await cuveesRouter(db)(Request(
        'POST',
        Uri.parse('http://localhost/'),
        body: jsonEncode({'name': name, 'domain_id': domainId, 'color': 1}),
        headers: {'Content-Type': 'application/json'},
      ))).readAsString()) as Map<String, dynamic>;

  Future<Map<String, dynamic>> createDesignation(String name) async =>
      jsonDecode(await (await designationsRouter(db)(Request(
        'POST',
        Uri.parse('http://localhost/'),
        body: jsonEncode({'name': name}),
        headers: {'Content-Type': 'application/json'},
      ))).readAsString()) as Map<String, dynamic>;

  group('GET /bottles', () {
    test('returns 200 with empty array when no bottles', () async {
      final response = await get('/');
      expect(response.statusCode, 200);
      expect(await jsonList(response), isEmpty);
    });

    test('excludes consumed bottles by default', () async {
      final domain = await createDomain('Pomerol');
      final cuvee = await createCuvee(domain['id'] as int, 'Le Pin');
      await post('/', {'cuvee_id': cuvee['id'], 'vintage': 2019, 'tag_id': 'AA'});
      // consume it
      await post('/consume', {'tag_id': 'AA'});

      final list = await jsonList(await get('/'));
      expect(list, isEmpty);
    });

    test('includes consumed bottles when include_consumed=true', () async {
      final domain = await createDomain('Pomerol');
      final cuvee = await createCuvee(domain['id'] as int, 'Le Pin');
      await post('/', {'cuvee_id': cuvee['id'], 'vintage': 2019, 'tag_id': 'BB'});
      await post('/consume', {'tag_id': 'BB'});

      final list = await jsonList(await get('/?include_consumed=true'));
      expect(list.length, 1);
    });

    test('response includes embedded cuvee with denormalized fields', () async {
      final domain = await createDomain('Château Margaux');
      final designation = await createDesignation('Margaux AOC');
      final cuvee = await jsonDecode(await (await cuveesRouter(db)(Request(
        'POST',
        Uri.parse('http://localhost/'),
        body: jsonEncode({
          'name': 'Grande Réserve',
          'domain_id': domain['id'],
          'designation_id': designation['id'],
          'color': 1,
        }),
        headers: {'Content-Type': 'application/json'},
      ))).readAsString()) as Map<String, dynamic>;

      await post('/', {'cuvee_id': cuvee['id'], 'vintage': 2020});

      final list = await jsonList(await get('/'));
      expect(list.length, 1);
      final b = list[0] as Map;
      expect(b['cuvee'], isNotNull);
      expect((b['cuvee'] as Map)['name'], 'Grande Réserve');
      expect((b['cuvee'] as Map)['domain_name'], 'Château Margaux');
      expect((b['cuvee'] as Map)['designation_name'], 'Margaux AOC');
    });

    test('list returns summary without descriptions', () async {
      final domain = await createDomain('Pomerol');
      final cuvee = await jsonDecode(await (await cuveesRouter(db)(Request(
        'POST',
        Uri.parse('http://localhost/'),
        body: jsonEncode({
          'name': 'Le Pin',
          'domain_id': domain['id'],
          'color': 1,
          'description': 'Cuvée description',
        }),
        headers: {'Content-Type': 'application/json'},
      ))).readAsString()) as Map<String, dynamic>;

      await post('/', {
        'cuvee_id': cuvee['id'],
        'vintage': 2019,
        'description': 'Bottle notes',
      });

      final list = await jsonList(await get('/'));
      final b = list[0] as Map;
      expect(b.containsKey('description'), isFalse);
      expect((b['cuvee'] as Map).containsKey('description'), isFalse);
    });
  });

  group('GET /bottles/by-tag/:tag_id', () {
    test('returns 200 with bottle when found', () async {
      final domain = await createDomain('Pomerol');
      final cuvee = await createCuvee(domain['id'] as int, 'Le Pin');
      await post('/', {'cuvee_id': cuvee['id'], 'vintage': 2019, 'tag_id': '04A32BFF'});

      final response = await get('/by-tag/04A32BFF');
      expect(response.statusCode, 200);
      final body = await jsonBody(response);
      expect(body['tag_id'], '04A32BFF');
      expect(body['vintage'], 2019);
    });

    test('normalizes tag_id in path', () async {
      final domain = await createDomain('Pomerol');
      final cuvee = await createCuvee(domain['id'] as int, 'Le Pin');
      await post('/', {'cuvee_id': cuvee['id'], 'vintage': 2019, 'tag_id': '04A32BFF'});

      final response = await get('/by-tag/04:a3:2b:ff');
      expect(response.statusCode, 200);
    });

    test('returns 404 when not found', () async {
      final response = await get('/by-tag/DEADBEEF');
      expect(response.statusCode, 404);
      final body = await jsonBody(response);
      expect(body['error'], 'not_found');
    });

    test('returns 404 for consumed bottles', () async {
      final domain = await createDomain('Pomerol');
      final cuvee = await createCuvee(domain['id'] as int, 'Le Pin');
      await post('/', {'cuvee_id': cuvee['id'], 'vintage': 2019, 'tag_id': 'CC'});
      await post('/consume', {'tag_id': 'CC'});

      final response = await get('/by-tag/CC');
      expect(response.statusCode, 404);
    });
  });

  group('GET /bottles/:id', () {
    test('returns 200 with bottle', () async {
      final domain = await createDomain('Pomerol');
      final cuvee = await createCuvee(domain['id'] as int, 'Le Pin');
      final created = await jsonBody(
          await post('/', {'cuvee_id': cuvee['id'], 'vintage': 2019}));

      final response = await get('/${created['id']}');
      expect(response.statusCode, 200);
      final body = await jsonBody(response);
      expect(body['id'], created['id']);
      expect(body['vintage'], 2019);
    });

    test('returns 404 for non-existent id', () async {
      final response = await get('/9999');
      expect(response.statusCode, 404);
      final body = await jsonBody(response);
      expect(body['error'], 'not_found');
    });

    test('returns 400 for non-integer id', () async {
      final response = await get('/abc');
      expect(response.statusCode, 400);
    });
  });

  group('POST /bottles', () {
    test('creates bottle and returns 201 with embedded cuvee', () async {
      final domain = await createDomain('Pomerol');
      final cuvee = await createCuvee(domain['id'] as int, 'Le Pin');

      final response = await post('/', {
        'cuvee_id': cuvee['id'],
        'vintage': 2019,
        'tag_id': '04A32BFF',
        'description': 'Acheté chez Nicolas',
        'purchase_price': 15.5,
        'drink_before': 2030,
      });
      expect(response.statusCode, 201);
      final body = await jsonBody(response);
      expect(body['id'], isA<int>());
      expect(body['cuvee_id'], cuvee['id']);
      expect(body['vintage'], 2019);
      expect(body['tag_id'], '04A32BFF');
      expect(body['description'], 'Acheté chez Nicolas');
      expect(body['purchase_price'], 15.5);
      expect(body['drink_before'], 2030);
      expect(body['added_at'], isA<String>());
      expect(body['cuvee'], isNotNull);
      expect((body['cuvee'] as Map)['domain_name'], 'Pomerol');
    });

    test('normalizes tag_id on create', () async {
      final domain = await createDomain('Pomerol');
      final cuvee = await createCuvee(domain['id'] as int, 'Le Pin');
      final response = await post('/', {
        'cuvee_id': cuvee['id'],
        'vintage': 2019,
        'tag_id': '04:a3:2b:ff',
      });
      expect(response.statusCode, 201);
      final body = await jsonBody(response);
      expect(body['tag_id'], '04A32BFF');
    });

    test('tag_id is optional', () async {
      final domain = await createDomain('Pomerol');
      final cuvee = await createCuvee(domain['id'] as int, 'Le Pin');
      final response = await post('/', {'cuvee_id': cuvee['id'], 'vintage': 2019});
      expect(response.statusCode, 201);
      final body = await jsonBody(response);
      expect(body.containsKey('tag_id'), isFalse); // omitted when null
    });

    test('returns 400 when cuvee_id is missing', () async {
      final response = await post('/', {'vintage': 2019});
      expect(response.statusCode, 400);
      final body = await jsonBody(response);
      expect(body['error'], 'invalid_argument');
    });

    test('returns 400 when vintage is missing', () async {
      final domain = await createDomain('Pomerol');
      final cuvee = await createCuvee(domain['id'] as int, 'Le Pin');
      final response = await post('/', {'cuvee_id': cuvee['id']});
      expect(response.statusCode, 400);
      final body = await jsonBody(response);
      expect(body['error'], 'invalid_argument');
    });

    test('returns 412 when cuvee_id does not exist', () async {
      final response = await post('/', {'cuvee_id': 9999, 'vintage': 2019});
      expect(response.statusCode, 412);
      final body = await jsonBody(response);
      expect(body['error'], 'referenced');
    });

    test('returns 400 on duplicate tag_id', () async {
      final domain = await createDomain('Pomerol');
      final cuvee = await createCuvee(domain['id'] as int, 'Le Pin');
      await post('/', {'cuvee_id': cuvee['id'], 'vintage': 2019, 'tag_id': 'DD'});
      final response =
          await post('/', {'cuvee_id': cuvee['id'], 'vintage': 2020, 'tag_id': 'DD'});
      expect(response.statusCode, 400);
      final body = await jsonBody(response);
      expect(body['error'], 'already_exists');
    });
  });

  group('POST /bottles/consume', () {
    test('consumes bottle and returns 200 with consumed_at set and tag_id cleared',
        () async {
      final domain = await createDomain('Pomerol');
      final cuvee = await createCuvee(domain['id'] as int, 'Le Pin');
      await post('/', {'cuvee_id': cuvee['id'], 'vintage': 2019, 'tag_id': 'EE'});

      final response = await post('/consume', {'tag_id': 'EE'});
      expect(response.statusCode, 200);
      final body = await jsonBody(response);
      expect(body['consumed_at'], isA<String>());
      expect(body.containsKey('tag_id'), isFalse); // cleared after consume
    });

    test('normalizes tag_id on consume', () async {
      final domain = await createDomain('Pomerol');
      final cuvee = await createCuvee(domain['id'] as int, 'Le Pin');
      await post('/', {'cuvee_id': cuvee['id'], 'vintage': 2019, 'tag_id': 'FF00AA'});

      final response = await post('/consume', {'tag_id': 'ff:00:aa'});
      expect(response.statusCode, 200);
    });

    test('returns 404 when no in-stock bottle with tag_id', () async {
      final response = await post('/consume', {'tag_id': 'NOTFOUND'});
      expect(response.statusCode, 404);
      final body = await jsonBody(response);
      expect(body['error'], 'not_found');
    });

    test('returns 400 when tag_id is missing', () async {
      final response = await post('/consume', {});
      expect(response.statusCode, 400);
    });
  });

  group('PUT /bottles/:id (partial update)', () {
    test('updates provided fields and returns 200', () async {
      final domain = await createDomain('Pomerol');
      final cuvee = await createCuvee(domain['id'] as int, 'Le Pin');
      final created = await jsonBody(
          await post('/', {'cuvee_id': cuvee['id'], 'vintage': 2019}));

      final response = await put('/${created['id']}', {'vintage': 2021, 'description': 'Updated'});
      expect(response.statusCode, 200);
      final body = await jsonBody(response);
      expect(body['vintage'], 2021);
      expect(body['description'], 'Updated');
      final cuveeObj = body['cuvee'] as Map<String, dynamic>;
      expect(cuveeObj['id'], cuvee['id']);
      expect(cuveeObj['name'], 'Le Pin');
      expect(cuveeObj.containsKey('domain_id'), isTrue);
      expect(cuveeObj.containsKey('designation_id'), isTrue);
    });

    test('absent fields are not changed', () async {
      final domain = await createDomain('Pomerol');
      final cuvee = await createCuvee(domain['id'] as int, 'Le Pin');
      final created = await jsonBody(await post('/', {
        'cuvee_id': cuvee['id'],
        'vintage': 2019,
        'description': 'Original',
      }));

      // Only update vintage — description should stay
      final response = await put('/${created['id']}', {'vintage': 2022});
      expect(response.statusCode, 200);
      final body = await jsonBody(response);
      expect(body['vintage'], 2022);
      expect(body['description'], 'Original');
    });

    test('returns 404 for non-existent id', () async {
      final response = await put('/9999', {'vintage': 2020});
      expect(response.statusCode, 404);
      final body = await jsonBody(response);
      expect(body['error'], 'not_found');
    });

    test('returns 400 for non-integer id', () async {
      final response = await put('/abc', {'vintage': 2020});
      expect(response.statusCode, 400);
    });

    test('returns 412 when cuvee_id does not exist', () async {
      final domain = await createDomain('Pomerol');
      final cuvee = await createCuvee(domain['id'] as int, 'Le Pin');
      final created = await jsonBody(
          await post('/', {'cuvee_id': cuvee['id'], 'vintage': 2019}));

      final response = await put('/${created['id']}', {'cuvee_id': 9999});
      expect(response.statusCode, 412);
    });
  });

  group('DELETE /bottles/:id', () {
    test('deletes and returns 204', () async {
      final domain = await createDomain('Pomerol');
      final cuvee = await createCuvee(domain['id'] as int, 'Le Pin');
      final created = await jsonBody(
          await post('/', {'cuvee_id': cuvee['id'], 'vintage': 2019}));
      final id = created['id'] as int;

      final response = await delete('/$id');
      expect(response.statusCode, 204);

      final getResponse = await get('/$id');
      expect(getResponse.statusCode, 404);
    });

    test('returns 404 for non-existent id', () async {
      final response = await delete('/9999');
      expect(response.statusCode, 404);
      final body = await jsonBody(response);
      expect(body['error'], 'not_found');
    });

    test('returns 400 for non-integer id', () async {
      final response = await delete('/abc');
      expect(response.statusCode, 400);
    });
  });
}
