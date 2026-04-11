import 'dart:typed_data';

import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/nfc_manager_android.dart';

import 'dart:developer' as dev;

import 'nfc_service.dart';
import 'tag_id.dart';

const _tag = 'NfcServiceAndroid';

/// Android NFC implementation.
///
/// A single NFC session is kept alive for the entire app lifetime.
/// By default, tag discoveries are silently ignored.
/// When [platformStartScan] is called the handler is armed so the next
/// tag discovery resolves via the callback, then disarms.
class NfcServiceAndroid extends NfcServiceBase {
  void Function(String tagId)? _pendingOnTagDiscovered;

  NfcServiceAndroid() {
    dev.log('constructor: starting persistent session', name: _tag);
    NfcManager.instance.startSession(
      pollingOptions: {NfcPollingOption.iso14443, NfcPollingOption.iso15693},
      onDiscovered: _handleTag,
    );
  }

  @override
  Future<void> restartSession() async {
    dev.log('restartSession: re-establishing persistent NFC session', name: _tag);
    _pendingOnTagDiscovered = null;
    await NfcManager.instance.stopSession().catchError((_) {});
    NfcManager.instance.startSession(
      pollingOptions: {NfcPollingOption.iso14443, NfcPollingOption.iso15693},
      onDiscovered: _handleTag,
    );
  }

  void _handleTag(NfcTag tag) {
    final callback = _pendingOnTagDiscovered;
    if (callback == null) return;
    _pendingOnTagDiscovered = null;
    try {
      final uid = _extractUid(tag);
      final hex = uid.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      callback(normalizeTagId(hex));
    } catch (e) {
      dev.log('_handleTag: extractUid error: $e', name: _tag);
    }
  }

  @override
  Future<bool> isAvailable() async {
    dev.log('isAvailable: start', name: _tag);
    final availability = await NfcManager.instance.checkAvailability();
    final result = availability == NfcAvailability.enabled;
    dev.log('isAvailable: return $result', name: _tag);
    return result;
  }

  @override
  void platformStartScan({
    required void Function(String tagId) onTagDiscovered,
    required void Function() onCanceled,
  }) {
    dev.log('platformStartScan: armed', name: _tag);
    _pendingOnTagDiscovered = onTagDiscovered;
  }

  @override
  Future<void> platformStopScan() async {
    dev.log('platformStopScan: disarmed', name: _tag);
    _pendingOnTagDiscovered = null;
  }

  Uint8List _extractUid(NfcTag tag) {
    final android = NfcTagAndroid.from(tag);
    if (android != null) return android.id;
    throw Exception('Unsupported NFC tag technology — could not extract UID');
  }
}
