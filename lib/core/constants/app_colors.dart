import 'package:flutter/material.dart';

/// KENOS palette — "Cosmic Zen" / Dark Introspection.
/// Absolute dark mode: abyssal black dominates, light comes from the echoes.
class AppColors {
  AppColors._();

  /// Main background — abyssal black tinted with deep blue/violet.
  static const Color voidBlack = Color(0xFF030508);

  /// Slightly lighter variant for panels / HUD.
  static const Color voidBlackDeep = Color(0xFF07090F);

  /// Primary text, origin nodes.
  static const Color pureLight = Color(0xFFF4F4F6);

  /// Security, calm, local anchoring, encryption.
  static const Color teal = Color(0xFF14B8A6);
  static const Color cyan = Color(0xFF22D3EE);

  /// The ether, mystery, public space, listening.
  static const Color indigo = Color(0xFF6366F1);
  static const Color purple = Color(0xFF8B5CF6);

  /// EXCLUSIVELY data destruction (burn after reading).
  static const Color rose = Color(0xFFF43F5E);

  /// Lighter rose for TEXT on Void Black (contrast),
  /// still reserved for destruction only.
  static const Color roseText = Color(0xFFFB7185);

  /// Minimal translucent border (5% white).
  static const Color hairline = Color(0x0DFFFFFF);
  static const Color hairlineStrong = Color(0x1FFFFFFF);

  /// Alpha helper compatible with every Flutter version.
  static Color fade(Color c, double alpha) =>
      c.withAlpha((alpha * 255).round());
}
