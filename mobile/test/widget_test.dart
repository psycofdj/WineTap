import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:wine_tap_mobile/providers/intake_provider.dart';
import 'package:wine_tap_mobile/providers/scan_provider.dart';
import 'package:wine_tap_mobile/providers/server_provider.dart';
import 'package:wine_tap_mobile/server/consume_tracker.dart';
import 'package:wine_tap_mobile/server/database.dart';
import 'package:wine_tap_mobile/server/scan_coordinator.dart';
import 'package:wine_tap_mobile/services/nfc_service.dart';
import 'package:wine_tap_mobile/main.dart';

void main() {
  testWidgets('App renders with consume button on home screen', (WidgetTester tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final coordinator = ScanCoordinator();
    final nfc = NoOpNfcService();
    addTearDown(db.close);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AppDatabase>.value(value: db),
          Provider<ScanCoordinator>.value(value: coordinator),
          Provider<NfcService>.value(value: nfc),
          ChangeNotifierProvider(create: (_) => ServerProvider(8080)),
          ChangeNotifierProvider(
            create: (_) => ScanProvider(db, ConsumeTracker(), nfcService: nfc),
          ),
          ChangeNotifierProvider(
            create: (_) => IntakeProvider(coordinator, nfcService: nfc),
          ),
        ],
        child: const WineTapApp(),
      ),
    );
    await tester.pump();

    expect(find.text('Consommer une bouteille'), findsOneWidget);
  });
}
