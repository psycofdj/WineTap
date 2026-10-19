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
      final desId = await db.insertDesignation(
        DesignationsCompanion.insert(name: 'Madiran'),
      );
      expect(desId, greaterThan(0));

      final domId = await db.insertDomain(
        DomainsCompanion.insert(name: 'Domaine Brumont'),
      );
      expect(domId, greaterThan(0));

      final cuvId = await db.insertCuvee(
        CuveesCompanion.insert(name: 'Château Montus', domainId: domId),
      );
      expect(cuvId, greaterThan(0));

      final botId = await db.insertBottle(
        BottlesCompanion.insert(
          cuveeId: cuvId,
          vintage: 2019,
          addedAt: '2026-03-15T10:30:00Z',
        ),
      );
      expect(botId, greaterThan(0));
    });

    test('designation name is unique', () async {
      await db.insertDesignation(DesignationsCompanion.insert(name: 'Cahors'));
      expect(
        () =>
            db.insertDesignation(DesignationsCompanion.insert(name: 'Cahors')),
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
        DesignationsCompanion.insert(name: 'Madiran'),
      );
      final domId = await db.insertDomain(
        DomainsCompanion.insert(name: 'Brumont'),
      );
      final cuvId = await db.insertCuvee(
        CuveesCompanion.insert(
          name: 'Montus',
          domainId: domId,
          designationId: Value(desId),
        ),
      );
      await db.insertBottle(
        BottlesCompanion.insert(
          tagId: const Value('04A32BFF'),
          cuveeId: cuvId,
          vintage: 2019,
          addedAt: '2026-01-01T00:00:00Z',
        ),
      );
      expect(
        () => db.insertBottle(
          BottlesCompanion.insert(
            tagId: const Value('04A32BFF'),
            cuveeId: cuvId,
            vintage: 2020,
            addedAt: '2026-01-01T00:00:00Z',
          ),
        ),
        throwsA(isA<SqliteException>()),
      );
    });

    test('foreign key cuvees → domains', () async {
      await expectLater(
        db.insertCuvee(CuveesCompanion.insert(name: 'Orphan', domainId: 9999)),
        throwsA(isA<SqliteException>()),
      );
    });

    test('designation_id=0 means unassigned (no FK enforcement)', () async {
      final domId = await db.insertDomain(
        DomainsCompanion.insert(name: 'Brumont'),
      );
      // designation_id=0 is valid (unassigned); leftOuterJoin handles it
      final cuvId = await db.insertCuvee(
        CuveesCompanion.insert(name: 'Unassigned', domainId: domId),
      );
      final cuv = await db.getCuveeById(cuvId);
      expect(cuv.cuvee.designationId, 0);
      expect(cuv.designationName, '(unassigned)');
      expect(cuv.region, '');
    });

    test('foreign key bottles → cuvees', () async {
      await expectLater(
        db.insertBottle(
          BottlesCompanion.insert(
            cuveeId: 9999,
            vintage: 2020,
            addedAt: '2026-01-01T00:00:00Z',
          ),
        ),
        throwsA(isA<SqliteException>()),
      );
    });

    test('default values are applied', () async {
      final desId = await db.insertDesignation(
        DesignationsCompanion.insert(name: 'Margaux'),
      );
      final des = await db.getDesignationById(desId);
      expect(des.region, '');
      expect(des.description, '');

      final domId = await db.insertDomain(
        DomainsCompanion.insert(name: 'Test Domain'),
      );
      final dom = await db.getDomainById(domId);
      expect(dom.description, '');

      final cuvId = await db.insertCuvee(
        CuveesCompanion.insert(name: 'Test Cuvee', domainId: domId),
      );
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
      await db.insertDesignation(
        DesignationsCompanion.insert(name: 'Bordeaux'),
      );

      final list = await db.listDesignations();
      // (unassigned) is seeded at id=0 by onCreate
      expect(list.map((d) => d.name).toList(), [
        '(unassigned)',
        'Alsace',
        'Bordeaux',
        'Cahors',
      ]);
    });

    test('getById returns correct record', () async {
      final id = await db.insertDesignation(
        DesignationsCompanion.insert(
          name: 'Madiran',
          region: const Value('Sud-Ouest'),
        ),
      );
      final des = await db.getDesignationById(id);
      expect(des.name, 'Madiran');
      expect(des.region, 'Sud-Ouest');
    });

    test('update modifies record', () async {
      final id = await db.insertDesignation(
        DesignationsCompanion.insert(name: 'Old'),
      );
      await db.updateDesignation(
        DesignationsCompanion(
          id: Value(id),
          name: const Value('New'),
          region: const Value('Updated'),
          description: const Value('Desc'),
        ),
      );
      final des = await db.getDesignationById(id);
      expect(des.name, 'New');
      expect(des.region, 'Updated');
    });

    test('delete removes record', () async {
      final id = await db.insertDesignation(
        DesignationsCompanion.insert(name: 'ToDelete'),
      );
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

      await db.updateDomain(
        DomainsCompanion(
          id: Value(id),
          name: const Value('Updated'),
          description: const Value('Desc'),
        ),
      );
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
        DesignationsCompanion.insert(
          name: 'Madiran',
          region: const Value('Sud-Ouest'),
        ),
      );
      domId = await db.insertDomain(DomainsCompanion.insert(name: 'Brumont'));
    });

    test(
      'list returns with denormalized names, ordered by domain then name',
      () async {
        final dom2 = await db.insertDomain(
          DomainsCompanion.insert(name: 'Alpha Domain'),
        );

        await db.insertCuvee(
          CuveesCompanion.insert(
            name: 'Bouscassé',
            domainId: domId,
            designationId: Value(desId),
          ),
        );
        await db.insertCuvee(
          CuveesCompanion.insert(
            name: 'Montus',
            domainId: domId,
            designationId: Value(desId),
          ),
        );
        await db.insertCuvee(
          CuveesCompanion.insert(
            name: 'Vin Alpha',
            domainId: dom2,
            designationId: Value(desId),
          ),
        );

        final list = await db.listCuvees();
        expect(list.length, 3);
        // Alpha Domain sorts before Brumont
        expect(list[0].cuvee.name, 'Vin Alpha');
        expect(list[0].domainName, 'Alpha Domain');
        expect(list[1].cuvee.name, 'Bouscassé');
        expect(list[1].domainName, 'Brumont');
        expect(list[1].designationName, 'Madiran');
        expect(list[1].region, 'Sud-Ouest');
      },
    );

    test('getById returns denormalized data', () async {
      final id = await db.insertCuvee(
        CuveesCompanion.insert(
          name: 'Montus',
          domainId: domId,
          designationId: Value(desId),
          color: const Value(1),
        ),
      );
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
        DesignationsCompanion.insert(
          name: 'Madiran',
          region: const Value('Sud-Ouest'),
        ),
      );
      final domId = await db.insertDomain(
        DomainsCompanion.insert(name: 'Brumont'),
      );
      cuvId = await db.insertCuvee(
        CuveesCompanion.insert(
          name: 'Montus',
          domainId: domId,
          designationId: Value(desId),
          color: const Value(1),
        ),
      );
    });

    test('list excludes consumed by default', () async {
      await db.insertBottle(
        BottlesCompanion.insert(
          cuveeId: cuvId,
          vintage: 2019,
          addedAt: '2026-01-01T00:00:00Z',
        ),
      );
      await db.insertBottle(
        BottlesCompanion.insert(
          cuveeId: cuvId,
          vintage: 2020,
          addedAt: '2026-01-01T00:00:00Z',
          consumedAt: const Value('2026-03-01T00:00:00Z'),
        ),
      );

      final inStock = await db.listBottles();
      expect(inStock.length, 1);
      expect(inStock[0].bottle.vintage, 2019);

      final all = await db.listBottles(includeConsumed: true);
      expect(all.length, 2);
    });

    test('getByTagId returns in-stock bottle', () async {
      await db.insertBottle(
        BottlesCompanion.insert(
          tagId: const Value('AABB'),
          cuveeId: cuvId,
          vintage: 2019,
          addedAt: '2026-01-01T00:00:00Z',
        ),
      );

      final found = await db.getBottleByTagId('AABB');
      expect(found, isNotNull);
      expect(found!.bottle.vintage, 2019);
      expect(found.domainName, 'Brumont');
    });

    test('getByTagId returns null for consumed bottle', () async {
      await db.insertBottle(
        BottlesCompanion.insert(
          tagId: const Value('CCDD'),
          cuveeId: cuvId,
          vintage: 2019,
          addedAt: '2026-01-01T00:00:00Z',
          consumedAt: const Value('2026-02-01T00:00:00Z'),
        ),
      );

      final found = await db.getBottleByTagId('CCDD');
      expect(found, isNull);
    });

    test('consumeBottle sets consumed_at and clears tag_id', () async {
      await db.insertBottle(
        BottlesCompanion.insert(
          tagId: const Value('EEFF'),
          cuveeId: cuvId,
          vintage: 2018,
          addedAt: '2026-01-01T00:00:00Z',
        ),
      );

      final consumed = await db.consumeBottle('EEFF');
      expect(consumed.bottle.consumedAt, isNotNull);
      expect(consumed.bottle.tagId, isNull);
      expect(consumed.bottle.vintage, 2018);
    });

    test('consumeBottle throws for unknown tag', () async {
      expect(() => db.consumeBottle('NONEXISTENT'), throwsA(isA<StateError>()));
    });

    test('updateBottleFields updates only specified fields', () async {
      final id = await db.insertBottle(
        BottlesCompanion.insert(
          cuveeId: cuvId,
          vintage: 2019,
          addedAt: '2026-01-01T00:00:00Z',
          description: const Value('original'),
        ),
      );

      final count = await db.updateBottleFields(
        id,
        const BottlesCompanion(vintage: Value(2021)),
      );
      expect(count, 1);

      final b = await db.getBottleById(id);
      expect(b.bottle.vintage, 2021);
      expect(b.bottle.description, 'original');
    });

    test('getById returns denormalized cuvee data', () async {
      final id = await db.insertBottle(
        BottlesCompanion.insert(
          tagId: const Value('11AA'),
          cuveeId: cuvId,
          vintage: 2019,
          addedAt: '2026-03-15T10:30:00Z',
          purchasePrice: const Value(15.50),
          drinkBefore: const Value(2030),
        ),
      );

      final b = await db.getBottleById(id);
      expect(b.bottle.tagId, '11AA');
      expect(b.bottle.purchasePrice, 15.50);
      expect(b.bottle.drinkBefore, 2030);
      expect(b.cuvee.name, 'Montus');
      expect(b.domainName, 'Brumont');
      expect(b.designationName, 'Madiran');
      expect(b.region, 'Sud-Ouest');
    });

    test('listConsumedBottles returns empty when none consumed', () async {
      await db.insertBottle(
        BottlesCompanion.insert(
          cuveeId: cuvId,
          vintage: 2019,
          addedAt: '2026-01-01T00:00:00Z',
        ),
      );

      final result = await db.listConsumedBottles();
      expect(result, isEmpty);
    });

    test('listConsumedBottles excludes in-stock rows', () async {
      await db.insertBottle(
        BottlesCompanion.insert(
          cuveeId: cuvId,
          vintage: 2019,
          addedAt: '2026-01-01T00:00:00Z',
        ),
      );
      await db.insertBottle(
        BottlesCompanion.insert(
          cuveeId: cuvId,
          vintage: 2020,
          addedAt: '2026-01-01T00:00:00Z',
          consumedAt: const Value('2026-03-01T00:00:00Z'),
        ),
      );

      final result = await db.listConsumedBottles();
      expect(result, hasLength(1));
      expect(result[0].bottle.vintage, 2020);
    });

    test('listConsumedBottles orders by consumedAt desc', () async {
      await db.insertBottle(
        BottlesCompanion.insert(
          cuveeId: cuvId,
          vintage: 2018,
          addedAt: '2026-01-01T00:00:00Z',
          consumedAt: const Value('2026-01-15T00:00:00Z'),
        ),
      );
      await db.insertBottle(
        BottlesCompanion.insert(
          cuveeId: cuvId,
          vintage: 2019,
          addedAt: '2026-01-01T00:00:00Z',
          consumedAt: const Value('2026-03-10T00:00:00Z'),
        ),
      );
      await db.insertBottle(
        BottlesCompanion.insert(
          cuveeId: cuvId,
          vintage: 2020,
          addedAt: '2026-01-01T00:00:00Z',
          consumedAt: const Value('2026-02-05T00:00:00Z'),
        ),
      );

      final result = await db.listConsumedBottles();
      expect(result.map((b) => b.bottle.vintage).toList(), [2019, 2020, 2018]);
    });

    test('listConsumedBottles respects limit and offset', () async {
      for (var i = 0; i < 25; i++) {
        // consumedAt strictly increases so order is deterministic
        final ts = DateTime.utc(2026, 1, 1).add(Duration(days: i));
        await db.insertBottle(
          BottlesCompanion.insert(
            cuveeId: cuvId,
            vintage: 2000 + i,
            addedAt: '2026-01-01T00:00:00Z',
            consumedAt: Value(ts.toIso8601String()),
          ),
        );
      }

      final page0 = await db.listConsumedBottles(limit: 20, offset: 0);
      expect(page0, hasLength(20));
      // Newest first → vintage 2024 (i=24) is most recent
      expect(page0.first.bottle.vintage, 2024);

      final page1 = await db.listConsumedBottles(limit: 20, offset: 20);
      expect(page1, hasLength(5));
      // Oldest of the 25 is vintage 2000 (i=0)
      expect(page1.last.bottle.vintage, 2000);

      final page2 = await db.listConsumedBottles(limit: 20, offset: 40);
      expect(page2, isEmpty);
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
        DesignationsCompanion.insert(name: 'Test'),
      );
      final domId = await db.insertDomain(
        DomainsCompanion.insert(name: 'Test'),
      );
      await db.insertCuvee(
        CuveesCompanion.insert(
          name: 'Château Montus',
          domainId: domId,
          designationId: Value(desId),
        ),
      );
      await db.insertCuvee(
        CuveesCompanion.insert(
          name: 'Château Bouscassé',
          domainId: domId,
          designationId: Value(desId),
        ),
      );
      await db.insertCuvee(
        CuveesCompanion.insert(
          name: 'Le Jardin',
          domainId: domId,
          designationId: Value(desId),
        ),
      );

      final results = await db.searchCuveeNames('Château');
      expect(results, ['Château Bouscassé', 'Château Montus']);
    });
  });
}
