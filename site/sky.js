// KENOS — the living sky of the landing (2026-09-25).
//
// The showcase breathes what the product breathes: a miniature of the
// app's cosmology (V3.75–77 constitution).
//   · three depth fields of breathing stars, drifting on tempos
//     catchable in a ten-second gaze (V3.74: never a carousel);
//   · the named system: la Lune with her companion and two echo
//     lanes — echoes age, they pale and slow (V3.75) — an artifact
//     planet ringed with poem lines, Vénus low, and at the world's
//     floor L'Aube, the ember origin;
//   · Polaris, fixed — the only body immune to the scroll parallax;
//   · vestiges drifting forever through the culture band (a vestige
//     never dies — "il se relit toujours");
//   · shooting stars, and among them the teal phoenix, whose trail
//     crosses every orbit (one in five);
//   · the black hole, far and quiet: a photon ring, two slow
//     contra-rotating accretion arcs, eating the stars behind it.
//
// Laws honored: ROSE never appears in this sky (destruction owns it —
// the burn overlay alone); reduced motion CALMS the heavens (clocks
// ×5 slower, meteors skip — V3.73) but never stills them. The static
// CSS star field under the canvas stands as the no-JS truth.
(function () {
  'use strict';

  var TAU = Math.PI * 2;
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

  // ── stage: viewport fractions; the sky adapts, never repeats ──
  var AT = {
    venus:    [0.14, 0.12],
    lune:     [0.76, 0.24],  // hero-side: moon + companion + echo lanes
    artifact: [0.16, 0.66],  // poem ring
    hole:     [0.88, 0.50],
    aube:     [0.50, 0.94]   // the ember origin — the world's floor
  };
  var POLARIS = [0.06, 0.86]; // fixed: no parallax, no drift — the still heart

  var W = 0, H = 0, sysK = 1, areaK = 1;
  var stars = [], vestiges = [], meteors = [], echoes = [];
  var compPh = 1.2, ringPh = 0.4, holePh = 0, venusPh = 0.4;
  var t = 0, last = 0, scroll = 0, hidden = false, resizeTimer = 0;

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
    var py = fy * H - scroll * k;
    return (((py + m) % span) + span) % span - m;
  }

  function build() {
    var dpr = Math.min(window.devicePixelRatio || 1, 2);
    W = window.innerWidth;
    H = window.innerHeight;
    canvas.width = Math.round(W * dpr);
    canvas.height = Math.round(H * dpr);
    if (ctx.setTransform) ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    areaK = Math.max(0.55, Math.min(1.6, (W * H) / (1280 * 800)));
    sysK = Math.max(0.62, Math.min(1, W / 1100)); // the named system shrinks on phones

    stars.length = 0;
    var fields = [[0.32, 110], [0.62, 66], [1, 36]];
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

  // ── deep field ──
  function drawStars(dt) {
    var drift = dt / 60; // vx is px/min
    for (var i = 0; i < stars.length; i++) {
      var s = stars[i];
      s.x += (s.vx * drift) / W;
      var px = (((s.x % 1) + 1) % 1) * W;
      var py = parY(s.y, 0.05 * s.d);
      ctx.globalAlpha = s.a * (0.72 + 0.28 * Math.sin(t * s.tw + s.ph));
      ctx.fillStyle = rgba(s.c, 1);
      ctx.beginPath();
      ctx.arc(px, py, s.r, 0, TAU);
      ctx.fill();
    }
    ctx.globalAlpha = 1;
  }

  // ── vestiges: small, pale, forever ──
  function drawVestiges(dt) {
    ctx.fillStyle = rgba(VESTIGE, 1);
    for (var i = 0; i < vestiges.length; i++) {
      var v = vestiges[i];
      v.x += (v.vx / 60) * dt / W;
      v.wob += (TAU / v.was) * dt;
      var px = (((v.x % 1) + 1) % 1) * W;
      var py = parY(v.y + Math.sin(v.wob) * 0.008, 0.05);
      ctx.globalAlpha = v.a * (0.7 + 0.3 * Math.sin(t * 0.6 + v.wob));
      ctx.beginPath();
      ctx.arc(px, py, v.r, 0, TAU);
      ctx.fill();
    }
    ctx.globalAlpha = 1;
  }

  // ── the named system: la Lune, her companion, two echo lanes ──
  var CRATERS = [[-0.30, -0.12, 0.16], [0.25, -0.35, 0.10], [0.15, 0.30, 0.13],
                 [-0.15, 0.38, 0.08], [0.42, 0.12, 0.07]];
  function drawLune(dt) {
    var x = AT.lune[0] * W, y = parY(AT.lune[1], 0.06);
    var R = Math.max(15, Math.min(26, W * 0.016)) * sysK / Math.max(sysK, 0.85);
    var laneR = [78 * sysK, 112 * sysK];

    // lane guides — faint, like the app's orbit rings
    ctx.strokeStyle = 'rgba(255,255,255,0.045)';
    ctx.lineWidth = 1;
    for (var L = 0; L < 2; L++) {
      ctx.beginPath();
      ctx.arc(x, y, laneR[L], 0, TAU);
      ctx.stroke();
    }

    // echoes orbit by lane; age pales them and slows their stride (V3.75)
    for (var i = 0; i < echoes.length; i++) {
      var e = echoes[i];
      e.ph += (TAU / (140 + e.age * 150)) * dt;
      var ex = x + Math.cos(e.ph) * e.r * sysK;
      var ey = y + Math.sin(e.ph) * e.r * sysK;
      var fresh = 1 - e.age;
      var breathe = 0.75 + 0.25 * Math.sin(t * 1.3 + e.ph * 2);
      ctx.globalAlpha = (0.35 + 0.55 * fresh) * breathe;
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

    // la Lune herself
    var halo = ctx.createRadialGradient(x, y, R * 0.6, x, y, R * 3);
    halo.addColorStop(0, rgba(MOON, 0.12));
    halo.addColorStop(1, rgba(MOON, 0));
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
    if (front) companion();
  }

  // ── the artifact: a poem ring, carried line by line ──
  function drawArtifact(dt) {
    ringPh += (TAU / 150) * dt;
    var x = AT.artifact[0] * W, y = parY(AT.artifact[1], 0.08);
    var R = 30 * sysK;
    ctx.strokeStyle = rgba(PURPLE, 0.13);
    ctx.lineWidth = 1;
    ctx.beginPath(); ctx.arc(x, y, R, 0, TAU); ctx.stroke();
    var N = 12;
    for (var i = 0; i < N; i++) {
      var a0 = ringPh + (i / N) * TAU;
      var carried = i % 4 === 0; // three lines bright: hands hold them
      var breathe = carried ? 0.75 + 0.25 * Math.sin(t * 0.9 + i) : 1;
      ctx.strokeStyle = rgba(PURPLE, (carried ? 0.8 : 0.28) * breathe);
      ctx.lineWidth = carried ? 1.6 : 1;
      ctx.beginPath();
      ctx.arc(x, y, R, a0, a0 + (carried ? 0.16 : 0.09));
      ctx.stroke();
    }
    ctx.globalAlpha = 0.9;
    ctx.drawImage(sprites.indigo, x - 13, y - 13, 26, 26);
    ctx.fillStyle = rgba(INDIGO, 1);
    ctx.beginPath(); ctx.arc(x, y, 2.6 * sysK + 0.8, 0, TAU); ctx.fill();
    ctx.globalAlpha = 1;
  }

  // ── Vénus gathers whispered confessions ──
  function drawVenus(dt) {
    venusPh += (TAU / 26) * dt;
    var x = AT.venus[0] * W, y = parY(AT.venus[1], 0.05);
    var a = 0.5 + 0.3 * Math.sin(venusPh);
    ctx.globalAlpha = a;
    ctx.drawImage(sprites.venus, x - 11, y - 11, 22, 22);
    ctx.fillStyle = rgba(VENUS, 1);
    ctx.beginPath(); ctx.arc(x, y, 1.7, 0, TAU); ctx.fill();
    ctx.globalAlpha = 1;
  }

  // ── the black hole: far, quiet, eating the stars behind it ──
  function drawHole(dt) {
    holePh += (TAU / 60) * dt;
    var x = AT.hole[0] * W, y = parY(AT.hole[1], 0.07);
    var eat = ctx.createRadialGradient(x, y, 2, x, y, 30);
    eat.addColorStop(0, 'rgba(3,5,8,0.85)');
    eat.addColorStop(0.55, 'rgba(3,5,8,0.5)');
    eat.addColorStop(1, 'rgba(3,5,8,0)');
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
  }

  // ── shooting stars, and the phoenix among them ──
  var nextMeteor = 4;
  function spawnMeteor() {
    var phoenix = Math.random() < 0.2;
    var dir = Math.random() < 0.5 ? 1 : -1;
    var ang = rnd(Math.PI * 0.14, Math.PI * 0.30);
    var sp = phoenix ? rnd(260, 340) : rnd(380, 560);
    meteors.push({
      x: rnd(0.05, 0.95) * W, y: rnd(-0.05, 0.4) * H,
      vx: Math.cos(ang) * sp * dir, vy: Math.sin(ang) * sp,
      life: 0, dur: phoenix ? rnd(2.2, 3.0) : rnd(0.9, 1.5),
      len: phoenix ? rnd(150, 210) : rnd(80, 140), phoenix: phoenix
    });
    if (meteors.length > 3) meteors.shift();
  }
  function drawMeteors(dt, dtReal) {
    if (!calm) { // under the calm law, shooting stars skip (V3.73)
      nextMeteor -= dtReal;
      if (nextMeteor <= 0) { spawnMeteor(); nextMeteor = rnd(7, 16); }
    }
    for (var i = meteors.length - 1; i >= 0; i--) {
      var m = meteors[i];
      m.life += dtReal / m.dur;
      if (m.life >= 1) { meteors.splice(i, 1); continue; }
      m.x += m.vx * dt;
      m.y += m.vy * dt;
      var fade = Math.sin(Math.PI * m.life);
      var nl = Math.sqrt(m.vx * m.vx + m.vy * m.vy);
      var nx = m.vx / nl, ny = m.vy / nl;
      var tx = m.x - nx * m.len, ty = m.y - ny * m.len;
      var col = m.phoenix ? CYAN : LIGHT;
      var grad = ctx.createLinearGradient(m.x, m.y, tx, ty);
      grad.addColorStop(0, rgba(col, 0.85 * fade));
      grad.addColorStop(1, rgba(col, 0));
      ctx.strokeStyle = grad;
      ctx.lineWidth = m.phoenix ? 1.6 : 1.1;
      ctx.lineCap = 'round';
      ctx.beginPath(); ctx.moveTo(m.x, m.y); ctx.lineTo(tx, ty); ctx.stroke();
      ctx.globalAlpha = fade;
      ctx.drawImage(sprites[m.phoenix ? 'cyan' : 'light'],
                    m.x - (m.phoenix ? 15 : 9), m.y - (m.phoenix ? 15 : 9),
                    m.phoenix ? 30 : 18, m.phoenix ? 30 : 18);
      ctx.fillStyle = rgba(col, 1);
      ctx.beginPath(); ctx.arc(m.x, m.y, m.phoenix ? 1.7 : 1.2, 0, TAU); ctx.fill();
      ctx.globalAlpha = 1;
    }
  }

  // ── Polaris: fixed at the heart of the turning sky ──
  function drawPolaris() {
    var x = POLARIS[0] * W, y = POLARIS[1] * H; // no parallax — the still point
    var a = 0.62 + 0.18 * Math.sin(t * 0.5);
    ctx.globalAlpha = a;
    ctx.drawImage(sprites.light, x - 12, y - 12, 24, 24);
    ctx.fillStyle = '#FFFFFF';
    ctx.beginPath(); ctx.arc(x, y, 1.7, 0, TAU); ctx.fill();
    ctx.strokeStyle = 'rgba(255,255,255,0.16)';
    ctx.lineWidth = 1;
    ctx.beginPath();
    ctx.moveTo(x - 11, y); ctx.lineTo(x + 11, y);
    ctx.moveTo(x, y - 11); ctx.lineTo(x, y + 11);
    ctx.stroke();
    ctx.globalAlpha = 1;
  }

  // ── L'Aube: the ember origin at the world's floor ──
  function drawAube() {
    var x = AT.aube[0] * W, y = AT.aube[1] * H;
    var a = 0.7 + 0.3 * Math.sin(t * 0.8 + 1.7);
    ctx.globalAlpha = a;
    ctx.drawImage(sprites.ember, x - 17, y - 17, 34, 34);
    ctx.fillStyle = rgba(EMBER, 1);
    ctx.beginPath(); ctx.arc(x, y, 2.0, 0, TAU); ctx.fill();
    ctx.globalAlpha = 1;
  }

  // ── the turn ──
  function frame(now) {
    requestAnimationFrame(frame);
    if (hidden) return;
    if (!last) last = now;
    var dtReal = Math.min(0.1, (now - last) / 1000);
    last = now;
    var dt = dtReal * (calm ? CALM_SCALE : 1);
    t += dt;
    scroll = window.scrollY || window.pageYOffset || 0;

    ctx.clearRect(0, 0, W, H);
    drawStars(dt);
    drawVestiges(dt);
    drawArtifact(dt);
    drawVenus(dt);
    drawLune(dt);
    drawHole(dt);
    drawMeteors(dt, dtReal);
    drawPolaris();
    drawAube();
  }

  document.addEventListener('visibilitychange', function () {
    hidden = document.hidden;
    last = 0; // no giant catch-up step on return
  });
  window.addEventListener('resize', function () {
    clearTimeout(resizeTimer);
    resizeTimer = setTimeout(build, 150);
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
