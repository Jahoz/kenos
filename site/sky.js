// KENOS — the living sky of the landing, V2 "the dream" (2026-09-25).
//
// The showcase breathes what the product breathes: a miniature of the
// app's cosmology (V3.75–77 constitution), now with both hands free.
//   · three depth fields of breathing stars on endless scroll parallax,
//     plus a milky band of dust and micro-stars crossing the void;
//   · the sky ANSWERS THE HAND: pointer (desktop) and tilt (mobile,
//     where the platform allows) low-pass the layers, like the app's
//     gyro parallax;
//   · the named system: la Lune, her companion, two echo lanes (echoes
//     age — they pale and slow), an artifact poem-ring, Vénus, and at
//     the world's floor L'Aube, the ember origin;
//   · Polaris fixed — immune to every drift; a flare greets the Seuil;
//   · vestige shards SPEAK: real culture fragments (quote, etymology,
//     fact — source carried, never an author) drift and fade away;
//   · constellations draw themselves as the traveller descends;
//   · shooting stars — ambient, summoned by the comets territory, and
//     BORN UNDER THE FINGER: pressing the void casts a star from where
//     you touched; the phoenix is one in five, teal, longer-lived;
//   · the black hole, far and quiet, feeds: a star streak spirals in;
//   · the reliquary lights its seven ember marks in an arc;
//   · sound is a door, never a wall: a small toggle opens the 70 Hz
//     drone and spatialized pentatonic bells — off by default, always
//     killable, born only from a gesture.
//
// Laws honored: ROSE never appears in this sky (destruction owns it —
// the burn overlay alone); reduced motion CALMS the heavens (clocks
// ×5 slower, ambient meteors, infalls and pointer sway shrink; it
// never stills — V3.73); the static CSS field under the canvas stands
// as the no-JS truth.
(function () {
  'use strict';

  var TAU = Math.PI * 2;
  var EN = (document.documentElement.lang || 'fr').indexOf('en') === 0;
  var canvas = document.getElementById('sky');
  if (!canvas || !canvas.getContext) return;
  var ctx = canvas.getContext('2d');
  if (!ctx) return;

  // ── the calm law: prefers-reduced-motion calms, never stills ──
  var calm = false;
  var reduceMq = window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)');
  if (reduceMq) {
    calm = reduceMq.matches;
    if (reduceMq.addEventListener) {
      reduceMq.addEventListener('change', function (e) { calm = e.matches; });
    }
  }
  var CALM_SCALE = 0.2; // ×5 slower heavens when the traveller asks for calm

  // ── palette: design tokens only; rose never comes here ──
  var TEAL = [20, 184, 166], CYAN = [34, 211, 238], INDIGO = [99, 102, 241],
      PURPLE = [139, 92, 246], LIGHT = [244, 244, 246], MOON = [233, 230, 223],
      EMBER = [245, 158, 11], VENUS = [244, 240, 230], VESTIGE = [214, 211, 202];
  function rgba(c, a) { return 'rgba(' + c[0] + ',' + c[1] + ',' + c[2] + ',' + a + ')'; }
  function clamp01(v) { return v < 0 ? 0 : v > 1 ? 1 : v; }

  // ── stage: viewport fractions; the sky adapts, never repeats ──
  var AT = {
    venus:    [0.14, 0.12],
    lune:     [0.76, 0.24],  // hero-side: moon + companion + echo lanes
    artifact: [0.16, 0.66],  // poem ring
    hole:     [0.88, 0.50],
    aube:     [0.50, 0.94]   // the ember origin — the world's floor
  };
  var POLARIS = [0.06, 0.86]; // fixed: no parallax, no drift — the still heart

  // vestige shards — curated culture, source carried, never an author
  var SHARDS = EN ? [
    ['"To see a World in a Grain of Sand…" — William Blake', 'quote'],
    ['kenosis (κένωσις): to empty oneself — ancient Greek', 'etymology'],
    ['The light of Polaris has travelled 433 years to reach you.', 'fact'],
    ['One light-year: 9.46 trillion kilometres.', 'fact'],
    ['The Moon drifts 3.8 cm farther from Earth every year.', 'fact'],
    ['"The sky is, above the roof…" — Paul Verlaine', 'quote']
  ] : [
    ['« Voir un monde en un grain de sable… » — William Blake', 'citation'],
    ['kenosis (κένωσις) : se vider de soi-même — grec ancien', 'étymologie'],
    ['La lumière de Polaris a voyagé 433 ans jusqu\u2019à toi.', 'fait'],
    ['Une année-lumière : 9 461 milliards de kilomètres.', 'fait'],
    ['La Lune s\u2019éloigne de la Terre de 3,8 cm par an.', 'fait'],
    ['« Le ciel est, par-dessus le toit… » — Paul Verlaine', 'citation']
  ];
  var shardIdx = Math.floor(Math.random() * SHARDS.length);
  var shard = null, nextShard = 6;

  // constellations: figures that draw themselves as the traveller descends
  var FIGURES = [
    { trigger: 0.10, pts: [[0.56, 0.28], [0.61, 0.31], [0.66, 0.30], [0.70, 0.35], [0.68, 0.43], [0.61, 0.42]], edges: [[0, 1], [1, 2], [2, 3], [3, 4], [4, 5], [5, 0], [2, 5]] },
    { trigger: 0.42, pts: [[0.13, 0.50], [0.18, 0.54], [0.15, 0.59], [0.09, 0.55]], edges: [[0, 1], [1, 2], [2, 3], [3, 0]] }
  ];

  var W = 0, H = 0, sysK = 1, areaK = 1, docH = 1;
  var stars = [], band = [], vestiges = [], meteors = [], echoes = [];
  var compPh = 1.2, ringPh = 0.4, holePh = 0, venusPh = 0.4;
  var t = 0, tReal = 0, last = 0, scroll = 0, hidden = false, resizeTimer = 0;
  var firstMeteorDone = false;
  var infall = null, nextInfall = 15;
  var effects = []; // section-summoned: ember arc, polaris flare

  // ── the hand: pointer + tilt, low-passed like the app (α-ish 0.06) ──
  var pxT = 0, pyT = 0, px = 0, py = 0;
  window.addEventListener('pointermove', function (e) {
    pxT = (e.clientX / W) * 2 - 1;
    pyT = (e.clientY / H) * 2 - 1;
  }, { passive: true });
  window.addEventListener('deviceorientation', function (e) {
    if (e.gamma == null || e.beta == null) return;
    pxT = Math.max(-1, Math.min(1, e.gamma / 22));
    pyT = Math.max(-1, Math.min(1, (e.beta - 42) / 22));
  }, { passive: true });

  // glow sprites — pre-rendered once, drawn cheap every frame
  var SPR = 64, sprites = {};
  function makeGlow(c) {
    var cv = document.createElement('canvas');
    cv.width = cv.height = SPR;
    var g = cv.getContext('2d');
    var gr = g.createRadialGradient(SPR / 2, SPR / 2, 0, SPR / 2, SPR / 2, SPR / 2);
    gr.addColorStop(0, rgba(c, 0.55));
    gr.addColorStop(0.35, rgba(c, 0.16));
    gr.addColorStop(1, rgba(c, 0));
    g.fillStyle = gr;
    g.fillRect(0, 0, SPR, SPR);
    return cv;
  }

  function rnd(a, b) { return a + Math.random() * (b - a); }

  // parallax: the page travels, the sky lags; bodies wrap — the sky is endless
  function parY(fy, k) {
    var m = 90, span = H + 2 * m;
    var y = fy * H - scroll * k;
    return (((y + m) % span) + span) % span - m;
  }

  function build() {
    var dpr = Math.min(window.devicePixelRatio || 1, 2);
    W = window.innerWidth;
    H = window.innerHeight;
    canvas.width = Math.round(W * dpr);
    canvas.height = Math.round(H * dpr);
    if (ctx.setTransform) ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    areaK = Math.max(0.55, Math.min(1.6, (W * H) / (1280 * 800)));
    sysK = Math.max(0.62, Math.min(1, W / 1100));
    docH = Math.max(1, document.documentElement.scrollHeight - H);

    stars.length = 0;
    var fields = [[0.32, 100], [0.62, 60], [1, 32]];
    for (var f = 0; f < 3; f++) {
      var depth = fields[f][0];
      for (var i = 0, n = Math.round(fields[f][1] * areaK); i < n; i++) {
        var roll = Math.random();
        stars.push({
          x: Math.random(), y: Math.random(), d: depth,
          r: (0.4 + Math.random() * 0.9) * (0.5 + depth * 0.8),
          a: rnd(0.22, 0.7) * (0.55 + depth * 0.45),
          tw: rnd(0.25, 1.1), ph: rnd(0, TAU),
          c: roll < 0.07 ? CYAN : roll < 0.15 ? INDIGO : LIGHT,
          vx: rnd(2, 6) * depth // px/min — a drifting backdrop
        });
      }
    }

    // the milky band: micro-stars clustered along a diagonal of dust
    band.length = 0;
    var ba = -0.5, dx = Math.cos(ba), dy = Math.sin(ba);
    for (var b = 0, bn = Math.round(170 * areaK); b < bn; b++) {
      var u = rnd(-0.75, 0.75), off = (Math.random() + Math.random() + Math.random()) / 3 - 0.5;
      band.push({
        u: u * 1.35 * Math.max(W, H), off: off * 2 * H * 0.14,
        dx: dx, dy: dy,
        r: rnd(0.4, 1.1), a: rnd(0.22, 0.58),
        tw: rnd(0.3, 1.2), ph: rnd(0, TAU)
      });
    }

    vestiges.length = 0;
    for (var v = 0, vn = Math.round(6 * areaK) + 3; v < vn; v++) {
      vestiges.push({
        x: Math.random(), y: rnd(0.34, 0.56), r: rnd(2.2, 3.6),
        vx: rnd(3, 9), wob: rnd(0, TAU), was: rnd(6, 16), a: rnd(0.45, 0.72)
      });
    }

    echoes.length = 0;
    var laneR = [78, 112];
    for (var L = 0; L < 2; L++) {
      for (var e = 0, en = L ? 3 : 4; e < en; e++) {
        echoes.push({
          lane: L, r: laneR[L], ph: rnd(0, TAU),
          age: Math.min(1, (e + L * 2.5) / 7) // 0 fresh → 1 old: pale and slow
        });
      }
    }
  }

  // birth choreography: the void lights up, piece by piece
  function born(delay) {
    return clamp01((tReal - delay) / 1.2);
  }

  // ── deep field ──
  function drawStars(dt, mul) {
    var drift = dt / 60; // vx is px/min
    var swayK = calm ? 0.25 : 1;
    for (var i = 0; i < stars.length; i++) {
      var s = stars[i];
      s.x += (s.vx * drift) / W;
      var pxs = (((s.x % 1) + 1) % 1) * W - px * 9 * s.d * swayK;
      var pys = parY(s.y, 0.05 * s.d) - py * 6 * s.d * swayK;
      ctx.globalAlpha = mul * s.a * (0.72 + 0.28 * Math.sin(t * s.tw + s.ph));
      ctx.fillStyle = rgba(s.c, 1);
      ctx.beginPath();
      ctx.arc(pxs, pys, s.r, 0, TAU);
      ctx.fill();
    }
    ctx.globalAlpha = 1;
  }

  // ── the milky band: dust + micro-stars ──
  function drawBand(mul) {
    var swayK = calm ? 0.25 : 1;
    ctx.save();
    ctx.translate(W * 0.5 - px * 4 * swayK, H * 0.5 - py * 3 * swayK);
    ctx.rotate(-0.5);
    var g = ctx.createLinearGradient(0, -H * 0.16, 0, H * 0.16);
    g.addColorStop(0, 'rgba(140,150,190,0)');
    g.addColorStop(0.5, 'rgba(150,160,200,0.075)');
    g.addColorStop(1, 'rgba(140,150,190,0)');
    ctx.fillStyle = g;
    ctx.globalAlpha = mul;
    ctx.fillRect(-W * 1.2, -H * 0.16, W * 2.4, H * 0.32);
    var g2 = ctx.createLinearGradient(0, -H * 0.055, 0, H * 0.055);
    g2.addColorStop(0, 'rgba(160,170,210,0)');
    g2.addColorStop(0.5, 'rgba(170,180,215,0.06)');
    g2.addColorStop(1, 'rgba(160,170,210,0)');
    ctx.fillStyle = g2;
    ctx.fillRect(-W * 1.2, -H * 0.055, W * 2.4, H * 0.11);
    ctx.restore();
    ctx.globalAlpha = 1;
    for (var i = 0; i < band.length; i++) {
      var m = band[i];
      var bx = W * 0.5 + m.dx * m.u - m.dy * m.off - px * 3 * swayK;
      var by = H * 0.5 + m.dy * m.u + m.dx * m.off - py * 2 * swayK;
      ctx.globalAlpha = mul * m.a * (0.7 + 0.3 * Math.sin(t * m.tw + m.ph));
      ctx.fillStyle = 'rgba(220,225,240,1)';
      ctx.beginPath();
      ctx.arc(bx, by, m.r, 0, TAU);
      ctx.fill();
    }
    ctx.globalAlpha = 1;
  }

  // ── vestiges: small, pale, forever ──
  function drawVestiges(dt, mul) {
    ctx.fillStyle = rgba(VESTIGE, 1);
    for (var i = 0; i < vestiges.length; i++) {
      var v = vestiges[i];
      v.x += (v.vx / 60) * dt / W;
      v.wob += (TAU / v.was) * dt;
      var vx2 = (((v.x % 1) + 1) % 1) * W - px * 5;
      var vy2 = parY(v.y + Math.sin(v.wob) * 0.008, 0.05) - py * 3;
      ctx.globalAlpha = mul * v.a * (0.7 + 0.3 * Math.sin(t * 0.6 + v.wob));
      ctx.beginPath();
      ctx.arc(vx2, vy2, v.r, 0, TAU);
      ctx.fill();
    }
    ctx.globalAlpha = 1;
  }

  // ── vestige shards speak: culture drifting, source carried ──
  function drawShard(mul) {
    if (!shard) {
      if (tReal > nextShard) {
        shard = { txt: SHARDS[shardIdx % SHARDS.length][0], tag: SHARDS[shardIdx % SHARDS.length][1],
                  x: rnd(0.12, 0.66), y: rnd(0.30, 0.62), t0: tReal, dur: 10500 };
        shardIdx++;
      }
      return;
    }
    var ph = (tReal - shard.t0) / shard.dur;
    if (ph >= 1) { shard = null; nextShard = tReal + rnd(7000, 14000); return; }
    var a = mul * Math.sin(Math.PI * ph) * 0.9;
    var driftK = calm ? 0.2 : 1;
    var sx = shard.x * W + ph * 18 * driftK - px * 6;
    var sy = (shard.y - ph * 0.035 * driftK) * H - py * 4;
    ctx.globalAlpha = a;
    ctx.font = 'italic 13px "Playfair Display", Georgia, serif';
    ctx.fillStyle = 'rgba(244,244,246,0.95)';
    ctx.fillText(shard.txt, sx, sy);
    ctx.globalAlpha = a * 0.65;
    ctx.font = '7.5px "Space Mono", monospace';
    ctx.fillStyle = rgba(TEAL, 1);
    ctx.fillText(shard.tag.toUpperCase(), sx + 2, sy + 15);
    ctx.globalAlpha = 1;
  }

  // ── constellations: they draw themselves as the traveller descends ──
  function drawFigures(mul) {
    var sp = clamp01(scroll / docH);
    for (var f = 0; f < FIGURES.length; f++) {
      var fig = FIGURES[f];
      var prog = clamp01((sp - fig.trigger) * 7) * mul;
      if (prog <= 0) continue;
      var pts = fig.pts, swayK = calm ? 0.25 : 1;
      var P = [];
      for (var i = 0; i < pts.length; i++) {
        P.push([pts[i][0] * W - px * 6 * swayK, parY(pts[i][1], 0.045) - py * 4 * swayK]);
      }
      // total path length → partial reveal
      var total = 0, lens = [];
      for (var e = 0; e < fig.edges.length; e++) {
        var a0 = P[fig.edges[e][0]], a1 = P[fig.edges[e][1]];
        var len = Math.hypot(a1[0] - a0[0], a1[1] - a0[1]);
        lens.push(len); total += len;
      }
      var budget = prog * total;
      ctx.strokeStyle = rgba(PURPLE, 0.30);
      ctx.lineWidth = 0.8;
      ctx.beginPath();
      for (var e2 = 0; e2 < fig.edges.length && budget > 0; e2++) {
        var p0 = P[fig.edges[e2][0]], p1 = P[fig.edges[e2][1]];
        var take = Math.min(1, budget / lens[e2]);
        ctx.moveTo(p0[0], p0[1]);
        ctx.lineTo(p0[0] + (p1[0] - p0[0]) * take, p0[1] + (p1[1] - p0[1]) * take);
        budget -= lens[e2];
      }
      ctx.stroke();
      for (var s2 = 0; s2 < P.length; s2++) {
        var tw = 0.65 + 0.35 * Math.sin(t * 0.9 + s2 * 2.1);
        ctx.globalAlpha = mul * tw;
        ctx.drawImage(sprites.light, P[s2][0] - 7, P[s2][1] - 7, 14, 14);
        ctx.fillStyle = '#FFFFFF';
        ctx.beginPath(); ctx.arc(P[s2][0], P[s2][1], 1.3, 0, TAU); ctx.fill();
      }
      ctx.globalAlpha = 1;
    }
  }

  // ── the named system: la Lune, her companion, two echo lanes ──
  var CRATERS = [[-0.30, -0.12, 0.16], [0.25, -0.35, 0.10], [0.15, 0.30, 0.13],
                 [-0.15, 0.38, 0.08], [0.42, 0.12, 0.07]];
  function drawLune(dt, mul) {
    var swayK = calm ? 0.25 : 1;
    var x = AT.lune[0] * W - px * 8 * swayK;
    var y = parY(AT.lune[1], 0.06) - py * 6 * swayK;
    var R = Math.max(15, Math.min(26, W * 0.016)) * sysK / Math.max(sysK, 0.85);
    var laneR = [78 * sysK, 112 * sysK];

    ctx.strokeStyle = 'rgba(255,255,255,0.045)';
    ctx.lineWidth = 1;
    for (var L = 0; L < 2; L++) {
      ctx.beginPath();
      ctx.arc(x, y, laneR[L], 0, TAU);
      ctx.stroke();
    }

    for (var i = 0; i < echoes.length; i++) {
      var e = echoes[i];
      e.ph += (TAU / (140 + e.age * 150)) * dt;
      var ex = x + Math.cos(e.ph) * e.r * sysK;
      var ey = y + Math.sin(e.ph) * e.r * sysK;
      var fresh = 1 - e.age;
      var breathe = 0.75 + 0.25 * Math.sin(t * 1.3 + e.ph * 2);
      ctx.globalAlpha = mul * (0.35 + 0.55 * fresh) * breathe;
      ctx.drawImage(sprites[fresh > 0.45 ? 'teal' : 'light'],
                    ex - 11, ey - 11, 22, 22);
      ctx.fillStyle = rgba(fresh > 0.45 ? TEAL : LIGHT, 1);
      ctx.beginPath();
      ctx.arc(ex, ey, 1.1 + fresh, 0, TAU);
      ctx.fill();
    }
    ctx.globalAlpha = 1;

    // the companion: one moon in six has one — here, she does
    compPh += (TAU / 115) * dt;
    var cR = Math.max(7, R * 2.1);
    var cx = x + Math.cos(compPh) * cR;
    var cy = y + Math.sin(compPh) * cR * 0.55;
    var front = Math.sin(compPh) > 0;
    function companion() {
      ctx.fillStyle = 'rgba(201,198,190,0.95)';
      ctx.beginPath();
      ctx.arc(cx, cy, Math.max(2.4, R * 0.16) * (front ? 1 : 0.8), 0, TAU);
      ctx.fill();
    }
    if (!front) companion();

    var halo = ctx.createRadialGradient(x, y, R * 0.6, x, y, R * 3);
    halo.addColorStop(0, rgba(MOON, 0.12));
    halo.addColorStop(1, rgba(MOON, 0));
    ctx.globalAlpha = mul;
    ctx.fillStyle = halo;
    ctx.beginPath(); ctx.arc(x, y, R * 3, 0, TAU); ctx.fill();
    var disc = ctx.createRadialGradient(x - R * 0.35, y - R * 0.35, R * 0.1, x, y, R);
    disc.addColorStop(0, '#EFEDE6');
    disc.addColorStop(1, '#9E9B93');
    ctx.fillStyle = disc;
    ctx.beginPath(); ctx.arc(x, y, R, 0, TAU); ctx.fill();
    ctx.fillStyle = 'rgba(3,5,8,0.16)';
    for (var c = 0; c < CRATERS.length; c++) {
      var cr = CRATERS[c];
      ctx.beginPath();
      ctx.arc(x + cr[0] * R, y + cr[1] * R, cr[2] * R, 0, TAU);
      ctx.fill();
    }
    ctx.globalAlpha = 1;
    if (front) companion();
  }

  // ── the artifact: a poem ring, carried line by line ──
  function drawArtifact(dt, mul) {
    ringPh += (TAU / 150) * dt;
    var swayK = calm ? 0.25 : 1;
    var x = AT.artifact[0] * W - px * 7 * swayK;
    var y = parY(AT.artifact[1], 0.08) - py * 5 * swayK;
    var R = 30 * sysK;
    ctx.strokeStyle = rgba(PURPLE, 0.13);
    ctx.lineWidth = 1;
    ctx.beginPath(); ctx.arc(x, y, R, 0, TAU); ctx.stroke();
    var N = 12;
    for (var i = 0; i < N; i++) {
      var a0 = ringPh + (i / N) * TAU;
      var carried = i % 4 === 0; // three lines bright: hands hold them
      var breathe = carried ? 0.75 + 0.25 * Math.sin(t * 0.9 + i) : 1;
      ctx.strokeStyle = rgba(PURPLE, (carried ? 0.8 : 0.28) * breathe * mul);
      ctx.lineWidth = carried ? 1.6 : 1;
      ctx.beginPath();
      ctx.arc(x, y, R, a0, a0 + (carried ? 0.16 : 0.09));
      ctx.stroke();
    }
    ctx.globalAlpha = 0.9 * mul;
    ctx.drawImage(sprites.indigo, x - 13, y - 13, 26, 26);
    ctx.fillStyle = rgba(INDIGO, 1);
    ctx.beginPath(); ctx.arc(x, y, 2.6 * sysK + 0.8, 0, TAU); ctx.fill();
    ctx.globalAlpha = 1;
  }

  // ── Vénus gathers whispered confessions ──
  function drawVenus(dt, mul) {
    venusPh += (TAU / 26) * dt;
    var x = AT.venus[0] * W - px * 5;
    var y = parY(AT.venus[1], 0.05) - py * 4;
    var a = (0.5 + 0.3 * Math.sin(venusPh)) * mul;
    ctx.globalAlpha = a;
    ctx.drawImage(sprites.venus, x - 11, y - 11, 22, 22);
    ctx.fillStyle = rgba(VENUS, 1);
    ctx.beginPath(); ctx.arc(x, y, 1.7, 0, TAU); ctx.fill();
    ctx.globalAlpha = 1;
  }

  // ── the black hole: far, quiet, feeding ──
  function drawHole(dt, mul) {
    holePh += (TAU / 60) * dt;
    var swayK = calm ? 0.25 : 1;
    var x = AT.hole[0] * W - px * 6 * swayK;
    var y = parY(AT.hole[1], 0.07) - py * 5 * swayK;
    var eat = ctx.createRadialGradient(x, y, 2, x, y, 30);
    eat.addColorStop(0, 'rgba(3,5,8,0.85)');
    eat.addColorStop(0.55, 'rgba(3,5,8,0.5)');
    eat.addColorStop(1, 'rgba(3,5,8,0)');
    ctx.globalAlpha = mul;
    ctx.fillStyle = eat;
    ctx.beginPath(); ctx.arc(x, y, 30, 0, TAU); ctx.fill();
    ctx.lineWidth = 1.2;
    ctx.strokeStyle = rgba(TEAL, 0.28);
    ctx.beginPath(); ctx.arc(x, y, 15, holePh, holePh + 1.9); ctx.stroke();
    ctx.strokeStyle = rgba(PURPLE, 0.20);
    ctx.beginPath(); ctx.arc(x, y, 20, -holePh * 0.7 + 2, -holePh * 0.7 + 3.4); ctx.stroke();
    ctx.strokeStyle = rgba(CYAN, 0.30);
    ctx.lineWidth = 1;
    ctx.beginPath(); ctx.arc(x, y, 9.5, 0, TAU); ctx.stroke();
    ctx.fillStyle = '#000';
    ctx.beginPath(); ctx.arc(x, y, 8, 0, TAU); ctx.fill();

    // feeding: a star streak spirals in and dies
    if (!infall && !calm && tReal > nextInfall) {
      infall = { a: rnd(0, TAU), r: 54, w: 2.0, px2: null, py2: null };
    }
    if (infall) {
      infall.r -= dt * 15;
      infall.a += (infall.w + (54 - infall.r) * 0.12) * dt;
      if (infall.r <= 9.5) { infall = null; nextInfall = tReal + rnd(16000, 32000); }
      else {
        var ix = x + Math.cos(infall.a) * infall.r;
        var iy = y + Math.sin(infall.a) * infall.r;
        if (infall.px2 != null) {
          var fade = clamp01((infall.r - 9.5) / 45);
          ctx.strokeStyle = 'rgba(190,235,255,' + (0.55 * fade * mul) + ')';
          ctx.lineWidth = 1;
          ctx.beginPath(); ctx.moveTo(infall.px2, infall.py2); ctx.lineTo(ix, iy); ctx.stroke();
          ctx.globalAlpha = fade * mul;
          ctx.drawImage(sprites.cyan, ix - 7, iy - 7, 14, 14);
        }
        infall.px2 = ix; infall.py2 = iy;
        ctx.globalAlpha = 1;
      }
    }
    ctx.globalAlpha = 1;
  }

  // ── shooting stars — ambient, summoned, and born under the finger ──
  var nextMeteor = 3.5;
  function spawnMeteor(opts) {
    var phoenix = opts && 'phoenix' in opts ? opts.phoenix : Math.random() < 0.2;
    var dir = rnd(0, 1) < 0.5 ? 1 : -1;
    var ang = rnd(Math.PI * 0.14, Math.PI * 0.30);
    var sp = phoenix ? rnd(260, 340) : rnd(380, 560);
    meteors.push({
      x: (opts && 'x' in opts) ? opts.x : rnd(0.05, 0.95) * W,
      y: (opts && 'y' in opts) ? opts.y : rnd(-0.05, 0.4) * H,
      vx: (opts && 'vx' in opts) ? opts.vx : Math.cos(ang) * sp * dir,
      vy: (opts && 'vy' in opts) ? opts.vy : Math.sin(ang) * sp,
      life: 0,
      dur: (opts && opts.manual) ? rnd(1.6, 2.1) : (phoenix ? rnd(2.2, 3.0) : rnd(0.9, 1.5)),
      len: phoenix ? rnd(150, 210) : rnd(80, 140), phoenix: phoenix
    });
    if (meteors.length > 4) meteors.shift();
  }
  function drawMeteors(dt, dtReal, mul) {
    if (!calm) {
      nextMeteor -= dtReal;
      if (nextMeteor <= 0) { spawnMeteor({}); nextMeteor = rnd(7, 16); }
      if (!firstMeteorDone && tReal > 2.4) { // the opening streak, behind the title
        firstMeteorDone = true;
        spawnMeteor({ x: 0.18 * W, y: 0.16 * H, vx: 420, vy: 150, phoenix: true });
      }
    }
    for (var i = meteors.length - 1; i >= 0; i--) {
      var m = meteors[i];
      m.life += dtReal / m.dur;
      if (m.life >= 1) { meteors.splice(i, 1); continue; }
      m.x += m.vx * dt;
      m.y += m.vy * dt;
      var calmMul = calm ? 0.6 : 1;
      var fade = Math.sin(Math.PI * m.life) * calmMul;
      var nl = Math.sqrt(m.vx * m.vx + m.vy * m.vy);
      var nx = m.vx / nl, ny = m.vy / nl;
      var tx = m.x - nx * m.len, ty = m.y - ny * m.len;
      var col = m.phoenix ? CYAN : LIGHT;
      var grad = ctx.createLinearGradient(m.x, m.y, tx, ty);
      grad.addColorStop(0, rgba(col, 0.85 * fade * mul));
      grad.addColorStop(1, rgba(col, 0));
      ctx.strokeStyle = grad;
      ctx.lineWidth = m.phoenix ? 1.6 : 1.1;
      ctx.lineCap = 'round';
      ctx.beginPath(); ctx.moveTo(m.x, m.y); ctx.lineTo(tx, ty); ctx.stroke();
      ctx.globalAlpha = fade * mul;
      ctx.drawImage(sprites[m.phoenix ? 'cyan' : 'light'],
                    m.x - (m.phoenix ? 15 : 9), m.y - (m.phoenix ? 15 : 9),
                    m.phoenix ? 30 : 18, m.phoenix ? 30 : 18);
      ctx.fillStyle = rgba(col, 1);
      ctx.beginPath(); ctx.arc(m.x, m.y, m.phoenix ? 1.7 : 1.2, 0, TAU); ctx.fill();
      ctx.globalAlpha = 1;
    }
  }

  // pressing the void casts a star from where you touched
  window.addEventListener('pointerdown', function (e) {
    var tEl = e.target;
    if (tEl && tEl.closest && tEl.closest('a, button, input, textarea, select, label, #demo, .overlay, .sky-sound')) return;
    var dir = Math.random() < 0.5 ? 1 : -1;
    var ang = rnd(Math.PI * 0.18, Math.PI * 0.32);
    spawnMeteor({ x: e.clientX, y: e.clientY, manual: true,
                  vx: Math.cos(ang) * 380 * dir, vy: Math.sin(ang) * 380 });
    if (AUDIO.on) bellSnd(rnd(-0.5, 0.5), 0.04);
  }, { passive: true });

  // ── Polaris: fixed at the heart of the turning sky ──
  function drawPolaris(mul) {
    var x = POLARIS[0] * W, y = POLARIS[1] * H; // no parallax — the still point
    var a = (0.62 + 0.18 * Math.sin(t * 0.5)) * mul;
    // the flare the Seuil summons
    var flare = 0;
    for (var i = 0; i < effects.length; i++) {
      if (effects[i].type !== 'flare') continue;
      var ph = (tReal - effects[i].t0) / effects[i].dur;
      if (ph >= 0 && ph <= 1) flare = Math.max(flare, Math.sin(Math.PI * ph));
    }
    var haloR = 12 + flare * 22;
    ctx.globalAlpha = a;
    ctx.drawImage(sprites.light, x - haloR, y - haloR, haloR * 2, haloR * 2);
    ctx.fillStyle = '#FFFFFF';
    ctx.beginPath(); ctx.arc(x, y, 1.7 + flare, 0, TAU); ctx.fill();
    ctx.strokeStyle = 'rgba(255,255,255,' + (0.16 + flare * 0.3) + ')';
    ctx.lineWidth = 1;
    ctx.beginPath();
    ctx.moveTo(x - 11, y); ctx.lineTo(x + 11, y);
    ctx.moveTo(x, y - 11); ctx.lineTo(x, y + 11);
    ctx.stroke();
    if (flare > 0) { // an expanding greeting ring
      ctx.strokeStyle = 'rgba(255,255,255,' + (0.25 * flare) + ')';
      ctx.beginPath(); ctx.arc(x, y, 12 + flare * 40, 0, TAU); ctx.stroke();
    }
    ctx.globalAlpha = 1;
  }

  // ── L'Aube: the ember origin at the world's floor ──
  function drawAube(mul) {
    var x = AT.aube[0] * W, y = AT.aube[1] * H;
    var a = (0.7 + 0.3 * Math.sin(t * 0.8 + 1.7)) * mul;
    ctx.globalAlpha = a;
    ctx.drawImage(sprites.ember, x - 17, y - 17, 34, 34);
    ctx.fillStyle = rgba(EMBER, 1);
    ctx.beginPath(); ctx.arc(x, y, 2.0, 0, TAU); ctx.fill();
    ctx.globalAlpha = 1;
  }

  // ── section-summoned effects: the reliquary's seven embers ──
  function drawEffects(mul) {
    for (var i = effects.length - 1; i >= 0; i--) {
      var fx = effects[i];
      var ph = (tReal - fx.t0) / fx.dur;
      if (ph >= 1) { effects.splice(i, 1); continue; }
      if (ph < 0) continue;
      if (fx.type === 'embers') {
        for (var k = 0; k < 7; k++) {
          var kp = clamp01((ph * 9) - k * 0.35); // one ember at a time
          if (kp <= 0) continue;
          var ea = Math.sin(Math.PI * clamp01(ph)) * Math.min(1, kp * 2);
          var ang = Math.PI * (0.12 + k * 0.126); // an arc beyond the moon
          var ex = W * 0.76 - px * 6 + Math.cos(ang) * W * 0.16;
          var ey = H * 0.24 - Math.sin(ang) * H * 0.30 + k * 6;
          ctx.globalAlpha = ea * mul;
          ctx.drawImage(sprites.ember, ex - 12, ey - 12, 24, 24);
          ctx.fillStyle = rgba(EMBER, 1);
          ctx.beginPath(); ctx.arc(ex, ey, 1.6, 0, TAU); ctx.fill();
        }
        ctx.globalAlpha = 1;
      }
    }
  }

  // ── sound is a door: drone + spatialized pentatonic bells, opt-in ──
  var AUDIO = { on: false, ctx: null, master: null, nextBell: 0 };
  var PENTA = [392.00, 440.00, 523.25, 587.33, 659.25]; // G A C D E
  function audioInit() {
    var AC = window.AudioContext || window.webkitAudioContext;
    if (!AC) return false;
    try {
      AUDIO.ctx = new AC();
      AUDIO.master = AUDIO.ctx.createGain();
      AUDIO.master.gain.value = 0;
      AUDIO.master.connect(AUDIO.ctx.destination);
      var d1 = AUDIO.ctx.createOscillator(); d1.type = 'sine'; d1.frequency.value = 70;
      var d2 = AUDIO.ctx.createOscillator(); d2.type = 'sine'; d2.frequency.value = 70.7;
      var dg = AUDIO.ctx.createGain(); dg.gain.value = 0.5;
      d1.connect(dg); d2.connect(dg); dg.connect(AUDIO.master);
      d1.start(); d2.start();
      return true;
    } catch (e) { return false; }
  }
  function bellSnd(pan, gain) {
    if (!AUDIO.ctx || !AUDIO.on) return;
    try {
      var ct = AUDIO.ctx.currentTime;
      var osc = AUDIO.ctx.createOscillator(), g = AUDIO.ctx.createGain();
      osc.type = 'sine';
      osc.frequency.value = PENTA[Math.floor(Math.random() * PENTA.length)];
      g.gain.setValueAtTime(gain || 0.05, ct);
      g.gain.exponentialRampToValueAtTime(0.0001, ct + 2.6);
      var out = g;
      if (AUDIO.ctx.createStereoPanner) {
        var p = AUDIO.ctx.createStereoPanner();
        p.pan.value = Math.max(-1, Math.min(1, pan || 0));
        g.connect(p); out = p;
      }
      osc.connect(g); out.connect(AUDIO.ctx.destination);
      osc.start(); osc.stop(ct + 2.7);
    } catch (e) { /* bells are optional */ }
  }
  (function makeSoundDoor() {
    var btn = document.createElement('button');
    btn.type = 'button';
    btn.className = 'sky-sound';
    btn.textContent = EN ? 'sound' : 'son';
    btn.setAttribute('aria-pressed', 'false');
    btn.addEventListener('click', function () {
      if (!AUDIO.ctx) { if (!audioInit()) return; }
      if (AUDIO.ctx.state === 'suspended' && AUDIO.ctx.resume) AUDIO.ctx.resume();
      AUDIO.on = !AUDIO.on;
      AUDIO.master.gain.setTargetAtTime(AUDIO.on ? 0.05 : 0, AUDIO.ctx.currentTime, 0.4);
      if (AUDIO.on) { AUDIO.nextBell = tReal + 2.5; bellSnd(0, 0.05); }
      btn.textContent = AUDIO.on ? (EN ? 'silence' : 'silence') : (EN ? 'sound' : 'son');
      btn.setAttribute('aria-pressed', AUDIO.on ? 'true' : 'false');
    });
    document.body.appendChild(btn);
  })();

  // ── the territories summon their objects ──
  function findByNum(prefix) {
    var nums = document.querySelectorAll('.card .num');
    for (var i = 0; i < nums.length; i++) {
      if (nums[i].textContent.indexOf(prefix) !== -1) return nums[i].parentNode;
    }
    return null;
  }
  function onceVisible(el, fn) {
    if (!el || !window.IntersectionObserver) return;
    var io = new IntersectionObserver(function (es) {
      es.forEach(function (en) {
        if (en.isIntersecting) { fn(); io.disconnect(); }
      });
    }, { threshold: 0.4 });
    io.observe(el);
  }
  onceVisible(findByNum(EN ? 'TERRITORY 03' : 'TERRITOIRE 03'), function () {
    if (calm) return;
    spawnMeteor({ phoenix: true, x: 0.12 * W, y: 0.1 * H, vx: 470, vy: 190 });
    setTimeout(function () { if (!calm) spawnMeteor({ phoenix: true, x: 0.05 * W, y: 0.2 * H, vx: 500, vy: 210 }); }, 900);
  });
  onceVisible(findByNum(EN ? 'TERRITORY 06' : 'TERRITOIRE 06'), function () {
    effects.push({ type: 'embers', t0: tReal, dur: 11000 });
  });
  (function () { // the Seuil greets with a Polaris flare
    var kicks = document.querySelectorAll('.kicker');
    for (var i = 0; i < kicks.length; i++) {
      var txt = kicks[i].textContent || '';
      if (txt.indexOf('05') === 0 || txt.indexOf(EN ? '05 /' : '05 /') === 0) {
        onceVisible(kicks[i].parentNode, function () {
          effects.push({ type: 'flare', t0: tReal, dur: 4200 });
        });
        return;
      }
    }
  })();

  // ── the turn ──
  function frame(now) {
    requestAnimationFrame(frame);
    if (hidden) return;
    if (!last) last = now;
    var dtRealMs = Math.min(0.1, (now - last) / 1000);
    last = now;
    var dtReal = dtRealMs;
    tReal += dtReal;
    var dt = dtReal * (calm ? CALM_SCALE : 1);
    t += dt;
    scroll = window.scrollY || window.pageYOffset || 0;

    // low-pass the hand (the app's α ≈ 0.08, calmer here)
    var lp = 1 - Math.pow(1 - 0.07, dtRealMs * 60);
    px += (pxT - px) * lp;
    py += (pyT - py) * lp;

    // spatial bells drift through the stereo field, unbidden
    if (AUDIO.on && tReal > AUDIO.nextBell) {
      bellSnd(px * 0.7, 0.045);
      AUDIO.nextBell = tReal + rnd(8, 18);
    }

    ctx.clearRect(0, 0, W, H);
    var mul = clamp01(tReal / 1.7); // the void lights up first
    drawBand(born(0.3));
    drawStars(dt, mul);
    drawFigures(mul);
    drawVestiges(dt, mul);
    drawShard(born(1.6));
    drawArtifact(dt, born(1.1));
    drawVenus(dt, born(0.6));
    drawLune(dt, born(0.8));
    drawHole(dt, born(1.3));
    drawEffects(mul);
    drawMeteors(dt, dtReal, mul);
    drawPolaris(born(0.5));
    drawAube(born(1.5));
  }

  document.addEventListener('visibilitychange', function () {
    hidden = document.hidden;
    last = 0; // no giant catch-up step on return
  });
  window.addEventListener('resize', function () {
    clearTimeout(resizeTimer);
    resizeTimer = setTimeout(function () { build(); docH = Math.max(1, document.documentElement.scrollHeight - H); }, 150);
  });

  sprites.teal = makeGlow(TEAL);
  sprites.cyan = makeGlow(CYAN);
  sprites.indigo = makeGlow(INDIGO);
  sprites.light = makeGlow(LIGHT);
  sprites.ember = makeGlow(EMBER);
  sprites.venus = makeGlow(VENUS);
  build();
  document.body.classList.add('sky-live'); // retire the static fallback field
  requestAnimationFrame(frame);
})();
