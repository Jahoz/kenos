-- KENOS security tests — access control as an authenticated client.
-- These tests actively try to cheat; every attempt must fail.
begin;
select plan(11);

-- Seed: one echo owned by a test author, created outside client reach.
insert into auth.users (id, email, aud, role)
values ('00000000-0000-4000-8000-0000000000a1', 'author@test kenos', 'authenticated', 'authenticated');

insert into public.echoes (author_id, encrypted_text, coord_x, coord_y, coord_z, color_theme)
values ('00000000-0000-4000-8000-0000000000a1', 'LE SECRET', 0.5, 0.5, 0.9, 'TEAL');

-- ── As an authenticated client ─────────────────────────────────────────
set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-4000-8000-0000000000b2","role":"authenticated"}',
  true
);

-- Metadata columns are readable.
select lives_ok(
  'select id, coord_x, coord_y, coord_z, color_theme, created_at from public.echoes',
  'metadata columns readable by authenticated'
);

-- The secret column is structurally unreadable.
select throws_ok(
  'select encrypted_text from public.echoes',
  42501, 'permission denied for table echoes',
  'encrypted_text permission-denied for clients'
);

select throws_ok(
  'select author_id from public.echoes',
  42501, 'permission denied for table echoes',
  'author_id not granted either'
);

-- No writes of any kind on the table.
select throws_ok(
  $$insert into public.echoes (author_id, encrypted_text) values ('00000000-0000-4000-8000-0000000000b2', 'x')$$,
  42501, 'permission denied for table echoes',
  'direct INSERT denied'
);
select throws_ok(
  'update public.echoes set coord_x = 0.1',
  42501, 'permission denied for table echoes',
  'direct UPDATE denied'
);
select throws_ok(
  'delete from public.echoes',
  42501, 'permission denied for table echoes',
  'direct DELETE denied — burn happens only through consume_echo'
);

-- Journal and receptions tables are RPC-only.
select throws_ok(
  'select * from public.kenos_reads',
  42501, 'permission denied for table kenos_reads',
  'kenos_reads invisible to clients'
);
select throws_ok(
  'select * from public.kenos_receptions',
  42501, 'permission denied for table kenos_receptions',
  'kenos_receptions invisible to clients'
);

-- The map view: metadata yes, text impossible.
select is(
  (select count(*) from public.echoes_map),
  1::bigint,
  'map view exposes the echo metadata'
);
select throws_ok(
  'select encrypted_text from public.echoes_map',
  42703, 'column "encrypted_text" does not exist',
  'map view has no text column at all'
);

-- ── As anon: nothing at all ────────────────────────────────────────────
reset role;
set local role anon;
select throws_ok(
  'select * from public.echoes_map',
  42501, 'permission denied for table echoes',
  'anon cannot even read the map (invoker view delegates the check)'
);

select * from finish();
rollback;
