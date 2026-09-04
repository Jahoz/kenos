-- ═══════════════════════════════════════════════════════════════════════
-- KENOS — the seed guard (V3.20): the sky is not a billboard
--
-- THE HOLE (found at launch): seed_constellation's cadence counted
-- only rings the caller had WRITTEN a line into. A script that only
-- seeds — never contributes — escaped every limit and could open
-- rings without end: each one a visible gate on the map, none of
-- them ever closing on their own (the reaper was not wired either).
--
-- THE FIX: a BEFORE INSERT trigger on kenos_constellations, not a
-- rewrite of seed_constellation. The trigger:
--   * stamps seeder_id := auth.uid() for every human seed — the
--     caller's own JWT, invisible to clients (fetch_constellations
--     selects explicit columns; the column is never granted);
--   * exempts the ether's own hands (gardener, curator, migrations,
--     load seed) — they run without a JWT, auth.uid() is null;
--   * enforces: one seed / 2 min per stranger, and at most 5 OPEN
--     rings per stranger at once (a hand holds few poems).
--
-- Being a trigger makes it version-proof: seed_constellation has
-- already been rewritten twice (song kinds, salons) — the guard
-- holds regardless of which version of the function inserts.
-- Legacy rings carry seeder_id null and count for no one. When an
-- account is deleted its rings survive, mothered by no one
-- (on delete set null — a poem outlives its seeder).
-- ═══════════════════════════════════════════════════════════════════════

alter table public.kenos_constellations
    add column if not exists seeder_id uuid
        references auth.users (id) on delete set null;

create or replace function public.kenos_seed_guard()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
    uid        uuid := auth.uid();
    open_rings integer;
begin
    -- No JWT: the ether's own hands (gardener, curator, migrations).
    if uid is null then
        new.seeder_id := null;
        return new;
    end if;

    new.seeder_id := uid;

    -- Cadence: one seed every 2 minutes per stranger. The old check
    -- inside seed_constellation counted only rings the caller wrote
    -- in — this one counts every seed the hand actually dropped.
    if exists (
        select 1 from public.kenos_constellations c
        where c.seeder_id = uid
          and c.created_at > now() - interval '2 minutes'
    ) then
        raise exception 'KENOS_RATE_LIMIT'
            using errcode = 'P0001';
    end if;

    -- Cap: five open rings per stranger at once. Close one to sow
    -- again — the sky shares its space.
    select count(*) into open_rings
      from public.kenos_constellations
     where seeder_id = uid
       and state = 'OPEN';
    if open_rings >= 5 then
        raise exception 'KENOS_SEED_CAP'
            using errcode = 'P0001';
    end if;

    return new;
end;
$$;
revoke all on function public.kenos_seed_guard() from public, anon, authenticated;

create trigger kenos_constellation_seed_guard
    before insert on public.kenos_constellations
    for each row execute function public.kenos_seed_guard();
