import 'dart:async';

import 'package:flutter/foundation.dart';

import '../server/remote_scan.dart';
import '../services/nfc_service.dart';

enum ReadingState { waiting, read, error }

/// A tag read in progress, shown by N-E4.
class Reading {
  Reading({required this.purpose, this.request});

  /// consommer, identifier, entree, recherche
  final String purpose;

  /// Set when a computer asked for the read.
  final ScanRequest? request;
  ReadingState state = ReadingState.waiting;
  String? tag;

  bool get fromComputer => request != null;
}

/// Runs every tag read through N-E4 (D-13): reads asked by the site in the
/// app (`readTag`) and reads asked by a computer (`POST /api/scan`).
class ReadingController extends ChangeNotifier {
  ReadingController(this._nfc, this._remote) {
    _sub = _remote.changes.listen(_onRemote);
  }

  final NfcService _nfc;
  final RemoteScan _remote;
  late final StreamSubscription<ScanRequest?> _sub;
  Completer<String?>? _done;

  /// Called after a read requested by a computer succeeded.
  VoidCallback? onSentToComputer;

  Reading? current;

  /// Read asked by the site in the app. Returns the tag, or null if cancelled
  /// (or if another read is in progress).
  Future<String?> readLocal(String purpose) {
    if (current != null) return Future.value(null);
    _start(Reading(purpose: purpose));
    _done = Completer<String?>();
    return _done!.future;
  }

  void _onRemote(ScanRequest? r) {
    if (r == null) {
      // Ended by the computer (cancelled) while still on screen.
      if (current?.fromComputer == true) _close(null, notifyRemote: false);
      return;
    }
    if (current != null) {
      _remote.cancel(r.id);
      return;
    }
    _start(Reading(purpose: r.purpose, request: r));
  }

  void _start(Reading r) {
    current = r;
    notifyListeners();
    _attempt();
  }

  Future<void> _attempt() async {
    final r = current;
    if (r == null) return;
    r.state = ReadingState.waiting;
    notifyListeners();
    final res = await _nfc.readTag();
    if (current != r) return;
    if (res.tag != null) {
      r
        ..state = ReadingState.read
        ..tag = res.tag;
      notifyListeners();
      await Future<void>.delayed(const Duration(milliseconds: 900));
      if (current == r) _close(res.tag);
    } else if (res.error == 'cancelled') {
      _close(null);
    } else {
      r.state = ReadingState.error;
      notifyListeners();
    }
  }

  void retry() => _attempt();

  Future<void> cancel() async {
    final r = current;
    if (r == null) return;
    await _nfc.cancel();
    if (current == r) _close(null);
  }

  void _close(String? tag, {bool notifyRemote = true}) {
    final r = current;
    current = null;
    notifyListeners();
    final done = _done;
    _done = null;
    if (r?.request == null) {
      done?.complete(tag);
      return;
    }
    if (!notifyRemote) return;
    if (tag != null) {
      _remote.complete(r!.request!.id, tag);
      onSentToComputer?.call();
    } else {
      _remote.cancel(r!.request!.id);
    }
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
