import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/recording/domain/entities/network_type.dart';

/// The three spellings Volume 4 Chapter 4.5 fixes for
/// `capture_conditions.network_type`.
///
/// Small, and worth pinning: [NetworkType.wireName] is what a stored metadata
/// row will carry to the backend, so a rename here is a wire-format change
/// rather than a refactor.
void main() {
  test('the wire names are Chapter 4.5s three spellings', () {
    expect(NetworkType.wifi.wireName, 'wifi');
    expect(NetworkType.cellular.wireName, 'cellular');
    expect(NetworkType.none.wireName, 'none');
  });

  test('every value has a wire name, so none can reach the backend blank', () {
    for (final NetworkType type in NetworkType.values) {
      expect(type.wireName, isNotEmpty, reason: type.name);
    }
  });

  test('the enum has exactly three values', () {
    // Chapter 4.5 fixes the vocabulary at three. A fourth would need a wire
    // format decision, not just an enum entry — this is the tripwire for it.
    expect(NetworkType.values, hasLength(3));
  });
}
