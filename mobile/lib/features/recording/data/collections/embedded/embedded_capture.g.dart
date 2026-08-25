// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'embedded_capture.dart';

// **************************************************************************
// IsarEmbeddedGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

const EmbeddedCaptureSchema = Schema(
  name: r'EmbeddedCapture',
  id: 2367373597823407617,
  properties: {
    r'bitrateKbps': PropertySchema(
      id: 0,
      name: r'bitrateKbps',
      type: IsarType.long,
    ),
    r'camera': PropertySchema(
      id: 1,
      name: r'camera',
      type: IsarType.string,
    ),
    r'codec': PropertySchema(
      id: 2,
      name: r'codec',
      type: IsarType.string,
    ),
    r'frameRate': PropertySchema(
      id: 3,
      name: r'frameRate',
      type: IsarType.long,
    ),
    r'orientation': PropertySchema(
      id: 4,
      name: r'orientation',
      type: IsarType.string,
    ),
    r'resolution': PropertySchema(
      id: 5,
      name: r'resolution',
      type: IsarType.string,
    ),
    r'zoomFactor': PropertySchema(
      id: 6,
      name: r'zoomFactor',
      type: IsarType.double,
    )
  },
  estimateSize: _embeddedCaptureEstimateSize,
  serialize: _embeddedCaptureSerialize,
  deserialize: _embeddedCaptureDeserialize,
  deserializeProp: _embeddedCaptureDeserializeProp,
);

int _embeddedCaptureEstimateSize(
  EmbeddedCapture object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  {
    final value = object.camera;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.codec;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.orientation;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.resolution;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  return bytesCount;
}

void _embeddedCaptureSerialize(
  EmbeddedCapture object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeLong(offsets[0], object.bitrateKbps);
  writer.writeString(offsets[1], object.camera);
  writer.writeString(offsets[2], object.codec);
  writer.writeLong(offsets[3], object.frameRate);
  writer.writeString(offsets[4], object.orientation);
  writer.writeString(offsets[5], object.resolution);
  writer.writeDouble(offsets[6], object.zoomFactor);
}

EmbeddedCapture _embeddedCaptureDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = EmbeddedCapture();
  object.bitrateKbps = reader.readLongOrNull(offsets[0]);
  object.camera = reader.readStringOrNull(offsets[1]);
  object.codec = reader.readStringOrNull(offsets[2]);
  object.frameRate = reader.readLongOrNull(offsets[3]);
  object.orientation = reader.readStringOrNull(offsets[4]);
  object.resolution = reader.readStringOrNull(offsets[5]);
  object.zoomFactor = reader.readDoubleOrNull(offsets[6]);
  return object;
}

P _embeddedCaptureDeserializeProp<P>(
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
    case 2:
      return (reader.readStringOrNull(offset)) as P;
    case 3:
      return (reader.readLongOrNull(offset)) as P;
    case 4:
      return (reader.readStringOrNull(offset)) as P;
    case 5:
      return (reader.readStringOrNull(offset)) as P;
    case 6:
      return (reader.readDoubleOrNull(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

extension EmbeddedCaptureQueryFilter
    on QueryBuilder<EmbeddedCapture, EmbeddedCapture, QFilterCondition> {
  QueryBuilder<EmbeddedCapture, EmbeddedCapture, QAfterFilterCondition>
      bitrateKbpsIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'bitrateKbps',
      ));
    });
  }

  QueryBuilder<EmbeddedCapture, EmbeddedCapture, QAfterFilterCondition>
      bitrateKbpsIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'bitrateKbps',
      ));
    });
  }

  QueryBuilder<EmbeddedCapture, EmbeddedCapture, QAfterFilterCondition>
      bitrateKbpsEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'bitrateKbps',
        value: value,
      ));
    });
  }

  QueryBuilder<EmbeddedCapture, EmbeddedCapture, QAfterFilterCondition>
      bitrateKbpsGreaterThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'bitrateKbps',
        value: value,
      ));
    });
  }

  QueryBuilder<EmbeddedCapture, EmbeddedCapture, QAfterFilterCondition>
      bitrateKbpsLessThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'bitrateKbps',
        value: value,
      ));
    });
  }

  QueryBuilder<EmbeddedCapture, EmbeddedCapture, QAfterFilterCondition>
      bitrateKbpsBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'bitrateKbps',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<EmbeddedCapture, EmbeddedCapture, QAfterFilterCondition>
      cameraIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'camera',
      ));
    });
  }

  QueryBuilder<EmbeddedCapture, EmbeddedCapture, QAfterFilterCondition>
      cameraIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'camera',
      ));
    });
  }

  QueryBuilder<EmbeddedCapture, EmbeddedCapture, QAfterFilterCondition>
      cameraEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'camera',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EmbeddedCapture, EmbeddedCapture, QAfterFilterCondition>
      cameraGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'camera',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EmbeddedCapture, EmbeddedCapture, QAfterFilterCondition>
      cameraLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'camera',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EmbeddedCapture, EmbeddedCapture, QAfterFilterCondition>
      cameraBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'camera',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EmbeddedCapture, EmbeddedCapture, QAfterFilterCondition>
      cameraStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'camera',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EmbeddedCapture, EmbeddedCapture, QAfterFilterCondition>
      cameraEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'camera',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EmbeddedCapture, EmbeddedCapture, QAfterFilterCondition>
      cameraContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'camera',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EmbeddedCapture, EmbeddedCapture, QAfterFilterCondition>
      cameraMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'camera',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EmbeddedCapture, EmbeddedCapture, QAfterFilterCondition>
      cameraIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'camera',
        value: '',
      ));
    });
  }

  QueryBuilder<EmbeddedCapture, EmbeddedCapture, QAfterFilterCondition>
      cameraIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'camera',
        value: '',
      ));
    });
  }

  QueryBuilder<EmbeddedCapture, EmbeddedCapture, QAfterFilterCondition>
      codecIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'codec',
      ));
    });
  }

  QueryBuilder<EmbeddedCapture, EmbeddedCapture, QAfterFilterCondition>
      codecIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'codec',
      ));
    });
  }

  QueryBuilder<EmbeddedCapture, EmbeddedCapture, QAfterFilterCondition>
      codecEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'codec',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EmbeddedCapture, EmbeddedCapture, QAfterFilterCondition>
      codecGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'codec',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EmbeddedCapture, EmbeddedCapture, QAfterFilterCondition>
      codecLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'codec',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EmbeddedCapture, EmbeddedCapture, QAfterFilterCondition>
      codecBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'codec',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EmbeddedCapture, EmbeddedCapture, QAfterFilterCondition>
      codecStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'codec',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EmbeddedCapture, EmbeddedCapture, QAfterFilterCondition>
      codecEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'codec',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EmbeddedCapture, EmbeddedCapture, QAfterFilterCondition>
      codecContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'codec',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EmbeddedCapture, EmbeddedCapture, QAfterFilterCondition>
      codecMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'codec',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EmbeddedCapture, EmbeddedCapture, QAfterFilterCondition>
      codecIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'codec',
        value: '',
      ));
    });
  }

  QueryBuilder<EmbeddedCapture, EmbeddedCapture, QAfterFilterCondition>
      codecIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'codec',
        value: '',
      ));
    });
  }

  QueryBuilder<EmbeddedCapture, EmbeddedCapture, QAfterFilterCondition>
      frameRateIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'frameRate',
      ));
    });
  }

  QueryBuilder<EmbeddedCapture, EmbeddedCapture, QAfterFilterCondition>
      frameRateIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'frameRate',
      ));
    });
  }

  QueryBuilder<EmbeddedCapture, EmbeddedCapture, QAfterFilterCondition>
      frameRateEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'frameRate',
        value: value,
      ));
    });
  }

  QueryBuilder<EmbeddedCapture, EmbeddedCapture, QAfterFilterCondition>
      frameRateGreaterThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'frameRate',
        value: value,
      ));
    });
  }

  QueryBuilder<EmbeddedCapture, EmbeddedCapture, QAfterFilterCondition>
      frameRateLessThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'frameRate',
        value: value,
      ));
    });
  }

  QueryBuilder<EmbeddedCapture, EmbeddedCapture, QAfterFilterCondition>
      frameRateBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'frameRate',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<EmbeddedCapture, EmbeddedCapture, QAfterFilterCondition>
      orientationIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'orientation',
      ));
    });
  }

  QueryBuilder<EmbeddedCapture, EmbeddedCapture, QAfterFilterCondition>
      orientationIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'orientation',
      ));
    });
  }

  QueryBuilder<EmbeddedCapture, EmbeddedCapture, QAfterFilterCondition>
      orientationEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'orientation',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EmbeddedCapture, EmbeddedCapture, QAfterFilterCondition>
      orientationGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'orientation',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EmbeddedCapture, EmbeddedCapture, QAfterFilterCondition>
      orientationLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'orientation',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EmbeddedCapture, EmbeddedCapture, QAfterFilterCondition>
      orientationBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'orientation',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EmbeddedCapture, EmbeddedCapture, QAfterFilterCondition>
      orientationStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'orientation',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EmbeddedCapture, EmbeddedCapture, QAfterFilterCondition>
      orientationEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'orientation',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EmbeddedCapture, EmbeddedCapture, QAfterFilterCondition>
      orientationContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'orientation',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EmbeddedCapture, EmbeddedCapture, QAfterFilterCondition>
      orientationMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'orientation',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EmbeddedCapture, EmbeddedCapture, QAfterFilterCondition>
      orientationIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'orientation',
        value: '',
      ));
    });
  }

  QueryBuilder<EmbeddedCapture, EmbeddedCapture, QAfterFilterCondition>
      orientationIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'orientation',
        value: '',
      ));
    });
  }

  QueryBuilder<EmbeddedCapture, EmbeddedCapture, QAfterFilterCondition>
      resolutionIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'resolution',
      ));
    });
  }

  QueryBuilder<EmbeddedCapture, EmbeddedCapture, QAfterFilterCondition>
      resolutionIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'resolution',
      ));
    });
  }

  QueryBuilder<EmbeddedCapture, EmbeddedCapture, QAfterFilterCondition>
      resolutionEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'resolution',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EmbeddedCapture, EmbeddedCapture, QAfterFilterCondition>
      resolutionGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'resolution',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EmbeddedCapture, EmbeddedCapture, QAfterFilterCondition>
      resolutionLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'resolution',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EmbeddedCapture, EmbeddedCapture, QAfterFilterCondition>
      resolutionBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'resolution',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EmbeddedCapture, EmbeddedCapture, QAfterFilterCondition>
      resolutionStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'resolution',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EmbeddedCapture, EmbeddedCapture, QAfterFilterCondition>
      resolutionEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'resolution',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EmbeddedCapture, EmbeddedCapture, QAfterFilterCondition>
      resolutionContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'resolution',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EmbeddedCapture, EmbeddedCapture, QAfterFilterCondition>
      resolutionMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'resolution',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EmbeddedCapture, EmbeddedCapture, QAfterFilterCondition>
      resolutionIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'resolution',
        value: '',
      ));
    });
  }

  QueryBuilder<EmbeddedCapture, EmbeddedCapture, QAfterFilterCondition>
      resolutionIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'resolution',
        value: '',
      ));
    });
  }

  QueryBuilder<EmbeddedCapture, EmbeddedCapture, QAfterFilterCondition>
      zoomFactorIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'zoomFactor',
      ));
    });
  }

  QueryBuilder<EmbeddedCapture, EmbeddedCapture, QAfterFilterCondition>
      zoomFactorIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'zoomFactor',
      ));
    });
  }

  QueryBuilder<EmbeddedCapture, EmbeddedCapture, QAfterFilterCondition>
      zoomFactorEqualTo(
    double? value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'zoomFactor',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<EmbeddedCapture, EmbeddedCapture, QAfterFilterCondition>
      zoomFactorGreaterThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'zoomFactor',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<EmbeddedCapture, EmbeddedCapture, QAfterFilterCondition>
      zoomFactorLessThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'zoomFactor',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<EmbeddedCapture, EmbeddedCapture, QAfterFilterCondition>
      zoomFactorBetween(
    double? lower,
    double? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'zoomFactor',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        epsilon: epsilon,
      ));
    });
  }
}

extension EmbeddedCaptureQueryObject
    on QueryBuilder<EmbeddedCapture, EmbeddedCapture, QFilterCondition> {}
