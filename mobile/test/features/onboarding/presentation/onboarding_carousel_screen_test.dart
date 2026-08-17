import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/onboarding/presentation/onboarding_carousel_screen.dart';
import 'package:mobile/features/onboarding/presentation/onboarding_dot_row.dart';
import 'package:mobile/features/onboarding/presentation/onboarding_permission.dart';

/// C-01 against Volume 2 Chapter 2.7's component table.
///
/// The assertions that earn their place here are the ones encoding a decision:
/// that there are **five** cards rather than the four Chapter 2.7's worked
/// example implies, that the last card and only the last card reads "Get
/// Started", and that the screen **requests no permission** — the last being
/// the thing a future reader is most likely to assume was done.
void main() {
  Widget harness({VoidCallback? onComplete}) => MaterialApp(
    home: OnboardingCarouselScreen(onComplete: onComplete ?? () {}),
  );

  group('five cards, one per FR-ONB-01 permission', () {
    test('the carousel holds exactly the five FR-ONB-01 names', () {
      // Volume 1 FR-ONB-01: "Camera, Microphone, Location (When In Use),
      // Notifications, and Files access". Chapter 2.7's example combines the
      // first two, which would give four and contradict its own button rule.
      expect(OnboardingPermission.carousel, hasLength(5));
      expect(
        OnboardingPermission.carousel.map((OnboardingPermission p) => p.title),
        <String>['Camera', 'Microphone', 'Location', 'Notifications', 'Files'],
      );
    });

    test('every card states a concrete reason, not a generic one', () {
      // Chapter 2.7: "One sentence stating the permission and the concrete
      // reason it's needed." Chapter 2.9 §2's named-cause rule is the same
      // instinct.
      for (final OnboardingPermission p in OnboardingPermission.carousel) {
        expect(p.reason, isNotEmpty, reason: p.title);
        expect(p.reason.trim(), endsWith('.'), reason: p.title);
        expect(p.reason.toLowerCase(), isNot(contains('better experience')));
      }
    });
  });

  group("the primary button's label follows position", () {
    test('cards 1-4 read Next and the last reads Get Started', () {
      final List<String> labels = OnboardingPermission.carousel
          .map((OnboardingPermission p) => p.primaryLabel)
          .toList();

      expect(labels, <String>['Next', 'Next', 'Next', 'Next', 'Get Started']);
    });

    testWidgets('the first card shows Next', (WidgetTester tester) async {
      await tester.pumpWidget(harness());

      expect(find.widgetWithText(FilledButton, 'Next'), findsOneWidget);
      expect(find.text('Camera'), findsOneWidget);
    });

    testWidgets('advancing to the last card shows Get Started', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(harness());

      for (int i = 0; i < 4; i++) {
        await tester.tap(find.byType(FilledButton));
        await tester.pumpAndSettle();
      }

      expect(find.widgetWithText(FilledButton, 'Get Started'), findsOneWidget);
      expect(find.text('Files'), findsOneWidget);
    });
  });

  group('completion', () {
    testWidgets('Next does not complete the carousel', (
      WidgetTester tester,
    ) async {
      bool completed = false;
      await tester.pumpWidget(harness(onComplete: () => completed = true));

      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      expect(completed, isFalse);
    });

    testWidgets('Get Started completes it exactly once', (
      WidgetTester tester,
    ) async {
      int completions = 0;
      await tester.pumpWidget(harness(onComplete: () => completions++));

      for (int i = 0; i < 4; i++) {
        await tester.tap(find.byType(FilledButton));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      expect(completions, 1);
    });
  });

  group('it primes, and requests nothing — FR-ONB-01 is NOT satisfied', () {
    testWidgets('no permission is requested by reaching the last card', (
      WidgetTester tester,
    ) async {
      // The screen constructs no probe, opens no camera and calls no platform
      // channel. If a later mission wires a real request in, it must also
      // update FR-ONB's Feature Tracker row and open item 78 -- this test is
      // what makes that visible rather than letting the requirement quietly
      // appear satisfied.
      final List<MethodCall> platformCalls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/camera_android'),
        (MethodCall call) async {
          platformCalls.add(call);
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/camera_android'),
          null,
        ),
      );

      await tester.pumpWidget(harness());
      for (int i = 0; i < 5; i++) {
        await tester.tap(find.byType(FilledButton));
        await tester.pumpAndSettle();
      }

      expect(platformCalls, isEmpty);
    });
  });

  group('the dot row', () {
    testWidgets('renders one dot per card and tracks position', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(harness());

      OnboardingDotRow row() =>
          tester.widget<OnboardingDotRow>(find.byType(OnboardingDotRow));

      expect(row().count, 5);
      expect(row().activeIndex, 0);

      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      expect(row().activeIndex, 1);
    });

    testWidgets('it announces position once, not once per dot', (
      WidgetTester tester,
    ) async {
      // Chapter 2.10 §4 requires an icon-only element to carry a text label.
      // Five separately-announced dots would satisfy the letter of that and
      // defeat its purpose, so the row labels itself and excludes its
      // children.
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: OnboardingDotRow(count: 5, activeIndex: 2)),
        ),
      );

      expect(find.bySemanticsLabel('Step 3 of 5'), findsOneWidget);
    });
  });
}
