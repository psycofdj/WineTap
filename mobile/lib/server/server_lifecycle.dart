import 'dart:developer' as dev;
import 'dart:io';

import '../services/nfc_service.dart';
import 'api/context.dart';
import 'server.dart';
import 'static_site.dart';

const _tag = 'ServerLifecycle';

/// Starts the HTTP server and restarts it when the app returns to the
/// foreground: the OS may have closed the listening socket (N-03, D-06).
class ServerLifecycle {
  ServerLifecycle(this.ctx, {required this.loadSite, required this.nfcService});

  final ApiContext ctx;
  final SiteLoader loadSite;
  final NfcService nfcService;
  HttpServer? _server;

  Future<void> start() async {
    _server = await startServer(ctx, loadSite: loadSite);
    dev.log('server started on port ${_server!.port}', name: _tag);
  }

  /// Closes the server (event streams included), re-establishes the NFC
  /// session, starts a new server. Browsers reconnect by themselves.
  Future<void> restart() async {
    try {
      await ctx.events.closeAll();
      await _server?.close(force: true);
    } catch (e) {
      dev.log('restart: close failed (non-fatal): $e', name: _tag);
    }
    try {
      await nfcService.restartSession();
    } catch (e) {
      dev.log('restart: NFC restart failed (non-fatal): $e', name: _tag);
    }
    await start();
  }
}
