import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart' hide isNull, isNotNull;
import 'package:shelf/shelf.dart';
import 'package:wine_tap_mobile/server/database.dart';
import 'package:wine_tap_mobile/server/handlers/domains.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  Future<Response> get(String path) =>
      domainsRouter(db)(Request('GET', Uri.parse('http://localhost$path')));

  Future<Response> post(String path, Map<String, dynamic> body) =>
      domainsRouter(db)(Request(
        'POST',
        Uri.parse('http://localhost$path'),
        body: jsonEncode(body),
        headers: {'Content-Type': 'application/json'},
      ));

  Future<Response> put(String path, Map<String, dynamic> body) =>
      domainsRouter(db)(Request(
        'PUT',
        Uri.parse('http://localhost$path'),
        body: jsonEncode(body),
        headers: {'Content-Type': 'application/json'},
      ));

  Future<Response> delete(String path) =>
      domainsRouter(db)(Request('DELETE', Uri.parse('http://localhost$path')));

  Future<Map<String, dynamic>> jsonBody(Response r) async =>
      jsonDecode(await r.readAsString()) as Map<String, dynamic>;

  Future<List<dynamic>> jsonList(Response r) async =>
      jsonDecode(await r.readAsString()) as List<dynamic>;

  group('GET /domains', () {
    test('returns 200 with empty array when no domains', () async {
      final response = await get('/');
      expect(response.statusCode, 200);
      expect(await jsonList(response), isEmpty);
    });

    test('returns created domains ordered by name', () async {
      await post('/', {'name': 'Mouton Rothschild'});
      await post('/', {'name': 'Château Pétrus'});
      final response = await get('/');
      expect(response.statusCode, 200);
      final list = await jsonList(response);
      expect(list.length, 2);
      expect((list[0] as Map)['name'], 'Château Pétrus');
      expect((list[1] as Map)['name'], 'Mouton Rothschild');
    });
  });

  group('POST /domains', () {
    test('creates domain and returns 201 with JSON', () async {
      final response = await post('/', {'name': 'Château Margaux', 'description': 'Grand cru'});
      expect(response.statusCode, 201);
      final body = await jsonBody(response);
      expect(body['name'], 'Château Margaux');
      expect(body['description'], 'Grand cru');
      expect(body['id'], isA<int>());
    });

    test('trims whitespace from name', () async {
      final response = await post('/', {'name': '  Pomerol  '});
      expect(response.statusCode, 201);
      final body = await jsonBody(response);
      expect(body['name'], 'Pomerol');
    });

    test('returns 400 when name is missing', () async {
      final response = await post('/', {'description': 'test'});
      expect(response.statusCode, 400);
      final body = await jsonBody(response);
      expect(body['error'], 'invalid_argument');
    });

    test('returns 400 when name is empty string', () async {
      final response = await post('/', {'name': '   '});
      expect(response.statusCode, 400);
    });

    test('returns 400 on duplicate name', () async {
      await post('/', {'name': 'Pomerol'});
      final response = await post('/', {'name': 'Pomerol'});
      expect(response.statusCode, 400);
      final body = await jsonBody(response);
      expect(body['error'], 'already_exists');
    });
  });

  group('PUT /domains/:id', () {
    test('updates and returns 200 with updated JSON', () async {
      final created = await jsonBody(await post('/', {'name': 'Pomerol'}));
      final id = created['id'] as int;

      final response = await put('/$id', {'name': 'Pomerol AOC', 'description': 'Merlot'});
      expect(response.statusCode, 200);
      final body = await jsonBody(response);
      expect(body['name'], 'Pomerol AOC');
      expect(body['description'], 'Merlot');
    });

    test('returns 404 for non-existent id', () async {
      final response = await put('/9999', {'name': 'X'});
      expect(response.statusCode, 404);
      final body = await jsonBody(response);
      expect(body['error'], 'not_found');
    });

    test('returns 400 on duplicate name during update', () async {
      await post('/', {'name': 'Pomerol'});
      final b = await jsonBody(await post('/', {'name': 'Médoc'}));
      final response = await put('/${b['id']}', {'name': 'Pomerol'});
      expect(response.statusCode, 400);
    });

    test('returns 400 when name is missing', () async {
      final created = await jsonBody(await post('/', {'name': 'Pomerol'}));
      final response = await put('/${created['id']}', {'description': 'X'});
      expect(response.statusCode, 400);
    });

    test('returns 400 for non-integer id', () async {
      final response = await put('/abc', {'name': 'X'});
      expect(response.statusCode, 400);
    });
  });

  group('DELETE /domains/:id', () {
    test('deletes and returns 204', () async {
      final created = await jsonBody(await post('/', {'name': 'Pomerol'}));
      final id = created['id'] as int;

      final response = await delete('/$id');
      expect(response.statusCode, 204);

      final list = await jsonList(await get('/'));
      expect(list.every((d) => (d as Map)['id'] != id), isTrue);
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

    test('returns 412 when domain is referenced by a cuvee', () async {
      final domain = await jsonBody(await post('/', {'name': 'Pomerol'}));
      await db.insertCuvee(CuveesCompanion.insert(
        name: 'Test Cuvee',
        domainId: domain['id'] as int,
        color: const Value(1),
      ));

      final response = await delete('/${domain['id']}');
      expect(response.statusCode, 412);
      final body = await jsonBody(response);
      expect(body['error'], 'referenced');
    });
  });
}
