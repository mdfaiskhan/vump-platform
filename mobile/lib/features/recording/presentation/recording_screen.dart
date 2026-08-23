import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/app/theme/app_radius.dart';
import 'package:mobile/app/theme/app_spacing.dart';
import 'package:mobile/core/errors/failure.dart';
import 'package:mobile/features/recording/application/recording_notifier.dart';
import 'package:mobile/features/recording/domain/entities/recording_state.dart';
import 'package:mobile/features/recording/presentation/recording_error_copy.dart';
import 'package:mobile/features/recording/presentation/widgets/camera_preview_surface.dart';

/// Volume 2 Chapter 2.7's C-09 — the chrome-free capture surface.
///
/// ## DESIGN-TOKEN-EXEMPT — this screen uses raw `Colors`, deliberately
///
/// Every other screen takes colour from `Theme.of(context)` per ADR-005. This
/// one does not, and Mission 5.3's token sweep left it alone rather than
/// converting it.
///
/// **The black is not a palette value.** Chapter 2.7's C-09 layout is a
/// *"full-bleed camera preview … no status bar chrome"*, and the surround
/// behind a camera feed is black because it is the absence of light, not
/// because a design system chose it. A themed surface colour would tint the
/// letterbox around a live preview.
///
/// **The red is a real question and is NOT resolved here.** Chapter 2.7 says
/// the recording indicator is *"red, per Design System critical hue, but
/// denoting 'live' not 'error' in this one context"*. `AppStatusColors`'
/// critical is `#D03B3B`; `Colors.red` is `#F44336`. **They are different
/// colours**, so switching is a visible change to a screen confirmed on a
/// CPH2707 (Mission 3), and there is no Chapter 2.8 to check the result
/// against (open item 74). Converting it inside a compliance sweep would be a
/// redesign performed by the wrong instrument.
///
/// Open item 98 carries both.
///
/// ## What delivers "chrome-free", structurally
///
/// Chapter 2.4 §2: *"deliberately removes all navigation chrome so nothing can
/// be tapped accidentally mid-recording; only Stop is reachable."* Three
/// properties, none cosmetic:
///
/// 1. **No tab bar** — the route sits outside both `StatefulShellRoute`s, so
///    no shell wraps it.
/// 2. **No back button** — there is no `AppBar` for Flutter to render one in.
/// 3. **No back gesture** — `PopScope(canPop: false)` refuses the pop, which
///    covers Android's back and iOS's edge-swipe alike. Chapter 2.9 §6 calls
///    this out as *"the one deliberate exception"* to honouring platform
///    navigation gestures, and asks that it be stated explicitly rather than
///    discovered later as a bug. This paragraph is that statement.
///
/// ## The preview is rendered, and still not from a controller
///
/// `CameraRecordingPipeline` owns the `CameraController` and does not expose
/// it — deliberately, because handing a controller to a widget would let the
/// UI start and stop capture behind the state machine's back. FR-REC-03 asks
/// for a full-screen live preview, and until ADR-053 this screen showed a
/// black surface instead; A-064 §5 recorded that gap rather than closing it by
/// breaking the boundary.
///
/// **ADR-053 closes it without spending the boundary.** The pipeline publishes
/// a texture id, a display aspect ratio and a rotation — three numbers, no
/// capability — and `CameraPreviewSurface` draws them. This screen still holds
/// nothing it could start or stop capture with, so Chapter 2.4 §2's *"only
/// Stop is reachable"* is as true as it was when the surface was black.
class RecordingScreen extends ConsumerWidget {
  /// Creates the capture surface for [sessionId].
  const RecordingScreen({required this.sessionId, super.key});

  /// Identifier supplied by the route path.
  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final RecordingState state = ref.watch(recordingNotifierProvider);

    // Draining, or done — C-10 owns the screen from here. Chapter 5.3 puts
    // Local Processing after Stop and never during capture.
    ref.listen<RecordingState>(recordingNotifierProvider, (
      RecordingState? previous,
      RecordingState next,
    ) {
      if (next is RecordingStateFinalizing || next is RecordingStateIdle) {
        context.go('/processing/$sessionId');
      }
    });

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(
            children: <Widget>[
              // FR-REC-03, closed by ADR-053. Was a black ColoredBox; the
              // pipeline now publishes a texture id, an aspect ratio and a
              // rotation, and this draws them. It still cannot start or stop
              // capture — there is no controller here to do it with.
              const Positioned.fill(child: CameraPreviewSurface()),
              Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xl),
                  child: _RecordingIndicator(state: state),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xxxl),
                  child: _StopControl(
                    enabled: state.isCapturing,
                    onStop: () => unawaited(_stop(context, ref)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _stop(BuildContext context, WidgetRef ref) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final Failure? failure = await ref
        .read(recordingNotifierProvider.notifier)
        .stop(now: DateTime.now());

    if (failure != null) {
      messenger.showSnackBar(
        SnackBar(content: Text(RecordingErrorCopy.forFailure(failure))),
      );
    }
  }
}

/// FR-REC-04's indicator and elapsed timer.
///
/// Chapter 2.7's C-09 fixes the format: *"timer format mm:ss up to 9:59, then
/// hh:mm:ss"*, and labels the dot **REC** because the red is the design
/// system's critical hue being used to mean "live" in this one place.
class _RecordingIndicator extends StatefulWidget {
  const _RecordingIndicator({required this.state});

  final RecordingState state;

  @override
  State<_RecordingIndicator> createState() => _RecordingIndicatorState();
}

class _RecordingIndicatorState extends State<_RecordingIndicator> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    // The elapsed time is derived from the session's own start instant, so
    // this timer only forces a repaint — it never accumulates a count that
    // could drift from the recording it describes.
    _tick = Timer.periodic(
      const Duration(seconds: 1),
      (Timer _) => setState(() {}),
    );
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final DateTime? startedAt = widget.state.activeSession?.startedAt;
    final Duration elapsed = startedAt == null
        ? Duration.zero
        : DateTime.now().difference(startedAt);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            Icons.fiber_manual_record,
            color: widget.state.isCapturing ? Colors.red : Colors.white38,
            size: 14,
          ),
          const SizedBox(width: AppSpacing.sm),
          // "REC" disambiguates the red dot from an error, per C-09, and
          // satisfies Chapter 2.10's colour-not-alone rule.
          const Text(
            'REC',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Text(
            formatElapsed(elapsed),
            style: const TextStyle(
              color: Colors.white,
              fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// `mm:ss` up to 9:59, then `hh:mm:ss` — C-09's stated format.
///
/// Public so the rule is testable without pumping a widget.
///
/// **Read literally.** The chapter says *"mm:ss up to 9:59, then hh:mm:ss"*,
/// so the switch happens at ten minutes rather than at one hour, and 10:00
/// renders as `0:10:00`. That is unusual — most timers switch at the hour —
/// but it is what the specification says, and it lines up with Chapter 5.6's
/// ten-minute chunk boundary, which is the moment a Collector has a reason to
/// start counting in a larger unit. Also not zero-padded on the leading unit:
/// the chapter writes "9:59", not "09:59".
String formatElapsed(Duration elapsed) {
  final String ss = elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');

  if (elapsed.inMinutes < 10) {
    return '${elapsed.inMinutes}:$ss';
  }
  final String mm = elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
  return '${elapsed.inHours}:$mm:$ss';
}

/// The only interactive element on the screen.
///
/// Chapter 2.7's C-09 requires a circular destructive control with a *"large
/// touch target (≥ 64px, exceeding the 44px minimum in Chapter 2.10)"*.
class _StopControl extends StatelessWidget {
  const _StopControl({required this.enabled, required this.onStop});

  final bool enabled;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: enabled,
      // Chapter 2.10 §4: the Stop control "announces its state changes
      // ('Recording — tap to stop' while active) so a screen-reader user
      // always knows recording is in progress even without seeing the pulsing
      // visual indicator".
      //
      // The label was the constant 'Stop recording' until Mission 5.5, which
      // named the action correctly and answered none of what §4 asks: the
      // sentence is about knowing that CAPTURE IS RUNNING, and a static label
      // reads identically whether it is or not. The pulsing indicator carries
      // that fact visually and `_RecordingIndicator` is the only thing that
      // does, so a TalkBack user had no equivalent.
      //
      // `liveRegion` is what makes it an announcement rather than something
      // only heard on focus. The label changes when `enabled` flips, and a
      // live region speaks that change wherever the person is on screen —
      // which is the point, since §5 confines focus to this one control.
      liveRegion: true,
      label: enabled ? 'Recording — tap to stop' : 'Stop recording',
      child: SizedBox.square(
        dimension: 80,
        child: Material(
          color: enabled ? Colors.red : Colors.red.withValues(alpha: 0.4),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: enabled ? onStop : null,
            child: const Center(
              child: Icon(
                Icons.stop,
                color: Colors.white,
                size: 40, // DESIGN-TOKEN-EXEMPT
              ),
            ),
          ),
        ),
      ),
    );
  }
}
