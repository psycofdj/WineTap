import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart' hide isNull, isNotNull;
import 'package:shelf/shelf.dart';
import 'package:wine_tap_mobile/server/database.dart';
import 'package:wine_tap_mobile/server/handlers/designations.dart';
import 'package:wine_tap_mobile/server/handlers/domains.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  Future<Response> get(String path) =>
      designationsRouter(db)(Request('GET', Uri.parse('http://localhost$path')));

  Future<Response> post(String path, Map<String, dynamic> body) =>
      designationsRouter(db)(Request(
        'POST',
        Uri.parse('http://localhost$path'),
        body: jsonEncode(body),
        headers: {'Content-Type': 'application/json'},
      ));

  Future<Response> put(String path, Map<String, dynamic> body) =>
      designationsRouter(db)(Request(
        'PUT',
        Uri.parse('http://localhost$path'),
        body: jsonEncode(body),
        headers: {'Content-Type': 'application/json'},
      ));

  Future<Response> delete(String path) => designationsRouter(db)(
      Request('DELETE', Uri.parse('http://localhost$path')));

  Future<Map<String, dynamic>> jsonBody(Response r) async =>
      jsonDecode(await r.readAsString()) as Map<String, dynamic>;

  Future<List<dynamic>> jsonList(Response r) async =>
      jsonDecode(await r.readAsString()) as List<dynamic>;

  group('GET /designations', () {
    test('returns 200 with empty array when no designations', () async {
      final response = await get('/');
      expect(response.statusCode, 200);
      expect(await jsonList(response), isEmpty);
    });

    test('does not return sentinel designation id=0', () async {
      final response = await get('/');
      final list = await jsonList(response);
      expect(list.every((d) => (d as Map)['id'] != 0), isTrue);
    });

    test('returns created designations ordered by name', () async {
      await post('/', {'name': 'Madiran'});
      await post('/', {'name': 'Bordeaux'});
      final response = await get('/');
      expect(response.statusCode, 200);
      final list = await jsonList(response);
      expect(list.length, 2);
      expect((list[0] as Map)['name'], 'Bordeaux');
      expect((list[1] as Map)['name'], 'Madiran');
    });
  });

  group('POST /designations', () {
    test('creates designation and returns 201 with JSON', () async {
      final response =
          await post('/', {'name': 'Madiran', 'region': 'Sud-Ouest'});
      expect(response.statusCode, 201);
      final body = await jsonBody(response);
      expect(body['name'], 'Madiran');
      expect(body['region'], 'Sud-Ouest');
      expect(body['description'], '');
      expect(body['id'], isA<int>());
    });

    test('trims whitespace from name', () async {
      final response = await post('/', {'name': '  Cahors  '});
      expect(response.statusCode, 201);
      final body = await jsonBody(response);
      expect(body['name'], 'Cahors');
    });

    test('returns 400 when name is missing', () async {
      final response = await post('/', {'region': 'Sud-Ouest'});
      expect(response.statusCode, 400);
      final body = await jsonBody(response);
      expect(body['error'], 'invalid_argument');
    });

    test('returns 400 when name is empty string', () async {
      final response = await post('/', {'name': '   '});
      expect(response.statusCode, 400);
    });

    test('returns 400 on duplicate name', () async {
      await post('/', {'name': 'Madiran'});
      final response = await post('/', {'name': 'Madiran'});
      expect(response.statusCode, 400);
      final body = await jsonBody(response);
      expect(body['error'], 'already_exists');
    });
  });

  group('PUT /designations/:id', () {
    test('updates and returns 200 with updated JSON', () async {
      final created = await jsonBody(await post('/', {'name': 'Madiran'}));
      final id = created['id'] as int;

      final response = await put('/$id',
          {'name': 'Madiran AOC', 'region': 'Sud-Ouest', 'description': 'Tannat'});
      expect(response.statusCode, 200);
      final body = await jsonBody(response);
      expect(body['name'], 'Madiran AOC');
      expect(body['region'], 'Sud-Ouest');
      expect(body['description'], 'Tannat');
    });

    test('returns 404 for non-existent id', () async {
      final response = await put('/9999', {'name': 'X'});
      expect(response.statusCode, 404);
      final body = await jsonBody(response);
      expect(body['error'], 'not_found');
    });

    test('returns 400 on duplicate name during update', () async {
      await post('/', {'name': 'Madiran'});
      final b = await jsonBody(await post('/', {'name': 'Bordeaux'}));
      final response = await put('/${b['id']}', {'name': 'Madiran'});
      expect(response.statusCode, 400);
    });

    test('returns 400 when name is missing', () async {
      final created = await jsonBody(await post('/', {'name': 'Madiran'}));
      final response = await put('/${created['id']}', {'region': 'X'});
      expect(response.statusCode, 400);
    });

    test('returns 400 for non-integer id', () async {
      final response = await put('/abc', {'name': 'X'});
      expect(response.statusCode, 400);
    });
  });

  group('DELETE /designations/:id', () {
    test('deletes and returns 204', () async {
      final created = await jsonBody(await post('/', {'name': 'Madiran'}));
      final id = created['id'] as int;

      final response = await delete('/$id');
      expect(response.statusCode, 204);

      // Verify gone from list
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

    test('returns 412 when designation is referenced by a cuvee', () async {
      final domain = await jsonBody(
          await domainsRouter(db)(Request('POST',
              Uri.parse('http://localhost/'),
              body: jsonEncode({'name': 'Test Domain'}),
              headers: {'Content-Type': 'application/json'})));
      final designation =
          await jsonBody(await post('/', {'name': 'Madiran'}));

      await db.insertCuvee(CuveesCompanion.insert(
        name: 'Test Cuvee',
        domainId: domain['id'] as int,
        designationId: Value(designation['id'] as int),
        color: const Value(1),
      ));

      final response = await delete('/${designation['id']}');
      expect(response.statusCode, 412);
      final body = await jsonBody(response);
      expect(body['error'], 'failed_precondition');
    });

    test('returns 412 for sentinel designation id=0', () async {
      final response = await delete('/0');
      expect(response.statusCode, 412);
    });
  });
}
