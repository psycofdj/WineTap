import 'package:flutter/material.dart';

import '../services/nfc_exceptions.dart';
import '../services/nfc_service.dart';
import '../widgets/connection_indicator.dart' show ServerIndicator;
import 'settings_screen.dart';

/// Temporary NFC test screen for hardware validation.
/// Replaced by ConsumeScreen in Story 2.4.
class NfcTestScreen extends StatefulWidget {
  const NfcTestScreen({super.key});

  @override
  State<NfcTestScreen> createState() => _NfcTestScreenState();
}

class _NfcTestScreenState extends State<NfcTestScreen> {
  final _nfcService = NfcService();
  String _status = 'Appuyez sur Scanner';
  String _tagId = '';
  bool _scanning = false;

  @override
  void dispose() {
    _nfcService.stopReading();
    super.dispose();
  }

  Future<void> _scan() async {
    final available = await _nfcService.isAvailable();
    if (!available) {
      setState(() {
        _status = 'NFC non disponible sur cet appareil';
      });
      return;
    }
    setState(() {
      _status = 'Scan en cours…';
      _tagId = '';
      _scanning = true;
    });
    try {
      final uid = await _nfcService.readTagId();
      setState(() {
        _status = 'Tag lu !';
        _tagId = uid;
        _scanning = false;
      });
    } on NfcSessionCancelledException {
      setState(() {
        _status = 'Annulé';
        _scanning = false;
      });
    } on NfcReadTimeoutException {
      setState(() {
        _status = 'Aucun tag détecté';
        _scanning = false;
      });
    } catch (e) {
      setState(() {
        _status = 'Erreur: $e';
        _scanning = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('NFC Test'),
        actions: [
          const Padding(
            padding: EdgeInsets.only(right: 8),
            child: ServerIndicator(),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const SettingsScreen(),
              ),
            ),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _status,
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              if (_tagId.isNotEmpty)
                SelectableText(
                  _tagId,
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                      ),
                ),
              const SizedBox(height: 48),
              FilledButton.icon(
                onPressed: _scanning ? null : _scan,
                icon: const Icon(Icons.nfc),
                label: const Text('Scanner'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
