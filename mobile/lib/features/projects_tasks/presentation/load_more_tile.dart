import 'package:flutter/material.dart';

import 'package:mobile/app/theme/app_spacing.dart';

/// The last row of a paginated list — Mission 7.4, F20.
///
/// ## Why a button and not infinite scroll
///
/// No chapter specifies either. Volume 2 describes C-04 and C-05 as lists and
/// says nothing about how a second page is reached, so this is a judgement, and
/// it is recorded rather than absorbed: an explicit control **states that more
/// exists**, which is the fact A-184 says nothing on either side was reporting.
/// Infinite scroll hides it — the list simply grows, and a Collector who
/// reaches the bottom on a bad connection sees a list that has stopped, with no
/// way to tell whether it stopped because it ended or because a fetch failed.
///
/// It is also the honest shape for what `loadMore` actually does. That method
/// deliberately neither enters the loading state nor publishes an error, so the
/// only place a failure can be reported is the control that asked for it —
/// which requires there to be one.
///
/// ## The failure is local and stays local
///
/// A failed page turns this tile into a retry, and touches nothing else. The
/// rows already rendered are still valid data, and Chapter 2.9 §2's
/// named-cause rule is satisfied at the row that failed rather than by
/// replacing a good list with a full-screen error.
class LoadMoreTile extends StatefulWidget {
  /// Creates the tile, calling [onLoad] when tapped.
  ///
  /// [onLoad] returns true when a page was appended, matching
  /// `ProjectsNotifier.loadMore` and `TasksNotifier.loadMore`.
  const LoadMoreTile({required this.onLoad, required this.label, super.key});

  /// Appends the next page. True when one arrived.
  final Future<bool> Function() onLoad;

  /// What is being loaded, for the button and for the failure message.
  ///
  /// Named rather than generic because Chapter 2.9 §2 forbids a failure that
  /// does not say what failed.
  final String label;

  @override
  State<LoadMoreTile> createState() => _LoadMoreTileState();
}

class _LoadMoreTileState extends State<LoadMoreTile> {
  bool _loading = false;
  bool _failed = false;

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });

    final bool loaded = await widget.onLoad();

    // The tile can leave the tree while the page is in flight — a pull to
    // refresh rebuilds the list without it.
    if (!mounted) {
      return;
    }
    setState(() {
      _loading = false;
      _failed = !loaded;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Column(
        children: <Widget>[
          if (_failed) ...<Widget>[
            Text(
              'More ${widget.label} could not be loaded. '
              'Check your connection.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          OutlinedButton(
            onPressed: _load,
            child: Text(_failed ? 'Try again' : 'Load more'),
          ),
        ],
      ),
    );
  }
}
