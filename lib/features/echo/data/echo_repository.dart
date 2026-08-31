import 'package:supabase_flutter/supabase_flutter.dart';

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

  /// Viewport variant: normalized rect, sector-culled (8×8 grid, newest
  /// per sector, capped total). Demo mode mirrors the exact semantics.
  Future<List<Echo>> fetchStarMapInSector(
    double minX,
    double minY,
    double maxX,
    double maxY,
  );

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

/// Functional error codes raised by server-side RPCs — exhaustive on
/// purpose: a new server code must become a new enum value here, not a
/// silent fallthrough to "unreachable".
enum KenosErrorCode { rateLimit, invalid, unauthenticated, unreachable }

/// Functional exceptions raised by server-side RPCs.
class KenosException implements Exception {
  const KenosException(this.code);

  final KenosErrorCode code;

  /// Typed origin: PostgREST carries the server's `raise exception`
  /// token in [PostgrestException.message]; anything else (network,
  /// serialization) is genuinely unreachable.
  factory KenosException.from(Object error) {
    if (error is KenosException) return error;
    final message = switch (error) {
      PostgrestException e => e.message,
      _ => error.toString(),
    };
    if (message.contains('KENOS_RATE_LIMIT')) {
      return const KenosException(KenosErrorCode.rateLimit);
    }
    if (message.contains('KENOS_INVALID')) {
      return const KenosException(KenosErrorCode.invalid);
    }
    if (message.contains('KENOS_UNAUTHENTICATED')) {
      return const KenosException(KenosErrorCode.unauthenticated);
    }
    return const KenosException(KenosErrorCode.unreachable);
  }

  /// French HUD message, machine typography (product UI language).
  String get hudMessage => switch (code) {
    KenosErrorCode.rateLimit => 'TROP RAPIDE. RESPIRE, PUIS RECOMMENCE.',
    KenosErrorCode.invalid => 'CET ÉCHO EST MALFORMÉ.',
    KenosErrorCode.unauthenticated => 'L\'ÉTHER NE TE RECONNAÎT PAS.',
    KenosErrorCode.unreachable => 'L\'ÉTHER EST INJOIGNABLE.',
  };
}
