-- ═══════════════════════════════════════════════════════════════════════
-- KENOS — migration 0009 : the Exquisite Corpse (V3.8, constellations)
--
-- A constellation is a blind collaborative poem: each stranger adds
-- ONE line WITHOUT seeing the others (the server never returns
-- fragments — only the count). At K contributions it closes, and ONE
-- person may read it whole, once, then it dissolves.
--
-- The soul guards (arbitrated with Hugo, ROADMAP_V3 V3.8):
--  - The contributor NEVER sees the whole they helped write: one
--    gives a line to the void, like an echo.
--  - No push, no live counter of "your" constellations: only the
--    Awakening may whisper, at the next visit, that one touched has
--    closed. No check-back hooks, no rewards, no signatures.
--  - Zero stardust, zero receptions: the corpse is culture, not
--    connection.
-- ═══════════════════════════════════════════════════════════════════════

-- A constellation: seeded somewhere in the ether, open or closed.
create table public.kenos_constellations (
    id             uuid primary key default gen_random_uuid(),
    seed_x         double precision not null check (seed_x between 0 and 1),
    seed_y         double precision not null check (seed_y between 0 and 1),
    target_lines   integer not null check (target_lines between 4 and 7),
    state          varchar(10) not null default 'OPEN'
                   check (state in ('OPEN', 'CLOSED', 'CONSUMED')),
    created_at     timestamptz not null default now(),
    closed_at      timestamptz
);

create index idx_constellations_state on public.kenos_constellations (state, created_at desc);

-- One blind line per stranger. The text is sealed like an echo
-- (Ether Seal: encrypted on the contributor's device).
create table public.kenos_constellation_lines (
    constellation_id uuid not null references public.kenos_constellations (id) on delete cascade,
    contributor_id   uuid not null references auth.users (id) on delete cascade,
    line_number      integer not null,
    encrypted_text   text not null,
    key_seal         text not null default '',
    created_at       timestamptz not null default now(),
    primary key (constellation_id, contributor_id)
);

create index idx_lines_constellation on public.kenos_constellation_lines (constellation_id, line_number);

alter table public.kenos_constellations enable row level security;
alter table public.kenos_constellation_lines enable row level security;

-- RPC-only, like everything that breathes here.
revoke all on public.kenos_constellations from anon, authenticated;
revoke all on public.kenos_constellation_lines from anon, authenticated;

-- ── RPC 1: seed a new constellation (the Mirror's third mode) ──────────
create function public.seed_constellation(
    p_seed_x double precision,
    p_seed_y double precision
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

    insert into public.kenos_constellations (seed_x, seed_y, target_lines)
    values (p_seed_x, p_seed_y, 4 + floor(random() * 4)::int)
    returning public.kenos_constellations.id into new_id;

    return query select new_id;
end;
$$;

revoke all on function public.seed_constellation(double precision, double precision)
    from public, anon;
grant execute on function public.seed_constellation(double precision, double precision)
    to authenticated;

-- ── RPC 2: contribute ONE blind line ────────────────────────────────────
-- Returns the count of lines so far (NEVER the fragments — the soul
-- of the exquisite corpse is that no one sees the whole while writing).
create function public.contribute_line(
    p_constellation_id uuid,
    p_ciphertext        text,
    p_key               text
)
returns integer
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
    uid uuid := auth.uid();
    lines_so_far integer;
    target integer;
    c_state varchar;
begin
    if uid is null then
        raise exception 'KENOS_UNAUTHENTICATED';
    end if;
    if length(p_ciphertext) < 1 or length(p_ciphertext) > 2000 then
        raise exception 'KENOS_INVALID_LENGTH';
    end if;
    if length(coalesce(p_key, '')) > 256 then
        raise exception 'KENOS_INVALID_LENGTH';
    end if;

    select c.state, c.target_lines into c_state, target
    from public.kenos_constellations c
    where c.id = p_constellation_id
    for update;

    if c_state is null then
        raise exception 'KENOS_NOT_FOUND';
    end if;
    if c_state <> 'OPEN' then
        raise exception 'KENOS_CLOSED';
    end if;

    -- One line per stranger: the PK (constellation_id, contributor_id)
    -- makes the second contribution a violation we translate.
    begin
        insert into public.kenos_constellation_lines (
            constellation_id, contributor_id, line_number,
            encrypted_text, key_seal
        )
        values (
            p_constellation_id, uid,
            (select count(*) from public.kenos_constellation_lines
             where constellation_id = p_constellation_id) + 1,
            p_ciphertext,
            case when coalesce(p_key, '') = '' then ''
                 else encode(pgp_sym_encrypt(p_key, public.kenos_ether_kek()), 'base64')
            end
        );
    exception when unique_violation then
        raise exception 'KENOS_ALREADY_CONTRIBUTED';
    end;

    select count(*) into lines_so_far
    from public.kenos_constellation_lines
    where constellation_id = p_constellation_id;

    -- Auto-close at the target: the corpse is complete.
    if lines_so_far >= target then
        update public.kenos_constellations
           set state = 'CLOSED', closed_at = now()
         where id = p_constellation_id;
    end if;

    return lines_so_far;
end;
$$;

revoke all on function public.contribute_line(uuid, text, text)
    from public, anon;
grant execute on function public.contribute_line(uuid, text, text)
    to authenticated;

-- ── RPC 3: the map sees open/closed constellations (metadata only) ────
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
    created_at timestamptz
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
           c.created_at
    from public.kenos_constellations c
    where c.seed_x >= least(p_min_x, p_max_x)
      and c.seed_x <= greatest(p_min_x, p_max_x)
      and c.seed_y >= least(p_min_y, p_max_y)
      and c.seed_y <= greatest(p_min_y, p_max_y)
      and c.created_at > now() - interval '7 days'
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

-- ── RPC 4: THE single reading — the corpse is read whole, once ────────
-- Only a CLOSED constellation, and only by someone who did NOT
-- contribute to it (the contributor never sees the whole — the soul).
create function public.consume_constellation(p_constellation_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
    uid uuid := auth.uid();
    c_state varchar;
    assembled jsonb;
begin
    if uid is null then
        raise exception 'KENOS_UNAUTHENTICATED';
    end if;

    select c.state into c_state
    from public.kenos_constellations c
    where c.id = p_constellation_id
    for update;

    if c_state is null then
        raise exception 'KENOS_NOT_FOUND';
    end if;
    if c_state = 'OPEN' then
        raise exception 'KENOS_STILL_OPEN';
    end if;
    if c_state = 'CONSUMED' then
        return null;
    end if;

    -- The contributor NEVER reads the whole they helped write.
    if exists (
        select 1 from public.kenos_constellation_lines l
        where l.constellation_id = p_constellation_id
          and l.contributor_id = uid
    ) then
        raise exception 'KENOS_CONTRIBUTOR_BARRED';
    end if;

    -- Assemble: unseal each line with the shared escrow.
    select jsonb_agg(
        jsonb_build_object(
            'line_number', l.line_number,
            'text', case when l.key_seal = '' then l.encrypted_text
                         else pgp_sym_decrypt(decode(l.key_seal, 'base64'), public.kenos_ether_kek())
                    end,
            'key', case when l.key_seal = '' then null
                        else pgp_sym_decrypt(decode(l.key_seal, 'base64'), public.kenos_ether_kek())
                   end
        ) order by l.line_number
    )
    into assembled
    from public.kenos_constellation_lines l
    where l.constellation_id = p_constellation_id;

    -- The corpse dissolves: lines AND constellation are gone.
    delete from public.kenos_constellation_lines
    where constellation_id = p_constellation_id;
    delete from public.kenos_constellations
    where id = p_constellation_id;

    return jsonb_build_object('lines', coalesce(assembled, '[]'::jsonb));
end;
$$;

revoke all on function public.consume_constellation(uuid)
    from public, anon;
grant execute on function public.consume_constellation(uuid)
    to authenticated;

-- ── kenos_purge (v4): stale constellations follow the echoes ───────────
create or replace function public.kenos_purge()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
    delete from public.echoes
    where created_at < now() - interval '30 days';
    delete from public.kenos_reads
    where read_at < now() - interval '1 day';
    delete from public.kenos_receptions
    where read_at < now() - interval '30 days';
    delete from public.kenos_echo_reports
    where reported_at < now() - interval '30 days';
    delete from public.kenos_frequencies
    where created_at < now() - interval '60 seconds';
    delete from public.kenos_lineages
    where consumed_at < now() - interval '1 hour';
    -- Constellations that never closed: the poem goes back to the void.
    delete from public.kenos_constellations
    where state = 'OPEN' and created_at < now() - interval '7 days';
end;
$$;

revoke all on function public.kenos_purge() from public, anon, authenticated;
