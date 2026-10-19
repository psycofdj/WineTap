import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:shelf/shelf.dart';

import 'preferences.dart';

/// Browser and system read from the User-Agent header.
class UserAgent {
  const UserAgent(this.browser, this.version, this.os);

  final String browser;
  final String version;
  final String os;

  factory UserAgent.parse(String ua) {
    String browser = 'Navigateur';
    String version = '';
    RegExpMatch? m;
    if ((m = RegExp(r'Firefox/(\d+)').firstMatch(ua)) != null) {
      browser = 'Firefox';
      version = m!.group(1)!;
    } else if ((m = RegExp(r'Edg/(\d+)').firstMatch(ua)) != null) {
      browser = 'Edge';
      version = m!.group(1)!;
    } else if ((m = RegExp(r'Chrome/(\d+)').firstMatch(ua)) != null) {
      browser = 'Chrome';
      version = m!.group(1)!;
    } else if ((m = RegExp(r'Version/(\d+).*Safari/').firstMatch(ua)) != null) {
      browser = 'Safari';
      version = m!.group(1)!;
    }
    final os = ua.contains('Android')
        ? 'Android'
        : RegExp(r'iPhone|iPad').hasMatch(ua)
        ? 'iOS'
        : ua.contains('Mac OS X')
        ? 'macOS'
        : ua.contains('Windows')
        ? 'Windows'
        : ua.contains('CrOS')
        ? 'ChromeOS'
        : ua.contains('Linux')
        ? 'Linux'
        : 'Système inconnu';
    return UserAgent(browser, version, os);
  }
}

/// What the phone shows about a browser asking for access.
class ClientInfo {
  ClientInfo({
    required this.browser,
    required this.browserVersion,
    required this.os,
    required this.ip,
    required this.requestedAt,
  });

  final String browser;
  final String browserVersion;
  final String os;
  final String ip;
  final DateTime requestedAt;

  factory ClientInfo.fromRequest(Request request, {DateTime? now}) {
    final ua = UserAgent.parse(request.headers['user-agent'] ?? '');
    final info = request.context['shelf.io.connection_info'];
    String ip = '';
    try {
      ip = (info as dynamic).remoteAddress.address as String;
    } catch (_) {}
    return ClientInfo(
      browser: ua.browser,
      browserVersion: ua.version,
      os: ua.os,
      ip: ip,
      requestedAt: (now ?? DateTime.now()).toUtc(),
    );
  }

  /// « Firefox sur macOS »
  String get label => '$browser sur $os';

  Map<String, Object> toApiJson() => {
    'navigateur': browser,
    'systeme': os,
    'ip': ip,
    'demande_le': requestedAt.toIso8601String(),
  };
}

/// A browser authorized on the phone (D-03). Persisted; never expires (D-10).
class AuthorizedSession {
  AuthorizedSession({
    required this.hash,
    required this.browser,
    required this.os,
    required this.ip,
    required this.authorizedAt,
    required this.lastSeen,
  });

  final String hash;
  final String browser;
  final String os;
  String ip;
  final DateTime authorizedAt;
  DateTime lastSeen;

  String get label => '$browser sur $os';

  Map<String, Object> toJson() => {
    'hash': hash,
    'browser': browser,
    'os': os,
    'ip': ip,
    'authorizedAt': authorizedAt.toIso8601String(),
    'lastSeen': lastSeen.toIso8601String(),
  };

  factory AuthorizedSession.fromJson(Map<String, dynamic> j) =>
      AuthorizedSession(
        hash: j['hash'] as String,
        browser: j['browser'] as String,
        os: j['os'] as String,
        ip: j['ip'] as String? ?? '',
        authorizedAt: DateTime.parse(j['authorizedAt'] as String),
        lastSeen: DateTime.parse(j['lastSeen'] as String),
      );
}

/// A pending or refused access request (kept in memory only).
class AccessRequest {
  AccessRequest(this.hash, this.client, this.status);

  final String hash;
  ClientInfo client;

  /// 'en_attente' or 'refusee'
  String status;

  /// Last request, or refusal: start of the pending lifetime or of the
  /// refusal cooldown.
  DateTime since = DateTime.now();
}

/// An access request refused before reaching the phone (R-05): another
/// request from the same address is pending, the address was just refused,
/// or too many requests are pending.
class AccessLimited implements Exception {
  AccessLimited(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Who is calling the API.
sealed class Identity {}

/// The app's own WebView.
class AppIdentity extends Identity {}

/// A browser, identified by its session cookie.
class BrowserIdentity extends Identity {
  BrowserIdentity(this.hash, this.status, {this.session});

  final String hash;

  /// 'autorisee', 'en_attente', 'refusee' or 'inconnue'
  final String status;
  final AuthorizedSession? session;
}

/// No session cookie.
class AnonymousIdentity extends Identity {}

const sessionCookie = 'wt_session';
const appCookie = 'wt_app';

String randomToken([int bytes = 32]) {
  final r = Random.secure();
  return List.generate(
    bytes,
    (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}

String hashToken(String token) => sha256.convert(utf8.encode(token)).toString();

Map<String, String> parseCookies(String? header) {
  final out = <String, String>{};
  for (final part in (header ?? '').split(';')) {
    final i = part.indexOf('=');
    if (i <= 0) continue;
    out[part.substring(0, i).trim()] = part.substring(i + 1).trim();
  }
  return out;
}

/// Browser sessions: authorization requests, authorized sessions, revocation.
/// The phone keeps only a hash of each session identifier (§5.2).
class SessionStore {
  SessionStore(this._store, {String? appToken, DateTime Function()? clock})
    : appToken = appToken ?? randomToken(),
      _now = clock ?? DateTime.now;

  /// Time source, replaced in tests.
  final DateTime Function() _now;

  final KeyValueStore _store;

  /// Secret of the app's WebView, regenerated at each start.
  final String appToken;

  static const _key = 'v3.sessions';

  /// A pending request is dropped after this delay.
  static const pendingLifetime = Duration(minutes: 5);

  /// After a refusal, the same address cannot ask again before this delay.
  static const refusalCooldown = Duration(minutes: 2);

  /// Pending requests shown on the phone at most, all addresses together.
  static const maxPending = 3;

  /// Refused requests are forgotten after this delay.
  static const _refusedLifetime = Duration(minutes: 30);

  final Map<String, AuthorizedSession> _authorized = {};
  final Map<String, AccessRequest> _requests = {};
  final _changes = StreamController<void>.broadcast();
  DateTime _lastPersist = DateTime.fromMillisecondsSinceEpoch(0);

  /// Notified on every change (requests, decisions, revocations).
  Stream<void> get changes => _changes.stream;

  List<AuthorizedSession> get authorized =>
      _authorized.values.toList()
        ..sort((a, b) => b.lastSeen.compareTo(a.lastSeen));

  List<AccessRequest> get pending {
    _purge();
    return _requests.values.where((r) => r.status == 'en_attente').toList();
  }

  /// Drops expired pending requests and old refusals.
  void _purge() {
    final now = _now();
    _requests.removeWhere(
      (_, r) =>
          now.difference(r.since) >
          (r.status == 'en_attente' ? pendingLifetime : _refusedLifetime),
    );
  }

  void load() {
    final raw = _store.get(_key);
    if (raw == null) return;
    try {
      for (final j in jsonDecode(raw) as List) {
        final s = AuthorizedSession.fromJson(j as Map<String, dynamic>);
        _authorized[s.hash] = s;
      }
    } catch (_) {
      // Unreadable: start with no authorized session.
    }
  }

  Future<void> _persist() async {
    _lastPersist = DateTime.now();
    await _store.set(
      _key,
      jsonEncode(_authorized.values.map((s) => s.toJson()).toList()),
    );
  }

  bool isAuthorized(String? hash) =>
      hash != null && _authorized.containsKey(hash);

  Identity identify(Request request) {
    final cookies = parseCookies(request.headers['cookie']);
    final token =
        request.headers['x-winetap-token'] ??
        request.url.queryParameters['token'] ??
        cookies[appCookie];
    if (token != null && token == appToken) return AppIdentity();
    final sid = cookies[sessionCookie];
    if (sid == null || sid.isEmpty) return AnonymousIdentity();
    final hash = hashToken(sid);
    final s = _authorized[hash];
    if (s != null) return BrowserIdentity(hash, 'autorisee', session: s);
    _purge();
    final r = _requests[hash];
    return BrowserIdentity(hash, r?.status ?? 'inconnue');
  }

  /// Records an access request. Returns the session id to set as cookie (a
  /// new one if the browser has none) and the request.
  ///
  /// Throws [AccessLimited] when another request from the same address is
  /// pending, when this address was refused less than [refusalCooldown] ago,
  /// or when [maxPending] requests are pending: anyone on the network can ask,
  /// so asking must not flood the phone with N-E2 sheets.
  ({String? newSid, AccessRequest request}) requestAccess(Request request) {
    _purge();
    final cookies = parseCookies(request.headers['cookie']);
    var sid = cookies[sessionCookie];
    final client = ClientInfo.fromRequest(request);
    final known = sid == null || sid.isEmpty ? null : hashToken(sid);
    final now = _now();
    final others = _requests.values.where((r) => r.hash != known);
    if (client.ip.isNotEmpty) {
      final sameIp = others.where((r) => r.client.ip == client.ip);
      if (sameIp.any((r) => r.status == 'en_attente')) {
        throw AccessLimited(
          'Une demande de cette adresse attend déjà une réponse sur le téléphone.',
        );
      }
    }
    final refusedHere = _requests.values.where(
      (r) =>
          r.status == 'refusee' &&
          (r.hash == known ||
              (client.ip.isNotEmpty && r.client.ip == client.ip)) &&
          now.difference(r.since) < refusalCooldown,
    );
    if (refusedHere.isNotEmpty) {
      throw AccessLimited(
        'Connexion refusée il y a moins de deux minutes : réessayez plus tard.',
      );
    }
    if (others.where((r) => r.status == 'en_attente').length >= maxPending) {
      throw AccessLimited(
        'Trop de demandes attendent une réponse sur le téléphone : réessayez plus tard.',
      );
    }
    String? newSid;
    if (known == null) sid = newSid = randomToken();
    final hash = known ?? hashToken(sid!);
    final r = _requests[hash] ?? AccessRequest(hash, client, 'en_attente');
    r
      ..client = client
      ..status = 'en_attente'
      ..since = now;
    _requests[hash] = r;
    _changes.add(null);
    return (newSid: newSid, request: r);
  }

  /// The user answered N-E2. Returns false if the request no longer exists
  /// (expired while the sheet was shown): nothing is decided.
  Future<bool> decide(String hash, {required bool allow}) async {
    _purge();
    final r = _requests[hash];
    if (r == null || r.status != 'en_attente') return false;
    if (allow) {
      _requests.remove(hash);
      final now = DateTime.now().toUtc();
      _authorized[hash] = AuthorizedSession(
        hash: hash,
        browser: r.client.browser,
        os: r.client.os,
        ip: r.client.ip,
        authorizedAt: now,
        lastSeen: now,
      );
      await _persist();
    } else {
      r
        ..status = 'refusee'
        ..since = _now();
    }
    _changes.add(null);
    return true;
  }

  Future<void> revoke(String hash) async {
    if (_authorized.remove(hash) == null) return;
    await _persist();
    _changes.add(null);
  }

  Future<List<String>> revokeAll() async {
    final hashes = _authorized.keys.toList();
    _authorized.clear();
    await _persist();
    _changes.add(null);
    return hashes;
  }

  /// Records activity; persisted at most once a minute.
  void touch(AuthorizedSession s, String ip) {
    s.lastSeen = DateTime.now().toUtc();
    if (ip.isNotEmpty) s.ip = ip;
    if (DateTime.now().difference(_lastPersist) > const Duration(minutes: 1)) {
      _persist();
      _changes.add(null);
    }
  }
}
