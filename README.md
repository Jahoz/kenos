# 🌌 KENOS

![ci](https://github.com/Jahoz/kenos/actions/workflows/ci.yml/badge.svg)

> *Du grec **kénose** : se vider de soi-même.*

KENOS est l'anti-réseau social : un sanctuaire numérique de décharge cognitive.
On y formule une pensée intime, un aveu, un doute — et on la lance dans un éther
cosmique anonyme. **Un seul être humain pourra jamais la lire.** Dès sa première
lecture, elle s'autodétruit.

- **Zéro validation** : pas de profil, pas de likes, pas de commentaires, pas de feed.
- **Friction as a feature** : lire un écho exige un appui long de 3 secondes (*Mindful Hold*).
- **Éphémère absolu** : 10 secondes de fenêtre de lecture, puis dissolution.
- **Dark Introspection** : Void Black `#030508`, serif Playfair Display pour
  l'humain, Space Mono pour la machine.

---

## La bouteille à la mer (traces de réception)

Pas de discussion — mais le **signal qu'on a touché quelqu'un** :

- Quand un écho est intercepté, son auteur reçoit une **réception** : durée de
  dérive et distance parcourue dans le vide (à la vitesse du vide — poétique).
- Le lecteur peut, après le burn, laisser **une trace** : une ligne, 140
  caractères max, une seule, sans réponse possible. Le silence est aussi une
  réponse (~1 réception sur 3 n'a pas de trace, en démo).
- L'auteur consulte le signal en touchant son étoile scellée (qui **pulse** en
  attente). **Voir = brûler** : le signal n'existe qu'une fois, comme l'écho.
- Côté serveur : `kenos_receptions` (sans contenu par défaut), RPC `leave_trace`
  (fenêtre de 10 min après lecture, one-shot), `fetch_receptions` / `burn_reception`.

## Démarrage rapide (mode démo, sans backend)

```bash
cd ~/Developer/projects/kenos
flutter pub get
flutter run   # iOS simulator, Android, macOS…
```

Sans identifiants Supabase, l'app démarre en **MODE DÉMO LOCAL** : un éther
simulé d'une douzaine d'échos, avec la sémantique exacte du backend (lecture
unique atomique incluse). Idéal pour découvrir l'expérience.

## Convention portfolio

- Projet enregistré dans [`../LOCAL_DEV_PORTS.json`](../LOCAL_DEV_PORTS.json)
  (id 17 — app Flutter + bloc ports Supabase dédié `56321-56324`).
- Identité de design : entrée `kenos` dans
  [`../portfolio-os/PROJECT_DESIGN_REGISTRY.md`](../portfolio-os/PROJECT_DESIGN_REGISTRY.md).
- Jalons : [`../portfolio-os/MILESTONE_LOG.md`](../portfolio-os/MILESTONE_LOG.md).

## Brancher le vrai éther (Supabase)

1. Créer un projet sur [supabase.com](https://supabase.com).
2. Lier le projet puis appliquer **toutes** les migrations (11 à ce
   jour — échos, réceptions, Ether Seal, culling, fréquences,
   signalements, médias, purge consolidée, sling-shot, lignage,
   constellations, extraits) :

```bash
supabase link --project-ref <ref>
supabase db push
```

   (Équivalent manuel : exécuter chaque fichier de
   [`supabase/migrations/`](supabase/migrations/) dans l'ordre dans le
   SQL Editor.)
3. (Optionnel, purge des échos dérivants) activer l'extension `pg_cron`
   puis décommenter le bloc cron livré **prêt à l'emploi** en fin de
   migration 0004 (`kenos-purge`, quotidien à 03:17 UTC).
3bis. (Optionnel, la voix dans le vide — V3.10b') pour que les portes
   musicales proposent un extrait Spotify de 30 s dans la fenêtre de
   lecture : créer une app sur [developer.spotify.com](https://developer.spotify.com)
   (client credentials) puis

```bash
supabase secrets set SPOTIFY_CLIENT_ID=xxx SPOTIFY_CLIENT_SECRET=yyy
supabase functions deploy door-preview
```

   Sans ces secrets, tout continue de fonctionner : la porte seule
   demeure (deep-link vers Spotify/YouTube).
4. Lancer l'app avec les identifiants (Project Settings → API) :

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJhbGciOi...
```

Le HUD affiche alors `KENOS // LIAISON ÉTABIE`. L'authentification est
**anonyme et silencieuse** (`signInAnonymously`) : aucune donnée personnelle.

## Tester l'app (trois canaux)

| Canal | Commande | Note |
|-------|----------|------|
| **PWA (web)** | `flutter build web --release` puis servir `build/web` sur **:4308** | Installable comme PWA (manifest + icônes + service worker). Démo locale : http://localhost:4308 |
| **Android** | `flutter emulators --launch Medium_Phone_API_36.1` puis `flutter run -d emulator-5554` | APK debug installable directement (`flutter build apk --debug`) |
| **iOS** | `flutter run -d <simulateur>` | Xcode 26.6 présent — **runtime simulateur à télécharger** (Xcode → Settings → Platforms, ou `xcodebuild -downloadPlatform iOS`) |

Le **mini-site de présentation** (avec démo interactive du Mindful Hold en pure HTML/JS)
vit dans `site/` — servi sur **:4307**. Copie du pitch deck d'origine, restylée dans
l'identité Cosmic Zen du produit.

Icônes régénérables : `python3 tool/gen_icons.py` (Web PWA + mipmap Android + asset
catalog iOS, pur stdlib).

## Qualité

```bash
make analyze     # flutter analyze — 0 issue
make test        # 162 tests Dart : chiffrement, culling, contrôleurs, parcours UI
make db-test     # 96 invariants SQL (pgTAP) : RPC + tentatives d'effraction RLS
make e2e         # boucle complète sur le PostgREST local réel (18 vérifications)
```

Le test `app_flow_test.dart` rejoue le parcours réel : seuil → carte →
Mindful Hold 3 s → révélation → burn 10 s → dissolution → retrait de l'étoile.
CI (GitHub Actions) : analyze + tests, build web (compile le shader GLSL),
et job SQL qui applique les migrations sur une stack locale vierge avant
de lancer pgTAP — c'est lui qui aurait attrapé le bug de `search_path`
avant tout branchement réel.

Documentation interne : [`docs/SECURITY.md`](docs/SECURITY.md) (modèle de
menace, frontières de confiance de l'Ether Seal),
[`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) (graphe de providers, ADR)
et [`CONTRIBUTING.md`](CONTRIBUTING.md) (règles, commandes, carte des tests).

---

## Architecture (feature-first, Clean simplifiée)

```
lib/
┣ core/
┃ ┣ constants/         # Void Black, Teal, Rose… typographies, durées
┃ ┣ theme/             # DarkTheme strict (pas de boutons Material criards)
┃ ┣ utils/             # ParallaxMath, LowPassFilter, préférences de mouvement
┃ ┣ audio/             # AudioController : drone 70 Hz + cloches pentatoniques
┃ ┣ haptics/           # KenosPulse : vocabulaire haptique, fire-and-forget
┃ ┗ widgets/           # ScrambleText (théâtre de sécurité), EtherDissolve (shader)
┣ app/                 # KenosApp, routeur go_router (tout en fondu)
┣ features/
┃ ┣ onboarding/        # Le seuil : trois règles, une porte
┃ ┣ echo/
┃ ┃ ┣ domain/          # Echo, EchoColorTheme, EchoCipher (AES-256-GCM)
┃ ┃ ┗ data/            # EchoRepository (contrat), Supabase, démo local,
┃ ┃                    # store scellé, SectorGrid (culling 8×8)
┃ ┣ cosmic_map/
┃ ┃ ┣ application/     # MapController (AsyncNotifier), MotionService (parallaxe)
┃ ┃ ┗ presentation/    # MapScreen, MindfulHoldStar, painters, RevealSheet
┃ ┗ create_echo/       # Le Miroir : formulation, scellement, lancement
┗ main.dart            # Bootstrap : secure storage → Supabase optionnel → runApp
shaders/               # ether_dissolve.frag — dispersion en particules réelles
```

### Le cœur du réacteur : `consume_echo`

La lecture unique est **atomique côté serveur** (`FOR UPDATE SKIP LOCKED`) :
deux humains maintenant la même étoile à la même milliseconde — un seul gagne,
l'autre voit `CET ÉCHO S'EST DISSOUS AILLEURS`. Le test
`local_echo_repository_test.dart` vérifie cette propriété avec 8 lectures
concurrentes.

### La parallaxe

L'accéléromètre (vecteur gravité → inclinaison, plus stable que le gyroscope)
est filtré par un passe-bas (α = 0,08). Le déplacement de chaque étoile est
**proportionnel à sa profondeur** (`offset = tilt × amplitude × z`) : les objets
proches suivent la main, le fond stellaire demeure. Sans capteurs (web, macOS,
simulateur), une dérive sinusoïdale lente prend le relais — l'espace reste vivant.

### Le son

`tool/gen_audio.py` synthétise tous les assets (aucune dépendance) :
un drone 70 Hz bouclé **sans couture auditive** (fréquences = multiples entiers
de 1/durée, LFO à cycle entier) et quatre cloches pures pentatoniques
(Mi5 sceller, Sol5 envoyer, Do6 révéler, La3 brûler). Pendant le Mindful Hold,
le **pitch du drone monte de 1.0 à 1.5** avec l'anneau de charge — et redescend
si l'on relâche.

---

## Améliorations apportées au CDC initial

1. **Fuite majeure corrigée** : le CDC prévoyait une politique RLS
   `FOR SELECT USING (auth.uid() != author_id)` sur la table `echoes` — ce qui
   exposait `encrypted_text` à **tous** les clients. Désormais la table est
   totalement opaque (`REVOKE ALL` + aucune politique SELECT) et la carte lit
   une **vue `echoes_map` sans aucune colonne de texte**.
2. **RPC durcis** : `SET search_path` sur les fonctions `SECURITY DEFINER`
   (anti-hijack), garde `author_id <> auth.uid()` dans `consume_echo` (on ne
   peut pas intercepter son propre écho, même avec un client modifié),
   journal `kenos_reads` = audit sans contenu + anti-spam (1 lecture / 5 s).
3. **Envoi validé côté serveur** : `launch_echo` vérifie longueur (≤ 280),
   bornes des coordonnées, thème, et cadence (1 écho / 20 s).
4. **Formule de parallaxe corrigée** : le CDC proposait `1/z` en facteur —
   ce qui faisait bouger le fond plus que le premier plan, l'inverse de la
   parallaxe réelle. Le déplacement est désormais proportionnel à `z`.
5. **Scellement intégral** : l'écho envoyé est stocké localement **sans son
   texte** — même son auteur ne peut plus le relire. On donne pour se libérer.
6. **Résilience** : mode démo hors-ligne, timeouts d'E/S trousseau (jamais de
   gel UI), audio strictement non-bloquant, fallback capteurs, couche audio
   fautive tolérante.
7. **ROSE interdit à la création** : la couleur de destruction est réservée
   à la destruction, jusque dans la validation SQL.
8. **Ether Seal (chiffrement réel au repos)** : le texte est chiffré sur
   l'appareil de l'auteur (AES-256-GCM, clé éphémère de 256 bits dérivée
   par écho) avant de partir dans l'éther. La clé voyage scellée
   (`key_seal`, KEK logée dans Supabase Vault quand disponible) et
   n'est échangée qu'à l'interception, dans la transaction atomique qui
   détruit l'écho. Un dump de la base ne contient que du chiffré ; le
   prix assumé de l'E2E : le serveur borne la taille scellée (≤ 4000),
   la ligne de 280 caractères reste garantie par le client.
9. **Culling par secteur** : `fetch_map_sector` (grille 8×8, 24 échos
   max par secteur, 400 au total, plus récents d'abord) — un quartier
   dense n'affame jamais un quartier calme. Le mode démo applique les
   mêmes constantes (`SectorGrid`).
10. **Purge de l'éther** : `kenos_purge()` détruit les échos dérivant
    depuis plus de 30 jours, le journal d'audit au-delà d'un jour et les
    réceptions non lues au même horizon — câblage `pg_cron` livré prêt,
    commenté, dans la migration.
11. **Haptique et accessibilité** : vocabulaire haptique dédié
    (battement du hold, deuil du burn, signal de réception…) qui respecte
    « réduire les animations » : le mouvement décoratif se fige, la
    parallaxe s'amortit, les transitions deviennent instantanées — la
    fenêtre de lecture de 10 s reste (c'est le produit).
12. **Dissolution en particules réelles** : shader custom
    (`shaders/ether_dissolve.frag`) — chaque cellule de l'écho devient
    une poussière avec son délai de départ, sa vitesse et sa lueur ; un
    peintre CPU prend le relais si le programme shader est indisponible.

## Feuille de route (V2+)

- ~~E2E encryption réel~~ ✅ v1.1 — Ether Seal (clé éphémère par écho,
  escrow Vault, échange atomique à l'interception).
- ~~Purge `pg_cron` des échos dérivants > 30 jours~~ ✅ v1.1 —
  `kenos_purge()` + bloc cron prêt, commenté, dans la migration 0004.
- ~~Culling par secteur (RPC viewport)~~ ✅ v1.1 — `fetch_map_sector`,
  grille 8×8, parité démo exacte.
- ~~Haptique enrichie + « réduire les animations »~~ ✅ v1.1 —
  vocabulaire `KenosPulse`, respect du drapeau plateforme partout.
- ~~Widget custom shaders~~ ✅ v1.1 — dissolution en particules réelles
  (GPU + repli CPU).
- ~~Panorama / panning de la carte~~ ✅ V3.7 — le Voyage (monde 2×
  écran, trois planètes, trou noir, comètes), RPC viewport enfin servi.
- ~~Symphonie Collective spatialisée~~ ✅ V3.1/3.2/3.6 — ondes
  pentatoniques connectées, pan stéréo et atténuation par distance
  (oscillateurs `flutter_soloud`, repli honnête sur assets).
- ~~Le Cadavre Exquis~~ ✅ V3.8/3.11 — constellations à l'aveugle,
  figure émergente à l'angle d'or, lecture unique du poème fermé.
- Scellement côté serveur des traces de réception (même Ether Seal).

La feuille de route vivante (V3+ : Vestiges, Extraits, Aube, clusters
gelés) vit dans [`docs/ROADMAP_V3.md`](docs/ROADMAP_V3.md).
