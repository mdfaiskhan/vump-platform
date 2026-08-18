import 'package:mobile/core/network/vump_api.dart';

/// A [VumpApi] that answers `POST /auth/verify` and counts the asking.
///
/// **The counting is the point, not a convenience.** Gap 11 — every cold start
/// performing the token exchange twice — shipped and survived a security review
/// because nothing anywhere asserted how many times it happened. A search of
/// `test/` for `auth/verify` returned nothing at all before Mission 7.2. A
/// behaviour no test can even observe is a behaviour that regresses silently,
/// so the double call is now a test failure rather than a log line somebody has
/// to notice. A-177.
///
/// Faked with `implements` plus [noSuchMethod] rather than a mock, per
/// testing-standards.md §8 and A-028 — `mocktail` is not a dependency. Every
/// member this class does not override throws, which is deliberate: a test that
/// reaches an unexpected route fails loudly instead of receiving a null.
class FakeVumpApi implements VumpApi {
  FakeVumpApi({this.orgId = 'org-42', this.role = 'collector'});

  /// The organisation `POST /auth/verify` reports, ADR-048's authoritative
  /// source. Set it empty to exercise the unprovisioned-account rejection.
  final String orgId;

  /// The role the profile route reports. Unused by the exchange, which reads
  /// `role` from the signed claim (Chapter 4.7 §2), and present so
  /// `GET /users/me` can be answered by the same double.
  final String role;

  /// Every path posted to, in order, so a test can assert both how many times
  /// and which.
  final List<String> postedPaths = <String>[];

  /// Every path fetched, in order.
  final List<String> fetchedPaths = <String>[];

  /// How many times the Chapter 4.7 §1 step 2 token exchange was performed.
  int get verifyCallCount =>
      postedPaths.where((String path) => path == '/auth/verify').length;

  @override
  Future<Map<String, Object?>> post(
    String path, {
    required String what,
    Object? body,
  }) async {
    postedPaths.add(path);
    if (path == '/auth/verify') {
      return <String, Object?>{
        'userId': 'user-1',
        'orgId': orgId,
        'role': role,
      };
    }
    return <String, Object?>{};
  }

  @override
  Future<Map<String, Object?>> get(
    String path, {
    required String what,
    Map<String, dynamic>? queryParameters,
  }) async {
    fetchedPaths.add(path);
    return <String, Object?>{
      'userId': 'user-1',
      'orgId': orgId,
      'role': role,
    };
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}
