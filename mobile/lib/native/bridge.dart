import 'dart:convert';
import 'dart:developer' as dev;

import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../server/db_holder.dart';
import 'reading.dart';

/// Native side of `window.winetapBridge` (API.md §9). Messages arrive on the
/// `WineTapNative` JavaScript channel: `{ id, methode, args }`; answers go back
/// through `window.__wtRetour(id, result)`.
class Bridge {
  Bridge({
    required this.reading,
    required this.dbs,
    required this.reply,
    required this.openNative,
    this.setTheme,
  });

  final ReadingController reading;
  final DbHolder dbs;

  /// Runs JavaScript in the WebView.
  final Future<void> Function(String js) reply;

  /// Opens N-E1 ('adresse') or N-E3 ('connexions').
  final void Function(String screen) openNative;

  /// Theme chosen in the site: 'clair', 'sombre' or 'systeme'.
  final void Function(String theme)? setTheme;

  static const _files = MethodChannel('com.winetap.mobile/file_io');

  Future<void> handle(String message) async {
    Map<String, dynamic> m;
    try {
      m = jsonDecode(message) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    final id = m['id'];
    final args = (m['args'] as List?) ?? const [];
    Object? result;
    try {
      result = await _call('${m['methode']}', args);
    } catch (e) {
      dev.log('bridge ${m['methode']}: $e', name: 'Bridge');
      result = {'erreur': '$e'};
    }
    await reply('window.__wtRetour(${jsonEncode(id)}, ${jsonEncode(result)})');
  }

  Future<Object?> _call(String method, List<dynamic> args) async {
    switch (method) {
      case 'readTag':
        final tag = await reading.readLocal(
          '${args.isEmpty ? 'identifier' : args.first}',
        );
        return tag == null ? {'annule': true} : {'tag_id': tag};
      case 'saveBackup':
        final d = DateTime.now();
        String p(int n) => n.toString().padLeft(2, '0');
        final name = 'winetap-${d.year}-${p(d.month)}-${p(d.day)}.db';
        final bytes = Uint8List.fromList(await dbs.backup());
        final saved = await _files.invokeMethod<bool>('saveFile', {
          'bytes': bytes,
          'name': name,
        });
        return {'enregistre': saved == true, 'nom': name};
      case 'pickFile':
        final bytes = await _files.invokeMethod<Uint8List>('pickFileBytes');
        if (bytes == null) return {'annule': true};
        return {'nom': 'fichier', 'base64': base64Encode(bytes)};
      case 'openNative':
        openNative('${args.isEmpty ? '' : args.first}');
        return true;
      case 'openExternal':
        final uri = Uri.tryParse('${args.isEmpty ? '' : args.first}');
        if (uri == null || !(uri.scheme == 'https' || uri.scheme == 'http')) {
          return false;
        }
        return launchUrl(uri, mode: LaunchMode.externalApplication);
      case 'setTheme':
        setTheme?.call('${args.isEmpty ? 'systeme' : args.first}');
        return true;
      default:
        return {'erreur': 'méthode inconnue'};
    }
  }
}
