import 'package:flutter/material.dart';

/// Landing screen shown at the root route.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [Text('Vump Technologies'), Text('Mission 0.6 Complete')],
        ),
      ),
    );
  }
}
