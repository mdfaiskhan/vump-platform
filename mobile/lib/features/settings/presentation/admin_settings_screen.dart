import 'package:flutter/material.dart';

/// The Admin's settings and account tab.
///
/// Placeholder registered by Mission 1.3's navigation skeleton. It renders
/// nothing but its own name; Volume 2 Chapter 2.4 §3 names it Settings/Account.
class AdminSettingsScreen extends StatelessWidget {
  const AdminSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: const Center(child: Text('Admin Settings')),
    );
  }
}
