// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'metadata_capture.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$MetadataCapture {
  /// `"1920x1080"` — formatted from `CameraSpecification`'s two constants
  /// rather than written as a literal, so it cannot drift from them.
  String get resolution => throw _privateConstructorUsedError;

  /// From `CameraSpecification.frameRate`.
  int get frameRate => throw _privateConstructorUsedError;

  /// From `CameraSpecification.targetVideoBitrateKbps`.
  int get bitrateKbps => throw _privateConstructorUsedError;

  /// The **wire** spelling, `"h264"` — see `CodecWireName` for why this
  /// differs from `CameraSpecification.videoCodec`'s `'H.264'`.
  String get codec => throw _privateConstructorUsedError;

  /// From `RecordingSession.zoomFactor` — the ladder's verdict.
  double get zoomFactor => throw _privateConstructorUsedError;

  /// `"rear-wide"`. BR-01 fixes the camera and BR-02 the field of view, so
  /// this is constant for every chunk this application will ever produce.
  String get camera => throw _privateConstructorUsedError;

  /// The orientation the chunk was actually captured at, as a wire spelling
  /// — `"landscape-left"`, `"portrait-up"`. Migration 0017, ADR-054 §6.
  ///
  /// **Read from the pipeline, not from a constant.** ADR-054 locks capture
  /// orientation to landscape, but this field records what the device did
  /// rather than what the build intends, so a build without the lock reports
  /// the handset's own orientation honestly instead of claiming the value it
  /// would have preferred.
  ///
  /// That is the whole point of the field. §6: *"a dataset that changes a
  /// capture parameter without recording it loses the ability to tell its own
  /// footage apart"* — a field that always said `landscape-left` could not
  /// tell them apart either.
  ///
  /// Nullable because a pipeline that never opened a session has nothing to
  /// report, and because every chunk recorded before 0017 has no value.
  String? get orientation => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $MetadataCaptureCopyWith<MetadataCapture> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $MetadataCaptureCopyWith<$Res> {
  factory $MetadataCaptureCopyWith(
          MetadataCapture value, $Res Function(MetadataCapture) then) =
      _$MetadataCaptureCopyWithImpl<$Res, MetadataCapture>;
  @useResult
  $Res call(
      {String resolution,
      int frameRate,
      int bitrateKbps,
      String codec,
      double zoomFactor,
      String camera,
      String? orientation});
}

/// @nodoc
class _$MetadataCaptureCopyWithImpl<$Res, $Val extends MetadataCapture>
    implements $MetadataCaptureCopyWith<$Res> {
  _$MetadataCaptureCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? resolution = null,
    Object? frameRate = null,
    Object? bitrateKbps = null,
    Object? codec = null,
    Object? zoomFactor = null,
    Object? camera = null,
    Object? orientation = freezed,
  }) {
    return _then(_value.copyWith(
      resolution: null == resolution
          ? _value.resolution
          : resolution // ignore: cast_nullable_to_non_nullable
              as String,
      frameRate: null == frameRate
          ? _value.frameRate
          : frameRate // ignore: cast_nullable_to_non_nullable
              as int,
      bitrateKbps: null == bitrateKbps
          ? _value.bitrateKbps
          : bitrateKbps // ignore: cast_nullable_to_non_nullable
              as int,
      codec: null == codec
          ? _value.codec
          : codec // ignore: cast_nullable_to_non_nullable
              as String,
      zoomFactor: null == zoomFactor
          ? _value.zoomFactor
          : zoomFactor // ignore: cast_nullable_to_non_nullable
              as double,
      camera: null == camera
          ? _value.camera
          : camera // ignore: cast_nullable_to_non_nullable
              as String,
      orientation: freezed == orientation
          ? _value.orientation
          : orientation // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$MetadataCaptureImplCopyWith<$Res>
    implements $MetadataCaptureCopyWith<$Res> {
  factory _$$MetadataCaptureImplCopyWith(_$MetadataCaptureImpl value,
          $Res Function(_$MetadataCaptureImpl) then) =
      __$$MetadataCaptureImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String resolution,
      int frameRate,
      int bitrateKbps,
      String codec,
      double zoomFactor,
      String camera,
      String? orientation});
}

/// @nodoc
class __$$MetadataCaptureImplCopyWithImpl<$Res>
    extends _$MetadataCaptureCopyWithImpl<$Res, _$MetadataCaptureImpl>
    implements _$$MetadataCaptureImplCopyWith<$Res> {
  __$$MetadataCaptureImplCopyWithImpl(
      _$MetadataCaptureImpl _value, $Res Function(_$MetadataCaptureImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? resolution = null,
    Object? frameRate = null,
    Object? bitrateKbps = null,
    Object? codec = null,
    Object? zoomFactor = null,
    Object? camera = null,
    Object? orientation = freezed,
  }) {
    return _then(_$MetadataCaptureImpl(
      resolution: null == resolution
          ? _value.resolution
          : resolution // ignore: cast_nullable_to_non_nullable
              as String,
      frameRate: null == frameRate
          ? _value.frameRate
          : frameRate // ignore: cast_nullable_to_non_nullable
              as int,
      bitrateKbps: null == bitrateKbps
          ? _value.bitrateKbps
          : bitrateKbps // ignore: cast_nullable_to_non_nullable
              as int,
      codec: null == codec
          ? _value.codec
          : codec // ignore: cast_nullable_to_non_nullable
              as String,
      zoomFactor: null == zoomFactor
          ? _value.zoomFactor
          : zoomFactor // ignore: cast_nullable_to_non_nullable
              as double,
      camera: null == camera
          ? _value.camera
          : camera // ignore: cast_nullable_to_non_nullable
              as String,
      orientation: freezed == orientation
          ? _value.orientation
          : orientation // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc

class _$MetadataCaptureImpl implements _MetadataCapture {
  const _$MetadataCaptureImpl(
      {required this.resolution,
      required this.frameRate,
      required this.bitrateKbps,
      required this.codec,
      required this.zoomFactor,
      required this.camera,
      this.orientation});

  /// `"1920x1080"` — formatted from `CameraSpecification`'s two constants
  /// rather than written as a literal, so it cannot drift from them.
  @override
  final String resolution;

  /// From `CameraSpecification.frameRate`.
  @override
  final int frameRate;

  /// From `CameraSpecification.targetVideoBitrateKbps`.
  @override
  final int bitrateKbps;

  /// The **wire** spelling, `"h264"` — see `CodecWireName` for why this
  /// differs from `CameraSpecification.videoCodec`'s `'H.264'`.
  @override
  final String codec;

  /// From `RecordingSession.zoomFactor` — the ladder's verdict.
  @override
  final double zoomFactor;

  /// `"rear-wide"`. BR-01 fixes the camera and BR-02 the field of view, so
  /// this is constant for every chunk this application will ever produce.
  @override
  final String camera;

  /// The orientation the chunk was actually captured at, as a wire spelling
  /// — `"landscape-left"`, `"portrait-up"`. Migration 0017, ADR-054 §6.
  ///
  /// **Read from the pipeline, not from a constant.** ADR-054 locks capture
  /// orientation to landscape, but this field records what the device did
  /// rather than what the build intends, so a build without the lock reports
  /// the handset's own orientation honestly instead of claiming the value it
  /// would have preferred.
  ///
  /// That is the whole point of the field. §6: *"a dataset that changes a
  /// capture parameter without recording it loses the ability to tell its own
  /// footage apart"* — a field that always said `landscape-left` could not
  /// tell them apart either.
  ///
  /// Nullable because a pipeline that never opened a session has nothing to
  /// report, and because every chunk recorded before 0017 has no value.
  @override
  final String? orientation;

  @override
  String toString() {
    return 'MetadataCapture(resolution: $resolution, frameRate: $frameRate, bitrateKbps: $bitrateKbps, codec: $codec, zoomFactor: $zoomFactor, camera: $camera, orientation: $orientation)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MetadataCaptureImpl &&
            (identical(other.resolution, resolution) ||
                other.resolution == resolution) &&
            (identical(other.frameRate, frameRate) ||
                other.frameRate == frameRate) &&
            (identical(other.bitrateKbps, bitrateKbps) ||
                other.bitrateKbps == bitrateKbps) &&
            (identical(other.codec, codec) || other.codec == codec) &&
            (identical(other.zoomFactor, zoomFactor) ||
                other.zoomFactor == zoomFactor) &&
            (identical(other.camera, camera) || other.camera == camera) &&
            (identical(other.orientation, orientation) ||
                other.orientation == orientation));
  }

  @override
  int get hashCode => Object.hash(runtimeType, resolution, frameRate,
      bitrateKbps, codec, zoomFactor, camera, orientation);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$MetadataCaptureImplCopyWith<_$MetadataCaptureImpl> get copyWith =>
      __$$MetadataCaptureImplCopyWithImpl<_$MetadataCaptureImpl>(
          this, _$identity);
}

abstract class _MetadataCapture implements MetadataCapture {
  const factory _MetadataCapture(
      {required final String resolution,
      required final int frameRate,
      required final int bitrateKbps,
      required final String codec,
      required final double zoomFactor,
      required final String camera,
      final String? orientation}) = _$MetadataCaptureImpl;

  @override

  /// `"1920x1080"` — formatted from `CameraSpecification`'s two constants
  /// rather than written as a literal, so it cannot drift from them.
  String get resolution;
  @override

  /// From `CameraSpecification.frameRate`.
  int get frameRate;
  @override

  /// From `CameraSpecification.targetVideoBitrateKbps`.
  int get bitrateKbps;
  @override

  /// The **wire** spelling, `"h264"` — see `CodecWireName` for why this
  /// differs from `CameraSpecification.videoCodec`'s `'H.264'`.
  String get codec;
  @override

  /// From `RecordingSession.zoomFactor` — the ladder's verdict.
  double get zoomFactor;
  @override

  /// `"rear-wide"`. BR-01 fixes the camera and BR-02 the field of view, so
  /// this is constant for every chunk this application will ever produce.
  String get camera;
  @override

  /// The orientation the chunk was actually captured at, as a wire spelling
  /// — `"landscape-left"`, `"portrait-up"`. Migration 0017, ADR-054 §6.
  ///
  /// **Read from the pipeline, not from a constant.** ADR-054 locks capture
  /// orientation to landscape, but this field records what the device did
  /// rather than what the build intends, so a build without the lock reports
  /// the handset's own orientation honestly instead of claiming the value it
  /// would have preferred.
  ///
  /// That is the whole point of the field. §6: *"a dataset that changes a
  /// capture parameter without recording it loses the ability to tell its own
  /// footage apart"* — a field that always said `landscape-left` could not
  /// tell them apart either.
  ///
  /// Nullable because a pipeline that never opened a session has nothing to
  /// report, and because every chunk recorded before 0017 has no value.
  String? get orientation;
  @override
  @JsonKey(ignore: true)
  _$$MetadataCaptureImplCopyWith<_$MetadataCaptureImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
