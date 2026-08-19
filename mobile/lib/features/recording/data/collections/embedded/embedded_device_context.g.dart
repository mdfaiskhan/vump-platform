// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'embedded_device_context.dart';

// **************************************************************************
// IsarEmbeddedGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

const EmbeddedDeviceContextSchema = Schema(
  name: r'EmbeddedDeviceContext',
  id: 379889751690488739,
  properties: {
    r'appVersion': PropertySchema(
      id: 0,
      name: r'appVersion',
      type: IsarType.string,
    ),
    r'deviceModel': PropertySchema(
      id: 1,
      name: r'deviceModel',
      type: IsarType.string,
    ),
    r'osVersion': PropertySchema(
      id: 2,
      name: r'osVersion',
      type: IsarType.string,
    ),
  },
  estimateSize: _embeddedDeviceContextEstimateSize,
  serialize: _embeddedDeviceContextSerialize,
  deserialize: _embeddedDeviceContextDeserialize,
  deserializeProp: _embeddedDeviceContextDeserializeProp,
);

int _embeddedDeviceContextEstimateSize(
  EmbeddedDeviceContext object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  {
    final value = object.appVersion;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.deviceModel;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.osVersion;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  return bytesCount;
}

void _embeddedDeviceContextSerialize(
  EmbeddedDeviceContext object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.appVersion);
  writer.writeString(offsets[1], object.deviceModel);
  writer.writeString(offsets[2], object.osVersion);
}

EmbeddedDeviceContext _embeddedDeviceContextDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = EmbeddedDeviceContext();
  object.appVersion = reader.readStringOrNull(offsets[0]);
  object.deviceModel = reader.readStringOrNull(offsets[1]);
  object.osVersion = reader.readStringOrNull(offsets[2]);
  return object;
}

P _embeddedDeviceContextDeserializeProp<P>(
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
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

extension EmbeddedDeviceContextQueryFilter
    on
        QueryBuilder<
          EmbeddedDeviceContext,
          EmbeddedDeviceContext,
          QFilterCondition
        > {
  QueryBuilder<
    EmbeddedDeviceContext,
    EmbeddedDeviceContext,
    QAfterFilterCondition
  >
  appVersionIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'appVersion'),
      );
    });
  }

  QueryBuilder<
    EmbeddedDeviceContext,
    EmbeddedDeviceContext,
    QAfterFilterCondition
  >
  appVersionIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'appVersion'),
      );
    });
  }

  QueryBuilder<
    EmbeddedDeviceContext,
    EmbeddedDeviceContext,
    QAfterFilterCondition
  >
  appVersionEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'appVersion',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    EmbeddedDeviceContext,
    EmbeddedDeviceContext,
    QAfterFilterCondition
  >
  appVersionGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'appVersion',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    EmbeddedDeviceContext,
    EmbeddedDeviceContext,
    QAfterFilterCondition
  >
  appVersionLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'appVersion',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    EmbeddedDeviceContext,
    EmbeddedDeviceContext,
    QAfterFilterCondition
  >
  appVersionBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'appVersion',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    EmbeddedDeviceContext,
    EmbeddedDeviceContext,
    QAfterFilterCondition
  >
  appVersionStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'appVersion',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    EmbeddedDeviceContext,
    EmbeddedDeviceContext,
    QAfterFilterCondition
  >
  appVersionEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'appVersion',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    EmbeddedDeviceContext,
    EmbeddedDeviceContext,
    QAfterFilterCondition
  >
  appVersionContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'appVersion',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    EmbeddedDeviceContext,
    EmbeddedDeviceContext,
    QAfterFilterCondition
  >
  appVersionMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'appVersion',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    EmbeddedDeviceContext,
    EmbeddedDeviceContext,
    QAfterFilterCondition
  >
  appVersionIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'appVersion', value: ''),
      );
    });
  }

  QueryBuilder<
    EmbeddedDeviceContext,
    EmbeddedDeviceContext,
    QAfterFilterCondition
  >
  appVersionIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'appVersion', value: ''),
      );
    });
  }

  QueryBuilder<
    EmbeddedDeviceContext,
    EmbeddedDeviceContext,
    QAfterFilterCondition
  >
  deviceModelIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'deviceModel'),
      );
    });
  }

  QueryBuilder<
    EmbeddedDeviceContext,
    EmbeddedDeviceContext,
    QAfterFilterCondition
  >
  deviceModelIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'deviceModel'),
      );
    });
  }

  QueryBuilder<
    EmbeddedDeviceContext,
    EmbeddedDeviceContext,
    QAfterFilterCondition
  >
  deviceModelEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'deviceModel',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    EmbeddedDeviceContext,
    EmbeddedDeviceContext,
    QAfterFilterCondition
  >
  deviceModelGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'deviceModel',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    EmbeddedDeviceContext,
    EmbeddedDeviceContext,
    QAfterFilterCondition
  >
  deviceModelLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'deviceModel',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    EmbeddedDeviceContext,
    EmbeddedDeviceContext,
    QAfterFilterCondition
  >
  deviceModelBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'deviceModel',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    EmbeddedDeviceContext,
    EmbeddedDeviceContext,
    QAfterFilterCondition
  >
  deviceModelStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'deviceModel',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    EmbeddedDeviceContext,
    EmbeddedDeviceContext,
    QAfterFilterCondition
  >
  deviceModelEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'deviceModel',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    EmbeddedDeviceContext,
    EmbeddedDeviceContext,
    QAfterFilterCondition
  >
  deviceModelContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'deviceModel',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    EmbeddedDeviceContext,
    EmbeddedDeviceContext,
    QAfterFilterCondition
  >
  deviceModelMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'deviceModel',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    EmbeddedDeviceContext,
    EmbeddedDeviceContext,
    QAfterFilterCondition
  >
  deviceModelIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'deviceModel', value: ''),
      );
    });
  }

  QueryBuilder<
    EmbeddedDeviceContext,
    EmbeddedDeviceContext,
    QAfterFilterCondition
  >
  deviceModelIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'deviceModel', value: ''),
      );
    });
  }

  QueryBuilder<
    EmbeddedDeviceContext,
    EmbeddedDeviceContext,
    QAfterFilterCondition
  >
  osVersionIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'osVersion'),
      );
    });
  }

  QueryBuilder<
    EmbeddedDeviceContext,
    EmbeddedDeviceContext,
    QAfterFilterCondition
  >
  osVersionIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'osVersion'),
      );
    });
  }

  QueryBuilder<
    EmbeddedDeviceContext,
    EmbeddedDeviceContext,
    QAfterFilterCondition
  >
  osVersionEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'osVersion',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    EmbeddedDeviceContext,
    EmbeddedDeviceContext,
    QAfterFilterCondition
  >
  osVersionGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'osVersion',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    EmbeddedDeviceContext,
    EmbeddedDeviceContext,
    QAfterFilterCondition
  >
  osVersionLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'osVersion',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    EmbeddedDeviceContext,
    EmbeddedDeviceContext,
    QAfterFilterCondition
  >
  osVersionBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'osVersion',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    EmbeddedDeviceContext,
    EmbeddedDeviceContext,
    QAfterFilterCondition
  >
  osVersionStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'osVersion',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    EmbeddedDeviceContext,
    EmbeddedDeviceContext,
    QAfterFilterCondition
  >
  osVersionEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'osVersion',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    EmbeddedDeviceContext,
    EmbeddedDeviceContext,
    QAfterFilterCondition
  >
  osVersionContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'osVersion',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    EmbeddedDeviceContext,
    EmbeddedDeviceContext,
    QAfterFilterCondition
  >
  osVersionMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'osVersion',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    EmbeddedDeviceContext,
    EmbeddedDeviceContext,
    QAfterFilterCondition
  >
  osVersionIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'osVersion', value: ''),
      );
    });
  }

  QueryBuilder<
    EmbeddedDeviceContext,
    EmbeddedDeviceContext,
    QAfterFilterCondition
  >
  osVersionIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'osVersion', value: ''),
      );
    });
  }
}

extension EmbeddedDeviceContextQueryObject
    on
        QueryBuilder<
          EmbeddedDeviceContext,
          EmbeddedDeviceContext,
          QFilterCondition
        > {}
