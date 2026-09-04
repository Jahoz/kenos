-- KENOS — AI-sown vestiges (generated 1788484888785, verified pass included).
-- Review the staging file before trusting this blindly: the verifier
-- drops and fixes, but the human stays the final gate.
begin;
insert into public.kenos_vestiges (id, kind, text, source, pos_x, pos_y) values
('ai-1788484888785-00', 'fact', 'La lumière du Soleil met 8 minutes pour franchir les 150 millions de kilomètres qui nous en séparent — distance appelée « unité astronomique ».', 'astronomie', 0.680, 0.500),
('ai-1788484888785-01', 'fact', 'Nuage de Magellan : galaxie naine visible à l''œil nu, mais sa lumière met 163 000 ans à nous parvenir.', 'astronomie', 0.505, 0.842),
('ai-1788484888785-02', 'haiku', 'Poussière d''étoiles / le vent dans l''absinthe / personne pour compter.', 'kenos', 0.346, 0.950),
('ai-1788484888785-03', 'fact', 'La nuit, la Voie lactée est un fleuve de lumière — mais sa clarté que nous percevons traverse des régions de poussière interstellaire s''étendant sur 100 000 années-lumière.', 'astronomie', 0.212, 0.950),
('ai-1788484888785-04', 'etymology', 'GALAXIE — du grec gala, « lait ». Ce qui coule comme le lait renversé des dieux, et nous enveloppe encore.', 'grec ancien', 0.096, 0.950),
('ai-1788484888785-05', 'fact', 'Proxima Centauri, notre étoile la plus proche après le Soleil, est si lointaine que sa lumière met 4,24 années à nous atteindre — un voyage sans retour.', 'astronomie', 0.050, 0.950),
('ai-1788484888785-06', 'etymology', 'COSMOS — du grec κόσμος, « ordre, parure ». L''univers n''est pas chaos : un tissu où chaque poussière chante l''harmonie.', 'grec ancien', 0.050, 0.950),
('ai-1788484888785-07', 'fact', 'La Voie lactée, notre galaxie, s''étend sur 100 000 années-lumière — une spirale de cent milliards d''étoiles prisonnières de leur propre lumière.', 'astronomie', 0.099, 0.950),
('ai-1788484888785-08', 'haiku', 'Poussière d''étoile / un grain sur l''aile d''une nuit / et le temps s''efface.', 'kenos', 0.050, 0.950)
on conflict (id) do nothing;
commit;
