import 'dart:typed_data';

import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/nfc_manager_ios.dart';

import 'dart:developer' as dev;

import 'nfc_service.dart';
import 'tag_id.dart';

const _tag = 'NfcServiceIos';

/// iOS NFC implementation.
///
/// Each scan starts a new NFC session which shows the system NFC sheet.
/// The session is stopped when a tag is read, on timeout, on error, or
/// when the user dismisses the sheet.
class NfcServiceIos extends NfcServiceBase {
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
    dev.log('platformStartScan: starting session', name: _tag);
    NfcManager.instance.startSession(
      pollingOptions: {NfcPollingOption.iso14443, NfcPollingOption.iso15693},
      alertMessageIos: 'Approchez le téléphone du tag NFC',
      onDiscovered: (NfcTag tag) {
        dev.log('onDiscovered: fired', name: _tag);
        NfcManager.instance
            .stopSession(alertMessageIos: 'Tag lu')
            .catchError((_) {});
        try {
          final uid = _extractUid(tag);
          final hex =
              uid.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
          onTagDiscovered(normalizeTagId(hex));
        } catch (e) {
          dev.log('onDiscovered: extractUid error: $e', name: _tag);
          onCanceled();
        }
      },
      onSessionErrorIos: (error) {
        dev.log('onSessionErrorIos: $error', name: _tag);
        onCanceled();
      },
    );
  }

  @override
  Future<void> platformStopScan() async {
    dev.log('platformStopScan: stopping session', name: _tag);
    await NfcManager.instance.stopSession().catchError((_) {});
  }

  Uint8List _extractUid(NfcTag tag) {
    final iso7816 = Iso7816Ios.from(tag);
    if (iso7816 != null) return iso7816.identifier;
    final mifare = MiFareIos.from(tag);
    if (mifare != null) return mifare.identifier;
    throw Exception('Unsupported NFC tag technology — could not extract UID');
  }
}
