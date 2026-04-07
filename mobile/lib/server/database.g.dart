// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $DesignationsTable extends Designations
    with TableInfo<$DesignationsTable, Designation> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DesignationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _regionMeta = const VerificationMeta('region');
  @override
  late final GeneratedColumn<String> region = GeneratedColumn<String>(
    'region',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _pictureMeta = const VerificationMeta(
    'picture',
  );
  @override
  late final GeneratedColumn<Uint8List> picture = GeneratedColumn<Uint8List>(
    'picture',
    aliasedName,
    true,
    type: DriftSqlType.blob,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, region, description, picture];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'designations';
  @override
  VerificationContext validateIntegrity(
    Insertable<Designation> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('region')) {
      context.handle(
        _regionMeta,
        region.isAcceptableOrUnknown(data['region']!, _regionMeta),
      );
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('picture')) {
      context.handle(
        _pictureMeta,
        picture.isAcceptableOrUnknown(data['picture']!, _pictureMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Designation map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Designation(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      region: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}region'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      )!,
      picture: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}picture'],
      ),
    );
  }

  @override
  $DesignationsTable createAlias(String alias) {
    return $DesignationsTable(attachedDatabase, alias);
  }
}

class Designation extends DataClass implements Insertable<Designation> {
  final int id;
  final String name;
  final String region;
  final String description;
  final Uint8List? picture;
  const Designation({
    required this.id,
    required this.name,
    required this.region,
    required this.description,
    this.picture,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['region'] = Variable<String>(region);
    map['description'] = Variable<String>(description);
    if (!nullToAbsent || picture != null) {
      map['picture'] = Variable<Uint8List>(picture);
    }
    return map;
  }

  DesignationsCompanion toCompanion(bool nullToAbsent) {
    return DesignationsCompanion(
      id: Value(id),
      name: Value(name),
      region: Value(region),
      description: Value(description),
      picture: picture == null && nullToAbsent
          ? const Value.absent()
          : Value(picture),
    );
  }

  factory Designation.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Designation(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      region: serializer.fromJson<String>(json['region']),
      description: serializer.fromJson<String>(json['description']),
      picture: serializer.fromJson<Uint8List?>(json['picture']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'region': serializer.toJson<String>(region),
      'description': serializer.toJson<String>(description),
      'picture': serializer.toJson<Uint8List?>(picture),
    };
  }

  Designation copyWith({
    int? id,
    String? name,
    String? region,
    String? description,
    Value<Uint8List?> picture = const Value.absent(),
  }) => Designation(
    id: id ?? this.id,
    name: name ?? this.name,
    region: region ?? this.region,
    description: description ?? this.description,
    picture: picture.present ? picture.value : this.picture,
  );
  Designation copyWithCompanion(DesignationsCompanion data) {
    return Designation(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      region: data.region.present ? data.region.value : this.region,
      description: data.description.present
          ? data.description.value
          : this.description,
      picture: data.picture.present ? data.picture.value : this.picture,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Designation(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('region: $region, ')
          ..write('description: $description, ')
          ..write('picture: $picture')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, region, description, picture);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Designation &&
          other.id == this.id &&
          other.name == this.name &&
          other.region == this.region &&
          other.description == this.description &&
          other.picture == this.picture);
}

class DesignationsCompanion extends UpdateCompanion<Designation> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> region;
  final Value<String> description;
  final Value<Uint8List?> picture;
  const DesignationsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.region = const Value.absent(),
    this.description = const Value.absent(),
    this.picture = const Value.absent(),
  });
  DesignationsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.region = const Value.absent(),
    this.description = const Value.absent(),
    this.picture = const Value.absent(),
  }) : name = Value(name);
  static Insertable<Designation> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? region,
    Expression<String>? description,
    Expression<Uint8List>? picture,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (region != null) 'region': region,
      if (description != null) 'description': description,
      if (picture != null) 'picture': picture,
    });
  }

  DesignationsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String>? region,
    Value<String>? description,
    Value<Uint8List?>? picture,
  }) {
    return DesignationsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      region: region ?? this.region,
      description: description ?? this.description,
      picture: picture ?? this.picture,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (region.present) {
      map['region'] = Variable<String>(region.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (picture.present) {
      map['picture'] = Variable<Uint8List>(picture.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DesignationsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('region: $region, ')
          ..write('description: $description, ')
          ..write('picture: $picture')
          ..write(')'))
        .toString();
  }
}

class $DomainsTable extends Domains with TableInfo<$DomainsTable, Domain> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DomainsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, description];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'domains';
  @override
  VerificationContext validateIntegrity(
    Insertable<Domain> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Domain map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Domain(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      )!,
    );
  }

  @override
  $DomainsTable createAlias(String alias) {
    return $DomainsTable(attachedDatabase, alias);
  }
}

class Domain extends DataClass implements Insertable<Domain> {
  final int id;
  final String name;
  final String description;
  const Domain({
    required this.id,
    required this.name,
    required this.description,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['description'] = Variable<String>(description);
    return map;
  }

  DomainsCompanion toCompanion(bool nullToAbsent) {
    return DomainsCompanion(
      id: Value(id),
      name: Value(name),
      description: Value(description),
    );
  }

  factory Domain.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Domain(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      description: serializer.fromJson<String>(json['description']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'description': serializer.toJson<String>(description),
    };
  }

  Domain copyWith({int? id, String? name, String? description}) => Domain(
    id: id ?? this.id,
    name: name ?? this.name,
    description: description ?? this.description,
  );
  Domain copyWithCompanion(DomainsCompanion data) {
    return Domain(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      description: data.description.present
          ? data.description.value
          : this.description,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Domain(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('description: $description')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, description);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Domain &&
          other.id == this.id &&
          other.name == this.name &&
          other.description == this.description);
}

class DomainsCompanion extends UpdateCompanion<Domain> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> description;
  const DomainsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.description = const Value.absent(),
  });
  DomainsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.description = const Value.absent(),
  }) : name = Value(name);
  static Insertable<Domain> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? description,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (description != null) 'description': description,
    });
  }

  DomainsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String>? description,
  }) {
    return DomainsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DomainsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('description: $description')
          ..write(')'))
        .toString();
  }
}

class $CuveesTable extends Cuvees with TableInfo<$CuveesTable, Cuvee> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CuveesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _domainIdMeta = const VerificationMeta(
    'domainId',
  );
  @override
  late final GeneratedColumn<int> domainId = GeneratedColumn<int>(
    'domain_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES domains (id)',
    ),
  );
  static const VerificationMeta _designationIdMeta = const VerificationMeta(
    'designationId',
  );
  @override
  late final GeneratedColumn<int> designationId = GeneratedColumn<int>(
    'designation_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES designations (id)',
    ),
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<int> color = GeneratedColumn<int>(
    'color',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    domainId,
    designationId,
    color,
    description,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cuvees';
  @override
  VerificationContext validateIntegrity(
    Insertable<Cuvee> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('domain_id')) {
      context.handle(
        _domainIdMeta,
        domainId.isAcceptableOrUnknown(data['domain_id']!, _domainIdMeta),
      );
    } else if (isInserting) {
      context.missing(_domainIdMeta);
    }
    if (data.containsKey('designation_id')) {
      context.handle(
        _designationIdMeta,
        designationId.isAcceptableOrUnknown(
          data['designation_id']!,
          _designationIdMeta,
        ),
      );
    }
    if (data.containsKey('color')) {
      context.handle(
        _colorMeta,
        color.isAcceptableOrUnknown(data['color']!, _colorMeta),
      );
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Cuvee map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Cuvee(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      domainId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}domain_id'],
      )!,
      designationId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}designation_id'],
      )!,
      color: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}color'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      )!,
    );
  }

  @override
  $CuveesTable createAlias(String alias) {
    return $CuveesTable(attachedDatabase, alias);
  }
}

class Cuvee extends DataClass implements Insertable<Cuvee> {
  final int id;
  final String name;
  final int domainId;
  final int designationId;
  final int color;
  final String description;
  const Cuvee({
    required this.id,
    required this.name,
    required this.domainId,
    required this.designationId,
    required this.color,
    required this.description,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['domain_id'] = Variable<int>(domainId);
    map['designation_id'] = Variable<int>(designationId);
    map['color'] = Variable<int>(color);
    map['description'] = Variable<String>(description);
    return map;
  }

  CuveesCompanion toCompanion(bool nullToAbsent) {
    return CuveesCompanion(
      id: Value(id),
      name: Value(name),
      domainId: Value(domainId),
      designationId: Value(designationId),
      color: Value(color),
      description: Value(description),
    );
  }

  factory Cuvee.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Cuvee(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      domainId: serializer.fromJson<int>(json['domainId']),
      designationId: serializer.fromJson<int>(json['designationId']),
      color: serializer.fromJson<int>(json['color']),
      description: serializer.fromJson<String>(json['description']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'domainId': serializer.toJson<int>(domainId),
      'designationId': serializer.toJson<int>(designationId),
      'color': serializer.toJson<int>(color),
      'description': serializer.toJson<String>(description),
    };
  }

  Cuvee copyWith({
    int? id,
    String? name,
    int? domainId,
    int? designationId,
    int? color,
    String? description,
  }) => Cuvee(
    id: id ?? this.id,
    name: name ?? this.name,
    domainId: domainId ?? this.domainId,
    designationId: designationId ?? this.designationId,
    color: color ?? this.color,
    description: description ?? this.description,
  );
  Cuvee copyWithCompanion(CuveesCompanion data) {
    return Cuvee(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      domainId: data.domainId.present ? data.domainId.value : this.domainId,
      designationId: data.designationId.present
          ? data.designationId.value
          : this.designationId,
      color: data.color.present ? data.color.value : this.color,
      description: data.description.present
          ? data.description.value
          : this.description,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Cuvee(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('domainId: $domainId, ')
          ..write('designationId: $designationId, ')
          ..write('color: $color, ')
          ..write('description: $description')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, domainId, designationId, color, description);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Cuvee &&
          other.id == this.id &&
          other.name == this.name &&
          other.domainId == this.domainId &&
          other.designationId == this.designationId &&
          other.color == this.color &&
          other.description == this.description);
}

class CuveesCompanion extends UpdateCompanion<Cuvee> {
  final Value<int> id;
  final Value<String> name;
  final Value<int> domainId;
  final Value<int> designationId;
  final Value<int> color;
  final Value<String> description;
  const CuveesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.domainId = const Value.absent(),
    this.designationId = const Value.absent(),
    this.color = const Value.absent(),
    this.description = const Value.absent(),
  });
  CuveesCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required int domainId,
    this.designationId = const Value.absent(),
    this.color = const Value.absent(),
    this.description = const Value.absent(),
  }) : name = Value(name),
       domainId = Value(domainId);
  static Insertable<Cuvee> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<int>? domainId,
    Expression<int>? designationId,
    Expression<int>? color,
    Expression<String>? description,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (domainId != null) 'domain_id': domainId,
      if (designationId != null) 'designation_id': designationId,
      if (color != null) 'color': color,
      if (description != null) 'description': description,
    });
  }

  CuveesCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<int>? domainId,
    Value<int>? designationId,
    Value<int>? color,
    Value<String>? description,
  }) {
    return CuveesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      domainId: domainId ?? this.domainId,
      designationId: designationId ?? this.designationId,
      color: color ?? this.color,
      description: description ?? this.description,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (domainId.present) {
      map['domain_id'] = Variable<int>(domainId.value);
    }
    if (designationId.present) {
      map['designation_id'] = Variable<int>(designationId.value);
    }
    if (color.present) {
      map['color'] = Variable<int>(color.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CuveesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('domainId: $domainId, ')
          ..write('designationId: $designationId, ')
          ..write('color: $color, ')
          ..write('description: $description')
          ..write(')'))
        .toString();
  }
}

class $BottlesTable extends Bottles with TableInfo<$BottlesTable, Bottle> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BottlesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _tagIdMeta = const VerificationMeta('tagId');
  @override
  late final GeneratedColumn<String> tagId = GeneratedColumn<String>(
    'tag_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _cuveeIdMeta = const VerificationMeta(
    'cuveeId',
  );
  @override
  late final GeneratedColumn<int> cuveeId = GeneratedColumn<int>(
    'cuvee_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES cuvees (id)',
    ),
  );
  static const VerificationMeta _vintageMeta = const VerificationMeta(
    'vintage',
  );
  @override
  late final GeneratedColumn<int> vintage = GeneratedColumn<int>(
    'vintage',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _purchasePriceMeta = const VerificationMeta(
    'purchasePrice',
  );
  @override
  late final GeneratedColumn<double> purchasePrice = GeneratedColumn<double>(
    'purchase_price',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _drinkBeforeMeta = const VerificationMeta(
    'drinkBefore',
  );
  @override
  late final GeneratedColumn<int> drinkBefore = GeneratedColumn<int>(
    'drink_before',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _addedAtMeta = const VerificationMeta(
    'addedAt',
  );
  @override
  late final GeneratedColumn<String> addedAt = GeneratedColumn<String>(
    'added_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _consumedAtMeta = const VerificationMeta(
    'consumedAt',
  );
  @override
  late final GeneratedColumn<String> consumedAt = GeneratedColumn<String>(
    'consumed_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    tagId,
    cuveeId,
    vintage,
    description,
    purchasePrice,
    drinkBefore,
    addedAt,
    consumedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'bottles';
  @override
  VerificationContext validateIntegrity(
    Insertable<Bottle> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('tag_id')) {
      context.handle(
        _tagIdMeta,
        tagId.isAcceptableOrUnknown(data['tag_id']!, _tagIdMeta),
      );
    }
    if (data.containsKey('cuvee_id')) {
      context.handle(
        _cuveeIdMeta,
        cuveeId.isAcceptableOrUnknown(data['cuvee_id']!, _cuveeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_cuveeIdMeta);
    }
    if (data.containsKey('vintage')) {
      context.handle(
        _vintageMeta,
        vintage.isAcceptableOrUnknown(data['vintage']!, _vintageMeta),
      );
    } else if (isInserting) {
      context.missing(_vintageMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('purchase_price')) {
      context.handle(
        _purchasePriceMeta,
        purchasePrice.isAcceptableOrUnknown(
          data['purchase_price']!,
          _purchasePriceMeta,
        ),
      );
    }
    if (data.containsKey('drink_before')) {
      context.handle(
        _drinkBeforeMeta,
        drinkBefore.isAcceptableOrUnknown(
          data['drink_before']!,
          _drinkBeforeMeta,
        ),
      );
    }
    if (data.containsKey('added_at')) {
      context.handle(
        _addedAtMeta,
        addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_addedAtMeta);
    }
    if (data.containsKey('consumed_at')) {
      context.handle(
        _consumedAtMeta,
        consumedAt.isAcceptableOrUnknown(data['consumed_at']!, _consumedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Bottle map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Bottle(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      tagId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tag_id'],
      ),
      cuveeId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cuvee_id'],
      )!,
      vintage: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}vintage'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      )!,
      purchasePrice: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}purchase_price'],
      ),
      drinkBefore: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}drink_before'],
      ),
      addedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}added_at'],
      )!,
      consumedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}consumed_at'],
      ),
    );
  }

  @override
  $BottlesTable createAlias(String alias) {
    return $BottlesTable(attachedDatabase, alias);
  }
}

class Bottle extends DataClass implements Insertable<Bottle> {
  final int id;
  final String? tagId;
  final int cuveeId;
  final int vintage;
  final String description;
  final double? purchasePrice;
  final int? drinkBefore;
  final String addedAt;
  final String? consumedAt;
  const Bottle({
    required this.id,
    this.tagId,
    required this.cuveeId,
    required this.vintage,
    required this.description,
    this.purchasePrice,
    this.drinkBefore,
    required this.addedAt,
    this.consumedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || tagId != null) {
      map['tag_id'] = Variable<String>(tagId);
    }
    map['cuvee_id'] = Variable<int>(cuveeId);
    map['vintage'] = Variable<int>(vintage);
    map['description'] = Variable<String>(description);
    if (!nullToAbsent || purchasePrice != null) {
      map['purchase_price'] = Variable<double>(purchasePrice);
    }
    if (!nullToAbsent || drinkBefore != null) {
      map['drink_before'] = Variable<int>(drinkBefore);
    }
    map['added_at'] = Variable<String>(addedAt);
    if (!nullToAbsent || consumedAt != null) {
      map['consumed_at'] = Variable<String>(consumedAt);
    }
    return map;
  }

  BottlesCompanion toCompanion(bool nullToAbsent) {
    return BottlesCompanion(
      id: Value(id),
      tagId: tagId == null && nullToAbsent
          ? const Value.absent()
          : Value(tagId),
      cuveeId: Value(cuveeId),
      vintage: Value(vintage),
      description: Value(description),
      purchasePrice: purchasePrice == null && nullToAbsent
          ? const Value.absent()
          : Value(purchasePrice),
      drinkBefore: drinkBefore == null && nullToAbsent
          ? const Value.absent()
          : Value(drinkBefore),
      addedAt: Value(addedAt),
      consumedAt: consumedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(consumedAt),
    );
  }

  factory Bottle.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Bottle(
      id: serializer.fromJson<int>(json['id']),
      tagId: serializer.fromJson<String?>(json['tagId']),
      cuveeId: serializer.fromJson<int>(json['cuveeId']),
      vintage: serializer.fromJson<int>(json['vintage']),
      description: serializer.fromJson<String>(json['description']),
      purchasePrice: serializer.fromJson<double?>(json['purchasePrice']),
      drinkBefore: serializer.fromJson<int?>(json['drinkBefore']),
      addedAt: serializer.fromJson<String>(json['addedAt']),
      consumedAt: serializer.fromJson<String?>(json['consumedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'tagId': serializer.toJson<String?>(tagId),
      'cuveeId': serializer.toJson<int>(cuveeId),
      'vintage': serializer.toJson<int>(vintage),
      'description': serializer.toJson<String>(description),
      'purchasePrice': serializer.toJson<double?>(purchasePrice),
      'drinkBefore': serializer.toJson<int?>(drinkBefore),
      'addedAt': serializer.toJson<String>(addedAt),
      'consumedAt': serializer.toJson<String?>(consumedAt),
    };
  }

  Bottle copyWith({
    int? id,
    Value<String?> tagId = const Value.absent(),
    int? cuveeId,
    int? vintage,
    String? description,
    Value<double?> purchasePrice = const Value.absent(),
    Value<int?> drinkBefore = const Value.absent(),
    String? addedAt,
    Value<String?> consumedAt = const Value.absent(),
  }) => Bottle(
    id: id ?? this.id,
    tagId: tagId.present ? tagId.value : this.tagId,
    cuveeId: cuveeId ?? this.cuveeId,
    vintage: vintage ?? this.vintage,
    description: description ?? this.description,
    purchasePrice: purchasePrice.present
        ? purchasePrice.value
        : this.purchasePrice,
    drinkBefore: drinkBefore.present ? drinkBefore.value : this.drinkBefore,
    addedAt: addedAt ?? this.addedAt,
    consumedAt: consumedAt.present ? consumedAt.value : this.consumedAt,
  );
  Bottle copyWithCompanion(BottlesCompanion data) {
    return Bottle(
      id: data.id.present ? data.id.value : this.id,
      tagId: data.tagId.present ? data.tagId.value : this.tagId,
      cuveeId: data.cuveeId.present ? data.cuveeId.value : this.cuveeId,
      vintage: data.vintage.present ? data.vintage.value : this.vintage,
      description: data.description.present
          ? data.description.value
          : this.description,
      purchasePrice: data.purchasePrice.present
          ? data.purchasePrice.value
          : this.purchasePrice,
      drinkBefore: data.drinkBefore.present
          ? data.drinkBefore.value
          : this.drinkBefore,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
      consumedAt: data.consumedAt.present
          ? data.consumedAt.value
          : this.consumedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Bottle(')
          ..write('id: $id, ')
          ..write('tagId: $tagId, ')
          ..write('cuveeId: $cuveeId, ')
          ..write('vintage: $vintage, ')
          ..write('description: $description, ')
          ..write('purchasePrice: $purchasePrice, ')
          ..write('drinkBefore: $drinkBefore, ')
          ..write('addedAt: $addedAt, ')
          ..write('consumedAt: $consumedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    tagId,
    cuveeId,
    vintage,
    description,
    purchasePrice,
    drinkBefore,
    addedAt,
    consumedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Bottle &&
          other.id == this.id &&
          other.tagId == this.tagId &&
          other.cuveeId == this.cuveeId &&
          other.vintage == this.vintage &&
          other.description == this.description &&
          other.purchasePrice == this.purchasePrice &&
          other.drinkBefore == this.drinkBefore &&
          other.addedAt == this.addedAt &&
          other.consumedAt == this.consumedAt);
}

class BottlesCompanion extends UpdateCompanion<Bottle> {
  final Value<int> id;
  final Value<String?> tagId;
  final Value<int> cuveeId;
  final Value<int> vintage;
  final Value<String> description;
  final Value<double?> purchasePrice;
  final Value<int?> drinkBefore;
  final Value<String> addedAt;
  final Value<String?> consumedAt;
  const BottlesCompanion({
    this.id = const Value.absent(),
    this.tagId = const Value.absent(),
    this.cuveeId = const Value.absent(),
    this.vintage = const Value.absent(),
    this.description = const Value.absent(),
    this.purchasePrice = const Value.absent(),
    this.drinkBefore = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.consumedAt = const Value.absent(),
  });
  BottlesCompanion.insert({
    this.id = const Value.absent(),
    this.tagId = const Value.absent(),
    required int cuveeId,
    required int vintage,
    this.description = const Value.absent(),
    this.purchasePrice = const Value.absent(),
    this.drinkBefore = const Value.absent(),
    required String addedAt,
    this.consumedAt = const Value.absent(),
  }) : cuveeId = Value(cuveeId),
       vintage = Value(vintage),
       addedAt = Value(addedAt);
  static Insertable<Bottle> custom({
    Expression<int>? id,
    Expression<String>? tagId,
    Expression<int>? cuveeId,
    Expression<int>? vintage,
    Expression<String>? description,
    Expression<double>? purchasePrice,
    Expression<int>? drinkBefore,
    Expression<String>? addedAt,
    Expression<String>? consumedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (tagId != null) 'tag_id': tagId,
      if (cuveeId != null) 'cuvee_id': cuveeId,
      if (vintage != null) 'vintage': vintage,
      if (description != null) 'description': description,
      if (purchasePrice != null) 'purchase_price': purchasePrice,
      if (drinkBefore != null) 'drink_before': drinkBefore,
      if (addedAt != null) 'added_at': addedAt,
      if (consumedAt != null) 'consumed_at': consumedAt,
    });
  }

  BottlesCompanion copyWith({
    Value<int>? id,
    Value<String?>? tagId,
    Value<int>? cuveeId,
    Value<int>? vintage,
    Value<String>? description,
    Value<double?>? purchasePrice,
    Value<int?>? drinkBefore,
    Value<String>? addedAt,
    Value<String?>? consumedAt,
  }) {
    return BottlesCompanion(
      id: id ?? this.id,
      tagId: tagId ?? this.tagId,
      cuveeId: cuveeId ?? this.cuveeId,
      vintage: vintage ?? this.vintage,
      description: description ?? this.description,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      drinkBefore: drinkBefore ?? this.drinkBefore,
      addedAt: addedAt ?? this.addedAt,
      consumedAt: consumedAt ?? this.consumedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (tagId.present) {
      map['tag_id'] = Variable<String>(tagId.value);
    }
    if (cuveeId.present) {
      map['cuvee_id'] = Variable<int>(cuveeId.value);
    }
    if (vintage.present) {
      map['vintage'] = Variable<int>(vintage.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (purchasePrice.present) {
      map['purchase_price'] = Variable<double>(purchasePrice.value);
    }
    if (drinkBefore.present) {
      map['drink_before'] = Variable<int>(drinkBefore.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<String>(addedAt.value);
    }
    if (consumedAt.present) {
      map['consumed_at'] = Variable<String>(consumedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BottlesCompanion(')
          ..write('id: $id, ')
          ..write('tagId: $tagId, ')
          ..write('cuveeId: $cuveeId, ')
          ..write('vintage: $vintage, ')
          ..write('description: $description, ')
          ..write('purchasePrice: $purchasePrice, ')
          ..write('drinkBefore: $drinkBefore, ')
          ..write('addedAt: $addedAt, ')
          ..write('consumedAt: $consumedAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $DesignationsTable designations = $DesignationsTable(this);
  late final $DomainsTable domains = $DomainsTable(this);
  late final $CuveesTable cuvees = $CuveesTable(this);
  late final $BottlesTable bottles = $BottlesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    designations,
    domains,
    cuvees,
    bottles,
  ];
}

typedef $$DesignationsTableCreateCompanionBuilder =
    DesignationsCompanion Function({
      Value<int> id,
      required String name,
      Value<String> region,
      Value<String> description,
    });
typedef $$DesignationsTableUpdateCompanionBuilder =
    DesignationsCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String> region,
      Value<String> description,
    });

final class $$DesignationsTableReferences
    extends BaseReferences<_$AppDatabase, $DesignationsTable, Designation> {
  $$DesignationsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$CuveesTable, List<Cuvee>> _cuveesRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.cuvees,
    aliasName: $_aliasNameGenerator(
      db.designations.id,
      db.cuvees.designationId,
    ),
  );

  $$CuveesTableProcessedTableManager get cuveesRefs {
    final manager = $$CuveesTableTableManager(
      $_db,
      $_db.cuvees,
    ).filter((f) => f.designationId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_cuveesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$DesignationsTableFilterComposer
    extends Composer<_$AppDatabase, $DesignationsTable> {
  $$DesignationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get region => $composableBuilder(
    column: $table.region,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> cuveesRefs(
    Expression<bool> Function($$CuveesTableFilterComposer f) f,
  ) {
    final $$CuveesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.cuvees,
      getReferencedColumn: (t) => t.designationId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CuveesTableFilterComposer(
            $db: $db,
            $table: $db.cuvees,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$DesignationsTableOrderingComposer
    extends Composer<_$AppDatabase, $DesignationsTable> {
  $$DesignationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get region => $composableBuilder(
    column: $table.region,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DesignationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DesignationsTable> {
  $$DesignationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get region =>
      $composableBuilder(column: $table.region, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  Expression<T> cuveesRefs<T extends Object>(
    Expression<T> Function($$CuveesTableAnnotationComposer a) f,
  ) {
    final $$CuveesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.cuvees,
      getReferencedColumn: (t) => t.designationId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CuveesTableAnnotationComposer(
            $db: $db,
            $table: $db.cuvees,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$DesignationsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DesignationsTable,
          Designation,
          $$DesignationsTableFilterComposer,
          $$DesignationsTableOrderingComposer,
          $$DesignationsTableAnnotationComposer,
          $$DesignationsTableCreateCompanionBuilder,
          $$DesignationsTableUpdateCompanionBuilder,
          (Designation, $$DesignationsTableReferences),
          Designation,
          PrefetchHooks Function({bool cuveesRefs})
        > {
  $$DesignationsTableTableManager(_$AppDatabase db, $DesignationsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DesignationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DesignationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DesignationsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> region = const Value.absent(),
                Value<String> description = const Value.absent(),
              }) => DesignationsCompanion(
                id: id,
                name: name,
                region: region,
                description: description,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<String> region = const Value.absent(),
                Value<String> description = const Value.absent(),
              }) => DesignationsCompanion.insert(
                id: id,
                name: name,
                region: region,
                description: description,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$DesignationsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({cuveesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (cuveesRefs) db.cuvees],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (cuveesRefs)
                    await $_getPrefetchedData<
                      Designation,
                      $DesignationsTable,
                      Cuvee
                    >(
                      currentTable: table,
                      referencedTable: $$DesignationsTableReferences
                          ._cuveesRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$DesignationsTableReferences(
                            db,
                            table,
                            p0,
                          ).cuveesRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where(
                            (e) => e.designationId == item.id,
                          ),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$DesignationsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DesignationsTable,
      Designation,
      $$DesignationsTableFilterComposer,
      $$DesignationsTableOrderingComposer,
      $$DesignationsTableAnnotationComposer,
      $$DesignationsTableCreateCompanionBuilder,
      $$DesignationsTableUpdateCompanionBuilder,
      (Designation, $$DesignationsTableReferences),
      Designation,
      PrefetchHooks Function({bool cuveesRefs})
    >;
typedef $$DomainsTableCreateCompanionBuilder =
    DomainsCompanion Function({
      Value<int> id,
      required String name,
      Value<String> description,
    });
typedef $$DomainsTableUpdateCompanionBuilder =
    DomainsCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String> description,
    });

final class $$DomainsTableReferences
    extends BaseReferences<_$AppDatabase, $DomainsTable, Domain> {
  $$DomainsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$CuveesTable, List<Cuvee>> _cuveesRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.cuvees,
    aliasName: $_aliasNameGenerator(db.domains.id, db.cuvees.domainId),
  );

  $$CuveesTableProcessedTableManager get cuveesRefs {
    final manager = $$CuveesTableTableManager(
      $_db,
      $_db.cuvees,
    ).filter((f) => f.domainId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_cuveesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$DomainsTableFilterComposer
    extends Composer<_$AppDatabase, $DomainsTable> {
  $$DomainsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> cuveesRefs(
    Expression<bool> Function($$CuveesTableFilterComposer f) f,
  ) {
    final $$CuveesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.cuvees,
      getReferencedColumn: (t) => t.domainId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CuveesTableFilterComposer(
            $db: $db,
            $table: $db.cuvees,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$DomainsTableOrderingComposer
    extends Composer<_$AppDatabase, $DomainsTable> {
  $$DomainsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DomainsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DomainsTable> {
  $$DomainsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  Expression<T> cuveesRefs<T extends Object>(
    Expression<T> Function($$CuveesTableAnnotationComposer a) f,
  ) {
    final $$CuveesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.cuvees,
      getReferencedColumn: (t) => t.domainId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CuveesTableAnnotationComposer(
            $db: $db,
            $table: $db.cuvees,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$DomainsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DomainsTable,
          Domain,
          $$DomainsTableFilterComposer,
          $$DomainsTableOrderingComposer,
          $$DomainsTableAnnotationComposer,
          $$DomainsTableCreateCompanionBuilder,
          $$DomainsTableUpdateCompanionBuilder,
          (Domain, $$DomainsTableReferences),
          Domain,
          PrefetchHooks Function({bool cuveesRefs})
        > {
  $$DomainsTableTableManager(_$AppDatabase db, $DomainsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DomainsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DomainsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DomainsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> description = const Value.absent(),
              }) => DomainsCompanion(
                id: id,
                name: name,
                description: description,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<String> description = const Value.absent(),
              }) => DomainsCompanion.insert(
                id: id,
                name: name,
                description: description,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$DomainsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({cuveesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (cuveesRefs) db.cuvees],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (cuveesRefs)
                    await $_getPrefetchedData<Domain, $DomainsTable, Cuvee>(
                      currentTable: table,
                      referencedTable: $$DomainsTableReferences
                          ._cuveesRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$DomainsTableReferences(db, table, p0).cuveesRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.domainId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$DomainsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DomainsTable,
      Domain,
      $$DomainsTableFilterComposer,
      $$DomainsTableOrderingComposer,
      $$DomainsTableAnnotationComposer,
      $$DomainsTableCreateCompanionBuilder,
      $$DomainsTableUpdateCompanionBuilder,
      (Domain, $$DomainsTableReferences),
      Domain,
      PrefetchHooks Function({bool cuveesRefs})
    >;
typedef $$CuveesTableCreateCompanionBuilder =
    CuveesCompanion Function({
      Value<int> id,
      required String name,
      required int domainId,
      Value<int> designationId,
      Value<int> color,
      Value<String> description,
    });
typedef $$CuveesTableUpdateCompanionBuilder =
    CuveesCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<int> domainId,
      Value<int> designationId,
      Value<int> color,
      Value<String> description,
    });

final class $$CuveesTableReferences
    extends BaseReferences<_$AppDatabase, $CuveesTable, Cuvee> {
  $$CuveesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $DomainsTable _domainIdTable(_$AppDatabase db) => db.domains
      .createAlias($_aliasNameGenerator(db.cuvees.domainId, db.domains.id));

  $$DomainsTableProcessedTableManager get domainId {
    final $_column = $_itemColumn<int>('domain_id')!;

    final manager = $$DomainsTableTableManager(
      $_db,
      $_db.domains,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_domainIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $DesignationsTable _designationIdTable(_$AppDatabase db) =>
      db.designations.createAlias(
        $_aliasNameGenerator(db.cuvees.designationId, db.designations.id),
      );

  $$DesignationsTableProcessedTableManager get designationId {
    final $_column = $_itemColumn<int>('designation_id')!;

    final manager = $$DesignationsTableTableManager(
      $_db,
      $_db.designations,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_designationIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$BottlesTable, List<Bottle>> _bottlesRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.bottles,
    aliasName: $_aliasNameGenerator(db.cuvees.id, db.bottles.cuveeId),
  );

  $$BottlesTableProcessedTableManager get bottlesRefs {
    final manager = $$BottlesTableTableManager(
      $_db,
      $_db.bottles,
    ).filter((f) => f.cuveeId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_bottlesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$CuveesTableFilterComposer
    extends Composer<_$AppDatabase, $CuveesTable> {
  $$CuveesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  $$DomainsTableFilterComposer get domainId {
    final $$DomainsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.domainId,
      referencedTable: $db.domains,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DomainsTableFilterComposer(
            $db: $db,
            $table: $db.domains,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$DesignationsTableFilterComposer get designationId {
    final $$DesignationsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.designationId,
      referencedTable: $db.designations,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DesignationsTableFilterComposer(
            $db: $db,
            $table: $db.designations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> bottlesRefs(
    Expression<bool> Function($$BottlesTableFilterComposer f) f,
  ) {
    final $$BottlesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.bottles,
      getReferencedColumn: (t) => t.cuveeId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BottlesTableFilterComposer(
            $db: $db,
            $table: $db.bottles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CuveesTableOrderingComposer
    extends Composer<_$AppDatabase, $CuveesTable> {
  $$CuveesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  $$DomainsTableOrderingComposer get domainId {
    final $$DomainsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.domainId,
      referencedTable: $db.domains,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DomainsTableOrderingComposer(
            $db: $db,
            $table: $db.domains,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$DesignationsTableOrderingComposer get designationId {
    final $$DesignationsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.designationId,
      referencedTable: $db.designations,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DesignationsTableOrderingComposer(
            $db: $db,
            $table: $db.designations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CuveesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CuveesTable> {
  $$CuveesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  $$DomainsTableAnnotationComposer get domainId {
    final $$DomainsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.domainId,
      referencedTable: $db.domains,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DomainsTableAnnotationComposer(
            $db: $db,
            $table: $db.domains,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$DesignationsTableAnnotationComposer get designationId {
    final $$DesignationsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.designationId,
      referencedTable: $db.designations,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DesignationsTableAnnotationComposer(
            $db: $db,
            $table: $db.designations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> bottlesRefs<T extends Object>(
    Expression<T> Function($$BottlesTableAnnotationComposer a) f,
  ) {
    final $$BottlesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.bottles,
      getReferencedColumn: (t) => t.cuveeId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BottlesTableAnnotationComposer(
            $db: $db,
            $table: $db.bottles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CuveesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CuveesTable,
          Cuvee,
          $$CuveesTableFilterComposer,
          $$CuveesTableOrderingComposer,
          $$CuveesTableAnnotationComposer,
          $$CuveesTableCreateCompanionBuilder,
          $$CuveesTableUpdateCompanionBuilder,
          (Cuvee, $$CuveesTableReferences),
          Cuvee,
          PrefetchHooks Function({
            bool domainId,
            bool designationId,
            bool bottlesRefs,
          })
        > {
  $$CuveesTableTableManager(_$AppDatabase db, $CuveesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CuveesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CuveesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CuveesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> domainId = const Value.absent(),
                Value<int> designationId = const Value.absent(),
                Value<int> color = const Value.absent(),
                Value<String> description = const Value.absent(),
              }) => CuveesCompanion(
                id: id,
                name: name,
                domainId: domainId,
                designationId: designationId,
                color: color,
                description: description,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required int domainId,
                Value<int> designationId = const Value.absent(),
                Value<int> color = const Value.absent(),
                Value<String> description = const Value.absent(),
              }) => CuveesCompanion.insert(
                id: id,
                name: name,
                domainId: domainId,
                designationId: designationId,
                color: color,
                description: description,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$CuveesTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback:
              ({domainId = false, designationId = false, bottlesRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [if (bottlesRefs) db.bottles],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (domainId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.domainId,
                                    referencedTable: $$CuveesTableReferences
                                        ._domainIdTable(db),
                                    referencedColumn: $$CuveesTableReferences
                                        ._domainIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }
                        if (designationId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.designationId,
                                    referencedTable: $$CuveesTableReferences
                                        ._designationIdTable(db),
                                    referencedColumn: $$CuveesTableReferences
                                        ._designationIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (bottlesRefs)
                        await $_getPrefetchedData<Cuvee, $CuveesTable, Bottle>(
                          currentTable: table,
                          referencedTable: $$CuveesTableReferences
                              ._bottlesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CuveesTableReferences(
                                db,
                                table,
                                p0,
                              ).bottlesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.cuveeId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$CuveesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CuveesTable,
      Cuvee,
      $$CuveesTableFilterComposer,
      $$CuveesTableOrderingComposer,
      $$CuveesTableAnnotationComposer,
      $$CuveesTableCreateCompanionBuilder,
      $$CuveesTableUpdateCompanionBuilder,
      (Cuvee, $$CuveesTableReferences),
      Cuvee,
      PrefetchHooks Function({
        bool domainId,
        bool designationId,
        bool bottlesRefs,
      })
    >;
typedef $$BottlesTableCreateCompanionBuilder =
    BottlesCompanion Function({
      Value<int> id,
      Value<String?> tagId,
      required int cuveeId,
      required int vintage,
      Value<String> description,
      Value<double?> purchasePrice,
      Value<int?> drinkBefore,
      required String addedAt,
      Value<String?> consumedAt,
    });
typedef $$BottlesTableUpdateCompanionBuilder =
    BottlesCompanion Function({
      Value<int> id,
      Value<String?> tagId,
      Value<int> cuveeId,
      Value<int> vintage,
      Value<String> description,
      Value<double?> purchasePrice,
      Value<int?> drinkBefore,
      Value<String> addedAt,
      Value<String?> consumedAt,
    });

final class $$BottlesTableReferences
    extends BaseReferences<_$AppDatabase, $BottlesTable, Bottle> {
  $$BottlesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $CuveesTable _cuveeIdTable(_$AppDatabase db) => db.cuvees.createAlias(
    $_aliasNameGenerator(db.bottles.cuveeId, db.cuvees.id),
  );

  $$CuveesTableProcessedTableManager get cuveeId {
    final $_column = $_itemColumn<int>('cuvee_id')!;

    final manager = $$CuveesTableTableManager(
      $_db,
      $_db.cuvees,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_cuveeIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$BottlesTableFilterComposer
    extends Composer<_$AppDatabase, $BottlesTable> {
  $$BottlesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tagId => $composableBuilder(
    column: $table.tagId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get vintage => $composableBuilder(
    column: $table.vintage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get purchasePrice => $composableBuilder(
    column: $table.purchasePrice,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get drinkBefore => $composableBuilder(
    column: $table.drinkBefore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get consumedAt => $composableBuilder(
    column: $table.consumedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$CuveesTableFilterComposer get cuveeId {
    final $$CuveesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cuveeId,
      referencedTable: $db.cuvees,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CuveesTableFilterComposer(
            $db: $db,
            $table: $db.cuvees,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BottlesTableOrderingComposer
    extends Composer<_$AppDatabase, $BottlesTable> {
  $$BottlesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tagId => $composableBuilder(
    column: $table.tagId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get vintage => $composableBuilder(
    column: $table.vintage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get purchasePrice => $composableBuilder(
    column: $table.purchasePrice,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get drinkBefore => $composableBuilder(
    column: $table.drinkBefore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get consumedAt => $composableBuilder(
    column: $table.consumedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$CuveesTableOrderingComposer get cuveeId {
    final $$CuveesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cuveeId,
      referencedTable: $db.cuvees,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CuveesTableOrderingComposer(
            $db: $db,
            $table: $db.cuvees,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BottlesTableAnnotationComposer
    extends Composer<_$AppDatabase, $BottlesTable> {
  $$BottlesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get tagId =>
      $composableBuilder(column: $table.tagId, builder: (column) => column);

  GeneratedColumn<int> get vintage =>
      $composableBuilder(column: $table.vintage, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<double> get purchasePrice => $composableBuilder(
    column: $table.purchasePrice,
    builder: (column) => column,
  );

  GeneratedColumn<int> get drinkBefore => $composableBuilder(
    column: $table.drinkBefore,
    builder: (column) => column,
  );

  GeneratedColumn<String> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);

  GeneratedColumn<String> get consumedAt => $composableBuilder(
    column: $table.consumedAt,
    builder: (column) => column,
  );

  $$CuveesTableAnnotationComposer get cuveeId {
    final $$CuveesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cuveeId,
      referencedTable: $db.cuvees,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CuveesTableAnnotationComposer(
            $db: $db,
            $table: $db.cuvees,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BottlesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BottlesTable,
          Bottle,
          $$BottlesTableFilterComposer,
          $$BottlesTableOrderingComposer,
          $$BottlesTableAnnotationComposer,
          $$BottlesTableCreateCompanionBuilder,
          $$BottlesTableUpdateCompanionBuilder,
          (Bottle, $$BottlesTableReferences),
          Bottle,
          PrefetchHooks Function({bool cuveeId})
        > {
  $$BottlesTableTableManager(_$AppDatabase db, $BottlesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BottlesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BottlesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BottlesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> tagId = const Value.absent(),
                Value<int> cuveeId = const Value.absent(),
                Value<int> vintage = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<double?> purchasePrice = const Value.absent(),
                Value<int?> drinkBefore = const Value.absent(),
                Value<String> addedAt = const Value.absent(),
                Value<String?> consumedAt = const Value.absent(),
              }) => BottlesCompanion(
                id: id,
                tagId: tagId,
                cuveeId: cuveeId,
                vintage: vintage,
                description: description,
                purchasePrice: purchasePrice,
                drinkBefore: drinkBefore,
                addedAt: addedAt,
                consumedAt: consumedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> tagId = const Value.absent(),
                required int cuveeId,
                required int vintage,
                Value<String> description = const Value.absent(),
                Value<double?> purchasePrice = const Value.absent(),
                Value<int?> drinkBefore = const Value.absent(),
                required String addedAt,
                Value<String?> consumedAt = const Value.absent(),
              }) => BottlesCompanion.insert(
                id: id,
                tagId: tagId,
                cuveeId: cuveeId,
                vintage: vintage,
                description: description,
                purchasePrice: purchasePrice,
                drinkBefore: drinkBefore,
                addedAt: addedAt,
                consumedAt: consumedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$BottlesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({cuveeId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (cuveeId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.cuveeId,
                                referencedTable: $$BottlesTableReferences
                                    ._cuveeIdTable(db),
                                referencedColumn: $$BottlesTableReferences
                                    ._cuveeIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$BottlesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BottlesTable,
      Bottle,
      $$BottlesTableFilterComposer,
      $$BottlesTableOrderingComposer,
      $$BottlesTableAnnotationComposer,
      $$BottlesTableCreateCompanionBuilder,
      $$BottlesTableUpdateCompanionBuilder,
      (Bottle, $$BottlesTableReferences),
      Bottle,
      PrefetchHooks Function({bool cuveeId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$DesignationsTableTableManager get designations =>
      $$DesignationsTableTableManager(_db, _db.designations);
  $$DomainsTableTableManager get domains =>
      $$DomainsTableTableManager(_db, _db.domains);
  $$CuveesTableTableManager get cuvees =>
      $$CuveesTableTableManager(_db, _db.cuvees);
  $$BottlesTableTableManager get bottles =>
      $$BottlesTableTableManager(_db, _db.bottles);
}
