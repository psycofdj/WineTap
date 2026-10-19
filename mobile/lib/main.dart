import 'dart:developer' as dev;
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'native/app_shell.dart';
import 'native/network.dart';
import 'native/prefs_store.dart';
import 'native/reading.dart';
import 'server/api/context.dart';
import 'server/database.dart';
import 'server/db_holder.dart';
import 'server/dev_seed.dart';
import 'server/events.dart';
import 'server/preferences.dart';
import 'server/remote_scan.dart';
import 'server/server_lifecycle.dart';
import 'server/sessions.dart';
import 'services/nfc_service.dart';

/// Reads a file of the built site from the app's assets (assets/site/).
Future<List<int>?> loadSite(String path) async {
  try {
    final data = await rootBundle.load('assets/site/$path');
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  } catch (_) {
    return null;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Base (schéma inchangé, C-01). Une requête force l'ouverture du fichier.
  final db = AppDatabase();
  await db.customSelect('SELECT 1').get();
  try {
    await seedDevDataIfNeeded(db);
  } catch (e) {
    dev.log('seedDevDataIfNeeded failed (non-fatal): $e', name: 'main');
  }
  final docs = await getApplicationDocumentsDirectory();
  final dbs = DbHolder(
    db,
    File('${docs.path}/winetap.sqlite'),
    () => AppDatabase(),
  );

  // 2. État hors de la base : sessions autorisées, réglages.
  final store = SharedPrefsStore(await SharedPreferences.getInstance());
  final sessions = SessionStore(store)..load();
  final events = EventHub(isAuthorized: sessions.isAuthorized);
  final ctx = ApiContext(
    dbs: dbs,
    sessions: sessions,
    events: events,
    scan: RemoteScan(events),
    settings: Settings(store),
    phone: PhoneInfo(
      name: Platform.isIOS ? 'iPhone' : 'Android',
      localAddress: localAddress,
    ),
  );

  // 3. NFC (session permanente sur Android) et serveur, avant l'interface.
  final nfc = NfcService();
  final lifecycle = ServerLifecycle(ctx, loadSite: loadSite, nfcService: nfc);
  await lifecycle.start();

  runApp(
    WineTapApp(
      ctx: ctx,
      reading: ReadingController(nfc, ctx.scan),
      lifecycle: lifecycle,
    ),
  );
}
