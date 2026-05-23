import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wine_tap_mobile/server/database.dart';
import 'package:wine_tap_mobile/server/dev_seed.dart';
import 'package:wine_tap_mobile/server/seed_data.dart';

/// Builds an in-memory DB and runs the production designations/domains seed,
/// so cuvée lookups in dev_seed have something to find.
Future<AppDatabase> _seededRefDb() async {
  // AppDatabase.forTesting already runs onCreate, which inserts the
  // (unassigned) sentinel. We only need to add the production reference data.
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  await seedDatabase(db);
  return db;
}

Future<bool> _devTrue() async => true;
Future<bool> _devFalse() async => false;

void main() {
  group('dev_seed gate', () {
    test('skips when not a dev build', () async {
      final db = await _seededRefDb();
      addTearDown(db.close);

      await seedDevDataIfNeeded(db, isDev: _devFalse);
      final bottles = await db.select(db.bottles).get();
      expect(bottles, isEmpty);
    });

    test('skips when bottles already present', () async {
      final db = await _seededRefDb();
      addTearDown(db.close);

      // Insert one bottle manually so the table is non-empty.
      final domId =
          (await (db.select(db.domains)..limit(1)).getSingle()).id;
      final cuvId = await db.into(db.cuvees).insert(
            CuveesCompanion.insert(name: 'Sentinel', domainId: domId),
          );
      await db.into(db.bottles).insert(BottlesCompanion.insert(
            cuveeId: cuvId,
            vintage: 2020,
            addedAt: '2026-01-01T00:00:00Z',
          ));

      await seedDevDataIfNeeded(db, isDev: _devTrue);
      final bottles = await db.select(db.bottles).get();
      expect(bottles, hasLength(1));
    });
  });

  group('dev_seed catalog', () {
    test('seeds ≥20 cuvées and ≥60 bottles, ≥20 consumed', () async {
      final db = await _seededRefDb();
      addTearDown(db.close);

      await seedDevDataIfNeeded(db, isDev: _devTrue);

      final cuvees = await db.select(db.cuvees).get();
      expect(cuvees.length, greaterThanOrEqualTo(20));

      final bottles = await db.select(db.bottles).get();
      expect(bottles.length, greaterThanOrEqualTo(60));

      final consumed =
          bottles.where((b) => b.consumedAt != null).toList();
      expect(consumed.length, greaterThanOrEqualTo(20));

      // Consumed invariant: tagId must be null.
      for (final b in consumed) {
        expect(b.tagId, isNull,
            reason: 'consumed bottle ${b.id} unexpectedly has tagId');
      }
    });

    test('covers every wine color value 1..5', () async {
      final db = await _seededRefDb();
      addTearDown(db.close);

      await seedDevDataIfNeeded(db, isDev: _devTrue);

      final cuvees = await db.select(db.cuvees).get();
      final colors = cuvees.map((c) => c.color).toSet();
      expect(colors, containsAll(<int>{1, 2, 3, 4, 5}));
    });

    test('is idempotent — second call inserts nothing', () async {
      final db = await _seededRefDb();
      addTearDown(db.close);

      await seedDevDataIfNeeded(db, isDev: _devTrue);
      final after1 = (await db.select(db.bottles).get()).length;

      await seedDevDataIfNeeded(db, isDev: _devTrue);
      final after2 = (await db.select(db.bottles).get()).length;

      expect(after2, after1);
    });

    test('post-seed listConsumedBottles returns 20 in DESC order', () async {
      final db = await _seededRefDb();
      addTearDown(db.close);

      await seedDevDataIfNeeded(db, isDev: _devTrue);

      final page0 = await db.listConsumedBottles(limit: 20, offset: 0);
      expect(page0, hasLength(20));
      for (var i = 1; i < page0.length; i++) {
        expect(
          page0[i - 1].bottle.consumedAt!.compareTo(page0[i].bottle.consumedAt!),
          greaterThanOrEqualTo(0),
          reason: 'rows must be ordered consumedAt DESC',
        );
      }
    });
  });
}
