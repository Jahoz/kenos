import '../domain/echo.dart';
import '../domain/echo_color_theme.dart';
import '../domain/reception.dart';

/// Ether access contract.
///
/// Two implementations:
///  - [SupabaseEchoRepository]: production (echoes_map view + atomic RPCs);
///  - [LocalEchoRepository]:    offline demo mode, identical semantics.
abstract class EchoRepository {
  /// Stellar map metadata (never the text).
  Future<List<Echo>> fetchStarMap();

  /// Atomic consumption: returns the text to the winner, `null` if the
  /// echo was just intercepted elsewhere.
  Future<String?> consumeEcho(String id);

  /// Seals and launches an echo into the ether.
  /// Returns the created echo (without text — sealing philosophy).
  Future<Echo> sendEcho({
    required String text,
    required double coordX,
    required double coordY,
    required double coordZ,
    required EchoColorTheme theme,
  });

  /// Reader side: leave the one-line trace after consuming an echo.
  /// Returns false if a trace was already left (one shot, no edit).
  Future<bool> leaveTrace(String echoId, String text);

  /// Author side: unseen receptions (view = burn).
  Future<List<Reception>> fetchReceptions();

  /// Marks a reception as seen — the signal itself burns.
  Future<void> burnReception(String echoId);

  /// Emits whenever a new reception lands (demo simulation);
  /// silent stream in backend mode (polling/refresh covers it).
  Stream<void> receptionChanges();
}

/// Functional exceptions raised by server-side RPCs.
class KenosException implements Exception {
  const KenosException(this.code);
  final String code;

  factory KenosException.from(Object error) {
    final raw = error.toString();
    if (raw.contains('KENOS_RATE_LIMIT')) {
      return const KenosException('RATE_LIMIT');
    }
    if (raw.contains('KENOS_INVALID')) {
      return const KenosException('INVALID');
    }
    return const KenosException('UNREACHABLE');
  }

  /// French HUD message, machine typography (product UI language).
  String get hudMessage => switch (code) {
    'RATE_LIMIT' => 'TROP RAPIDE. RESPIRE, PUIS RECOMMENCE.',
    'INVALID' => 'CET ÉCHO EST MALFORMÉ.',
    _ => 'L\'ÉTHER EST INJOIGNABLE.',
  };
}
