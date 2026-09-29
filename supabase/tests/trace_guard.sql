-- KENOS security tests — the Trace Guard (V3.88): the ether's only
-- gate. The burn RPC is service-role only; the webhook trigger never
-- breaks the trace flow it watches; the operator's shelf (kenos_config)
-- is invisible to every client role.
begin;
select plan(8);

create schema if not exists tests;
grant usage on schema tests to authenticated;

insert into auth.users (id, email, aud, role) values
  ('00000000-0000-4000-8000-0000000000d1', 'tg-author@test.kenos', 'authenticated', 'authenticated'),
  ('00000000-0000-4000-8000-0000000000d2', 'tg-reader@test.kenos', 'authenticated', 'authenticated');

-- Test-only helpers (security definer, postgres-owned), same shape as
-- the rpc.sql harness: each file's transaction rolls its own away.
create or replace function tests.echo_by_text(t text) returns uuid
language sql security definer set search_path = public as $$
  select id from public.echoes where encrypted_text = t limit 1
$$;

create or replace function tests.reception_for_reader(p_reader uuid) returns uuid
language sql security definer set search_path = public as $$
  select r.echo_id
  from public.kenos_receptions r
  join public.kenos_reads k on k.echo_id = r.echo_id and k.reader_id = p_reader
  limit 1
$$;
grant execute on all functions in schema tests to authenticated;

-- The full bottle cycle, in the rpc.sql harness's own steps: the
-- author launches, the reader consumes (creating the reception), the
-- reader leaves one trace.
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000d1","role":"authenticated"}', true);
select is(
  (select count(*) from public.launch_echo(
     'tg-guard-ciphertext', '', 0.4, 0.6, 1.0, 'TEAL') l),
  1::bigint,
  'the author launches the echo'
);

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000d2","role":"authenticated"}', true);
select is(
  (public.consume_echo(tests.echo_by_text('tg-guard-ciphertext'))->>'ciphertext'),
  'tg-guard-ciphertext',
  'the reader consumes it (reception born)'
);
-- 3 — the trigger is attached and the trace flow still holds.
select is(
  (select public.leave_trace(tests.reception_for_reader('00000000-0000-4000-8000-0000000000d2'), 'vu, courage.')),
  true,
  'leave_trace survives its own webhook trigger'
);

-- ── The gates ─────────────────────────────────────────────────────────
-- 4 — a client role cannot burn (the guard's hand is service-only).
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000d2","role":"authenticated"}', true);
select throws_ok(
  $$select public.admin_burn_reception(tests.reception_for_reader('00000000-0000-4000-8000-0000000000d2'))$$,
  '42501', 'permission denied for function admin_burn_reception',
  'no client role ever burns a trace'
);

-- 5 — the operator's shelf is invisible to every client role.
select throws_ok(
  $$select value from public.kenos_config where key = 'trace_guard_url'$$,
  '42501', 'permission denied for table kenos_config',
  'the guard URL is never client-readable'
);
reset role;
set local role anon;
select throws_ok(
  $$select value from public.kenos_config where key = 'trace_guard_token'$$,
  '42501', 'permission denied for table kenos_config',
  'the guard token is never anon-readable'
);
reset role;

-- ── The burn, in the service rank's own hand ─────────────────────────
-- 7 — the word leaves, the signal stays.
select is(
  public.admin_burn_reception(tests.reception_for_reader('00000000-0000-4000-8000-0000000000d2')),
  true,
  'the guard burns the reply_text'
);
select is(
  (select coalesce(r.reply_text, '<null>')
     from public.kenos_receptions r
    where r.echo_id = tests.reception_for_reader('00000000-0000-4000-8000-0000000000d2')),
  '<null>',
  'burned: the text is gone, the reception itself lives on'
);

select finish();
rollback;
