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

  // ── Wide viewports (V3.43) ─────────────────────────────────────────
  // Tablets and desktops get a DISPOSITION, not a stretched phone:
  // the map's two doors stand side by side, the Mirror composes in
  // two columns (the secret to the left, every choice and the seal
  // to the right).

  /// Past this width the map's two creation doors sit SIDE BY SIDE
  /// (stacked below it — the thumb's law holds on phones).
  static const double gatesSideBySide = 560;

  /// Past this width the Mirror composes in two columns — for
  /// GENUINELY wide windows only (V3.43c): at Hugo's Retina 955×480
  /// logical window the composer fired edge-to-edge and its tall
  /// editor pushed the seal below the fold — the honest single column
  /// (the constellation screen's own disposition, the one he calls
  /// good) serves every window that is not truly wide.
  static const double mirrorTwoColumns = 1150;

  /// The wide composer's measure (V3.43b): the Mirror's column cap
  /// RISES with the disposition — a two-column composer inside the
  /// phone's 560 cap was two cramped columns in a centered band, the
  /// very thing the wide layout came to fix.
  static const double mirrorWideMaxWidth = 1020;
}
