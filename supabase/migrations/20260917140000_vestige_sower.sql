-- ═══════════════════════════════════════════════════════════════════════
-- KENOS — migration : the Shard Sower module (V3.57, arbitré Hugo
-- 2026-09-17 : "le processus doit passer par l'Observatoire")
--
-- The vestige pipeline was a local toolchain: run the Dart sower
-- with a local AI key, read a staging markdown, hand-write SQL,
-- paste it through the operator console. The gate was human — the
-- road was a pilgrimage. The gate STAYS human; it becomes a screen.
--
--  1. kenos_vestige_proposals: verified shards awaiting the
--     guardian's taste. Publishing MOVES a proposal into the
--     library (its text is public culture — vestiges are served in
--     clear to everyone by design; the contentless law guards user
--     words, never the poets'). Discarding deletes. Nothing is
--     public until the guardian says so.
--  2. Five guardian RPCs: list proposals, sow proposals (called by
--     the Edge Function after its two AI passes — all authorization
--     and validation lives HERE, in tested SQL), decide (publish or
--     discard), read the library, retire/restore a shard.
--  3. The publish is counted (contentless, same transaction) — the
--     ledger will tell how the library grew.
-- ═══════════════════════════════════════════════════════════════════════

create table public.kenos_vestige_proposals (
    id         uuid primary key default gen_random_uuid(),
    kind       text not null check (kind in ('quote', 'etymology', 'haiku', 'history', 'fact')),
    text       text not null check (length(text) between 10 and 400),
    source     text not null default '',
    theme      text not null default 'ia',
    created_at timestamptz not null default now()
);

create index idx_vestige_proposals_created
    on public.kenos_vestige_proposals (created_at desc);

alter table public.kenos_vestige_proposals enable row level security;
revoke all on public.kenos_vestige_proposals from anon, authenticated;

-- ── Observatory: the library's growth joins the ledger ────────────────
alter table public.kenos_metrics_daily
    add column if not exists vestiges_published integer not null default 0
        check (vestiges_published >= 0);

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
        'salon_seeded', 'corpse_reported', 'corpse_retracted',
        'vestige_published'
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
        new_users, salons_seeded,
        corpses_reported, corpses_retracted, vestiges_published
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
        (p_kind = 'salon_seeded')::int,
        (p_kind = 'corpse_reported')::int,
        (p_kind = 'corpse_retracted')::int,
        (p_kind = 'vestige_published')::int
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
        corpses_reported   = m.corpses_reported   + (p_kind = 'corpse_reported')::int,
        corpses_retracted  = m.corpses_retracted  + (p_kind = 'corpse_retracted')::int,
        vestiges_published = m.vestiges_published + (p_kind = 'vestige_published')::int,
        updated_at         = now();
end;
$$;

revoke all on function public.kenos_metrics_touch(text)
    from public, anon, authenticated;

-- ── RPC 1: the proposals awaiting the guardian's taste ───────────────
-- plpgsql, not plain SQL: the guard needs RAISE (a plain-SQL body
-- could not refuse anyone — the pgTAP gate caught exactly that).
create or replace function public.admin_list_vestige_proposals()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
begin
    if auth.uid() is null then
        raise exception 'KENOS_UNAUTHENTICATED';
    end if;
    if not public.kenos_is_admin() then
        raise exception 'KENOS_FORBIDDEN' using errcode = '42501';
    end if;

    return coalesce(
        -- ISO timestamps sort as text exactly as they sort as dates.
        (select jsonb_agg(row_to_json(p) order by p.proposed_at desc)
           from (
                select id, kind, text, source, theme,
                       to_char(created_at, 'YYYY-MM-DD HH24:MI') as proposed_at
                  from public.kenos_vestige_proposals
                 order by created_at desc
                 limit 100
            ) p),
        '[]'::jsonb
    );
end;
$$;

-- ── RPC 2: the AI's harvest lands as proposals (Edge Function caller;
-- every guard lives here, in tested SQL — the function only carries) ───
create or replace function public.admin_sow_vestige_proposals(
    p_proposals jsonb,
    p_theme text default 'ia'
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
    item        jsonb;
    v_kind      text;
    v_text      text;
    v_source    text;
    v_norm      text;
    inserted    integer := 0;
begin
    if auth.uid() is null then
        raise exception 'KENOS_UNAUTHENTICATED';
    end if;
    if not public.kenos_is_admin() then
        raise exception 'KENOS_FORBIDDEN' using errcode = '42501';
    end if;
    if jsonb_typeof(p_proposals) <> 'array' then
        raise exception 'KENOS_INVALID_LENGTH';
    end if;
    if jsonb_array_length(p_proposals) > 30 then
        raise exception 'KENOS_INVALID_LENGTH';
    end if;

    for item in select * from jsonb_array_elements(p_proposals) loop
        v_kind   := item->>'kind';
        v_text   := btrim(coalesce(item->>'text', ''));
        v_source := coalesce(item->>'source', '');
        v_norm   := lower(regexp_replace(v_text, '[^a-zà-ÿ0-9]', '', 'g'));

        -- The sower's guards, in SQL: kind, measure, and no echo of
        -- what already lives (library or pending proposal).
        if v_kind not in ('quote', 'etymology', 'haiku', 'history', 'fact')
           or length(v_text) < 10 or length(v_text) > 400 then
            continue;
        end if;
        if exists (select 1 from public.kenos_vestiges v
                    where lower(regexp_replace(v.text, '[^a-zà-ÿ0-9]', '', 'g')) = v_norm)
           or exists (select 1 from public.kenos_vestige_proposals p
                    where lower(regexp_replace(p.text, '[^a-zà-ÿ0-9]', '', 'g')) = v_norm) then
            continue;
        end if;

        insert into public.kenos_vestige_proposals (kind, text, source, theme)
        values (v_kind, v_text, left(v_source, 120), left(coalesce(p_theme, 'ia'), 120));
        inserted := inserted + 1;
    end loop;

    return inserted;
end;
$$;

-- ── RPC 3: the human gate — publish into the library, or discard ─────
create or replace function public.admin_decide_vestige_proposal(
    p_proposal_id uuid,
    p_approve boolean
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
    p      public.kenos_vestige_proposals%rowtype;
    v_seed double precision;
begin
    if auth.uid() is null then
        raise exception 'KENOS_UNAUTHENTICATED';
    end if;
    if not public.kenos_is_admin() then
        raise exception 'KENOS_FORBIDDEN' using errcode = '42501';
    end if;

    select * into p from public.kenos_vestige_proposals
     where id = p_proposal_id;
    if p.id is null then
        raise exception 'KENOS_NOT_FOUND';
    end if;

    if p_approve then
        -- A resting place for the shard, deterministic from its own
        -- id: the golden spiral the local sower used, reborn in SQL.
        v_seed := (('x' || substr(p.id::text, 1, 8))::bit(32)::bigint % 2147483647)::double precision
                  / 2147483647;
        insert into public.kenos_vestiges (id, kind, text, source, pos_x, pos_y, locale)
        values (
            p.id::text,
            p.kind, p.text, p.source,
            (0.5 + 0.32 * cos(2.39996 * v_seed * 6.283185))::double precision,
            (0.5 + 0.32 * sin(2.39996 * v_seed * 6.283185))::double precision,
            'fr'
        );
        perform public.kenos_metrics_touch('vestige_published');
    end if;

    delete from public.kenos_vestige_proposals where id = p_proposal_id;
    return true;
end;
$$;

-- ── RPC 4: the library, read by its gardener ──────────────────────────
-- plpgsql for the same reason: the guard must RAISE.
create or replace function public.admin_fetch_vestiges(p_locale text default 'fr')
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
begin
    if auth.uid() is null then
        raise exception 'KENOS_UNAUTHENTICATED';
    end if;
    if not public.kenos_is_admin() then
        raise exception 'KENOS_FORBIDDEN' using errcode = '42501';
    end if;

    return coalesce(
        -- ISO dates sort as text exactly as they sort as dates.
        (select jsonb_agg(row_to_json(v) order by v.created_on desc)
           from (
                select id, kind, text, source, live,
                       to_char(created_at, 'YYYY-MM-DD') as created_on
                  from public.kenos_vestiges
                 where locale = coalesce(nullif(p_locale, ''), 'fr')
                 order by created_at desc
                 limit 200
            ) v),
        '[]'::jsonb
    );
end;
$$;

-- ── RPC 5: retire or restore — the curator's lever, one shard ─────────
create or replace function public.admin_set_vestige_live(
    p_id text,
    p_locale text default 'fr',
    p_live boolean default true
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
    if auth.uid() is null then
        raise exception 'KENOS_UNAUTHENTICATED';
    end if;
    if not public.kenos_is_admin() then
        raise exception 'KENOS_FORBIDDEN' using errcode = '42501';
    end if;

    update public.kenos_vestiges
       set live = p_live
     where id = p_id
       and locale = coalesce(nullif(p_locale, ''), 'fr');

    if not found then
        raise exception 'KENOS_NOT_FOUND';
    end if;
end;
$$;

revoke all on function public.admin_list_vestige_proposals()
    from public, anon;
revoke all on function public.admin_sow_vestige_proposals(jsonb, text)
    from public, anon;
revoke all on function public.admin_decide_vestige_proposal(uuid, boolean)
    from public, anon;
revoke all on function public.admin_fetch_vestiges(text)
    from public, anon;
revoke all on function public.admin_set_vestige_live(text, text, boolean)
    from public, anon;
grant execute on function public.admin_list_vestige_proposals()
    to authenticated;
grant execute on function public.admin_sow_vestige_proposals(jsonb, text)
    to authenticated;
grant execute on function public.admin_decide_vestige_proposal(uuid, boolean)
    to authenticated;
grant execute on function public.admin_fetch_vestiges(text)
    to authenticated;
grant execute on function public.admin_set_vestige_live(text, text, boolean)
    to authenticated;

-- ── admin_fetch_metrics: the pending count joins the live state ───────
-- Full re-declaration of the CURRENT live version (the census, V3.56
-- session of 2026-09-17 — sessions crossed, numbers collided) with
-- exactly one new series column and one new live count. The census
-- section survives untouched.
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
    v_census   jsonb;
begin
    if auth.uid() is null then
        raise exception 'KENOS_UNAUTHENTICATED';
    end if;
    if not public.kenos_is_admin() then
        raise exception 'KENOS_FORBIDDEN' using errcode = '42501';
    end if;

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
                 coalesce(m.salons_seeded, 0)      as salons_seeded,
                 coalesce(m.corpses_reported, 0)   as corpses_reported,
                 coalesce(m.corpses_retracted, 0)  as corpses_retracted,
                 coalesce(m.vestiges_published, 0) as vestiges_published
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
              'vestige_proposals_pending',
                  (select count(*) from public.kenos_vestige_proposals),
              'reports_open',
                  (select count(*) from public.kenos_echo_reports),
              'constellation_reports_open',
                  (select count(*) from public.kenos_constellation_reports)
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

    -- V3.56 — the census: the drift's ages, kinds and themes. Fixed
    -- vocabularies on the keys, counts on the values — a shape, as
    -- everywhere in this ledger.
    select jsonb_build_object(
              'echo_ages',
                  (select jsonb_build_object(
                           'fresh', count(*) filter (
                                       where e.created_at > now() - interval '1 day'),
                           'week', count(*) filter (
                                       where e.created_at <= now() - interval '1 day'
                                         and e.created_at > now() - interval '7 days'),
                           'ancient', count(*) filter (
                                       where e.created_at <= now() - interval '7 days')
                       )
                     from public.echoes e),
              'media_kinds',
                  (select coalesce(jsonb_object_agg(t.kind, t.n), '{}'::jsonb)
                     from (select coalesce(e.media_kind, 'TEXT') as kind,
                                  count(*) as n
                             from public.echoes e group by 1) t),
              'themes',
                  (select coalesce(jsonb_object_agg(t.theme, t.n), '{}'::jsonb)
                     from (select e.color_theme as theme, count(*) as n
                             from public.echoes e group by 1) t)
          )
      into v_census;

    return jsonb_build_object(
        'series', v_series,
        'live', v_live,
        'sectors', v_sectors,
        'derived', v_derived,
        'census', v_census
    );
end;
$$;

revoke all on function public.admin_fetch_metrics(integer)
    from public, anon;
grant execute on function public.admin_fetch_metrics(integer)
    to authenticated;
