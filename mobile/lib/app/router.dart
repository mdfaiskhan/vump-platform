import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/app/auth_guard.dart';
import 'package:mobile/app/navigation/tab_shell.dart';
import 'package:mobile/app/onboarding_guard.dart';
import 'package:mobile/app/recording_guard.dart';
import 'package:mobile/core/onboarding/providers/onboarding_ports.dart';
import 'package:mobile/features/auth/application/auth_notifier.dart';
import 'package:mobile/features/auth/application/auth_state.dart';
import 'package:mobile/features/auth/presentation/backend_profile_tile.dart';
import 'package:mobile/features/auth/presentation/login_screen.dart';
import 'package:mobile/features/auth/presentation/sign_out_tile.dart';
import 'package:mobile/features/auth/presentation/signup_screen.dart';
import 'package:mobile/features/onboarding/presentation/onboarding_carousel_screen.dart';
import 'package:mobile/features/projects_tasks/presentation/admin_create_project_screen.dart';
import 'package:mobile/features/projects_tasks/presentation/admin_create_task_screen.dart';
import 'package:mobile/features/projects_tasks/presentation/admin_dashboard_screen.dart';
import 'package:mobile/features/projects_tasks/presentation/admin_project_detail_screen.dart';
import 'package:mobile/features/projects_tasks/presentation/admin_projects_screen.dart';
import 'package:mobile/features/projects_tasks/presentation/collector_dashboard_screen.dart';
import 'package:mobile/features/projects_tasks/presentation/collector_project_detail_screen.dart';
import 'package:mobile/features/projects_tasks/presentation/collector_projects_screen.dart';
import 'package:mobile/features/projects_tasks/presentation/collector_task_detail_screen.dart';
import 'package:mobile/features/recording/application/recording_notifier.dart';
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
/// `features/` — ADR-022 R2.
///
/// **R2 also says "and only from a feature's `presentation/` layer", and this
/// file breaks that three times**: `auth/application/auth_notifier.dart`,
/// `auth/application/auth_state.dart` and
/// `recording/application/recording_notifier.dart`. `auth_guard.dart` and
/// `recording_guard.dart` add four more, for seven across `lib/app/`.
///
/// ADR-022 predicted this exactly — it recorded the rule as *"binding in
/// writing and unenforced in fact"* and assigned the CI check to *"the mission
/// that creates the first feature"*. That mission came and went; the check was
/// never added, and the breaches accumulated undetected. Recorded as an open
/// item, with the fix scoped as its own future work rather than a by-product
/// of Mission 5.4.
///
/// It is stated here rather than left implied, because the sentence this
/// replaced claimed compliance the file does not have.
///
/// ## Shape
///
/// Chapter 2.4 §2 and §3 define two role roots, each a persistent bottom tab
/// bar with independent drill-down stacks, plus one chrome-free surface:
///
/// ```text
/// /                                             renders nothing; always redirects
/// /login                                        shared, role-agnostic
/// /signup                                       public; the invite code is OPTIONAL (A-056)
///
/// /collector    5 tabs (Chapter 2.4 §2), stack per tab
///   /collector/dashboard                        C-03
///   /collector/projects                         C-04
///     /collector/projects/:projectId            C-05  — IS Chapter 2.4's "Task List"
///       …/tasks/:taskId                         C-06
///   /collector/record                           shortcut into a Task's checklist
///   /collector/sessions                         C-11
///     /collector/sessions/:sessionId            placeholder — open item 82
///   /collector/settings
///
/// /admin        4 tabs (Chapter 2.4 §3), stack per tab
///   /admin/dashboard                            A-01
///   /admin/projects                             A-02
///     /admin/projects/:projectId                A-03  — IS Chapter 2.4's "Task List"
///   /admin/sessions                             placeholder — A-07, open item 96
///   /admin/settings
///
/// /onboarding                                   full-screen modal, C-01
/// /admin/projects/new                           full-screen modal, A-04
/// /admin/projects/:projectId/tasks/new          full-screen modal, A-05
/// /checklist/:taskId                            full-screen modal
/// /recording/:sessionId                         chrome-free, no back
/// /processing/:sessionId                        C-10
/// ```
///
/// **This table lists every route the file declares.** It listed nine of them
/// until Mission 5.4 — accurate when Mission 1.3 wrote it, and left behind by
/// eleven sub-missions of additions, so a reader checking "what routes exist"
/// against the most obvious place to look got less than half the answer. Same
/// failure mode as A-114: a record true when written that nothing re-checks.
///
/// ## Four of these routes are not in Chapter 2.4's navigation model
///
/// `/onboarding` (C-01), `/processing/:sessionId` (C-10) and `/signup`.
/// Chapter 2.4 names no modal, tab or stack position for any of them —
/// verified against its full text, not assumed. `/signup` is not in Chapter
/// 2.5's screen inventory either; it exists because self-signup (A-051,
/// A-056) was decided after Volume 2 was written.
///
/// **`/admin/invite-codes` was a fourth, and is gone.** Mission 7.6 Phase 6
/// retired invite-code ISSUING rather than porting it: its only enforcement
/// was a `firestore.rules` condition being deleted in the same phase, so
/// leaving the screen would have presented a permission-gated-looking surface
/// with no gate behind it. Codes are minted by an operator until an admin
/// surface is designed against real requirements. See A-227.
///
/// This is the **inverse** of open item 82, where Chapter 2.4 names screens the
/// inventory lacks. Both directions are recorded, separately, because they
/// have different causes and different fixes.
///
/// `StatefulShellRoute.indexedStack` is what makes the tab bar persistent and
/// each tab's stack independent: a branch keeps its own navigator, so drilling
/// into a Project and switching tabs preserves both positions, which Chapter
/// 2.4 §5 requires.
///
/// ## The guard
///
/// A single top-level `redirect` delegates to three pure functions, in a fixed
/// order — see ADR-037:
///
/// 1. [AuthGuard] — who is this, and may they be here at all.
/// 2. [OnboardingGuard] — has this Collector seen C-01 (Chapter 2.7's
///    "shown at first launch").
/// 3. [RecordingGuard] — BR-04's checklist gate.
///
/// Auth runs first because someone with no session belongs on Login regardless
/// of what the other two think, and running them first would bounce them
/// twice. Each guard's own doc gives its reason for the position it holds.
///
/// `refreshListenable` is what re-runs the chain when the session changes,
/// because GoRouter evaluates `redirect` on navigation and has no other reason
/// to look again.
///
/// The router is a provider rather than a top-level `final` for one reason:
/// `redirect` must read `authNotifierProvider`, and a top-level object has no
/// `Ref`. ADR-004's "routes are declared in one place" is unaffected — this is
/// still the only route table.
///
/// ## What is deliberately absent
///
/// - **Five of Chapter 2.4's modals have no route, each for a recorded
///   reason.** Permission Blocked (C-02, no permission plugin — open item 78);
///   Edit Project (Chapter 2.9 contradicts itself — item 87); Edit Task (same
///   contradiction — item 90); Assign Collectors (A-06: no endpoint returns
///   assignments or the org's Collectors — item 89); Metadata Detail/Export
///   (A-08, item 97). **Create** Project and Create Task do have routes, added
///   by Mission 5.2.2.
///
///   None of them is a stub or a disabled control. A greyed entry point
///   implies a capability that is temporarily off, and nothing here is off —
///   the destinations do not exist.
/// - **Three routes Chapter 2.4 names have no screen in Chapter 2.5's
///   inventory**: Session Detail, Chunk Detail and Admin Task Detail. Open
///   item 82. `/collector/sessions/:sessionId` is a placeholder for the first;
///   the other two have no route at all.
/// - **Chapter 2.4's four-level Project stacks are three routes, correctly.**
///   *Projects → Project Detail → Task List → Task Detail* names four levels,
///   but Chapter 2.5 describes C-05 as *"Task List within the selected
///   Project"* and A-03 as *"Task list within the Project"* — Project Detail
///   **is** the Task List. The level collapses; nothing is missing.
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

      final String? authRedirect = AuthGuard.redirect(
        auth: auth,
        location: state.matchedLocation,
      );
      if (authRedirect != null) {
        return authRedirect;
      }

      // Chapter 2.7's "shown at first launch", and it runs after AuthGuard for
      // the same reason RecordingGuard does: someone with no session belongs
      // on Login, and priming them first would bounce them twice.
      //
      // It runs BEFORE RecordingGuard, which matters in exactly one case — a
      // first-launch deep link to /recording/:id. Onboarding wins there,
      // because a device that has never been primed has no live session for
      // RecordingGuard to protect, so its only possible answer is the Record
      // tab, and sending an unprimed Collector there skips the screen
      // Chapter 2.7 says comes first.
      final String? onboardingRedirect = OnboardingGuard.redirect(
        isCollector: AuthGuard.isCollector(auth),
        hasSeenOnboarding: ref
            .read(onboardingSeenStoreProvider)
            .hasSeenOnboarding,
        location: state.matchedLocation,
      );
      if (onboardingRedirect != null) {
        return onboardingRedirect;
      }

      // BR-04, and it runs second on purpose: someone who is not signed in
      // belongs on Login regardless of what the recording machine is doing,
      // and sending them to the Record tab first would bounce them twice.
      return RecordingGuard.redirect(
        state: ref.read(recordingNotifierProvider),
        location: state.matchedLocation,
      );
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
                              projectId:
                                  state.pathParameters['projectId'] ?? '',
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
                      accountActions: <Widget>[
                        BackendProfileTile(),
                        SignOutTile(),
                      ],
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
                      accountActions: <Widget>[
                        BackendProfileTile(),
                        SignOutTile(),
                      ],
                    ),
              ),
            ],
          ),
        ],
      ),

      // ---------------------------------------------------------------------
      // Outside both shells, so no tab bar wraps them — Chapter 2.4 §2 and §5.
      // ---------------------------------------------------------------------

      // A-04 and A-05's create halves. Chapter 2.4 §3 presents Create/Edit
      // Project and Create/Edit Task as modals, so both sit outside the shell
      // and carry no tab bar.
      //
      // They are declared here rather than as children of /admin/projects so
      // the literal `new` segment cannot be matched as a :projectId. Nesting
      // them would make the route table order-dependent, which is a trap the
      // next person to add a segment would have to know about.
      GoRoute(
        path: '/admin/projects/new',
        builder: (BuildContext context, GoRouterState state) =>
            const AdminCreateProjectScreen(),
      ),
      GoRoute(
        path: '/admin/projects/:projectId/tasks/new',
        builder: (BuildContext context, GoRouterState state) =>
            AdminCreateTaskScreen(
              projectId: state.pathParameters['projectId'] ?? '',
            ),
      ),

      // C-01, Chapter 2.4 §2's "full-screen modal, shown at first launch".
      //
      // Outside the shell because it carries no tab bar, and reachable by
      // route rather than only at launch so C-02 can send a Collector back
      // through the explanation once that screen exists.
      //
      // Reached by OnboardingGuard on a Collector's first launch, and by route
      // otherwise, so C-02 can send someone back through the explanation once
      // that screen exists.
      //
      // Until Mission 5.4 this route had NO inbound edge from anywhere in
      // `lib/` — declared, buildable, and reachable by nobody. The trigger it
      // was missing is `OnboardingSeenStore`.
      //
      // **The screen still requests no permission.** It cannot: this project
      // has no permission plugin, so three of FR-ONB-01's five cannot even be
      // read (see OnboardingCarouselScreen). Making the carousel reachable
      // makes it shipped, not satisfied — FR-ONB-01 stays open, with C-02 and
      // the ADR-030 plugin decision, at open item 78.
      GoRoute(
        path: OnboardingGuard.route,
        builder: (BuildContext context, GoRouterState state) =>
            OnboardingCarouselScreen(
              // Awaited before navigating, not fired alongside it: the `go`
              // below re-runs the top-level redirect, which reads the flag
              // synchronously. Navigating first would race the write and send
              // the Collector straight back to this screen.
              onComplete: () async {
                await ref.read(onboardingSeenStoreProvider).markSeen();
                if (context.mounted) {
                  context.go(AuthGuard.collectorRoot);
                }
              },
            ),
      ),

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
