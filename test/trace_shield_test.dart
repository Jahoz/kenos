import 'package:flutter_test/flutter_test.dart';
import 'package:kenos/features/echo/data/trace_shield.dart';

/// The Trace Shield's contract: the shield is a guest, never a gate.
/// Decode is fail-open (malformed → pass), flags map exactly to the
/// edge function's answer, and the verdicts the dialogs read are the
/// ones the model produced.
void main() {
  group('decodeShieldBody (fail-open par contrat)', () {
    test('le corps sain de la fonction edge décode ses drapeaux', () {
      final v = decodeShieldBody('{"ok": true, "pii": true, "selfharm": false}');
      expect(v.pii, isTrue);
      expect(v.selfharm, isFalse);
      expect(v.clean, isFalse,
          reason: 'un drapeau levé n\'est jamais un verdict propre');
    });

    test('un corps propre passe', () {
      final v = decodeShieldBody('{"ok": true, "pii": false, "selfharm": false}');
      expect(v.clean, isTrue);
    });

    test('un corps cassé lit en passage — jamais en erreur', () {
      expect(decodeShieldBody('{not json').clean, isTrue);
      expect(decodeShieldBody('null').clean, isTrue);
      expect(decodeShieldBody('[]').clean, isTrue);
      expect(decodeShieldBody('').clean, isTrue);
    });

    test('les types lâches ne lèvent rien de faux', () {
      // Truthy strings / numbers are NOT booleans: only `true` flags.
      final v = decodeShieldBody('{"ok": 1, "pii": "true", "selfharm": 1}');
      expect(v.clean, isTrue,
          reason: 'seul le booléen strict du edge function compte');
    });
  });

  group('TraceShield.read (échec réseau = fail-open)', () {
    test('sans session Supabase, la trace passe sans appel', () async {
      // No Supabase initialized in this test zone → the shield must
      // return pass, not throw.
      final v = await TraceShield.read('Appelle-moi au 06 12 34 56 78');
      expect(v.clean, isTrue,
          reason: 'démo / hors-ligne : le bouclier ne bloque rien');
    });
  });
}
