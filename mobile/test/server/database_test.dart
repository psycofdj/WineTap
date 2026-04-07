import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wine_tap_mobile/server/database.dart';

AppDatabase _createTestDb() {
  return AppDatabase.forTesting(NativeDatabase.memory());
}

void main() {
  late AppDatabase db;

  setUp(() {
    db = _createTestDb();
  });

  tearDown(() => db.close());

  group('Schema', () {
    test('tables are created', () async {
      // Verify we can insert into all tables without error
      final desId = await db.insertDesignation(DesignationsCompanion.insert(
        name: 'Madiran',
      ));
      expect(desId, greaterThan(0));

      final domId = await db.insertDomain(DomainsCompanion.insert(
        name: 'Domaine Brumont',
      ));
      expect(domId, greaterThan(0));

      final cuvId = await db.insertCuvee(CuveesCompanion.insert(
        name: 'Château Montus',
        domainId: domId,
      ));
      expect(cuvId, greaterThan(0));

      final botId = await db.insertBottle(BottlesCompanion.insert(
        cuveeId: cuvId,
        vintage: 2019,
        addedAt: '2026-03-15T10:30:00Z',
      ));
      expect(botId, greaterThan(0));
    });

    test('designation name is unique', () async {
      await db.insertDesignation(DesignationsCompanion.insert(name: 'Cahors'));
      expect(
        () => db.insertDesignation(DesignationsCompanion.insert(name: 'Cahors')),
        throwsA(isA<SqliteException>()),
      );
    });

    test('domain name is unique', () async {
      await db.insertDomain(DomainsCompanion.insert(name: 'Brumont'));
      expect(
        () => db.insertDomain(DomainsCompanion.insert(name: 'Brumont')),
        throwsA(isA<SqliteException>()),
      );
    });

    test('bottle tag_id is unique', () async {
      final desId = await db.insertDesignation(
          DesignationsCompanion.insert(name: 'Madiran'));
      final domId =
          await db.insertDomain(DomainsCompanion.insert(name: 'Brumont'));
      final cuvId = await db.insertCuvee(CuveesCompanion.insert(
        name: 'Montus',
        domainId: domId,
        designationId: Value(desId),
      ));
      await db.insertBottle(BottlesCompanion.insert(
        tagId: const Value('04A32BFF'),
        cuveeId: cuvId,
        vintage: 2019,
        addedAt: '2026-01-01T00:00:00Z',
      ));
      expect(
        () => db.insertBottle(BottlesCompanion.insert(
          tagId: const Value('04A32BFF'),
          cuveeId: cuvId,
          vintage: 2020,
          addedAt: '2026-01-01T00:00:00Z',
        )),
        throwsA(isA<SqliteException>()),
      );
    });

    test('foreign key cuvees → domains', () async {
      await expectLater(
        db.insertCuvee(CuveesCompanion.insert(
          name: 'Orphan',
          domainId: 9999,
        )),
        throwsA(isA<SqliteException>()),
      );
    });

    test('designation_id=0 means unassigned (no FK enforcement)', () async {
      final domId =
          await db.insertDomain(DomainsCompanion.insert(name: 'Brumont'));
      // designation_id=0 is valid (unassigned); leftOuterJoin handles it
      final cuvId = await db.insertCuvee(CuveesCompanion.insert(
        name: 'Unassigned',
        domainId: domId,
      ));
      final cuv = await db.getCuveeById(cuvId);
      expect(cuv.cuvee.designationId, 0);
      expect(cuv.designationName, '(unassigned)');
      expect(cuv.region, '');
    });

    test('foreign key bottles → cuvees', () async {
      await expectLater(
        db.insertBottle(BottlesCompanion.insert(
          cuveeId: 9999,
          vintage: 2020,
          addedAt: '2026-01-01T00:00:00Z',
        )),
        throwsA(isA<SqliteException>()),
      );
    });

    test('default values are applied', () async {
      final desId = await db.insertDesignation(
          DesignationsCompanion.insert(name: 'Margaux'));
      final des = await db.getDesignationById(desId);
      expect(des.region, '');
      expect(des.description, '');

      final domId = await db.insertDomain(
          DomainsCompanion.insert(name: 'Test Domain'));
      final dom = await db.getDomainById(domId);
      expect(dom.description, '');

      final cuvId = await db.insertCuvee(CuveesCompanion.insert(
        name: 'Test Cuvee',
        domainId: domId,
      ));
      final cuv = await db.getCuveeById(cuvId);
      expect(cuv.cuvee.color, 0);
      expect(cuv.cuvee.designationId, 0);
      expect(cuv.cuvee.description, '');
    });
  });

  group('Designation queries', () {
    test('list returns ordered by name', () async {
      await db.insertDesignation(DesignationsCompanion.insert(name: 'Cahors'));
      await db.insertDesignation(DesignationsCompanion.insert(name: 'Alsace'));
      await db.insertDesignation(DesignationsCompanion.insert(name: 'Bordeaux'));

      final list = await db.listDesignations();
      // (unassigned) is seeded at id=0 by onCreate
      expect(list.map((d) => d.name).toList(),
          ['(unassigned)', 'Alsace', 'Bordeaux', 'Cahors']);
    });

    test('getById returns correct record', () async {
      final id = await db.insertDesignation(
          DesignationsCompanion.insert(name: 'Madiran', region: const Value('Sud-Ouest')));
      final des = await db.getDesignationById(id);
      expect(des.name, 'Madiran');
      expect(des.region, 'Sud-Ouest');
    });

    test('update modifies record', () async {
      final id = await db.insertDesignation(
          DesignationsCompanion.insert(name: 'Old'));
      await db.updateDesignation(DesignationsCompanion(
        id: Value(id),
        name: const Value('New'),
        region: const Value('Updated'),
        description: const Value('Desc'),
      ));
      final des = await db.getDesignationById(id);
      expect(des.name, 'New');
      expect(des.region, 'Updated');
    });

    test('delete removes record', () async {
      final id = await db.insertDesignation(
          DesignationsCompanion.insert(name: 'ToDelete'));
      final count = await db.deleteDesignation(id);
      expect(count, 1);
      final all = await db.listDesignations();
      // Only the seeded (unassigned) sentinel remains
      expect(all.length, 1);
      expect(all[0].name, '(unassigned)');
    });
  });

  group('Domain queries', () {
    test('list returns ordered by name', () async {
      await db.insertDomain(DomainsCompanion.insert(name: 'Zeta'));
      await db.insertDomain(DomainsCompanion.insert(name: 'Alpha'));

      final list = await db.listDomains();
      expect(list.map((d) => d.name).toList(), ['Alpha', 'Zeta']);
    });

    test('CRUD operations work', () async {
      final id = await db.insertDomain(DomainsCompanion.insert(name: 'Test'));
      final dom = await db.getDomainById(id);
      expect(dom.name, 'Test');

      await db.updateDomain(DomainsCompanion(
        id: Value(id),
        name: const Value('Updated'),
        description: const Value('Desc'),
      ));
      final updated = await db.getDomainById(id);
      expect(updated.name, 'Updated');

      await db.deleteDomain(id);
      final all = await db.listDomains();
      expect(all, isEmpty);
    });
  });

  group('Cuvee queries', () {
    late int domId;
    late int desId;

    setUp(() async {
      desId = await db.insertDesignation(
          DesignationsCompanion.insert(name: 'Madiran', region: const Value('Sud-Ouest')));
      domId = await db.insertDomain(
          DomainsCompanion.insert(name: 'Brumont'));
    });

    test('list returns with denormalized names, ordered by domain then name', () async {
      final dom2 = await db.insertDomain(
          DomainsCompanion.insert(name: 'Alpha Domain'));

      await db.insertCuvee(CuveesCompanion.insert(
        name: 'Bouscassé',
        domainId: domId,
        designationId: Value(desId),
      ));
      await db.insertCuvee(CuveesCompanion.insert(
        name: 'Montus',
        domainId: domId,
        designationId: Value(desId),
      ));
      await db.insertCuvee(CuveesCompanion.insert(
        name: 'Vin Alpha',
        domainId: dom2,
        designationId: Value(desId),
      ));

      final list = await db.listCuvees();
      expect(list.length, 3);
      // Alpha Domain sorts before Brumont
      expect(list[0].cuvee.name, 'Vin Alpha');
      expect(list[0].domainName, 'Alpha Domain');
      expect(list[1].cuvee.name, 'Bouscassé');
      expect(list[1].domainName, 'Brumont');
      expect(list[1].designationName, 'Madiran');
      expect(list[1].region, 'Sud-Ouest');
    });

    test('getById returns denormalized data', () async {
      final id = await db.insertCuvee(CuveesCompanion.insert(
        name: 'Montus',
        domainId: domId,
        designationId: Value(desId),
        color: const Value(1),
      ));
      final cuv = await db.getCuveeById(id);
      expect(cuv.cuvee.name, 'Montus');
      expect(cuv.cuvee.color, 1);
      expect(cuv.domainName, 'Brumont');
      expect(cuv.designationName, 'Madiran');
    });
  });

  group('Bottle queries', () {
    late int cuvId;

    setUp(() async {
      final desId = await db.insertDesignation(
          DesignationsCompanion.insert(name: 'Madiran', region: const Value('Sud-Ouest')));
      final domId = await db.insertDomain(
          DomainsCompanion.insert(name: 'Brumont'));
      cuvId = await db.insertCuvee(CuveesCompanion.insert(
        name: 'Montus',
        domainId: domId,
        designationId: Value(desId),
        color: const Value(1),
      ));
    });

    test('list excludes consumed by default', () async {
      await db.insertBottle(BottlesCompanion.insert(
        cuveeId: cuvId,
        vintage: 2019,
        addedAt: '2026-01-01T00:00:00Z',
      ));
      await db.insertBottle(BottlesCompanion.insert(
        cuveeId: cuvId,
        vintage: 2020,
        addedAt: '2026-01-01T00:00:00Z',
        consumedAt: const Value('2026-03-01T00:00:00Z'),
      ));

      final inStock = await db.listBottles();
      expect(inStock.length, 1);
      expect(inStock[0].bottle.vintage, 2019);

      final all = await db.listBottles(includeConsumed: true);
      expect(all.length, 2);
    });

    test('getByTagId returns in-stock bottle', () async {
      await db.insertBottle(BottlesCompanion.insert(
        tagId: const Value('AABB'),
        cuveeId: cuvId,
        vintage: 2019,
        addedAt: '2026-01-01T00:00:00Z',
      ));

      final found = await db.getBottleByTagId('AABB');
      expect(found, isNotNull);
      expect(found!.bottle.vintage, 2019);
      expect(found.domainName, 'Brumont');
    });

    test('getByTagId returns null for consumed bottle', () async {
      await db.insertBottle(BottlesCompanion.insert(
        tagId: const Value('CCDD'),
        cuveeId: cuvId,
        vintage: 2019,
        addedAt: '2026-01-01T00:00:00Z',
        consumedAt: const Value('2026-02-01T00:00:00Z'),
      ));

      final found = await db.getBottleByTagId('CCDD');
      expect(found, isNull);
    });

    test('consumeBottle sets consumed_at and clears tag_id', () async {
      await db.insertBottle(BottlesCompanion.insert(
        tagId: const Value('EEFF'),
        cuveeId: cuvId,
        vintage: 2018,
        addedAt: '2026-01-01T00:00:00Z',
      ));

      final consumed = await db.consumeBottle('EEFF');
      expect(consumed.bottle.consumedAt, isNotNull);
      expect(consumed.bottle.tagId, isNull);
      expect(consumed.bottle.vintage, 2018);
    });

    test('consumeBottle throws for unknown tag', () async {
      expect(
        () => db.consumeBottle('NONEXISTENT'),
        throwsA(isA<StateError>()),
      );
    });


    test('bulkUpdate updates multiple bottles', () async {
      final id1 = await db.insertBottle(BottlesCompanion.insert(
        cuveeId: cuvId,
        vintage: 2019,
        addedAt: '2026-01-01T00:00:00Z',
      ));
      final id2 = await db.insertBottle(BottlesCompanion.insert(
        cuveeId: cuvId,
        vintage: 2020,
        addedAt: '2026-01-01T00:00:00Z',
      ));

      final count = await db.bulkUpdateBottles(
        [id1, id2],
        const BottlesCompanion(vintage: Value(2021)),
      );
      expect(count, 2);

      final b1 = await db.getBottleById(id1);
      final b2 = await db.getBottleById(id2);
      expect(b1.bottle.vintage, 2021);
      expect(b2.bottle.vintage, 2021);
    });

    test('bulkUpdate with empty list returns 0', () async {
      final count = await db.bulkUpdateBottles(
        [],
        const BottlesCompanion(vintage: Value(2021)),
      );
      expect(count, 0);
    });

    test('getById returns denormalized cuvee data', () async {
      final id = await db.insertBottle(BottlesCompanion.insert(
        tagId: const Value('11AA'),
        cuveeId: cuvId,
        vintage: 2019,
        addedAt: '2026-03-15T10:30:00Z',
        purchasePrice: const Value(15.50),
        drinkBefore: const Value(2030),
      ));

      final b = await db.getBottleById(id);
      expect(b.bottle.tagId, '11AA');
      expect(b.bottle.purchasePrice, 15.50);
      expect(b.bottle.drinkBefore, 2030);
      expect(b.cuvee.name, 'Montus');
      expect(b.domainName, 'Brumont');
      expect(b.designationName, 'Madiran');
      expect(b.region, 'Sud-Ouest');
    });
  });

  group('Completions', () {
    test('searchDesignationNames returns matching prefixes', () async {
      await db.insertDesignation(DesignationsCompanion.insert(name: 'Madiran'));
      await db.insertDesignation(DesignationsCompanion.insert(name: 'Margaux'));
      await db.insertDesignation(DesignationsCompanion.insert(name: 'Cahors'));

      final results = await db.searchDesignationNames('Ma');
      expect(results, ['Madiran', 'Margaux']);
    });

    test('searchDomainNames returns matching prefixes', () async {
      await db.insertDomain(DomainsCompanion.insert(name: 'Domaine Brumont'));
      await db.insertDomain(DomainsCompanion.insert(name: 'Domaine Cauhapé'));
      await db.insertDomain(DomainsCompanion.insert(name: 'Château Margaux'));

      final results = await db.searchDomainNames('Domaine');
      expect(results, ['Domaine Brumont', 'Domaine Cauhapé']);
    });

    test('searchCuveeNames returns matching prefixes', () async {
      final desId = await db.insertDesignation(
          DesignationsCompanion.insert(name: 'Test'));
      final domId = await db.insertDomain(
          DomainsCompanion.insert(name: 'Test'));
      await db.insertCuvee(CuveesCompanion.insert(
          name: 'Château Montus', domainId: domId, designationId: Value(desId)));
      await db.insertCuvee(CuveesCompanion.insert(
          name: 'Château Bouscassé', domainId: domId, designationId: Value(desId)));
      await db.insertCuvee(CuveesCompanion.insert(
          name: 'Le Jardin', domainId: domId, designationId: Value(desId)));

      final results = await db.searchCuveeNames('Château');
      expect(results, ['Château Bouscassé', 'Château Montus']);
    });
  });

  group('toJson()', () {
    test('Designation toJson has snake_case keys', () {
      const des = Designation(
        id: 1,
        name: 'Madiran',
        region: 'Sud-Ouest',
        description: 'Test',
      );
      final json = des.toJson();
      expect(json, {
        'id': 1,
        'name': 'Madiran',
        'region': 'Sud-Ouest',
        'description': 'Test',
      });
    });

    test('Domain toJson has snake_case keys', () {
      const dom = Domain(id: 1, name: 'Brumont', description: '');
      final json = dom.toJson();
      expect(json, {'id': 1, 'name': 'Brumont', 'description': ''});
    });

    test('CuveeWithNames toJson has denormalized fields', () {
      final cuv = CuveeWithNames(
        cuvee: const Cuvee(
          id: 1,
          name: 'Montus',
          domainId: 1,
          designationId: 3,
          color: 1,
          description: '',
        ),
        domainName: 'Brumont',
        designationName: 'Madiran',
        region: 'Sud-Ouest',
      );
      final json = cuv.toJson();
      expect(json, {
        'id': 1,
        'name': 'Montus',
        'domain_id': 1,
        'designation_id': 3,
        'color': 1,
        'description': '',
        'domain_name': 'Brumont',
        'designation_name': 'Madiran',
        'region': 'Sud-Ouest',
      });
    });

    test('BottleWithCuvee toJson omits null fields', () {
      final bwc = BottleWithCuvee(
        bottle: const Bottle(
          id: 42,
          tagId: '04A32BFF',
          cuveeId: 1,
          vintage: 2019,
          description: 'Notes',
          purchasePrice: null,
          drinkBefore: null,
          addedAt: '2026-03-15T10:30:00Z',
          consumedAt: null,
        ),
        cuvee: const Cuvee(
          id: 1,
          name: 'Montus',
          domainId: 1,
          designationId: 3,
          color: 1,
          description: '',
        ),
        domainName: 'Brumont',
        designationName: 'Madiran',
        region: 'Sud-Ouest',
      );
      final json = bwc.toJson();

      expect(json['id'], 42);
      expect(json['tag_id'], '04A32BFF');
      expect(json['vintage'], 2019);
      expect(json['added_at'], '2026-03-15T10:30:00Z');
      expect(json.containsKey('purchase_price'), isFalse);
      expect(json.containsKey('drink_before'), isFalse);
      expect(json.containsKey('consumed_at'), isFalse);
      expect(json['cuvee'], isA<Map<String, dynamic>>());
      expect(json['cuvee']['designation_id'], 3);
      expect(json['cuvee']['domain_name'], 'Brumont');
    });

    test('BottleWithCuvee toJson includes non-null optional fields', () {
      final bwc = BottleWithCuvee(
        bottle: const Bottle(
          id: 1,
          tagId: null,
          cuveeId: 1,
          vintage: 2019,
          description: '',
          purchasePrice: 15.50,
          drinkBefore: 2030,
          addedAt: '2026-01-01T00:00:00Z',
          consumedAt: '2026-03-01T00:00:00Z',
        ),
        cuvee: const Cuvee(
          id: 1,
          name: 'X',
          domainId: 1,
          designationId: 1,
          color: 0,
          description: '',
        ),
        domainName: 'D',
        designationName: 'Des',
        region: 'R',
      );
      final json = bwc.toJson();

      expect(json.containsKey('tag_id'), isFalse);
      expect(json['purchase_price'], 15.50);
      expect(json['drink_before'], 2030);
      expect(json['consumed_at'], '2026-03-01T00:00:00Z');
    });
  });
}
