import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../server/database.dart';

/// Maps cuvee color int to display label.
String? _colorLabel(int color) {
  switch (color) {
    case 1:
      return S.colorRouge;
    case 2:
      return S.colorBlanc;
    case 3:
      return S.colorRose;
    case 4:
      return S.colorEffervescent;
    case 5:
      return S.colorAutre;
    default:
      return null;
  }
}

/// Displays bottle details in a "label : value" table layout.
class BottleDetailsCard extends StatelessWidget {
  const BottleDetailsCard({super.key, required this.bottle});

  final BottleWithCuvee bottle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _colorLabel(bottle.cuvee.color);
    final drinkBefore = bottle.bottle.drinkBefore;
    final description = bottle.bottle.description;

    final rows = <(String, String)>[
      (S.labelCuvee, bottle.cuvee.name),
      (S.labelMillesime, bottle.bottle.vintage.toString()),
      if (color != null) (S.labelColor, color),
      (S.labelDomain, bottle.domainName),
      (S.labelDesignation, bottle.designationName),
      (S.labelRegion, bottle.region),
      if (drinkBefore != null) (S.labelDrinkBefore, drinkBefore.toString()),
      if (description.isNotEmpty) (S.labelDescription, description),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Table(
          columnWidths: const {
            0: IntrinsicColumnWidth(),
            1: FlexColumnWidth(),
          },
          defaultVerticalAlignment: TableCellVerticalAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            for (final (label, value) in rows)
              TableRow(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 12, bottom: 6),
                    child: Text(
                      label,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      value,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
