import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../database.dart';

Router completionsRouter(AppDatabase db) {
  final router = Router();

  // GET /completions?field=designation|domain|cuvee&prefix=...
  router.get('/', (Request req) async {
    final field = req.url.queryParameters['field'];
    final prefix = req.url.queryParameters['prefix'] ?? '';

    if (field == null) {
      return _error(400, 'invalid_argument', 'field is required');
    }

    final List<String> values;
    if (field == 'designation') {
      values = await db.searchDesignationNames(prefix);
    } else if (field == 'domain') {
      values = await db.searchDomainNames(prefix);
    } else if (field == 'cuvee') {
      values = await db.searchCuveeNames(prefix);
    } else {
      return _error(
          400, 'invalid_argument', 'field must be designation, domain, or cuvee');
    }

    return _json(200, {'values': values});
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
