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

/// Displays bottle details: domain, cuvee name, vintage, appellation, color.
class BottleDetailsCard extends StatelessWidget {
  const BottleDetailsCard({super.key, required this.bottle});

  final BottleWithCuvee bottle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _colorLabel(bottle.cuvee.color);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              bottle.domainName,
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              '${bottle.cuvee.name} ${bottle.bottle.vintage}',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              bottle.designationName,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (color != null) ...[
              const SizedBox(height: 4),
              Text(
                color,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
