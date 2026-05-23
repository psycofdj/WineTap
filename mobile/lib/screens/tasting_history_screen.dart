import 'dart:developer' as dev;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/strings.dart';
import '../server/database.dart';
import 'tasting_detail_screen.dart';

const _pageSize = 20;
const _loadMoreThreshold = 400.0;

/// Paginated list of consumed bottles, newest first.
class TastingHistoryScreen extends StatefulWidget {
  const TastingHistoryScreen({super.key});

  @override
  State<TastingHistoryScreen> createState() => _TastingHistoryScreenState();
}

class _TastingHistoryScreenState extends State<TastingHistoryScreen> {
  final ScrollController _scrollController = ScrollController();
  final List<BottleWithCuvee> _items = [];
  bool _loading = false;
  bool _hasMore = true;
  bool _opening = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadMore();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_hasMore || _loading) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - _loadMoreThreshold) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    // Set flag synchronously so re-entrant calls (initState + scroll listener
    // firing in the same frame) cannot both pass the guard before setState.
    _loading = true;
    final gen = _generation;
    setState(() {});
    try {
      final page = await context.read<AppDatabase>().listConsumedBottles(
        limit: _pageSize,
        offset: _items.length,
      );
      if (!mounted || gen != _generation) return;
      setState(() {
        _items.addAll(page);
        _hasMore = page.length == _pageSize;
        _loading = false;
      });
    } catch (e) {
      dev.log('listConsumedBottles failed: $e', name: 'TastingHistoryScreen');
      if (!mounted || gen != _generation) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text(S.databaseError)));
    }
  }

  Future<void> _refresh() async {
    // Bump generation so any in-flight _loadMore discards its result.
    _generation++;
    _items.clear();
    _hasMore = true;
    _loading = false;
    await _loadMore();
  }

  Future<void> _openDetail(BottleWithCuvee bottle) async {
    if (_opening) return;
    _opening = true;
    try {
      final changed = await Navigator.push<bool>(
        context,
        MaterialPageRoute<bool>(
          builder: (_) => TastingDetailScreen(bottle: bottle),
        ),
      );
      if (changed == true && mounted) {
        await _refresh();
      }
    } finally {
      if (mounted) _opening = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(S.tastingHistoryTitle)),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_items.isEmpty && _loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_items.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(S.noTastings, textAlign: TextAlign.center),
        ),
      );
    }
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _items.length + 1,
      itemBuilder: (context, index) {
        if (index == _items.length) {
          if (_loading && _hasMore) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return const SizedBox.shrink();
        }
        final bottle = _items[index];
        return _ConsumedBottleCard(
          bottle: bottle,
          onTap: () => _openDetail(bottle),
        );
      },
    );
  }
}

class _ConsumedBottleCard extends StatelessWidget {
  const _ConsumedBottleCard({required this.bottle, required this.onTap});

  final BottleWithCuvee bottle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final consumed = _formatConsumedAt(bottle.bottle.consumedAt);
    final hasDesignation = bottle.designationName.isNotEmpty;
    final title = hasDesignation ? bottle.designationName : bottle.cuvee.name;
    final subtitle = hasDesignation
        ? '${bottle.cuvee.name} · ${bottle.bottle.vintage}'
        : bottle.bottle.vintage.toString();
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                bottle.domainName,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 6),
              Text(subtitle, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 8),
              Text(
                '${S.labelConsumedAt} $consumed',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatConsumedAt(String? iso) {
  if (iso == null || iso.isEmpty) return '';
  try {
    final dt = DateTime.parse(iso).toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(dt.day)}/${two(dt.month)}/${dt.year} '
        '${two(dt.hour)}:${two(dt.minute)}';
  } catch (_) {
    return iso;
  }
}
