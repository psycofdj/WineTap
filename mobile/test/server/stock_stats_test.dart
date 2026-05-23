import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wine_tap_mobile/l10n/strings.dart';
import 'package:wine_tap_mobile/server/database.dart';
import 'package:wine_tap_mobile/server/seed_data.dart';

Future<AppDatabase> _seededDb() async {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  await seedDatabase(db);
  return db;
}

Future<int> _designationWithRegion(AppDatabase db, String region) async {
  return db
      .into(db.designations)
      .insert(
        DesignationsCompanion.insert(
          name: 'Test-$region',
          region: Value(region),
        ),
      );
}

Future<int> _cuvee(
  AppDatabase db, {
  required int domainId,
  required int designationId,
  required int color,
}) {
  return db
      .into(db.cuvees)
      .insert(
        CuveesCompanion.insert(
          name: 'C$color-$designationId',
          domainId: domainId,
          designationId: Value(designationId),
          color: Value(color),
        ),
      );
}

Future<void> _bottle(
  AppDatabase db, {
  required int cuveeId,
  required int vintage,
  String? consumedAt,
}) async {
  await db
      .into(db.bottles)
      .insert(
        BottlesCompanion.insert(
          cuveeId: cuveeId,
          vintage: vintage,
          addedAt: '2026-01-01T00:00:00Z',
          consumedAt: consumedAt == null
              ? const Value.absent()
              : Value(consumedAt),
        ),
      );
}

void main() {
  group('getStockStats', () {
    test(
      'counts only in-stock bottles and buckets unknowns into Inconnue',
      () async {
        final db = await _seededDb();
        addTearDown(db.close);

        final domainId = (await (db.select(
          db.domains,
        )..limit(1)).getSingle()).id;
        // Designation 0 is the (unassigned) sentinel with empty region.
        final desBordeaux = await _designationWithRegion(db, 'Bordeaux');
        final desEmpty = await _designationWithRegion(db, '');

        // Cuvées covering color 0 (unknown), 1 (Rouge), 2 (Blanc) and the
        // three region cases: 'Bordeaux', '' explicit, unassigned (id 0).
        final cRedBordeaux = await _cuvee(
          db,
          domainId: domainId,
          designationId: desBordeaux,
          color: 1,
        );
        final cWhiteEmpty = await _cuvee(
          db,
          domainId: domainId,
          designationId: desEmpty,
          color: 2,
        );
        final cUnknownUnassigned = await _cuvee(
          db,
          domainId: domainId,
          designationId: 0,
          color: 0,
        );

        // 3 in-stock + 1 consumed for cRedBordeaux.
        await _bottle(db, cuveeId: cRedBordeaux, vintage: 2020);
        await _bottle(db, cuveeId: cRedBordeaux, vintage: 2021);
        await _bottle(db, cuveeId: cRedBordeaux, vintage: 2019);
        await _bottle(
          db,
          cuveeId: cRedBordeaux,
          vintage: 2018,
          consumedAt: '2026-04-01T00:00:00Z',
        );

        // 2 in-stock for cWhiteEmpty.
        await _bottle(db, cuveeId: cWhiteEmpty, vintage: 2022);
        await _bottle(db, cuveeId: cWhiteEmpty, vintage: 2023);

        // 1 in-stock for cUnknownUnassigned.
        await _bottle(db, cuveeId: cUnknownUnassigned, vintage: 2017);

        final stats = await db.getStockStats();

        expect(stats.totalInStock, 6);
        expect(stats.byColor, {1: 3, 2: 2, 0: 1});
        expect(stats.byRegion, {
          'Bordeaux': 3,
          S.statsInconnue: 3, // 2 from empty-region designation + 1 unassigned
        });
      },
    );

    test('returns zeros and empty maps when nothing is in stock', () async {
      final db = await _seededDb();
      addTearDown(db.close);

      final stats = await db.getStockStats();
      expect(stats.totalInStock, 0);
      expect(stats.byColor, isEmpty);
      expect(stats.byRegion, isEmpty);
    });
  });
}
