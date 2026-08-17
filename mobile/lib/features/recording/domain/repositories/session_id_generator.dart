/// Produces the `session_id` stamped on every chunk of a session.
///
/// Volume 5 Chapter 5.14 §3 fixes both the shape and the owner: *"a UUID
/// generated once at session start (Chapter 5.3) — two Collectors, or the same
/// Collector on two devices, can never produce the same `session_id`."* That
/// makes generating it this chapter's job, which is why the port is declared
/// here rather than borrowed from elsewhere.
///
/// ## A port rather than a package call
///
/// The project has no UUID dependency, and adding one is an ADR-030 admission
/// with a confinement entry and a conversion boundary — none of which belongs
/// in a domain-and-application mission. Inverting it costs one interface and
/// leaves the choice to whoever wires the composition root, exactly as
/// `authRepositoryProvider` and `authTokenSourceProvider` do for the same
/// reason (ADR-022, ADR-035).
///
/// It also keeps the lifecycle deterministic under test: a fake returning a
/// fixed string makes every assertion about session identity readable, where a
/// real UUID would force every test to match on a pattern.
abstract interface class SessionIdGenerator {
  /// Returns a fresh UUID.
  ///
  /// Called exactly once per session, on the Checklist-passed transition.
  /// Chapter 5.6 §2: *"chunking never creates a new `session_id`."*
  String newSessionId();
}
