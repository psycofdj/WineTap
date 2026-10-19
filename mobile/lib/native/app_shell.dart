import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../server/api/context.dart';
import '../server/server_lifecycle.dart';
import '../server/sessions.dart';
import 'address_screen.dart';
import 'auth_sheet.dart';
import 'bridge.dart';
import 'connections_screen.dart';
import 'nfc_screen.dart';
import 'reading.dart';
import 'theme.dart';

/// Theme mode for a theme chosen in the site: 'clair', 'sombre' or 'systeme'.
ThemeMode themeModeOf(String theme) => switch (theme) {
  'clair' => ThemeMode.light,
  'sombre' => ThemeMode.dark,
  _ => ThemeMode.system,
};

class WineTapApp extends StatefulWidget {
  const WineTapApp({
    super.key,
    required this.ctx,
    required this.reading,
    required this.lifecycle,
  });

  final ApiContext ctx;
  final ReadingController reading;
  final ServerLifecycle lifecycle;

  @override
  State<WineTapApp> createState() => _WineTapAppState();
}

class _WineTapAppState extends State<WineTapApp> {
  // Thème retenu au dernier lancement, puis celui que le site envoie par le pont.
  late ThemeMode _mode = themeModeOf(widget.ctx.settings.theme);

  void _setTheme(String theme) {
    widget.ctx.settings.setTheme(theme);
    final mode = themeModeOf(theme);
    if (mode != _mode) setState(() => _mode = mode);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WineTap',
      debugShowCheckedModeBanner: false,
      theme: winetapTheme(Brightness.light),
      darkTheme: winetapTheme(Brightness.dark),
      themeMode: _mode,
      home: AppShell(
        ctx: widget.ctx,
        reading: widget.reading,
        lifecycle: widget.lifecycle,
        onTheme: _setTheme,
      ),
    );
  }
}

/// The site in a WebView (D-01), with the native screens on top: N-E4
/// (reading), N-E2 (authorization), N-E1 and N-E3 (pushed by the site).
class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.ctx,
    required this.reading,
    required this.lifecycle,
    this.onTheme,
  });

  final ApiContext ctx;
  final ReadingController reading;
  final ServerLifecycle lifecycle;

  /// Theme chosen in the site ('clair', 'sombre', 'systeme').
  final void Function(String theme)? onTheme;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  late final WebViewController _web;
  late final Bridge _bridge;
  StreamSubscription<void>? _sessionsSub;
  bool _authSheetOpen = false;
  final _messenger = GlobalKey<ScaffoldMessengerState>();

  ApiContext get ctx => widget.ctx;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bridge = Bridge(
      reading: widget.reading,
      dbs: ctx.dbs,
      reply: _runJs,
      openNative: _openNative,
      setTheme: (t) => widget.onTheme?.call(t),
    );
    _web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..addJavaScriptChannel(
        'WineTapNative',
        onMessageReceived: (m) => _bridge.handle(m.message),
      )
      ..setNavigationDelegate(
        NavigationDelegate(onNavigationRequest: _navigation),
      )
      // Le jeton pose le cookie de l'application ; le serveur injecte alors le pont.
      ..loadRequest(
        Uri.parse(
          'http://localhost:${ctx.port}/?jeton=${ctx.sessions.appToken}',
        ),
      );
    widget.reading.onSentToComputer = () =>
        _message('Tag envoyé à l’ordinateur');
    _sessionsSub = ctx.sessions.changes.listen((_) => _maybeAskAuthorization());
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _maybeAskAuthorization(),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sessionsSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) widget.lifecycle.restart();
  }

  Future<void> _runJs(String js) => _web.runJavaScript(js);

  /// Pages of the site stay in the WebView; any other address opens in the
  /// phone's browser.
  NavigationDecision _navigation(NavigationRequest req) {
    final uri = Uri.tryParse(req.url);
    if (uri == null) return NavigationDecision.prevent;
    if (uri.host == 'localhost' ||
        uri.host == '127.0.0.1' ||
        uri.scheme == 'about') {
      return NavigationDecision.navigate;
    }
    launchUrl(uri, mode: LaunchMode.externalApplication);
    return NavigationDecision.prevent;
  }

  void _message(String text) {
    _messenger.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          duration: const Duration(milliseconds: 2600),
        ),
      );
  }

  void _openNative(String screen) {
    final nav = Navigator.of(context);
    void connexions() => nav.push(
      MaterialPageRoute<void>(
        builder: (_) => ScaffoldMessenger(
          child: ConnectionsScreen(
            sessions: ctx.sessions,
            events: ctx.events,
            onMessage: _message,
          ),
        ),
      ),
    );
    if (screen == 'connexions') {
      connexions();
    } else if (screen == 'adresse') {
      nav.push(
        MaterialPageRoute<void>(
          builder: (_) =>
              AddressScreen(port: ctx.port, onConnections: connexions),
        ),
      );
    }
  }

  /// Shows N-E2 for the first pending request, one at a time.
  Future<void> _maybeAskAuthorization() async {
    if (_authSheetOpen || !mounted) return;
    final pending = ctx.sessions.pending;
    if (pending.isEmpty) return;
    final AccessRequest req = pending.first;
    _authSheetOpen = true;
    final allow = await showAuthSheet(context, req);
    _authSheetOpen = false;
    final decided = await ctx.sessions.decide(req.hash, allow: allow == true);
    if (!decided) {
      _message('Demande expirée');
    } else {
      ctx.events.session(req.hash, allow == true ? 'autorisee' : 'refusee');
      _message(
        allow == true ? '${req.client.label} autorisé' : 'Connexion refusée',
      );
    }
    _maybeAskAuthorization();
  }

  Future<void> _back() async {
    if (widget.reading.current != null) {
      await widget.reading.cancel();
    } else if (await _web.canGoBack()) {
      await _web.goBack();
    } else {
      await SystemNavigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: (dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
          .copyWith(
            statusBarColor: const Color(0x00000000),
            systemNavigationBarColor: p.card,
          ),
      child: ScaffoldMessenger(
        key: _messenger,
        child: PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _back();
          },
          child: Scaffold(
            backgroundColor: p.paper,
            body: Stack(
              children: [
                SafeArea(
                  bottom: defaultTargetPlatform != TargetPlatform.iOS,
                  child: WebViewWidget(controller: _web),
                ),
                Positioned.fill(child: NfcScreen(controller: widget.reading)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
