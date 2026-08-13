import 'package:flutter/material.dart';

/// The Collector's settings tab.
///
/// Placeholder registered by Mission 1.3's navigation skeleton. It renders
/// nothing but its own name; Volume 2 Chapter 2.3 §2 gives it account and
/// logout, upload mode (automatic or manual), and — in Phase 2 — support
/// contact and notifications.
class CollectorSettingsScreen extends StatelessWidget {
  const CollectorSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: const Center(child: Text('Collector Settings')),
    );
  }
}
