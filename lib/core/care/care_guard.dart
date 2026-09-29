/// The Care Guard — the quiet hand extended before the seal (V3.88).
///
/// Sealed thoughts are AES-256-GCM blind to the ether, and the care
/// of a distant moderation API is a guest that fails open — a care
/// that depends on a quota is a care that fails silent. The device
/// holds the thought in clear for one moment, before the seal exists,
/// and that moment is the only honest place left to say: you don't
/// have to carry this alone.
///
/// Core vocabulary, like the voice: every feature writes through the
/// same doors. Same contract as the PII guard: pure lexicon, zero
/// network, WARN never block. The guard answers with THEMES, never
/// quotes — what the author wrote is theirs alone; the resources
/// belong to everyone. Over-matching is the safe direction: the
/// moment is an offer, not a gate, and one offer too many costs a
/// dismiss, while one offer too few costs a night alone.
enum CareTheme {
  /// Despair, suicidal or self-harm pain → 3114 / 15.
  detresse,

  /// Violence lived at home or from a partner → 3919.
  violences,

  /// Sexual aggression → SOS Viols.
  agression,

  /// Childhood in danger (incest, predation) → 119.
  enfance,
}

class CareGuard {
  const CareGuard._();

  /// Accents folded: French is written fast, accents are the first
  /// casualty — "deprimée" must find "déprimée" for the guard to be
  /// honest about how people actually write at 2 a.m.
  static const _folds = {
    'á': 'a', 'à': 'a', 'â': 'a', 'ä': 'a', 'ã': 'a',
    'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
    'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
    'ó': 'o', 'ò': 'o', 'ô': 'o', 'ö': 'o', 'õ': 'o',
    'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u',
    'ý': 'y', 'ÿ': 'y', 'ç': 'c', 'ñ': 'n',
  };

  static String _normalize(String text) {
    var t = text.toLowerCase();
    for (final e in _folds.entries) {
      t = t.replaceAll(e.key, e.value);
    }
    // Typographic apostrophes fold to the plain one, so "j'en finir"
    // matches however the keyboard felt like writing it.
    return t.replaceAll('’', '\'');
  }

  /// Suicidal and self-harm language — strong phrases only: "tuer"
  /// alone also kills time, and a guard that cries wolf at every
  /// shadow teaches everyone to dismiss it.
  static final RegExp _detresse = RegExp(
    'suicid' // suicide, suicider, suicidé·e…
    r'|\bme tuer\b|\bme tue\b|vais me tue|veux me tue'
    "|envie d'en finir|j'en finir|en finir avec"
    '|envie de mourir|veux mourir|envie de disparaitre|veux disparaitre'
    '|plus envie de vivre|plus envie de rien'
    r'|\bme coup\w*\b|\bme bruler\b|me faire du mal|me faire mal'
    '|automutil'
    '|deprim|depress'
    '|kill myself|killing myself|suicidal'
    '|end my life|end it all|want to die|wanna die|wanted to die'
    '|better off dead|hurt myself|self.?harm|cut myself'
    '|no reason to live|dont want to live|don?t want to live',
  );

  /// Violence lived — conjugales, familiales. "violent" alone stays
  /// out ("un violent orage" is weather, "la mer était violente" is
  /// the sea); the blows land as phrases.
  static final RegExp _violences = RegExp(
    'me frappe|me frappait|me frapper'
    r'|\bme bat\b|\bme bats\b|me battait|me battre|batterie de coups'
    '|violences? conjugales?|conjoint violent|mari violent|pere violent'
    '|mere violente'
    '|violent avec moi|violente avec moi'
    '|violence a la maison'
    '|a menace de me|menace de me frapper'
    '|domestic violence|beats me|beat me|hits me|hitting me|abusive',
  );

  /// Sexual aggression. The "violon" and "violent" families are
  /// carved out — a cello's cousin and rough weather must never
  /// summon a care moment; the blows belong to the phrases above.
  static final RegExp _agression = RegExp(
    r'\bviol(?!on|en)\w*\b' // viol, viols, violer, violé·e, violeur…
    r'|\babus\w*\b' // abus, abusé·e, abuser…
    '|agression|agresse'
    '|sans mon consentement|non consentie|sans consentement'
    '|harcel' // harcèlement, harceler…
    r'|\brape[ds]?\b|raping|molest\w*|sexual assault'
    '|without my consent',
  );

  /// Childhood in danger — the theme where the reader may be a child
  /// writing at night, and 119 exists for exactly that.
  static final RegExp _enfance = RegExp(
    'incest' // inceste, incestueux, incest…
    '|pedophil|pedocriminel|pedophile'
    '|attouchements'
    r'|when i was a (child|kid|little)',
  );

  /// The themes this text seems to carry — empty means no care to
  /// offer. Themes are a set: one text may be both a violence and an
  /// enfance, and every matched door opens.
  static Set<CareTheme> themes(String text) {
    if (text.trim().length < 3) return const {};
    final t = _normalize(text);
    final found = <CareTheme>{};
    if (_detresse.hasMatch(t)) found.add(CareTheme.detresse);
    if (_violences.hasMatch(t)) found.add(CareTheme.violences);
    if (_agression.hasMatch(t)) found.add(CareTheme.agression);
    if (_enfance.hasMatch(t)) found.add(CareTheme.enfance);
    return found;
  }
}
