-- KENOS security tests — RPC invariants: atomic single read,
-- bottle-in-the-sea traces, rate limits, author isolation.
-- Every statement tries to break a promise; the schema must hold.
begin;
select plan(24);

-- Test-only helpers (security definer, postgres-owned) so restricted
-- roles can reference row ids without touching locked tables.
create schema if not exists tests;
grant usage on schema tests to authenticated;
create or replace function tests.echo_by_text(t text) returns uuid
language sql security definer set search_path = public as $$
  select id from public.echoes where encrypted_text = t limit 1
$$;
create or replace function tests.reception_echo_for(p_author uuid) returns uuid
language sql security definer set search_path = public as $$
  select echo_id from public.kenos_receptions where author_id = p_author limit 1
$$;

insert into auth.users (id, email, aud, role) values
  ('00000000-0000-4000-8000-0000000000a1', 'u1@test.kenos', 'authenticated', 'authenticated'),
  ('00000000-0000-4000-8000-0000000000a2', 'u2@test.kenos', 'authenticated', 'authenticated'),
  ('00000000-0000-4000-8000-0000000000a3', 'u3@test.kenos', 'authenticated', 'authenticated'),
  ('00000000-0000-4000-8000-0000000000a4', 'u4@test.kenos', 'authenticated', 'authenticated'),
  ('00000000-0000-4000-8000-0000000000a5', 'u5@test.kenos', 'authenticated', 'authenticated'),
  ('00000000-0000-4000-8000-0000000000a6', 'u6@test.kenos', 'authenticated', 'authenticated');

-- ── u1 launches one echo ───────────────────────────────────────────────
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000a1","role":"authenticated"}', true);

-- 1
select is(
  (select count(*) from public.launch_echo('premier secret', 0.4, 0.6, 1.0, 'TEAL') l),
  1::bigint,
  'launch_echo creates the echo'
);
-- 2 — friction: one echo per 20 s per author.
select throws_ok(
  $$select * from public.launch_echo('trop vite', 0.4, 0.6, 1.0, 'TEAL')$$,
  'P0001', 'KENOS_RATE_LIMIT',
  'launch rate limit enforces the 20 s breath'
);

-- ── u2: server-side validation, then a clean launch ────────────────────
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000a2","role":"authenticated"}', true);

-- 3
select throws_ok(
  $$select * from public.launch_echo(rpad('x', 281, 'x'), 0.5, 0.5, 0.9, 'INDIGO')$$,
  'P0001', 'KENOS_INVALID_LENGTH',
  '281-char echo rejected server-side'
);
-- 4
select throws_ok(
  $$select * from public.launch_echo('coords', 1.7, 0.5, 0.9, 'TEAL')$$,
  'P0001', 'KENOS_INVALID_COORDS',
  'out-of-bound coordinates rejected'
);
-- 5
select throws_ok(
  $$select * from public.launch_echo('theme', 0.5, 0.5, 0.9, 'ROSE')$$,
  'P0001', 'KENOS_INVALID_THEME',
  'ROSE theme rejected — destruction color never selectable'
);
-- 6
select is(
  (select count(*) from public.launch_echo('second secret', 0.5, 0.5, 0.9, 'INDIGO') l),
  1::bigint,
  'u2 launches cleanly'
);

-- ── u5: one cannot intercept one's own echo ────────────────────────────
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000a5","role":"authenticated"}', true);

select * from public.launch_echo('secret de u5', 0.1, 0.1, 0.5, 'LUMEN');
-- 7
select is(
  (select public.consume_echo(tests.echo_by_text('secret de u5'))),
  null::text,
  'own echo is shielded from its author'
);

-- ── u3 intercepts u1's echo: single read, atomically ───────────────────
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000a3","role":"authenticated"}', true);

-- 8
select is(
  (select public.consume_echo(tests.echo_by_text('premier secret'))),
  'premier secret',
  'the winner gets the text'
);

reset role;
-- 9
select is(
  (select count(*) from public.echoes where encrypted_text = 'premier secret'),
  0::bigint,
  'the read echo is destroyed — burn after reading'
);
-- 10
select is(
  (select count(*) from public.kenos_receptions),
  1::bigint,
  'contentless reception recorded for the author'
);
-- 11
select is(
  (select r.drift_seconds >= 0 from public.kenos_receptions r limit 1),
  true,
  'reception carries the real drift'
);

-- ── u4 arrives late: nothing left, then the 5 s breath ─────────────────
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000a4","role":"authenticated"}', true);

-- 12
select is(
  (select public.consume_echo(tests.echo_by_text('premier secret'))),
  null::text,
  'a later reader finds nothing — single read is absolute'
);

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000a3","role":"authenticated"}', true);
-- 13
select throws_ok(
  $$select public.consume_echo(tests.echo_by_text('secret de u5'))$$,
  'P0001', 'KENOS_RATE_LIMIT',
  'interception rate limit: breathe between two reads'
);

-- ── u4 reads the second echo ───────────────────────────────────────────
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000a4","role":"authenticated"}', true);
-- 14
select is(
  (select public.consume_echo(tests.echo_by_text('second secret'))),
  'second secret',
  'u4 gets the second echo'
);

-- ── Traces: one line, one shot, reader-only ────────────────────────────
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000a3","role":"authenticated"}', true);
-- 15
select is(
  (select public.leave_trace(tests.reception_echo_for('00000000-0000-4000-8000-0000000000a1'), 'Je te vois.')),
  true,
  'the reader leaves one trace'
);
-- 16
select is(
  (select public.leave_trace(tests.reception_echo_for('00000000-0000-4000-8000-0000000000a1'), 'remplacement')),
  false,
  'a trace can never be edited or replaced'
);

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000a5","role":"authenticated"}', true);
-- 17
select throws_ok(
  $$select public.leave_trace(tests.reception_echo_for('00000000-0000-4000-8000-0000000000a1'), 'vol')$$,
  'P0001', 'KENOS_RATE_LIMIT',
  'only the reader can leave the trace'
);

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000a4","role":"authenticated"}', true);
-- 18
select throws_ok(
  $$select public.leave_trace(tests.reception_echo_for('00000000-0000-4000-8000-0000000000a2'), rpad('x', 141, 'x'))$$,
  'P0001', 'KENOS_INVALID_LENGTH',
  'trace length enforced server-side'
);
-- 19
select is(
  (select public.leave_trace(tests.reception_echo_for('00000000-0000-4000-8000-0000000000a2'), 'Lu. Merci.')),
  true,
  'u4 traces the second echo'
);

-- ── Author isolation: view once, burn, nobody else ─────────────────────
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000a1","role":"authenticated"}', true);
-- 20
select is(
  (select count(*) from public.fetch_receptions()),
  1::bigint,
  'u1 sees exactly their own reception'
);
-- 21
select is(
  (select reply_text from public.fetch_receptions()),
  'Je te vois.',
  'the trace reached the author'
);
select public.burn_reception(tests.reception_echo_for('00000000-0000-4000-8000-0000000000a1'));
-- 22
select is(
  (select count(*) from public.fetch_receptions()),
  0::bigint,
  'viewing burned the signal — it never returns'
);

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000a6","role":"authenticated"}', true);
-- 23
select is(
  (select count(*) from public.fetch_receptions()),
  0::bigint,
  'an intruder sees no receptions at all'
);
select public.burn_reception(tests.reception_echo_for('00000000-0000-4000-8000-0000000000a2'));

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000a2","role":"authenticated"}', true);
-- 24
select is(
  (select count(*) from public.fetch_receptions()),
  1::bigint,
  'a non-author burn is a silent no-op'
);

select * from finish();
rollback;
