import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart' hide isNull, isNotNull;
import 'package:shelf/shelf.dart';
import 'package:wine_tap_mobile/server/database.dart';
import 'package:wine_tap_mobile/server/handlers/completions.dart';
import 'package:wine_tap_mobile/server/handlers/designations.dart';
import 'package:wine_tap_mobile/server/handlers/domains.dart';
import 'package:wine_tap_mobile/server/handlers/cuvees.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  Future<Response> get(String path) =>
      completionsRouter(db)(Request('GET', Uri.parse('http://localhost$path')));

  Future<Map<String, dynamic>> jsonBody(Response r) async =>
      jsonDecode(await r.readAsString()) as Map<String, dynamic>;

  Future<void> seedDesignation(String name) async {
    await designationsRouter(db)(Request(
      'POST',
      Uri.parse('http://localhost/'),
      body: jsonEncode({'name': name}),
      headers: {'Content-Type': 'application/json'},
    ));
  }

  Future<void> seedDomain(String name) async {
    await domainsRouter(db)(Request(
      'POST',
      Uri.parse('http://localhost/'),
      body: jsonEncode({'name': name}),
      headers: {'Content-Type': 'application/json'},
    ));
  }

  Future<void> seedCuvee(String name, int domainId) async {
    await cuveesRouter(db)(Request(
      'POST',
      Uri.parse('http://localhost/'),
      body: jsonEncode({'name': name, 'domain_id': domainId, 'color': 1}),
      headers: {'Content-Type': 'application/json'},
    ));
  }

  group('GET /completions?field=designation', () {
    test('returns matching designation names', () async {
      await seedDesignation('Madiran');
      await seedDesignation('Margaux');
      await seedDesignation('Médoc');
      await seedDesignation('Bordeaux');

      final response = await get('/?field=designation&prefix=Ma');
      expect(response.statusCode, 200);
      final body = await jsonBody(response);
      final values = (body['values'] as List).cast<String>();
      expect(values, containsAll(['Madiran', 'Margaux']));
      expect(values, isNot(contains('Médoc')));
      expect(values, isNot(contains('Bordeaux')));
    });

    test('empty prefix returns all designation names (excluding sentinel)', () async {
      await seedDesignation('Madiran');
      await seedDesignation('Bordeaux');

      final response = await get('/?field=designation&prefix=');
      expect(response.statusCode, 200);
      final body = await jsonBody(response);
      final values = (body['values'] as List).cast<String>();
      // sentinel '(unassigned)' (id=0) may also be returned — check seeds are present
      expect(values, containsAll(['Madiran', 'Bordeaux']));
    });

    test('no prefix param returns all names', () async {
      await seedDesignation('Madiran');

      final response = await get('/?field=designation');
      expect(response.statusCode, 200);
      final body = await jsonBody(response);
      final values = (body['values'] as List).cast<String>();
      expect(values, contains('Madiran'));
    });
  });

  group('GET /completions?field=domain', () {
    test('returns matching domain names', () async {
      await seedDomain('Château Margaux');
      await seedDomain('Château Pétrus');
      await seedDomain('Domaine Brumont');

      final response = await get('/?field=domain&prefix=Château');
      expect(response.statusCode, 200);
      final body = await jsonBody(response);
      final values = (body['values'] as List).cast<String>();
      expect(values.length, 2);
      expect(values, containsAll(['Château Margaux', 'Château Pétrus']));
    });
  });

  group('GET /completions?field=cuvee', () {
    test('returns matching cuvee names', () async {
      await seedDomain('Pomerol');
      final domainList = await jsonDecode(await (await domainsRouter(db)(
        Request('GET', Uri.parse('http://localhost/')),
      )).readAsString()) as List;
      final domainId = (domainList[0] as Map)['id'] as int;

      await seedCuvee('Le Pin', domainId);
      await seedCuvee('Pétrus', domainId);
      await seedCuvee('La Fleur-Pétrus', domainId);

      final response = await get('/?field=cuvee&prefix=Le');
      expect(response.statusCode, 200);
      final body = await jsonBody(response);
      final values = (body['values'] as List).cast<String>();
      expect(values, contains('Le Pin'));
      expect(values, isNot(contains('Pétrus')));
    });
  });

  group('GET /completions — error cases', () {
    test('returns 400 when field is missing', () async {
      final response = await get('/?prefix=mad');
      expect(response.statusCode, 400);
      final body = await jsonBody(response);
      expect(body['error'], 'invalid_argument');
    });

    test('returns 400 when field value is invalid', () async {
      final response = await get('/?field=bottle&prefix=x');
      expect(response.statusCode, 400);
      final body = await jsonBody(response);
      expect(body['error'], 'invalid_argument');
    });

    test('returns empty list when no names match', () async {
      await seedDesignation('Madiran');

      final response = await get('/?field=designation&prefix=XYZ');
      expect(response.statusCode, 200);
      final body = await jsonBody(response);
      expect(body['values'], isEmpty);
    });
  });
}
