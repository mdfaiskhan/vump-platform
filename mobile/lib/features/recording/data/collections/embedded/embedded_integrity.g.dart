// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'embedded_integrity.dart';

// **************************************************************************
// IsarEmbeddedGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

const EmbeddedIntegritySchema = Schema(
  name: r'EmbeddedIntegrity',
  id: -2105844545809875298,
  properties: {
    r'byteCount': PropertySchema(
      id: 0,
      name: r'byteCount',
      type: IsarType.long,
    ),
    r'checksumSha256': PropertySchema(
      id: 1,
      name: r'checksumSha256',
      type: IsarType.string,
    )
  },
  estimateSize: _embeddedIntegrityEstimateSize,
  serialize: _embeddedIntegritySerialize,
  deserialize: _embeddedIntegrityDeserialize,
  deserializeProp: _embeddedIntegrityDeserializeProp,
);

int _embeddedIntegrityEstimateSize(
  EmbeddedIntegrity object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  {
    final value = object.checksumSha256;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  return bytesCount;
}

void _embeddedIntegritySerialize(
  EmbeddedIntegrity object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeLong(offsets[0], object.byteCount);
  writer.writeString(offsets[1], object.checksumSha256);
}

EmbeddedIntegrity _embeddedIntegrityDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = EmbeddedIntegrity();
  object.byteCount = reader.readLongOrNull(offsets[0]);
  object.checksumSha256 = reader.readStringOrNull(offsets[1]);
  return object;
}

P _embeddedIntegrityDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readLongOrNull(offset)) as P;
    case 1:
      return (reader.readStringOrNull(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

extension EmbeddedIntegrityQueryFilter
    on QueryBuilder<EmbeddedIntegrity, EmbeddedIntegrity, QFilterCondition> {
  QueryBuilder<EmbeddedIntegrity, EmbeddedIntegrity, QAfterFilterCondition>
      byteCountIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'byteCount',
      ));
    });
  }

  QueryBuilder<EmbeddedIntegrity, EmbeddedIntegrity, QAfterFilterCondition>
      byteCountIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'byteCount',
      ));
    });
  }

  QueryBuilder<EmbeddedIntegrity, EmbeddedIntegrity, QAfterFilterCondition>
      byteCountEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'byteCount',
        value: value,
      ));
    });
  }

  QueryBuilder<EmbeddedIntegrity, EmbeddedIntegrity, QAfterFilterCondition>
      byteCountGreaterThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'byteCount',
        value: value,
      ));
    });
  }

  QueryBuilder<EmbeddedIntegrity, EmbeddedIntegrity, QAfterFilterCondition>
      byteCountLessThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'byteCount',
        value: value,
      ));
    });
  }

  QueryBuilder<EmbeddedIntegrity, EmbeddedIntegrity, QAfterFilterCondition>
      byteCountBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'byteCount',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<EmbeddedIntegrity, EmbeddedIntegrity, QAfterFilterCondition>
      checksumSha256IsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'checksumSha256',
      ));
    });
  }

  QueryBuilder<EmbeddedIntegrity, EmbeddedIntegrity, QAfterFilterCondition>
      checksumSha256IsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'checksumSha256',
      ));
    });
  }

  QueryBuilder<EmbeddedIntegrity, EmbeddedIntegrity, QAfterFilterCondition>
      checksumSha256EqualTo(
    String? value, {
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

  QueryBuilder<EmbeddedIntegrity, EmbeddedIntegrity, QAfterFilterCondition>
      checksumSha256GreaterThan(
    String? value, {
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

  QueryBuilder<EmbeddedIntegrity, EmbeddedIntegrity, QAfterFilterCondition>
      checksumSha256LessThan(
    String? value, {
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

  QueryBuilder<EmbeddedIntegrity, EmbeddedIntegrity, QAfterFilterCondition>
      checksumSha256Between(
    String? lower,
    String? upper, {
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

  QueryBuilder<EmbeddedIntegrity, EmbeddedIntegrity, QAfterFilterCondition>
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

  QueryBuilder<EmbeddedIntegrity, EmbeddedIntegrity, QAfterFilterCondition>
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

  QueryBuilder<EmbeddedIntegrity, EmbeddedIntegrity, QAfterFilterCondition>
      checksumSha256Contains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'checksumSha256',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EmbeddedIntegrity, EmbeddedIntegrity, QAfterFilterCondition>
      checksumSha256Matches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'checksumSha256',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EmbeddedIntegrity, EmbeddedIntegrity, QAfterFilterCondition>
      checksumSha256IsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'checksumSha256',
        value: '',
      ));
    });
  }

  QueryBuilder<EmbeddedIntegrity, EmbeddedIntegrity, QAfterFilterCondition>
      checksumSha256IsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'checksumSha256',
        value: '',
      ));
    });
  }
}

extension EmbeddedIntegrityQueryObject
    on QueryBuilder<EmbeddedIntegrity, EmbeddedIntegrity, QFilterCondition> {}
