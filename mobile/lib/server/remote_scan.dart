import 'dart:async';

import 'events.dart';
import 'sessions.dart';

/// A tag read requested by a computer (`POST /api/scan`, API.md §5).
class ScanRequest {
  ScanRequest(this.id, this.purpose, this.origin);

  final String id;

  /// 'entree' or 'recherche'
  final String purpose;

  /// The computer that asked, shown on N-E4.
  final ClientInfo? origin;
}

/// One remote read at a time. The app shows N-E4 when a request starts and
/// reports the result, which goes back to browsers through [EventHub].
class RemoteScan {
  RemoteScan(this._events);

  final EventHub _events;
  ScanRequest? _current;
  final _changes = StreamController<ScanRequest?>.broadcast();

  ScanRequest? get current => _current;

  /// Emits the new request, or null when it ends.
  Stream<ScanRequest?> get changes => _changes.stream;

  /// Throws [StateError] if a read is already in progress.
  ScanRequest start(String purpose, ClientInfo? origin) {
    if (_current != null) throw StateError('busy');
    final r = ScanRequest(
      randomToken(6),
      purpose == 'recherche' ? 'recherche' : 'entree',
      origin,
    );
    _current = r;
    _changes.add(r);
    return r;
  }

  void complete(String id, String tagId) =>
      _end(id, {'statut': 'lu', 'tag_id': tagId});

  void cancel(String id) => _end(id, {'statut': 'annule'});

  void fail(String id) => _end(id, {'statut': 'erreur'});

  void _end(String id, Map<String, Object?> result) {
    if (_current?.id != id) return;
    _current = null;
    _changes.add(null);
    _events.scan({'id': id, ...result});
  }
}
