import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/identity/uuid_v4.dart';

/// The one minter behind three ports — F23.
///
/// `RandomUuidGenerator` used to own this code. Mission 7.4 moved it here
/// because `DeviceIdStore` needs a UUID too and neither belongs to the other's
/// feature. These tests moved with it, so what Mission 3 proved about the
/// format is still proved about the code that produces it.
void main() {
  group('the format', () {
    test('is RFC 4122 §4.4 — version 4, variant 10', () {
      // A fixed seed, so the assertion is about the layout rather than about
      // whichever bytes happened to come out.
      final UuidV4 uuid = UuidV4(random: Random(7));

      for (int i = 0; i < 200; i++) {
        final String value = uuid.next();

        expect(
          value,
          matches(
            RegExp(
              r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-'
              r'[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
            ),
          ),
          reason: 'iteration $i produced $value',
        );
      }
    });

    test('an all-ones source still yields version 4 and variant 10', () {
      // The masks are the whole of §4.4's requirement, and a mask is exactly
      // the kind of code that passes on typical input and fails on the
      // extremes. This is the extreme that would expose an OR without its AND.
      expect(
        UuidV4(random: const _Fixed(255)).next(),
        'ffffffff-ffff-4fff-bfff-'
        'ffffffffffff',
      );
    });

    test('an all-zeroes source still yields version 4 and variant 10', () {
      expect(
        UuidV4(random: const _Fixed(0)).next(),
        '00000000-0000-4000-8000-'
        '000000000000',
      );
    });
  });

  test('successive calls differ', () {
    final UuidV4 uuid = UuidV4();
    final Set<String> seen = <String>{
      for (int i = 0; i < 1000; i++) uuid.next(),
    };

    expect(seen, hasLength(1000));
  });
}

/// A source that returns one byte forever, for the boundary cases above.
class _Fixed implements Random {
  const _Fixed(this.value);

  final int value;

  @override
  int nextInt(int max) => value;

  @override
  bool nextBool() => throw UnimplementedError();

  @override
  double nextDouble() => throw UnimplementedError();
}
