import 'package:flutter/material.dart';

/// The Admin's home tab (A-01).
///
/// Placeholder registered by Mission 1.3's navigation skeleton. It renders
/// nothing but its own name; Volume 2 Chapter 2.3 §3 fills it with the managed-
/// Projects summary and the Collector activity summary. Ownership is ambiguous
/// in Volume 3 Chapter 3.5 §2 — see the mission report.
class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: const Center(child: Text('Admin Dashboard')),
    );
  }
}
