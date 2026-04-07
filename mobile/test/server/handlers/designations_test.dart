import 'dart:convert';
import 'dart:typed_data';

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

    test('list returns summary without description and picture', () async {
      final picData = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47]);
      await post('/', {
        'name': 'Pauillac',
        'region': 'Bordeaux',
        'description': 'A great appellation',
        'picture': base64Encode(picData),
      });
      final response = await get('/');
      final list = await jsonList(response);
      final item = list[0] as Map;
      expect(item['name'], 'Pauillac');
      expect(item['region'], 'Bordeaux');
      expect(item.containsKey('description'), isFalse);
      expect(item.containsKey('picture'), isFalse);
    });
  });

  group('GET /designations/:id', () {
    test('returns 200 with full object including description and picture', () async {
      final picData = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47]);
      final b64 = base64Encode(picData);
      final created = await jsonBody(
          await post('/', {'name': 'Pauillac', 'region': 'Bordeaux', 'description': 'Fine wines', 'picture': b64}));
      final id = created['id'] as int;

      final response = await get('/$id');
      expect(response.statusCode, 200);
      final body = await jsonBody(response);
      expect(body['id'], id);
      expect(body['name'], 'Pauillac');
      expect(body['region'], 'Bordeaux');
      expect(body['description'], 'Fine wines');
      expect(body['picture'], b64);
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

    test('creates designation with picture and returns base64', () async {
      final picData = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47]);
      final b64 = base64Encode(picData);
      final response =
          await post('/', {'name': 'Pauillac', 'picture': b64});
      expect(response.statusCode, 201);
      final body = await jsonBody(response);
      expect(body['picture'], b64);
    });

    test('creates designation without picture field returns no picture key', () async {
      final response = await post('/', {'name': 'Listrac'});
      expect(response.statusCode, 201);
      final body = await jsonBody(response);
      expect(body.containsKey('picture'), isFalse);
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

    test('updates picture via PUT', () async {
      final created = await jsonBody(await post('/', {'name': 'Margaux'}));
      final id = created['id'] as int;
      final picData = Uint8List.fromList([0xFF, 0xD8, 0xFF]);
      final b64 = base64Encode(picData);

      final response = await put('/$id', {'name': 'Margaux', 'picture': b64});
      expect(response.statusCode, 200);
      final body = await jsonBody(response);
      expect(body['picture'], b64);
    });

    test('clears picture when picture is null in PUT', () async {
      final picData = Uint8List.fromList([0x01, 0x02]);
      final created = await jsonBody(
          await post('/', {'name': 'Pessac', 'picture': base64Encode(picData)}));
      final id = created['id'] as int;

      final response =
          await put('/$id', {'name': 'Pessac', 'picture': null});
      expect(response.statusCode, 200);
      final body = await jsonBody(response);
      expect(body.containsKey('picture'), isFalse);
    });

    test('preserves picture when picture key is absent in PUT', () async {
      final picData = Uint8List.fromList([0x01, 0x02]);
      final b64 = base64Encode(picData);
      final created = await jsonBody(
          await post('/', {'name': 'Graves', 'picture': b64}));
      final id = created['id'] as int;

      final response =
          await put('/$id', {'name': 'Graves', 'region': 'Bordeaux'});
      expect(response.statusCode, 200);
      final body = await jsonBody(response);
      expect(body['picture'], b64);
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
      expect(body['error'], 'referenced');
    });

    test('returns 412 for sentinel designation id=0', () async {
      final response = await delete('/0');
      expect(response.statusCode, 412);
    });
  });
}
