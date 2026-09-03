-- ═══════════════════════════════════════════════════════════════════════
-- KENOS — migration 0013 : the constellation-song (V3.14)
--
-- A corpse is a POEM or a SONG (arbitration Hugo, 2026-09-03):
--  - POEM: sealed text lines, as since V3.8/V3.13;
--  - SONG: sealed note phrases — a short sequence of indices into
--    the public pentatonic scale (the waves' instrument), composed
--    note by note by each stranger after HEARING the previous
--    phrase. Wordless by construction: anonymous as the waves,
--    tiny as a few integers, synthesized on-device at reading.
--
--  The lines' transport is untouched: a song phrase is a sealed
--  JSON payload inside the existing ciphertext column (bounded at
--  2000 chars — a 8-note phrase is ~60). No audio bytes ever
--  travel, nothing to store beyond the seal, nothing to moderate.
--  The finished song is an artifact like the finished poem: read
--  (heard) by everyone, again and again, until the moon.
--
--  VOICE (recorded audio) was arbitrated OUT for now: a voice is
--  an identity — the anonymity of the ether would not survive it.
--  Documented as a possible future mode, eyes open. See ROADMAP.
-- ═══════════════════════════════════════════════════════════════════════

alter table public.kenos_constellations
    add column if not exists kind text not null default 'POEM'
        check (kind in ('POEM', 'MELODY'));

-- ── seed_constellation v2: the drop chooses poem or song ──────────────
drop function if exists public.seed_constellation(double precision, double precision);

create function public.seed_constellation(
    p_seed_x double precision,
    p_seed_y double precision,
    p_kind text default 'POEM'
)
returns table (id uuid)
language plpgsql
security definer
set search_path = public
as $$
declare
    uid uuid := auth.uid();
    new_id uuid;
begin
    if uid is null then
        raise exception 'KENOS_UNAUTHENTICATED';
    end if;
    if p_seed_x < 0 or p_seed_x > 1 or p_seed_y < 0 or p_seed_y > 1 then
        raise exception 'KENOS_INVALID_COORDS';
    end if;
    if p_kind not in ('POEM', 'MELODY') then
        raise exception 'KENOS_INVALID_KIND';
    end if;
    -- Gentle cadence: one seed per 2 minutes per stranger.
    if exists (
        select 1 from public.kenos_constellations c
        where c.created_at > now() - interval '2 minutes'
          and c.id in (
            select constellation_id from public.kenos_constellation_lines
            where contributor_id = uid
          )
    ) then
        raise exception 'KENOS_RATE_LIMIT';
    end if;

    insert into public.kenos_constellations (seed_x, seed_y, target_lines, kind)
    values (p_seed_x, p_seed_y, 4 + floor(random() * 4)::int, p_kind)
    returning public.kenos_constellations.id into new_id;

    return query select new_id;
end;
$$;

revoke all on function public.seed_constellation(double precision, double precision, text)
    from public, anon;
grant execute on function public.seed_constellation(double precision, double precision, text)
    to authenticated;

-- ── fetch_constellations v2: the map knows what it draws ─────────────
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
    kind       text
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
           c.kind
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
