import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/echo.dart';
import '../domain/echo_color_theme.dart';
import '../domain/echo_excerpt.dart';
import '../domain/echo_media.dart';
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

  /// Atomic consumption: returns the content to the winner, `null` if the
  /// echo was just intercepted elsewhere.
  Future<ConsumedEcho?> consumeEcho(String id);

  /// Seals and launches an echo into the ether.
  /// Returns the created echo (without text — sealing philosophy).
  /// At most ONE attachment: a binary [media] fragment OR a cultural
  /// [excerpt] door — the ether's media slot is single.
  Future<Echo> sendEcho({
    required String text,
    required double coordX,
    required double coordY,
    required double coordZ,
    required EchoColorTheme theme,
    EchoMediaDraft? media,
    EchoExcerpt? excerpt,
  });

  /// Reader side: leave the one-line trace after consuming an echo.
  /// Returns false if a trace was already left (one shot, no edit).
  Future<bool> leaveTrace(String echoId, String text);

  /// The Sling-Shot (phoenix): re-seal the just-read text and give it
  /// velocity. The reader's device encrypts it fresh — for ONE new
  /// receiver — and the server stamps the lineage momentum + 1.
  /// Only the reader, within the 10-minute decision window.
  Future<Echo> reboundEcho({
    required String sourceId,
    required int parentMomentum,
    required String text,
    required double coordX,
    required double coordY,
    required double coordZ,
  });

  /// Reader side: records one contentless moderation report for an echo.
  Future<bool> reportEcho(String echoId, EchoReportReason reason);

  /// Author side: unseen receptions (view = burn).
  Future<List<Reception>> fetchReceptions();

  /// Marks a reception as seen — the signal itself burns.
  Future<void> burnReception(String echoId);

  /// Emits whenever a new reception lands (demo simulation);
  /// silent stream in backend mode (polling/refresh covers it).
  Stream<void> receptionChanges();
}

/// Fixed report reasons: moderation data stays minimal and classifiable.
enum EchoReportReason {
  inappropriate('INAPPROPRIATE', 'CONTENU INAPPROPRIÉ'),
  spam('SPAM', 'SPAM'),
  danger('DANGER', 'DANGER IMMÉDIAT'),
  other('OTHER', 'AUTRE MOTIF');

  const EchoReportReason(this.wire, this.label);

  final String wire;
  final String label;
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
    // A swallowed cause is a mystery ten minutes later: keep it visible.
    debugPrint('[kenos.rpc] $message');
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

  @override
  String toString() => 'KenosException($code)';
}
