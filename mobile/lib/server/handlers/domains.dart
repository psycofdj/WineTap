import 'dart:convert';
import 'dart:developer' as dev;

import 'package:drift/drift.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:sqlite3/sqlite3.dart' show SqliteException;

import '../database.dart';

Router domainsRouter(AppDatabase db) {
  final router = Router();

  // GET /domains — list all ordered by name
  router.get('/', (Request req) async {
    final list = await db.listDomains();
    return _json(200, list.map((d) => d.toJson()).toList());
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
    try {
      final id = await db.insertDomain(DomainsCompanion.insert(
        name: name.trim(),
        description: Value((body['description'] as String?)?.trim() ?? ''),
      ));
      final d = await db.getDomainById(id);
      return _json(201, d.toJson());
    } on SqliteException catch (e) {
      if (e.message.contains('UNIQUE constraint')) {
        return _error(
            400, 'already_exists', 'domain "${name.trim()}" already exists');
      }
      dev.log('insertDomain error: $e', name: 'domains');
      return _error(500, 'internal', e.toString());
    }
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

    try {
      await db.updateDomain(DomainsCompanion(
        id: Value(intId),
        name: Value(name.trim()),
        description: Value((body['description'] as String?)?.trim() ?? ''),
      ));
      final d = await db.getDomainById(intId);
      return _json(200, d.toJson());
    } on SqliteException catch (e) {
      if (e.message.contains('UNIQUE constraint')) {
        return _error(
            400, 'already_exists', 'domain "${name.trim()}" already exists');
      }
      dev.log('updateDomain error: $e', name: 'domains');
      return _error(500, 'internal', e.toString());
    }
  });

  // DELETE /domains/<id>
  router.delete('/<id>', (Request req, String id) async {
    final intId = int.tryParse(id);
    if (intId == null) {
      return _error(400, 'invalid_argument', 'id must be an integer');
    }
    try {
      final count = await db.deleteDomain(intId);
      if (count == 0) {
        return _error(404, 'not_found', 'domain $intId not found');
      }
      return Response(204);
    } on SqliteException catch (e) {
      if (e.message.contains('FOREIGN KEY constraint')) {
        return _error(412, 'referenced', 'entity is still referenced');
      }
      dev.log('deleteDomain error: $e', name: 'domains');
      return _error(500, 'internal', e.toString());
    } catch (e) {
      if (e.toString().contains('FOREIGN KEY constraint')) {
        return _error(412, 'referenced', 'entity is still referenced');
      }
      dev.log('deleteDomain error: $e', name: 'domains');
      return _error(500, 'internal', e.toString());
    }
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
