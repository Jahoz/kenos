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

### V3.5 — Médias : le dé-bruitage ✅ (livré 2026-09-01)
- Le fragment révélé arrive VOILÉ et se développe sur ~3,5 s de la
  fenêtre de lecture : image derrière un flou qui s'amincit et une
  constellation de points déterministe qui se disperse ; son gardé
  « SIGNAL BROUILLÉ… » sans bouton d'écoute tant que le voile tient.
  Rien de net avant que l'œil ait tenu — fidèle au manifeste, adapté
  au moment où le média existe réellement (après le hold atomique).
- **DoD** atteint : 2 tests widget épinglent voile→développement
  (image et son).

### V3.6 — Spatialisation ✅ (livrée 2026-09-02, V3.11c du flux)
- `flutter_soloud` (T2 tenu : il arrive avec la spatialisation, là où
  il apporte de la valeur) : 20 AudioSources oscillateur (sinus pur),
  une par note pentatonique — pitch miroir exact de `gen_audio.py`
  (testé). Chaque onde est placée dans le champ stéréo par son écart
  horizontal au point d'écoute (`panFor`), atténuée par la distance
  (`gainFor`), enveloppe nébuleuse reconstruite en temps réel
  (1,2 s de montée / 2,4 s de présence / 2,4 s d'expiration,
  `scheduleStop` à 6 s — comme l'asset qu'elle remplace).
- **Dégradation honnête** : sans moteur (web sans WASM, VM de test,
  plateforme exotique), `playNote` rend false et l'écran retombe sur
  les assets cuits — la symphonie ne se tait jamais pour un moteur,
  ne bloque jamais l'UI (testé en VM).
- **DoD atteint** : les ondes lointaines s'entendent moins ET du bon
  côté ; build web compile (chargeur WASM embarqué) ; 162 tests.

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
- **V3.7c ✅ (livrée 2026-09-01)** : comètes (momentum > 0 → ellipse
  excentrique autour du vide, périhélie frôlant le trou noir,
  aphélie au-delà des planètes, excentricité croissant avec le
  momentum — déterministe), constellations de lignage (parent_id via
  migration 20260901100000 ; segments faint vers le point de
  renaissance ; parent consumé = ancre fantôme), musique des sphères
  (le centre d'écoute FRÉQUENCES s'ouvre là où repose l'œil —
  travelPositionProvider). pgTAP 58/58, 103 tests Dart, déployé et
  vérifié live.

## V3.8 — Le Cadavre Exquis ✅ (livré 2026-09-01)

À travailler — trois déclinautions, de la trace involontaire à
l'œuvre collective à l'aveugle :

1. **Constellations de lignage** (presque gratuit, complète V3.7c) :
   relier les points d'une chaîne phénix (`parent_id` existe déjà) —
   la carte du voyage d'une pensée à travers N inconnus. Personne ne
   dessine : le monde dessine en lisant. Zéro backend.
2. **UNE LIGNE — le vrai cadavre exquis** : un troisième mode de
   lancement. Chaque inconnu ajoute une ligne SANS voir les
   précédentes (le serveur ne renvoie jamais les fragments, seulement
   le compte) ; sa ligne devient une étoile au point suivant d'une
   figure émergente (angle d'or). À 5-7 contributions elle se
   referme, et une seule personne peut alors la lire entière une
   fois, puis elle se dissout. Le contributeur ne verra JAMAIS le
   tout qu'il a aidé à faire — on donne une ligne au vide, même
   l'auteur collectif ne se relit pas.
3. **Garde-fou d'âme (le point dur)** : l'attente est le danger (le
   contributeur voudra revenir voir). Parade : seul L'Aube murmure à
   la prochaine visite (« la constellation que tu as touchée s'est
   refermée ») — jamais de push, jamais de compteur vivant, zéro
   stardust, zéro signature.
- **Livré** : migration 20260901110000 (4 RPC — contribute_line
  renvoie le COMPTE, jamais les fragments ; fermeture auto à 4-7
  lignes ; lecture unique du fermé par un non-contributeur seulement
  — KENOS_CONTRIBUTOR_BARRED ; purge 7 j), anneaux pointillés sur la
  carte (points remplis par les inconnus, fermé = anneau indigo
  plein), panneau « UNE LIGNE, À L'AVEUGLE », lecture du poème entier
  numéroté, murmure de l'Aube (constellationsTouched), pgTAP 71/71,
  112 tests, déployé.

**V3.11a — le cadavre scellé relit ✅ (2026-09-02)** : bug de
production corrigé — `consume_constellation` assemblait `text` avec
la CLÉ déchiffrée de l'escrow (pas le poème) : toute constellation
refermée se lisait en lignes VIDES dans l'éther réel (la démo en
clair et le pgTAP en clair masquaient le défaut). Migration 0011 : le
bundle du gagnant porte désormais ciphertext + clé (parité
`consume_echo`), ouvert sur l'appareil — le serveur ne voit toujours
aucune ligne ; les clients déjà déployés sont guéris par le seul
serveur. Chemin scellé épinglé en pgTAP (96/96), parsing client
extrait et testé (round-trip Ether Seal réel).

**V3.11b — la figure émergente ✅ (2026-09-02)** : la promesse V3.8
tenue — chaque ligne donnée devient une étoile à la station d'angle
d'or (~137,5°) suivante autour de la graine, spirale vers l'extérieur :
la constellation SE DESSINE à mesure que les inconnus écrivent.
Arithmétique pure sur l'index (déterministe : tous les clients voient
la même figure), étoiles pleines / stations creuses, segments pâles
pour ce qui est déjà tracé, graine au centre ; fermée = lueur indigo
sur figure complète. Le panneau de lecture montre la figure complète,
une fois, au-dessus du poème qu'elle garde. 8 tests.

## V3.9 — Les Vestiges ✅ (livrée 2026-09-01)

Le cold start : un éther vide n'offre rien à découvrir. La réponse est
de la culture réelle, curatée — JAMAIS de faux échos (le contrat
sacré : une étoile = une vraie pensée humaine ; une confidence
fabriquée tuerait la confiance en tout ce qu'on lit).

- **Forme** : éclats géométriques gravés, ternes, qui culbutent — la
  grammaire visuelle dit « artefact culturel », pas « confidence ».
- **Rituel différent** : décryptage ~1 s, RE-LISIBLES (une citation ne
  brûle pas — ce serait du gâchis), aucune réception, aucune trace,
  aucun rebond, AUCUNE stardust (elle mesure la connexion humaine).
- **Hors décompte** : « N ÉCHOS EN ORBITE » ne compte que les humains ;
  « L'ÉTHER EST CALME » reste honnête même si des vestiges dérivent.
- **Contenu** (curaté, français, public domain, sourcé) : citations sur
  le vide et le lâcher-prise (stoïciens, Rilke, Bachelard, haïku),
  étymologies (kénose, dérive, silence, vacance), micro-histoires,
  invites respiratoires. Embarqué en JSON dans l'app : zéro backend,
  honnête hors-ligne.
- **Répartition** : clairsemés (3-4 par secteur), trouvés en voyageant
  — une bibliothèque du vide, jamais un fil.
- **Livré** : 12 vestiges (citations, étymologies, haïku, histoire des
  bouteilles à la mer), JSON embarqué, éclats gravés tournant
  lentement, panneau serif sourcé re-lisible (« CECI NE BRÛLE PAS —
  IL REVIENDRA »), 3 tests, déployé.

## V3.10 — Les Extraits : portes culturelles ✅ (idée Hugo, livré 2026-09-01)

Un écho peut être habité par la voix d'un autre : l'auteur colle un lien
**Spotify** (titre) ou **YouTube** (extrait horodaté) dans le Miroir. Ce
n'est pas du contenu qu'on stocke — c'est une **porte**, ouverte dans la
fenêtre de révélation, qui mène hors du vide. Distinct des Vestiges
(culture curatée par l'app, re-lisible) : ici c'est l'auteur qui prête
une voix extérieure à sa confidence, et la porte ne s'ouvre que pour le
lecteur unique.

- **Rien ne se stocke** : pas de bucket, pas d'octets — une référence
  compacte (`spotify:track:<id>` / `youtube:<id>:<secondes>`), **scellée
  sous la clé éphémère de l'écho** comme le texte (Ether Seal jusque
  dans le goût musical : un dump de la base ne révèle ni l'un ni
  l'autre). Le serveur borne le scellé (≤ 512) sans jamais voir l'ID —
  prix assumé identique à la ligne de 280 caractères.
- **Anti-injection par construction** : le client ne lance JAMAIS la
  chaîne brute — il parse strictement la référence et construit l'URL
  canonique (`open.spotify.com/track/<id>`,
  `youtube.com/watch?v=<id>&t=<s>s`). Une référence forgée ne peut pas
  devenir une URL arbitraire.
- **La fenêtre reste 10 s** : l'éphémérité absolue n'est pas négociable.
  La porte apparaît derrière le même voile de dé-bruitage V3.5
  (« SIGNAL BROUILLÉ… » tant que l'œil n'a pas tenu), survit à la
  dissolution du texte (jusqu'à la fin du panneau — trace incluse), puis
  disparaît : rien ne persiste localement. Ce qui a été ouvert *dehors*
  demeure — c'est le monde extérieur, pas KENOS.
- **Hors du vide, littéralement** : V3.10 = deep-links (sortie assumée
  vers l'app/browser). Lire *dans* le vide (embed YouTube, preview 30 s
  Spotify) exige webview/clés API — reporté à V3.10b via Edge Function
  si le besoin se confirme (Roadmap+).
- **Un seul attachement par écho** (fragment OU extrait) : l'invariant
  « un fragment optionnel borné » reste vrai, le Miroir les rend
  exclusifs.
- Démo : l'éther semé compte des échos à extrait (parité scellement
  incluse) ; mode hors-ligne honnête (la porte peut être fermée, le HUD
  le dit doucement).

**Livré et vérifié** (2026-09-01) : HUD allégé en prod ; dialogue de
porte, parse strict (queue de tracking Spotify dépouillée, horodatage
YouTube `1:30` affiché) et chip en navigateur réel ; le chemin serveur
SONG/EXCERPT prouvé bout-en-bout par appel PostgREST authentifié
(ligne scellée en base, ref 84 chars). **Limitation web constatée
(v3.10b)** : la couche d'édition web croise les sessions du champ du
Miroir et du champ de dialogue (l'hôte d'édition unique peut
entrelacer les deux textes — famille du bug « lettres se mélangent »
déjà signalée), et le mode clavier dérive le viewport (clics bas peu
fiables sur desktop). Deux envois réels depuis l'app ont perdu la
porte (media_kind NULL en base) après manipulation du clavier ; le
correctif candidat : défocaliser avant d'ouvrir le dialogue +
réinitialiser proprement l'état d'édition à la fermeture.

**Correctif livré (v3.10b, 2026-09-01)** : le Miroir défocalise son
champ AVANT d'ouvrir le dialogue (un seul hôte d'édition vivant), le
champ du dialogue a son FocusNode dédié, et « SCELLER LA PORTE »
ferme la connexion d'édition puis attend une frame AVANT de parser —
seul un état committé peut devenir une porte (garde anti double-tap
incluse). Trois tests épinglent le contrat : cession de l'hôte
d'édition, texte du Miroir intact + porte attachée, lien invalide
sans porte. Reste documenté (non corrigé) : la dérive du viewport en
mode clavier sur desktop web — famille navigateur (scroll-into-view
de l'input HTML), à traiter séparément si elle gêne encore.

**V3.10b' — la voix dans le vide (livrée 2026-09-01)** : les portes
musicales proposent « ÉCOUTER UN FRAGMENT » (preview Spotify 30 s)
DANS la fenêtre de révélation, après le voile — jamais en auto-play
(l'oreille demande, comme l'œil tient). Edge Function `door-preview`
(client credentials, token caché au warm scope, id de piste strictement
validé) ; dégradation honnête à tous les étages (pas de secrets, hors
ligne, piste sans preview → `{url: null}`) : la porte seule demeure,
aucune erreur, aucun blocage. **La voix empruntée brûle avec l'écho** :
elle se tait au burn (stop explicite), la porte survit jusqu'à la fermeture
du panneau. Les vidéos gardent leur porte extérieure (l'embed exige une
webview — refus de complexité maintenu). Démo : décline toujours (test
épinglé). 4 tests (song vs vidéo, HUD de dégradation, parité démo).

## V3.12 — Le Champ de Réception & le Ciel Vivant ✅ (livrés 2026-09-02)

Nés d'une montée en charge seedée (4 200 échos, 180 inconnus, 30 jours
de rampe) : le premier regard demandait tout le ciel (94 Ko, plafond
400 atteint), le ciel n'avançait que 4 fois par seconde, et la
distance à l'œil ne comptait pas. Tout cela est mort.

- **Le premier regard ne charge que le ciel visible** : le rect de la
  caméra d'ouverture + la marge de voyage, au budget viewport
  (`SectorGrid.viewBudget = 180`) — 42 Ko sur le même éther (−55 %).
  Le reste se découvre en voyageant (machinerie V3.7a, fusion par
  union). RECALIBRER ne refetch plus (le dédoublonnage de rect
  l'absorbe). La démo passe de 14 à 120 étoiles : elle révèle enfin
  les coûts du vrai éther.
- **L'œil est écoutable, le ciel est mémoïsé** : `TravelCamera` devient
  `ChangeNotifier` — les gestes ne rebuild plus l'écran, seulement les
  couches qui regardent à travers lui. Tri/profondeurs mémoïsés, porte
  epsilon sur le tilt, `RepaintBoundary` par étoile.
- **Les orbites battent au framerate, au niveau du rendu** : `StarShift`
  (boîte proxy à décalage de peinture piloté par `ValueNotifier`) — le
  drift est un passage de layout + recomposition GPU des rasters en
  cache, zéro rebuild de widget. Le souffle garde son métabolisme 4 Hz ;
  le ticker ne fait jamais de `setState`. Le halo de profondeur quitte
  le `ImageFiltered` de bucket (un blur re-filtre dès que son contenu
  bouge — chaque frame, maintenant) et vit dans le glow de chaque
  étoile : lointain = plus doux, plus large.
- **Le champ de réception** (`ParallaxMath.receptionIntensity`, rayon
  0,16 + fondu 0,18 en unités monde) : à portée de l'œil, une étoile
  est vive et tenable ; au-delà, elle s'estompe à ~30 % — un
  scintillement — et le Mindful Hold ne s'arme plus. Zoomer, c'est
  approcher. Les étoiles scellées ignorent le champ (des ancres, pas
  des bouteilles). **La bouteille à la mer se mérite à la distance.**
  Le mécanisme s'enseigne seul : une ligne au Seuil (« à portée de ton
  œil ») et un whisper unique par session (« TROP LOIN.
  RAPPROCHE-TOI. »).
- **Trois familles d'étoiles, distinguées par la FORME** : les
  scellées lisent comme des **anneaux creux** teal (le contenu est
  parti — même l'auteur ne relit plus : donné = creux), l'éther
  lisible garde ses lumières **pleines** (une confidence attend
  dedans), et chaque lecture consumée laisse une **cicatrice** — un
  point creux froid, sans contenu, local à l'appareil (cap 80, fondu
  à l'horizon 30 jours de l'éther). Le voyage de lecture se peint.
- **L'ergonomie du choix (retour utilisateur 2026-09-03)** : les modes
  du Miroir ont des NOMS (`IMAGE · SON · PORTE · CADAVRE` — les icônes
  muettes étaient invisibles au doigt), le thème se lit (10 px/55 %).
  **Lancer un cadavre exquis existe enfin** : `CADAVRE` transforme le
  Miroir, l'anneau naît près du regard, et le lanceur est invité à
  donner la PREMIÈRE ligne (il n'est qu'un inconnu de plus). Les
  cadavres se comptent au HUD (`N CADAVRES`), s'expliquent une fois
  (voile une-fois, grammaire du guide des ondes), et leurs anneaux
  gagnent en lisibilité (46 px). Zéro migration — le RPC seed n'avait
  JAMAIS d'UI.
- **Outillage de charge** : seed SQL reproductible (30 j de rampe,
  tous les cas de vie, scellés AES **lisibles** générés par
  `tool/gen_load_payloads.dart`, vérification e2e
  `make db-verify-load`), wipe propre (`make db-wipe-load`), serveur
  de dev `no-store` (une tab en cache a déjà servi le mauvais éther
  toute une soirée). Portes : 171 tests Dart, e2e 18 ✓, analyze 0,
  déployé et vérifié live.

## V3.13 — Le cadavre exquis, règle classique ✅ (arbitrage Hugo, livré 2026-09-03)

Retour utilisateur : « on doit voir au moins la ligne qui nous
précède ; les constellations finies doivent être accessibles à ceux
qui ont participé, et à la manière des artefacts aux autres. » La
règle surréaliste originelle, en fait — et une âme assouplie,
arbitrée :

- **La ligne qui précède** : `peek_previous_line` montre la queue du
  poème (UNE ligne, scellée, clé libérée de l'escrow, ouverte sur
  l'appareil) AVANT d'écrire ; `contribute_line` renvoie compte +
  précédente. Jamais le tout — on enchaîne, c'est tout.
- **Le poème refermé est un artefact** : `read_constellation` le
  livre à TOUS (contributeurs inclus), re-lisible comme les
  Vestiges, jamais consommé. `consume_constellation` reste en alias
  non destructif — les clients déjà déployés guérissent seuls.
- **L'artefact vit une lune** : purge CLOSED > 30 j (`closed_at`),
  OPEN > 7 j inchangé. L'éther oublie, même ses plus beaux poèmes.
- Ce qui reste sacré : pendant l'écriture personne ne voit le tout,
  zéro push, zéro compteur vivant, zéro plaintext serveur.
- Copies à la vérité : feuille de contribution (« LA LIGNE QUI
  PRÉCÈDE »), panneau de lecture (« UN POÈME D'ÉTRANGERS — IL
  RESTE, REFERMÉ »), Miroir, voile une-fois, L'Aube, landing.
  Gates : 107 invariants pgTAP (âmes inversées épinglées :
  contributeur-lit, artefact-survit, alias-non-destructif, purge
  lune), 176 tests Dart, e2e 18/18.

## V3.14 — La constellation-chanson ✅ (idée Hugo, livrée 2026-09-03)

« On doit pouvoir faire ça avec de l'audio… avec la symphonie
améliorée qui enregistrerait et diffuserait pour la personne
suivante. » Arbitrages : **notes pures** (la voix est une empreinte —
l'anonymat de l'éther n'y survivrait pas ; documentée comme mode
futur possible, les yeux ouverts), **poème OU chanson** au largage
(jamais mélangés), **écoute à l'infini** comme l'artefact.

- **Une ligne de chanson = une phrase de notes** : ≤ 8 indices dans
  la gamme pentatonique publique des ondes, scellés en JSON sous la
  clé éphémère de la ligne (~60 caractères — la borne 2000 du RPC
  ne bouge pas). **Zéro octet audio dans l'éther** : rien à stocker
  au-delà du scellé, rien à modérer, anonyme par construction.
- **La règle classique devient sonore** : le compositeur ÉCOUTE la
  phrase qui précède (synthétisée sur son appareil depuis les notes
  déscellées — le peek V3.13 interprète la charge), puis pose ses
  notes sur le vide (tap : bas = grave, haut = cristallin — le
  mapping exact des ondes).
- **Le rythme voyage avec la mélodie** (2026-09-03, « hyper
  important ») : chaque intervalle entre touches du compositeur est
  chronométré et scellé dans la phrase (`d`, tenues bornées 120-4000
  ms — un flutter au minimum, un souffle au maximum, jamais de
  silence infini). La lecture restitue chaque tenue exacte — chez le
  compositeur, chez le suivant qui écoute la phrase précédente, et
  dans la chanson refermée. La portée s'écrit de gauche à droite :
  chaque point à SA hauteur, à SON instant ; la teinte suit la
  progression (palette des ondes).
- **La figure chante** : refermée, la chanson est un artefact qui se
  traverse — phrase après phrase, chacune synthétisée à SA station
  de l'angle d'or, placée dans le champ stéréo (flutter_soloud,
  repli sur les assets cuits). **Lecture séquentielle** : une phrase
  à la fois, jamais le tout d'un coup — la réponse à la surcharge.
  REJOUER à volonté, la station qui chante respire en cyan.
- Migration 20260903050411 : `kind` POEM/MELODY (garde
  KENOS_INVALID_KIND), `seed_constellation(p_kind)` (param optionnel
  — le smoke nocturne reste vert), `fetch_constellations` expose le
  genre (et passe à 30 j — les artefacts vivent une lune). Le
  marqueur carte : chansons ouvertes en cyan (l'instrument des
  ondes), poèmes en blanc, refermés en indigo.
- Gates : 111 invariants pgTAP (+4 : défaut POEM, seed MELODY, le
  genre au fetch, jamais de SHOUT), 181 tests Dart, e2e 18/18.

## V3.14b — Le Jardinier & le Curateur ✅ (livrés 2026-09-03)

L'éther de production devait vivre : des anneaux ouverts à remplir
(offre), et des artefacts lisibles dès le premier jour (culture).

- **Le Jardinier** — `kenos_garden_seed(target, max_new)` : plante des
  anneaux OUVERTS (jamais une ligne — les anneaux attendent les
  inconnus), auto-régulé : il compte ce qui vit et ne plante que le
  manquant (câblage pg_cron fourni commenté ; `make db-garden` en
  local). Mélanges poèmes/chansons, cibles 4-7, positions dérivantes.
- **Le Curateur** — `curated_by` : les artefacts lisibles naissent de
  VRAIE poésie de domaine public, créditée (philosophie Vestiges :
  contenu réel, jamais de fausses confidences). `curate_constellations.sql`
  sème 7 constellations refermées — Rimbaud, Verlaine, Baudelaire,
  Apollinaire, Nerval, Labé — lignes dans l'ordre du poète, ouverture
  sur l'appareil, **le nom du poète à la lecture** (`— RIMBAUD —` en
  footer, jamais l'illusion que des inconnus l'ont écrit). Idempotent,
  effaçable en un prédicat (`curated_by is not null`). `make db-curate`.
- Appliqué en production le 2026-09-03 : 13 anneaux ouverts + 7
  artefacts crédités, vérifiés via REST authentifié. Gates : 104
  invariants pgTAP (+7 : le jardinier plante par paliers jusqu'à la
  cible puis s'arrête, n'écrit JAMAIS de ligne, ne plante que
  POEM/MELODY, l'attribution voyage au fetch), 189 tests Dart.

## V3.14c — Les Vestiges traversent l'éther ✅ (livrés 2026-09-03)

Les Vestiges vivaient dans le bundle (12 éclats, honnête hors-ligne —
mais gelés entre les releases). Le Curateur les nourrit désormais
depuis la base : **32 éclats** — les 12 originaux (positions kept) +
une première récolte de 20 (faits d'astronomie, étymologies grecques
et latines, micro-histoires Voyager/Sénéque/Labé, haïkus, citations
de domaine public), crédités, upsertables sans release.

- Migration 0015 : table `kenos_vestiges` (kind quote/etymology/
  haiku/history/fact, texte 1-400, live flag) + `fetch_vestiges()`
  RPC (≤ 200 en vol). Culture délibérément LISIBLE — pas de scellé,
  pas de burn : un éclat se relit toujours.
- Client : **l'éther d'abord, le bundle en repli** — connecté, la
  carte lit la bibliothèque curatée ; en démo/hors-ligne, les 12
  éclats du bundle portent la culture. Jamais de blocage.
- La rotation quotidienne (~2/3 dérivants, déterministe) reste
  client : même ciel pour tous les appareils ce jour-là. L'état lu
  reste local (un fantôme, jamais un burn). Purge : les vestiges
  **n'expirent jamais** — la culture ne pourrit pas, le curateur la
  retire (`live = false`).
- `make db-curate` (constellations + vestiges). Appliqué en prod le
  2026-09-03, vérifié REST : 32 éclats servis. Gates : 106 pgTAP
  (+2 : la bibliothèque sert ses éclats, un éclat retiré quitte le
  ciel), 189 tests Dart, e2e 18/18.

## V3.12 — Le Système nommé (idée Hugo, 2026-09-02) ✅

Le ciel reçoit sa mythologie : **sept corps nommés**, chacun expliqué
au clic (et au survol desktop, étiquette + curseur). Les trois ancres
d'intention deviennent des mondes identifiables — **La Lune** (APAISER,
un croissant qui renaît), **Vénus** (CONFIER, l'anneau de l'amour à
voix basse — la proposition même de Hugo), **Polaris** (ÉCLAIRER,
l'étoile fixe en phare : elle N'ORBITE PLUS, le point immobile du ciel
tournant — glyphes distincts par nature). La plaque dit le nom, la
nature, un poème, l'intention et le compte d'échos en orbite vivant
(« 3 échos dérivent autour d'elle en ce moment »), avec VOYAGER VERS.
Quatre **corps errants** dérivent au-delà des orbites — **Pluton**,
**Triton**, **Europe**, **Titan** — des catégories ouvertes : leur
plaque dit « RIEN N'ORBITE ICI — PAS ENCORE », l'imagination du tri
que l'éther ne connaît pas encore. Trouvés en voyageant (arcs lents
déterministes, 0,62-0,74 UA du vide). Zéro migration : la mythologie
vit client, le thème→orbite reste la clé sacrée du Miroir. 7 tests.

## V3.15 — Le Bouclier de Trace ✅ (livré 2026-09-04)

L'IA au service de l'âme, pas contre elle. Le contenu scellé
(échos, constellations, chansons) est structurellement invisible —
AES-256-GCM sur l'appareil, par design, pour toujours. La TRACE est
la seule contenu utilisateur en clair que l'éther voie jamais :
c'est précisément là que la modération Mistral (`mistral-moderation-
latest`, free tier, 11 catégories) intervient.

- **Edge Function `trace-shield`** : proxy vers la modération Mistral
  (clé en secret serveur, jamais dans le client). Seuils calibrés
  sur sondage live (fuites réelles = 1.0, traces saines ≤ 0.05) :
  `pii > 0.8`, `selfharm > 0.85`. **Fail-open par contrat** : clé
  absente, réseau mort, JSON cassé → la trace passe, le bouclier est
  un invité, jamais une porte.
- **PII = l'anonymat est le contrat** : l'app AVERTIT, jamais ne
  bloque — « Ce que tu t'apprêtes à laisser semble porter des
  données personnelles… l'anonymat, lui, ne revient pas. »
  LAISSER QUAND MÊME / REPRENDRE MA LIGNE. Protéger l'âme de l'app
  au moment exact où l'humain la menace lui-même.
- **Selfharm = un moment de soin, jamais une censure** : le cri
  appartient à celle ou celui qui l'a écrit. « Tu n'es pas obligé·e
  de la porter seul·e — le 3114 (national, 24h/24, gratuit) écoute,
  et le 15 en urgence. » LAISSER LA TRACE / REPRENDRE MA LIGNE.
- Démo/hors-ligne : le bouclier ne s'appelle même pas. Chaque
  drapeau ne s'affiche qu'une fois par session d'écriture.

Gates : 5 tests (décodage fail-open, types lâches sans faux positif,
sans session = passage), déployé et vérifié live sur les trois cas
(PII levé, saine passe, selfharm levé).

## V3.16 — L'Observatoire ✅ (livré 2026-09-04 — dashboard gardien, idée Hugo)

L'astronome ne lit jamais les messages : il compte les étoiles. Une
vue d'usage du ciel pour le gardien du projet — **des formes et des
comptages, jamais de textes ni d'identifiants** (le modèle de menace
de SECURITY.md reste la loi : le dashboard est contentless par
construction, comme les rapports).

- **Design Readiness Gate (validé à l'écriture de cette entrée)** :
  1. *Identité* — réutilisation stricte de l'identité enregistrée kenos
     (registry portfolio-os) ; aucun design importé d'ailleurs.
  2. *Jetons* — uniquement AppColors/AppFonts/KenosTheme existants ;
     ROSE interdit dans l'Observatoire (réservé à la destruction) ;
     données en teal/cyan/indigo/purple/ember ; Space Mono pour toute
     donnée, Playfair pour la phrase humaine.
  3. *Composants signature* — le **Seuil du Gardien** (sheet
     glassmorphism email+mdp), le **Spectre** (barres quotidiennes
     30 j), la **Grille des secteurs** (heatmap 8×8).
  4. *États critiques* — verrouillé (seuil), chargement, vide («
     l'éther est encore silencieux »), erreur (+ RÉESSAYER),
     identifiants refusés.
  5. *Parcours clé* — appuyage long sur L'Aube (OriginNode) → Seuil
     du Gardien → métriques. Portrait mobile, colonne ≤ 560.
  6. *A11y* — contrastes des jetons, labels sémantiques, focus
     ordonné sur le formulaire, cibles ≥ 44 px.
  7. *MVP vs Roadmap* — voir ci-dessous.

- **MVP** : route cachée `/observatoire` ; authentification **Gardien**
  (compte Supabase email+mdp dédié, claim `role=admin` dans
  `app_metadata` — non falsifiable, jamais `user_metadata`) via un
  **second client Supabase** (la session anonyme céleste n'est jamais
  touchée) ; RPC `admin_fetch_metrics` (security definer, refus
  `kenos_forbidden` hors gardien, jsonb 100 % agrégé : série
  quotidienne, état vivant, heatmap 8×8, dérivés) ; capture durable
  `kenos_metrics_daily` (un compte/jour) incrémentée **dans la même
  transaction** que launch/consume/rebound/trace/report/seed/line —
  aucune nouvelle lecture, `FOR UPDATE SKIP LOCKED` intact ; nouveaux
  usagers par trigger contentless sur auth.users ; lecteurs actifs
  pliés idempotemment dans kenos_purge avant la purge 1 j ; mode démo
  iso-sémantique (LocalAdminRepository).
- **Roadmap+** : export CSV, temps réel, actions de modération,
  activation pg_cron du rollup, graphes multi-métriques.

Gates : 144 pgTAP (22 nouveaux : deltas exacts par snapshot sur les
compteurs, refus anon/lambda/user_metadata-forgé, succès gardien,
pliure purge), 218 tests Dart (7 nouveaux : seuil refusé/données/rang
révoqué/éther silencieux/démo déterministe), `flutter analyze` 0,
advisors 0, e2e local réel GoTrue (compte gardien créé, claim
promu, connexion mot de passe, RPC, refus 400/403), migration
20260904043728 poussée au cloud, nightly smoke 25 ✓ / 0 ✗ (probe
`admin_fetch_metrics` + payloads V3.13/15 manquants réparés au
passage). Reste à Hugo : créer le Gardien prod (dashboard +
`supabase/snippets/create_guardian.sql`) et vérifier le seuil sur
device (cloud + démo).

## V3.16 — Les Vestiges multilingues ✅ (livrés 2026-09-04)

Arbitrage Hugo : « on garde KENOS » — la voix produit reste FRANÇAISE,
canonique, pour toujours. Ce qui traverse les frontières, c'est la
CULTURE CURATÉE : chaque éclat existe en canon FR + traductions,
servi selon la langue du device, avec repli honnête sur le français.

- **LA LOI DU PRODUIT** (écrite noir sur blanc) : le contenu
  utilisateur — échos, constellations, chansons, traces — n'est
  JAMAIS traduit. Scellé sur l'appareil, il traverse les frontières
  dans la langue où il a été chuchoté. Comme une vraie bouteille.
- Migration 0016 : `locale` sur `kenos_vestiges` (PK id+locale),
  `fetch_vestiges(p_locale)` normalise (`fr-FR` → `fr`) et replie
  sur le canon FR — le ciel n'est jamais vide.
- **Traducteur** (`tool/translate_vestiges.dart`) : Mistral traduit
  le canon dans la voix kenos (sens, pas les mots), passe de
  vérification, staging humain, SQL upsert. Les positions suivent le
  canon : une étoile ne bouge pas parce qu'on la lit en anglais.
  (Première passe : traduction humaine — la clé Mistral avait épuisé
  son quota du jour, le Semeur reprendra pour le volume.)
- **L'anglais servi** : 32 éclats EN en prod, vérifiés REST par
  locale (en = anglais, fr-FR = canon, de = repli français).
- L'interface reste française (la voix fait le produit). La landing
  pourra suivre le même schéma plus tard.

Gates : 152 invariants pgTAP (+3 : la locale normalize, le canon FR
par défaut, le repli honnête), 252 tests Dart, e2e 18/18.

## V4 — Les Clusters : galaxies privées (idée Hugo, 2026-09-01 — **GELÉ, arbitrage Hugo 2026-09-02** : on va au bout du Cadavre Exquis et des Symphonies d'abord)

Créer une mini-galaxie invitable (amis, collègues), vivant en parallèle
de l'univers complet. **La plus grosse tension philosophique depuis le
Sling-Shot** : la kénose est de se vider vers des *inconnus* — dans un
cercle connu, l'anonymat devient un leurre (on devine qui a écrit →
autocensure, ou « c'était sur moi ? »), et les mécaniques sacrées
(lecture unique, burn) risquent de devenir des effets de soirée. C'est
la mort de Secret et Yik Yak ; KENOS n'assume pas les cercles clos.

- **Fausse piste écartée** : le multi-tenant in-app (`galaxy_id` sur
  `echoes`, memberships, invitations, RLS par galaxie) touche *tous*
  les RPC, chaque invariant pgTAP, la purge, l'Aube et les vestiges —
  coût maximal pour un risque d'âme maximal. Refusé pour l'instant.
- **Alternative quasi gratuite, à valider par l'usage** : une galaxie
  privée = **un déploiement Supabase séparé** (mêmes migrations), une
  build PWA/APK pointant dessus (`--dart-define=SUPABASE_URL`), le lien
  de partage EST l'invitation. Zéro code, sémantique sacrée intacte,
  l'échelle reste « un éther entier ». Si des équipes l'utilisent
  vraiment, le multi-tenant redevient une question — avec ses garde-fous
  (cold start : les vestiges dérivent-ils dans les clusters ? une
  galaxie meurt-elle ? qui paie ?).
- **Gate avant tout code** : l'anonymat petit-cercle est-il croyable ?
  Qui est le garant d'une galaxie (modération) ? Répondre avant d'écrire
  une ligne de SQL.

## V3.17 — Le Soutien du sanctuaire (décision Hugo, 2026-09-04)

Le sanctuaire reste gratuit : **pas de publicité, pas d'abonnement, pas de
paywall sur le cœur** (lire, écrire, dériver). La couverture des frais
(Supabase free tier aujourd'hui, Pro ~25 $/mois demain, frais des stores
ensuite) passe par le soutien volontaire — décision prise après revue des
options (dons, IAP offrande, cosmétiques, affiliation musicale écartée).

- **GitHub Sponsors** (`github.com/sponsors/Jahoz`) : 0 % de commission,
  ponctuel ou mensuel. Section « 07 / Entretenir le vide » ajoutée au
  mini-site (`site/index.html`), lien en pied de page + lien sobre dans
  le header sticky (toujours accessible au scroll, quasi muet par défaut,
  teal au survol ; tagline masquée < 640 px) — composants existants
  uniquement, identité registry intacte. **Refusé** : tout CTA flottant
  persistant (bandeau/bouton sticky) — le pattern caritatif agressif
  contredit le contrat zen ; le header sticky suffit à la permanence.
- **Transparence** : les sommes financisent l'hébergement de l'éther ;
  ce ne sont pas des dons fiscaux (pas d'association). Le soutien se vit
  hors du sanctuaire — l'éther ne sait jamais qui donne.
- **Fiscal** : revenus occasionnels (2042-C-PRO) tant que les flux
  restent modérés et sporadiques ; bascule micro-entreprise si
  régularité, ou au premier IAP.
- **L'offrande IAP (Roadmap+)** : si une communauté se forme — IAP
  consommable « cloche/dérive » (0,99-2,99 €), déblocage strictement
  local (secure storage), jamais de compte, jamais de télémétrie, jamais
  de ROSE en achat. Puis éventuellement packs cosmétiques.
- **Interdits (contrat kenos)** : publicité, abonnement, revente de
  données (de toute façon impossible — Ether Seal), paywall sur le
  Mindful Hold.
- **Hébergement du site** : la page de soutien est « commerciale » au
  sens du tier Vercel Hobby — migration à arbitrer vers Cloudflare
  Pages / GitHub Pages avant promotion active du lien.

## V3.18 — La landing rafraîchie (2026-09-04)

« On a fait pas mal de choses… il faut que ça claque. » Le one-pager
disait six territoires ; l'éther en vit neuf. Vérité produit d'abord —
chaque phrase correspond à une livraison réelle :

- **Univers : 6 → 9 territoires** (grille 3×3) : ajout du **Système
  nommé** (V3.12 — Lune/Vénus/Polaris + errants muets) et du
  **Reliquaire** (mémoire de sept jours locale, sept objets marqués
  braise) ; **Portes** et **Vestiges** séparés (crédits poésie domaine
  public — Rimbaud, Verlaine, Baudelaire) ; comètes rafraîchies
  (traînée phénix V3.12c).
- **Le Seuil gagne une ligne de garanties** : Ether Seal AES-256-GCM,
  lecture unique atomique, zéro donnée personnelle, bouclier qui
  avertit sans censurer, « le gardien compte les étoiles, jamais les
  mots » (V3.15/V3.16 en une phrase).
- **L'état du ciel actualisé** : univers entier livré / ciel vivant
  maintenant (refresh silencieux, mains marquées V3.18-app, bouclier) /
  cercles privés gelés inchangés.
- Composants existants uniquement — aucune nouveauté visuelle
  importée ; tokens registry intacts (teal/cyan pour la donnée, la
  braise n'apparaît qu'en mots).

## V3.19 — LE SALON : la constellation invitable ✅ (idée Hugo, livrée 2026-09-04)

Le cadavre exquis historique se jouait en salon, entre amis, à
l'aveugle — le rite est porté. Un anneau peut naître derrière une
porte : **un lien unique**, porté par le semeur à qui il choisit. Le
lien EST l'invitation (l'alternative « quasi gratuite » documentée
pour les clusters) — et la boucle de découverte est native : pour
poser sa ligne, l'invité entre dans le vide.

- **Arbitrages (recommandations adoptées, toutes réversibles)** :
  UN LIEN par anneau (chaque porteur pose une ligne, la règle
  un-inconnu-une-ligne intacte — invitations nominatives → Roadmap+) ·
  CACHÉ EN ÉCRITURE (un salon ouvert n'existe pas sur la carte, pas
  d'éther à deux classes ; refermé, l'artefact rejoint le ciel,
  indiscernable d'un poème d'étrangers) · **la clé est une
  capability** : 16 octets aléatoires en hex, la base ne garde que
  l'empreinte sha256 (un dump ne tient aucune porte), le clair vit
  dans le lien et sur l'écran du semeur — une fois.
- **Le claim EST la contribution** : la clé se vérifie DANS la
  transaction qui écrit la ligne (`KENOS_INVITE_UNKNOWN` — absent et
  faux se ressemblent, la porte ne dit rien). Aucun registre
  d'invités, aucun siège fantôme ; le lien meurt avec l'anneau
  (purge inchangée : ouvert 7 j, refermé une lune).
- **La porte SQL** : `seed_constellation(+p_invited)` rend la clé une
  fois · `contribute_line` / `peek_previous_line` l'exigent ·
  `fetch_invited_constellation` résout les MÉTADONNÉES seules (jamais
  la clé) · `fetch_constellations` ignore les salons ouverts.
- **Le seuil de l'invité** (`/#/c/<clé>` — hash routing GoRouter,
  zéro config serveur, prêt pour universal links le jour des stores) :
  un invité neuf croise le Seuil d'abord (`returnTo` + `onEntered` —
  le retour sur la même route est un no-op GoRouter, l'écran réagit
  lui-même), puis figure d'attente (stations de l'angle d'or,
  pleines/creuses), progression honnête, POSER MA LIGNE/PHRASE — le
  rituel existant, verbatim. Six états : résolution, clé morte (« LE
  SALON S'EST TU »), refermé (→ lire l'artefact public), déjà
  contribué, injoignable (+ RÉESSAYER), l'invitation.
- **Le semeur** : le seuil du cadavre choisit son public — DANS LE
  VIDE (défaut) ou EN SALON — puis la feuille de partage montre le
  lien UNE fois (PARTAGER `share_plus` / COPIER, fermeture uniquement
  par « J'AI PARTAGÉ » : la clé ne se perd pas par accident).
- **Observatoire** : compteur `salons_seeded` (sans contenu, même
  transaction) et `salons_open` dans l'état vivant. **Braise** : la
  main tendue de l'invitation — ember, avec parcimonie ; ROSE reste
  réservé à la destruction.
- Roadmap+ : invitations nominatives par siège, universal links /
  stores, URLs en chemin, ~~ancre locale des salons ouverts pour les
  participants, métrique `salon_opened`, mémo « mes salons »~~ (✅
  ancre locale + mémo « mes salons » → V3.31), mélange
  inconnus/invités dans un même anneau.

Gates : 174 invariants pgTAP (+22 : la clé rendue une fois et
l'empreinte ≠ clé, salon ouvert invisible / refermé visible, refus
sans et avec fausse clé, auto-close par la porte, peek gardé,
artefact public, aucun payload client ne porte la clé, chemin public
inchangé, métrique, empreinte inaccessible aux clients), 272 tests
Dart (+20 : parité démo de la porte, forme du lien, les états du
seuil, le parcours Seuil→salon, le panneau de partage, le choix du
public), analyze 0, e2e 28/28 (+10 sur l'éther local réel).

## V3.20 — Le garde-semeur et le faucheur (2026-09-06)

Le produit est public : l'audit anti-spam de lancement a montré un
socle réel (1 écho / 20 s, 1 lecture / 5 s, 3 vagues / 5 s, une
ligne par main par anneau, longueurs bornées serveur) — et deux
failles. Toutes deux colmatées :

- **Le garde-semeur** (trigger `BEFORE INSERT` sur
  `kenos_constellations`) : l'ancienne cadence ne comptait que les
  anneaux où l'appelant avait ÉCRIT — un script qui ne faisait que
  semer échappait à toute limite. Le trigger tamponne `seeder_id`
  (JWT serveur, jamais servi : `fetch_constellations` liste ses
  colonnes) et impose **1 semis / 2 min par main** et **5 anneaux
  ouverts par main** (en refermer un libère la place). Les mains de
  l'éther (jardiner, curater, migrations — sans JWT) sont exemptées ;
  être trigger le rend insensible aux réécritures futures de
  `seed_constellation`. Les anneaux survivent à leur semeur
  (`on delete set null`).
- **Le faucheur** : `kenos_purge` concentrait toutes les règles de
  rétention mais personne ne l'appelait jamais. pg_cron maintenant :
  `kenos-purge` chaque heure (:17) et `kenos-garden` chaque jour
  (07:30 UTC, remet le champ d'anneaux à 14). Le spam a désormais un
  fossoyeur automatique.
- Roadmap+ (au chaud) : **CAPTCHA sur l'entrée anonyme** (réglage
  dashboard Supabase, hCaptcha/Turnstile) — toutes les limites sont
  par compte, créer N comptes multiplie tout par N ; Supabase bride
  les signups par IP (~30/min) mais rien ne prouve l'humanité.
  À envisager si le trafic monte ou au premier incident.

Gates : +15 invariants pgTAP (`seed_guard.sql` : le trou bouché, la
cadence, le plafond, la place libérée, l'exemption sans claims,
l'absence de fuite du semeur) ; fixtures `rpc.sql` pliées à la
cadence (backdating selon la convention du fichier, mains de l'éther
sans claims). Suite pgTAP complète verte.

## V3.26 — L'origine et le voyage (2026-09-08)

La notion perdue de parcours revient à l'interception : chaque
lecture devient l'histoire d'un déplacement.

- **Le voyage conté** : la révélation lecteur gagne sa télémétrie —
  « DÉRIVÉ PENDANT … », « LANCÉ À X A.L. DE TON ŒIL » (distance
  réelle du point de lancement à l'œil au moment de l'interception,
  la devise A.L. du compteur de dérive).
- **L'origine réelle** (opt-in) : « NOMMER L'ORIGINE » au Miroir —
  le navigateur résout pays · région · ville (lookup IP libre, sans
  clé, UNE fois par session), l'auteur voit exactement ce que le
  lecteur apprendra. Le libellé voyage avec le sceau, servi SEULEMENT
  dans le bundle de consommation atomique — jamais sur la carte,
  jamais dans aucun fetch (pgTAP le veille). Borné à 96 caractères.
- **Privacy par architecture** : le lookup se fait dans le navigateur
  de l'auteur — l'éther ne voit jamais l'IP, seulement le libellé
  choisi. Anonymat par défaut, origine par choix.
- Hotfix au passage : un relicte 6-arguments de `launch_echo`
  (l'aube pré-média du projet) rendait PostgREST ambigu — mort, et
  sentinelle pgTAP : un seul `launch_echo`, pour toujours.

Gates : +7 pgTAP (`echo_origin.sql` : stockage, bundle, non-fuite
carte, borne 96, appel 8-args des clients déployés, sentinelle
d'unicité) ; +3 tests Dart (`origin_voyage_test.dart` : rivage,
anonymat préservé, distance tue à portée de main) ; parité démo
complète. 278 Dart verts, analyze 0, preuve live REST en prod.

## V3.28 — La Légende du Ciel (2026-09-08)

Le constat (Hugo) : « toujours des problèmes de répartition et
d'orbite — on doit mieux comprendre visuellement l'organisation pour
naviguer dans l'espace. » Trois causes structurelles, trois
arbitrages (2026-09-08), une même loi : le ciel doit se lire.

- **Les essaims en coques** : la bande hash-continue (0.075-0.145)
  devient TROIS coques discrètes (0.085 / 0.110 / 0.135), chacune à
  tempo fixe (210/300/390 s) — chaque anneau tourne comme un anneau,
  trois voies lisibles par planète au lieu d'un brassis. Les guides
  dessinés disent enfin vrai (l'ancienne paire 0.08/0.13 mentait).
- **Naître là où on dérive** : les coordonnées de lancement ne sont
  plus aléatoires — l'écho naît dans la bande de gravité de sa
  planète d'intention (`launchCoordsFor`). Le fetch par secteur, la
  télémétrie A.L. et les ancres de lignée racontent la même histoire
  que l'écran. Parité démo exacte.
- **Les errants ramenés** : l'anneau 0.62-0.74 vivait largement HORS
  du ciel naviguable — des rumeurs hors-cadre. Ramené à 0.55-0.65 :
  le lointain reste le lointain (clair de l'aphélie de Vénus), mais
  la marge du voyageur le visite vraiment.
- **LA CARTE DU CIEL** : le bouton CARTE (HUD) ouvre le schéma du
  système à l'échelle — cœur et exclusion, voies des ancrès et
  positions vivantes, coques, phare, anneau des errants, champ du
  repos, ton œil et son rayon de réception. Chaque corps nommé est
  un départ : la caméra glisse vers sa position vivante. Trois lois
  en légende : les échos orbitent l'intention qu'on leur confie ·
  les vestiges reposent — la culture ne tourne pas · les comètes
  traversent tout : des pensées portées.

Gates : +4 tests Dart (coques : appartenance et tempo par coque ;
naissance : bande de la bonne planète, bornes, déterminisme ; errants
bornés ; carte : construction, lois, voyage-referme) ; suite complète
284 verts, analyze 0. Les positions rendues changent à l'ouverture
suivante (coques nouvelles) — voulu : c'est la lisibilité demandée.

## V3.31 — L'Ancre du Salon ✅ (livrée 2026-09-10)

Le trou était en prod : le semeur refermait les deux feuilles sans
copier le lien — et sa propre porte lui devenait invisible pour
toujours (l'anneau ouvert n'existe pas sur la carte, le lien n'est
montré qu'une fois). L'ancre referme ce trou sans plier une loi :

- **Le mémo des portes** (`SalonAnchorStore`) : chaque appareil
  retient les salons ouverts qu'il porte — semeur dès le semage,
  invité dès sa première ligne revendiquée. La clé vit en
  `secure_storage` : le contrat « la clé existe dans le lien et sur
  l'appareil du porteur, nulle part ailleurs » tient, littéralement.
  Aucun contenu : jamais une ligne, jamais un poème — où dort
  l'anneau, comment frapper, rien d'autre.
- **La braise sur la carte** : graine ember et halo fin là où dort
  l'anneau — visible de son porteur seul. Pas de stations : l'anneau
  caché ne se dessine pas. Mains ayant donné : l'orbite fine « mine »
  en ember (grammaire partagée avec les cadavres publics). Statique
  et sobre — ROSE reste réservé à la destruction, rien ne bouge seul.
- **Le tap frappe à la porte** : ouvert et mains vides → l'offre de
  contribution (le semeur n'est qu'un étranger de plus pour son
  poème) ; ligne déjà donnée → « TA LIGNE EST DÉJÀ DANS CE CORPS » ;
  refermé → l'ancre se dissout, l'artefact public se lit aussitôt
  (indiscernable, la loi tient) ; mort → « LE SALON S'EST TU »,
  l'ancre s'en va avec la clé.
- **La loi des sept jours, en local** : une ancre plus vieille que
  le fauchage des anneaux ouverts se taille seule au chargement —
  même coupée du réseau, la mémoire ne garde pas des clés mortes.
- **Rafraîchissement** : ouverture de la carte et retour au premier
  plan, jamais dans le souffle des 90 s — les portes ne tirent pas
  sur l'éther.

Gates : +7 tests Dart (mémoire des portes : survie au redémarrage,
upsert, ordre, oubli, sept jours, JSON corrompu, zéro contenu) ;
suite 295 verts, analyze 0. Aucun SQL touché : la base ne sait
toujours pas qu'une porte est gardée — l'indiscernabilité de
l'artefact refermé reste totale.

## V3.32 — La Porte Ne Ment Plus ✅ (livrée 2026-09-11)

La plaie venait de prod : partout où l'app proposait une ligne, le
refus tombait à l'envoi — « L'ÉTHER A REFUSÉ LA LIGNE. », sans
raison. Deux causes, deux remèdes :

- **Le peek est la vérité de la porte** : la feuille demande déjà la
  ligne précédente à l'éther en s'ouvrant — elle avalait toutes les
  réponses et offrait son clavier même à un anneau mort. Un refus
  `KENOS_*` (anneau fauché à sept jours — `KENOS_NOT_FOUND` —,
  refermé ailleurs, clé de salon morte) tue maintenant le compositeur
  avant le premier mot : la feuille dit ce qui est vrai (« CET ANNEAU
  A RETOURNÉ AU VIDE. », « LE POÈME S'EST REFERMÉ AILLEURS. ») et
  n'offre plus que « RETOURNER AU VIDE ». Seul un éther injoignable
  laisse l'offre en place (fail-open, comme `hasContributed`) — rien
  n'a été refusé, le ciel était loin.
- **Chaque refus dit son nom** : `KENOS_NOT_FOUND`,
  `KENOS_UNAUTHENTICATED` et l'injoignable réseau (« L'ÉTHER EST
  INJOIGNABLE — LA LIGNE RESTE À TOI. ») entrent dans la grammaire de
  `contributeRefusalMessage` ; le message générique ne survit que
  pour un vrai refus PostgREST sans code connu. Le semis reçoit la
  même honnêteté : cadence (« LE CIEL SOUFFLE — DEUX MINUTES ENTRE
  DEUX ANNEAUX. ») et plafond de cinq anneaux ouverts (« TA MAIN
  TIENT DÉJÀ CINQ POÈMES OUVERTS. ») — les deux gardes actionnables,
  avant le silence.
- **Contrat** : `peekPrevious` propage les refus `KENOS_*` (null
  reste « le poème n'a pas commencé ») — le panneau de contribution
  est le seul appelant, la parité démo tient (`SalonKeyRefused`
  traverse).

Gates : +9 tests Dart (`dead_ring_test` : anneau dissous, refermé,
clé morte — jamais de clavier, jamais de ligne partie vers un mort ;
injoignable — fail-open ; mappers contribution et semis exhaustifs) ;
suite 304 verts, analyze 0. Aucun SQL touché.

## V3.33 — Le Corpus du Lundi ✅ (livrée 2026-09-11)

L'audit du LAUNCH_KIT disait vrai : le backlog d'artefacts ne tenait
plus que neuf lundis (à sec mi-novembre) — et le lundi de l'artefact
est un moteur de la vague d'annonces. Vingt slots curatés (11-30)
portent la réserve à vingt-neuf lundis, jusque début avril 2027.

- **La loi tient** : vrais fragments du domaine public, crédités
  (poète + œuvre + année), 4-7 lignes — la forme de l'anneau, jamais
  une ligne inventée. Huit voix françaises (Rimbaud, Apollinaire,
  Nerval, Lamartine, Verlaine, Mallarmé, Charles d'Orléans, La
  Fontaine), douze anglophones (Whitman, Byron, Stevenson, Yeats,
  Housman, Wordsworth, Emily Brontë, Edward Thomas, Hardy, Teasdale,
  Burns, Clare) — et les ciels y sont chez eux : « Of cloudless
  climes and starry skies », « Under the wide and starry sky »,
  « Ma seule étoile est morte ».
- **Domaine public vérifié poème par poème** : auteur mort depuis
  plus de 70 ans ET publication d'avant 1929 — les deux régimes
  satisfaits, l'Union comme l'Amérique disent oui. Au moindre doute
  sur un texte ou une édition, le poème est écarté, jamais deviné.
- **Insertion idempotente** au format exact du corpus (apostrophes
  ASCII dans le JSON, `''` doublé dans les littéraux SQL) ;
  `on conflict (slot) do update` rafraîchit les textes sans jamais
  toucher `released_at` — un slot libéré reste dépensé. Gates en
  conteneur jetable : 30 slots, 4-7 lignes chacun, slugs uniques,
  re-jeu vert (INSERT 0 30 deux fois).

Aucun code, aucun schéma : la mécanique V3.30
(`kenos_artifact_release`, cron du lundi 06:45 UTC) reste exactement
celle qui vit en prod. Déploiement quand la sélection est relue :
`bash scripts/prod_admin.sh filemulti
supabase/snippets/artifact_backlog.sql` (l'en-tête du fichier dit
tout). La relecture de goût n'est pas déléguée.

## V3.34 — La profondeur au voyage ✅ (livrée 2026-09-14)

Le constat (Hugo) : « peut-on améliorer la spatialisation, les notions
de voyages et distance ? » Le voyage était réel mais PLAT : la
parallaxe existait (accéléromètre, z par étoile) et ne bougeait pas
quand on voyageait — un seul plan de vitesse, paner ne donnait aucune
sensation de traversée.

- **Le champ profond** (`DeepFieldPainter`) : deux couches de poussière
  ancrées dans le monde mais chevauchant PLUS LENTEMENT que lui —
  facteurs 0.30 (le champ lointain, 90 motes) et 0.55 (la dérive
  proche, 48 motes). L'œil avance, le monde défile à sa vitesse, la
  poussière traîne derrière : le pan devient un passage, pas un
  scroll. Scenery, jamais matière : rien à lire, rien à tenir, rien
  compté — IgnorePointer, sous toutes les couches du monde, aucune
  interaction avec le champ de réception ni le souffle.
- **Le zoom aussi recule** : les couches profondes grossissent moins
  sous le pincement (zoom effectif `1 + (z−1)·f`), la poussière reste
  poussière — jamais un disque.
- **Déterministe par LCG stable** (pas `Random` : sa graine est
  définie par l'implémentation, et le ciel lointain doit être le même
  partout) ; recouvrement de viewport prouvé par test pour tout état
  légal de la caméra ; culling par mote (une comparaison hors écran).
  Zéro ticker : le champ lointain ne respire pas, il ne fait que
  reculer.

Gates : 10 tests Dart (`deep_field_test` : lois des couches,
déterminisme, bornes du plan, l'exactitude du facteur — la poussière
recule de f·δ quand le monde défile de δ — recouvrement pour toute
caméra légale, smoke de peinture, shouldRepaint) ; suite complète
327 verts, analyze 0. Zéro backend, zéro migration, parité démo
triviale (le décor n'a pas d'éther).

## V3.35 — Les paysages du vide ✅ (livrés 2026-09-14)

La distance était un nombre (le compteur A.L.) et un rayon (le champ
de réception) — jamais des LIEUX. Trois territoires, dits par le rayon
au cœur, alignés sur les lois existantes du ciel :

- **LE GOUFFRE** (r < 0.19) : le quartier du trou noir, juste au-delà
  de l'exclusion du repos (0.15) — où les comètes frôlent et rien ne
  repose. **LES JARDINS DE L'INTENTION** (0.19–0.54) : les deux voies
  et leurs coques — Polaris (r ≈ 0.523) veille le système, elle
  n'appartient pas au pays lointain. **LE PAYS LOINTAIN** (r ≥ 0.54) :
  au-delà de la bande de Vénus (0.515), les errants (0.55–0.65) y
  vivent — le vocabulaire de la CARTE DU CIEL, tenu.
- **Le HUD dit toujours où dérive l'œil** : la ligne silencieuse porte
  le territoire (« DÉRIVE 0.42 A.L. · LES JARDINS · … ») — la distance
  devient un lieu, pas qu'un nombre.
- **La traversée murmure, une fois** : franchir un territoire le dit
  en un souffle (titre machine + ligne serif, la grammaire du
  murmure d'œil), 7 s, IgnorePointer — puis le ciel s'en tait pour
  toujours. Le territoire de NAISSANCE n'est jamais salué (le ciel ne
  se salue pas lui-même) ; le franchir au retour, si.
- **Le drone boit le rayon** : la courbe `droneFactor` — plein dans
  les jardins (1.0, le son des pensées en orbite), bu par le gouffre
  (0.5), mince au pays lointain (0.6). L'axe du VOLUME seulement :
  l'axe du pitch appartient au Mindful Hold, les deux couplages ne se
  combattent jamais. epsilon 0.05, best-effort, muet en repli.

Gates : 13 tests Dart (`void_territories_test` : bornes honnêtes
contre l'exclusion, le coin de Polaris (0.523 — elle jardine), la
bande des errants, nœuds et jambes de la courbe du drone ;
`territory_whisper_test` : le paysage se dit en le traversant, UNE
fois — le territoire de naissance jamais salué, le retour si ; le HUD
dit toujours où dérive l'œil) ; suite complète 327 verts, analyze 0.
Zéro backend, zéro migration — le murmure vit sur le pouls de la
caméra, jamais sur un timer propre.

## V3.36 — La chute des jours ✅ (livrée 2026-09-14, révisée à la livraison)

La promesse non tenue de V3.7 : « les échos non interceptés à la
dérive s'approchent du trou noir jusqu'à la purge des 30 jours ».
Le retour de Hugo le 14/09 la rendait urgente : « on a du mal à
comprendre la notion de distance et la durée depuis laquelle un écho
dérive » — le temps et l'espace du ciel étaient déconnectés, un écho
de 29 jours orbitait comme un écho frais. La chute les fusionne :
**l'âge devient une distance**.

- **La loi (révisée)** : l'orbite d'un écho non lu DECROÎT avec l'âge —
  48 h de grâce dans sa voie (une pensée fraîche ne s'affaisse
  nulle part), puis chute linéaire sur le reste de sa lune, de sa
  coque jusqu'au bord du monde qu'on lui a confié (`landingRadius`
  0.02). La purge à 30 jours est l'atterrissage : **ce qui n'est
  jamais lu rentre chez son intention**. Autour de chaque monde,
  l'essaim se lit désormais trié radialement par temps de dérive.
- **Pourquoi tomber vers le monde et non vers le trou noir** (la
  variante de la première spec, écartée) : le fetch par secteur croit
  aux coordonnées de largage STOCKÉES ; une mourante rendue près du
  cœur serait invisible — son rect d'origine est loin. La chute vers
  le monde garde chaque mote DANS la bande de sa planète : le culling
  reste honnête, zéro SQL, zéro fetch en plus. Et le ROSE reste pur —
  réservé au trou noir, à l'accrétion et au burn ; une pensée qui
  rentre chez elle n'est pas une destruction. Le puits par union de
  la première spec : mort avec la variante qui le motivait.
- **Les arbitrages, pris (réversibles)** : (c) les scellées tombent
  aussi — même l'auteur voit sa confidence approcher du monde (la loi
  ne connaît pas l'auteur, testé) ; (b) la touche rose des derniers
  jours : refusée — la position EST le récit, aucun compteur, aucune
  étiquette, aucun coût visuel. Les comètes ne tombent pas : elles
  traversent déjà tout, elles meurent à leur manière (testé).
- **La distance lisible, aussi** : le souffle du HUD porte désormais
  ce que coûte la lumière la plus proche — « SOUFFLE VERS 3 H —
  0.84 A.L. » — la devise A.L. de la carte, enseignée en voyageant.
  La CARTE DU CIEL gagne sa quatrième loi : « les pensées non lues
  retombent vers le monde qui les porte ».
- Reduce-motion : la chute est une POSITION, pas une animation
  (l'époque gèle, l'âge passe — comme les orbites). Démo : parité
  exacte, le seed couvre tous les âges.

Gates : +5 tests Dart (`kenos_system_test` : la grâce — 47 h sur SA
coque à 1e-9 ; la chute monotone, atterrissage à la lune pile ; les
scellées soumises à la même loi ; les comètes vieillies traversent
toujours) ; +2 (`parallax_math_test` : la cadence du scintillement) ;
`sky_map_test` étendu à la quatrième loi ; suite complète verte,
analyze 0. Aucun SQL touché.

## V3.37 — Le pas des étoiles ✅ (livrée 2026-09-14)

Le signalement de Hugo : « en zoom maximal les échos qui se
déplacent saccadent ». Deux causes dans la machinerie de dérive :

- **Le layout par étoile et par frame** : `RenderStarShift` répondait
  à chaque mise à jour d'orbite par un `markNeedsLayout` — un passage
  de layout complet par étoile visible et par frame, là où l'offset
  n'est lu que par `paint` et le hit-test (les tailles ne changent
  jamais). C'est `markNeedsPaint` désormais : le raster en cache se
  recomposite, rien ne se relayoute.
- **Le plafond 30 fps du scintillement** : l'horloge des lueurs
  lointaines ne battait qu'un tick sur deux (la batterie du
  sanctuaire) — invisible à l'œil au repos, lisible en saccades dès
  que le zoom ×8 amplifie les vitesses. `glimmerFullRate` : passé
  `deepWatchZoom` (3×) le champ suit chaque battement ; en dessous le
  demi-rythme tient.
- Piste documentée si les saccades persistent sur appareil (non
  corrigée faute de profil) : les cercles pleins des voies/coques
  dans `SystemPainter` à 12.5 Hz (des rayons ×2.5 en zoom profond),
  et le raster des halos soufflants à 4 Hz — candidats à un
  respiration du pas ou à des arcs clippés, à trancher sur profil
  DevTools, pas au doigt mouillé.

Gates : +2 tests (`parallax_math_test` : le seuil du plein rythme) ;
`StarShift` inchangé en comportement visible (la suite widget le
couvre) ; suite complète verte, analyze 0.

## V3.38 — Le nom qui chevauche son monde ✅ (livrée 2026-09-14)

Le signalement de Hugo : « problèmes d'affichage et de décalage au
survol sur le module la carte ». Le coupable : l'étiquette de survol
des corps nommés (desktop) était figée à SA PREMIÈRE position — elle
ne se recalculait qu'au changement de cible, jamais pendant. Trois
défauts en découlaient : un monde qui orbite (la Lune, Vénus) ou un
ciel qui panne sous un pointeur immobile laissait le nom flottant au
vide ; l'ancrage en pixels fixes (−60/−44) imprimait le nom SUR le
corps dès le zoom profond ; le clamp supposait une largeur de 128 px.

- **L'état porte la CIBLE, jamais la position** : `_hoverTarget`
  (record wanderer/index, comparaison par valeur — un déplacement DANS
  le même monde ne coûte aucun setState). L'étiquette dérive sa place
  en direct sur le battement des cieux (le monde survolé continue
  d'orbiter) ET sur le pouls de la caméra (le ciel glisse sous le
  pointeur immobile). Un `Positioned` statique à l'origine porte une
  étiquette translatée — le ParentData ne vit jamais dans les
  builders qui battent.
- **L'ancrage honnête** : le nom se pose à DROITE de la zone de tap du
  corps (`planetTapRect`/`wandererTapRect` + 10 px) — à tout zoom la
  zone grandit avec le monde, le nom ne le recouvre jamais ; clamp
  rapporté à la largeur réelle du viewport.
- Reproduit et épinglé par tests AVANT la correction (l'ancien code
  échoue les trois : nom centré sur le monde, immobile au pan, largeur
  supposée) ; vérification visuelle tentée sur la PWA locale — le
  canvas vivant à 60 fps a raison de la surface de capture IAB, le
  test widget reste la preuve.

Gates : +3 tests Dart (`hover_label_test` : naît à côté jamais dessus,
suit le monde au pan ~120 px tolérance glide/orbite, quitte le monde
→ nom éteint) ; suite complète 337 verts, analyze 0.

## V3.39 — La carte retrouvée ✅ (livrée 2026-09-14)

Second signalement de Hugo, décisif : « il y a toujours un décalage…
la carte n'affiche QUE LA LUNE ». Le vrai coupable n'était pas le
survol (V3.38 a corrigé un vrai défaut, mais pas CELUI-LÀ) : le
schéma de LA CARTE DU CIEL plantait **en plein peinture**. Son
`_labelAt` créait un `TextPainter` NU — sans `textDirection` — et
sous le Flutter courant, `layout()` lève `Bad state`. L'exception
tombe au PREMIER libellé du schéma… LA LUNE. En release, le canvas
garde ce qui fut dessiné avant le jet et saute le reste : **une voie,
un monde sans nom — et plus rien**. Pas de Vénus, pas de Polaris, pas
d'errants, pas de cœur, pas d'œil. Le « décalage » et le « que la
lune », mot pour mot.

- **Pourquoi la suite n'a rien vu** : `sky_map_test` affirmait
  `find.text('LA CARTE DU CIEL')` — or `find` parcourt l'arbre des
  widgets, jamais les pixels ; une feuille dont le peintre jette
  reste « trouvable ». Seule une capture raster (golden) a exposé
  l'exception — le harnais temporaire a rendu la feuille : noire.
- **Le correctif** : `textDirection: TextDirection.ltr` sur le
  TextPainter du schéma (un painter nu n'a pas de DefaultTextStyle
  ambiant à qui se fier). L'Observatoire (`spectrum_bars`) l'avait
  déjà — le grep des `TextPainter(` nus ne trouve plus que la CARTE.
- **La garde** : un paintsmoke réel dans `sky_map_test` — les
  RenderCustomPaint de la feuille peints sur un vrai canvas ; toute
  exception de peinture tue le test désormais. (Une golden commitée
  aurait divergé par les fontes entre macOS et la CI ; le paintsmoke
  est déterministe partout.)
- Preuve du rétablissement : le golden du harnais passe de 7 Ko de
  noir quasi pur à 47 Ko de schéma complet (voies, coques, mondes
  étiquetés, errants, cœur, œil, chips, légende).

Gates : +1 test (`sky_map_test` : le schéma se peint SANS exception) ;
suite complète 338 verts, analyze 0. Une ligne de code changée — la
plus rentable du projet.

## V3.40 — Le vide traversable ✅ (livrée 2026-09-14)

Le signalement de Hugo : « des temps en temps des corps célestes se
positionnent vraiment trop près du bord de l'espace — difficilement
atteignables, et ça casse l'aspect immensité ». La cause est
GÉOMÉTRIQUE : les anneaux sont des cercles autour du cœur, l'éther un
carré [0,1] (+ une marge d'œil de 0,1). Les errants (r 0,55–0,65)
DÉPASSENT le carré sur les axes — Europe file jusqu'à x = 1,15 quand
l'œil ne voyait jamais au-delà de 1,10 : littéralement invisible et
inatteignable à certains passages. Vénus à son aphélie (0,87) et
Polaris dans son coin (0,13) colletaient le mur.

- **La réponse : agrandir le vide, pas reculer les corps.** La marge
  traversable passe de 0,1 à **0,5** — l'œil chevauche [−0,5, 1,5] :
  au-delà de la dernière lumière il existe du vide VRAI et
  traversable. Chaque corps nommé devient centrable à tout instant
  (loi épinglée par test sur 32 échantillons d'un jour et demi — les
  croisements d'axes compris), et « LE PAYS LOINTAIN — et le vide est
  plus vaste » devient une vérité qu'on peut parcourir. Le fetch par
  secteur reste honnête (le rect est clampé à [0,1] serveur ; hors de
  l'éther, il se dégénère et ne demande rien).
- **Le champ profond suit** : plan du décor élargi à [−0.4, 1.4],
  densité portée à 110/60 motes — la traversée du vide garde sa
  profondeur jusqu'au bout (couverture re-prouvée par le test existant
  qui énumère les caméras légales).
- **La CARTE** : l'œil du voyageur au-delà du rim se tient au bord du
  schéma (la direction gardée — le vide n'est pas la carte à dessiner).
- Reculer les errants à la place fut écarté : le monde se serait senti
  plus PETIT (le pays lointain ramassé dans le carré), l'inverse du
  symptôme signalé.

Gates : +2 tests (`travel_camera_test` : tout corps nommé centrable à
tout instant ; le vide reste borné — le monde n'est pas infini) ;
suite complète 340 verts, analyze 0. Zéro backend : la géométrie du
voyage vit client.

## V3.41 — Les deux portes ✅ (livrée 2026-09-14)

Le signalement de Hugo : les deux boutons d'action principaux
(SEMER UNE CONSTELLATION / FORMULER UN ÉCHO) sont « trop discrets, et
le violet sur fond d'espace est pas top ». L'audit confirmait : 9 px
de texte, la porte ÉCHO TRANSPARENTE (les étoiles imprimaient à
travers les mots), la porte CONSTELLATION en indigo 0.55 sur noir (le
violet boueux), et 36 px de haut — sous le plancher 44 px du projet.

- **Design Readiness Gate** : une seule famille, « LES DEUX PORTES »
  (`_GateDoor`) — la hiérarchie porte par la LUMIÈRE, pas par le
  bruit. La première porte (le Miroir, le geste du produit) : remplissage
  opaque teal 0.10 sur Void Black, bordure teal 0.85, texte pureLight
  0.95 à 10.5 px, souffle teal ~4 s — la lumière respire, LE TEXTE
  JAMAIS (plus de scale : l'espace entre les mots reste stable,
  lisible). La seconde porte : même famille un cran plus bas —
  hairline pureLight, texte 0.82, sans souffle. Cibles ≥ 44 px,
  `Semantics(button)`, relâchement qui tamise. **L'indigo meurt sur
  les portes** — il vit sur la carte (anneaux, artefacts fermés), là
  où il a du contraste ; registre tenu, aucun jeton neuf, ROSE
  toujours interdit.
- **Moins de Material, plus du registre** : le bouton cadavre était
  un OutlinedButton Material — le registre interdit les widgets
  brandés par défaut ; les deux portes partagent désormais le même
  composant signature.
- Au passage, un défaut de conception des tests de survol (V3.38)
  fut corrigé : ils visaient La Lune à l'horloge réelle — son orbite
  basse passe derrière les portes du bas à la mauvaise heure. Les
  sondes portent désormais La Lune à un point connu par un drag
  exact sans inertie (doigt immobile au relâcher) : les tests ne
  dépendent plus de l'heure.

Gates : +2 tests (`gates_test` : deux portes ≥ 44 px, remplissages
OPAQUES (alpha 1.0 — le ciel n'imprime pas à travers), bordures teal
ou lumière (plus de violet), la première porte porte le souffle et la
voix pleine) ; preuve visuelle par golden temporaire (texte 1,5–2× le
HUD, hiérarchie lisible) ; suite complète 342 verts, analyze 0.

## V3.42 — Le sens du Miroir ✅ (livrée 2026-09-14)

Le signalement de Hugo : « l'outil de formulation n'a pas le bon
sens — on ne voit pas qu'on peut catégoriser ou attacher une photo,
un son, un lien… ça arrive trop en bas et c'est trop discret ».
L'audit tenait : le champ de texte était `Expanded` — il mangeait
tout l'écran et poussait SOUS LE PLI, en chuchotant (9 px, alpha
0,55), tout ce que l'outil propose : l'intention (APAISER · CONFIER ·
ÉCLAIRER, texte nu), les attaches (`IMAGE · SON · PORTE`, mots
séparés par des points), l'origine.

- **L'intention d'abord** : les trois intentions montent SOUS le
  titre, en pastilles véritables — la sélection porte SA lumière
  (remplissage teinté du thème, bordure, texte), les autres gardent
  un hairline. Catégoriser se voit AVANT d'écrire : c'est la gravité
  de l'écho, pas une note de bas de page.
- **L'éditeur borné** : minLines 4, maxLines 9, plus jamais
  `Expanded` — la confidence a de la place sans manger l'écran.
  L'échafaudage `IntrinsicHeight`+`Center` (qui exigeait un enfant
  flexible pour absorber le clavier) cède la place au pattern
  remplir-sinon-scroller : la colonne s'étire et se centre quand elle
  est petite, scrolle quand elle est grande.
- **Les attaches vues avant d'être choisies** : une ligne serif dit
  ce qui peut voyager (« Une seule chose peut voyager avec elle,
  scellée sous la même clé »), et trois puces à bordure portent un
  **＋ visible** — `＋ IMAGE`, `＋ SON`, `＋ PORTE` (le ＋ vit À CÔTÉ du
  nom : les libellés exacts restent, les tests du dialogue de porte
  les épinglent). Attaché → la puce passe teal, le ＋ devient ·.
  L'enregistrement actif reste ARRÊTER — en teal désormais : arrêter
  un souffle n'est pas une destruction, le ROSE garde sa loi.
- **Le sceau en famille** : SCELLER & LANCER revêt la grammaire de la
  première porte (V3.41) — surface opaque lavée teal, bordure teal,
  10.5 px, voix pleine quand le sceau est possible, tamisée à 0.35
  quand il ne l'est pas. Toujours `OutlinedButton` : les tests du
  chemin d'envoi l'épinglent.
- **Un premier regard suffit** (loi épinglée par test sur 390×844) :
  intention, éditeur, attaches et sceau vivent dans le premier écran,
  dans cet ordre — rien ne se découvre en scrollant. Les harnais PII
  et porte-clavier passent en surface téléphonique (ils héritaient du
  800×600 par défaut, où la colonne enrichie dépassait le pli).

Gates : +3 tests (`mirror_sense_test` : l'ordre intention → éditeur →
attaches → sceau ; tout dans le premier écran ; trois ＋ visibles et
un éditeur né borné) ; preuve structurelle par golden temporaire
(pastilles sélectionnées teal, puces à bordure, sceau plein cadre,
rien coupé) ; suite complète 345 verts, analyze 0.

## V3.43 — Les grandes fenêtres ✅ (livrée 2026-09-14)

Le signalement de Hugo : boutons de création comme « miroirs », la
disposition est à revoir sur tablette et desktop. Large ne devait
plus être un téléphone étiré :

- **Les deux portes, côte à côte** (≥ 560 px) : deux portes de seuil
  se tiennent l'une à côté de l'autre, posées sur le même sol — la
  première garde son souffle de lumière plus haut. Sous 560, le
  téléphone garde l'empilement, là où vit le pouce.
- **Le Miroir en compositeur** (≥ 880 px) : la confidence possède la
  colonne de gauche, HAUTE (12–26 lignes — le desktop doit de la
  chambre au secret), et tout le reste se tient à droite :
  l'intention, les attaches ＋, l'origine, le sceau, le murmure. Un
  seul regard, rien ne scrolle. Sous 880, la colonne téléphonique de
  V3.42 reste, épinglée par ses tests. Les deux dispositions
  composent les MÊMES pièces (l'éditeur, les sections, le sceau
  extraits en méthodes partagées) — une seule loi, deux géométries.
- **LA LEÇON (attrapée par les tests, la plus chère de la
  session)** : le `Container` des portes portait
  `alignment: Alignment.center` — une boîte d'alignment S'ÉTEND à
  toute contrainte libre qu'on lui donne. Dans la colonne, il
  étalait la porte en largeur (inoffensif) ; dans le Flex horizontal,
  il a étiré chaque porte à 770 px de HAUT — le bloc avalait la
  moitié basse du ciel et **tout toucher de la carte**. Diagnostiqué
  par la chaîne de hit-test elle-même (`Align → SafeArea → Flex →
  porte`, au centre de l'écran). L'alignment est mort ; le padding
  symétrique centre déjà le texte. `CrossAxisAlignment.end` pose les
  portes sur le même sol.

Gates : +2 tests (`gates_test` : empilées sur téléphone, côte à côte
et même sol en large ; `mirror_sense_test` : le compositeur — le
secret à gauche, le sceau à droite, un regard) ; suite complète 347
verts, analyze 0.

**V3.43b — la mesure suit la disposition (2026-09-14)** : la capture
de Hugo à 1910×960 montrait le Miroir encore en colonne étriquée — le
compositeur large vivait TOUJOURS sous le cap téléphone de
`contentMaxWidth` (560) : deux colonnes serrées dans une bande
centrée, exactement ce que la disposition large venait corriger. Le
cap monte avec la disposition (`mirrorWideMaxWidth` 1020) : à 1910,
l'éditeur tient 507 px à gauche, les choix et le sceau se tiennent à
droite. Épinglé par le test (« l'éditeur ÉCHAPPE au cap »). Au
passage : une capture hébergeant un vieux bundle (PWA en cache) peut
montrer l'avant — recharger l'onglet avant de juger un déploiement.

**V3.43c — le compositeur est pour les fenêtres VRAIMENT larges
(2026-09-14)** : la seconde capture de Hugo (après rechargement fort)
montrait l'écueil inverse — sa fenêtre Retina fait 955×480 LOGIQUES :
le compositeur s'y déclenchait (≥ 880) et s'étalait bord à bord, mais
dans 480 px de haut l'éditeur haut poussait le sceau sous le pli.
Son mot de référence : « la partie constellation est bonne » — la
colonne unique propre et centrée. Le seuil monte à 1150 logiques :
sous lui, la colonne honnête (celle de l'écran constellation) sert
toutes les fenêtres ; au-dessus, le compositeur à pleine mesure.
Épinglé par test à 955×480 (empilement, sceau atteignable en un
geste).

**V3.43d — la colonne se tient au centre (2026-09-14)** : le verdict
final de Hugo tranchait net — le Miroir restait « ferré à gauche »
tandis que l'écran constellation était juste. Le code ancien du
Miroir portait un avertissement que la refonte V3.42 a supprimé avec
le `Center` : « sans le Center, la colonne s'épingle au bord gauche
(le bug de l'Aube, même famille) ». Le remplir-sinon-scroller a
remplacé `IntrinsicHeight`+`Center` — et perdu le Centre : toute
fenêtre plus large que la mesure montrait une colonne ferrée à
gauche, aucun test n'assertait le centrage. Le `Center` revient, au
-dessus du ScrollView exactement comme l'écran constellation — et le
test 955×480 épingle désormais le titre à moins de 40 px du milieu.

## V3.44 — Tous les supports, civilisés ✅ (livrée 2026-09-15)

L'audit demandé par Hugo après la série des grandes fenêtres :
qu'est-ce qui reste rugueux, par support ? Six livraisons d'un lot.

- **Le murmure « L'ÉTHER S'EST RAFRAÎCHI » (PWA)** : le service
  worker sert le dernier bundle INSTALLÉ jusqu'à la fermeture de
  tous les onglets — un correctif déployé y semblait « pas déployé »
  (cette confusion a mal jugé deux livraisons le 14/09). La barre
  (grammaire de la barre d'installation) parle quand un worker plus
  récent attend : RECHARGER recharge en contournant le cache
  (`?fresh=`), la frame suivante est le nouveau ciel. Vérifié au
  chargement, au focus, chaque minute — et `reg.update()` force le
  navigateur à chercher maintenant (il ne revient de lui-même que
  toutes les ~24 h).
- **ÉCHAP, le réflexe universel** : le Miroir se renonce au clavier
  (jamais pendant le scellement — une pensée en cours de scellement
  est au-delà du retrait, le geste aussi) ; les feuilles natives
  (CARTE, plaques) refermées par Échap sont désormais ÉPINGLÉES par
  test — un cadeau du framework qu'aucun test ne gardait.
- **La porte vit sous le curseur** : bordure et lavis se vivifient
  au survol des deux portes (pleine lumière), et les étoiles à
  portée de réception prennent le curseur main — le pointeur
  desktop sait enfin ce qui se tient.
- **Le téléphone plie l'inventaire** : sous 430 px, la ligne
  silencieuse garde DÉRIVE, le lieu et le souffle (le chemin de la
  maison et le où-suis-je) — les comptes (SCELLÉES,
  CONSTELLATIONS, VESTIGES) attendent un ciel plus large. Les puces
  ＋ passent à 44 px, le plancher du pouce.
- **La CARTE respire sur tablette** : ≥ 700 px, la mesure du
  schéma monte à 460 (les anneaux reprennent leur stature) ; les
  portes du HUD gagnent un cran de taille (11 px) au-dessus de 700.

Gates : +5 tests (`desktop_polish_test` : Échap renonce le Miroir,
Échap referme la CARTE, le survol vivifie la porte — alpha pleine
lumière, 390 px plie l'inventaire, la CARTE 460/compacte) ; suite
complète 353 verts, analyze 0.

Roadmap+ (arbitrages Hugo, hors lot) : **tenir une étoile au
clavier** (maintenir ESPACE 3 s comme le doigt — accessibilité et
desktop d'un coup, mais le rituel du hold se touche : à trancher) ·
**liens profonds du ciel** (un lieu du vide partageable en hash,
comme les salons `/#/c/<clé>` — généraliser le mécanisme).

## V3.45 — Ta main dans ce corps ✅ (livrée 2026-09-15)

Le signalement de Hugo : « j'ai du mal à repérer une constellation
fermée dans laquelle j'ai participé… on devrait au moins pouvoir
voir le résultat du cadavre exquis en tant que participant. L'aube
l'annonce pourtant. » L'audit a trouvé TROIS trous enchaînés — la
machinerie existait presque tout entière (mémoire des contributions
V3.31, lecture du poème refermé pour tous V3.13) mais elle ne se
voyait pas, ne guidait pas, et l'Aube mentait :

- **Le marqueur était invisible** : l'orbite « mine » faisait 4,2 px
  à alpha 0,45 DANS LA COULEUR DE L'ANNEAU — sur un artefact fermé
  indigo, une orbite indigo pâle parmi cent anneaux indigo. Elle
  passe en **EMBER** (la grammaire des salons : « mains ayant donné »
  — l'orbite ember), 5,5 px, alpha 0,85 : ta main se lit d'un coup
  d'œil sur tout ciel.
- **L'Aube prédisait des fermetures** : son compteur grimpe à la
  LIGNE (anneau encore ouvert), mais elle disait « s'est refermée ».
  Désormais elle dit vrai (« Ta main porte des poèmes d'étrangers…
  l'orbite ember les garde ») — et la fermeture RÉELLE est annoncée
  par la carte : au chargement des constellations, un poème de ta
  main refermé et non lu déclenche un murmure une-fois (« UN POÈME
  DE TA MAIN S'EST REFERMÉ » — refermé, lisible, ember) ; dit =
  mémoire persistante (`closureTold`), le ciel ne radote pas.
- **Rien ne menait au poème** : le souffle du HUD prend désormais la
  priorité du poème — « UN POÈME DE TA MAIN S'EST REFERMÉ — SOUFFLE
  VERS 3 H » jusqu'à la lecture (`PoemBreath`, pur). Le participant
  ne chasse plus : il suit le souffle, reconnaît l'ember, tape,
  relit.

Gates : +4 tests (`poem_breath_test` : le poème de ta main prend le
souffle — horaire exact ; ouvert/étranger/lu/gardé jamais ; le plus
proche gagne ; `closureTold` traverse le redémarrage) ; ligne d'Aube
épinglée réécrite (`awakening_test`) ; suite complète 357 verts,
analyze 0. Zéro SQL : toute la machinerie est locale, le poème
refermé reste public et indiscernable pour l'éther.

## 4. Règles inchangées (rappel)


- Single-read atomique, Ether Seal, RPC-only, ROSE destructif,
  haptique/audio non bloquants, demo mode iso-sémantique, lints
  `unawaited_futures` et Cie. Toute mécanique nouvelle passe par les
  mêmes épreuves (pgTAP + tests Dart + parity démo).
