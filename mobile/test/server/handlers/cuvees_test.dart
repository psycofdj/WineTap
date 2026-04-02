import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart' hide isNull, isNotNull;
import 'package:shelf/shelf.dart';
import 'package:wine_tap_mobile/server/database.dart';
import 'package:wine_tap_mobile/server/handlers/cuvees.dart';
import 'package:wine_tap_mobile/server/handlers/designations.dart';
import 'package:wine_tap_mobile/server/handlers/domains.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  Future<Response> get(String path) =>
      cuveesRouter(db)(Request('GET', Uri.parse('http://localhost$path')));

  Future<Response> post(String path, Map<String, dynamic> body) =>
      cuveesRouter(db)(Request(
        'POST',
        Uri.parse('http://localhost$path'),
        body: jsonEncode(body),
        headers: {'Content-Type': 'application/json'},
      ));

  Future<Response> put(String path, Map<String, dynamic> body) =>
      cuveesRouter(db)(Request(
        'PUT',
        Uri.parse('http://localhost$path'),
        body: jsonEncode(body),
        headers: {'Content-Type': 'application/json'},
      ));

  Future<Response> delete(String path) =>
      cuveesRouter(db)(Request('DELETE', Uri.parse('http://localhost$path')));

  Future<Map<String, dynamic>> jsonBody(Response r) async =>
      jsonDecode(await r.readAsString()) as Map<String, dynamic>;

  Future<List<dynamic>> jsonList(Response r) async =>
      jsonDecode(await r.readAsString()) as List<dynamic>;

  Future<Map<String, dynamic>> createDomain(String name) async =>
      jsonBody(await domainsRouter(db)(Request(
        'POST',
        Uri.parse('http://localhost/'),
        body: jsonEncode({'name': name}),
        headers: {'Content-Type': 'application/json'},
      )));

  Future<Map<String, dynamic>> createDesignation(String name) async =>
      jsonBody(await designationsRouter(db)(Request(
        'POST',
        Uri.parse('http://localhost/'),
        body: jsonEncode({'name': name}),
        headers: {'Content-Type': 'application/json'},
      )));

  group('GET /cuvees', () {
    test('returns 200 with empty array when no cuvees', () async {
      final response = await get('/');
      expect(response.statusCode, 200);
      expect(await jsonList(response), isEmpty);
    });
  });

  group('POST /cuvees', () {
    test('creates cuvee and returns 201 with denormalized JSON', () async {
      final domain = await createDomain('Château Margaux');
      final designation = await createDesignation('Margaux AOC');

      final response = await post('/', {
        'name': 'Grande Réserve',
        'domain_id': domain['id'],
        'color': 1,
        'designation_id': designation['id'],
        'description': 'Flagship wine',
      });
      expect(response.statusCode, 201);
      final body = await jsonBody(response);
      expect(body['name'], 'Grande Réserve');
      expect(body['domain_id'], domain['id']);
      expect(body['color'], 1);
      expect(body['designation_id'], designation['id']);
      expect(body['description'], 'Flagship wine');
      expect(body['id'], isA<int>());
    });

    test('designation_id defaults to 0 when omitted', () async {
      final domain = await createDomain('Pomerol');

      final response = await post('/', {
        'name': 'Cuvée Classique',
        'domain_id': domain['id'],
        'color': 2,
      });
      expect(response.statusCode, 201);
      final body = await jsonBody(response);
      expect(body['designation_id'], 0);
    });

    test('trims whitespace from name', () async {
      final domain = await createDomain('Pomerol');
      final response = await post('/', {
        'name': '  Le Pin  ',
        'domain_id': domain['id'],
        'color': 1,
      });
      expect(response.statusCode, 201);
      final body = await jsonBody(response);
      expect(body['name'], 'Le Pin');
    });

    test('returns 400 when name is missing', () async {
      final domain = await createDomain('Pomerol');
      final response = await post('/', {'domain_id': domain['id'], 'color': 1});
      expect(response.statusCode, 400);
      final body = await jsonBody(response);
      expect(body['error'], 'invalid_argument');
    });

    test('returns 400 when domain_id is missing', () async {
      final response = await post('/', {'name': 'Test', 'color': 1});
      expect(response.statusCode, 400);
      final body = await jsonBody(response);
      expect(body['error'], 'invalid_argument');
    });

    test('returns 400 when color is missing', () async {
      final domain = await createDomain('Pomerol');
      final response = await post('/', {'name': 'Test', 'domain_id': domain['id']});
      expect(response.statusCode, 400);
      final body = await jsonBody(response);
      expect(body['error'], 'invalid_argument');
    });

    test('returns 400 when domain_id does not exist (FK violation)', () async {
      final response = await post('/', {
        'name': 'Test',
        'domain_id': 9999,
        'color': 1,
      });
      expect(response.statusCode, 400);
      final body = await jsonBody(response);
      expect(body['error'], 'invalid_argument');
    });

    test('returns 400 when designation_id does not exist (FK violation)', () async {
      final domain = await createDomain('Pomerol');
      final response = await post('/', {
        'name': 'Test',
        'domain_id': domain['id'],
        'color': 1,
        'designation_id': 9999,
      });
      expect(response.statusCode, 400);
      final body = await jsonBody(response);
      expect(body['error'], 'invalid_argument');
    });
  });

  group('PUT /cuvees/:id', () {
    test('updates and returns 200 with updated JSON', () async {
      final domain = await createDomain('Château Margaux');
      final created = await jsonBody(await post('/', {
        'name': 'Cuvée A',
        'domain_id': domain['id'],
        'color': 1,
      }));

      final response = await put('/${created['id']}', {
        'name': 'Cuvée B',
        'domain_id': domain['id'],
        'color': 2,
        'description': 'Updated',
      });
      expect(response.statusCode, 200);
      final body = await jsonBody(response);
      expect(body['name'], 'Cuvée B');
      expect(body['color'], 2);
      expect(body['description'], 'Updated');
    });

    test('returns 404 for non-existent id', () async {
      final domain = await createDomain('Pomerol');
      final response = await put('/9999', {
        'name': 'X',
        'domain_id': domain['id'],
        'color': 1,
      });
      expect(response.statusCode, 404);
      final body = await jsonBody(response);
      expect(body['error'], 'not_found');
    });

    test('returns 400 for non-integer id', () async {
      final response = await put('/abc', {'name': 'X', 'domain_id': 1, 'color': 1});
      expect(response.statusCode, 400);
    });

    test('returns 400 when domain_id does not exist (FK violation)', () async {
      final domain = await createDomain('Pomerol');
      final created = await jsonBody(await post('/', {
        'name': 'Test',
        'domain_id': domain['id'],
        'color': 1,
      }));
      final response = await put('/${created['id']}', {
        'name': 'Test',
        'domain_id': 9999,
        'color': 1,
      });
      expect(response.statusCode, 400);
    });
  });

  group('DELETE /cuvees/:id', () {
    test('deletes and returns 204', () async {
      final domain = await createDomain('Pomerol');
      final created = await jsonBody(await post('/', {
        'name': 'Test',
        'domain_id': domain['id'],
        'color': 1,
      }));
      final id = created['id'] as int;

      final response = await delete('/$id');
      expect(response.statusCode, 204);

      final list = await jsonList(await get('/'));
      expect(list.every((c) => (c as Map)['id'] != id), isTrue);
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
