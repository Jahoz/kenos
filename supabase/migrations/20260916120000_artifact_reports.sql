-- ═══════════════════════════════════════════════════════════════════════
-- KENOS — migration : the artifact guard (V3.51)
--
-- The moderation hole, closed. Sealed content is structurally
-- invisible server-side (Ether Seal, forever) — but a CLOSED
-- constellation is a PUBLIC artifact, readable and re-readable by
-- everyone for a moon. Until now nothing could flag or remove one:
-- report_echo guards echoes only, and the sole deletes on
-- kenos_constellations were the reaper's age-based purge. A ring
-- closed on hateful or unlawful lines would have burned in public
-- for thirty days with no remedy but a panic SQL session.
--
--  1. kenos_constellation_reports: contentless reports (echo-report
--     grammar — one per hand, a reason code, never a text). The
--     reportable state is CLOSED ONLY: an open ring shows nothing
--     readable, there is nothing to judge.
--  2. report_constellation: authenticated strangers, capped at
--     10 reports/day/hand (the guardian's list is not a billboard).
--  3. admin_list_constellation_reports: pure metadata for the
--     guardian (counts, reasons, ages, kind, the seed coordinate for
--     the sky link, is_curated, the moon left) — NEVER a text, never
--     a poet's name, never an identifier. The Observatory stays
--     contentless by construction: the guardian reads the poem
--     itself in the public sky, where it lives.
--  4. admin_retract_constellation: the guardian's only moderation
--     gesture — the artifact returns to the void like the purge
--     would take it (lines and reports cascade). Never automatic:
--     no threshold, no brigading vector, a human decides.
--
--  What stays sacred: single-read atomicity, Ether Seal, RPC-only,
--  zero plaintext, the KENOS_* grammar, contentless metrics bumped
--  inside the same transactions.
-- ═══════════════════════════════════════════════════════════════════════

-- ── The report ledger: one row per hand per artifact, no content ──────
create table public.kenos_constellation_reports (
    constellation_id uuid not null
        references public.kenos_constellations (id) on delete cascade,
    reporter_id      uuid not null references auth.users (id) on delete cascade,
    reason_code      text not null
        check (reason_code in ('INAPPROPRIATE', 'SPAM', 'DANGER', 'OTHER')),
    reported_at      timestamptz not null default now(),
    primary key (constellation_id, reporter_id)
);

create index idx_constellation_reports_reported_at
    on public.kenos_constellation_reports (reported_at desc);

alter table public.kenos_constellation_reports enable row level security;
revoke all on public.kenos_constellation_reports from anon, authenticated;

-- ── Observatory: two more contentless counters ─────────────────────────
alter table public.kenos_metrics_daily
    add column if not exists corpses_reported integer not null default 0
        check (corpses_reported >= 0),
    add column if not exists corpses_retracted integer not null default 0
        check (corpses_retracted >= 0);

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
        'salon_seeded', 'corpse_reported', 'corpse_retracted'
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
        corpses_reported, corpses_retracted
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
        (p_kind = 'corpse_retracted')::int
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
        updated_at         = now();
end;
$$;

revoke all on function public.kenos_metrics_touch(text)
    from public, anon, authenticated;

-- ── RPC: a stranger flags a public artifact ────────────────────────────
-- The report is metadata, not testimony: a reason code, never a text.
-- The constellation must be CLOSED — an open ring carries nothing
-- readable, there is nothing to judge yet.
create or replace function public.report_constellation(
    p_constellation_id uuid,
    p_reason_code text
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
    c_state varchar;
begin
    if auth.uid() is null then
        raise exception 'KENOS_UNAUTHENTICATED';
    end if;
    if p_reason_code not in ('INAPPROPRIATE', 'SPAM', 'DANGER', 'OTHER') then
        raise exception 'KENOS_INVALID_REPORT_REASON';
    end if;

    select c.state into c_state
      from public.kenos_constellations c
     where c.id = p_constellation_id;
    if c_state is null then
        raise exception 'KENOS_NOT_FOUND';
    end if;
    if c_state <> 'CLOSED' then
        raise exception 'KENOS_INVALID_STATE';
    end if;

    -- The guardian's list is not a billboard either: ten flags a day
    -- per hand is a concerned sky, more is a storm.
    if (select count(*) from public.kenos_constellation_reports r
         where r.reporter_id = auth.uid()
           and r.reported_at > now() - interval '1 day') >= 10 then
        raise exception 'KENOS_RATE_LIMIT';
    end if;

    insert into public.kenos_constellation_reports (constellation_id, reporter_id, reason_code)
    values (p_constellation_id, auth.uid(), p_reason_code)
    on conflict (constellation_id, reporter_id) do nothing;

    if found then
        perform public.kenos_metrics_touch('corpse_reported');
    end if;

    return found;
end;
$$;

revoke all on function public.report_constellation(uuid, text)
    from public, anon;
grant execute on function public.report_constellation(uuid, text)
    to authenticated;

-- ── RPC: what the guardian sees — shapes, never texts ─────────────────
-- One row per REPORTED artifact: how many hands flagged it, why (the
-- latest reason), how old, what it is (kind, curated or strangers',
-- the moon it has left) and WHERE it rests (the seed coordinate —
-- public metadata the sky already renders for everyone — so the
-- guardian can open the poem itself, in public, and judge with their
-- own eyes). No line, no poet, no reporter identity ever crosses.
create or replace function public.admin_list_constellation_reports()
returns jsonb
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

    return coalesce(
        (
            select jsonb_agg(row_to_json(t) order by t.latest_reported_at desc)
              from (
                  select r.constellation_id,
                         count(*)::int as report_count,
                         (array_agg(r.reason_code order by r.reported_at desc))[1]
                             as latest_reason,
                         max(r.reported_at) as latest_reported_at,
                         c.kind,
                         (c.curated_by is not null) as is_curated,
                         c.seed_x,
                         c.seed_y,
                         c.closed_at,
                         greatest(
                             0,
                             ceil(extract(epoch from (c.closed_at + interval '30 days' - now())) / 86400)::int
                         ) as moon_days_left
                    from public.kenos_constellation_reports r
                    join public.kenos_constellations c
                      on c.id = r.constellation_id
                   group by r.constellation_id, c.kind, c.curated_by,
                            c.seed_x, c.seed_y, c.closed_at
              ) t
        ),
        '[]'::jsonb
    );
end;
$$;

revoke all on function public.admin_list_constellation_reports()
    from public, anon;
grant execute on function public.admin_list_constellation_reports()
    to authenticated;

-- ── RPC: the guardian's one gesture — back to the void ────────────────
-- The retraction is an honest death: the artifact, its lines and its
-- reports leave together (cascade), exactly as the 30-day reaper
-- would take a moon-old poem. Never automatic, never threshold-based:
-- mass-flagging cannot censor a sky, only a guardian decides. Works
-- on any state (an open ring may deserve death too) — but only the
-- guardian can pull it.
create or replace function public.admin_retract_constellation(
    p_constellation_id uuid
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

    delete from public.kenos_constellations c
     where c.id = p_constellation_id;

    if not found then
        raise exception 'KENOS_NOT_FOUND';
    end if;

    perform public.kenos_metrics_touch('corpse_retracted');
end;
$$;

revoke all on function public.admin_retract_constellation(uuid)
    from public, anon;
grant execute on function public.admin_retract_constellation(uuid)
    to authenticated;

-- ── admin_fetch_metrics: the new counters join the ledger ─────────────
-- Full re-declaration of the current live version (salon, 20260905)
-- with exactly the two new series columns and one new live count.
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
                 coalesce(m.salons_seeded, 0)      as salons_seeded,
                 coalesce(m.corpses_reported, 0)   as corpses_reported,
                 coalesce(m.corpses_retracted, 0)  as corpses_retracted
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
