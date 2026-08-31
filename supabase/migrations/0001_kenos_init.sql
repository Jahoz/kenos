-- ═══════════════════════════════════════════════════════════════════════
-- KENOS — initial migration (run in the Supabase SQL Editor)
--
-- Security by design — improvements over the initial technical spec:
--  1. The spec planned `CREATE POLICY ... FOR SELECT USING (auth.uid() != author_id)`
--     on the `echoes` table: that exposed `encrypted_text` to ALL clients.
--     Here RLS + COLUMN-LEVEL grants make `encrypted_text` structurally
--     unreadable by clients: the role has no SELECT privilege on that
--     column, so even a modified view cannot leak it.
--  2. The map view uses `security_invoker = true` (no owner-RLS bypass,
--     per Supabase security guidance) and only reads granted columns.
--  3. `consume_echo` is hardened: `SET search_path` (SECURITY DEFINER
--     hijack protection), an `author_id <> auth.uid()` guard (one cannot
--     intercept one's own echo), and a `kenos_reads` journal (contentless
--     audit + anti-spam).
--  4. Insertion goes through `launch_echo`: validation (length, coordinate
--     bounds, theme) and rate limiting (1 echo / 20 s) server-side.
--  5. All writes are RPC-only: the table carries no INSERT/UPDATE/DELETE
--     policy and no write grants.
-- ═══════════════════════════════════════════════════════════════════════

create extension if not exists pgcrypto;

-- ── Main table ──────────────────────────────────────────────────────────
create table public.echoes (
    id             uuid primary key default gen_random_uuid(),
    author_id      uuid not null references auth.users (id) on delete cascade,
    encrypted_text text not null,
    coord_x        double precision not null check (coord_x between 0 and 1),
    coord_y        double precision not null check (coord_y between 0 and 1),
    coord_z        double precision not null check (coord_z between 0.05 and 1),
    color_theme    varchar(20) not null default 'TEAL',
    created_at     timestamptz not null default now()
);

create index idx_echoes_created_at on public.echoes (created_at desc);
create index idx_echoes_author_created on public.echoes (author_id, created_at desc);

-- Interception journal: contentless audit (the text does not survive),
-- used as anti-spam (a reader cannot empty the galaxy by spamming).
create table public.kenos_reads (
    reader_id uuid not null references auth.users (id) on delete cascade,
    echo_id   uuid not null,
    read_at   timestamptz not null default now(),
    primary key (reader_id, echo_id)
);

alter table public.echoes      enable row level security;
alter table public.kenos_reads enable row level security;

-- Rows are visible to authenticated clients (metadata is public in the
-- ether), but COLUMN-LEVEL grants below keep encrypted_text unreadable:
-- policies gate rows, grants gate columns. Both are needed.
create policy "echoes_metadata_visible"
    on public.echoes for select to authenticated
    using (true);

-- Writes are RPC-only: no INSERT/UPDATE/DELETE policy, no write grants.
revoke all on public.echoes      from anon, authenticated;
revoke all on public.kenos_reads from anon, authenticated;

-- Metadata columns only — encrypted_text is deliberately NOT granted.
grant select (id, coord_x, coord_y, coord_z, color_theme, created_at)
    on public.echoes to authenticated;

-- ── Stellar map view (metadata only) ────────────────────────────────────
-- security_invoker = true: the view executes as the CALLING role (no
-- owner-RLS bypass). It can only expose columns the caller may read:
-- even if someone later edits this view, encrypted_text stays
-- permission-denied for clients.
create or replace view public.echoes_map
with (security_invoker = true)
as
select id, coord_x, coord_y, coord_z, color_theme, created_at
from public.echoes;

grant select on public.echoes_map to authenticated;

-- ── RPC 1: launch an echo (validation + anti-spam) ──────────────────────
create or replace function public.launch_echo(
    p_text  text,
    p_x     double precision,
    p_y     double precision,
    p_z     double precision,
    p_theme text
)
returns table (id uuid, created_at timestamptz)
language plpgsql
security definer
set search_path = public
as $$
declare
    uid     uuid := auth.uid();
    new_id  uuid;
    ts      timestamptz;
begin
    if uid is null then
        raise exception 'KENOS_UNAUTHENTICATED';
    end if;
    if length(p_text) < 1 or length(p_text) > 280 then
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

    insert into public.echoes (author_id, encrypted_text, coord_x, coord_y, coord_z, color_theme)
    values (uid, p_text, p_x, p_y, p_z, p_theme)
    -- Table-qualified: unqualified id/created_at are ambiguous with the
    -- RETURNS TABLE output variables inside plpgsql.
    returning public.echoes.id, public.echoes.created_at
    into new_id, ts;

    return query select new_id, ts;
end;
$$;

revoke all on function public.launch_echo(text, double precision, double precision, double precision, text) from public, anon;
grant execute on function public.launch_echo(text, double precision, double precision, double precision, text) to authenticated;

-- ── RPC 2: THE reactor core — atomic single read ────────────────────────
-- `FOR UPDATE SKIP LOCKED`: two simultaneous readers on the same star, at
-- the very same millisecond — only one wins, the other gets NULL.
create or replace function public.consume_echo(target_echo_id uuid)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
    echo_content text;
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
    select e.encrypted_text into echo_content
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

    return echo_content;
end;
$$;

revoke all on function public.consume_echo(uuid) from public, anon;
grant execute on function public.consume_echo(uuid) to authenticated;

-- ── Optional: purge drifting echoes older than 30 days ──────────────────
-- (requires pg_cron enabled on the project)
-- select cron.schedule(
--   'kenos-purge',
--   '17 3 * * *',
--   $$ delete from public.echoes where created_at < now() - interval '30 days' $$
-- );
