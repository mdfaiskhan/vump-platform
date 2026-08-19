/// The seams where the recording identity group is introduced to its sources.
///
/// Volume 4 Chapter 4.5 §2's `identity` group needs five values, and
/// `features/recording/` can obtain exactly one of them on its own. The other
/// four belong to other features — `project_id` and `task_id` to
/// `features/projects_tasks/`, `collector_id` to `features/auth/` — and
/// ADR-022 R3 forbids reaching for any of them by import, *"at any layer, in
/// either direction"*.
///
/// So the consumer declares what it needs and the composition root binds it,
/// which is the same resolution `core/upload/providers/upload_ports.dart`
/// already applies to the chunk pipeline. This file is that file's shape, for
/// identity rather than for upload.
///
/// ## Both throw until overridden
///
/// The reason `authTokenSourceProvider` and `databaseDirectoryProvider`
/// established, and `upload_ports.dart` restates: failing loudly at the
/// override point is easier to diagnose than any default. A default here would
/// be worse than a missing file — it would put an **empty or invented
/// identifier onto a chunk's metadata**, and A-068's Guard 1 exists precisely
/// because an unattributed recording must be refused rather than uploaded.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mobile/core/identity/interfaces/device_context.dart';
import 'package:mobile/core/identity/interfaces/task_context.dart';

/// Where the Project and Task a session records against come from.
///
/// Bound in `main.dart` to `UnsourcedTaskContext` as of Mission 7.4 step 1,
/// which still returns `MetadataIdentity.unsourced` for both. **The plumbing
/// moved before the values did, deliberately** — this step changes no
/// behaviour, so a green suite after it means the move was clean rather than
/// that two changes cancelled out. The real binding lands in step 4, when
/// `features/projects_tasks/` reads a Task from the live backend.
final Provider<TaskContext> taskContextProvider = Provider<TaskContext>(
  (Ref ref) => throw UnimplementedError(
    'taskContextProvider must be overridden before a chunk is finalized. '
    'features/recording/data/UnsourcedTaskContext binds it today; a real '
    'implementation sourced from features/projects_tasks/ lands in Mission '
    '7.4. See ADR-040 and open item 37.',
  ),
);

/// Where the Collector, device and build identifiers come from.
///
/// Bound to `PlatformDeviceContext`, which supplies `appVersion` and
/// `deviceModel` and still returns `MetadataIdentity.unsourced` for
/// `collectorId` and `deviceId`. Those two are Mission 7.4 steps 3 and 4:
/// `collectorId` is wired from the signed-in session at this composition root,
/// and `deviceId` becomes F19's install-scoped UUID.
final Provider<DeviceContext> deviceContextProvider = Provider<DeviceContext>(
  (Ref ref) => throw UnimplementedError(
    'deviceContextProvider must be overridden before a chunk is finalized. '
    'features/recording/data/PlatformDeviceContext binds it; collectorId and '
    'deviceId are still unsourced. See ADR-040 and open item 37.',
  ),
);
