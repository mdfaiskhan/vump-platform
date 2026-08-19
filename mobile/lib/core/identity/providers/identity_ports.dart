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
import 'package:mobile/core/identity/selected_task.dart';

/// The Task a Collector chose, from the moment they tap Start Recording until
/// the session row is written — Mission 7.4, F38.
///
/// **Not overridden anywhere.** Unlike every other provider in this file, this
/// one holds state rather than binding an implementation, so it has a real
/// default: null, meaning nothing is selected. `features/projects_tasks/`
/// writes it; `features/recording/` reads it; neither imports the other.
///
/// Its lifetime is one navigation. `SelectedTask` carries the full argument for
/// why it is not persisted — in short, the `LocalSession` row it produces is
/// the durability boundary, and there is no mid-recording resume for a
/// persisted selection to restore into.
final NotifierProvider<SelectedTaskNotifier, SelectedTask?>
selectedTaskProvider = NotifierProvider<SelectedTaskNotifier, SelectedTask?>(
  SelectedTaskNotifier.new,
);

/// Holds the current selection.
class SelectedTaskNotifier extends Notifier<SelectedTask?> {
  @override
  SelectedTask? build() => null;

  /// Records the Task a session is about to record against.
  ///
  /// A method rather than a setter, against `use_setters_to_change_properties`,
  /// because [clear] is its pair and `selection = null` would read as an
  /// assignment of no consequence. Selecting and forgetting are both events
  /// with a reason, and naming them keeps the reason at the call site.
  // ignore: use_setters_to_change_properties
  void select(SelectedTask task) => state = task;

  /// Forgets the selection.
  ///
  /// Called when a session ends. Leaving it set would let a later recording
  /// started by some path that forgot to select inherit the previous Task —
  /// which is worse than an unsourced chunk, because it is attributed and
  /// wrong rather than refused.
  void clear() => state = null;
}

/// Where the Project and Task a session records against come from.
///
/// Bound in `main.dart` to a `PlatformTaskContext` reading
/// [selectedTaskProvider], since Mission 7.4 step 5. It returns
/// `MetadataIdentity.unsourced` for both when nothing is selected, which
/// A-068's Guard 1 then refuses — so a recording started without a Task is
/// stopped rather than uploaded unattributed.
final Provider<TaskContext> taskContextProvider = Provider<TaskContext>(
  (Ref ref) => throw UnimplementedError(
    'taskContextProvider must be overridden before a chunk is finalized. '
    'features/recording/data/PlatformTaskContext binds it, reading '
    'selectedTaskProvider. See ADR-040.',
  ),
);

/// Where the Collector, device and build identifiers come from.
///
/// Bound to `PlatformDeviceContext`, whose four values the composition root
/// resolves: `appVersion` from `app/config/`, `deviceId` and `deviceModel` at
/// startup (steps 3's F19 and F22), and `collectorId` reactively from the
/// signed-in session — `User.backendUserId`, not the Firebase uid (A-206).
final Provider<DeviceContext> deviceContextProvider = Provider<DeviceContext>(
  (Ref ref) => throw UnimplementedError(
    'deviceContextProvider must be overridden before a chunk is finalized. '
    'features/recording/data/PlatformDeviceContext binds it. See ADR-040.',
  ),
);
