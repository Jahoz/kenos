-- ═══════════════════════════════════════════════════════════════════════
-- KENOS — migration 0002 : traces de réception (bouteille à la mer)
--
-- Product rule: NO discussion — only a one-way signal.
--  - When an echo is consumed, a contentless reception row is created for
--    its author (when it was read, how long it drifted).
--  - The reader may leave ONE short trace (<= 140 chars) within 10 minutes,
--    exactly once, no edit, no reply.
--  - The author sees each reception ONCE (view = burn).
-- ═══════════════════════════════════════════════════════════════════════

-- Reception rows: contentless by default, reply arrives later (one shot).
create table public.kenos_receptions (
    echo_id       uuid primary key,
    author_id     uuid not null references auth.users (id) on delete cascade,
    read_at       timestamptz not null default now(),
    drift_seconds bigint not null,
    reply_text    text,
    reply_seen    boolean not null default false
);

create index idx_receptions_author on public.kenos_receptions (author_id, read_at desc);

alter table public.kenos_receptions enable row level security;

-- Total lockdown: RPC-only access (consistent with `echoes`).
revoke all on public.kenos_receptions from anon, authenticated;

-- ── consume_echo: now records the reception for the author ─────────────
create or replace function public.consume_echo(target_echo_id uuid)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
    echo_content text;
    echo_author  uuid;
    echo_created timestamptz;
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
    select e.encrypted_text, e.author_id, e.created_at
      into echo_content, echo_author, echo_created
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

    return echo_content;
end;
$$;

revoke all on function public.consume_echo(uuid) from public, anon;
grant execute on function public.consume_echo(uuid) to authenticated;

-- ── Reader side: leave ONE trace, shortly after reading ────────────────
create or replace function public.leave_trace(p_echo_id uuid, p_text text)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
    if auth.uid() is null then
        raise exception 'KENOS_UNAUTHENTICATED';
    end if;
    if length(p_text) < 1 or length(p_text) > 140 then
        raise exception 'KENOS_INVALID_LENGTH';
    end if;

    -- Only the reader of THIS echo, within a short window after reading.
    if not exists (
        select 1 from public.kenos_reads r
        where r.reader_id = auth.uid()
          and r.echo_id = p_echo_id
          and r.read_at > now() - interval '10 minutes'
    ) then
        raise exception 'KENOS_RATE_LIMIT';
    end if;

    -- One shot: a trace already left can never be edited or replaced.
    update public.kenos_receptions
       set reply_text = p_text
     where echo_id = p_echo_id
       and reply_text is null;

    return found;
end;
$$;

revoke all on function public.leave_trace(uuid, text) from public, anon;
grant execute on function public.leave_trace(uuid, text) to authenticated;

-- ── Author side: unseen receptions (view = burn) ───────────────────────
create or replace function public.fetch_receptions()
returns table (echo_id uuid, read_at timestamptz, drift_seconds bigint, reply_text text)
language plpgsql
security definer
set search_path = public
as $$
begin
    if auth.uid() is null then
        raise exception 'KENOS_UNAUTHENTICATED';
    end if;

    return query
    select r.echo_id, r.read_at, r.drift_seconds, r.reply_text
    from public.kenos_receptions r
    where r.author_id = auth.uid()
      and not r.reply_seen
    order by r.read_at desc
    limit 20;
end;
$$;

revoke all on function public.fetch_receptions() from public, anon;
grant execute on function public.fetch_receptions() to authenticated;

-- Viewing a reception burns it (one look, then the void).
create or replace function public.burn_reception(p_echo_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
    if auth.uid() is null then
        raise exception 'KENOS_UNAUTHENTICATED';
    end if;

    update public.kenos_receptions
       set reply_seen = true
     where echo_id = p_echo_id
       and author_id = auth.uid();
end;
$$;

revoke all on function public.burn_reception(uuid) from public, anon;
grant execute on function public.burn_reception(uuid) to authenticated;
