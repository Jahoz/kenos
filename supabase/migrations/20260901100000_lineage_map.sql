-- ═══════════════════════════════════════════════════════════════════════
-- KENOS — migration 0008 : lineage on the map (V3.7c)
--
-- The rebound already carries `parent_id` (migration 20260831130000).
-- The map now returns it, so the client can draw the LINEAGE
-- CONSTELLATIONS: faint lines between the members of a phoenix chain
-- — the living map of a thought's journey through humans. Metadata
-- only (a link, never a content).
-- ═══════════════════════════════════════════════════════════════════════

-- Postgres refuses CREATE OR REPLACE with a changed return type.
drop function if exists public.fetch_map_sector(
    double precision, double precision, double precision, double precision,
    integer, integer
);

create function public.fetch_map_sector(
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
    created_at  timestamptz,
    momentum    integer,
    parent_id   uuid
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
    select s.id, s.coord_x, s.coord_y, s.coord_z, s.color_theme, s.created_at, s.momentum, s.parent_id
    from (
        select e.id, e.coord_x, e.coord_y, e.coord_z, e.color_theme, e.created_at,
               e.momentum, e.parent_id,
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
          -- already represents it, and it is untouchable by contract.
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
