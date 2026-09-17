-- ═══════════════════════════════════════════════════════════════════════
-- KENOS — migration : the second key (V3.53, B2 arbitré Hugo 2026-09-16)
--
-- A salon's one link dies with its ring — and a guest who never comes
-- condemned their seat: the target would never be reached, the ring
-- would die at day seven with the seeder watching. The arbitration:
-- the SEEDED may cut a NEW key while the ring has received ZERO
-- lines. The door was never touched — nobody is replaced. The moment
-- one line exists, the key is immutable again: a guest who came is a
-- guest forever.
--
--  THE LAWS THAT HOLD:
--   UN SEUL LIEN VIVANT: the update swaps the fingerprint — the old
--   key dies in the same transaction the new one is born. At any
--   instant the ring has exactly one living key (a dump still holds
--   no door: only sha256, as ever).
--   SEEDER ONLY, ZERO LINES ONLY: absent, not-yours and public rings
--   all answer KENOS_NOT_FOUND — the same silence the door has always
--   kept (nothing leaks: not even that a ring is a salon).
--   THE CLAIM IS STILL THE CONTRIBUTION: nothing changes for guests —
--   the key is checked inside contribute_line/peek exactly as before.
--   The 7-day life is untouched: a new key does not revive an old
--   ring, the link dies with it as always.
--
--  No new metric: a key rotation is not a lifecycle event (nothing
--  entered the ether). The anchor on the seeder's device is the
--  client's to refresh — the base never knows a door is held.
-- ═══════════════════════════════════════════════════════════════════════

create or replace function public.reseed_salon_key(p_constellation_id uuid)
returns text
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
    uid      uuid := auth.uid();
    v_state  varchar;
    v_hash   text;
    v_seeder uuid;
    v_lines  integer;
    v_token  text;
begin
    if uid is null then
        raise exception 'KENOS_UNAUTHENTICATED';
    end if;

    select c.state, c.invite_token_hash, c.seeder_id,
           (select count(*) from public.kenos_constellation_lines l
             where l.constellation_id = c.id)
      into v_state, v_hash, v_seeder, v_lines
      from public.kenos_constellations c
     where c.id = p_constellation_id
       for update;

    -- The door's silence: a ring that does not exist, a public ring,
    -- and a salon that is not the caller's are the same answer. Not
    -- even the existence of a door leaks.
    if v_state is null or v_hash is null or v_seeder is distinct from uid then
        raise exception 'KENOS_NOT_FOUND';
    end if;
    if v_state <> 'OPEN' then
        raise exception 'KENOS_CLOSED';
    end if;
    -- One line and the door has been touched: the guests who came are
    -- guests forever, a key cut now would replace nobody.
    if v_lines > 0 then
        raise exception 'KENOS_LINES_EXIST';
    end if;

    -- 16 random bytes, hex for the URL — the plaintext crosses the
    -- wire exactly once, to the seeder, exactly like the drop.
    v_token := encode(gen_random_bytes(16), 'hex');
    update public.kenos_constellations
       set invite_token_hash = encode(digest(v_token, 'sha256'), 'hex')
     where id = p_constellation_id;

    return v_token;
end;
$$;

revoke all on function public.reseed_salon_key(uuid)
    from public, anon;
grant execute on function public.reseed_salon_key(uuid)
    to authenticated;
