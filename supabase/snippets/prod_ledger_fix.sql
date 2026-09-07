-- ═══════════════════════════════════════════════════════════════════════
-- KENOS — the ledger fix (production): the sow's births leave the book
--
-- The desow removed the 48 'sky-%@seed.kenos.local' authors and their
-- ~360 echoes — but their BIRTHS stayed counted: the accounts were
-- created through the signup path, so the Observatory's trigger fired,
-- and 2026-09-04 reads 63 new_users while only 12 accounts of that
-- day survive. The desow commit claimed "the adoption signal was
-- already clean" — true for the echo lifecycle counters (the sow
-- bypassed launch_echo), false for new_users. This makes the claim
-- true:
--
--   new_users[2026-09-04] := the surviving real births of that day
--
-- The value is DERIVED from live data (auth.users), never hand-typed,
-- and guarded to only ever SHRINK the counter toward the truth — a
-- re-run is inert. The 2+2 consumptions of 2026-09-04/05 stay as
-- they are: real readers really read, even sown stars.
--
-- One atomic statement. Run:
--   bash scripts/prod_admin.sh file supabase/snippets/prod_ledger_fix.sql
-- Verify:
--   bash scripts/prod_admin.sh sql "select day, new_users from public.kenos_metrics_daily order by day"
-- ═══════════════════════════════════════════════════════════════════════

do $ledger_fix$
declare
    v_before int;
    v_real   int;
begin
    select new_users into v_before
      from public.kenos_metrics_daily
     where day = date '2026-09-04';

    select count(*) into v_real
      from auth.users
     where created_at::date = date '2026-09-04';

    update public.kenos_metrics_daily
       set new_users = v_real,
           updated_at = now()
     where day = date '2026-09-04'
       and new_users > v_real;

    raise notice 'LEDGER FIX 2026-09-04: new_users % -> % (the sow''s seeded births leave the book)',
        v_before, v_real;
end
$ledger_fix$;
