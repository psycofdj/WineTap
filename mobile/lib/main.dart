import 'dart:developer' as dev;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import 'l10n/strings.dart';
import 'providers/intake_provider.dart';
import 'providers/scan_provider.dart';
import 'providers/server_provider.dart';
import 'screens/consume_screen.dart';
import 'screens/intake_screen.dart';
import 'server/consume_tracker.dart';
import 'server/database.dart';
import 'server/scan_coordinator.dart';
import 'server/server.dart';
import 'services/discovery_service.dart';
import 'services/nfc_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Database
  final db = AppDatabase();

  // 2. Scan coordinator & consume tracker
  final coordinator = ScanCoordinator();
  final consumeTracker = ConsumeTracker();

  // 3. Resolve database file path for backup/restore.
  //    Force a trivial query so Drift's lazy connection materializes the file.
  await db.customSelect('SELECT 1').get();
  final docsDir = await getApplicationDocumentsDirectory();
  final dbFile = File('${docsDir.path}/winetap.sqlite');
  dev.log('dbFile path: ${dbFile.path}, exists: ${await dbFile.exists()}',
      name: 'main');

  // Restart callback: exit the process after a successful restore.
  // The app restarts fresh on next launch with the restored database.
  Future<void> restartDb() async {
    dev.log('Database restored — exiting for clean restart', name: 'main');
    exit(0);
  }

  // 4. HTTP server — running before UI renders
  late final HttpServer server;
  try {
    server = await startServer(db, coordinator, dbFile, restartDb, consumeTracker);
    dev.log(
      'Server started on port ${server.port}',
      name: 'main',
    );
  } catch (e) {
    dev.log('Server failed to start: $e', name: 'main');
    rethrow;
  }

  // 4. mDNS registration (non-fatal — continue without it)
  final discovery = DiscoveryService();
  try {
    await discovery.register(server.port);
    dev.log('mDNS registered _winetap._tcp on port ${server.port}',
        name: 'main');
  } catch (e) {
    dev.log('mDNS registration failed (non-fatal): $e', name: 'main');
  }

  // 5. NFC — constructor starts a persistent session that claims
  //    foreground dispatch (suppresses Android's default tag dialog).
  final nfc = NfcService();

  // 6. UI
  runApp(
    MultiProvider(
      providers: [
        Provider<AppDatabase>.value(value: db),
        Provider<ScanCoordinator>.value(value: coordinator),
        Provider<NfcService>.value(value: nfc),
        ChangeNotifierProvider(create: (_) => ServerProvider(server.port)),
        ChangeNotifierProvider(
          create: (ctx) => ScanProvider(
            db,
            consumeTracker,
            nfcService: ctx.read<NfcService>(),
          ),
        ),
        ChangeNotifierProvider(
          create: (ctx) => IntakeProvider(
            coordinator,
            nfcService: ctx.read<NfcService>(),
            scanProvider: ctx.read<ScanProvider>(),
          ),
        ),
      ],
      child: const WineTapApp(),
    ),
  );
}

class WineTapApp extends StatelessWidget {
  const WineTapApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: S.appTitle,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF722F37),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  static const _screens = [
    ConsumeScreen(),
    IntakeScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    // Auto-switch tabs based on IntakeProvider state (FR12)
    final intake = context.watch<IntakeProvider>();
    final intakeActive = intake.shouldShowIntakeScreen;
    // Derive tab index: intake takes over when active, returns home when done
    final effectiveIndex = intakeActive ? 1 : _currentIndex;

    return Scaffold(
      body: IndexedStack(
        index: effectiveIndex,
        children: _screens,
      ),
      /*
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: effectiveIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.nfc),
            label: S.consumeButton,
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory_2),
            label: S.intake,
          ),
        ],
      ),
      */
    );
  }
}
