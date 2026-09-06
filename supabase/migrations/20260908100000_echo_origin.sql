-- ═══════════════════════════════════════════════════════════════════════
-- KENOS — l'origine (V3.26): every echo may carry the name of its
-- shore.
--
-- The author OPTS IN at the Mirror ("NOMMER L'ORIGINE"): the browser
-- resolves a coarse label (pays · région · ville) and sends it with
-- the launch. The ether stores it as plain metadata the AUTHOR chose
-- to make public-to-the-reader — the intimate text stays sealed as
-- ever, and the label is served ONLY inside the atomic consumption
-- bundle: never on the map, never in any fetch, so scraping the sky
-- can never learn where a light was born.
--
-- The reader's reveal gains the story: "PARTI DE …" next to the
-- drift telemetry, and "LANCÉ À X A.L. DE TON ŒIL" (client-side,
-- from the launch coordinates to the eye at interception).
--
-- p_origin defaults to '' (already-deployed clients keep their
-- eight-argument call) and is bounded at 96 characters.
-- ═══════════════════════════════════════════════════════════════════════

alter table public.echoes
    add column if not exists origin_label text not null default '';

-- ── launch_echo v-next: the shore's name rides with the seal ───────────
-- REPLACE, never overload: a second launch_echo with an extra default
-- argument would make every existing eight-argument call (and every
-- deployed client's named-argument RPC) ambiguous — Postgres refuses
-- to choose between overloads.
drop function if exists public.launch_echo(
    text, text, double precision, double precision, double precision,
    text, text, text
);

create or replace function public.launch_echo(
    p_ciphertext text, p_key text, p_x double precision, p_y double precision,
    p_z double precision, p_theme text, p_media_kind text, p_media_path text,
    p_origin text default ''
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
    if length(coalesce(p_origin, '')) > 96 then
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
    insert into public.echoes (author_id, encrypted_text, key_seal, coord_x, coord_y, coord_z, color_theme, media_kind, media_path, origin_label)
    values (uid, p_ciphertext, case when key = '' then '' else encode(pgp_sym_encrypt(key, public.kenos_ether_kek()), 'base64') end, p_x, p_y, p_z, p_theme, p_media_kind, p_media_path, coalesce(p_origin, ''))
    returning public.echoes.id, public.echoes.created_at into new_id, ts;
    -- Observatory: one launch counted, contentless, same transaction.
    perform public.kenos_metrics_touch('launched');
    return query select new_id, ts;
end;
$$;
revoke all on function public.launch_echo(text, text, double precision, double precision, double precision, text, text, text, text) from public, anon;
grant execute on function public.launch_echo(text, text, double precision, double precision, double precision, text, text, text, text) to authenticated;

-- ── consume_echo v-next: the winner learns where the light was born ────
create or replace function public.consume_echo(target_echo_id uuid)
returns jsonb
language plpgsql
security definer
-- pgcrypto lives in the `extensions` schema on Supabase.
set search_path = public, extensions
as $$
declare
    echo_content  text;
    echo_author   uuid;
    echo_created  timestamptz;
    echo_key      text;
    echo_momentum integer;
    media_path    text;
    media_kind    text;
    echo_theme    varchar(20);
    echo_origin   text;
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

    -- The day's measure (V3.22): 60 lights a day per hand — no one
    -- empties the ether for everyone else.
    if (
        select count(*) from public.kenos_reads r
        where r.reader_id = auth.uid()
          and r.read_at > current_date
    ) >= 60 then
        raise exception 'KENOS_DAILY_QUOTA';
    end if;

    -- Lock the row, excluding one's own echo (untouchable).
    select e.encrypted_text, e.author_id, e.created_at, e.key_seal,
           e.momentum, e.media_path, e.media_kind, e.color_theme,
           e.origin_label
      into echo_content, echo_author, echo_created, echo_key,
            echo_momentum, media_path, media_kind, echo_theme,
            echo_origin
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

    -- The lineage: the reader's 10-minute window to re-seal it —
    -- carrying the parent's theme (the parent is destroyed below, the
    -- phoenix must inherit its color from HERE).
    insert into public.kenos_lineages (echo_id, momentum, color_theme, read_by)
    values (target_echo_id, echo_momentum, coalesce(echo_theme, 'TEAL'), auth.uid())
    on conflict (echo_id) do nothing;

    -- Bottle-in-the-sea signal for the author.
    insert into public.kenos_receptions (echo_id, author_id, drift_seconds)
    values (
        target_echo_id,
        echo_author,
        extract(epoch from (now() - echo_created))::bigint
    )
    on conflict (echo_id) do nothing;

    -- Observatory: one consumption counted, contentless, same
    -- transaction (rolls back with it — the burn and the count are one).
    perform public.kenos_metrics_touch('consumed');

    return jsonb_build_object(
        'ciphertext', echo_content,
        'key', case when echo_key = '' then null
                    else pgp_sym_decrypt(decode(echo_key, 'base64'), public.kenos_ether_kek())
        end,
        'momentum', echo_momentum,
        'origin', nullif(echo_origin, '')
    ) || case when media_path is null then '{}'::jsonb
              else jsonb_build_object('media_path', media_path, 'media_kind', media_kind)
         end;
end;
$$;

revoke all on function public.consume_echo(uuid) from public, anon;
grant execute on function public.consume_echo(uuid) to authenticated;
