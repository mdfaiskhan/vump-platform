import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:mobile/app/home_screen.dart';

/// Application route configuration.
final GoRouter appRouter = GoRouter(
  routes: <RouteBase>[
    GoRoute(
      path: '/',
      builder: (BuildContext context, GoRouterState state) =>
          const HomeScreen(),
    ),
  ],
);
