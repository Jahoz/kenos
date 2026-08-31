-- ═══════════════════════════════════════════════════════════════════════
-- KENOS — migration 0007 : the Sling-Shot (V3.3, « phoenix » design)
--
-- An echo read is an echo dead — the atomic single read stays sacred.
-- But the reader now holds a power: re-seal the thought and give it
-- velocity again. The rebound is a NEW echo, freshly encrypted by the
-- reader's device for ONE new receiver, carrying the lineage's
-- momentum + 1 as a PUBLIC metadata (a count, never a content).
--
--  NB: timestamped AFTER 20260831105403_echo_media, which also
--  replaces consume_echo (this is the second silent-overwrite of the
--  purge/consume family — concurrent migrations must be merged, and
--  the merged version lives HERE, applying last).
--
--  - kenos_lineages: captured at consumption (echo_id, momentum,
--    read_by). The source echo is destroyed the same instant; the
--    lineage is what makes rebounds honest and infalsifiable — the
--    server, not the client, decides the next momentum. One shot:
--    10 minutes to decide, then the lineage is swept.
--  - rebound_echo: guarded by that lineage + the shared 20 s launch
--    cadence (one echo at a time, whatever its origin).
--  - fetch_map_sector (v2): momentum travels with the metadata — the
--    map draws the comet tail.
--  - kenos_purge (v3): sweeps stale lineages too. Single source of
--    truth for every retention rule (extends 20260831120000).
-- ═══════════════════════════════════════════════════════════════════════

-- Lineage of a consumed echo: who read it, with what momentum, when.
-- No FK to echoes (the parent is destroyed at consumption by design).
create table public.kenos_lineages (
    echo_id     uuid primary key,
    momentum    integer not null check (momentum >= 0),
    color_theme varchar(20) not null default 'TEAL',
    read_by     uuid not null references auth.users (id) on delete cascade,
    consumed_at timestamptz not null default now()
);

create index idx_lineages_reader on public.kenos_lineages (read_by, consumed_at desc);

alter table public.kenos_lineages enable row level security;
revoke all on public.kenos_lineages from anon, authenticated;

-- Rebound momentum lives on the echo as public metadata.
alter table public.echoes
    add column if not exists parent_id uuid,
    add column if not exists momentum integer not null default 0;

-- ── consume_echo (v5): momentum + media, one source of truth ──────────
-- Merges the ether-seal v4 (momentum/lineage) with echo_media (media
-- path/kind for the Edge Function). Every later consumer edits HERE.
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

-- ── RPC: the rebound — a phoenix, sealed by the reader's device ────────
create function public.rebound_echo(
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

-- ── fetch_map_sector (v3): momentum rides with the metadata ────────────
-- Postgres refuses CREATE OR REPLACE with a changed return type: drop
-- and recreate (transactional — no window without the function).
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
    momentum    integer
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
    select s.id, s.coord_x, s.coord_y, s.coord_z, s.color_theme, s.created_at, s.momentum
    from (
        select e.id, e.coord_x, e.coord_y, e.coord_z, e.color_theme, e.created_at, e.momentum,
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

-- ── kenos_purge (v3): every retention rule, one place ──────────────────
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

    -- Lineages: the sling-shot window is 10 minutes — an hour is mercy.
    delete from public.kenos_lineages
    where consumed_at < now() - interval '1 hour';
end;
$$;

revoke all on function public.kenos_purge() from public, anon, authenticated;
