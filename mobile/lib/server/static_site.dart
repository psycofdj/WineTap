import 'dart:convert';

import 'package:shelf/shelf.dart';

import 'sessions.dart';

/// Loads a file of the built site (`assets/site/...`); null if missing.
typedef SiteLoader = Future<List<int>?> Function(String path);

const _types = {
  'html': 'text/html; charset=utf-8',
  'js': 'text/javascript; charset=utf-8',
  'css': 'text/css; charset=utf-8',
  'svg': 'image/svg+xml',
  'png': 'image/png',
  'ico': 'image/x-icon',
  'woff2': 'font/woff2',
  'woff': 'font/woff',
  'json': 'application/json',
  'txt': 'text/plain; charset=utf-8',
};

/// JavaScript bridge of the WebView (API.md §9). The app answers through the
/// `WineTapNative` channel and `window.__wtRetour(id, result)`.
String bridgeScript(String token) =>
    '''
<script>
(function () {
  var n = 0, attente = {};
  window.__wtRetour = function (id, resultat) {
    var r = attente[id];
    if (r) { delete attente[id]; r(resultat); }
  };
  function appel(methode, args) {
    return new Promise(function (resoudre) {
      var id = ++n;
      attente[id] = resoudre;
      WineTapNative.postMessage(JSON.stringify({ id: id, methode: methode, args: args }));
    });
  }
  window.winetapBridge = {
    token: ${jsonEncode(token)},
    readTag: function (objet) { return appel('readTag', [objet]); },
    saveBackup: function () { return appel('saveBackup', []); },
    pickFile: function () { return appel('pickFile', []); },
    openNative: function (ecran) { return appel('openNative', [ecran]); },
    openExternal: function (url) { return appel('openExternal', [url]); },
    setTheme: function (theme) { return appel('setTheme', [theme]); }
  };
})();
</script>
''';

/// Serves the built site. For the app's WebView, `/?jeton=<appToken>` sets the
/// `wt_app` cookie, and `index.html` receives the JavaScript bridge.
Handler staticSite({required SiteLoader load, required SessionStore sessions}) {
  return (Request req) async {
    if (req.method != 'GET' && req.method != 'HEAD') {
      return Response.notFound('');
    }
    var path = req.url.path;

    final jeton = req.url.queryParameters['jeton'];
    if (path.isEmpty && jeton != null) {
      if (jeton != sessions.appToken) return Response.forbidden('');
      return Response.found(
        '/',
        headers: {
          'Set-Cookie': '$appCookie=$jeton; HttpOnly; SameSite=Strict; Path=/',
        },
      );
    }

    if (path.isEmpty) path = 'index.html';
    if (path.contains('..')) return Response.notFound('');
    final bytes = await load(path);
    if (bytes == null) return Response.notFound('Fichier introuvable');

    final ext = path.split('.').last.toLowerCase();
    final headers = <String, String>{
      'Content-Type': _types[ext] ?? 'application/octet-stream',
      'X-Content-Type-Options': 'nosniff',
      // Les fichiers de assets/ portent une empreinte dans leur nom.
      'Cache-Control': path.startsWith('assets/')
          ? 'public, max-age=31536000, immutable'
          : 'no-cache',
    };

    if (path == 'index.html') {
      var html = utf8.decode(bytes);
      if (sessions.identify(req) is AppIdentity) {
        html = html.replaceFirst(
          '<head>',
          '<head>\n${bridgeScript(sessions.appToken)}',
        );
      }
      headers['Content-Security-Policy'] =
          "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; img-src 'self' data: blob:; connect-src 'self'; frame-ancestors 'none'";
      return Response.ok(html, headers: headers);
    }
    return Response.ok(bytes, headers: headers);
  };
}
