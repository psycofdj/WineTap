import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'seed_data.dart';

part 'database.g.dart';

// ---------------------------------------------------------------------------
// Table definitions
// ---------------------------------------------------------------------------

class Designations extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().unique()();
  TextColumn get region => text().withDefault(const Constant(''))();
  TextColumn get description => text().withDefault(const Constant(''))();
  BlobColumn get picture => blob().nullable()();
}

class Domains extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().unique()();
  TextColumn get description => text().withDefault(const Constant(''))();
}

class Cuvees extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  IntColumn get domainId => integer().references(Domains, #id)();
  IntColumn get designationId =>
      integer().references(Designations, #id).withDefault(const Constant(0))();
  IntColumn get color => integer().withDefault(const Constant(0))();
  TextColumn get description => text().withDefault(const Constant(''))();
}

class Bottles extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get tagId => text().nullable().unique()();
  IntColumn get cuveeId => integer().references(Cuvees, #id)();
  IntColumn get vintage => integer()();
  TextColumn get description => text().withDefault(const Constant(''))();
  RealColumn get purchasePrice => real().nullable()();
  IntColumn get drinkBefore => integer().nullable()();
  TextColumn get addedAt => text()();
  TextColumn get consumedAt => text().nullable()();
}

// ---------------------------------------------------------------------------
// Denormalized result classes
// ---------------------------------------------------------------------------

class CuveeWithNames {
  final Cuvee cuvee;
  final String domainName;
  final String designationName;
  final String region;

  CuveeWithNames({
    required this.cuvee,
    required this.domainName,
    required this.designationName,
    required this.region,
  });
}

class BottleWithCuvee {
  final Bottle bottle;
  final Cuvee cuvee;
  final String domainName;
  final String designationName;
  final String region;

  BottleWithCuvee({
    required this.bottle,
    required this.cuvee,
    required this.domainName,
    required this.designationName,
    required this.region,
  });
}

// ---------------------------------------------------------------------------
// toJson() extensions — snake_case keys matching docs/rest-api-contracts.md
// ---------------------------------------------------------------------------

extension DesignationToApiJson on Designation {
  Map<String, dynamic> toApiJson() {
    final json = <String, dynamic>{
      'id': id,
      'name': name,
      'region': region,
      'description': description,
    };
    if (picture != null) json['picture'] = base64Encode(picture!);
    return json;
  }

  /// Lightweight representation for list endpoints — excludes description and
  /// picture to keep payloads small.
  Map<String, dynamic> toSummaryJson() => {
        'id': id,
        'name': name,
        'region': region,
      };
}

extension DomainToApiJson on Domain {
  Map<String, dynamic> toApiJson() => {
        'id': id,
        'name': name,
        'description': description,
      };
}

extension CuveeWithNamesToApiJson on CuveeWithNames {
  Map<String, dynamic> toApiJson() => {
        'id': cuvee.id,
        'name': cuvee.name,
        'domain_id': cuvee.domainId,
        'designation_id': cuvee.designationId,
        'color': cuvee.color,
        'description': cuvee.description,
        'domain_name': domainName,
        'designation_name': designationName,
        'region': region,
      };

  /// Lightweight representation for list endpoints — excludes description.
  Map<String, dynamic> toSummaryJson() => {
        'id': cuvee.id,
        'name': cuvee.name,
        'domain_id': cuvee.domainId,
        'designation_id': cuvee.designationId,
        'color': cuvee.color,
        'domain_name': domainName,
        'designation_name': designationName,
        'region': region,
      };
}

extension BottleWithCuveeToApiJson on BottleWithCuvee {
  Map<String, dynamic> toApiJson() {
    final json = <String, dynamic>{
      'id': bottle.id,
      'cuvee_id': bottle.cuveeId,
      'vintage': bottle.vintage,
      'description': bottle.description,
      'added_at': bottle.addedAt,
      'cuvee': {
        'id': cuvee.id,
        'name': cuvee.name,
        'domain_id': cuvee.domainId,
        'designation_id': cuvee.designationId,
        'color': cuvee.color,
        'description': cuvee.description,
        'domain_name': domainName,
        'designation_name': designationName,
        'region': region,
      },
    };
    if (bottle.tagId != null) json['tag_id'] = bottle.tagId;
    if (bottle.purchasePrice != null) {
      json['purchase_price'] = bottle.purchasePrice;
    }
    if (bottle.drinkBefore != null) json['drink_before'] = bottle.drinkBefore;
    if (bottle.consumedAt != null) json['consumed_at'] = bottle.consumedAt;
    return json;
  }

  /// Lightweight representation for list endpoints — excludes descriptions
  /// from both the bottle and nested cuvée.
  Map<String, dynamic> toSummaryJson() {
    final json = <String, dynamic>{
      'id': bottle.id,
      'cuvee_id': bottle.cuveeId,
      'vintage': bottle.vintage,
      'added_at': bottle.addedAt,
      'cuvee': {
        'id': cuvee.id,
        'name': cuvee.name,
        'domain_id': cuvee.domainId,
        'designation_id': cuvee.designationId,
        'color': cuvee.color,
        'domain_name': domainName,
        'designation_name': designationName,
        'region': region,
      },
    };
    if (bottle.tagId != null) json['tag_id'] = bottle.tagId;
    if (bottle.purchasePrice != null) {
      json['purchase_price'] = bottle.purchasePrice;
    }
    if (bottle.drinkBefore != null) json['drink_before'] = bottle.drinkBefore;
    if (bottle.consumedAt != null) json['consumed_at'] = bottle.consumedAt;
    return json;
  }
}

// ---------------------------------------------------------------------------
// Database
// ---------------------------------------------------------------------------

@DriftDatabase(tables: [Designations, Domains, Cuvees, Bottles])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : _seedOnCreate = true, super(_openConnection());

  AppDatabase.forTesting(super.e) : _seedOnCreate = false;

  final bool _seedOnCreate;

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          // Seed sentinel designation (id=0) for "unassigned" cuvees.
          await into(designations).insert(DesignationsCompanion.insert(
            name: '(unassigned)',
          ));
          // Overwrite the autoincrement id to 0.
          await customStatement(
            "UPDATE designations SET id = 0 WHERE name = '(unassigned)'",
          );
          // Seed reference data (designations & domains).
          if (_seedOnCreate) await seedDatabase(this);
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.addColumn(designations, designations.picture);
          }
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'winetap');
  }

  // -------------------------------------------------------------------------
  // Designation queries
  // -------------------------------------------------------------------------

  Future<List<Designation>> listDesignations() {
    return (select(designations)
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .get();
  }

  Future<Designation> getDesignationById(int id) {
    return (select(designations)..where((t) => t.id.equals(id))).getSingle();
  }

  Future<int> insertDesignation(DesignationsCompanion entry) {
    return into(designations).insert(entry);
  }

  Future<bool> updateDesignation(DesignationsCompanion entry) {
    return update(designations).replace(entry);
  }

  Future<int> deleteDesignation(int id) {
    return (delete(designations)..where((t) => t.id.equals(id))).go();
  }

  // -------------------------------------------------------------------------
  // Domain queries
  // -------------------------------------------------------------------------

  Future<List<Domain>> listDomains() {
    return (select(domains)..orderBy([(t) => OrderingTerm.asc(t.name)])).get();
  }

  Future<Domain> getDomainById(int id) {
    return (select(domains)..where((t) => t.id.equals(id))).getSingle();
  }

  Future<int> insertDomain(DomainsCompanion entry) {
    return into(domains).insert(entry);
  }

  Future<bool> updateDomain(DomainsCompanion entry) {
    return update(domains).replace(entry);
  }

  Future<int> deleteDomain(int id) {
    return (delete(domains)..where((t) => t.id.equals(id))).go();
  }

  // -------------------------------------------------------------------------
  // Cuvee queries
  // -------------------------------------------------------------------------

  CuveeWithNames _mapCuveeRow(TypedResult row) {
    final des = row.readTableOrNull(designations);
    return CuveeWithNames(
      cuvee: row.readTable(cuvees),
      domainName: row.readTable(domains).name,
      designationName: des?.name ?? '',
      region: des?.region ?? '',
    );
  }

  Future<List<CuveeWithNames>> listCuvees() {
    final query = select(cuvees).join([
      innerJoin(domains, domains.id.equalsExp(cuvees.domainId)),
      leftOuterJoin(designations,
          designations.id.equalsExp(cuvees.designationId)),
    ]);
    query.orderBy([
      OrderingTerm.asc(domains.name),
      OrderingTerm.asc(cuvees.name),
    ]);
    return query.map(_mapCuveeRow).get();
  }

  Future<CuveeWithNames> getCuveeById(int id) {
    final query = select(cuvees).join([
      innerJoin(domains, domains.id.equalsExp(cuvees.domainId)),
      leftOuterJoin(designations,
          designations.id.equalsExp(cuvees.designationId)),
    ]);
    query.where(cuvees.id.equals(id));
    return query.map(_mapCuveeRow).getSingle();
  }

  Future<int> insertCuvee(CuveesCompanion entry) {
    return into(cuvees).insert(entry);
  }

  Future<bool> updateCuvee(CuveesCompanion entry) {
    return update(cuvees).replace(entry);
  }

  Future<int> deleteCuvee(int id) {
    return (delete(cuvees)..where((t) => t.id.equals(id))).go();
  }

  // -------------------------------------------------------------------------
  // Bottle queries
  // -------------------------------------------------------------------------

  JoinedSelectStatement<HasResultSet, dynamic> _bottleWithCuveeQuery() {
    return select(bottles).join([
      innerJoin(cuvees, cuvees.id.equalsExp(bottles.cuveeId)),
      innerJoin(domains, domains.id.equalsExp(cuvees.domainId)),
      leftOuterJoin(designations,
          designations.id.equalsExp(cuvees.designationId)),
    ]);
  }

  BottleWithCuvee _mapBottleRow(TypedResult row) {
    final des = row.readTableOrNull(designations);
    return BottleWithCuvee(
      bottle: row.readTable(bottles),
      cuvee: row.readTable(cuvees),
      domainName: row.readTable(domains).name,
      designationName: des?.name ?? '',
      region: des?.region ?? '',
    );
  }

  Future<List<BottleWithCuvee>> listBottles({bool includeConsumed = false}) {
    final query = _bottleWithCuveeQuery();
    if (!includeConsumed) {
      query.where(bottles.consumedAt.isNull());
    }
    query.orderBy([
      OrderingTerm.asc(domains.name),
      OrderingTerm.asc(cuvees.name),
      OrderingTerm.asc(bottles.vintage),
    ]);
    return query.map(_mapBottleRow).get();
  }

  Future<BottleWithCuvee> getBottleById(int id) {
    final query = _bottleWithCuveeQuery();
    query.where(bottles.id.equals(id));
    return query.map(_mapBottleRow).getSingle();
  }

  Future<BottleWithCuvee?> getBottleByTagId(String tagId) {
    final query = _bottleWithCuveeQuery();
    query.where(bottles.tagId.equals(tagId) & bottles.consumedAt.isNull());
    return query.map(_mapBottleRow).getSingleOrNull();
  }

  Future<int> insertBottle(BottlesCompanion entry) {
    return into(bottles).insert(entry);
  }

  Future<BottleWithCuvee> consumeBottle(String tagId) {
    return transaction(() async {
      // Find the bottle first to get its ID.
      final row = await (select(bottles)
            ..where((t) => t.tagId.equals(tagId) & t.consumedAt.isNull()))
          .getSingleOrNull();
      if (row == null) {
        throw StateError('No in-stock bottle with tag_id=$tagId');
      }
      final now = DateTime.now().toUtc().toIso8601String();
      await (update(bottles)..where((t) => t.id.equals(row.id))).write(
        BottlesCompanion(
          consumedAt: Value(now),
          tagId: const Value(null),
        ),
      );
      return getBottleById(row.id);
    });
  }

  Future<bool> updateBottle(BottlesCompanion entry) {
    return update(bottles).replace(entry);
  }

  Future<int> updateBottleFields(int id, BottlesCompanion fields) {
    return (update(bottles)..where((t) => t.id.equals(id))).write(fields);
  }

  Future<int> deleteBottle(int id) {
    return (delete(bottles)..where((t) => t.id.equals(id))).go();
  }


  // -------------------------------------------------------------------------
  // Completions
  // -------------------------------------------------------------------------

  static String _escapeLike(String input) {
    return input
        .replaceAll(r'\', r'\\')
        .replaceAll('%', r'\%')
        .replaceAll('_', r'\_');
  }

  /// LIKE with ESCAPE clause — drift doesn't expose ESCAPE natively.
  Expression<bool> _likePrefixEscaped(
      GeneratedColumn<String> column, String prefix) {
    final pattern = '${_escapeLike(prefix)}%';
    return FunctionCallExpression('LIKE', [
      Variable.withString(pattern),
      column,
      Variable.withString(r'\'),
    ]);
  }

  Future<List<String>> searchDesignationNames(String prefix) {
    return (select(designations)
          ..where((t) => _likePrefixEscaped(t.name, prefix))
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .map((d) => d.name)
        .get();
  }

  Future<List<String>> searchDomainNames(String prefix) {
    return (select(domains)
          ..where((t) => _likePrefixEscaped(t.name, prefix))
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .map((d) => d.name)
        .get();
  }

  Future<List<String>> searchCuveeNames(String prefix) {
    return (select(cuvees)
          ..where((t) => _likePrefixEscaped(t.name, prefix))
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .map((c) => c.name)
        .get();
  }
}
