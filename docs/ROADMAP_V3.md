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

## 4. Règles inchangées (rappel)

- Single-read atomique, Ether Seal, RPC-only, ROSE destructif,
  haptique/audio non bloquants, demo mode iso-sémantique, lints
  `unawaited_futures` et Cie. Toute mécanique nouvelle passe par les
  mêmes épreuves (pgTAP + tests Dart + parity démo).
