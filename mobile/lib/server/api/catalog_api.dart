import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../database.dart';
import '../sqlite_errors.dart';
import 'context.dart';
import 'json.dart';

/// Appellations, domaines, cuvées (API.md §2).
void mountCatalogApi(Router r, ApiContext ctx) {
  AppDatabase db() => ctx.db;

  String text(Map<String, dynamic> body, String key) {
    final v = body[key];
    return v is String ? v.trim() : '';
  }

  Response duplicate(String name) =>
      apiError(400, 'invalide', '« $name » existe déjà.');

  /// Runs a write, maps SQLite constraint errors, notifies browsers.
  Future<Response> write(
    Future<Response> Function() action, {
    required String name,
  }) async {
    try {
      final res = await action();
      if (res.statusCode < 300) ctx.events.data(['catalogue']);
      return res;
    } catch (e) {
      final s = extractSqliteException(e);
      if (s != null &&
          (s.extendedResultCode == sqliteConstraintUnique ||
              s.extendedResultCode == sqliteConstraintPrimaryKey)) {
        return duplicate(name);
      }
      if (s != null && s.extendedResultCode == sqliteConstraintForeignKey) {
        return apiError(409, 'referencee', 'Fiche encore utilisée.', {
          'nombre': 1,
        });
      }
      rethrow;
    }
  }

  // --- Appellations (table designations) -------------------------------------

  r.get('/api/appellations', (Request req) async {
    final list =
        await (db().select(db().designations)
              ..where((t) => t.id.isNotValue(0))
              ..orderBy([(t) => OrderingTerm.asc(t.name)]))
            .get();
    return jsonResponse(list.map(designationJson).toList());
  });

  /// Decoded image, or the error to return. `absent` when the key is missing.
  ({Value<Uint8List?> value, Response? error}) imageOf(
    Map<String, dynamic> body,
  ) {
    if (!body.containsKey('image')) {
      return (value: const Value.absent(), error: null);
    }
    final v = body['image'];
    if (v == null || v == '') return (value: const Value(null), error: null);
    if (v is! String) {
      return (
        value: const Value.absent(),
        error: apiError(400, 'invalide', 'Image invalide.'),
      );
    }
    try {
      return (value: Value(base64Decode(v)), error: null);
    } catch (_) {
      return (
        value: const Value.absent(),
        error: apiError(400, 'invalide', 'Image invalide.'),
      );
    }
  }

  r.post('/api/appellations', (Request req) async {
    final body = await readJson(req);
    if (body == null) return apiError(400, 'invalide', 'Corps JSON invalide.');
    final name = text(body, 'nom');
    if (name.isEmpty) {
      return apiError(400, 'invalide', 'Le nom est obligatoire.');
    }
    final img = imageOf(body);
    if (img.error != null) return img.error!;
    return write(name: name, () async {
      final id = await db()
          .into(db().designations)
          .insert(
            DesignationsCompanion.insert(
              name: name,
              region: Value(text(body, 'region')),
              description: Value(text(body, 'description')),
              picture: img.value,
            ),
          );
      return jsonResponse(
        designationJson(await db().getDesignationById(id)),
        status: 201,
      );
    });
  });

  r.put('/api/appellations/<id|[0-9]+>', (Request req, String id) async {
    final n = int.parse(id);
    if (n == 0) return apiError(404, 'introuvable', 'Appellation introuvable.');
    final body = await readJson(req);
    if (body == null) return apiError(400, 'invalide', 'Corps JSON invalide.');
    final name = text(body, 'nom');
    if (name.isEmpty) {
      return apiError(400, 'invalide', 'Le nom est obligatoire.');
    }
    final img = imageOf(body);
    if (img.error != null) return img.error!;
    return write(name: name, () async {
      final count =
          await (db().update(
            db().designations,
          )..where((t) => t.id.equals(n))).write(
            DesignationsCompanion(
              name: Value(name),
              region: Value(text(body, 'region')),
              description: Value(text(body, 'description')),
              picture: img.value,
            ),
          );
      if (count == 0) {
        return apiError(404, 'introuvable', 'Appellation introuvable.');
      }
      return jsonResponse(designationJson(await db().getDesignationById(n)));
    });
  });

  r.delete('/api/appellations/<id|[0-9]+>', (Request req, String id) async {
    final n = int.parse(id);
    if (n == 0) return apiError(404, 'introuvable', 'Appellation introuvable.');
    final used = await (db().select(
      db().cuvees,
    )..where((t) => t.designationId.equals(n))).get();
    if (used.isNotEmpty) {
      return apiError(409, 'referencee', 'Fiche encore utilisée.', {
        'nombre': used.length,
      });
    }
    return write(name: '', () async {
      final count = await db().deleteDesignation(n);
      if (count == 0) {
        return apiError(404, 'introuvable', 'Appellation introuvable.');
      }
      return Response(204);
    });
  });

  r.get('/api/appellations/<id|[0-9]+>/image', (Request req, String id) async {
    final d = await (db().select(
      db().designations,
    )..where((t) => t.id.equals(int.parse(id)))).getSingleOrNull();
    final pic = d?.picture;
    if (pic == null || pic.isEmpty) {
      return apiError(404, 'introuvable', 'Pas d’image.');
    }
    return Response.ok(
      pic,
      headers: {
        'Content-Type': imageContentType(pic),
        'Cache-Control': 'no-cache',
        'X-Content-Type-Options': 'nosniff',
        // Une image SVG ouverte seule ne doit rien exécuter.
        'Content-Security-Policy':
            "default-src 'none'; style-src 'unsafe-inline'",
      },
    );
  });

  // --- Domaines ----------------------------------------------------------------

  r.get('/api/domaines', (Request req) async {
    final list = await (db().select(
      db().domains,
    )..orderBy([(t) => OrderingTerm.asc(t.name)])).get();
    return jsonResponse(list.map(domainJson).toList());
  });

  r.post('/api/domaines', (Request req) async {
    final body = await readJson(req);
    if (body == null) return apiError(400, 'invalide', 'Corps JSON invalide.');
    final name = text(body, 'nom');
    if (name.isEmpty) {
      return apiError(400, 'invalide', 'Le nom est obligatoire.');
    }
    return write(name: name, () async {
      final id = await db()
          .into(db().domains)
          .insert(
            DomainsCompanion.insert(
              name: name,
              description: Value(text(body, 'description')),
            ),
          );
      return jsonResponse(
        domainJson(await db().getDomainById(id)),
        status: 201,
      );
    });
  });

  r.put('/api/domaines/<id|[0-9]+>', (Request req, String id) async {
    final n = int.parse(id);
    final body = await readJson(req);
    if (body == null) return apiError(400, 'invalide', 'Corps JSON invalide.');
    final name = text(body, 'nom');
    if (name.isEmpty) {
      return apiError(400, 'invalide', 'Le nom est obligatoire.');
    }
    return write(name: name, () async {
      final count =
          await (db().update(db().domains)..where((t) => t.id.equals(n))).write(
            DomainsCompanion(
              name: Value(name),
              description: Value(text(body, 'description')),
            ),
          );
      if (count == 0) {
        return apiError(404, 'introuvable', 'Domaine introuvable.');
      }
      return jsonResponse(domainJson(await db().getDomainById(n)));
    });
  });

  r.delete('/api/domaines/<id|[0-9]+>', (Request req, String id) async {
    final n = int.parse(id);
    final used = await (db().select(
      db().cuvees,
    )..where((t) => t.domainId.equals(n))).get();
    if (used.isNotEmpty) {
      return apiError(409, 'referencee', 'Fiche encore utilisée.', {
        'nombre': used.length,
      });
    }
    return write(name: '', () async {
      final count = await db().deleteDomain(n);
      if (count == 0) {
        return apiError(404, 'introuvable', 'Domaine introuvable.');
      }
      return Response(204);
    });
  });

  // --- Cuvées ------------------------------------------------------------------

  /// Checks the fields of a cuvée; returns an error or the companion.
  Future<({CuveesCompanion? companion, Response? error})> cuveeOf(
    Map<String, dynamic> body,
  ) async {
    final name = text(body, 'nom');
    if (name.isEmpty) {
      return (
        companion: null,
        error: apiError(400, 'invalide', 'Le nom est obligatoire.'),
      );
    }
    final domainId = body['domaine_id'];
    if (domainId is! int ||
        await (db().select(
              db().domains,
            )..where((t) => t.id.equals(domainId))).getSingleOrNull() ==
            null) {
      return (
        companion: null,
        error: apiError(400, 'invalide', 'Choisissez un domaine.'),
      );
    }
    final appId = body['appellation_id'] ?? 0;
    if (appId is! int ||
        (appId != 0 &&
            await (db().select(
                  db().designations,
                )..where((t) => t.id.equals(appId))).getSingleOrNull() ==
                null)) {
      return (
        companion: null,
        error: apiError(400, 'invalide', 'Appellation inconnue.'),
      );
    }
    final color = body['couleur'] ?? 0;
    if (color is! int || color < 0 || color > 5) {
      return (
        companion: null,
        error: apiError(400, 'invalide', 'Couleur invalide.'),
      );
    }
    return (
      companion: CuveesCompanion(
        name: Value(name),
        domainId: Value(domainId),
        designationId: Value(appId),
        color: Value(color),
        description: Value(text(body, 'description')),
      ),
      error: null,
    );
  }

  r.get('/api/cuvees', (Request req) async {
    final list = await (db().select(
      db().cuvees,
    )..orderBy([(t) => OrderingTerm.asc(t.name)])).get();
    return jsonResponse(list.map(cuveeJson).toList());
  });

  r.post('/api/cuvees', (Request req) async {
    final body = await readJson(req);
    if (body == null) return apiError(400, 'invalide', 'Corps JSON invalide.');
    final c = await cuveeOf(body);
    if (c.error != null) return c.error!;
    return write(name: text(body, 'nom'), () async {
      final id = await db().into(db().cuvees).insert(c.companion!);
      final row = await (db().select(
        db().cuvees,
      )..where((t) => t.id.equals(id))).getSingle();
      return jsonResponse(cuveeJson(row), status: 201);
    });
  });

  r.put('/api/cuvees/<id|[0-9]+>', (Request req, String id) async {
    final n = int.parse(id);
    final body = await readJson(req);
    if (body == null) return apiError(400, 'invalide', 'Corps JSON invalide.');
    final c = await cuveeOf(body);
    if (c.error != null) return c.error!;
    return write(name: text(body, 'nom'), () async {
      final count = await (db().update(
        db().cuvees,
      )..where((t) => t.id.equals(n))).write(c.companion!);
      if (count == 0) return apiError(404, 'introuvable', 'Cuvée introuvable.');
      final row = await (db().select(
        db().cuvees,
      )..where((t) => t.id.equals(n))).getSingle();
      return jsonResponse(cuveeJson(row));
    });
  });

  r.delete('/api/cuvees/<id|[0-9]+>', (Request req, String id) async {
    final n = int.parse(id);
    final used = await (db().select(
      db().bottles,
    )..where((t) => t.cuveeId.equals(n))).get();
    if (used.isNotEmpty) {
      return apiError(409, 'referencee', 'Fiche encore utilisée.', {
        'nombre': used.length,
      });
    }
    return write(name: '', () async {
      final count = await db().deleteCuvee(n);
      if (count == 0) return apiError(404, 'introuvable', 'Cuvée introuvable.');
      return Response(204);
    });
  });
}
