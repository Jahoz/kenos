import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'void_territories.dart';

/// The sky's one-time-per-session whispers, as session state.
///
/// These used to be widget statics (`MindfulHoldStar.farWhisperSpoken`,
/// `MapScreen.territoriesAnnounced`, `_aubeSpokenThisSession`) —
/// global mutable state that survived screen remounts BY DESIGN but
/// also leaked across tests and sessions. As Riverpod state they keep
/// exactly that session semantics (one scope = one session) while
/// being owned by the application layer, reset honestly by a fresh
/// scope, and readable by tests without touching product code.

/// The far-field whisper ("TROP LOIN. RAPPROCHE-TOI."): the reception
/// field teaches itself once, then stays quiet.
final farWhisperSpokenProvider = StateProvider<bool>((ref) => false);

/// V3.35 — the landscapes already whispered this session (silence is
/// the default state): crossing a territory speaks its name once.
final territoriesAnnouncedProvider =
    StateProvider<Set<VoidTerritory>>((ref) => {});

/// The Awakening sas speaks once per session, after the first
/// receptions sync — never again.
final aubeSpokenProvider = StateProvider<bool>((ref) => false);
