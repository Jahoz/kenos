import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kenos/features/cosmic_map/presentation/widgets/origin_node.dart';

/// V3.26b — the ember's whole box is the target. deferToChild left
/// only the 18 px core tappable: invisible theft on desktop, total
/// theft on phones where the wide gates button sits above. A thumb
/// must find L'Aube by its glow's promise.
void main() {
  testWidgets('un appui au bord de la braise ouvre l\'impact', (tester) async {
    var impactOpened = false;
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(body: Center(child: OriginNode())),
        ),
        GoRoute(
          path: '/impact',
          builder: (context, state) {
            impactOpened = true;
            return const Scaffold(body: SizedBox());
          },
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );
    await tester.pump();

    // The box's very corner — no child widget lives there, only the
    // opaque target. With deferToChild this tap fell through to void.
    final box = tester.getRect(find.byType(OriginNode));
    await tester.tapAt(Offset(box.left + 6, box.top + 6));
    await tester.pumpAndSettle();

    expect(impactOpened, isTrue,
        reason: 'la braise se touche comme elle brille : entière');
    // The stats store runs a 2 s async shim: let it complete before
    // the tree comes down, or its timer outlives the test.
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('l\'appui long au bord ouvre le seuil du gardien', (tester) async {
    var observatoryOpened = false;
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(body: Center(child: OriginNode())),
        ),
        GoRoute(
          path: '/observatoire',
          builder: (context, state) {
            observatoryOpened = true;
            return const Scaffold(body: SizedBox());
          },
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );
    await tester.pump();

    final box = tester.getRect(find.byType(OriginNode));
    await tester.startGesture(Offset(box.right - 6, box.bottom - 6));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(observatoryOpened, isTrue,
        reason: 'la porte cachée vit dans toute la braise, pas son seul cœur');
    // The stats store runs a 2 s async shim: let it complete before
    // the tree comes down, or its timer outlives the test.
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpWidget(const SizedBox());
  });
}
