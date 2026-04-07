import 'dart:typed_data';

import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/nfc_manager_ios.dart';

import 'dart:developer' as dev;

import 'nfc_exceptions.dart';
import 'nfc_service.dart';

const _tag = 'NfcServiceIos';

/// iOS NFC implementation.
///
/// Each read starts a new NFC session which shows the system NFC sheet.
/// The session is stopped when a tag is read, on timeout, on error, or
/// when the user dismisses the sheet.
class NfcServiceIos extends NoOpNfcService {
  bool _sessionActive = false;

  /// Tracks an in-flight [stopSession] call so [teardownSession] can await it
  /// even when another code path (e.g. widget dispose) already triggered the
  /// stop and set [_sessionActive] to false.
  Future<void>? _pendingStop;

  @override
  Future<bool> isAvailable() async {
    dev.log('isAvailable: start', name: _tag);
    final availability = await NfcManager.instance.checkAvailability();
    final result = availability == NfcAvailability.enabled;
    dev.log('isAvailable: return $result', name: _tag);
    return result;
  }

  @override
  Future<void> teardownSession() async {
    if (_sessionActive) {
      dev.log('teardownSession: stopping active session', name: _tag);
      _sessionActive = false;
      _pendingStop = NfcManager.instance.stopSession().catchError((_) {});
    }
    if (_pendingStop != null) {
      dev.log('teardownSession: awaiting pending stop', name: _tag);
      await _pendingStop;
      _pendingStop = null;
    }
  }

  @override
  void onReadStart() {
    dev.log('onReadStart: starting session', name: _tag);
    _sessionActive = true;
    NfcManager.instance.startSession(
      pollingOptions: {NfcPollingOption.iso14443, NfcPollingOption.iso15693},
      alertMessageIos: 'Approchez le téléphone du tag NFC',
      onDiscovered: (NfcTag tag) {
        dev.log('onDiscovered: fired', name: _tag);
        _stopSession(alertMessage: 'Tag lu');
        handleTagDiscovered(tag, _extractUid);
      },
      onSessionErrorIos: (error) {
        dev.log('onSessionErrorIos: $error', name: _tag);
        _sessionActive = false;
        failRead(NfcSessionCancelledException());
      },
    );
  }

  @override
  void onReadTimeout() {
    dev.log('onReadTimeout: stopping session', name: _tag);
    _stopSession();
  }

  @override
  void onReadStop() {
    dev.log('onReadStop: stopping session', name: _tag);
    _stopSession();
  }

  void _stopSession({String? alertMessage}) {
    if (!_sessionActive) return;
    _sessionActive = false;
    _pendingStop = NfcManager.instance
        .stopSession(alertMessageIos: alertMessage)
        .catchError((_) {})
        .whenComplete(() => _pendingStop = null);
  }

  Uint8List _extractUid(NfcTag tag) {
    final iso7816 = Iso7816Ios.from(tag);
    if (iso7816 != null) return iso7816.identifier;
    final mifare = MiFareIos.from(tag);
    if (mifare != null) return mifare.identifier;
    throw Exception('Unsupported NFC tag technology — could not extract UID');
  }
}
