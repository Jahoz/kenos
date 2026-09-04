import 'package:flutter_test/flutter_test.dart';
import 'package:kenos/features/echo/domain/pii_guard.dart';

/// The PII guard: the author's last quiet look before the seal. The
/// case that borned it: a real phone number typed in the Mirror
/// drifted unwarned — the ether is blind to sealed thoughts, only the
/// device can ask the question. Over-matching is the safe direction
/// (the warning is a question, not a gate).
void main() {
  group('PiiGuard — téléphones', () {
    test('le cas du monde réel : numéro nu dans une phrase', () {
      expect(PiiGuard.carriesIdentity('appelle moi au 0683077484 ce soir'), isTrue);
    });

    test('formats français : espaces, points, tirets', () {
      expect(PiiGuard.carriesIdentity('06 83 07 74 84'), isTrue);
      expect(PiiGuard.carriesIdentity('06.83.07.74.84'), isTrue);
      expect(PiiGuard.carriesIdentity('06-83-07-74-84'), isTrue);
    });

    test('préfixes internationaux français', () {
      expect(PiiGuard.carriesIdentity('+33683077484'), isTrue);
      expect(PiiGuard.carriesIdentity('+33 6 83 07 74 84'), isTrue);
      expect(PiiGuard.carriesIdentity('0033 6 83 07 74 84'), isTrue);
    });

    test('numéro international étranger', () {
      expect(PiiGuard.carriesIdentity('+1 (415) 555 2671'), isTrue);
      expect(PiiGuard.carriesIdentity('+49 30 12345678'), isTrue);
    });

    test('fixe français aussi', () {
      expect(PiiGuard.carriesIdentity('01 42 68 53 00'), isTrue);
    });
  });

  group('PiiGuard — emails', () {
    test('adresse nue et dans une phrase', () {
      expect(PiiGuard.carriesIdentity('hugo@example.com'), isTrue);
      expect(PiiGuard.carriesIdentity('écris-moi : prenom.nom+kenos@exemple.fr !'), isTrue);
    });
  });

  group('PiiGuard — le reste du monde passe', () {
    test('durées, dates, heures, lignes de soin', () {
      expect(PiiGuard.carriesIdentity('30 jours à la dérive'), isFalse);
      expect(PiiGuard.carriesIdentity('nous sommes en 2026'), isFalse);
      expect(PiiGuard.carriesIdentity('rendez-vous à 10:30'), isFalse);
      expect(PiiGuard.carriesIdentity('appelle le 3114'), isFalse);
    });

    test('coordonnées célestes et grands nombres', () {
      expect(PiiGuard.carriesIdentity('0.512 0.842 0.900'), isFalse);
      expect(PiiGuard.carriesIdentity('100 000 années-lumière'), isFalse);
      expect(PiiGuard.carriesIdentity('4,24 années pour arriver'), isFalse);
    });

    test('haikus et versions', () {
      expect(
        PiiGuard.carriesIdentity(
          'Poussière d\'étoile / un grain sur l\'aile d\'une nuit / et le temps s\'efface.',
        ),
        isFalse,
      );
      expect(PiiGuard.carriesIdentity('la règle classique depuis v3.12c'), isFalse);
    });
  });
}
