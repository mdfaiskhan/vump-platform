import 'package:flutter/material.dart';

/// The Admin's session and chunk status across managed Projects (A-07).
///
/// Placeholder registered by Mission 1.3's navigation skeleton. It renders
/// nothing but its own name; Volume 3 Chapter 3.5 §2 assigns this root to
/// `upload`; the Metadata Detail and Export view (A-08) is a `metadata`-owned
/// overlay presented on top of it per Chapter 2.4 §3, and is not yet
/// registered.
class AdminSessionsScreen extends StatelessWidget {
  const AdminSessionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sessions & metadata')),
      body: const Center(child: Text('Admin Sessions & Metadata')),
    );
  }
}
