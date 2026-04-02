import 'dart:async';
import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/nfc_manager_android.dart';
import 'package:nfc_manager/nfc_manager_ios.dart';

import 'dart:developer' as dev;

import 'nfc_exceptions.dart';
import 'tag_id.dart';

/// NFC tag reading service. Platform differences (iOS NFC sheet vs Android
/// foreground dispatch) are hidden inside this class.
class NfcService {
  /// Default timeout for a single NFC read on Android.
  static const _readTimeout = Duration(seconds: 30);

  /// Global flag — iOS allows only one NFC session at a time across the
  /// entire app, regardless of how many NfcService instances exist.
  static bool _sessionActive = false;

  /// Returns whether the device has NFC hardware and it is enabled.
  Future<bool> isAvailable() async {
    final availability = await NfcManager.instance.checkAvailability();
    return availability == NfcAvailability.enabled;
  }

  /// Initiates an NFC session, reads one tag, and returns the UID as a
  /// normalized uppercase hex string (e.g., "04A32BFF").
  ///
  /// Throws [NfcReadTimeoutException] if no tag is presented.
  /// Throws [NfcSessionCancelledException] if the user cancels (iOS sheet).
  Future<String> readTagId() async {
    dev.log('readTagId called, _sessionActive=$_sessionActive', name: 'NfcService');

    // Ensure no lingering session (iOS single-session limit).
    if (_sessionActive) {
      dev.log('Stopping lingering session', name: 'NfcService');
      _sessionActive = false;
      try {
        await NfcManager.instance.stopSession();
      } catch (e) {
        dev.log('stopSession error: $e', name: 'NfcService');
      }
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }

    dev.log('Starting new NFC session', name: 'NfcService');
    final completer = Completer<String>();

    // Android has no system NFC timeout — enforce one explicitly.
    final timer = Timer(_readTimeout, () {
      _sessionActive = false;
      if (!completer.isCompleted) {
        NfcManager.instance.stopSession();
        completer.completeError(NfcReadTimeoutException());
      }
    });

    _sessionActive = true;

    NfcManager.instance.startSession(
      pollingOptions: {NfcPollingOption.iso14443, NfcPollingOption.iso15693},
      alertMessageIos: 'Approchez le téléphone du tag NFC',
      onDiscovered: (NfcTag tag) {
        dev.log('onDiscovered fired', name: 'NfcService');
        _sessionActive = false;
        timer.cancel();
        try {
          final uid = _extractUid(tag);
          NfcManager.instance.stopSession();
          if (!completer.isCompleted) {
            completer.complete(normalizeTagId(_bytesToHex(uid)));
          }
        } catch (e) {
          NfcManager.instance
              .stopSession(errorMessageIos: e.toString());
          if (!completer.isCompleted) {
            completer.completeError(e);
          }
        }
      },
      onSessionErrorIos: (error) {
        dev.log('onSessionErrorIos: $error', name: 'NfcService');
        _sessionActive = false;
        timer.cancel();
        if (completer.isCompleted) return;
        completer.completeError(NfcSessionCancelledException());
      },
    );

    return completer.future;
  }

  /// Stops any active NFC session and continuous read loop.
  Future<void> stopReading() async {
    dev.log('stopReading called, _sessionActive=$_sessionActive', name: 'NfcService');
    _continuousActive = false;
    if (!_sessionActive) return;
    _sessionActive = false;
    try {
      await NfcManager.instance.stopSession();
    } catch (_) {}
  }

  /// Continuously reads NFC tags, yielding each UID as a normalized hex string.
  /// On iOS, each read creates a new NFC session (system sheet appears briefly).
  /// On Android, the session stays active naturally.
  /// Cancel by calling [stopReading] or closing the stream subscription.
  Stream<String> continuousRead() async* {
    _continuousActive = true;
    try {
      while (_continuousActive) {
        try {
          final tagId = await readTagId();
          if (!_continuousActive) return;
          yield tagId;
        } on NfcSessionCancelledException {
          yield* Stream<String>.error(NfcSessionCancelledException());
          return; // user dismissed iOS sheet — stop continuous
        } on NfcReadTimeoutException {
          if (!_continuousActive) return;
          continue; // timeout — retry automatically
        } catch (e) {
          dev.log('continuousRead error: $e', name: 'NfcService');
          if (!_continuousActive) return;
          continue;
        }
      }
    } finally {
      _continuousActive = false;
    }
  }

  bool _continuousActive = false;

  /// Extracts the tag UID bytes from an NfcTag.
  Uint8List _extractUid(NfcTag tag) {
    if (Platform.isAndroid) {
      final android = NfcTagAndroid.from(tag);
      if (android != null) return android.id;
    } else if (Platform.isIOS) {
      final iso7816 = Iso7816Ios.from(tag);
      if (iso7816 != null) return iso7816.identifier;
      final mifare = MiFareIos.from(tag);
      if (mifare != null) return mifare.identifier;
    }
    throw Exception('Unsupported NFC tag technology — could not extract UID');
  }

  /// Converts raw bytes to a hex string (lowercase, no separators).
  String _bytesToHex(Uint8List bytes) {
    return bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
  }
}
