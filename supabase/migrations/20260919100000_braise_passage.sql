-- ═══════════════════════════════════════════════════════════════════════
-- KENOS — migration : LA BRAISE — the anonymous passage (V3.60)
--
-- A traveller holds no account: their identity is the anonymous session
-- living in one device's secure storage. When the body changes (new
-- phone, new browser), everything that body was dies with it — the
-- unread bottles addressed to its echoes, the doors it held, the rings
-- it seeded. LA BRAISE closes that hole WITHOUT inventing an account:
-- a hand-over, not a recovery.
--
-- Arbitrations (Hugo, 2026-09-19 — recommendations adopted):
--   THE LINK IS THE HAND-OVER: forged on the old body, opened on the
--   new one, both devices side by side. No email, no pseudonym, no
--   recovery factor — if the old body is gone, the ember dies with it
--   (assumed: kenos keeps no identity that outlives its body).
--   THE KEY IS A CAPABILITY: 16 random bytes, hex — the base stores
--   only its sha256 fingerprint and only for ten minutes. A dump holds
--   no identity, and after the claim even the fingerprint is gone
--   (the passage row is deleted in the claiming transaction).
--   THE CLAIM IS THE REMAP: the new anonymous session inherits what
--   the old body had addressed to it — unread receptions first, then
--   drifted echoes (so "the author never re-reads" keeps holding: they
--   stay excluded from the newcomer's own sky), seeded rings, given
--   lines, filed reports. Collisions (the new body had already touched
--   the same ring/report) keep the line with the old body: one
--   stranger, one line, no exception raised.
--   ONE LIVE EMBER: forging again kills the previous link; claiming
--   extinguishes the old body (KENOS_BRAISE_PASSED on launch_echo — a
--   dead body creates no new addressing; it may still read the sky
--   like any stranger).
--   THE LOCAL MEMORIES NEVER TOUCH THE WIRE: anchors, stats and guide
--   flags travel inside the link's #fragment (encrypted under the
--   passage key, HKDF → AES-256-GCM, on-device) — the server never
--   sees a byte of the ballot, exactly like the salon door key.
--
--  What stays sacred: single-read atomicity (echoes/encrypted_text/
--  key_seal untouched, consume_echo untouched), RPC-only access,
--  KENOS_* grammar, FOR UPDATE SKIP LOCKED, absent == fake.
-- ═══════════════════════════════════════════════════════════════════════

-- ── The passage: a fingerprint that dies in ten minutes ────────────────
create table if not exists public.kenos_passages (
    key_hash   text primary key,
    old_uid    uuid not null references auth.users (id) on delete cascade,
    forged_at  timestamptz not null default now(),
    expires_at timestamptz not null
);

comment on table public.kenos_passages is
    'La Braise: sha256 fingerprint of a one-shot passage key. Never the key.';

alter table public.kenos_passages enable row level security;
revoke all on public.kenos_passages from anon, authenticated;

-- ── The extinguished bodies: contentless, forever ──────────────────────
-- One row per transmitted body. It never purges: "a body that passed
-- its ember on stays dead" is an eternal invariant, and the row holds
-- nothing but a uid and a date.
create table if not exists public.kenos_passed (
    -- passed_uid, never uid: the plpgsql variable `uid := auth.uid()`
    -- is project grammar, and a same-named column makes every guard
    -- ambiguous.
    passed_uid uuid primary key references auth.users (id) on delete cascade,
    passed_at timestamptz not null default now()
);

comment on table public.kenos_passed is
    'La Braise: bodies that transmitted their ember. Contentless tombstones.';

alter table public.kenos_passed enable row level security;
revoke all on public.kenos_passed from anon, authenticated;

-- ── forge_passage: the old body hands its ember over ───────────────────
-- Returns the plaintext key ONCE (the salon grammar: the plaintext
-- crosses the wire exactly once, to the forger). Re-forging kills any
-- previous live link — one ember, one link.
create function public.forge_passage()
returns text
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
    uid    uuid := auth.uid();
    v_key  text;
    v_hash text;
begin
    if uid is null then
        raise exception 'KENOS_UNAUTHENTICATED';
    end if;
    if exists (select 1 from public.kenos_passed t where t.passed_uid = uid) then
        raise exception 'KENOS_BRAISE_PASSED';
    end if;

    delete from public.kenos_passages where old_uid = uid;

    v_key  := encode(gen_random_bytes(16), 'hex');
    v_hash := encode(digest(v_key, 'sha256'), 'hex');
    insert into public.kenos_passages (key_hash, old_uid, expires_at)
    values (v_hash, uid, now() + interval '10 minutes');

    return v_key;
end;
$$;

revoke all on function public.forge_passage() from public, anon;
grant execute on function public.forge_passage() to authenticated;

-- ── claim_passage: the new body receives the ember ─────────────────────
-- The claim is the remap, atomically. Missing, wrong, expired and
-- self-addressed keys raise the SAME error — the ember says nothing
-- about which body held it. Collisions keep the row with the old body
-- (one stranger, one line; the invariant never breaks, nothing throws).
create function public.claim_passage(p_key text)
returns void
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
    uid    uuid := auth.uid();
    v_old  uuid;
    v_hash text;
begin
    if uid is null then
        raise exception 'KENOS_UNAUTHENTICATED';
    end if;
    if exists (select 1 from public.kenos_passed t where t.passed_uid = uid) then
        raise exception 'KENOS_BRAISE_PASSED';
    end if;
    if p_key is null or length(p_key) < 16 or length(p_key) > 128 then
        raise exception 'KENOS_PASSAGE_UNKNOWN';
    end if;

    v_hash := encode(digest(p_key, 'sha256'), 'hex');
    select p.old_uid
      into v_old
      from public.kenos_passages p
     where p.key_hash = v_hash
       and p.expires_at > now()
       for update skip locked;

    if v_old is null or v_old = uid then
        raise exception 'KENOS_PASSAGE_UNKNOWN';
    end if;

    -- The heart: unread bottles follow the living body (view = burn
    -- keeps holding — reply_seen flags travel with the rows).
    update public.kenos_receptions
       set author_id = uid
     where author_id = v_old;

    -- Drifted echoes follow too, so the newcomer's own sky still hides
    -- what this being launched ("the author never re-reads": their
    -- echoes stay excluded from their map, exactly as before).
    update public.echoes
       set author_id = uid
     where author_id = v_old;

    -- Rings the body seeded (without this, reseed_salon_key would
    -- refuse the newcomer on their own salon).
    update public.kenos_constellations
       set seeder_id = uid
     where seeder_id = v_old;

    -- Lines given, reports filed, journals kept — each guarded against
    -- the PK collisions: if the new body already touched the same
    -- ring/echo/report, that row stays with the old body.
    update public.kenos_constellation_lines l
       set contributor_id = uid
     where l.contributor_id = v_old
       and not exists (
           select 1 from public.kenos_constellation_lines n
            where n.constellation_id = l.constellation_id
              and n.contributor_id = uid
       );

    update public.kenos_echo_reports r
       set reporter_id = uid
     where r.reporter_id = v_old
       and not exists (
           select 1 from public.kenos_echo_reports n
            where n.echo_id = r.echo_id
              and n.reporter_id = uid
       );

    update public.kenos_constellation_reports r
       set reporter_id = uid
     where r.reporter_id = v_old
       and not exists (
           select 1 from public.kenos_constellation_reports n
            where n.constellation_id = r.constellation_id
              and n.reporter_id = uid
       );

    update public.kenos_constellation_reads q
       set reader_id = uid
     where q.reader_id = v_old
       and not exists (
           select 1 from public.kenos_constellation_reads n
            where n.constellation_id = q.constellation_id
              and n.reader_id = uid
       );

    update public.kenos_reads k
       set reader_id = uid
     where k.reader_id = v_old
       and not exists (
           select 1 from public.kenos_reads n
            where n.echo_id = k.echo_id
              and n.reader_id = uid
       );

    update public.kenos_lineages
       set read_by = uid
     where read_by = v_old;

    update public.kenos_frequencies
       set author_id = uid
     where author_id = v_old;

    -- The old body is extinguished; the link is consumed — after this
    -- transaction even the fingerprint is gone.
    insert into public.kenos_passed (passed_uid, passed_at)
    values (v_old, now())
    on conflict (passed_uid) do nothing;

    delete from public.kenos_passages
     where key_hash = v_hash;
end;
$$;

revoke all on function public.claim_passage(text) from public, anon;
grant execute on function public.claim_passage(text) to authenticated;

-- ── launch_echo: an extinguished body creates no new addressing ────────
-- Same signature, one guard more. A passed body may still wander and
-- read like any stranger — it just cannot launch anymore (its future
-- receptions would address a dead uid).
create or replace function public.launch_echo(
    p_ciphertext text, p_key text, p_x double precision, p_y double precision,
    p_z double precision, p_theme text,
    p_media_kind text default null, p_media_path text default null,
    p_origin text default ''
)
returns table (id uuid, created_at timestamptz)
language plpgsql security definer set search_path = public, extensions
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

-- ── The reaper learns the ember: unclaimed passages die at ten minutes ──
create or replace function public.kenos_purge()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
    -- Drifting echoes: 30 days without interception, back to the void.
    delete from public.echoes
    where created_at < now() - interval '30 days';

    -- Audit journal: the trace window is 10 minutes, the read anti-spam
    -- 5 seconds — a day of retention is already generous.
    delete from public.kenos_reads
    where read_at < now() - interval '1 day';

    -- Ring reads follow the same day (the quota's journal IS the
    -- quota's memory — a new day, a new measure).
    delete from public.kenos_constellation_reads
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
    -- La Braise: an unclaimed link dies at ten minutes; the reaper
    -- sweeps the fingerprints the next hour it passes. kenos_passed
    -- never purges — an extinguished body stays extinguished.
    delete from public.kenos_passages
    where expires_at < now();
end;
$$;
revoke all on function public.kenos_purge() from public, anon, authenticated;
