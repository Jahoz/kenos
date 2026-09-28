-- ═══════════════════════════════════════════════════════════════════════
-- KENOS — sow the generated sky (production companion to prod_reset)
--
-- The launch reset leaves an honest but EMPTY ether — the fear of
-- the void is real. This sows 360 drifting echoes from the same
-- generator pool as the local load seed (tool/gen_load_payloads.dart
-- → staging table), so every star is a REAL client-format sealed
-- confidence: the first stranger to intercept one opens it on
-- device, exactly like a live echo, then it is gone for good.
--
--   * 48 anonymous seed authors ('sky-NNNN@seed.kenos.local'). The
--     future wipe predicate is 'sky-%@seed.kenos.local' — NOT the
--     whole seed namespace: the curated hands share it.
--   * Deterministic ids (md5('kenos-sky-…')) → idempotent re-sows.
--   * V3.83-sow — THE CROWD LAW: ages spread AREA-UNIFORM across the
--     memory moon (none older than 27 days, a 3-day margin from the
--     purge), so the courts fill to their rim — a first 14-day
--     young-skewed sow packed every star into the inner half of its
--     court and the sky read as three BLOBS, not crowds ("ils
--     s'agglutinent un peu trop", the live report). The elder rim
--     pales with the aging law by design: youth glows close, age
--     recedes dim. The crowd decays honestly — half purges within a
--     fortnight; re-sow to replenish.
--   * 300 stars (V3.83: 360 → 300) at 42/33/25 TEAL/INDIGO/LUMEN —
--     La Lune's court held 207 at 55% teal; ~126 reads as a rich
--     halo, not a mass. TEAL/INDIGO/LUMEN only (ROSE stays
--     destruction-only); z spread; NO media doors and NO rebound
--     momentum — generated stars are confidences to read, not
--     slings or doors pointing at nothing.
--   * REFUSES to run without staged payloads: the prod sky must
--     never ship dead stars (random-bundle fallback is local-only).
--
-- Staging (make prod-sow does all three steps):
--   dart run tool/gen_load_payloads.dart 360 > /tmp/kenos_sky_payloads.csv
--   bash scripts/prod_admin.sh stage /tmp/kenos_sky_payloads.csv
--   bash scripts/prod_admin.sh file supabase/snippets/prod_sow.sql
--
-- Report after (scripts/prod_admin.sh sql "…"):
--   select (select count(*) from public.echoes) as echoes,
--          (select count(*) from public.kenos_constellations) as rings,
--          (select count(*) from public.kenos_vestiges) as vestiges;
-- ═══════════════════════════════════════════════════════════════════════

do $sow_sky$
declare
    n_users    int := 48;
    n_alive    int := 300;
    n_payloads int := 0;
    i          int;
    k          int;
    v          double precision;
    x          double precision;
    y          double precision;
    author     uuid;
    theme      text;
    sealed_key text;
    sealed_ct  text;
begin
    -- Idempotent re-sow: clear only OUR namespace, never the
    -- curated hands or anything a stranger wrote.
    delete from public.echoes
     where id in (select md5('kenos-sky-echo-' || s)::uuid
                  from generate_series(1, 5000) s);
    delete from auth.users where email like 'sky-%@seed.kenos.local';

    -- Prod skies are readable or not shipped at all.
    if to_regclass('public.kenos_load_payloads') is null then
        raise exception 'staging table missing — run prod_admin.sh stage first (dead stars are a local-only fallback)';
    end if;
    select count(*) into n_payloads from public.kenos_load_payloads;
    if n_payloads = 0 then
        raise exception 'staging table empty — stage payloads first';
    end if;

    perform public.kenos_ether_kek();
    perform setseed(0.20260904);

    -- The authors: joined over the same moon as their echoes.
    for i in 1..n_users loop
        v := 27 * random();
        insert into auth.users (
            id, instance_id, aud, role, email,
            email_confirmed_at,
            raw_app_meta_data, raw_user_meta_data,
            created_at, updated_at, is_anonymous
        ) values (
            md5('kenos-sky-user-' || i)::uuid,
            '00000000-0000-0000-0000-000000000000',
            'anonymous', 'authenticated',
            'sky-' || lpad(i::text, 4, '0') || '@seed.kenos.local',
            now() - v * interval '1 day',
            jsonb_build_object('provider', 'anonymous', 'providers', array['anonymous'], 'kenos_sky_seed', true),
            jsonb_build_object('kenos_sky_seed', true),
            now() - v * interval '1 day', now() - v * interval '1 day',
            true
        );
    end loop;

    for i in 1..n_alive loop
        -- V3.83 — THE CROWD LAW: age uniform in AREA over the court
        -- (aphelion A = 0.03 + 0.12·age/30; A²-linear in the draw
        -- spreads the crowd to the rim, none older than 27 d).
        v := 27 * (sqrt(0.0009 + 0.0216 * random()) - 0.03) / 0.12;

        -- Sky: mostly uniform, two soft lived-in clusters.
        k := floor(random() * 25);
        if k < 22 then
            x := random(); y := random();
        elsif k < 24 then
            x := 0.32 + sqrt(-2 * ln(greatest(random(), 1e-12))) * cos(2 * pi() * random()) * 0.03;
            y := 0.68 + sqrt(-2 * ln(greatest(random(), 1e-12))) * sin(2 * pi() * random()) * 0.03;
        else
            x := 0.70 + sqrt(-2 * ln(greatest(random(), 1e-12))) * cos(2 * pi() * random()) * 0.025;
            y := 0.30 + sqrt(-2 * ln(greatest(random(), 1e-12))) * sin(2 * pi() * random()) * 0.025;
        end if;
        x := least(greatest(x, 0), 1);
        y := least(greatest(y, 0), 1);

        -- Few authors own most of the sky (power-law), like a real one.
        author := md5('kenos-sky-user-' || (1 + floor(power(random(), 0.45) * n_users)))::uuid;

        -- V3.83 — the crowd rebalanced: 42/33/25 (La Lune held 207 of
        -- 360 at the old 55% — her court read as a mass, not a halo).
        -- NB: two independent draws — the second threshold is
        -- conditional (0.33/0.58 ≈ 0.57), not the target share.
        if random() < 0.42 then
            theme := 'TEAL';
        elsif random() < 0.57 then
            theme := 'INDIGO';
        else
            theme := 'LUMEN';
        end if;

        select p.key_b64, p.payload_b64 into sealed_key, sealed_ct
          from public.kenos_load_payloads p
         where p.seq = ((i - 1) % n_payloads) + 1;

        insert into public.echoes (
            id, author_id, encrypted_text, key_seal,
            coord_x, coord_y, coord_z, color_theme, created_at,
            media_kind, media_path, parent_id, momentum
        ) values (
            md5('kenos-sky-echo-' || i)::uuid, author,
            sealed_ct,
            encode(pgp_sym_encrypt(sealed_key, public.kenos_ether_kek()), 'base64'),
            x, y, 0.05 + 0.95 * random(), theme,
            now() - v * interval '1 day',
            null, null, null, 0
        );
    end loop;

    -- The staging table is transient by contract.
    drop table public.kenos_load_payloads;

    raise notice 'SKY SOWN: % echoes by % authors', n_alive, n_users;
end
$sow_sky$;
