-- ═══════════════════════════════════════════════════════════════════════
-- KENOS — the reaper and the gardener, on the ether's own clock (V3.20)
--
-- kenos_purge() held every retention rule in one place (drifting
-- echoes 30 d, audit reads 1 d, stale receptions, reports, waves
-- 60 s; open rings 7 d, closed artifacts 30 d) — but nothing ever
-- called it: pg_cron was left unwired, so the only reaper of spam
-- was a human with a SQL console. Now the ether reaps itself:
--
--   kenos-purge   hourly at :17  — every retention rule, one call
--   kenos-garden  daily 07:30 UTC — tops the open-ring field back
--                                  to 14 (max 5 new a day)
--
-- Jobs run as the migration user (postgres): both functions are
-- revoked from anon/authenticated on purpose. Scheduling is
-- idempotent (unschedule, then schedule) so a re-run never stacks
-- duplicate jobs.
-- ═══════════════════════════════════════════════════════════════════════

create extension if not exists pg_cron;

-- Idempotent: the cron.job table itself is locked to the migration
-- role, but the extension's own unschedule/schedule functions are
-- not. Never stack duplicate jobs.
select cron.unschedule('kenos-purge')
 where exists (select 1 from cron.job where jobname = 'kenos-purge');

select cron.unschedule('kenos-garden')
 where exists (select 1 from cron.job where jobname = 'kenos-garden');

select cron.schedule(
    'kenos-purge',
    '17 * * * *',
    $$ select public.kenos_purge(); $$
);

select cron.schedule(
    'kenos-garden',
    '30 7 * * *',
    $$ select public.kenos_garden_seed(14, 5); $$
);
