import 'dart:io' show Platform;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mobile/app/config/app_config.dart';
import 'package:mobile/core/errors/app_exception.dart';
import 'package:mobile/features/recording/application/recording_notifier.dart';
import 'package:mobile/features/recording/domain/entities/camera_capability.dart';
import 'package:mobile/features/recording/domain/entities/camera_specification.dart';
import 'package:mobile/features/recording/domain/entities/checklist_check.dart';
import 'package:mobile/features/recording/domain/entities/checklist_outcome.dart';
import 'package:mobile/features/recording/domain/entities/device_fingerprint.dart';
import 'package:mobile/features/recording/domain/entities/network_type.dart';
import 'package:mobile/features/recording/domain/entities/wide_angle_eligibility.dart';
import 'package:mobile/features/recording/domain/entities/wide_angle_tier.dart';
import 'package:mobile/features/recording/domain/repositories/battery_reader.dart';
import 'package:mobile/features/recording/domain/repositories/camera_capability_probe.dart';
import 'package:mobile/features/recording/domain/repositories/camera_permission_probe.dart';
import 'package:mobile/features/recording/domain/repositories/network_reader.dart';
import 'package:mobile/features/recording/domain/repositories/wide_angle_eligibility_cache.dart';
import 'package:mobile/features/recording/domain/wide_angle_ladder.dart';

/// The camera/microphone probe, overridden at the composition root.
final Provider<CameraPermissionProbe> cameraPermissionProbeProvider =
    Provider<CameraPermissionProbe>(
      (Ref ref) => throw UnimplementedError(
        'cameraPermissionProbeProvider must be overridden. '
        'features/recording/data/ provides CameraPermissionProbeImpl.',
      ),
    );

/// The wide-angle capability probe, overridden at the composition root.
final Provider<CameraCapabilityProbe> cameraCapabilityProbeProvider =
    Provider<CameraCapabilityProbe>(
      (Ref ref) => throw UnimplementedError(
        'cameraCapabilityProbeProvider must be overridden. '
        'features/recording/data/ provides CameraCapabilityProbeImpl.',
      ),
    );

/// The eligibility cache, overridden at the composition root.
final Provider<WideAngleEligibilityCache> wideAngleEligibilityCacheProvider =
    Provider<WideAngleEligibilityCache>(
      (Ref ref) => throw UnimplementedError(
        'wideAngleEligibilityCacheProvider must be overridden. '
        'features/recording/data/ provides '
        'SharedPreferencesWideAngleEligibilityCache.',
      ),
    );

/// The battery reader, overridden at the composition root.
final Provider<BatteryReader> batteryReaderProvider = Provider<BatteryReader>(
  (Ref ref) => throw UnimplementedError(
    'batteryReaderProvider must be overridden with a BatteryReader. '
    'features/recording/data/ provides BatteryPlusBatteryReader.',
  ),
);

/// The network reader, overridden at the composition root.
final Provider<NetworkReader> networkReaderProvider = Provider<NetworkReader>(
  (Ref ref) => throw UnimplementedError(
    'networkReaderProvider must be overridden with a NetworkReader. '
    'features/recording/data/ provides ConnectivityPlusNetworkReader.',
  ),
);

/// The directory free space is measured against, supplied at the composition
/// root because resolving it needs `path_provider`.
final Provider<String> recordingsDirectoryProvider = Provider<String>(
  (Ref ref) => throw UnimplementedError(
    'recordingsDirectoryProvider must be overridden with a writable path.',
  ),
);

/// Runs Volume 2 Chapter 2.7's C-07 and holds its readings.
///
/// ## The rows run in order, not in parallel
///
/// Permission first, capability last. Volume 5 Chapter 5.1 §3 puts the grant
/// before the probe and A-057 explains why it has to be: the Tier 2 reading
/// opens the camera, and an open without permission fails for a reason that
/// has nothing to do with the lens. Running them concurrently would produce a
/// capability failure caused by a permission problem, which is exactly the
/// misdiagnosis FR-CHK-05 exists to prevent.
///
/// Storage, battery and network have no such ordering constraint and are still
/// run in row order — five sequential platform reads cost less than the
/// camera open that precedes them, and a deterministic order makes the screen
/// fill top to bottom instead of at random.
///
/// ## Failure of one row is not failure of the checklist
///
/// Each read is caught individually. A battery reading that throws leaves that
/// row failed and lets the other four answer, because C-08 must *name the
/// specific failed check*, and a checklist that abandons the run on the first
/// error can only report the first problem.
class ChecklistNotifier extends Notifier<ChecklistOutcome> {
  @override
  ChecklistOutcome build() => ChecklistOutcome.pending;

  /// Runs every row, in order. Volume 2's C-07 entry behaviour.
  Future<void> runAll() async {
    state = ChecklistOutcome.pending;
    for (final ChecklistCheck check in ChecklistCheck.values) {
      await rerun(check);
    }
  }

  /// Re-runs one row.
  ///
  /// Volume 2 Chapter 2.7's C-08 requires exactly this granularity: the
  /// re-run action *"re-runs the specific failed check only, not the full
  /// checklist, so a fixed battery doesn't force re-granting an already-granted
  /// permission"*.
  Future<void> rerun(ChecklistCheck check) async {
    switch (check) {
      case ChecklistCheck.cameraAndMicrophone:
        await _checkPermissions();
      case ChecklistCheck.freeStorage:
        await _checkStorage();
      case ChecklistCheck.batteryLevel:
        await _checkBattery();
      case ChecklistCheck.network:
        await _checkNetwork();
      case ChecklistCheck.wideAngleCapability:
        await _checkWideAngle();
    }
  }

  Future<void> _checkPermissions() async {
    try {
      await ref.read(cameraPermissionProbeProvider).verify();
      state = state.copyWith(permissionsGranted: true);
    } on AppException catch (exception) {
      state = state.copyWith(
        permissionsGranted: false,
        permissionFailure: exception.errorCode,
      );
    }
  }

  Future<void> _checkStorage() async {
    try {
      final int bytes = await ref
          .read(freeSpaceReaderProvider)
          .availableBytes(ref.read(recordingsDirectoryProvider));
      state = state.copyWith(availableBytes: bytes);
    } on AppException {
      // Left unmeasured, which `passes` treats as a failure. A free-space
      // reading that could not be taken is not a reading that passed.
      state = state.copyWith(availableBytes: 0);
    }
  }

  Future<void> _checkBattery() async {
    try {
      state = state.copyWith(
        batteryPercent: await ref.read(batteryReaderProvider).percent(),
      );
    } on AppException {
      state = state.copyWith(batteryPercent: 0);
    }
  }

  Future<void> _checkNetwork() async {
    try {
      state = state.copyWith(
        network: await ref.read(networkReaderProvider).current(),
      );
    } on AppException {
      // Unreadable is reported as no connection. FR-CHK-04 never blocks, so
      // the only consequence is that the row says upload will queue — which
      // is the safe thing to tell someone whose connectivity is unknown.
      state = state.copyWith(network: NetworkType.none);
    }
  }

  /// A-057's row: cached per device, probed only when the cache cannot answer.
  ///
  /// The fingerprint is the app version and the OS version, and nothing else.
  /// A verdict does not decay with age — it becomes wrong only when the code
  /// that produced it changes or the platform that answered it does, and both
  /// arrive as a version bump.
  Future<void> _checkWideAngle() async {
    final DeviceFingerprint fingerprint = DeviceFingerprint(
      appVersion: AppInfo.fullVersion,
      osVersion: Platform.operatingSystemVersion,
    );
    final WideAngleEligibilityCache cache = ref.read(
      wideAngleEligibilityCacheProvider,
    );

    try {
      final WideAngleTier? cached = await cache.read(fingerprint);
      final WideAngleEligibility? exact = _exactlyFromTier(cached);
      if (exact != null) {
        state = state.copyWith(wideAngle: exact);
        return;
      }

      final CameraCapability capability = await ref
          .read(cameraCapabilityProbeProvider)
          .probe();
      final WideAngleEligibility verdict = WideAngleLadder.resolve(capability);
      await cache.write(tier: verdict.tier, fingerprint: fingerprint);
      state = state.copyWith(wideAngle: verdict);
    } on AppException {
      // A probe that failed is not a device without a wide lens. It is
      // reported as ineligible so the row fails visibly and the Collector can
      // re-run it, and deliberately **not** written to the cache — caching a
      // failed read would make one bad probe permanent until the next release.
      state = state.copyWith(
        wideAngle: const WideAngleEligibility.ineligible(
          reason: WideAngleIneligibleReason.noWideAngleCapability,
        ),
      );
    }
  }

  /// Rebuilds a verdict from a cached tier — **only when the tier determines
  /// the factor**, and null otherwise.
  ///
  /// ## The cache cannot answer for Tier 2, and this is a defect in its shape
  ///
  /// `WideAngleEligibilityCache` stores a `WideAngleTier` and nothing else.
  /// For two of the three tiers that is lossless: Tier 1 always resolves to
  /// `zoomFactorOptical`, and `unsupported` carries no factor at all.
  ///
  /// **Tier 2 is not.** `WideAngleLadder` snaps the sensor's reported minimum
  /// to the nearer permitted factor, so `primarySensorZoom` resolves to 0.5 on
  /// a device that reaches 0.5 and 0.6 on one that stops at 0.6 — and the
  /// stored tier is identical in both cases. Reconstructing a factor from it
  /// would hand a 0.5-capable device 0.6 on every session after its first,
  /// which is precisely what Chapter 5.2 §2 forbids: *"footage from the same
  /// device is always comparable to itself over time."*
  ///
  /// So a cached Tier 2 returns null here and the probe runs. That is correct
  /// and it is slower than A-057 intended — a camera open before every session
  /// on exactly the devices the Android path produces most often, the CPH2707
  /// included. The fix is to store the factor beside the tier, which changes a
  /// port and a persisted format committed in Mission 3.1; recorded in A-064
  /// and deliberately not taken here.
  static WideAngleEligibility? _exactlyFromTier(WideAngleTier? tier) =>
      switch (tier) {
        null => null,
        WideAngleTier.opticalDedicated => const WideAngleEligibility.optical(
          zoomFactor: CameraSpecification.zoomFactorOptical,
        ),
        // Ambiguous — re-probe rather than guess. See above.
        WideAngleTier.primarySensorZoom => null,
        WideAngleTier.unsupported => const WideAngleEligibility.ineligible(
          reason: WideAngleIneligibleReason.noWideAngleCapability,
        ),
      };
}

/// The live Pre-Recording Checklist.
final NotifierProvider<ChecklistNotifier, ChecklistOutcome>
checklistNotifierProvider =
    NotifierProvider<ChecklistNotifier, ChecklistOutcome>(
      ChecklistNotifier.new,
    );
