// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'embedded_timing.dart';

// **************************************************************************
// IsarEmbeddedGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

const EmbeddedTimingSchema = Schema(
  name: r'EmbeddedTiming',
  id: 7244891783795601443,
  properties: {
    r'endedAt': PropertySchema(
      id: 0,
      name: r'endedAt',
      type: IsarType.dateTime,
    ),
    r'sequenceIndex': PropertySchema(
      id: 1,
      name: r'sequenceIndex',
      type: IsarType.long,
    ),
    r'startedAt': PropertySchema(
      id: 2,
      name: r'startedAt',
      type: IsarType.dateTime,
    ),
  },
  estimateSize: _embeddedTimingEstimateSize,
  serialize: _embeddedTimingSerialize,
  deserialize: _embeddedTimingDeserialize,
  deserializeProp: _embeddedTimingDeserializeProp,
);

int _embeddedTimingEstimateSize(
  EmbeddedTiming object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  return bytesCount;
}

void _embeddedTimingSerialize(
  EmbeddedTiming object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeDateTime(offsets[0], object.endedAt);
  writer.writeLong(offsets[1], object.sequenceIndex);
  writer.writeDateTime(offsets[2], object.startedAt);
}

EmbeddedTiming _embeddedTimingDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = EmbeddedTiming();
  object.endedAt = reader.readDateTimeOrNull(offsets[0]);
  object.sequenceIndex = reader.readLongOrNull(offsets[1]);
  object.startedAt = reader.readDateTimeOrNull(offsets[2]);
  return object;
}

P _embeddedTimingDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 1:
      return (reader.readLongOrNull(offset)) as P;
    case 2:
      return (reader.readDateTimeOrNull(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

extension EmbeddedTimingQueryFilter
    on QueryBuilder<EmbeddedTiming, EmbeddedTiming, QFilterCondition> {
  QueryBuilder<EmbeddedTiming, EmbeddedTiming, QAfterFilterCondition>
  endedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'endedAt'),
      );
    });
  }

  QueryBuilder<EmbeddedTiming, EmbeddedTiming, QAfterFilterCondition>
  endedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'endedAt'),
      );
    });
  }

  QueryBuilder<EmbeddedTiming, EmbeddedTiming, QAfterFilterCondition>
  endedAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'endedAt', value: value),
      );
    });
  }

  QueryBuilder<EmbeddedTiming, EmbeddedTiming, QAfterFilterCondition>
  endedAtGreaterThan(DateTime? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'endedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<EmbeddedTiming, EmbeddedTiming, QAfterFilterCondition>
  endedAtLessThan(DateTime? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'endedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<EmbeddedTiming, EmbeddedTiming, QAfterFilterCondition>
  endedAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'endedAt',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<EmbeddedTiming, EmbeddedTiming, QAfterFilterCondition>
  sequenceIndexIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'sequenceIndex'),
      );
    });
  }

  QueryBuilder<EmbeddedTiming, EmbeddedTiming, QAfterFilterCondition>
  sequenceIndexIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'sequenceIndex'),
      );
    });
  }

  QueryBuilder<EmbeddedTiming, EmbeddedTiming, QAfterFilterCondition>
  sequenceIndexEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'sequenceIndex', value: value),
      );
    });
  }

  QueryBuilder<EmbeddedTiming, EmbeddedTiming, QAfterFilterCondition>
  sequenceIndexGreaterThan(int? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'sequenceIndex',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<EmbeddedTiming, EmbeddedTiming, QAfterFilterCondition>
  sequenceIndexLessThan(int? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'sequenceIndex',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<EmbeddedTiming, EmbeddedTiming, QAfterFilterCondition>
  sequenceIndexBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'sequenceIndex',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<EmbeddedTiming, EmbeddedTiming, QAfterFilterCondition>
  startedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'startedAt'),
      );
    });
  }

  QueryBuilder<EmbeddedTiming, EmbeddedTiming, QAfterFilterCondition>
  startedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'startedAt'),
      );
    });
  }

  QueryBuilder<EmbeddedTiming, EmbeddedTiming, QAfterFilterCondition>
  startedAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'startedAt', value: value),
      );
    });
  }

  QueryBuilder<EmbeddedTiming, EmbeddedTiming, QAfterFilterCondition>
  startedAtGreaterThan(DateTime? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'startedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<EmbeddedTiming, EmbeddedTiming, QAfterFilterCondition>
  startedAtLessThan(DateTime? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'startedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<EmbeddedTiming, EmbeddedTiming, QAfterFilterCondition>
  startedAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'startedAt',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension EmbeddedTimingQueryObject
    on QueryBuilder<EmbeddedTiming, EmbeddedTiming, QFilterCondition> {}
