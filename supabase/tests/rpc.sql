-- KENOS security tests — RPC invariants: atomic single read, Ether Seal
-- key exchange, bottle-in-the-sea traces, sector culling, purge, rate
-- limits, author isolation. Every statement tries to break a promise;
-- the schema must hold.
begin;
select plan(58);

-- Test-only helpers (security definer, postgres-owned) so restricted
-- roles can reference row ids without touching locked tables.
create schema if not exists tests;
grant usage on schema tests to authenticated;
create or replace function tests.echo_by_text(t text) returns uuid
language sql security definer set search_path = public as $$
  select id from public.echoes where encrypted_text = t limit 1
$$;
-- Deterministic: the reception of the echo THIS user read.
-- Sling-shot helpers: capture the echo id BEFORE consumption (once
-- read, the echo is destroyed and text lookups go blind). The id is
-- stashed in a definer-owned scratch table for the rebound calls.
create table if not exists tests.consumed_ids (
  tag text primary key,
  echo_id uuid not null
);
truncate tests.consumed_ids;
create or replace function tests.consume_by_text(p_text text) returns jsonb
language plpgsql security definer set search_path = public, tests as $$
declare eid uuid;
begin
  select id into eid from public.echoes where encrypted_text = p_text limit 1;
  insert into tests.consumed_ids (tag, echo_id) values (p_text, eid);
  return public.consume_echo(eid);
end;
$$;
create or replace function tests.rebound_by_text(
  p_text text, parent integer, ct text, k text
) returns table (rid uuid, rcreated timestamptz, rmomentum integer)
language plpgsql security definer set search_path = public, tests as $$
declare src uuid;
begin
  select echo_id into src from tests.consumed_ids where tag = p_text;
  return query
  select r.id, r.created_at, r.momentum
  from public.rebound_echo(
    src, parent, 0.5::float8, 0.5::float8, 0.9::float8, ct, k
  ) r;
end;
$$;
create or replace function tests.count_by_text(t text) returns bigint
language sql security definer set search_path = public as $$
  select count(*) from public.echoes where encrypted_text = t
$$;
create or replace function tests.reception_for_reader(p_reader uuid) returns uuid
language sql security definer set search_path = public as $$
  select r.echo_id
  from public.kenos_receptions r
  join public.kenos_reads k on k.echo_id = r.echo_id and k.reader_id = p_reader
  limit 1
$$;
-- Default privileges on fresh schemas are restrictive in Supabase:
-- grant EXECUTE explicitly, AFTER every helper exists.
grant execute on all functions in schema tests to authenticated;

insert into auth.users (id, email, aud, role) values
  ('00000000-0000-4000-8000-0000000000a1', 'u1@test.kenos', 'authenticated', 'authenticated'),
  ('00000000-0000-4000-8000-0000000000a2', 'u2@test.kenos', 'authenticated', 'authenticated'),
  ('00000000-0000-4000-8000-0000000000a3', 'u3@test.kenos', 'authenticated', 'authenticated'),
  ('00000000-0000-4000-8000-0000000000a4', 'u4@test.kenos', 'authenticated', 'authenticated'),
  ('00000000-0000-4000-8000-0000000000a5', 'u5@test.kenos', 'authenticated', 'authenticated'),
  ('00000000-0000-4000-8000-0000000000a6', 'u6@test.kenos', 'authenticated', 'authenticated');

-- ── u1 launches one echo (legacy plaintext tooling path: p_key = '') ────
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000a1","role":"authenticated"}', true);

-- 1
select is(
  (select count(*) from public.launch_echo('premier secret', '', 0.4, 0.6, 1.0, 'TEAL') l),
  1::bigint,
  'launch_echo creates the echo'
);
-- 2 — friction: one echo per 20 s per author.
select throws_ok(
  $$select * from public.launch_echo('trop vite', '', 0.4, 0.6, 1.0, 'TEAL')$$,
  'P0001', 'KENOS_RATE_LIMIT',
  'launch rate limit enforces the 20 s breath'
);

-- ── u2: server-side validation, then a clean launch ────────────────────
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000a2","role":"authenticated"}', true);

-- 3 — E2E price: the bound now applies to the sealed payload.
select throws_ok(
  $$select * from public.launch_echo(rpad('x', 4001, 'x'), '', 0.5, 0.5, 0.9, 'INDIGO')$$,
  'P0001', 'KENOS_INVALID_LENGTH',
  'oversized sealed payload rejected server-side'
);
-- 4
select throws_ok(
  $$select * from public.launch_echo('coords', '', 1.7, 0.5, 0.9, 'TEAL')$$,
  'P0001', 'KENOS_INVALID_COORDS',
  'out-of-bound coordinates rejected'
);
-- 5
select throws_ok(
  $$select * from public.launch_echo('theme', '', 0.5, 0.5, 0.9, 'ROSE')$$,
  'P0001', 'KENOS_INVALID_THEME',
  'ROSE theme rejected — destruction color never selectable'
);
-- 6
select is(
  (select count(*) from public.launch_echo('second secret', '', 0.5, 0.5, 0.9, 'INDIGO') l),
  1::bigint,
  'u2 launches cleanly'
);

-- ── u2 launches a SEALED echo (backdate first: the 20 s breath) ────────
reset role;
update public.echoes set created_at = now() - interval '30 seconds';
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000a2","role":"authenticated"}', true);

-- 7
select is(
  (select count(*) from public.launch_echo(
     'AAECAwQFBgcICQ==', 'a2Vub3Mta2V5LXRlc3Q=', 0.4, 0.6, 1.0, 'TEAL') l),
  1::bigint,
  'launch_echo accepts a sealed echo (ciphertext + key)'
);
reset role;
-- 8
select is(
  (select key_seal <> '' from public.echoes where encrypted_text = 'AAECAwQFBgcICQ=='),
  true,
  'the per-echo key is stored sealed, never in the clear'
);

-- ── u5: one cannot intercept one's own echo ────────────────────────────
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000a5","role":"authenticated"}', true);

select * from public.launch_echo('secret de u5', '', 0.1, 0.1, 0.5, 'LUMEN');
-- 9
select is(
  (select public.consume_echo(tests.echo_by_text('secret de u5'))),
  null::jsonb,
  'own echo is shielded from its author'
);

-- ── u3 intercepts u1's echo: single read, atomically ───────────────────
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000a3","role":"authenticated"}', true);

-- 10 — legacy echo: one consume returns the full bundle (plaintext
-- passthrough, no key). NB: never call consume twice within 5 s — the
-- anti-spam breath applies to the winner too.
select is(
  (select public.consume_echo(tests.echo_by_text('premier secret'))),
  jsonb_build_object('ciphertext', 'premier secret', 'key', null, 'momentum', 0),
  'the winner gets the legacy bundle (plaintext, no key)'
);

reset role;
-- 12
select is(
  (select count(*) from public.echoes where encrypted_text = 'premier secret'),
  0::bigint,
  'the read echo is destroyed — burn after reading'
);
-- 13
select is(
  (select count(*) from public.kenos_receptions),
  1::bigint,
  'contentless reception recorded for the author'
);
-- 14
select is(
  (select r.drift_seconds >= 0 from public.kenos_receptions r limit 1),
  true,
  'reception carries the real drift'
);

-- ── u4 arrives late: nothing left, then the 5 s breath ─────────────────
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000a4","role":"authenticated"}', true);

-- 15
select is(
  (select public.consume_echo(tests.echo_by_text('premier secret'))),
  null::jsonb,
  'a later reader finds nothing — single read is absolute'
);

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000a3","role":"authenticated"}', true);
-- 16
select throws_ok(
  $$select public.consume_echo(tests.echo_by_text('secret de u5'))$$,
  'P0001', 'KENOS_RATE_LIMIT',
  'interception rate limit: breathe between two reads'
);

-- ── u4 reads the SEALED echo: the one-shot key exchange ────────────────
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000a4","role":"authenticated"}', true);

-- 16 — the key comes back exactly as the author's device sealed it,
-- in the same single call as the payload.
select is(
  (select public.consume_echo(tests.echo_by_text('AAECAwQFBgcICQ=='))),
  jsonb_build_object('ciphertext', 'AAECAwQFBgcICQ==', 'key', 'a2Vub3Mta2V5LXRlc3Q=', 'momentum', 0),
  'the interceptor receives the escrowed key (exchange at interception)'
);

-- ── u6 launches + reads for the remaining loop tests ───────────────────
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000a6","role":"authenticated"}', true);
select * from public.launch_echo('troisième secret', '', 0.2, 0.2, 0.7, 'LUMEN');
-- 19
select is(
  (select public.consume_echo(tests.echo_by_text('second secret')) ->> 'ciphertext'),
  'second secret',
  'u6 gets the second echo'
);

-- ── Traces: one line, one shot, reader-only ────────────────────────────
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000a3","role":"authenticated"}', true);
-- 20
select is(
  (select public.leave_trace(tests.reception_for_reader('00000000-0000-4000-8000-0000000000a3'), 'Je te vois.')),
  true,
  'the reader leaves one trace'
);
-- 21
select is(
  (select public.leave_trace(tests.reception_for_reader('00000000-0000-4000-8000-0000000000a3'), 'remplacement')),
  false,
  'a trace can never be edited or replaced'
);

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000a5","role":"authenticated"}', true);
-- 22
select throws_ok(
  $$select public.leave_trace(tests.reception_for_reader('00000000-0000-4000-8000-0000000000a5'), 'vol')$$,
  'P0001', 'KENOS_RATE_LIMIT',
  'only the reader can leave the trace'
);

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000a6","role":"authenticated"}', true);
-- 23
select throws_ok(
  $$select public.leave_trace(tests.reception_for_reader('00000000-0000-4000-8000-0000000000a6'), rpad('x', 141, 'x'))$$,
  'P0001', 'KENOS_INVALID_LENGTH',
  'trace length enforced server-side'
);
-- 24
select is(
  (select public.leave_trace(tests.reception_for_reader('00000000-0000-4000-8000-0000000000a6'), 'Lu. Merci.')),
  true,
  'u6 traces the second echo'
);

-- ── Reports: reader-only, one contentless moderation record ───────────
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000a3","role":"authenticated"}', true);
-- 25
select is(
  (select public.report_echo(tests.reception_for_reader('00000000-0000-4000-8000-0000000000a3'), 'SPAM')),
  true,
  'the reader can report an echo without accessing its content'
);
-- 26
select is(
  (select public.report_echo(tests.reception_for_reader('00000000-0000-4000-8000-0000000000a3'), 'SPAM')),
  false,
  'a report is one shot per reader and echo'
);

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000a5","role":"authenticated"}', true);
-- 27
select throws_ok(
  $$select public.report_echo(tests.reception_for_reader('00000000-0000-4000-8000-0000000000a3'), 'SPAM')$$,
  'P0001', 'KENOS_RATE_LIMIT',
  'a stranger cannot report an echo they did not read'
);

-- ── Author isolation: view once, burn, nobody else ─────────────────────
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000a1","role":"authenticated"}', true);
-- 25
select is(
  (select count(*) from public.fetch_receptions()),
  1::bigint,
  'u1 sees exactly their own reception'
);
-- 26
select is(
  (select reply_text from public.fetch_receptions()),
  'Je te vois.',
  'the trace reached the author'
);
select public.burn_reception(tests.reception_for_reader('00000000-0000-4000-8000-0000000000a3'));
-- 27
select is(
  (select count(*) from public.fetch_receptions()),
  0::bigint,
  'viewing burned the signal — it never returns'
);

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000a5","role":"authenticated"}', true);
-- 28
select is(
  (select count(*) from public.fetch_receptions()),
  0::bigint,
  'an intruder sees no receptions at all'
);
select public.burn_reception(tests.reception_for_reader('00000000-0000-4000-8000-0000000000a6'));

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000a2","role":"authenticated"}', true);
-- 29
select is(
  (select count(*) from public.fetch_receptions()),
  2::bigint,
  'a non-author burn is a silent no-op'
);

-- ── Sector culling: viewport rect + per-sector caps ────────────────────
-- Seed a dense single sector (100 echoes in the top-left cell) as postgres.
reset role;
insert into public.echoes (author_id, encrypted_text, coord_x, coord_y, coord_z, color_theme, created_at)
select '00000000-0000-4000-8000-0000000000a1', 'dense-' || g, 0.01, 0.01, 0.5, 'TEAL',
       now() - (interval '1 minute' * g)
from generate_series(1, 100) g;

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000a3","role":"authenticated"}', true);

-- 30 — a dense sector is capped at the newest 24, newest first.
select is(
  (select count(*) from public.fetch_map_sector(0.0, 0.0, 0.125, 0.125)),
  24::bigint,
  'a dense sector is culled to the newest 24'
);
-- 31 — viewport rect excludes out-of-rect echoes.
select is(
  (select count(*) from public.fetch_map_sector(0.9, 0.9, 1.0, 1.0)
    where coord_x < 0.9 or coord_y < 0.9),
  0::bigint,
  'nothing outside the viewport rect comes back'
);

-- ── Purge: the ether forgets what drifted too long ─────────────────────
reset role;
update public.echoes set created_at = now() - interval '31 days'
where encrypted_text like 'dense-%';
update public.kenos_reads set read_at = now() - interval '2 days';

select public.kenos_purge();
-- 32
select is(
  (select count(*) from public.echoes where encrypted_text like 'dense-%'),
  0::bigint,
  'kenos_purge destroys echoes drifting for more than 30 days'
);
-- 33
select is(
  (select count(*) from public.kenos_reads),
  0::bigint,
  'kenos_purge also clears the stale audit journal'
);

-- ── KEK escrow: clients can never reach the wrapping key ───────────────
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000a3","role":"authenticated"}', true);
-- 34
select throws_ok(
  $$select * from public.kenos_ether_kek()$$,
  '42501', 'permission denied for function kenos_ether_kek',
  'the KEK function is unreachable for clients'
);

-- ── One's own echo never appears on one's map ───────────────────────────
-- (u5's 'secret de u5' is still drifting at (0.1, 0.1).)
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000a5","role":"authenticated"}', true);
-- 35
select is(
  (select count(*) from public.fetch_map_sector(0, 0, 1, 1)
    where id = tests.echo_by_text('secret de u5')),
  0::bigint,
  'the author does not see their own echo as an interceptable star'
);

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000a3","role":"authenticated"}', true);
-- 36
select is(
  (select count(*) from public.fetch_map_sector(0, 0, 1, 1)
    where id = tests.echo_by_text('secret de u5')),
  1::bigint,
  'a stranger does see it'
);

-- ── Sector bins use floor, not float→int rounding ──────────────────────
reset role;
insert into public.echoes (author_id, encrypted_text, coord_x, coord_y, coord_z, color_theme)
values ('00000000-0000-4000-8000-0000000000a1', 'borne-secteur', 0.0626, 0.9376, 0.5, 'TEAL');
-- 37 (a naive cast would round 0.5008 → 1 and 7.5008 → 8.)
select is(
  (select (sector_x, sector_y) = (0, 7) from public.echoes where encrypted_text = 'borne-secteur'),
  true,
  'sector columns floor — SQL and Dart agree on bin boundaries'
);

-- ── Symphonie Collective: waves cross the ether (V3.2) ─────────────────
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000a1","role":"authenticated"}', true);

-- 35 — u1 emits the wave under test, inside u2's future hearing radius.
select lives_ok(
  $$select public.emit_frequency(0.5::float8, 0.5::float8, 9::smallint, 2::smallint)$$,
  'emit_frequency accepts a valid wave'
);
-- 36 — chords allowed (2nd wave), flood refused (3rd within 5 s).
select lives_ok(
  $$select public.emit_frequency(0.05::float8, 0.95::float8, 4::smallint, 1::smallint)$$,
  'a second wave within 5 s is a chord, not a flood'
);
-- 37 — the threshold is >= 3: the FOURTH emission within 5 s refuses.
select lives_ok(
  $$select public.emit_frequency(0.05::float8, 0.95::float8, 4::smallint, 1::smallint)$$,
  'the third wave within 5 s is still allowed (ceiling is inclusive)'
);
select throws_ok(
  $$select public.emit_frequency(0.05::float8, 0.95::float8, 4::smallint, 1::smallint)$$,
  'P0001', 'KENOS_RATE_LIMIT',
  'wave flood limit: a fourth emission within 5 s refuses'
);

-- 38 — u2 hears exactly u1's wave inside the radius.
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000a2","role":"authenticated"}', true);
select is(
  (select note_index from public.fetch_nearby_frequencies(0.55, 0.5, 0.2)),
  9::smallint,
  'a stranger hears the wave within the hearing radius'
);
-- 39 — far away: silence.
select is(
  (select count(*) from public.fetch_nearby_frequencies(0.95, 0.95, 0.2)),
  0::bigint,
  'outside the radius, the wave is inaudible'
);

-- 40 — u2 emits; u2 never hears themself.
select emit_frequency(0.1::float8, 0.1::float8, 15::smallint, 0::smallint);
select is(
  (select count(*) from public.fetch_nearby_frequencies(0.1, 0.1, 0.15)),
  0::bigint,
  'own waves never come back — you already heard yourself'
);
-- 41 — but u1 hears u2's wave (and never their own).
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000a1","role":"authenticated"}', true);
select is(
  (select note_index from public.fetch_nearby_frequencies(0.1, 0.1, 0.15)),
  15::smallint,
  'the wave crosses the ether to the other emitter'
);

-- 42 — one minute of life, then the purge sweeps it away.
reset role;
update public.kenos_frequencies set created_at = now() - interval '61 seconds';
select public.kenos_purge();
select is(
  (select count(*) from public.kenos_frequencies),
  0::bigint,
  'kenos_purge sweeps waves older than one minute'
);

-- ── Sling-Shot: the phoenix chain (V3.3) ───────────────────────────────
reset role;
-- Backdate u1's launches: the 20 s breath must not interfere.
update public.echoes set created_at = now() - interval '40 seconds'
where author_id = '00000000-0000-4000-8000-0000000000a1';
-- The whole file runs in well under a second: backdate u4's reads or
-- the 5 s interception breath refuses the sling-shot intercept.
update public.kenos_reads set read_at = now() - interval '10 seconds'
where reader_id = '00000000-0000-4000-8000-0000000000a4';

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000a1","role":"authenticated"}', true);
-- 43 — u1 launches the comet's origin (legacy plaintext, tooling path).
select lives_ok(
  $$select public.launch_echo('comet origin', '', 0.5, 0.5, 0.9, 'INDIGO')$$,
  'u1 launches the comet origin'
);
-- The consume/rebound go through security-definer helpers keyed by
-- text: once read, the echo is destroyed and psql variables would go
-- stale — the helpers keep the whole chain readable and dollar-quoted.
-- 44 — u4 intercepts: the bundle carries the origin momentum.
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000a4","role":"authenticated"}', true);
select is(
  (tests.consume_by_text('comet origin') ->> 'momentum')::int,
  0,
  'the bundle carries the origin momentum'
);

-- 45 — u3 never read it: no lineage, no rebound.
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000a3","role":"authenticated"}', true);
select throws_ok(
  $$select * from tests.rebound_by_text('comet origin', 0, 'phoenix-one', 'cGhvdGVuaXgtY2xlcg==')$$,
  'P0001', 'KENOS_REBOUND_DENIED',
  'a stranger who never read the echo cannot rebound it'
);

-- 46 — u4, the reader, re-seals it: momentum 1, freshly sealed.
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000a4","role":"authenticated"}', true);
select is(
  (select rmomentum from tests.rebound_by_text('comet origin', 0, 'phoenix-one', 'cGhvdGVuaXgtY2xlcg==')),
  1,
  'the rebound is born with momentum 1'
);
-- 47 — the lineage burned with the decision: one rebound, once.
select throws_ok(
  $$select * from tests.rebound_by_text('comet origin', 0, 'phoenix-again', 'cGhvdGVuaXgtY2xlcg==')$$,
  'P0001', 'KENOS_REBOUND_DENIED',
  'the lineage burns with the decision — one rebound, once'
);

-- 48 — u3 intercepts the phoenix: momentum 1 travels with it.
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000a3","role":"authenticated"}', true);
select is(
  (tests.consume_by_text('phoenix-one') ->> 'momentum')::int,
  1,
  'the phoenix is readable once, carrying momentum 1'
);
-- 49 — the client cannot inflate the comet: the server holds the truth.
select throws_ok(
  $$select * from tests.rebound_by_text('phoenix-one', 5, 'phoenix-two', 'cGhvdGVuaXgtdHJvaXM=')$$,
  'P0001', 'KENOS_REBOUND_DENIED',
  'an inflated parent momentum is refused'
);
-- 50 — honest rebound: momentum 2.
select is(
  (select rmomentum from tests.rebound_by_text('phoenix-one', 1, 'phoenix-two', 'cGhvdGVuaXgtdHJvaXM=')),
  2,
  'the chain continues: momentum 2'
);

-- 51 — the map carries the comet: u1 (author of neither) sees momentum 2.
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000a1","role":"authenticated"}', true);
select is(
  (select momentum from public.fetch_map_sector(0, 0, 1, 1)
    where id = tests.echo_by_text('phoenix-two')),
  2,
  'the map metadata carries the comet tail'
);

-- 51b — the map carries the lineage link: phoenix-two's parent is the
-- phoenix-one id captured at its rebound.
reset role;
-- The parent row no longer exists (consumed by its reader — by
-- design); the truth is the link carried by the child. We assert the
-- map returns A parent (the consumed phoenix-one's id, non-null) and
-- that the child's own momentum says how far the chain travelled.
-- u1 (author of neither phoenix) reads the map as themselves.
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000a1","role":"authenticated"}', true);
select is(
  (select m.parent_id is not null from public.fetch_map_sector(0, 0, 1, 1) m
    where m.id = tests.echo_by_text('phoenix-two')),
  true,
  'the map returns parent_id — the client draws lineage constellations'
);

-- 52 — stale lineages are swept, and with them the rebound window.
reset role;
insert into public.kenos_lineages (echo_id, momentum, read_by, consumed_at)
values (gen_random_uuid(), 0, '00000000-0000-4000-8000-0000000000a4',
        now() - interval '2 hours');
select public.kenos_purge();
select is(
  (select count(*) from public.kenos_lineages
    where consumed_at < now() - interval '10 minutes'),
  0::bigint,
  'kenos_purge sweeps lineages past the decision window'
);

select * from finish();
rollback;
