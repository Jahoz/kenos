-- V3.77 — BEYOND THE SQUARE.
--
-- The storable sky was the server's [0,1]² square, and its WALLS had
-- become visible: content stopped along a rectangular boundary and
-- beyond lay only intersidereal void ("on se limite à un rectangle
-- virtuel", the live report). The traversable margin (±0.7) and the
-- dressed presence already extend past it — now the STORAGE does
-- too: every coordinate bound widens to [-0.6, 1.6], the vestige
-- spread law reaches r = 0.95 (past the old square's corners), and
-- the sky's silhouette becomes a field that thins, never a wall.
--
-- The known ether's heart stays [0,1]² — nothing moves inward, only
-- the ceiling rises.

-- ── The walls fall (table constraints) ────────────────────────────────
alter table public.echoes
    drop constraint if exists echoes_coord_x_check;
alter table public.echoes
    add constraint echoes_coord_x_check check (coord_x between -0.6 and 1.6);
alter table public.echoes
    drop constraint if exists echoes_coord_y_check;
alter table public.echoes
    add constraint echoes_coord_y_check check (coord_y between -0.6 and 1.6);

alter table public.kenos_constellations
    drop constraint if exists kenos_constellations_seed_x_check;
alter table public.kenos_constellations
    add constraint kenos_constellations_seed_x_check check (seed_x between -0.6 and 1.6);
alter table public.kenos_constellations
    drop constraint if exists kenos_constellations_seed_y_check;
alter table public.kenos_constellations
    add constraint kenos_constellations_seed_y_check check (seed_y between -0.6 and 1.6);

alter table public.kenos_vestiges
    drop constraint if exists kenos_vestiges_pos_x_check;
alter table public.kenos_vestiges
    add constraint kenos_vestiges_pos_x_check check (pos_x between -0.6 and 1.6);
alter table public.kenos_vestiges
    drop constraint if exists kenos_vestiges_pos_y_check;
alter table public.kenos_vestiges
    add constraint kenos_vestiges_pos_y_check check (pos_y between -0.6 and 1.6);

alter table public.kenos_frequencies
    drop constraint if exists kenos_frequencies_x_pos_check;
alter table public.kenos_frequencies
    add constraint kenos_frequencies_x_pos_check check (x_pos between -0.6 and 1.6);
alter table public.kenos_frequencies
    drop constraint if exists kenos_frequencies_y_pos_check;
alter table public.kenos_frequencies
    add constraint kenos_frequencies_y_pos_check check (y_pos between -0.6 and 1.6);

-- ── The gates open (RPC validations) ──────────────────────────────────
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
    -- V3.77: the sky's walls are gone — the traversable extent is the
    -- bound (a hair inside the camera's ±0.7 margin).
    if p_x < -0.6 or p_x > 1.6 or p_y < -0.6 or p_y > 1.6
       or p_z < 0.05 or p_z > 1 then
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
    returning public.echoes.id, public.echoes.created_at
    into new_id, ts;

    return query select new_id, ts;
end;
$$;

create function public.seed_constellation(
    p_seed_x double precision,
    p_seed_y double precision
)
returns table (id uuid)
language plpgsql
security definer
set search_path = public
as $$
declare
    uid uuid := auth.uid();
    new_id uuid;
begin
    if uid is null then
        raise exception 'KENOS_UNAUTHENTICATED';
    end if;
    -- V3.77: beyond the square (same widened bound).
    if p_seed_x < -0.6 or p_seed_x > 1.6 or p_seed_y < -0.6 or p_seed_y > 1.6 then
        raise exception 'KENOS_INVALID_COORDS';
    end if;
    -- Gentle cadence: one seed per 2 minutes per stranger.
    if exists (
        select 1 from public.kenos_constellations c
        where c.created_at > now() - interval '2 minutes'
          and c.id in (
            select constellation_id from public.kenos_constellation_lines
            where contributor_id = uid
          )
    ) then
        raise exception 'KENOS_RATE_LIMIT';
    end if;

    insert into public.kenos_constellations (seed_x, seed_y, target_lines)
    values (p_seed_x, p_seed_y, 4 + floor(random() * 4)::int)
    returning public.kenos_constellations.id into new_id;

    return query select new_id;
end;
$$;

-- ── The culture spreads FARTHER (r 0.60 -> 0.95, edge 0.45 -> 0.90) ──
create or replace function public.vestige_resting_place(p_seed double precision)
returns double precision[]
language sql
immutable
as $$
    -- V3.76 FIX: theta = 2pi * fract(s*e). Two traps died here: (1)
    -- V3.72 used the GOLDEN ANGLE as the multiplier — theta never
    -- exceeded 85 degrees (the whole library in the north-east
    -- quadrant); (2) even x 2pi, fract(s*phi) stays under 0.618 for
    -- every s in [0,1) — the south stayed empty. e (~2.718) wraps
    -- the seed twice: the angle truly spans the full circle.
    -- V3.77: the disc reaches 0.95 (past the old square's corners),
    -- capped by the WIDENED sky's true edge along the angle.
    with t as (
        select greatest(p_seed, 0)::double precision as u,
               (6.283185307179586 *
                (p_seed * 2.718281828459045
                 - floor(p_seed * 2.718281828459045)))::double precision as theta
    )
    select array[
        0.5 + least(0.95 * sqrt(u),
                    0.90 / greatest(abs(cos(theta)), 1e-9),
                    0.90 / greatest(abs(sin(theta)), 1e-9)) * cos(theta),
        0.5 + least(0.95 * sqrt(u),
                    0.90 / greatest(abs(cos(theta)), 1e-9),
                    0.90 / greatest(abs(sin(theta)), 1e-9)) * sin(theta)
    ]
    from t
$$;

-- ── The living library reseats itself under the wider law ─────────────
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
