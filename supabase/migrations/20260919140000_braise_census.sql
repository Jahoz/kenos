-- ═══════════════════════════════════════════════════════════════════════
-- KENOS — migration : the ember joins the guardian's ledger (V3.60c)
--
-- The census learns la Braise: one contentless counter per day
-- (`braises_passed`, bumped inside the claiming transaction — no new
-- read, the sacred atomicity is untouched) and one live count
-- (`braises_pending`, the links alive right now: fingerprints under
-- ten minutes old, a stock that can only be tiny or stale).
--
-- The guardian reads shapes and counts, never more: no uid, no link,
-- nothing that could tell one body from another.
-- ═══════════════════════════════════════════════════════════════════════

-- ── The ledger's column ────────────────────────────────────────────────
alter table public.kenos_metrics_daily
    add column if not exists braises_passed integer not null default 0
        check (braises_passed >= 0);

-- ── metrics_touch v-next: the ember's kind ─────────────────────────────
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
        'vestige_published', 'braise_passed'
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
        corpses_reported, corpses_retracted, vestiges_published,
        braises_passed
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
        (p_kind = 'vestige_published')::int,
        (p_kind = 'braise_passed')::int
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
        braises_passed     = m.braises_passed     + (p_kind = 'braise_passed')::int,
        updated_at         = now();
end;
$$;

revoke all on function public.kenos_metrics_touch(text)
    from public, anon, authenticated;

-- ── claim_passage v2: the ledger counts the hand-over ──────────────────
-- Same body, one counter more — bumped inside the very transaction
-- that remaps the identity (contentless, no new read).
create or replace function public.claim_passage(p_key text)
returns void
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
    uid    uuid := auth.uid();
    v_old  uuid;
    v_hash text;
begin
    if uid is null then
        raise exception 'KENOS_UNAUTHENTICATED';
    end if;
    if exists (select 1 from public.kenos_passed t where t.passed_uid = uid) then
        raise exception 'KENOS_BRAISE_PASSED';
    end if;
    if p_key is null or length(p_key) < 16 or length(p_key) > 128 then
        raise exception 'KENOS_PASSAGE_UNKNOWN';
    end if;

    v_hash := encode(digest(p_key, 'sha256'), 'hex');
    select p.old_uid
      into v_old
      from public.kenos_passages p
     where p.key_hash = v_hash
       and p.expires_at > now()
       for update skip locked;

    if v_old is null or v_old = uid then
        raise exception 'KENOS_PASSAGE_UNKNOWN';
    end if;

    -- The heart: unread bottles follow the living body (view = burn
    -- keeps holding — reply_seen flags travel with the rows).
    update public.kenos_receptions
       set author_id = uid
     where author_id = v_old;

    -- Drifted echoes follow too, so the newcomer's own sky still hides
    -- what this being launched ("the author never re-reads": their
    -- echoes stay excluded from their map, exactly as before).
    update public.echoes
       set author_id = uid
     where author_id = v_old;

    -- Rings the body seeded (without this, reseed_salon_key would
    -- refuse the newcomer on their own salon).
    update public.kenos_constellations
       set seeder_id = uid
     where seeder_id = v_old;

    -- Lines given, reports filed, journals kept — each guarded against
    -- the PK collisions: if the new body already touched the same
    -- ring/echo/report, that row stays with the old body.
    update public.kenos_constellation_lines l
       set contributor_id = uid
     where l.contributor_id = v_old
       and not exists (
           select 1 from public.kenos_constellation_lines n
            where n.constellation_id = l.constellation_id
              and n.contributor_id = uid
       );

    update public.kenos_echo_reports r
       set reporter_id = uid
     where r.reporter_id = v_old
       and not exists (
           select 1 from public.kenos_echo_reports n
            where n.echo_id = r.echo_id
              and n.reporter_id = uid
       );

    update public.kenos_constellation_reports r
       set reporter_id = uid
     where r.reporter_id = v_old
       and not exists (
           select 1 from public.kenos_constellation_reports n
            where n.constellation_id = r.constellation_id
              and n.reporter_id = uid
       );

    update public.kenos_constellation_reads q
       set reader_id = uid
     where q.reader_id = v_old
       and not exists (
           select 1 from public.kenos_constellation_reads n
            where n.constellation_id = q.constellation_id
              and n.reader_id = uid
       );

    update public.kenos_reads k
       set reader_id = uid
     where k.reader_id = v_old
       and not exists (
           select 1 from public.kenos_reads n
            where n.echo_id = k.echo_id
              and n.reader_id = uid
       );

    update public.kenos_lineages
       set read_by = uid
     where read_by = v_old;

    update public.kenos_frequencies
       set author_id = uid
     where author_id = v_old;

    -- Observatory: one hand-over counted, contentless, same
    -- transaction (V3.60c).
    perform public.kenos_metrics_touch('braise_passed');

    -- The old body is extinguished; the link is consumed — after this
    -- transaction even the fingerprint is gone.
    insert into public.kenos_passed (passed_uid, passed_at)
    values (v_old, now())
    on conflict (passed_uid) do nothing;

    delete from public.kenos_passages
     where key_hash = v_hash;
end;
$$;

revoke all on function public.claim_passage(text) from public, anon;
grant execute on function public.claim_passage(text) to authenticated;

-- ── admin_fetch_metrics v-next: the ember reaches the guardian ─────────
-- Full re-declaration of the CURRENT live version (the Sower session,
-- 20260917140000) with exactly one new series column and one new live
-- count. The census section survives untouched.
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
                 coalesce(m.vestiges_published, 0) as vestiges_published,
                 coalesce(m.braises_passed, 0)     as braises_passed
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
                  (select count(*) from public.kenos_constellation_reports),
              'braises_pending',
                  (select count(*) from public.kenos_passages)
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
