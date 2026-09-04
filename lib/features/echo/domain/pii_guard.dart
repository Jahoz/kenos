/// The PII guard — the author's last quiet look before the seal.
///
/// The Trace Shield (V3.15) can only read the trace: the one clear
/// content the ether ever sees. A thought in the Mirror is sealed
/// AES-256-GCM on the device BEFORE it leaves — the ether is
/// structurally blind to it, so no server-side moderation can warn
/// the author. The only honest place left is here: on the device, in
/// clear, before sealing. Pure regex, zero network — the plaintext
/// never leaves the app any earlier than it otherwise would.
///
/// Same contract as the shield: WARN, never block. Anonymity is the
/// contract; choosing belongs to the author. Over-matching is the
/// safe direction (the warning is a question, not a gate).
class PiiGuard {
  const PiiGuard._();

  /// French numbers: 0683077484, 06 83 07 74 84, +33683077484,
  /// 0033 6 83 07 74 84, 06.83.07.74.84 — ten digits, separators
  /// free, mobile or landline.
  static final RegExp _phoneFr = RegExp(
    r'(?:\+33|0033|0)\s*[1-9](?:[\s.\-]*\d{2}){4}',
  );

  /// Other international numbers: a leading + and at least eight
  /// digits, separators free — "+1 (415) 555 2671" hits, "+100 %"
  /// does not.
  static final RegExp _phoneIntl = RegExp(r'\+(?:[\s().\-]*\d){8,}');

  static final RegExp _email = RegExp(
    r'[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}',
  );

  /// Whether [text] seems to carry the author's own identity — a
  /// phone number or an email address about to drift in clear.
  static bool carriesIdentity(String text) =>
      _phoneFr.hasMatch(text) || _phoneIntl.hasMatch(text) || _email.hasMatch(text);
}
