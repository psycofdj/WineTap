import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/strings.dart';
import '../providers/intake_provider.dart';
import '../widgets/connection_indicator.dart';
import 'settings_screen.dart';

/// Intake listener screen — fully passive, no user interaction required.
/// Screen auto-shows when manager requests scan, auto-hides when done.
class IntakeScreen extends StatefulWidget {
  const IntakeScreen({super.key});

  @override
  State<IntakeScreen> createState() => _IntakeScreenState();
}

class _IntakeScreenState extends State<IntakeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<IntakeProvider>().startListening();
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(S.intake),
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
      body: const _IntakeBody(),
    );
  }
}

class _IntakeBody extends StatelessWidget {
  const _IntakeBody();

  @override
  Widget build(BuildContext context) {
    final intake = context.watch<IntakeProvider>();

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: switch (intake.state) {
          IntakeState.idle => _buildIdle(context),
          IntakeState.waitingForRequest => _buildWaiting(),
          IntakeState.scanning => _buildScanning(context, intake),
          IntakeState.tagSent => _buildTagSent(intake),
          IntakeState.error => _buildError(context, intake),
        },
      ),
    );
  }

  Widget _buildIdle(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.inventory_2_outlined,
          size: 48,
          color: Theme.of(context).colorScheme.outline,
        ),
        const SizedBox(height: 16),
        const Text(
          S.intakeUnavailable,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildWaiting() {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.hearing, size: 48, color: Colors.grey),
        SizedBox(height: 16),
        Text(S.waitingForRequest,
            style: TextStyle(fontSize: 18, color: Colors.grey)),
      ],
    );
  }

  Widget _buildScanning(BuildContext context, IntakeProvider intake) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CircularProgressIndicator(),
        const SizedBox(height: 16),
        Text(
          S.intakeInProgress,
          style: Theme.of(context).textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildTagSent(IntakeProvider intake) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.check_circle, size: 64, color: Colors.green),
        const SizedBox(height: 16),
        const Text(S.tagSentSuccess,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        if (intake.lastTagId != null) ...[
          const SizedBox(height: 8),
          SelectableText(
            intake.lastTagId!,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 16),
          ),
        ],
      ],
    );
  }

  Widget _buildError(BuildContext context, IntakeProvider intake) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.error_outline, size: 48,
            color: Theme.of(context).colorScheme.error),
        const SizedBox(height: 16),
        Text(
          intake.errorMessage ?? S.noTagDetected,
          style: Theme.of(context).textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
