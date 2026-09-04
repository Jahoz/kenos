-- KENOS security tests — the seed guard (V3.20): the sky is not a
-- billboard. The old cadence inside seed_constellation counted only
-- rings the caller WROTE in — a script that only seeded escaped it.
-- The BEFORE INSERT trigger must hold against rapid reseeds and ring
-- flooding, exempt the ether's claimless hands, never leak the
-- seeder, and let a closed ring free its slot.
--
-- Reads go through security-definer helpers: the constellations
-- table is admin-only, exactly like rpc.sql's helpers.
begin;
select plan(15);

-- The tests schema is created per-file: rpc.sql's own copy rolls
-- back with its transaction.
create schema if not exists tests;
grant usage on schema tests to authenticated;

-- Fresh strangers (the rpc.sql users are busy elsewhere).
insert into auth.users (id, email, aud, role) values
  ('00000000-0000-4000-8000-0000000000b1', 'seed-b1@test.kenos', 'authenticated', 'authenticated'),
  ('00000000-0000-4000-8000-0000000000b2', 'seed-b2@test.kenos', 'authenticated', 'authenticated');

-- Test-only hands: time, state and table reads belong to the ether,
-- not to a stranger — security-definer helpers, rpc.sql's grammar.
create or replace function tests.my_seed_count()
returns bigint
language sql security definer set search_path = public as $$
  select count(*) from public.kenos_constellations
   where seeder_id = auth.uid()
$$;
create or replace function tests.my_open_ring_count()
returns bigint
language sql security definer set search_path = public as $$
  select count(*) from public.kenos_constellations
   where seeder_id = auth.uid() and state = 'OPEN'
$$;
create or replace function tests.backdate_my_seeds(p_back text)
returns void
language sql security definer set search_path = public as $$
  update public.kenos_constellations
     set created_at = now() - (p_back)::interval
   where seeder_id = auth.uid()
$$;
create or replace function tests.close_my_newest_seed()
returns void
language sql security definer set search_path = public as $$
  update public.kenos_constellations
     set state = 'CLOSED', closed_at = now()
   where id = (
     select id from public.kenos_constellations
      where seeder_id = auth.uid()
      order by created_at desc limit 1
   )
$$;
grant execute on all functions in schema tests to authenticated;

-- ── A. The hole, closed: seeding alone is now rate-limited ─────────────
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000b1","role":"authenticated"}', true);

select lives_ok(
  $$select * from public.seed_constellation(0.20, 0.20)$$,
  'the first seed lands'
);
select is(
  tests.my_seed_count(),
  1::bigint,
  'the trigger stamped the seeder — stamped rings are the only counted ones'
);

-- THE REGRESSION: a second seed, with no line ever written, must now
-- be refused. (The old check only counted rings the caller
-- contributed to — this exact call used to pass.)
select throws_ok(
  $$select * from public.seed_constellation(0.21, 0.21)$$,
  'P0001', 'KENOS_RATE_LIMIT',
  'seed-only spam is rate-limited (the launch hole, closed)'
);

select tests.backdate_my_seeds('3 minutes');
select lives_ok(
  $$select * from public.seed_constellation(0.22, 0.22)$$,
  'the cadence frees after the 2-minute breath'
);

-- ── B. The cap: five open rings per hand, no more ──────────────────────
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000b2","role":"authenticated"}', true);

select tests.backdate_my_seeds('3 minutes');
select lives_ok($$select * from public.seed_constellation(0.30, 0.30)$$, 'b2 holds ring 1');
select tests.backdate_my_seeds('3 minutes');
select lives_ok($$select * from public.seed_constellation(0.31, 0.31)$$, 'b2 holds ring 2');
select tests.backdate_my_seeds('3 minutes');
select lives_ok($$select * from public.seed_constellation(0.32, 0.32)$$, 'b2 holds ring 3');
select tests.backdate_my_seeds('3 minutes');
select lives_ok($$select * from public.seed_constellation(0.33, 0.33)$$, 'b2 holds ring 4');
select tests.backdate_my_seeds('3 minutes');
select lives_ok($$select * from public.seed_constellation(0.34, 0.34)$$, 'b2 holds ring 5');

select is(
  tests.my_open_ring_count(),
  5::bigint,
  'five open rings held by one hand — the cap is full'
);

select tests.backdate_my_seeds('3 minutes');
select throws_ok(
  $$select * from public.seed_constellation(0.35, 0.35)$$,
  'P0001', 'KENOS_SEED_CAP',
  'the sixth open ring is refused — the sky shares its space'
);

select tests.close_my_newest_seed();
select tests.backdate_my_seeds('3 minutes');
select lives_ok(
  $$select * from public.seed_constellation(0.36, 0.36)$$,
  'a closed ring frees its slot — endings make room'
);

-- ── C. The ether's own hands are exempt, and never leak ────────────────
-- No JWT (claims cleared, role reset): the gardener's cron path.
reset role;
select set_config('request.jwt.claims', '', true);
select lives_ok(
  $$insert into public.kenos_constellations (seed_x, seed_y, target_lines, kind)
      values (0.90, 0.90, 5, 'POEM')$$,
  'the gardener sows claimless (exempt)'
);
select is(
  (select seeder_id from public.kenos_constellations
    where seed_x = 0.90 and seed_y = 0.90),
  null::uuid,
  'ether-sown rings are mothered by no one'
);

-- The seeder never crosses the wire (postgres may call the RPC).
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000b1","role":"authenticated"}', true);
select is(
  (select count(*) from public.fetch_constellations(0, 0, 1, 1) r
    where (r::text) like '%seeder_id%'
       or (r::text) like '%00000000-0000-4000-8000-0000000000b1'),
  0::bigint,
  'fetch_constellations never carries the seeder'
);

select * from finish();
rollback;
