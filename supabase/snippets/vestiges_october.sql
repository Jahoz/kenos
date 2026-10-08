-- KENOS — the October harvest: 12 hand-curated vestiges (2026-10-08).
--
-- The sky fell silent: 179 echoes drift unread, the last read was
-- weeks ago. The vestiges are the layer that NEVER dies — they are
-- what a lone traveller finds when nobody else is writing. This
-- harvest leans into the quiet: fragments about silence, distance,
-- light, and what survives. Same voice, same law: REAL, CREDITED,
-- never a fabricated confession.
--
-- Run: bash scripts/prod_admin.sh filemulti supabase/snippets/vestiges_october.sql
-- Then verify:
--   bash scripts/prod_admin.sh sql "select count(*) from public.kenos_vestiges where live"

insert into public.kenos_vestiges (id, locale, kind, text, source, pos_x, pos_y) values
('ov01', 'fr', $$etymology$$, $$SILENCE — du latin silere, « être immobile, se taire ». Non pas l'absence de son : la présence du calme. Le silence a un poids, et le vide le porte.$$, $$latin$$, 0.12, 0.18),
('ov02', 'fr', $$fact$$, $$La lumière du Soleil met 8 minutes et 20 secondes à t'atteindre. Celle d'Orion, 1 344 ans. Chaque regard vers le ciel est une conversation avec le passé.$$, $$astronomie$$, 0.85, 0.14),
('ov03', 'fr', $$haiku$$, $$Bouteille ouverte / le vide la prend tout entière / quelqu'un viendra.$$, $$kenos$$, 0.32, 0.72),
('ov04', 'fr', $$etymology$$, $$MÉMOIRE — du latin memoria, « faculté de se souvenir », racine sanskrite smri, « mettre ensemble ». Se souvenir, c'est rassembler ce que le temps a dispersé.$$, $$latin$$, 0.68, 0.88),
('ov05', 'fr', $$quote$$, $$« Le vide est ce qui reste quand on a tout donné. »$$, $$après Rilke$$, 0.15, 0.44),
('ov06', 'fr', $$fact$$, $$Une goutte d'eau peut rester dans l'atmosphère 9 jours avant de retomber. Une confidence, dans l'éther, peut dériver 30 jours avant d'être lue — ou disparaître sans lecteur.$$, $$océan$$, 0.75, 0.38),
('ov07', 'fr', $$history$$, $$En 1977, les sondes Voyager ont embarqué un disque d'or gravé de 115 images et 90 minutes de musique terrestre. Une bouteille à la mer lancée à 17 km/s — toujours en vol, toujours inconnue de son destinataire.$$, $$Voyager$$, 0.22, 0.82),
('ov08', 'fr', $$etymology$$, $$ÉTOILE — du latin stella, du grec astêr. Ce qui brûle en silence à des années-lumière, et dont la lumière arrive quand même. Comme une confidence lâchée dans le vide.$$, $$grec ancien$$, 0.58, 0.28),
('ov09', 'fr', $$haiku$$, $$La pensée part / le ciel ne la retient pas / quelqu'un la lira.$$, $$kenos$$, 0.44, 0.12),
('ov10', 'fr', $$fact$$, $$Le point de Lagrange L2, où le télescope James Webb observe l'univers, se trouve à 1,5 million de kilomètres de la Terre — quatre fois plus loin que la Lune. Un poste d'écoute au bord du vide.$$, $$astronomie$$, 0.88, 0.62),
('ov11', 'fr', $$etymology$$, $$DÉRIVE — du latin derivare, « détourner de sa source ». Ce qui dérive n'est pas perdu : il suit un courant que personne ne voit.$$, $$latin$$, 0.18, 0.56),
('ov12', 'fr', $$fact$$, $$Le son se propage dans l'eau à 1 480 m/s — quatre fois plus vite que dans l'air. Les baleines chantent à des dizaines de kilomètres. L'éther, lui, porte les pensées instantanément — mais une seule fois.$$, $$océan$$, 0.52, 0.48)
on conflict (id, locale) do nothing;
