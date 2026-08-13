import 'package:flutter/material.dart';

/// One Task, and the only route to the Pre-Recording Checklist (C-06).
///
/// Placeholder registered by Mission 1.3's navigation skeleton. It renders
/// nothing but its own name and the path parameter it received; Volume 2
/// Chapter 2.3 §2 gives it Instructions, Examples and Requirements, and §5
/// makes it the sole path toward capture.
class CollectorTaskDetailScreen extends StatelessWidget {
  const CollectorTaskDetailScreen({required this.taskId, super.key});

  /// Identifier supplied by the route path.
  final String taskId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Task')),
      body: Center(child: Text('Collector Task $taskId')),
    );
  }
}
