import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../db_holder.dart';
import '../sessions.dart';
import 'context.dart';
import 'json.dart';

/// Identity attached to the request by [securityMiddleware].
Identity identityOf(Request req) =>
    req.context['wt.identity'] as Identity? ?? AnonymousIdentity();

/// Session, événements, réglages, lecture à distance, sauvegarde (API.md §1, 4 à 7).
void mountSystemApi(Router r, ApiContext ctx) {
  // --- Session -----------------------------------------------------------------

  r.get('/api/session', (Request req) async {
    final id = identityOf(req);
    final authorized =
        id is AppIdentity ||
        (id is BrowserIdentity && id.status == 'autorisee');
    if (!authorized) {
      final hash = id is BrowserIdentity ? id.hash : null;
      final pending = hash == null
          ? null
          : ctx.sessions.pending.where((p) => p.hash == hash).firstOrNull;
      return jsonResponse({
        'statut': id is BrowserIdentity ? id.status : 'inconnue',
        'client': (pending?.client ?? ClientInfo.fromRequest(req)).toApiJson(),
      }, status: 401);
    }
    final ip = await ctx.phone.localAddress();
    return jsonResponse({
      'statut': 'autorisee',
      'dans_application': id is AppIdentity,
      'telephone': {
        'nom': ctx.phone.name,
        'adresse': ip == null ? 'localhost:${ctx.port}' : '$ip:${ctx.port}',
      },
      'annee': ctx.currentYear(),
      'connexions': ctx.sessions.authorized.length,
    });
  });

  r.post('/api/session', (Request req) async {
    final id = identityOf(req);
    if (id is AppIdentity ||
        (id is BrowserIdentity && id.status == 'autorisee')) {
      return jsonResponse({
        'statut': 'autorisee',
        'client': ClientInfo.fromRequest(req).toApiJson(),
      }, status: 202);
    }
    final ({String? newSid, AccessRequest request}) r;
    try {
      r = ctx.sessions.requestAccess(req);
    } on AccessLimited catch (e) {
      return apiError(429, 'trop_de_demandes', e.message);
    }
    return jsonResponse(
      {'statut': r.request.status, 'client': r.request.client.toApiJson()},
      status: 202,
      headers: {
        if (r.newSid != null)
          'Set-Cookie':
              '$sessionCookie=${r.newSid}; HttpOnly; SameSite=Strict; Path=/; Max-Age=315360000',
      },
    );
  });

  r.get('/api/events', (Request req) {
    final id = identityOf(req);
    return ctx.events.subscribe(
      isApp: id is AppIdentity,
      sessionHash: id is BrowserIdentity ? id.hash : null,
    );
  });

  // --- Réglages ----------------------------------------------------------------

  r.get(
    '/api/reglages',
    (Request req) => jsonResponse({'assistant': ctx.settings.assistant}),
  );

  r.put('/api/reglages', (Request req) async {
    final body = await readJson(req);
    if (body == null) return apiError(400, 'invalide', 'Corps JSON invalide.');
    await ctx.settings.setAssistant('${body['assistant']}');
    ctx.events.data(['reglages']);
    return jsonResponse({'assistant': ctx.settings.assistant});
  });

  // --- Lecture demandée par un ordinateur ------------------------------------------

  r.post('/api/scan', (Request req) async {
    final body = await readJson(req) ?? {};
    final id = identityOf(req);
    try {
      final s = ctx.scan.start(
        '${body['objet']}',
        id is BrowserIdentity ? ClientInfo.fromRequest(req) : null,
      );
      return jsonResponse({'id': s.id}, status: 202);
    } on StateError {
      return apiError(409, 'occupe', 'Une lecture est déjà en cours.');
    }
  });

  r.delete('/api/scan/<id>', (Request req, String id) {
    ctx.scan.cancel(id);
    return Response(204);
  });

  // --- Sauvegarde et restauration ------------------------------------------------

  r.get('/api/sauvegarde', (Request req) async {
    final bytes = await ctx.dbs.backup();
    final d = DateTime.now();
    String p(int n) => n.toString().padLeft(2, '0');
    return Response.ok(
      bytes,
      headers: {
        'Content-Type': 'application/octet-stream',
        'Content-Disposition':
            'attachment; filename="winetap-${d.year}-${p(d.month)}-${p(d.day)}.db"',
        'Content-Length': '${bytes.length}',
        'Cache-Control': 'no-store',
      },
    );
  });

  Future<({List<int>? bytes, BackupInfo? info, Response? error})> received(
    Request req,
  ) async {
    final List<int> bytes;
    try {
      bytes = await readBytes(req);
    } on BodyTooLarge {
      return (
        bytes: null,
        info: null,
        error: apiError(413, 'trop_gros', 'Le fichier dépasse 100 Mo.'),
      );
    }
    final info = await inspectBackup(bytes);
    if (info == null) {
      return (
        bytes: null,
        info: null,
        error: apiError(
          400,
          'fichier_invalide',
          'Ce fichier n’est pas une sauvegarde WineTap.',
        ),
      );
    }
    return (bytes: bytes, info: info, error: null);
  }

  r.post('/api/restauration/examen', (Request req) async {
    final f = await received(req);
    if (f.error != null) return f.error!;
    return jsonResponse({'en_stock': f.info!.inStock});
  });

  r.post('/api/restauration', (Request req) async {
    final f = await received(req);
    if (f.error != null) return f.error!;
    await ctx.dbs.replace(f.bytes!);
    ctx.freedTags.clear();
    ctx.events.data(['catalogue', 'bouteilles', 'reglages']);
    return jsonResponse({'en_stock': f.info!.inStock});
  });
}
