import 'package:freezed_annotation/freezed_annotation.dart';

part 'collector_authored.freezed.dart';

/// The `collector_authored` group of Volume 4 Chapter 4.5's schema.
///
/// **Empty at generation time, always.** Chapter 5.7 §2 says so, and Chapter
/// 4.5 §4 explains why it is the only group that may ever change: every other
/// field is *"written once, at creation … and rejected on any subsequent
/// PATCH by the database trigger"*, enforced server-side per NFR-META-03.
///
/// Notes and tags are Phase 2 (C-13, FR-SEC-01), so nothing writes here yet.
/// The group exists in the shape because the wire format has it and the
/// backend expects it.
@freezed
class CollectorAuthored with _$CollectorAuthored {
  /// Creates the collector-authored group.
  const factory CollectorAuthored({
    String? notes,
    @Default(<String>[]) List<String> tags,
  }) = _CollectorAuthored;

  /// What Chapter 5.7 §2 requires at generation: nothing.
  static const CollectorAuthored empty = CollectorAuthored();
}
