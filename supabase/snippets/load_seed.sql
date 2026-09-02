-- ═══════════════════════════════════════════════════════════════════════
-- KENOS — load-ramp seed (montée en charge visualization)
--
-- PURPOSE
--   Flood a backend with REALISTIC, REPRODUCIBLE volume so the ramp-up
--   can be visualized both in the numbers (load_report.sql) and in the
--   app itself (dense galaxy, capped sectors, closed corpses, waves).
--   Covers every lifecycle case the schema knows about.
--
-- WHERE TO RUN
--   Local stack (recommended):
--     make db-seed-load            (or: supabase db query --local -f this)
--   Cloud/production SQL Editor: works unchanged, but think twice —
--   the nightly CI smoke test hits prod, and fake volume would pollute
--   the real ether. Local is the sandbox; see load_wipe.sql for the
--   clean reset either way.
--
-- DESIGN RULES (mirrors the migration invariants)
--   * Idempotent regeneration: the seed wipes its own previous run
--     first (marker email '%@seed.kenos.local', deterministic ids).
--   * Deterministic: setseed + md5-derived uuids → same galaxy twice.
--   * Themes are TEAL/INDIGO/LUMEN only — ROSE stays reserved for
--     destruction (SQL self-discipline: the RPC validates, raw
--     inserts must too).
--   * Sealed echoes carry a real pgp key escrow under the shared KEK
--     (kenos_ether_kek()). Their payloads are REAL client-format
--     AES-256-GCM bundles when the staging table
--     public.kenos_load_payloads exists (filled by `make db-seed-load`
--     via tool/gen_load_payloads.dart) — the winner can actually open
--     them on device. Without the staging table the seed falls back
--     to syntactically valid random bundles (metadata-only testing:
--     the stars render and cull, but reads are dead — run the make
--     target for a functional ether). Legacy plaintext echoes
--     (key_seal = '', real French text) keep the passthrough path.
--   * Consumed echoes are GONE from `echoes` by design — their wake
--     lives in receptions/reads/lineages/reports, exactly like prod.
--   * Ramp: daily volume grows ~13%/day compounded over 30 days
--     (≈ ×39 between oldest and newest day), users included.
--
-- VOLUME (tune the constants in the DECLARE block)
--   180 users · 4 200 drifting echoes (incl. 300 rebound heads) ·
--   6 500 consumed echoes (receptions) · 800 audit reads ·
--   200 lineages · 120 reports · 25 live waves · 90 constellations.
--   ~12k rows total — inserts in a couple of seconds.
-- ═══════════════════════════════════════════════════════════════════════

begin;

do $seed$
declare
    -- ── Tunable volumes ────────────────────────────────────────────────
    n_users            int := 180;
    n_alive            int := 4200;   -- echoes currently drifting
    n_rebound_heads    int := 300;    -- phoenix heads (subset of n_alive)
    n_dead             int := 6500;   -- consumed echoes (reception wake)
    n_reads            int := 800;    -- audit rows, kept < 24h like purge
    n_lineages_active  int := 40;     -- rebound window still open (< 10 min)
    n_lineages_stale   int := 160;    -- window closed, waiting for purge
    n_reports          int := 120;
    n_frequencies      int := 25;     -- waves live 60 s only
    n_constellations   int := 90;     -- open + closed, all < 7 days
    -- ── Ramp shape ─────────────────────────────────────────────────────
    ramp_days          double precision := 30;
    ramp_growth        double precision := 1.13;  -- +13%/day compounded
    g                  double precision := ln(1.13);
    -- ── French payload pools (UI language stays French) ────────────────
    texts              text[] := array[
        'je navigue dans le vide pour toi', 'il paraît que le silence aussi se partage',
        'j''ai peur du calme avant la vague', 'ce soir l''éther me semble immense',
        'je laisse ici ce que je ne dirai jamais', 'personne ne lira ceci, et c''est bien',
        'la ville dort, moi je dérive', 'un poids de moins, un poids de plus',
        'je pense à celle qui ne sait pas', 'le vide me répond toujours',
        'trois secondes pour te tenir, une vie pour te lâcher', 'j''écris pour disparaitre',
        'la nuit porte conseil, je lui porte mes restes', 'rien à demander, tout à poser',
        'je suis l''étoile que personne ne nomme', 'confié au hasard, enfin léger',
        'ceci n''est pas un message', 'la dérive est une forme de paix',
        'j''ai traversé ma journée, il reste ceci', 'que le premier venu respire avec moi'
    ];
    traces             text[] := array[
        'Reçu. Respiré. Merci.', 'porte-toi bien, inconnu', 'lu à l''aube, ça m''a tenu compagnie',
        'je te laisse le silence en retour', 'tes mots sont retombés quelque part',
        'merci d''avoir lancé ça', 'je garderai l''idée, pas l''auteur',
        'ça résonne plus que prévu', 'bonne dérive à toi', 'reçu cinq fois plus fort que prévu'
    ];
    corpse_lines       text[] := array[
        'et si le vide avait un rivage', 'nous y laisserions nos manteaux',
        'le froid y serait une langue', 'personne ne la parlerait entier',
        'chaque mot y perd son poids', 'la nuit s''y replie comme une voile',
        'et l''aube n''ose plus nommer', 'ce que le silence a gardé',
        'nous marchons sur la craie des étoiles', 'le ciel ferme ses portes doucement'
    ];
    -- ── Working vars ───────────────────────────────────────────────────
    i                  int;
    k                  int;
    i_x                int;
    v                  double precision;
    uid                uuid;
    x                  double precision;
    y                  double precision;
    age_days           double precision;
    drift_s            bigint;
    echo_id            uuid;
    author             uuid;
    reader             uuid;
    read_ts            timestamptz;
    sealed_key         text;
    sealed_ct          text;
    n_payloads         int := 0;
    is_legacy          boolean;
    theme              text;
    target             int;
    n_lines            int;
    closed_bite        int := 55;     -- constellations OPEN, the rest CLOSED
begin
    perform set_config('search_path', 'public, extensions', true);
    perform setseed(0.4242);

    -- ══ 0. Idempotent regeneration: wipe the previous seed run ══
    delete from public.kenos_constellations
     where id in (select md5('kenos-load-const-' || s)::uuid
                  from generate_series(1, 1000) s);
    delete from auth.users
     where email like '%@seed.kenos.local';   -- cascades every kenos_* wake

    -- The KEK must exist before anything is sealed under it.
    perform public.kenos_ether_kek();

    -- Real GCM payloads (from tool/gen_load_payloads.dart) when the
    -- make target staged them; 0 = random-bundle fallback.
    if to_regclass('public.kenos_load_payloads') is not null then
        select count(*) into n_payloads from public.kenos_load_payloads;
    end if;

    -- ══ 1. Anonymous crowd, joining along the same ramp ══
    for i in 1..n_users loop
        v := -ln(1 - random() * (1 - exp(-g * ramp_days))) / g;
        insert into auth.users (
            id, instance_id, aud, role, email,
            email_confirmed_at,
            raw_app_meta_data, raw_user_meta_data,
            created_at, updated_at, is_anonymous
        ) values (
            md5('kenos-load-user-' || i)::uuid,
            '00000000-0000-0000-0000-000000000000',
            'anonymous', 'authenticated',
            'load-' || lpad(i::text, 4, '0') || '@seed.kenos.local',
            now() - v * interval '1 day',
            jsonb_build_object('provider', 'anonymous', 'providers', array['anonymous'], 'kenos_load_seed', true),
            jsonb_build_object('kenos_load_seed', true),
            now() - v * interval '1 day', now() - v * interval '1 day',
            true
        );
    end loop;

    -- ══ 2. Drifting echoes: uniform background + gaussian clusters ══
    -- Cluster hotspots stress the 8×8 sector culling (24/sector, 400 cap).
    for i in 1..n_alive loop
        -- Ramp age: density grows ~13%/day toward today.
        v := -ln(1 - random() * (1 - exp(-g * ramp_days))) / g;
        -- Keep a handful of ancient drifters on the purge horizon.
        if i % 105 = 0 then
            v := 29 + random() * 0.9;
        end if;

        -- Spatial mix: 76% uniform, 20% three clusters, 4% tight hotspot.
        k := floor(random() * 25);
        if k < 19 then
            x := random(); y := random();
        elsif k < 21 then
            x := 0.5 + sqrt(-2 * ln(greatest(random(), 1e-12))) * cos(2 * pi() * random()) * 0.025;
            y := 0.5 + sqrt(-2 * ln(greatest(random(), 1e-12))) * sin(2 * pi() * random()) * 0.025;
        elsif k < 23 then
            x := 0.18 + sqrt(-2 * ln(greatest(random(), 1e-12))) * cos(2 * pi() * random()) * 0.03;
            y := 0.82 + sqrt(-2 * ln(greatest(random(), 1e-12))) * sin(2 * pi() * random()) * 0.03;
        elsif k < 24 then
            x := 0.85 + sqrt(-2 * ln(greatest(random(), 1e-12))) * cos(2 * pi() * random()) * 0.02;
            y := 0.15 + sqrt(-2 * ln(greatest(random(), 1e-12))) * sin(2 * pi() * random()) * 0.02;
        else
            -- The hotspot: ~170 echoes in ~2 sectors → culling visibly bites.
            x := 0.62 + sqrt(-2 * ln(greatest(random(), 1e-12))) * cos(2 * pi() * random()) * 0.008;
            y := 0.38 + sqrt(-2 * ln(greatest(random(), 1e-12))) * sin(2 * pi() * random()) * 0.008;
        end if;
        x := least(greatest(x, 0), 1);
        y := least(greatest(y, 0), 1);

        -- Whales: power-law authorship (few users own most echoes).
        author := md5('kenos-load-user-' || (1 + floor(power(random(), 0.45) * n_users)))::uuid;

        -- 4% legacy plaintext relics (pre-ether-seal, > 20 days old).
        is_legacy := random() < 0.04;
        if is_legacy then
            v := greatest(v, 20 + random() * 10);
        end if;

        -- Themes: never ROSE (reserved for destruction).
        if random() < 0.55 then
            theme := 'TEAL';
        elsif random() < 0.67 then
            theme := 'INDIGO';
        else
            theme := 'LUMEN';
        end if;

        if is_legacy then
            insert into public.echoes (
                id, author_id, encrypted_text, key_seal,
                coord_x, coord_y, coord_z, color_theme, created_at,
                media_kind, media_path, parent_id, momentum
            ) values (
                md5('kenos-load-echo-' || i)::uuid, author,
                texts[1 + floor(random() * array_length(texts, 1))], '',
                x, y, 0.05 + 0.95 * random(), theme,
                now() - v * interval '1 day',
                null, null, null, 0
            );
        else
            if n_payloads > 0 then
                -- A REAL client-format seal: the winner opens it on
                -- device (deterministic cycle over the staged pool).
                select p.key_b64, p.payload_b64 into sealed_key, sealed_ct
                  from public.kenos_load_payloads p
                 where p.seq = ((i - 1) % n_payloads) + 1;
            else
                sealed_key := encode(gen_random_bytes(32), 'base64');
                sealed_ct := encode(gen_random_bytes(96), 'base64');
            end if;
            insert into public.echoes (
                id, author_id, encrypted_text, key_seal,
                coord_x, coord_y, coord_z, color_theme, created_at,
                media_kind, media_path, parent_id, momentum
            ) values (
                md5('kenos-load-echo-' || i)::uuid, author,
                sealed_ct,
                encode(pgp_sym_encrypt(sealed_key, public.kenos_ether_kek()), 'base64'),
                x, y, 0.05 + 0.95 * random(), theme,
                now() - v * interval '1 day',
                case floor(random() * 200)
                    when 0 then 'IMAGE'
                    when 1 then 'IMAGE'
                    when 2 then 'IMAGE'
                    when 3 then 'AUDIO'
                    when 4 then 'AUDIO'
                    else null end,
                case floor(random() * 200)
                    when 0 then author::text || '/' || i || '-IMAGE.bin'
                    when 1 then author::text || '/' || i || '-IMAGE.bin'
                    when 2 then author::text || '/' || i || '-IMAGE.bin'
                    when 3 then author::text || '/' || i || '-AUDIO.bin'
                    when 4 then author::text || '/' || i || '-AUDIO.bin'
                    else null end,
                null, 0
            );
        end if;

        -- Sealed doors (SONG/EXCERPT) ride with ~12% of the modern echoes.
        if not is_legacy and random() < 0.12 then
            update public.echoes
               set media_kind = case when random() < 0.55 then 'SONG' else 'EXCERPT' end,
                   media_path = encode(gen_random_bytes((33 + floor(random() * 60))::int), 'base64')
             where id = md5('kenos-load-echo-' || i)::uuid;
        end if;
    end loop;

    -- ══ 3. Phoenix heads: rebound chains whose parents are consumed ══
    for i in 1..n_rebound_heads loop
        k := 1 + floor(random() * n_dead);           -- the consumed parent
        update public.echoes
           set momentum = 1 + floor(random() * 4),
               parent_id = md5('kenos-load-dead-' || k)::uuid
         where id = md5('kenos-load-echo-' || (1 + floor(random() * n_alive)))::uuid;
    end loop;

    -- ══ 4. Consumed echoes: the wake (receptions, reads, lineages) ══
    for i in 1..n_dead loop
        v := -ln(1 - random() * (1 - exp(-g * ramp_days))) / g;   -- consumed age
        -- One slice lands in the last quarter-hour: fresh consumption
        -- feeding the active rebound windows (and the ramp's last hours).
        if i % 100 = 0 then
            v := random() * 15 / 1440;
        end if;
        author := md5('kenos-load-user-' || (1 + floor(power(random(), 0.45) * n_users)))::uuid;
        echo_id := md5('kenos-load-dead-' || i)::uuid;

        -- Drift: minutes-to-days tail, capped below the consumed age.
        drift_s := least(
            (30 + (-ln(greatest(random(), 1e-12))) * 5400)::bigint,
            (v * 86400 * 0.9)::bigint
        );

        insert into public.kenos_receptions (
            echo_id, author_id, read_at, drift_seconds, reply_text, reply_seen
        ) values (
            echo_id, author,
            now() - v * interval '1 day', drift_s,
            case when random() < 0.35
                 then traces[1 + floor(random() * array_length(traces, 1))]
                 else null end,
            random() < 0.62
        );
    end loop;

    -- Audit journal: purge keeps one day — only recent consumptions.
    for i in 1..n_reads loop
        select r.echo_id, r.author_id, r.read_at into echo_id, author, read_ts
          from public.kenos_receptions r
         where r.read_at > now() - interval '20 hours'
         order by random() limit 1;
        exit when echo_id is null;
        reader := md5('kenos-load-user-' || (1 + floor(random() * n_users)))::uuid;
        if reader <> author then
            insert into public.kenos_reads (reader_id, echo_id, read_at)
            values (reader, echo_id, read_ts)
            on conflict do nothing;
        end if;
    end loop;

    -- Lineages: active rebound windows + stale ones awaiting the sweep.
    -- consumed_at is the real read_at (window semantics stay honest).
    for i in 1..n_lineages_active loop
        insert into public.kenos_lineages (echo_id, momentum, color_theme, read_by, consumed_at)
        select r.echo_id, floor(random() * 3)::int,
               (array['TEAL','INDIGO','LUMEN'])[1 + floor(random() * 3)],
               md5('kenos-load-user-' || (1 + floor(random() * n_users)))::uuid,
               r.read_at
          from public.kenos_receptions r
         where r.read_at > now() - interval '9 minutes'
         order by random() limit 1
         on conflict do nothing;
    end loop;
    for i in 1..n_lineages_stale loop
        insert into public.kenos_lineages (echo_id, momentum, color_theme, read_by, consumed_at)
        select r.echo_id, floor(random() * 3)::int,
               (array['TEAL','INDIGO','LUMEN'])[1 + floor(random() * 3)],
               md5('kenos-load-user-' || (1 + floor(random() * n_users)))::uuid,
               r.read_at
          from public.kenos_receptions r
         where r.read_at between now() - interval '6 hours' and now() - interval '1 hour'
         order by random() limit 1
         on conflict do nothing;
    end loop;

    -- ══ 5. Reports: every reason code, filed by the actual reader ══
    for i in 1..n_reports loop
        select r.echo_id, r.read_at, r.author_id into echo_id, read_ts, author
          from public.kenos_receptions r
         order by random() limit 1;
        reader := md5('kenos-load-user-' || (1 + floor(random() * n_users)))::uuid;
        if reader <> author then
            insert into public.kenos_echo_reports (echo_id, reporter_id, reason_code, reported_at)
            values (echo_id, reader,
                    (array['INAPPROPRIATE','SPAM','DANGER','OTHER'])[1 + floor(random() * 4)],
                    read_ts + random() * 600 * interval '1 second')
            on conflict do nothing;
        end if;
    end loop;

    -- ══ 6. Waves: the symphony only hears the last 60 seconds ══
    for i in 1..n_frequencies loop
        insert into public.kenos_frequencies (author_id, x_pos, y_pos, note_index, hue_index, created_at)
        values (
            md5('kenos-load-user-' || (1 + floor(random() * n_users)))::uuid,
            random(), random(),
            floor(random() * 20)::smallint, floor(random() * 4)::smallint,
            now() - random() * 55 * interval '1 second'
        );
    end loop;

    -- ══ 7. Constellations: open corpses, closed corpses, sealed lines ══
    for i in 1..n_constellations loop
        v := -ln(1 - random() * (1 - exp(-ln(1.35) * 7))) / ln(1.35);  -- faster ramp, 7-day window
        if i % 23 = 0 then
            v := 6.7 + random() * 0.25;   -- a few on the 7-day fetch horizon
        end if;
        target := 4 + floor(random() * 4);
        insert into public.kenos_constellations (
            id, seed_x, seed_y, target_lines, state, created_at, closed_at
        ) values (
            md5('kenos-load-const-' || i)::uuid,
            random(), random(), target,
            case when i <= closed_bite then 'OPEN' else 'CLOSED' end,
            now() - v * interval '1 day',
            case when i <= closed_bite then null
                 else now() - v * interval '1 day' + (2 + random() * 40) * interval '1 hour' end
        );

        n_lines := case when i <= closed_bite
                        then floor(random() * target)::int      -- 0..target-1
                        else target end;                         -- complete corpse
        -- Distinct contributors within a constellation (one line per
        -- stranger, PK constraint): stride 61 is prime vs n_users and
        -- larger than any target_lines, so k stays collision-free.
        k := floor(random() * n_users)::int;   -- per-constellation base
        for i_x in 1..n_lines loop
            if n_payloads > 0 then
                select p.key_b64, p.payload_b64 into sealed_key, sealed_ct
                  from public.kenos_load_payloads p
                 where p.seq = ((i * 7 + i_x) % n_payloads) + 1;
            else
                sealed_key := encode(gen_random_bytes(32), 'base64');
                sealed_ct := encode(gen_random_bytes(48), 'base64');
            end if;
            insert into public.kenos_constellation_lines (
                constellation_id, contributor_id, line_number,
                encrypted_text, key_seal, created_at
            ) values (
                md5('kenos-load-const-' || i)::uuid,
                md5('kenos-load-user-' || (1 + ((k + i_x * 61) % n_users)))::uuid,
                i_x,
                sealed_ct,
                encode(pgp_sym_encrypt(sealed_key, public.kenos_ether_kek()), 'base64'),
                now() - v * interval '1 day' + i_x * (3 + random() * 25) * interval '1 minute'
            );
        end loop;
    end loop;

    -- The staged payload pool has served its galaxy: ciphertext only,
    -- already inserted — the staging table leaves no trace.
    drop table if exists public.kenos_load_payloads;
end
$seed$;

-- ══ Summary: what the ether now holds ══
select 'users (seed)'      as what, count(*) from auth.users where email like '%@seed.kenos.local'
union all select 'echoes drifting',         count(*) from public.echoes
union all select 'echoes sealed',           count(*) from public.echoes where key_seal <> ''
union all select 'echoes legacy plaintext', count(*) from public.echoes where key_seal = ''
union all select 'rebound heads (momentum>0)', count(*) from public.echoes where momentum > 0
union all select 'receptions',              count(*) from public.kenos_receptions
union all select 'receptions w/ trace',     count(*) from public.kenos_receptions where reply_text is not null
union all select 'audit reads',             count(*) from public.kenos_reads
union all select 'lineages',                count(*) from public.kenos_lineages
union all select 'reports',                 count(*) from public.kenos_echo_reports
union all select 'waves (live)',            count(*) from public.kenos_frequencies
union all select 'constellations',          count(*) from public.kenos_constellations
union all select 'constellation lines',     count(*) from public.kenos_constellation_lines
order by 1;

commit;
