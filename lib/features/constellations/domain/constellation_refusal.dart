import 'package:supabase_flutter/supabase_flutter.dart';

/// LE SALON (V3.19): the salon door refused the key — demo parity for
/// the SQL guard (KENOS_INVITE_UNKNOWN: missing and wrong look alike).
class SalonKeyRefused implements Exception {
  const SalonKeyRefused();

  @override
  String toString() => 'KENOS_INVITE_UNKNOWN';
}

/// Every refusal the constellation RPC grammar can raise. The token is
/// the SQLERRMC the server puts in the PostgREST message — the enum is
/// the exhaustive client-side mirror of the grammar (a new server code
/// must become a new value here, not a silent fallthrough).
enum ConstellationRefusal {
  alreadyContributed('KENOS_ALREADY_CONTRIBUTED'),
  rateLimit('KENOS_RATE_LIMIT'),
  closed('KENOS_CLOSED'),
  notFound('KENOS_NOT_FOUND'),
  invalidLength('KENOS_INVALID_LENGTH'),
  inviteUnknown('KENOS_INVITE_UNKNOWN'),
  unauthenticated('KENOS_UNAUTHENTICATED'),
  seedCap('KENOS_SEED_CAP'),
  invalidState('KENOS_INVALID_STATE'),
  invalidReportReason('KENOS_INVALID_REPORT_REASON'),
  linesExist('KENOS_LINES_EXIST');

  const ConstellationRefusal(this.token);

  /// The token exactly as the SQL raises it (`RAISE EXCEPTION`).
  final String token;
}

/// THE single structural interpreter of the ether's refusals.
///
/// Structure, not string sniffing: the code is read only from TYPED
/// fields — a [PostgrestException]'s message (the server answered: a
/// true refusal, code or no code — 42501 and friends included), a
/// [StateError]'s message (the demo repositories' parity throws), or
/// the typed [SalonKeyRefused]. Anything else (network, serialization)
/// is the sky being far: nothing was refused, and the caller must say
/// so honestly. Returns null for exactly that case.
ConstellationRefusal? refusalOf(Object error) {
  if (error is SalonKeyRefused) return ConstellationRefusal.inviteUnknown;
  final message = switch (error) {
    PostgrestException e => e.message,
    StateError e => e.message,
    _ => null,
  };
  if (message == null) return null;
  for (final refusal in ConstellationRefusal.values) {
    if (message.contains(refusal.token)) return refusal;
  }
  return null;
}

/// Whether the ether answered at all — a typed PostgrestException IS
/// an answer (a refusal, even without a known code); only anything
/// else separates "refused" from "unreachable".
bool etherAnswered(Object error) => error is PostgrestException;

/// What the ether actually said when a line was refused — the
/// writer deserves the reason, not a shrug. Every KENOS_* the SQL
/// grammar can raise has its word here; a PostgREST error with no
/// known code is a true refusal, anything else is the sky being far
/// (never "refused": nothing was refused, the ether never answered).
String contributeRefusalMessage(Object error) {
  final refusal = refusalOf(error);
  if (refusal != null) {
    return switch (refusal) {
      ConstellationRefusal.alreadyContributed =>
        'TA PHRASE EST DÉJÀ DANS CE CORPS.',
      ConstellationRefusal.rateLimit =>
        'LE CIEL SOUFFLE — REVIENS DANS DEUX MINUTES.',
      ConstellationRefusal.closed => 'LE POÈME S\'EST REFERMÉ AILLEURS.',
      ConstellationRefusal.notFound => 'CET ANNEAU A RETOURNÉ AU VIDE.',
      ConstellationRefusal.invalidLength =>
        'LA PHRASE EST TROP LONGUE POUR LE CIEL.',
      ConstellationRefusal.inviteUnknown =>
        'LE SALON N\'A PAS RECONNU TA CLÉ.',
      ConstellationRefusal.unauthenticated =>
        'L\'ÉTHER NE TE RECONNAÎT PLUS.',
      _ => 'L\'ÉTHER A REFUSÉ LA LIGNE.',
    };
  }
  return etherAnswered(error)
      ? 'L\'ÉTHER A REFUSÉ LA LIGNE.'
      : 'L\'ÉTHER EST INJOIGNABLE — LA LIGNE RESTE À TOI.';
}

/// The same honesty for a refused seed — the two guards a hand meets
/// (cadence, open-ring cap) both have a remedy, and it is not silence.
String seedRefusalMessage(Object error) {
  final refusal = refusalOf(error);
  if (refusal != null) {
    return switch (refusal) {
      ConstellationRefusal.rateLimit =>
        'LE CIEL SOUFFLE — DEUX MINUTES ENTRE DEUX ANNEAUX.',
      ConstellationRefusal.seedCap =>
        'TA MAIN TIENT DÉJÀ CINQ POÈMES OUVERTS.',
      ConstellationRefusal.unauthenticated =>
        'L\'ÉTHER NE TE RECONNAÎT PLUS.',
      _ => 'L\'ÉTHER A REFUSÉ LA CONSTELLATION.',
    };
  }
  return etherAnswered(error)
      ? 'L\'ÉTHER A REFUSÉ LA CONSTELLATION.'
      : 'L\'ÉTHER EST INJOIGNABLE.';
}

/// The same honesty for a refused artifact report — the closed poem is
/// the only user content the ether shows in clear to everyone; the
/// reader who judges it worthy of the guardian's eye deserves the
/// reason of every refusal (V3.51).
String reportRefusalMessage(Object error) {
  final refusal = refusalOf(error);
  if (refusal != null) {
    return switch (refusal) {
      ConstellationRefusal.invalidState =>
        'RIEN N\'EST LISIBLE DANS CET ANNEAU.',
      ConstellationRefusal.notFound => 'CET ARTEFACT A RETOURNÉ AU VIDE.',
      ConstellationRefusal.rateLimit => 'LE CIEL SOUFFLE — REVIENS DEMAIN.',
      ConstellationRefusal.invalidReportReason =>
        'L\'ÉTHER NE CONNAÎT PAS CE MOTIF.',
      ConstellationRefusal.unauthenticated =>
        'L\'ÉTHER NE TE RECONNAÎT PLUS.',
      _ => 'L\'ÉTHER A REFUSÉ LE SIGNALEMENT.',
    };
  }
  return etherAnswered(error)
      ? 'L\'ÉTHER A REFUSÉ LE SIGNALEMENT.'
      : 'L\'ÉTHER EST INJOIGNABLE — LE CIEL GARDERA.';
}

/// The same honesty for a refused key cut (V3.53) — the seeder who
/// replaces a silent guest deserves the door's reason, not silence.
String reseedRefusalMessage(Object error) {
  final refusal = refusalOf(error);
  if (refusal != null) {
    return switch (refusal) {
      ConstellationRefusal.linesExist => 'LA PORTE A DÉJÀ ÉTÉ TOUCHÉE.',
      ConstellationRefusal.closed => 'LE POÈME S\'EST REFERMÉ.',
      ConstellationRefusal.notFound => 'AUCUNE PORTE À RESEMER.',
      ConstellationRefusal.unauthenticated =>
        'L\'ÉTHER NE TE RECONNAÎT PLUS.',
      _ => 'L\'ÉTHER A REFUSÉ LA CLÉ.',
    };
  }
  return etherAnswered(error)
      ? 'L\'ÉTHER A REFUSÉ LA CLÉ.'
      : 'L\'ÉTHER EST INJOIGNABLE.';
}
