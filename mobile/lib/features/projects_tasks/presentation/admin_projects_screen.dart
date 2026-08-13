import 'package:flutter/material.dart';

/// The Admin's managed-Projects list (A-02).
///
/// Placeholder registered by Mission 1.3's navigation skeleton. It renders
/// nothing but its own name; Volume 2 Chapter 2.3 §5 scopes it to Projects the
/// Admin manages (BR-20). Create and Edit arrive as modals per Chapter 2.4 §3.
class AdminProjectsScreen extends StatelessWidget {
  const AdminProjectsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Projects')),
      body: const Center(child: Text('Admin Projects')),
    );
  }
}
