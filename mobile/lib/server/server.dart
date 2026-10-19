import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

import 'api/bottle_api.dart';
import 'api/catalog_api.dart';
import 'api/context.dart';
import 'api/json.dart';
import 'api/security.dart';
import 'api/system_api.dart';
import 'middleware/wakelock.dart';
import 'static_site.dart';

/// The whole HTTP handler: API under `/api/`, built site elsewhere.
Handler buildHandler(
  ApiContext ctx, {
  required SiteLoader loadSite,
  bool enableWakelock = true,
}) {
  final api = Router(
    notFoundHandler: (Request req) =>
        apiError(404, 'introuvable', 'Route inconnue.'),
  );
  mountSystemApi(api, ctx);
  mountCatalogApi(api, ctx);
  mountBottleApi(api, ctx);
  final site = staticSite(load: loadSite, sessions: ctx.sessions);

  Future<Response> route(Request req) async {
    if (req.url.path.startsWith('api/')) {
      try {
        return await api.call(req);
      } catch (e, st) {
        stderr.writeln('API ${req.method} /${req.url.path}: $e\n$st');
        return apiError(500, 'interne', 'Erreur interne.');
      }
    }
    return site(req);
  }

  var pipeline = const Pipeline().addMiddleware(securityMiddleware(ctx));
  if (enableWakelock) pipeline = pipeline.addMiddleware(wakelockMiddleware());
  return pipeline.addHandler(route);
}

/// Starts the server on all IPv4 addresses (D-04: no mDNS, the phone shows its
/// address). Returns the running server.
Future<HttpServer> startServer(
  ApiContext ctx, {
  required SiteLoader loadSite,
  bool enableWakelock = true,
}) async {
  final server = await shelf_io.serve(
    buildHandler(ctx, loadSite: loadSite, enableWakelock: enableWakelock),
    InternetAddress.anyIPv4,
    ctx.port,
    shared: true,
  );
  server.idleTimeout = const Duration(seconds: 60);
  return server;
}
