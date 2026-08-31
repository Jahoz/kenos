-- ═══════════════════════════════════════════════════════════════════════
-- KENOS — migration 0004 : map sector culling + drifting-echo purge
--
--  1. Culling: beyond a few thousand echoes the map must not ship the
--     whole galaxy. `fetch_map_sector(p_min_x, p_min_y, p_max_x, p_max_y)`
--     returns metadata for a normalized viewport rect, capped per sector
--     (8×8 grid, newest first) and in total — a dense neighborhood never
--     starves a calm one. The client mirrors the exact same constants
--     (SectorGrid) so demo mode keeps identical semantics.
--  2. Purge: `kenos_purge()` destroys echoes drifting for more than
--     30 days, audit rows older than a day (the trace window is 10 min),
--     and unread receptions after the same 30-day horizon. The pg_cron
--     wiring block is provided below, COMMENTED, as the roadmap demands:
--     enable it once `pg_cron` is available on the project.
-- ═══════════════════════════════════════════════════════════════════════

-- ── Retired: the echoes_map view ────────────────────────────────────────
-- The client reads the map through `fetch_map_sector` (metadata only,
-- author-excluded, sector-culled); the view added surface for zero value.
drop view if exists public.echoes_map;

-- Sector coordinates of an echo on the 8×8 grid (generated, always fresh).
-- `floor` is NOT optional: a float→int cast ROUNDS in Postgres
-- ((0.0626*8)::int = 1, not 0), which would desynchronize SQL sectors
-- from the Dart client (which floors) and silently break demo parity.
-- `least(..., 7)`: coord 1.0 is a legal position and must land in the
-- last sector, not overflow the grid.
alter table public.echoes
    add column if not exists sector_x smallint
        generated always as (least(floor(coord_x * 8)::int, 7)::smallint) stored,
    add column if not exists sector_y smallint
        generated always as (least(floor(coord_y * 8)::int, 7)::smallint) stored;

create index if not exists idx_echoes_sector
    on public.echoes (sector_x, sector_y, created_at desc);

-- ── RPC: viewport query with per-sector culling ─────────────────────────
create or replace function public.fetch_map_sector(
    p_min_x          double precision default 0,
    p_min_y          double precision default 0,
    p_max_x          double precision default 1,
    p_max_y          double precision default 1,
    p_max_per_sector integer default 24,
    p_max_total      integer default 400
)
returns table (
    id          uuid,
    coord_x     double precision,
    coord_y     double precision,
    coord_z     double precision,
    color_theme varchar,
    created_at  timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
begin
    if auth.uid() is null then
        raise exception 'KENOS_UNAUTHENTICATED';
    end if;

    return query
    select s.id, s.coord_x, s.coord_y, s.coord_z, s.color_theme, s.created_at
    from (
        select e.id, e.coord_x, e.coord_y, e.coord_z, e.color_theme, e.created_at,
               row_number() over (
                   partition by e.sector_x, e.sector_y
                   order by e.created_at desc
               ) as rn
        from public.echoes e
        where e.coord_x >= least(p_min_x, p_max_x)
          and e.coord_x <= greatest(p_min_x, p_max_x)
          and e.coord_y >= least(p_min_y, p_max_y)
          and e.coord_y <= greatest(p_min_y, p_max_y)
          -- One's own echo never appears on one's map: the sealed star
          -- already represents it, and it is untouchable by contract
          -- ("jamais toi"). Without this, the author would see it twice
          -- and a 3 s hold would lie ("dissolved elsewhere").
          and e.author_id <> auth.uid()
    ) s
    where s.rn <= greatest(1, least(p_max_per_sector, 100))
    order by s.created_at desc
    limit greatest(1, least(p_max_total, 1000));
end;
$$;

revoke all on function public.fetch_map_sector(
    double precision, double precision, double precision, double precision,
    integer, integer
) from public, anon;
grant execute on function public.fetch_map_sector(
    double precision, double precision, double precision, double precision,
    integer, integer
) to authenticated;

-- ── Purge: the ether forgets what drifted too long ──────────────────────
-- Safe to run at any time: only age-based cleanup, never content reads.
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
end;
$$;

revoke all on function public.kenos_purge() from public, anon, authenticated;

-- ── pg_cron wiring (READY, COMMENTED — enable on the project) ───────────
-- Requires the pg_cron extension (Supabase: Dashboard → Database →
-- Extensions, or `create extension pg_cron;`). Then run once:
--
-- create extension if not exists pg_cron;
-- select cron.schedule(
--     'kenos-purge',
--     '17 3 * * *',                       -- daily, 03:17 UTC (off-peak)
--     $$ select public.kenos_purge(); $$
-- );
--
-- To unschedule (e.g. before restoring a dump):
-- select cron.unschedule('kenos-purge');
