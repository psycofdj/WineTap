/// Tracks the timestamp of the last consumed bottle.
///
/// Shared between the HTTP server (health endpoint) and the ScanProvider
/// (direct NFC consume on the phone).  The value is 0 until the first
/// bottle is consumed after app startup.
class ConsumeTracker {
  int _lastConsumedAt = 0;

  /// Unix epoch seconds of the most recent consume, or 0 if none.
  int get lastConsumedAt => _lastConsumedAt;

  /// Record a consume event right now.
  void touch() {
    _lastConsumedAt = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
  }
}
