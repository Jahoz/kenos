-- ═══════════════════════════════════════════════════════════════════════
-- KENOS — migration 0005 : the Symphonie crosses the ether (V3.2)
--
-- Waves are primal, wordless signals: a tap becomes a colored sound
-- that any stranger within a virtual hearing radius can feel. They
-- live for ONE MINUTE, then are gone from the universe — the only
-- ephemerality shorter than an echo's.
--
--  - kenos_frequencies: contentless by nature (an index into a public
--    pentatonic scale + a hue + a position). Never a message.
--  - emit_frequency: validated, rate-limited (3 waves / 5 s — chords
--    are allowed, floods are not).
--  - fetch_nearby_frequencies: normalized-space bbox hearing (a radius
--    over [0,1]² needs no PostGIS — documented in ROADMAP_V3 T3). Own
--    waves never come back: you already heard yourself.
--  - kenos_purge (v2, replaced in full per the forward-only policy):
--    now also sweeps waves older than 60 s.
-- ═══════════════════════════════════════════════════════════════════════

create table public.kenos_frequencies (
    id           uuid primary key default gen_random_uuid(),
    author_id    uuid not null references auth.users (id) on delete cascade,
    x_pos        double precision not null check (x_pos between 0 and 1),
    y_pos        double precision not null check (y_pos between 0 and 1),
    note_index   smallint not null check (note_index between 0 and 19),
    hue_index    smallint not null check (hue_index between 0 and 3),
    created_at   timestamptz not null default now()
);

create index idx_frequencies_created on public.kenos_frequencies (created_at desc);

alter table public.kenos_frequencies enable row level security;

-- RPC-only, like everything that breathes.
revoke all on public.kenos_frequencies from anon, authenticated;

-- ── RPC: emit a wave ────────────────────────────────────────────────────
create function public.emit_frequency(
    p_x          double precision,
    p_y          double precision,
    p_note_index smallint,
    p_hue_index  smallint
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
    uid uuid := auth.uid();
begin
    if uid is null then
        raise exception 'KENOS_UNAUTHENTICATED';
    end if;
    if p_x < 0 or p_x > 1 or p_y < 0 or p_y > 1 then
        raise exception 'KENOS_INVALID_COORDS';
    end if;
    if p_note_index < 0 or p_note_index > 19 or p_hue_index < 0 or p_hue_index > 3 then
        raise exception 'KENOS_INVALID_FREQUENCY';
    end if;
    -- Chords yes, floods no: at most 3 waves per 5 s per emitter.
    if (
        select count(*) from public.kenos_frequencies f
        where f.author_id = uid
          and f.created_at > now() - interval '5 seconds'
    ) >= 3 then
        raise exception 'KENOS_RATE_LIMIT';
    end if;

    insert into public.kenos_frequencies (author_id, x_pos, y_pos, note_index, hue_index)
    values (uid, p_x, p_y, p_note_index, p_hue_index);
end;
$$;

revoke all on function public.emit_frequency(
    double precision, double precision, smallint, smallint
) from public, anon;
grant execute on function public.emit_frequency(
    double precision, double precision, smallint, smallint
) to authenticated;

-- ── RPC: hear the nearby waves (never your own) ────────────────────────
create function public.fetch_nearby_frequencies(
    p_x     double precision default 0.5,
    p_y     double precision default 0.5,
    p_radius double precision default 0.35,
    p_limit  integer default 50
)
returns table (
    id          uuid,
    x_pos       double precision,
    y_pos       double precision,
    note_index  smallint,
    hue_index   smallint,
    created_at  timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
begin
    if auth.uid() is null then
        raise exception 'KENOS_UNAUTHENTICATED';
    end if;
    if p_radius <= 0 or p_radius > 1 then
        raise exception 'KENOS_INVALID_COORDS';
    end if;

    return query
    select f.id, f.x_pos, f.y_pos, f.note_index, f.hue_index, f.created_at
    from public.kenos_frequencies f
    where f.created_at > now() - interval '60 seconds'
      and f.author_id <> auth.uid()          -- you never hear yourself
      and f.x_pos >= p_x - p_radius
      and f.x_pos <= p_x + p_radius
      and f.y_pos >= p_y - p_radius
      and f.y_pos <= p_y + p_radius
    order by f.created_at desc
    limit greatest(1, least(p_limit, 100));
end;
$$;

revoke all on function public.fetch_nearby_frequencies(
    double precision, double precision, double precision, integer
) from public, anon;
grant execute on function public.fetch_nearby_frequencies(
    double precision, double precision, double precision, integer
) to authenticated;

-- ── kenos_purge v2 ──────────────────────────────────────────────────────
-- (superseded by 0006_purge_consolidation, which merges the concurrent
-- echo_reports block — kept here only so this migration stays
-- self-contained when read alone.)
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

    -- Unread receptions follow the echoes they describe.
    delete from public.kenos_receptions
    where read_at < now() - interval '30 days';

    -- Waves: one minute of life, then nothing remains.
    delete from public.kenos_frequencies
    where created_at < now() - interval '60 seconds';
end;
$$;

revoke all on function public.kenos_purge() from public, anon, authenticated;
