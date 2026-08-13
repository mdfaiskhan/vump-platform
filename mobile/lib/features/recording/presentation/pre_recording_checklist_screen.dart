import 'package:flutter/material.dart';

/// The gate every recording passes through (C-07).
///
/// Placeholder registered by Mission 1.3's navigation skeleton. It renders
/// nothing but its own name and the path parameter it received; Volume 2
/// Chapter 2.4 §2 presents it as a full-screen modal from Task Detail, and
/// Chapter 2.3 §5 makes it the only route to the Recording Screen — there is no
/// direct path from the Dashboard or Task List (BR-04).
class PreRecordingChecklistScreen extends StatelessWidget {
  const PreRecordingChecklistScreen({required this.taskId, super.key});

  /// Identifier supplied by the route path.
  final String taskId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pre-recording checklist')),
      body: Center(child: Text('Pre-Recording Checklist $taskId')),
    );
  }
}
