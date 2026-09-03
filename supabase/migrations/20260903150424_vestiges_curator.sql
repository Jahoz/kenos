-- ═══════════════════════════════════════════════════════════════════════
-- KENOS — migration 0015 : the Vestiges cross the ether (2026-09-03)
--
-- Vestiges were bundled in the app (12 shards, honest offline, but
-- frozen between releases). The Curator now feeds them from the
-- database: real curated culture — quotes, etymologies, haiku,
-- histories, facts — credited, wipeable, updatable without a
-- release. The bundle stays as the offline/demo fallback: the app
-- tries the ether, falls back to the bundle, never blocks.
--
-- Read state stays device-local (a memory, not a burn); the daily
-- drift rotation stays client-side (deterministic, same sky for
-- every device that day). Nothing here counts, nothing pushes.
-- ═══════════════════════════════════════════════════════════════════════

create table public.kenos_vestiges (
    id        text primary key,
    kind      text not null check (kind in ('quote', 'etymology', 'haiku', 'history', 'fact')),
    text      text not null check (length(text) between 1 and 400),
    source    text not null default '',
    pos_x     double precision not null check (pos_x between 0 and 1),
    pos_y     double precision not null check (pos_y between 0 and 1),
    live      boolean not null default true,
    created_at timestamptz not null default now()
);

create index idx_vestiges_live on public.kenos_vestiges (live);

alter table public.kenos_vestiges enable row level security;
revoke all on public.kenos_vestiges from anon, authenticated;

-- ── The map reads the drifting library (metadata + text — public
--    culture, deliberately readable; no sealing, no burning) ─────────
create or replace function public.fetch_vestiges()
returns table (
    id     text,
    kind   text,
    text   text,
    source text,
    x      double precision,
    y      double precision
)
language sql
security definer
set search_path = public
stable
as $$
    select v.id, v.kind, v.text, v.source, v.pos_x, v.pos_y
    from public.kenos_vestiges v
    where v.live
    order by v.created_at desc
    limit 200;
$$;

revoke all on function public.fetch_vestiges() from public, anon;
grant execute on function public.fetch_vestiges() to authenticated;

-- ── kenos_purge v6: culture is timeless — vestiges never expire ──────
-- (deliberately NOT in the purge: curated shards rest until the
--  curator retires them with live = false)
