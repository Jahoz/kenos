/// Local user statistics (no PII, purely anonymized metrics).
/// Tracks: echo creation count, reception count, last echo timestamp.
class UserStats {
  UserStats({
    required this.totalEchosSent,
    required this.totalReceptionsReceived,
    required this.totalTracesLeft,
    this.lastEchoSentAt,
    this.readCount = 0,
    this.stardust = 0,
    this.seenReceptions = 0,
    this.constellationsTouched = 0,
    this.lastVisitAt,
  });

  final int totalEchosSent;
  final int totalReceptionsReceived;
  final int totalTracesLeft;
  final DateTime? lastEchoSentAt;
  final int readCount;

  /// L'Aube: what the user's presence has kindled in others. One mote
  /// per echo read, one per reception received — impact, never a score.
  final int stardust;

  /// Receptions already counted at the last visit: the difference is
  /// what happened during the absence (the sas speaks of it, and only
  /// of it — never a notification afterwards).
  final int seenReceptions;

  /// Constellations the user contributed a line to (the Awakening may
  /// whisper when one closes — the only check-back signal, by design).
  final int constellationsTouched;

  final DateTime? lastVisitAt;

  /// Countdown in seconds until next echo can be sent (based on 20s friction).
  int? get secondsUntilNextEcho {
    if (lastEchoSentAt == null) return null;
    final elapsed =
        DateTime.now().difference(lastEchoSentAt!).inSeconds;
    const friction = 20; // Backend rate limit
    return friction - elapsed > 0 ? friction - elapsed : null;
  }

  /// Is the user ready to send (passed 20s friction)?
  bool get canSendEcho => secondsUntilNextEcho == null;

  /// The dashboard uses a quiet observation, never a score or rank.
  String get resonanceMessage {
    if (totalEchosSent == 0) return 'Le vide peut accueillir un premier écho.';
    if (totalReceptionsReceived > 0) {
      return 'Un écho a trouvé une présence, puis le silence.';
    }
    if (totalTracesLeft > 0) return 'Une trace a rejoint quelqu\'un, sans attente.';
    if (readCount > 0) return 'Tu as reçu une confidence et l\'as laissée partir.';
    return 'Tes échos dérivent encore dans l\'éther.';
  }

  /// Receptions that landed since the last visit — L'Aube's material.
  int get receptionsSinceLastVisit =>
      (totalReceptionsReceived - seenReceptions).clamp(0, 1 << 30);

  /// Whether the sas has anything to say (silence is also an answer,
  /// and then the sas stays closed).
  bool get hasAwakeningToTell =>
      receptionsSinceLastVisit > 0 ||
      (lastVisitAt != null && stardust >= 3) ||
      constellationsTouched > 0 ||
      (lastVisitAt == null && totalEchosSent > 0);

  /// The sas's poetic lines, in order. Pure: the widget test pins them.
  List<String> awakeningLines() {
    final waiting = receptionsSinceLastVisit;
    if (waiting == 1) {
      return [
        'Pendant ton absence, un de tes échos a touché un inconnu.',
        'Le silence a porté tes mots plus loin que tu ne sais.',
      ];
    }
    if (waiting > 1) {
      return [
        'Pendant ton absence, $waiting de tes échos ont touché un inconnu.',
        'Le silence a porté tes mots plus loin que tu ne sais.',
      ];
    }
    if (constellationsTouched > 0) {
      return [
        'Une constellation que tu as touchée s\'est refermée.',
        'Tu ne la liras jamais — quelqu\'un d\'autre l\'a eue entière.',
      ];
    }
    if (totalEchosSent > 0) {
      return [
        'Tes $totalEchosSent échos dérivent encore, quelque part, intacts.',
        'Respire. Rien ne presse.',
      ];
    }
    return ['L\'éther est calme. Commence doucement.'];
  }

  UserStats copyWith({
    int? totalEchosSent,
    int? totalReceptionsReceived,
    int? totalTracesLeft,
    DateTime? lastEchoSentAt,
    int? readCount,
    int? stardust,
    int? seenReceptions,
    int? constellationsTouched,
    DateTime? lastVisitAt,
  }) =>
      UserStats(
        totalEchosSent: totalEchosSent ?? this.totalEchosSent,
        totalReceptionsReceived:
            totalReceptionsReceived ?? this.totalReceptionsReceived,
        totalTracesLeft: totalTracesLeft ?? this.totalTracesLeft,
        lastEchoSentAt: lastEchoSentAt ?? this.lastEchoSentAt,
        readCount: readCount ?? this.readCount,
        stardust: stardust ?? this.stardust,
        seenReceptions: seenReceptions ?? this.seenReceptions,
        constellationsTouched:
            constellationsTouched ?? this.constellationsTouched,
        lastVisitAt: lastVisitAt ?? this.lastVisitAt,
      );

  Map<String, dynamic> toJson() => {
    'totalEchosSent': totalEchosSent,
    'totalReceptionsReceived': totalReceptionsReceived,
    'totalTracesLeft': totalTracesLeft,
    'lastEchoSentAt': lastEchoSentAt?.toIso8601String(),
    'readCount': readCount,
    'stardust': stardust,
    'seenReceptions': seenReceptions,
    'constellationsTouched': constellationsTouched,
    'lastVisitAt': lastVisitAt?.toIso8601String(),
  };

  factory UserStats.fromJson(Map<String, dynamic> json) => UserStats(
    totalEchosSent: json['totalEchosSent'] as int? ?? 0,
    totalReceptionsReceived: json['totalReceptionsReceived'] as int? ?? 0,
    totalTracesLeft: json['totalTracesLeft'] as int? ?? 0,
    lastEchoSentAt: json['lastEchoSentAt'] != null
        ? DateTime.parse(json['lastEchoSentAt'] as String)
        : null,
    readCount: json['readCount'] as int? ?? 0,
    stardust: json['stardust'] as int? ?? 0,
    seenReceptions: json['seenReceptions'] as int? ?? 0,
    constellationsTouched: json['constellationsTouched'] as int? ?? 0,
    lastVisitAt: json['lastVisitAt'] != null
        ? DateTime.parse(json['lastVisitAt'] as String)
        : null,
  );

  /// Default empty stats.
  factory UserStats.empty() => UserStats(
    totalEchosSent: 0,
    totalReceptionsReceived: 0,
    totalTracesLeft: 0,
  );
}
