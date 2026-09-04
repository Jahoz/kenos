import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The Trace Shield — the reader's last quiet look before the line
/// drifts (V3.15).
///
/// The trace is the ONLY user content the ether sees in clear; before
/// it leaves, the `trace-shield` edge function reads it through
/// Mistral's moderation model and returns two flags:
///  - [pii]: the writer is about to burn their own anonymity —
///    the app WARNS, never blocks (anonymity is the contract, and
///    choosing belongs to the one who writes);
///  - [selfharm]: a real pain is being left in the void — the app
///    offers a care moment with resources, never censorship.
///
/// Fail-open by contract: unreachable, unconfigured, malformed —
/// the shield is a guest, never a gate. Sealed content (echoes,
/// constellations, songs) is structurally invisible to it, forever.
class TraceShield {
  const TraceShield._();

  /// Reads the trace through the shield. Any failure = clean pass:
  /// the trace proceeds untouched.
  static Future<TraceShieldVerdict> read(String text) async {
    try {
      final client = Supabase.instance.client;
      // Only meaningful with a live session (the edge function
      // authenticates); demo mode skips the shield entirely.
      if (client.auth.currentSession == null) {
        return TraceShieldVerdict.pass;
      }
      final res = await client.functions.invoke(
        'trace-shield',
        body: {'text': text},
      );
      if (res.status != 200) return TraceShieldVerdict.pass;
      final data = res.data;
      if (data is! Map) return TraceShieldVerdict.pass;
      final map = data.cast<String, dynamic>();
      return TraceShieldVerdict(
        pii: map['pii'] == true,
        selfharm: map['selfharm'] == true,
      );
    } catch (e) {
      debugPrint('[kenos.shield] guest unreachable, trace passes: $e');
      return TraceShieldVerdict.pass;
    }
  }
}

class TraceShieldVerdict {
  const TraceShieldVerdict({required this.pii, required this.selfharm});

  final bool pii;
  final bool selfharm;

  static const pass = TraceShieldVerdict(pii: false, selfharm: false);

  bool get clean => !pii && !selfharm;
}

/// Decodes a shield response body (test seam — the shape the edge
/// function answers with).
TraceShieldVerdict decodeShieldBody(String raw) {
  try {
    final data = jsonDecode(raw);
    if (data is! Map) return TraceShieldVerdict.pass;
    final map = data.cast<String, dynamic>();
    return TraceShieldVerdict(
      pii: map['pii'] == true,
      selfharm: map['selfharm'] == true,
    );
  } catch (_) {
    return TraceShieldVerdict.pass;
  }
}
