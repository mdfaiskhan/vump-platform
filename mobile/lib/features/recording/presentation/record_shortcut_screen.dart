import 'package:flutter/material.dart';

/// The Record tab, which is a shortcut rather than a destination.
///
/// Placeholder registered by Mission 1.3's navigation skeleton. It renders
/// nothing but its own name; Volume 2 Chapter 2.4 §2 defines the behaviour: it
/// *"jumps into the most relevant in-progress Task's checklist, or prompts Task
/// selection if none is obviously in progress"*. It resolves to a checklist
/// rather than rendering content of its own.
class RecordShortcutScreen extends StatelessWidget {
  const RecordShortcutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Record')),
      body: const Center(child: Text('Record')),
    );
  }
}
