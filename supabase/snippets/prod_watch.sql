-- ═══════════════════════════════════════════════════════════════════════
-- KENOS — the daily watch (production): the guardian reads the sky
--
-- READ-ONLY, CONTENTLESS, ZERO SIDE EFFECTS. The nightly CI smoke
-- (scripts/smoke_prod.sh) proves the ether still WORKS; nothing told
-- the guardian whether anyone sailed it. This is that glance:
--
--   series_7d   the Observatory's ledger, last 7 days incl. today
--               (launches, consumptions, rebounds, traces, reports,
--               rings seeded/closed, lines, new users, active readers)
--   live        the sky right now (drifting echoes, users, rings,
--               vestiges, open reports) — same shapes the admin
--               dashboard's live block carries
--   db          a pulse: postmaster age, database size, connections
--
-- The astronomer never reads the messages: they count the stars. No
-- table is written, no function with side effects is called, no
-- anonymous user is created (unlike the smoke — so this probe never
-- bumps new_users itself). One statement so prod_admin.sh `file` runs
-- it whole.
--
-- Run (or: make prod-watch):
--   bash scripts/prod_admin.sh file supabase/snippets/prod_watch.sql
-- ═══════════════════════════════════════════════════════════════════════

select jsonb_pretty(jsonb_build_object(
    'watch', 'prod-daily',
    'ran_at', now(),
    'series_7d', (
        select coalesce(jsonb_agg(to_jsonb(d) order by d.day), '[]'::jsonb)
        from (
            select to_char(m.day, 'YYYY-MM-DD') as day,
                   m.echoes_launched, m.echoes_consumed, m.echoes_rebound,
                   m.traces_left, m.reports_filed,
                   m.corpses_seeded, m.corpses_closed, m.lines_contributed,
                   m.new_users, m.active_readers
              from public.kenos_metrics_daily m
             where m.day > current_date - 7
        ) d
    ),
    'live', jsonb_build_object(
        'echoes_drifting', (select count(*) from public.echoes),
        'users_total', (select count(*) from auth.users),
        'constellations_open',
            (select count(*) from public.kenos_constellations
              where state = 'OPEN'),
        'constellations_closed',
            (select count(*) from public.kenos_constellations
              where state = 'CLOSED'),
        'vestiges_live',
            (select count(*) from public.kenos_vestiges where live),
        'reports_open',
            (select count(*) from public.kenos_echo_reports)
    ),
    'db', jsonb_build_object(
        'postmaster_since', pg_postmaster_start_time(),
        'db_size_mb',
            round(pg_database_size(current_database())::numeric / 1048576, 1),
        'connections', (select count(*) from pg_stat_activity),
        'connections_active',
            (select count(*) from pg_stat_activity where state = 'active')
    )
)) as watch;
