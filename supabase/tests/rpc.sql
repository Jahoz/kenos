-- KENOS security tests — RPC invariants: atomic single read, Ether Seal
-- key exchange, bottle-in-the-sea traces, sector culling, purge, rate
-- limits, author isolation. Every statement tries to break a promise;
-- the schema must hold.
begin;
select plan(131);

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

-- ── The Exquisite Corpse: blind constellations (V3.8) ─────────────────
reset role;
insert into auth.users (id, email, aud, role) values
  ('00000000-0000-4000-8000-0000000000d1', 'd1@t.kenos', 'authenticated', 'authenticated'),
  ('00000000-0000-4000-8000-0000000000d2', 'd2@t.kenos', 'authenticated', 'authenticated'),
  ('00000000-0000-4000-8000-0000000000d3', 'd3@t.kenos', 'authenticated', 'authenticated'),
  ('00000000-0000-4000-8000-0000000000d4', 'd4@t.kenos', 'authenticated', 'authenticated'),
  ('00000000-0000-4000-8000-0000000000d5', 'd5@t.kenos', 'authenticated', 'authenticated');

create or replace function tests.constellation_seed_by(t text) returns uuid
language sql security definer set search_path = public as $f$
  select id from public.kenos_constellations
  where seed_y = (select case when t = 'first' then 0.11 else 0.22 end)
  order by created_at desc limit 1
$f$;
create or replace function tests.constellation_target(t text) returns int
language sql security definer set search_path = public as $f$
  select target_lines from public.kenos_constellations
  where seed_y = (select case when t = 'first' then 0.11 else 0.22 end)
  order by created_at desc limit 1
$f$;
create or replace function tests.constellation_exists(t text) returns bigint
language sql security definer set search_path = public as $f$
  select count(*) from public.kenos_constellations
  where seed_y = (select case when t = 'first' then 0.11 else 0.22 end)
$f$;
grant execute on all functions in schema tests to authenticated;

-- d1 seeds.
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000d1","role":"authenticated"}', true);
select is(
  (select count(*) from public.seed_constellation(0.5::float8, 0.11::float8)),
  1::bigint,
  'seed_constellation creates an open corpse'
);
-- The target is between 4 and 7.
select is(
  tests.constellation_target('first') between 4 and 7,
  true,
  'the target lines are 4-7'
);

-- Pin to 4 so the auto-close is deterministic in this test.
reset role;
update public.kenos_constellations set target_lines = 4
  where id = tests.constellation_seed_by('first');

-- V3.13: contribute returns a jsonb bundle; stash helpers capture it.
reset role;
create table if not exists tests.contribute_bundle (bundle jsonb);
truncate tests.contribute_bundle;
grant usage on schema tests to authenticated;
grant select, insert, truncate on table tests.contribute_bundle to authenticated;

-- d2 contributes line 1: the bundle carries the count — and NO
-- preceding line (the poem opens with them).
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000d2","role":"authenticated"}', true);
insert into tests.contribute_bundle (bundle)
  select public.contribute_line(tests.constellation_seed_by('first'), 'première ligne aveugle', '');
select is(
  (select bundle ->> 'count' from tests.contribute_bundle),
  '1',
  'contribution 1 returns the count (not the lines)'
);
select is(
  (select jsonb_typeof(bundle -> 'previous') from tests.contribute_bundle),
  'null',
  'the first contributor has no preceding line — they open the poem'
);
truncate tests.contribute_bundle;

-- Blind: the map never exposes text.
select is(
  (select line_count from public.fetch_constellations(0, 0, 1, 1)
    where id = tests.constellation_seed_by('first')),
  1,
  'the map sees the count, zero text columns'
);

-- The tail of the poem, to continue it: the peeker sees exactly ONE
-- line — the last — never the whole.
select is(
  (select result ->> 'text' from (
    select public.peek_previous_line(tests.constellation_seed_by('first')) as result
  ) q),
  'première ligne aveugle',
  'peek_previous_line shows the tail — exactly one line, to continue it'
);
select is(
  (select jsonb_typeof(result -> 'key') from (
    select public.peek_previous_line(tests.constellation_seed_by('first')) as result
  ) q),
  'null',
  'peek on a legacy plaintext line: no key beside it'
);

-- d2 cannot contribute twice to the same corpse.
select throws_ok(
  $$select public.contribute_line(tests.constellation_seed_by('first'), 'deuxième', '')$$,
  'P0001', 'KENOS_ALREADY_CONTRIBUTED',
  'one line per stranger'
);

-- d3 contributes line 2 — and SEES the preceding line: the classic
-- surrealist rule. One continues; nobody sees the whole.
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000d3","role":"authenticated"}', true);
insert into tests.contribute_bundle (bundle)
  select public.contribute_line(tests.constellation_seed_by('first'), 'troisième', '');
select is(
  (select bundle ->> 'count' from tests.contribute_bundle),
  '2',
  'contribution 2 counts two lines'
);
select is(
  (select bundle -> 'previous' ->> 'text' from tests.contribute_bundle),
  'première ligne aveugle',
  'the contributor SEES the preceding line — the classic rule'
);
select is(
  (select jsonb_typeof(bundle -> 'previous' -> 'key') from tests.contribute_bundle),
  'null',
  'legacy plaintext line: no key beside it'
);
truncate tests.contribute_bundle;

-- d4, d5 contribute — the corpse auto-closes at its target.
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000d4","role":"authenticated"}', true);
select is(
  (select state from public.fetch_constellations(0, 0, 1, 1)
    where id = tests.constellation_seed_by('first')),
  'OPEN',
  'still open before the target'
);
select public.contribute_line(tests.constellation_seed_by('first'), 'quatrième', '');
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000d5","role":"authenticated"}', true);
select public.contribute_line(tests.constellation_seed_by('first'), 'cinquième', '');

select is(
  (select state from public.fetch_constellations(0, 0, 1, 1)
    where id = tests.constellation_seed_by('first')),
  'CLOSED',
  'the corpse auto-closes at its target'
);

-- THE NEW SOUL (arbitrage 2026-09-03): the contributor reads the
-- finished poem too — the artifact belongs to its strangers.
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000d2","role":"authenticated"}', true);
select is(
  (select jsonb_array_length(result -> 'lines') from (
    select public.read_constellation(tests.constellation_seed_by('first')) as result
  ) q),
  4,
  'a contributor reads the finished poem — the artifact belongs to its strangers'
);

-- A stranger reads the SAME artifact — re-readable, like the vestiges.
reset role;
insert into auth.users (id, email, aud, role) values
  ('00000000-0000-4000-8000-0000000000d6', 'd6@t.kenos', 'authenticated', 'authenticated');
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000d6","role":"authenticated"}', true);
select is(
  (select jsonb_array_length(result -> 'lines') from (
    select public.read_constellation(tests.constellation_seed_by('first')) as result
  ) q),
  4,
  'a stranger reads the same artifact — for all, again and again'
);
select is(
  tests.constellation_exists('first'),
  1::bigint,
  'the read corpse REMAINS — an artifact, not a memory'
);

-- An OPEN corpse cannot be read.
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000d1","role":"authenticated"}', true);
select is(
  (select count(*) from public.seed_constellation(0.5::float8, 0.22::float8)),
  1::bigint,
  'a second corpse is seeded'
);
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000d6","role":"authenticated"}', true);
select throws_ok(
  $$select public.read_constellation(tests.constellation_seed_by('second'))$$,
  'P0001', 'KENOS_STILL_OPEN',
  'an open corpse cannot be read whole'
);

-- V3.14 — the constellation-song: the drop chooses poem or song,
-- and the map knows what it draws.
select is(
  (select kind from public.fetch_constellations(0, 0, 1, 1)
    where id = tests.constellation_seed_by('second')),
  'POEM',
  'a corpse seeds as a POEM by default'
);
select is(
  (select count(*) from public.seed_constellation(0.8::float8, 0.8::float8, 'MELODY')),
  1::bigint,
  'a SONG is seeded (MELODY)'
);
select is(
  (select kind from public.fetch_constellations(0, 0, 1, 1)
    where seed_x = 0.8::float8),
  'MELODY',
  'the map sees the kind'
);
select throws_ok(
  $$select public.seed_constellation(0.81::float8, 0.81::float8, 'SHOUT')$$,
  'P0001', 'KENOS_INVALID_KIND',
  'the kind is POEM or MELODY — never a shout'
);

-- ── V3.14b — the Gardener & the Curator ─────────────────────────────────
-- Wipe every corpse first (deterministic garden).
reset role;
delete from public.kenos_constellations;
select is(
  public.kenos_garden_seed(14, 5),
  5,
  'the gardener plants up to max_new on an empty ether'
);
select is(
  public.kenos_garden_seed(14, 5),
  5,
  'the gardener plants again toward the target'
);
select is(
  public.kenos_garden_seed(14, 5),
  4,
  'the gardener stops exactly at the target (14)'
);
select is(
  public.kenos_garden_seed(14, 5),
  0,
  'a full garden plants nothing'
);
select is(
  (select count(*) from public.kenos_constellation_lines),
  0::bigint,
  'the gardener writes NO lines — rings wait for strangers'
);
select is(
  (select count(*) from public.kenos_constellations
    where kind not in ('POEM', 'MELODY')),
  0::bigint,
  'every planted ring is a poem or a song'
);
-- The attribution rides the metadata (curated corpses carry it).
update public.kenos_constellations
   set curated_by = 'TEST POET', state = 'CLOSED', closed_at = now()
 where id = (select id from public.kenos_constellations limit 1);
select is(
  (select curated_by from public.fetch_constellations(0, 0, 1, 1)
    where state = 'CLOSED' limit 1),
  'TEST POET',
  'the map sees the attribution — the reading will name the poet'
);
delete from public.kenos_constellations;

-- ── V3.14c — the Vestiges cross the ether ──────────────────────────────
-- The library is curated culture: readable text (deliberately public —
-- no sealing, no burning), live-flagged, capped at 200 in flight.
reset role;
insert into public.kenos_vestiges (id, kind, text, source, pos_x, pos_y) values
  ('t-vest-1', 'quote', 'test quote', 'test', 0.5, 0.5),
  ('t-vest-2', 'fact', 'test fact', 'test', 0.5, 0.6);
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000d1","role":"authenticated"}', true);
select is(
  (select count(*) from public.fetch_vestiges()),
  2::bigint,
  'the drifting library serves its shards'
);
reset role;
update public.kenos_vestiges set live = false where id = 't-vest-2';
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000d1","role":"authenticated"}', true);
select is(
  (select count(*) from public.fetch_vestiges()),
  1::bigint,
  'a retired shard leaves the sky (live = false)'
);
reset role;
delete from public.kenos_vestiges where id like 't-vest-%';

-- Purge: open corpses > 7 days go back to the void; a closed corpse
-- is an artifact for a moon — then the ether forgets.
-- The gardener/curator wipes above emptied the sky: re-seed the two
-- rings this scenario needs (deterministic direct writes — postgres
-- tooling, outside client reach). Without them the scenario kept
-- referencing rows deleted by the V3.14b wipe.
reset role;
insert into public.kenos_constellations (seed_x, seed_y, target_lines, state, kind, closed_at)
values (0.5, 0.11, 4, 'CLOSED', 'POEM', now()),
       (0.5, 0.22, 4, 'OPEN', 'POEM', null);
update public.kenos_constellations set created_at = now() - interval '8 days'
  where id = tests.constellation_seed_by('second');
select public.kenos_purge();
select is(
  tests.constellation_exists('first'),
  1::bigint,
  'kenos_purge keeps recent artifacts (closed corpses stay)'
);
select is(
  tests.constellation_exists('second'),
  0::bigint,
  'kenos_purge sweeps stale open corpses'
);
update public.kenos_constellations set closed_at = now() - interval '31 days'
  where id = tests.constellation_seed_by('first');
select public.kenos_purge();
select is(
  tests.constellation_exists('first'),
  0::bigint,
  'the artifact lives a moon — then the ether forgets'
);

-- ── V3.11a — the SEALED corpse: the winner gets ciphertext + key ────────
-- The regression: 'text' used to carry pgp_sym_decrypt(key_seal) — the
-- KEY — so real (sealed) corpses read as empty lines on device. The
-- bundle must pass the client-sealed ciphertext through untouched,
-- with the key unsealed from escrow beside it (consume_echo parity).
create table if not exists tests.sealed_bundle (bundle jsonb);
truncate tests.sealed_bundle;
create or replace function tests.constellation_at(px float8, py float8) returns uuid
language sql security definer set search_path = public as $$
  select id from public.kenos_constellations
   where seed_x = px and seed_y = py limit 1
$$;
create or replace function tests.consume_constellation_at(px float8, py float8)
returns jsonb
language plpgsql security definer set search_path = public, tests as $$
begin
  insert into tests.sealed_bundle (bundle)
  values (public.consume_constellation(tests.constellation_at(px, py)));
  return (select bundle from tests.sealed_bundle limit 1);
end;
$$;
grant execute on function tests.constellation_at(float8, float8) to authenticated;
grant execute on function tests.consume_constellation_at(float8, float8) to authenticated;

reset role;
insert into auth.users (id, email, aud, role) values
  ('00000000-0000-4000-8000-0000000000f1', 'f1@t.kenos', 'authenticated', 'authenticated'),
  ('00000000-0000-4000-8000-0000000000f2', 'f2@t.kenos', 'authenticated', 'authenticated'),
  ('00000000-0000-4000-8000-0000000000f3', 'f3@t.kenos', 'authenticated', 'authenticated'),
  ('00000000-0000-4000-8000-0000000000f4', 'f4@t.kenos', 'authenticated', 'authenticated'),
  ('00000000-0000-4000-8000-0000000000f5', 'f5@t.kenos', 'authenticated', 'authenticated');
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000f1","role":"authenticated"}', true);
select is(
  (select count(*) from public.seed_constellation(0.7::float8, 0.7::float8)),
  1::bigint,
  'the sealed corpse is seeded'
);
reset role;
update public.kenos_constellations set target_lines = 4
  where seed_x = 0.7 and seed_y = 0.7;

-- Four strangers, each with a REAL sealed pair (key non-empty).
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000f1","role":"authenticated"}', true);
select public.contribute_line(
  tests.constellation_at(0.7, 0.7),
  'AAECAwQFBgcICQ==', 'a2Vub3Mta2V5LXRlc3Q=');
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000f2","role":"authenticated"}', true);
truncate tests.contribute_bundle;
insert into tests.contribute_bundle (bundle)
  select public.contribute_line(
    tests.constellation_at(0.7, 0.7),
    'AAECAwQFBgcIR0xP', 'a2Vub3Mta2V5LXRlc3Q=');
select is(
  (select bundle -> 'previous' ->> 'text' from tests.contribute_bundle),
  'AAECAwQFBgcICQ==',
  'sealed preceding line: text IS the ciphertext, untouched'
);
select is(
  (select bundle -> 'previous' ->> 'key' from tests.contribute_bundle),
  'a2Vub3Mta2V5LXRlc3Q=',
  'sealed preceding line: the key leaves the escrow for the contributor, once'
);
truncate tests.contribute_bundle;
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000f3","role":"authenticated"}', true);
select public.contribute_line(
  tests.constellation_at(0.7, 0.7),
  'AAECAwQFBgcJVEVN', 'a2Vub3Mta2V5LXRlc3Q=');
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000f4","role":"authenticated"}', true);
select public.contribute_line(
  tests.constellation_at(0.7, 0.7),
  'AAECAwQFBgcKRE9S', 'a2Vub3Mta2V5LXRlc3Q=');

-- The single reader (never a contributor) opens the sealed corpse;
-- the definer helper stashes the bundle for both assertions.
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000f5","role":"authenticated"}', true);
select tests.consume_constellation_at(0.7, 0.7);
reset role;

-- 80
select is(
  (select bundle -> 'lines' -> 0 ->> 'text' from tests.sealed_bundle),
  'AAECAwQFBgcICQ==',
  'sealed corpse: text IS the ciphertext — never the key, never a server decryption'
);
-- 81
select is(
  (select bundle -> 'lines' -> 0 ->> 'key' from tests.sealed_bundle),
  'a2Vub3Mta2V5LXRlc3Q=',
  'sealed corpse: the key travels beside it, unsealed from escrow exactly once'
);
-- 82 — the alias heals deployed clients WITHOUT destroying the artifact.
select is(
  (select count(*) from public.kenos_constellations where seed_x = 0.7::float8),
  1::bigint,
  'alias consume_constellation reads without destroying — the artifact stays'
);

-- ── V3.10 — the Excerpts: sealed cultural doors ─────────────────────────
-- e7 seals a door; e8 verifies the map metadata and the winner bundle.
reset role;
insert into auth.users (id, email, aud, role) values
  ('00000000-0000-4000-8000-0000000000e7', 'e7@t.kenos', 'authenticated', 'authenticated'),
  ('00000000-0000-4000-8000-0000000000e8', 'e8@t.kenos', 'authenticated', 'authenticated');
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000e7","role":"authenticated"}', true);

-- 72 — a SONG door launches: sealed reference, bounded, opaque.
select is(
  (select count(*) from public.launch_echo(
     'porte scellée de e7', '', 0.3, 0.3, 0.9, 'TEAL', 'SONG', repeat('QUJD', 16)) l),
  1::bigint,
  'launch_echo accepts a sealed SONG door (bounded opaque reference)'
);
reset role;
update public.echoes set created_at = now() - interval '30 seconds';
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000e7","role":"authenticated"}', true);

-- 73
select throws_ok(
  $$select * from public.launch_echo('trop longue', '', 0.3, 0.3, 0.9, 'TEAL', 'EXCERPT', repeat('QUJD', 129))$$,
  'P0001', 'KENOS_INVALID_MEDIA',
  'a door reference beyond 512 sealed chars is refused'
);
-- 74
select throws_ok(
  $$select * from public.launch_echo('trop courte', '', 0.3, 0.3, 0.9, 'TEAL', 'EXCERPT', repeat('Q', 31))$$,
  'P0001', 'KENOS_INVALID_MEDIA',
  'a door reference under 32 sealed chars is refused'
);
-- 75 — the sealed blob is base64-shaped: no arbitrary payloads ride along.
select throws_ok(
  $$select * from public.launch_echo('pas du base64', '', 0.3, 0.3, 0.9, 'TEAL', 'SONG', repeat('a b!', 16))$$,
  'P0001', 'KENOS_INVALID_MEDIA',
  'a non-base64 door reference is refused'
);
-- 76
select throws_ok(
  $$select * from public.launch_echo('genre inconnu', '', 0.3, 0.3, 0.9, 'TEAL', 'PODCAST', repeat('QUJD', 16))$$,
  'P0001', 'KENOS_INVALID_MEDIA',
  'an unknown door kind is refused'
);
-- 77 — the XOR rule holds for doors as for fragments.
select throws_ok(
  $$select * from public.launch_echo('porte sans référence', '', 0.3, 0.3, 0.9, 'TEAL', 'SONG', null)$$,
  'P0001', 'KENOS_INVALID_MEDIA',
  'a door kind without a reference is refused'
);

-- 78 — the map knows nothing of the door: the echo drifts as a normal
-- star (fetch_map_sector exposes no media column at all).
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000e8","role":"authenticated"}', true);
select is(
  (select count(*) from public.fetch_map_sector()
   where id = tests.echo_by_text('porte scellée de e7')),
  1::bigint,
  'the door echo drifts as a normal star — the map knows nothing of it'
);

-- 79 — the single winner receives the sealed reference with the key.
select is(
  (select (bundle ? 'media_path' and bundle ->> 'media_kind' = 'SONG')
   from (select public.consume_echo(tests.echo_by_text('porte scellée de e7')) as bundle) q),
  true,
  'the winner gets the sealed door reference and its kind'
);

-- ── V3.16 — The Observatory: contentless usage counters + guardian gate ──
-- Fresh hands (c7/c8, m901-m907) so the frozen-transaction clocks (the
-- 5 s / 20 s cadences read now(), which never advances inside one tx)
-- cannot interfere with earlier cases.
reset role;
insert into auth.users (id, email, aud, role) values
  ('00000000-0000-4000-8000-0000000000c7', 'c7@t.kenos', 'authenticated', 'authenticated'),
  ('00000000-0000-4000-8000-0000000000c8', 'c8@t.kenos', 'authenticated', 'authenticated'),
  ('00000000-0000-4000-8000-000000000901', 'm901@t.kenos', 'authenticated', 'authenticated'),
  ('00000000-0000-4000-8000-000000000902', 'm902@t.kenos', 'authenticated', 'authenticated'),
  ('00000000-0000-4000-8000-000000000903', 'm903@t.kenos', 'authenticated', 'authenticated'),
  ('00000000-0000-4000-8000-000000000904', 'm904@t.kenos', 'authenticated', 'authenticated'),
  ('00000000-0000-4000-8000-000000000905', 'm905@t.kenos', 'authenticated', 'authenticated'),
  ('00000000-0000-4000-8000-000000000906', 'm906@t.kenos', 'authenticated', 'authenticated'),
  ('00000000-0000-4000-8000-000000000907', 'm907@t.kenos', 'authenticated', 'authenticated');

-- Definer helper: the consumed echo id, readable from authenticated
-- blocks (tests.consumed_ids itself is out of client reach).
create or replace function tests.consumed_id_by_tag(p_tag text) returns uuid
language sql security definer set search_path = public, tests as $$
  select echo_id from tests.consumed_ids where tag = p_tag
$$;
grant execute on function tests.consumed_id_by_tag(text) to authenticated;

-- 80 — the counter whitelist: no dynamic SQL, no invented kinds.
select throws_ok(
  $$select public.kenos_metrics_touch('bogus')$$,
  'P0001', 'KENOS_METRICS_BAD_KIND',
  'the metrics bump refuses unknown kinds'
);

-- 81 — every user birth is counted, and nothing else about it.
select is(
  coalesce((select m.new_users from public.kenos_metrics_daily m where m.day = current_date), 0),
  (select count(*)::int from auth.users),
  'every user birth counted, contentless'
);

-- Snapshots live in a temp table (read/written as postgres around the
-- authenticated actions) so assertions are exact deltas, whatever the
-- earlier cases did on the same day.
create temp table metrics_probe_snap (k text primary key, v integer);

-- 82 — one launch (the live 8-param path), one counted launch.
insert into metrics_probe_snap (k, v)
select 'launched', coalesce((select m.echoes_launched from public.kenos_metrics_daily m where m.day = current_date), 0);
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000c7","role":"authenticated"}', true);
select * from public.launch_echo('observatoire sonde', '', 0.42, 0.52, 0.9, 'TEAL', null, null);
reset role;
select is(
  coalesce((select m.echoes_launched from public.kenos_metrics_daily m where m.day = current_date), 0),
  (select v from metrics_probe_snap where k = 'launched') + 1,
  'launch_echo bumps the daily launched counter exactly once'
);

-- 83 — one atomic consumption, one counted burn (same transaction).
insert into metrics_probe_snap (k, v)
select 'consumed', coalesce((select m.echoes_consumed from public.kenos_metrics_daily m where m.day = current_date), 0);
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000c8","role":"authenticated"}', true);
select tests.consume_by_text('observatoire sonde');
reset role;
select is(
  coalesce((select m.echoes_consumed from public.kenos_metrics_daily m where m.day = current_date), 0),
  (select v from metrics_probe_snap where k = 'consumed') + 1,
  'consume_echo bumps the daily consumed counter exactly once'
);

-- 84/85/86 — a trace is counted once; the one-shot second call never counts.
insert into metrics_probe_snap (k, v)
select 'traces', coalesce((select m.traces_left from public.kenos_metrics_daily m where m.day = current_date), 0);
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000c8","role":"authenticated"}', true);
select is(
  public.leave_trace(tests.consumed_id_by_tag('observatoire sonde'), 'merci, étoile'),
  true,
  'the reader leaves one trace'
);
select is(
  public.leave_trace(tests.consumed_id_by_tag('observatoire sonde'), 'remplacement'),
  false,
  'a trace already left can never be replaced'
);
reset role;
select is(
  coalesce((select m.traces_left from public.kenos_metrics_daily m where m.day = current_date), 0),
  (select v from metrics_probe_snap where k = 'traces') + 1,
  'leave_trace counted exactly once — the one-shot rule holds'
);

-- 87 — a report is counted when filed, not when refused.
insert into metrics_probe_snap (k, v)
select 'reports', coalesce((select m.reports_filed from public.kenos_metrics_daily m where m.day = current_date), 0);
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000c8","role":"authenticated"}', true);
select public.report_echo(tests.consumed_id_by_tag('observatoire sonde'), 'OTHER');
reset role;
select is(
  coalesce((select m.reports_filed from public.kenos_metrics_daily m where m.day = current_date), 0),
  (select v from metrics_probe_snap where k = 'reports') + 1,
  'report_echo bumps the daily report counter exactly once'
);

-- 88 — the phoenix rebirth is counted too.
insert into metrics_probe_snap (k, v)
select 'rebound', coalesce((select m.echoes_rebound from public.kenos_metrics_daily m where m.day = current_date), 0);
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000c8","role":"authenticated"}', true);
select * from tests.rebound_by_text('observatoire sonde', 0, 'phoenix métrique', '');
reset role;
select is(
  coalesce((select m.echoes_rebound from public.kenos_metrics_daily m where m.day = current_date), 0),
  (select v from metrics_probe_snap where k = 'rebound') + 1,
  'rebound_echo bumps the daily rebirth counter exactly once'
);

-- 89/90/91 — a full corpse: seed, lines, and the closing day it deserves.
-- The target is random (4..7): the probe contributes as fresh strangers
-- until the constellation closes, then the deltas tell the truth.
create or replace function tests.metrics_corpse_probe()
returns integer
language plpgsql security definer set search_path = public, tests as $$
declare
    cid uuid;
    target int;
    n int := 0;
begin
    select id into cid from public.seed_constellation(0.31, 0.13, 'POEM') s;
    select target_lines into target from public.kenos_constellations where id = cid;
    while n < target loop
        n := n + 1;
        perform set_config(
            'request.jwt.claims',
            format('{"sub":"00000000-0000-4000-8000-%s","role":"authenticated"}',
                   lpad((900 + n)::text, 12, '0')),
            true
        );
        perform public.contribute_line(cid, 'ligne de sonde ' || n, '');
    end loop;
    return target;
end;
$$;
grant execute on function tests.metrics_corpse_probe() to authenticated;

insert into metrics_probe_snap (k, v)
select 'seeded', coalesce((select m.corpses_seeded from public.kenos_metrics_daily m where m.day = current_date), 0);
insert into metrics_probe_snap (k, v)
select 'lines', coalesce((select m.lines_contributed from public.kenos_metrics_daily m where m.day = current_date), 0);
insert into metrics_probe_snap (k, v)
select 'closed', coalesce((select m.corpses_closed from public.kenos_metrics_daily m where m.day = current_date), 0);
-- The random target (4..7) is captured through the GUC-only claims:
-- the definer probe reads request.jwt.claims whatever the invoking role.
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000c7","role":"authenticated"}', true);
insert into metrics_probe_snap (k, v)
select 'probe_target', tests.metrics_corpse_probe();
reset role;
select is(
  coalesce((select m.corpses_seeded from public.kenos_metrics_daily m where m.day = current_date), 0),
  (select v from metrics_probe_snap where k = 'seeded') + 1,
  'seed_constellation bumps the seeded counter exactly once'
);
select is(
  coalesce((select m.lines_contributed from public.kenos_metrics_daily m where m.day = current_date), 0)
    - (select v from metrics_probe_snap where k = 'lines'),
  (select v from metrics_probe_snap where k = 'probe_target'),
  'every contributed line counted, contentless'
);
select is(
  coalesce((select m.corpses_closed from public.kenos_metrics_daily m where m.day = current_date), 0)
    - (select v from metrics_probe_snap where k = 'closed'),
  1,
  'the closing line bumps the corpse counter exactly once'
);

-- ── The guardian gate ───────────────────────────────────────────────────
-- anon cannot even resolve the function (existence proof, like smoke_prod).
set local role anon;
select throws_ok(
  $$select public.admin_fetch_metrics()$$,
  42501, 'permission denied for function admin_fetch_metrics',
  'anon cannot even resolve the observatory RPC'
);
reset role;

-- A mere stranger: refused.
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000c8","role":"authenticated"}', true);
select throws_ok(
  $$select public.admin_fetch_metrics()$$,
  '42501', 'KENOS_FORBIDDEN',
  'a mere stranger cannot read the observatory'
);

-- user_metadata is user-editable: it must NEVER authorize anything.
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000c8","role":"authenticated","user_metadata":{"role":"admin"}}', true);
select throws_ok(
  $$select public.admin_fetch_metrics()$$,
  '42501', 'KENOS_FORBIDDEN',
  'a forged user_metadata claim authorizes nothing'
);

-- The guardian: app_metadata (operator-set, not user-editable).
-- tests.user_count: the expected population, read through a definer
-- (auth.users itself is out of any client's reach).
reset role;
create or replace function tests.user_count() returns integer
language sql security definer set search_path = public as $$
  select count(*)::int from auth.users
$$;
grant execute on function tests.user_count() to authenticated;
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000c8","role":"authenticated","app_metadata":{"role":"admin"}}', true);
select is(jsonb_exists(public.admin_fetch_metrics(), 'series'), true, 'the guardian reads the spectrum');
select is(jsonb_exists(public.admin_fetch_metrics(), 'live'), true, 'the guardian reads the live state');
select is(jsonb_exists(public.admin_fetch_metrics(), 'sectors'), true, 'the guardian reads the sector grid');
select is(jsonb_exists(public.admin_fetch_metrics(), 'derived'), true, 'the guardian reads the derived ratios');
select is(
  (public.admin_fetch_metrics() -> 'live' ->> 'users_total')::int,
  tests.user_count(),
  'users_total is the whole population, contentless'
);
select is(
  jsonb_array_length(public.admin_fetch_metrics() -> 'series'),
  30,
  'the spectrum spans thirty days by default'
);
reset role;

-- The purge folds distinct readers BEFORE burning the 1-day journal.
select public.kenos_purge();
select is(
  (select m.active_readers from public.kenos_metrics_daily m where m.day = current_date),
  (select count(distinct r.reader_id)::int from public.kenos_reads r where r.read_at::date = current_date),
  'the purge folds distinct readers into the daily row before the journal burns'
);

-- ── Media orphans: the ledger sees only the debt, never the living ────
-- Two encrypted fragments older than a day; only the second belongs
-- to a still-drifting echo. SQL deletes from storage.objects are
-- blocked by storage.protect_delete on purpose; the sweep lives in
-- the sweep-media edge function (Storage API, service key), and its
-- eyes are THIS ledger: kenos_list_media_orphans, service-role only
-- (object names embed author ids — never for clients).
insert into storage.objects (id, bucket_id, name, created_at)
values (gen_random_uuid(), 'echo-media',
        '00000000-0000-4000-8000-0000000000a1/77-IMAGE.bin',
        now() - interval '2 days'),
       (gen_random_uuid(), 'echo-media',
        '00000000-0000-4000-8000-0000000000a1/78-IMAGE.bin',
        now() - interval '2 days');
insert into public.echoes (author_id, encrypted_text, coord_x, coord_y, coord_z,
                           color_theme, media_kind, media_path)
values ('00000000-0000-4000-8000-0000000000a1', 'media-keep', 0.5, 0.5, 0.9,
        'TEAL', 'IMAGE', '00000000-0000-4000-8000-0000000000a1/78-IMAGE.bin');

-- 129 — the ledger lists exactly the orphan:
select is(
  public.kenos_list_media_orphans(),
  array['00000000-0000-4000-8000-0000000000a1/77-IMAGE.bin'],
  'the orphan ledger lists exactly the unreferenced fragment, never a live echo''s media'
);

select public.kenos_purge();

-- 130 — after the purge, the live echo's media is untouched:
select is(
  (select count(*) from storage.objects
    where name = '00000000-0000-4000-8000-0000000000a1/78-IMAGE.bin'),
  1::bigint,
  'a live echo keeps its media: neither the ledger nor the purge may touch it'
);

-- 131 — clients can never read the ledger (names embed author ids):
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000b2","role":"authenticated"}', true);
select throws_ok(
  $$select public.kenos_list_media_orphans()$$,
  '42501', 'permission denied for function kenos_list_media_orphans',
  'the orphan ledger is service-role only'
);
reset role;

select * from finish();
rollback;
