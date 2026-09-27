import 'package:flutter_test/flutter_test.dart';
import 'package:kenos/core/voice/kenos_voice.dart';
import 'package:kenos/features/create_echo/application/seal_echo.dart';
import 'package:kenos/features/echo/data/echo_repository.dart';

/// The Mirror's use case (audit 2026-09-23): the send gate, the PII
/// gate, the launch-failure voice and the cultural door's verdict —
/// pure decisions, tested as objects (they used to be inline screen
/// state nobody could reach).
void main() {
  group('SealEcho.canSend — the seal arms honestly', () {
    test('a secret arms it, blank spaces do not', () {
      expect(SealEcho.canSend(text: 'je porte un secret'), isTrue);
      expect(SealEcho.canSend(text: '   \n  '), isFalse);
      expect(SealEcho.canSend(text: ''), isFalse);
    });

    test('a fragment or a door may carry the echo alone', () {
      expect(SealEcho.canSend(text: '', hasMedia: true), isTrue);
      expect(SealEcho.canSend(text: '', hasExcerpt: true), isTrue);
      expect(SealEcho.canSend(text: ''), isFalse);
    });

    test('the ceiling is hard: 280 passes, 281 never', () {
      expect(SealEcho.canSend(text: 'a' * 280), isTrue);
      expect(SealEcho.canSend(text: 'a' * 281), isFalse);
      // A fragment does NOT buy room for an overlong secret.
      expect(SealEcho.canSend(text: 'a' * 281, hasMedia: true), isFalse);
    });
  });

  group('PiiGate — the last quiet look, once per secret', () {
    test('identity in the text asks the question', () {
      expect(SealEcho.needsPiiWarning('appelle-moi au 06 83 07 74 84'),
          isTrue);
      expect(SealEcho.needsPiiWarning('mon mail est moi@exemple.fr'), isTrue);
      expect(SealEcho.needsPiiWarning('rien de personnel ici'), isFalse);
    });

    test('acknowledged once, never asked again for the same draft', () {
      final gate = PiiGate();
      const text = 'je t\'écris depuis moi@exemple.fr';
      expect(gate.shouldWarn(text), isTrue);
      gate.acknowledge();
      expect(gate.shouldWarn(text), isFalse,
          reason: 'l\'auteur a choisi : la même pensée ne redemande pas');
      // A different gate (another draft) asks again.
      expect(PiiGate().shouldWarn(text), isTrue);
    });

    test('a clean text never opens the warning', () {
      final gate = PiiGate();
      expect(gate.shouldWarn('aucune donnée'), isFalse);
      gate.acknowledge(); // acknowledging nothing changes nothing
      expect(gate.shouldWarn('toujours rien'), isFalse);
    });
  });

  group('SealEcho.launchFailureMessage — the failure says its name', () {
    test('the rate limit has its own remedy', () {
      expect(
        SealEcho.launchFailureMessage(
          const KenosException(KenosErrorCode.rateLimit),
          KenosVoice.french,
        ),
        contains('20 SECONDES'),
      );
      expect(
        SealEcho.launchFailureMessage(
          const KenosException(KenosErrorCode.rateLimit),
          KenosVoice.english,
        ),
        contains('20 SECONDS'),
      );
    });

    test('functional refusals speak their HUD message', () {
      expect(
        SealEcho.launchFailureMessage(
          const KenosException(KenosErrorCode.invalid),
          KenosVoice.french,
        ),
        'CET ÉCHO EST MALFORMÉ.',
      );
      expect(
        SealEcho.launchFailureMessage(
          const KenosException(KenosErrorCode.braisePassed),
          KenosVoice.french,
        ),
        contains('BRAISE'),
      );
    });

    test('anything else is the ether refusing, said plainly', () {
      expect(
        SealEcho.launchFailureMessage(Exception('SocketException'), KenosVoice.french),
        'L\'ÉTHER A REFUSÉ L\'ÉCHO.',
      );
      expect(
        SealEcho.launchFailureMessage(Exception('SocketException'), KenosVoice.english),
        'THE ETHER REFUSED THE ECHO.',
      );
    });
  });

  group('SealEcho.excerptVerdict — the cultural door closes honestly', () {
    test('a parsed link is kept', () {
      expect(
        SealEcho.excerptVerdict(
          pasted: 'https://open.spotify.com/track/4cOdK2wGLETKBW3PvgPWqT',
          parsed: Object(),
        ),
        ExcerptDoorVerdict.keep,
      );
    });

    test('an empty cancelled dialog is renouncement, not failure', () {
      expect(
        SealEcho.excerptVerdict(pasted: '', parsed: null),
        ExcerptDoorVerdict.renounce,
      );
      expect(
        SealEcho.excerptVerdict(pasted: '   ', parsed: null),
        ExcerptDoorVerdict.renounce,
      );
    });

    test('a pasted unparseable link is the only scolded case', () {
      expect(
        SealEcho.excerptVerdict(pasted: 'https://exemple.fr', parsed: null),
        ExcerptDoorVerdict.malformed,
      );
    });
  });
}
