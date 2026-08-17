import 'package:flutter/material.dart';

/// One session, with its chunks and their upload status.
///
/// Placeholder registered by Mission 1.3's navigation skeleton. It renders
/// nothing but its own name and the path parameter it received.
///
/// ## It is NOT C-12, and the screen it implements has no inventory entry
///
/// A previous revision of this comment called it *"(C-12)"*. **C-12 is Session
/// Complete** — Chapter 2.5: *"Confirms every chunk + metadata verified;
/// returns to Task List/Dashboard"* — a post-recording confirmation, not a
/// drill-down from the Sessions tab. Corrected rather than left, because the
/// two have different triggers, different copy and different blockers.
///
/// What this route actually implements is the *"Session Detail"* in Chapter
/// 2.4 §2's stack, *"Sessions → Session Detail → Chunk Detail"* — **the only
/// mention of either name in all of Volume 2.** Chapter 2.5, which calls
/// itself the *"master, authoritative list of screens"*, has no entry for
/// either, and C-11's own line already covers both levels: *"per-session,
/// per-chunk status"*. Mission 4.6 built exactly that, flattened into one
/// screen.
///
/// So this route is unreachable by design rather than by oversight — nothing
/// in the application navigates to it, because C-11 has nowhere to drill down
/// *to*. Open item 82 records the conflict; resolving it is a product call
/// between Chapter 2.4's stack and Chapter 2.5's inventory, not something a
/// screen should settle by being built.
class CollectorSessionDetailScreen extends StatelessWidget {
  const CollectorSessionDetailScreen({required this.sessionId, super.key});

  /// Identifier supplied by the route path.
  final String sessionId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Session')),
      body: Center(child: Text('Collector Session $sessionId')),
    );
  }
}
