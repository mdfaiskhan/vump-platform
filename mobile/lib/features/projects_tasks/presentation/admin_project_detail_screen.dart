import 'package:flutter/material.dart';

/// One managed Project, with its Tasks and Collector assignment.
///
/// Placeholder registered by Mission 1.3's navigation skeleton. It renders
/// nothing but its own name and the path parameter it received; Volume 2
/// Chapter 2.3 §3 nests Create/Edit Task and the assign, reassign and remove
/// actions beneath it (A-03 to A-06).
class AdminProjectDetailScreen extends StatelessWidget {
  const AdminProjectDetailScreen({required this.projectId, super.key});

  /// Identifier supplied by the route path.
  final String projectId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Project')),
      body: Center(child: Text('Admin Project $projectId')),
    );
  }
}
