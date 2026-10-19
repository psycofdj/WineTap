import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:shelf/shelf.dart';
import 'package:wine_tap_mobile/server/api/context.dart';
import 'package:wine_tap_mobile/server/database.dart';
import 'package:wine_tap_mobile/server/db_holder.dart';
import 'package:wine_tap_mobile/server/events.dart';
import 'package:wine_tap_mobile/server/preferences.dart';
import 'package:wine_tap_mobile/server/remote_scan.dart';
import 'package:wine_tap_mobile/server/server.dart';
import 'package:wine_tap_mobile/server/sessions.dart';

/// Adjustable time source for [SessionStore].
class TestClock {
  Duration offset = Duration.zero;
  DateTime now() => DateTime.now().add(offset);
  void advance(Duration d) => offset += d;
}

/// Stands for shelf's connection info: gives the client's address.
class _Connection {
  _Connection(String ip) : remoteAddress = InternetAddress(ip);
  final InternetAddress remoteAddress;
}

/// A v3 server with its database, called without a socket.
class Harness {
  Harness._(this.ctx, this.handler, this.dir, this.site, this.clock);

  /// Time seen by the session store.
  final TestClock clock;

  final ApiContext ctx;
  final Handler handler;
  final Directory dir;

  /// Files of the fake built site.
  final Map<String, String> site;

  AppDatabase get db => ctx.db;
  String get appToken => ctx.sessions.appToken;

  static Future<Harness> create({int year = 2026}) async {
    final dir = await Directory.systemTemp.createTemp('winetap-test');
    final file = File('${dir.path}/winetap.sqlite');
    AppDatabase open() => AppDatabase.forTesting(NativeDatabase(file));
    final db = open();
    await db.customSelect('SELECT 1').get();
    final store = MemoryStore();
    final clock = TestClock();
    final sessions = SessionStore(store, clock: clock.now)..load();
    final events = EventHub(isAuthorized: sessions.isAuthorized);
    final ctx = ApiContext(
      dbs: DbHolder(db, file, open),
      sessions: sessions,
      events: events,
      scan: RemoteScan(events),
      settings: Settings(store),
      phone: PhoneInfo(
        name: 'iPhone',
        localAddress: () async => '192.168.1.42',
      ),
      currentYear: () => year,
    );
    final site = {
      'index.html':
          '<!doctype html><html><head><title>WineTap</title></head><body></body></html>',
      'assets/index-abc.js': 'console.log(1)',
    };
    final handler = buildHandler(
      ctx,
      enableWakelock: false,
      loadSite: (path) async =>
          site[path] == null ? null : utf8.encode(site[path]!),
    );
    return Harness._(ctx, handler, dir, site, clock);
  }

  Future<void> dispose() async {
    await ctx.events.closeAll();
    await ctx.db.close();
    await dir.delete(recursive: true);
  }

  /// Calls the server. By default as the app's WebView (token header).
  Future<Response> call(
    String method,
    String path, {
    Object? json,
    List<int>? bytes,
    bool app = true,
    String host = 'localhost:8080',
    String? origin,
    String? cookie,
    String? ip,
    Map<String, String> headers = const {},
  }) {
    final h = <String, String>{
      'host': host,
      'origin': origin ?? 'http://$host',
      'user-agent':
          'Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) Gecko/20100101 Firefox/131.0',
      if (app) 'x-winetap-token': appToken,
      'cookie': ?cookie,
      if (json != null) 'content-type': 'application/json',
      ...headers,
    };
    final Object? body = json != null ? jsonEncode(json) : bytes;
    return Future.sync(
      () => handler(
        Request(
          method,
          Uri.parse('http://$host$path'),
          headers: h,
          body: body,
          context: {
            'shelf.io.connection_info': ?(ip == null ? null : _Connection(ip)),
          },
        ),
      ),
    );
  }

  /// Body as JSON.
  static Future<dynamic> body(Response r) async =>
      jsonDecode(await r.readAsString());

  // Fixtures --------------------------------------------------------------------

  Future<int> domain(String name) async =>
      (await body(
            await call('POST', '/api/domaines', json: {'nom': name}),
          ))['id']
          as int;

  Future<int> appellation(String name, {String region = 'Bordeaux'}) async =>
      (await body(
            await call(
              'POST',
              '/api/appellations',
              json: {'nom': name, 'region': region},
            ),
          ))['id']
          as int;

  Future<int> cuvee(
    String name,
    int domainId, {
    int appellationId = 0,
    int color = 1,
  }) async =>
      (await body(
            await call(
              'POST',
              '/api/cuvees',
              json: {
                'nom': name,
                'domaine_id': domainId,
                'appellation_id': appellationId,
                'couleur': color,
              },
            ),
          ))['id']
          as int;

  Future<Map<String, dynamic>> bottle(
    int cuveeId, {
    int vintage = 2018,
    String? tag,
  }) async =>
      (await body(
            await call(
              'POST',
              '/api/bouteilles',
              json: {'cuvee_id': cuveeId, 'millesime': vintage, 'tag_id': ?tag},
            ),
          ))
          as Map<String, dynamic>;
}

/// Collects the server-sent events of a stream for [duration].
Future<String> collectEvents(
  Response r, {
  Duration duration = const Duration(milliseconds: 200),
}) async {
  final buf = StringBuffer();
  final sub = r.read().listen((chunk) => buf.write(utf8.decode(chunk)));
  await Future<void>.delayed(duration);
  await sub.cancel();
  return buf.toString();
}
