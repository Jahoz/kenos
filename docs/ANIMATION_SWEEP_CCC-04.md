# Balayage d'animation CCC-04 — le « saut en arrière » de kenos

> Vague DDD de portfolio-os, 29/10/2026. Contradiction à trancher : le
> 25/10 le repo était « PRÊT DE BOUT EN BOUT » (#28 mergée, HUD V3.92,
> V3.92b déployée kenos-efkgvmmql), mais la note d'Hugo du 27/10 dit
> « Problème d'animation persiste sur kenos » (répétée le 28).
> J-11 avant le lancement visé (09/11).

## Le fil connu (ce que le repo dit déjà)

Le seul problème d'animation documenté comme OUVERT au 25/10 est le
**saut en arrière périodique** de la carte cosmique — le live report
historique cité par V3.58h : « repart en arrière à intervalle
régulier ». Quatre corrections ont échoué (V3.58h hystérésis à la
frontière alive/glimmer, V3.58i gate de tilt 0.008, V3.78e crossfade
de frontière, V3.80 la phase est une intégrale) ; V3.92 a alors posé
le HUD de télémétrie (tap 4 doigts → deltas Z/T/C) pour que le
coupable se nomme lui-même au prochain saut. **Personne n'a lu ce
verdict** : la note d'Hugo des 27-28/10 ne contient ni Z, ni T, ni C.

## Le balayage du 29/10 (mesuré, pas deviné)

Protocole : la carte au repos, échantillonnage du canvas à 2 fps,
suivi du barycentre lumineux des pixels > seuil (grille 64×86). Un
saut en arrière se lirait comme un pic de déplacement ou un
renversement de direction entre deux échantillons consécutifs
(500 ms) ; la dérive orbitale légale est lente (~0,23 unités-monde/min).

| Où | Mode | Durée | max/500 ms | renversements |
|---|---|---|---|---|
| kenos-lemon.vercel.app (déploiement du 25/10) | liaison (RPC 401 sans session) | 81 s, 119 deltas | 0,04 grille ≈ 0,5 px | 0 |
| build local `:4308` (main 924b817 + garde CCC-04) | démo | 55 s, 83 deltas | 0,05 grille ≈ 0,6 px | 0 |

**Le ciel au repos ne saute pas** — ni le champ d'étoiles, ni le
décor, ni le glimmer. Médiane du déplacement : 0,02 grille (~0,25 px),
le niveau du scintillement légal.

Limites honnêtes du balayage :

- **Le geste ne traverse pas l'headless** : dans le navigateur outillé
  de cette session, aucun événement pointeur (souris, molette, touch)
  n'atteint le canvas Flutter — seuls les clics sémantiques ARIA
  passent. Le pan, le pinch et le hold n'ont donc PAS pu être jugés
  ici ; le live report historique plaçait le saut **pendant le
  voyage**. Le HUD 4 doigts reste l'outil prévu pour ça — sur le
  téléphone d'Hugo.
- **Un seul site code reste capable d'un saut de caméra périodique**,
  non confirmé : `TravelCamera.attach()` re-clamp zoom ET centre à
  chaque changement de viewport. Sur navigateur mobile, la barre
  d'URL qui se cache/revient fait osciller le viewport à la cadence
  des pans — si l'œil est près d'un mur ou sous le plancher de zoom,
  chaque oscillation claque. Le HUD le nommerait : **Z et C ensemble**.

## Ce que le balayage a trouvé à la place (corrigé)

En servant le build local, la reproduction a heurté un crash boot :
**« Invalid argument(s): DSN is required. »** — sentry 9.30 jette
`ArgumentError` dès que le DSN est null (throw inconditionnel,
`sentry-9.30.0/lib/src/sentry.dart`). La promesse PWW-04 « absent =
no-op propre » n'a jamais été vraie : depuis le 20/10, tout build
sans `--dart-define=SENTRY_DSN` — la PWA démo locale, tout
`make dev-local` — mourait avant le premier cadre. Seul le déployé
vivait, son `.env.cloud` portant un DSN. Correctif CCC-04 : la garde
dans `main()` (sans DSN, `bootstrap()` direct — le SDK ne s'arme pas
du tout), test épingle la preuve (`boot_sentry_guard_test.dart`).

Si les tests d'Hugo des 27-28/10 passaient par la PWA locale, ils ont
vu un écran mort — un motif de « ça bloque » bien plus brutal qu'une
animation, et désormais réparé.

## La question à cocher (répondre dans la PR)

Au prochain saut visible : **poser 4 doigts d'un coup sur la carte**
(le HUD V3.92 s'arme) puis regarder la ligne `TELEM Z… T… C…` au
moment du saut. Trois cases :

1. [ ] **Z et C bougent ensemble au saut** → confirmé : le viewport
   oscille (barre d'URL / clavier) et `attach` claque — le fix sera
   dans `TravelCamera.attach` (amortir le re-clamp).
2. [ ] **T bouge beaucoup au saut** → la parallaxe capteur (piste
   V3.58i rouverte : le gate 0.008 est-il encore trop gros sur ton
   téléphone ?).
3. [ ] **Rien ne bouge dans TELEM** (Z/T/C tous ~0) → le saut vit
   dans les étoiles elles-mêmes : dire QUAND (pendant un pan ? au
   repos ? après une lecture ?) et où (une lumière précise, ou tout
   le ciel).

Et le contexte : PWA installée ou navigateur ? (La barre d'URL ne
touche que le navigateur.)
