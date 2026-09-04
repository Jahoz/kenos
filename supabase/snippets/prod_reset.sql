-- ═══════════════════════════════════════════════════════════════════════
-- KENOS — the LAUNCH RESET (production, 2026-09-04)
--
-- The ship is live and the test wake must go. This keeps everything
-- the project GENERATED and removes everything that was LIVED:
--
--   KEPT   the 7 curated poetry artifacts (+ their 8 credited hands),
--          the 64 vestiges (fr + en), the KEK, the schema.
--   GONE   every non-seed anonymous account (test sessions, evening
--          visitors, nightly smoke users) and its whole wake — the
--          user delete cascades echoes, receptions, reads, lineages,
--          reports, waves and constellation lines; then every
--          non-curated open ring (test openings + the previous
--          garden crop) and the stale ephemera.
--   BACK   the Gardener replants a fresh field of 14 open rings.
--
-- Follow with prod_sow.sql to give the sky its 360 generated
-- drifting echoes (the fear-of-the-void insurance).
--
-- One atomic DO block. Run:
--   bash scripts/prod_admin.sh file supabase/snippets/prod_reset.sql
-- Then verify with the report query in the header of prod_sow.sql.
--
-- NB: accounts deleted mid-session — a visitor online at reset time
-- reloads and silently re-enters as a new stranger (one reload, the
-- anonymous door never closes).
-- ═══════════════════════════════════════════════════════════════════════

do $launch_reset$
declare
    gone_users int;
    gone_rings int;
    rings_back int;
begin
    -- 1. Real-usage accounts and their whole wake (cascades).
    --    NULL-safe predicate: true anonymous sign-ups carry NO email
    --    (email is null) — a bare `not like` silently spares them all.
    delete from auth.identities
     where user_id in (select id from auth.users
                        where is_anonymous
                          and coalesce(email, '') not like '%@seed.kenos.local');
    with deleted as (
        delete from auth.users
         where is_anonymous
           and coalesce(email, '') not like '%@seed.kenos.local'
        returning 1
    )
    select count(*) into gone_users from deleted;

    -- 2. Non-curated rings: test openings and the previous garden
    --    crop. Curated artifacts (curated_by is not null) and their
    --    credited hands stay untouched.
    with deleted as (
        delete from public.kenos_constellations
         where curated_by is null
        returning 1
    )
    select count(*) into gone_rings from deleted;

    -- 3. Ephemera sweep (kenos_purge semantics by hand — pg_cron is
    --    still unwired by design).
    delete from public.kenos_reads;
    delete from public.kenos_lineages;
    delete from public.kenos_frequencies
     where created_at < now() - interval '60 seconds';

    -- 4. The Gardener replants: a fresh field of 14 open rings.
    rings_back := public.kenos_garden_seed(14, 14);

    raise notice 'LAUNCH RESET: % accounts gone, % rings gone, % rings replanted',
        gone_users, gone_rings, rings_back;
end
$launch_reset$;
