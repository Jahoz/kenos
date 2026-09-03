-- ═══════════════════════════════════════════════════════════════════════
-- KENOS — migration 0012 : the classic exquisite corpse rule (V3.13)
--
-- Two product arbitrations (Hugo, 2026-09-03):
--
--  1. THE PRECEDING LINE. A contributor now sees the line that came
--     right before theirs — the original surrealist rule: one
--     continues, never sees the whole. `contribute_line` returns a
--     jsonb bundle { count, previous } where previous carries the
--     highest-numbered line's client-sealed ciphertext plus its key,
--     unsealed from escrow INSIDE the contribution transaction (the
--     same one-shot key exchange consume did — now at writing time,
--     for exactly one line). The server still never sees any line
--     in clear. First contributor: previous = null.
--
--  2. THE FINISHED CORPSE IS AN ARTIFACT. A CLOSED constellation is
--     readable by EVERYONE — contributors included — and re-readable,
--     like the Vestiges. `read_constellation` replaces the single
--     destructive consume; `consume_constellation` remains as a thin
--     alias so already-deployed clients keep working (they read,
--     then find the corpse still on the map — the gentle truth).
--
--  Retention: the artifact lives a moon, not forever — kenos_purge
--  sweeps CLOSED corpses 30 days after they closed (the ether's
--  memory horizon). OPEN corpses keep their 7-day window.
--
--  What stays sacred: while OPEN nobody sees the whole (only the
--  preceding line circulates); no push, no live counters; zero
--  plaintext server-side.
-- ═══════════════════════════════════════════════════════════════════════

-- ── contribute_line v2: count + the preceding line's bundle ──────────
-- Return type changes (int → jsonb): drop & recreate, transactional.
drop function if exists public.contribute_line(uuid, text, text);

create function public.contribute_line(
    p_constellation_id uuid,
    p_ciphertext        text,
    p_key               text
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
    uid           uuid := auth.uid();
    lines_so_far  integer;
    target        integer;
    c_state       varchar;
    prev_ct       text;
    prev_key_seal text;
begin
    if uid is null then
        raise exception 'KENOS_UNAUTHENTICATED';
    end if;
    if length(p_ciphertext) < 1 or length(p_ciphertext) > 2000 then
        raise exception 'KENOS_INVALID_LENGTH';
    end if;
    if length(coalesce(p_key, '')) > 256 then
        raise exception 'KENOS_INVALID_LENGTH';
    end if;

    select c.state, c.target_lines into c_state, target
    from public.kenos_constellations c
    where c.id = p_constellation_id
    for update;

    if c_state is null then
        raise exception 'KENOS_NOT_FOUND';
    end if;
    if c_state <> 'OPEN' then
        raise exception 'KENOS_CLOSED';
    end if;

    -- The preceding line, captured BEFORE the insert: the highest
    -- line number so far. Its key leaves the escrow here, once,
    -- for this contributor only.
    select l.encrypted_text, l.key_seal
      into prev_ct, prev_key_seal
      from public.kenos_constellation_lines l
     where l.constellation_id = p_constellation_id
     order by l.line_number desc
     limit 1;

    begin
        insert into public.kenos_constellation_lines (
            constellation_id, contributor_id, line_number,
            encrypted_text, key_seal
        )
        values (
            p_constellation_id, uid,
            (select count(*) from public.kenos_constellation_lines
             where constellation_id = p_constellation_id) + 1,
            p_ciphertext,
            case when coalesce(p_key, '') = '' then ''
                 else encode(pgp_sym_encrypt(p_key, public.kenos_ether_kek()), 'base64')
            end
        );
    exception when unique_violation then
        raise exception 'KENOS_ALREADY_CONTRIBUTED';
    end;

    select count(*) into lines_so_far
    from public.kenos_constellation_lines
    where constellation_id = p_constellation_id;

    if lines_so_far >= target then
        update public.kenos_constellations
           set state = 'CLOSED', closed_at = now()
         where id = p_constellation_id;
    end if;

    return jsonb_build_object(
        'count', lines_so_far,
        'previous', case
            when prev_ct is null then null
            else jsonb_build_object(
                'text', prev_ct,
                'key', case when prev_key_seal = '' then null
                            else pgp_sym_decrypt(decode(prev_key_seal, 'base64'), public.kenos_ether_kek())
                       end
            )
        end
    );
end;
$$;

revoke all on function public.contribute_line(uuid, text, text)
    from public, anon;
grant execute on function public.contribute_line(uuid, text, text)
    to authenticated;

-- ── peek_previous_line: the tail of the poem, to continue it ─────────
-- The writer must SEE the line they continue — before giving theirs.
-- OPEN corpses only; exactly ONE line (the highest number), bundle
-- ciphertext + key. Peeking costs nothing; the whole stays blind.
create or replace function public.peek_previous_line(p_constellation_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
    c_state       varchar;
    prev_ct       text;
    prev_key_seal text;
begin
    if auth.uid() is null then
        raise exception 'KENOS_UNAUTHENTICATED';
    end if;

    select c.state into c_state
    from public.kenos_constellations c
    where c.id = p_constellation_id;

    if c_state is null then
        raise exception 'KENOS_NOT_FOUND';
    end if;
    if c_state <> 'OPEN' then
        raise exception 'KENOS_CLOSED';
    end if;

    select l.encrypted_text, l.key_seal
      into prev_ct, prev_key_seal
      from public.kenos_constellation_lines l
     where l.constellation_id = p_constellation_id
     order by l.line_number desc
     limit 1;

    if prev_ct is null then
        return null;  -- the poem has not started: the peeker opens it
    end if;

    return jsonb_build_object(
        'text', prev_ct,
        'key', case when prev_key_seal = '' then null
                    else pgp_sym_decrypt(decode(prev_key_seal, 'base64'), public.kenos_ether_kek())
               end
    );
end;
$$;

revoke all on function public.peek_previous_line(uuid)
    from public, anon;
grant execute on function public.peek_previous_line(uuid)
    to authenticated;

-- ── read_constellation: the artifact reading — anyone, any number ────
create or replace function public.read_constellation(p_constellation_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
    c_state  varchar;
    assembled jsonb;
begin
    if auth.uid() is null then
        raise exception 'KENOS_UNAUTHENTICATED';
    end if;

    select c.state into c_state
    from public.kenos_constellations c
    where c.id = p_constellation_id;

    if c_state is null then
        raise exception 'KENOS_NOT_FOUND';
    end if;
    if c_state = 'OPEN' then
        raise exception 'KENOS_STILL_OPEN';
    end if;

    -- No contributor bar, no destruction: the finished poem is an
    -- artifact. Each line travels as ciphertext + its key, unsealed
    -- from escrow — the poem opens on the reader's device only.
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

    return jsonb_build_object('lines', coalesce(assembled, '[]'::jsonb));
end;
$$;

revoke all on function public.read_constellation(uuid)
    from public, anon;
grant execute on function public.read_constellation(uuid)
    to authenticated;

-- ── consume_constellation: alias of read (deployed clients heal) ─────
-- Old clients call this after the tap; they now get a NON-destructive
-- read, and their post-reading map reload simply finds the artifact
-- still closed on the sky — the gentle truth of the new rule.
create or replace function public.consume_constellation(p_constellation_id uuid)
returns jsonb
language sql
security definer
set search_path = public, extensions
as $$
    select public.read_constellation(p_constellation_id);
$$;

revoke all on function public.consume_constellation(uuid)
    from public, anon;
grant execute on function public.consume_constellation(uuid)
    to authenticated;

-- ── kenos_purge v5: the artifact lives a moon ─────────────────────────
create or replace function public.kenos_purge()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
    delete from public.echoes
    where created_at < now() - interval '30 days';
    delete from public.kenos_reads
    where read_at < now() - interval '1 day';
    delete from public.kenos_receptions
    where read_at < now() - interval '30 days';
    delete from public.kenos_echo_reports
    where reported_at < now() - interval '30 days';
    delete from public.kenos_frequencies
    where created_at < now() - interval '60 seconds';
    delete from public.kenos_lineages
    where consumed_at < now() - interval '1 hour';
    -- Constellations that never closed: the poem goes back to the void.
    delete from public.kenos_constellations
    where state = 'OPEN' and created_at < now() - interval '7 days';
    -- Finished corpses: artifacts for a moon, then the ether forgets.
    delete from public.kenos_constellations
    where state = 'CLOSED' and closed_at < now() - interval '30 days';
end;
$$;

revoke all on function public.kenos_purge() from public, anon, authenticated;
