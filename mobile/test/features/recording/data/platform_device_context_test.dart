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
}
