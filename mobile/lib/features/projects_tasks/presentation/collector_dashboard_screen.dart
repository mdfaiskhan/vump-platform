import 'package:flutter/material.dart';

/// The Collector's home tab (C-03).
///
/// Placeholder registered by Mission 1.3's navigation skeleton. It renders
/// nothing but its own name; Volume 2 Chapter 2.3 §2 fills it with the active
/// Projects summary, the in-progress Sessions summary, and total recorded time
/// with sync status.
class CollectorDashboardScreen extends StatelessWidget {
  const CollectorDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: const Center(child: Text('Collector Dashboard')),
    );
  }
}
