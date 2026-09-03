-- ═══════════════════════════════════════════════════════════════════════
-- KENOS — the Vestiges Curator (2026-09-03)
--
-- Real curated culture: quotes (public domain or credited),
-- etymologies, histories, astronomy facts, haiku. NEVER a fake
-- confession — a Vestige is an artefact, re-readable, carrying no
-- author identity, no reception, no stardust.
--
-- Idempotent: upsert by id — rerun updates texts, adds new, keeps
-- positions stable. Retire a shard by deleting its line here and
-- running with live = false, or simply delete the row.
--
-- Usage (local):  docker exec -i supabase_db_kenos psql -U postgres \
--                    -d postgres -v ON_ERROR_STOP=1 \
--                    < supabase/snippets/curate_vestiges.sql
-- Usage (cloud):  supabase db query --linked \
--                    --file supabase/snippets/curate_vestiges.sql
-- ═══════════════════════════════════════════════════════════════════════

begin;

insert into public.kenos_vestiges (id, kind, text, source, pos_x, pos_y) values
-- ── The originals (the bundled twelve, positions kept) ──────────────
('v001', 'quote', 'Tu es fait pour te vider, comme le ciel se vide de ses nuages.', 'après Rilke', 0.42, 0.28),
('v002', 'etymology', 'KÉNOSE — du grec kenôsis, « vidange, dépouillement ». S''empty de soi pour laisser place au tout autre.', 'grec ancien', 0.65, 0.18),
('v003', 'quote', 'Le silence est un ami qui ne trahit jamais.', 'Confucius', 0.22, 0.52),
('v004', 'history', 'Les cadavres exquis naissent vers 1925, rue du Château : Breton, Éluard, Tzara plient le papier, chacun aveugle au fragment des autres — et le tout surprend tout le monde.', 'surréalisme', 0.84, 0.42),
('v005', 'etymology', 'ÉTHER — du grec aithêin, « brûler, flamber ». Ce qui brûle sans consumer : la lumière entre les étoiles.', 'grec ancien', 0.32, 0.36),
('v006', 'haiku', 'Dans le calme du vide / une bouteille dérive / quelqu''un lira.', 'kenos', 0.50, 0.50),
('v007', 'quote', 'Tout ce qui est profond aime le masque.', 'Nietzsche', 0.56, 0.34),
('v008', 'etymology', 'Silence — du latin silere, « être immobile, se taire ». Non pas l''absence de son : la présence du calme.', 'latin', 0.80, 0.82),
('v009', 'history', 'Le 16 septembre 1977, le Voyager 1 embarque un disque d''or : des voix, des musiques, une bouteille à la mer lancée vers nulle part — l''écho le plus lointain jamais donné.', 'Voyager 1', 0.72, 0.56),
('v010', 'haiku', 'Étoile fermée / la confidence a brûlé / le ciel reste grand.', 'kenos', 0.44, 0.68),
('v011', 'quote', 'On ne voit bien qu''avec le cœur. L''essentiel est invisible pour les yeux.', 'Antoine de Saint-Exupéry', 0.50, 0.28),
('v012', 'etymology', 'Constellation — du latin cum stella, « avec les étoiles ». Une figure qui n''existe que si des regards la relient.', 'latin', 0.50, 0.84),

-- ── The first curated harvest (positions dérivantes) ────────────────
('c001', 'fact', 'La lumière de la Lune met 1,3 seconde à t''atteindre ; celle du Soleil, 8 minutes ; celle d''Andromède, 2,5 millions d''années. Regarder le ciel, c''est lire le passé.', 'astronomie', 0.15, 0.45),
('c002', 'quote', 'Je suis fait d''obscurité et de marveilles.', 'après Rilke', 0.87, 0.46),
('c003', 'fact', 'Une journée sur Vénus dure plus longtemps qu''une année vénusienne : la planète tourne sur elle-même plus lentement qu''elle ne tourne autour du Soleil.', 'astronomie', 0.28, 0.50),
('c004', 'etymology', 'Écho — la nymphe grecque condamnée à ne répéter que la fin des phrases des autres. Ici, elle ne répète rien : chaque écho ne se dit qu''une fois.', 'grec ancien', 0.55, 0.50),
('c005', 'history', '1977 : on a entendu pour la première fois le « son » de l''espace — les ondes de plasma traduites en son par Voyager. Le vide chante, à sa manière.', 'Voyager', 0.25, 0.30),
('c006', 'fact', 'Il y a plus d''étoiles dans l''univers observable que de grains de sable sur toutes les plages de la Terre. Et pourtant, la plupart des confidences restent sans lecteur.', 'astronomie', 0.68, 0.28),
('c007', 'quote', 'Le vide n''est pas le néant : c''est ce qui reste quand on a tout donné.', 'kenos', 0.50, 0.72),
('c008', 'etymology', 'Pentatonique — cinq notes, aucune fausse possible. La gamme des musiques anciennes, du blues aux flûtes d''Asie : c''est elle que chante la symphonie des ondes.', 'musique', 0.50, 0.16),
('c009', 'fact', 'Les neurones et les galaxies ont la même densité de nœuds : environ 10^26 fois l''un plus grand que l''autre, mais le même motif. Le vide relie les deux.', 'science', 0.44, 0.39),
('c010', 'history', '1928 : Schrödinger écrit que la vie « se nourrit de négativité » — d''ordre qu''elle consomme. Se vider pour vivre : la kénose était déjà de la physique.', 'physique', 0.61, 0.64),
('c011', 'haiku', 'Bouteille lancée / la mer la porte sans bruit / quelqu''un veille, loin.', 'kenos', 0.16, 0.52),
('c012', 'etymology', 'Anonyme — du grec anônymos, « sans nom ». Ici, ce n''est pas un masque : c''est la condition.', 'grec ancien', 0.50, 0.60),
('c013', 'fact', 'Une bouteille à la mer met en moyenne 14 mois à traverser l''Atlantique. Les courants sont lents ; les confidences aussi.', 'océan', 0.35, 0.80),
('c014', 'quote', 'Les grandes pensées viennent du cœur.', 'Vauvenargues', 0.62, 0.47),
('c015', 'fact', 'Le son ne voyage pas dans le vide : la symphonie de l''éther n''existe que dans ton casque. La musique des sphères est toujours une écoute intime.', 'physique', 0.71, 0.73),
('c016', 'etymology', 'Comète — du grec komêtês, « chevelu ». Une pensée qui voyage garde quelque chose des cheveux au vent.', 'grec ancien', 0.38, 0.60),
('c017', 'history', 'Les sonnets de Louise Labé circulaient anonymement dans Lyon, vers 1555 — signés d''un nom que beaucoup croyaient un pseudonyme. La ville débattait ; elle se taisait.', 'Lyon, 1555', 0.43, 0.51),
('c018', 'fact', 'Chaque nuit, environ 100 tonnes de poussière d''étoiles se posent sur la Terre. Tu marches sur des confidences anciennes.', 'astronomie', 0.30, 0.50),
('c019', 'quote', 'Ce n''est pas parce que les choses sont difficiles que nous n''osons pas ; c''est parce que nous n''osons pas qu''elles sont difficiles.', 'Sénèque', 0.76, 0.50),
('c020', 'etymology', 'Bouteille — du grec butylon, passé par le latin. À la mer, elle est l''art d''envoyer sans savoir : le pari le plus doux de la navigation.', 'navigation', 0.57, 0.54)

on conflict (id) do update
    set kind = excluded.kind,
        text = excluded.text,
        source = excluded.source,
        live = true;

commit;
