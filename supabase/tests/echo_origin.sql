-- KENOS security tests — l'origine (V3.26): the shore's name rides
-- with the seal, and only the winner learns it. The map never
-- carries it; the label is the author's choice, bounded; old clients
-- (eight-argument calls) keep launching unnamed lights.
begin;
select plan(7);

create schema if not exists tests;
grant usage on schema tests to authenticated;

insert into auth.users (id, email, aud, role) values
  ('00000000-0000-4000-8000-0000000000d1', 'origin-d1@test.kenos', 'authenticated', 'authenticated'),
  ('00000000-0000-4000-8000-0000000000d2', 'origin-d2@test.kenos', 'authenticated', 'authenticated');

-- The ambiguity sentinel: exactly ONE launch_echo lives in the
-- schema (a second overload once made PostgREST refuse every call
-- that did not exactly match — PGRST202).
select is(
  (select count(*) from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
   where p.proname = 'launch_echo' and n.nspname = 'public'),
  1::bigint,
  'one launch_echo, never overloads'
);

-- Test-only hand: the echoes table is admin-only, the id lookup goes
-- through a definer — rpc.sql's grammar.
create or replace function tests.origin_echo_by_text(t text)
returns uuid
language sql security definer set search_path = public as $$
  select id from public.echoes where encrypted_text = t limit 1
$$;
grant execute on all functions in schema tests to authenticated;

-- d1 names the shore; d2 launches the old way (no origin argument).
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000d1","role":"authenticated"}', true);
select is(
  (select count(*) from public.launch_echo(
      'secret nommé', '', 0.4, 0.4, 0.9, 'TEAL', null, null,
      'FRANCE · AUVERGNE-RHÔNE-ALPES · LYON') l),
  1::bigint,
  'a named origin launches'
);
reset role;
-- The 20-second launch breath: the fixture bends, not the rule.
update public.echoes set created_at = now() - interval '30 seconds';
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000d1","role":"authenticated"}', true);
select is(
  (select count(*) from public.launch_echo('secret anonyme', '', 0.5, 0.5, 0.9, 'INDIGO') l),
  1::bigint,
  'the eight-argument call still works (deployed clients)'
);
select throws_ok(
  $$select * from public.launch_echo('trop long', '', 0.6, 0.6, 0.9, 'TEAL',
                                     null, null, rpad('x', 97, 'x'))$$,
  'P0001', 'KENOS_INVALID_LENGTH',
  'the shore''s name is bounded at 96 characters'
);

-- The map NEVER carries the origin (metadata only, by law).
reset role;
select is(
  (select count(*) from public.fetch_map_sector(0, 0, 1, 1, 24, 400) r
    where (r::text) like '%LYON%'),
  0::bigint,
  'fetch_map_sector never carries the origin'
);

-- d2 intercepts the named light: the winner alone learns the shore.
reset role;
update public.echoes set created_at = now() - interval '30 seconds';
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000d2","role":"authenticated"}', true);
select is(
  (select (public.consume_echo(tests.origin_echo_by_text('secret nommé'))
   ->> 'origin')),
  'FRANCE · AUVERGNE-RHÔNE-ALPES · LYON',
  'the consumption bundle carries the shore''s name'
);
reset role;
-- The 5-second read breath between the two interceptions.
update public.kenos_reads set read_at = now() - interval '10 seconds';
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000d2","role":"authenticated"}', true);
select is(
  (select coalesce(
      public.consume_echo(tests.origin_echo_by_text('secret anonyme'))
      ->> 'origin', '')),
  '',
  'an unnamed light stays unnamed — the key is absent, not invented'
);

select * from finish();
rollback;
