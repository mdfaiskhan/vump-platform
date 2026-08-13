import 'package:flutter/material.dart';

/// One Project, drilled into from the Projects tab (C-05).
///
/// Placeholder registered by Mission 1.3's navigation skeleton. It renders
/// nothing but its own name and the path parameter it received; Volume 2
/// Chapter 2.3 §2 lists its Tasks beneath it.
class CollectorProjectDetailScreen extends StatelessWidget {
  const CollectorProjectDetailScreen({required this.projectId, super.key});

  /// Identifier supplied by the route path.
  final String projectId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Project')),
      body: Center(child: Text('Collector Project $projectId')),
    );
  }
}
