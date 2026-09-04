-- KENOS — the Vestiges in English (V3.16, human first pass).
-- The canon stays French; the shards meet the traveler in their
-- language. Positions match the canon: a star does not move because
-- you read it in English.
begin;
insert into public.kenos_vestiges (id, kind, text, source, pos_x, pos_y, locale) values
('v001', 'quote', 'You were made to empty yourself, the way the sky empties of its clouds.', 'after Rilke', 0.420, 0.280, 'en'),
('v002', 'etymology', 'KENOSIS — from the Greek kenôsis, "emptying, being stripped". Emptying oneself to make room for the wholly other.', 'ancient Greek', 0.650, 0.180, 'en'),
('v003', 'quote', 'Silence is a friend who never betrays.', 'Confucius', 0.220, 0.520, 'en'),
('v004', 'history', 'The exquisite corpse was born around 1925, rue du Château: Breton, Éluard, Tzara folding the paper, each blind to the others’ fragments — and the whole surprises everyone.', 'surrealism', 0.840, 0.420, 'en'),
('v005', 'etymology', 'AETHER — from the Greek aithêin, "to burn, to blaze". That which burns without consuming: the light between the stars.', 'ancient Greek', 0.320, 0.360, 'en'),
('v006', 'haiku', 'In the stillness of the void / a bottle drifts / someone will read.', 'kenos', 0.500, 0.500, 'en'),
('v007', 'quote', 'Everything profound loves a mask.', 'Nietzsche', 0.560, 0.340, 'en'),
('v008', 'etymology', 'Silence — from the Latin silere, "to be still, to say nothing". Not the absence of sound: the presence of calm.', 'Latin', 0.800, 0.820, 'en'),
('v009', 'history', 'On September 16, 1977, Voyager 1 carried a golden record: voices, musics, a bottle cast toward nowhere — the most distant echo ever given.', 'Voyager 1', 0.720, 0.560, 'en'),
('v010', 'haiku', 'Star closed / the confidence has burned / the sky stays wide.', 'kenos', 0.440, 0.680, 'en'),
('v011', 'quote', 'One only sees well with the heart. What is essential is invisible to the eye.', 'Antoine de Saint-Exupéry', 0.500, 0.280, 'en'),
('v012', 'etymology', 'Constellation — from the Latin cum stella, "with the stars". A figure that exists only if gazes connect it.', 'Latin', 0.500, 0.840, 'en'),
('c001', 'fact', 'Moonlight takes 1.3 seconds to reach you; sunlight, 8 minutes; Andromeda’s, 2.5 million years. To look at the sky is to read the past.', 'astronomy', 0.150, 0.450, 'en'),
('c002', 'quote', 'I am made of darkness and wonders.', 'after Rilke', 0.870, 0.460, 'en'),
('c003', 'fact', 'A day on Venus lasts longer than its year: the planet spins on its axis more slowly than it circles the Sun.', 'astronomy', 0.280, 0.500, 'en'),
('c004', 'etymology', 'Echo — the Greek nymph condemned to repeat only the endings of others’ sentences. Here she repeats nothing: every echo is said only once.', 'ancient Greek', 0.550, 0.500, 'en'),
('c005', 'history', '1977: space was heard for the first time — plasma waves translated into sound by Voyager. The void sings, in its own way.', 'Voyager', 0.250, 0.300, 'en'),
('c006', 'fact', 'There are more stars in the observable universe than grains of sand on all of Earth’s beaches. And yet most confidences still go unread.', 'astronomy', 0.680, 0.280, 'en'),
('c007', 'quote', 'The void is not nothingness: it is what remains when everything has been given away.', 'kenos', 0.500, 0.720, 'en'),
('c008', 'etymology', 'Pentatonic — five notes, no wrong one possible. The scale of ancient music, from blues to Asian flutes: it is what the symphony of waves sings.', 'music', 0.500, 0.160, 'en'),
('c009', 'fact', 'Neurons and galaxies share the same density of nodes: one 10^26 times larger than the other, but the same pattern. The void connects both.', 'science', 0.440, 0.390, 'en'),
('c010', 'history', '1928: Schrödinger writes that life "feeds on negativity" — on order it consumes. Emptying to live: kenosis was already physics.', 'physics', 0.610, 0.640, 'en'),
('c011', 'haiku', 'Bottle cast / the sea carries it without a sound / someone keeps watch, far away.', 'kenos', 0.160, 0.520, 'en'),
('c012', 'etymology', 'Anonymous — from the Greek anônymos, "without a name". Here it is not a mask: it is the condition.', 'ancient Greek', 0.500, 0.600, 'en'),
('c013', 'fact', 'A bottle at sea takes fourteen months on average to cross the Atlantic. Currents are slow; so are confidences.', 'ocean', 0.350, 0.800, 'en'),
('c014', 'quote', 'Great thoughts come from the heart.', 'Vauvenargues', 0.620, 0.470, 'en'),
('c015', 'fact', 'Sound does not travel through a vacuum: the ether’s symphony exists only in your headphones. The music of the spheres is always an intimate listening.', 'physics', 0.710, 0.730, 'en'),
('c016', 'etymology', 'Comet — from the Greek komêtês, "long-haired". A traveling thought keeps something of hair in the wind.', 'ancient Greek', 0.380, 0.600, 'en'),
('c017', 'history', 'Louise Labé’s sonnets circulated anonymously in Lyon around 1555 — signed with a name many believed a pseudonym. The city argued; she stayed silent.', 'Lyon, 1555', 0.430, 0.510, 'en'),
('c018', 'fact', 'Every night, about 100 tons of stardust settle on the Earth. You walk on ancient confidences.', 'astronomy', 0.300, 0.500, 'en'),
('c019', 'quote', 'It is not because things are difficult that we do not dare; it is because we do not dare that they are difficult.', 'Seneca', 0.760, 0.500, 'en'),
('c020', 'etymology', 'Bottle — from the Greek butylon, by way of Latin. At sea it is the art of sending without knowing: navigation’s gentlest wager.', 'navigation', 0.570, 0.540, 'en')
on conflict (id, locale) do update
    set kind = excluded.kind,
        text = excluded.text,
        source = excluded.source,
        live = true;
commit;
