import 'dart:convert';
import 'dart:developer' as dev;

import 'package:drift/drift.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:sqlite3/sqlite3.dart' show SqliteException;

import '../database.dart';

Router cuveesRouter(AppDatabase db) {
  final router = Router();

  // GET /cuvees — list all ordered by domain then name (denormalized)
  router.get('/', (Request req) async {
    final list = await db.listCuvees();
    return _json(200, list.map((c) => c.toJson()).toList());
  });

  // POST /cuvees — create
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
    final domainIdRaw = body['domain_id'];
    if (domainIdRaw == null) {
      return _error(400, 'invalid_argument', 'domain_id is required');
    }
    final domainId = domainIdRaw is int
        ? domainIdRaw
        : int.tryParse(domainIdRaw.toString());
    if (domainId == null) {
      return _error(400, 'invalid_argument', 'domain_id must be an integer');
    }
    final colorRaw = body['color'];
    if (colorRaw == null) {
      return _error(400, 'invalid_argument', 'color is required');
    }
    final color =
        colorRaw is int ? colorRaw : int.tryParse(colorRaw.toString());
    if (color == null) {
      return _error(400, 'invalid_argument', 'color must be an integer');
    }

    final designationIdRaw = body['designation_id'];
    final designationId = designationIdRaw == null
        ? 0
        : (designationIdRaw is int
            ? designationIdRaw
            : int.tryParse(designationIdRaw.toString()) ?? 0);

    try {
      final id = await db.insertCuvee(CuveesCompanion.insert(
        name: name.trim(),
        domainId: domainId,
        designationId: Value(designationId),
        color: Value(color),
        description:
            Value((body['description'] as String?)?.trim() ?? ''),
      ));
      final c = await db.getCuveeById(id);
      return _json(201, c.toJson());
    } on SqliteException catch (e) {
      if (e.message.contains('FOREIGN KEY constraint')) {
        // FK on INSERT = invalid parent reference (domain or designation)
        return _error(400, 'invalid_argument',
            'domain_id $domainId or designation_id $designationId does not exist');
      }
      dev.log('insertCuvee error: $e', name: 'cuvees');
      return _error(500, 'internal', e.toString());
    }
  });

  // PUT /cuvees/<id> — update
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
    final domainIdRaw = body['domain_id'];
    if (domainIdRaw == null) {
      return _error(400, 'invalid_argument', 'domain_id is required');
    }
    final domainId = domainIdRaw is int
        ? domainIdRaw
        : int.tryParse(domainIdRaw.toString());
    if (domainId == null) {
      return _error(400, 'invalid_argument', 'domain_id must be an integer');
    }
    final colorRaw = body['color'];
    if (colorRaw == null) {
      return _error(400, 'invalid_argument', 'color is required');
    }
    final color =
        colorRaw is int ? colorRaw : int.tryParse(colorRaw.toString());
    if (color == null) {
      return _error(400, 'invalid_argument', 'color must be an integer');
    }

    final designationIdRaw = body['designation_id'];
    final designationId = designationIdRaw == null
        ? 0
        : (designationIdRaw is int
            ? designationIdRaw
            : int.tryParse(designationIdRaw.toString()) ?? 0);

    // 404 check
    try {
      await db.getCuveeById(intId);
    } on StateError {
      return _error(404, 'not_found', 'cuvée $intId not found');
    }

    try {
      await db.updateCuvee(CuveesCompanion(
        id: Value(intId),
        name: Value(name.trim()),
        domainId: Value(domainId),
        designationId: Value(designationId),
        color: Value(color),
        description:
            Value((body['description'] as String?)?.trim() ?? ''),
      ));
      final c = await db.getCuveeById(intId);
      return _json(200, c.toJson());
    } on SqliteException catch (e) {
      if (e.message.contains('FOREIGN KEY constraint')) {
        return _error(400, 'invalid_argument',
            'domain_id $domainId or designation_id $designationId does not exist');
      }
      dev.log('updateCuvee error: $e', name: 'cuvees');
      return _error(500, 'internal', e.toString());
    }
  });

  // DELETE /cuvees/<id>
  router.delete('/<id>', (Request req, String id) async {
    final intId = int.tryParse(id);
    if (intId == null) {
      return _error(400, 'invalid_argument', 'id must be an integer');
    }
    try {
      final count = await db.deleteCuvee(intId);
      if (count == 0) {
        return _error(404, 'not_found', 'cuvée $intId not found');
      }
      return Response(204);
    } on SqliteException catch (e) {
      if (e.message.contains('FOREIGN KEY constraint')) {
        return _error(412, 'referenced', 'entity is still referenced');
      }
      dev.log('deleteCuvee error: $e', name: 'cuvees');
      return _error(500, 'internal', e.toString());
    } catch (e) {
      if (e.toString().contains('FOREIGN KEY constraint')) {
        return _error(412, 'referenced', 'entity is still referenced');
      }
      dev.log('deleteCuvee error: $e', name: 'cuvees');
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
