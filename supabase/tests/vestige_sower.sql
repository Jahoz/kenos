-- KENOS security tests — the Shard Sower module (V3.57): the vestige
-- pipeline lives in the Observatory. AI proposals land as PENDING
-- rows (validated here, in SQL); the guardian publishes or discards;
-- the library retires and restores. The gate is human — the road is
-- a screen.
begin;
select plan(21);

create schema if not exists tests;
grant usage on schema tests to authenticated;

insert into auth.users (id, email, aud, role) values
  ('00000000-0000-4000-8000-0000000000a1', 'vs-stranger@test.kenos', 'authenticated', 'authenticated'),
  ('00000000-0000-4000-8000-0000000000a9', 'vs-guardian@test.kenos', 'authenticated', 'authenticated');

create or replace function tests.vs_metric(k text) returns integer
language sql security definer set search_path = public as $$
  select coalesce(
    case k when 'published' then vestiges_published end,
    0)::int
  from public.kenos_metrics_daily where day = current_date
$$;
grant execute on all functions in schema tests to authenticated;

-- ── A. The gates hold on every door ───────────────────────────────────
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000a1","role":"authenticated"}', true);
select throws_ok(
  $$select public.admin_list_vestige_proposals()$$,
  '42501', 'KENOS_FORBIDDEN',
  'a stranger reads no proposals'
);
select throws_ok(
  $$select public.admin_decide_vestige_proposal('11111111-2222-4333-8444-555555555555', true)$$,
  '42501', 'KENOS_FORBIDDEN',
  'a stranger decides nothing'
);
select throws_ok(
  $$select public.admin_set_vestige_live('v001', 'fr', false)$$,
  '42501', 'KENOS_FORBIDDEN',
  'a stranger retires no shard'
);
select throws_ok(
  $$select public.admin_sow_vestige_proposals('[]'::jsonb)$$,
  '42501', 'KENOS_FORBIDDEN',
  'a stranger sows nothing'
);
reset role;
set local role anon;
select throws_ok(
  $$select public.admin_fetch_vestiges('fr')$$,
  '42501', 'permission denied for function admin_fetch_vestiges',
  'anon reads no library'
);
reset role;

-- ── B. The AI's harvest, guarded in SQL ───────────────────────────────
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000a9","role":"authenticated","app_metadata":{"role":"admin"}}', true);
select is(
  public.admin_sow_vestige_proposals(
    '[{"kind":"fact","text":"La lumière du Soleil met huit minutes pour nous atteindre — distance appelée unité astronomique.","source":"astronomie"},
      {"kind":"fact","text":"cour","source":"x"},
      {"kind":"nonsense","text":"un genre inconnu passe son chemin ici","source":"x"},
      {"kind":"haiku","text":"Poussiere d etoile / un grain sur l aile d une nuit / et le temps s efface","source":"kenos"}]'::jsonb,
    'astronomie'
  ),
  2,
  'the sower keeps the honest two: bad measure and unknown kind are filtered'
);
select is(
  jsonb_array_length(public.admin_list_vestige_proposals()),
  2,
  'the guardian reads the pending harvest'
);
-- Re-sowing the same text changes nothing: no echo of what waits.
select is(
  public.admin_sow_vestige_proposals(
    '[{"kind":"fact","text":"La lumière du Soleil met huit minutes pour nous atteindre — distance appelée unité astronomique.","source":"astronomie"}]'::jsonb
  ),
  0,
  'a duplicate of a pending proposal never lands twice'
);

-- ── C. The human gate: publish and discard ────────────────────────────
-- The library is read through its RPCs: the tables belong to the
-- ether, tests look through the same doors the clients use.
select is(
  public.admin_decide_vestige_proposal(
    (select (public.admin_list_vestige_proposals() -> 0) ->> 'id')::uuid,
    true
  ),
  true,
  'the guardian publishes one shard'
);
select is(
  (select count(*) from jsonb_array_elements(public.admin_fetch_vestiges('fr')) e
    where e->>'text' like 'La lumière du Soleil met huit minutes%'),
  1::bigint,
  'the published shard lives in the library, French canon'
);
select is(
  (select count(*) from public.fetch_vestiges('fr') v
    where v.text like 'La lumière du Soleil met huit minutes%'),
  1::bigint,
  'and the CLIENT sky serves it (fetch_vestiges, live by default)'
);
select is(
  jsonb_array_length(public.admin_list_vestige_proposals()),
  1,
  'the decided proposal is gone from the pending list'
);
select is(tests.vs_metric('published'), 1,
  'one publication counted, contentless');
select is(
  public.admin_decide_vestige_proposal(
    (select (public.admin_list_vestige_proposals() -> 0) ->> 'id')::uuid,
    false
  ),
  true,
  'the guardian discards the other'
);
select is(
  jsonb_array_length(public.admin_list_vestige_proposals()),
  0,
  'nothing waits anymore'
);
select throws_ok(
  $$select public.admin_decide_vestige_proposal('11111111-2222-4333-8444-555555555555', true)$$,
  'P0001', 'KENOS_NOT_FOUND',
  'a decided proposal cannot be decided again'
);

-- ── D. The library lever: retire and restore ──────────────────────────
select lives_ok(
  $$select public.admin_set_vestige_live(
      (select e->>'id' from jsonb_array_elements(public.admin_fetch_vestiges('fr')) e
        where e->>'text' like 'La lumière du Soleil met huit minutes%' limit 1),
      'fr', false)$$,
  'the guardian retires the fresh shard'
);
select is(
  (select (e->>'live')::boolean
     from jsonb_array_elements(public.admin_fetch_vestiges('fr')) e
    where e->>'text' like 'La lumière du Soleil met huit minutes%'),
  false,
  'a retired shard leaves the sky (the client stops serving it)'
);
select is(
  (select count(*) from public.fetch_vestiges('fr') v
    where v.text like 'La lumière du Soleil met huit minutes%'),
  0::bigint,
  'the CLIENT sky no longer serves it — pinned at the source'
);
select lives_ok(
  $$select public.admin_set_vestige_live(
      (select e->>'id' from jsonb_array_elements(public.admin_fetch_vestiges('fr')) e
        where e->>'text' like 'La lumière du Soleil met huit minutes%' limit 1),
      'fr', true)$$,
  'the guardian restores it'
);
select is(
  (select count(*) from public.fetch_vestiges('fr') v
    where v.text like 'La lumière du Soleil met huit minutes%'),
  1::bigint,
  'the shard drifts again'
);

select * from finish();
rollback;
