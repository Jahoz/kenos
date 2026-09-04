-- ═══════════════════════════════════════════════════════════════════════
-- KENOS — migration 0018 : the media orphan ledger (the sweeper's eyes)
--
-- The `echo-media` bucket grants INSERT-only, size-bounded (1 MiB)
-- uploads under each caller's own prefix — but NOTHING bounds the
-- NUMBER of objects. A hostile authenticated client could fill the
-- bucket without ever launching an echo (abandoned uploads), and a
-- storage hiccup in `consume-media` can leave a winner-less object
-- behind (the sealed text ships regardless; the fragment dissolves).
--
-- The storage catalog is write-protected on modern stacks
-- (storage.protect_delete trigger): deletes must go through the
-- Storage API, never SQL. The sweep is therefore two halves:
--
--   * THIS migration: kenos_list_media_orphans() — the honest list
--     (echo-media objects older than one day — an in-flight upload
--     takes seconds, never days — referenced by NO live echo; a live
--     echo's media is untouchable). Executable by the service role
--     ONLY: object names embed author ids, they are not for clients.
--   * supabase/functions/sweep-media: the Storage API half — list,
--     remove (metadata + blob), loop to drain. Invoked with the
--     service key; wire it beside kenos_purge (same pg_cron + pg_net
--     note as the purge itself).
--
-- Upload names are unique per attempt (`<uid>/<millis>-KIND.bin`):
-- a listing race can never orphan a just-launched echo's media.
-- kenos_purge itself stays untouched: it cannot and must not reach
-- into the storage catalog.
-- ═══════════════════════════════════════════════════════════════════════

create function public.kenos_list_media_orphans()
returns text[]
language sql
stable
security definer
set search_path = public
as $$
    select coalesce(array_agg(name order by name), '{}'::text[])
      from (
          select o.name
            from storage.objects o
           where o.bucket_id = 'echo-media'
             and o.created_at < now() - interval '1 day'
             and not exists (
                 select 1 from public.echoes e
                  where e.media_kind in ('IMAGE', 'AUDIO')
                    and e.media_path = o.name
             )
           limit 1000
      ) listed
$$;

revoke all on function public.kenos_list_media_orphans()
    from public, anon, authenticated;
grant execute on function public.kenos_list_media_orphans()
    to service_role;
