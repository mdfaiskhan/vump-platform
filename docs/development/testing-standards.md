# Testing Standards

The canonical testing standard for the Vump Technologies repository.

Governed by **ADR-029**. Where this document and the ADR disagree, the ADR governs.

**Volume 9 is the authority for testing** and is unusually complete: Chapter 9.5 fixes the pyramid and coverage targets, 9.6 unit testing, 9.7 integration and golden testing, 9.8 manual, 9.9 the device matrix. This document implements what the repository can implement today, cites Volume 9 for the rest, and **records what is absent as absent** — three of the four test tools Volume 3 §3.1 names are not installed, and 39 of 55 hand-written source files are never loaded by any test.

**Nothing already governed is restated.** Cited, not duplicated:

| Already fixed by | What it fixes |
|---|---|
| Volume 9 Ch. 9.5 | The pyramid — unit ~70%, integration/widget ~20%, manual ~8%, device ~2% — and the coverage targets |
| Volume 9 Ch. 9.6 | What gets a unit test, and what unit tests deliberately do not cover |
| Volume 9 Ch. 9.7 | The five end-to-end flows, the fake backend, golden tests as a hard gate |
| Volume 9 Ch. 9.1 §3 | *"No untested error path ships"* |
| Volume 9 Ch. 9.4 | Six measurable performance targets, and which are manual rather than automated |
| Volume 3 Ch. 3.6 §4 | Every test file at the identical path under `test/` |
| Volume 6 Ch. 6.4 §4 | Repository providers are designed to be overridden with a fake |
| ADR-021 | `use_test_throws_matchers`, and the analyzer rules that apply to test code too |
| ADR-022 §6.1 | A feature mirrors its structure in `test/` |
| ADR-023 §1.3, §8 | Test filenames and test names |
| ADR-025 §28 | What every error boundary must have a test for |
| ADR-027 §13 | Silencing log output in tests, via the `LogOutput` seam |
| ADR-028 · `review-checklist.md` §4.5 | The test items a reviewer checks |

---

## 1. The pyramid, and where the repository sits in it

Volume 9 Chapter 9.5 §1 fixes four layers:

| Layer | Volume | Proportion | Tooling Volume 3 §3.1 names | Installed |
|---|---|---|---|---|
| Unit | 9.6 | ~70% | `flutter_test`, `mocktail` | `flutter_test` only |
| Integration / Widget | 9.7 | ~20% | `integration_test`, `golden_toolkit` | **Neither** |
| Manual / Exploratory | 9.8 | ~8% | Human tester, real devices | — |
| Device Matrix | 9.9 | ~2%, *"but gates every release"* | Physical devices, Firebase Test Lab | — |

**Why the weight sits at the bottom**, in Volume 9 §9.5 §1's own words: *"Volume 3, Chapter 3.4's layered architecture (Domain/Data as pure Dart) is what makes a 70% unit-test proportion realistic rather than aspirational; most business logic (every BR-tagged rule) is testable without a widget tree or a real device at all."*

That is the load-bearing connection between the architecture and this standard: ADR-001's dependency inversion is what makes the pyramid affordable.

**Where the repository actually is.** 4 test files, 28 tests, 7 groups — 27 `test()` and 1 `testWidgets()`. The proportions are not yet meaningful, because `lib/features/` is empty and there is no business logic to unit-test. Tooling absence is tracked as **A-027** (golden) and **A-028** (`mocktail`, `integration_test`).

---

## 2. Structure and placement

**Every test file lives at the identical path under `test/` as the file it tests under `lib/`.** Volume 3 §3.6 §4 fixes this and states the reason: *"so there is never any ambiguity about where a new feature's tests belong."* Volume 9 §9.6 §1 cites the same rule, and `test/app/home_screen_test.dart` cites it in a header comment.

**Filename is `<subject>_test.dart`** (ADR-023 §1.3). `flutter test` discovers `*_test.dart`; a file not matching is not run, silently.

**One test file per class** for use cases (Volume 9 §9.6 §1).

Current tree, mirroring exactly:

```text
test/app/config/app_environment_test.dart      → lib/app/config/app_environment.dart
test/app/home_screen_test.dart                 → lib/app/home_screen.dart
test/core/environment/environment_profile_test.dart
test/core/firebase/firebase_initializer_test.dart
```

**A test file opens with a header comment when its placement or scope needs explaining.** `home_screen_test.dart` is the model — it cites the mirroring rule and states that it pumps the real composition rather than the widget in isolation, *"so the router and theme are exercised too."*

**State what is deliberately untested, and why, at the top.** `environment_profile_test.dart` does exactly this: *"`firebaseProjectId` is deliberately untested here: it reads `DefaultFirebaseOptions.currentPlatform`, which depends on a platform the test host does not provide. Everything else is pure."* A named exclusion is a decision; an unnamed one is an oversight, and a reader cannot tell them apart.

---

## 3. Naming

**Fixed by ADR-023 §8 and not restated:** `group` names the area as a noun phrase; `test` names a lowercase sentence stating the guarantee; "should" is dropped.

**One addition from Volume 9 §9.6 §2, which ADR-023 does not carry.** The Volume's worked example prefixes the requirement ID:

```dart
test('BR-06: chunk boundary fires at exactly 10 minutes', () async {
```

That is how Volume 3 §3.7 §4's traceability requirement — *"any code implementing a rule non-obvious from its own logic alone carries a one-line comment citing the ID"* — is satisfied for a test. The prefix is an identifier followed by ADR-023's lowercase sentence, so the two conventions compose:

```text
BR-06: chunk boundary fires at exactly 10 minutes
FR-CHK-05: a failed checklist can be re-run without restarting the session
```

**Use the prefix when the test exists because a numbered requirement exists.** Not otherwise — `'an absent APP_ENV is not treated as a mistake'` cites nothing because no Volume 1 requirement drives it, and inventing an ID would be worse than omitting one.

**No requirement-ID prefix appears in the suite today**, because no Volume 1 requirement is implemented (`features/` is empty). The convention is recorded ahead of its first use.

---

## 4. Unit testing

Volume 9 §9.6 §1 fixes what gets one:

- **Every use-case class** — one test file per class.
- **Every repository's error paths** — *"not just its happy path"* (Volume 9 §9.1).
- **Every Riverpod notifier's state transitions**, using `ProviderContainer` overrides *"rather than a widget pump"*.

That third item is the one most often done the expensive way. A notifier is plain Dart reading from an interface; testing it through a rendered widget adds a render tree, an async settle and a source of flakiness for no additional assurance.

**What unit tests deliberately do not cover**, per Volume 9 §9.6 §4: real camera behaviour, real background upload, real platform-channel calls — *"faked/mocked at the Platform Services boundary, never exercised for real in a unit test"* — and visual correctness, which is §9.7's golden testing.

**Established pattern in the suite: exhaustive loops over an enum.** `environment_profile_test.dart` and `app_environment_test.dart` both iterate `AppEnvironment.values` rather than asserting three cases by hand, so adding an environment cannot leave a test passing on a subset.

**Also established: test the property, not the value.** The most valuable tests in the suite are the delegation checks, and they carry a comment saying so — *"These are the tests that matter. If someone gives the profile its own copy of a value, it will drift from the owner and these will catch it."* They assert `EnvironmentProfile.apiBaseUrl == NetworkConfig.baseUrlFor(environment)` rather than a literal URL, so they survive a URL change and still catch a duplicated definition, which is the failure ADR-018 exists to prevent.

---

## 5. Widget testing

**One widget test exists**, and it sets the convention: pump the real composition, not the widget in isolation.

```dart
await tester.pumpWidget(const ProviderScope(child: VumpApp()));
await tester.pumpAndSettle();
expect(find.text('Vump Technologies'), findsOneWidget);
```

**Wrap in `ProviderScope`** — ADR-003 makes Riverpod the sole injection mechanism, so a widget outside a scope cannot read what it needs.

**Override providers rather than constructing dependencies.** Volume 6 §6.4 §4 fixes the mechanism and the reason: *"every repository provider is designed to be overridden this way, so Volume 9's test suite never needs a real Drift database, a real camera, or a real network call to test a Notifier's logic."*

```dart
ProviderScope(
  overrides: <Override>[
    recordingRepositoryProvider.overrideWithValue(FakeRecordingRepository()),
  ],
  child: const VumpApp(),
)
```

**Find by semantics or text, not by widget type**, where the assertion is about what a Collector sees. A `find.byType` assertion passes when the widget renders the wrong content.

**Golden tests are the presentation layer's coverage measure, not a line percentage.** Volume 9 §9.5 §2 is explicit: golden tests for every Design System component *"rather than a blanket coverage percentage — pixel-consistency matters more here than line coverage."*

---

## 6. Integration testing

**None exists.** No `integration_test/` directory, and `integration_test` is not a dependency (**A-028**).

Volume 9 §9.7 §1 fixes five flows, each traced to a requirement:

| Flow | Traces to |
|---|---|
| Collector records and uploads a session | Volume 1 Ch. 1.8, UC-01/02 |
| Offline recording, resumed upload | FR-UPL-05, NFR-AVL-02 |
| Checklist failure and recovery | FR-CHK-05, Chapter 2.9 |
| Admin assigns a Collector, Collector sees it appear | FR-ADM-01–03, UC-07 |
| Failed upload, manual retry succeeds | FR-UPL-07, Volume 5 Ch. 5.13 |

**Each flow runs against a fake backend**, not staging: *"a local mock server returning scripted responses… fast, deterministic, and runnable in CI without network flakiness."* That is a requirement, not an optimisation — a test that reaches staging is neither deterministic nor available offline.

**What integration tests deliberately do not cover** (§9.7 §3): real camera hardware, real background upload across an app kill, real multi-day battery or thermal behaviour. *"These can't be faked meaningfully"* — they belong to Chapters 9.8 and 9.9.

All five flows depend on features that do not exist. This section is a specification, not a description.

---

## 7. Golden testing

**None exists**, and the tool is unchosen.

Volume 9 §9.7 §2 fixes the requirement: every reusable Design System component has a golden test capturing its rendered output **in both light and dark theme**, and *"a golden test failing on an unintentional pixel diff is a hard CI gate — intentional visual changes require explicitly regenerating and committing the new golden image as part of that PR, so no visual regression ships silently."*

**The requirement stands; the named tool does not.** `golden_toolkit` is discontinued (**A-027**). Flutter's built-in `matchesGoldenFile` is the likely replacement and is not yet decided. `lib/shared/` is empty and the only screen renders two `Text` widgets, so there is nothing to capture — the decision belongs to the mission that builds the first component.

**The regenerate-and-commit rule is the part worth remembering early**, because it is what makes a golden gate meaningful rather than an obstacle: a diff is either a bug or a reviewed, committed image.

---

## 8. Substitution — fakes, not mocks

**The repository uses hand-written fakes with no mocking framework.** Verified: no `mocktail`, no `Mock` subclass, no generated mock anywhere in `test/` or `lib/`.

The one substitution in the suite is a fake:

```dart
/// Discards log output so a failing-by-design test does not print noise.
class _SilentOutput extends LogOutput {
  @override
  void output(OutputEvent event) {}
}
```

**Prefer a fake to a mock.** A fake implements the interface with a working, simplified behaviour; a mock asserts on calls. Three reasons this repository's design favours fakes:

- **ADR-001's interfaces exist to be substituted.** `SecureStorageRepository` and `Migration` are `abstract interface class` declarations — a fake implementing one is checked by the compiler, and a renamed method breaks it immediately.
- **Volume 6 §6.4 §4 specifies the mechanism** as `overrideWithValue(FakeRecordingRepository())`, a fake behind a provider.
- **A mock asserts on interactions, which couples the test to the implementation.** Asserting that a repository method was called once tests how the use case is written, not what it guarantees.

**Use a mock when the interaction *is* the guarantee** — that a retry was attempted exactly N times, that a credential was never requested. Volume 3 §3.1 and Volume 9 §9.5 §1 both name `mocktail` for this, and A-028 records that it is deliberately not installed until it has a consumer, because *"an installed-but-unused test dependency is weight in the lockfile and an invitation to use the wrong tool for the current problem."*

**Name a fake `Fake<Subject>`**, private (`_`) when local to one test file. `_SilentOutput` is named for its behaviour rather than its type, which is correct for a stub with one job.

---

## 9. Determinism

**A test that can fail without a code change is worse than no test**, because it teaches the suite to be ignored.

**Never call `DateTime.now()` inside code under test.** Volume 9 §9.6 §2 requires an injectable clock: *"A fake, injectable clock (never `DateTime.now()` called directly inside a use-case) is what makes a 10-minute business rule testable in milliseconds rather than requiring an actual 10-minute test run."*

**Audit finding.** `DateTime.now()` is called directly in three places today — `LoggingInterceptor` (request timing), `DatabaseService` and `FirebaseInitializer` (operation duration). None is a use case, so none violates the letter of §9.6 §2, and all three produce a duration for a log line rather than a decision. The consequence is narrow but real: **those durations cannot be asserted**, which is part of why `LogFormatter` and the interceptors have no tests. No clock abstraction exists in the repository.

Volume 9 §9.6 §2 also claims the pattern is *"itself a Chapter 3.7 coding-standard requirement"*. **It is not** — Volume 3 §3.7 has nine sections and none mentions a clock, `DateTime.now()` or time injection. Registered as **A-045**.

**Other determinism rules, derived:**

- **No real network.** Volume 9 §9.7 §1's fake backend requirement; and `AWS credential isolation` in CI means nothing in `mobile/` can reach S3 directly anyway.
- **No real device, database or camera in a unit test** (Volume 9 §9.6 §4).
- **No `Math.random()` or unseeded randomness** in code under test — pass the value in.
- **No dependence on test execution order.** Build state in `setUp`, as `firebase_initializer_test.dart` does.
- **No wall-clock waits.** `pumpAndSettle` over a fixed `Future.delayed`.

---

## 10. Async testing

- **`await` every future in a test.** `unawaited_futures` and `discarded_futures` are analyzer **errors** (ADR-021), and they apply to test code — a dropped future in a test produces a pass that asserted nothing.
- **`pumpAndSettle` after an interaction that triggers async work**, as the widget test does.
- **Assert that concurrent callers share one attempt** where the code deduplicates. `firebase_initializer_test.dart` does exactly this: *"concurrent callers share a single initialisation attempt"*, asserting `identical(first, second)`.
- **Assert that a failed async attempt is retryable rather than cached.** Also from that file — *"a failed attempt is retryable rather than cached forever"* — which catches the specific bug of a memoised in-flight future holding a failure permanently.
- **Use `throwsA(isA<T>())`, never a manual `try`/`catch` with `fail()`.** `use_test_throws_matchers` is enabled (ADR-021).

---

## 11. Error-path testing

**Volume 9 §9.1 §3 is the one rule Volume 9 defines rather than references:** *"No untested error path ships: any pull request adding a new failure mode (a new sealed subtype, a new possible API error code) must add its corresponding test in the same PR — enforced at code review."*

**What every conversion boundary needs is fixed by ADR-025 §28 and not restated here.** The one assertion that matters most, in its words: a test *"that the third-party error is converted"* — asserting the `AppException` subclass and the `ErrorCode`. `firebase_initializer_test.dart` is the model, with *"initialize converts the failure into the application taxonomy"*.

**Assert on the `ErrorCode`, never on a message string.** A message is developer-facing prose that may be reworded; asserting it breaks on a reword and passes on a wrong code — exactly inverted.

**Volume 9 §9.5 §2 makes the data layer's target error-path-focused**, not merely 80%: *"focused on error-path coverage per Chapter 9.1's rule, not just the happy path."* A repository at 80% that covers only success paths does not meet the target.

---

## 12. Logging verification

**Fixed by ADR-027 §13 and not restated.** Two points belong here:

**Silence log output rather than tolerating it.** Inject a `LogOutput`; `_SilentOutput` is the established form. A test that prints real log lines makes a failing run harder to read.

**The seam that silences output is the same one that would verify it.** A capturing `LogOutput` collecting `OutputEvent`s is what makes redaction assertable — and ADR-027 §13 records that as the highest-value missing test in that layer: seven header names are the only thing between a bearer token and a log line, `_redactHeaders` is a pure function, and nothing verifies it.

---

## 13. Platform testing

**A `flutter test` host has no platform channels.** This shapes what is testable and is already documented in the suite: `firebase_initializer_test.dart`'s header explains that *"the platform channels `Firebase.initializeApp` depends on do not exist under `flutter test`. That makes them a test of the error boundary rather than of initialisation itself: whatever goes wrong, callers must see an `AppException` and never a `FirebaseException` from the SDK."*

**That is the pattern to reuse, not a limitation to work around.** A missing platform channel gives a free failure injection: the boundary is exercised for real, and the assertion is the one that matters.

**Real-device verification is Volume 9 Chapter 9.9's job** and gates every release at ~2% of the suite. Nothing exists — no device matrix, no Firebase Test Lab configuration. `flutter build apk --debug` and `--release` succeed via the Gradle shim (**A-029**); 16 KB page size support for Isar's prebuilt libraries remains unverified and is the likely next release blocker.

**Manual and exploratory testing is Chapter 9.8's job** — the camera, background upload and multi-day thermal behaviour that cannot be faked. No plan exists in the repository.

### Performance measurement

**Volume 9 Chapter 9.4 fixes six measurable performance targets, and assigns four of them to manual measurement rather than to an automated test:**

| Target | Measured by |
|---|---|
| Metadata generation < 500ms per chunk (NFR-META-01) | **In-app instrumented timestamp diff** around Volume 5 §5.7's generation step |
| Upload resume after reconnect < 30s (NFR-AVL-02) | **In-app**, from the same data source as Chapter 9.3's recovery-time metric |
| Cold start to Login < 2.5s on a mid-range device | Manual stopwatch during Chapter 9.9 — *"no automated instrumentation needed for a one-time-per-launch metric"* |
| Recording Screen sustained 60fps, zero dropped-frame jank | Flutter DevTools performance overlay, Chapter 9.8 manual device testing |
| Battery drain < 15% per 10-minute chunk | Manual measurement, Chapter 9.9 |
| No OOM across a full multi-chunk session | Android Studio / Xcode Instruments profiling, device testing |

**So the absence of an automated performance test is correct by design, not a gap.** No Volume asks for one. What Volume 9 §9.4 does ask for is two pieces of **in-app instrumentation** and four **manual measurement procedures**, none of which exists — and all six depend on the recording and upload features, so all six are correctly absent today.

**Volume 9 §9.4 §2 explains why these targets matter more here than in a typical app:** the Recording Screen *"runs continuously for up to 10 minutes per chunk, often back-to-back across a full field shift — a janky preview or excessive battery drain isn't a minor annoyance here, it's a direct threat to the product's core promise of reliable, unattended field capture."*

**The instrumentation precedent already exists**, and it intersects with §9. `DatabaseService` and `FirebaseInitializer` already log an operation duration as a `DateTime.now()` difference, which is exactly the *"instrumented timestamp diff"* shape §9.4 wants for metadata generation. Today those durations only reach a log line. Once a **target** depends on one, the value has to be assertable — and §9's finding is that a directly-called `DateTime.now()` is not. An injected clock stops being a testing nicety at that point.

---

## 14. Fixtures and test data

**None exists.** No `test/fixtures/`, no test data directory, no `dart_test.yaml`, no shared helper file. Every test constructs what it needs inline, which is correct at four files.

**When fixtures arrive, three rules are already implied by decisions taken:**

- **A fixture carries no real credential.** `review-checklist.md` §4.7 records why the CI `Secret scan` is not enough: its patterns are deliberately narrow, so a fixture-shaped secret can pass.
- **A fixture is a `const` in Dart, not a loose JSON file**, unless the point is to test decoding. A JSON fixture bypasses the type system; a `const` DTO does not compile when the shape changes.
- **A shared fixture lives at the mirrored path of what it serves**, or in the test file that uses it. There is no `test/utils/` — ADR-022 R5 forbids that shape in `lib/` and the same reasoning applies here.

---

## 15. Coverage

**Volume 9 §9.5 §2's targets:**

| Layer | Target |
|---|---|
| Domain (use cases) | **90%+** line coverage — *"this is where BR-01–23 actually live in code"* |
| Data (repositories) | **80%+**, error-path focused |
| Presentation (widgets) | Golden tests for every Design System component, **not** a percentage |

**What CI measures, and why it cannot express those targets.** The `Test` job runs `flutter test --coverage` and reports:

```bash
hit=$(grep -c '^DA:.*,[1-9]' coverage/lcov.info)
total=$(grep -c '^DA:' coverage/lcov.info)
```

**That is a single repository-wide percentage with no layer breakdown**, so neither the 90% nor the 80% target is computable from it. It is also **blind to files no test imports** — `lcov.info` lists only files loaded during the run, so a file with no test does not appear as 0%, it does not appear at all.

**The measured effect, verified against the committed `coverage/lcov.info`:**

| | |
|---|---|
| Reported by CI | **146 / 224 lines = 65%** |
| Files that figure covers | **16** |
| Hand-written source files in `lib/` | **55** |
| **Files never loaded by any test** | **39** |

So the honest coverage figure is 146 lines out of a codebase whose instrumented portion is under a third of it. **65% is not wrong; it is measured over 29% of the files.** Registered as **A-046**.

**Modules with no test contact at all:**

| Module | Files never loaded |
|---|---|
| `app/theme` | 8 |
| `core/database` | 7 |
| `core/errors` | 6 |
| `core/network` | 6 |
| `app/config` | 4 |
| `core/storage` | 4 |
| `core/firebase` | 2 |
| `core/logging` | 1 |
| `main.dart` | 1 |

**The gate is deliberately off**, and CI says why: *"No threshold is enforced yet, deliberately: `lib/features/` is empty, so `domain/` and `data/` do not exist and any gate would be vacuous."* That reasoning is sound for the *layer* targets and does not extend to the six `core/` modules above, which exist and ship.

---

## 16. CI execution

**Fixed by ADR-019's protection rules — all nine jobs are required.** Two concern testing:

| Job | Does |
|---|---|
| `Test` | `flutter test --coverage --reporter expanded`, then reports the coverage line. Fails if `coverage/lcov.info` was not produced |
| `Generated code drift` | Regenerates and diffs, so a test cannot pass against stale generated code |

**Tests run on `ubuntu-latest` with `FLUTTER_VERSION: 3.44.9` pinned** (A-024), so a test cannot pass locally and fail in CI because of an SDK difference.

**The four jobs run as separate jobs, not steps**, so a test failure still reports the format, analyze and drift results. This matters when a change breaks two things.

**`coverage/lcov.info` is committed.** That is what made §15's audit possible without running the suite, and it also means a stale file could mislead — it is regenerated on every CI run, and locally by `flutter test --coverage`.

---

## 17. Gaps

Recorded rather than fixed — this is a documentation and governance mission.

| Gap | Evidence | Disposition |
|---|---|---|
| **39 of 55 source files have no test contact** | §15, measured from `lcov.info` | **A-046.** The six `core/` modules are the priority: they exist, they ship, and the "features are empty" argument does not apply to them |
| **Coverage cannot express Volume 9's per-layer targets** | One repository-wide percentage, no layer breakdown, blind to unimported files | **A-046.** Needs per-layer computation before any gate is meaningful |
| **Three of four named test tools absent** | `mocktail`, `integration_test`, `golden_toolkit` | **A-028**, and **A-027** for the discontinued one |
| **No integration test, no golden test** | No `integration_test/`, no golden files | Volume 9 §9.7's five flows all depend on features that do not exist |
| **No error-boundary test outside Firebase** | `core/network`, `core/database`, `core/storage` all convert third-party errors and none is tested | Highest-value missing tests. ADR-025 §28 specifies exactly what each needs; ADR-027 §13 names the redaction test |
| **No clock abstraction** | `DateTime.now()` called directly in three `core/` files (§9) | Not a violation — none is a use case — but those durations are unassertable |
| **Volume 9 §9.6 §2 mis-cites Volume 3 §3.7** | V3.7 has nine sections; none mentions a clock | **A-045** |
| **No fixtures, no `dart_test.yaml`, no shared helpers** | §14 | Correct at four test files; §14 records the rules for when they arrive |
| **No manual test plan, no device matrix** | Volume 9 §9.8, §9.9 | ~10% of the pyramid by Volume 9's proportions, entirely absent |
| **No automated performance test** | Verified: nothing measures frame time, memory or battery | **Correct by design.** Volume 9 §9.4 assigns four of its six targets to manual measurement and two to in-app instrumentation; no Volume asks for an automated performance test (§13) |
| **No performance instrumentation or measurement procedure** | Volume 9 §9.4's six targets have no implementation and no runbook | All six depend on recording and upload, so correctly absent. The two in-app ones will need an injected clock (§9, §13) |
| **Coverage gate is off** | Deliberate for layer targets; not justified for `core/` | Revisit once `core/` has tests |

---

## 18. Maintenance

- **A new failure mode adds its test in the same pull request.** Volume 9 §9.1 §3, and `review-checklist.md` §4.4 checks it.
- **A new use case gets one test file, at the mirrored path.**
- **A new `Design System` component gets a golden test in both themes** — once the tool is chosen (§7).
- **A test asserting a message string is a defect.** Assert the `ErrorCode`.
- **When a tool is finally installed**, remove it from §1's *Installed* column and from §17, and update A-027 or A-028.
- **Every number in §15 is re-derived, not copied.** It is computed from `coverage/lcov.info`, which is committed and regenerated on every run.
- **A new determinism hazard gets a rule in §9**, with the mechanism that removes it — an injected clock, a seeded value, a fake server.
