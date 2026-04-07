import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math';
import 'dart:typed_data';

import 'package:nfc_manager/nfc_manager.dart';

import 'dart:developer' as dev;

import 'nfc_exceptions.dart';
import 'nfc_service_android.dart';
import 'nfc_service_ios.dart';
import 'tag_id.dart';

const _tag = 'NfcService';

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

  /// Returns whether the device has NFC hardware and it is enabled.
  Future<bool> isAvailable();

  /// Reads one tag and returns the UID as a normalized uppercase hex string
  /// (e.g. "04A32BFF").
  ///
  /// Throws [NfcReadTimeoutException] if no tag is presented.
  /// Throws [NfcSessionCancelledException] if the user cancels (iOS sheet).
  Future<String> readTagId();

  /// Cancels any active read and returns to idle.
  Future<void> stopReading();

  /// Whether a platform NFC session is currently active (e.g. iOS scan sheet).
  bool get isSessionActive;
}

/// Base implementation that owns the completer + timeout timer.
///
/// Subclasses override [onReadStart], [onReadStop], and [onReadTimeout]
/// for platform-specific behavior, and call [completeRead] / [failRead]
/// when a tag is discovered or an error occurs.
///
/// As-is (without subclassing), returns random fake tags prefixed with
/// "FFFF" — useful for desktop runs and tests.
class NoOpNfcService implements NfcService {
  static const _readTimeout = Duration(seconds: 30);
  final _random = Random();

  Completer<String>? _readCompleter;
  Timer? _readTimer;

  @override
  bool get isSessionActive => false;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<String> readTagId() async {
    dev.log('readTagId: start', name: _tag);
    _disarm();
    final completer = Completer<String>();
    _readCompleter = completer;
    _readTimer = Timer(_readTimeout, () {
      dev.log('readTagId: timeout fired, completed=${completer.isCompleted}',
          name: _tag);
      if (!completer.isCompleted) {
        dev.log('readTagId: return timeout error', name: _tag);
        _disarm();
        onReadTimeout();
        completer.completeError(NfcReadTimeoutException());
      }
    });
    dev.log('readTagId: armed, awaiting tag', name: _tag);
    onReadStart();
    return completer.future;
  }

  @override
  Future<void> stopReading() async {
    dev.log('stopReading: start', name: _tag);
    _disarm();
    onReadStop();
    dev.log('stopReading: return ok', name: _tag);
  }

  /// Called when [readTagId] arms the handler. Override to start
  /// platform-specific NFC listening.
  /// The default generates a random fake tag immediately.
  void onReadStart() {
    final suffix = List.generate(
      4,
      (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    completeRead('FFFF$suffix'.toUpperCase());
  }

  /// Called when the read timer expires. Override for platform cleanup
  /// (e.g. stopping an iOS session).
  void onReadTimeout() {}

  /// Called when [stopReading] is invoked. Override for platform cleanup.
  void onReadStop() {}

  /// Extracts the UID from a discovered tag, normalizes it, and resolves
  /// the pending read. Subclasses call this from their onDiscovered callback.
  void handleTagDiscovered(NfcTag tag, Uint8List Function(NfcTag) extractUid) {
    dev.log('handleTagDiscovered: fired', name: _tag);
    try {
      final uid = extractUid(tag);
      final hex = uid.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      final normalized = normalizeTagId(hex);
      dev.log('handleTagDiscovered: tag=$normalized', name: _tag);
      completeRead(normalized);
    } catch (e) {
      dev.log('handleTagDiscovered: extractUid error: $e', name: _tag);
      failRead(e);
    }
  }

  /// Resolves the pending read with a tag ID.
  void completeRead(String tagId) {
    dev.log('completeRead: tagId=$tagId', name: _tag);
    final completer = _readCompleter;
    _disarm();
    if (completer != null && !completer.isCompleted) {
      dev.log('completeRead: return success', name: _tag);
      completer.complete(tagId);
    } else {
      dev.log('completeRead: skipped (no pending read)', name: _tag);
    }
  }

  /// Rejects the pending read with an error.
  void failRead(Object error) {
    dev.log('failRead: error=$error', name: _tag);
    final completer = _readCompleter;
    _disarm();
    if (completer != null && !completer.isCompleted) {
      dev.log('failRead: return error', name: _tag);
      completer.completeError(error);
    } else {
      dev.log('failRead: skipped (no pending read)', name: _tag);
    }
  }

  void _disarm() {
    _readTimer?.cancel();
    _readTimer = null;
    _readCompleter = null;
  }
}
