-- ═══════════════════════════════════════════════════════════════════════
-- KENOS — migration : the past moons (V3.54, C3 arbitré Hugo 2026-09-16)
--
-- The Monday ritual: each week a public-domain poem joins the ether,
-- credited, readable for one moon — then the ether forgets, even its
-- most beautiful poems (the law). The arbitration: the LANDING may
-- name which POETS inhabited the sky, and which Mondays — never the
-- poems. The depth of the ritual shows; the forgetting stays true.
--
--  1. kenos_artifact_backlog becomes part of the versioned schema
--     (until now it only lived in the operator snippet, so a fresh
--     migration-run database never had it). `if not exists`: the
--     snippet keeps its role — filling the corpus — and never fights
--     the DDL. Clients still see nothing of it (RLS, revoked).
--  2. fetch_past_moons: RELEASED slots only (no spoilers for what
--     the cron has not freed), poet + title + kind + the Monday —
--     NEVER a line, never a source note. Granted to ANON: the landing
--     is a static page behind the publishable key, and a released
--     moon is public knowledge (the map shows the poet to everyone
--     for thirty days).
-- ═══════════════════════════════════════════════════════════════════════

create table if not exists public.kenos_artifact_backlog (
    slot        integer primary key,
    slug        text not null unique,
    poet        text not null,
    title       text not null,
    kind        text not null default 'POEM' check (kind in ('POEM', 'MELODY')),
    lines       jsonb not null check (jsonb_typeof(lines) = 'array'
                                      and jsonb_array_length(lines) between 4 and 7),
    source_note text,
    released_at timestamptz
);

alter table public.kenos_artifact_backlog enable row level security;
revoke all on public.kenos_artifact_backlog from anon, authenticated;

create or replace function public.fetch_past_moons()
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
    -- The landing's calendar: released lunes only, newest first, a
    -- year of Mondays at most. Shapes only — no poem ever crosses.
    select coalesce(
        -- ISO dates sort as text exactly as they sort as dates.
        jsonb_agg(row_to_json(m) order by m.released_on desc),
        '[]'::jsonb
    )
    from (
        select to_char(released_at, 'YYYY-MM-DD') as released_on,
               poet, title, kind
          from public.kenos_artifact_backlog
         where released_at is not null
         order by released_at desc
         limit 52
    ) m
$$;

revoke all on function public.fetch_past_moons()
    from public;
grant execute on function public.fetch_past_moons()
    to anon, authenticated;
