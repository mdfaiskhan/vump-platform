import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/features/upload/application/upload_dispatcher_status_notifier.dart';
import 'package:mobile/features/upload/domain/entities/upload_dispatcher_status.dart';

/// Open item 60's signal — the fact that uploads are not running.
void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
    addTearDown(container.dispose);
  });

  test('starts running — an empty queue is not a fault', () {
    expect(
      container.read(uploadDispatcherStatusProvider),
      UploadDispatcherStatus.running,
    );
  });

  test('marking halted is visible to a watcher', () {
    container.read(uploadDispatcherStatusProvider.notifier).markHalted();

    expect(
      container.read(uploadDispatcherStatusProvider),
      UploadDispatcherStatus.halted,
    );
  });

  test('halted is terminal for this launch', () {
    // Both faults that reach here need a restart: a pipeline that cannot be
    // constructed will not construct on the next attempt. Flipping back would
    // be a claim nothing could honour.
    final UploadDispatcherStatusNotifier notifier = container.read(
      uploadDispatcherStatusProvider.notifier,
    );
    notifier.markHalted();
    notifier.markHalted();

    expect(
      container.read(uploadDispatcherStatusProvider),
      UploadDispatcherStatus.halted,
    );
  });

  test('isHalted answers the question C-11 actually asks', () {
    expect(UploadDispatcherStatus.running.isHalted, isFalse);
    expect(UploadDispatcherStatus.halted.isHalted, isTrue);
  });
}
