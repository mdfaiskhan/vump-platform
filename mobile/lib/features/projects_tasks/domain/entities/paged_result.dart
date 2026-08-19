/// One page of a list read, and where the next one starts.
///
/// ## Why the repository returns this and the notifier does not
///
/// A-184 recorded that `fetchProjects()` returning `List<Project>` *"sees page
/// one and stops"*, with nothing on either side reporting the truncation. The
/// port has to be able to say *"and there is more"*, so it returns this.
///
/// **The notifier still exposes `List<Project>`.** Mission 7.4's F25 ruling:
/// the cursor is held privately by the notifier and the accumulated items stay
/// the state, so none of the seven consumers of `projectsProvider` and
/// `tasksProvider` changes type. Pagination is a property of the *read*, not of
/// what a screen renders.
///
/// ## `nextCursor` is opaque and must stay that way
///
/// `cursor.ts` says so outright: it is base64 of a JSON pair, *"and callers are
/// told nothing about the contents"*, because opacity is what lets the backend
/// change its sort key without a `/v2`. Nothing here parses it, compares it, or
/// derives anything from it — it is carried back to the backend unchanged or it
/// is null.
library;

/// A page of [T] with the cursor that follows it.
///
/// **Named `PagedResult` rather than `Page`** because `Page` is a Flutter type
/// — `package:flutter/material.dart` re-exports the Navigator 2.0 one — and a
/// presentation file importing both would not compile. Found by that exact
/// collision in a widget test, not by foresight.
class PagedResult<T> {
  /// Creates a page.
  const PagedResult({required this.items, this.nextCursor});

  /// A last page, or the only one.
  const PagedResult.last(this.items) : nextCursor = null;

  /// The rows on this page, in the order the backend supplied.
  final List<T> items;

  /// The opaque cursor for the following page, or null when this is the last.
  final String? nextCursor;

  /// Whether a further page exists.
  ///
  /// Reads `nextCursor != null` rather than `items.length == limit`. The
  /// backend fetches one row more than asked for precisely so that a full page
  /// is not mistaken for a non-final one — `pageMeta` discards the extra and
  /// returns a cursor only when it actually saw it. Re-deriving the answer from
  /// the length here would reintroduce the empty-final-page bug that design
  /// avoids.
  bool get hasMore => nextCursor != null;
}
