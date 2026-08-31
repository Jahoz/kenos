/// Local user statistics (no PII, purely anonymized metrics).
/// Tracks: echo creation count, reception count, last echo timestamp.
class UserStats {
  UserStats({
    required this.totalEchosSent,
    required this.totalReceptionsReceived,
    required this.totalTracesLeft,
    this.lastEchoSentAt,
    this.readCount = 0,
  });

  final int totalEchosSent;
  final int totalReceptionsReceived;
  final int totalTracesLeft;
  final DateTime? lastEchoSentAt;
  final int readCount;

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

  UserStats copyWith({
    int? totalEchosSent,
    int? totalReceptionsReceived,
    int? totalTracesLeft,
    DateTime? lastEchoSentAt,
    int? readCount,
  }) =>
      UserStats(
        totalEchosSent: totalEchosSent ?? this.totalEchosSent,
        totalReceptionsReceived:
            totalReceptionsReceived ?? this.totalReceptionsReceived,
        totalTracesLeft: totalTracesLeft ?? this.totalTracesLeft,
        lastEchoSentAt: lastEchoSentAt ?? this.lastEchoSentAt,
        readCount: readCount ?? this.readCount,
      );

  Map<String, dynamic> toJson() => {
    'totalEchosSent': totalEchosSent,
    'totalReceptionsReceived': totalReceptionsReceived,
    'totalTracesLeft': totalTracesLeft,
    'lastEchoSentAt': lastEchoSentAt?.toIso8601String(),
    'readCount': readCount,
  };

  factory UserStats.fromJson(Map<String, dynamic> json) => UserStats(
    totalEchosSent: json['totalEchosSent'] as int? ?? 0,
    totalReceptionsReceived: json['totalReceptionsReceived'] as int? ?? 0,
    totalTracesLeft: json['totalTracesLeft'] as int? ?? 0,
    lastEchoSentAt: json['lastEchoSentAt'] != null
        ? DateTime.parse(json['lastEchoSentAt'] as String)
        : null,
    readCount: json['readCount'] as int? ?? 0,
  );

  /// Default empty stats.
  factory UserStats.empty() => UserStats(
    totalEchosSent: 0,
    totalReceptionsReceived: 0,
    totalTracesLeft: 0,
  );
}
