import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/identity/device_id_store.dart';
import 'package:mobile/core/identity/uuid_v4.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// F19's one property: generated once, stable afterwards.
///
/// Everything else this class does is plumbing. What Chapter 5.7 §2 asks for
/// is a *stable* identifier, and the only way it can fail to be stable is by
/// minting a second value when one is already stored — so that is what these
/// tests are about.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<SharedPreferences> preferencesWith(Map<String, Object> initial) {
    SharedPreferences.setMockInitialValues(initial);
    return SharedPreferences.getInstance();
  }

  group('with nothing stored', () {
    test('mints a value and persists it under the namespaced key', () async {
      final SharedPreferences preferences = await preferencesWith(
        <String, Object>{},
      );

      final String id = await DeviceIdStore(
        preferences: preferences,
      ).deviceId();

      expect(id, isNotEmpty);
      expect(
        preferences.getString(DeviceIdStore.key),
        id,
        reason: 'the returned value is the one that was written, not a copy',
      );
    });

    test('what it mints is a v4 UUID', () async {
      final SharedPreferences preferences = await preferencesWith(
        <String, Object>{},
      );

      final String id = await DeviceIdStore(
        preferences: preferences,
      ).deviceId();

      expect(
        id,
        matches(
          RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-'
            r'[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          ),
        ),
      );
    });
  });

  group('with a value already stored', () {
    test('returns it and does not mint', () async {
      final SharedPreferences preferences = await preferencesWith(
        <String, Object>{DeviceIdStore.key: 'stored-id'},
      );
      final _CountingUuid uuid = _CountingUuid();

      final String id = await DeviceIdStore(
        preferences: preferences,
        uuid: uuid,
      ).deviceId();

      expect(id, 'stored-id');
      expect(
        uuid.calls,
        0,
        reason: 'minting at all would mean the id is not stable',
      );
    });

    test('a second call returns the first call value', () async {
      // The property stated end to end, through the real minter rather than a
      // counter: this is what survives a process death, since the second
      // instance reads the same store the first one wrote.
      final SharedPreferences preferences = await preferencesWith(
        <String, Object>{},
      );

      final String first = await DeviceIdStore(
        preferences: preferences,
      ).deviceId();
      final String second = await DeviceIdStore(
        preferences: preferences,
      ).deviceId();

      expect(second, first);
    });
  });

  test('a blank stored value is treated as absent', () async {
    // `MetadataIdentity.unsourced` is the empty string. A row holding it — from
    // a defect, or from a version that wrote the sentinel — must not be read
    // back as a real identifier, because A-068's Guard 1 exists to refuse
    // exactly that value and returning it here would launder it into looking
    // sourced.
    final SharedPreferences preferences = await preferencesWith(
      <String, Object>{DeviceIdStore.key: ''},
    );

    final String id = await DeviceIdStore(preferences: preferences).deviceId();

    expect(id, isNotEmpty);
    expect(preferences.getString(DeviceIdStore.key), id);
  });
}

/// A minter that records how often it was asked.
class _CountingUuid implements UuidV4 {
  int calls = 0;

  @override
  String next() {
    calls++;
    return 'minted-$calls';
  }
}
