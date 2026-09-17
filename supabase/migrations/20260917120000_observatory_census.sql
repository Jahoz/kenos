-- ═══════════════════════════════════════════════════════════════════════
-- KENOS — migration : the Observatory census (V3.56)
--
-- The drift shows its ages and kinds. A new `census` section joins
-- the guardian's ledger: the three ages of the drifting echoes (the
-- sky fluid or congested?), their kinds (a media-less echo is a
-- text), their color themes. Three shapes over public.echoes — the
-- keys come from the fixed vocabularies, the values are counts, and
-- nothing else ever leaves the table.
--
--  admin_fetch_metrics: full re-declaration of the current live
--  version (artifact_reports, 20260916) with exactly one new jsonb
--  section. No table change, no new read path, no lifecycle touch —
--  the single-read core stays as it is.
--
--  What stays sacred: single-read atomicity, zero plaintext
--  server-side, zero content in metrics, RLS-everything.
-- ═══════════════════════════════════════════════════════════════════════

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
