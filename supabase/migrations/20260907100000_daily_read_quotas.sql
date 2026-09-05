-- ═══════════════════════════════════════════════════════════════════════
-- KENOS — daily read quotas (V3.22): no hand empties the ether for
-- the others.
--
-- A single account could burn a light every 5 s — 17 000 echoes a
-- day, a whole seeded sky gone by breakfast. The day now has a
-- measure, per hand:
--   * consume_echo: 60 lights a day (a long vigil already), counted
--     from kenos_reads of today — the audit journal already exists
--     and is purged daily, so the measure is free;
--   * read_constellation: 150 distinct rings a day, re-reads FREE
--     (a finished poem is an artifact — coming back to it is the
--     product, not a drain). Audited in kenos_constellation_reads,
--     PK (reader, ring): the count is distinct rings, naturally.
-- Unknown to the client, the error is the ether's usual refusal
-- (KENOS_DAILY_QUOTA).
-- ═══════════════════════════════════════════════════════════════════════

create table if not exists public.kenos_constellation_reads (
    reader_id        uuid not null references auth.users (id) on delete cascade,
    constellation_id uuid not null,
    read_at          timestamptz not null default now(),
    primary key (reader_id, constellation_id)
);
alter table public.kenos_constellation_reads enable row level security;
revoke all on public.kenos_constellation_reads from anon, authenticated;
create index if not exists idx_constellation_reads_read_at
    on public.kenos_constellation_reads (read_at desc);

-- ── consume_echo: the day's measure (body from the observatory
--    version, quota gated right after the 5 s anti-spam) ────────────────
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
           e.momentum, e.media_path, e.media_kind, e.color_theme
      into echo_content, echo_author, echo_created, echo_key,
            echo_momentum, media_path, media_kind, echo_theme
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
        'momentum', echo_momentum
    ) || case when media_path is null then '{}'::jsonb
              else jsonb_build_object('media_path', media_path, 'media_kind', media_kind)
         end;
end;
$$;

revoke all on function public.consume_echo(uuid) from public, anon;
grant execute on function public.consume_echo(uuid) to authenticated;

-- ── read_constellation: 150 distinct rings a day, re-reads free ────────
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

    -- The day's measure (V3.22): 150 distinct rings — revisiting an
    -- already-read artifact never counts (the audit is keyed to the
    -- PAIR, the insert below is a no-op on re-read).
    if (
        select count(*) from public.kenos_constellation_reads r
        where r.reader_id = auth.uid()
          and r.read_at > current_date
    ) >= 150 then
        raise exception 'KENOS_DAILY_QUOTA';
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

    insert into public.kenos_constellation_reads (reader_id, constellation_id)
    values (auth.uid(), p_constellation_id)
    on conflict (reader_id, constellation_id) do nothing;

    return jsonb_build_object('lines', coalesce(assembled, '[]'::jsonb));
end;
$$;

revoke all on function public.read_constellation(uuid) from public, anon;
grant execute on function public.read_constellation(uuid) to authenticated;

-- ── The reaper learns the new journal: ring reads live one day ─────────
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
end;
$$;
revoke all on function public.kenos_purge() from public, anon, authenticated;
