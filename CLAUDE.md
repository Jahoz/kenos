# CLAUDE.md — kenos

## Project Overview

**KENOS** — App Flutter iOS/Android (du grec *kénose* : se vider de soi-même).
L'anti-réseau social : un sanctuaire numérique de décharge cognitive où l'on
lance des pensées intimes anonymes dans un « éther » cosmique. **Un écho ne
peut être lu qu'une seule fois, par une seule personne** — puis il s'autodétruit
(burn after reading).

- Zéro validation : pas de profil, pas de likes, pas de commentaires, pas de feed.
- Friction as a feature : lire exige un appui long de 3 s (*Mindful Hold*)
  — et **d'être à portée de l'œil** (champ de réception, V3.12 : au-delà,
  l'étoile n'est qu'un scintillement et le hold ne s'arme pas).
- Éphémère absolu : 10 s de fenêtre de lecture, puis dissolution.
- Sans identifiants Supabase, l'app démarre en **MODE DÉMO LOCAL** (éther simulé,
  sémantique identique — atomicité comprise).

## Stack

| Couche | Tech |
|--------|------|
| Framework | Flutter 3.41+ / Dart 3.11+ |
| State | Riverpod (`flutter_riverpod` 2.x, AsyncNotifier) |
| Routing | GoRouter (tout en fondu) |
| Backend | Supabase (auth anonyme + RPC PostgreSQL atomiques) |
| Capteurs | `sensors_plus` (accéléromètre → parallaxe, passe-bas α=0.08) |
| Audio | `just_audio` (drone 70 Hz bouclé + cloches pentatoniques, pitch couplé au hold) |
| Crypto | `cryptography` (AES-256-GCM, clé éphémère 256 bits par écho) |
| Stockage local | `flutter_secure_storage` (échos scellés SANS texte, timeout d'E/S) |

## Architecture

```
lib/
├── app/               # KenosApp, routeur go_router (fades uniquement)
├── core/
│   ├── constants/     # Void Black, typographies (Playfair/Space Mono), durées
│   ├── theme/         # Thème dark strict, aucun fioriture Material
│   ├── utils/         # ParallaxMath, LowPassFilter
│   ├── audio/         # AudioController : drone + cloches
│   └── widgets/       # ScrambleText (security theater)
└── features/
    ├── onboarding/      # Le seuil : trois règles, une porte
    ├── echo/            # domain (Echo, EchoExcerpt, cipher) + data (repo, store)
    ├── cosmic_map/      # application (MapController, caméra de voyage) + presentation
    ├── create_echo/     # Le Miroir : formulation, fragments, portes culturelles
    ├── constellations/  # Cadavre exquis : lignes à l'aveugle, figure angle d'or
    ├── frequencies/     # Symphonie spatialisée (oscillateurs + repli assets)
    └── observatory/     # L'Observatoire (V3.16) : seuil du gardien, formes sans contenu
```

## Commands

```bash
make dev                   # Mode démo local (aucun backend requis)
make dev-local             # PWA release sur l'éther local seedé (:4308) — JAMAIS juger la perf sur `flutter run` (debug, 5-20× plus lent)
make analyze               # 0 issue
make test                  # 247 tests (chiffrement, culling, contrôleurs, UI)
make db-reset && make db-test  # Migrations + 147 invariants pgTAP
make db-seed-load && make db-load-report  # Montée en charge : seed 30 j (scellés LISIBLES, ~12k lignes) + rapport
make db-verify-load           # Preuve e2e : consommer un écho seedé, l'ouvrir sur l'appareil
make db-wipe-load              # Reset clean du seed (data réelle + KEK intacts)
make db-garden                 # Jardiner : plante des anneaux ouverts (jamais de lignes)
make db-curate                 # Curater : artefacts poésie domaine public + vestiges, crédités
make db-sow-vestiges SOW_ARGS="--count 20"  # IA : semer des éclats vérifiés (2 passes) — clé gratuite Google AI Studio (https://aistudio.google.com/apikey)
make e2e                   # Boucle réelle sur PostgREST local
make deploy-site           # Landing → kenos-site.vercel.app (Vercel séparé, SANS lien git ; épingle l'alias — jamais de déploiement par push)
python3 tool/gen_audio.py  # Régénère les assets audio (std-lib only)
python3 tool/gen_icons.py  # Régénère les icônes Web/Android/iOS (std-lib only)
```

Canaux de test (registry `../LOCAL_DEV_PORTS.json`) :

```bash
flutter build web --release && (cd build/web && python3 -m http.server 4308)  # PWA :4308
(cd site && python3 -m http.server 4307)                                      # Site :4307
flutter emulators --launch Medium_Phone_API_36.1 && flutter run -d emulator-5554  # Android
```

> iOS : Xcode présent mais **aucun runtime simulateur installé** — télécharger via
> Xcode → Settings → Platforms avant `flutter run -d <sim>`.
> Android : si Gradle réclame `android-37` alors que `platforms/android-37.0` existe,
> créer le symlink `android-37 → android-37.0` (fait une fois sur ce poste).

Backend réel :

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJ...
```

Après avoir exécuté `supabase/migrations/0001_kenos_init.sql` dans le SQL Editor.

## Security Model (non-negotiable)

- Le client ne touche JAMAIS la table `echoes` : carte → RPC
  `fetch_map_sector` (métadonnées, culling 8×8), lecture → RPC
  `consume_echo` (atomique `FOR UPDATE SKIP LOCKED`), envoi → RPC
  `launch_echo` (validation + anti-spam).
- **Ether Seal** : le texte est chiffré sur l'appareil (AES-256-GCM,
  clé éphémère par écho) ; la clé est escrowée scellée sous une KEK
  (Vault) et échangée une seule fois, à l'interception, dans la
  transaction atomique. `encrypted_text` et `key_seal` ne fuittent
  jamais côté client. Prix assumé : la validation de longueur du
  plaintext est côté client (le serveur borne le scellé à 4000).
- Ne jamais exposer `encrypted_text` ni `key_seal` côté client avant
  consommation.
- L'écho envoyé est stocké localement SANS son texte : même l'auteur ne relit plus.
- Cicatrices de lecture : chaque écho consumé laisse une marque locale
  sans contenu (position seule, cap 80, fondu 30 j) — jamais de réseau ;
  les scellées se lisent comme des anneaux creux, l'éther comme des lumières pleines.
- **Traces de réception** (bouteille à la mer) : `kenos_receptions` est sans
  contenu par défaut ; la trace du lecteur est one-shot (≤ 140 caractères,
  fenêtre de 10 min après lecture, jamais éditable) ; l'auteur la voit une
  seule fois (voir = brûler). Aucun identité, aucun fil, jamais de réponse.
- ROSE (`#F43F5E`/`#FB7185`) est réservé à la destruction, jamais sélectionnable.
- **Purge** : `kenos_purge()` (échos > 30 j, audit > 1 j, réceptions non
  lues > 30 j) — câblage `pg_cron` fourni commenté dans la migration 0004.
- **Constellations (cadavre exquis)** : lignes scellées sur l'appareil.
  V3.13 (règle classique, arbitrage Hugo 2026-09-03) : `peek_previous_line`
  montre la ligne qui précède (une seule, scellée, ouverte sur l'appareil),
  `contribute_line` renvoie compte + précédente (bundle ciphertext + clé),
  `read_constellation` = le poème REFERMÉ est un artefact — lisible par
  tous (contributeurs inclus), re-lisible, jamais consommé ;
  `consume_constellation` reste en alias (les clients déployés guérissent).
  Purge : OPEN > 7 j, CLOSED > 30 j (l'artefact vit une lune).
- **Constellations-chansons (V3.14)** : un cadavre est POÈME ou
  CHANSON au largage (`kind`, jamais mélangé). Une ligne de chanson
  = une phrase de ≤ 8 indices de la gamme pentatonique, scellée en
  JSON — zéro octet audio dans l'éther, anonyme par construction
  (la voix est arbitré HORS pour l'instant : une voix est une
  empreinte). Le compositeur ÉCOUTE la phrase précédente (synthèse
  sur l'appareil), la chanson refermée se traverse : lecture
  séquentielle, chaque phrase spatialisée à sa station d'angle d'or
  (flutter_soloud, repli assets cuits).
- **Bouclier de trace (V3.15)** : la trace est la SEULE contenu clair
  vue par l'éther ; l'Edge Function `trace-shield` la lit via Mistral
  moderation (clé en secret serveur, fail-open par contrat). PII →
  avertissement non-bloquant (l'anonymat est le contrat, choisir
  appartient à l'auteur) ; selfharm → moment de soin avec ressources
  (3114/15), jamais une censure. Le contenu scellé reste
  structurelement invisible, pour toujours.
- **Extraits culturels (V3.10)** : la référence Spotify/YouTube voyage
  scellée sous la clé de l'écho (le serveur borne le scellé 32-512,
  ne voit jamais l'ID) ; l'URL lancée est TOUJOURS reconstruite
  canoniquement depuis un parse strict — jamais la chaîne brute.
  `door-preview` (Edge Function) ne connaît que l'ID de piste nu,
  jamais l'écho ni le texte.
- **Observatoire (V3.16)** : le dashboard gardien est CONTENTLESS par
  construction — `kenos_metrics_daily` ne stocke que des compteurs,
  bumpés dans la transaction des RPC de cycle de vie (aucune nouvelle
  lecture, l'atomicité sacrée est intacte). Le RPC `admin_fetch_metrics`
  ne rend que des agrégats (série, live, heatmap 8×8, dérivés) ; le
  gate lit `app_metadata` UNIQUEMENT (`user_metadata` est falsifiable,
  épinglé refusé en pgTAP) ; la session gardien vit sur un second
  client Supabase (la session anonyme céleste n'est jamais touchée) et
  ne persiste nulle part. Compte-rendu opérateur :
  `supabase/snippets/create_guardian.sql`.

## Design Boundary

Identité « Cosmic Zen / Dark Introspection » — voir
`../portfolio-os/PROJECT_DESIGN_REGISTRY.md` (entrée `kenos`).
ABSOLU : ne jamais importer de design d'un autre projet.
