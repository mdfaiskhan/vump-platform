# ADR-051 — Client-Side Cursor Pagination Stops at the Notifier

- **Status:** Accepted
- **Date:** 2026-08-19
- **Supersedes:** none. Discharges A-184, and settles the client half of a contract Volume 4 Chapter 4.6 §1 fixed in Mission 6.2.

## Context

Chapter 4.6 §1 requires *"cursor-based (`?cursor=…&limit=…`) on every list endpoint"*. The backend built it in Mission 6.2 and produced its first real cursor in Mission 7.3. `pagination.ts` predicted the gap in writing at the time — *"The client does not consume cursors yet … so this side defines the contract and the client inherits it"* — and inheriting it is what had not happened.

A-184 recorded the consequence precisely: an org with 51 Projects rendered 50, *"with no error, no empty state and nothing on either side reporting a truncation"*.

Two things made this a decision rather than a chore.

**`VumpApi` could not read a list endpoint at all.** A list route's `data` is a JSON array; `VumpApi._unwrap` required an object and raised `NETWORK_SERIALIZATION` on anything else. So `GET /v1/projects` would not have truncated, it would have been **refused** on the first call. A-184's "discards `meta`" was the visible half of a client that could not have consumed the rows either.

**Seven things read the two providers**, and only four of them are lists. The other three select a single row out of the list, because Chapter 4.6 §3 has no by-id route for a Project or a Task.

## Decision

**A paginated read returns a page from `data/`. The cursor stops at the notifier. `presentation/` sees a plain list.**

| Layer | Type | Holds the cursor? |
|---|---|---|
| `core/network/` | `ApiPage` — raw rows plus `nextCursor` | passes it through |
| `domain/repositories/` | `PagedResult<T>` | returns it |
| `application/` notifier | `AsyncNotifier<List<T>>` | **yes, privately** |
| `presentation/` | `List<T>` plus a `hasMore` getter | no |

```dart
Future<PagedResult<Project>> fetchProjects({String? cursor, int? limit});
```

### Why the state stays a list

The alternative — `AsyncNotifier<PagedResult<Project>>` — changes the type at every consumer, including the three that do not paginate and the one that only counts. Those consumers do not care where the next page starts; making them name a type that says so is a cost paid by every reader of every screen, forever, to express a fact used in one builder.

`hasMore` is the narrow exception, and it is a **getter rather than state** because it is derived from the cursor and re-read on each rebuild. If a screen ever needs more than that bit, the answer is another narrow getter, not a widened state type.

### `hasMore` reads the cursor, never the item count

`items.length == limit` is the obvious derivation and it is wrong. The backend fetches `limit + 1` rows precisely so a *full* page is not mistaken for a non-final one, discards the extra, and issues a cursor only when it actually saw one. Re-deriving the answer client-side would reintroduce the empty-final-page bug that design exists to avoid, every time a total is an exact multiple of the page size.

### `loadMore` neither enters the loading state nor publishes an error

Both are deliberate and both are about not destroying good data.

`AsyncValue.loading` **replaces the value**, so a list showing 200 rows would blank while the 201st arrived. That is right for a refresh, which is discarding the list anyway, and wrong for an append.

A failed page likewise must not become an `AsyncError`, because that would discard rows the user is reading *because more of them could not be fetched*. `loadMore` returns a `bool` instead, and the control that asked for the page reports the failure — which is why the affordance is an explicit **"Load more" button rather than infinite scroll**. Infinite scroll has nowhere to put the retry, and a list that silently stops growing cannot be told apart from a list that ended.

### The page size is `MAX_LIMIT`, not `DEFAULT_LIMIT`

This is the part that is a correctness requirement rather than a preference.

C-06 Task Detail selects its Task **out of `tasksProvider`**, because Chapter 4.6 §3 has no `GET /v1/tasks/{id}`; C-05 and A-05 do the same for the Project. When the row is absent, C-06 renders *"This Task isn't available to you"* — copy written to mean BR-19, whose *"not assigned"* and *"does not exist"* are deliberately indistinguishable.

At the backend's default of 50, **the 51st Task in a Project would make the app state a false authorization fact**: a Collector told they lack access to their own assigned Task. That is not a truncated list; it is a lie about permissions, produced by pagination.

200 is the backend's ceiling — `parsePageRequest` rejects an out-of-range `limit` rather than clamping it — so it cannot be raised further without changing `MAX_LIMIT`, which was chosen against ADR-044's 1 MiB response ceiling.

## Consequences

**The residual gap is real and is recorded, not closed.** A Project with more than 200 Tasks reproduces the false message exactly. A-201 carries it with an explicit revisit trigger: a real by-id route, *if and when a mission approaches one*. Chapter 4.6's catalog was closed by Mission 7.3, and reopening it now for a case no real org is near would be scope creep into finished territory.

**An aggregate over a paginated list is no longer answerable.** `DashboardSummary.activeProjectCount` counted every Project; it now counts the pages loaded. There is no total in Chapter 4.6 §1's envelope and walking every page to render one tile is unbounded, so the tile was dropped on the precedent the same screen already set for two other FR-PT-01 aggregates. A-200. **Any future dashboard number derived from a list read inherits this problem** and should be checked against it before it is built.

**200 maximal `tasks` rows exceeds ADR-044's ceiling.** `MAX_LIMIT` was justified as *"a generous row is on the order of a few kilobytes"*, and `instructions` is accepted up to 20,000 characters. 50 such rows is already about 1 MiB, so the exposure predates this ADR and is made four times more reachable by it. It fails loudly — a terminated Data API call, not a short list — and A-202 records it against the measurement `pagination.ts` deferred and that still has no real rows to make.

**`PagedResult`, not `Page`.** `Page` is a Flutter type; `package:flutter/material.dart` re-exports the Navigator 2.0 one, and a presentation file importing both does not compile. Found by that collision in a widget test rather than by foresight, and named here so the next paginated feature does not rediscover it.

**Nothing here is feature-specific except where it lives.** `PagedResult` sits in `features/projects_tasks/domain/entities/` because it has one feature's worth of callers. The second paginated feature — sessions, most likely — moves it to `core/`, and this ADR is what says so rather than leaving a second copy to be written.
