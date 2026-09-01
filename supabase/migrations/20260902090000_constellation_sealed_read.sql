-- ═══════════════════════════════════════════════════════════════════════
-- KENOS — migration 0011 : fix the sealed corpse reading (V3.11a)
--
-- consume_constellation assembled the winner's bundle with 'text' set
-- to pgp_sym_decrypt(key_seal) — THE KEY, not the poem. With sealed
-- lines (any real contributor), the single reader got the key twice
-- and the on-device AES-GCM open failed silently: every closed corpse
-- read as empty lines. Demo mode (plaintext) and the pgTAP suite
-- (plaintext fixtures) masked it.
--
-- The fix returns exactly what consume_echo returns: the client-sealed
-- ciphertext + the key unsealed from escrow. The poem is opened on the
-- winner's device only — the server still never sees a line in clear.
-- Same bundle shape, so already-deployed clients are healed too.
-- ═══════════════════════════════════════════════════════════════════════

create or replace function public.consume_constellation(p_constellation_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
    uid uuid := auth.uid();
    c_state varchar;
    assembled jsonb;
begin
    if uid is null then
        raise exception 'KENOS_UNAUTHENTICATED';
    end if;

    select c.state into c_state
    from public.kenos_constellations c
    where c.id = p_constellation_id
    for update;

    if c_state is null then
        raise exception 'KENOS_NOT_FOUND';
    end if;
    if c_state = 'OPEN' then
        raise exception 'KENOS_STILL_OPEN';
    end if;
    if c_state = 'CONSUMED' then
        return null;
    end if;

    -- The contributor NEVER reads the whole they helped write.
    if exists (
        select 1 from public.kenos_constellation_lines l
        where l.constellation_id = p_constellation_id
          and l.contributor_id = uid
    ) then
        raise exception 'KENOS_CONTRIBUTOR_BARRED';
    end if;

    -- Assemble for the winner's device: each line travels as the
    -- client-sealed ciphertext plus its key, unsealed from escrow.
    -- 'text' IS the ciphertext (consume_echo parity) — never a server
    -- decryption of the poem, which the server cannot perform.
    select jsonb_agg(
        jsonb_build_object(
            'line_number', l.line_number,
            'text', l.encrypted_text,
            'key', case when l.key_seal = '' then null
                        else pgp_sym_decrypt(decode(l.key_seal, 'base64'), public.kenos_ether_kek())
                   end
        ) order by l.line_number
    )
    into assembled
    from public.kenos_constellation_lines l
    where l.constellation_id = p_constellation_id;

    -- The corpse dissolves: lines AND constellation are gone.
    delete from public.kenos_constellation_lines
    where constellation_id = p_constellation_id;
    delete from public.kenos_constellations
    where id = p_constellation_id;

    return jsonb_build_object('lines', coalesce(assembled, '[]'::jsonb));
end;
$$;

revoke all on function public.consume_constellation(uuid)
    from public, anon;
grant execute on function public.consume_constellation(uuid)
    to authenticated;
