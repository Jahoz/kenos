-- ═══════════════════════════════════════════════════════════════════════
-- KENOS — load-seed wipe (the CLEAN RESET before real launch)
--
-- Removes every row the load seed ever wrote, and nothing else:
--   * seed constellations carry deterministic ids (md5 namespace);
--   * every other seed row hangs off a seed user
--     (email '%@seed.kenos.local') and cascades away with it
--     (echoes, reads, receptions, reports, frequencies, lineages,
--     constellation lines).
--   * the KEK (kenos_ether_kek / vault) is deliberately KEPT: it is
--     infrastructure, not data — dropping it would not clean anything.
--
-- Run:
--   make db-wipe-load
--   (or: docker exec -i supabase_db_kenos psql -U postgres -d postgres
--        < supabase/snippets/load_wipe.sql)
--
-- On the local stack, the nuclear alternative is always:
--   make db-reset        (rebuilds everything from the migrations)
--
-- ═══════════════════════════════════════════════════════════════════════

begin;

-- Counters before the wipe (for the after-check below).
create temp table if not exists _before as
select (select count(*) from auth.users where email like '%@seed.kenos.local') as seed_users,
       (select count(*) from public.echoes)            as echoes,
       (select count(*) from public.kenos_receptions)  as receptions,
       (select count(*) from public.kenos_reads)       as reads,
       (select count(*) from public.kenos_lineages)    as lineages,
       (select count(*) from public.kenos_echo_reports) as reports,
       (select count(*) from public.kenos_frequencies) as waves,
       (select count(*) from public.kenos_constellations) as constellations,
       (select count(*) from public.kenos_constellation_lines) as corpse_lines;
delete from _before;
insert into _before select (select count(*) from auth.users where email like '%@seed.kenos.local'),
       (select count(*) from public.echoes), (select count(*) from public.kenos_receptions),
       (select count(*) from public.kenos_reads), (select count(*) from public.kenos_lineages),
       (select count(*) from public.kenos_echo_reports), (select count(*) from public.kenos_frequencies),
       (select count(*) from public.kenos_constellations), (select count(*) from public.kenos_constellation_lines);

-- 1. Seed constellations (deterministic id namespace, ≤ 1000 corpses).
delete from public.kenos_constellations
 where id in (select md5('kenos-load-const-' || s)::uuid
              from generate_series(1, 1000) s);

-- 2. Seed users: the cascade does the rest of the work.
delete from auth.users
 where email like '%@seed.kenos.local';

-- ── After: what remains is pre-existing real data, nothing seeded ───────
select b.seed_users                                                          as seed_users_before,
       (select count(*) from auth.users where email like '%@seed.kenos.local') as seed_users_after,
       b.echoes            as echoes_before,      (select count(*) from public.echoes)            as echoes_after,
       b.receptions        as receptions_before,  (select count(*) from public.kenos_receptions)  as receptions_after,
       b.reads             as reads_before,       (select count(*) from public.kenos_reads)       as reads_after,
       b.lineages          as lineages_before,    (select count(*) from public.kenos_lineages)    as lineages_after,
       b.reports           as reports_before,     (select count(*) from public.kenos_echo_reports) as reports_after,
       b.waves             as waves_before,       (select count(*) from public.kenos_frequencies) as waves_after,
       b.constellations    as const_before,       (select count(*) from public.kenos_constellations) as const_after,
       b.corpse_lines      as lines_before,       (select count(*) from public.kenos_constellation_lines) as lines_after
  from _before b;

drop table _before;

commit;

-- ═══════════════════════════════════════════════════════════════════════
-- REAL-LAUNCH RESET (cloud/production, uncomment deliberately)
--
-- The wipe above only removes seeded rows. When the product ships for
-- real and EVERYTHING must go (seed + real early data alike), run the
-- block below in the cloud SQL Editor — it empties the ether entirely:
--
-- truncate public.kenos_constellation_lines, public.kenos_constellations,
--          public.kenos_lineages, public.kenos_receptions,
--          public.kenos_reads, public.kenos_echo_reports,
--          public.kenos_frequencies, public.echoes;
-- delete from auth.users where is_anonymous = true;  -- + real users if any
-- ═══════════════════════════════════════════════════════════════════════
