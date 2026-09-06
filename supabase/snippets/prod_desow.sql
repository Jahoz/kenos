-- ═══════════════════════════════════════════════════════════════════════
-- KENOS — the desow (production): the generated sky goes home
--
-- Before the real launch, prod must mirror ADOPTION: every drifting
-- star a real stranger's thought, the metrics legible with no
-- background noise. This removes exactly what prod_sow.sql planted
-- and nothing else:
--
--   GONE   the 48 'sky-NNNN@seed.kenos.local' authors and their
--          ~360 sealed echoes (cascade: their receptions, reads,
--          lineages), plus any contentless test rings left by the
--          launch probes (OPEN, no lines, seeded by throwaway
--          accounts).
--   KEPT   the 7 curated poetry artifacts (+ their 8 credited
--          hands), the 64 vestiges, the gardener's open rings,
--          every real stranger's echo and constellation, the KEK.
--
-- The Observatory's daily metrics were NEVER polluted: the sow
-- inserted rows directly, only the RPCs touch the counters — the
-- adoption signal was already clean; this cleans the sky itself.
--
-- Volume for perf and ergonomics work lives in the LOCAL stack:
--   make db-seed-load   (30-day ramp, ~12k rows, readable seals)
--
-- One atomic statement pair. Run:
--   bash scripts/prod_admin.sh sql "..."   (both statements below)
-- Verify:
--   select (select count(*) from public.echoes) as real_echoes,
--          (select count(*) from public.kenos_constellations) as rings;
-- ═══════════════════════════════════════════════════════════════════════

-- 1. The sown authors: the cascade carries their whole sky away.
delete from auth.users where email like 'sky-%@seed.kenos.local';

-- 2. Launch-probe leftovers: OPEN rings with no lines whose seeder
--    account no longer holds content (throwaway test accounts — a
--    real stranger's ring keeps its lines or its living seeder).
delete from public.kenos_constellations c
 where c.state = 'OPEN'
   and not exists (
       select 1 from public.kenos_constellation_lines l
        where l.constellation_id = c.id
   )
   and c.seeder_id in (
       select u.id from auth.users u
        where not exists (select 1 from public.echoes e where e.author_id = u.id)
          and not exists (select 1 from public.kenos_constellation_lines l
                           where l.contributor_id = u.id)
   );
