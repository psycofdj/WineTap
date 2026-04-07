import 'dart:async';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:wine_tap_mobile/screens/identify_screen.dart';
import 'package:wine_tap_mobile/server/database.dart';
import 'package:wine_tap_mobile/services/nfc_exceptions.dart';
import 'package:wine_tap_mobile/services/nfc_service.dart';

class MockNfcService implements NfcService {
  Completer<String>? _readCompleter;
  bool stopReadingCalled = false;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<String> readTagId() {
    _readCompleter = Completer<String>();
    return _readCompleter!.future;
  }

  void completeRead(String tagId) => _readCompleter?.complete(tagId);
  void failRead(Object error) => _readCompleter?.completeError(error);

  @override
  Future<void> stopReading() async {
    stopReadingCalled = true;
  }
}

void main() {
  late AppDatabase db;
  late MockNfcService mockNfc;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    mockNfc = MockNfcService();

    final desId = await db.insertDesignation(
      DesignationsCompanion.insert(name: 'Madiran'),
    );
    final domId = await db.insertDomain(
      DomainsCompanion.insert(name: 'Domaine Brumont'),
    );
    final cuvId = await db.insertCuvee(CuveesCompanion.insert(
      name: 'Château Montus',
      domainId: domId,
      designationId: Value(desId),
    ));
    await db.insertBottle(BottlesCompanion.insert(
      tagId: const Value('04A32BFF'),
      cuveeId: cuvId,
      vintage: 2019,
      addedAt: DateTime.now().toUtc().toIso8601String(),
    ));
  });

  tearDown(() async {
    await db.close();
  });

  Widget buildApp() {
    return Provider<AppDatabase>.value(
      value: db,
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => IdentifyScreen(nfcService: mockNfc),
                ),
              ),
              child: const Text('Go'),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> pushIdentifyScreen(WidgetTester tester) async {
    await tester.pumpWidget(buildApp());
    await tester.tap(find.text('Go'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('shows scanning state on launch', (tester) async {
    await pushIdentifyScreen(tester);

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('En attente du scan…'), findsOneWidget);
    expect(find.text('Annuler'), findsOneWidget);

    mockNfc.failRead(NfcSessionCancelledException());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  });

  testWidgets('shows bottle details after successful scan', (tester) async {
    await pushIdentifyScreen(tester);
    mockNfc.completeRead('04A32BFF');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Bottle info displayed — proves the tag was found (not consumed/cleared)
    expect(find.text('Domaine Brumont'), findsOneWidget);
    expect(find.text('Château Montus'), findsOneWidget);
    expect(find.text('2019'), findsOneWidget);
    expect(find.text('Madiran'), findsOneWidget);
    expect(find.text('Terminé'), findsOneWidget);
  });

  testWidgets('shows color label when cuvee has a color', (tester) async {
    // Insert a rouge bottle with a different tag.
    final desId2 = await db.insertDesignation(
      DesignationsCompanion.insert(name: 'Bordeaux'),
    );
    final domId2 = await db.insertDomain(
      DomainsCompanion.insert(name: 'Château Margaux'),
    );
    final cuvId2 = await db.insertCuvee(CuveesCompanion.insert(
      name: 'Grand Vin',
      domainId: domId2,
      designationId: Value(desId2),
      color: const Value(1), // rouge
    ));
    await db.insertBottle(BottlesCompanion.insert(
      tagId: const Value('AABB1122'),
      cuveeId: cuvId2,
      vintage: 2020,
      addedAt: DateTime.now().toUtc().toIso8601String(),
    ));

    await pushIdentifyScreen(tester);
    mockNfc.completeRead('AABB1122');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Château Margaux'), findsOneWidget);
    expect(find.text('Grand Vin'), findsOneWidget);
    expect(find.text('2020'), findsOneWidget);
    expect(find.text('Bordeaux'), findsOneWidget);
    expect(find.text('Rouge'), findsOneWidget);
  });

  testWidgets('hides color label when cuvee color is unspecified',
      (tester) async {
    await pushIdentifyScreen(tester);
    mockNfc.completeRead('04A32BFF');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Domaine Brumont'), findsOneWidget);
    expect(find.text('Rouge'), findsNothing);
    expect(find.text('Blanc'), findsNothing);
  });

  testWidgets('shows error for unknown tag', (tester) async {
    await pushIdentifyScreen(tester);
    mockNfc.completeRead('DEADBEEF');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Tag inconnu'), findsOneWidget);
    expect(find.text('Terminé'), findsOneWidget);
  });

  testWidgets('shows error on NFC timeout', (tester) async {
    await pushIdentifyScreen(tester);
    mockNfc.failRead(NfcReadTimeoutException());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining('Aucun tag détecté'), findsOneWidget);
    expect(find.text('Terminé'), findsOneWidget);
  });

  testWidgets('NFC session cancelled pops the screen', (tester) async {
    await pushIdentifyScreen(tester);

    mockNfc.failRead(NfcSessionCancelledException());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(IdentifyScreen), findsNothing);
  });

  testWidgets('done button pops the screen', (tester) async {
    await pushIdentifyScreen(tester);

    mockNfc.completeRead('04A32BFF');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text('Terminé'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(IdentifyScreen), findsNothing);
  });
}
