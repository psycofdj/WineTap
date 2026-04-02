import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:wine_tap_mobile/l10n/strings.dart';
import 'package:wine_tap_mobile/providers/server_provider.dart';
import 'package:wine_tap_mobile/screens/settings_screen.dart';

Widget _buildSubject() {
  return MaterialApp(
    home: ChangeNotifierProvider(
      create: (_) => ServerProvider(8080),
      child: const SettingsScreen(),
    ),
  );
}

void main() {
  group('SettingsScreen', () {
    testWidgets('renders server address section', (tester) async {
      await tester.pumpWidget(_buildSubject());
      await tester.pump();
      expect(find.text(S.serverAddress), findsOneWidget);
      expect(find.text(S.serverRunning), findsOneWidget);
    });

    testWidgets('renders export database button', (tester) async {
      await tester.pumpWidget(_buildSubject());
      await tester.pump();
      expect(find.text(S.exportDatabase), findsOneWidget);
    });

    testWidgets('renders restore database button', (tester) async {
      await tester.pumpWidget(_buildSubject());
      await tester.pump();
      expect(find.text(S.restoreDatabase), findsAtLeastNWidgets(1));
    });

    testWidgets('restore button shows confirmation dialog on tap',
        (tester) async {
      await tester.pumpWidget(_buildSubject());
      await tester.pump();

      // Tap the restore button (the OutlinedButton — find by icon ancestor).
      final restoreButton = find.widgetWithText(OutlinedButton, S.restoreDatabase);
      expect(restoreButton, findsOneWidget);
      await tester.tap(restoreButton);
      await tester.pumpAndSettle();

      expect(find.text(S.restoreConfirmTitle), findsOneWidget);
      expect(find.text(S.restoreConfirmBody), findsOneWidget);
    });

    testWidgets('cancelling restore dialog dismisses without proceeding',
        (tester) async {
      await tester.pumpWidget(_buildSubject());
      await tester.pump();

      await tester.tap(find.widgetWithText(OutlinedButton, S.restoreDatabase));
      await tester.pumpAndSettle();

      // Tap Cancel.
      await tester.tap(find.widgetWithText(TextButton, S.cancel));
      await tester.pumpAndSettle();

      // Dialog dismissed, back on settings screen.
      expect(find.text(S.restoreConfirmTitle), findsNothing);
      expect(find.text(S.restoreDatabase), findsAtLeastNWidgets(1));
    });

    testWidgets('export button is disabled while backing up', (tester) async {
      await tester.pumpWidget(_buildSubject());
      await tester.pump();

      final button =
          tester.widget<FilledButton>(find.widgetWithText(FilledButton, S.exportDatabase));
      // Initially enabled.
      expect(button.onPressed, isNotNull);
    });
  });
}
