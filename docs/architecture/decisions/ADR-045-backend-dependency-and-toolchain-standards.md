# ADR-045 — Backend Dependency and Toolchain Standards

- **Status:** Accepted
- **Date:** 2026-08-18
- **Supersedes:** none. Fills the gap ADR-030 and ADR-021 each name and each decline to fill.

## Context

Two accepted records hand this off explicitly, in almost the same words.

**ADR-030 — Dependency Management** governs `mobile/` and says so: *"the backend has no dependency tree because `backend/` is empty (ADR-015). When it exists it is a **separate tree with separate rules** — npm, its own lockfile, its own audit — and this standard governs `mobile/`."*

**ADR-021 — Static Analysis** governs `mobile/analysis_options.yaml` and says the same: *"There is no repository-root `analysis_options.yaml`. `mobile/` is the only Dart package; `backend/` is empty and is Node/TypeScript per ADR-015 … A root config would govern nothing."*

Mission 6.2 made `backend/` non-empty. The condition both records named has been met, and neither is being amended — this is the separate standard they each pointed at.

There is also a **toolchain** half that neither anticipated: a Node version, a Lambda runtime, a bundler and a test runner, none of which has an owner.

## Decision

### Package manager: npm, with workspaces

npm, not pnpm or yarn. Not on merit — all three would work — but because this repository already uses npm, in `functions/`, with a committed `package-lock.json`. Introducing a second package manager for the second Node package would mean two lockfile formats and two install commands in one repository, to gain nothing measurable.

**npm workspaces**, with one root `package.json` at `backend/`, a shared package at `backend/packages/shared/`, and one package per function at `backend/functions/<name>/`.

The layout is decided by Volume 4, Chapter 4.7 §1 step 3 rather than by preference: *"Each Lambda function verifies the token using the Firebase Admin SDK before touching any data."* Every function needs the same token-verification path, and §4's pseudocode is middleware. **Seven copies of a token-verification path is the worst thing in this codebase to duplicate** — drift between them is a security defect, not a maintenance annoyance. A package per function with no shared code would require exactly that duplication.

### Lockfile: `package-lock.json`, committed; `npm ci` in CI

Identical to ADR-030's reasoning for `pubspec.lock`, and for the same reason: the lockfile is what makes an install reproducible.

### Version constraints: caret

Caret constraints (`^`) for every dependency, matching ADR-030's rejection of exact pins: *"exact pins would make every transitive security patch a manual edit, and `pubspec.lock` already provides build reproducibility, which is what an exact pin is usually reached for."*

**Two exceptions, both pinned exactly** because they are not libraries but environment:

- **Node** — `engines: { node: ">=24 <25" }`, and the Lambda runtime `nodejs24.x`.
- **Toolchain versions in CI** — `TERRAFORM_VERSION` and `TFLINT_VERSION` are already pinned in `ci.yml` for this reason.

### Node version: 24, and the reasoning is a deprecation date

Checked against what Lambda supports rather than defaulted to either available precedent:

| Runtime | Status | Deprecation |
|---|---|---|
| `nodejs20.x` | **Deprecated** | 2026-04-30 — already past |
| `nodejs22.x` | Supported | **2027-04-30** |
| `nodejs24.x` | Supported | 2028-04-30 |
| `nodejs26.x` | **Public preview** | AWS: *"should not be used for production workloads"* |

`functions/` pins Node 22, and following that precedent would have put a new backend on a runtime with roughly eight months of support. 24 is the only generally-available runtime with a horizon worth building on. Recorded as amendment A-151.

### Audit: `npm audit`, gating CI

Volume 8, Chapter 8.3 §4 names the tool directly: *"an automated vulnerability scan (npm audit or an equivalent SCA tool) gating CI"*, and *"Any dependency with a published critical CVE blocks deployment until patched or explicitly risk-accepted by the project owner."*

`npm audit --audit-level=high` runs as `npm run audit` and **gates the `Backend` CI job**. The threshold is stricter than the chapter's: V8.3 §4 blocks on *critical*, and this fails on *high*, because a high-severity advisory is worth failing on while the tree is small enough to fix it.

This is the one place the backend is better off than `mobile/`: ADR-030 records that `dart pub audit` *"does not exist as a subcommand in this SDK"*, so `mobile/` has no equivalent.

### Static analysis: ESLint with type-aware rules, plus Prettier

`typescript-eslint`'s `strictTypeChecked` and `stylisticTypeChecked`, with four rules promoted or scoped.

Type-aware rather than syntactic, because the non-type-aware set cannot see an unawaited promise or an `any` crossing a module boundary — which is most of what matters in a handler that awaits I/O.

The posture is ADR-021's, applied at the same moment in the same way: *"strictness is cheap now and expensive later, and it never gets cheaper."* ADR-021 adopted 176 rules while `lib/features/` was empty; this adopts a strict preset while `backend/` is seven stub handlers.

**TypeScript itself is configured strictly** — `strict`, plus `noUncheckedIndexedAccess`, `exactOptionalPropertyTypes`, `noImplicitOverride`, `noImplicitReturns`, `noUnusedLocals`, `noUnusedParameters`, `verbatimModuleSyntax`.

### Bundler: esbuild, one tree-shaken bundle per function

ADR-015 counts modular bundling as a benefit of SDK v3: *"each function bundles only the clients it uses — which keeps cold-start cost proportional to what a function actually does."* A workspace with shared code only preserves that if the bundler drops what each entry point does not reach.

**Verified rather than assumed:** `RDSDataClient` is absent from the `auth-verify` bundle, because that function's routes never reach `data-api.ts`. Tree-shaking works across the workspace boundary.

**What it does not solve, stated plainly:** every bundle is ~1.6 MiB, and the bulk is `firebase-admin`. That is not the layout's doing — it follows from Chapter 4.7 §1 step 3 requiring every function to verify tokens. A package-per-function layout would produce the same seven copies of the same library. Recorded as amendment A-152.

### Test framework: Vitest

Vitest, not Jest. Natively TypeScript and ESM, no transform step, and fast.

The risk in choosing it was `aws-sdk-client-mock`, which is Jest-shaped by reputation and is how a Data API test will be written in 6.3. **Tested before committing**, against Vitest 4.1.10 and `aws-sdk-client-mock` 4.1.0: stubbing a command, inspecting recorded calls, rejecting, and `reset()` between tests all work. Recorded as amendment A-149.

### Coverage: measured, not gated — and deliberately not Volume 9's numbers

Coverage is reported by `vitest run --coverage` and **no threshold is enforced**.

Volume 9, Chapter 9.5 §2's targets — `domain` 90%+, `data` 80%+ — are expressed against the four-layer feature structure ADR-001 gives the Flutter app. **A Lambda handler has no `domain/` or `data/` layer**, so those numbers have nothing to attach to here, and inventing a single backend percentage to look like compliance would be a gate nobody chose.

What is adopted is Volume 9's *intent*: a thing is not "verified" until it is meaningfully tested. Concretely, for this backend:

- **The token path is tested for ordering, not just outcome** — that verification happens *before* the domain handler runs, which is Chapter 4.7 §1 step 3's actual requirement.
- **Error mapping is tested for what it does not leak**, not only for what it returns.
- **The route inventory is asserted against Chapter 4.6's catalogue**, so the scaffold cannot drift from the specification it implements.

A numeric gate becomes reasonable when 6.3 gives the handlers real behaviour to cover. It is not set now because it would be met by the tests that already exist and would prove nothing.

## Alternatives Considered

- **One npm package per function, no shared package** — rejected, and it is the serious alternative. It gives the tightest possible bundles and per-function dependency isolation. It requires either duplicating the token-verification middleware seven times or publishing it to a registry, and the first is a security risk while the second is heavy machinery for one consumer.
- **pnpm** — rejected. Better at workspaces and disk use; it would be the second package manager in this repository, and `functions/` already establishes npm.
- **Jest** — rejected, narrowly. Larger ecosystem and the assumed default for `aws-sdk-client-mock`. Rejected on the transform step for TypeScript ESM, after confirming the compatibility concern was not real.
- **Node 22, following `functions/`** — rejected on the deprecation date above.
- **Node 26** — rejected. AWS documents preview runtimes as *"not covered by the Lambda SLA or Technical Support"*.
- **A backend coverage threshold now** — rejected as theatre, per the reasoning above.
- **Adopting Volume 9's Dart percentages verbatim** — rejected. They describe a structure the backend does not have.
- **`npm audit` as a CI gate in this mission** — deferred, not rejected. V8.3 §4 requires it; the backend has no CI job yet, and adding one is its own piece of work.

## Consequences

- `backend/` has a toolchain: `npm run verify` runs format, lint, typecheck and tests in one command.
- **A third language and a third dependency tree.** `mobile/` (pub), `functions/` (npm, retiring per ADR-036), `backend/` (npm). Two of the three are npm and neither shares a lockfile with the other.
- The bundles are ~1.6 MiB each and cold-start cost is dominated by `firebase-admin`, not by anything this project wrote. If cold starts become a measured problem, the lever is Chapter 4.7's every-function verification requirement, not the layout.
- **V8.3 §4 is met.** `npm audit` gates CI at `high`, one level stricter than the chapter's critical floor. Six moderate advisories currently sit below that line, all transitive through `firebase-admin`; they are visible and do not block.
- ADR-020 rejected commitlint because it *"would mean a Node toolchain and a lockfile at the root of a Flutter repository"* and said *"Revisit when `backend/` exists."* It exists. The condition is met; the revisit is not this mission's.
- Node 24 will need revisiting before 2028-04-30. **Four** files restate the major — `engines`, the esbuild target, the Terraform `runtime` variable and `BACKEND_NODE_VERSION` — and `Environment consistency` now fails if they disagree, so the upgrade is a four-file change that CI enforces rather than a four-file change someone has to remember.

## Related Missions

- Mission 6.2 — Lambda and API Gateway scaffold, which created `backend/` and needed this.

## Implementation Status

**Implemented.**

| | Decision | State |
|---|---|---|
| npm workspaces | Root + shared + 7 functions | ✅ 9 packages |
| `package-lock.json` committed | Required | ✅ |
| Caret constraints | Required | ✅ |
| Node 24 / `nodejs24.x` | Required | ✅ `engines`, esbuild target, Terraform `runtime` |
| ESLint type-aware | Required | ✅ 0 problems |
| Prettier | Required | ✅ clean |
| `tsc --build` strict | Required | ✅ clean |
| Vitest | Required | ✅ 49 tests, 8 files |
| esbuild per-function bundles | Required | ✅ 7 bundles, tree-shaking verified |
| `npm audit` script | Required | ✅ available |
| `npm audit` in CI | V8.3 §4 | ✅ Gates the `Backend` job, at `high` |
| Backend CI job | lint, type-check, test, audit, build | ✅ Twelfth job |
| Node major checked across its four sites | A-151's named risk | ✅ `Environment consistency`, proven non-vacuous |
| Coverage gate | Deliberately absent | ⬜ Revisit at 6.3 |
