-- KENOS security tests — the second key (V3.53): a silent guest
-- condemned their seat; the SEEDED may now cut a new key while the
-- ring has received ZERO lines (nobody is replaced). One living key
-- at any instant — the old fingerprint dies in the same transaction.
-- The door keeps its silence: absent, not-yours and public rings all
-- answer KENOS_NOT_FOUND.
begin;
select plan(12);

create schema if not exists tests;
grant usage on schema tests to authenticated;

insert into auth.users (id, email, aud, role) values
  ('00000000-0000-4000-8000-0000000000f1', 'sr-f1@test.kenos', 'authenticated', 'authenticated'),
  ('00000000-0000-4000-8000-0000000000f2', 'sr-f2@test.kenos', 'authenticated', 'authenticated'),
  ('00000000-0000-4000-8000-0000000000f3', 'sr-f3@test.kenos', 'authenticated', 'authenticated'),
  ('00000000-0000-4000-8000-0000000000f4', 'sr-f4@test.kenos', 'authenticated', 'authenticated');

-- Scratch: the tokens the drops and cuts returned (the plaintext
-- crosses the wire exactly once — the test table stands for the
-- seeder's screen).
create table if not exists tests.salon_tokens (label text primary key, token text);
truncate tests.salon_tokens;
grant select, insert, update, truncate on table tests.salon_tokens to authenticated;

create or replace function tests.sr_id(py float8) returns uuid
language sql security definer set search_path = public as $$
  select id from public.kenos_constellations
   where seed_y = py order by created_at desc limit 1
$$;
create or replace function tests.sr_hash_is(py float8, p_token text) returns boolean
language sql security definer set search_path = public, extensions as $$
  select invite_token_hash = encode(digest(p_token, 'sha256'), 'hex')
    from public.kenos_constellations
   where seed_y = py order by created_at desc limit 1
$$;
create or replace function tests.sr_close(py float8) returns void
language sql security definer set search_path = public as $$
  update public.kenos_constellations
     set state = 'CLOSED', closed_at = now()
   where id = (select id from public.kenos_constellations
                where seed_y = py order by created_at desc limit 1)
$$;
grant execute on all functions in schema tests to authenticated;

-- ── Fixtures: f1's salon (0.51), f2's public ring (0.52), f3's
-- salon-to-close (0.53). One seeder per ring: the seed guard counts
-- every hand's drops, contributed or not. ────────────────────────────
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000f1","role":"authenticated"}', true);
insert into tests.salon_tokens (label, token)
select 's1-old', invite_token from public.seed_constellation(0.5, 0.51, 'POEM', true);

select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000f2","role":"authenticated"}', true);
select is(
  (select count(*) from public.seed_constellation(0.5, 0.52, 'POEM', false)),
  1::bigint,
  'fixture: a public ring exists'
);

select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000f3","role":"authenticated"}', true);
insert into tests.salon_tokens (label, token)
select 's2', invite_token from public.seed_constellation(0.5, 0.53, 'POEM', true);
reset role;
select tests.sr_close(0.53);

-- ── A. The seeder cuts a new key on an untouched door ─────────────────
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000f1","role":"authenticated"}', true);
-- The cut, stored the moment it crosses (the test table stands for
-- the seeder's screen) — exactly one living key from here on.
insert into tests.salon_tokens (label, token)
values ('s1-live', public.reseed_salon_key(tests.sr_id(0.51)));
select is(
  (select token ~ '^[0-9a-f]{32}$'
     from tests.salon_tokens where label = 's1-live'),
  true,
  'the seeder receives a new 16-byte hex key'
);
select throws_ok(
  $$select public.fetch_invited_constellation(
     (select token from tests.salon_tokens where label = 's1-old'))$$,
  'P0001', 'KENOS_INVITE_UNKNOWN',
  'the ORIGINAL drop key opens nothing anymore — it died with the first cut'
);
select is(
  (select count(*) from public.fetch_invited_constellation(
     (select token from tests.salon_tokens where label = 's1-live'))),
  1::bigint,
  'the LIVING key resolves the ring'
);
select is(
  tests.sr_hash_is(0.51, (select token from tests.salon_tokens where label = 's1-live')),
  true,
  'the base holds only the fingerprint of the living key'
);

-- ── B. The guards: silence, closed doors ─────────────────────────────
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000f2","role":"authenticated"}', true);
select throws_ok(
  $$select public.reseed_salon_key(tests.sr_id(0.51))$$,
  'P0001', 'KENOS_NOT_FOUND',
  'a stranger reseeds nothing — the door says nothing'
);
select throws_ok(
  $$select public.reseed_salon_key(tests.sr_id(0.52))$$,
  'P0001', 'KENOS_NOT_FOUND',
  'one''s own PUBLIC ring is no salon — same silence'
);
select throws_ok(
  $$select public.reseed_salon_key('11111111-2222-4333-8444-555555555555')$$,
  'P0001', 'KENOS_NOT_FOUND',
  'the void holds no such door'
);
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000f3","role":"authenticated"}', true);
select throws_ok(
  $$select public.reseed_salon_key(tests.sr_id(0.53))$$,
  'P0001', 'KENOS_CLOSED',
  'a closed salon keeps its last key forever'
);
reset role;
set local role anon;
select throws_ok(
  $$select public.reseed_salon_key('11111111-2222-4333-8444-555555555555')$$,
  '42501', 'permission denied for function reseed_salon_key',
  'anon cuts no key'
);
reset role;

-- ── C. One line and the door has been touched — forever ──────────────
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000f4","role":"authenticated"}', true);
select lives_ok(
  $$select public.contribute_line(
      tests.sr_id(0.51), 'la ligne qui verrouille', '',
      (select token from tests.salon_tokens where label = 's1-live'))$$,
  'a guest claims with the living key'
);
reset role;
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000f1","role":"authenticated"}', true);
select throws_ok(
  $$select public.reseed_salon_key(tests.sr_id(0.51))$$,
  'P0001', 'KENOS_LINES_EXIST',
  'one line and no key cut can replace anyone'
);

select * from finish();
rollback;
