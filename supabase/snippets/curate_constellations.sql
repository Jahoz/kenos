-- ═══════════════════════════════════════════════════════════════════════
-- KENOS — the Curator: readable artifacts from day one (2026-09-03)
--
-- The Gardener plants EMPTY rings; artifacts (closed, readable
-- constellations) are written by strangers — or CURATED. Curation
-- follows the Vestiges philosophy: REAL content, PUBLIC DOMAIN,
-- CREDITED. Every constellation below is a true poem by a true poet
-- (dead long enough that the verses belong to everyone), assembled
-- line by line. The reading names the poet — it never pretends
-- strangers wrote it. Wipeable in one predicate:
--   delete from kenos_constellations where curated_by is not null;
--
-- Idempotent: rerun replaces (deterministic ids + hand pool).
--
-- Usage (local):  docker exec -i supabase_db_kenos psql -U postgres \
--                    -d postgres -v ON_ERROR_STOP=1 \
--                    < supabase/snippets/curate_constellations.sql
-- Usage (cloud):  paste in the SQL Editor.
-- ═══════════════════════════════════════════════════════════════════════

begin;

delete from public.kenos_constellations
 where curated_by is not null;

-- The hands: one anonymous contributor per line (the PK forbids two
-- lines by the same stranger — even a curator's hands obey).
insert into auth.users (
    id, instance_id, aud, role, email,
    email_confirmed_at, created_at, updated_at, is_anonymous
)
select md5('kenos-curated-hand-' || h)::uuid,
       '00000000-0000-0000-0000-000000000000',
       'anonymous', 'authenticated',
       'curated-hand-' || h || '@seed.kenos.local',
       now(), now(), now(), true
from generate_series(1, 8) h
on conflict (id) do nothing;

-- One helper: a curated CLOSED constellation, lines in the poet's
-- order. Curated verses are published culture, credited in the open:
-- they travel on the legacy plaintext path (key_seal = ''), opened
-- on-device like any line — the seal protects confidences, not
-- Baudelaire.
create or replace function public.kenos_curate(
    p_slug  text,
    p_poet  text,
    p_x     double precision,
    p_y     double precision,
    p_lines text[]
)
returns uuid
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
    id uuid := md5('kenos-curated-' || p_slug)::uuid;
    k  int;
begin
    insert into public.kenos_constellations (
        id, seed_x, seed_y, target_lines, state, kind, curated_by,
        created_at, closed_at
    )
    values (
        id, p_x, p_y, array_length(p_lines, 1), 'CLOSED', 'POEM', p_poet,
        now() - (2 + random() * 5) * interval '1 day',
        now() - random() * 2 * interval '1 day'
    );

    for k in 1..array_length(p_lines, 1) loop
        insert into public.kenos_constellation_lines (
            constellation_id, contributor_id, line_number,
            encrypted_text, key_seal, created_at
        )
        values (
            id,
            md5('kenos-curated-hand-' || k)::uuid,
            k,
            p_lines[k],
            '',
            now() - (2 + random() * 5) * interval '1 day'
                     + k * interval '37 minutes'
        );
    end loop;

    return id;
end;
$$;

-- ── The corpus: public-domain French poetry (fragments, credited) ────

select public.kenos_curate('mirabeau', 'GUILLAUME APOLLINAIRE', 0.18, 0.22,
    array[
        'Sous le pont Mirabeau coule la Seine',
        'Et nos amours',
        'Vienne la nuit sonne l''heure',
        'Les jours s''en vont je demeure'
    ]);

select public.kenos_curate('automne', 'PAUL VERLAINE', 0.72, 0.16,
    array[
        'Les sanglots longs des violons de l''automne',
        'Blessent mon cœur d''une langueur monotone',
        'Tout suffocant et blême, quand sonne l''heure',
        'Je me souviens des jours anciens, et je pleure'
    ]);

select public.kenos_curate('invitation', 'CHARLES BAUDELAIRE', 0.30, 0.66,
    array[
        'Mon enfant, ma sœur, songe à la douceur',
        'D''aller là-bas vivre ensemble!',
        'Là, tout n''est qu''ordre et beauté,',
        'Luxe, calme et volupté.'
    ]);

select public.kenos_curate('dormeur', 'ARTHUR RIMBAUD', 0.58, 0.44,
    array[
        'C''est un trou de verdure où chante une rivière',
        'Accrochant follement aux herbes des haillons',
        'Un soldat jeune, bouche ouverte, tête nue',
        'Il dort dans le soleil, la main sur sa poitrine',
        'Il a deux trous rouges au côté droit.'
    ]);

select public.kenos_curate('desdichado', 'GÉRARD DE NERVAL', 0.84, 0.62,
    array[
        'Je suis le ténébreux, — le veuf, — l''inconsolé',
        'Le prince d''Aquitaine à la tour abolie',
        'Ma seule étoile est morte, — et mon luth constellé',
        'Porte le soleil noir de la Mélancolie'
    ]);

select public.kenos_curate('clairdelune', 'PAUL VERLAINE', 0.66, 0.88,
    array[
        'Votre âme est un paysage choisi',
        'Que vont charmant masques et bergamasques',
        'Jouant du luth et dansant et quasi',
        'Tristes sous leurs déguisements fantasques'
    ]);

select public.kenos_curate('labbe', 'LOUISE LABÉ', 0.46, 0.10,
    array[
        'Baise m''encor, rebaise-moi et baise;',
        'Donne m''en un de tes plus savoureux;',
        'Donne m''en un de tes plus amoureux :',
        'Je t''en rendrai quatre plus chauds que braise.'
    ]);

drop function public.kenos_curate(
    text, text, double precision, double precision, text[]
);

commit;
