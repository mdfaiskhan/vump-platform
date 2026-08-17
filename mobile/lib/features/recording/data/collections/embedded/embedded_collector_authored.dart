import 'package:isar/isar.dart';

part 'embedded_collector_authored.g.dart';

/// The `collector_authored` group on disk.
///
/// The only group Chapter 4.5 §4 permits to change after creation. Empty at
/// generation, and Phase 2 (C-13) is what will write it.
@embedded
class EmbeddedCollectorAuthored {
  /// Creates a stored EmbeddedCollectorAuthored.
  EmbeddedCollectorAuthored();

  /// Collector-authored free text. Phase 2 (C-13); null today.
  String? notes;

  /// Collector-authored tags. Phase 2; empty today.
  List<String> tags = <String>[];
}
