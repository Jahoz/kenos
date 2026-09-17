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

  /// V3.51 — the artifact guard: the reported public artifacts,
  /// metadata only (never a text). The guardian reads the poems
  /// themselves in the public sky, at the seed coordinate each row
  /// carries.
  Future<List<ConstellationReportSummary>> fetchConstellationReports();

  /// V3.51 — sends an artifact back to the void: lines and reports
  /// leave with it (cascade), exactly as the 30-day reaper would take
  /// a moon-old poem. The guardian's only moderation gesture — never
  /// automatic, never a threshold.
  Future<void> retractConstellation(String constellationId);

  /// V3.57 — the Shard Sower module: shards awaiting the guardian's
  /// taste (newest first), the lever that publishes or discards them,
  /// the library the sky serves, its retire/restore lever, and the
  /// sowing pass (the AI's two passes live server-side; the survivors
  /// land as proposals for the human gate).
  Future<List<VestigeProposal>> fetchVestigeProposals();

  /// True when the proposal existed and was decided. Publishing moves
  /// the shard into the library (nothing is public before this).
  Future<bool> decideVestigeProposal(String proposalId, bool approve);

  Future<List<VestigeLibraryEntry>> fetchVestigeLibrary();

  Future<void> setVestigeLive(String id, bool live);

  Future<SowResult> sowVestiges({int count = 6, required String theme});
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
