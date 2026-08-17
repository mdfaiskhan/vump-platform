import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The [ThemeMode] the application renders with.
///
/// Follows the operating system setting. Overriding this from a settings
/// surface is out of scope for this step.
final Provider<ThemeMode> themeModeProvider = Provider<ThemeMode>(
  (Ref<ThemeMode> ref) => ThemeMode.system,
);
