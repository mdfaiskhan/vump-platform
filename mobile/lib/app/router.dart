import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/app/home_screen.dart';
import 'package:mobile/app/navigation/tab_shell.dart';
import 'package:mobile/features/auth/presentation/login_screen.dart';
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
/// ## What is deliberately absent
///
/// - **No role redirect.** Chapter 2.4 §4's Role Router sends a user to one
///   root or the other on the strength of their authenticated role. There is
///   no authentication yet, so `/collector` and `/admin` are both reachable
///   directly. ADR-004 records that route-level redirects are where a guard
///   belongs; the guard itself is undecided.
/// - **No modal routes beyond the checklist.** Chapter 2.4 §2 and §3 also
///   specify Permission Blocked (owned by `onboarding`), Create/Edit Project,
///   Create/Edit Task, Assign Collectors, and Metadata Detail/Export (owned by
///   `metadata`). Neither module is scaffolded.
/// - **No typed route arguments.** Every parameter is read as a raw `String`
///   from `GoRouterState`. ADR-004 records the choice between manual parsing
///   and GoRouter's typed-routes generator as unresolved.
final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: <RouteBase>[
    // Mission 0.6's placeholder. ADR-022 §2.2 marks it as leaving "when the
    // first real screen exists"; it is kept here because its widget test is
    // the suite's only widget test and removing it is a separate decision.
    GoRoute(
      path: '/',
      builder: (BuildContext context, GoRouterState state) =>
          const HomeScreen(),
    ),

    GoRoute(
      path: '/login',
      builder: (BuildContext context, GoRouterState state) =>
          const LoginScreen(),
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
                  const CollectorSettingsScreen(),
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
                  const AdminSettingsScreen(),
            ),
          ],
        ),
      ],
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

    // The one chrome-free route. See `RecordingScreen` for what delivers that.
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
