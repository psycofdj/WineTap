import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../l10n/strings.dart';
import '../providers/scan_provider.dart';
import '../widgets/bottle_details_card.dart';
import '../widgets/connection_indicator.dart';
import 'identify_screen.dart';
import 'settings_screen.dart';

/// Main consume flow screen: tap "Consommer une bouteille" → scan → consumed → "Terminé".
class ConsumeScreen extends StatelessWidget {
  const ConsumeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: FutureBuilder<PackageInfo>(
          future: PackageInfo.fromPlatform(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Text(S.appTitle);
            final info = snapshot.data!;
            return Text('${S.appTitle} (${info.version}+${info.buildNumber})');
          },
        ),
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
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.opaque,
        child: const _ConsumeBody(),
      ),
    );
  }
}

class _ConsumeBody extends StatefulWidget {
  const _ConsumeBody();

  @override
  State<_ConsumeBody> createState() => _ConsumeBodyState();
}

class _ConsumeBodyState extends State<_ConsumeBody> {
  bool _showComment = false;
  final _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _resetCommentState() {
    _showComment = false;
    _commentController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final scan = context.watch<ScanProvider>();

    // Reset comment UI when leaving consumed state.
    if (scan.state != ScanState.consumed && _showComment) {
      _resetCommentState();
    }

    final child = switch (scan.state) {
      ScanState.idle => _buildIdle(context),
      ScanState.scanning => _buildScanning(context),
      ScanState.consumed => _buildConsumed(context, scan),
      ScanState.error => _buildError(context, scan),
    };

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(child: child),
    );
  }

  Widget _buildIdle(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FilledButton.icon(
          onPressed: () => context.read<ScanProvider>().startScan(),
          icon: const Icon(Icons.nfc),
          label: const Text(S.consumeButton),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => const IdentifyScreen(),
            ),
          ),
          icon: const Icon(Icons.search),
          label: const Text(S.identifyButton),
        ),
      ],
    );
  }

  Widget _buildScanning(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CircularProgressIndicator(),
        const SizedBox(height: 16),
        const Text(S.waitingForScan),
        const SizedBox(height: 24),
        OutlinedButton(
          onPressed: () => context.read<ScanProvider>().cancel(),
          child: const Text(S.cancel),
        ),
      ],
    );
  }

  Widget _buildConsumed(BuildContext context, ScanProvider scan) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.check_circle,
          size: 64,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 16),
        Text(
          S.markedAsConsumed,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),
        if (scan.bottle != null) BottleDetailsCard(bottle: scan.bottle!),
        const SizedBox(height: 24),
        if (_showComment) ...[
          TextField(
            controller: _commentController,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: S.addComment,
            ),
            maxLines: 3,
            textInputAction: TextInputAction.done,
            autofocus: true,
          ),
          const SizedBox(height: 16),
        ],
        if (!_showComment)
          OutlinedButton.icon(
            onPressed: () => setState(() => _showComment = true),
            icon: const Icon(Icons.comment),
            label: const Text(S.addComment),
          ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: () {
            if (_showComment && _commentController.text.trim().isNotEmpty) {
              context
                  .read<ScanProvider>()
                  .resetWithComment(_commentController.text);
            } else {
              context.read<ScanProvider>().reset();
            }
            _resetCommentState();
          },
          child: const Text(S.done),
        ),
      ],
    );
  }

  Widget _buildError(BuildContext context, ScanProvider scan) {
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
          scan.errorMessage ?? S.unknownTag,
          style: Theme.of(context).textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: () => context.read<ScanProvider>().reset(),
          child: const Text(S.done),
        ),
      ],
    );
  }
}
