-- THE BROOM (2026-09-27): the nightly smoke signs one anonymous body
-- in through the app's own door (POST /auth/v1/signup, an empty body —
-- anonymity is the product), probes read-only surfaces, and — until
-- now — left that body in auth.users forever. Prod grew by one
-- traveller per night with no cleanup.
--
-- dissolve_body is the harness's broom: the CALLING body unmakes
-- ITSELF, nothing else. Two guards make it a broom rather than a
-- weapon:
--   - freshness: only bodies younger than fifteen minutes dissolve
--     (the smoke signs in, probes, and sweeps within seconds; a body
--     that lived keeps its place in the sky);
--   - emptiness: a body that wrote even one echo refuses — the broom
--     never burns content, it only closes unused doors.
-- Every kenos table cascades on auth.users delete (the schema's own
-- law), so a dissolved body leaves nothing behind. Historical harness
-- bodies predate the broom; they are contentless and age out of every
-- retention rule on their own.
--
-- Grammar note: called by scripts/smoke_prod.sh (§5), never from lib/
-- — like admin_sow_vestige_proposals, the caller lives outside the
-- Dart client on purpose.

create function public.dissolve_body()
returns void
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
    uid uuid := auth.uid();
begin
    if uid is null then
        raise exception 'KENOS_UNAUTHENTICATED';
    end if;
    if not exists (
        select 1 from auth.users u
         where u.id = uid
           and u.created_at > now() - interval '15 minutes'
    ) then
        raise exception 'KENOS_BODY_SETTLED';
    end if;
    if exists (select 1 from public.echoes e where e.author_id = uid) then
        raise exception 'KENOS_BODY_NOT_EMPTY';
    end if;
    delete from auth.users where id = uid;
end;
$$;

revoke all on function public.dissolve_body() from public, anon;
grant execute on function public.dissolve_body() to authenticated;
