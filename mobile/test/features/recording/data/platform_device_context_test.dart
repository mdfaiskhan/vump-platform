import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/recording/data/platform_device_context.dart';
import 'package:mobile/features/recording/domain/entities/metadata_identity.dart';

/// The device half of Chapter 4.5 §2's identity group.
///
/// Small on purpose: this class holds values and nothing else, because every
/// one of them is resolved by the composition root for a reason recorded in the
/// class comment. What is worth asserting is that the holding is faithful — a
/// field wired to the wrong source is the failure this class can have, and it
/// would otherwise surface as mislabelled evidence rather than as an error.
void main() {
  test('every value passes through unchanged', () {
    const PlatformDeviceContext context = PlatformDeviceContext(
      collectorId: 'collector-1',
      deviceId: 'device-1',
      deviceModel: 'OnePlus CPH2707',
      appVersion: '1.0.0+1',
    );

    expect(context.collectorId, 'collector-1');
    expect(context.deviceId, 'device-1');
    expect(context.deviceModel, 'OnePlus CPH2707');
    expect(context.appVersion, '1.0.0+1');
  });

  test('the unsourced constructor blanks the three identifiers, not the '
      'version', () {
    // `appVersion` is known at compile time and never absent, so blanking it
    // would be inventing a failure the app cannot have.
    const PlatformDeviceContext context = PlatformDeviceContext.unsourced(
      appVersion: '1.0.0+1',
    );

    expect(context.collectorId, MetadataIdentity.unsourced);
    expect(context.deviceId, MetadataIdentity.unsourced);
    expect(context.deviceModel, MetadataIdentity.unsourced);
    expect(context.appVersion, '1.0.0+1');
  });

  test('built at runtime from resolved values, as the composition root builds '
      'it', () {
    // The two tests above construct with `const`, which Dart evaluates at
    // compile time — so the constructor body never runs and coverage records
    // the declaration as unexecuted. That is a measurement artefact rather
    // than a missing assertion: they already prove the field wiring.
    //
    // This one exists because `main.dart` does NOT construct it with `const`.
    // It cannot: `collectorId` comes from `ref.watch(authNotifierProvider)`,
    // so the real call site is a runtime construction from values that are not
    // compile-time constants. Mirroring that is the honest way to reach the
    // path production actually takes.
    final String collectorId = <String>['collector', '1'].join('-');
    final PlatformDeviceContext context = PlatformDeviceContext(
      collectorId: collectorId,
      deviceId: 'device-1',
      deviceModel: 'OnePlus CPH2707',
      appVersion: '1.0.0+1',
    );

    expect(context.collectorId, 'collector-1');
    expect(context.deviceId, 'device-1');
  });
}
