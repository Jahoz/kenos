-- ═══════════════════════════════════════════════════════════════════════
-- KENOS — migration 0016 : the Vestiges go multilingual (V3.16)
--
-- Arbitration (Hugo, 2026-09-04): "on garde KENOS" — the product
-- voice stays FRENCH, canonical, forever. The interface stays French.
-- What crosses borders is the CURATED CULTURE: every shard exists in
-- a canonical French row and any number of translated rows, served
-- by the traveller's device locale — with an honest French fallback
-- (a traveler never meets an empty library).
--
--  THE PRODUCT LAW (unchanged, now written down): user content —
--  echoes, constellations, songs, traces — is NEVER translated.
--  Sealed on-device, it crosses borders in the language it was
--  whispered in. Like a real bottle at sea.
-- ═══════════════════════════════════════════════════════════════════════

-- Locale on every shard; the canonical French is the default and the
-- fallback. PK widens: the same id may exist in several languages.
alter table public.kenos_vestiges
    add column if not exists locale text not null default 'fr';

-- The same shard may exist in several languages: the key widens.
alter table public.kenos_vestiges
    drop constraint kenos_vestiges_pkey;
alter table public.kenos_vestiges
    add primary key (id, locale);

drop index if exists idx_vestiges_live;
create index idx_vestiges_live on public.kenos_vestiges (live, locale);

-- ── fetch_vestiges v2: the shard speaks the traveler's language ────
drop function if exists public.fetch_vestiges();

create or replace function public.fetch_vestiges(p_locale text default 'fr')
returns table (
    id     text,
    kind   text,
    text   text,
    source text,
    x      double precision,
    y      double precision
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
        select v.id, v.kind, v.text, v.source, v.pos_x, v.pos_y
        from public.kenos_vestiges v
        where v.live and v.locale = p_locale
        order by v.created_at desc
        limit 200;
    else
        return query
        select v.id, v.kind, v.text, v.source, v.pos_x, v.pos_y
        from public.kenos_vestiges v
        where v.live and v.locale = 'fr'
        order by v.created_at desc
        limit 200;
    end if;
end;
$$;

revoke all on function public.fetch_vestiges(text) from public, anon;
grant execute on function public.fetch_vestiges(text) to authenticated;
