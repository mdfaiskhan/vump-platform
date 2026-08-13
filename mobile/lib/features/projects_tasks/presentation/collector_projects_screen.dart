import 'package:flutter/material.dart';

/// The Collector's assigned-Projects list (C-04).
///
/// Placeholder registered by Mission 1.3's navigation skeleton. It renders
/// nothing but its own name; Volume 2 Chapter 2.3 §5 constrains it to assigned
/// items only — a Collector can never reach a Project they are not assigned to
/// (BR-14, BR-19).
class CollectorProjectsScreen extends StatelessWidget {
  const CollectorProjectsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Projects')),
      body: const Center(child: Text('Collector Projects')),
    );
  }
}
