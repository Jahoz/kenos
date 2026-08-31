# KENOS — Roadmap V3 « The Cosmic Introspection Engine »

Alignement du manifeste V2 ([`MANIFESTE_V2.md`](MANIFESTE_V2.md)) avec
l'état réel du produit, tensions à trancher, et plan d'incréments.
Rédigé le 2026-08-31, après la passe qualité et le branchement du réel.

---

## 1. Ce que le manifeste demande — et ce qui existe déjà

| Manifeste | État | Où |
|---|---|---|
| Single Receiver (1 émetteur, 1 lecteur) | ✅ livré, prouvé cloud | `consume_echo` FOR UPDATE SKIP LOCKED, e2e 18/18 |
| Zéro égo, anonymat absolu | ✅ livré | auth anonyme, zéro profil |
| Friction volontaire (Mindful Hold) | ✅ livré | 3 s, anneau, pitch drone |
| Éphémère absolu (burn after reading) | ✅ livré | détruit dans la transaction atomique |
| Intouchabilité de ses propres échos | ✅ livré | garde SQL + exclusion carte |
| Bouteilles à la mer qui dérivent | ✅ livré | étoiles scellées, dérive z, réceptions |
| Ether Seal (chiffrement réel au repos) | ✅ livré, au-delà du manifeste | AES-256-GCM, escrow Vault |
| **§2C Sling-Shot** (cendres / rebond, momentum, queue de comète) | ❌ absent | — |
| **§2D Symphonie Collective** (ondes pentatoniques, rayon, purge 60 s) | ❌ absent (POC React + port HTML dans `poc/`) | — |
| **§2E L'Aube** (sas poétique d'ouverture, stardust, aura ambre) | 🟡 partiel | `impact_screen` + `user_stats_store` (dashboard local, one-shot reports) |
| **§4 Médias** (photo/audio chiffrés, dé-bruitage au hold) | 🟡 partiel | fragments chiffrés + Edge Function `consume-media` (session du 31/08) ; shaders de dé-bruitage à finaliser |
| `users_impact`, `echoes.momentum/type`, `frequencies` | ❌ absent (sauf `echo_reports` livré) | migrations à venir |

## 2. Les tensions à trancher (Design Readiness Gate)

### T1 — Sling-Shot vs Éphémérité Absolue (LA décision produit)

Le pilier 3 déclare « une fois lue, détruite de l'univers » ; le §2C
donne au lecteur le pouvoir de la faire **renaître**. Les deux ne
peuvent pas être vrais en même temps. Le manifeste tranche implicitement
(§2C prime), mais l'implémentation proposée (`claim_echo` + `locked_by`
+ `locked_at`) coûte cher :

- des étoiles verrouillées fantômes si le lecteur ferme l'app pendant
  la fenêtre de décision (il faudrait un cron de déblocage) ;
- deux états pour une étoile (verrouillée/consumée) sur toute la carte ;
- l'invariant atomique le plus sacré du projet (lock → delete → return)
  se retrouve étiré sur une fenêtre utilisateur.

**Proposition (variante « phénix », recommandée)** : l'écho lu **meurt
toujours atomiquement** — rien ne change sur le socle. Le Swipe Up
recrée **un nouvel écho scellé** (`parent_id`, `momentum = parent + 1`),
même position, re-chiffré côté client pour UN nouveau récepteur unique.
Le Swipe Down ne fait rien de plus (l'écho est déjà mort — le geste
devient le rite). Le momentum est une métadonnée **publique** (compte de
rebonds, jamais de contenu), la queue de comète s'anime sur
`momentum > 0`. Coût : une insertion au lieu d'un lock fenêtré.
Gagné : l'atomicité absolue reste vraie, « Single Receiver » devient «
**un récepteur par cycle de vie** », et une comète à N rebonds prouve N
humains touchés — plus fort que l'original.

⚠️ Décision appartenant à Hugo : phénix (recommandé) vs lock fenêtré
(fidèle au §3.2 du manifeste, avec les coûts ci-dessus).

### T2 — `flutter_soloud` « obligatoire » (§3.3)

Vrai pour la spatialisation 3D native et les oscillateurs temps réel.
Lourd à avaler d'un coup (libs natives par plateforme). Escalier
proposé : **V1 des ondes avec les 20 notes pré-générées** par
`tool/gen_audio.py` (zéro dépendance, cohérent avec le drone/cloches
existants — un tap déclenche un asset enveloppé) ; `flutter_soloud`
arrive avec la spatialisation par rayon (V3.2/V3.6) où il apporte
réellement de la valeur.

### T3 — PostGIS `ST_DWithin` (§2D)

Un rayon sur une carte normalisée (x, y ∈ [0,1]) se calcule avec une
simple bbox indexée — PostGIS est sur-ingénierie tant que la carte n'a
pas de géographie réelle. Documenté comme refus de complexité
(Roadmap+ si la géographie réelle arrive un jour).

### T4 — La charte du POC React

Le POC soumis (violet/rose Tailwind) n'est pas l'identité Cosmic Zen du
registre. Le portage `poc/frequencies.html` reprend la **mécanique** du
POC avec les tokens KENOS. C'est la mécanique qui est porte, jamais la
charte (règle du registre : ne jamais importer un design d'ailleurs).

## 3. Incréments (petits, complets, dans l'ordre)

### V3.1 — Symphonie Collective, locale (le POC devient Flutter)
- Écran « FRÉQUENCES » accessible depuis la carte (route + icône HUD).
- Tap → onde : note pentatonique (asset pré-généré ×20 via
  `gen_audio.py`), nébuleuse CustomPainter (blur, enveloppe 10 s,
  60 fps — aucun widget par onde), X → timbre/teinte, Y → registre.
- Durée de vie 10 s locale, compteur HUD, respect « réduire les
  animations » (onde sans anim, note conservée).
- **DoD** : parité mécanique avec `poc/frequencies.html`, analyze 0,
  tests (mapping Y→note, X→teinte, purge), mode démo complet.

### V3.2 — Symphonie connectée ✅ (livrée 2026-08-31)
- Migrations 0005 (`kenos_frequencies`, `emit_frequency`, `fetch_nearby_frequencies`
  — bbox, T3) + `20260831120000_purge_consolidation` (la purge de 0005
  et celle d'echo_reports se marchaient dessus : source unique désormais).
- Polling 2 s, volume selon la distance au point d'écoute, démo
  habitée par des inconnus fantômes, dégradation locale silencieuse.
- Edge Function `consume-media` déployée au cloud (elle ne l'était
  pas : chaque lecture échouait silencieusement en prod).
- DoD atteint : smoke réel A émet → B entend (cloud_smoke_test 2/2),
  purge en pgTAP (60/60).

### V3.3 — Sling-Shot « phénix » ✅ (livrée 2026-08-31)
- Design phénix implémenté : l'écho lu meurt atomiquement ; le geste
  décide — bas = cendres (le burn n'attend pas), haut = re-scellé par
  l'appareil du lecteur pour UN nouveau récepteur, momentum + 1.
- Migration 20260831130000 : `kenos_lineages` (momentum + thème du
  parent capturé à la consommation — la ligne parente est détruite),
  `rebound_echo` (fenêtre 10 min, momentum serveur infalsifiable, un
  rebond une fois), `fetch_map_sector` porte le momentum, purge v3.
- Comète : queue sur les étoiles `momentum > 0` (CustomPainter, cachée
  en reduce-motion), hint de geste sur le panneau de lecture.
- DoD atteint : single-read intact (pgTAP 60/60 dont la chaîne complète
  u1→u4→u3 et les refus), smoke réel A lance → B lit+relance → C lit
  un momentum 1 (3/3).

### V3.4 — L'Aube complète ✅ (livrée 2026-08-31)
- Sas d'ouverture : lignes poétiques sur ce qui s'est passé pendant
  l'absence (strictement réceptions non vues — les traces restent
  non brûlées), point ambre qui respire, « touche le vide pour
  entrer ». Parle une fois par session, puis se tait ; la visite est
  enregistrée à la fermeture.
- Nœud d'origine sur la carte : cœur ambre dont la lueur monte avec
  la stardust (une mote par écho lu, une par réception reçue),
  jusqu'à 9 motes en orbite (plafonné : le vide reste un vide),
  un tap vers l'observation d'impact. Label sémantique.
- Token dédié `ember` (#F59E0B/#D97706) ajouté au registre — impact
  chaleureux, jamais confondu avec le rose destructif (testé).
- DoD atteint : ouvrir l'app raconte l'absence, jamais une
  notification — 77 tests, analyze 0, déployé et vérifié.

### V3.5 — Médias : finir le dé-bruitage
- Finaliser shaders photo (constellation de points, dé-brouillage au
  hold) et voix inversée/distordue (déjà amorcé par la session
  médias), en respectant Ether Seal (chiffré au repos, one-shot).
- **DoD** : aucune image nette ni voix claire avant 100 % du hold.

### V3.6 — Spatialisation (flutter_soloud, rayon réel)
- Évaluer le poids natif, puis remplacer les assets par des
  oscillateurs spatialisés, volume/pan par distance.
- **DoD** : les ondes lointaines s'entendent moins, sans engorger le
  thread principal.

## V3.7 — Le Système (proposé 2026-09-01, en attente d'arbitrage)

Le constat est juste : la carte est un cadre fixe, on n'y *voyage* pas.
Le manifeste voulait des distances relatives au nœud du joueur —
portons-les. Le design ci-dessous garde l'âme : **gravité, pas
filtres** — on ne choisit pas son contenu, on va quelque part et on
trouve ce qui y dérive.

### Le monde proposé

- **Le centre est un trou noir** (arbitrage Hugo, 2026-09-01 — mieux
  que le « soleil de vide » : KENOS ne source aucune lumière, les
  échos sont les seules lumières du produit). Un disque plus noir que
  le fond, un fin anneau d'accrétion rosé — le ROSE, réservé à la
  destruction, trouve ici son seul objet céleste légitime. L'horizon
  des événements dit le contrat de lecture : ce qui franchit la ligne
  ne revient jamais. Les planètes orbitent le vide ; les comètes le
  frôlent ; plus tard, les échos non interceptés à la dérive
  s'en approchent jusqu'à la purge des 30 jours.
- **Trois planètes = les trois intentions déjà présentes** dans le
  Miroir : APAISER (sarcelle), CONFIER (indigo), ÉCLAIRER (lumen).
  Ce ne sont pas des hashtags : ce sont des états d'être, des gravités.
  Un écho lancé « pour apaiser » entre en orbite autour de sa planète.
- **Les échos orbitent** leur planète — mouvement déterministe calculé
  client depuis `created_at` serveur : tous les clients voient le même
  ciel sans aucune synchronisation. Zéro migration : `x, y, theme,
  created_at` suffisent déjà.
- **Les comètes existent déjà** : un écho rebondi (momentum > 0) devient
  une orbite elliptique qui *traverse* les trois planètes — la trace
  des humains qui l'ont portée, en mouvement.
- **Voyager = glisser le vide.** Pan sur un monde plus grand que
  l'écran ; le HUD affiche la dérive poétique (« TU AS DÉRIVÉ DE 0.4 UA »).
  Tenir une étoile reste la friction de lecture — le geste pan sur le
  vide vide d'étoile n'entre jamais en conflit avec le hold.
- **`fetch_map_sector` attendait ça depuis V3.2** : le RPC viewport est
  déjà paramétré par rect — le voyage charge les secteurs voisins à
  l'approche des bords. La première vague d'incréments est
  intégralement client.
- Plus tard (V3.7c) : le rayon d'écoute des FRÉQUENCES suit la caméra —
  la musique des sphères devient locale au lieu où l'on se trouve.

### Garde-fous d'âme

- Trois planètes clairsemées dans un monde surtout vide — pas un menu.
- Aucun compteur de collection, aucune récompense de voyage : on va
  quelque part parce que la gravité y tire, pas pour gagner.
- Reduce-motion : orbites gelées (le ciel devient une carte), voyage
  par taps successifs au lieu de l'inertie.

### Incréments

- **V3.7a — Le Voyage** : monde 2× écran, pan + inertie douce, HUD de
  dérive en UA, chargement des secteurs voisins (RPC viewport existant),
  conflit de gestes hold/pan arbitré. Zéro backend.
- **V3.7b — Les Planètes** : trois ancres fixes, orbites déterministes
  des échos par intention, halos CustomPainter + lente rotation, tap
  planète = glissement de caméra (« voyager vers »), le soleil vide au
  centre. Zéro backend.
- **V3.7b (visuel centre)** : le trou noir — disque noir-sur-noir,
  anneau rosé discret, lentille gravitationnelle très douce sur les
  étoiles proches (déplacement apparent), jamais éblouissant.
- **V3.7c — Comètes & musique des sphères** : orbites elliptiques des
  momentum (frôlant le trou noir), nœud d'origine en ancrage
  personnel, rayon d'écoute lié à la caméra.

## 4. Règles inchangées (rappel)

- Single-read atomique, Ether Seal, RPC-only, ROSE destructif,
  haptique/audio non bloquants, demo mode iso-sémantique, lints
  `unawaited_futures` et Cie. Toute mécanique nouvelle passe par les
  mêmes épreuves (pgTAP + tests Dart + parity démo).
