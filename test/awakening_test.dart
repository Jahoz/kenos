import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kenos/core/constants/app_colors.dart';
import 'package:kenos/features/cosmic_map/presentation/widgets/origin_node.dart';
import 'package:kenos/features/echo/data/user_stats_store.dart';

UserStats _stats({
  int sent = 0,
  int receptions = 0,
  int seen = 0,
  int stardust = 0,
  DateTime? lastVisit,
}) =>
    UserStats(
      totalEchosSent: sent,
      totalReceptionsReceived: receptions,
      totalTracesLeft: 0,
      seenReceptions: seen,
      stardust: stardust,
      lastVisitAt: lastVisit,
    );

void main() {
  group('L\'Aube — lignes du sas (pures, épinglées)', () {
    test('une réception pendant l\'absence : le sas parle d\'elle', () {
      final stats = _stats(sent: 3, receptions: 5, seen: 4, lastVisit: DateTime.now());
      final lines = stats.awakeningLines();
      expect(lines.first, contains('un de tes échos a touché un inconnu'));
      expect(lines.last, contains('plus loin que tu ne sais'));
    });

    test('plusieurs réceptions : le compte parle', () {
      final stats = _stats(receptions: 9, seen: 4);
      expect(stats.receptionsSinceLastVisit, 5);
      expect(stats.awakeningLines().first, contains('5 de tes échos'));
    });

    test('rien de nouveau mais des échos lancés : ils dérivent, intact', () {
      final stats = _stats(sent: 4, receptions: 2, seen: 2, lastVisit: DateTime.now());
      expect(stats.receptionsSinceLastVisit, 0);
      final lines = stats.awakeningLines();
      expect(lines.first, contains('4 échos dérivent encore'));
      expect(lines.last, contains('Respire'));
    });

    test('premier passage sans rien : invitation douce, pas de silence mort', () {
      final stats = _stats(sent: 0);
      expect(stats.hasAwakeningToTell, isFalse,
          reason: 'rien à dire → le sas reste fermé');
      expect(stats.awakeningLines().single, contains('Commence doucement'));
    });

    test('une constellation touchée fait parler l\'Aube (une fois)', () {
    final stats = _stats(sent: 2, receptions: 2, seen: 2).copyWith(
      constellationsTouched: 1,
      lastVisitAt: DateTime.now(),
    );
    expect(stats.hasAwakeningToTell, isTrue,
        reason: 'le murmure constellation est un signal d\'aube');
    final lines = stats.awakeningLines();
    expect(lines.first, contains('constellation'));
    expect(lines.first, contains('refermée'));
    expect(lines.last, contains('quelqu\'un d\'autre'));
  });

  test('le sas ne se rouvre pas pour ce qui a déjà été vu', () {
      final fresh = _stats(sent: 2, receptions: 3, seen: 3, lastVisit: DateTime.now());
      expect(fresh.receptionsSinceLastVisit, 0);
      // Stardust accumulée + revisite : le seuil hasAwakeningToTell exige
      // du NOUVEAU (réceptions) ou une première visite.
      expect(fresh.hasAwakeningToTell, isFalse);
    });
  });

  group('Stardust — sérialisation et visites', () {
    test('roundtrip json conserve stardust, visites vues, dernier passage', () {
      final when = DateTime(2026, 8, 31, 21);
      final stats = _stats(sent: 7, receptions: 4, seen: 2, stardust: 11)
          .copyWith(lastVisitAt: when);
      final back = UserStats.fromJson(stats.toJson());
      expect(back.stardust, 11);
      expect(back.seenReceptions, 2);
      expect(back.lastVisitAt, when);
    });

    test('copyWith ne perd jamais les champs d\'aube', () {
      final stats = _stats(stardust: 5, seen: 3).copyWith(totalEchosSent: 9);
      expect(stats.stardust, 5);
      expect(stats.seenReceptions, 3);
    });
  });

  group('OriginNode (widget)', () {
    testWidgets('rend le cœur ambre sans planter, motes plafonnées', (
      tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: Scaffold(body: OriginNode()))),
      );
      await tester.pump();
      expect(find.byType(OriginNode), findsOneWidget);
      // Let the stats provider's storage-timeout timer (2 s) fire,
      // then unmount: nothing must outlive the widget tree.
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('l\'ambre n\'est JAMAIS le rose (destruction only)', (
      tester,
    ) async {
      expect(AppColors.ember.toARGB32(), isNot(AppColors.rose.toARGB32()));
      expect(AppColors.emberSoft.toARGB32(), isNot(AppColors.roseText.toARGB32()));
    });
  });
}
