-- KENOS — the staged harvest becomes proposals (V3.57).
--
-- The nine shards that waited in vestiges_staging.md (astronomie,
-- étymologies grecques, haïkus — AI-sown, two passes verified,
-- human-review pending) move into the Sower module's queue: the
-- guardian re-reads them on the Observatory screen, publishes or
-- discards each. Nothing is public until then.
--
-- Idempotent: a shard already proposed or already in the library
-- never lands twice (normalized-text dedup, same law as the RPC).
do $$
declare
    proposals jsonb := $json$
    [
      {"kind":"fact","text":"La lumière du Soleil met 8 minutes pour franchir les 150 millions de kilomètres qui nous en séparent — distance appelée « unité astronomique ».","source":"astronomie"},
      {"kind":"fact","text":"Nuage de Magellan : galaxie naine visible à l'œil nu, mais sa lumière met 163 000 ans à nous parvenir.","source":"astronomie"},
      {"kind":"haiku","text":"Poussière d'étoiles / le vent dans l'absinthe / personne pour compter.","source":"kenos"},
      {"kind":"fact","text":"La nuit, la Voie lactée est un fleuve de lumière — mais sa clarté que nous percevons traverse des régions de poussière interstellaire s'étendant sur 100 000 années-lumière.","source":"astronomie"},
      {"kind":"etymology","text":"GALAXIE — du grec gala, « lait ». Ce qui coule comme le lait renversé des dieux, et nous enveloppe encore.","source":"grec ancien"},
      {"kind":"fact","text":"Proxima Centauri, notre étoile la plus proche après le Soleil, est si lointaine que sa lumière met 4,24 années à nous atteindre — un voyage sans retour.","source":"astronomie"},
      {"kind":"etymology","text":"COSMOS — du grec κόσμος, « ordre, parure ». L'univers n'est pas chaos : un tissu où chaque poussière chante l'harmonie.","source":"grec ancien"},
      {"kind":"fact","text":"La Voie lactée, notre galaxie, s'étend sur 100 000 années-lumière — une spirale de cent milliards d'étoiles prisonnières de leur propre lumière.","source":"astronomie"},
      {"kind":"haiku","text":"Poussière d'étoile / un grain sur l'aile d'une nuit / et le temps s'efface.","source":"kenos"}
    ]
    $json$;
    item jsonb;
    v_norm text;
begin
    for item in select * from jsonb_array_elements(proposals) loop
        v_norm := lower(regexp_replace(item->>'text', '[^a-zà-ÿ0-9]', '', 'g'));
        if exists (select 1 from public.kenos_vestige_proposals p
                    where lower(regexp_replace(p.text, '[^a-zà-ÿ0-9]', '', 'g')) = v_norm)
           or exists (select 1 from public.kenos_vestiges v
                    where lower(regexp_replace(v.text, '[^a-zà-ÿ0-9]', '', 'g')) = v_norm) then
            continue;
        end if;
        insert into public.kenos_vestige_proposals (kind, text, source, theme)
        values (item->>'kind', item->>'text', item->>'source', 'moisson 2026-09');
    end loop;
end $$;
