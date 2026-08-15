import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/core/database/database_config.dart';
import 'package:mobile/core/database/providers/database_provider.dart';
import 'package:mobile/core/upload/interfaces/chunk_upload_source.dart';
import 'package:mobile/core/upload/providers/upload_ports.dart';
import 'package:mobile/core/upload/uploadable_chunk.dart';
import 'package:mobile/features/recording/application/finalize_chunk_use_case.dart';
import 'package:mobile/features/recording/application/recording_notifier.dart';
import 'package:mobile/features/recording/application/storage_cleanup_sweep.dart';
import 'package:mobile/features/recording/data/collections/recording_schemas.dart';
import 'package:mobile/features/recording/domain/entities/chunk_processing_job.dart';
import 'package:mobile/features/recording/domain/entities/recording_session.dart';
import 'package:mobile/features/recording/domain/entities/storage_sweep_result.dart';
import 'package:mobile/features/recording/domain/repositories/chunk_store.dart';
import 'package:mobile/main.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Mission 4.5's on-device probe for Volume 5 Chapter 5.15.
///
/// Run with:
/// ```shell
/// flutter run --target=lib/main_cleanup_probe.dart
/// ```
///
/// ## Why this one carries more weight than 4.3's and 4.4's probes
///
/// Those confirmed OS behaviour on top of logic that was already unit-tested.
/// This is different: `IsarChunkStore` needs a native Isar the test host does
/// not have, so **`deleteChunkFile` has no unit test at all**. The sweep's
/// policy is tested against a fake; the code that actually unlinks a file and
/// writes `localDeletedAt` is tested only here.
///
/// ## What it exercises — all of it real
///
/// The real database, the real `IsarChunkStore`, the real
/// `FinalizeChunkUseCase` and the real `StorageCleanupSweep`. Nothing is
/// stubbed except the video: the seeded files are small placeholders rather
/// than 610 MB captures, because Chapter 5.15 deletes a path and a row and
/// does not care what the bytes were.
///
/// 1. Seed several chunks through the real finalizer — real rows, real files
///    at Chapter 5.14 §2's paths.
/// 2. Move each to `complete` the way the pipeline does — claim, then mark.
/// 3. Show every file's existence, run the sweep, show it again.
/// 4. Run the sweep a **second** time: it must report idle, not re-delete and
///    not double-count.
/// 5. Delete one file behind the store's back and sweep again, to exercise the
///    orphan path and confirm a cleaned row is not itself reported as one.
///
/// ## It cannot become a release build
///
/// Volume 11's M12 gate. `main` refuses to run in release mode, and nothing in
/// the shipped entrypoint references this file.
void main() async {
  if (kReleaseMode) {
    throw StateError(
      'main_cleanup_probe.dart is a debug-only device probe that seeds and '
      'deletes chunk rows. Volume 11 M12 forbids shipping it. Build '
      'lib/main.dart instead.',
    );
  }

  WidgetsFlutterBinding.ensureInitialized();
  final Directory documents = await getApplicationDocumentsDirectory();
  final SharedPreferences preferences = await SharedPreferences.getInstance();

  final ProviderContainer container = ProviderContainer(
    overrides: <Override>[
      databaseDirectoryProvider.overrideWithValue(documents.path),
      databaseConfigProvider.overrideWith(
        (Ref ref) => DatabaseConfig(
          directory: ref.watch(databaseDirectoryProvider),
        ).withSchemas(RecordingSchemas.all),
      ),
      // The same list main.dart binds, so this probe verifies the composition
      // the application actually ships rather than one it declared here.
      ...recordingOverrides(documents.path, preferences),
    ],
  );

  await container.read(databaseProvider.future);

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: _CleanupProbeApp(documentsPath: documents.path),
    ),
  );
}

class _CleanupProbeApp extends StatelessWidget {
  const _CleanupProbeApp({required this.documentsPath});

  final String documentsPath;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Ch. 5.15 probe',
    theme: ThemeData(useMaterial3: true),
    home: _CleanupProbeScreen(documentsPath: documentsPath),
  );
}

class _CleanupProbeScreen extends ConsumerStatefulWidget {
  const _CleanupProbeScreen({required this.documentsPath});

  final String documentsPath;

  @override
  ConsumerState<_CleanupProbeScreen> createState() => _CleanupProbeState();
}

class _CleanupProbeState extends ConsumerState<_CleanupProbeScreen> {
  final List<String> _log = <String>[];
  final List<String> _seededPaths = <String>[];
  bool _busy = false;

  void _say(String line) => setState(() => _log.add(line));

  Future<void> _run(Future<void> Function() step) async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      await step();
    } on Object catch (error) {
      _say('ERROR $error');
    } finally {
      setState(() => _busy = false);
    }
  }

  /// Seeds [count] chunks through the real finalizer and marks them complete.
  Future<void> _seed(int count) async {
    final ChunkStore store = ref.read(chunkStoreProvider);
    final ChunkUploadSource source = ref.read(chunkUploadSourceProvider);
    final FinalizeChunkUseCase finalizer =
        ref.read(chunkFinalizerProvider) as FinalizeChunkUseCase;

    final DateTime now = DateTime.now();
    final String sessionId = 'cleanup-${now.millisecondsSinceEpoch}';
    final RecordingSession session = RecordingSession(
      sessionId: sessionId,
      zoomFactor: 1,
      startedAt: now,
    );

    for (int i = 0; i < count; i++) {
      // A placeholder file in the plugin's role: the finalizer moves it to
      // Chapter 5.14 §2's canonical path, which is the path cleanup deletes.
      final File staged = File('${widget.documentsPath}/probe_stage_$i.mp4');
      await staged.writeAsBytes(List<int>.filled(4096, i % 256));

      await finalizer.finalizeChunk(
        session: session,
        job: ChunkProcessingJob(
          chunkId: '$sessionId-$i',
          sequenceIndex: i,
          filePath: staged.path,
          startedAt: now,
        ),
        chunkStartedAt: now,
      );
    }
    _say('seeded $count chunk(s) for session $sessionId');

    // Move each to `complete` exactly as Chapter 5.10's pipeline does:
    // claim (queued -> uploading), then mark (uploading -> complete).
    int completed = 0;
    while (true) {
      final UploadableChunk? claimed = await source.claimNext(
        now: DateTime.now(),
      );
      if (claimed == null) {
        break;
      }
      await source.markComplete(claimed.chunkId);
      _seededPaths.add(claimed.localFilePath);
      completed += 1;
    }
    _say('marked $completed chunk(s) complete');
    await _reportFiles();

    final List<String> orphans = await store.orphanedChunkIds();
    _say('orphans before sweep: ${orphans.length} (expect 0)');
  }

  Future<void> _reportFiles() async {
    final int present = _seededPaths
        .where((String p) => File(p).existsSync())
        .length;
    _say('files on disk: $present of ${_seededPaths.length}');
  }

  Future<void> _sweep(String label) async {
    final StorageSweepResult result = await ref
        .read(storageCleanupSweepProvider)
        .sweep();
    _say('$label -> $result');
    await _reportFiles();
  }

  /// Deletes one file behind the store's back, so the orphan path has a
  /// genuine subject rather than a simulated one.
  Future<void> _breakOne() async {
    final ChunkStore store = ref.read(chunkStoreProvider);
    final String? victim = _seededPaths.cast<String?>().firstWhere(
      (String? p) => p != null && File(p).existsSync(),
      orElse: () => null,
    );
    if (victim == null) {
      _say('nothing left to break');
      return;
    }
    await File(victim).delete();
    _say('deleted $victim behind the store');
    final List<String> orphans = await store.orphanedChunkIds();
    _say('orphans now: ${orphans.length} (expect 1 if it was not cleaned)');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chapter 5.15 probe')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                FilledButton(
                  onPressed: _busy ? null : () => _run(() => _seed(4)),
                  child: const Text('1. Seed 4 + complete'),
                ),
                FilledButton(
                  onPressed: _busy ? null : () => _run(() => _sweep('sweep 1')),
                  child: const Text('2. Sweep'),
                ),
                OutlinedButton(
                  onPressed: _busy ? null : () => _run(() => _sweep('sweep 2')),
                  child: const Text('3. Sweep again'),
                ),
                OutlinedButton(
                  onPressed: _busy ? null : () => _run(_breakOne),
                  child: const Text('4. Break one file'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Expect: sweep 1 deletes 4 and reclaims bytes; sweep 2 is idle '
              'with 0 deleted; a cleaned row is never reported as an orphan.',
            ),
            const Divider(),
            Expanded(
              child: ListView.builder(
                itemCount: _log.length,
                itemBuilder: (BuildContext context, int i) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    _log[i],
                    style: const TextStyle(fontFamily: 'monospace'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
