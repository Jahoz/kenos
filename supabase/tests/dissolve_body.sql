-- KENOS security tests — THE BROOM (2026-09-27): the calling body
-- unmakes itself, nothing else. Fresh and empty bodies only — the
-- broom never burns content, and a body that lived keeps its place.
begin;
select plan(6);

create schema if not exists tests;
grant usage on schema tests to authenticated;

insert into auth.users (id, email, aud, role, created_at) values
  ('00000000-0000-4000-8000-0000000000d2', 'db-d2@test.kenos', 'authenticated', 'authenticated', now()),
  ('00000000-0000-4000-8000-0000000000d3', 'db-d3@test.kenos', 'authenticated', 'authenticated', now()),
  ('00000000-0000-4000-8000-0000000000d4', 'db-d4@test.kenos', 'authenticated', 'authenticated', now());

-- ── A. Anon never even reaches the broom ────────────────────────────────
set local role anon;
select throws_ok(
  $$select public.dissolve_body()$$,
  '42501', 'permission denied for function dissolve_body',
  'anon cannot dissolve — the broom is for the body itself, signed in'
);
reset role;

-- ── B. A fresh, empty body unmakes itself ───────────────────────────────
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000d2","role":"authenticated"}', true);
select lives_ok(
  $$select public.dissolve_body()$$,
  'the calling body dissolves itself'
);
reset role;
select is(
  (select count(*) from auth.users where id = '00000000-0000-4000-8000-0000000000d2'),
  0::bigint,
  'the dissolved body is gone from auth.users'
);

-- ── C. A body that lived keeps its place ────────────────────────────────
update auth.users set created_at = now() - interval '1 hour'
 where id = '00000000-0000-4000-8000-0000000000d3';
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000d3","role":"authenticated"}', true);
select throws_ok(
  $$select public.dissolve_body()$$,
  'P0001', 'KENOS_BODY_SETTLED',
  'a body older than the broom''s window is settled — it stays'
);
reset role;

-- ── D. A body that wrote is not empty ───────────────────────────────────
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000d4","role":"authenticated"}', true);
select lives_ok(
  $$select id from public.launch_echo('la-balançoire-du-broom', '', 0.5, 0.92, 0.5, 'INDIGO')$$,
  'fixture: the body wrote one echo'
);
select throws_ok(
  $$select public.dissolve_body()$$,
  'P0001', 'KENOS_BODY_NOT_EMPTY',
  'a body that wrote keeps its echo — the broom never burns content'
);
reset role;

select * from finish();
rollback;
