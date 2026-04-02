import 'dart:developer' as dev;

import 'package:bonsoir/bonsoir.dart';

/// Registers the WineTap server as an mDNS service.
///
/// In v2 the phone IS the server — this service broadcasts (not browses).
class DiscoveryService {
  static const _serviceType = '_winetap._tcp';

  BonsoirBroadcast? _broadcast;

  /// Register the mDNS service on [port].
  ///
  /// If already broadcasting, stops the existing broadcast first.
  Future<void> register(int port) async {
    if (_broadcast != null) await stop();
    final service = BonsoirService(
      name: 'WineTap',
      type: _serviceType,
      port: port,
    );
    _broadcast = BonsoirBroadcast(service: service);
    await _broadcast!.ready;
    await _broadcast!.start();
    dev.log('mDNS broadcast started: $_serviceType on port $port',
        name: 'DiscoveryService');
  }

  /// Stop broadcasting.
  Future<void> stop() async {
    await _broadcast?.stop();
    _broadcast = null;
  }
}
