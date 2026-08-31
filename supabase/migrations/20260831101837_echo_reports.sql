-- ═══════════════════════════════════════════════════════════════════════
-- KENOS — contentless moderation reports
-- A report contains no echo text and can only be filed by the reader who
-- atomically consumed that echo. It is not a social signal and is purged.
-- ═══════════════════════════════════════════════════════════════════════

create table public.kenos_echo_reports (
	echo_id     uuid not null,
	reporter_id uuid not null references auth.users (id) on delete cascade,
	reason_code text not null check (reason_code in ('INAPPROPRIATE', 'SPAM', 'DANGER', 'OTHER')),
	reported_at timestamptz not null default now(),
	primary key (echo_id, reporter_id)
);

create index idx_echo_reports_reported_at
	on public.kenos_echo_reports (reported_at desc);

alter table public.kenos_echo_reports enable row level security;
revoke all on public.kenos_echo_reports from anon, authenticated;

create or replace function public.report_echo(p_echo_id uuid, p_reason_code text)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
	if auth.uid() is null then
		raise exception 'KENOS_UNAUTHENTICATED';
	end if;
	if p_reason_code not in ('INAPPROPRIATE', 'SPAM', 'DANGER', 'OTHER') then
		raise exception 'KENOS_INVALID_REPORT_REASON';
	end if;

	-- A report is possible only for an echo the caller actually consumed,
	-- within the same short after-reading window as a trace.
	if not exists (
		select 1 from public.kenos_reads r
		where r.reader_id = auth.uid()
		  and r.echo_id = p_echo_id
		  and r.read_at > now() - interval '10 minutes'
	) then
		raise exception 'KENOS_RATE_LIMIT';
	end if;

	insert into public.kenos_echo_reports (echo_id, reporter_id, reason_code)
	values (p_echo_id, auth.uid(), p_reason_code)
	on conflict (echo_id, reporter_id) do nothing;

	return found;
end;
$$;

revoke all on function public.report_echo(uuid, text) from public, anon;
grant execute on function public.report_echo(uuid, text) to authenticated;

create or replace function public.kenos_purge()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
	delete from public.echoes
	where created_at < now() - interval '30 days';

	delete from public.kenos_reads
	where read_at < now() - interval '1 day';

	delete from public.kenos_receptions
	where read_at < now() - interval '30 days';

	delete from public.kenos_echo_reports
	where reported_at < now() - interval '30 days';
end;
$$;

revoke all on function public.kenos_purge() from public, anon, authenticated;
