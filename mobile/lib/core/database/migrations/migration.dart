import 'package:isar/isar.dart';

/// One step in the schema upgrade path.
///
/// Isar migrates additive change silently — a new collection or property
/// simply appears — and offers no hook for anything else. A rename, a type
/// change, or any change requiring existing rows to be rewritten must be
/// performed explicitly. That is what a migration is for.
///
/// Steps form an ordered chain: a database at version 1 upgrading to version 3
/// runs the 1→2 step and then the 2→3 step. There is no step that skips
/// versions, so every intermediate state is one a device has actually been in.
///
/// **A shipped migration is never edited.** It describes a transformation that
/// has already run on real devices, and changing it makes the version number
/// on disk mean two different things. Correct a mistake with a further step.
abstract interface class Migration {
  /// Version this step upgrades from.
  int get from;

  /// Version this step upgrades to. Always [from] + 1.
  int get to;

  /// Applies the transformation.
  ///
  /// Runs inside a write transaction opened by the runner, so an
  /// implementation must not open its own. Throwing aborts the transaction and
  /// leaves the database at [from].
  Future<void> apply(Isar isar);
}
