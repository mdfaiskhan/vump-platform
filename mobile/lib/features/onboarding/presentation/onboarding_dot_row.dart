import 'package:flutter/material.dart';

import 'package:mobile/app/theme/app_sizes.dart';
import 'package:mobile/app/theme/app_spacing.dart';

/// C-01's carousel position indicator — Chapter 2.7's "Dot row".
///
/// ## Why this is a local widget and not a Design System component
///
/// Chapter 2.7 flags it as *"not in Design System v1.0 — flagged as a net-new
/// component for the Ch. 2.8 v1.1 pass"*, and §6 says such components
/// *"should be folded back into the Design System in its next revision rather
/// than treated as one-offs"*.
///
/// **That is guidance for the design document, not licence to pre-promote the
/// code.** ADR-022 R5 is binding and says the opposite for `lib/`:
///
/// > Nothing enters `shared/` without a second consumer. Components are
/// > written inside the feature that needs them and *promoted* when a second
/// > feature needs them.
///
/// C-01 is the only consumer, and `lib/shared/` does not exist. So this lives
/// here until something else needs it, and the promotion is one move at that
/// point — the extra step ADR-022's Consequences names and accepts outright.
///
/// ## Never a percentage — Chapter 2.7
///
/// *"Shows position in the carousel; never a percentage, since the count is
/// fixed and small."* So this takes a count and an index, and has no notion of
/// progress at all.
///
/// ## It is decorative, and says so — Chapter 2.10 §4
///
/// The dots carry no information the screen does not already state: the card's
/// own heading names the permission, and the primary button's label changes on
/// the last card. A screen reader reading "dot 3 of 5" after the card content
/// would add position without adding meaning, so the row is wrapped in
/// [ExcludeSemantics] and the position is exposed once, as a label on the row
/// itself, rather than five times.
///
/// This is the *opposite* of Chapter 2.10 §4's progress-indicator rule
/// (*"expose their state as a value a screen reader can read"*) and
/// deliberately so — that rule governs upload progress and checklist re-runs,
/// which report state the user cannot otherwise obtain. Carousel position is
/// not that.
class OnboardingDotRow extends StatelessWidget {
  /// Creates a dot row of [count] dots with [activeIndex] filled.
  const OnboardingDotRow({
    required this.count,
    required this.activeIndex,
    super.key,
  });

  /// How many cards the carousel has.
  final int count;

  /// Which card is showing, zero-based.
  final int activeIndex;

  static const double _dotSize = 8;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Semantics(
      label: 'Step ${activeIndex + 1} of $count',
      child: ExcludeSemantics(
        child: SizedBox(
          // The row keeps a full touch-target height even though nothing in it
          // is tappable, so the card content above does not shift when the
          // carousel is the only thing between it and the button.
          height: AppSizes.minTouchTarget,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              for (int i = 0; i < count; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs,
                  ),
                  child: Container(
                    width: _dotSize,
                    height: _dotSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      // The inactive dot uses a distinct colour role rather
                      // than an opacity of the active one: Chapter 2.10 §2.4
                      // makes the same point about disabled buttons -- a state
                      // distinguished by opacity alone is faded, not legible.
                      color: i == activeIndex
                          ? colors.primary
                          : colors.surfaceContainerHighest,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
