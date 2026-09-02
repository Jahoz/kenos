import 'package:flutter/painting.dart' show EdgeInsets;

/// Layout constants of the void.
///
/// The app is FULL-BLEED: the ether owns every pixel of every screen —
/// wide viewports get more sky, never pillarboxed margins. Only
/// content that must not stretch (the threshold's rules, the Mirror's
/// editor) constrains itself to [contentMaxWidth], centered in the
/// void. A held phone lying flat still meets the ritual veil.
class AppLayout {
  AppLayout._();

  /// Inner content column for screens that must not stretch (the
  /// threshold, the Mirror). Centered by their own scaffolds; the sky
  /// and the frequencies fill everything else.
  static const double contentMaxWidth = 560;

  /// A landscape window shorter than this is a held phone: the ritual
  /// veil applies. Tablets (768+) and desktop windows live wide — no
  /// veil, ever.
  static const double phoneLandscapeMaxHeight = 480;

  /// Native orientation lock applies only to screens this narrow
  /// (phones); tablets and desktops rotate freely.
  static const double nativeLockMaxWidth = 600;

  // ── Stellar map HUD ────────────────────────────────────────────────
  // The machine whisper's home: asymmetric on purpose (the eye starts
  // reading top-left, the void eats the right).

  /// Top HUD padding (left breathing wider than right — reading starts
  /// at the left edge of the whisper).
  static const EdgeInsets hudPadding = EdgeInsets.fromLTRB(20, 10, 16, 0);

  /// Below this viewport width the OriginNode sits above the Mirror
  /// gate (narrow portraits), else at the map's calm corner.
  static const double mirrorGateMaxWidth = 640;
  static const double originBottomNarrow = 118;
  static const double originBottomWide = 44;
  static const double originLeft = 22;

  /// The Mirror gate never drowns under home-indicator territory.
  static const double mirrorGateBottomInset = 30;
}
