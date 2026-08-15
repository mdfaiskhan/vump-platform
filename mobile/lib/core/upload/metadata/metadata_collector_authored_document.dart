/// The `collector_authored` group of Volume 4 Chapter 4.5 §2's wire shape.
///
/// **The only mutable group.** Chapter 4.5 §4: *"every field above except
/// `collector_authored` is written once, at creation … and rejected on any
/// subsequent PATCH"* (BR-22, NFR-META-03). It is separated in the schema for
/// exactly that reason, so the immutability trigger has a clean boundary.
///
/// Always empty at generation (Chapter 5.7 §2). C-13, the screen that would
/// fill it, is Phase 2.
class MetadataCollectorAuthoredDocument {
  /// Creates the collector-authored group.
  const MetadataCollectorAuthoredDocument({
    this.notes,
    this.tags = const <String>[],
  });

  /// `collector_authored.notes`.
  final String? notes;

  /// `collector_authored.tags`.
  ///
  /// Empty rather than null when unset: the field is a list the Collector may
  /// add to, and an absent list and an empty one mean the same thing to a
  /// consumer while only one of them needs a null check at every use.
  final List<String> tags;

  /// Chapter 4.5 §2's `collector_authored` object.
  Map<String, Object?> toJson() => <String, Object?>{
    'notes': notes,
    'tags': List<String>.unmodifiable(tags),
  };
}
