import 'dart:developer' as dev;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/strings.dart';
import '../server/database.dart';
import 'bottle_details_card.dart';

/// Home-screen panel: total in-stock count + two pie charts (by color, by region).
///
/// Fetches [StockStats] on mount and whenever the parent bumps [revision],
/// which the parent does each time the user returns to the idle state.
class StockStatsPanel extends StatefulWidget {
  const StockStatsPanel({super.key, required this.revision});

  final int revision;

  @override
  State<StockStatsPanel> createState() => _StockStatsPanelState();
}

class _StockStatsPanelState extends State<StockStatsPanel> {
  StockStats? _stats;
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(StockStatsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.revision != widget.revision) _load();
  }

  Future<void> _load() async {
    // Keep the previous chart visible during the refresh (no spinner flicker)
    // but always surface fresh errors per the spec.
    if (_stats == null) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final s = await context.read<AppDatabase>().getStockStats();
      if (!mounted) return;
      setState(() {
        _stats = s;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      dev.log('getStockStats failed: $e', name: 'StockStatsPanel');
      if (!mounted) return;
      setState(() {
        _error = e;
        _stats = null;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return const Text(S.databaseError, textAlign: TextAlign.center);
    }
    if (_loading && _stats == null) {
      return const SizedBox(
        height: 80,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final s = _stats!;
    if (s.totalInStock == 0) {
      return const Padding(
        padding: EdgeInsets.all(8),
        child: Text(S.noBottlesInStock, textAlign: TextAlign.center),
      );
    }

    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(S.stockTitle, style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          '${s.totalInStock} ${S.bottlesInStock}',
          style: theme.textTheme.headlineSmall,
        ),
        const SizedBox(height: 24),
        _ChartSection(title: S.byColor, slices: _colorSlices(s.byColor)),
        const SizedBox(height: 24),
        _ChartSection(title: S.byRegion, slices: _regionSlices(s.byRegion)),
      ],
    );
  }

  List<_Slice> _colorSlices(Map<int, int> byColor) {
    final slices = byColor.entries.map((e) {
      final label = colorLabel(e.key) ?? S.statsInconnue;
      return _Slice(label, e.value, _colorTint(e.key));
    }).toList();
    _sortSlices(slices);
    return slices;
  }

  List<_Slice> _regionSlices(Map<String, int> byRegion) {
    // Assign palette colors deterministically by sorted region name so the
    // same region keeps the same color across refreshes.
    final keys = byRegion.keys.toList()..sort();
    const palette = _regionPalette;
    final slices = <_Slice>[
      for (var i = 0; i < keys.length; i++)
        _Slice(keys[i], byRegion[keys[i]]!, palette[i % palette.length]),
    ];
    _sortSlices(slices);
    return slices;
  }

  void _sortSlices(List<_Slice> slices) {
    slices.sort((a, b) {
      final c = b.count.compareTo(a.count);
      return c != 0 ? c : a.label.compareTo(b.label);
    });
  }

  // Mirror the palette used by the manager app — see
  // internal/manager/widget/aggregate.go (wineColorHex / regionPalette) so
  // the same wine looks the same color across the two surfaces.
  Color _colorTint(int color) {
    switch (color) {
      case 1:
        return const Color(0xFFC0392B); // Rouge
      case 2:
        return const Color(0xFFF1C40F); // Blanc
      case 3:
        return const Color(0xFFE8A0BF); // Rosé
      case 4:
        return const Color(0xFF3498DB); // Effervescent
      case 5:
        return const Color(0xFF95A5A6); // Autre
      default:
        return const Color(0xFF95A5A6); // Inconnue — same grey as Autre
    }
  }

  static const _regionPalette = <Color>[
    Color(0xFFE6194B),
    Color(0xFF3CB44B),
    Color(0xFF4363D8),
    Color(0xFFF58231),
    Color(0xFF911EB4),
    Color(0xFF42D4F4),
    Color(0xFFF032E6),
    Color(0xFFBFEF45),
    Color(0xFFFABED4),
    Color(0xFF469990),
    Color(0xFFDCBEFF),
    Color(0xFF9A6324),
    Color(0xFF800000),
    Color(0xFFAAFFC3),
    Color(0xFF808000),
    Color(0xFF000075),
    Color(0xFFA9A9A9),
  ];
}

class _Slice {
  final String label;
  final int count;
  final Color color;

  _Slice(this.label, this.count, this.color);
}

class _ChartSection extends StatelessWidget {
  const _ChartSection({required this.title, required this.slices});

  final String title;
  final List<_Slice> slices;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = slices.fold<int>(0, (a, b) => a + b.count);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        SizedBox(
          height: 200,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 32,
              sections: [
                for (final s in slices)
                  PieChartSectionData(
                    color: s.color,
                    value: s.count.toDouble(),
                    title: total > 0
                        ? '${(s.count * 100 / total).round()}%'
                        : '',
                    radius: 56,
                    titleStyle: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color:
                          ThemeData.estimateBrightnessForColor(s.color) ==
                              Brightness.dark
                          ? Colors.white
                          : Colors.black87,
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 4,
          alignment: WrapAlignment.center,
          children: [
            for (final s in slices)
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 220),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 12, height: 12, color: s.color),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        '${s.label} · ${s.count}',
                        style: theme.textTheme.bodySmall,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}
