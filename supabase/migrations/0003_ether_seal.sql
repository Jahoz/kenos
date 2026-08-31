-- ═══════════════════════════════════════════════════════════════════════
-- KENOS — migration 0003 : real at-rest encryption (Ether Seal)
--
-- Until now `encrypted_text` carried PLAINTEXT: the name was a promise the
-- schema did not keep. This migration makes it real:
--
--  1. The author's device derives a random 256-bit ephemeral key per echo
--     and encrypts the text with AES-256-GCM BEFORE calling `launch_echo`.
--     The ether never sees the plaintext of what it carries.
--  2. The per-echo key is stored sealed (`key_seal`) under a key-encryption
--     key (KEK) held in Supabase Vault when available (cloud projects), with
--     a locked-table fallback for local stacks without Vault. A plain
--     `pg_dump` of `public` therefore yields ciphertext only.
--  3. `consume_echo` unseals the key INSIDE the same atomic transaction
--     that destroys the echo (FOR UPDATE SKIP LOCKED untouched): the key is
--     exchanged exactly once, at interception, to the single winner.
--
-- Honest trade-off (E2E price): the server can no longer validate plaintext
-- length/theme semantics — `launch_echo` now bounds the ciphertext instead.
-- The client UI keeps enforcing the 280-character line.
--
-- Backward compatibility: echoes launched before this migration keep
-- `key_seal = ''`; `consume_echo` then returns `key = null` and clients
-- treat `ciphertext` as plaintext (legacy passthrough).
-- ═══════════════════════════════════════════════════════════════════════

create extension if not exists pgcrypto;

-- Sealed per-echo key escrow ('' = legacy plaintext echo, pre-migration).
alter table public.echoes
    add column if not exists key_seal text not null default '';

-- ── Key-encryption key (KEK) ─────────────────────────────────────────────
-- Fallback store for stacks without Vault: no policy, no grants — only
-- the postgres/service role (i.e. SECURITY DEFINER functions) can touch it.
create table if not exists public.kenos_ether_kek (
    id     int primary key check (id = 1),
    secret text not null
);

alter table public.kenos_ether_kek enable row level security;
revoke all on public.kenos_ether_kek from anon, authenticated;

-- Lazily provisions the KEK and returns it. Prefers Supabase Vault
-- (`vault.decrypted_secrets`), falls back to the locked table above.
-- Never granted to clients: SECURITY DEFINER call sites only.
create or replace function public.kenos_ether_kek()
returns text
language plpgsql
security definer
set search_path = public, vault, extensions
as $$
declare
    secret text;
begin
    if to_regclass('vault.decrypted_secrets') is not null then
        select v.decrypted_secret into secret
        from vault.decrypted_secrets v
        where v.name = 'kenos_ether_kek';

        if secret is not null then
            return secret;
        end if;

        perform vault.create_secret(
            encode(gen_random_bytes(32), 'base64'),
            'kenos_ether_kek'
        );

        return (select v.decrypted_secret
                from vault.decrypted_secrets v
                where v.name = 'kenos_ether_kek');
    end if;

    -- No Vault on this stack: locked table it is.
    select k.secret into secret from public.kenos_ether_kek k where k.id = 1;
    if secret is not null then
        return secret;
    end if;

    insert into public.kenos_ether_kek (id, secret)
    values (1, encode(gen_random_bytes(32), 'base64'))
    on conflict (id) do nothing;

    return (select k.secret from public.kenos_ether_kek k where k.id = 1);
end;
$$;

revoke all on function public.kenos_ether_kek()
    from public, anon, authenticated;

-- ── RPC 1 (v2): launch a SEALED echo ────────────────────────────────────
-- Signature change (p_text → p_ciphertext + p_key): drop & recreate.
-- p_key = '' keeps the legacy plaintext path for ops tooling (e2e script).
drop function if exists public.launch_echo(
    text, double precision, double precision, double precision, text
);

create function public.launch_echo(
    p_ciphertext text,
    p_key        text,
    p_x          double precision,
    p_y          double precision,
    p_z          double precision,
    p_theme      text
)
returns table (id uuid, created_at timestamptz)
language plpgsql
security definer
-- pgcrypto lives in the `extensions` schema on Supabase: it MUST be in
-- the path or pgp_sym_encrypt is unresolved at runtime.
set search_path = public, extensions
as $$
declare
    uid     uuid := auth.uid();
    new_id  uuid;
    ts      timestamptz;
    key     text := coalesce(p_key, '');
begin
    if uid is null then
        raise exception 'KENOS_UNAUTHENTICATED';
    end if;
    -- E2E price: the ether bounds the sealed size, not the plaintext
    -- (280 UTF-8 chars → ~120 B ciphertext → ~160 chars base64; 4000 is
    -- a pure abuse bound, the client UI keeps enforcing the 280 line).
    if length(p_ciphertext) < 1 or length(p_ciphertext) > 4000 then
        raise exception 'KENOS_INVALID_LENGTH';
    end if;
    if length(key) > 256 then
        raise exception 'KENOS_INVALID_LENGTH';
    end if;
    if p_x < 0 or p_x > 1 or p_y < 0 or p_y > 1 or p_z < 0.05 or p_z > 1 then
        raise exception 'KENOS_INVALID_COORDS';
    end if;
    if p_theme not in ('TEAL', 'INDIGO', 'LUMEN') then
        raise exception 'KENOS_INVALID_THEME';
    end if;
    -- One echo at a time, every 20 seconds: friction as a feature.
    if exists (
        select 1 from public.echoes e
        where e.author_id = uid
          and e.created_at > now() - interval '20 seconds'
    ) then
        raise exception 'KENOS_RATE_LIMIT';
    end if;

    insert into public.echoes (
        author_id, encrypted_text, key_seal, coord_x, coord_y, coord_z, color_theme
    )
    values (
        uid,
        p_ciphertext,
        case when key = '' then ''
             else encode(pgp_sym_encrypt(key, public.kenos_ether_kek()), 'base64')
        end,
        p_x, p_y, p_z, p_theme
    )
    returning public.echoes.id, public.echoes.created_at
    into new_id, ts;

    return query select new_id, ts;
end;
$$;

revoke all on function public.launch_echo(
    text, text, double precision, double precision, double precision, text
) from public, anon;
grant execute on function public.launch_echo(
    text, text, double precision, double precision, double precision, text
) to authenticated;

-- ── RPC 2 (v3): atomic single read + one-shot key exchange ──────────────
-- Same reactor core (FOR UPDATE SKIP LOCKED, author shield, anti-spam,
-- contentless reception) — now returns a jsonb bundle:
--   { "ciphertext": <sealed payload>, "key": <per-echo key | null> }
-- The key transits exactly once, inside the winning transaction.
drop function if exists public.consume_echo(uuid);

create function public.consume_echo(target_echo_id uuid)
returns jsonb
language plpgsql
security definer
-- pgcrypto lives in the `extensions` schema on Supabase: it MUST be in
-- the path or pgp_sym_decrypt is unresolved at runtime.
set search_path = public, extensions
as $$
declare
    echo_content text;
    echo_author  uuid;
    echo_created timestamptz;
    echo_key     text;
begin
    if auth.uid() is null then
        raise exception 'KENOS_UNAUTHENTICATED';
    end if;

    -- Interception anti-spam: at most one read every 5 s.
    if exists (
        select 1 from public.kenos_reads r
        where r.reader_id = auth.uid()
          and r.read_at > now() - interval '5 seconds'
    ) then
        raise exception 'KENOS_RATE_LIMIT';
    end if;

    -- Lock the row, excluding one's own echo (untouchable).
    select e.encrypted_text, e.author_id, e.created_at, e.key_seal
      into echo_content, echo_author, echo_created, echo_key
    from public.echoes e
    where e.id = target_echo_id
      and e.author_id <> auth.uid()
    for update skip locked;

    if not found then
        return null;  -- already read elsewhere, already dissolved, or shielded.
    end if;

    delete from public.echoes where id = target_echo_id;

    insert into public.kenos_reads (reader_id, echo_id)
    values (auth.uid(), target_echo_id);

    -- Bottle-in-the-sea signal: the author will learn the echo was read,
    -- how long it drifted — contentless until an optional trace is left.
    insert into public.kenos_receptions (echo_id, author_id, drift_seconds)
    values (
        target_echo_id,
        echo_author,
        extract(epoch from (now() - echo_created))::bigint
    )
    on conflict (echo_id) do nothing;

    if echo_key = '' then
        -- Legacy echo (pre-migration): the client reads it as plaintext.
        return jsonb_build_object('ciphertext', echo_content, 'key', null);
    end if;

    return jsonb_build_object(
        'ciphertext', echo_content,
        'key', pgp_sym_decrypt(decode(echo_key, 'base64'), public.kenos_ether_kek())
    );
end;
$$;

revoke all on function public.consume_echo(uuid) from public, anon;
grant execute on function public.consume_echo(uuid) to authenticated;
