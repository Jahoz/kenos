// KENOS — the landing's ear to the ether (V3.54, C3).
//
// The past-moons calendar: which POETS inhabited the sky, and which
// Mondays — never the poems (the ether forgets, the landing names).
// The publishable key is public by design (the PWA ships it too);
// the only anon-readable surface is fetch_past_moons — released lunes
// alone, shapes only.
//
// Honest degradation: the static list below is the truth as of the
// last deploy; when the ether answers, it is replaced by the live
// truth. When it does not, the page stays quiet and true.
(function () {
  var ETHER_URL = "https://xmbdrzkvjxaaoqwluonx.supabase.co";
  var ETHER_ANON_KEY = "sb_publishable_DYyU1kOPhbId3BvQ73-8Nw_QQoEQtt3";

  function row(moon, idx) {
    var li = document.createElement("li");
    li.className = "moon";
    var phase = document.createElement("span");
    phase.className = "moon-phase";
    // each Monday the calendar's moon is reborn thin, then waxes with age
    phase.style.boxShadow = "inset " + Math.max(0, 6.5 - idx * 1.1) + "px 0 0 0 #030508";
    li.appendChild(phase);
    var date = document.createElement("span");
    date.className = "moon-date";
    date.textContent = moon.released_on;
    var who = document.createElement("span");
    who.className = "moon-poet";
    who.textContent = moon.poet;
    var what = document.createElement("span");
    what.className = "moon-title";
    what.textContent = moon.title;
    li.appendChild(date);
    li.appendChild(who);
    li.appendChild(what);
    return li;
  }

  function fill(moons) {
    var list = document.getElementById("moon-list");
    if (!list || !moons || !moons.length) return;
    list.textContent = "";
    for (var i = 0; i < moons.length; i++) list.appendChild(row(moons[i], i));
    var foot = document.getElementById("moon-foot");
    if (foot) foot.hidden = false;
  }

  window.kenosMoons = function () {
    try {
      fetch(ETHER_URL + "/rest/v1/rpc/fetch_past_moons", {
        method: "POST",
        headers: {
          "apikey": ETHER_ANON_KEY,
          "Authorization": "Bearer " + ETHER_ANON_KEY,
          "Content-Type": "application/json",
        },
        body: "{}",
      })
        .then(function (r) { return r.ok ? r.json() : null; })
        .then(function (moons) { if (moons) fill(moons); })
        .catch(function () { /* the sky is far — the static list stands */ });
    } catch (_) {
      /* no fetch, no sorrow */
    }
  };

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", window.kenosMoons);
  } else {
    window.kenosMoons();
  }
})();
