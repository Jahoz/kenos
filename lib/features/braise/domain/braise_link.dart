import '../../../core/utils/app_link_origin.dart';

/// LA BRAISE — the passage link's shape (V3.60).
///
/// `https://<origin>/#/pass/<key>.<ballot>` — hash routing, zero
/// server config, same grammar as the salon door. The fragment never
/// reaches a server: the 16-byte hex key knocks at `claim_passage`,
/// the sealed ballot never leaves the traveller's link. A key without
/// a ballot is a naked passage (the identity moves, the souvenirs do
/// not) — tolerated, told honestly.
class BraiseLink {
  BraiseLink._();

  static final RegExp _keyShape = RegExp(r'^[0-9a-f]{32}$');
  static final RegExp _ballotShape = RegExp(r'^[A-Za-z0-9_-]+$');

  /// The full passage URL from the forged key and the sealed ballot.
  static String forge(String keyHex, String packedBallot) {
    final origin = appLinkOrigin();
    return origin.isEmpty
        ? '/#/pass/$keyHex.$packedBallot'
        : '$origin/#/pass/$keyHex.$packedBallot';
  }

  /// Parses a route payload (`<key>` or `<key>.<ballot>`). Anything
  /// that does not wear the ember's shape is a dead link — null, and
  /// the claim screen mourns it like an expired passage.
  static ({String key, String? ballot})? parse(String payload) {
    final dot = payload.indexOf('.');
    final key = dot == -1 ? payload : payload.substring(0, dot);
    final ballot = dot == -1 ? null : payload.substring(dot + 1);
    if (!_keyShape.hasMatch(key)) return null;
    if (ballot != null && !_ballotShape.hasMatch(ballot)) return null;
    return (key: key, ballot: ballot);
  }
}
