import 'dart:developer' as dev;
import 'dart:io';

import 'consume_tracker.dart';
import 'database.dart';
import 'scan_coordinator.dart';
import 'server.dart';
import '../services/discovery_service.dart';
import '../services/nfc_service.dart';

const _tag = 'ServerLifecycle';

/// Manages the HTTP server and mDNS broadcast lifecycle.
///
/// When the mobile app returns from background, the OS may have killed the
/// listening socket. Call [restart] to tear down and recreate both the HTTP
/// server and the mDNS broadcast, and re-establish the NFC session.
class ServerLifecycle {
  ServerLifecycle({
    required this.db,
    required this.coordinator,
    required this.dbFile,
    required this.restartDb,
    required this.consumeTracker,
    required this.nfcService,
    required this.discovery,
    required HttpServer initialServer,
    this.port = 8080,
  }) : _server = initialServer;

  final AppDatabase db;
  final ScanCoordinator coordinator;
  final File dbFile;
  final Future<void> Function() restartDb;
  final ConsumeTracker consumeTracker;
  final NfcService nfcService;
  final DiscoveryService discovery;
  final int port;

  HttpServer _server;
  HttpServer get server => _server;

  /// Stop the current server and mDNS broadcast, then start fresh ones.
  Future<void> restart() async {
    dev.log('restart: tearing down server and mDNS', name: _tag);

    // 1. Stop mDNS broadcast (best-effort).
    try {
      await discovery.stop();
    } catch (e) {
      dev.log('restart: mDNS stop failed (non-fatal): $e', name: _tag);
    }

    // 2. Close the HTTP server (refuse new connections, let in-flight finish).
    try {
      await _server.close();
    } catch (e) {
      dev.log('restart: server close failed (non-fatal): $e', name: _tag);
    }

    // 3. Re-establish the NFC session.
    try {
      await nfcService.restartSession();
    } catch (e) {
      dev.log('restart: NFC restart failed (non-fatal): $e', name: _tag);
    }

    // 4. Start a new HTTP server.
    try {
      _server = await startServer(
        db,
        coordinator,
        dbFile,
        restartDb,
        consumeTracker,
        nfcService: nfcService,
        port: port,
      );
      dev.log('restart: server restarted on port ${_server.port}', name: _tag);
    } catch (e) {
      dev.log('restart: server start failed: $e', name: _tag);
      rethrow;
    }

    // 5. Re-register mDNS.
    try {
      await discovery.register(_server.port);
      dev.log('restart: mDNS re-registered on port ${_server.port}',
          name: _tag);
    } catch (e) {
      dev.log('restart: mDNS register failed (non-fatal): $e', name: _tag);
    }
  }
}
