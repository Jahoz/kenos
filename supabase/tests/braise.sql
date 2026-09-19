-- KENOS security tests — LA BRAISE (V3.60): the anonymous passage.
-- One link, one life: forged on the old body, opened on the new
-- one, then even the fingerprint is gone. The claim IS the remap —
-- bottles, rings, given lines follow the living body; collisions keep
-- the row with the old body (one stranger, one line, nothing throws).
-- The ember keeps its silence: missing, wrong, short, expired and
-- self-addressed keys all answer KENOS_PASSAGE_UNKNOWN.
begin;
select plan(22);

create schema if not exists tests;
grant usage on schema tests to authenticated;

insert into auth.users (id, email, aud, role) values
  ('00000000-0000-4000-8000-0000000000b1', 'br-b1@test.kenos', 'authenticated', 'authenticated'),
  ('00000000-0000-4000-8000-0000000000b2', 'br-b2@test.kenos', 'authenticated', 'authenticated'),
  ('00000000-0000-4000-8000-0000000000b3', 'br-b3@test.kenos', 'authenticated', 'authenticated');

-- Scratch: the ember the forge returned (it crosses the wire exactly
-- once — the test table stands for the traveller's link), and the two
-- drifting echoes the old body launched.
create table if not exists tests.braise_keys (label text primary key, token text);
truncate tests.braise_keys;
create table if not exists tests.braise_echoes (label text primary key, echo_id uuid);
truncate tests.braise_echoes;
grant select, insert, update, truncate on table tests.braise_keys to authenticated;
grant select, insert, update, truncate on table tests.braise_echoes to authenticated;

create or replace function tests.br_ring_id(py float8) returns uuid
language sql security definer set search_path = public as $$
  select id from public.kenos_constellations
   where seed_y = py order by created_at desc limit 1
$$;
create or replace function tests.br_hash_is(p_key text) returns boolean
language sql security definer set search_path = public, extensions as $$
  select exists (
    select 1 from public.kenos_passages
     where key_hash = encode(digest(p_key, 'sha256'), 'hex')
  )
$$;
create or replace function tests.br_seeder_is(py float8) returns uuid
language sql security definer set search_path = public as $$
  select seeder_id from public.kenos_constellations
   where seed_y = py order by created_at desc limit 1
$$;
create or replace function tests.br_contributor_lines(py float8, p_uid uuid) returns bigint
language sql security definer set search_path = public as $$
  select count(*) from public.kenos_constellation_lines
   where constellation_id = (select tests.br_ring_id(py))
     and contributor_id = p_uid
$$;
create or replace function tests.br_echo_alive(p_echo uuid) returns boolean
language sql security definer set search_path = public as $$
  select exists (select 1 from public.echoes where id = p_echo)
$$;
create or replace function tests.br_passage_count() returns bigint
language sql security definer set search_path = public as $$
  select count(*) from public.kenos_passages
$$;
-- The launch cadence is 20 s per body; the old body must launch twice
-- in one fixture — the first echo ages a quiet quarter-minute.
create or replace function tests.br_age_fix() returns void
language plpgsql security definer set search_path = public as $$
begin
  update public.echoes
     set created_at = now() - interval '25 seconds'
   where id = (select echo_id from tests.braise_echoes where label = 'e1');
end;
$$;
grant execute on all functions in schema tests to authenticated;

-- ── Fixtures ───────────────────────────────────────────────────────────
-- b1 (the old body): two drifting echoes, one seeded ring (0.62), one
-- line given on b2's ring (0.64), one line on b3's ring (0.63). b3:
-- seeded ring 0.63, read echo-two and left a trace in the bottle.
-- b2 (the new body): seeded ring 0.64 (one seed per hand — the guard
-- counts every drop), one line on 0.63 — the future collision.
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000b1","role":"authenticated"}', true);
insert into tests.braise_echoes (label, echo_id)
select 'e1', id from public.launch_echo('scellé-un', '', 0.5, 0.61, 0.5, 'TEAL');
select tests.br_age_fix();
insert into tests.braise_echoes (label, echo_id)
select 'e2', id from public.launch_echo('scellé-deux', '', 0.5, 0.65, 0.5, 'INDIGO');
insert into tests.braise_keys (label, token) values ('k1', public.forge_passage());
select public.seed_constellation(0.5, 0.62, 'POEM', false);

select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000b3","role":"authenticated"}', true);
select public.seed_constellation(0.5, 0.63, 'POEM', false);
select public.consume_echo((select echo_id from tests.braise_echoes where label = 'e2'));
select public.leave_trace((select echo_id from tests.braise_echoes where label = 'e2'), 'merci');

select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000b2","role":"authenticated"}', true);
select public.seed_constellation(0.5, 0.64, 'POEM', false);
select public.contribute_line(tests.br_ring_id(0.63), 'la ligne de collision', '');

select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000b1","role":"authenticated"}', true);
select public.contribute_line(tests.br_ring_id(0.64), 'la ligne isolee de b1', '');
select public.contribute_line(tests.br_ring_id(0.63), 'la ligne qui restera', '');
reset role;

-- ── A. The forge ───────────────────────────────────────────────────────
select is(
  (select token ~ '^[0-9a-f]{32}$' from tests.braise_keys where label = 'k1'),
  true,
  'the old body receives a 16-byte hex ember'
);
select columns_are(
  'public', 'kenos_passages',
  array['key_hash', 'old_uid', 'forged_at', 'expires_at'],
  'the table holds no key — only what dies in ten minutes'
);
select is(
  tests.br_hash_is((select token from tests.braise_keys where label = 'k1')),
  true,
  'the base holds only the sha256 fingerprint of the ember'
);

-- ── B. The silence before the claim ────────────────────────────────────
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000b1","role":"authenticated"}', true);
select throws_ok(
  $$select public.claim_passage((select token from tests.braise_keys where label = 'k1'))$$,
  'P0001', 'KENOS_PASSAGE_UNKNOWN',
  'a body cannot pass the ember to itself — same silence as a dead link'
);
reset role;

-- ── C. The claim IS the remap ──────────────────────────────────────────
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000b2","role":"authenticated"}', true);
select lives_ok(
  $$select public.claim_passage((select token from tests.braise_keys where label = 'k1'))$$,
  'the new body claims the ember'
);
select is(
  (select count(*) from public.fetch_receptions()),
  1::bigint,
  'the unread bottle follows the living body (the Aube still speaks)'
);
select is(
  tests.br_seeder_is(0.62)::text,
  '00000000-0000-4000-8000-0000000000b2',
  'the ring the old body seeded recognizes the new seeder'
);
select is(
  tests.br_contributor_lines(0.63, '00000000-0000-4000-8000-0000000000b1'::uuid),
  1::bigint,
  'collision: the line stays with the old body — one stranger, one line'
);
select is(
  tests.br_contributor_lines(0.64, '00000000-0000-4000-8000-0000000000b2'::uuid),
  1::bigint,
  'the uncontested line migrates to the new body'
);
select is(
  public.consume_echo((select echo_id from tests.braise_echoes where label = 'e1')) is null,
  true,
  'the author never re-reads: the new body is shielded from what the old one launched'
);
select is(
  tests.br_echo_alive((select echo_id from tests.braise_echoes where label = 'e1')),
  true,
  'the shielded echo keeps drifting, untouched'
);
select throws_ok(
  $$select public.claim_passage((select token from tests.braise_keys where label = 'k1'))$$,
  'P0001', 'KENOS_PASSAGE_UNKNOWN',
  'the ember dies at the claim — no replay, the fingerprint is gone'
);
reset role;
-- V3.60c — the guardian's ledger counted the hand-over, contentless,
-- inside the same transaction (exactly one claim succeeded above).
-- Read as the owner: the ledger itself is locked to RPCs.
select is(
  (select braises_passed from public.kenos_metrics_daily
    where day = current_date),
  1,
  'the census counts one passed ember — a shape, never a body'
);

-- ── D. The ember says nothing ──────────────────────────────────────────
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000b3","role":"authenticated"}', true);
select throws_ok(
  $$select public.claim_passage('deadbeefdeadbeefdeadbeefdeadbeef')$$,
  'P0001', 'KENOS_PASSAGE_UNKNOWN',
  'a key nobody forged answers like a consumed one'
);
select throws_ok(
  $$select public.claim_passage('ab')$$,
  'P0001', 'KENOS_PASSAGE_UNKNOWN',
  'a too-short key answers the same — absent and fake look alike'
);
reset role;

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000b3","role":"authenticated"}', true);
insert into tests.braise_keys (label, token) values ('k3', public.forge_passage());
reset role;
update public.kenos_passages
   set expires_at = now() - interval '1 second'
 where key_hash = encode(digest((select token from tests.braise_keys where label = 'k3'), 'sha256'), 'hex');
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000b2","role":"authenticated"}', true);
select throws_ok(
  $$select public.claim_passage((select token from tests.braise_keys where label = 'k3'))$$,
  'P0001', 'KENOS_PASSAGE_UNKNOWN',
  'an ember older than ten minutes is ash'
);
reset role;

-- ── E. One live body ───────────────────────────────────────────────────
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000b1","role":"authenticated"}', true);
select throws_ok(
  $$select public.forge_passage()$$,
  'P0001', 'KENOS_BRAISE_PASSED',
  'an extinguished body forges no new ember'
);
select throws_ok(
  $$select id from public.launch_echo('plus rien', '', 0.5, 0.66, 0.5, 'LUMEN')$$,
  'P0001', 'KENOS_BRAISE_PASSED',
  'an extinguished body creates no new addressing'
);
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000b2","role":"authenticated"}', true);
select lives_ok(
  $$select id from public.launch_echo('la braise vit', '', 0.5, 0.67, 0.5, 'TEAL')$$,
  'the living body launches on'
);
reset role;

-- ── F. The lockdown ────────────────────────────────────────────────────
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000b3","role":"authenticated"}', true);
select throws_ok(
  $$select count(*) from public.kenos_passages$$,
  '42501', 'permission denied for table kenos_passages',
  'authenticated reads no passage — RPC only'
);
select throws_ok(
  $$select count(*) from public.kenos_passed$$,
  '42501', 'permission denied for table kenos_passed',
  'authenticated reads no tombstone — RPC only'
);
reset role;

-- ── G. The reaper sweeps the ash ───────────────────────────────────────
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000b3","role":"authenticated"}', true);
insert into tests.braise_keys (label, token) values ('k4', public.forge_passage());
reset role;
update public.kenos_passages
   set expires_at = now() - interval '1 second'
 where key_hash = encode(digest((select token from tests.braise_keys where label = 'k4'), 'sha256'), 'hex');
select public.kenos_purge();
select is(
  tests.br_passage_count(),
  0::bigint,
  'the reaper sweeps every expired fingerprint'
);

select * from finish();
rollback;
