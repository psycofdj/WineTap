import 'dart:async';
import 'dart:developer' as dev;

import 'package:flutter/foundation.dart';

import '../l10n/strings.dart';
import '../server/scan_coordinator.dart';
import '../services/nfc_exceptions.dart';
import '../services/nfc_service.dart';
import 'scan_provider.dart';

/// States for the simplified intake listener flow.
/// idle → waitingForRequest → scanning (auto) → tagSent → waitingForRequest
enum IntakeState {
  idle,
  waitingForRequest,
  scanning,
  tagSent,
  error,
}

/// Manages the intake listener: polls ScanCoordinator for scan requests,
/// auto-starts NFC scanning (no user interaction), and tracks scan state.
/// Each scan request is a single read — the manager loops for bulk intake.
class IntakeProvider extends ChangeNotifier {
  final ScanCoordinator _coordinator;
  final NfcService _nfcService;
  final ScanProvider? _scanProvider;

  IntakeProvider(ScanCoordinator coordinator,
      {NfcService? nfcService, ScanProvider? scanProvider})
      : _coordinator = coordinator,
        _nfcService = nfcService ?? NfcService(),
        _scanProvider = scanProvider;

  IntakeState _state = IntakeState.idle;
  String? _errorMessage;
  String? _lastTagId;
  bool _disposed = false;
  bool _hadActiveRequest = false;
  Timer? _resetTimer;
  Timer? _pollTimer;

  IntakeState get state => _state;
  String? get errorMessage => _errorMessage;
  String? get lastTagId => _lastTagId;

  /// Whether the HomeScreen should switch to the intake tab.
  bool get shouldShowIntakeScreen =>
      _state != IntakeState.idle && _state != IntakeState.waitingForRequest;

  /// Start polling ScanCoordinator for scan requests.
  void startListening() {
    _setState(IntakeState.waitingForRequest);
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(
      const Duration(milliseconds: 500),
      (_) => _onPollTick(),
    );
  }

  /// Stop polling.
  void stopListening() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _nfcService.stopReading();
    _resetTimer?.cancel();
    _hadActiveRequest = false;
    _setState(IntakeState.idle);
  }

  void _onPollTick() {
    if (_disposed) return;
    final pending = _coordinator.hasPendingRequest;

    if (pending &&
        (_state == IntakeState.waitingForRequest ||
            _state == IntakeState.idle)) {
      _hadActiveRequest = true;
      // Interrupt active consume if any (FR19b)
      _scanProvider?.cancelForIntake();
      // Auto-start NFC scan immediately — no user interaction (FR12)
      _setState(IntakeState.scanning);
      _singleRead();
    } else if (!pending && _hadActiveRequest) {
      // Manager cancelled or scan completed and reset
      _hadActiveRequest = false;
      _nfcService.stopReading();
      if (_state != IntakeState.waitingForRequest &&
          _state != IntakeState.error) {
        _setState(IntakeState.waitingForRequest);
      }
    }
  }

  /// Cancels an active NFC scan and returns to waitingForRequest.
  Future<void> cancelScan() async {
    await _nfcService.stopReading();
    _setState(IntakeState.waitingForRequest);
  }

  Future<void> _singleRead() async {
    String tagId;
    try {
      tagId = await _nfcService.readTagId();
    } on NfcSessionCancelledException {
      _showBriefError(S.scanCancelledRetry);
      return;
    } on NfcReadTimeoutException {
      _showBriefError(S.noTagDetectedWithHint);
      return;
    } catch (e) {
      dev.log('Intake NFC error: $e', name: 'IntakeProvider');
      _showBriefError(S.noTagDetectedWithHint);
      return;
    }

    _sendTag(tagId);
  }

  void _sendTag(String tagId) {
    _lastTagId = tagId;
    dev.log('Intake tag scanned: $tagId', name: 'IntakeProvider');
    if (!_coordinator.hasPendingRequest) {
      dev.log('Intake: coordinator no longer pending, tag dropped',
          name: 'IntakeProvider');
      _setState(IntakeState.waitingForRequest);
      return;
    }
    _coordinator.submitResult(tagId);
    _setState(IntakeState.tagSent);

    // Return to waitingForRequest after brief feedback
    _resetTimer?.cancel();
    _resetTimer = Timer(const Duration(seconds: 1), () {
      if (!_disposed && _state == IntakeState.tagSent) {
        _setState(IntakeState.waitingForRequest);
      }
    });
  }

  void _showBriefError(String message) {
    _errorMessage = message;
    _setState(IntakeState.error);
    _resetTimer?.cancel();
    _resetTimer = Timer(const Duration(seconds: 2), () {
      if (!_disposed && _state == IntakeState.error) {
        _errorMessage = null;
        // Only re-enter scanning if coordinator still has a pending request
        if (_coordinator.hasPendingRequest) {
          _setState(IntakeState.scanning);
          _singleRead();
        } else {
          _setState(IntakeState.waitingForRequest);
        }
      }
    });
  }

  void _setState(IntakeState newState) {
    if (_disposed) return;
    _state = newState;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _pollTimer?.cancel();
    _nfcService.stopReading();
    _resetTimer?.cancel();
    super.dispose();
  }
}
