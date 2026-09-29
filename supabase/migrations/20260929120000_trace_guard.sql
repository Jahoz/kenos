-- ═══════════════════════════════════════════════════════════════════════
-- KENOS — migration : the Trace Guard (V3.88), the ether's only gate.
--
-- The trace is the ONLY user content the ether ever sees in clear —
-- and the only surface where server-side enforcement is possible
-- without betraying the sealed word. The care moments live on the
-- writer's device (CareGuard, V3.88); here lives the law's floor:
-- when a trace lands, a pg_net webhook hands it to the trace-guard
-- edge function (Llama Guard 4 via Groq, fail-open), and ONLY the
-- illegal floor (minors / non-consensual / child safety) is burned
-- through admin_burn_reception — before the author can ever fetch
-- it. Everything else stays: pain is not illegality, and censorship
-- is not care.
--
-- The operator wires it once (see the function's header):
--   insert into kenos_config (key, value) values
--     ('trace_guard_url',  'https://<ref>.supabase.co/functions/v1/trace-guard'),
--     ('trace_guard_token', '<same hex as the TRACE_GUARD_TOKEN secret>')
--   on conflict (key) do update set value = excluded.value;
-- Until then the trigger is a quiet no-op (empty URL = no call).
-- ═══════════════════════════════════════════════════════════════════════

-- ── The operator's shelf: URLs and shared tokens, nothing else. ───────
-- No RLS policy on purpose: every role is revoked to the bone — the
-- table speaks only to postgres (migrations, operator console) and
-- to the security-definer trigger that reads it.
create table if not exists public.kenos_config (
    key   text primary key check (key ~ '^[a-z_]+$'),
    value text not null default ''
);

alter table public.kenos_config enable row level security;
revoke all on public.kenos_config from anon, authenticated;

insert into public.kenos_config (key, value) values
    ('trace_guard_url', ''),
    ('trace_guard_token', '')
on conflict (key) do nothing;

-- ── The burn RPC: the guard's only hand. ──────────────────────────────
-- Service-role only (the edge function calls it with ctx.supabaseAdmin):
-- revoked from every client role. The text leaves the row entirely —
-- the reception survives (the author still learns their echo was
-- read), only the word is gone. No metric here, on purpose: burns
-- are rare security events — they live in the function's logs, not
-- in the product's contentless ledger.
create or replace function public.admin_burn_reception(p_echo_id uuid)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
    update public.kenos_receptions
       set reply_text = null
     where echo_id = p_echo_id
       and reply_text is not null;

    return found;
end;
$$;

revoke all on function public.admin_burn_reception(uuid)
    from public, anon, authenticated;

-- ── The webhook: one quiet call per trace, within the second. ─────────
create extension if not exists pg_net with schema extensions;

create or replace function public.kenos_trace_guard_notify()
returns trigger
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
    v_url   text;
    v_token text;
begin
    -- Only the moment a trace is BORN (null → text). Burns, reads and
    -- identity travels never wake the guard.
    if tg_op = 'UPDATE'
       and new.reply_text is not null
       and old.reply_text is null then
        select c.value into v_url
          from public.kenos_config c
         where c.key = 'trace_guard_url';
        select c.value into v_token
          from public.kenos_config c
         where c.key = 'trace_guard_token';

        if v_url is not null and v_url <> '' then
            perform net.http_post(
                url := v_url,
                headers := jsonb_build_object(
                    'Content-Type', 'application/json',
                    'x-kenos-token', coalesce(v_token, '')
                ),
                body := jsonb_build_object(
                    'echoId', new.echo_id,
                    'text', new.reply_text
                ),
                timeout_milliseconds := 5000
            );
        end if;
    end if;

    return coalesce(new, old);
end;
$$;

revoke all on function public.kenos_trace_guard_notify()
    from public, anon, authenticated;

create trigger kenos_trace_guard
    after update on public.kenos_receptions
    for each row execute function public.kenos_trace_guard_notify();
