import 'package:flutter_test/flutter_test.dart';
import 'package:shelf/shelf.dart' show Response;
import 'package:wine_tap_mobile/server/api/security.dart';
import 'package:wine_tap_mobile/server/sessions.dart';

import 'harness.dart';

/// Cookie value from a Set-Cookie header.
String cookieOf(String setCookie) => setCookie.split(';').first;

void main() {
  late Harness h;
  setUp(() async => h = await Harness.create());
  tearDown(() => h.dispose());

  group('hostAllowed', () {
    test('accepts localhost and IP addresses', () {
      expect(hostAllowed('localhost:8080'), isTrue);
      expect(hostAllowed('192.168.1.42:8080'), isTrue);
      expect(hostAllowed('127.0.0.1'), isTrue);
      expect(hostAllowed('[::1]:8080'), isTrue);
    });
    test('rejects domain names (DNS rebinding)', () {
      expect(hostAllowed('evil.example.com:8080'), isFalse);
      expect(hostAllowed('192.168.1.42.nip.io'), isFalse);
      expect(hostAllowed(null), isFalse);
    });
  });

  group('Host and Origin', () {
    test('a domain name in Host is refused', () async {
      final r = await h.call(
        'GET',
        '/api/bouteilles',
        host: 'evil.example.com:8080',
      );
      expect(r.statusCode, 403);
    });

    test('a write without a matching Origin is refused', () async {
      final r = await h.call(
        'POST',
        '/api/domaines',
        json: {'nom': 'X'},
        origin: 'http://evil.example.com',
      );
      expect(r.statusCode, 403);
      final none = await h.call(
        'POST',
        '/api/domaines',
        json: {'nom': 'X'},
        headers: {'origin': ''},
      );
      expect(none.statusCode, 403);
    });
  });

  group('Authorization of a computer', () {
    test('an unknown browser gets 401, except on session and events', () async {
      final r = await h.call('GET', '/api/bouteilles', app: false);
      expect(r.statusCode, 401);
      final s = await h.call('GET', '/api/session', app: false);
      expect(s.statusCode, 401);
      expect((await Harness.body(s))['statut'], 'inconnue');
    });

    test('request, wait, authorize, then revoke', () async {
      final req = await h.call(
        'POST',
        '/api/session',
        app: false,
        host: '192.168.1.42:8080',
      );
      expect(req.statusCode, 202);
      expect((await Harness.body(req))['statut'], 'en_attente');
      final setCookie = req.headers['set-cookie']!;
      expect(setCookie, contains('HttpOnly'));
      expect(setCookie, contains('SameSite=Strict'));
      final cookie = cookieOf(setCookie);

      expect(h.ctx.sessions.pending, hasLength(1));
      expect(h.ctx.sessions.pending.first.client.browser, 'Firefox');
      expect(h.ctx.sessions.pending.first.client.os, 'macOS');

      var s = await h.call(
        'GET',
        '/api/session',
        app: false,
        cookie: cookie,
        host: '192.168.1.42:8080',
      );
      expect((await Harness.body(s))['statut'], 'en_attente');

      await h.ctx.sessions.decide(
        h.ctx.sessions.pending.first.hash,
        allow: true,
      );
      s = await h.call(
        'GET',
        '/api/session',
        app: false,
        cookie: cookie,
        host: '192.168.1.42:8080',
      );
      expect(s.statusCode, 200);
      final body = await Harness.body(s);
      expect(body['dans_application'], isFalse);
      expect(body['telephone']['adresse'], '192.168.1.42:8080');
      final list = await h.call(
        'GET',
        '/api/bouteilles',
        app: false,
        cookie: cookie,
        host: '192.168.1.42:8080',
      );
      expect(list.statusCode, 200);

      await h.ctx.sessions.revoke(h.ctx.sessions.authorized.first.hash);
      final after = await h.call(
        'GET',
        '/api/bouteilles',
        app: false,
        cookie: cookie,
        host: '192.168.1.42:8080',
      );
      expect(after.statusCode, 401);
    });

    test(
      'a refused browser sees « refusee » and can ask again later',
      () async {
        final req = await h.call('POST', '/api/session', app: false);
        final cookie = cookieOf(req.headers['set-cookie']!);
        await h.ctx.sessions.decide(
          h.ctx.sessions.pending.first.hash,
          allow: false,
        );
        var s = await h.call('GET', '/api/session', app: false, cookie: cookie);
        expect((await Harness.body(s))['statut'], 'refusee');
        final tooSoon = await h.call(
          'POST',
          '/api/session',
          app: false,
          cookie: cookie,
        );
        expect(tooSoon.statusCode, 429);
        expect((await Harness.body(tooSoon))['erreur'], 'trop_de_demandes');
        h.clock.advance(SessionStore.refusalCooldown);
        final again = await h.call(
          'POST',
          '/api/session',
          app: false,
          cookie: cookie,
        );
        expect(again.statusCode, 202);
        expect(again.headers['set-cookie'], isNull, reason: 'same session id');
        s = await h.call('GET', '/api/session', app: false, cookie: cookie);
        expect((await Harness.body(s))['statut'], 'en_attente');
      },
    );

    group('requests are limited (R-05)', () {
      Future<Response> ask(String ip, {String? cookie}) =>
          h.call('POST', '/api/session', app: false, ip: ip, cookie: cookie);

      test('one pending request per address', () async {
        final first = await ask('192.168.1.27');
        expect(first.statusCode, 202);
        final cookie = cookieOf(first.headers['set-cookie']!);
        // Same browser asking again: still one request.
        expect((await ask('192.168.1.27', cookie: cookie)).statusCode, 202);
        // Another browser (no cookie) from the same address: refused.
        final second = await ask('192.168.1.27');
        expect(second.statusCode, 429);
        expect(second.headers['set-cookie'], isNull);
        expect(h.ctx.sessions.pending, hasLength(1));
        // Another address is not blocked.
        expect((await ask('192.168.1.54')).statusCode, 202);
        expect(h.ctx.sessions.pending, hasLength(2));
      });

      test('a refused address waits before asking again', () async {
        await ask('192.168.1.27');
        await h.ctx.sessions.decide(
          h.ctx.sessions.pending.first.hash,
          allow: false,
        );
        expect((await ask('192.168.1.27')).statusCode, 429);
        h.clock.advance(SessionStore.refusalCooldown);
        expect((await ask('192.168.1.27')).statusCode, 202);
      });

      test('at most a few pending requests in all', () async {
        for (var i = 0; i < SessionStore.maxPending; i++) {
          expect((await ask('192.168.1.${10 + i}')).statusCode, 202);
        }
        expect((await ask('192.168.1.99')).statusCode, 429);
        expect(h.ctx.sessions.pending, hasLength(SessionStore.maxPending));
      });

      test('pending requests expire; a late answer decides nothing', () async {
        final r = await ask('192.168.1.27');
        final cookie = cookieOf(r.headers['set-cookie']!);
        final hash = h.ctx.sessions.pending.single.hash;
        h.clock.advance(
          SessionStore.pendingLifetime + const Duration(seconds: 1),
        );
        expect(h.ctx.sessions.pending, isEmpty);
        expect(await h.ctx.sessions.decide(hash, allow: true), isFalse);
        expect(h.ctx.sessions.authorized, isEmpty);
        final s = await h.call(
          'GET',
          '/api/session',
          app: false,
          cookie: cookie,
        );
        expect((await Harness.body(s))['statut'], 'inconnue');
        // The address can ask again.
        expect((await ask('192.168.1.27')).statusCode, 202);
      });
    });

    test('authorized sessions are kept, as hashes only', () async {
      final req = await h.call('POST', '/api/session', app: false);
      final sid = cookieOf(req.headers['set-cookie']!).split('=').last;
      await h.ctx.sessions.decide(
        h.ctx.sessions.pending.first.hash,
        allow: true,
      );
      expect(h.ctx.sessions.authorized.first.hash, hashToken(sid));
      expect(h.ctx.sessions.authorized.first.hash, isNot(sid));
    });
  });

  group('App WebView', () {
    test('the token makes the WebView authorized', () async {
      final s = await h.call('GET', '/api/session');
      expect(s.statusCode, 200);
      expect((await Harness.body(s))['dans_application'], isTrue);
    });

    test('a wrong token is not the app', () async {
      final r = await h.call(
        'GET',
        '/api/bouteilles',
        app: false,
        headers: {'x-winetap-token': 'faux'},
      );
      expect(r.statusCode, 401);
    });
  });

  group('UserAgent', () {
    test('parses common browsers', () {
      final chrome = UserAgent.parse(
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36',
      );
      expect(
        (chrome.browser, chrome.version, chrome.os),
        ('Chrome', '130', 'Windows'),
      );
      final safari = UserAgent.parse(
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 14_5) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Safari/605.1.15',
      );
      expect((safari.browser, safari.os), ('Safari', 'macOS'));
    });
  });
}
