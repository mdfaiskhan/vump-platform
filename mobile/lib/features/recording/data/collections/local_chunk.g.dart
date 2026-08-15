// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'local_chunk.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetLocalChunkCollection on Isar {
  IsarCollection<LocalChunk> get localChunks => this.collection();
}

const LocalChunkSchema = CollectionSchema(
  name: r'LocalChunk',
  id: -8062280676810480142,
  properties: {
    r'checksumSha256': PropertySchema(
      id: 0,
      name: r'checksumSha256',
      type: IsarType.string,
    ),
    r'chunkId': PropertySchema(
      id: 1,
      name: r'chunkId',
      type: IsarType.string,
    ),
    r'fileSizeBytes': PropertySchema(
      id: 2,
      name: r'fileSizeBytes',
      type: IsarType.long,
    ),
    r'localDeletedAt': PropertySchema(
      id: 3,
      name: r'localDeletedAt',
      type: IsarType.dateTime,
    ),
    r'localFilePath': PropertySchema(
      id: 4,
      name: r'localFilePath',
      type: IsarType.string,
    ),
    r's3ObjectKey': PropertySchema(
      id: 5,
      name: r's3ObjectKey',
      type: IsarType.string,
    ),
    r'sequenceIndex': PropertySchema(
      id: 6,
      name: r'sequenceIndex',
      type: IsarType.long,
    ),
    r'sessionId': PropertySchema(
      id: 7,
      name: r'sessionId',
      type: IsarType.string,
    ),
    r'status': PropertySchema(
      id: 8,
      name: r'status',
      type: IsarType.string,
    )
  },
  estimateSize: _localChunkEstimateSize,
  serialize: _localChunkSerialize,
  deserialize: _localChunkDeserialize,
  deserializeProp: _localChunkDeserializeProp,
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
    ),
    r'sessionId': IndexSchema(
      id: 6949518585047923839,
      name: r'sessionId',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'sessionId',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    )
  },
  links: {},
  embeddedSchemas: {},
  getId: _localChunkGetId,
  getLinks: _localChunkGetLinks,
  attach: _localChunkAttach,
  version: '3.1.0+1',
);

int _localChunkEstimateSize(
  LocalChunk object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.checksumSha256.length * 3;
  bytesCount += 3 + object.chunkId.length * 3;
  bytesCount += 3 + object.localFilePath.length * 3;
  {
    final value = object.s3ObjectKey;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.sessionId.length * 3;
  bytesCount += 3 + object.status.length * 3;
  return bytesCount;
}

void _localChunkSerialize(
  LocalChunk object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.checksumSha256);
  writer.writeString(offsets[1], object.chunkId);
  writer.writeLong(offsets[2], object.fileSizeBytes);
  writer.writeDateTime(offsets[3], object.localDeletedAt);
  writer.writeString(offsets[4], object.localFilePath);
  writer.writeString(offsets[5], object.s3ObjectKey);
  writer.writeLong(offsets[6], object.sequenceIndex);
  writer.writeString(offsets[7], object.sessionId);
  writer.writeString(offsets[8], object.status);
}

LocalChunk _localChunkDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = LocalChunk();
  object.checksumSha256 = reader.readString(offsets[0]);
  object.chunkId = reader.readString(offsets[1]);
  object.fileSizeBytes = reader.readLong(offsets[2]);
  object.id = id;
  object.localDeletedAt = reader.readDateTimeOrNull(offsets[3]);
  object.localFilePath = reader.readString(offsets[4]);
  object.s3ObjectKey = reader.readStringOrNull(offsets[5]);
  object.sequenceIndex = reader.readLong(offsets[6]);
  object.sessionId = reader.readString(offsets[7]);
  object.status = reader.readString(offsets[8]);
  return object;
}

P _localChunkDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readString(offset)) as P;
    case 1:
      return (reader.readString(offset)) as P;
    case 2:
      return (reader.readLong(offset)) as P;
    case 3:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 4:
      return (reader.readString(offset)) as P;
    case 5:
      return (reader.readStringOrNull(offset)) as P;
    case 6:
      return (reader.readLong(offset)) as P;
    case 7:
      return (reader.readString(offset)) as P;
    case 8:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _localChunkGetId(LocalChunk object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _localChunkGetLinks(LocalChunk object) {
  return [];
}

void _localChunkAttach(IsarCollection<dynamic> col, Id id, LocalChunk object) {
  object.id = id;
}

extension LocalChunkByIndex on IsarCollection<LocalChunk> {
  Future<LocalChunk?> getByChunkId(String chunkId) {
    return getByIndex(r'chunkId', [chunkId]);
  }

  LocalChunk? getByChunkIdSync(String chunkId) {
    return getByIndexSync(r'chunkId', [chunkId]);
  }

  Future<bool> deleteByChunkId(String chunkId) {
    return deleteByIndex(r'chunkId', [chunkId]);
  }

  bool deleteByChunkIdSync(String chunkId) {
    return deleteByIndexSync(r'chunkId', [chunkId]);
  }

  Future<List<LocalChunk?>> getAllByChunkId(List<String> chunkIdValues) {
    final values = chunkIdValues.map((e) => [e]).toList();
    return getAllByIndex(r'chunkId', values);
  }

  List<LocalChunk?> getAllByChunkIdSync(List<String> chunkIdValues) {
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

  Future<Id> putByChunkId(LocalChunk object) {
    return putByIndex(r'chunkId', object);
  }

  Id putByChunkIdSync(LocalChunk object, {bool saveLinks = true}) {
    return putByIndexSync(r'chunkId', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByChunkId(List<LocalChunk> objects) {
    return putAllByIndex(r'chunkId', objects);
  }

  List<Id> putAllByChunkIdSync(List<LocalChunk> objects,
      {bool saveLinks = true}) {
    return putAllByIndexSync(r'chunkId', objects, saveLinks: saveLinks);
  }
}

extension LocalChunkQueryWhereSort
    on QueryBuilder<LocalChunk, LocalChunk, QWhere> {
  QueryBuilder<LocalChunk, LocalChunk, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension LocalChunkQueryWhere
    on QueryBuilder<LocalChunk, LocalChunk, QWhereClause> {
  QueryBuilder<LocalChunk, LocalChunk, QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<LocalChunk, LocalChunk, QAfterWhereClause> idNotEqualTo(Id id) {
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

  QueryBuilder<LocalChunk, LocalChunk, QAfterWhereClause> idGreaterThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<LocalChunk, LocalChunk, QAfterWhereClause> idLessThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<LocalChunk, LocalChunk, QAfterWhereClause> idBetween(
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

  QueryBuilder<LocalChunk, LocalChunk, QAfterWhereClause> chunkIdEqualTo(
      String chunkId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'chunkId',
        value: [chunkId],
      ));
    });
  }

  QueryBuilder<LocalChunk, LocalChunk, QAfterWhereClause> chunkIdNotEqualTo(
      String chunkId) {
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

  QueryBuilder<LocalChunk, LocalChunk, QAfterWhereClause> sessionIdEqualTo(
      String sessionId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'sessionId',
        value: [sessionId],
      ));
    });
  }

  QueryBuilder<LocalChunk, LocalChunk, QAfterWhereClause> sessionIdNotEqualTo(
      String sessionId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'sessionId',
              lower: [],
              upper: [sessionId],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'sessionId',
              lower: [sessionId],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'sessionId',
              lower: [sessionId],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'sessionId',
              lower: [],
              upper: [sessionId],
              includeUpper: false,
            ));
      }
    });
  }
}

extension LocalChunkQueryFilter
    on QueryBuilder<LocalChunk, LocalChunk, QFilterCondition> {
  QueryBuilder<LocalChunk, LocalChunk, QAfterFilterCondition>
      checksumSha256EqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'checksumSha256',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalChunk, LocalChunk, QAfterFilterCondition>
      checksumSha256GreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'checksumSha256',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalChunk, LocalChunk, QAfterFilterCondition>
      checksumSha256LessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'checksumSha256',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalChunk, LocalChunk, QAfterFilterCondition>
      checksumSha256Between(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'checksumSha256',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalChunk, LocalChunk, QAfterFilterCondition>
      checksumSha256StartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'checksumSha256',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalChunk, LocalChunk, QAfterFilterCondition>
      checksumSha256EndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'checksumSha256',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalChunk, LocalChunk, QAfterFilterCondition>
      checksumSha256Contains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'checksumSha256',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalChunk, LocalChunk, QAfterFilterCondition>
      checksumSha256Matches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'checksumSha256',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalChunk, LocalChunk, QAfterFilterCondition>
      checksumSha256IsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'checksumSha256',
        value: '',
      ));
    });
  }

  QueryBuilder<LocalChunk, LocalChunk, QAfterFilterCondition>
      checksumSha256IsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'checksumSha256',
        value: '',
      ));
    });
  }

  QueryBuilder<LocalChunk, LocalChunk, QAfterFilterCondition> chunkIdEqualTo(
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

  QueryBuilder<LocalChunk, LocalChunk, QAfterFilterCondition>
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

  QueryBuilder<LocalChunk, LocalChunk, QAfterFilterCondition> chunkIdLessThan(
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

  QueryBuilder<LocalChunk, LocalChunk, QAfterFilterCondition> chunkIdBetween(
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

  QueryBuilder<LocalChunk, LocalChunk, QAfterFilterCondition> chunkIdStartsWith(
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

  QueryBuilder<LocalChunk, LocalChunk, QAfterFilterCondition> chunkIdEndsWith(
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

  QueryBuilder<LocalChunk, LocalChunk, QAfterFilterCondition> chunkIdContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'chunkId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalChunk, LocalChunk, QAfterFilterCondition> chunkIdMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'chunkId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalChunk, LocalChunk, QAfterFilterCondition> chunkIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'chunkId',
        value: '',
      ));
    });
  }

  QueryBuilder<LocalChunk, LocalChunk, QAfterFilterCondition>
      chunkIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'chunkId',
        value: '',
      ));
    });
  }

  QueryBuilder<LocalChunk, LocalChunk, QAfterFilterCondition>
      fileSizeBytesEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'fileSizeBytes',
        value: value,
      ));
    });
  }

  QueryBuilder<LocalChunk, LocalChunk, QAfterFilterCondition>
      fileSizeBytesGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'fileSizeBytes',
        value: value,
      ));
    });
  }

  QueryBuilder<LocalChunk, LocalChunk, QAfterFilterCondition>
      fileSizeBytesLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'fileSizeBytes',
        value: value,
      ));
    });
  }

  QueryBuilder<LocalChunk, LocalChunk, QAfterFilterCondition>
      fileSizeBytesBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'fileSizeBytes',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<LocalChunk, LocalChunk, QAfterFilterCondition> idEqualTo(
      Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<LocalChunk, LocalChunk, QAfterFilterCondition> idGreaterThan(
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

  QueryBuilder<LocalChunk, LocalChunk, QAfterFilterCondition> idLessThan(
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

  QueryBuilder<LocalChunk, LocalChunk, QAfterFilterCondition> idBetween(
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

  QueryBuilder<LocalChunk, LocalChunk, QAfterFilterCondition>
      localDeletedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'localDeletedAt',
      ));
    });
  }

  QueryBuilder<LocalChunk, LocalChunk, QAfterFilterCondition>
      localDeletedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'localDeletedAt',
      ));
    });
  }

  QueryBuilder<LocalChunk, LocalChunk, QAfterFilterCondition>
      localDeletedAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'localDeletedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<LocalChunk, LocalChunk, QAfterFilterCondition>
      localDeletedAtGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'localDeletedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<LocalChunk, LocalChunk, QAfterFilterCondition>
      localDeletedAtLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'localDeletedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<LocalChunk, LocalChunk, QAfterFilterCondition>
      localDeletedAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'localDeletedAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<LocalChunk, LocalChunk, QAfterFilterCondition>
      localFilePathEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'localFilePath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalChunk, LocalChunk, QAfterFilterCondition>
      localFilePathGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'localFilePath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalChunk, LocalChunk, QAfterFilterCondition>
      localFilePathLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'localFilePath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalChunk, LocalChunk, QAfterFilterCondition>
      localFilePathBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'localFilePath',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalChunk, LocalChunk, QAfterFilterCondition>
      localFilePathStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'localFilePath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalChunk, LocalChunk, QAfterFilterCondition>
      localFilePathEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'localFilePath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalChunk, LocalChunk, QAfterFilterCondition>
      localFilePathContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'localFilePath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalChunk, LocalChunk, QAfterFilterCondition>
      localFilePathMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'localFilePath',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalChunk, LocalChunk, QAfterFilterCondition>
      localFilePathIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'localFilePath',
        value: '',
      ));
    });
  }

  QueryBuilder<LocalChunk, LocalChunk, QAfterFilterCondition>
      localFilePathIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'localFilePath',
        value: '',
      ));
    });
  }

  QueryBuilder<LocalChunk, LocalChunk, QAfterFilterCondition>
      s3ObjectKeyIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r's3ObjectKey',
      ));
    });
  }

  QueryBuilder<LocalChunk, LocalChunk, QAfterFilterCondition>
      s3ObjectKeyIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r's3ObjectKey',
      ));
    });
  }

  QueryBuilder<LocalChunk, LocalChunk, QAfterFilterCondition>
      s3ObjectKeyEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r's3ObjectKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalChunk, LocalChunk, QAfterFilterCondition>
      s3ObjectKeyGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r's3ObjectKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalChunk, LocalChunk, QAfterFilterCondition>
      s3ObjectKeyLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r's3ObjectKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalChunk, LocalChunk, QAfterFilterCondition>
      s3ObjectKeyBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r's3ObjectKey',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalChunk, LocalChunk, QAfterFilterCondition>
      s3ObjectKeyStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r's3ObjectKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalChunk, LocalChunk, QAfterFilterCondition>
      s3ObjectKeyEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r's3ObjectKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalChunk, LocalChunk, QAfterFilterCondition>
      s3ObjectKeyContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r's3ObjectKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalChunk, LocalChunk, QAfterFilterCondition>
      s3ObjectKeyMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r's3ObjectKey',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalChunk, LocalChunk, QAfterFilterCondition>
      s3ObjectKeyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r's3ObjectKey',
        value: '',
      ));
    });
  }

  QueryBuilder<LocalChunk, LocalChunk, QAfterFilterCondition>
      s3ObjectKeyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r's3ObjectKey',
        value: '',
      ));
    });
  }

  QueryBuilder<LocalChunk, LocalChunk, QAfterFilterCondition>
      sequenceIndexEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'sequenceIndex',
        value: value,
      ));
    });
  }

  QueryBuilder<LocalChunk, LocalChunk, QAfterFilterCondition>
      sequenceIndexGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'sequenceIndex',
        value: value,
      ));
    });
  }

  QueryBuilder<LocalChunk, LocalChunk, QAfterFilterCondition>
      sequenceIndexLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'sequenceIndex',
        value: value,
      ));
    });
  }

  QueryBuilder<LocalChunk, LocalChunk, QAfterFilterCondition>
      sequenceIndexBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'sequenceIndex',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<LocalChunk, LocalChunk, QAfterFilterCondition> sessionIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'sessionId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalChunk, LocalChunk, QAfterFilterCondition>
      sessionIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'sessionId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalChunk, LocalChunk, QAfterFilterCondition> sessionIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'sessionId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalChunk, LocalChunk, QAfterFilterCondition> sessionIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'sessionId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalChunk, LocalChunk, QAfterFilterCondition>
      sessionIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'sessionId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalChunk, LocalChunk, QAfterFilterCondition> sessionIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'sessionId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalChunk, LocalChunk, QAfterFilterCondition> sessionIdContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'sessionId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalChunk, LocalChunk, QAfterFilterCondition> sessionIdMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'sessionId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalChunk, LocalChunk, QAfterFilterCondition>
      sessionIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'sessionId',
        value: '',
      ));
    });
  }

  QueryBuilder<LocalChunk, LocalChunk, QAfterFilterCondition>
      sessionIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'sessionId',
        value: '',
      ));
    });
  }

  QueryBuilder<LocalChunk, LocalChunk, QAfterFilterCondition> statusEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'status',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalChunk, LocalChunk, QAfterFilterCondition> statusGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'status',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalChunk, LocalChunk, QAfterFilterCondition> statusLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'status',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalChunk, LocalChunk, QAfterFilterCondition> statusBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'status',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalChunk, LocalChunk, QAfterFilterCondition> statusStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'status',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalChunk, LocalChunk, QAfterFilterCondition> statusEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'status',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalChunk, LocalChunk, QAfterFilterCondition> statusContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'status',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalChunk, LocalChunk, QAfterFilterCondition> statusMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'status',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalChunk, LocalChunk, QAfterFilterCondition> statusIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'status',
        value: '',
      ));
    });
  }

  QueryBuilder<LocalChunk, LocalChunk, QAfterFilterCondition>
      statusIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'status',
        value: '',
      ));
    });
  }
}

extension LocalChunkQueryObject
    on QueryBuilder<LocalChunk, LocalChunk, QFilterCondition> {}

extension LocalChunkQueryLinks
    on QueryBuilder<LocalChunk, LocalChunk, QFilterCondition> {}

extension LocalChunkQuerySortBy
    on QueryBuilder<LocalChunk, LocalChunk, QSortBy> {
  QueryBuilder<LocalChunk, LocalChunk, QAfterSortBy> sortByChecksumSha256() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'checksumSha256', Sort.asc);
    });
  }

  QueryBuilder<LocalChunk, LocalChunk, QAfterSortBy>
      sortByChecksumSha256Desc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'checksumSha256', Sort.desc);
    });
  }

  QueryBuilder<LocalChunk, LocalChunk, QAfterSortBy> sortByChunkId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chunkId', Sort.asc);
    });
  }

  QueryBuilder<LocalChunk, LocalChunk, QAfterSortBy> sortByChunkIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chunkId', Sort.desc);
    });
  }

  QueryBuilder<LocalChunk, LocalChunk, QAfterSortBy> sortByFileSizeBytes() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fileSizeBytes', Sort.asc);
    });
  }

  QueryBuilder<LocalChunk, LocalChunk, QAfterSortBy> sortByFileSizeBytesDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fileSizeBytes', Sort.desc);
    });
  }

  QueryBuilder<LocalChunk, LocalChunk, QAfterSortBy> sortByLocalDeletedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'localDeletedAt', Sort.asc);
    });
  }

  QueryBuilder<LocalChunk, LocalChunk, QAfterSortBy>
      sortByLocalDeletedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'localDeletedAt', Sort.desc);
    });
  }

  QueryBuilder<LocalChunk, LocalChunk, QAfterSortBy> sortByLocalFilePath() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'localFilePath', Sort.asc);
    });
  }

  QueryBuilder<LocalChunk, LocalChunk, QAfterSortBy> sortByLocalFilePathDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'localFilePath', Sort.desc);
    });
  }

  QueryBuilder<LocalChunk, LocalChunk, QAfterSortBy> sortByS3ObjectKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r's3ObjectKey', Sort.asc);
    });
  }

  QueryBuilder<LocalChunk, LocalChunk, QAfterSortBy> sortByS3ObjectKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r's3ObjectKey', Sort.desc);
    });
  }

  QueryBuilder<LocalChunk, LocalChunk, QAfterSortBy> sortBySequenceIndex() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sequenceIndex', Sort.asc);
    });
  }

  QueryBuilder<LocalChunk, LocalChunk, QAfterSortBy> sortBySequenceIndexDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sequenceIndex', Sort.desc);
    });
  }

  QueryBuilder<LocalChunk, LocalChunk, QAfterSortBy> sortBySessionId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sessionId', Sort.asc);
    });
  }

  QueryBuilder<LocalChunk, LocalChunk, QAfterSortBy> sortBySessionIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sessionId', Sort.desc);
    });
  }

  QueryBuilder<LocalChunk, LocalChunk, QAfterSortBy> sortByStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.asc);
    });
  }

  QueryBuilder<LocalChunk, LocalChunk, QAfterSortBy> sortByStatusDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.desc);
    });
  }
}

extension LocalChunkQuerySortThenBy
    on QueryBuilder<LocalChunk, LocalChunk, QSortThenBy> {
  QueryBuilder<LocalChunk, LocalChunk, QAfterSortBy> thenByChecksumSha256() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'checksumSha256', Sort.asc);
    });
  }

  QueryBuilder<LocalChunk, LocalChunk, QAfterSortBy>
      thenByChecksumSha256Desc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'checksumSha256', Sort.desc);
    });
  }

  QueryBuilder<LocalChunk, LocalChunk, QAfterSortBy> thenByChunkId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chunkId', Sort.asc);
    });
  }

  QueryBuilder<LocalChunk, LocalChunk, QAfterSortBy> thenByChunkIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chunkId', Sort.desc);
    });
  }

  QueryBuilder<LocalChunk, LocalChunk, QAfterSortBy> thenByFileSizeBytes() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fileSizeBytes', Sort.asc);
    });
  }

  QueryBuilder<LocalChunk, LocalChunk, QAfterSortBy> thenByFileSizeBytesDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fileSizeBytes', Sort.desc);
    });
  }

  QueryBuilder<LocalChunk, LocalChunk, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<LocalChunk, LocalChunk, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<LocalChunk, LocalChunk, QAfterSortBy> thenByLocalDeletedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'localDeletedAt', Sort.asc);
    });
  }

  QueryBuilder<LocalChunk, LocalChunk, QAfterSortBy>
      thenByLocalDeletedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'localDeletedAt', Sort.desc);
    });
  }

  QueryBuilder<LocalChunk, LocalChunk, QAfterSortBy> thenByLocalFilePath() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'localFilePath', Sort.asc);
    });
  }

  QueryBuilder<LocalChunk, LocalChunk, QAfterSortBy> thenByLocalFilePathDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'localFilePath', Sort.desc);
    });
  }

  QueryBuilder<LocalChunk, LocalChunk, QAfterSortBy> thenByS3ObjectKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r's3ObjectKey', Sort.asc);
    });
  }

  QueryBuilder<LocalChunk, LocalChunk, QAfterSortBy> thenByS3ObjectKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r's3ObjectKey', Sort.desc);
    });
  }

  QueryBuilder<LocalChunk, LocalChunk, QAfterSortBy> thenBySequenceIndex() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sequenceIndex', Sort.asc);
    });
  }

  QueryBuilder<LocalChunk, LocalChunk, QAfterSortBy> thenBySequenceIndexDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sequenceIndex', Sort.desc);
    });
  }

  QueryBuilder<LocalChunk, LocalChunk, QAfterSortBy> thenBySessionId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sessionId', Sort.asc);
    });
  }

  QueryBuilder<LocalChunk, LocalChunk, QAfterSortBy> thenBySessionIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sessionId', Sort.desc);
    });
  }

  QueryBuilder<LocalChunk, LocalChunk, QAfterSortBy> thenByStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.asc);
    });
  }

  QueryBuilder<LocalChunk, LocalChunk, QAfterSortBy> thenByStatusDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.desc);
    });
  }
}

extension LocalChunkQueryWhereDistinct
    on QueryBuilder<LocalChunk, LocalChunk, QDistinct> {
  QueryBuilder<LocalChunk, LocalChunk, QDistinct> distinctByChecksumSha256(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'checksumSha256',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LocalChunk, LocalChunk, QDistinct> distinctByChunkId(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'chunkId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LocalChunk, LocalChunk, QDistinct> distinctByFileSizeBytes() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'fileSizeBytes');
    });
  }

  QueryBuilder<LocalChunk, LocalChunk, QDistinct> distinctByLocalDeletedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'localDeletedAt');
    });
  }

  QueryBuilder<LocalChunk, LocalChunk, QDistinct> distinctByLocalFilePath(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'localFilePath',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LocalChunk, LocalChunk, QDistinct> distinctByS3ObjectKey(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r's3ObjectKey', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LocalChunk, LocalChunk, QDistinct> distinctBySequenceIndex() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'sequenceIndex');
    });
  }

  QueryBuilder<LocalChunk, LocalChunk, QDistinct> distinctBySessionId(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'sessionId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LocalChunk, LocalChunk, QDistinct> distinctByStatus(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'status', caseSensitive: caseSensitive);
    });
  }
}

extension LocalChunkQueryProperty
    on QueryBuilder<LocalChunk, LocalChunk, QQueryProperty> {
  QueryBuilder<LocalChunk, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<LocalChunk, String, QQueryOperations> checksumSha256Property() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'checksumSha256');
    });
  }

  QueryBuilder<LocalChunk, String, QQueryOperations> chunkIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'chunkId');
    });
  }

  QueryBuilder<LocalChunk, int, QQueryOperations> fileSizeBytesProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'fileSizeBytes');
    });
  }

  QueryBuilder<LocalChunk, DateTime?, QQueryOperations>
      localDeletedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'localDeletedAt');
    });
  }

  QueryBuilder<LocalChunk, String, QQueryOperations> localFilePathProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'localFilePath');
    });
  }

  QueryBuilder<LocalChunk, String?, QQueryOperations> s3ObjectKeyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r's3ObjectKey');
    });
  }

  QueryBuilder<LocalChunk, int, QQueryOperations> sequenceIndexProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'sequenceIndex');
    });
  }

  QueryBuilder<LocalChunk, String, QQueryOperations> sessionIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'sessionId');
    });
  }

  QueryBuilder<LocalChunk, String, QQueryOperations> statusProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'status');
    });
  }
}
