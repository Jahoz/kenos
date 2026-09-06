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
class OriginWhisper {
  OriginWhisper._();

  static String? _cached;

  /// Resolves the origin label ('FRANCE · AUVERGNE-RHÔNE-ALPES · LYON'
  /// style — whatever the lookup can name, joined with ' · '), or
  /// null when the shore stays unnamed. Cached for the session.
  static Future<String?> resolve() async {
    if (_cached != null) return _cached;
    try {
      final response = await http
          .get(Uri.parse('https://ipwho.is/?fields=country,region,city'))
          .timeout(const Duration(seconds: 4));
      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body);
      if (data is! Map<String, dynamic>) return null;
      final parts = [
        data['country'],
        data['region'],
        data['city'],
      ].whereType<String>().where((s) => s.trim().isNotEmpty).toList();
      if (parts.isEmpty) return null;
      // The ether bounds the shore's name at 96 characters (SQL law).
      _cached = parts.join(' · ').substring(0, 96);
      return _cached;
    } catch (e) {
      debugPrint('[kenos.origin] the shore stays unnamed: $e');
      return null;
    }
  }
}
