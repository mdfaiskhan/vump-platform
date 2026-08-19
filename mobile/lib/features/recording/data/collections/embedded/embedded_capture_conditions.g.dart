// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'embedded_capture_conditions.dart';

// **************************************************************************
// IsarEmbeddedGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

const EmbeddedCaptureConditionsSchema = Schema(
  name: r'EmbeddedCaptureConditions',
  id: 6114592010276828997,
  properties: {
    r'batteryPercent': PropertySchema(
      id: 0,
      name: r'batteryPercent',
      type: IsarType.long,
    ),
    r'gps': PropertySchema(
      id: 1,
      name: r'gps',
      type: IsarType.object,
      target: r'EmbeddedGpsFix',
    ),
    r'networkType': PropertySchema(
      id: 2,
      name: r'networkType',
      type: IsarType.string,
    )
  },
  estimateSize: _embeddedCaptureConditionsEstimateSize,
  serialize: _embeddedCaptureConditionsSerialize,
  deserialize: _embeddedCaptureConditionsDeserialize,
  deserializeProp: _embeddedCaptureConditionsDeserializeProp,
);

int _embeddedCaptureConditionsEstimateSize(
  EmbeddedCaptureConditions object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  {
    final value = object.gps;
    if (value != null) {
      bytesCount += 3 +
          EmbeddedGpsFixSchema.estimateSize(
              value, allOffsets[EmbeddedGpsFix]!, allOffsets);
    }
  }
  {
    final value = object.networkType;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  return bytesCount;
}

void _embeddedCaptureConditionsSerialize(
  EmbeddedCaptureConditions object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeLong(offsets[0], object.batteryPercent);
  writer.writeObject<EmbeddedGpsFix>(
    offsets[1],
    allOffsets,
    EmbeddedGpsFixSchema.serialize,
    object.gps,
  );
  writer.writeString(offsets[2], object.networkType);
}

EmbeddedCaptureConditions _embeddedCaptureConditionsDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = EmbeddedCaptureConditions();
  object.batteryPercent = reader.readLongOrNull(offsets[0]);
  object.gps = reader.readObjectOrNull<EmbeddedGpsFix>(
    offsets[1],
    EmbeddedGpsFixSchema.deserialize,
    allOffsets,
  );
  object.networkType = reader.readStringOrNull(offsets[2]);
  return object;
}

P _embeddedCaptureConditionsDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readLongOrNull(offset)) as P;
    case 1:
      return (reader.readObjectOrNull<EmbeddedGpsFix>(
        offset,
        EmbeddedGpsFixSchema.deserialize,
        allOffsets,
      )) as P;
    case 2:
      return (reader.readStringOrNull(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

extension EmbeddedCaptureConditionsQueryFilter on QueryBuilder<
    EmbeddedCaptureConditions, EmbeddedCaptureConditions, QFilterCondition> {
  QueryBuilder<EmbeddedCaptureConditions, EmbeddedCaptureConditions,
      QAfterFilterCondition> batteryPercentIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'batteryPercent',
      ));
    });
  }

  QueryBuilder<EmbeddedCaptureConditions, EmbeddedCaptureConditions,
      QAfterFilterCondition> batteryPercentIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'batteryPercent',
      ));
    });
  }

  QueryBuilder<EmbeddedCaptureConditions, EmbeddedCaptureConditions,
      QAfterFilterCondition> batteryPercentEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'batteryPercent',
        value: value,
      ));
    });
  }

  QueryBuilder<EmbeddedCaptureConditions, EmbeddedCaptureConditions,
      QAfterFilterCondition> batteryPercentGreaterThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'batteryPercent',
        value: value,
      ));
    });
  }

  QueryBuilder<EmbeddedCaptureConditions, EmbeddedCaptureConditions,
      QAfterFilterCondition> batteryPercentLessThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'batteryPercent',
        value: value,
      ));
    });
  }

  QueryBuilder<EmbeddedCaptureConditions, EmbeddedCaptureConditions,
      QAfterFilterCondition> batteryPercentBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'batteryPercent',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<EmbeddedCaptureConditions, EmbeddedCaptureConditions,
      QAfterFilterCondition> gpsIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'gps',
      ));
    });
  }

  QueryBuilder<EmbeddedCaptureConditions, EmbeddedCaptureConditions,
      QAfterFilterCondition> gpsIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'gps',
      ));
    });
  }

  QueryBuilder<EmbeddedCaptureConditions, EmbeddedCaptureConditions,
      QAfterFilterCondition> networkTypeIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'networkType',
      ));
    });
  }

  QueryBuilder<EmbeddedCaptureConditions, EmbeddedCaptureConditions,
      QAfterFilterCondition> networkTypeIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'networkType',
      ));
    });
  }

  QueryBuilder<EmbeddedCaptureConditions, EmbeddedCaptureConditions,
      QAfterFilterCondition> networkTypeEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'networkType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EmbeddedCaptureConditions, EmbeddedCaptureConditions,
      QAfterFilterCondition> networkTypeGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'networkType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EmbeddedCaptureConditions, EmbeddedCaptureConditions,
      QAfterFilterCondition> networkTypeLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'networkType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EmbeddedCaptureConditions, EmbeddedCaptureConditions,
      QAfterFilterCondition> networkTypeBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'networkType',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EmbeddedCaptureConditions, EmbeddedCaptureConditions,
      QAfterFilterCondition> networkTypeStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'networkType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EmbeddedCaptureConditions, EmbeddedCaptureConditions,
      QAfterFilterCondition> networkTypeEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'networkType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EmbeddedCaptureConditions, EmbeddedCaptureConditions,
          QAfterFilterCondition>
      networkTypeContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'networkType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EmbeddedCaptureConditions, EmbeddedCaptureConditions,
          QAfterFilterCondition>
      networkTypeMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'networkType',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EmbeddedCaptureConditions, EmbeddedCaptureConditions,
      QAfterFilterCondition> networkTypeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'networkType',
        value: '',
      ));
    });
  }

  QueryBuilder<EmbeddedCaptureConditions, EmbeddedCaptureConditions,
      QAfterFilterCondition> networkTypeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'networkType',
        value: '',
      ));
    });
  }
}

extension EmbeddedCaptureConditionsQueryObject on QueryBuilder<
    EmbeddedCaptureConditions, EmbeddedCaptureConditions, QFilterCondition> {
  QueryBuilder<EmbeddedCaptureConditions, EmbeddedCaptureConditions,
      QAfterFilterCondition> gps(FilterQuery<EmbeddedGpsFix> q) {
    return QueryBuilder.apply(this, (query) {
      return query.object(q, r'gps');
    });
  }
}
