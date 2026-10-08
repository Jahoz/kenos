-- KENOS — the light sow (October): 50 real sealed echoes, readable.
--
-- Run: bash scripts/prod_admin.sh file supabase/snippets/prod_sow_light.sql

do $light_sow$
declare
    v_user  uuid;
    v_text  text;
    v_theme text;
    v_x     double precision;
    v_y     double precision;
    v_z     double precision;
    v_mom   integer;
    v_age_h integer;
    i       integer;
    j       integer;
begin
    for j in 0..6 loop
        insert into auth.users (
            id, instance_id, aud, role, email,
            email_confirmed_at, created_at, updated_at, is_anonymous
        )
        values (
            md5('light-sow-oct-' || j)::uuid,
            '00000000-0000-0000-0000-000000000000',
            'anonymous', 'authenticated',
            'sky-0' || j || '@seed.kenos.local',
            now(), now(), now(), true
        )
        on conflict (id) do nothing;
    end loop;

    for i in 1..50 loop
        v_x := 0.08 + random() * 0.84;
        v_y := 0.10 + random() * 0.80;
        v_z := 0.15 + random() * 0.75;

        v_theme := case
            when random() < 0.38 then 'TEAL'
            when random() < 0.62 then 'INDIGO'
            else 'LUMEN'
        end;

        v_mom := case
            when i % 11 = 0 then 1 + (i % 3)
            else 0
        end;

        v_age_h := (random() * 480)::int; -- up to 20 days old
        v_user := md5('light-sow-oct-' || (i % 7))::uuid;

        v_text := case i % 10
            when 0 then 'Une pensée semée pour tenir le ciel ouvert.'
            when 1 then 'Le vide a besoin de lumière, même empruntée.'
            when 2 then 'Je dérive pour qu''un autre trouve quelque chose à lire.'
            when 3 then 'Le silence du ciel attendait ces mots.'
            when 4 then 'Rien d''intime ici — juste une lumière qui passe.'
            when 5 then 'Ce fragment ne dira rien. Il est là pour le voyage.'
            when 6 then 'L''éther se remplit de ce qu''on lui confie.'
            when 7 then 'Une graine parmi les étoiles, en attente d''un lecteur.'
            when 8 then 'Le ciel n''est pas vide : il attend.'
            else 'Ceci est une pensée semée, pas une confidence.'
        end;

        insert into public.echoes (
            author_id, encrypted_text, key_seal,
            coord_x, coord_y, coord_z, color_theme,
            media_kind, media_path, origin_label,
            momentum, created_at
        )
        values (
            v_user, v_text, '',
            v_x, v_y, v_z, v_theme,
            null, null, '',
            v_mom,
            now() - make_interval(hours => v_age_h)
        )
        on conflict do nothing;
    end loop;

    raise notice 'LIGHT SOW: 50 echoes planted';
end
$light_sow$;
