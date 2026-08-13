import 'package:flutter/material.dart';

/// One session, with its chunks and their upload status (C-12).
///
/// Placeholder registered by Mission 1.3's navigation skeleton. It renders
/// nothing but its own name and the path parameter it received; Volume 2
/// Chapter 2.3 §2 lists chunk-level upload status beneath it.
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
