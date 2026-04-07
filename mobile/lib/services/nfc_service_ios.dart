import 'dart:async';
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
  @override
  Future<bool> isAvailable() async {
    dev.log('isAvailable: start', name: _tag);
    final availability = await NfcManager.instance.checkAvailability();
    final result = availability == NfcAvailability.enabled;
    dev.log('isAvailable: return $result', name: _tag);
    return result;
  }

  bool _sessionActive = false;
  bool _stopRequested = false;
  Completer<void>? _sessionEndCompleter;

  @override
  bool get isSessionActive => _sessionActive;

  @override
  Future<String> readTagId() async {
    // Wait for a previous session to fully dismiss before starting a new one.
    if (_sessionActive) {
      dev.log('readTagId: waiting for previous session to end', name: _tag);
      _sessionEndCompleter ??= Completer<void>();
      await _sessionEndCompleter!.future;
    }
    return super.readTagId();
  }

  @override
  void onReadStart() {
    dev.log('onReadStart: starting session', name: _tag);
    _sessionActive = true;
    _stopRequested = false;
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
        _stopRequested = false;
        _sessionEndCompleter?.complete();
        _sessionEndCompleter = null;
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
    if (!_sessionActive || _stopRequested) return;
    _stopRequested = true;
    NfcManager.instance
        .stopSession(alertMessageIos: alertMessage)
        .catchError((_) {});
  }

  Uint8List _extractUid(NfcTag tag) {
    final iso7816 = Iso7816Ios.from(tag);
    if (iso7816 != null) return iso7816.identifier;
    final mifare = MiFareIos.from(tag);
    if (mifare != null) return mifare.identifier;
    throw Exception('Unsupported NFC tag technology — could not extract UID');
  }
}
