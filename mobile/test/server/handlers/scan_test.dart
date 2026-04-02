import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shelf/shelf.dart';
import 'package:wine_tap_mobile/server/handlers/scan.dart';
import 'package:wine_tap_mobile/server/scan_coordinator.dart';

void main() {
  late ScanCoordinator coordinator;
  late Handler handler;

  setUp(() {
    coordinator = ScanCoordinator(timeout: const Duration(milliseconds: 100));
    handler = scanRouter(coordinator).call;
  });

  Future<Response> post(String path, [Map<String, dynamic>? body]) async =>
      await handler(Request(
        'POST',
        Uri.parse('http://localhost$path'),
        body: body != null ? jsonEncode(body) : null,
        headers:
            body != null ? {'Content-Type': 'application/json'} : const {},
      ));

  Future<Response> get(String path) async =>
      await handler(Request('GET', Uri.parse('http://localhost$path')));

  Future<Map<String, dynamic>> jsonBody(Response r) async =>
      jsonDecode(await r.readAsString()) as Map<String, dynamic>;

  test('POST /scan/request returns 201', () async {
    final response = await post('/request');
    expect(response.statusCode, 201);
    final body = await jsonBody(response);
    expect(body['status'], 'requested');
  });

  test('POST /scan/request when scan active returns 409', () async {
    await post('/request');
    final response = await post('/request');
    expect(response.statusCode, 409);
    final body = await jsonBody(response);
    expect(body['error'], 'already_exists');
  });

  // --- GET /scan/result ---
  test('GET /scan/result timeout returns 204', () async {
    coordinator.request();
    final response = await get('/result');
    expect(response.statusCode, 204);
  });

  test('GET /scan/result returns tag after submit', () async {
    coordinator.request();

    final resultFuture = get('/result');
    await Future<void>.delayed(const Duration(milliseconds: 10));
    coordinator.submitResult('04AABBCC');

    final response = await resultFuture;
    expect(response.statusCode, 200);
    final body = await jsonBody(response);
    expect(body['status'], 'resolved');
    expect(body['tag_id'], '04AABBCC');
  });

  test('GET /scan/result after cancel returns 410', () async {
    coordinator.request();

    final resultFuture = get('/result');
    await Future<void>.delayed(const Duration(milliseconds: 10));
    coordinator.cancel();

    final response = await resultFuture;
    expect(response.statusCode, 410);
    final body = await jsonBody(response);
    expect(body['status'], 'cancelled');
  });

  test('GET /scan/result with no pending request returns 400', () async {
    final response = await get('/result');
    expect(response.statusCode, 400);
    final body = await jsonBody(response);
    expect(body['error'], 'invalid_state');
  });

  // --- POST /scan/cancel ---
  test('POST /scan/cancel returns 200', () async {
    coordinator.request();
    final response = await post('/cancel');
    expect(response.statusCode, 200);
    final body = await jsonBody(response);
    expect(body['status'], 'cancelled');
  });

  test('POST /scan/cancel when no request returns 200 (idempotent)', () async {
    final response = await post('/cancel');
    expect(response.statusCode, 200);
    final body = await jsonBody(response);
    expect(body['status'], 'cancelled');
  });
}
