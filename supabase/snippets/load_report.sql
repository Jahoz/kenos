-- ═══════════════════════════════════════════════════════════════════════
-- KENOS — load-ramp report (montée en charge visualization)
--
-- Read-only. Run after load_seed.sql:
--   make db-load-report
--   (or: docker exec -i supabase_db_kenos psql -U postgres -d postgres
--        < supabase/snippets/load_report.sql)
--
-- Sections:
--   1. The 30-day ramp (launched / consumed / corpses / reports + bar)
--   2. Live state of the ether (every table)
--   3. Sector pressure (8×8 culling: which sectors hit the 24-star cap)
--   4. Case-coverage matrix (every lifecycle case must be non-zero)
-- ═══════════════════════════════════════════════════════════════════════

-- ── 1. The ramp ─────────────────────────────────────────────────────────
with days as (
    select generate_series(current_date - 29, current_date, interval '1 day')::date as d
),
per_day as (
    select days.d,
           (select count(*) from public.echoes e
             where e.created_at::date = days.d)                     as launched,
           (select count(*) from public.kenos_receptions r
             where r.read_at::date = days.d)                        as consumed,
           (select count(*) from public.kenos_constellations c
             where c.created_at::date = days.d)                     as corpses,
           (select count(*) from public.kenos_echo_reports rep
             where rep.reported_at::date = days.d)                  as reports
      from days
)
select to_char(d, 'MM-DD') as day,
       launched,
       consumed,
       corpses,
       reports,
       rpad(repeat('█', least(38, (launched * 38 / greatest(max(launched) over (), 1)))::int), 38) as ramp
  from per_day
 order by d;

-- ── 2. Live state ───────────────────────────────────────────────────────
select 'users (seed)'             as what, count(*) from auth.users where email like '%@seed.kenos.local'
union all select 'echoes drifting',        count(*) from public.echoes
union all select 'receptions (consumed history)', count(*) from public.kenos_receptions
union all select 'audit reads (< 24h)',    count(*) from public.kenos_reads
union all select 'lineages',               count(*) from public.kenos_lineages
union all select 'reports',                count(*) from public.kenos_echo_reports
union all select 'waves (live)',           count(*) from public.kenos_frequencies
union all select 'constellations',         count(*) from public.kenos_constellations
union all select 'constellation lines',    count(*) from public.kenos_constellation_lines
order by 1;

-- ── 3. Sector pressure (what fetch_map_sector will cull) ────────────────
with per_sector as (
    select sector_x, sector_y, count(*) as n
      from public.echoes
     group by 1, 2
)
select 'top sectors' as facet,
       sector_x || ',' || sector_y as detail, n as stars,
       case when n > 24 then 'CULLED to 24' else '' end as capping
  from per_sector
 order by n desc
 limit 10;

with per_sector as (
    select sector_x, sector_y, count(*) as n from public.echoes group by 1, 2
),
as_client as (
    -- What the map actually ships: ≤ 24/sector, ≤ 400 total.
    select sum(least(n, 24)) as uncapped_total,
           count(*) filter (where n > 24) as sectors_over_cap,
           sum(n) as raw_total
      from per_sector
)
select raw_total                                        as stars_in_ether,
       uncapped_total                                   as stars_after_sector_cap,
       least(uncapped_total, 400)                       as stars_shipped_to_client,
       sectors_over_cap                                 as sectors_hitting_cap,
       round(100.0 * least(uncapped_total, 400) / greatest(raw_total, 1)) as pct_visible
  from as_client;

-- ── 4. Case-coverage matrix (all rows must be non-zero) ─────────────────
select 'theme' as case_family, color_theme as case, count(*) as n from public.echoes group by 2
union all
select 'media', coalesce(media_kind, 'none'), count(*) from public.echoes group by 2
union all
select 'momentum', 'm=' || momentum, count(*) from public.echoes group by 2
union all
select 'seal', case when key_seal = '' then 'legacy plaintext' else 'sealed (KEK escrow)' end, count(*) from public.echoes group by 2
union all
select 'receptions', case when reply_text is null then 'contentless' else 'with trace' end, count(*) from public.kenos_receptions group by 2
union all
select 'receptions', case when reply_seen then 'seen (burned)' else 'unseen' end, count(*) from public.kenos_receptions group by 2
union all
select 'lineages', case when consumed_at > now() - interval '10 minutes' then 'active window' else 'stale' end, count(*) from public.kenos_lineages group by 2
union all
select 'reports', reason_code, count(*) from public.kenos_echo_reports group by 2
union all
select 'constellations', state, count(*) from public.kenos_constellations group by 2
union all
select 'constellations', case when closed_at is null then 'open · incomplete' else 'closed · complete corpse' end, count(*) from public.kenos_constellations group by 2
union all
select 'drift age', case when created_at > now() - interval '1 day' then 'fresh (< 1d)'
                          when created_at > now() - interval '7 days' then 'week-old'
                          when created_at > now() - interval '20 days' then 'aging'
                          else 'purge horizon (20-30d)' end, count(*) from public.echoes group by 2
order by 1, 2;
