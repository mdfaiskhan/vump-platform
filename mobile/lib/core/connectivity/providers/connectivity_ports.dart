/// The seam where Chapter 5.12's ConnectivityService is introduced.
///
/// Unimplemented rather than defaulted, for the reason every other port in
/// this project follows: a default would have to name a concrete class living
/// in a feature's `data/`, which `core/` may not import at all (invariant
/// I41). Failing loudly at the override point beats a silent default that
/// would present as "the device is permanently offline".
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mobile/core/connectivity/interfaces/connectivity_source.dart';

/// Where Chapter 5.12 §2's online/offline signal comes from.
///
/// Overridden in `main.dart` to `ConnectivityPlusConnectivitySource`, which
/// shares one `Connectivity` instance with the checklist's
/// `ConnectivityPlusNetworkReader` — §2's *"neither polls it independently"*,
/// held at the plugin channel. See ADR-040 and A-081.
final Provider<ConnectivitySource> connectivitySourceProvider =
    Provider<ConnectivitySource>(
      (Ref ref) => throw UnimplementedError(
        'connectivitySourceProvider must be overridden with a '
        'ConnectivitySource. features/recording/data/ provides '
        'ConnectivityPlusConnectivitySource, which implements it. '
        'See ADR-040 and A-081.',
      ),
    );
