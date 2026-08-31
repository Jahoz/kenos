# CLAUDE.md — kenos

## Project Overview

**KENOS** — App Flutter iOS/Android (du grec *kénose* : se vider de soi-même).
L'anti-réseau social : un sanctuaire numérique de décharge cognitive où l'on
lance des pensées intimes anonymes dans un « éther » cosmique. **Un écho ne
peut être lu qu'une seule fois, par une seule personne** — puis il s'autodétruit
(burn after reading).

- Zéro validation : pas de profil, pas de likes, pas de commentaires, pas de feed.
- Friction as a feature : lire exige un appui long de 3 s (*Mindful Hold*).
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
    ├── onboarding/    # Le seuil : trois règles, une porte
    ├── echo/          # domain (Echo, EchoColorTheme) + data (repository, store)
    ├── cosmic_map/    # application (MapController, MotionService) + presentation
    └── create_echo/   # Le Miroir : formulation, scellement, lancement
```

## Commands

```bash
flutter run                # Mode démo local (aucun backend requis)
flutter analyze            # 0 issue
flutter test               # 22 tests (atomicité, parallaxe, parcours UI complet)
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

- Le client ne touche JAMAIS la table `echoes` : carte → vue `echoes_map`
  (aucune colonne de texte), lecture → RPC `consume_echo` (atomique
  `FOR UPDATE SKIP LOCKED`), envoi → RPC `launch_echo` (validation + anti-spam).
- Ne jamais exposer `encrypted_text` côté client avant consommation.
- L'écho envoyé est stocké localement SANS son texte : même l'auteur ne relit plus.
- **Traces de réception** (bouteille à la mer) : `kenos_receptions` est sans
  contenu par défaut ; la trace du lecteur est one-shot (≤ 140 caractères,
  fenêtre de 10 min après lecture, jamais éditable) ; l'auteur la voit une
  seule fois (voir = brûler). Aucun identité, aucun fil, jamais de réponse.
- ROSE (`#F43F5E`/`#FB7185`) est réservé à la destruction, jamais sélectionnable.

## Design Boundary

Identité « Cosmic Zen / Dark Introspection » — voir
`../portfolio-os/PROJECT_DESIGN_REGISTRY.md` (entrée `kenos`).
ABSOLU : ne jamais importer de design d'un autre projet.
