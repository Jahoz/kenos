import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// V3.26 — the origin whisper: the browser resolves the shore's name
/// (pays · région · ville) from the visitor's IP, ONCE per session,
/// and ONLY when the author asks for it.
///
/// Privacy by architecture: the lookup happens in the author's own
/// browser — the ether never sees the IP, only the short label the
/// author chose to send (and only the single future reader will ever
/// see it). Fail-open by contract: an unreachable or unroutable
/// lookup means an unnamed light, never a blocked launch.
///
/// V3.26c: two keyless CORS-open shores, tried in order — ipwho.is
/// sits on popular blocklists (EasyPrivacy tracks IP lookups), so
/// geojs.io rows behind it. And the 96-character SQL bound is now a
/// CLAMP, never a blind substring: the V3.26 `substring(0, 96)`
/// threw a RangeError on every label shorter than 96 characters —
/// which is every label — making the origin eternally "injoignable"
/// even while the lookup answered perfectly.
class OriginWhisper {
  OriginWhisper._();

  static String? _cached;

  static final List<({Uri uri, List<String> keys})> _shores = [
    (
      uri: Uri.parse('https://ipwho.is/?fields=country,region,city'),
      keys: ['country', 'region', 'city'],
    ),
    (
      uri: Uri.parse('https://get.geojs.io/v1/ip/geo.json'),
      keys: ['country', 'region', 'city'],
    ),
  ];

  /// Resolves the origin label ('FRANCE · AUVERGNE-RHÔNE-ALPES · LYON'
  /// style — whatever the lookup can name, joined with ' · '), or
  /// null when the shore stays unnamed. Cached for the session.
  static Future<String?> resolve() async {
    if (_cached != null) return _cached;
    for (final shore in _shores) {
      try {
        final response = await http
            .get(shore.uri)
            .timeout(const Duration(seconds: 4));
        if (response.statusCode != 200) continue;
        final data = jsonDecode(response.body);
        if (data is! Map<String, dynamic>) continue;
        final parts = shore.keys
            .map((k) => data[k])
            .whereType<String>()
            .where((s) => s.trim().isNotEmpty)
            .toList();
        if (parts.isEmpty) continue;
        final label = parts.join(' · ');
        // The ether bounds the shore's name at 96 characters (SQL law)
        // — a clamp, never a blind slice.
        _cached = label.length <= 96 ? label : label.substring(0, 96);
        return _cached;
      } catch (e) {
        debugPrint('[kenos.origin] ${shore.uri.host} stays silent: $e');
      }
    }
    return null;
  }
}
