// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'embedded_identity.dart';

// **************************************************************************
// IsarEmbeddedGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

const EmbeddedIdentitySchema = Schema(
  name: r'EmbeddedIdentity',
  id: 3658843347606614130,
  properties: {
    r'collectorId': PropertySchema(
      id: 0,
      name: r'collectorId',
      type: IsarType.string,
    ),
    r'deviceId': PropertySchema(
      id: 1,
      name: r'deviceId',
      type: IsarType.string,
    ),
    r'projectId': PropertySchema(
      id: 2,
      name: r'projectId',
      type: IsarType.string,
    ),
    r'sessionId': PropertySchema(
      id: 3,
      name: r'sessionId',
      type: IsarType.string,
    ),
    r'taskId': PropertySchema(id: 4, name: r'taskId', type: IsarType.string),
  },
  estimateSize: _embeddedIdentityEstimateSize,
  serialize: _embeddedIdentitySerialize,
  deserialize: _embeddedIdentityDeserialize,
  deserializeProp: _embeddedIdentityDeserializeProp,
);

int _embeddedIdentityEstimateSize(
  EmbeddedIdentity object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  {
    final value = object.collectorId;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.deviceId;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.projectId;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.sessionId;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.taskId;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  return bytesCount;
}

void _embeddedIdentitySerialize(
  EmbeddedIdentity object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.collectorId);
  writer.writeString(offsets[1], object.deviceId);
  writer.writeString(offsets[2], object.projectId);
  writer.writeString(offsets[3], object.sessionId);
  writer.writeString(offsets[4], object.taskId);
}

EmbeddedIdentity _embeddedIdentityDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = EmbeddedIdentity();
  object.collectorId = reader.readStringOrNull(offsets[0]);
  object.deviceId = reader.readStringOrNull(offsets[1]);
  object.projectId = reader.readStringOrNull(offsets[2]);
  object.sessionId = reader.readStringOrNull(offsets[3]);
  object.taskId = reader.readStringOrNull(offsets[4]);
  return object;
}

P _embeddedIdentityDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readStringOrNull(offset)) as P;
    case 1:
      return (reader.readStringOrNull(offset)) as P;
    case 2:
      return (reader.readStringOrNull(offset)) as P;
    case 3:
      return (reader.readStringOrNull(offset)) as P;
    case 4:
      return (reader.readStringOrNull(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

extension EmbeddedIdentityQueryFilter
    on QueryBuilder<EmbeddedIdentity, EmbeddedIdentity, QFilterCondition> {
  QueryBuilder<EmbeddedIdentity, EmbeddedIdentity, QAfterFilterCondition>
  collectorIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'collectorId'),
      );
    });
  }

  QueryBuilder<EmbeddedIdentity, EmbeddedIdentity, QAfterFilterCondition>
  collectorIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'collectorId'),
      );
    });
  }

  QueryBuilder<EmbeddedIdentity, EmbeddedIdentity, QAfterFilterCondition>
  collectorIdEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'collectorId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EmbeddedIdentity, EmbeddedIdentity, QAfterFilterCondition>
  collectorIdGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'collectorId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EmbeddedIdentity, EmbeddedIdentity, QAfterFilterCondition>
  collectorIdLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'collectorId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EmbeddedIdentity, EmbeddedIdentity, QAfterFilterCondition>
  collectorIdBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'collectorId',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EmbeddedIdentity, EmbeddedIdentity, QAfterFilterCondition>
  collectorIdStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'collectorId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EmbeddedIdentity, EmbeddedIdentity, QAfterFilterCondition>
  collectorIdEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'collectorId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EmbeddedIdentity, EmbeddedIdentity, QAfterFilterCondition>
  collectorIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'collectorId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EmbeddedIdentity, EmbeddedIdentity, QAfterFilterCondition>
  collectorIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'collectorId',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EmbeddedIdentity, EmbeddedIdentity, QAfterFilterCondition>
  collectorIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'collectorId', value: ''),
      );
    });
  }

  QueryBuilder<EmbeddedIdentity, EmbeddedIdentity, QAfterFilterCondition>
  collectorIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'collectorId', value: ''),
      );
    });
  }

  QueryBuilder<EmbeddedIdentity, EmbeddedIdentity, QAfterFilterCondition>
  deviceIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'deviceId'),
      );
    });
  }

  QueryBuilder<EmbeddedIdentity, EmbeddedIdentity, QAfterFilterCondition>
  deviceIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'deviceId'),
      );
    });
  }

  QueryBuilder<EmbeddedIdentity, EmbeddedIdentity, QAfterFilterCondition>
  deviceIdEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'deviceId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EmbeddedIdentity, EmbeddedIdentity, QAfterFilterCondition>
  deviceIdGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'deviceId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EmbeddedIdentity, EmbeddedIdentity, QAfterFilterCondition>
  deviceIdLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'deviceId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EmbeddedIdentity, EmbeddedIdentity, QAfterFilterCondition>
  deviceIdBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'deviceId',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EmbeddedIdentity, EmbeddedIdentity, QAfterFilterCondition>
  deviceIdStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'deviceId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EmbeddedIdentity, EmbeddedIdentity, QAfterFilterCondition>
  deviceIdEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'deviceId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EmbeddedIdentity, EmbeddedIdentity, QAfterFilterCondition>
  deviceIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'deviceId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EmbeddedIdentity, EmbeddedIdentity, QAfterFilterCondition>
  deviceIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'deviceId',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EmbeddedIdentity, EmbeddedIdentity, QAfterFilterCondition>
  deviceIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'deviceId', value: ''),
      );
    });
  }

  QueryBuilder<EmbeddedIdentity, EmbeddedIdentity, QAfterFilterCondition>
  deviceIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'deviceId', value: ''),
      );
    });
  }

  QueryBuilder<EmbeddedIdentity, EmbeddedIdentity, QAfterFilterCondition>
  projectIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'projectId'),
      );
    });
  }

  QueryBuilder<EmbeddedIdentity, EmbeddedIdentity, QAfterFilterCondition>
  projectIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'projectId'),
      );
    });
  }

  QueryBuilder<EmbeddedIdentity, EmbeddedIdentity, QAfterFilterCondition>
  projectIdEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'projectId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EmbeddedIdentity, EmbeddedIdentity, QAfterFilterCondition>
  projectIdGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'projectId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EmbeddedIdentity, EmbeddedIdentity, QAfterFilterCondition>
  projectIdLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'projectId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EmbeddedIdentity, EmbeddedIdentity, QAfterFilterCondition>
  projectIdBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'projectId',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EmbeddedIdentity, EmbeddedIdentity, QAfterFilterCondition>
  projectIdStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'projectId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EmbeddedIdentity, EmbeddedIdentity, QAfterFilterCondition>
  projectIdEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'projectId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EmbeddedIdentity, EmbeddedIdentity, QAfterFilterCondition>
  projectIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'projectId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EmbeddedIdentity, EmbeddedIdentity, QAfterFilterCondition>
  projectIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'projectId',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EmbeddedIdentity, EmbeddedIdentity, QAfterFilterCondition>
  projectIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'projectId', value: ''),
      );
    });
  }

  QueryBuilder<EmbeddedIdentity, EmbeddedIdentity, QAfterFilterCondition>
  projectIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'projectId', value: ''),
      );
    });
  }

  QueryBuilder<EmbeddedIdentity, EmbeddedIdentity, QAfterFilterCondition>
  sessionIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'sessionId'),
      );
    });
  }

  QueryBuilder<EmbeddedIdentity, EmbeddedIdentity, QAfterFilterCondition>
  sessionIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'sessionId'),
      );
    });
  }

  QueryBuilder<EmbeddedIdentity, EmbeddedIdentity, QAfterFilterCondition>
  sessionIdEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'sessionId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EmbeddedIdentity, EmbeddedIdentity, QAfterFilterCondition>
  sessionIdGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'sessionId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EmbeddedIdentity, EmbeddedIdentity, QAfterFilterCondition>
  sessionIdLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'sessionId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EmbeddedIdentity, EmbeddedIdentity, QAfterFilterCondition>
  sessionIdBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'sessionId',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EmbeddedIdentity, EmbeddedIdentity, QAfterFilterCondition>
  sessionIdStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'sessionId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EmbeddedIdentity, EmbeddedIdentity, QAfterFilterCondition>
  sessionIdEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'sessionId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EmbeddedIdentity, EmbeddedIdentity, QAfterFilterCondition>
  sessionIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'sessionId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EmbeddedIdentity, EmbeddedIdentity, QAfterFilterCondition>
  sessionIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'sessionId',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EmbeddedIdentity, EmbeddedIdentity, QAfterFilterCondition>
  sessionIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'sessionId', value: ''),
      );
    });
  }

  QueryBuilder<EmbeddedIdentity, EmbeddedIdentity, QAfterFilterCondition>
  sessionIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'sessionId', value: ''),
      );
    });
  }

  QueryBuilder<EmbeddedIdentity, EmbeddedIdentity, QAfterFilterCondition>
  taskIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'taskId'),
      );
    });
  }

  QueryBuilder<EmbeddedIdentity, EmbeddedIdentity, QAfterFilterCondition>
  taskIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'taskId'),
      );
    });
  }

  QueryBuilder<EmbeddedIdentity, EmbeddedIdentity, QAfterFilterCondition>
  taskIdEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'taskId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EmbeddedIdentity, EmbeddedIdentity, QAfterFilterCondition>
  taskIdGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'taskId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EmbeddedIdentity, EmbeddedIdentity, QAfterFilterCondition>
  taskIdLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'taskId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EmbeddedIdentity, EmbeddedIdentity, QAfterFilterCondition>
  taskIdBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'taskId',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EmbeddedIdentity, EmbeddedIdentity, QAfterFilterCondition>
  taskIdStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'taskId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EmbeddedIdentity, EmbeddedIdentity, QAfterFilterCondition>
  taskIdEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'taskId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EmbeddedIdentity, EmbeddedIdentity, QAfterFilterCondition>
  taskIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'taskId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EmbeddedIdentity, EmbeddedIdentity, QAfterFilterCondition>
  taskIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'taskId',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<EmbeddedIdentity, EmbeddedIdentity, QAfterFilterCondition>
  taskIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'taskId', value: ''),
      );
    });
  }

  QueryBuilder<EmbeddedIdentity, EmbeddedIdentity, QAfterFilterCondition>
  taskIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'taskId', value: ''),
      );
    });
  }
}

extension EmbeddedIdentityQueryObject
    on QueryBuilder<EmbeddedIdentity, EmbeddedIdentity, QFilterCondition> {}
