-- KENOS security tests — the past moons (V3.54): the landing names
-- which poets inhabited the sky, and which Mondays — never the poems.
-- Released lunes only (no spoilers), anon-readable (a public static
-- page behind the publishable key), shapes only.
begin;
select plan(6);

-- Fixtures straight into the backlog (postgres, the curator's hand):
-- two released lunes, one still waiting for its Monday.
insert into public.kenos_artifact_backlog
    (slot, slug, poet, title, kind, lines, released_at)
values
  (1, 'test-a', 'Poète Ancien', 'Première lune', 'POEM',
   '["une ligne", "deux lignes", "trois lignes", "quatre lignes"]',
   now() - interval '7 days'),
  (2, 'test-b', 'Autre Poète', 'Seconde lune', 'POEM',
   '["a line", "two lines", "three lines", "four lines"]',
   now() - interval '1 day'),
  (3, 'test-c', 'Poète Futur', 'Lune à venir', 'POEM',
   '["sealed", "sealed", "sealed", "sealed"]',
   null);

-- ── A. The landing's calendar is public and shaped ────────────────────
set local role anon;
select is(
  jsonb_array_length(public.fetch_past_moons()),
  2,
  'anon reads the calendar: two released lunes'
);
select is(
  (public.fetch_past_moons() -> 0) ->> 'poet',
  'Autre Poète',
  'newest first'
);
select is(
  (public.fetch_past_moons() -> 0) ->> 'released_on',
  to_char(now() - interval '1 day', 'YYYY-MM-DD'),
  'the Monday is a date, nothing more'
);
select is(
  (public.fetch_past_moons() @> '[{"title": "Lune à venir"}]'),
  false,
  'an unreleased slot stays a secret (no spoilers)'
);
select is(
  (public.fetch_past_moons() -> 0) ?| array['lines', 'source_note', 'slug', 'slot'],
  false,
  'never a line, never a source — the ether forgets, the landing names'
);
reset role;

-- ── B. The backlog itself stays opaque to clients ─────────────────────
set local role authenticated;
select throws_ok(
  $$select count(*) from public.kenos_artifact_backlog$$,
  '42501', 'permission denied for table kenos_artifact_backlog',
  'the corpus is the curator''s, clients never touch the table'
);
reset role;

select * from finish();
rollback;
