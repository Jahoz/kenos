-- KENOS security tests — daily read quotas (V3.22): no hand empties
-- the ether for the others. 60 lights a day, 150 distinct rings a
-- day (re-reads free), per hand — and a fresh hand starts untouched.
begin;
select plan(8);

create schema if not exists tests;
grant usage on schema tests to authenticated;

insert into auth.users (id, email, aud, role) values
  ('00000000-0000-4000-8000-0000000000c0', 'quota-c0@test.kenos', 'authenticated', 'authenticated'),
  ('00000000-0000-4000-8000-0000000000c1', 'quota-c1@test.kenos', 'authenticated', 'authenticated'),
  ('00000000-0000-4000-8000-0000000000c2', 'quota-c2@test.kenos', 'authenticated', 'authenticated'),
  ('00000000-0000-4000-8000-0000000000c3', 'quota-c3@test.kenos', 'authenticated', 'authenticated');

-- Fixtures, ether-owned (claimless): the drain loops call the REAL
-- RPCs as the reader, so the quota counts exactly what production
-- would count.
create or replace function tests.quota_seed_echoes(p_n integer)
returns void
language plpgsql security definer set search_path = public as $$
begin
    insert into public.echoes (author_id, encrypted_text, coord_x, coord_y, coord_z, color_theme)
    select '00000000-0000-4000-8000-0000000000c0'::uuid,
           'quota fixture ' || g, 0.4, 0.4, 0.5, 'TEAL'
      from generate_series(1, p_n) g;
end;
$$;

create or replace function tests.quota_drain_echoes(p_n integer)
returns integer
language plpgsql security definer set search_path = public as $$
declare
    done integer := 0;
    eid   uuid;
begin
    for k in 1..p_n loop
        select id into eid from public.echoes
         where author_id <> auth.uid()
           and id not in (select echo_id from public.kenos_reads where reader_id = auth.uid())
         limit 1;
        exit when eid is null;
        if public.consume_echo(eid) is null then
            exit; -- shielded or raced: stop honestly
        end if;
        -- The 5 s anti-spam must not throttle the test loop.
        update public.kenos_reads set read_at = now() - interval '10 seconds'
         where reader_id = auth.uid() and echo_id = eid;
        done := done + 1;
    end loop;
    return done;
end;
$$;

create or replace function tests.quota_seed_rings(p_n integer)
returns void
language plpgsql security definer set search_path = public as $$
begin
    -- Claimless CLOSED artifacts, lines included: readable rings.
    insert into public.kenos_constellations (seed_x, seed_y, target_lines, state, kind, closed_at, curated_by)
    select 0.4, 0.4, 4, 'CLOSED', 'POEM', now(), 'QUOTA TEST'
      from generate_series(1, p_n);
    insert into public.kenos_constellation_lines (constellation_id, contributor_id, line_number, encrypted_text, key_seal)
    select c.id, '00000000-0000-4000-8000-0000000000c0'::uuid, 1, 'ligne', ''
      from public.kenos_constellations c
     where c.curated_by = 'QUOTA TEST';
end;
$$;

create or replace function tests.quota_read_rings(p_n integer)
returns integer
language plpgsql security definer set search_path = public as $$
declare
    done integer := 0;
    cid   uuid;
begin
    for k in 1..p_n loop
        select c.id into cid from public.kenos_constellations c
         where c.curated_by = 'QUOTA TEST'
           and c.state = 'CLOSED'
           and c.id not in (
               select constellation_id from public.kenos_constellation_reads
                where reader_id = auth.uid()
           )
         limit 1;
        exit when cid is null;
        perform public.read_constellation(cid);
        done := done + 1;
    end loop;
    return done;
end;
$$;

create or replace function tests.quota_next_echo()
returns uuid
language sql security definer set search_path = public as $$
  select id from public.echoes
   where author_id <> auth.uid()
     and id not in (select echo_id from public.kenos_reads where reader_id = auth.uid())
   limit 1
$$;
create or replace function tests.quota_first_ring()
returns uuid
language sql security definer set search_path = public as $$
  select id from public.kenos_constellations
   where curated_by = 'QUOTA TEST' limit 1
$$;
create or replace function tests.quota_next_ring()
returns uuid
language sql security definer set search_path = public as $$
  select c.id from public.kenos_constellations c
   where c.curated_by = 'QUOTA TEST' and c.state = 'CLOSED'
     and c.id not in (select constellation_id from public.kenos_constellation_reads
                       where reader_id = auth.uid())
   limit 1
$$;

grant execute on all functions in schema tests to authenticated;

select tests.quota_seed_echoes(62);
select tests.quota_seed_rings(151);

-- ── A. The echo quota: 60 lights a day, then the ether refuses ────────
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000c1","role":"authenticated"}', true);

select is(
  tests.quota_drain_echoes(60),
  60,
  'sixty lights taken in one day — the vigil is long already'
);
select throws_ok(
  $$select public.consume_echo(tests.quota_next_echo())$$,
  'P0001', 'KENOS_DAILY_QUOTA',
  'the 61st light of the day is refused — no hand empties the ether'
);

-- ── B. The quota is per hand: another stranger still reads ────────────
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000c2","role":"authenticated"}', true);
select is(
  (select public.consume_echo(tests.quota_next_echo()) is not null),
  true,
  'a fresh hand still reads — the measure is per traveller'
);

-- ── C. The ring quota: 150 distinct rings, then refusal ───────────────
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000c1","role":"authenticated"}', true);
select is(
  tests.quota_read_rings(150),
  150,
  '150 distinct artifacts read in one day'
);
select throws_ok(
  $$select public.read_constellation(tests.quota_next_ring())$$,
  'P0001', 'KENOS_DAILY_QUOTA',
  'the 151st new artifact of the day is refused'
);

-- ── D. Re-reads are free: an artifact is a place, not a consumable ────
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000c3","role":"authenticated"}', true);
select lives_ok(
  $$select public.read_constellation(tests.quota_first_ring())$$,
  'first read of an artifact'
);
select lives_ok(
  $$select public.read_constellation(tests.quota_first_ring())$$,
  'coming back to it is free — the artifact stays'
);
reset role;
select is(
  (select count(*) from public.kenos_constellation_reads
    where reader_id = '00000000-0000-4000-8000-0000000000c3'::uuid),
  1::bigint,
  'a re-read adds no row: the count is distinct rings'
);

select * from finish();
rollback;
