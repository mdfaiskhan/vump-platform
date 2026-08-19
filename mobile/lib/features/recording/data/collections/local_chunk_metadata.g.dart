// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'local_chunk_metadata.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetLocalChunkMetadataCollection on Isar {
  IsarCollection<LocalChunkMetadata> get localChunkMetadatas =>
      this.collection();
}

const LocalChunkMetadataSchema = CollectionSchema(
  name: r'LocalChunkMetadata',
  id: 537305059786954697,
  properties: {
    r'capture': PropertySchema(
      id: 0,
      name: r'capture',
      type: IsarType.object,
      target: r'EmbeddedCapture',
    ),
    r'captureConditions': PropertySchema(
      id: 1,
      name: r'captureConditions',
      type: IsarType.object,
      target: r'EmbeddedCaptureConditions',
    ),
    r'chunkId': PropertySchema(
      id: 2,
      name: r'chunkId',
      type: IsarType.string,
    ),
    r'collectorAuthored': PropertySchema(
      id: 3,
      name: r'collectorAuthored',
      type: IsarType.object,
      target: r'EmbeddedCollectorAuthored',
    ),
    r'deviceContext': PropertySchema(
      id: 4,
      name: r'deviceContext',
      type: IsarType.object,
      target: r'EmbeddedDeviceContext',
    ),
    r'identity': PropertySchema(
      id: 5,
      name: r'identity',
      type: IsarType.object,
      target: r'EmbeddedIdentity',
    ),
    r'integrity': PropertySchema(
      id: 6,
      name: r'integrity',
      type: IsarType.object,
      target: r'EmbeddedIntegrity',
    ),
    r'timing': PropertySchema(
      id: 7,
      name: r'timing',
      type: IsarType.object,
      target: r'EmbeddedTiming',
    )
  },
  estimateSize: _localChunkMetadataEstimateSize,
  serialize: _localChunkMetadataSerialize,
  deserialize: _localChunkMetadataDeserialize,
  deserializeProp: _localChunkMetadataDeserializeProp,
  idName: r'id',
  indexes: {
    r'chunkId': IndexSchema(
      id: 7020861766424886656,
      name: r'chunkId',
      unique: true,
      replace: true,
      properties: [
        IndexPropertySchema(
          name: r'chunkId',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    )
  },
  links: {},
  embeddedSchemas: {
    r'EmbeddedIdentity': EmbeddedIdentitySchema,
    r'EmbeddedTiming': EmbeddedTimingSchema,
    r'EmbeddedCapture': EmbeddedCaptureSchema,
    r'EmbeddedDeviceContext': EmbeddedDeviceContextSchema,
    r'EmbeddedCaptureConditions': EmbeddedCaptureConditionsSchema,
    r'EmbeddedGpsFix': EmbeddedGpsFixSchema,
    r'EmbeddedIntegrity': EmbeddedIntegritySchema,
    r'EmbeddedCollectorAuthored': EmbeddedCollectorAuthoredSchema
  },
  getId: _localChunkMetadataGetId,
  getLinks: _localChunkMetadataGetLinks,
  attach: _localChunkMetadataAttach,
  version: '3.1.0+1',
);

int _localChunkMetadataEstimateSize(
  LocalChunkMetadata object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  {
    final value = object.capture;
    if (value != null) {
      bytesCount += 3 +
          EmbeddedCaptureSchema.estimateSize(
              value, allOffsets[EmbeddedCapture]!, allOffsets);
    }
  }
  {
    final value = object.captureConditions;
    if (value != null) {
      bytesCount += 3 +
          EmbeddedCaptureConditionsSchema.estimateSize(
              value, allOffsets[EmbeddedCaptureConditions]!, allOffsets);
    }
  }
  bytesCount += 3 + object.chunkId.length * 3;
  {
    final value = object.collectorAuthored;
    if (value != null) {
      bytesCount += 3 +
          EmbeddedCollectorAuthoredSchema.estimateSize(
              value, allOffsets[EmbeddedCollectorAuthored]!, allOffsets);
    }
  }
  {
    final value = object.deviceContext;
    if (value != null) {
      bytesCount += 3 +
          EmbeddedDeviceContextSchema.estimateSize(
              value, allOffsets[EmbeddedDeviceContext]!, allOffsets);
    }
  }
  {
    final value = object.identity;
    if (value != null) {
      bytesCount += 3 +
          EmbeddedIdentitySchema.estimateSize(
              value, allOffsets[EmbeddedIdentity]!, allOffsets);
    }
  }
  {
    final value = object.integrity;
    if (value != null) {
      bytesCount += 3 +
          EmbeddedIntegritySchema.estimateSize(
              value, allOffsets[EmbeddedIntegrity]!, allOffsets);
    }
  }
  {
    final value = object.timing;
    if (value != null) {
      bytesCount += 3 +
          EmbeddedTimingSchema.estimateSize(
              value, allOffsets[EmbeddedTiming]!, allOffsets);
    }
  }
  return bytesCount;
}

void _localChunkMetadataSerialize(
  LocalChunkMetadata object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeObject<EmbeddedCapture>(
    offsets[0],
    allOffsets,
    EmbeddedCaptureSchema.serialize,
    object.capture,
  );
  writer.writeObject<EmbeddedCaptureConditions>(
    offsets[1],
    allOffsets,
    EmbeddedCaptureConditionsSchema.serialize,
    object.captureConditions,
  );
  writer.writeString(offsets[2], object.chunkId);
  writer.writeObject<EmbeddedCollectorAuthored>(
    offsets[3],
    allOffsets,
    EmbeddedCollectorAuthoredSchema.serialize,
    object.collectorAuthored,
  );
  writer.writeObject<EmbeddedDeviceContext>(
    offsets[4],
    allOffsets,
    EmbeddedDeviceContextSchema.serialize,
    object.deviceContext,
  );
  writer.writeObject<EmbeddedIdentity>(
    offsets[5],
    allOffsets,
    EmbeddedIdentitySchema.serialize,
    object.identity,
  );
  writer.writeObject<EmbeddedIntegrity>(
    offsets[6],
    allOffsets,
    EmbeddedIntegritySchema.serialize,
    object.integrity,
  );
  writer.writeObject<EmbeddedTiming>(
    offsets[7],
    allOffsets,
    EmbeddedTimingSchema.serialize,
    object.timing,
  );
}

LocalChunkMetadata _localChunkMetadataDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = LocalChunkMetadata();
  object.capture = reader.readObjectOrNull<EmbeddedCapture>(
    offsets[0],
    EmbeddedCaptureSchema.deserialize,
    allOffsets,
  );
  object.captureConditions = reader.readObjectOrNull<EmbeddedCaptureConditions>(
    offsets[1],
    EmbeddedCaptureConditionsSchema.deserialize,
    allOffsets,
  );
  object.chunkId = reader.readString(offsets[2]);
  object.collectorAuthored = reader.readObjectOrNull<EmbeddedCollectorAuthored>(
    offsets[3],
    EmbeddedCollectorAuthoredSchema.deserialize,
    allOffsets,
  );
  object.deviceContext = reader.readObjectOrNull<EmbeddedDeviceContext>(
    offsets[4],
    EmbeddedDeviceContextSchema.deserialize,
    allOffsets,
  );
  object.id = id;
  object.identity = reader.readObjectOrNull<EmbeddedIdentity>(
    offsets[5],
    EmbeddedIdentitySchema.deserialize,
    allOffsets,
  );
  object.integrity = reader.readObjectOrNull<EmbeddedIntegrity>(
    offsets[6],
    EmbeddedIntegritySchema.deserialize,
    allOffsets,
  );
  object.timing = reader.readObjectOrNull<EmbeddedTiming>(
    offsets[7],
    EmbeddedTimingSchema.deserialize,
    allOffsets,
  );
  return object;
}

P _localChunkMetadataDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readObjectOrNull<EmbeddedCapture>(
        offset,
        EmbeddedCaptureSchema.deserialize,
        allOffsets,
      )) as P;
    case 1:
      return (reader.readObjectOrNull<EmbeddedCaptureConditions>(
        offset,
        EmbeddedCaptureConditionsSchema.deserialize,
        allOffsets,
      )) as P;
    case 2:
      return (reader.readString(offset)) as P;
    case 3:
      return (reader.readObjectOrNull<EmbeddedCollectorAuthored>(
        offset,
        EmbeddedCollectorAuthoredSchema.deserialize,
        allOffsets,
      )) as P;
    case 4:
      return (reader.readObjectOrNull<EmbeddedDeviceContext>(
        offset,
        EmbeddedDeviceContextSchema.deserialize,
        allOffsets,
      )) as P;
    case 5:
      return (reader.readObjectOrNull<EmbeddedIdentity>(
        offset,
        EmbeddedIdentitySchema.deserialize,
        allOffsets,
      )) as P;
    case 6:
      return (reader.readObjectOrNull<EmbeddedIntegrity>(
        offset,
        EmbeddedIntegritySchema.deserialize,
        allOffsets,
      )) as P;
    case 7:
      return (reader.readObjectOrNull<EmbeddedTiming>(
        offset,
        EmbeddedTimingSchema.deserialize,
        allOffsets,
      )) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _localChunkMetadataGetId(LocalChunkMetadata object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _localChunkMetadataGetLinks(
    LocalChunkMetadata object) {
  return [];
}

void _localChunkMetadataAttach(
    IsarCollection<dynamic> col, Id id, LocalChunkMetadata object) {
  object.id = id;
}

extension LocalChunkMetadataByIndex on IsarCollection<LocalChunkMetadata> {
  Future<LocalChunkMetadata?> getByChunkId(String chunkId) {
    return getByIndex(r'chunkId', [chunkId]);
  }

  LocalChunkMetadata? getByChunkIdSync(String chunkId) {
    return getByIndexSync(r'chunkId', [chunkId]);
  }

  Future<bool> deleteByChunkId(String chunkId) {
    return deleteByIndex(r'chunkId', [chunkId]);
  }

  bool deleteByChunkIdSync(String chunkId) {
    return deleteByIndexSync(r'chunkId', [chunkId]);
  }

  Future<List<LocalChunkMetadata?>> getAllByChunkId(
      List<String> chunkIdValues) {
    final values = chunkIdValues.map((e) => [e]).toList();
    return getAllByIndex(r'chunkId', values);
  }

  List<LocalChunkMetadata?> getAllByChunkIdSync(List<String> chunkIdValues) {
    final values = chunkIdValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'chunkId', values);
  }

  Future<int> deleteAllByChunkId(List<String> chunkIdValues) {
    final values = chunkIdValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'chunkId', values);
  }

  int deleteAllByChunkIdSync(List<String> chunkIdValues) {
    final values = chunkIdValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'chunkId', values);
  }

  Future<Id> putByChunkId(LocalChunkMetadata object) {
    return putByIndex(r'chunkId', object);
  }

  Id putByChunkIdSync(LocalChunkMetadata object, {bool saveLinks = true}) {
    return putByIndexSync(r'chunkId', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByChunkId(List<LocalChunkMetadata> objects) {
    return putAllByIndex(r'chunkId', objects);
  }

  List<Id> putAllByChunkIdSync(List<LocalChunkMetadata> objects,
      {bool saveLinks = true}) {
    return putAllByIndexSync(r'chunkId', objects, saveLinks: saveLinks);
  }
}

extension LocalChunkMetadataQueryWhereSort
    on QueryBuilder<LocalChunkMetadata, LocalChunkMetadata, QWhere> {
  QueryBuilder<LocalChunkMetadata, LocalChunkMetadata, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension LocalChunkMetadataQueryWhere
    on QueryBuilder<LocalChunkMetadata, LocalChunkMetadata, QWhereClause> {
  QueryBuilder<LocalChunkMetadata, LocalChunkMetadata, QAfterWhereClause>
      idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<LocalChunkMetadata, LocalChunkMetadata, QAfterWhereClause>
      idNotEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<LocalChunkMetadata, LocalChunkMetadata, QAfterWhereClause>
      idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<LocalChunkMetadata, LocalChunkMetadata, QAfterWhereClause>
      idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<LocalChunkMetadata, LocalChunkMetadata, QAfterWhereClause>
      idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: lowerId,
        includeLower: includeLower,
        upper: upperId,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<LocalChunkMetadata, LocalChunkMetadata, QAfterWhereClause>
      chunkIdEqualTo(String chunkId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'chunkId',
        value: [chunkId],
      ));
    });
  }

  QueryBuilder<LocalChunkMetadata, LocalChunkMetadata, QAfterWhereClause>
      chunkIdNotEqualTo(String chunkId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'chunkId',
              lower: [],
              upper: [chunkId],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'chunkId',
              lower: [chunkId],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'chunkId',
              lower: [chunkId],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'chunkId',
              lower: [],
              upper: [chunkId],
              includeUpper: false,
            ));
      }
    });
  }
}

extension LocalChunkMetadataQueryFilter
    on QueryBuilder<LocalChunkMetadata, LocalChunkMetadata, QFilterCondition> {
  QueryBuilder<LocalChunkMetadata, LocalChunkMetadata, QAfterFilterCondition>
      captureIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'capture',
      ));
    });
  }

  QueryBuilder<LocalChunkMetadata, LocalChunkMetadata, QAfterFilterCondition>
      captureIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'capture',
      ));
    });
  }

  QueryBuilder<LocalChunkMetadata, LocalChunkMetadata, QAfterFilterCondition>
      captureConditionsIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'captureConditions',
      ));
    });
  }

  QueryBuilder<LocalChunkMetadata, LocalChunkMetadata, QAfterFilterCondition>
      captureConditionsIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'captureConditions',
      ));
    });
  }

  QueryBuilder<LocalChunkMetadata, LocalChunkMetadata, QAfterFilterCondition>
      chunkIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'chunkId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalChunkMetadata, LocalChunkMetadata, QAfterFilterCondition>
      chunkIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'chunkId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalChunkMetadata, LocalChunkMetadata, QAfterFilterCondition>
      chunkIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'chunkId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalChunkMetadata, LocalChunkMetadata, QAfterFilterCondition>
      chunkIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'chunkId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalChunkMetadata, LocalChunkMetadata, QAfterFilterCondition>
      chunkIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'chunkId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalChunkMetadata, LocalChunkMetadata, QAfterFilterCondition>
      chunkIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'chunkId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalChunkMetadata, LocalChunkMetadata, QAfterFilterCondition>
      chunkIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'chunkId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalChunkMetadata, LocalChunkMetadata, QAfterFilterCondition>
      chunkIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'chunkId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalChunkMetadata, LocalChunkMetadata, QAfterFilterCondition>
      chunkIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'chunkId',
        value: '',
      ));
    });
  }

  QueryBuilder<LocalChunkMetadata, LocalChunkMetadata, QAfterFilterCondition>
      chunkIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'chunkId',
        value: '',
      ));
    });
  }

  QueryBuilder<LocalChunkMetadata, LocalChunkMetadata, QAfterFilterCondition>
      collectorAuthoredIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'collectorAuthored',
      ));
    });
  }

  QueryBuilder<LocalChunkMetadata, LocalChunkMetadata, QAfterFilterCondition>
      collectorAuthoredIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'collectorAuthored',
      ));
    });
  }

  QueryBuilder<LocalChunkMetadata, LocalChunkMetadata, QAfterFilterCondition>
      deviceContextIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'deviceContext',
      ));
    });
  }

  QueryBuilder<LocalChunkMetadata, LocalChunkMetadata, QAfterFilterCondition>
      deviceContextIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'deviceContext',
      ));
    });
  }

  QueryBuilder<LocalChunkMetadata, LocalChunkMetadata, QAfterFilterCondition>
      idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<LocalChunkMetadata, LocalChunkMetadata, QAfterFilterCondition>
      idGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<LocalChunkMetadata, LocalChunkMetadata, QAfterFilterCondition>
      idLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<LocalChunkMetadata, LocalChunkMetadata, QAfterFilterCondition>
      idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'id',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<LocalChunkMetadata, LocalChunkMetadata, QAfterFilterCondition>
      identityIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'identity',
      ));
    });
  }

  QueryBuilder<LocalChunkMetadata, LocalChunkMetadata, QAfterFilterCondition>
      identityIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'identity',
      ));
    });
  }

  QueryBuilder<LocalChunkMetadata, LocalChunkMetadata, QAfterFilterCondition>
      integrityIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'integrity',
      ));
    });
  }

  QueryBuilder<LocalChunkMetadata, LocalChunkMetadata, QAfterFilterCondition>
      integrityIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'integrity',
      ));
    });
  }

  QueryBuilder<LocalChunkMetadata, LocalChunkMetadata, QAfterFilterCondition>
      timingIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'timing',
      ));
    });
  }

  QueryBuilder<LocalChunkMetadata, LocalChunkMetadata, QAfterFilterCondition>
      timingIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'timing',
      ));
    });
  }
}

extension LocalChunkMetadataQueryObject
    on QueryBuilder<LocalChunkMetadata, LocalChunkMetadata, QFilterCondition> {
  QueryBuilder<LocalChunkMetadata, LocalChunkMetadata, QAfterFilterCondition>
      capture(FilterQuery<EmbeddedCapture> q) {
    return QueryBuilder.apply(this, (query) {
      return query.object(q, r'capture');
    });
  }

  QueryBuilder<LocalChunkMetadata, LocalChunkMetadata, QAfterFilterCondition>
      captureConditions(FilterQuery<EmbeddedCaptureConditions> q) {
    return QueryBuilder.apply(this, (query) {
      return query.object(q, r'captureConditions');
    });
  }

  QueryBuilder<LocalChunkMetadata, LocalChunkMetadata, QAfterFilterCondition>
      collectorAuthored(FilterQuery<EmbeddedCollectorAuthored> q) {
    return QueryBuilder.apply(this, (query) {
      return query.object(q, r'collectorAuthored');
    });
  }

  QueryBuilder<LocalChunkMetadata, LocalChunkMetadata, QAfterFilterCondition>
      deviceContext(FilterQuery<EmbeddedDeviceContext> q) {
    return QueryBuilder.apply(this, (query) {
      return query.object(q, r'deviceContext');
    });
  }

  QueryBuilder<LocalChunkMetadata, LocalChunkMetadata, QAfterFilterCondition>
      identity(FilterQuery<EmbeddedIdentity> q) {
    return QueryBuilder.apply(this, (query) {
      return query.object(q, r'identity');
    });
  }

  QueryBuilder<LocalChunkMetadata, LocalChunkMetadata, QAfterFilterCondition>
      integrity(FilterQuery<EmbeddedIntegrity> q) {
    return QueryBuilder.apply(this, (query) {
      return query.object(q, r'integrity');
    });
  }

  QueryBuilder<LocalChunkMetadata, LocalChunkMetadata, QAfterFilterCondition>
      timing(FilterQuery<EmbeddedTiming> q) {
    return QueryBuilder.apply(this, (query) {
      return query.object(q, r'timing');
    });
  }
}

extension LocalChunkMetadataQueryLinks
    on QueryBuilder<LocalChunkMetadata, LocalChunkMetadata, QFilterCondition> {}

extension LocalChunkMetadataQuerySortBy
    on QueryBuilder<LocalChunkMetadata, LocalChunkMetadata, QSortBy> {
  QueryBuilder<LocalChunkMetadata, LocalChunkMetadata, QAfterSortBy>
      sortByChunkId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chunkId', Sort.asc);
    });
  }

  QueryBuilder<LocalChunkMetadata, LocalChunkMetadata, QAfterSortBy>
      sortByChunkIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chunkId', Sort.desc);
    });
  }
}

extension LocalChunkMetadataQuerySortThenBy
    on QueryBuilder<LocalChunkMetadata, LocalChunkMetadata, QSortThenBy> {
  QueryBuilder<LocalChunkMetadata, LocalChunkMetadata, QAfterSortBy>
      thenByChunkId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chunkId', Sort.asc);
    });
  }

  QueryBuilder<LocalChunkMetadata, LocalChunkMetadata, QAfterSortBy>
      thenByChunkIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chunkId', Sort.desc);
    });
  }

  QueryBuilder<LocalChunkMetadata, LocalChunkMetadata, QAfterSortBy>
      thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<LocalChunkMetadata, LocalChunkMetadata, QAfterSortBy>
      thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }
}

extension LocalChunkMetadataQueryWhereDistinct
    on QueryBuilder<LocalChunkMetadata, LocalChunkMetadata, QDistinct> {
  QueryBuilder<LocalChunkMetadata, LocalChunkMetadata, QDistinct>
      distinctByChunkId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'chunkId', caseSensitive: caseSensitive);
    });
  }
}

extension LocalChunkMetadataQueryProperty
    on QueryBuilder<LocalChunkMetadata, LocalChunkMetadata, QQueryProperty> {
  QueryBuilder<LocalChunkMetadata, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<LocalChunkMetadata, EmbeddedCapture?, QQueryOperations>
      captureProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'capture');
    });
  }

  QueryBuilder<LocalChunkMetadata, EmbeddedCaptureConditions?, QQueryOperations>
      captureConditionsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'captureConditions');
    });
  }

  QueryBuilder<LocalChunkMetadata, String, QQueryOperations> chunkIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'chunkId');
    });
  }

  QueryBuilder<LocalChunkMetadata, EmbeddedCollectorAuthored?, QQueryOperations>
      collectorAuthoredProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'collectorAuthored');
    });
  }

  QueryBuilder<LocalChunkMetadata, EmbeddedDeviceContext?, QQueryOperations>
      deviceContextProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'deviceContext');
    });
  }

  QueryBuilder<LocalChunkMetadata, EmbeddedIdentity?, QQueryOperations>
      identityProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'identity');
    });
  }

  QueryBuilder<LocalChunkMetadata, EmbeddedIntegrity?, QQueryOperations>
      integrityProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'integrity');
    });
  }

  QueryBuilder<LocalChunkMetadata, EmbeddedTiming?, QQueryOperations>
      timingProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'timing');
    });
  }
}
