import 'package:shelf/shelf.dart';

import '../sessions.dart';
import 'context.dart';
import 'json.dart';

/// `Host` must be `localhost` or an IP address: a site reached by a domain
/// name (DNS rebinding) cannot talk to the API (§5.2).
bool hostAllowed(String? host) {
  if (host == null || host.isEmpty) return false;
  String name = host;
  if (name.startsWith('[')) {
    // IPv6 : [::1]:8080
    final end = name.indexOf(']');
    if (end < 0) return false;
    name = name.substring(1, end);
    return name.contains(':');
  }
  final colon = name.lastIndexOf(':');
  if (colon >= 0) name = name.substring(0, colon);
  if (name == 'localhost') return true;
  return RegExp(r'^\d{1,3}(\.\d{1,3}){3}$').hasMatch(name);
}

const _unsafeMethods = {'POST', 'PUT', 'PATCH', 'DELETE'};

/// Routes reachable without an authorized session.
bool _open(Request req) {
  final p = req.url.path;
  return p == 'api/session' || p == 'api/events';
}

/// Identifies the caller and enforces Host, Origin and authorization on `/api/`.
Middleware securityMiddleware(ApiContext ctx) {
  return (Handler inner) {
    return (Request req) async {
      final identity = ctx.sessions.identify(req);
      req = req.change(context: {'wt.identity': identity});
      if (!req.url.path.startsWith('api/')) return inner(req);

      final host = req.headers['host'];
      if (!hostAllowed(host)) {
        return apiError(403, 'origine_refusee', 'Adresse non autorisée.');
      }
      if (_unsafeMethods.contains(req.method)) {
        final origin = req.headers['origin'];
        if (origin == null || origin != 'http://$host') {
          return apiError(403, 'origine_refusee', 'Origine non autorisée.');
        }
      }
      final authorized =
          identity is AppIdentity ||
          (identity is BrowserIdentity && identity.status == 'autorisee');
      if (!authorized && !_open(req)) {
        return apiError(
          401,
          'non_autorise',
          'Ce navigateur n’est pas autorisé.',
        );
      }
      if (identity is BrowserIdentity && identity.session != null) {
        final info = ClientInfo.fromRequest(req);
        ctx.sessions.touch(identity.session!, info.ip);
      }
      return inner(req);
    };
  };
}
