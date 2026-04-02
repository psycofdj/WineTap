/// NFC is not available on this device.
class NfcNotAvailableException implements Exception {
  @override
  String toString() => 'NFC is not available on this device';
}

/// NFC read timed out — no tag was presented.
class NfcReadTimeoutException implements Exception {
  @override
  String toString() => 'NFC read timed out — no tag detected';
}

/// NFC session was cancelled by the user (e.g. iOS NFC sheet dismissed).
class NfcSessionCancelledException implements Exception {
  @override
  String toString() => 'NFC session was cancelled by user';
}
