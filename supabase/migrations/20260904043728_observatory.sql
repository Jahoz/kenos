-- ═══════════════════════════════════════════════════════════════════════
-- KENOS — migration 0017 : the Observatory (V3.16, guardian dashboard)
--
-- The astronomer never reads the messages: they count the stars.
-- A usage view of the ether for the project's guardian — shapes and
-- counts only, never texts, never identifiers (the SECURITY.md threat
-- model stays the law; the dashboard is contentless by construction).
--
--  1. kenos_metrics_daily: one row per day, integer counters. Every
--     counter is bumped INSIDE the lifecycle RPC transaction (launch,
--     consume, rebound, trace, report, seed, line, close) — no new
--     reads, the FOR UPDATE SKIP LOCKED single-read core is intact.
--     Nothing client-facing is ever stored: a count is a shape.
--  2. New users: a contentless AFTER INSERT trigger on auth.users
--     (counts a birth, stores nothing about it).
--  3. Active readers: folded idempotently from the 1-day kenos_reads
--     journal into the daily row by kenos_purge (before the purge
--     erases it) and refreshed live by the admin RPC.
--  4. admin_fetch_metrics: security definer, guarded by an
--     app_metadata role claim (never user_metadata — that one is
--     user-editable). Returns pure aggregates: series, live state,
--     the 8×8 sector heatmap, derived ratios.
--
--  What stays sacred: single-read atomicity, zero plaintext
--  server-side, zero content in metrics, RLS-everything.
-- ═══════════════════════════════════════════════════════════════════════

-- ── The daily ledger: one row per day, contentless counters ────────────
create table public.kenos_metrics_daily (
    day                date primary key,
    echoes_launched    integer not null default 0 check (echoes_launched >= 0),
    echoes_consumed    integer not null default 0 check (echoes_consumed >= 0),
    echoes_rebound     integer not null default 0 check (echoes_rebound >= 0),
    traces_left        integer not null default 0 check (traces_left >= 0),
    reports_filed      integer not null default 0 check (reports_filed >= 0),
    corpses_seeded     integer not null default 0 check (corpses_seeded >= 0),
    corpses_closed     integer not null default 0 check (corpses_closed >= 0),
    lines_contributed  integer not null default 0 check (lines_contributed >= 0),
    new_users          integer not null default 0 check (new_users >= 0),
    active_readers     integer not null default 0 check (active_readers >= 0),
    updated_at         timestamptz not null default now()
);

alter table public.kenos_metrics_daily enable row level security;
revoke all on public.kenos_metrics_daily from anon, authenticated;

-- ── The counter bump: one event, one transaction, no content ───────────
-- Called ONLY from other security-definer lifecycle functions (revoked
-- from every client role). Static column increments — no dynamic SQL.
create function public.kenos_metrics_touch(p_kind text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
    if p_kind not in (
        'launched', 'consumed', 'rebound', 'trace', 'report',
        'corpse_seeded', 'corpse_closed', 'line', 'new_user'
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
        new_users
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
        (p_kind = 'new_user')::int
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
            updated_at         = now();
end;
$$;

revoke all on function public.kenos_metrics_touch(text)
    from public, anon, authenticated;

-- ── New users: count the birth, never describe it ──────────────────────
create function public.kenos_metrics_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
    perform public.kenos_metrics_touch('new_user');
    return new;
end;
$$;

revoke all on function public.kenos_metrics_new_user()
    from public, anon, authenticated;
-- GoTrue inserts users as supabase_auth_admin: the trigger function
-- must stay executable by that server-side role (never by clients).
grant execute on function public.kenos_metrics_new_user()
    to supabase_auth_admin;

create trigger kenos_metrics_user_birth
    after insert on auth.users
    for each row execute function public.kenos_metrics_new_user();

-- ── The guardian gate: app_metadata ONLY ────────────────────────────────
-- raw_user_meta_data is user-editable and must never authorize
-- anything (Supabase security rule). The claim lives in
-- raw_app_meta_data, set once by the operator (see
-- supabase/snippets/create_guardian.sql).
create function public.kenos_is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
    select coalesce(auth.jwt() -> 'app_metadata' ->> 'role', '') = 'admin'
$$;

revoke all on function public.kenos_is_admin()
    from public, anon, authenticated;

-- ── admin_fetch_metrics: pure aggregates, admin-only ───────────────────
create function public.admin_fetch_metrics(p_days integer default 30)
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
                 coalesce(m.active_readers, 0)     as active_readers
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

-- ═══════════════════════════════════════════════════════════════════════
-- Lifecycle hooks — full re-declaration of the touched functions with
-- exactly ONE added line each (the counter bump), same transaction.
-- The bodies below are verbatim copies of their current live versions;
-- this file applies last.
-- ═══════════════════════════════════════════════════════════════════════

-- ── launch_echo (current 8-param version, from 20260901120000) ────────
create or replace function public.launch_echo(
    p_ciphertext text, p_key text, p_x double precision, p_y double precision,
    p_z double precision, p_theme text, p_media_kind text, p_media_path text
)
returns table (id uuid, created_at timestamptz)
language plpgsql security definer set search_path = public, extensions
as $$
declare uid uuid := auth.uid(); new_id uuid; ts timestamptz; key text := coalesce(p_key, '');
begin
    if uid is null then raise exception 'KENOS_UNAUTHENTICATED'; end if;
    if length(p_ciphertext) < 1 or length(p_ciphertext) > 4000 or length(key) > 256 then
        raise exception 'KENOS_INVALID_LENGTH';
    end if;
    if p_x < 0 or p_x > 1 or p_y < 0 or p_y > 1 or p_z < 0.05 or p_z > 1 then raise exception 'KENOS_INVALID_COORDS'; end if;
    if p_theme not in ('TEAL', 'INDIGO', 'LUMEN') then raise exception 'KENOS_INVALID_THEME'; end if;
    if (p_media_kind is null) <> (p_media_path is null)
            or (p_media_kind is not null and p_media_kind not in ('IMAGE', 'AUDIO', 'SONG', 'EXCERPT'))
            or (p_media_kind in ('IMAGE', 'AUDIO')
                and p_media_path !~ ('^' || uid::text || '/[0-9]+-(IMAGE|AUDIO)\.bin$'))
            or (p_media_kind in ('SONG', 'EXCERPT')
                and (length(p_media_path) < 32 or length(p_media_path) > 512
                     or p_media_path !~ '^[A-Za-z0-9+/]+={0,2}$')) then
        raise exception 'KENOS_INVALID_MEDIA';
    end if;
    if exists (select 1 from public.echoes e where e.author_id = uid and e.created_at > now() - interval '20 seconds') then raise exception 'KENOS_RATE_LIMIT'; end if;
    insert into public.echoes (author_id, encrypted_text, key_seal, coord_x, coord_y, coord_z, color_theme, media_kind, media_path)
    values (uid, p_ciphertext, case when key = '' then '' else encode(pgp_sym_encrypt(key, public.kenos_ether_kek()), 'base64') end, p_x, p_y, p_z, p_theme, p_media_kind, p_media_path)
    returning public.echoes.id, public.echoes.created_at into new_id, ts;
    -- Observatory: one launch counted, contentless, same transaction.
    perform public.kenos_metrics_touch('launched');
    return query select new_id, ts;
end;
$$;
revoke all on function public.launch_echo(text, text, double precision, double precision, double precision, text, text, text) from public, anon;
grant execute on function public.launch_echo(text, text, double precision, double precision, double precision, text, text, text) to authenticated;

-- ── consume_echo (v5, from 20260831130000) — the sacred core, untouched
-- apart from the single contentless bump AFTER the atomic success ──────
create or replace function public.consume_echo(target_echo_id uuid)
returns jsonb
language plpgsql
security definer
-- pgcrypto lives in the `extensions` schema on Supabase.
set search_path = public, extensions
as $$
declare
    echo_content  text;
    echo_author   uuid;
    echo_created  timestamptz;
    echo_key      text;
    echo_momentum integer;
    media_path    text;
    media_kind    text;
    echo_theme    varchar(20);
begin
    if auth.uid() is null then
        raise exception 'KENOS_UNAUTHENTICATED';
    end if;

    -- Interception anti-spam: at most one read every 5 s.
    if exists (
        select 1 from public.kenos_reads r
        where r.reader_id = auth.uid()
          and r.read_at > now() - interval '5 seconds'
    ) then
        raise exception 'KENOS_RATE_LIMIT';
    end if;

    -- Lock the row, excluding one's own echo (untouchable).
    select e.encrypted_text, e.author_id, e.created_at, e.key_seal,
           e.momentum, e.media_path, e.media_kind, e.color_theme
      into echo_content, echo_author, echo_created, echo_key,
            echo_momentum, media_path, media_kind, echo_theme
    from public.echoes e
    where e.id = target_echo_id
      and e.author_id <> auth.uid()
    for update skip locked;

    if not found then
        return null;  -- already read elsewhere, already dissolved, or shielded.
    end if;

    delete from public.echoes where id = target_echo_id;

    insert into public.kenos_reads (reader_id, echo_id)
    values (auth.uid(), target_echo_id);

    -- The lineage: the reader's 10-minute window to re-seal it —
    -- carrying the parent's theme (the parent is destroyed below, the
    -- phoenix must inherit its color from HERE).
    insert into public.kenos_lineages (echo_id, momentum, color_theme, read_by)
    values (target_echo_id, echo_momentum, coalesce(echo_theme, 'TEAL'), auth.uid())
    on conflict (echo_id) do nothing;

    -- Bottle-in-the-sea signal for the author.
    insert into public.kenos_receptions (echo_id, author_id, drift_seconds)
    values (
        target_echo_id,
        echo_author,
        extract(epoch from (now() - echo_created))::bigint
    )
    on conflict (echo_id) do nothing;

    -- Observatory: one consumption counted, contentless, same
    -- transaction (rolls back with it — the burn and the count are one).
    perform public.kenos_metrics_touch('consumed');

    return jsonb_build_object(
        'ciphertext', echo_content,
        'key', case when echo_key = '' then null
                    else pgp_sym_decrypt(decode(echo_key, 'base64'), public.kenos_ether_kek())
        end,
        'momentum', echo_momentum
    ) || case when media_path is null then '{}'::jsonb
              else jsonb_build_object('media_path', media_path, 'media_kind', media_kind)
         end;
end;
$$;

revoke all on function public.consume_echo(uuid) from public, anon;
grant execute on function public.consume_echo(uuid) to authenticated;

-- ── rebound_echo (from 20260831130000) ─────────────────────────────────
create or replace function public.rebound_echo(
    p_source_id       uuid,
    p_parent_momentum integer,
    p_x               double precision,
    p_y               double precision,
    p_z               double precision,
    p_ciphertext      text,
    p_key             text
)
returns table (id uuid, created_at timestamptz, momentum integer)
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
    uid      uuid := auth.uid();
    lineage  integer;
    inherited_theme varchar(20);
    new_id   uuid;
    ts       timestamptz;
    next_m   integer;
begin
    if uid is null then
        raise exception 'KENOS_UNAUTHENTICATED';
    end if;

    -- Only the reader of THIS echo, within the 10-minute window.
    select l.momentum, l.color_theme into lineage, inherited_theme
    from public.kenos_lineages l
    where l.echo_id = p_source_id
      and l.read_by = uid
      and l.consumed_at > now() - interval '10 minutes';

    if lineage is null then
        raise exception 'KENOS_REBOUND_DENIED';
    end if;
    -- The client may not inflate the comet: the server holds the truth.
    if p_parent_momentum <> lineage then
        raise exception 'KENOS_REBOUND_DENIED';
    end if;

    -- Shared launch cadence: one echo at a time, whatever its origin.
    if exists (
        select 1 from public.echoes e
        where e.author_id = uid
          and e.created_at > now() - interval '20 seconds'
    ) then
        raise exception 'KENOS_RATE_LIMIT';
    end if;

    if length(p_ciphertext) < 1 or length(p_ciphertext) > 4000 then
        raise exception 'KENOS_INVALID_LENGTH';
    end if;
    if length(coalesce(p_key, '')) > 256 then
        raise exception 'KENOS_INVALID_LENGTH';
    end if;
    if p_x < 0 or p_x > 1 or p_y < 0 or p_y > 1 or p_z < 0.05 or p_z > 1 then
        raise exception 'KENOS_INVALID_COORDS';
    end if;

    next_m := lineage + 1;

    -- The phoenix inherits its parent's color (captured in the lineage
    -- at consumption — the parent row itself is long gone).
    insert into public.echoes (
        author_id, encrypted_text, key_seal,
        coord_x, coord_y, coord_z, color_theme,
        parent_id, momentum
    )
    values (
        uid,
        p_ciphertext,
        case when coalesce(p_key, '') = '' then ''
             else encode(pgp_sym_encrypt(p_key, public.kenos_ether_kek()), 'base64')
        end,
        p_x, p_y, p_z,
        coalesce(inherited_theme, 'TEAL'),
        p_source_id, next_m
    )
    returning public.echoes.id, public.echoes.created_at
    into new_id, ts;

    -- Observatory: one rebirth counted, contentless, same transaction.
    perform public.kenos_metrics_touch('rebound');

    -- The lineage burns with its decision: one rebound, once.
    delete from public.kenos_lineages where echo_id = p_source_id;

    return query select new_id, ts, next_m;
end;
$$;

revoke all on function public.rebound_echo(
    uuid, integer, double precision, double precision, double precision, text, text
) from public, anon;
grant execute on function public.rebound_echo(
    uuid, integer, double precision, double precision, double precision, text, text
) to authenticated;

-- ── leave_trace (from 0002) — found is captured BEFORE any perform,
-- so the one-shot truth is unchanged ────────────────────────────────────
create or replace function public.leave_trace(p_echo_id uuid, p_text text)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
    if auth.uid() is null then
        raise exception 'KENOS_UNAUTHENTICATED';
    end if;
    if length(p_text) < 1 or length(p_text) > 140 then
        raise exception 'KENOS_INVALID_LENGTH';
    end if;

    -- Only the reader of THIS echo, within a short window after reading.
    if not exists (
        select 1 from public.kenos_reads r
        where r.reader_id = auth.uid()
          and r.echo_id = p_echo_id
          and r.read_at > now() - interval '10 minutes'
    ) then
        raise exception 'KENOS_RATE_LIMIT';
    end if;

    -- One shot: a trace already left can never be edited or replaced.
    update public.kenos_receptions
       set reply_text = p_text
     where echo_id = p_echo_id
       and reply_text is null;

    if found then
        -- Observatory: one trace counted, contentless.
        perform public.kenos_metrics_touch('trace');
        return true;
    end if;
    return false;
end;
$$;

revoke all on function public.leave_trace(uuid, text) from public, anon;
grant execute on function public.leave_trace(uuid, text) to authenticated;

-- ── report_echo (from 20260831101837) ──────────────────────────────────
create or replace function public.report_echo(p_echo_id uuid, p_reason_code text)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
    if auth.uid() is null then
        raise exception 'KENOS_UNAUTHENTICATED';
    end if;
    if p_reason_code not in ('INAPPROPRIATE', 'SPAM', 'DANGER', 'OTHER') then
        raise exception 'KENOS_INVALID_REPORT_REASON';
    end if;

    -- A report is possible only for an echo the caller actually consumed,
    -- within the same short after-reading window as a trace.
    if not exists (
        select 1 from public.kenos_reads r
        where r.reader_id = auth.uid()
          and r.echo_id = p_echo_id
          and r.read_at > now() - interval '10 minutes'
    ) then
        raise exception 'KENOS_RATE_LIMIT';
    end if;

    insert into public.kenos_echo_reports (echo_id, reporter_id, reason_code)
    values (p_echo_id, auth.uid(), p_reason_code)
    on conflict (echo_id, reporter_id) do nothing;

    if found then
        -- Observatory: one report counted, contentless.
        perform public.kenos_metrics_touch('report');
        return true;
    end if;
    return false;
end;
$$;

revoke all on function public.report_echo(uuid, text) from public, anon;
grant execute on function public.report_echo(uuid, text) to authenticated;

-- ── seed_constellation (v2, from 20260903050411) ───────────────────────
create or replace function public.seed_constellation(
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

    -- Observatory: one corpse seeded, contentless, same transaction.
    perform public.kenos_metrics_touch('corpse_seeded');

    return query select new_id;
end;
$$;

revoke all on function public.seed_constellation(double precision, double precision, text)
    from public, anon;
grant execute on function public.seed_constellation(double precision, double precision, text)
    to authenticated;

-- ── contribute_line (v2, from 20260903001537) ──────────────────────────
create or replace function public.contribute_line(
    p_constellation_id uuid,
    p_ciphertext        text,
    p_key               text
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

revoke all on function public.contribute_line(uuid, text, text)
    from public, anon;
grant execute on function public.contribute_line(uuid, text, text)
    to authenticated;

-- ── kenos_purge (v6): fold the readers BEFORE the journal burns ────────
create or replace function public.kenos_purge()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
    -- Observatory fold: capture distinct readers per day BEFORE the
    -- 1-day purge erases the journal (idempotent — never decreases).
    update public.kenos_metrics_daily m
       set active_readers = greatest(
               m.active_readers,
               (select count(distinct r.reader_id)
                  from public.kenos_reads r
                 where r.read_at::date = m.day)
           ),
           updated_at = now()
     where m.day in (select distinct read_at::date from public.kenos_reads);

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
    -- Finished corpses: artifacts for a moon, then the ether forgets.
    delete from public.kenos_constellations
    where state = 'CLOSED' and closed_at < now() - interval '30 days';
end;
$$;

revoke all on function public.kenos_purge() from public, anon, authenticated;
