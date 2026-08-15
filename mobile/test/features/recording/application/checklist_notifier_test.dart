import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/errors/error_codes.dart';
import 'package:mobile/core/errors/exceptions/device_exception.dart';
import 'package:mobile/features/recording/application/checklist_notifier.dart';
import 'package:mobile/features/recording/application/recording_notifier.dart';
import 'package:mobile/features/recording/domain/entities/camera_capability.dart';
import 'package:mobile/features/recording/domain/entities/checklist_check.dart';
import 'package:mobile/features/recording/domain/entities/checklist_outcome.dart';
import 'package:mobile/features/recording/domain/entities/device_fingerprint.dart';
import 'package:mobile/features/recording/domain/entities/network_type.dart';
import 'package:mobile/features/recording/domain/entities/wide_angle_tier.dart';
import 'package:mobile/features/recording/domain/repositories/battery_reader.dart';
import 'package:mobile/features/recording/domain/repositories/camera_capability_probe.dart';
import 'package:mobile/features/recording/domain/repositories/camera_permission_probe.dart';
import 'package:mobile/features/recording/domain/repositories/free_space_reader.dart';
import 'package:mobile/features/recording/domain/repositories/network_reader.dart';
import 'package:mobile/features/recording/domain/repositories/wide_angle_eligibility_cache.dart';

/// The Checklist runner — sequencing, isolation of failures, and the cache.
///
/// The verdict arithmetic is a pure table in `checklist_outcome_test.dart`.
/// What is only observable here is what the notifier owns: the order the rows
/// run in, that one bad row does not abandon the others, and when the
/// wide-angle probe is allowed to be skipped.
void main() {
  ProviderContainer build({
    Exception? permissionThrows,
    int freeBytes = 50 * 1000 * 1000 * 1000,
    Exception? freeSpaceThrows,
    int battery = 90,
    Exception? batteryThrows,
    NetworkType network = NetworkType.wifi,
    Exception? networkThrows,
    WideAngleTier? cachedTier,
    CameraCapability? capability,
    required List<String> order,
  }) {
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        cameraPermissionProbeProvider.overrideWithValue(
          _FakePermissionProbe(order, permissionThrows),
        ),
        freeSpaceReaderProvider.overrideWithValue(
          _FakeFreeSpace(order, freeBytes, freeSpaceThrows),
        ),
        recordingsDirectoryProvider.overrideWithValue('/files'),
        batteryReaderProvider.overrideWithValue(
          _FakeBattery(order, battery, batteryThrows),
        ),
        networkReaderProvider.overrideWithValue(
          _FakeNetwork(order, network, networkThrows),
        ),
        wideAngleEligibilityCacheProvider.overrideWithValue(
          _FakeCache(cachedTier),
        ),
        cameraCapabilityProbeProvider.overrideWithValue(
          _FakeCapabilityProbe(
            order,
            capability ??
                const CameraCapability(
                  hasRearCamera: true,
                  hasDedicatedUltraWide: null,
                  minimumZoomFactor: 0.6,
                ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  ChecklistNotifier notifierOf(ProviderContainer c) =>
      c.read(checklistNotifierProvider.notifier);
  ChecklistOutcome stateOf(ProviderContainer c) =>
      c.read(checklistNotifierProvider);

  group('sequencing — Ch. 5.1 §3 puts permission before the probe', () {
    test('permission runs first and the capability probe last', () async {
      // A-057: the Tier 2 reading opens the camera, which cannot succeed
      // without the grant. Running them in the other order would report a
      // capability failure caused by a permission problem — exactly the
      // misdiagnosis FR-CHK-05 exists to prevent.
      final List<String> order = <String>[];
      await notifierOf(build(order: order)).runAll();

      expect(order.first, 'permission');
      expect(order.last, 'capability');
    });

    test('every row is measured after a full run', () async {
      final ProviderContainer c = build(order: <String>[]);
      await notifierOf(c).runAll();

      for (final ChecklistCheck check in ChecklistCheck.values) {
        expect(stateOf(c).isMeasured(check), isTrue, reason: check.name);
      }
      expect(stateOf(c).allPassed, isTrue);
    });
  });

  group('one bad row does not abandon the rest', () {
    test('a permission refusal still leaves the other four measured', () async {
      // C-08 must name the specific failed check. A run that stopped at the
      // first error could only ever report one problem.
      final ProviderContainer c = build(
        order: <String>[],
        permissionThrows: const DeviceException(
          errorCode: ErrorCode.devicePermissionCameraDenied,
          message: 'denied',
        ),
      );
      await notifierOf(c).runAll();

      expect(stateOf(c).permissionsGranted, isFalse);
      expect(stateOf(c).isMeasured(ChecklistCheck.batteryLevel), isTrue);
      expect(stateOf(c).isMeasured(ChecklistCheck.network), isTrue);
      expect(stateOf(c).allPassed, isFalse);
    });

    test('the refusal keeps the code, so C-08 can name which grant', () async {
      final ProviderContainer c = build(
        order: <String>[],
        permissionThrows: const DeviceException(
          errorCode: ErrorCode.devicePermissionMicrophoneDenied,
          message: 'denied',
        ),
      );
      await notifierOf(c).runAll();

      expect(
        stateOf(c).permissionFailure,
        ErrorCode.devicePermissionMicrophoneDenied,
      );
    });

    test('an unreadable battery fails its row rather than passing', () async {
      final ProviderContainer c = build(
        order: <String>[],
        batteryThrows: const DeviceException(
          errorCode: ErrorCode.deviceBatteryUnreadable,
          message: 'no answer',
        ),
      );
      await notifierOf(c).runAll();

      expect(stateOf(c).passes(ChecklistCheck.batteryLevel), isFalse);
    });

    test('an unreadable network reports offline and still passes', () async {
      // FR-CHK-04 never blocks. Telling someone uploads will queue is the
      // safe thing to say when connectivity is unknown.
      final ProviderContainer c = build(
        order: <String>[],
        networkThrows: const DeviceException(
          errorCode: ErrorCode.deviceNetworkStatusUnreadable,
          message: 'no answer',
        ),
      );
      await notifierOf(c).runAll();

      expect(stateOf(c).network, NetworkType.none);
      expect(stateOf(c).allPassed, isTrue);
    });
  });

  group('the wide-angle cache is used only when it is exact', () {
    test('a cached Tier 1 skips the probe entirely', () async {
      // Tier 1 always resolves to zoomFactorOptical, so the tier determines
      // the factor and A-057's per-session probe is genuinely avoidable.
      final List<String> order = <String>[];
      final ProviderContainer c = build(
        order: order,
        cachedTier: WideAngleTier.opticalDedicated,
      );
      await notifierOf(c).runAll();

      expect(order, isNot(contains('capability')));
      expect(stateOf(c).resolvedZoomFactor, 0.5);
    });

    test('a cached Tier 2 re-probes — the factor is ambiguous', () async {
      // primarySensorZoom resolves to 0.5 on a device that reaches 0.5 and 0.6
      // on one that stops at 0.6, and the stored tier is identical. Rebuilding
      // a factor from it would hand a 0.5-capable device 0.6 on every session
      // after its first — what Ch. 5.2 §2 forbids.
      final List<String> order = <String>[];
      final ProviderContainer c = build(
        order: order,
        cachedTier: WideAngleTier.primarySensorZoom,
        capability: const CameraCapability(
          hasRearCamera: true,
          hasDedicatedUltraWide: null,
          minimumZoomFactor: 0.5,
        ),
      );
      await notifierOf(c).runAll();

      expect(order, contains('capability'));
      expect(
        stateOf(c).resolvedZoomFactor,
        0.5,
        reason: 'the probe answered 0.5; the cache would have said 0.6',
      );
    });

    test('a cached unsupported verdict blocks without a probe', () async {
      final List<String> order = <String>[];
      final ProviderContainer c = build(
        order: order,
        cachedTier: WideAngleTier.unsupported,
      );
      await notifierOf(c).runAll();

      expect(order, isNot(contains('capability')));
      expect(stateOf(c).allPassed, isFalse);
    });

    test('a failed probe blocks and is not written to the cache', () async {
      // Caching a failed read would make one bad probe permanent until the
      // next release, because the fingerprint is app and OS version only.
      final _FakeCache cache = _FakeCache(null);
      final ProviderContainer c = ProviderContainer(
        overrides: <Override>[
          cameraPermissionProbeProvider.overrideWithValue(
            _FakePermissionProbe(<String>[], null),
          ),
          freeSpaceReaderProvider.overrideWithValue(
            _FakeFreeSpace(<String>[], 50 * 1000 * 1000 * 1000, null),
          ),
          recordingsDirectoryProvider.overrideWithValue('/files'),
          batteryReaderProvider.overrideWithValue(
            _FakeBattery(<String>[], 90, null),
          ),
          networkReaderProvider.overrideWithValue(
            _FakeNetwork(<String>[], NetworkType.wifi, null),
          ),
          wideAngleEligibilityCacheProvider.overrideWithValue(cache),
          cameraCapabilityProbeProvider.overrideWithValue(
            _ThrowingCapabilityProbe(),
          ),
        ],
      );
      addTearDown(c.dispose);

      await c.read(checklistNotifierProvider.notifier).runAll();

      expect(cache.writes, 0);
      expect(
        c
            .read(checklistNotifierProvider)
            .passes(ChecklistCheck.wideAngleCapability),
        isFalse,
      );
    });
  });

  group('a single row can be re-run — C-08s action', () {
    test('re-running battery does not re-run permission', () async {
      // "so a fixed battery doesn't force re-granting an already-granted
      // permission" — Volume 2 Ch. 2.7, C-08.
      final List<String> order = <String>[];
      final ProviderContainer c = build(order: order);
      await notifierOf(c).runAll();
      order.clear();

      await notifierOf(c).rerun(ChecklistCheck.batteryLevel);

      expect(order, <String>['battery']);
    });

    test('a re-run picks up a changed value', () async {
      // C-07 requires live re-evaluation "if a value changes (e.g. battery
      // drains) while the screen is open".
      final _FakeBattery battery = _FakeBattery(<String>[], 90, null);
      final ProviderContainer c = ProviderContainer(
        overrides: <Override>[
          batteryReaderProvider.overrideWithValue(battery),
          recordingsDirectoryProvider.overrideWithValue('/files'),
        ],
      );
      addTearDown(c.dispose);

      await c
          .read(checklistNotifierProvider.notifier)
          .rerun(ChecklistCheck.batteryLevel);
      expect(c.read(checklistNotifierProvider).batteryPercent, 90);

      battery.level = 4;
      await c
          .read(checklistNotifierProvider.notifier)
          .rerun(ChecklistCheck.batteryLevel);

      expect(c.read(checklistNotifierProvider).batteryPercent, 4);
      expect(
        c.read(checklistNotifierProvider).passes(ChecklistCheck.batteryLevel),
        isFalse,
      );
    });
  });
}

class _FakePermissionProbe implements CameraPermissionProbe {
  _FakePermissionProbe(this.order, this.throws);

  final List<String> order;
  final Exception? throws;

  @override
  Future<void> verify() async {
    order.add('permission');
    if (throws != null) {
      throw throws!;
    }
  }
}

class _FakeFreeSpace implements FreeSpaceReader {
  _FakeFreeSpace(this.order, this.bytes, this.throws);

  final List<String> order;
  final int bytes;
  final Exception? throws;

  @override
  Future<int> availableBytes(String path) async {
    order.add('storage');
    if (throws != null) {
      throw throws!;
    }
    return bytes;
  }
}

class _FakeBattery implements BatteryReader {
  _FakeBattery(this.order, this.level, this.throws);

  final List<String> order;
  int level;
  final Exception? throws;

  @override
  Future<int> percent() async {
    order.add('battery');
    if (throws != null) {
      throw throws!;
    }
    return level;
  }
}

class _FakeNetwork implements NetworkReader {
  _FakeNetwork(this.order, this.type, this.throws);

  final List<String> order;
  final NetworkType type;
  final Exception? throws;

  @override
  Future<NetworkType> current() async {
    order.add('network');
    if (throws != null) {
      throw throws!;
    }
    return type;
  }
}

class _FakeCache implements WideAngleEligibilityCache {
  _FakeCache(this.stored);

  WideAngleTier? stored;
  int writes = 0;

  @override
  Future<WideAngleTier?> read(DeviceFingerprint fingerprint) async => stored;

  @override
  Future<void> write({
    required WideAngleTier tier,
    required DeviceFingerprint fingerprint,
  }) async {
    writes += 1;
    stored = tier;
  }

  @override
  Future<void> clear() async => stored = null;
}

class _FakeCapabilityProbe implements CameraCapabilityProbe {
  _FakeCapabilityProbe(this.order, this.capability);

  final List<String> order;
  final CameraCapability capability;

  @override
  Future<CameraCapability> probe() async {
    order.add('capability');
    return capability;
  }
}

class _ThrowingCapabilityProbe implements CameraCapabilityProbe {
  @override
  Future<CameraCapability> probe() async => throw const DeviceException(
    errorCode: ErrorCode.deviceCameraUnavailable,
    message: 'probe failed',
  );
}
