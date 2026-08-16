import 'dart:async';

import 'package:flutter/material.dart';

import 'package:mobile/app/theme/app_sizes.dart';
import 'package:mobile/app/theme/app_spacing.dart';
import 'package:mobile/features/onboarding/presentation/onboarding_dot_row.dart';
import 'package:mobile/features/onboarding/presentation/onboarding_permission.dart';

/// C-01 — Onboarding / Permission Priming.
///
/// Volume 2 Chapter 2.7's component table, implemented row for row:
///
/// | Element | Component | Here |
/// |---|---|---|
/// | Card body | Card (Design System §5) | [Card] with one sentence |
/// | Progress indicator | Dot row (net-new) | [OnboardingDotRow] |
/// | Primary button | `btn-primary` | [FilledButton], label per card |
///
/// Layout is Chapter 2.7's: *"Full-screen carousel, one permission per card,
/// primary button advances."*
///
/// ## IT REQUESTS NOTHING, AND THAT IS THE POINT WORTH READING
///
/// Chapter 2.7's layout ends *"last card's primary button triggers the first
/// real OS permission prompt."* **This screen does not do that, and cannot.**
///
/// This project has no permission plugin — no `permission_handler`, nothing
/// equivalent. The only permission machinery that exists is
/// `CameraPermissionProbeImpl`, which infers camera and microphone grants by
/// opening a camera with audio enabled and disposing it immediately. That is a
/// side-effect probe rather than a permission API, and it covers two of
/// FR-ONB-01's five permissions. **Nothing in this project can read or request
/// Location, Notifications or Files access at all.**
///
/// So **FR-ONB-01 is not satisfied by this screen.** The requirement is that
/// the system *"shall request Camera, Microphone, Location (When In Use),
/// Notifications, and Files access during first launch"*. The carousel that
/// explains the request exists; the request does not. Adding it is an ADR-030
/// dependency decision, taken together with C-02 (FR-ONB-02's blocked-state
/// explainer and settings deep link), which needs the same package.
///
/// This is stated here rather than left to a reader to discover, because a
/// priming carousel that primes nothing looks finished.
class OnboardingCarouselScreen extends StatefulWidget {
  /// Creates the carousel.
  ///
  /// [onComplete] runs when the last card's "Get Started" is pressed. Supplied
  /// by the router rather than navigated to from here, so this screen names no
  /// route and stays testable without one.
  const OnboardingCarouselScreen({required this.onComplete, super.key});

  /// What happens after the final card.
  final VoidCallback onComplete;

  @override
  State<OnboardingCarouselScreen> createState() =>
      _OnboardingCarouselScreenState();
}

class _OnboardingCarouselScreenState extends State<OnboardingCarouselScreen> {
  final PageController _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _advance() {
    if (_index == OnboardingPermission.carousel.length - 1) {
      widget.onComplete();
      return;
    }
    // `unawaited`: the animation's completion is not a result anything here
    // depends on, and awaiting it inside a button callback would hold the
    // handler open for the duration of a transition.
    unawaited(
      _controller.nextPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const List<OnboardingPermission> cards = OnboardingPermission.carousel;
    final OnboardingPermission current = cards[_index];

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            children: <Widget>[
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: cards.length,
                  onPageChanged: (int index) => setState(() => _index = index),
                  itemBuilder: (BuildContext context, int index) =>
                      _PermissionCard(permission: cards[index]),
                ),
              ),
              OnboardingDotRow(count: cards.length, activeIndex: _index),
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                width: double.infinity,
                height: AppSizes.buttonHeightLg,
                child: FilledButton(
                  onPressed: _advance,
                  // The label is derived from position, so the last card
                  // cannot silently read "Next" if a permission is added.
                  child: Text(current.primaryLabel),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One card — Chapter 2.7's *"Card (Design System §5, card container)"*.
class _PermissionCard extends StatelessWidget {
  const _PermissionCard({required this.permission});

  final OnboardingPermission permission;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Center(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(permission.title, style: theme.textTheme.headlineSmall),
              const SizedBox(height: AppSpacing.md),
              Text(permission.reason, style: theme.textTheme.bodyLarge),
            ],
          ),
        ),
      ),
    );
  }
}
