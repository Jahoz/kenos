# LAUNCH_KIT — propager le sanctuaire sans dépenser un euro

> Audit du 2026-09-10 + playbooks + livrables prêts à coller.
> Objectif : deux moteurs ritualisés (Salons semés à la main, lundi de
> l'artefact) + une vague d'annonces (Show HN, presse FR, boards gratuites).
> Mesure : l'Observatoire (`make prod-watch`) — aucun analytics externe.

---

## 1. État opérationnel — verdict : OUI, avec une décision à prendre

Vérifié ce jour sur la prod (lecture seule, `prod_watch.sql` + `cron.job`) :

| Élément | État |
|---|---|
| Cron `kenos-artifact` (lundi 06:45 UTC) | ✅ actif en prod — dernier né : Victor Hugo, « Demain, dès l'aube » |
| Backlog d'artefacts | ⚠️ 9 poèmes restants ≈ 9 lundis (courir jusqu'à ~mi-novembre) |
| Cron `kenos-garden` / `kenos-purge` | ✅ actifs (quotidien 07:30 / horaire :17) |
| Flux Salon (créer → lien montré une fois → claim `/#/c/<clé>`) | ✅ code déployé, lien auto-construit sur l'origine réelle, invité neuf = règles d'abord puis claim |
| PWA + landing FR/EN | ✅ vivantes (`kenos-lemon.vercel.app`, `kenos-site.vercel.app/index_en.html`) |
| Vie organique | 43 visiteurs anonymes, 64 vestiges, 8 artefacts, réceptions réelles |

**La décision à prendre** : l'éther ne porte aujourd'hui qu'**1 écho
dérivant** (le ciel semé est parti, `prod-desow`, pour garder l'adoption
lisible). Un arrivant qui chasse des étoiles trouvera un ciel calme —
les 17 anneaux ouverts du Jardinier font vivre la carte, mais l'écho
lui-même est rare. Deux postures :

- **Rester désert** (choix actuel) : chaque écho lancé est un vrai
  signal, l'Observatoire mesure l'adoption pure. Cohérent avec
  l'esprit du sanctuaire — la rareté est une profondeur.
- **Ressemer** (`make prod-sow`, 360 échos scellés réels, jamais
  d'étoile morte) : le ciel respire pour l'arrivée d'une vague, puis
  `prod-desow` quand l'adoption est lancée.

Recommandation : ressemer **une fenêtre de lancement** (semaine du Show
HN / presse), puis désemer. L'outil existe pour exactement ce cycle.

---

## 2. Playbook — les Salons semés à la main

### L'anonymat, précisément

Le contrat tient : la plateforme ne sait **rien** de qui est invité. La
base ne garde que l'empreinte sha256 de la clé ; l'invité arrive par un
auth anonyme silencieux ; l'anneau ouvert est invisible sur la carte.
Le seul lieu où l'identité existe, c'est **ton canal d'envoi** (Signal,
mail…) — hors du sanctuaire, par construction. Toi, semeur, tu restes
anonyme *dans* kenos ; tu choisis simplement *qui reçoit la porte*.

### Salon ≠ galaxie privée (ne pas confondre — décision 2026-09-04)

Ce qui a été **écarté** (roadmap V3.16/17), c'est le multi-tenant
in-app — les « galaxies privées », le kenos pour cercles clos
(équipes, CSE, entreprises) : l'anonymat en cercle connu est un leurre
(mort de Secret et Yik Yak), refusé pour l'instant. L'alternative
validée pour ce besoin : **un déploiement Supabase séparé** + une
build pointant dessus, zéro code. Le Salon (V3.19) est un autre animal :
un cadavre exquis invitable — des lignes de poème à l'aveugle, jamais
des aveux ; refermé, l'anneau devient un artefact **public**. L'écho
intime, lui, ne voyage JAMAIS en cercle clos — c'est la ligne rouge,
et elle tient.

### Le geste, pas à pas

1. Dans l'app : lancer une constellation **invitable** (Le Salon).
2. Le lien t'est montré **une seule fois** — copie-le immédiatement
   (presse-papiers, sinon il reste à l'écran mais ne reviendra plus).
3. Envoie-le à UNE personne choisie, avec un mot personnel. Exemple :
   « Une porte. Une ligne à écrire à l'aveugle, sans savoir ce que les
   autres ont posé. Elle ferme dans 7 jours. »
4. Elle ouvre : règles du seuil, puis claim — puis une ligne chacun,
   la précédente visible, jamais le tout.
5. Anneau refermé → l'artefact rejoint l'éther public, indiscernable.
6. **L'ancre ember (V3.31)** : ta porte reste sur TA carte (clé gardée
   localement, sans contenu) — tu rouvres et poses ta ligne sans
   dépendre du lien copié ; elle meurt avec l'anneau à 7 jours.

### Contraintes opérationnelles

- **Fenêtre de 7 jours** : sème à des gens qui joueront dans la
  semaine, sinon l'anneau meurt avec le lien.
- Un seul lien par anneau — pas de relance possible, le lien meurt
  avec lui.
- Le claim EST la contribution : pas de spectateur, seulement des
  mains.

### La liste des semeurs (semaine 1)

20–30 personnes, une porte chacune. Critères : poètes, designers,
voix du « calm tech » / minimalisme numérique, amis sensibles. Préfère
la qualité à la liste — chaque salon est un cadeau, pas une campagne.
Rythme : 10 la première semaine, lire l'Observatoire
(`corpses_seeded`, `lines_contributed`), compléter ensuite.

---

## 3. Playbook — le lundi de l'artefact

La naissance est **déjà automatisée** : chaque lundi 06:45 UTC
(08:45 Paris), `kenos-artifact` libère le poème suivant du backlog,
avant la montre de 09:00. La part humaine est le partage :

- **Heure fixe** : publier chaque lundi à 12:00 Paris (l'artefact est
  né le matin, la lune dure 30 jours — jamais « trop tard »).
- **Format** : capture verticale 15–20 s de l'artefact (le poème, la
  figure à l'angle d'or, la dissolution), son ambient de l'app, texte
  court : poète + titre + « lisible jusqu'au <date> » + le lien
  `https://kenos-lemon.vercel.app`.
- **Canaux** : TikTok / Reels / Shorts (téléphone, sans visage), post
  X/LinkedIn FR. Un compte « KENOS » séparé du tien garde ton
  anonymat d'auteur — le sanctuaire n'a pas de comptes, toi si.
- **Runway** : 9 lundis devant nous. Avant mi-novembre, grossir le
  corpus (`supabase/snippets/artifact_backlog.sql` est idempotent —
  `make prod-artifact-backlog` recharge sans dupliquer).

---

## 4. Livrable A — le post Show HN (anglais, prêt à coller)

Lancer mardi ou jeudi, 13:00–16:00 UTC (matin US). Répondre aux
commentaires pendant 4–6 h — sur HN, la conversation EST le lancement.
Le lien du post : la PWA. Ne pas voter soi-même avec des comptes amis
(radar anti-manipulation).

**Titre :**

```
Show HN: Kenos – an anti-social network where each message can be read exactly once, ever
```

**Corps :**

```
Kenos is a quiet corner of the internet built on one promise: when you
release a thought into the ether, exactly one stranger will read it,
once, and then it is destroyed. No profile, no likes, no comments, no
feed. Just a dark star map, sealed thoughts drifting as stars, and a
10-second reading window before the message dissolves into particles.

A few details I care about:

- Reading a message requires holding a star for 3 full seconds. The
  gesture is the product: you give your attention before you take
  someone's thought.
- "Read exactly once" is enforced server-side with an atomic
  FOR UPDATE SKIP LOCKED transaction — two people holding the same
  star at the same millisecond, only one wins, the other sees "this
  echo dissolved elsewhere".
- Messages are end-to-end encrypted on the device (AES-256-GCM, a
  fresh key per message, key escrowed and exchanged inside that same
  atomic transaction). A database dump contains only ciphertext. The
  accepted trade-off: even the author can never re-read what they
  released. You give to be free.
- After reading, the reader may leave one trace (≤140 chars, one
  shot, no reply possible). Sometimes silence is the answer — and the
  author sees the trace exactly once, too.
- There are also "constellations": blind exquisite-corpse poems. Each
  player writes one sealed line, sees only the previous line, and the
  finished poem becomes a public "artifact" that lives for one 30-day
  moon. Every Monday morning a new artifact is born from a
  public-domain backlog (this week: Victor Hugo). Permanent culture
  shards — quotes, etymologies — are "vestiges" and never expire.

The interface is French; the gesture is universal (I hope). The web
version is a PWA — nothing to install. The code is source-available
(non-commercial) and the SQL layer carries 174 pgTAP invariants:
https://github.com/Jahoz/kenos

I'd be glad to sow a private "salon" (a one-link, invite-only
constellation) for anyone who wants to write a line — say the word
and I'll send you a door.
```

---

## 5. Livrable B — le mail presse français (prêt à envoyer)

Destinaires premiers : Numerama (ils aiment les objets internet
poétiques), iGen, Mac4ever, 01net. Trouver l'adresse de la rubrique
« apps » sur chaque site ; personnaliser la première phrase par media.
Envoyer mardi ou mercredi matin, 9:00–10:00.

**Objet :** `Une app française où chaque pensée ne sera lue qu'une seule fois au monde`

**Corps :**

```
Bonjour,

Je développe seul, sans budget, une application française qui refuse
tout ce qui fait un réseau social : KENOS (du grec « kénose », se
vider de soi-même).

On y lance une pensée intime, anonyme, chiffrée sur son appareil,
dans un éther cosmique. Une seule personne au monde pourra la lire —
un appui de trois secondes sur son étoile, dix secondes de fenêtre,
puis elle s'autodétruit. Pas de profil, pas de likes, pas de fil
d'actualité : l'inverse d'une métrique d'engagement. Après la
lecture, le lecteur peut laisser une trace de 140 signes, une seule,
sans réponse possible — le signal qu'on a touché quelqu'un.

Il y a aussi des « constellations » : des cadavres exquis joués à
l'aveugle, où chacun ne voit que la ligne précédente. Le poème fini
rejoint l'éther comme un « artefact » public, crédité (domaine
public), qui vit une lune de trente jours — chaque lundi matin, un
naît. Cette semaine : Victor Hugo, « Demain, dès l'aube ».

Tout fonctionne dans le navigateur (PWA, rien à installer) :
https://kenos-lemon.vercel.app — le code est public et l'app est
gratuite.

Si le sujet vous tente, je vous sème volontiers un « salon » privé :
un lien unique, une ligne à écrire à l'aveugle, sept jours avant que
la porte ne se referme. C'est la meilleure façon de le vivre.

Bien à vous,
Hugo
```

---

## 6. Livrable C — les boards gratuites (soumission en demi-journée)

Règle d'or : **ne jamais tout lancer le même jour**. Étaler sur deux
semaines, un canal par jour, pour que l'Observatoire attribue chaque
vague. Préparer une fois : logo carré, 3 captures (carte, hold/burn,
artefact), description EN 60 mots + FR 60 mots, lien PWA.

| Board | Coût | Délai / procédure | À préparer |
|---|---|---|---|
| [Uneed](https://www.uneed.best) | gratuit | file d'attente ~1–2 semaines, programmation | logo, captures, tagline EN |
| [Peerlist Launchpad](https://launchpeerlist.com) | gratuit | choisir sa date de lancement | page produit, maker bio |
| [Microlaunch](https://microlaunch.net) | gratuit (boost payant, refuser) | revue rapide, listing durable | description EN, lien |
| [Fazier](https://fazier.com) | gratuit | lancement programmé | captures, description EN |
| [Dev Hunt](https://devhunt.org) | gratuit | hebdo, produit tech | angle code (repo, pgTAP) |
| [Tiny Startups](https://tinystartups.io) | gratuit | annuaire, validation éditeur | logo, catégorie well-being |
| [itslaunched](https://itslaunched.com) | gratuit | 10 lancements par période seulement | description EN |
| Product Hunt | gratuit | mardi–jeudi, préparer galerie + vidéo EN | faire APRÈS Show HN et presse — la neige d'audience y est meilleure fraîche |

Ordre conseillé : boards mineures (semaine 1, un/jour) → Show HN +
presse FR + 10 salons (semaine 2, mardi/mercredi) → Product Hunt la
semaine suivante, alimenté par les retours corrigés.

---

## 7. La mesure

Tout se lit dans l'Observatoire (aucun cookie, aucun analytics) :

```bash
make prod-watch   # lecture seule : série 7 j, ciel vivant, backlog
```

Signaux qui comptent pour cette campagne : `new_users`,
`echoes_launched` (le vrai passage à l'acte), `lines_contributed`
(les salons prennent), `traces_left` (les lectures touchent).

## 8. Roadmap+ (noté, pas maintenant)

- `og:image` générée pour l'artefact du lundi (partage beau par défaut).
- Vestiges exposés en pages publiques sur le site (SEO longue traîne —
  ils sont permanents par définition).
- Grossir le corpus du backlog avant mi-novembre (9 lundis restants).
