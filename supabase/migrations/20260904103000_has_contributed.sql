-- ═══════════════════════════════════════════════════════════════════════
-- KENOS — migration 0019 : has_contributed (the sky asks the truth)
--
-- The live report: the app kept OFFERING composition to hands that
-- had already given, then the ether refused — frustrating loop. The
-- device's local memory heals at the first refusal, but only the
-- ETHER knows across devices and sessions. One quiet boolean, asked
-- at the tap: has THIS stranger already given to THIS corpse?
--
--  Contentless by construction (a boolean about a row's existence —
--  never a line, never an author). RLS-everything, authenticated
--  only, same grammar as every lifecycle RPC.
-- ═══════════════════════════════════════════════════════════════════════

create function public.has_contributed(p_constellation_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
    select exists (
        select 1
          from public.kenos_constellation_lines l
         where l.constellation_id = p_constellation_id
           and l.contributor_id = auth.uid()
    )
$$;

revoke all on function public.has_contributed(uuid)
    from public, anon;
grant execute on function public.has_contributed(uuid)
    to authenticated;
