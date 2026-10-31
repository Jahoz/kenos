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

## 2026-10-21 - kenos - La révélation lit, le backlog respire (PR #26 + #27, gabarit Sentry)

- **PR #26 — V3.91 « reading reads, fate decides after »** : la
  simplification du flux de lecture arbitrée par Hugo le 10/10.
  Le panneau de lecture ne porte PLUS que le texte, son voile et son
  compte à rebours ; le destin (RELANCER / REPOSER / signaler)
  se décide APRÈS la dissolution. La suite reveal_fall a été
  réalignée en 4 fix (le phénix voyage le vrai éther démo, le
  rideau se pompe avant le verdict, la garde 2 s du store se
  franchit, le refus laisse aussi une chute).
- **PR #27 — le backlog corpus entier** : d04b89a, un `;` dans un
  commentaire découpait le fichier à la moitié — le corpus charge
  maintenant en entier via filemulti.
- **1c55f62 — gabarit Sentry** : `#SENTRY_DSN=` commenté dans
  env.cloud.example (télémétrie crash seulement, absent = no-op,
  rien d'autre collecté — la loi tient).

2026-10-21 | kenos | V3.91 reveal simplifié + backlog corpus entier + gabarit Sentry (PR #26, #27, 1c55f62) | 526 tests verts, analyze 0 | stop : none — la chasse au saut en arrière reste ouverte

## 2026-10-25 - kenos - La télémétrie réparée : le HUD V3.92 compile, la chasse au saut en arrière continue

- Le wip nocturne du 25/10 (HUD de diagnostic V3.92) était né cassé :
  sept champs d'état déclarés dans _ParallaxStarLayerState alors que
  _MapScreenState les référence — la suite entière ne compilait plus.
  Réparé dans la journée : champs remontés au plus près de _camera,
  les deux champs morts (_telemetryPrevAt, _telemetryWord) TRANCHÉS
  (retirés — le HUD n'a pas besoin d'une mémoire, il lit les deltas
  à chaque rebuild), analyze 0 + 526 tests verts.
- **Le HUD reste** : tap 4 doigts sur la carte → la ligne HUD affiche
  les deltas Z (zoom) / T (tilt) / C (centre caméra) depuis la
  dernière lecture. Au prochain saut en arrière, le coupable se
  nomme lui-même — la 5e correction sera chirurgicale.
- **V3.92b au passage** : le hover de « SIGNALER CE POÈME » ne
  claque plus pleine largeur (Align + wrap, le geste civique reste
  discret). Déployé (kenos-efkgvmmql).

2026-10-25 | kenos | HUD télémétrie V3.92 réparé (compile, 526 verts) + hover signaler discret | outillage de diagnostic, aucun test exigé | stop : la lettre du coupable (Z/T/C) lue par Hugo au prochain saut

## 2026-10-29 - kenos - CCC-04 : le balayage dit son nom — le ciel est immobile, le boot démo était mort

- **La contradiction** (PRÊT le 25/10 vs « animation persiste » 27-28/10)
  balayée à la mesure, pas au ressenti : le ciel au repos est IMMOBILE —
  déployé (81 s, 119 deltas, max 0,5 px) comme local démo (55 s, 83
  deltas, max 0,6 px), zéro renversement de direction. Protocole et
  chiffres : `docs/ANIMATION_SWEEP_CCC-04.md`.
- **Non-lieu honnête sur le geste** : dans le navigateur outillé, aucun
  pointeur (souris/molette/touch) n'atteint le canvas Flutter — pan et
  pinch restent injugés ici. Le HUD V3.92 (4 doigts) reste l'outil prévu ;
  la PR porte la liste à cocher Z/T/C pour qu'Hugo lise enfin la lettre
  du coupable. Seul site code restant capable d'un saut périodique :
  `TravelCamera.attach` re-clampe zoom+centre quand le viewport oscille
  (barre d'URL mobile) — le HUD le dirait (Z et C ensemble).
- **Trouvé à la place, corrigé** : le boot sans SENTRY_DSN crachait
  « DSN is required. » avant le premier cadre (sentry 9.30 jette sur
  DSN null — le « no-op absent » promis par PWW-04 n'a jamais existé).
  Depuis le 20/10, la PWA démo locale et tout `make dev-local`
  mouraient au boot ; seul le déployé vivait (DSN dans .env.cloud).
  Garde posée dans `main()` (sans DSN → `bootstrap()` direct),
  preuve épinglée par `boot_sentry_guard_test.dart`.

2026-10-29 | kenos | balayage CCC-04 : repos immobile (déployé+local), saut non reproduit faute de geste traversant, question Z/T/C posée ; fix boot sans DSN + test | PR vague/CCC-04 | stop : la case cochée par Hugo (Z+C / T / rien) décide de la 5e correction

## 2026-10-31 - kenos - La ligne du temps J-9 → J-0 posée dans le kit (PFFF-05)

- **Le constat** : à J-9 du lancement (09/11), les trois gestes humains
  vivaient dispersés — la lettre Z/T/C dans
  `docs/ANIMATION_SWEEP_CCC-04.md`, le semis J-0 au § 1 du kit, la
  diffusion aux §§ 4–6. Rien ne disait « qui fait quoi quand » sur une
  seule ligne du temps.
- **La section 1bis** (`docs/LAUNCH_KIT.md`) : une entrée par jour qui
  compte — J-9 la lettre (Hugo, au prochain saut visible), J-8 la
  décision qu'elle déclenche (5e correction ou statu quo, les trois
  issues dites : viewport / parallaxe capteur / étoiles), J-7→J-2 les
  préparatifs doux, J-1 la veille au calme (fenêtre dernière de la
  correction, smoke nocturne), J-0 le semis + prod-check + diffusion.
  Chaque ligne : qui, quoi, le renvoi à sa section — zéro duplication.
- **Le calendrier réconcilié en une phrase** : 09/11 est un LUNDI —
  l'artefact du jour naît seul à 06:45 UTC (§ 3), et les fenêtres
  Show HN / presse (mardi/mercredi, §§ 4–5) suivent le semis du matin
  exactement comme le § 1 l'avait arbitré (« juste avant l'afflux »).

2026-10-31 | kenos | ligne du temps J-9 → J-0 posée au § 1bis du kit (PFFF-05, vague FFF de portfolio-os) : lettre → décision → semis J-0, reliés sans duplication | docs/LAUNCH_KIT.md, MILESTONE_LOG | stop : PR vague/FFF-05 attend le go ; la lettre Z/T/C reste LE geste en attente (A-9)
