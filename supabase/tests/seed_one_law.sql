-- KENOS security tests — ONE LAW PER DOOR (2026-09-27): V3.77
-- redeclared launch_echo and seed_constellation under signatures
-- nobody calls, leaving zombie overloads next to the living doors —
-- PostgREST ambiguity (PGRST203, the nightly smoke) on one side, a
-- widened storage law unreachable by the app on the other. The law is
-- one door each again, and both carry the field [-0.6, 1.6] the
-- storage already believed in. (echo_origin.sql keeps the
-- launch_echo ambiguity sentinel; here the widened law is proven on
-- both living doors.)
begin;
select plan(6);

create schema if not exists tests;
grant usage on schema tests to authenticated;

insert into auth.users (id, email, aud, role, created_at) values
  ('00000000-0000-4000-8000-0000000000c1', 'sl-c1@test.kenos', 'authenticated', 'authenticated', now()),
  ('00000000-0000-4000-8000-0000000000c2', 'sl-c2@test.kenos', 'authenticated', 'authenticated', now());

create table if not exists tests.sl_tokens (label text primary key, token text);
truncate tests.sl_tokens;
grant select, insert on table tests.sl_tokens to authenticated;

-- ── A. One seed law, never two ───────────────────────────────────────────
select is(
  (select count(*) from pg_proc p
     join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'seed_constellation'),
  1::bigint,
  'exactly one seed_constellation overload — the PostgREST ambiguity can never return silently'
);

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000c1","role":"authenticated"}', true);

-- ── B. The widened field reaches the living doors ────────────────────────
select throws_ok(
  $$select public.seed_constellation(1.7, 0.5, 'POEM', false)$$,
  'P0001', 'KENOS_INVALID_COORDS',
  'seed past the widened field is still refused — a farther wall'
);
select throws_ok(
  $$select id from public.launch_echo('au-delà-du-mur', '', 1.7, 0.5, 0.5, 'TEAL')$$,
  'P0001', 'KENOS_INVALID_COORDS',
  'launch past the widened field is still refused — a farther wall'
);
select lives_ok(
  $$select public.seed_constellation(1.45, -0.45, 'POEM', false)$$,
  'seeding beyond the old square works through the client''s own door'
);
select lives_ok(
  $$select id from public.launch_echo('scellé-beyond', '', 1.45, -0.45, 0.5, 'TEAL')$$,
  'launching beyond the old square works through the client''s own door'
);

-- ── C. The salon grammar survives the merge ──────────────────────────────
-- (a second body: the seed guard's cadence is one seed per stranger
-- per 2 minutes — the trigger counts every drop, the file runs in
-- one transaction)
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000c2","role":"authenticated"}', true);
insert into tests.sl_tokens (label, token)
select 'k1', invite_token from public.seed_constellation(0.55, 0.85, 'MELODY', true);
select is(
  (select token ~ '^[0-9a-f]{32}$' from tests.sl_tokens where label = 'k1'),
  true,
  'an invited seed still mints a one-shot 16-byte hex key'
);
reset role;

select * from finish();
rollback;
