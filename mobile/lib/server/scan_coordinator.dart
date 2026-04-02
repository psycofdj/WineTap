import 'dart:async';

/// Manages scan request lifecycle for coordinated intake.
///
/// The manager POSTs a scan request, then long-polls for the result.
/// The phone's NFC handler submits the scanned tag ID via [submitResult].
/// Each request is a single scan — the manager loops for bulk intake.
/// Timeout is injectable (30s default, short for tests).
class ScanCoordinator {
  Completer<String?>? _completer;
  final Duration timeout;

  ScanCoordinator({this.timeout = const Duration(seconds: 30)});

  /// Whether a scan request is currently pending.
  bool get hasPendingRequest => _completer != null;

  /// Start a new scan request. Throws if one is already pending.
  void request() {
    if (_completer != null) {
      throw StateError('Scan already in progress');
    }
    _completer = Completer<String?>();
  }

  /// Wait for a tag to be scanned. Returns the tag ID, or null on timeout.
  /// Throws [StateError] if no request is pending.
  Future<String?> waitForResult() async {
    final completer = _completer;
    if (completer == null) {
      throw StateError('No pending request');
    }
    try {
      return await completer.future.timeout(timeout);
    } on TimeoutException {
      // Timeout — caller retries with another long poll.
      // Create a fresh completer for the next poll (same request continues).
      if (_completer == completer && !completer.isCompleted) {
        _completer = Completer<String?>();
      }
      return null;
    }
  }

  /// Called by the NFC handler when a tag is scanned.
  /// Always resets after delivering the result — manager sends a new request
  /// for the next bottle in bulk intake.
  void submitResult(String tagId) {
    final completer = _completer;
    if (completer == null || completer.isCompleted) return;
    completer.complete(tagId);
    _completer = null;
  }

  /// Cancel the pending scan request.
  void cancel() {
    final completer = _completer;
    _completer = null;
    if (completer != null && !completer.isCompleted) {
      completer.complete(null);
    }
  }
}
