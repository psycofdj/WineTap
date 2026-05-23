import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:wine_tap_mobile/screens/tasting_history_screen.dart';
import 'package:wine_tap_mobile/server/database.dart';

Future<int> _seedCuvee(AppDatabase db) async {
  final desId = await db.insertDesignation(
    DesignationsCompanion.insert(name: 'Madiran'),
  );
  final domId = await db.insertDomain(
    DomainsCompanion.insert(name: 'Domaine Brumont'),
  );
  return db.insertCuvee(CuveesCompanion.insert(
    name: 'Château Montus',
    domainId: domId,
    designationId: Value(desId),
  ));
}

Future<void> _seedConsumed(AppDatabase db, int cuvId, int count) async {
  for (var i = 0; i < count; i++) {
    final ts = DateTime.utc(2026, 1, 1).add(Duration(days: i));
    await db.insertBottle(BottlesCompanion.insert(
      cuveeId: cuvId,
      vintage: 2000 + i,
      addedAt: '2026-01-01T00:00:00Z',
      consumedAt: Value(ts.toIso8601String()),
    ));
  }
}

Widget _wrap(AppDatabase db) {
  return Provider<AppDatabase>.value(
    value: db,
    child: const MaterialApp(home: TastingHistoryScreen()),
  );
}

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  testWidgets('shows empty state when no consumed bottles', (tester) async {
    await tester.pumpWidget(_wrap(db));
    await tester.pumpAndSettle();

    expect(find.text('Aucune bouteille consommée'), findsOneWidget);
  });

  testWidgets('renders first page of 20 when 25 rows exist', (tester) async {
    // Tall viewport so the ListView mounts all 20 cards in one shot.
    tester.view.physicalSize = const Size(800, 6000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final cuvId = await _seedCuvee(db);
    await _seedConsumed(db, cuvId, 25);

    await tester.pumpWidget(_wrap(db));
    await tester.pumpAndSettle();

    // Card title is the designation name → 'Madiran' appears once per card.
    expect(find.text('Madiran'), findsNWidgets(20));
  });

  testWidgets('infinite scroll appends remaining rows', (tester) async {
    final cuvId = await _seedCuvee(db);
    await _seedConsumed(db, cuvId, 25);

    await tester.pumpWidget(_wrap(db));
    await tester.pumpAndSettle();

    // Vintage 2000 is the oldest of 25 → only visible after page 2 loads.
    // Page 1 holds vintages 2024..2005; page 2 holds 2004..2000.
    final lastCard = find.text('Château Montus · 2000');
    expect(lastCard, findsNothing);

    await tester.scrollUntilVisible(
      lastCard,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(lastCard, findsOneWidget);
  });
}
