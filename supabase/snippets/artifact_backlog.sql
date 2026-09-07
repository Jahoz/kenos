-- ═══════════════════════════════════════════════════════════════════════
-- KENOS — the artifact backlog: a poem a week, even in the calm
--
-- The purge gives closed artifacts a moon, then the ether forgets
-- them (30 days). Without regeneration, the sky slowly loses its
-- culture while adoption is quiet. The gardener keeps OPEN rings
-- coming — and this keeps READABLE culture coming: every release takes
-- the next backlog slot and writes one CLOSED, curated, credited
-- constellation — same mechanics as the launch curation (plaintext
-- legacy path, deterministic anonymous hands, curated_by names the
-- poet).
--
-- The Vestiges law holds: REAL public-domain fragments, CREDITED,
-- never fabricated confidences. The backlog is replenished by hand
-- (or a reviewed session) — the release never invents a line, it
-- only reveals what was curated. A released slot stays released
-- (released_at), so a poem never returns once the ether forgot it.
--
-- Idempotent by design, NO wrapping transaction on purpose: every
-- statement stands alone (Management API runs filemulti statements
-- in separate sessions) and a partial failure heals on re-run.
--
-- Usage (local):
--   docker exec -i supabase_db_kenos psql -U postgres -d postgres \
--     -v ON_ERROR_STOP=1 < supabase/snippets/artifact_backlog.sql
-- Usage (cloud):
--   bash scripts/prod_admin.sh filemulti supabase/snippets/artifact_backlog.sql
-- Release the next one (or: make prod-artifact-release):
--   bash scripts/prod_admin.sh sql "select public.kenos_artifact_release()"
-- Verify:
--   select slot, poet, released_at from public.kenos_artifact_backlog order by slot
--   select curated_by, count(*) from public.kenos_constellations
--     where curated_by is not null group by 1
-- ═══════════════════════════════════════════════════════════════════════

-- ── The queue: slots wait their turn, plaintext poetry, never client-read ──
create table if not exists public.kenos_artifact_backlog (
    slot        integer primary key,
    slug        text not null unique,
    poet        text not null,
    title       text not null,
    kind        text not null default 'POEM' check (kind in ('POEM', 'MELODY')),
    lines       jsonb not null check (jsonb_typeof(lines) = 'array'
                                      and jsonb_array_length(lines) between 4 and 7),
    source_note text,
    released_at timestamptz
);

alter table public.kenos_artifact_backlog enable row level security;
revoke all on public.kenos_artifact_backlog from anon, authenticated;

-- ── The corpus: public-domain fragments, FR + EN, 4–7 lines (the ring's own shape) ──
-- Re-run refreshes texts — released_at is NEVER touched (a slot stays spent).
insert into public.kenos_artifact_backlog (slot, slug, poet, title, kind, lines, source_note) values
(1, 'hugo-demain', 'VICTOR HUGO', 'Demain, dès l''aube', 'POEM',
 $$["Demain, dès l'aube, à l'heure où blanchit la campagne,",
   "Je partirai. Vois-tu, je sais que tu m'attends.",
   "J'irai par la forêt, j'irai par la montagne.",
   "Je ne puis demeurer loin de toi plus longtemps."]$$::jsonb,
 'Les Contemplations, 1856'),
(2, 'verlaine-ciel', 'PAUL VERLAINE', 'Le ciel est, par-dessus le toit…', 'POEM',
 $$["Le ciel est, par-dessus le toit,",
   "Si bleu, si calme !",
   "Un arbre, par-dessus le toit,",
   "Berce sa palme.",
   "La cloche, dans le ciel qu'on voit,",
   "Doucement tinte."]$$::jsonb,
 'Sagesse, 1880'),
(3, 'dickinson-hope', 'EMILY DICKINSON', '"Hope" is the thing with feathers', 'POEM',
 $$["\"Hope\" is the thing with feathers -",
   "That perches in the soul -",
   "And sings the tune without the words -",
   "And never stops - at all -"]$$::jsonb,
 'Poems, 1891'),
(4, 'shelley-ozymandias', 'PERCY BYSSHE SHELLEY', 'Ozymandias', 'POEM',
 $$["I met a traveller from an antique land,",
   "Who said—\"Two vast and trunkless legs of stone",
   "Stand in the desert. Near them, on the sand,",
   "Half sunk a shattered visage lies, whose frown,",
   "And wrinkled lip, and sneer of cold command,",
   "Tell that its sculptor well those passions read"]$$::jsonb,
 '1818'),
(5, 'baudelaire-correspondances', 'CHARLES BAUDELAIRE', 'Correspondances', 'POEM',
 $$["La Nature est un temple où de vivants piliers",
   "Laissent parfois sortir de confuses paroles ;",
   "L'homme y passe à travers des forêts de symboles",
   "Qui l'observent avec des regards familiers."]$$::jsonb,
 'Les Fleurs du mal, 1857'),
(6, 'rossetti-wind', 'CHRISTINA ROSSETTI', 'Who has seen the wind?', 'POEM',
 $$["Who has seen the wind?",
   "Neither I nor you:",
   "But when the leaves hang trembling,",
   "The wind is passing through."]$$::jsonb,
 '1872'),
(7, 'verlaine-lune', 'PAUL VERLAINE', 'La lune blanche…', 'POEM',
 $$["La lune blanche",
   "Luit dans les bois ;",
   "De chaque branche",
   "Part une voix",
   "Sous la ramée.",
   "Ô bien-aimée."]$$::jsonb,
 'La Bonne Chanson, 1870'),
(8, 'keats-nightingale', 'JOHN KEATS', 'Ode to a Nightingale (ouverture)', 'POEM',
 $$["My heart aches, and a drowsy numbness pains",
   "My sense, as though of hemlock I had drunk,",
   "Or emptied some dull opiate to the drains",
   "One minute past, and Lethe-wards had sunk:"]$$::jsonb,
 '1819'),
(9, 'lafontaine-corbeau', 'JEAN DE LA FONTAINE', 'Le Corbeau et le Renard', 'POEM',
 $$["Maître Corbeau, sur un arbre perché,",
   "Tenait en son bec un fromage.",
   "Maître Renard, par l'odeur alléché,",
   "Lui tint à peu près ce langage :",
   "« Hé ! bonjour, Monsieur du Corbeau.",
   "Que vous êtes joli ! Que vous me semblez beau !"]$$::jsonb,
 'Fables, 1668'),
(10, 'blake-tyger', 'WILLIAM BLAKE', 'The Tyger', 'POEM',
 $$["Tyger Tyger, burning bright,",
   "In the forests of the night;",
   "What immortal hand or eye,",
   "Could frame thy fearful symmetry?",
   "In what distant deeps or skies",
   "Burnt the fire of thine eyes?"]$$::jsonb,
 'Songs of Experience, 1794')
on conflict (slot) do update
   set poet        = excluded.poet,
       title       = excluded.title,
       kind        = excluded.kind,
       lines       = excluded.lines,
       source_note = excluded.source_note;

-- ── The release: one slot becomes a readable constellation ─────────────
-- Service-level (no auth), operator- or cron-called, like the gardener.
-- Deterministic ids make a re-run inert: the same slug can never write
-- a second constellation, and a partial failure heals on retry.
create or replace function public.kenos_artifact_release()
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
    a         public.kenos_artifact_backlog%rowtype;
    v_id      uuid;
    k         int;
    n         int;
    remaining int;
begin
    select * into a
      from public.kenos_artifact_backlog
     where released_at is null
     order by slot
     limit 1
     for update skip locked;

    if a.slot is null then
        return jsonb_build_object('released', false, 'reason', 'backlog empty');
    end if;

    v_id := md5('kenos-curated-' || a.slug)::uuid;
    n  := jsonb_array_length(a.lines);

    -- The hands: extend the classic pool of 8 if the fragment is longer.
    insert into auth.users (
        id, instance_id, aud, role, email,
        email_confirmed_at, created_at, updated_at, is_anonymous
    )
    select md5('kenos-curated-hand-' || h)::uuid,
           '00000000-0000-0000-0000-000000000000',
           'anonymous', 'authenticated',
           'curated-hand-' || h || '@seed.kenos.local',
           now(), now(), now(), true
      from generate_series(1, greatest(8, n)) h
    on conflict (id) do nothing;

    insert into public.kenos_constellations (
        id, seed_x, seed_y, target_lines, state, kind, curated_by,
        created_at, closed_at
    )
    values (
        v_id, 0.06 + random() * 0.88, 0.08 + random() * 0.84,
        n, 'CLOSED', a.kind, a.poet, now(), now()
    )
    on conflict (id) do nothing;

    -- Published culture rides the legacy plaintext path (key_seal empty):
    -- the seal protects confidences, not Baudelaire.
    for k in 1..n loop
        insert into public.kenos_constellation_lines (
            constellation_id, contributor_id, line_number,
            encrypted_text, key_seal, created_at
        )
        values (
            v_id, md5('kenos-curated-hand-' || k)::uuid, k,
            a.lines ->> (k - 1), '', now() + k * interval '37 minutes'
        )
        on conflict do nothing;
    end loop;

    update public.kenos_artifact_backlog
       set released_at = now()
     where slot = a.slot;

    select count(*) into remaining
      from public.kenos_artifact_backlog
     where released_at is null;

    return jsonb_build_object(
        'released', true, 'slot', a.slot, 'slug', a.slug,
        'poet', a.poet, 'title', a.title, 'id', v_id,
        'lines', n, 'backlog_remaining', remaining
    );
end;
$$;

revoke all on function public.kenos_artifact_release()
    from public, anon, authenticated;

-- ── The ether's own clock: one release every Monday morning ────────────
-- 06:45 UTC = 08:45 Paris in summer, 07:45 after the DST switch — always
-- before the 09:00 local watch, so the morning report carries the birth.
-- Idempotent like the reaper's wiring: unschedule, then schedule.
select cron.unschedule('kenos-artifact')
 where exists (select 1 from cron.job where jobname = 'kenos-artifact');

select cron.schedule(
    'kenos-artifact',
    '45 6 * * 1',
    $$ select public.kenos_artifact_release(); $$
);
