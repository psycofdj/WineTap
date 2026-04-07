import 'dart:convert';
import 'dart:developer' as dev;

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../../services/nfc_service.dart';
import '../scan_coordinator.dart';

Router scanRouter(ScanCoordinator coordinator, NfcService nfcService) {
  final router = Router();

  // POST /request — start a new scan
  router.post('/request', (Request req) async {
    try {
      coordinator.request();
    } on StateError {
      return _error(409, 'already_exists', 'scan already in progress');
    }

    dev.log('Scan requested', name: 'scan');
    return _json(201, {'status': 'requested'});
  });

  // GET /result — long-poll for scan result
  router.get('/result', (Request req) async {
    if (!coordinator.hasPendingRequest) {
      return _error(400, 'invalid_state', 'no pending scan request');
    }

    final String? result;
    try {
      result = await coordinator.waitForResult();
    } on StateError {
      return _json(410, {'status': 'cancelled'});
    }
    if (result != null) {
      dev.log('Scan resolved: tag_id=$result', name: 'scan');
      return _json(200, {'status': 'resolved', 'tag_id': result});
    }
    if (coordinator.hasPendingRequest) {
      return Response(204); // timeout — manager retries
    }
    return _json(410, {'status': 'cancelled'});
  });

  // POST /cancel — cancel pending scan
  router.post('/cancel', (Request req) async {
    coordinator.cancel();
    await nfcService.cancel();
    dev.log('Scan cancelled', name: 'scan');
    return _json(200, {'status': 'cancelled'});
  });

  return router;
}

Response _json(int status, Object body) => Response(
      status,
      body: jsonEncode(body),
      headers: {'Content-Type': 'application/json'},
    );

Response _error(int status, String code, String message) =>
    _json(status, {'error': code, 'message': message});
