import 'dart:developer' as dev;

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import '../l10n/strings.dart';
import '../server/consume_tracker.dart';
import '../server/database.dart';
import '../services/nfc_service.dart';

/// States for the simplified consume scan flow.
/// idle → scanning → consumed | error → (user taps "Terminé") → idle
enum ScanState { idle, scanning, consumed, error }

/// Manages the NFC scan -> auto-consume flow via drift directly.
/// No confirmation step: tag read = bottle consumed immediately.
class ScanProvider extends ChangeNotifier {
  final NfcService _nfcService;
  final AppDatabase _db;
  final ConsumeTracker _consumeTracker;

  ScanState _state = ScanState.idle;
  String? _tagId;
  BottleWithCuvee? _bottle;
  String? _errorMessage;
  bool _disposed = false;
  String? _lastScannedTagId;

  ScanProvider(AppDatabase db, ConsumeTracker consumeTracker,
      {required NfcService nfcService})
      : _db = db,
        _consumeTracker = consumeTracker,
        _nfcService = nfcService;

  ScanState get state => _state;
  String? get tagId => _tagId;
  BottleWithCuvee? get bottle => _bottle;
  String? get errorMessage => _errorMessage;

  /// Initiates NFC scan, looks up bottle, and consumes immediately on success.
  Future<void> startScan() async {
    if (_state != ScanState.idle) return;
    _setState(ScanState.scanning);
    _tagId = null;
    _bottle = null;
    _errorMessage = null;

    // 1. Read NFC tag
    final result = await _nfcService.readTag();
    if (result.tag == null) {
      if (result.error == 'cancelled') {
        _setState(ScanState.idle);
      } else {
        _setError(S.noTagDetectedWithHint);
      }
      return;
    }
    final uid = result.tag!;

    // Duplicate suppression (FR5): ignore if same tag just scanned
    if (uid == _lastScannedTagId) {
      dev.log('Duplicate tag ignored: $uid', name: 'ScanProvider');
      _setState(ScanState.idle);
      return;
    }
    _lastScannedTagId = uid;
    _tagId = uid;
    dev.log('Tag scanned: $uid', name: 'ScanProvider');

    // 2. Look up bottle by tag ID — drift direct
    BottleWithCuvee? bottle;
    try {
      bottle = await _db.getBottleByTagId(uid);
    } catch (e) {
      dev.log('getBottleByTagId unexpected: $e', name: 'ScanProvider');
      _setError(S.databaseError);
      return;
    }

    if (bottle == null) {
      _setError(S.unknownTag);
      return;
    }

    // 3. Consume immediately — no confirmation step (FR7)
    try {
      await _db.consumeBottle(uid);
      _consumeTracker.touch();
      _bottle = bottle;
      _setState(ScanState.consumed);
      dev.log('Bottle consumed: tag=$uid', name: 'ScanProvider');
    } on StateError {
      _setError(S.alreadyConsumed);
    } catch (e) {
      dev.log('ConsumeBottle unexpected: $e', name: 'ScanProvider');
      _setError(S.databaseError);
    }
  }

  /// Cancels the current NFC scan session and returns to idle.
  void cancel() {
    if (_state != ScanState.scanning) return;
    // NfcService state machine handles cleanup internally.
    _setState(ScanState.idle);
    _tagId = null;
    _bottle = null;
    _errorMessage = null;
    _lastScannedTagId = null;
  }

  /// Interrupts the consume flow for an incoming intake request (FR19b).
  /// Cancels NFC if scanning, resets UI state to idle.
  /// Does NOT undo a completed consume — once consumeBottle() ran, it's final.
  void cancelForIntake() {
    if (_state == ScanState.idle) return;
    if (_state == ScanState.scanning) {
      // NfcService state machine handles cleanup internally.
    }
    _tagId = null;
    _bottle = null;
    _errorMessage = null;
    _lastScannedTagId = null;
    _setState(ScanState.idle);
  }

  /// Resets to idle from consumed or error state (user taps "Terminé").
  void reset() {
    // NfcService state machine handles cleanup internally.
    _tagId = null;
    _bottle = null;
    _errorMessage = null;
    _lastScannedTagId = null;
    _setState(ScanState.idle);
  }

  /// Updates the bottle description with a comment, then resets to idle.
  Future<void> resetWithComment(String comment) async {
    if (_bottle != null && comment.trim().isNotEmpty) {
      final id = _bottle!.bottle.id;
      await _db.updateBottleFields(
        id,
        BottlesCompanion(description: Value(comment.trim())),
      );
      dev.log('Bottle $id description updated', name: 'ScanProvider');
    }
    reset();
  }

  @override
  void dispose() {
    _disposed = true;
    // NfcService state machine handles cleanup internally.
    super.dispose();
  }

  void _setState(ScanState newState) {
    if (_disposed) return;
    _state = newState;
    notifyListeners();
  }

  void _setError(String message) {
    _errorMessage = message;
    _setState(ScanState.error);
  }
}
