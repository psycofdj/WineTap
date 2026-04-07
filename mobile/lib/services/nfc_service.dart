import 'dart:async';
import 'dart:io' show Platform;
import 'dart:developer' as dev;

import 'nfc_exceptions.dart';
import 'nfc_service_android.dart';
import 'nfc_service_ios.dart';

const _tag = 'NfcService';

enum NfcState { ready, scanning, postScanning }

/// Result of [NfcService.readTag].
/// Exactly one of [tag] or [error] is non-null.
typedef NfcReadResult = ({String? tag, String? error});

/// Platform-agnostic NFC tag reading interface.
///
/// The factory constructor picks the right implementation for the current
/// platform. On desktop (or any non-mobile platform) a no-op fallback is
/// returned so the app can run without NFC hardware.
abstract class NfcService {
  factory NfcService() {
    if (Platform.isAndroid) return NfcServiceAndroid();
    if (Platform.isIOS) return NfcServiceIos();
    return NoOpNfcService();
  }

  NfcState get state;
  Future<bool> isAvailable();

  /// High-level read: handles any current state, ensures scanner is ready,
  /// then performs a scan and returns the result.
  Future<NfcReadResult> readTag();

  /// Cancels an active scan. No-op if not scanning.
  Future<void> cancel();
}

/// Base implementation that owns the state machine.
///
/// Subclasses override [platformStartScan] and [platformStopScan]
/// for platform-specific NFC behavior.
abstract class NfcServiceBase implements NfcService {
  static const _postScanCooldown = Duration(seconds: 5);

  NfcState _state = NfcState.ready;
  Completer<String>? _scanCompleter;
  DateTime? _lastScanAt;

  @override
  NfcState get state => _state;

  /// Start listening for NFC tags. The implementation must call
  /// [onTagDiscovered] with the normalized hex tag ID when a tag is read,
  /// or [onCanceled] if the scan is cancelled by the platform (e.g. iOS
  /// sheet dismissed).
  void platformStartScan({
    required void Function(String tagId) onTagDiscovered,
    required void Function() onCanceled,
  });

  /// Stop listening for NFC tags (platform cleanup).
  Future<void> platformStopScan();

  Future<String> _scan() {
    dev.log('scan: state=$_state', name: _tag);
    switch (_state) {
      case NfcState.ready:
        _state = NfcState.scanning;
        final completer = Completer<String>();
        _scanCompleter = completer;
        platformStartScan(
          onTagDiscovered: _onTagDiscovered,
          onCanceled: _onCanceled,
        );
        return completer.future;
      case NfcState.scanning:
        throw NfcNotReadyException('already scanning');
      case NfcState.postScanning:
        throw NfcNotReadyException('post-scanning');
    }
  }

  @override
  Future<void> cancel() async {
    dev.log('cancel: state=$_state', name: _tag);
    switch (_state) {
      case NfcState.ready:
      case NfcState.postScanning:
        return;
      case NfcState.scanning:
        _state = NfcState.postScanning;
        _lastScanAt = DateTime.now();
        final completer = _scanCompleter;
        _scanCompleter = null;
        await platformStopScan();
        if (completer != null && !completer.isCompleted) {
          completer.completeError(NfcSessionCancelledException());
        }
    }
  }

  Future<void> _waitReady() async {
    dev.log('waitReady: state=$_state', name: _tag);
    switch (_state) {
      case NfcState.ready:
        return;
      case NfcState.scanning:
        throw NfcNotReadyException('already scanning');
      case NfcState.postScanning:
        final elapsed = DateTime.now().difference(_lastScanAt ?? DateTime.now());
        final remaining = _postScanCooldown - elapsed;
        if (remaining > Duration.zero) {
          await Future.delayed(remaining);
        }
        _state = NfcState.ready;
    }
  }

  @override
  Future<NfcReadResult> readTag() async {
    dev.log('readTag: state=$_state', name: _tag);
    switch (_state) {
      case NfcState.scanning:
        await cancel();
        await _waitReady();
      case NfcState.postScanning:
        await _waitReady();
      case NfcState.ready:
        break;
    }
    try {
      final tag = await _scan();
      return (tag: tag, error: null);
    } on NfcSessionCancelledException {
      return (tag: null, error: 'cancelled');
    } on NfcReadTimeoutException {
      return (tag: null, error: 'timeout');
    } catch (e) {
      return (tag: null, error: e.toString());
    }
  }

  void _onTagDiscovered(String tagId) {
    dev.log('_onTagDiscovered: tagId=$tagId, state=$_state', name: _tag);
    platformStopScan();
    if (_state != NfcState.scanning) return;
    _state = NfcState.postScanning;
    _lastScanAt = DateTime.now();
    final completer = _scanCompleter;
    _scanCompleter = null;
    completer?.complete(tagId);
  }

  void _onCanceled() {
    dev.log('_onCanceled: state=$_state', name: _tag);
    platformStopScan();
    if (_state != NfcState.scanning) return;
    _state = NfcState.postScanning;
    _lastScanAt = DateTime.now();
    final completer = _scanCompleter;
    _scanCompleter = null;
    if (completer != null && !completer.isCompleted) {
      completer.completeError(NfcSessionCancelledException());
    }
  }
}

/// Desktop / test fallback that produces a fake tag immediately.
class NoOpNfcService extends NfcServiceBase {
  @override
  Future<bool> isAvailable() async => true;

  @override
  void platformStartScan({
    required void Function(String tagId) onTagDiscovered,
    required void Function() onCanceled,
  }) {
    final suffix = DateTime.now().microsecondsSinceEpoch
        .toRadixString(16)
        .padLeft(8, '0')
        .substring(0, 8)
        .toUpperCase();
    onTagDiscovered('FFFF$suffix');
  }

  @override
  Future<void> platformStopScan() async {}
}
