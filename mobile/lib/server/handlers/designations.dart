import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../database.dart';
import 'sqlite_errors.dart';

Router designationsRouter(AppDatabase db) {
  final router = Router();

  // GET /designations — list all (excludes sentinel id=0)
  router.get('/', (Request req) async {
    final list = await db.listDesignations();
    final filtered = list.where((d) => d.id != 0).toList();
    return _json(200, filtered.map((d) => d.toJson()).toList());
  });

  // POST /designations — create
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
        final id = await db.insertDesignation(DesignationsCompanion.insert(
          name: name.trim(),
          region: Value((body['region'] as String?)?.trim() ?? ''),
          description: Value((body['description'] as String?)?.trim() ?? ''),
        ));
        final d = await db.getDesignationById(id);
        return _json(201, d.toJson());
      }, logTag: 'designations');
  });

  // PUT /designations/<id> — update
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
      await db.getDesignationById(intId);
    } on StateError {
      return _error(404, 'not_found', 'designation $intId not found');
    }

    return guardDb(() async {
        await db.updateDesignation(DesignationsCompanion(
          id: Value(intId),
          name: Value(name.trim()),
          region: Value((body['region'] as String?)?.trim() ?? ''),
          description: Value((body['description'] as String?)?.trim() ?? ''),
        ));
        final d = await db.getDesignationById(intId);
        return _json(200, d.toJson());
      }, logTag: 'designations');
  });

  // DELETE /designations/<id>
  router.delete('/<id>', (Request req, String id) async {
    final intId = int.tryParse(id);
    if (intId == null) {
      return _error(400, 'invalid_argument', 'id must be an integer');
    }
    // Guard sentinel designation
    if (intId == 0) {
      return _error(412, 'failed_precondition',
          'sentinel designation cannot be deleted');
    }

    return guardDb(() async {
        final count = await db.deleteDesignation(intId);
        if (count == 0) {
          return _error(404, 'not_found', 'designation $intId not found');
        }
        return Response(204);
      }, logTag: 'designations');
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
