import 'dart:developer' as dev;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/strings.dart';
import '../server/database.dart';
import '../services/nfc_exceptions.dart';
import '../services/nfc_service.dart';
import '../widgets/bottle_details_card.dart';

/// Scan a tag to identify a bottle without consuming it.
class IdentifyScreen extends StatefulWidget {
  const IdentifyScreen({super.key, this.nfcService});

  /// Optional NFC service for testing. Uses the Provider tree by default.
  final NfcService? nfcService;

  @override
  State<IdentifyScreen> createState() => _IdentifyScreenState();
}

enum _IdentifyState { scanning, found, error }

class _IdentifyScreenState extends State<IdentifyScreen> {
  late final NfcService _nfc =
      widget.nfcService ?? context.read<NfcService>();
  _IdentifyState _state = _IdentifyState.scanning;
  BottleWithCuvee? _bottle;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _scan();
  }

  @override
  void dispose() {
    _nfc.stopReading();
    super.dispose();
  }

  Future<void> _scan() async {
    setState(() {
      _state = _IdentifyState.scanning;
      _bottle = null;
      _errorMessage = null;
    });

    String uid;
    try {
      uid = await _nfc.readTagId();
    } on NfcSessionCancelledException {
      if (mounted) Navigator.pop(context);
      return;
    } on NfcReadTimeoutException {
      _setError(S.noTagDetectedWithHint);
      return;
    } catch (e) {
      dev.log('NFC scan error: $e', name: 'IdentifyScreen');
      _setError(S.noTagDetectedWithHint);
      return;
    }

    dev.log('Identify tag scanned: $uid', name: 'IdentifyScreen');

    if (!mounted) return;
    final db = context.read<AppDatabase>();
    BottleWithCuvee? bottle;
    try {
      bottle = await db.getBottleByTagId(uid);
    } catch (e) {
      dev.log('getBottleByTagId unexpected: $e', name: 'IdentifyScreen');
      _setError(S.databaseError);
      return;
    }

    if (bottle == null) {
      _setError(S.unknownTag);
      return;
    }

    if (!mounted) return;
    setState(() {
      _bottle = bottle;
      _state = _IdentifyState.found;
    });
  }

  void _setError(String message) {
    if (!mounted) return;
    setState(() {
      _errorMessage = message;
      _state = _IdentifyState.error;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(S.identifyButton)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: switch (_state) {
            _IdentifyState.scanning => _buildScanning(),
            _IdentifyState.found => _buildFound(),
            _IdentifyState.error => _buildError(),
          },
        ),
      ),
    );
  }

  Widget _buildScanning() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CircularProgressIndicator(),
        const SizedBox(height: 16),
        const Text(S.waitingForScan),
        const SizedBox(height: 24),
        OutlinedButton(
          onPressed: () {
            _nfc.stopReading();
            Navigator.pop(context);
          },
          child: const Text(S.cancel),
        ),
      ],
    );
  }

  Widget _buildFound() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.info_outline,
          size: 64,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 16),
        if (_bottle != null) BottleDetailsCard(bottle: _bottle!),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(S.done),
        ),
      ],
    );
  }

  Widget _buildError() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.error_outline,
          size: 48,
          color: Theme.of(context).colorScheme.error,
        ),
        const SizedBox(height: 16),
        Text(
          _errorMessage ?? S.unknownTag,
          style: Theme.of(context).textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(S.done),
        ),
      ],
    );
  }
}
