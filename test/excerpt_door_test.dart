import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kenos/features/cosmic_map/presentation/widgets/reveal_sheet.dart';
import 'package:kenos/features/echo/domain/echo.dart';
import 'package:kenos/features/echo/domain/echo_color_theme.dart';
import 'package:kenos/features/echo/domain/echo_excerpt.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

/// Captures the door's launch — the federated plugins never register
/// inside a test VM, so the platform interface is faked here.
class _DoorLauncher extends UrlLauncherPlatform {
  String? launchedUrl;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launchedUrl = url;
    return true;
  }

  @override
  Future<bool> canLaunch(String url) async => true;

  @override
  Widget Function(LinkInfo)? get linkDelegate => null;
}

/// V3.10 — the door in the reveal window: veiled like every fragment,
/// opened OUTSIDE the void (deep link), and the launched URL is always
/// the canonical one — never a raw reference.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const songDoor = EchoExcerpt(
    kind: EchoExcerptKind.song,
    id: '4cOdK2wGLETKBW3PvgPWqT',
  );

  Echo doorEcho(EchoExcerpt door) => Echo(
        id: 'door-test',
        coordX: 0.5,
        coordY: 0.5,
        coordZ: 0.9,
        theme: EchoColorTheme.teal,
        createdAt: DateTime.now(),
        text: 'un texte qui brûlera',
        excerpt: door,
      );

  Future<void> open(WidgetTester tester, Echo echo) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(home: Scaffold(body: RevealPanel(echo: echo))),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
  }

  testWidgets('la porte arrive voilée, puis s\'offre', (tester) async {
    await open(tester, doorEcho(songDoor));

    expect(find.text('SIGNAL BROUILLÉ…'), findsOneWidget);
    expect(find.text('OUVRIR LA PORTE'), findsNothing,
        reason: 'aucune porte tant que le voile tient');

    await tester.pump(const Duration(milliseconds: 3800));

    expect(find.text('SIGNAL BROUILLÉ…'), findsNothing);
    expect(find.text('EXTRAIT MUSICAL'), findsOneWidget);
    expect(find.text('OUVRIR LA PORTE'), findsOneWidget);
  });

  testWidgets('ouvrir la porte lance l\'URL canonique, hors du vide',
      (tester) async {
    final launcher = _DoorLauncher();
    UrlLauncherPlatform.instance = launcher;

    await open(tester, doorEcho(songDoor));
    await tester.pump(const Duration(milliseconds: 3800));

    await tester.tap(find.text('OUVRIR LA PORTE'));
    await tester.pump(const Duration(milliseconds: 100));

    expect(launcher.launchedUrl, songDoor.doorUrl.toString());
    expect(
      launcher.launchedUrl,
      startsWith('https://open.spotify.com/track/'),
    );
  });

  testWidgets('une porte vidéo affiche le bon genre', (tester) async {
    await open(
      tester,
      doorEcho(
        const EchoExcerpt(
          kind: EchoExcerptKind.video,
          id: 'jfKfPfyJRdk',
          startSeconds: 90,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 3800));

    expect(find.text('EXTRAIT VIDÉO'), findsOneWidget);
  });
}
