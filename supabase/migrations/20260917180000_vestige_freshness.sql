-- ═══════════════════════════════════════════════════════════════════════
-- KENOS — la lune de faveur (V3.58)
--
-- The guardian published a harvest and the traveller never saw it:
-- the client's daily rotation (~2/3 of the library adrift per day,
-- deterministic) kept deferring the fresh shards — publish 12, see
-- 6 tomorrow, 1 the day after. "Always something left to discover"
-- was curating the OLD library against its own publisher.
--
-- The ether now tells the client WHEN a shard was born: fetch_vestiges
-- returns created_at, and the client exempts every shard younger than
-- a moon (30 days) from the rotation. Publishing appears the same
-- day, everywhere — the rotation keeps renewing only the old library.
--
-- Same shape otherwise (live, locale-first with French canon
-- fallback, newest first, 200 cap). Idempotent — pure REPLACE.
-- ═══════════════════════════════════════════════════════════════════════

-- The row type changes (created_at joins): REPLACE cannot alter OUT
-- parameters — the drop-then-recreate the older fetch migrations
-- used. Grants ride at the bottom, as always.
drop function if exists public.fetch_vestiges(text);

create or replace function public.fetch_vestiges(p_locale text default 'fr')
returns table (
    id         text,
    kind       text,
    text       text,
    source     text,
    x          double precision,
    y          double precision,
    created_at timestamptz
)
language plpgsql
security definer
set search_path = public
stable
as $$
begin
    if auth.uid() is null then
        raise exception 'KENOS_UNAUTHENTICATED';
    end if;
    -- Normalize: 'fr-FR' → 'fr'; anything unknown falls back to the
    -- canonical French — the library is never empty.
    p_locale := lower(split_part(coalesce(p_locale, 'fr'), '-', 1));

    if exists (
        select 1 from public.kenos_vestiges v
        where v.live and v.locale = p_locale
    ) then
        return query
        select v.id, v.kind, v.text, v.source, v.pos_x, v.pos_y, v.created_at
        from public.kenos_vestiges v
        where v.live and v.locale = p_locale
        order by v.created_at desc
        limit 200;
    else
        return query
        select v.id, v.kind, v.text, v.source, v.pos_x, v.pos_y, v.created_at
        from public.kenos_vestiges v
        where v.live and v.locale = 'fr'
        order by v.created_at desc
        limit 200;
    end if;
end;
$$;

revoke all on function public.fetch_vestiges(text) from public, anon;
grant execute on function public.fetch_vestiges(text) to authenticated;
