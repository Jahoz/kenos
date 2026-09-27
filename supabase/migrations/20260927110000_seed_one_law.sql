-- ONE LAW PER DOOR (V3.77 completed).
--
-- V3.77 (20260925120000) widened every coordinate bound to [-0.6, 1.6]
-- and redeclared launch_echo and seed_constellation — under signatures
-- nobody calls (a 5-arg launch_echo(p_text, …) and a 2-arg
-- seed_constellation(x, y)). `create function` with a new argument
-- list does not replace: it ADDS. Prod ended up carrying FOUR laws for
-- two doors:
--
--   launch_echo(p_text, x, y, z, theme)          — zombie (V3.77): a
--     plaintext path into encrypted_text, never called by the client;
--   launch_echo(p_ciphertext, p_key, … 9 args)   — the living door,
--     still walled inside the old [0,1] square;
--   seed_constellation(x, y)                     — zombie (V3.77);
--   seed_constellation(x, y, p_kind, p_invited)  — the living salon
--     door, also still walled inside [0,1].
--
-- Two consequences the tests caught the moment anyone ran them: the
-- PostgREST ambiguity sentinel went red (two launch_echo overloads —
-- echo_origin.sql, never CI'd on this branch), and a 2-arg named call
-- stopped resolving at all (PGRST203, "could not choose the best
-- candidate" — the nightly smoke caught THAT on 2026-09-26). Worse:
-- the widened STORAGE law (table CHECKs accept [-0.6, 1.6]) was
-- unreachable by the app — every launch or seed past the old square
-- answered KENOS_INVALID_COORDS through the only doors the client
-- ever opens.
--
-- This migration completes the declared law: both zombies die, both
-- living doors carry the widened field. Bodies are the living ones,
-- verbatim — only the coordinate wall moves.

-- ── launch_echo: the zombie dies, the real door widens ──────────────────
drop function if exists public.launch_echo(text, double precision, double precision, double precision, text);

create or replace function public.launch_echo(
    p_ciphertext text,
    p_key text,
    p_x double precision,
    p_y double precision,
    p_z double precision,
    p_theme text,
    p_media_kind text default null,
    p_media_path text default null,
    p_origin text default ''
)
returns table (id uuid, created_at timestamptz)
language plpgsql
security definer
set search_path = public, extensions
as $$
declare uid uuid := auth.uid(); new_id uuid; ts timestamptz; key text := coalesce(p_key, '');
begin
    if uid is null then raise exception 'KENOS_UNAUTHENTICATED'; end if;
    if exists (select 1 from public.kenos_passed t where t.passed_uid = uid) then
        raise exception 'KENOS_BRAISE_PASSED';
    end if;
    if length(p_ciphertext) < 1 or length(p_ciphertext) > 4000 or length(key) > 256 then
        raise exception 'KENOS_INVALID_LENGTH';
    end if;
    if length(coalesce(p_origin, '')) > 96 then
        raise exception 'KENOS_INVALID_LENGTH';
    end if;
    -- V3.77: beyond the square — the same widened field as the
    -- storage CHECKs (a hair inside the camera's ±0.7 margin).
    if p_x < -0.6 or p_x > 1.6 or p_y < -0.6 or p_y > 1.6 or p_z < 0.05 or p_z > 1 then raise exception 'KENOS_INVALID_COORDS'; end if;
    if p_theme not in ('TEAL', 'INDIGO', 'LUMEN') then raise exception 'KENOS_INVALID_THEME'; end if;
    if (p_media_kind is null) <> (p_media_path is null)
            or (p_media_kind is not null and p_media_kind not in ('IMAGE', 'AUDIO', 'SONG', 'EXCERPT'))
            or (p_media_kind in ('IMAGE', 'AUDIO')
                and p_media_path !~ ('^' || uid::text || '/[0-9]+-(IMAGE|AUDIO)\.bin$'))
            or (p_media_kind in ('SONG', 'EXCERPT')
                and (length(p_media_path) < 32 or length(p_media_path) > 512
                     or p_media_path !~ '^[A-Za-z0-9+/]+={0,2}$')) then
        raise exception 'KENOS_INVALID_MEDIA';
    end if;
    if exists (select 1 from public.echoes e where e.author_id = uid and e.created_at > now() - interval '20 seconds') then raise exception 'KENOS_RATE_LIMIT'; end if;
    insert into public.echoes (author_id, encrypted_text, key_seal, coord_x, coord_y, coord_z, color_theme, media_kind, media_path, origin_label)
    values (uid, p_ciphertext, case when key = '' then '' else encode(pgp_sym_encrypt(key, public.kenos_ether_kek()), 'base64') end, p_x, p_y, p_z, p_theme, p_media_kind, p_media_path, coalesce(p_origin, ''))
    returning public.echoes.id, public.echoes.created_at into new_id, ts;
    -- Observatory: one launch counted, contentless, same transaction.
    perform public.kenos_metrics_touch('launched');
    return query select new_id, ts;
end;
$$;

revoke all on function public.launch_echo(text, text, double precision, double precision, double precision, text, text, text, text)
    from public, anon;
grant execute on function public.launch_echo(text, text, double precision, double precision, double precision, text, text, text, text)
    to authenticated;

-- ── seed_constellation: same surgery on the salon door ──────────────────
drop function if exists public.seed_constellation(double precision, double precision);

create or replace function public.seed_constellation(
    p_seed_x double precision,
    p_seed_y double precision,
    p_kind text default 'POEM',
    p_invited boolean default false
)
returns table (id uuid, invite_token text)
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
    uid        uuid := auth.uid();
    new_id     uuid;
    v_token    text := '';
    v_hash     text;
begin
    if uid is null then
        raise exception 'KENOS_UNAUTHENTICATED';
    end if;
    -- V3.77: beyond the square — the same widened field as every
    -- other coordinate law (storage CHECKs, launch, fetch).
    if p_seed_x < -0.6 or p_seed_x > 1.6 or p_seed_y < -0.6 or p_seed_y > 1.6 then
        raise exception 'KENOS_INVALID_COORDS';
    end if;
    if p_kind not in ('POEM', 'MELODY') then
        raise exception 'KENOS_INVALID_KIND';
    end if;
    -- Gentle cadence: one seed per 2 minutes per stranger.
    if exists (
        select 1 from public.kenos_constellations c
        where c.created_at > now() - interval '2 minutes'
          and c.id in (
            select constellation_id from public.kenos_constellation_lines
            where contributor_id = uid
          )
    ) then
        raise exception 'KENOS_RATE_LIMIT';
    end if;

    if p_invited then
        -- The key: 16 random bytes, hex-printable for a URL. Only its
        -- sha256 fingerprint is stored; the plaintext crosses the wire
        -- exactly once, to the seeder.
        v_token := encode(gen_random_bytes(16), 'hex');
        v_hash  := encode(digest(v_token, 'sha256'), 'hex');
    end if;

    insert into public.kenos_constellations (seed_x, seed_y, target_lines, kind, invite_token_hash)
    values (p_seed_x, p_seed_y, 4 + floor(random() * 4)::int, p_kind, v_hash)
    returning public.kenos_constellations.id into new_id;

    -- Observatory: one corpse seeded, contentless, same transaction —
    -- a salon is a corpse; the salon counter tells the two apart.
    perform public.kenos_metrics_touch('corpse_seeded');
    if p_invited then
        perform public.kenos_metrics_touch('salon_seeded');
    end if;

    return query select new_id, nullif(v_token, '');
end;
$$;

revoke all on function public.seed_constellation(double precision, double precision, text, boolean)
    from public, anon;
grant execute on function public.seed_constellation(double precision, double precision, text, boolean)
    to authenticated;
