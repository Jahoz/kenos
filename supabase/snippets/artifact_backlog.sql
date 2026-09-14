-- ═══════════════════════════════════════════════════════════════════════
-- KENOS — the artifact backlog: a poem a week, even in the calm
--
-- The purge gives closed artifacts a moon, then the ether forgets
-- them (30 days). Without regeneration, the sky slowly loses its
-- culture while adoption is quiet. The gardener keeps OPEN rings
-- coming — and this keeps READABLE culture coming: every release takes
-- the next backlog slot and writes one CLOSED, curated, credited
-- constellation — same mechanics as the launch curation (plaintext
-- legacy path, deterministic anonymous hands, curated_by names the
-- poet).
--
-- The Vestiges law holds: REAL public-domain fragments, CREDITED,
-- never fabricated confidences. The backlog is replenished by hand
-- (or a reviewed session) — the release never invents a line, it
-- only reveals what was curated. A released slot stays released
-- (released_at), so a poem never returns once the ether forgot it.
--
-- Idempotent by design, NO wrapping transaction on purpose: every
-- statement stands alone (Management API runs filemulti statements
-- in separate sessions) and a partial failure heals on re-run.
--
-- Usage (local):
--   docker exec -i supabase_db_kenos psql -U postgres -d postgres \
--     -v ON_ERROR_STOP=1 < supabase/snippets/artifact_backlog.sql
-- Usage (cloud):
--   bash scripts/prod_admin.sh filemulti supabase/snippets/artifact_backlog.sql
-- Release the next one (or: make prod-artifact-release):
--   bash scripts/prod_admin.sh sql "select public.kenos_artifact_release()"
-- Verify:
--   select slot, poet, released_at from public.kenos_artifact_backlog order by slot
--   select curated_by, count(*) from public.kenos_constellations
--     where curated_by is not null group by 1
-- ═══════════════════════════════════════════════════════════════════════

-- ── The queue: slots wait their turn, plaintext poetry, never client-read ──
create table if not exists public.kenos_artifact_backlog (
    slot        integer primary key,
    slug        text not null unique,
    poet        text not null,
    title       text not null,
    kind        text not null default 'POEM' check (kind in ('POEM', 'MELODY')),
    lines       jsonb not null check (jsonb_typeof(lines) = 'array'
                                      and jsonb_array_length(lines) between 4 and 7),
    source_note text,
    released_at timestamptz
);

alter table public.kenos_artifact_backlog enable row level security;
revoke all on public.kenos_artifact_backlog from anon, authenticated;

-- ── The corpus: public-domain fragments, FR + EN, 4–7 lines (the ring's own shape) ──
-- Re-run refreshes texts — released_at is NEVER touched (a slot stays spent).
insert into public.kenos_artifact_backlog (slot, slug, poet, title, kind, lines, source_note) values
(1, 'hugo-demain', 'VICTOR HUGO', 'Demain, dès l''aube', 'POEM',
 $$["Demain, dès l'aube, à l'heure où blanchit la campagne,",
   "Je partirai. Vois-tu, je sais que tu m'attends.",
   "J'irai par la forêt, j'irai par la montagne.",
   "Je ne puis demeurer loin de toi plus longtemps."]$$::jsonb,
 'Les Contemplations, 1856'),
(2, 'verlaine-ciel', 'PAUL VERLAINE', 'Le ciel est, par-dessus le toit…', 'POEM',
 $$["Le ciel est, par-dessus le toit,",
   "Si bleu, si calme !",
   "Un arbre, par-dessus le toit,",
   "Berce sa palme.",
   "La cloche, dans le ciel qu'on voit,",
   "Doucement tinte."]$$::jsonb,
 'Sagesse, 1880'),
(3, 'dickinson-hope', 'EMILY DICKINSON', '"Hope" is the thing with feathers', 'POEM',
 $$["\"Hope\" is the thing with feathers -",
   "That perches in the soul -",
   "And sings the tune without the words -",
   "And never stops - at all -"]$$::jsonb,
 'Poems, 1891'),
(4, 'shelley-ozymandias', 'PERCY BYSSHE SHELLEY', 'Ozymandias', 'POEM',
 $$["I met a traveller from an antique land,",
   "Who said—\"Two vast and trunkless legs of stone",
   "Stand in the desert. Near them, on the sand,",
   "Half sunk a shattered visage lies, whose frown,",
   "And wrinkled lip, and sneer of cold command,",
   "Tell that its sculptor well those passions read"]$$::jsonb,
 '1818'),
(5, 'baudelaire-correspondances', 'CHARLES BAUDELAIRE', 'Correspondances', 'POEM',
 $$["La Nature est un temple où de vivants piliers",
   "Laissent parfois sortir de confuses paroles ;",
   "L'homme y passe à travers des forêts de symboles",
   "Qui l'observent avec des regards familiers."]$$::jsonb,
 'Les Fleurs du mal, 1857'),
(6, 'rossetti-wind', 'CHRISTINA ROSSETTI', 'Who has seen the wind?', 'POEM',
 $$["Who has seen the wind?",
   "Neither I nor you:",
   "But when the leaves hang trembling,",
   "The wind is passing through."]$$::jsonb,
 '1872'),
(7, 'verlaine-lune', 'PAUL VERLAINE', 'La lune blanche…', 'POEM',
 $$["La lune blanche",
   "Luit dans les bois ;",
   "De chaque branche",
   "Part une voix",
   "Sous la ramée.",
   "Ô bien-aimée."]$$::jsonb,
 'La Bonne Chanson, 1870'),
(8, 'keats-nightingale', 'JOHN KEATS', 'Ode to a Nightingale (ouverture)', 'POEM',
 $$["My heart aches, and a drowsy numbness pains",
   "My sense, as though of hemlock I had drunk,",
   "Or emptied some dull opiate to the drains",
   "One minute past, and Lethe-wards had sunk:"]$$::jsonb,
 '1819'),
(9, 'lafontaine-corbeau', 'JEAN DE LA FONTAINE', 'Le Corbeau et le Renard', 'POEM',
 $$["Maître Corbeau, sur un arbre perché,",
   "Tenait en son bec un fromage.",
   "Maître Renard, par l'odeur alléché,",
   "Lui tint à peu près ce langage :",
   "« Hé ! bonjour, Monsieur du Corbeau.",
   "Que vous êtes joli ! Que vous me semblez beau !"]$$::jsonb,
 'Fables, 1668'),
(10, 'blake-tyger', 'WILLIAM BLAKE', 'The Tyger', 'POEM',
 $$["Tyger Tyger, burning bright,",
   "In the forests of the night;",
   "What immortal hand or eye,",
   "Could frame thy fearful symmetry?",
   "In what distant deeps or skies",
   "Burnt the fire of thine eyes?"]$$::jsonb,
 'Songs of Experience, 1794'),
-- ── V3.33: slots 11-30, the corpus rides to spring 2027 (9 Mondays
-- were left; the announcement wave needs the ritual alive past it).
-- Same law: real public-domain fragments, credited, 4-7 lines, FR+EN.
(11, 'rimbaud-dormeur', 'ARTHUR RIMBAUD', 'Le Dormeur du val', 'POEM',
 $$["C'est un trou de verdure où chante une rivière,",
   "Accrochant follement aux herbes des haillons",
   "D'argent ; où le soleil, de la montagne fière,",
   "Luit : c'est un petit val qui mousse de rayons.",
   "Un soldat jeune, bouche ouverte, tête nue,",
   "Et la nuque baignant dans le frais cresson bleu,"]$$::jsonb,
 'Poésies, 1870'),
(12, 'apollinaire-mirabeau', 'GUILLAUME APOLLINAIRE', 'Le Pont Mirabeau', 'POEM',
 $$["Sous le pont Mirabeau coule la Seine",
   "Et nos amours",
   "Faut-il qu'il m'en souvienne",
   "La joie venait toujours après la peine",
   "Vienne la nuit sonne l'heure",
   "Les jours s'en vont je demeure"]$$::jsonb,
 'Alcools, 1913'),
(13, 'verlaine-automne', 'PAUL VERLAINE', 'Chanson d''automne', 'POEM',
 $$["Les sanglots longs",
   "Des violons",
   "De l'automne",
   "Blessent mon cœur",
   "D'une langueur",
   "Monotone."]$$::jsonb,
 'Poèmes saturniens, 1866'),
(14, 'nerval-desdichado', 'GÉRARD DE NERVAL', 'El Desdichado', 'POEM',
 $$["Je suis le ténébreux, — le veuf, — l'inconsolé,",
   "Le prince d'Aquitaine à la tour abolie :",
   "Ma seule étoile est morte, — et mon luth constellé",
   "Porte le Soleil noir de la Mélancolie."]$$::jsonb,
 'Les Chimères, 1854'),
(15, 'lamartine-lac', 'ALPHONSE DE LAMARTINE', 'Le Lac (stance)', 'POEM',
 $$["Ô temps, suspends ton vol... et vous, heures propices,",
   "Suspendez votre cours :",
   "Laissez-nous savourer les rapides délices",
   "Des plus beaux de nos jours !"]$$::jsonb,
 'Méditations poétiques, 1820'),
(16, 'byron-night', 'LORD BYRON', 'She Walks in Beauty', 'POEM',
 $$["She walks in beauty, like the night",
   "Of cloudless climes and starry skies;",
   "And all that's best of dark and bright",
   "Meet in her aspect and her eyes;"]$$::jsonb,
 'Hebrew Melodies, 1815'),
(17, 'stevenson-requiem', 'ROBERT LOUIS STEVENSON', 'Requiem', 'POEM',
 $$["Under the wide and starry sky,",
   "Dig the grave and let me lie.",
   "Glad did I live and gladly die,",
   "And I laid me down with a will."]$$::jsonb,
 'Underwoods, 1887'),
(18, 'whitman-omeolife', 'WALT WHITMAN', 'O Me! O Life!', 'POEM',
 $$["O me! O life! of the questions of these recurring,",
   "Of the endless trains of the faithless, of cities fill'd with the foolish,",
   "Of myself forever reproaching myself, (for who more foolish than I, and who more faithless?)",
   "Of eyes that vainly crave the light, of the objects mean, of the struggle ever renew'd,",
   "Of the poor results of all, of the plodding and sordid crowds I see around me,",
   "Of the empty and useless years of the rest, with the rest me intertwined,",
   "The question, O me! so sad, recurring—What good amid these, O me, O life?"]$$::jsonb,
 'Leaves of Grass, 1892'),
(19, 'yeats-cloths', 'W. B. YEATS', 'Aedh wishes for the cloths of heaven', 'POEM',
 $$["Of night and light and the half light,",
   "I would spread the cloths under your feet:",
   "But I, being poor, have only my dreams;",
   "I have spread my dreams under your feet;",
   "Tread softly because you tread on my dreams."]$$::jsonb,
 'The Wind Among the Reeds, 1899'),
(20, 'dorleans-printemps', 'CHARLES D''ORLÉANS', 'Le temps a laissé son manteau', 'POEM',
 $$["Le temps a laissé son manteau",
   "De vent, de froidure et de pluye,",
   "Et s'est vestu de brouderie,",
   "De soleil luyant, cler et beau :"]$$::jsonb,
 'Poésies, XVe siècle'),
(21, 'mallarme-brise', 'STÉPHANE MALLARMÉ', 'Brise marine', 'POEM',
 $$["La chair est triste, hélas ! et j'ai lu tous les livres.",
   "Fuir ! là-bas fuir ! Je sens que les oiseaux sont ivres",
   "D'être parmi l'écume inconnue et les cieux !",
   "Rien, ni les vieux jardins reflétés par les yeux",
   "Ne retient ce cœur qui dans la mer se juge"]$$::jsonb,
 'Poésies, 1866'),
(22, 'lafontaine-lievre', 'JEAN DE LA FONTAINE', 'Le Lièvre et la Tortue', 'POEM',
 $$["Rien ne sert de courir ; il faut partir à point.",
   "Le lièvre et la tortue en sont un témoignage.",
   "« Gage, dit celle-ci, que vous n'arriverez point",
   "Si tôt que moi. — Si tôt ? Êtes-vous sage ?"]$$::jsonb,
 'Fables, Livre VI, 1668'),
(23, 'housman-loveliest', 'A. E. HOUSMAN', 'Loveliest of trees', 'POEM',
 $$["Loveliest of trees, the cherry now",
   "Is hung with bloom along the bough,",
   "And stands about the woodland ride",
   "Wearing white for Eastertide."]$$::jsonb,
 'A Shropshire Lad, 1896'),
(24, 'wordsworth-rainbow', 'WILLIAM WORDSWORTH', 'My heart leaps up', 'POEM',
 $$["My heart leaps up when I behold",
   "A rainbow in the sky:",
   "So was it when my life began;",
   "So is it now I am a man;",
   "So be it when I shall grow old,"]$$::jsonb,
 'Poems in Two Volumes, 1807'),
(25, 'bronte-nocoward', 'EMILY BRONTË', 'No coward soul is mine', 'POEM',
 $$["No coward soul is mine,",
   "No trembler in the world's storm-troubled sphere:",
   "I see Heaven's glories shine,",
   "And faith shines equal, arming me from fear."]$$::jsonb,
 'Poems by Currer, Ellis and Acton Bell, 1846'),
(26, 'thomas-adlestrop', 'EDWARD THOMAS', 'Adlestrop', 'POEM',
 $$["Yes. I remember Adlestrop—",
   "The name, because one afternoon",
   "Of heat the express-train drew up there",
   "Unwontedly. It was late June."]$$::jsonb,
 'Poems, 1917'),
(27, 'hardy-darkling', 'THOMAS HARDY', 'The Darkling Thrush', 'POEM',
 $$["I leant upon a coppice gate",
   "When Frost was spectre-grey,",
   "And Winter's dregs made desolate",
   "The weakening eye of day."]$$::jsonb,
 'Poems of the Past and the Present, 1901'),
(28, 'teasdale-barter', 'SARA TEASDALE', 'Barter', 'POEM',
 $$["Life has loveliness to sell,",
   "All beautiful and splendid things,",
   "Blue waves whitened on a cliff,",
   "Soaring fire that sways and sings,",
   "And children's faces looking up,",
   "Holding wonder like a cup."]$$::jsonb,
 'Helen of Troy and Other Poems, 1911'),
(29, 'burns-redrose', 'ROBERT BURNS', 'A Red, Red Rose', 'POEM',
 $$["O my Luve is like a red, red rose,",
   "That's newly sprung in June;",
   "O my Luve is like the melody",
   "That's sweetly play'd in tune."]$$::jsonb,
 'Scots Musical Museum, 1794'),
(30, 'clare-iam', 'JOHN CLARE', 'I Am', 'POEM',
 $$["I am—yet what I am none cares or knows;",
   "My friends forsake me like a memory lost:—",
   "I am the self-consumer of my woes;—",
   "They rise and vanish in oblivion's host,"]$$::jsonb,
 'Poems, 1848')
on conflict (slot) do update
   set poet        = excluded.poet,
       title       = excluded.title,
       kind        = excluded.kind,
       lines       = excluded.lines,
       source_note = excluded.source_note;

-- ── The release: one slot becomes a readable constellation ─────────────
-- Service-level (no auth), operator- or cron-called, like the gardener.
-- Deterministic ids make a re-run inert: the same slug can never write
-- a second constellation, and a partial failure heals on retry.
create or replace function public.kenos_artifact_release()
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
    a         public.kenos_artifact_backlog%rowtype;
    v_id      uuid;
    k         int;
    n         int;
    remaining int;
begin
    select * into a
      from public.kenos_artifact_backlog
     where released_at is null
     order by slot
     limit 1
     for update skip locked;

    if a.slot is null then
        return jsonb_build_object('released', false, 'reason', 'backlog empty');
    end if;

    v_id := md5('kenos-curated-' || a.slug)::uuid;
    n  := jsonb_array_length(a.lines);

    -- The hands: extend the classic pool of 8 if the fragment is longer.
    insert into auth.users (
        id, instance_id, aud, role, email,
        email_confirmed_at, created_at, updated_at, is_anonymous
    )
    select md5('kenos-curated-hand-' || h)::uuid,
           '00000000-0000-0000-0000-000000000000',
           'anonymous', 'authenticated',
           'curated-hand-' || h || '@seed.kenos.local',
           now(), now(), now(), true
      from generate_series(1, greatest(8, n)) h
    on conflict (id) do nothing;

    insert into public.kenos_constellations (
        id, seed_x, seed_y, target_lines, state, kind, curated_by,
        created_at, closed_at
    )
    values (
        v_id, 0.06 + random() * 0.88, 0.08 + random() * 0.84,
        n, 'CLOSED', a.kind, a.poet, now(), now()
    )
    on conflict (id) do nothing;

    -- Published culture rides the legacy plaintext path (key_seal empty):
    -- the seal protects confidences, not Baudelaire.
    for k in 1..n loop
        insert into public.kenos_constellation_lines (
            constellation_id, contributor_id, line_number,
            encrypted_text, key_seal, created_at
        )
        values (
            v_id, md5('kenos-curated-hand-' || k)::uuid, k,
            a.lines ->> (k - 1), '', now() + k * interval '37 minutes'
        )
        on conflict do nothing;
    end loop;

    update public.kenos_artifact_backlog
       set released_at = now()
     where slot = a.slot;

    select count(*) into remaining
      from public.kenos_artifact_backlog
     where released_at is null;

    return jsonb_build_object(
        'released', true, 'slot', a.slot, 'slug', a.slug,
        'poet', a.poet, 'title', a.title, 'id', v_id,
        'lines', n, 'backlog_remaining', remaining
    );
end;
$$;

revoke all on function public.kenos_artifact_release()
    from public, anon, authenticated;

-- ── The ether's own clock: one release every Monday morning ────────────
-- 06:45 UTC = 08:45 Paris in summer, 07:45 after the DST switch — always
-- before the 09:00 local watch, so the morning report carries the birth.
-- Idempotent like the reaper's wiring: unschedule, then schedule.
select cron.unschedule('kenos-artifact')
 where exists (select 1 from cron.job where jobname = 'kenos-artifact');

select cron.schedule(
    'kenos-artifact',
    '45 6 * * 1',
    $$ select public.kenos_artifact_release(); $$
);
