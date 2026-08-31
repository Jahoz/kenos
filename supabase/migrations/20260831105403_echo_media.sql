-- Encrypted fragments are private objects. Clients can insert only into
-- their own prefix; reads and deletes are performed by consume-media.
insert into storage.buckets (id, name, public, file_size_limit)
values ('echo-media', 'echo-media', false, 1048576)
on conflict (id) do update set public = false, file_size_limit = 1048576;

create policy "kenos media upload only"
on storage.objects for insert to authenticated
with check (
	bucket_id = 'echo-media'
	and (storage.foldername(name))[1] = (select auth.uid()::text)
);

alter table public.echoes
	add column if not exists media_kind text check (media_kind in ('IMAGE', 'AUDIO')),
	add column if not exists media_path text;

create function public.launch_echo(
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
		 or (p_media_kind is not null and p_media_kind not in ('IMAGE', 'AUDIO'))
		 or (p_media_path is not null and p_media_path !~ ('^' || uid::text || '/[0-9]+-(IMAGE|AUDIO)\.bin$')) then
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

drop function public.fetch_map_sector(double precision, double precision, double precision, double precision, integer, integer);
create function public.fetch_map_sector(p_min_x double precision default 0, p_min_y double precision default 0, p_max_x double precision default 1, p_max_y double precision default 1, p_max_per_sector integer default 24, p_max_total integer default 400)
returns table (id uuid, coord_x double precision, coord_y double precision, coord_z double precision, color_theme varchar, created_at timestamptz, media_kind text)
language plpgsql security definer set search_path = public
as $$ begin
	if auth.uid() is null then raise exception 'KENOS_UNAUTHENTICATED'; end if;
	return query select s.id, s.coord_x, s.coord_y, s.coord_z, s.color_theme, s.created_at, s.media_kind from (
		select e.*, row_number() over (partition by e.sector_x, e.sector_y order by e.created_at desc) rn from public.echoes e
		where e.coord_x >= least(p_min_x,p_max_x) and e.coord_x <= greatest(p_min_x,p_max_x) and e.coord_y >= least(p_min_y,p_max_y) and e.coord_y <= greatest(p_min_y,p_max_y) and e.author_id <> auth.uid()
	) s where s.rn <= greatest(1, least(p_max_per_sector, 100)) order by s.created_at desc limit greatest(1, least(p_max_total, 1000));
end; $$;
revoke all on function public.fetch_map_sector(double precision, double precision, double precision, double precision, integer, integer) from public, anon;
grant execute on function public.fetch_map_sector(double precision, double precision, double precision, double precision, integer, integer) to authenticated;

create or replace function public.consume_echo(target_echo_id uuid)
returns jsonb language plpgsql security definer set search_path = public, extensions
as $$
declare echo_content text; echo_author uuid; echo_created timestamptz; echo_key text; path text; kind text;
begin
	if auth.uid() is null then raise exception 'KENOS_UNAUTHENTICATED'; end if;
	if exists (select 1 from public.kenos_reads r where r.reader_id=auth.uid() and r.read_at > now()-interval '5 seconds') then raise exception 'KENOS_RATE_LIMIT'; end if;
	select e.encrypted_text,e.author_id,e.created_at,e.key_seal,e.media_path,e.media_kind into echo_content,echo_author,echo_created,echo_key,path,kind from public.echoes e where e.id=target_echo_id and e.author_id<>auth.uid() for update skip locked;
	if not found then return null; end if;
	delete from public.echoes where id=target_echo_id;
	insert into public.kenos_reads(reader_id,echo_id) values(auth.uid(),target_echo_id);
	insert into public.kenos_receptions(echo_id,author_id,drift_seconds) values(target_echo_id,echo_author,extract(epoch from(now()-echo_created))::bigint) on conflict(echo_id) do nothing;
	return jsonb_build_object('ciphertext',echo_content,'key',case when echo_key='' then null else pgp_sym_decrypt(decode(echo_key,'base64'),public.kenos_ether_kek()) end)
		|| case when path is null then '{}'::jsonb else jsonb_build_object('media_path',path,'media_kind',kind) end;
end; $$;
