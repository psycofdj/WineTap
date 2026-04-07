import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../database.dart';
import 'sqlite_errors.dart';

Router domainsRouter(AppDatabase db) {
  final router = Router();

  // GET /domains — list all ordered by name
  router.get('/', (Request req) async {
    final list = await db.listDomains();
    return _json(200, list.map((d) => d.toApiJson()).toList());
  });

  // GET /domains/<id> — full detail
  router.get('/<id>', (Request req, String id) async {
    final intId = int.tryParse(id);
    if (intId == null) {
      return _error(400, 'invalid_argument', 'id must be an integer');
    }
    try {
      final d = await db.getDomainById(intId);
      return _json(200, d.toApiJson());
    } on StateError {
      return _error(404, 'not_found', 'domain $intId not found');
    }
  });

  // POST /domains — create
  router.post('/', (Request req) async {
    final Map<String, dynamic> body;
    try {
      body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
    } catch (_) {
      return _error(400, 'invalid_argument', 'request body must be valid JSON');
    }
    final name = body['name'] as String?;
    if (name == null || name.trim().isEmpty) {
      return _error(400, 'invalid_argument', 'name is required');
    }

    return guardDb(() async {
        final id = await db.insertDomain(DomainsCompanion.insert(
          name: name.trim(),
          description: Value((body['description'] as String?)?.trim() ?? ''),
        ));
        final d = await db.getDomainById(id);
        return _json(201, d.toApiJson());
      }, logTag: 'domains');
  });

  // PUT /domains/<id> — update
  router.put('/<id>', (Request req, String id) async {
    final intId = int.tryParse(id);
    if (intId == null) {
      return _error(400, 'invalid_argument', 'id must be an integer');
    }

    final Map<String, dynamic> body;
    try {
      body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
    } catch (_) {
      return _error(400, 'invalid_argument', 'request body must be valid JSON');
    }
    final name = body['name'] as String?;
    if (name == null || name.trim().isEmpty) {
      return _error(400, 'invalid_argument', 'name is required');
    }

    // 404 check
    try {
      await db.getDomainById(intId);
    } on StateError {
      return _error(404, 'not_found', 'domain $intId not found');
    }

    return guardDb(() async {
        await db.updateDomain(DomainsCompanion(
          id: Value(intId),
          name: Value(name.trim()),
          description: Value((body['description'] as String?)?.trim() ?? ''),
        ));
        final d = await db.getDomainById(intId);
        return _json(200, d.toApiJson());
      }, logTag: 'domains');
  });

  // DELETE /domains/<id>
  router.delete('/<id>', (Request req, String id) async {
    final intId = int.tryParse(id);
    if (intId == null) {
      return _error(400, 'invalid_argument', 'id must be an integer');
    }

    return guardDb(() async {
        final count = await db.deleteDomain(intId);
        if (count == 0) {
          return _error(404, 'not_found', 'domain $intId not found');
        }
        return Response(204);
      }, logTag: 'domains');
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
