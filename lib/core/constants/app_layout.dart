/// The posture: KENOS's designed composition is a portrait column —
/// the ether is a held breath, not a widescreen. Wide viewports
/// (desktop browsers, tablets) center that column over the void
/// instead of stretching it; a held phone in landscape is asked,
/// gently, to stand back up.
class AppLayout {
  AppLayout._();

  /// The posture column's width. Everything inside is designed against
  /// this portrait canvas; wider windows surround it with pure void.
  static const double postureMaxWidth = 520;

  /// A landscape window shorter than this is a held phone: the ritual
  /// veil applies. Tablets (768+) and desktop windows live standing in
  /// the column — no veil, ever.
  static const double phoneLandscapeMaxHeight = 480;

  /// Native orientation lock applies only to screens this narrow
  /// (phones); tablets and desktops rotate freely into the column.
  static const double nativeLockMaxWidth = 600;
}
