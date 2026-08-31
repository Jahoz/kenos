# KENOS — Manifeste Produit V2 (archivé tel que soumis)

> Archivé le 2026-08-31. Document de direction produit soumis par Hugo.
> L'analyse d'alignement et le plan d'incréments vivent dans
> [`ROADMAP_V3.md`](ROADMAP_V3.md). Le POC de référence de la Symphonie
> Collective vit dans [`poc/`](../poc/).

---

KENOS // THE COSMIC INTROSPECTION ENGINE

Manifeste Produit & Technical Design Document (TDD)
Version 1.0 — Architecture : Flutter + Supabase

## 1. VISION & PHILOSOPHIE (LE CONCEPT)

KENOS n'est pas un réseau social. C'est un anti-réseau.
C'est un sanctuaire cryptographique conçu pour l'introspection, la
libération émotionnelle et la compassion asynchrone. L'objectif est de
combattre la saturation cognitive en offrant un espace de "Single
Receiver" (Un émetteur, un récepteur unique).

Les 3 Piliers (Règles d'Or de l'UX) :

- **Zéro Égo, Zéro Bruit** : pas de likes, pas de followers, pas de
  profil public, pas de commentaires. L'anonymat est absolu
  (représenté par des hash cryptographiques type 0x8F...).
- **Friction Volontaire (Mindful UI)** : rien ne se consomme
  frénétiquement. Lire ou écouter demande une action physique prolongée
  (Mindful Hold).
- **Éphémérité Absolue** : une fois qu'une donnée touche une
  conscience, elle est détruite de l'univers (burn after
  reading/listening).

## 2. LES MÉCANIQUES FONDAMENTALES (FEATURES)

### A. L'Éther et la Cosmic Map

L'interface principale n'est pas un feed vertical, mais une carte
spatiale 2D avec profondeur (Parallaxe 3D).

Les messages des autres sont des étoiles flottantes.

La position est calculée en Années-Lumière (A.L.) relatives au nœud du
joueur.

**Intouchabilité** : l'utilisateur voit ses propres messages (bouteilles
à la mer) dériver et s'éloigner, mais ils sont verrouillés. Il ne peut
lire que ce qui ne lui appartient pas.

### B. Le "Mindful Hold" (L'Appui Long)

Pour lire un écho, l'utilisateur doit maintenir son doigt sur l'étoile.

- Un anneau de progression se remplit.
- L'audio spatial monte en intensité.
- Le relâchement avant 100 % annule l'action.

### C. Le "Sling-Shot" (Destruction vs Amplification)

Une fois l'écho lu, l'utilisateur a le pouvoir de décider de son sort
via un geste de Drag (Glisser) :

- **Swipe Down (Cendres)** : le message est incinéré. Il disparaît à
  jamais.
- **Swipe Up (Rebond)** : le message est amplifié. L'utilisateur lui
  redonne de la vélocité. Le message regagne l'espace, sa colonne
  momentum augmente, et il laisse désormais une "queue de comète"
  visuelle pour les prochains découvreurs.

### D. La Symphonie Collective (Ondes & Fréquences)

Communication primale sans mots.

L'utilisateur génère une onde colorée et sonore en touchant l'espace.
(Axe Y = hauteur de note / gamme pentatonique).

**Audio spatial** : le client ne joue que les ondes émises dans son
rayon virtuel de détection. Le volume s'ajuste selon la distance
(PostGIS ST_DWithin).

### E. L'Aube (The Awakening)

Le remplacement des notifications. À l'ouverture de l'application,
l'utilisateur traverse un sas de connexion :

- Des phrases poétiques affichent l'impact de l'utilisateur pendant son
  absence ("Votre secret a libéré un inconnu").
- Le Nœud d'Origine de l'utilisateur sur la carte brille d'une aura
  chaude (ambre) et accumule de la Stardust si son impact communautaire
  est positif.

## 3. ARCHITECTURE TECHNIQUE (FLUTTER + SUPABASE)

### 3.1 Supabase — Schéma de base de données (PostgreSQL)

**Table `users_impact`** — gère l'Aube et l'Aura du joueur.

- id (uuid, PK)
- secrets_read_by_others (int, incrémenté via trigger quand un de ses
  secrets est détruit)
- stardust_accumulated (int, gagné quand l'utilisateur lit un secret)

**Table `echoes`** (les bouteilles à la mer)

- id (uuid, PK)
- author_id (uuid, FK — pour l'intouchabilité)
- content (text / cipher)
- type (enum : 'text', 'audio', 'photo')
- x_pos, y_pos (float — ou Point PostGIS)
- momentum (int, default 0 — le nombre de rebonds)
- is_consumed (boolean, default false)

**Table `frequencies`** (la symphonie)

- id (uuid, PK)
- freq_value (float)
- x_pos, y_pos (float)
- created_at (timestamp) — un cron ou TTL purge les ondes > 60 secondes.

### 3.2 Sécurité & Concurrence (les RPC Supabase)

Pour éviter que deux utilisateurs ne lisent (et détruisent) le même
message éphémère en même temps, nous devons utiliser des fonctions RPC
atomiques.

```sql
-- Fonction RPC pour le "Mindful Hold"
CREATE OR REPLACE FUNCTION claim_echo(target_echo_id UUID, user_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
  locked_echo RECORD;
BEGIN
  -- SELECT FOR UPDATE évite les race conditions
  SELECT * INTO locked_echo FROM echoes
  WHERE id = target_echo_id AND is_consumed = false
  FOR UPDATE SKIP LOCKED;

  IF FOUND THEN
    -- On ne le marque pas encore consumed (laisse le temps du
    -- sling-shot). Mais on pourrait le verrouiller avec un
    -- `locked_by` et un `locked_at`.
    RETURN TRUE;
  ELSE
    RETURN FALSE;
  END IF;
END;
$$ LANGUAGE plpgsql;
```

### 3.3 Directives Flutter (front-end)

1. **Gestion d'état (Riverpod ou BLoC)** :
   - MapState : doit gérer les positions (X, Y, Z pour la parallaxe).
   - L'axe Z (parallaxe) est simulé côté client : les objets lointains
     (z < 0.5) bougent moins sur le onPanUpdate du background que les
     objets proches (z > 1.0).

2. **Animations & interactions** :
   - Mindful Hold : GestureDetector avec onLongPressStart, un
     AnimationController de 2000 ms. Si onLongPressUp ou
     onLongPressCancel avant 100 %, faire un `.reverse()`.
   - Sling-Shot : Dismissible ou GestureDetector custom sur la carte
     révélée. onPanUpdate pour déplacer la carte en Y. Si deltaY < -100
     → RPC Amplification. Si deltaY > 100 → RPC Destruction.
   - Constellations (CustomPaint) : étoiles, halos (aura) et comètes
     dessinés via CustomPainter pour garantir 60 fps, même avec 200
     éléments à l'écran. Éviter d'instancier 200 widgets complexes.

3. **Moteur audio spatial** : le package `flutter_soloud` est
   obligatoire — spatialisation 3D native, gestion fine des
   oscillateurs pour la Symphonie, n'engorge pas le thread principal.
   L'audio doit être indexé sur la valeur de l'AnimationController
   (ex. : la fréquence du drone monte exactement en même temps que
   l'anneau se remplit).

## 4. TRAITEMENT DES MÉDIAS (RÈGLES UX STRICTES)

- **Photos** : upload sur Supabase Storage. L'image n'est jamais
  affichée nette. Elle subit un shader (glitch pastel ou constellation
  de points). Le Mindful Hold dé-brouille l'image progressivement.
- **Audio (voix)** : joué à l'envers ou avec une distortion radio tant
  que l'appui long n'est pas complété.

---

Fin du manifeste. KENOS : *Preserve the silence.*
