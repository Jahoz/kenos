import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kenos/features/cosmic_map/presentation/widgets/reveal_sheet.dart';
import 'package:kenos/features/echo/domain/echo.dart';
import 'package:kenos/features/echo/domain/echo_color_theme.dart';
import 'package:kenos/features/echo/domain/echo_media.dart';

// 1x1 baseline JPEG — a real decodable image for the veil.
const _jpegB64 =
    '/9j/4AAQSkZJRgABAQEAYABgAAD/2wBDAAgGBgcGBQgHBwcJCQgKDBQNDAsLDBkSEw8UHRofHh0a'
    'HBwgJC4nICIsIxwcKDcpLDAxNDQ0Hyc5PTgyPC4zNDL/wAALCAABAAEBAREA/8QAFAABAQAAA'
    'AAAAAAAAAAAAP/aAAgBAQABBQJ//8QAFBEBAAAAAAAAAAAAAAAAAAAAAP/aAAgBAgEBPwF//8Q'
    'AFBEBAAAAAAAAAAAAAAAAAAAAAP/aAAgBAwEBPwF//9k=';

Uint8List get _jpegBytes => base64Decode(_jpegB64);

Echo _echo(EchoMediaKind kind) => Echo(
      id: 'veil-test',
      coordX: 0.5,
      coordY: 0.5,
      coordZ: 0.9,
      theme: EchoColorTheme.lumen,
      createdAt: DateTime.now(),
      text: 'texte de test',
      media: EchoMedia(kind: kind, bytes: _jpegBytes),
    );

Future<void> _open(WidgetTester tester, Echo echo) async {
  await tester.pumpWidget(
    MaterialApp(home: Scaffold(body: RevealPanel(echo: echo))),
  );
  await tester.pump(const Duration(milliseconds: 200));
}

void main() {
  group('V3.5 — le fragment arrive voilé', () {
    testWidgets("image : voile à l'ouverture, nette après développement",
        (tester) async {
      await _open(tester, _echo(EchoMediaKind.image));

      // Veiled at rest: the blur filter wraps the image.
      expect(find.byType(ImageFiltered), findsOneWidget,
          reason: "l'image doit arriver floutée");

      // The development runs ~3.5 s.
      await tester.pump(const Duration(milliseconds: 3800));

      expect(find.byType(ImageFiltered), findsNothing,
          reason: "l'image est nette après le développement");
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets("son : SIGNAL BROUILLÉ puis écoute possible", (tester) async {
      await _open(tester, _echo(EchoMediaKind.audio));

      expect(find.text('SIGNAL BROUILLÉ…'), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow), findsNothing,
          reason: 'aucune écoute tant que le voile tient');

      await tester.pump(const Duration(milliseconds: 3800));

      expect(find.text('SIGNAL BROUILLÉ…'), findsNothing);
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    });
  });
}
