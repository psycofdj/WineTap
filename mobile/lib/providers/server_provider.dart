import 'dart:developer' as dev;
import 'dart:io';

import 'package:flutter/foundation.dart';

/// Provides the local server's IP:port for display in the UI.
///
/// Resolves the device's first non-loopback IPv4 address at startup.
/// Falls back to `localhost:PORT` if no WiFi interface is found.
class ServerProvider extends ChangeNotifier {
  final int _port;
  String _serverAddress = '';

  ServerProvider(int port) : _port = port {
    _resolveAddress();
  }

  int get port => _port;
  String get serverAddress => _serverAddress;

  Future<void> _resolveAddress() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
      );
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (!addr.isLoopback) {
            _serverAddress = '${addr.address}:$_port';
            notifyListeners();
            return;
          }
        }
      }
    } catch (e) {
      dev.log('NetworkInterface.list failed: $e', name: 'ServerProvider');
    }
    _serverAddress = 'localhost:$_port';
    notifyListeners();
  }
}
