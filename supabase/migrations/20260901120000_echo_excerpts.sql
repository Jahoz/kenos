-- KENOS — migration 0010 : the Excerpts (V3.10, cultural doors)
--
-- An echo may carry one external cultural excerpt — a Spotify track
-- (SONG) or a timestamped YouTube video (EXCERPT). Nothing is stored:
-- no bucket, no bytes, only a compact reference SEALED under the echo's
-- ephemeral key, exactly like the text. A database dump reveals neither
-- the confidence nor the taste that travelled with it.
--
-- Assumed price (same as the 280-char plaintext line): the server
-- cannot regex-validate a reference it never sees. It bounds the sealed
-- blob instead (32..512 base64 chars). Injection is impossible by
-- construction on the client: the raw string is never launched — the
-- winner parses it strictly and builds the canonical door URL.

-- Widen the media kind vocabulary: fragments (IMAGE/AUDIO, bucket)
-- and doors (SONG/EXCERPT, sealed reference inline).
alter table public.echoes
    drop constraint if exists echoes_media_kind_check;

alter table public.echoes
    add constraint echoes_media_kind_check
    check (media_kind in ('IMAGE', 'AUDIO', 'SONG', 'EXCERPT'));

create or replace function public.launch_echo(
    p_ciphertext text, p_key text, p_x double precision, p_y double precision,
    p_z double precision, p_theme text, p_media_kind text, p_media_path text
)
returns table (id uuid, created_at timestamptz)
language plpgsql security definer set search_path = public, extensions
as $$
declare uid uuid := auth.uid(); new_id uuid; ts timestamptz; key text := coalesce(p_key, '');
begin
    if uid is null then raise exception 'KENOS_UNAUTHENTICATED'; end if;
    if length(p_ciphertext) < 1 or length(p_ciphertext) > 4000 or length(key) > 256 then
        raise exception 'KENOS_INVALID_LENGTH';
    end if;
    if p_x < 0 or p_x > 1 or p_y < 0 or p_y > 1 or p_z < 0.05 or p_z > 1 then raise exception 'KENOS_INVALID_COORDS'; end if;
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
    insert into public.echoes (author_id, encrypted_text, key_seal, coord_x, coord_y, coord_z, color_theme, media_kind, media_path)
    values (uid, p_ciphertext, case when key = '' then '' else encode(pgp_sym_encrypt(key, public.kenos_ether_kek()), 'base64') end, p_x, p_y, p_z, p_theme, p_media_kind, p_media_path)
    returning public.echoes.id, public.echoes.created_at into new_id, ts;
    return query select new_id, ts;
end;
$$;
revoke all on function public.launch_echo(text, text, double precision, double precision, double precision, text, text, text) from public, anon;
grant execute on function public.launch_echo(text, text, double precision, double precision, double precision, text, text, text) to authenticated;
