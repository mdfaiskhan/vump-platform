/// The kind of connection the device has, as FR-CHK-04 needs it.
///
/// FR-CHK-04 asks the Checklist to *"check network availability and inform the
/// Collector whether upload will start immediately or be queued"* — so a
/// boolean is not enough. What the Collector is told depends on the kind of
/// connection, and Volume 4 Chapter 4.5's metadata carries the same three
/// spellings, which is why [wireName] exists rather than a second enum.
///
/// **No value here fails the Checklist.** Volume 2 Chapter 2.9 §5 is explicit:
/// *"the checklist's network check (FR-CHK-04) only determines whether upload
/// starts immediately or is queued, never whether recording is allowed to
/// proceed."* [none] is an outcome the row reports, not a block.
enum NetworkType {
  /// Wi-Fi, or any unmetered connection the platform reports as such.
  wifi('wifi'),

  /// A mobile data connection.
  cellular('cellular'),

  /// No connectivity. Recording proceeds; upload queues (BR-10).
  none('none');

  const NetworkType(this.wireName);

  /// The spelling Volume 4 Chapter 4.5's `capture_conditions.network_type`
  /// uses, so the stored value and the displayed one come from one source.
  final String wireName;
}
