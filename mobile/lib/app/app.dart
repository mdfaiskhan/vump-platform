import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mobile/app/config/app_config.dart';
import 'package:mobile/app/router.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/app/theme/theme_provider.dart';

/// Root widget of the Vump Technologies application.
class VumpApp extends ConsumerWidget {
  const VumpApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeMode themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: AppInfo.appName,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: appRouter,
    );
  }
}
