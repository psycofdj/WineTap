import 'dart:developer' as dev;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/strings.dart';
import '../server/database.dart';
import '../widgets/bottle_details_card.dart';

/// Detail screen for a consumed bottle: shows summary + editable comment.
class TastingDetailScreen extends StatefulWidget {
  const TastingDetailScreen({super.key, required this.bottle});

  final BottleWithCuvee bottle;

  @override
  State<TastingDetailScreen> createState() => _TastingDetailScreenState();
}

class _TastingDetailScreenState extends State<TastingDetailScreen> {
  late final TextEditingController _controller;
  late final String _initialTrimmed;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _initialTrimmed = widget.bottle.bottle.description.trim();
    _controller =
        TextEditingController(text: widget.bottle.bottle.description);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _isDirty(String text) => text.trim() != _initialTrimmed;

  Future<void> _save() async {
    final trimmed = _controller.text.trim();
    if (trimmed == _initialTrimmed || _saving) return;
    setState(() => _saving = true);
    try {
      await context.read<AppDatabase>().updateBottleFields(
            widget.bottle.bottle.id,
            BottlesCompanion(description: Value(trimmed)),
          );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      dev.log('updateBottleFields failed: $e', name: 'TastingDetailScreen');
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(S.databaseError)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(S.tastingHistoryTitle)),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.opaque,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BottleDetailsCard(bottle: widget.bottle),
              const SizedBox(height: 16),
              TextField(
                controller: _controller,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: S.commentHint,
                ),
                maxLines: 5,
                minLines: 3,
                textInputAction: TextInputAction.newline,
              ),
              const SizedBox(height: 16),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _controller,
                builder: (context, value, _) {
                  final enabled = _isDirty(value.text) && !_saving;
                  return FilledButton(
                    onPressed: enabled ? _save : null,
                    child: _saving
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text(S.save),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
