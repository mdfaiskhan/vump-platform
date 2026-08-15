# ADR-021 — Static Analysis Configuration

- **Status:** Superseded by ADR-038 (2026-08-15)
- **Superseded because:** its §"Generated code is analysed, not excluded" states that `isar_generator` emits its own `ignore_for_file` header. It does not. The body below is left exactly as accepted, per governance — ADR-038 carries the correction and every other decision here forward unchanged.
- **Date:** 2026-08-10
- **Supersedes:** none. Widens Volume 3, Chapter 3.7 §2 — see `docs/architecture/volume-amendments.md`, amendment A-031.

## Context

Static analysis is the only code-quality mechanism in this project that runs on every change, needs no reviewer, and cannot be forgotten. Everything else — review, tests, the architecture boundary check — depends on someone writing something first. The analyzer runs on a file the moment it is saved.

That makes the rule set a load-bearing decision, and until now it was not recorded as one.

Three things forced the decision now.

**The rule set was fixed by a volume, not by an ADR.** `mobile/analysis_options.yaml`, written in Mission 0.18.5, enables six rules and states that all six are required by Volume 3, Chapter 3.7 §2, and that adding a seventh "is an architecture change and needs an ADR". That is the correct governance instinct and it left the file frozen at a floor: six rules plus `flutter_lints`. Six rules is not a production configuration. Under it, `strict-casts` was off, `dynamic` flowed freely through JSON boundaries, unawaited futures were silent, and `BuildContext` could be used across an `await`.

**The volumes describe a floor, not a ceiling.** §3.7 §2's six rules were chosen for one purpose — "to enforce the layer and module boundaries fixed in Chapters 3.4 and 3.5". They do that. They were never a claim that nothing else matters, and reading a purpose-built list as exhaustive is what left the gap above.

**`lib/features/` is empty.** This is the last moment at which a strict configuration costs almost nothing. The codebase is 63 Dart files of infrastructure written to a consistent style; adopting `always_specify_types` today cost five annotations. Adopting it after twenty features would be a mechanical rewrite of thousands of lines, which is the point at which a team decides the rule is not worth it. **Strictness is cheap now and expensive later, and it never gets cheaper.**

## Decision

### The rule set is a documented decision, enumerated in one file

`mobile/analysis_options.yaml` is the canonical static-analysis configuration. It enables **176 explicit lint rules** on top of `package:flutter_lints/flutter.yaml`, sets three type-system strictness flags, promotes 25 diagnostics to `error` or `warning`, and records every rule considered and rejected.

Volume 3 §3.7 §2's six rules are all retained: `always_use_package_imports`, `avoid_print`, `avoid_dynamic_calls`, `prefer_const_constructors`, `prefer_final_locals`, `unnecessary_await_in_return`. Nothing in the chapter is weakened. The chapter is treated as the floor it was written to be.

### Every rule carries its reason, in the file

The reason lives in a comment beside the rule, not in this ADR and not in a wiki. A rule whose justification is one file away is a rule that gets deleted the first time it fires inconveniently, because the person deleting it cannot see what it was for.

The file is organised into documented sections — Base rule set, Language, Excludes, Errors, Formatter, then Safety, Type explicitness, Performance, API design, Documentation comments, Style and consistency — and closes with an **Excluded rules** register.

### The type system is tightened, not just linted

Three `analyzer.language` flags matter more than any single lint:

| Flag | What it closes |
|---|---|
| `strict-casts` | An implicit downcast from `dynamic`. `final int id = json['id']` becomes a compile error instead of a production `TypeError`. |
| `strict-inference` | An expression that would silently infer as `dynamic`. |
| `strict-raw-types` | A generic used without type arguments. Bare `List` is `List<dynamic>` while looking entirely ordinary. |

Every network response and every Isar query result enters this codebase as `Map<String, dynamic>`. Without these three, ADR-001's typed layer boundaries are a convention the compiler does not check.

### Severity is promoted by consequence, not by effort

`flutter analyze` fails on any diagnostic, info included, so CI already gates on everything. Promotion exists for the two places where severity is the only signal: the IDE, where an error is red and an info is a grey dot, and `dart analyze --no-fatal-infos`, which a developer may run locally.

Promoted to `error`: anything that ships a defect, leaks data, or leaks a resource — `avoid_print`, `avoid_dynamic_calls`, `cast_nullable_to_non_nullable`, `use_build_context_synchronously`, `unawaited_futures`, `discarded_futures`, `empty_catches`, `only_throw_errors`, `close_sinks`, `cancel_subscriptions`, the always-false comparison rules, and the analyzer's own dead-code diagnostics.

Left at their defaults: every style and consistency rule, however strongly held. `lines_longer_than_80_chars` and `always_specify_types` are enforced but they are not defects, and flattening the distinction would make the severity column meaningless.

Dead code is promoted specifically because `CLAUDE.md` states "do not leave dead code" as a coding standard. `unused_import`, `unused_local_variable`, `unused_element`, `unused_field` and `dead_code` become errors, so the standard is enforced rather than asserted.

### Types are annotated explicitly

`always_specify_types` is adopted. This is the most contested rule in the set and it is chosen deliberately, because it matches what this codebase already does — `final ProviderContainer container = ProviderContainer();`, `List<CollectionSchema<dynamic>>`, `MapEntry<String, dynamic>` — and because of what it buys at a layer boundary.

An omitted type infers from the initialiser. When an upstream return type changes, inferred code still compiles and quietly propagates the new type; annotated code fails at every call site. In an architecture where the boundary *is* the type, that failure is the feature.

The cost is real: annotations are longer to write and sometimes restate the obvious. It also forecloses `omit_local_variable_types` and three related rules permanently, since they are mutually exclusive.

### Generated code is analysed, not excluded

Generated files are committed (Volume 6 §6.2, Volume 3 §3.6 §5) so that a fresh clone builds before anyone runs `build_runner`. They therefore ship, and code that ships is analysed. The `analyzer.exclude` section is empty and says so.

This is workable because `isar_generator` emits its own `ignore_for_file` header covering the rules its output trips. Verified: the committed generated files produce zero issues under this configuration. Exactly one candidate rule had to be dropped for this reason — `cascade_invocations`, which the generator does not suppress — and it is a readability preference, whereas the analyse-what-ships policy is not.

This is the mirror image of the CI **format** check, which does exclude generated files: reformatting them would make them diverge from what the generator produces, failing the `Generated code drift` job. Analysed but not formatted. The asymmetry is intentional and now recorded in both places.

### Suppression is constrained

`document_ignores` requires every `// ignore` comment to state why. `unnecessary_ignore` deletes the ones that no longer suppress anything. Together they stop ignore comments accumulating as the residue of past analysis failures — which is how a strict configuration becomes a decorative one.

### The formatter width is stated, not assumed

`formatter.page_width: 80` restates `dart format`'s default because `lines_longer_than_80_chars` asserts the same number. Two settings that must agree get one visible source; otherwise a future width change moves the formatter and leaves the lint behind, and every reformatted line becomes an analysis failure.

### Scope: one file, in `mobile/`

There is no repository-root `analysis_options.yaml`. `mobile/` is the only Dart package; `backend/` is empty and is Node/TypeScript per ADR-015, and `infrastructure/` is shell and JSON. A root config would govern nothing and would imply a second Dart package exists.

The one planned exception is nested configuration for `public_member_api_docs`, which Volume 3 §3.7 §2 scopes to `domain/` and `data/` only. The analyzer cannot scope a lint to a subdirectory from a parent file, so the rule must be enabled by a nested `analysis_options.yaml` inside each feature's `domain/` and `data/` directory. `lib/features/` is empty, so this is deferred to the first feature; the exact form is documented in `mobile/analysis_options.yaml` and registered as amendment A-025.

## Alternatives Considered

- **Leave the six-rule floor in place.** Rejected. It is not a production configuration, and its cost grows with every file added. The governance instinct behind it — that the set is a decision needing an ADR — is honoured by this ADR rather than by inaction.

- **Adopt `very_good_analysis`, `lint`, or another community meta-package.** Rejected, and this is the closest call. They are well-maintained and would have been faster. But an include is a rule set this project does not control: an upstream minor release can change what CI enforces with no commit here, and the reason for each rule stays in another repository's changelog. `flutter_lints` is accepted as the one exception because Flutter maintains it against each SDK release and its scope is the framework's own API.

- **Enable every available lint and disable what fires.** Rejected outright, and it is the failure mode this ADR exists to prevent. It produces a configuration nobody can defend rule by rule, containing mutually contradictory pairs (`prefer_final_parameters` against `avoid_final_parameters`), and the first inconvenient failure gets an `ignore` comment because there is no recorded reason to prefer the rule.

- **Exclude generated files from analysis.** Rejected. They are committed and they ship. Excluding them hides genuine generator-output errors, and it was unnecessary: the generators suppress their own violations.

- **Weaken rules to accommodate existing code.** Rejected, and not needed. All 22 findings the new configuration surfaced were fixed in the source. Three rules were dropped for the opposite reason — the codebase's convention is deliberately the other way, and the rule was wrong for this project rather than the code being wrong for the rule.

- **`avoid_catches_without_on_clauses`.** Rejected. `core/errors/app_exception.dart` states the invariant that no third-party exception escapes infrastructure, which requires a catch-all at every infrastructure boundary. The rule would force an `ignore` at each one, converting a design invariant into per-site suppression. `avoid_catching_errors` is enabled instead, so catching `Error` — a programming mistake dressed up as a handled condition — remains forbidden.

- **`do_not_use_environment` and `avoid_classes_with_only_static_members`.** Rejected as incompatible with accepted ADRs. The first forbids `String.fromEnvironment`, which ADR-007 and ADR-016 require and ADR-006 requires to be const-evaluable. The second forbids the `abstract final class` static-token shape that ADR-005 and ADR-006 define.

- **A separate `docs/development/code-quality.md` standards document.** Rejected. It would restate the configuration in prose, and the two would diverge — at which point the readable one is wrong and the enforced one is undocumented. The configuration documents itself; this ADR records the decision behind it.

## Consequences

- **The analyzer now blocks classes of defect that were previously invisible**: `dynamic` crossing a layer boundary, an unawaited future, a `BuildContext` used after an `await`, a swallowed exception, an unclosed sink.

- **Any contribution written against the old configuration will fail analysis.** In-flight work needs the fixes applied; there is no grace period, because a configuration with one is not enforced.

- **`always_specify_types` is a permanent commitment.** It forecloses `omit_local_variable_types` and its relatives, and reversing it later means a mechanical rewrite in the other direction. It was adopted at the moment the cost was five annotations.

- **Generated code must stay analysis-clean.** Adding a generator whose output trips an unsuppressed rule becomes a decision, not a detail: request an upstream `ignore_for_file`, or narrowly exclude that one output pattern. A blanket `**/*.g.dart` exclude contradicts this ADR.

- **An SDK upgrade can introduce new diagnostics.** A newly deprecated Flutter API or a new lint that `flutter_lints` adopts can fail CI on a build that touched nothing. This is mitigated but not removed by the pinned toolchain (`FLUTTER_VERSION: 3.44.9`, amendment A-024): the pin makes the failure arrive with a deliberate `build:` commit rather than on Google's release schedule.

- **176 rules is a real reading cost.** The file is long, and it is long on purpose — the comments are the deliverable as much as the rule names. A reader who wants only the list can read the rule names; a reader who wants to change one must read why it is there.

- **Excluded rules are recorded, so exclusions stop being re-litigated.** The register also makes an accidental omission distinguishable from a deliberate one, which is the failure mode a bare rule list cannot avoid.

- **`prefer_const_constructors` and its relatives change frame cost, not just style.** On a device recording video, the frame budget is not spare.

- **`document_ignores` makes every future suppression a small piece of writing.** That friction is the point, and it will occasionally be annoying at exactly the moment someone is in a hurry.

## Related Missions

- Mission 0.18.5 — Lint Configuration, which established the six-rule floor this ADR builds on.
- Mission 0.18.4 — CI, whose `Analyze` and `Format` jobs enforce this configuration, and whose Flutter version pin bounds the SDK-upgrade risk above.
- Mission 0.19.1 — Code Quality Foundation, which produced this ADR and the configuration it records.

## Implementation Status

**Implemented.**

`mobile/analysis_options.yaml` carries the configuration. Verified against Flutter 3.44.9 / Dart 3.12.2 — the version CI pins:

- `flutter analyze` — **no issues found**; zero errors, zero warnings, zero infos across `lib/`, `test/` and every committed generated file.
- 22 findings were surfaced across 17 source files. **18 were fixed in the source.** The remaining 4 were resolved by excluding the rule, each for a reason recorded in the Excluded register — two `avoid_redundant_argument_values` (deliberate restatement of a package default), one `unnecessary_raw_strings` (every `RegExp` pattern is raw by convention), one `avoid_catches_without_on_clauses` (the infrastructure-boundary invariant). No rule was weakened to accommodate existing code, and **no `ignore` comment was added anywhere in the repository.**
- Two further changes followed from the fixes: `lib/app/router.dart` needed an explicit `package:flutter/widgets.dart` import once `BuildContext` was named, and `lib/app/theme/theme_provider.dart` moved from the deprecated `ProviderRef` to `Ref` once the closure parameter was annotated. The second is a latent deprecation the previous configuration could not see, because an unannotated parameter never names the type.
- `dart format --set-exit-if-changed` over all 59 hand-written Dart files — 0 changed.
- `flutter test` — 28 tests passed.
- `dart run build_runner build --delete-conflicting-outputs` followed by `git diff` on `*.g.dart` and `*.freezed.dart` — no drift.
- `flutter build apk --debug` — succeeds.

Severity promotion verified directly rather than assumed: a probe file containing `print()` and an unused local reported both as **errors**, while a missing type annotation reported as **info** — confirming the promotion map is applied and that the style/defect distinction is preserved.

**Correction (Mission 1.5b, 2026-08-13).** The Decision above says the configuration "promotes 25 diagnostics to `error` or `warning`". The real number is **26**: 24 to `error` and 2 to `warning`. Mission 1.5's verification pass counted the `errors:` block directly and found 26 distinct entries, with no duplicate keys.

The two `warning` promotions are `document_ignores` and `unnecessary_ignore`. Both concern ignore comments rather than the code itself, which is why they sit a step below the 24 that mark real defects.

The other two figures in that sentence were re-counted at the same time and are **correct**: 176 explicit lint rules, and three type-system strictness flags (`strict-casts`, `strict-inference`, `strict-raw-types`). Nothing about the configuration changed — only this record's count of it was wrong, and `analysis_options.yaml` has been the authority throughout.
