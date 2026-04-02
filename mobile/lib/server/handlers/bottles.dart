import 'dart:convert';
import 'dart:developer' as dev;

import 'package:drift/drift.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:sqlite3/sqlite3.dart' show SqliteException;

import '../consume_tracker.dart';
import '../database.dart';

String _normalizeTagId(String tagId) =>
    tagId.replaceAll(RegExp(r'[:\s\-]'), '').toUpperCase();

Router bottlesRouter(AppDatabase db, ConsumeTracker consumeTracker) {
  final router = Router();

  // GET /bottles — list; include_consumed=true to include consumed
  router.get('/', (Request req) async {
    final includeConsumed =
        req.url.queryParameters['include_consumed'] == 'true';
    final list = await db.listBottles(includeConsumed: includeConsumed);
    return _json(200, list.map((b) => b.toJson()).toList());
  });

  // GET /bottles/by-tag/:tag_id — BEFORE /<id> to prevent "by-tag" capturing as id
  router.get('/by-tag/<tag_id>', (Request req, String tagId) async {
    final normalized = _normalizeTagId(tagId);
    final bottle = await db.getBottleByTagId(normalized);
    if (bottle == null) {
      return _error(404, 'not_found', 'no in-stock bottle with tag_id=$normalized');
    }
    return _json(200, bottle.toJson());
  });

  // GET /bottles/:id
  router.get('/<id>', (Request req, String id) async {
    final intId = int.tryParse(id);
    if (intId == null) {
      return _error(400, 'invalid_argument', 'id must be an integer');
    }
    try {
      final bottle = await db.getBottleById(intId);
      return _json(200, bottle.toJson());
    } on StateError {
      return _error(404, 'not_found', 'bottle $intId not found');
    }
  });

  // POST /bottles/consume — tag-based consumption
  router.post('/consume', (Request req) async {
    final Map<String, dynamic> body;
    try {
      body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
    } catch (_) {
      return _error(400, 'invalid_argument', 'request body must be valid JSON');
    }
    final tagIdRaw = body['tag_id'];
    if (tagIdRaw == null || tagIdRaw is! String || tagIdRaw.trim().isEmpty) {
      return _error(400, 'invalid_argument', 'tag_id is required');
    }
    final tagId = _normalizeTagId(tagIdRaw);
    try {
      final bottle = await db.consumeBottle(tagId);
      consumeTracker.touch();
      return _json(200, bottle.toJson());
    } on StateError {
      return _error(404, 'not_found', 'no in-stock bottle with tag_id=$tagId');
    }
  });

  // POST /bottles — create
  router.post('/', (Request req) async {
    final Map<String, dynamic> body;
    try {
      body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
    } catch (_) {
      return _error(400, 'invalid_argument', 'request body must be valid JSON');
    }

    final cuveeIdRaw = body['cuvee_id'];
    if (cuveeIdRaw == null) {
      return _error(400, 'invalid_argument', 'cuvee_id is required');
    }
    final cuveeId = cuveeIdRaw is int
        ? cuveeIdRaw
        : int.tryParse(cuveeIdRaw.toString());
    if (cuveeId == null) {
      return _error(400, 'invalid_argument', 'cuvee_id must be an integer');
    }

    final vintageRaw = body['vintage'];
    if (vintageRaw == null) {
      return _error(400, 'invalid_argument', 'vintage is required');
    }
    final vintage = vintageRaw is int
        ? vintageRaw
        : int.tryParse(vintageRaw.toString());
    if (vintage == null) {
      return _error(400, 'invalid_argument', 'vintage must be an integer');
    }

    final tagIdRawVal = body['tag_id'];
    if (tagIdRawVal != null && tagIdRawVal is! String) {
      return _error(400, 'invalid_argument', 'tag_id must be a string');
    }
    String? tagId;
    if (tagIdRawVal != null) {
      tagId = _normalizeTagId(tagIdRawVal as String);
      if (tagId.isEmpty) {
        return _error(400, 'invalid_argument', 'tag_id must not be empty after normalization');
      }
    }

    final descriptionRaw = body['description'];
    if (body.containsKey('description')) {
      if (descriptionRaw == null) {
        return _error(400, 'invalid_argument', 'description cannot be null');
      }
      if (descriptionRaw is! String) {
        return _error(400, 'invalid_argument', 'description must be a string');
      }
    }
    final description = descriptionRaw is String ? descriptionRaw.trim() : '';

    final drinkBeforeRaw = body['drink_before'];
    if (body.containsKey('drink_before') &&
        drinkBeforeRaw != null &&
        drinkBeforeRaw is! int) {
      return _error(400, 'invalid_argument', 'drink_before must be an integer or null');
    }
    final drinkBefore = drinkBeforeRaw as int?;

    try {
      final id = await db.insertBottle(BottlesCompanion.insert(
        cuveeId: cuveeId,
        vintage: vintage,
        addedAt: DateTime.now().toUtc().toIso8601String(),
        tagId: Value(tagId),
        description: Value(description),
        purchasePrice: Value(_toDouble(body['purchase_price'])),
        drinkBefore: Value(drinkBefore),
      ));
      final bottle = await db.getBottleById(id);
      return _json(201, bottle.toJson());
    } on SqliteException catch (e) {
      if (e.message.contains('UNIQUE constraint')) {
        return _error(400, 'already_exists', 'tag_id $tagId is already in use');
      }
      if (e.message.contains('FOREIGN KEY constraint')) {
        return _error(400, 'invalid_argument', 'cuvee_id $cuveeId does not exist');
      }
      dev.log('insertBottle error: $e', name: 'bottles');
      return _error(500, 'internal', e.toString());
    }
  });

  // PUT /bottles/bulk — BEFORE /<id> to prevent "bulk" capturing as id
  router.put('/bulk', (Request req) async {
    final Map<String, dynamic> body;
    try {
      body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
    } catch (_) {
      return _error(400, 'invalid_argument', 'request body must be valid JSON');
    }

    final idsRaw = body['ids'];
    if (idsRaw == null || idsRaw is! List) {
      return _error(400, 'invalid_argument', 'ids must be an array');
    }
    for (final element in idsRaw) {
      if (element is! int) {
        return _error(400, 'invalid_argument', 'ids must be an array of integers');
      }
    }
    final ids = idsRaw.cast<int>();

    final fieldsRaw = body['fields'];
    if (fieldsRaw == null || fieldsRaw is! Map) {
      return _error(400, 'invalid_argument', 'fields must be an object');
    }
    final fields = Map<String, dynamic>.from(fieldsRaw);

    final BottlesCompanion companion;
    try {
      companion = _buildPartialCompanion(fields);
    } on FormatException catch (e) {
      return _error(400, 'invalid_argument', e.message);
    }

    try {
      final count = await db.bulkUpdateBottles(ids, companion);
      return _json(200, {'updated': count});
    } on SqliteException catch (e) {
      if (e.message.contains('FOREIGN KEY constraint')) {
        return _error(400, 'invalid_argument', 'one or more cuvee_id values do not exist');
      }
      dev.log('bulkUpdateBottles error: $e', name: 'bottles');
      return _error(500, 'internal', e.toString());
    }
  });

  // PUT /bottles/:id/tag — BEFORE /<id> (different depth, but ordered first for clarity)
  router.put('/<id>/tag', (Request req, String id) async {
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
    final tagIdRaw = body['tag_id'];
    if (tagIdRaw == null || tagIdRaw is! String || tagIdRaw.trim().isEmpty) {
      return _error(400, 'invalid_argument', 'tag_id is required');
    }
    final tagId = _normalizeTagId(tagIdRaw);

    try {
      final bottle = await db.setBottleTagId(intId, tagId);
      return _json(200, bottle.toJson());
    } on StateError {
      return _error(404, 'not_found', 'bottle $intId not found');
    } on SqliteException catch (e) {
      if (e.message.contains('UNIQUE constraint')) {
        return _error(400, 'already_exists', 'tag_id $tagId is already in use');
      }
      dev.log('setBottleTagId error: $e', name: 'bottles');
      return _error(500, 'internal', e.toString());
    }
  });

  // PUT /bottles/:id — partial update
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

    final BottlesCompanion companion;
    try {
      companion = _buildPartialCompanion(body);
    } on FormatException catch (e) {
      return _error(400, 'invalid_argument', e.message);
    }

    try {
      final count = await db.bulkUpdateBottles([intId], companion);
      if (count == 0) {
        return _error(404, 'not_found', 'bottle $intId not found');
      }
      final bottle = await db.getBottleById(intId);
      return _json(200, bottle.toJson());
    } on SqliteException catch (e) {
      if (e.message.contains('FOREIGN KEY constraint')) {
        return _error(400, 'invalid_argument', 'cuvee_id does not exist');
      }
      dev.log('updateBottle error: $e', name: 'bottles');
      return _error(500, 'internal', e.toString());
    }
  });

  // DELETE /bottles/:id
  router.delete('/<id>', (Request req, String id) async {
    final intId = int.tryParse(id);
    if (intId == null) {
      return _error(400, 'invalid_argument', 'id must be an integer');
    }
    final count = await db.deleteBottle(intId);
    if (count == 0) {
      return _error(404, 'not_found', 'bottle $intId not found');
    }
    return Response(204);
  });

  return router;
}

/// Builds a partial BottlesCompanion — absent keys → Value.absent(), present keys → Value(v).
/// Never updates system fields: addedAt, consumedAt, id.
/// tag_id: null clears it; non-null string is normalized and set (use PUT /:id/tag for dedicated flow).
/// Throws [FormatException] on invalid field types — callers must catch and return 400.
BottlesCompanion _buildPartialCompanion(Map<String, dynamic> body) {
  return BottlesCompanion(
    cuveeId: body.containsKey('cuvee_id')
        ? Value(_requireInt(body['cuvee_id'], 'cuvee_id'))
        : const Value.absent(),
    vintage: body.containsKey('vintage')
        ? Value(_requireInt(body['vintage'], 'vintage'))
        : const Value.absent(),
    description: body.containsKey('description')
        ? () {
            final v = body['description'];
            if (v == null) throw const FormatException('description cannot be null');
            if (v is! String) throw const FormatException('description must be a string');
            return Value(v.trim());
          }()
        : const Value.absent(),
    purchasePrice: body.containsKey('purchase_price')
        ? Value(_toDouble(body['purchase_price']))
        : const Value.absent(),
    drinkBefore: body.containsKey('drink_before')
        ? _nullableIntValue(body['drink_before'], 'drink_before')
        : const Value.absent(),
    tagId: body.containsKey('tag_id')
        ? () {
            final v = body['tag_id'];
            if (v == null) return const Value<String?>(null);
            if (v is! String) throw const FormatException('tag_id must be a string or null');
            final normalized = _normalizeTagId(v);
            if (normalized.isEmpty) {
              throw const FormatException('tag_id must not be empty after normalization');
            }
            return Value<String?>(normalized);
          }()
        : const Value.absent(),
  );
}

int _requireInt(dynamic v, String field) {
  if (v is int) return v;
  final parsed = v != null ? int.tryParse(v.toString()) : null;
  if (parsed == null) throw FormatException('$field must be an integer');
  return parsed;
}

Value<int?> _nullableIntValue(dynamic v, String field) {
  if (v == null) return const Value(null);
  if (v is int) return Value(v);
  throw FormatException('$field must be an integer or null');
}

double? _toDouble(dynamic v) {
  if (v == null) return null;
  if (v is double) return v;
  if (v is int) return v.toDouble();
  return double.tryParse(v.toString());
}

Response _json(int status, Object body) => Response(
      status,
      body: jsonEncode(body),
      headers: {'Content-Type': 'application/json'},
    );

Response _error(int status, String code, String message) =>
    _json(status, {'error': code, 'message': message});
