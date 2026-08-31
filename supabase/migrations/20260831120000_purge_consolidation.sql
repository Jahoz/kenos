-- ═══════════════════════════════════════════════════════════════════════
-- KENOS — migration 0006 : consolidated purge (V3.2)
--
-- Two concurrent migrations (0005_frequencies, 20260831101837_echo_
-- reports) both replaced `kenos_purge`; lexicographic order made the
-- echo_reports one win, silently dropping the waves block. This
-- migration timestamps itself AFTER both so it applies last, and is
-- the single source of truth: EVERY retention rule in one place.
-- Any future retention rule extends THIS function in a new migration.
-- ═══════════════════════════════════════════════════════════════════════

create or replace function public.kenos_purge()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
    -- Drifting echoes: 30 days without interception, back to the void.
    delete from public.echoes
    where created_at < now() - interval '30 days';

    -- Audit journal: the trace window is 10 minutes, the read anti-spam
    -- 5 seconds — a day of retention is already generous.
    delete from public.kenos_reads
    where read_at < now() - interval '1 day';

    -- Unread receptions follow the echoes they describe.
    delete from public.kenos_receptions
    where read_at < now() - interval '30 days';

    -- Reader reports on echoes (community curation), 30 days.
    delete from public.kenos_echo_reports
    where reported_at < now() - interval '30 days';

    -- Waves: one minute of life, then nothing remains.
    delete from public.kenos_frequencies
    where created_at < now() - interval '60 seconds';
end;
$$;

revoke all on function public.kenos_purge() from public, anon, authenticated;
