# 🌌 KENOS

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
2. Dans le **SQL Editor**, exécuter le contenu de
   [`supabase/migrations/0001_kenos_init.sql`](supabase/migrations/0001_kenos_init.sql)
   puis [`supabase/migrations/0002_echo_receptions.sql`](supabase/migrations/0002_echo_receptions.sql).
3. Lancer l'app avec les identifiants (Project Settings → API) :

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
flutter analyze   # 0 issue
flutter test      # 22 tests : atomicité de lecture, parallaxe, parcours UI complet
```

Le test `app_flow_test.dart` rejoue le parcours réel : seuil → carte →
Mindful Hold 3 s → révélation → burn 10 s → dissolution → retrait de l'étoile.

---

## Architecture (feature-first, Clean simplifiée)

```
lib/
┣ core/
┃ ┣ constants/         # Void Black, Teal, Rose… typographies, durées
┃ ┣ theme/             # DarkTheme strict (pas de boutons Material criards)
┃ ┣ utils/             # ParallaxMath, LowPassFilter (capteurs)
┃ ┣ audio/             # AudioController : drone 70 Hz + cloches pentatoniques
┃ ┗ widgets/           # ScrambleText (théâtre de sécurité)
┣ app/                 # KenosApp, routeur go_router (tout en fondu)
┣ features/
┃ ┣ onboarding/        # Le seuil : trois règles, une porte
┃ ┣ echo/
┃ ┃ ┣ domain/          # Echo, EchoColorTheme
┃ ┃ ┗ data/            # EchoRepository (contrat), Supabase, démo local, store scellé
┃ ┣ cosmic_map/
┃ ┃ ┣ application/     # MapController (AsyncNotifier), MotionService (parallaxe)
┃ ┃ ┗ presentation/    # MapScreen, MindfulHoldStar, painters, RevealSheet
┃ ┗ create_echo/       # Le Miroir : formulation, scellement, lancement
┗ main.dart            # Bootstrap : secure storage → Supabase optionnel → runApp
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

## Feuille de route (V2+)

- E2E encryption réel (clé éphémère dérivée par écho, échangée à l'interception).
- Purge `pg_cron` des échos dérivants > 30 jours (bloc prêt, commenté, dans la migration).
- Culling par secteur de la carte (RPC viewport) au-delà de quelques milliers d'échos.
- Haptique enrichie et respect de « réduire les animations » (accessibilité).
- Widget custom shaders (dispersion en particules réelles à la dissolution).
