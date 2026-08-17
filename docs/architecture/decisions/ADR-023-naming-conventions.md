# ADR-023 — Naming Conventions

- **Status:** Accepted
- **Date:** 2026-08-11
- **Supersedes:** none. Extends `CLAUDE.md`'s four naming standards and ADR-021's mechanical enforcement.

## Context

Naming in this repository is currently governed in three places, and between them they cover perhaps a third of the decisions a developer actually makes.

**`CLAUDE.md` states four rules** — `snake_case` filenames, `PascalCase` classes, `camelCase` variables, one public class per file. They are correct and they are the easy cases. They say nothing about the questions that arise in practice.

**ADR-021 enforces the mechanical layer.** `file_names`, `camel_case_types`, `non_constant_identifier_names`, `constant_identifier_names` and `camel_case_extensions` make the *shape* of a name checkable by `flutter analyze`. But the analyzer cannot tell a `Repository` from a `Service`, cannot object to `SessionManager`, and has no opinion about whether an interface is `SessionRepository` or `ISessionRepository`. Every naming decision that carries architectural meaning is invisible to it.

**Individual ADRs fix individual names** — S3 buckets in ADR-011, environments in ADR-007/014, branches in ADR-019, commit scopes in ADR-020, theme tokens in ADR-005. Each is authoritative for its own domain and none is discoverable from the others.

What is missing is the layer in between: **a closed vocabulary of suffixes.** The codebase has one — 48 types written across eleven missions use `Repository`, `Service`, `Client`, `Config`, `Constants`, `Exception`, `Interceptor`, `Initializer`, `Runner` and `Screen` consistently, and no type anywhere uses `Manager`, `Helper`, `Model` or `Impl`. That consistency is currently an accident of one author's habit. It is recorded nowhere, so the first developer to write `SessionManager` will have broken no rule.

Three specific gaps make this urgent rather than tidy.

**The suffix is what makes ADR-022's import rules readable.** ADR-022 forbids `presentation/` from importing `data/`. A reviewer checks that by reading import lines — which only works if `SessionRepository` reliably means the interface in `domain/` and `SessionRemoteDataSource` reliably means the I/O class in `data/`. If the suffix is a matter of taste, the rule is unreviewable.

**Some names are protocol, not identifiers.** `ErrorCode` values appear in API responses; `StorageKey` values are OS keychain keys; the S3 key schema is immutable. These are load-bearing strings whose format is deliberate — `'NETWORK_TIMEOUT'` upper case, `'access_token'` lower — and the reason for the difference exists in nobody's head but the author's. A future developer "harmonising" them would break stored credentials and published error codes.

**Three conventions have no precedent at all, and the first use will set them.** Migration filenames, the wire JSON field case, and markdown heading case. Migrations and JSON do not exist yet; heading case is genuinely inconsistent across existing documents. Each will be decided by whoever needs one first, and then followed by imitation.

`lib/features/` is empty. Every name the five planned features introduce is still unwritten.

## Decision

### One canonical reference, deriving the standard from the codebase

`docs/architecture/naming-conventions.md` is the canonical naming standard. It covers every category the repository uses — folders, files, types, members, providers, tests, routes, environments, external resources, documentation, commits — with the **convention, the reason, examples, the common mistake, and exceptions** for each, plus a one-page quick reference and an audited register of known deviations.

It is a reference document, not ADR content, following the pattern already established by ADR-019 with `branching-strategy.md`, ADR-020 with `commit-conventions.md` and ADR-022 with `folder-structure.md`.

**The standard is derived, not invented.** Every rule was checked against what the repository already does. Where existing practice was consistent, it was recorded as the rule. Where it was inconsistent, the inconsistency is recorded as a known deviation rather than resolved by a rename. Three rules had no precedent and are genuinely new decisions; they are listed below.

**Nothing already governed is restated.** The reference opens with a table of what is fixed by `CLAUDE.md`, ADR-021, ADR-022, ADR-005, ADR-007, ADR-011, ADR-014, ADR-019, ADR-020 and `docs/architecture/README.md`, and cites rather than duplicates each.

### The suffix vocabulary is closed

The suffix of a type name is a contract about what kind of thing it is. Sixteen suffixes are permitted, each mapped to a meaning and a layer; anything else takes no suffix and is a domain entity.

**Forbidden, explicitly:** `Manager`, `Helper`, `Handler`, `Util`/`Utils`, `Wrapper`, `Processor`, `Model`, `Impl`, an `I` or `Abstract` prefix, `Page`, and a `Widget` suffix.

The rejections are not stylistic. `Manager` means "does something", which is true of every class, and is therefore where responsibilities accumulate — nothing is obviously out of scope for a manager. `Model` is ambiguous across all four of ADR-001's layers, so it defeats the purpose of having a vocabulary. `Impl` and the `I` prefix encode a limitation of languages Dart is not, and `Impl` fails at the first moment it matters: with two implementations, it names neither.

`Page` is forbidden solely for consistency — `HomeScreen` exists, so `Screen` is the word, and mixing the two means guessing per feature.

### Interfaces take the role, implementations take the mechanism

`SecureStorageRepository` is the contract; `SecureStorageService` is the class that talks to the keychain. This is what the codebase already does, and it is recorded because the alternative is the default instinct. It means a second implementation is `SecureStorageInMemoryService` — a name that says which one it is — rather than a numbered `Impl`.

### Three new conventions, where no precedent existed

**Migration files:** `migration_v<from>_to_v<to>.dart` containing `class MigrationV<From>ToV<To>`. Chosen because `Migration` already declares `from` and `to` (ADR-009) and `MigrationRunner` orders by them, so the filename states exactly the two facts that determine execution order. A date prefix was rejected — the schema version is the ordering key, not wall-clock time, and two developers can date-collide. A single-version name (`migration_v2.dart`) was rejected as ambiguous about which end 2 is.

**Wire JSON fields: `camelCase`.** Two of the three surfaces are already `camelCase`-native — TypeScript on the backend (ADR-015) and Dart on the client — while Aurora is `snake_case`, so exactly one rename is unavoidable. Putting it in the backend, in one typed layer, is cheaper and safer than a `@JsonKey` on every field of every Dart DTO, where each omission is a silent null rather than a compile error. `infrastructure/aws/config/environments.json` already uses `camelCase`, so this matches the only JSON the repository has.

**Markdown headings: sentence case.** The majority of the repository's prose documents already use it, and it removes the per-heading judgement about whether a short word takes a capital. Two exceptions are recorded: ADR section headings are template slots fixed verbatim by `docs/architecture/README.md` (including the Title Case `Alternatives Considered`), and pre-existing Title Case documents are not rewritten by this mission.

### Protocol strings are separated from identifiers

Where an enum carries a string across a boundary, the string lives in a `final String` field and never derives from the member name. `ErrorCode` uses `SCREAMING_SNAKE_CASE` because its values appear in logs and API responses beside prose, where upper case marks them unmistakably as identifiers and makes them greppable. `StorageKey` uses `snake_case` because its values are OS keychain and `SharedPreferences` keys, where that is the platform convention.

The difference is deliberate and is recorded so that nobody harmonises it. Deriving a wire value from a member name via `name` or `toString()` is forbidden for the same reason: it turns every future rename into a silent protocol change.

### Deviations are recorded, not renamed

Four deviations were found by audit and none is fixed here, because this mission does not rename existing code and none violates an accepted ADR:

- **`docs/Teams_work.txt`** — the only filename violating the documentation rule. Renaming it is a judgement about its contents and audience, not about naming.
- **Title Case headings** in `docs/architecture/README.md` and `docs/git/*.md` — normalised when next edited for another reason.
- **Theme token pluralisation** — `AppColors` and `AppSizes` are plural, `AppRadius` and `AppDuration` singular, though each holds a set. **Not renamed:** ADR-005 names these classes and files, so changing them needs a superseding ADR for zero behavioural gain. New token classes take the plural.
- **`secureStorageProvider`** — names neither its interface nor its implementation, and is **correct**: it is used in the reference as the worked example of why a provider names its subject rather than its type.

## Alternatives Considered

- **Rely on `CLAUDE.md` and the lint rules.** Rejected. Together they cover casing and nothing else. They cannot distinguish a `Repository` from a `Service`, and it is precisely those distinctions that make ADR-001's layers and ADR-022's import rules reviewable.

- **Adopt an external style guide — Effective Dart alone, or a published Flutter convention.** Rejected as insufficient rather than wrong. `CLAUDE.md` already requires Effective Dart and this document does not contradict it. But Effective Dart stops at the language: it has no position on `UseCase` versus `Service`, on whether a DTO may leave `data/`, or on how a migration file is named. The gap this ADR fills is project-specific by definition.

- **Extend `CLAUDE.md` instead of writing an ADR and a reference.** Rejected. `CLAUDE.md` is the constitution: it states standards, not their justification, and a naming rule without its reason is discarded the first time it is inconvenient — which for naming is the moment someone has already written the code. It is also not the place for an audited deviation register.

- **Amend ADR-021 to add the naming rules.** Rejected, and not permitted. `docs/architecture/README.md` forbids editing an accepted ADR to add or reinterpret a constraint. ADR-021 also governs a different thing: it configures a tool, and none of these rules is machine-checkable.

- **Rename the deviations found by audit as part of this mission.** Rejected. The theme token names are fixed by ADR-005, so renaming them requires a superseding ADR — a large diff, a rewritten accepted decision, and no behavioural change. The mission was explicit that existing code is renamed only where an accepted ADR requires it, and no accepted ADR requires any of these.

- **Permit both Title Case and sentence case headings**, since the repository uses both. Rejected. A standard that permits both is not a standard, and heading case is the one convention where a coin-flip per document produces visible inconsistency in a table of contents.

- **`snake_case` on the wire JSON**, matching Aurora and the S3 key placeholders. Rejected. It would place a rename on both the TypeScript and the Dart side rather than one, and the Dart side is where it is most dangerous — a missing `@JsonKey` is a silent null, not a compile error.

- **Defer to the first feature mission.** Rejected. That mission is the worst placed to decide: it would be choosing the suffix vocabulary while writing the code that depends on it, and every subsequent feature would imitate whatever it happened to do.

## Consequences

- **A reviewer can check ADR-022's import rules by reading import lines**, because the suffix now reliably indicates the layer and the kind.

- **None of this is machine-checked, and most of it cannot be.** `flutter analyze` enforces casing (ADR-021) and nothing about the vocabulary — no analyzer can tell whether a class named `SessionService` should have been `SessionRepository`. A forbidden-suffix grep over `lib/` is feasible and would catch `Manager`, `Helper` and `Impl`; the judgement cases stay human. This is a documented convention enforced at review, and it is honest to say so: it will drift unless reviewers use it.

- **The vocabulary is closed, so an unlisted suffix is a decision, not a choice.** A future kind of thing that genuinely needs a seventeenth suffix means amending this ADR. That friction is deliberate — an open vocabulary is not a vocabulary.

- **Four deviations remain in the repository**, recorded with their dispositions. Anyone auditing naming will find them and can tell they were seen rather than missed. Two carry a small ongoing cost: the Title Case documents read differently from the rest, and the theme token pluralisation is inconsistent and permanent.

- **The wire JSON decision constrains the backend before it exists.** The first backend mission inherits the obligation to map `camelCase` to Aurora's `snake_case`, in one place. That is a real constraint recorded ahead of the code, which is the point, but it was decided without the backend author in the room.

- **The migration filename convention assumes single-digit schema versions** for directory sort order. At version 10 the lexical sort breaks (`v10` before `v2`). Not worth zero-padding now for a database with one collection and no migrations; worth remembering.

- **`Page` is forbidden**, which will feel arbitrary to anyone arriving from a codebase that uses it. The reason is consistency with `HomeScreen`, and it is recorded so the answer is available without an argument.

## Related Missions

- Mission 0.19.1 — Static analysis configuration (ADR-021), which enforces the mechanical half of this standard.
- Mission 0.19.2 — Folder architecture (ADR-022), whose import rules depend on the suffix vocabulary being reliable.
- Mission 0.19.3 — Naming Conventions, which produced this ADR and the reference document.

## Implementation Status

**Documented. Enforced mechanically in part, by review otherwise.**

`docs/architecture/naming-conventions.md` carries the standard. Every claim in it was verified by audit over every tracked file rather than asserted:

| Audited | Count | Result |
|---|---|---|
| Dart filenames (`lib/` + `test/`) | 59 | All `snake_case` |
| Declared types outside `*.g.dart` | 48 | All `PascalCase`; no forbidden suffix anywhere |
| Riverpod providers | 13 | All `camelCase` ending `Provider` |
| `ErrorCode` values | 28 | All `SCREAMING_SNAKE_CASE` |
| `StorageKey` values | 5 | All `snake_case` |
| Test files | 4 | All `<subject>_test.dart` at mirrored paths |
| Infrastructure files | 18 | All `kebab-case`, environment slug last |
| ADR files | 23 | All match `ADR-NNN-kebab-case-title.md` |

`flutter analyze` reports no issues. No code was renamed, moved or created; the four deviations found are recorded in the reference, §11.

One initial count in the draft was wrong — 30 declared types, against 48 actual — and was corrected by re-running the audit rather than left as a plausible figure.
