import 'package:drift/drift.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../../services/tag_id.dart';
import '../database.dart';
import 'context.dart';
import 'json.dart';

/// Bouteilles, consommation, dégustations (API.md §3).
void mountBottleApi(Router r, ApiContext ctx) {
  AppDatabase db() => ctx.db;

  Future<Bottle?> byId(int id) => (db().select(
    db().bottles,
  )..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<Bottle?> inStockByTag(String tag) =>
      (db().select(db().bottles)
            ..where((t) => t.tagId.equals(tag) & t.consumedAt.isNull()))
          .getSingleOrNull();

  Response changed(Response res) {
    if (res.statusCode < 300) ctx.events.data(['bouteilles']);
    return res;
  }

  /// Consumes [b]: date set, tag freed (and remembered, see [ApiContext.freedTags]).
  Future<Bottle> consume(Bottle b) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await (db().update(db().bottles)..where((t) => t.id.equals(b.id))).write(
      BottlesCompanion(consumedAt: Value(now), tagId: const Value(null)),
    );
    if (b.tagId != null) ctx.freedTags[b.tagId!] = b.id;
    return (await byId(b.id))!;
  }

  /// Validates the writable fields present in [body]. `creation`: cuvée and
  /// millésime are required.
  Future<({BottlesCompanion? companion, Response? error})> fieldsOf(
    Map<String, dynamic> body, {
    required bool creation,
    int? selfId,
  }) async {
    Response bad(String m) => apiError(400, 'invalide', m);
    var c = const BottlesCompanion();

    if (creation || body.containsKey('cuvee_id')) {
      final id = body['cuvee_id'];
      if (id is! int ||
          await (db().select(
                db().cuvees,
              )..where((t) => t.id.equals(id))).getSingleOrNull() ==
              null) {
        return (companion: null, error: bad('Choisissez une cuvée.'));
      }
      c = c.copyWith(cuveeId: Value(id));
    }
    if (creation || body.containsKey('millesime')) {
      final v = body['millesime'];
      if (v is! int || v < 1900 || v > ctx.currentYear()) {
        return (
          companion: null,
          error: bad(
            'Millésime obligatoire, entre 1900 et ${ctx.currentYear()}.',
          ),
        );
      }
      c = c.copyWith(vintage: Value(v));
    }
    if (body.containsKey('a_boire_avant')) {
      final v = body['a_boire_avant'];
      if (v != null && (v is! int || v < 1900 || v > 2200)) {
        return (companion: null, error: bad('« À boire avant » invalide.'));
      }
      c = c.copyWith(drinkBefore: Value(v as int?));
    }
    if (body.containsKey('prix')) {
      final v = body['prix'];
      if (v != null && (v is! num || v < 0)) {
        return (companion: null, error: bad('Prix invalide.'));
      }
      c = c.copyWith(purchasePrice: Value((v as num?)?.toDouble()));
    }
    if (body.containsKey('commentaire')) {
      final v = body['commentaire'];
      if (v != null && v is! String) {
        return (companion: null, error: bad('Commentaire invalide.'));
      }
      c = c.copyWith(description: Value(((v as String?) ?? '').trim()));
    }
    if (body.containsKey('tag_id')) {
      final v = body['tag_id'];
      if (v != null && v is! String) {
        return (companion: null, error: bad('Tag invalide.'));
      }
      final tag = v == null ? null : normalizeTagId(v as String);
      if (tag != null && tag.isEmpty) {
        return (companion: null, error: bad('Tag invalide.'));
      }
      if (tag != null) {
        final other = await inStockByTag(tag);
        if (other != null && other.id != selfId) {
          return (
            companion: null,
            error: apiError(
              409,
              'tag_utilise',
              'Ce tag est déjà sur une bouteille en stock.',
              {'bouteille_id': other.id},
            ),
          );
        }
      }
      c = c.copyWith(tagId: Value(tag));
    }
    return (companion: c, error: null);
  }

  r.get('/api/bouteilles', (Request req) async {
    final withConsumed = req.url.queryParameters['consommees'] == '1';
    final q = db().select(db().bottles);
    if (!withConsumed) q.where((t) => t.consumedAt.isNull());
    return jsonResponse((await q.get()).map(bottleJson).toList());
  });

  r.post('/api/bouteilles', (Request req) async {
    final body = await readJson(req);
    if (body == null) return apiError(400, 'invalide', 'Corps JSON invalide.');
    final f = await fieldsOf(body, creation: true);
    if (f.error != null) return f.error!;
    final c = f.companion!.copyWith(
      addedAt: Value(DateTime.now().toUtc().toIso8601String()),
    );
    final id = await db().into(db().bottles).insert(c);
    final tag = c.tagId.present ? c.tagId.value : null;
    if (tag != null) ctx.freedTags.remove(tag);
    return changed(jsonResponse(bottleJson((await byId(id))!), status: 201));
  });

  r.put('/api/bouteilles/<id|[0-9]+>', (Request req, String id) async {
    final n = int.parse(id);
    if (await byId(n) == null) {
      return apiError(404, 'introuvable', 'Bouteille introuvable.');
    }
    final body = await readJson(req);
    if (body == null) return apiError(400, 'invalide', 'Corps JSON invalide.');
    final f = await fieldsOf(body, creation: false, selfId: n);
    if (f.error != null) return f.error!;
    await (db().update(
      db().bottles,
    )..where((t) => t.id.equals(n))).write(f.companion!);
    final tag = f.companion!.tagId.present ? f.companion!.tagId.value : null;
    if (tag != null) ctx.freedTags.remove(tag);
    return changed(jsonResponse(bottleJson((await byId(n))!)));
  });

  r.delete('/api/bouteilles/<id|[0-9]+>', (Request req, String id) async {
    final count = await db().deleteBottle(int.parse(id));
    if (count == 0) {
      return apiError(404, 'introuvable', 'Bouteille introuvable.');
    }
    return changed(Response(204));
  });

  r.post('/api/bouteilles/<id|[0-9]+>/consommer', (
    Request req,
    String id,
  ) async {
    final b = await byId(int.parse(id));
    if (b == null) {
      return apiError(404, 'introuvable', 'Bouteille introuvable.');
    }
    if (b.consumedAt != null) {
      return apiError(409, 'deja_consommee', 'Bouteille déjà consommée.', {
        'bouteille': bottleJson(b),
      });
    }
    return changed(jsonResponse(bottleJson(await consume(b))));
  });

  /// Looks up a tag: the in-stock bottle, or the error to return.
  Future<({Bottle? bottle, Response? error})> lookup(String raw) async {
    final tag = normalizeTagId(raw);
    final b = tag.isEmpty ? null : await inStockByTag(tag);
    if (b != null) return (bottle: b, error: null);
    final freed = ctx.freedTags[tag];
    final consumed = freed == null ? null : await byId(freed);
    if (consumed != null && consumed.consumedAt != null) {
      return (
        bottle: null,
        error: apiError(409, 'deja_consommee', 'Bouteille déjà consommée.', {
          'bouteille': bottleJson(consumed),
        }),
      );
    }
    return (
      bottle: null,
      error: apiError(
        404,
        'tag_inconnu',
        'Ce tag n’est associé à aucune bouteille en stock.',
      ),
    );
  }

  r.post('/api/consommer', (Request req) async {
    final body = await readJson(req);
    final tag = body?['tag_id'];
    if (tag is! String || tag.trim().isEmpty) {
      return apiError(400, 'invalide', 'tag_id est obligatoire.');
    }
    final l = await lookup(tag);
    if (l.error != null) return l.error!;
    return changed(
      jsonResponse({'bouteille': bottleJson(await consume(l.bottle!))}),
    );
  });

  r.get('/api/bouteilles/tag/<tag>', (Request req, String tag) async {
    final l = await lookup(Uri.decodeComponent(tag));
    if (l.error != null) return l.error!;
    return jsonResponse(bottleJson(l.bottle!));
  });

  r.get('/api/degustations', (Request req) async {
    final from = int.tryParse(req.url.queryParameters['depuis'] ?? '') ?? 0;
    final count = (int.tryParse(req.url.queryParameters['nombre'] ?? '') ?? 20)
        .clamp(1, 200);
    final total =
        await (db().selectOnly(db().bottles)
              ..addColumns([db().bottles.id.count()])
              ..where(db().bottles.consumedAt.isNotNull()))
            .map((row) => row.read(db().bottles.id.count()) ?? 0)
            .getSingle();
    final page =
        await (db().select(db().bottles)
              ..where((t) => t.consumedAt.isNotNull())
              ..orderBy([(t) => OrderingTerm.desc(t.consumedAt)])
              ..limit(count, offset: from))
            .get();
    return jsonResponse({
      'total': total,
      'bouteilles': page.map(bottleJson).toList(),
    });
  });
}
