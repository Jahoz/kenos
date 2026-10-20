# Milestone Log

Format ligne:

`YYYY-MM-DD | projet | milestone | scope livré | next stop condition`

---

## 2026-10-20 - kenos - Durci pour le jour J : l'e2e tourne vraiment, les crashes seront vus

- **PWW-04** (vague WW du portfolio-os, go Hugo 20/10 ; lancement cible
  le 9/11) — le durcissement structurel qui vaut quelle que soit la date :
  - **E2e réel en CI** : le job « migrations + pgTAP » se terminait par un
    `bash -n` — un contrôle SYNTAXIQUE. La régression V3.11a
    (constellations vides en PROD, CI verte) avait été attrapée par un œil
    humain, pas par la CI. `scripts/e2e_local.sh` (la boucle
    bouteille-en-mer complète : deux anonymes, triche mesures, salons)
    s'exécute maintenant DANS ce job, sur la stack déjà debout (aucune
    collision de ports), après pgTAP ; stack muette = sauté avec la raison
    affichée en warning — jamais un `bash -n` à la place.
  - **Crash reporting** : `sentry_flutter` 9.30.1 (la 10 exige Flutter
    ≥3.44, le projet épingle 3.41.6), initialisé au boot AVANT tout le
    reste, `appRunner` embarquant tout le démarrage dans la zone de
    capture. DSN par `--dart-define=SENTRY_DSN` — absent (tout build
    local, toute CI) : no-op propre, zéro réseau. Crash et rien d'autre :
    pas de tracing, pas de sessions, `sendDefaultPii = false`. Geste
    restant côté Hugo : créer le projet Sentry, poser le secret GitHub
    `SENTRY_DSN` et la ligne dans `.env.cloud` (le Makefile `deploy-web`
    transmet déjà chaque entrée en `--dart-define`).
  - **Racine rangée** : 6 captures + le dernier log sights (28/09)
    archivés dans `docs/assets/` (v380-arrival + hold_state = matière
    kit), `/*.png` et `/sights_log*` ignorés à la racine, octets
    identiques aux sauvegardes (sha vérifiés).
  - **Branches jugées** : `audit-2026-09-23`, `audit-pur`,
    `ia/8445cdf4-j-aimerai-voir-passer` (les trois mergées dans main)
    supprimées ; `wip/sauvegarde-0810` supprimée (locale + origin) — son
    contenu entier était exactement les 10 fichiers wip de la racine,
    préservés dans ce chantier sous meilleure forme.
- **Doc alignée sur ce qui existe** : `make prod-sow` est RETIRED
  (arbitrage Hugo 29/09) — CLAUDE.md et LAUNCH_KIT.md le disaient encore
  actif ; le kit de lancement parle maintenant des vestiges comme
  nourriture du ciel.

2026-10-20 | kenos | durcissement jour J (PWW-04) : e2e réel en CI + Sentry no-op-safe + racine rangée + branches jugées + doc alignée | ci.yml, main.dart, pubspec, docs/assets/, MILESTONE_LOG né | stop : PR vague/WW-04 attend le go ; geste Sentry (projet + secret SENTRY_DSN + .env.cloud) côté Hugo

---

## 2026-10-13 - kenos - Le quintuple smoke-prod : cinq nuits vertes d'affilée (consigné le 20/10)

- Les nuits du 01/10 au 08/10 avaient ouvert **8 issues** « smoke prod
  FAIL » : le smoke exigeait de la landing un 301 vers l'app, une
  posture que le site avait quittée. Le fix 97a1003 (08/10, « the
  landing lives — smoke watches what it IS ») a appris au smoke à
  regarder ce qui existe — les 8 issues fermées le soir même.
- Depuis : **vert chaque nuit**. Le run du **13/10 05:42:19Z** (run
  38352763606, 29 s, `41 ✓ / 0 ✗`) est le **cinquième vert
  consécutif** — la preuve que le fix tient, pas un accident isolé.
- Au moment de la consignation (20/10), la série est à **12 nuits
  vertes** d'affilée (dernier run : 20/10 05:39Z, 26 s). Le veilleur
  fait son métier : ce que V3.11a avait enseigné à un œil humain, le
  smoke le voit maintenant chaque nuit.

2026-10-13 | kenos | smoke-prod : 5e nuit verte consécutive (05:42Z, 29 s, 41 ✓ / 0 ✗) après 8 échecs corrigés par 97a1003 | série à 12 verts au 20/10 | stop : aucune — le cron veille
