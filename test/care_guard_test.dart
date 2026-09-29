import 'package:flutter_test/flutter_test.dart';
import 'package:kenos/core/care/care_guard.dart';

/// The Care Guard (V3.88): pure lexicon, zero network, WARN never
/// block. These tests pin the two directions the law demands —
/// the real cries of the night must find their theme (however the
/// keyboard wrote the accents), and the everyday words that merely
/// RESEMBLE them must stay silent, or everyone learns to dismiss
/// the hand.
void main() {
  group('CareGuard.themes — les douleurs trouvent leur porte', () {
    test('détresse : suicidalité, franche ou nue', () {
      expect(CareGuard.themes('je veux mourir'), contains(CareTheme.detresse));
      expect(
        CareGuard.themes('parfois j\'en finirais volontiers'),
        contains(CareTheme.detresse),
      );
      expect(
        CareGuard.themes('elle a tenté de se suicider'),
        contains(CareTheme.detresse),
      );
      expect(
        CareGuard.themes('plus envie de rien, honnêtement'),
        contains(CareTheme.detresse),
      );
    });

    test('détresse : automutilation et ponctuation finale', () {
      // "me tue." — la ponctuation ne doit pas casser la frontière.
      expect(
        CareGuard.themes('je vais me tue.'),
        contains(CareTheme.detresse),
      );
      expect(
        CareGuard.themes('je me coupe depuis mars'),
        contains(CareTheme.detresse),
      );
    });

    test('détresse : les accents tapés à 2h du matin', () {
      expect(
        CareGuard.themes('je suis deprimee en ce moment'),
        contains(CareTheme.detresse),
      );
      expect(
        CareGuard.themes('cette dépression ne me lâche pas'),
        contains(CareTheme.detresse),
      );
    });

    test('violences : conjugales, familiales', () {
      expect(
        CareGuard.themes('mon mari me frappe depuis deux ans'),
        contains(CareTheme.violences),
      );
      expect(
        CareGuard.themes('violences conjugales, encore une nuit'),
        contains(CareTheme.violences),
      );
      expect(
        CareGuard.themes('mon père était violent avec moi'),
        contains(CareTheme.violences),
      );
    });

    test('agression : le mot juste, sans confusion', () {
      expect(
        CareGuard.themes('j\'ai subi un viol'),
        contains(CareTheme.agression),
      );
      expect(
        CareGuard.themes('il m\'a violée'),
        contains(CareTheme.agression),
      );
      expect(
        CareGuard.themes('agression sexuelle hier soir'),
        contains(CareTheme.agression),
      );
      expect(
        CareGuard.themes('c\'était sans mon consentement'),
        contains(CareTheme.agression),
      );
    });

    test('enfance : inceste, prédation', () {
      expect(
        CareGuard.themes('l\'inceste dans ma famille'),
        contains(CareTheme.enfance),
      );
      expect(
        CareGuard.themes('mon oncle, pédophile, me cherchait'),
        contains(CareTheme.enfance),
      );
    });

    test('un texte peut porter plusieurs thèmes — toutes les portes s\'ouvrent', () {
      // La survivante adulte trouve l'agression et la détresse ; le 119
      // (enfance EN danger, présent) n'est pas sa porte — le lexique
      // ne la lui impose pas.
      final themes = CareGuard.themes(
        'mon père me violait quand j\'étais petite, je veux mourir',
      );
      expect(themes, containsAll(<CareTheme>{CareTheme.detresse, CareTheme.agression}));
      expect(themes, isNot(contains(CareTheme.enfance)));
    });

    test('anglais (premier parcours web) : les mêmes douleurs', () {
      expect(
        CareGuard.themes('I want to kill myself'),
        contains(CareTheme.detresse),
      );
      expect(
        CareGuard.themes('my husband beats me'),
        contains(CareTheme.violences),
      );
      expect(
        CareGuard.themes('I was raped'),
        contains(CareTheme.agression),
      );
      expect(
        CareGuard.themes('incest, and nobody believed me'),
        contains(CareTheme.enfance),
      );
    });
  });

  group('CareGuard.themes — les faux positifs restent muets', () {
    test('violon : le cousin du violoncelle n\'invoque rien', () {
      expect(CareGuard.themes('je joue du violon ce soir'), isEmpty);
      expect(CareGuard.themes('un concerto pour violon'), isEmpty);
    });

    test('la météo violente n\'est pas la violence', () {
      expect(CareGuard.themes('un violent orage sur Calais'), isEmpty);
      expect(CareGuard.themes('la mer était violente'), isEmpty);
      expect(CareGuard.themes('de violentes rafales'), isEmpty);
    });

    test('tuer le temps n\'est pas se tuer', () {
      expect(CareGuard.themes('ce livre a tué le temps'), isEmpty);
      expect(CareGuard.themes('on a tué l\'ennui ensemble'), isEmpty);
    });

    test('grape n\'est pas rape', () {
      expect(CareGuard.themes('grapes in the basket'), isEmpty);
    });

    test('les mots du quotidien passent sans se lever', () {
      expect(CareGuard.themes('le vent dans l\'absinthe'), isEmpty);
      expect(CareGuard.themes('on boit des coups vendredi'), isEmpty);
      expect(CareGuard.themes('une pensée pour la nuit'), isEmpty);
      expect(CareGuard.themes(''), isEmpty);
      expect(CareGuard.themes('ok'), isEmpty);
    });
  });
}
