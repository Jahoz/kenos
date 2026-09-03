-- ═══════════════════════════════════════════════════════════════════════
-- KENOS — migration 0014 : the Gardener & the Curator (2026-09-03)
--
-- The ether must stay alive in production: open rings for strangers
-- to fill (supply), and READABLE artifacts from day one (culture).
--
--  THE GARDENER — `kenos_garden_seed()`: plants open constellations
--  (empty rings, never content) up to a target, self-regulating: it
--  counts what is already open and plants only the missing few.
--  Wire pg_cron (or any scheduler) and the ether never runs empty.
--
--  THE CURATOR — `curated_by`: a nullable attribution on the
--  constellation. The gardener plants EMPTY rings (no lines, no
--  lies). Readable artifacts come from CURATED culture — real
--  public-domain poetry (the Vestiges philosophy: real content,
--  credited, never fabricated confidences). When curated_by is set,
--  the reading tells the poet's name instead of pretending
--  strangers wrote it. Curated rows are wipeable in one predicate.
-- ═══════════════════════════════════════════════════════════════════════

alter table public.kenos_constellations
    add column if not exists curated_by text;

-- ── fetch_constellations v3: the attribution rides the metadata ───────
drop function if exists public.fetch_constellations(
    double precision, double precision, double precision, double precision
);

create function public.fetch_constellations(
    p_min_x double precision default 0,
    p_min_y double precision default 0,
    p_max_x double precision default 1,
    p_max_y double precision default 1
)
returns table (
    id         uuid,
    seed_x     double precision,
    seed_y     double precision,
    state      varchar,
    line_count integer,
    target     integer,
    created_at timestamptz,
    kind       text,
    curated_by text
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
    select c.id, c.seed_x, c.seed_y, c.state,
           (select count(*) from public.kenos_constellation_lines l
            where l.constellation_id = c.id)::int,
           c.target_lines,
           c.created_at,
           c.kind,
           c.curated_by
    from public.kenos_constellations c
    where c.seed_x >= least(p_min_x, p_max_x)
      and c.seed_x <= greatest(p_min_x, p_max_x)
      and c.seed_y >= least(p_min_y, p_max_y)
      and c.seed_y <= greatest(p_min_y, p_max_y)
      and c.created_at > now() - interval '30 days'
    order by c.created_at desc
    limit 100;
end;
$$;

revoke all on function public.fetch_constellations(
    double precision, double precision, double precision, double precision
) from public, anon;
grant execute on function public.fetch_constellations(
    double precision, double precision, double precision, double precision
) to authenticated;

-- ── The Gardener: keep the ether seeded with open rings ───────────────
-- Service-level (no auth): called by a scheduler or an operator. Plants
-- up to p_max_new open constellations when fewer than p_target are
-- alive, mixing poems and songs, never writing a single line — the
-- rings wait for strangers, exactly like hand-sown ones.
create or replace function public.kenos_garden_seed(
    p_target int default 14,
    p_max_new int default 5
)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
    alive   int;
    planted int := 0;
    missing int;
    kind    text;
    target  int;
begin
    select count(*) into alive
    from public.kenos_constellations
    where state = 'OPEN' and created_at > now() - interval '7 days';

    missing := least(p_target - alive, p_max_new);
    while planted < missing and missing > 0 loop
        kind := case when random() < 0.6 then 'POEM' else 'MELODY' end;
        target := 4 + floor(random() * 4)::int;
        insert into public.kenos_constellations (seed_x, seed_y, target_lines, kind)
        values (0.06 + random() * 0.88, 0.08 + random() * 0.84, target, kind);
        planted := planted + 1;
    end loop;

    return planted;
end;
$$;

revoke all on function public.kenos_garden_seed(int, int)
    from public, anon, authenticated;

-- ── pg_cron wiring (READY, COMMENTED — enable when the extension is) ──
-- create extension if not exists pg_cron;
-- select cron.schedule(
--     'kenos-gardener',
--     '23 */6 * * *',                    -- every 6 hours, off-minute
--     $$ select public.kenos_garden_seed(); $$
-- );
