import 'package:flutter/foundation.dart';

/// Where KENOS deep links point (salon doors, ember passages): one
/// origin for every `/#/...` hand-carried link. A build-time origin
/// wins (the deployed PWA); on the web the current origin speaks; a
/// native build without a known origin returns empty — the panels then
/// say the truth instead of sharing a broken link.
String appLinkOrigin() {
  const fromBuild = String.fromEnvironment('SALON_LINK_ORIGIN');
  if (fromBuild.isNotEmpty) return fromBuild;
  if (kIsWeb) {
    final base = Uri.base;
    if (base.scheme.startsWith('http')) return base.origin;
  }
  return '';
}
