import 'dart:async';
import 'dart:convert';

import 'package:shelf/shelf.dart';

class _Client {
  _Client(this.controller, this.sessionHash, this.isApp);

  final StreamController<List<int>> controller;

  /// Hash of the browser session, null for the app's WebView.
  final String? sessionHash;
  final bool isApp;
  Timer? ping;

  void send(String event, Object data) {
    if (controller.isClosed) return;
    controller.add(utf8.encode('event: $event\ndata: ${jsonEncode(data)}\n\n'));
  }
}

/// Server-Sent Events hub (`GET /api/events`, API.md §7).
class EventHub {
  EventHub({required this.isAuthorized});

  /// Whether the browser session with this hash is currently authorized.
  final bool Function(String? sessionHash) isAuthorized;

  final _clients = <_Client>{};

  int get clientCount => _clients.length;

  /// Opens an event stream for a client.
  Response subscribe({String? sessionHash, bool isApp = false}) {
    late final _Client client;
    final controller = StreamController<List<int>>(
      onCancel: () => _remove(client),
    );
    client = _Client(controller, sessionHash, isApp);
    _clients.add(client);
    controller.add(utf8.encode('retry: 5000\n\n'));
    client.ping = Timer.periodic(const Duration(seconds: 20), (_) {
      if (!controller.isClosed) controller.add(utf8.encode(': ping\n\n'));
    });
    return Response.ok(
      controller.stream,
      headers: {
        'Content-Type': 'text/event-stream; charset=utf-8',
        'Cache-Control': 'no-cache',
        'X-Accel-Buffering': 'no',
      },
      context: {'shelf.io.buffer_output': false},
    );
  }

  void _remove(_Client client) {
    client.ping?.cancel();
    _clients.remove(client);
  }

  bool _authorized(_Client c) => c.isApp || isAuthorized(c.sessionHash);

  /// Data changed: [what] is a subset of bouteilles, catalogue, reglages.
  void data(List<String> what) {
    for (final c in _clients.toList()) {
      if (_authorized(c)) c.send('donnees', {'quoi': what});
    }
  }

  /// End of a scan requested by a computer.
  void scan(Map<String, Object?> event) {
    for (final c in _clients.toList()) {
      if (_authorized(c)) c.send('scan', event);
    }
  }

  /// Decision on a browser session: autorisee, refusee, revoquee.
  /// A revoked session's streams are closed.
  void session(String sessionHash, String status) {
    for (final c in _clients.toList()) {
      if (c.sessionHash != sessionHash) continue;
      c.send('session', {'statut': status});
      if (status == 'revoquee') {
        _remove(c);
        c.controller.close();
      }
    }
  }

  /// Closes every stream (server shutdown).
  Future<void> closeAll() async {
    for (final c in _clients.toList()) {
      _remove(c);
      await c.controller.close();
    }
  }
}
