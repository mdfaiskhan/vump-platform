import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/app/theme/app_status_colors.dart';

/// Volume 2 Chapter 2.10 §2.2's four hexes, and §2.3's contrast floor.
void main() {
  group('the four hues are transcribed, not chosen', () {
    test('match Chapter 2.10 §2.2 exactly', () {
      // A failure here means the palette drifted from the chapter, not that
      // the chapter is wrong. The four were validated for colour-vision
      // deficiency separation before adoption; changing one discards that.
      expect(AppStatusColors.goodHue, const Color(0xFF0CA30C));
      expect(AppStatusColors.warningHue, const Color(0xFFFAB219));
      expect(AppStatusColors.accentHue, const Color(0xFF2A78D6));
      expect(AppStatusColors.criticalHue, const Color(0xFFD03B3B));
    });

    test('the light theme uses the hues at full strength', () {
      expect(AppStatusColors.light.good, AppStatusColors.goodHue);
      expect(AppStatusColors.light.warning, AppStatusColors.warningHue);
      expect(AppStatusColors.light.accent, AppStatusColors.accentHue);
      expect(AppStatusColors.light.critical, AppStatusColors.criticalHue);
    });

    test('the four stay distinguishable from each other', () {
      final Set<int> hues = <int>{
        AppStatusColors.goodHue.toARGB32(),
        AppStatusColors.warningHue.toARGB32(),
        AppStatusColors.accentHue.toARGB32(),
        AppStatusColors.criticalHue.toARGB32(),
      };
      expect(hues, hasLength(4));
    });
  });

  group('foregrounds meet Chapter 2.10 §2.3 — 4.5:1 for body text', () {
    void assertReadable(Color fill, Color foreground, String name) {
      expect(
        _contrast(fill, foreground),
        greaterThanOrEqualTo(4.5),
        reason: '$name fails AA for body text',
      );
    }

    test('in the light theme', () {
      const AppStatusColors p = AppStatusColors.light;
      assertReadable(p.good, p.onGood, 'good');
      assertReadable(p.warning, p.onWarning, 'warning');
      assertReadable(p.accent, p.onAccent, 'accent');
      assertReadable(p.critical, p.onCritical, 'critical');
    });

    test('in the dark theme', () {
      const AppStatusColors p = AppStatusColors.dark;
      assertReadable(p.good, p.onGood, 'good');
      assertReadable(p.warning, p.onWarning, 'warning');
      assertReadable(p.accent, p.onAccent, 'accent');
      assertReadable(p.critical, p.onCritical, 'critical');
    });

    test(
      'white on the warning hue would NOT pass, which is why it is dark',
      () {
        // Pins the reason the warning foreground differs from the other three.
        expect(
          _contrast(AppStatusColors.warningHue, const Color(0xFFFFFFFF)),
          lessThan(4.5),
        );
      },
    );
  });
}

/// WCAG relative-luminance contrast ratio.
double _contrast(Color a, Color b) {
  final double la = _luminance(a);
  final double lb = _luminance(b);
  final double lighter = math.max(la, lb);
  final double darker = math.min(la, lb);
  return (lighter + 0.05) / (darker + 0.05);
}

double _luminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}
