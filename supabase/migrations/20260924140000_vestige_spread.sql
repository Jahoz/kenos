-- V3.72 — THE CULTURE SPREADS.
--
-- Every shard used to land on ONE ring (r = 0.32): the "golden
-- spiral" had collapsed into a circle — the radius never grew with
-- the seed, so the whole library ringed the jewel in the 0.03-wide
-- corridor between the planetary lanes (0.295–0.325). A second
-- asteroid belt of culture, visually imposing and using ~1% of the
-- sky's area ("les vestiges nombreux sont visuellement trop
-- imposants", the S25 report).
--
-- The new law mirrors the errant crowd's: uniform over the ether's
-- median — r = 0.60·√u (dense toward the system, thinning outward),
-- capped by the square's TRUE edge along the angle so nothing piles
-- on the walls. Deterministic from the shard's own id, forever.

-- ── The placement law, ONE home (immutable, callable anywhere) ────────
create or replace function public.vestige_resting_place(p_seed double precision)
returns double precision[]
language sql
immutable
as $$
    with t as (
        select greatest(p_seed, 0)::double precision as u,
               (2.399963229728653 *
                (p_seed * 0.6180339887498949
                 - floor(p_seed * 0.6180339887498949)))::double precision as theta
    )
    select array[
        -- r = least(the median's span, the square's edge on each axis)
        0.5 + least(0.60 * sqrt(u),
                    0.45 / greatest(abs(cos(theta)), 1e-9),
                    0.45 / greatest(abs(sin(theta)), 1e-9)) * cos(theta),
        0.5 + least(0.60 * sqrt(u),
                    0.45 / greatest(abs(cos(theta)), 1e-9),
                    0.45 / greatest(abs(sin(theta)), 1e-9)) * sin(theta)
    ]
    from t
$$;

-- ── The sower rides the law ───────────────────────────────────────────
create or replace function public.admin_decide_vestige_proposal(
    p_proposal_id uuid,
    p_approve boolean
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
    p      public.kenos_vestige_proposals%rowtype;
    v_seed double precision;
    place  double precision[];
begin
    if auth.uid() is null then
        raise exception 'KENOS_UNAUTHENTICATED';
    end if;
    if not public.kenos_is_admin() then
        raise exception 'KENOS_FORBIDDEN' using errcode = '42501';
    end if;

    select * into p from public.kenos_vestige_proposals
     where id = p_proposal_id;
    if p.id is null then
        raise exception 'KENOS_NOT_FOUND';
    end if;

    if p_approve then
        -- A resting place for the shard, deterministic from its own
        -- id (V3.72: the spread law — one home, above). NB: ids are
        -- TEXT and the legacy corpus carries non-uuid ids ('v…') —
        -- md5 feeds the bit-cast hex that raw ids cannot.
        v_seed := abs(
            (('x' || substr(md5(p.id::text), 1, 8))::bit(32)::bigint % 2147483647)
        )::double precision / 2147483647;
        place := public.vestige_resting_place(v_seed);
        insert into public.kenos_vestiges (id, kind, text, source, pos_x, pos_y, locale)
        values (
            p.id::text,
            p.kind, p.text, p.source,
            place[1],
            place[2],
            'fr'
        );
        perform public.kenos_metrics_touch('vestige_published');
    end if;

    delete from public.kenos_vestige_proposals where id = p_proposal_id;
    return true;
end;
$$;

-- ── The living library reseats itself under the new law ───────────────
-- Deterministic per id (idempotent): the same shard always finds the
-- same sky. Kept shards (the reliquaire) live client-side with their
-- own stored anchors — they stay where their traveller kept them.
update public.kenos_vestiges v
   set pos_x = (public.vestige_resting_place(z.s))[1],
       pos_y = (public.vestige_resting_place(z.s))[2]
  from (
    select id,
           abs(
             (('x' || substr(md5(id::text), 1, 8))::bit(32)::bigint % 2147483647)
           )::double precision / 2147483647 as s
      from public.kenos_vestiges
  ) z
 where v.id = z.id;
