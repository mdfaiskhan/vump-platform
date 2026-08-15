/// Whether Chapter 5.11's dispatcher is able to run at all.
///
/// A **system-level** fact, deliberately not a fifth chunk status. Chapter 5.9
/// §1 fixes four chunk states and Chapter 2.10 §2.2 four status colours; a
/// dispatcher that cannot start is not a property of any one chunk, and
/// painting it onto every pill would say something false about each of them.
///
/// ## Why this exists
///
/// The dispatcher already knew when it had stopped — it logged and shut down —
/// and nothing published that. On a device the result was an amber "Queued"
/// pill that never changed, indistinguishable from a chunk waiting its turn.
/// The Collector could record all day with no upload ever attempted and no
/// signal beyond a log line. Recorded as open item 60 and fixed in Mission
/// 4.6.5.
enum UploadDispatcherStatus {
  /// The dispatcher is subscribed and able to claim work.
  ///
  /// Not a claim that anything *is* uploading — an empty queue is also
  /// `running`.
  running,

  /// The dispatcher stopped on a fault and will not resume this launch.
  ///
  /// Two causes reach here, and neither is recoverable without a restart: the
  /// upload pipeline could not be constructed, or the queue stream broke.
  /// Deliberate teardown is **not** one of them.
  halted;

  /// Whether the Collector should be told uploads are not running.
  bool get isHalted => this == UploadDispatcherStatus.halted;
}
