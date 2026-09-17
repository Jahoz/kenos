-- KENOS security tests — the artifact guard (V3.51): a CLOSED
-- constellation is a PUBLIC artifact, readable for a moon — the only
-- user content the ether ever shows in clear to everyone. It can be
-- flagged (one report per hand, CLOSED only, ten a day) and the
-- guardian alone can retract it (never automatic, never a threshold —
-- mass-flagging censors nothing). The guardian's list is metadata
-- only: counts, reasons, ages, the seed coordinate for the sky link —
-- never a line, never a poet, never a reporter.
begin;
select plan(34);

create schema if not exists tests;
grant usage on schema tests to authenticated;

-- Fresh strangers (one file, one population).
insert into auth.users (id, email, aud, role) values
  ('00000000-0000-4000-8000-0000000000e1', 'ar-e1@test.kenos', 'authenticated', 'authenticated'),
  ('00000000-0000-4000-8000-0000000000e2', 'ar-e2@test.kenos', 'authenticated', 'authenticated'),
  ('00000000-0000-4000-8000-0000000000e3', 'ar-e3@test.kenos', 'authenticated', 'authenticated'),
  ('00000000-0000-4000-8000-0000000000e4', 'ar-e4@test.kenos', 'authenticated', 'authenticated'),
  ('00000000-0000-4000-8000-0000000000e5', 'ar-e5@test.kenos', 'authenticated', 'authenticated'),
  ('00000000-0000-4000-8000-0000000000e6', 'ar-e6@test.kenos', 'authenticated', 'authenticated'),
  ('00000000-0000-4000-8000-0000000000e9', 'ar-guardian@test.kenos', 'authenticated', 'authenticated');

-- Test-only hands: restricted tables belong to the ether, the probes
-- read through security-definer helpers (rpc.sql's grammar).
create or replace function tests.ar_id(py float8) returns uuid
language sql security definer set search_path = public as $$
  select id from public.kenos_constellations
   where seed_y = py order by created_at desc limit 1
$$;
create or replace function tests.ar_state(py float8) returns text
language sql security definer set search_path = public as $$
  select state from public.kenos_constellations
   where seed_y = py order by created_at desc limit 1
$$;
create or replace function tests.ar_exists(py float8) returns bigint
language sql security definer set search_path = public as $$
  select count(*) from public.kenos_constellations where seed_y = py
$$;
create or replace function tests.ar_report_rows(cid uuid) returns bigint
language sql security definer set search_path = public as $$
  select count(*) from public.kenos_constellation_reports
   where constellation_id = cid
$$;
create or replace function tests.ar_metric(k text) returns integer
language sql security definer set search_path = public as $$
  select coalesce(
    case k when 'reported' then corpses_reported
            when 'retracted' then corpses_retracted end,
    0)::int
  from public.kenos_metrics_daily where day = current_date
$$;
-- A storm of backdated reports on throwaway closed rings: the daily
-- cap must hold against a hand that never touched the RPC. The rings
-- are planted by the ETHER's hand (claims cleared, then restored —
-- the seed guard exempts claimless hands, the gardener's convention).
create or replace function tests.ar_flood(p_reporter uuid) returns integer
language plpgsql security definer set search_path = public as $$
declare
  i int;
  v_claims text := current_setting('request.jwt.claims', true);
begin
  perform set_config('request.jwt.claims', '', true);
  for i in 1..10 loop
    insert into public.kenos_constellations
      (seed_x, seed_y, target_lines, state, closed_at, kind)
    values (0.9, 0.90 + i * 0.001, 4, 'CLOSED', now(), 'POEM');
    insert into public.kenos_constellation_reports
      (constellation_id, reporter_id, reason_code, reported_at)
    select id, p_reporter, 'OTHER', now() - interval '1 hour'
      from public.kenos_constellations
     where seed_y = 0.90 + i * 0.001
     order by created_at desc limit 1;
  end loop;
  perform set_config('request.jwt.claims', v_claims, true);
  return 10;
end;
$$;
-- The whole file is ONE transaction: every default now() is the same
-- instant, and "latest_reported_at" would tie blindly. The fixture
-- orders time by hand, like the ether would have.
create or replace function tests.ar_backdate_mine(p_back text) returns void
language sql security definer set search_path = public as $$
  update public.kenos_constellation_reports
     set reported_at = now() - (p_back)::interval
   where reporter_id = auth.uid()
$$;
grant execute on all functions in schema tests to authenticated;

-- ── Fixture: one closed artifact (A), one open ring (B), one
-- moon-expired artifact (C) with a report riding it ────────────────────
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000e1","role":"authenticated"}', true);
select is(
  (select count(*) from public.seed_constellation(0.5::float8, 0.31::float8, 'POEM')),
  1::bigint,
  'fixture: the artifact ring is seeded'
);
reset role;
update public.kenos_constellations set target_lines = 4
 where id = tests.ar_id(0.31);

-- Four strangers, four lines: the ring closes itself.
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000e1","role":"authenticated"}', true);
select public.contribute_line(tests.ar_id(0.31), 'ligne un', '');
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000e2","role":"authenticated"}', true);
select public.contribute_line(tests.ar_id(0.31), 'ligne deux', '');
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000e3","role":"authenticated"}', true);
select public.contribute_line(tests.ar_id(0.31), 'ligne trois', '');
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000e4","role":"authenticated"}', true);
select public.contribute_line(tests.ar_id(0.31), 'ligne quatre', '');

select is(tests.ar_state(0.31), 'CLOSED', 'fixture: the ring closed itself');

-- B: a public ring that stays OPEN (nothing readable to judge).
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000e5","role":"authenticated"}', true);
select is(
  (select count(*) from public.seed_constellation(0.5::float8, 0.22::float8, 'POEM')),
  1::bigint,
  'fixture: an open ring is seeded'
);

-- C: a closed artifact aged past its moon, carrying one report — the
-- reaper's cascade has a witness. (A fresh hand seeds it: everyone
-- else wrote a line into A moments ago, and the seed guard counts
-- CONTRIBUTED rings too — 2 minutes between two rings.)
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000e6","role":"authenticated"}', true);
select is(
  (select count(*) from public.seed_constellation(0.5::float8, 0.41::float8, 'POEM')),
  1::bigint,
  'fixture: the aged ring is seeded'
);
reset role;
update public.kenos_constellations
   set state = 'CLOSED', closed_at = now() - interval '31 days'
 where id = tests.ar_id(0.41);
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000e3","role":"authenticated"}', true);
select is(
  public.report_constellation(tests.ar_id(0.41), 'SPAM'),
  true,
  'fixture: the aged artifact carries a report'
);
-- Aged by hand: the ledger's "latest" must not tie with today's.
select tests.ar_backdate_mine('2 hours');

-- ── A. The report path: one hand, one report, a reason ────────────────
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000e2","role":"authenticated"}', true);
select is(
  public.report_constellation(tests.ar_id(0.31), 'INAPPROPRIATE'),
  true,
  'a stranger flags a closed artifact'
);
select tests.ar_backdate_mine('1 hour');
select is(
  public.report_constellation(tests.ar_id(0.31), 'SPAM'),
  false,
  'the same hand never flags twice'
);
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000e3","role":"authenticated"}', true);
select is(
  public.report_constellation(tests.ar_id(0.31), 'DANGER'),
  true,
  'another hand, another reason — both live'
);
select is(tests.ar_report_rows(tests.ar_id(0.31)), 2::bigint,
  'two reports, two rows, no duplicates');
select is(tests.ar_metric('reported'), 3,
  'three reports counted, contentless, same transactions');

-- ── B. The guards: closed-only, known rings, honest reasons, a cap ────
select throws_ok(
  $$select public.report_constellation(tests.ar_id(0.31), 'MADE_UP')$$,
  'P0001', 'KENOS_INVALID_REPORT_REASON',
  'an unknown reason code is refused'
);
select throws_ok(
  $$select public.report_constellation(tests.ar_id(0.22), 'INAPPROPRIATE')$$,
  'P0001', 'KENOS_INVALID_STATE',
  'an open ring carries nothing readable — nothing to flag'
);
select throws_ok(
  $$select public.report_constellation('11111111-2222-4333-8444-555555555555', 'INAPPROPRIATE')$$,
  'P0001', 'KENOS_NOT_FOUND',
  'a gone artifact takes no report'
);
reset role;
set local role anon;
-- A literal id: the anon role cannot even resolve the tests helpers
-- (the denial under test is the FUNCTION grant, arguments irrelevant).
select throws_ok(
  $$select public.report_constellation('11111111-2222-4333-8444-555555555555', 'INAPPROPRIATE')$$,
  '42501', 'permission denied for function report_constellation',
  'anon cannot flag: the function is authenticated-only'
);
reset role;
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000e4","role":"authenticated"}', true);
select is(tests.ar_flood('00000000-0000-4000-8000-0000000000e4'), 10,
  'fixture: a hand storms ten backdated reports');
select throws_ok(
  $$select public.report_constellation(tests.ar_id(0.31), 'OTHER')$$,
  'P0001', 'KENOS_RATE_LIMIT',
  'ten flags a day per hand — the guardian list is not a billboard'
);

-- ── C. The guardian gate and the contentless list ─────────────────────
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000e2","role":"authenticated"}', true);
select throws_ok(
  $$select public.admin_list_constellation_reports()$$,
  '42501', 'KENOS_FORBIDDEN',
  'a stranger reads no report list'
);
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000e2","role":"authenticated","user_metadata":{"role":"admin"}}', true);
select throws_ok(
  $$select public.admin_list_constellation_reports()$$,
  '42501', 'KENOS_FORBIDDEN',
  'a forged user_metadata claim authorizes nothing'
);
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000e9","role":"authenticated","app_metadata":{"role":"admin"}}', true);
select is(
  jsonb_array_length(public.admin_list_constellation_reports()),
  12,
  'the guardian reads the list: the artifact, the aged ring, ten storms'
);
select is(
  (public.admin_list_constellation_reports() -> 0) ->> 'constellation_id',
  tests.ar_id(0.31)::text,
  'the most recently flagged artifact leads'
);
select is(
  (public.admin_list_constellation_reports() -> 0) ->> 'report_count',
  '2',
  'the count of hands is told, contentless'
);
select is(
  (public.admin_list_constellation_reports() -> 0) ->> 'latest_reason',
  'DANGER',
  'the latest reason is told — a code, never a text'
);
select is(
  ((public.admin_list_constellation_reports() -> 0) ?| array['text', 'curated_by', 'lines', 'reporter_id', 'encrypted_text']),
  false,
  'contentless, pinned: no text, no poet, no reporter identity'
);
select is(
  ((public.admin_list_constellation_reports() -> 0) ?| array['seed_x', 'seed_y', 'kind', 'is_curated', 'moon_days_left']),
  true,
  'the shapes are there: where it rests, what it is, the moon left'
);

-- ── D. The retraction: the guardian's one gesture ─────────────────────
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000e2","role":"authenticated"}', true);
select throws_ok(
  $$select public.admin_retract_constellation(tests.ar_id(0.31))$$,
  '42501', 'KENOS_FORBIDDEN',
  'a stranger retracts nothing'
);
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000e9","role":"authenticated","app_metadata":{"role":"admin"}}', true);
select throws_ok(
  $$select public.admin_retract_constellation('11111111-2222-4333-8444-555555555555')$$,
  'P0001', 'KENOS_NOT_FOUND',
  'the void refuses to retract what it never held'
);
select lives_ok(
  $$select public.admin_retract_constellation(tests.ar_id(0.31))$$,
  'the guardian sends the artifact back to the void'
);
select is(tests.ar_exists(0.31), 0::bigint,
  'the artifact is gone — like the purge would take it');
select is(tests.ar_report_rows(tests.ar_id(0.31)), 0::bigint,
  'its reports died with it (cascade)');
select is(
  (select count(*) from public.fetch_constellations(0::float8, 0::float8, 1::float8, 1::float8)
    where seed_y = 0.31),
  0::bigint,
  'the public sky no longer lists it'
);
select is(tests.ar_metric('retracted'), 1,
  'one retraction counted, contentless');
select lives_ok(
  $$select public.admin_retract_constellation(tests.ar_id(0.22))$$,
  'the guardian may also fell an open ring (the tool is general)'
);

-- ── E. The reaper's cascade: a moon-old report leaves with its ring ───
reset role;
select public.kenos_purge();
select is(tests.ar_exists(0.41), 0::bigint,
  'the 30-day reaper took the moon-old artifact');
select is(tests.ar_report_rows(tests.ar_id(0.41)), 0::bigint,
  'and its report left with it — no orphan ever waits');

select * from finish();
rollback;
