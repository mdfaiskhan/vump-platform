import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/app/auth_guard.dart';
import 'package:mobile/app/navigation/tab_shell.dart';
import 'package:mobile/features/auth/application/auth_notifier.dart';
import 'package:mobile/features/auth/application/auth_state.dart';
import 'package:mobile/features/auth/presentation/admin_invite_codes_screen.dart';
import 'package:mobile/features/auth/presentation/login_screen.dart';
import 'package:mobile/features/auth/presentation/sign_out_tile.dart';
import 'package:mobile/features/auth/presentation/signup_screen.dart';
import 'package:mobile/features/projects_tasks/presentation/admin_dashboard_screen.dart';
import 'package:mobile/features/projects_tasks/presentation/admin_project_detail_screen.dart';
import 'package:mobile/features/projects_tasks/presentation/admin_projects_screen.dart';
import 'package:mobile/features/projects_tasks/presentation/collector_dashboard_screen.dart';
import 'package:mobile/features/projects_tasks/presentation/collector_project_detail_screen.dart';
import 'package:mobile/features/projects_tasks/presentation/collector_projects_screen.dart';
import 'package:mobile/features/projects_tasks/presentation/collector_task_detail_screen.dart';
import 'package:mobile/features/recording/presentation/local_processing_screen.dart';
import 'package:mobile/features/recording/presentation/pre_recording_checklist_screen.dart';
import 'package:mobile/features/recording/presentation/record_shortcut_screen.dart';
import 'package:mobile/features/recording/presentation/recording_screen.dart';
import 'package:mobile/features/settings/presentation/admin_settings_screen.dart';
import 'package:mobile/features/settings/presentation/collector_settings_screen.dart';
import 'package:mobile/features/upload/presentation/admin_sessions_screen.dart';
import 'package:mobile/features/upload/presentation/collector_session_detail_screen.dart';
import 'package:mobile/features/upload/presentation/collector_sessions_screen.dart';

/// Application route configuration.
///
/// The single route table ADR-004 requires, implementing Volume 2 Chapter 2.4's
/// navigation model. This is the only file in `app/` permitted to import from
/// `features/`, and only from a feature's `presentation/` layer — ADR-022 §2.2.
///
/// ## Shape
///
/// Chapter 2.4 §2 and §3 define two role roots, each a persistent bottom tab
/// bar with independent drill-down stacks, plus one chrome-free surface:
///
/// ```text
/// /login                                        shared, role-agnostic
/// /collector    5 tabs, stack per tab
/// /admin        4 tabs, stack per tab
/// /checklist/:taskId                            full-screen modal
/// /recording/:sessionId                         chrome-free, no back
/// /processing/:sessionId
/// ```
///
/// `StatefulShellRoute.indexedStack` is what makes the tab bar persistent and
/// each tab's stack independent: a branch keeps its own navigator, so drilling
/// into a Project and switching tabs preserves both positions, which Chapter
/// 2.4 §5 requires.
///
/// ## The guard
///
/// A single top-level `redirect` delegates to [AuthGuard], a pure function of
/// auth state and location — see ADR-037. `refreshListenable` is what re-runs
/// it when the session changes, because GoRouter evaluates `redirect` on
/// navigation and has no other reason to look again.
///
/// The router is a provider rather than a top-level `final` for one reason:
/// `redirect` must read `authNotifierProvider`, and a top-level object has no
/// `Ref`. ADR-004's "routes are declared in one place" is unaffected — this is
/// still the only route table.
///
/// ## What is deliberately absent
///
/// - **No modal routes beyond the checklist.** Chapter 2.4 §2 and §3 also
///   specify Permission Blocked (owned by `onboarding`), Create/Edit Project,
///   Create/Edit Task, Assign Collectors, and Metadata Detail/Export (owned by
///   `metadata`). Neither module is scaffolded.
/// - **No typed route arguments.** Every parameter is read as a raw `String`
///   from `GoRouterState`. ADR-004 records the choice between manual parsing
///   and GoRouter's typed-routes generator as unresolved.
/// The application's router.
final Provider<GoRouter> routerProvider = Provider<GoRouter>((Ref ref) {
  return GoRouter(
    initialLocation: AuthGuard.entryRoute,
    refreshListenable: _AuthRefresh(ref),
    redirect: (BuildContext context, GoRouterState state) {
      // `read`, not `watch`: this runs during navigation rather than a build,
      // and watching would rebuild the provider that owns this router.
      // Freshness comes from refreshListenable instead.
      final AsyncValue<AuthState> session = ref.read(authNotifierProvider);

      // `valueOrNull`, never `value`. `AsyncValue.value` *rethrows* on an
      // AsyncError rather than returning null, and this callback runs during
      // `MaterialApp.router`'s build — so a refused session surfaced here as
      // an uncaught exception before any screen was drawn, instead of the
      // fallback to Login it was supposed to produce.
      //
      // An error is treated as "no session": the app could not establish who
      // this is, and Login is where that lands. Distinct from `null`, which
      // means "not yet known" and correctly declines to move anyone.
      final AuthState? auth = session.hasError
          ? const AuthState.unauthenticated()
          : session.valueOrNull;

      return AuthGuard.redirect(auth: auth, location: state.matchedLocation);
    },
    routes: <RouteBase>[
      // The entry point renders nothing: the guard rewrites `/` before a
      // builder is reached, which is why this route has a redirect and none.
      //
      // Mission 0.6's HomeScreen placeholder was here until this mission.
      // ADR-022 §2.2 marked it as leaving "when the first real screen
      // exists", and that condition is now met several times over.
      GoRoute(
        path: AuthGuard.entryRoute,
        redirect: (BuildContext context, GoRouterState state) => '/login',
      ),

      GoRoute(
        path: '/login',
        builder: (BuildContext context, GoRouterState state) =>
            const LoginScreen(),
      ),

      // Reachable without a session, necessarily — the person has no account
      // yet. Linked from Login since amendment A-056, which reversed
      // Mission 2.7's unlinked route: Volume 10 Chapter 10.4 §4's framing
      // exists for an App Store reviewer, and this build is shared as an
      // APK among known people. The invite code is optional now, so what
      // bounds this entry point is that it can only produce a Collector.
      GoRoute(
        path: '/signup',
        builder: (BuildContext context, GoRouterState state) =>
            const SignupScreen(),
      ),

      // ---------------------------------------------------------------------
      // Collector root — Chapter 2.4 §2. Five tabs, in the order it lists them.
      // ---------------------------------------------------------------------
      StatefulShellRoute.indexedStack(
        builder:
            (
              BuildContext context,
              GoRouterState state,
              StatefulNavigationShell navigationShell,
            ) => TabShell(
              navigationShell: navigationShell,
              destinations: const <NavigationDestination>[
                NavigationDestination(
                  icon: Icon(Icons.dashboard_outlined),
                  selectedIcon: Icon(Icons.dashboard),
                  label: 'Dashboard',
                ),
                NavigationDestination(
                  icon: Icon(Icons.folder_outlined),
                  selectedIcon: Icon(Icons.folder),
                  label: 'Projects',
                ),
                NavigationDestination(
                  icon: Icon(Icons.fiber_manual_record_outlined),
                  selectedIcon: Icon(Icons.fiber_manual_record),
                  label: 'Record',
                ),
                NavigationDestination(
                  icon: Icon(Icons.cloud_upload_outlined),
                  selectedIcon: Icon(Icons.cloud_upload),
                  label: 'Sessions',
                ),
                NavigationDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings),
                  label: 'Settings',
                ),
              ],
            ),
        branches: <StatefulShellBranch>[
          // Tab 1 — Dashboard (Home).
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/collector/dashboard',
                builder: (BuildContext context, GoRouterState state) =>
                    const CollectorDashboardScreen(),
              ),
            ],
          ),

          // Tab 2 — Projects, with its drill-down stack.
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/collector/projects',
                builder: (BuildContext context, GoRouterState state) =>
                    const CollectorProjectsScreen(),
                routes: <RouteBase>[
                  GoRoute(
                    path: ':projectId',
                    builder: (BuildContext context, GoRouterState state) =>
                        CollectorProjectDetailScreen(
                          projectId: state.pathParameters['projectId'] ?? '',
                        ),
                    routes: <RouteBase>[
                      GoRoute(
                        path: 'tasks/:taskId',
                        builder: (BuildContext context, GoRouterState state) =>
                            CollectorTaskDetailScreen(
                              taskId: state.pathParameters['taskId'] ?? '',
                            ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),

          // Tab 3 — Record. A shortcut per §2, not a destination.
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/collector/record',
                builder: (BuildContext context, GoRouterState state) =>
                    const RecordShortcutScreen(),
              ),
            ],
          ),

          // Tab 4 — Sessions, with its drill-down stack.
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/collector/sessions',
                builder: (BuildContext context, GoRouterState state) =>
                    const CollectorSessionsScreen(),
                routes: <RouteBase>[
                  GoRoute(
                    path: ':sessionId',
                    builder: (BuildContext context, GoRouterState state) =>
                        CollectorSessionDetailScreen(
                          sessionId: state.pathParameters['sessionId'] ?? '',
                        ),
                  ),
                ],
              ),
            ],
          ),

          // Tab 5 — Settings.
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/collector/settings',
                builder: (BuildContext context, GoRouterState state) =>
                    // R3's fourth resolution: this file may import any
                    // feature's presentation/ (ADR-022 §2.2), so it composes
                    // the auth control into the settings screen. Neither
                    // feature imports the other.
                    const CollectorSettingsScreen(
                      accountActions: <Widget>[SignOutTile()],
                    ),
              ),
            ],
          ),
        ],
      ),

      // ---------------------------------------------------------------------
      // Admin root — Chapter 2.4 §3. Four tabs, in the order it lists them.
      // The left-sidebar alternative §3 mentions depends on Chapter 1.1 §8's
      // open web-surface question and is not built.
      // ---------------------------------------------------------------------
      StatefulShellRoute.indexedStack(
        builder:
            (
              BuildContext context,
              GoRouterState state,
              StatefulNavigationShell navigationShell,
            ) => TabShell(
              navigationShell: navigationShell,
              destinations: const <NavigationDestination>[
                NavigationDestination(
                  icon: Icon(Icons.dashboard_outlined),
                  selectedIcon: Icon(Icons.dashboard),
                  label: 'Dashboard',
                ),
                NavigationDestination(
                  icon: Icon(Icons.folder_outlined),
                  selectedIcon: Icon(Icons.folder),
                  label: 'Projects',
                ),
                NavigationDestination(
                  icon: Icon(Icons.assessment_outlined),
                  selectedIcon: Icon(Icons.assessment),
                  label: 'Sessions',
                ),
                NavigationDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings),
                  label: 'Settings',
                ),
              ],
            ),
        branches: <StatefulShellBranch>[
          // Tab 1 — Dashboard (Home).
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/admin/dashboard',
                builder: (BuildContext context, GoRouterState state) =>
                    const AdminDashboardScreen(),
              ),
            ],
          ),

          // Tab 2 — Projects, with its drill-down stack.
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/admin/projects',
                builder: (BuildContext context, GoRouterState state) =>
                    const AdminProjectsScreen(),
                routes: <RouteBase>[
                  GoRoute(
                    path: ':projectId',
                    builder: (BuildContext context, GoRouterState state) =>
                        AdminProjectDetailScreen(
                          projectId: state.pathParameters['projectId'] ?? '',
                        ),
                  ),
                ],
              ),
            ],
          ),

          // Tab 3 — Sessions & Metadata. Volume 3 §3.5 §2 assigns this root to
          // `upload` (A-07); the metadata overlay (A-08) is not registered.
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/admin/sessions',
                builder: (BuildContext context, GoRouterState state) =>
                    const AdminSessionsScreen(),
              ),
            ],
          ),

          // Tab 4 — Settings/Account.
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/admin/settings',
                builder: (BuildContext context, GoRouterState state) =>
                    const AdminSettingsScreen(
                      accountActions: <Widget>[SignOutTile()],
                    ),
              ),
            ],
          ),
        ],
      ),

      // The Admin's invite-code surface (ADR-036). Outside the shell because it
      // is reached from Settings rather than being a tab of its own, and
      // TEMPORARY — it is retired with the rest of ADR-036 at Mission 6/7.
      //
      // Unguarded, like every other /admin route here: this table still has no
      // redirect (Mission 2.7 owns that). Reaching the screen grants nothing,
      // because firestore.rules checks the admin claim on every write.
      GoRoute(
        path: '/admin/invite-codes',
        builder: (BuildContext context, GoRouterState state) =>
            const AdminInviteCodesScreen(),
      ),

      // ---------------------------------------------------------------------
      // Outside both shells, so no tab bar wraps them — Chapter 2.4 §2 and §5.
      // ---------------------------------------------------------------------

      // Full-screen modal from Task Detail, and per Chapter 2.3 §5 the only
      // route toward capture (BR-04). Nothing enforces that yet; see the class
      // documentation on this route table.
      GoRoute(
        path: '/checklist/:taskId',
        builder: (BuildContext context, GoRouterState state) =>
            PreRecordingChecklistScreen(
              taskId: state.pathParameters['taskId'] ?? '',
            ),
      ),

      // The one chrome-free route. See `RecordingScreen` for what delivers
      // that.
      GoRoute(
        path: '/recording/:sessionId',
        builder: (BuildContext context, GoRouterState state) =>
            RecordingScreen(sessionId: state.pathParameters['sessionId'] ?? ''),
      ),

      GoRoute(
        path: '/processing/:sessionId',
        builder: (BuildContext context, GoRouterState state) =>
            LocalProcessingScreen(
              sessionId: state.pathParameters['sessionId'] ?? '',
            ),
      ),
    ],
  );
});

/// Re-runs the router's `redirect` when authentication state changes.
///
/// GoRouter evaluates `redirect` on navigation. Without this, a session that
/// ends while the user is sitting on a screen leaves them there until they
/// happen to navigate — and a sign-in would not move them at all, because
/// nothing navigates after it.
///
/// `ChangeNotifier` rather than a stream subscription because `Listenable` is
/// the type GoRouter's `refreshListenable` takes. `ref.listen` is what feeds
/// it, and Riverpod disposes the subscription with the provider.
class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(Ref ref) {
    ref.listen<AsyncValue<AuthState>>(authNotifierProvider, (
      AsyncValue<AuthState>? previous,
      AsyncValue<AuthState> next,
    ) {
      // Fires on any transition, including loading→data at cold start.
      // The guard is a pure function, so a redundant evaluation costs a
      // comparison and never a navigation.
      notifyListeners();
    });
  }
}
