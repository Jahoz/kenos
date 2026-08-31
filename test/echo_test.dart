import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kenos/features/echo/domain/echo.dart';
import 'package:kenos/features/echo/domain/echo_color_theme.dart';
import 'package:kenos/features/echo/domain/echo_media.dart';

void main() {
  Echo buildEcho({bool isMine = false, DateTime? createdAt}) => Echo(
    id: 'abc',
    coordX: 0.5,
    coordY: 0.5,
    coordZ: 0.6,
    theme: EchoColorTheme.indigo,
    createdAt: createdAt ?? DateTime(2026, 1, 1),
    isMine: isMine,
  );

  group('Echo', () {
    test('sérialisation locale SANS le texte (scellement irréversible)', () {
      final echo = buildEcho(isMine: true).copyWith(text: 'mon secret');
      final json = echo.toJson();
      expect(json.containsKey('text'), isFalse);
      expect(json.containsKey('encrypted_text'), isFalse);

      final restored = Echo.fromJson(json, isMine: true);
      expect(restored.text, isNull);
      expect(restored.isMine, isTrue);
      expect(restored.theme, EchoColorTheme.indigo);
    });

    test('un écho lu porte son texte, un écho de carte jamais', () {
      expect(buildEcho().text, isNull);
      expect(buildEcho().copyWith(text: 'révélé').text, 'révélé');
    });

    test('resolveZ : les échos propres dérivent, les autres restent fixes', () {
      final now = DateTime(2026, 1, 1, 5);
      final mine = buildEcho(isMine: true).copyWith(text: null);
      final theirs = buildEcho();

      expect(theirs.resolveZ(now), 0.6);
      expect(mine.resolveZ(now), lessThan(1.0)); // 5h of drift
    });
  });

  group('EchoColorTheme', () {
    test('parse le wire format avec fallback sûr', () {
      expect(EchoColorTheme.fromWire('INDIGO'), EchoColorTheme.indigo);
      expect(EchoColorTheme.fromWire('LUMEN'), EchoColorTheme.lumen);
      expect(EchoColorTheme.fromWire('CORROMPU'), EchoColorTheme.teal);
      expect(EchoColorTheme.fromWire(null), EchoColorTheme.teal);
    });

    test('seuls TEAL, INDIGO, LUMEN sont sélectionnables', () {
      expect(EchoColorTheme.selectable.map((t) => t.wire).toSet(), {
        'TEAL',
        'INDIGO',
        'LUMEN',
      });
    });
  });

  group('EchoMediaDraft', () {
    test('la photo est bornée à 1 MiB avant tout envoi', () {
      final accepted = EchoMediaDraft(
        kind: EchoMediaKind.image,
        name: 'fragment.jpg',
        bytes: Uint8List(EchoMediaKind.image.maxBytes),
      );
      final rejected = EchoMediaDraft(
        kind: EchoMediaKind.image,
        name: 'trop-lourd.jpg',
        bytes: Uint8List(EchoMediaKind.image.maxBytes + 1),
      );

      expect(accepted.isWithinLimit, isTrue);
      expect(rejected.isWithinLimit, isFalse);
    });

    test('l\'audio est borné à 512 KiB avant tout envoi', () {
      final accepted = EchoMediaDraft(
        kind: EchoMediaKind.audio,
        name: 'fragment.m4a',
        bytes: Uint8List(EchoMediaKind.audio.maxBytes),
      );
      final rejected = EchoMediaDraft(
        kind: EchoMediaKind.audio,
        name: 'trop-lourd.m4a',
        bytes: Uint8List(EchoMediaKind.audio.maxBytes + 1),
      );

      expect(accepted.isWithinLimit, isTrue);
      expect(rejected.isWithinLimit, isFalse);
    });
  });
}
