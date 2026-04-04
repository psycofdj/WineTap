import 'dart:typed_data';

import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/nfc_manager_android.dart';

import 'dart:developer' as dev;

import 'nfc_service.dart';

const _tag = 'NfcServiceAndroid';

/// Android NFC implementation.
///
/// A single NFC session is kept alive for the entire app lifetime.
/// By default, tag discoveries are silently ignored (prevents Android from
/// showing its "New tag analyzed" system dialog).
/// When [readTagId] is called the handler is armed so the next tag discovery
/// resolves the future, then returns to no-op.
class NfcServiceAndroid extends NoOpNfcService {
  NfcServiceAndroid() {
    dev.log('constructor: starting persistent session', name: _tag);
    NfcManager.instance.startSession(
      pollingOptions: {NfcPollingOption.iso14443, NfcPollingOption.iso15693},
      onDiscovered: (tag) => handleTagDiscovered(tag, _extractUid),
    );
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
  void onReadStart() {
    dev.log('onReadStart: armed', name: _tag);
  }

  Uint8List _extractUid(NfcTag tag) {
    final android = NfcTagAndroid.from(tag);
    if (android != null) return android.id;
    throw Exception('Unsupported NFC tag technology — could not extract UID');
  }
}
