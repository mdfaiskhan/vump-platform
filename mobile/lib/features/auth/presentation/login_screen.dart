import 'package:flutter/material.dart';

/// The single shared sign-in surface for both roles.
///
/// Placeholder registered by Mission 1.3's navigation skeleton. It renders
/// nothing but its own name; Volume 2 Chapter 2.4 §4 makes this role-agnostic —
/// there is no separate Admin login — and the Role Router sends the user to the
/// Collector or Admin root immediately after authentication.
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign in')),
      body: const Center(child: Text('Login Screen')),
    );
  }
}
