import 'dart:developer' as dev;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/strings.dart';
import '../providers/server_provider.dart';
import '../widgets/connection_indicator.dart';

/// HTTP timeout for backup/restore operations.
const _httpTimeout = Duration(seconds: 30);

/// Maximum download size for backup (100 MB) — matches server-side cap.
const _maxBackupBytes = 100 * 1024 * 1024;

/// Settings screen showing server info and data management (backup/restore).
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _backingUp = false;
  bool _restoring = false;

  /// True while any data operation is in progress — disables both buttons.
  bool get _busy => _backingUp || _restoring;

  // -------------------------------------------------------------------------
  // Backup
  // -------------------------------------------------------------------------

  Future<void> _onBackup() async {
    final port = context.read<ServerProvider>().port;
    setState(() => _backingUp = true);
    try {
      final bytes = await _downloadBackup(port);
      if (Platform.isAndroid) {
        const ch = MethodChannel('com.winetap.mobile/file_io');
        final saved = await ch.invokeMethod<bool>('saveFile', {
          'bytes': Uint8List.fromList(bytes),
          'name': 'winetap.db',
        });
        if (!mounted) return;
        if (saved == true) _showSnackBar(S.backupSuccess);
      } else {
        // iOS: write to temp then share via system share sheet.
        final tmp = await getTemporaryDirectory();
        final file = File('${tmp.path}/winetap.db');
        await file.writeAsBytes(bytes);
        final result = await Share.shareXFiles([XFile(file.path)]);
        if (!mounted) return;
        if (result.status == ShareResultStatus.success) {
          _showSnackBar(S.backupSuccess);
        }
      }
    } on PlatformException catch (e) {
      dev.log('backup error: $e', name: 'settings');
      if (mounted) _showSnackBar(S.backupError);
    } catch (e) {
      dev.log('backup error: $e', name: 'settings');
      if (mounted) _showSnackBar(S.backupError);
    } finally {
      if (mounted) setState(() => _backingUp = false);
    }
  }

  // -------------------------------------------------------------------------
  // Restore
  // -------------------------------------------------------------------------

  Future<void> _onRestore() async {
    // Step 1: confirmation dialog.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(S.restoreConfirmTitle),
        content: const Text(S.restoreConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(S.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(S.restoreDatabase),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    // Step 2: pick .db file.
    final Uint8List? fileBytes;
    try {
      if (Platform.isAndroid) {
        // Android: use platform channel to avoid content URI issues.
        const ch = MethodChannel('com.winetap.mobile/file_io');
        final result = await ch.invokeMethod<Uint8List>('pickFileBytes');
        if (result == null || !mounted) return;
        fileBytes = result;
      } else {
        // iOS: use file_picker.
        final result = await FilePicker.platform.pickFiles(withData: true);
        if (result == null || !mounted) return;
        fileBytes = result.files.single.bytes;
        if (fileBytes == null) {
          if (mounted) _showSnackBar(S.restoreError);
          return;
        }
      }
    } on PlatformException catch (e) {
      dev.log('File picker error: $e', name: 'settings');
      if (mounted) _showSnackBar(S.restoreError);
      return;
    }

    // Step 3: POST to /restore.
    // Re-check mounted immediately before reading context after async gaps.
    if (!mounted) return;
    final port = context.read<ServerProvider>().port;
    setState(() => _restoring = true);
    try {
      await _uploadRestore(port, fileBytes);
      if (mounted) _showSnackBar(S.restoreSuccess);
    } catch (e) {
      dev.log('restore error: $e', name: 'settings');
      if (mounted) _showSnackBar(S.restoreError);
    } finally {
      if (mounted) setState(() => _restoring = false);
    }
  }

  // -------------------------------------------------------------------------
  // HTTP helpers
  // -------------------------------------------------------------------------

  Future<List<int>> _downloadBackup(int port) async {
    final client = HttpClient()
      ..connectionTimeout = _httpTimeout
      ..idleTimeout = _httpTimeout;
    try {
      final request =
          await client.getUrl(Uri.parse('http://localhost:$port/backup'));
      final response = await request.close().timeout(_httpTimeout);
      if (response.statusCode != 200) {
        await response.drain<void>();
        throw HttpException('Backup failed: ${response.statusCode}');
      }
      var totalBytes = 0;
      final bytes = <int>[];
      await for (final chunk in response) {
        totalBytes += chunk.length;
        if (totalBytes > _maxBackupBytes) {
          throw const HttpException('Backup response exceeds 100 MB');
        }
        bytes.addAll(chunk);
      }
      return bytes;
    } finally {
      client.close();
    }
  }

  Future<void> _uploadRestore(int port, List<int> bytes) async {
    final client = HttpClient()
      ..connectionTimeout = _httpTimeout
      ..idleTimeout = _httpTimeout;
    try {
      final request =
          await client.postUrl(Uri.parse('http://localhost:$port/restore'));
      request.headers.contentType =
          ContentType('application', 'octet-stream');
      request.contentLength = bytes.length;
      request.add(bytes);
      final response = await request.close().timeout(_httpTimeout);
      if (response.statusCode != 200) {
        await response.drain<void>();
        throw HttpException('Restore failed: ${response.statusCode}');
      }
      // Drain successful response body before closing.
      await response.drain<void>();
    } finally {
      client.close();
    }
  }

  // -------------------------------------------------------------------------
  // UI helpers
  // -------------------------------------------------------------------------

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(S.settings),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: ServerIndicator(),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Consumer<ServerProvider>(
          builder: (context, server, _) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- Server info ---
                Text(
                  S.serverAddress,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.wifi, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      server.serverAddress,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  S.serverRunning,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),

                const SizedBox(height: 32),
                const Divider(),
                const SizedBox(height: 16),

                // --- Data management ---
                Text(
                  S.dataManagement,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _busy ? null : _onBackup,
                    icon: _backingUp
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.download),
                    label: const Text(S.exportDatabase),
                  ),
                ),
                const SizedBox(height: 12),

                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _onRestore,
                    icon: _restoring
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.upload),
                    label: const Text(S.restoreDatabase),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
