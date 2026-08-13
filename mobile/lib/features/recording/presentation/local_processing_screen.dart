import 'package:flutter/material.dart';

/// Chunking and metadata generation after Stop (C-10).
///
/// Placeholder registered by Mission 1.3's navigation skeleton. It renders
/// nothing but its own name and the path parameter it received; Volume 5
/// Chapter 5.3 places it after Stop and never during capture, and NFR-PERF-02
/// requires it to begin within 2 seconds.
class LocalProcessingScreen extends StatelessWidget {
  const LocalProcessingScreen({required this.sessionId, super.key});

  /// Identifier supplied by the route path.
  final String sessionId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Processing')),
      body: Center(child: Text('Local Processing $sessionId')),
    );
  }
}
