import 'package:flutter/material.dart';

/// The chrome-free capture surface.
///
/// Volume 2 Chapter 2.4 §2 makes this the one screen with no navigation
/// chrome at all: *"deliberately removes all navigation chrome so nothing can
/// be tapped accidentally mid-recording; only Stop is reachable."* Chapter 2.4
/// §5 repeats it as a table row — chrome-free full-screen, Recording Screen
/// only, *"no tabs, no back button"*.
///
/// Three properties deliver that, and all three are structural rather than
/// cosmetic:
///
/// 1. **No tab bar** — the route sits outside both `StatefulShellRoute`s, so
///    no shell wraps it. A route inside a branch would inherit the bottom bar.
/// 2. **No back button** — there is no `AppBar`, so Flutter has nowhere to
///    render one.
/// 3. **No back gesture or hardware back** — `PopScope(canPop: false)`
///    refuses the pop, which covers the Android back button and the iOS
///    back-swipe alike.
///
/// Placeholder registered by Mission 1.3. Mission 3 fills in the capture
/// pipeline and the Stop control that is the only sanctioned way out.
class RecordingScreen extends StatelessWidget {
  const RecordingScreen({required this.sessionId, super.key});

  /// Identifier supplied by the route path.
  final String sessionId;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Center(child: Text('Recording Screen — session $sessionId')),
      ),
    );
  }
}
