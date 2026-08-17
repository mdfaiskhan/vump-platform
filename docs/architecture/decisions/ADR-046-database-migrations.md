# ADR-046 — Database Migrations

- **Status:** Accepted
- **Date:** 2026-08-18
- **Supersedes:** none. Fills the gap Volume 4, Chapter 4.4 §9 defers to implementation.

## Context

Volume 4, Chapter 4.4 §9 hands migrations to implementation explicitly: *"Index definitions, exact CHECK constraint SQL, and **migration ordering** are Volume 6/7 implementation detail — this chapter fixes the schema's shape and meaning, not its migration scripts."*

Nothing since has picked a tool. Mission 6.3 needed one to create nine tables, three functions, two triggers and seven database roles against a live cluster.

## Decision

**Numbered `.sql` files in `backend/migrations/`, applied by a TypeScript runner over the RDS Data API.**

The choice is narrower than it looks, and ADR-044 is what narrows it.

### The conventional tools cannot reach this database

`node-pg-migrate` speaks the PostgreSQL wire protocol over TCP through `pg`. Flyway speaks JDBC. **Neither can use the Data API**, so both need network reachability to the cluster — and Mission 6.1's network, verified live, has no internet gateway, no NAT gateway, and an Aurora security group with **zero ingress rules**.

Adopting either would mean provisioning a network path ADR-044 deliberately does not have, or running migrations from a VPC-attached context that does not exist. Both are larger changes than the migration problem itself.

### What the Data API imposes, measured rather than assumed

Three constraints, each verified against the live cluster before the runner was written:

1. **One statement per call.** `SELECT 1; SELECT 2` returns `ValidationException: Multistatements aren't supported`. Files are split by a lexer that understands dollar-quoted bodies — without it, `0006_integrity_rules.sql`'s PL/pgSQL functions shatter into fragments at every internal semicolon.
2. **DDL is transactional and rolls back cleanly.** Verified by creating a table, a role and a grant inside one transaction, rolling back, and confirming none survived. So a migration can be atomic, and a half-applied migration is impossible.
3. **The cluster may be asleep.** `min_capacity = 0` means the first call after an idle period fails with `DatabaseResumingException`. Handled by `@vump/shared`'s retry (A-156), shared with the handlers rather than special-cased.

### Shape

- **One transaction per migration.** Every statement plus the tracking-table row commit together, so the ledger cannot disagree with the schema.
- **A checksum per migration.** An applied migration whose file has changed is a hard error, not a re-run: an edited migration means the database and the repository describe different schemas, and appending a new migration is the only correct response. Same principle as ADR-019's commit history — history is appended to, not rewritten.
- **Numbered `NNNN_lower_snake_case.sql`.** Ordering is the only thing that decides what runs first, so a name that does not sort is rejected by the loader.
- **Run deliberately, never by CI.** The same rule `folder-structure.md` §1.3 applies to `terraform apply`: a pipeline that can migrate a database is a pipeline that can drop one.

### Terraform does not own the schema

Uncontested, and confirmed rather than assumed: ADR-043 scopes Terraform to AWS resources and `folder-structure.md` §1.3 makes `infrastructure/` *"declared AWS state"*. A schema is data-tier state with its own lifecycle. Two consequences make the separation worth stating: a `terraform destroy` must never be able to drop tables, and a schema change must not require an infrastructure apply.

The one seam is the credential secrets — Terraform creates the empty containers, the bootstrap command fills them. That split exists so no password reaches Terraform state.

## Alternatives Considered

- **`node-pg-migrate`** — rejected. TypeScript-native and the closest fit on paper; cannot reach the cluster.
- **Flyway** — rejected. Same reachability problem, plus a JVM in a repository that is Dart, TypeScript and HCL.
- **Opening a network path so a conventional tool works** — rejected. It would undo ADR-044's central property to gain a tool, and the migration problem is smaller than the network change.
- **Terraform owning the schema** — rejected on lifecycle grounds above.
- **One statement per file** — rejected. It would turn nine tables into forty files and put the ordering burden on filenames rather than on a splitter.
- **`sql.split(';')`** — rejected, and it is the trap worth naming: it works on every migration here except the one that matters, and fails by producing SQL fragments rather than by erroring.
- **No tracking table, applying everything every time** — rejected. Most DDL is not idempotent, and `CREATE TABLE` twice is an error rather than a no-op.

## Consequences

- Migrations run from a developer's machine with the master credential. There is no CI path and no automated deployment, which is deliberate and also means **nothing prevents a developer forgetting to run them**.
- **The runner is a fourth thing that must agree with the schema.** A-153 already records that nothing compares the Terraform routes with the handler route tables; table and column names now live in `.sql` and in the TypeScript that will query them, with nothing checking the pair.
- The checksum guard means a typo in an applied migration cannot be fixed in place. That is the intended cost.
- Rollback is not implemented. Every migration is forward-only; undoing one means writing another. Adding `down` migrations would double the surface for a project that has never rolled a schema back, and the honest position is that this is untested rather than unnecessary.
- `@vump/migrate` is a fourth workspace package and pulls in `@aws-sdk/client-rds` and `@aws-sdk/client-secrets-manager`, neither of which any Lambda bundles.

## Related Missions

- Mission 6.3 — Aurora schema and migrations, which needed this and produced it.

## Implementation Status

**Implemented and applied to development.**

| | Decision | State |
|---|---|---|
| Numbered `.sql` files | Required | ✅ 8 migrations |
| Dollar-quote-aware splitter | Required | ✅ 16 tests |
| One transaction per migration | Required | ✅ |
| Checksum guard | Required | ✅ |
| Resume retry | A-156 | ✅ Exercised live on the first apply |
| Applied to dev | — | ✅ 8/8, re-run skips all 8 |
| Applied to staging/prod | — | ⬜ Neither environment exists |
| `down` migrations | Deliberately absent | ❌ Forward-only |
| CI runs migrations | Deliberately absent | ❌ By design |
