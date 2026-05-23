import 'dart:developer' as dev;

import 'package:drift/drift.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'database.dart';

/// Reference instant used to derive deterministic `addedAt` / `consumedAt`
/// timestamps. Keeping this fixed means the seeded catalog is identical across
/// cold starts.
final DateTime _refInstant = DateTime.utc(2026, 5, 1);

/// Returns true when the running build is a dev build, i.e. the full version
/// string `'${version}+${buildNumber}'` contains the substring `+dev`.
/// Any failure to read package info is treated as non-dev.
Future<bool> isDevBuild() async {
  try {
    final info = await PackageInfo.fromPlatform();
    final full = '${info.version}+${info.buildNumber}';
    return full.contains('0.0.0');
  } catch (e) {
    dev.log('PackageInfo lookup failed: $e', name: 'DevSeed');
    return false;
  }
}

/// Seeds a realistic dev catalog into [db] when (a) this is a dev build and
/// (b) the `bottles` table is empty. Idempotent: a second call with bottles
/// already present is a no-op.
Future<void> seedDevDataIfNeeded(
  AppDatabase db, {
  Future<bool> Function()? isDev,
}) async {
  final gate = isDev ?? isDevBuild;
  if (!await gate()) {
    dev.log('skipped: not a dev build', name: 'DevSeed');
    return;
  }
  dev.log('seeding dev catalog', name: 'DevSeed');
  final result = await db.transaction(() async {
    // Re-check emptiness inside the transaction so a concurrent insert
    // (e.g. a re-entrant call during app resume) cannot lead to a double seed.
    final existing = await (db.select(db.bottles)..limit(1)).get();
    if (existing.isNotEmpty) {
      dev.log('skipped: bottles already present', name: 'DevSeed');
      return _SeedResult(0, 0, 0);
    }
    return _seed(db);
  });
  if (result.bottleCount == 0) return;
  dev.log('seeded ${result.bottleCount} bottles across ${result.cuveeCount} '
      'cuvées (${result.consumedCount} consumed)', name: 'DevSeed');
}

class _SeedResult {
  final int cuveeCount;
  final int bottleCount;
  final int consumedCount;
  _SeedResult(this.cuveeCount, this.bottleCount, this.consumedCount);
}

Future<_SeedResult> _seed(AppDatabase db) async {
  // Wine color encoding (must match BottleDetailsCard._colorLabel):
  //   1=Rouge, 2=Blanc, 3=Rosé, 4=Effervescent, 5=Autre.
  const catalog = <_DevCuvee>[
    // Rouge (1) — 6 cuvées
    _DevCuvee('Grand Vin', 'Château Margaux', 'Margaux', 1,
        bottles: 4, consumedFraction: 0.5,
        priceRange: (520, 780), drinkBefore: 2045),
    _DevCuvee('Pavillon Rouge', 'Château Margaux', 'Margaux', 1,
        bottles: 3, consumedFraction: 0.66,
        priceRange: (140, 200), drinkBefore: 2035),
    _DevCuvee('Carruades de Lafite', 'Château Lafite Rothschild', 'Pauillac', 1,
        bottles: 3, consumedFraction: 0.33,
        priceRange: (260, 340), drinkBefore: 2040),
    _DevCuvee('Romanée-Saint-Vivant', 'Domaine de la Romanée-Conti',
        'Vosne-Romanée', 1,
        bottles: 2, consumedFraction: 0.5,
        priceRange: (3800, 5200), drinkBefore: 2050),
    _DevCuvee('Hermitage', 'Domaine Jean-Louis Chave', 'Hermitage', 1,
        bottles: 4, consumedFraction: 0.5,
        priceRange: (320, 480), drinkBefore: 2042),
    _DevCuvee('Châteauneuf-du-Pape Hommage', 'Château de Beaucastel',
        'Châteauneuf-du-Pape', 1,
        bottles: 3, consumedFraction: 0.66,
        priceRange: (180, 240), drinkBefore: 2038),

    // Blanc (2) — 5 cuvées
    _DevCuvee('Meursault Perrières', 'Domaine Comtes Lafon', 'Meursault', 2,
        bottles: 3, consumedFraction: 0.66,
        priceRange: (380, 520), drinkBefore: 2032),
    _DevCuvee('Puligny-Montrachet Les Pucelles', 'Domaine Leflaive',
        'Chassagne-Montrachet', 2,
        bottles: 3, consumedFraction: 0.33,
        priceRange: (340, 460), drinkBefore: 2032),
    _DevCuvee('Sancerre Les Monts Damnés', 'Domaine Vacheron', 'Sancerre', 2,
        bottles: 4, consumedFraction: 0.5,
        priceRange: (32, 48), drinkBefore: 2028),
    _DevCuvee('Le Mont Sec', 'Domaine Huet', 'Vouvray', 2,
        bottles: 3, consumedFraction: 0.66,
        priceRange: (28, 42), drinkBefore: 2030),
    _DevCuvee('Riesling Clos Sainte-Hune', 'Domaine Trimbach', 'Alsace', 2,
        bottles: 2, consumedFraction: 0.5,
        priceRange: (220, 320), drinkBefore: 2040),

    // Rosé (3) — 3 cuvées
    _DevCuvee('Sancerre Rosé', 'Domaine Henri Bourgeois', 'Sancerre', 3,
        bottles: 4, consumedFraction: 0.75,
        priceRange: (22, 28), drinkBefore: 2027),
    _DevCuvee('Tavel Rosé', 'Domaine E. Guigal', 'Côte-Rôtie', 3,
        bottles: 3, consumedFraction: 0.66,
        priceRange: (18, 26), drinkBefore: 2026),
    _DevCuvee('Marsannay Rosé', 'Domaine Armand Rousseau', 'Gevrey-Chambertin',
        3,
        bottles: 2, consumedFraction: 0.5,
        priceRange: (32, 40), drinkBefore: 2027),

    // Effervescent (4) — 4 cuvées
    _DevCuvee('Grande Cuvée 172e Édition', 'Krug', 'Champagne', 4,
        bottles: 3, consumedFraction: 0.66,
        priceRange: (240, 320), drinkBefore: 2035),
    _DevCuvee('La Grande Année', 'Bollinger', 'Champagne', 4,
        bottles: 4, consumedFraction: 0.5,
        priceRange: (140, 200), drinkBefore: 2034),
    _DevCuvee('Cristal Brut', 'Louis Roederer', 'Champagne', 4,
        bottles: 3, consumedFraction: 0.33,
        priceRange: (240, 320), drinkBefore: 2035),
    _DevCuvee('Crémant d\'Alsace Brut', 'Domaine Zind-Humbrecht', 'Alsace', 4,
        bottles: 3, consumedFraction: 0.66,
        priceRange: (18, 24), drinkBefore: 2027),

    // Autre (5) — 2 cuvées (sweet / late-harvest)
    _DevCuvee('Sauternes', "Château d'Yquem", 'Sauternes', 5,
        bottles: 3, consumedFraction: 0.33,
        priceRange: (380, 560), drinkBefore: 2055),
    _DevCuvee('Vouvray Moelleux 1er Trie', 'Domaine Huet', 'Vouvray', 5,
        bottles: 3, consumedFraction: 0.66,
        priceRange: (45, 70), drinkBefore: 2040),
  ];

  const tastingNotes = <String>[
    'Bouche ample, finale longue sur les fruits noirs.',
    'Belle minéralité, attaque vive, à carafer 30 min.',
    'Sous-bois et truffe au nez, tanins fondus.',
    "Notes d'agrumes confits, équilibre remarquable.",
    'Très expressif, à boire dans les 2 ans.',
    'Bulle fine, brioche et noisette, élégant.',
    'Encore jeune — attendre 5 ans pour l\'apogée.',
    'Magnifique avec un gibier rôti.',
  ];

  var cuveeCount = 0;
  var bottleCount = 0;
  var consumedCount = 0;
  var bottleIndex = 0;

  for (final c in catalog) {
    final domainRow = await (db.select(db.domains)
          ..where((t) => t.name.equals(c.domainName)))
        .getSingleOrNull();
    final desRow = await (db.select(db.designations)
          ..where((t) => t.name.equals(c.designationName)))
        .getSingleOrNull();
    if (domainRow == null) {
      dev.log('domain not found, skipping cuvée "${c.name}": ${c.domainName}',
          name: 'DevSeed');
      continue;
    }
    if (desRow == null) {
      dev.log(
          'designation not found, skipping cuvée "${c.name}": ${c.designationName}',
          name: 'DevSeed');
      continue;
    }

    final cuveeId = await db.into(db.cuvees).insert(CuveesCompanion.insert(
          name: c.name,
          domainId: domainRow.id,
          designationId: Value(desRow.id),
          color: Value(c.color),
        ));
    cuveeCount++;

    for (var i = 0; i < c.bottles; i++) {
      // Vintage spread 2008..2022, deterministic per (cuvée, bottle).
      final vintage = 2008 + ((bottleIndex * 7 + i * 3) % 15);
      // Added 1..18 months before reference instant. Build in UTC so the
      // timestamp is identical regardless of host timezone.
      final addedMonthsBack = 1 + ((bottleIndex * 5 + i) % 18);
      final addedInstant = DateTime.utc(
        _refInstant.year,
        _refInstant.month - addedMonthsBack,
        12,
      );
      final addedAt = addedInstant.toIso8601String();

      // Consumed cadence: spread the "consumed" bottles among each cuvée's
      // first N. Use ceil so cuvées with consumedFraction>0 always have ≥1.
      final consumeQuota = (c.bottles * c.consumedFraction).ceil();
      final isConsumed = i < consumeQuota;
      String? consumedAt;
      if (isConsumed) {
        // Place consumption between addedInstant + 7 days and the reference
        // instant, deterministically and never before the bottle was added.
        final windowDays = _refInstant.difference(addedInstant).inDays - 7;
        final daysAfterAdd = windowDays <= 0
            ? 0
            : ((bottleIndex * 11 + i * 17) % windowDays);
        consumedAt = addedInstant
            .add(Duration(days: 7 + daysAfterAdd))
            .toIso8601String();
        consumedCount++;
      }

      final price = c.priceRange.$1 +
          ((bottleIndex * 13 + i * 5) %
              (c.priceRange.$2 - c.priceRange.$1 + 1));
      final hasDescription = (bottleIndex + i) % 3 == 0;
      final description = hasDescription
          ? tastingNotes[(bottleIndex + i) % tastingNotes.length]
          : '';

      await db.into(db.bottles).insert(BottlesCompanion.insert(
            cuveeId: cuveeId,
            vintage: vintage,
            addedAt: addedAt,
            tagId: const Value(null),
            description: Value(description),
            purchasePrice: Value(price.toDouble()),
            drinkBefore: Value(c.drinkBefore),
            consumedAt: Value(consumedAt),
          ));
      bottleCount++;
      bottleIndex++;
    }
  }

  return _SeedResult(cuveeCount, bottleCount, consumedCount);
}

class _DevCuvee {
  final String name;
  final String domainName;
  final String designationName;
  final int color;
  final int bottles;
  final double consumedFraction;
  final (int, int) priceRange;
  final int drinkBefore;

  const _DevCuvee(
    this.name,
    this.domainName,
    this.designationName,
    this.color, {
    required this.bottles,
    required this.consumedFraction,
    required this.priceRange,
    required this.drinkBefore,
  });
}
