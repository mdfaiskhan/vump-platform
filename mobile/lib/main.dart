import 'dart:io';

// One alphabetically sorted `package:` block rather than this file's previous
// third-party-then-first-party grouping: `directives_ordering` (ADR-021) sorts
// the whole section, and `path_provider` sorts after `mobile`, so the grouping
// and the lint can no longer both hold.
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/app/app.dart';
import 'package:mobile/app/config/app_config.dart';
import 'package:mobile/core/connectivity/providers/connectivity_ports.dart';
import 'package:mobile/core/database/database_config.dart';
import 'package:mobile/core/database/providers/database_provider.dart';
import 'package:mobile/core/environment/environment_profile.dart';
import 'package:mobile/core/errors/app_exception.dart';
import 'package:mobile/core/firebase/providers/firebase_provider.dart';
import 'package:mobile/core/logging/app_logger.dart';
import 'package:mobile/core/logging/providers/logger_provider.dart';
import 'package:mobile/core/upload/providers/upload_ports.dart';
import 'package:mobile/features/auth/application/auth_notifier.dart';
import 'package:mobile/features/auth/application/invite_code_notifier.dart';
import 'package:mobile/features/auth/data/invite_code_repository_impl.dart';
import 'package:mobile/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:mobile/features/recording/application/checklist_notifier.dart';
import 'package:mobile/features/recording/application/finalize_chunk_use_case.dart';
import 'package:mobile/features/recording/application/recording_notifier.dart';
import 'package:mobile/features/recording/application/storage_cleanup_sweep.dart';
import 'package:mobile/features/recording/data/battery_plus_battery_reader.dart';
import 'package:mobile/features/recording/data/camera_capability_probe_impl.dart';
import 'package:mobile/features/recording/data/camera_permission_probe_impl.dart';
import 'package:mobile/features/recording/data/camera_recording_pipeline.dart';
import 'package:mobile/features/recording/data/chunk_metadata_assembler.dart';
import 'package:mobile/features/recording/data/collections/recording_schemas.dart';
import 'package:mobile/features/recording/data/connectivity_plus_connectivity_source.dart';
import 'package:mobile/features/recording/data/connectivity_plus_network_reader.dart';
import 'package:mobile/features/recording/data/free_space_channel.dart';
import 'package:mobile/features/recording/data/isar_chunk_store.dart';
import 'package:mobile/features/recording/data/isolate_video_processor.dart';
import 'package:mobile/features/recording/data/platform_device_context.dart';
import 'package:mobile/features/recording/data/random_uuid_generator.dart';
import 'package:mobile/features/recording/data/shared_preferences_wide_angle_eligibility_cache.dart';
import 'package:mobile/features/recording/data/unavailable_capture_conditions_reader.dart';
import 'package:mobile/features/recording/data/unsourced_task_context.dart';
import 'package:mobile/features/upload/application/upload_dispatcher.dart';
import 'package:mobile/features/upload/application/upload_dispatcher_status_notifier.dart';
import 'package:mobile/features/upload/application/upload_queue_notifier.dart';
import 'package:mobile/features/upload/data/foreground_upload_service_host.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Resolved before the container so the database directory override can be
  // supplied at construction. ADR-009 Caveat 2 makes this the composition
  // root's job: `databaseDirectoryProvider` throws until overridden, because a
  // guessed path is wrong on at least one platform and failing at the override
  // point is easier to diagnose than a database opened somewhere unexpected.
  final Directory documents = await getApplicationDocumentsDirectory();

  // Resolved here for the same reason as the documents directory: obtaining it
  // is asynchronous, and `SharedPreferencesWideAngleEligibilityCache` takes the
  // instance rather than resolving one itself so it stays substitutable in
  // tests. A-057's per-device verdict is what it holds.
  final SharedPreferences preferences = await SharedPreferences.getInstance();

  // The container is built before runApp so that asynchronous startup work can
  // be awaited here rather than inside a widget. ADR-010 requires Firebase to
  // be initialised exactly once, off the widget tree; this is the only place
  // that satisfies both.
  final ProviderContainer container = ProviderContainer(
    overrides: <Override>[
      databaseDirectoryProvider.overrideWithValue(documents.path),
      // The composition root is the only place that may name a concrete
      // implementation: `application/` declares `authRepositoryProvider` and
      // may not import `data/` (ADR-022), so the two are introduced here.
      //
      // Constructing it is safe with Firebase down — ADR-035 made the SDK
      // resolution lazy precisely so this line cannot throw during startup
      // that ADR-017 has already decided to tolerate.
      authRepositoryProvider.overrideWith(
        (Ref ref) => AuthRepositoryImpl(logger: ref.watch(loggerProvider)),
      ),
      // TEMPORARY, retired with ADR-036 at Mission 6/7.
      inviteCodeRepositoryProvider.overrideWithValue(
        InviteCodeRepositoryImpl(),
      ),

      // The recording feature's collections, contributed here rather than by
      // editing `core/database/`. ADR-039 §2: the engine's module has no
      // knowledge of any feature collection, and invariant I41 forbids `core/`
      // importing `features/` — so the composition root is the only place the
      // two can meet.
      databaseConfigProvider.overrideWith(
        (Ref ref) => DatabaseConfig(
          directory: ref.watch(databaseDirectoryProvider),
          inspector: AppFeatureFlags.forEnvironment(
            AppConfig.environment,
          ).databaseInspectorEnabled,
        ).withSchemas(RecordingSchemas.all),
      ),

      ...recordingOverrides(documents.path, preferences),
      ...uploadOverrides(),
    ],
  );
  final AppLogger logger = container.read(loggerProvider);

  _announceEnvironment(logger);
  await _initializeFirebase(container, logger);
  await _openDatabase(container, logger);
  await _restoreSession(container, logger);
  _startUploadDispatcher(container, logger);
  _startStorageCleanup(container, logger);

  runApp(
    UncontrolledProviderScope(container: container, child: const VumpApp()),
  );
}

/// Introduces every `features/recording/` port to its implementation.
///
/// **Public so that an alternate entrypoint binds the same wiring.** A second
/// `--target` that re-declared this list could verify a composition the
/// application does not actually ship, which is worse than not verifying it —
/// so there is one list and both entrypoints read it.
///
/// ## Why they are all here and none of them have defaults
///
/// `application/` declares the providers and may not import `data/`
/// (ADR-022 §5.3), so a default would have to name a class it cannot see.
/// Every one of these therefore throws `UnimplementedError` until this
/// function overrides it — the same arrangement `authRepositoryProvider` has
/// had since Mission 2.2. It fails loudly at the override point rather than
/// quietly at first use.
///
/// [documentsPath] is the writable application directory, already resolved for
/// the database.
///
/// ## `chunkStoreProvider` reads the database synchronously, and that is safe
///
/// `databaseProvider` is a `FutureProvider`, but `main` awaits it before
/// `runApp`, so by the time anything reads a store the future has completed.
/// `requireValue` states that expectation rather than hiding it behind a
/// silent null — if the ordering in `main` ever changes, this throws where the
/// mistake is instead of recording chunks into nothing.
List<Override> recordingOverrides(
  String documentsPath,
  SharedPreferences preferences,
) {
  return <Override>[
    recordingsDirectoryProvider.overrideWithValue(documentsPath),

    recordingPipelineProvider.overrideWith(
      (Ref ref) => CameraRecordingPipeline(outputDirectoryPath: documentsPath),
    ),
    freeSpaceReaderProvider.overrideWith((Ref ref) => const FreeSpaceChannel()),

    // One generator, two ports — see RandomUuidGenerator on why `uuid` is not
    // a dependency. Shared instance so both draw from one secure source.
    sessionIdGeneratorProvider.overrideWith(
      (Ref ref) => ref.watch(_uuidGeneratorProvider),
    ),
    chunkIdGeneratorProvider.overrideWith(
      (Ref ref) => ref.watch(_uuidGeneratorProvider),
    ),

    // Checklist rows.
    cameraPermissionProbeProvider.overrideWith(
      (Ref ref) => CameraPermissionProbeImpl(),
    ),
    cameraCapabilityProbeProvider.overrideWith(
      (Ref ref) => CameraCapabilityProbeImpl(),
    ),
    wideAngleEligibilityCacheProvider.overrideWith(
      (Ref ref) => SharedPreferencesWideAngleEligibilityCache(preferences),
    ),
    batteryReaderProvider.overrideWith((Ref ref) => BatteryPlusBatteryReader()),
    // ONE Connectivity instance behind BOTH ports. Volume 5 Chapter 5.12 §2
    // requires that the queue and the dispatcher "neither polls it
    // independently, avoiding duplicated battery cost", and there are two
    // ports above this plugin: NetworkReader answers FR-CHK-04's one-shot
    // checklist question, ConnectivitySource carries §4's transition stream.
    //
    // Sharing the instance is what makes §2 true at the layer it is about —
    // one plugin channel, one platform subscription — without editing the
    // checklist path Mission 3 verified on hardware. A-081.
    networkReaderProvider.overrideWith(
      (Ref ref) => ConnectivityPlusNetworkReader(
        connectivity: ref.watch(_connectivityProvider),
      ),
    ),

    // One IsarChunkStore behind both contracts it satisfies. It implements
    // ChunkStore (declared in features/recording/domain/) and
    // ChunkQueueSource (declared in core/queue/), and ADR-040 explains why
    // the second lives in core/: it is what lets features/upload/ read these
    // rows without importing features/recording/.
    //
    // Sharing one instance matters — the queue must observe exactly the rows
    // the finalizer writes, not a second connection's view of them.
    _chunkStoreProvider.overrideWith(
      (Ref ref) => IsarChunkStore(
        database: ref.watch(databaseProvider).requireValue,
        documentsDirectoryPath: documentsPath,
      ),
    ),
    chunkStoreProvider.overrideWith(
      (Ref ref) => ref.watch(_chunkStoreProvider),
    ),
    chunkQueueSourceProvider.overrideWith(
      (Ref ref) => ref.watch(_chunkStoreProvider),
    ),

    // Mission 4.2's two additions, behind the same instance. Chapter 5.10's
    // pipeline must move exactly the rows C-11 renders and the finalizer
    // wrote — four contracts, one store, one connection.
    //
    // sessionRegistrarProvider is deliberately NOT overridden: no
    // implementation exists, because it needs a task_id that
    // features/projects_tasks/ owns and that feature is unbuilt. The pipeline
    // therefore throws at that seam rather than uploading, which is the
    // feature's honest state. A fake satisfies it in the test suite only —
    // Volume 11's M12 gate makes a fake wired into a build a defect.
    chunkUploadSourceProvider.overrideWith(
      (Ref ref) => ref.watch(_chunkStoreProvider),
    ),
    chunkMetadataSourceProvider.overrideWith(
      (Ref ref) => ref.watch(_chunkStoreProvider),
    ),

    // Volume 3 Ch. 3.9 §4's FinalizeChunkUseCase — Chapters 5.5, 5.7 and 5.8
    // joined. Mission 3.8 wrote it; until then this provider had no
    // implementation at all and the first chunk boundary would have thrown.
    chunkFinalizerProvider.overrideWith(
      (Ref ref) => FinalizeChunkUseCase(
        videoProcessor: const IsolateVideoProcessor(),
        metadataGenerator: const ChunkMetadataAssembler(
          taskContext: UnsourcedTaskContext(),
          // `app/config/` is granted to `core/` and `shared/` by ADR-022 and
          // not to a feature's `data/`, so the version is read here and passed
          // in rather than imported there.
          deviceContext: PlatformDeviceContext(appVersion: AppInfo.fullVersion),
          conditionsReader: UnavailableCaptureConditionsReader(),
        ),
        chunkStore: ref.watch(chunkStoreProvider),
      ),
    ),
  ];
}

/// Introduces every `features/upload/` port to its implementation.
///
/// Public for the same reason [recordingOverrides] is: a second `--target`
/// binds this exact list rather than re-declaring one that could drift from
/// what the application ships.
///
/// ## Only one port, and the two that are deliberately absent
///
/// `uploadServiceHostProvider` is the only entry. The other two seams
/// `features/upload/` declares are bound elsewhere or not at all:
///
/// - `chunkUploadSourceProvider` and `chunkMetadataSourceProvider` are in
///   [recordingOverrides], because the one `IsarChunkStore` satisfies them.
/// - `sessionRegistrarProvider` has no implementation anywhere. It needs a
///   `task_id` that `features/projects_tasks/` owns, and that feature is
///   unbuilt (open item 36). The pipeline therefore throws at that seam, and
///   `UploadDispatcher` converts the throw into a logged stop rather than a
///   crash. A fake satisfies it in the test suite only.
List<Override> uploadOverrides() {
  return <Override>[
    // Volume 5 Chapter 5.11 §1's Android foreground service. ADR-042 records
    // why the upload runs in this isolate and the service merely keeps the
    // process alive around it.
    uploadServiceHostProvider.overrideWith(
      (Ref ref) => ForegroundUploadServiceHost(),
    ),

    // Chapter 5.12 §2's ConnectivityService. Declared in core/, implemented in
    // features/recording/data/ because connectivity_plus is confined there --
    // ADR-040's pattern applied a fifth time, and its most lopsided instance.
    // A-081 records why the asymmetry was accepted rather than corrected.
    connectivitySourceProvider.overrideWith(
      (Ref ref) => ConnectivityPlusConnectivitySource(
        connectivity: ref.watch(_connectivityProvider),
      ),
    ),
  ];
}

/// The single `connectivity_plus` handle, shared by both ports above.
///
/// Private because nothing outside this file should depend on the plugin type
/// -- each layer sees only its own port. Declaring it here is what keeps one
/// instance behind both overrides, which is the whole of Chapter 5.12 §2's
/// "neither polls it independently".
final Provider<Connectivity> _connectivityProvider = Provider<Connectivity>(
  (Ref ref) => Connectivity(),
);

/// The one IsarChunkStore, shared by both contracts it satisfies.
///
/// Private because nothing outside this file should depend on the concrete
/// type — each `application/` layer sees only its own port. Declaring it here
/// is what keeps a single instance behind both overrides above.
final Provider<IsarChunkStore> _chunkStoreProvider = Provider<IsarChunkStore>(
  (Ref ref) => throw UnimplementedError('overridden in main()'),
);

/// One shared UUID source behind both id ports.
final Provider<RandomUuidGenerator> _uuidGeneratorProvider =
    Provider<RandomUuidGenerator>((Ref ref) => RandomUuidGenerator());

/// Records which environment this build resolved to, and warns if it fell back.
///
/// ADR-007 requires an unrecognised `APP_ENV` to be logged rather than
/// silently defaulting. A silent fallback hides a typo in a release pipeline —
/// the build succeeds, ships, and points at the wrong infrastructure.
///
/// This runs before anything else so the first line in any diagnostic report
/// says which environment produced everything after it.
void _announceEnvironment(AppLogger logger) {
  if (!AppConfig.environmentWasRecognised) {
    logger.warning(
      'APP_ENV was set to "${AppConfig.rawEnvironmentValue}", which is not a '
      'recognised environment. Falling back to '
      '${AppEnvironment.defaultEnvironment.label}. Expected one of: '
      '${AppEnvironment.values.map((AppEnvironment e) => e.key).join(', ')}.',
    );
  }

  logger.info(
    '${AppInfo.appName} ${AppInfo.fullVersion} starting — '
    '${EnvironmentProfile.current.describe()}',
  );
}

/// Brings up the Firebase platform before the first frame.
///
/// Awaiting the provider here means every Firebase product is usable from the
/// first frame, and no widget ever triggers initialisation.
///
/// Whether a failure is fatal is environment-driven, per ADR-017. In
/// development it is survivable, so an unconfigured or offline machine can
/// still run the app while no feature depends on Firebase. In staging and
/// production it aborts startup, because a build that silently runs without
/// the platform it was built against is worse than one that fails loudly.
Future<void> _initializeFirebase(
  ProviderContainer container,
  AppLogger logger,
) async {
  final bool isFatal = AppFeatureFlags.forEnvironment(
    AppConfig.environment,
  ).firebaseFailureIsFatal;

  try {
    await container.read(firebaseAppProvider.future);
  } on AppException catch (error, stackTrace) {
    if (isFatal) {
      logger.fatal(
        'Firebase initialisation failed in ${AppConfig.environment.label}. '
        'Aborting startup rather than running against an uninitialised '
        'platform.',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }

    logger.error(
      'Starting without Firebase. Products that depend on it will fail.',
      error: error,
    );
  }
}

/// Resolves who is signed in before the first frame.
///
/// Volume 6 Chapter 6.7 §3 requires the session to be resolved *"only at app
/// cold-start, to attempt silent re-authentication before falling back to the
/// Login screen"*. Awaiting `authNotifierProvider` here is what puts that on
/// the startup path: `AuthNotifier.build` calls `restoreSession`, and until
/// this line existed nothing read the provider, so the restore never ran until
/// something happened to watch it.
///
/// ADR-008 predicted the shape of this: *"the session cannot be known
/// synchronously before `runApp`, so the router needs a loading state while
/// the token is read"*. Awaiting it here satisfies the constraint without a
/// loading state in the router, because the OS-native splash already covers
/// the window — the first Flutter frame is drawn after the answer is known.
///
/// ## There is no token to read, and that is not an omission
///
/// Volume 6 Chapter 6.7 §2 expects the Firebase refresh token to live in
/// `flutter_secure_storage`. It cannot: `firebase_auth` documents
/// `User.refreshToken` as *"an empty string for native platforms (android, iOS
/// & macOS)"*, so the value this application would store is not obtainable
/// through the API. The native SDK persists its own credential in the
/// platform's keystore instead, which is the same protection by a different
/// owner. Registered as amendment A-055.
///
/// ## Failure is never fatal
///
/// Unlike the database, an unresolvable session is a normal outcome — nobody
/// has signed in yet on a fresh install. `AuthNotifier` already converts a
/// failed restore into `unauthenticated` rather than an error, so this await
/// resolves either way; the guard here is for a defect in that conversion, not
/// for the expected path.
Future<void> _restoreSession(
  ProviderContainer container,
  AppLogger logger,
) async {
  try {
    await container.read(authNotifierProvider.future);
  } on Object catch (error, stackTrace) {
    logger.error(
      'The session could not be resolved at startup. Continuing signed out.',
      error: error,
      stackTrace: stackTrace,
    );
  }
}

/// Starts Volume 5 Chapter 5.11's Background Upload dispatcher.
///
/// Placed after [_openDatabase] because the dispatcher subscribes to the queue
/// immediately, and the queue is a live view over rows the database has to be
/// holding first.
///
/// ## Not awaited, unlike everything above it
///
/// The other startup steps block the first frame because something on that
/// frame depends on their answer — which environment, who is signed in,
/// whether persistence works. Uploading is not one of those: Chapter 2.9 §2
/// principle 3 has it happen *while* the Collector does something else, and
/// FR-UPL-04 lets a new session start while an earlier one is still
/// uploading. Awaiting a drain here would hold the splash screen for the
/// length of a video upload.
///
/// ## Nothing uploads today, and it fails visibly rather than silently
///
/// `sessionRegistrarProvider` throws until `features/projects_tasks/` exists
/// (open item 36), so the first claimed chunk ends in `UploadDispatcher`
/// logging a wiring fault and stopping. That is the honest state of the
/// feature: A-068's Guard 1 would refuse every chunk on a real device anyway,
/// because four of `MetadataIdentity`'s five fields still carry the unsourced
/// sentinel (open item 37).
///
/// Starting it regardless is deliberate. A dispatcher wired but never started
/// would be verified only by its own tests, and Mission 3.8.1 is the standing
/// lesson that an unstarted path reports green while nothing calls it
/// (open item 32).
void _startUploadDispatcher(ProviderContainer container, AppLogger logger) {
  try {
    container.read(uploadDispatcherProvider).start();
  } on Object catch (error, stackTrace) {
    logger.error(
      'The upload dispatcher could not be started. Recording is unaffected '
      'and queued chunks stay on disk (BR-08).',
      error: error,
      stackTrace: stackTrace,
    );
    // The dispatcher never ran, so it cannot report its own fault. C-11 must
    // still be able to say uploads are not running - open item 60.
    container.read(uploadDispatcherStatusProvider.notifier).markHalted();
  }
}

/// Starts Volume 5 Chapter 5.15's storage cleanup sweep.
///
/// After [_openDatabase], because the sweep reads chunk rows; after the
/// dispatcher, because a chunk only becomes eligible once the pipeline has
/// confirmed it, and starting cleanup first would only ever find last
/// session's leftovers a few milliseconds sooner.
///
/// ## Not awaited, and not fatal
///
/// §2 makes cleanup explicitly non-urgent — *"deleting a large video file is
/// not time-critical"*. Awaiting it would hold the first frame behind file
/// I/O for no benefit, and a cleanup that cannot run costs disk space rather
/// than data: BR-08 means the failure mode is files that should have gone and
/// did not, never the reverse.
void _startStorageCleanup(ProviderContainer container, AppLogger logger) {
  try {
    container.read(storageCleanupSweepProvider).start();
  } on Object catch (error, stackTrace) {
    logger.error(
      'Storage cleanup could not be started. Confirmed chunks will stay on '
      'disk until a later launch reclaims them.',
      error: error,
      stackTrace: stackTrace,
    );
  }
}

/// Opens the local database before the first frame.
///
/// Awaiting `databaseProvider` here is what puts the open on the startup path,
/// which Volume 6 Chapter 6.1 §2's bootstrap sequence requires and ADR-009
/// assumes when it records that "database open is on the startup path, so its
/// duration is worth recording".
///
/// ## Opening exactly once
///
/// Two mechanisms combine, and neither is sufficient alone. Riverpod caches the
/// `FutureProvider`, so a later `ref.watch(databaseProvider)` from a widget
/// receives this same future rather than starting a second open. Beneath it,
/// `DatabaseService.open` holds the in-flight `Future` rather than the
/// instance, so even direct concurrent callers await the first open — the
/// guarantee ADR-009 requires by construction rather than by convention.
///
/// ## Failure aborts startup
///
/// **ADR-009 does not specify a failure policy for startup**, and this is the
/// choice made here: a database that cannot open is fatal in every
/// environment, unlike Firebase, whose policy ADR-017 makes environment-driven
/// via `AppFeatureFlags.firebaseFailureIsFatal`.
///
/// The reasoning is that the two are not comparable. Firebase is survivable in
/// development because no feature depends on it yet. The database is the
/// offline-first foundation the Constitution §3 requires — every core workflow
/// must work with no network, and `NFR-REL-04` requires the upload queue to
/// survive a force-close. An application running without local persistence
/// cannot honour "never lose a take"; it is broken rather than degraded, and
/// continuing would hide that.
///
/// This is the second `fatal` call site in the codebase. `logging-standards.md`
/// §5 records that adding one is a decision rather than a detail, which is why
/// the reasoning is here and not left implicit.
Future<void> _openDatabase(
  ProviderContainer container,
  AppLogger logger,
) async {
  try {
    await container.read(databaseProvider.future);
  } on AppException catch (error, stackTrace) {
    logger.fatal(
      'The local database could not be opened. Aborting startup rather than '
      'running without local persistence.',
      error: error,
      stackTrace: stackTrace,
    );
    rethrow;
  }
}
