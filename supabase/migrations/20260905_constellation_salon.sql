-- ═══════════════════════════════════════════════════════════════════════
-- KENOS — migration 0020 : LE SALON — the invitable constellation (V3.19)
--
-- The historic exquisite corpse was played in a salon, between friends,
-- blind. A public ring drifts for strangers; a SALON ring lives behind
-- a door: one shareable link, carried by the seeder to the people they
-- chose. Whoever holds the key may give a line — the sacred rules are
-- untouched (one line per stranger, the preceding line only, auto-close
-- at the target, the finished poem becomes a public artifact).
--
-- Arbitrations (Hugo, 2026-09-04 — recommendations adopted):
--   ONE LINK, not per-person invitations: the token is the door, every
--   holder is a guest, it may travel from friend to friend (the viral
--   loop is native). Nominative seats remain Roadmap+.
--   HIDDEN WHILE WRITING: an OPEN salon never appears on the map — no
--   two-class ether, no visible reserved seats. CLOSED, the artifact
--   joins the public sky, indistinguishable from a strangers' poem.
--   THE KEY IS A CAPABILITY: 16 random bytes, hex — the base stores
--   only its sha256 fingerprint. A dump holds no door. The plaintext
--   exists in the link and in the seeder's share sheet, nowhere else.
--   THE CLAIM IS THE CONTRIBUTION: no guest registry, no ghost seats —
--   the token is checked inside the same transaction that writes the
--   line. The link dies with the ring (OPEN purge 7 days, CLOSED 30).
--
--  What stays sacred: single-read atomicity, Ether Seal (zero line in
--  clear server-side), RPC-only access, KENOS_* grammar, contentless
--  metrics inside the lifecycle transactions.
-- ═══════════════════════════════════════════════════════════════════════

-- ── The door column: sha256 fingerprint, null = a public ring ─────────
alter table public.kenos_constellations
    add column if not exists invite_token_hash text;

create unique index if not exists idx_constellations_invite_token
    on public.kenos_constellations (invite_token_hash)
    where invite_token_hash is not null;

-- ── Observatory: one more contentless counter ──────────────────────────
alter table public.kenos_metrics_daily
    add column if not exists salons_seeded integer not null default 0
        check (salons_seeded >= 0);

create or replace function public.kenos_metrics_touch(p_kind text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
    if p_kind not in (
        'launched', 'consumed', 'rebound', 'trace', 'report',
        'corpse_seeded', 'corpse_closed', 'line', 'new_user',
        'salon_seeded'
    ) then
        raise exception 'KENOS_METRICS_BAD_KIND';
    end if;

    -- The INSERT path seeds the touched counter at 1 (the first event
    -- of a day must never be lost to a zero-default row); every later
    -- event of the day takes the conflict path and increments.
    insert into public.kenos_metrics_daily as m (
        day,
        echoes_launched, echoes_consumed, echoes_rebound,
        traces_left, reports_filed,
        corpses_seeded, corpses_closed, lines_contributed,
        new_users, salons_seeded
    )
    values (
        current_date,
        (p_kind = 'launched')::int,
        (p_kind = 'consumed')::int,
        (p_kind = 'rebound')::int,
        (p_kind = 'trace')::int,
        (p_kind = 'report')::int,
        (p_kind = 'corpse_seeded')::int,
        (p_kind = 'corpse_closed')::int,
        (p_kind = 'line')::int,
        (p_kind = 'new_user')::int,
        (p_kind = 'salon_seeded')::int
    )
    on conflict (day) do update
    set echoes_launched    = m.echoes_launched    + (p_kind = 'launched')::int,
        echoes_consumed    = m.echoes_consumed    + (p_kind = 'consumed')::int,
        echoes_rebound     = m.echoes_rebound     + (p_kind = 'rebound')::int,
        traces_left        = m.traces_left        + (p_kind = 'trace')::int,
        reports_filed      = m.reports_filed      + (p_kind = 'report')::int,
        corpses_seeded     = m.corpses_seeded     + (p_kind = 'corpse_seeded')::int,
        corpses_closed     = m.corpses_closed     + (p_kind = 'corpse_closed')::int,
        lines_contributed  = m.lines_contributed  + (p_kind = 'line')::int,
        new_users          = m.new_users          + (p_kind = 'new_user')::int,
        salons_seeded      = m.salons_seeded      + (p_kind = 'salon_seeded')::int,
        updated_at         = now();
end;
$$;

revoke all on function public.kenos_metrics_touch(text)
    from public, anon, authenticated;

-- ── seed_constellation v3: the ring may be born behind a door ─────────
-- Additive parameter and additive return column: already-deployed
-- clients keep their three-argument call and ignore the null token.
drop function if exists public.seed_constellation(double precision, double precision, text);

create function public.seed_constellation(
    p_seed_x double precision,
    p_seed_y double precision,
    p_kind text default 'POEM',
    p_invited boolean default false
)
returns table (id uuid, invite_token text)
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
    uid        uuid := auth.uid();
    new_id     uuid;
    v_token    text := '';
    v_hash     text;
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

    if p_invited then
        -- The key: 16 random bytes, hex-printable for a URL. Only its
        -- sha256 fingerprint is stored; the plaintext crosses the wire
        -- exactly once, to the seeder.
        v_token := encode(gen_random_bytes(16), 'hex');
        v_hash  := encode(digest(v_token, 'sha256'), 'hex');
    end if;

    insert into public.kenos_constellations (seed_x, seed_y, target_lines, kind, invite_token_hash)
    values (p_seed_x, p_seed_y, 4 + floor(random() * 4)::int, p_kind, v_hash)
    returning public.kenos_constellations.id into new_id;

    -- Observatory: one corpse seeded, contentless, same transaction —
    -- a salon is a corpse; the salon counter tells the two apart.
    perform public.kenos_metrics_touch('corpse_seeded');
    if p_invited then
        perform public.kenos_metrics_touch('salon_seeded');
    end if;

    return query select new_id, nullif(v_token, '');
end;
$$;

revoke all on function public.seed_constellation(double precision, double precision, text, boolean)
    from public, anon;
grant execute on function public.seed_constellation(double precision, double precision, text, boolean)
    to authenticated;

-- ── contribute_line v3: the door guards the writing ────────────────────
-- The token check lives INSIDE the locked read: the claim is the
-- contribution, atomically. Missing and wrong keys raise the SAME
-- error — the door says nothing about what is behind it.
drop function if exists public.contribute_line(uuid, text, text);

create function public.contribute_line(
    p_constellation_id uuid,
    p_ciphertext        text,
    p_key               text,
    p_invite_token      text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
    uid           uuid := auth.uid();
    lines_so_far  integer;
    target        integer;
    c_state       varchar;
    c_hash        text;
    prev_ct       text;
    prev_key_seal text;
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

    select c.state, c.target_lines, c.invite_token_hash
      into c_state, target, c_hash
      from public.kenos_constellations c
     where c.id = p_constellation_id
       for update;

    if c_state is null then
        raise exception 'KENOS_NOT_FOUND';
    end if;
    if c_state <> 'OPEN' then
        raise exception 'KENOS_CLOSED';
    end if;
    if c_hash is not null then
        if coalesce(p_invite_token, '') = ''
           or encode(digest(p_invite_token, 'sha256'), 'hex') <> c_hash then
            raise exception 'KENOS_INVITE_UNKNOWN';
        end if;
    end if;

    -- The preceding line, captured BEFORE the insert: the highest
    -- line number so far. Its key leaves the escrow here, once,
    -- for this contributor only.
    select l.encrypted_text, l.key_seal
      into prev_ct, prev_key_seal
      from public.kenos_constellation_lines l
     where l.constellation_id = p_constellation_id
     order by l.line_number desc
     limit 1;

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

    -- Observatory: one line contributed, contentless, same transaction.
    perform public.kenos_metrics_touch('line');

    select count(*) into lines_so_far
      from public.kenos_constellation_lines
      where constellation_id = p_constellation_id;

    if lines_so_far >= target then
        update public.kenos_constellations
           set state = 'CLOSED', closed_at = now()
         where id = p_constellation_id;
        -- Observatory: one corpse closed, contentless.
        perform public.kenos_metrics_touch('corpse_closed');
    end if;

    return jsonb_build_object(
        'count', lines_so_far,
        'previous', case
            when prev_ct is null then null
            else jsonb_build_object(
                'text', prev_ct,
                'key', case when prev_key_seal = '' then null
                            else pgp_sym_decrypt(decode(prev_key_seal, 'base64'), public.kenos_ether_kek())
                       end
            )
        end
    );
end;
$$;

revoke all on function public.contribute_line(uuid, text, text, text)
    from public, anon;
grant execute on function public.contribute_line(uuid, text, text, text)
    to authenticated;

-- ── peek_previous_line v2: the peek demands the key too ────────────────
drop function if exists public.peek_previous_line(uuid);

create function public.peek_previous_line(
    p_constellation_id uuid,
    p_invite_token text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
    c_state       varchar;
    c_hash        text;
    prev_ct       text;
    prev_key_seal text;
begin
    if auth.uid() is null then
        raise exception 'KENOS_UNAUTHENTICATED';
    end if;

    select c.state, c.invite_token_hash
      into c_state, c_hash
      from public.kenos_constellations c
     where c.id = p_constellation_id;

    if c_state is null then
        raise exception 'KENOS_NOT_FOUND';
    end if;
    if c_state <> 'OPEN' then
        raise exception 'KENOS_CLOSED';
    end if;
    if c_hash is not null then
        if coalesce(p_invite_token, '') = ''
           or encode(digest(p_invite_token, 'sha256'), 'hex') <> c_hash then
            raise exception 'KENOS_INVITE_UNKNOWN';
        end if;
    end if;

    select l.encrypted_text, l.key_seal
      into prev_ct, prev_key_seal
      from public.kenos_constellation_lines l
     where l.constellation_id = p_constellation_id
     order by l.line_number desc
     limit 1;

    if prev_ct is null then
        return null;  -- the poem has not started: the peeker opens it
    end if;

    return jsonb_build_object(
        'text', prev_ct,
        'key', case when prev_key_seal = '' then null
                    else pgp_sym_decrypt(decode(prev_key_seal, 'base64'), public.kenos_ether_kek())
               end
    );
end;
$$;

revoke all on function public.peek_previous_line(uuid, text)
    from public, anon;
grant execute on function public.peek_previous_line(uuid, text)
    to authenticated;

-- ── fetch_constellations v4: open salons do not exist on the map ───────
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
      -- LE SALON: hidden while OPEN — a CLOSED salon joins the sky as
      -- an artifact like any other, indistinguishable from a poem of
      -- strangers. No two-class ether.
      and (c.invite_token_hash is null or c.state = 'CLOSED')
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

-- ── fetch_invited_constellation: the claim door ────────────────────────
-- The link's key resolves the ring's METADATA (never a line, never the
-- fingerprint): enough for the claim screen to speak, blind as the map.
create function public.fetch_invited_constellation(p_token text)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
    v_id          uuid;
    v_seed_x      double precision;
    v_seed_y      double precision;
    v_kind        text;
    v_state       varchar;
    v_target      integer;
    v_line_count  integer;
begin
    if auth.uid() is null then
        raise exception 'KENOS_UNAUTHENTICATED';
    end if;
    if p_token is null or length(p_token) < 16 or length(p_token) > 128 then
        raise exception 'KENOS_INVITE_UNKNOWN';
    end if;

    select c.id, c.seed_x, c.seed_y, c.kind, c.state, c.target_lines,
           (select count(*) from public.kenos_constellation_lines l
            where l.constellation_id = c.id)::int
      into v_id, v_seed_x, v_seed_y, v_kind, v_state, v_target, v_line_count
      from public.kenos_constellations c
     where c.invite_token_hash = encode(digest(p_token, 'sha256'), 'hex');

    if v_id is null then
        raise exception 'KENOS_INVITE_UNKNOWN';
    end if;

    return jsonb_build_object(
        'id', v_id,
        'seed_x', v_seed_x,
        'seed_y', v_seed_y,
        'kind', v_kind,
        'state', v_state,
        'line_count', v_line_count,
        'target', v_target
    );
end;
$$;

revoke all on function public.fetch_invited_constellation(text)
    from public, anon;
grant execute on function public.fetch_invited_constellation(text)
    to authenticated;

-- ── admin_fetch_metrics v2: the salon counters reach the guardian ──────
create or replace function public.admin_fetch_metrics(p_days integer default 30)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    v_days     integer := greatest(1, least(coalesce(p_days, 30), 90));
    v_series   jsonb;
    v_live     jsonb;
    v_sectors  jsonb;
    v_derived  jsonb;
begin
    if auth.uid() is null then
        raise exception 'KENOS_UNAUTHENTICATED';
    end if;
    if not public.kenos_is_admin() then
        raise exception 'KENOS_FORBIDDEN' using errcode = '42501';
    end if;

    -- Refresh the rolling active-readers fold for the days the 1-day
    -- journal still covers (idempotent: greatest never decreases).
    update public.kenos_metrics_daily m
       set active_readers = greatest(
               m.active_readers,
               (select count(distinct r.reader_id)
                  from public.kenos_reads r
                 where r.read_at::date = m.day)
           ),
           updated_at = now()
     where m.day >= current_date - 1;

    select coalesce(jsonb_agg(row_to_json(s) order by s.day), '[]'::jsonb)
      into v_series
      from (
          select to_char(d.day, 'YYYY-MM-DD') as day,
                 coalesce(m.echoes_launched, 0)    as echoes_launched,
                 coalesce(m.echoes_consumed, 0)    as echoes_consumed,
                 coalesce(m.echoes_rebound, 0)     as echoes_rebound,
                 coalesce(m.traces_left, 0)        as traces_left,
                 coalesce(m.reports_filed, 0)      as reports_filed,
                 coalesce(m.corpses_seeded, 0)     as corpses_seeded,
                 coalesce(m.corpses_closed, 0)     as corpses_closed,
                 coalesce(m.lines_contributed, 0)  as lines_contributed,
                 coalesce(m.new_users, 0)          as new_users,
                 coalesce(m.active_readers, 0)     as active_readers,
                 coalesce(m.salons_seeded, 0)      as salons_seeded
            from (
                select generate_series(
                           current_date - (v_days - 1),
                           current_date,
                           interval '1 day'
                       )::date as day
            ) d
            left join public.kenos_metrics_daily m on m.day = d.day
      ) s;

    select jsonb_build_object(
              'echoes_drifting', (select count(*) from public.echoes),
              'users_total', (select count(*) from auth.users),
              'constellations_open',
                  (select count(*) from public.kenos_constellations
                    where state = 'OPEN'),
              'constellations_closed',
                  (select count(*) from public.kenos_constellations
                    where state = 'CLOSED'),
              'salons_open',
                  (select count(*) from public.kenos_constellations
                    where state = 'OPEN'
                      and invite_token_hash is not null),
              'vestiges_live',
                  (select count(*) from public.kenos_vestiges where live),
              'reports_open',
                  (select count(*) from public.kenos_echo_reports)
           )
      into v_live;

    select coalesce(
               jsonb_agg(jsonb_build_array(t.sector_x, t.sector_y, t.n)
                         order by t.n desc),
               '[]'::jsonb
           )
      into v_sectors
      from (select sector_x, sector_y, count(*) as n
              from public.echoes group by 1, 2) t;

    select jsonb_build_object(
              'median_drift_seconds',
                  (select percentile_disc(0.5) within group (order by drift_seconds)
                     from public.kenos_receptions
                    where read_at > now() - interval '30 days'),
              'trace_rate_30d',
                  (select round(count(reply_text)::numeric
                                / greatest(count(*), 1), 3)
                     from public.kenos_receptions
                    where read_at > now() - interval '30 days'),
              'rebound_rate_30d',
                  (select round(sum(echoes_rebound)::numeric
                                / greatest(sum(echoes_consumed), 1), 3)
                     from public.kenos_metrics_daily
                    where day > current_date - 30)
           )
      into v_derived;

    return jsonb_build_object(
        'series', v_series,
        'live', v_live,
        'sectors', v_sectors,
        'derived', v_derived
    );
end;
$$;

revoke all on function public.admin_fetch_metrics(integer)
    from public, anon;
grant execute on function public.admin_fetch_metrics(integer)
    to authenticated;
