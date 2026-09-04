import '../domain/admin_metrics.dart';

/// Guardian access to the Observatory (V3.16).
///
/// Contract shared by the Supabase path and the demo path: sign in,
/// sign out, read the contentless aggregates. The credentials belong
/// to the ONE guardian account (see supabase/snippets/create_guardian.sql);
/// sessions live in memory only — nothing persists on the device.
abstract class AdminRepository {
  /// True while a guardian session is held in memory.
  bool get isSignedIn;

  /// Throws [GuardianAuthException] on refused credentials.
  Future<void> signIn(String email, String password);

  /// Closes the session (the anonymous celestial session, if any, is
  /// a different client and is never touched).
  Future<void> signOut();

  /// Throws [GuardianForbiddenException] if the session lost its rank.
  Future<AdminMetrics> fetchMetrics({int days = 30});
}

/// The threshold refused these words (bad credentials or network).
class GuardianAuthException implements Exception {
  GuardianAuthException([this.message = 'invalid_credentials']);
  final String message;
}

/// Signed in, but the server does not see a guardian in the JWT —
/// the claim is missing or was revoked.
class GuardianForbiddenException implements Exception {
  GuardianForbiddenException([this.message = 'forbidden']);
  final String message;
}
