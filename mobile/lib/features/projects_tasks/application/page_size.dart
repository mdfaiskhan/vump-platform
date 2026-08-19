/// How many rows this feature asks for per page — Mission 7.4, F26.
///
/// ## Why it is the backend's maximum rather than its default
///
/// Three screens select a single row **out of a list**, because Chapter 4.6 §3
/// has no by-id route for either type:
///
/// - **C-06 Task Detail** picks its Task out of `tasksProvider`.
/// - **C-05 and A-05 Project Detail** pick the Project out of
///   `projectsProvider` for the title, and C-05 renders a "not visible to you"
///   branch when it is absent.
///
/// At the backend's `DEFAULT_LIMIT` of 50, a Task that happens to be the 51st
/// in its Project would make C-06 render *"This Task isn't available to you"* —
/// a **false claim about authorization**, written to mean BR-19 and triggered
/// by pagination instead. That is a correctness bug, not a cosmetic one, which
/// is why the page size is raised to `MAX_LIMIT` rather than left at the
/// default with a caveat.
///
/// ## The residual gap, stated rather than closed
///
/// 200 is a bound, not a fix. A Project with more than 200 Tasks reproduces the
/// same false message for the 201st, and 200 is the backend's own ceiling — an
/// out-of-range `?limit=` is rejected rather than clamped, so this cannot be
/// raised further without changing `MAX_LIMIT`. Recorded as A-201 with an
/// explicit revisit trigger: **a real `GET /v1/tasks/{id}`**, if and when a
/// mission actually approaches one. It is not worth opening Chapter 4.6's
/// closed route catalog preemptively for a case no real org is near.
///
/// ## What it costs
///
/// A page of 200 Tasks is the largest response this client asks for, and
/// ADR-044 terminates a Data API call whose response exceeds 1 MiB. `tasks`
/// has no length limit in the table and the backend accepts `instructions` up
/// to 20,000 characters, so 200 maximal rows would be roughly 4 MiB. The same
/// arithmetic already applies at the default — 50 maximal rows is about 1 MiB,
/// which is the ceiling itself — so this raises an existing exposure rather
/// than creating one, and it fails loudly (a terminated call) rather than
/// silently. Recorded as A-202.
library;

/// Rows requested per page, matching the backend's `MAX_LIMIT`.
///
/// The backend rejects a larger value with `REQUEST_INVALID` rather than
/// clamping it, so this constant and `pagination.ts`'s `MAX_LIMIT` must agree.
/// A mismatch is a failed request on every list read, which is loud.
const int projectTaskPageSize = 200;
