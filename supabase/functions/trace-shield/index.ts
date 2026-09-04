// KENOS — the Trace Shield (V3.15).
//
// The ONLY user content the ether ever sees in clear is the trace
// (≤140 chars, one shot). Before it drifts, this edge function reads
// it through Mistral's moderation model and returns two quiet flags:
//   pii      — the writer is about to burn their own anonymity
//              (phone, address, email…). The app WARNS, never blocks:
//              the contract is anonymity, and choosing is the user's.
//   selfharm — a real pain is being left in the void. The app offers
//              a care moment with resources, never censorship: the
//              cry belongs to the one who wrote it.
//
// Sealed content (echoes, constellations, songs) is structurally
// invisible here — AES-256-GCM on-device, by design, forever.
//
// Fail-open by contract: no key configured, Mistral unreachable, any
// parse trouble → { ok: true } and the trace proceeds untouched. The
// shield is a guest, never a gate.
//
// Setup: supabase secrets set MISTRAL_API_KEY=rzZ…

import "@supabase/functions-js/edge-runtime.d.ts";
import { withSupabase } from "@supabase/server";

export default {
  fetch: withSupabase({ auth: "user" }, async (req, _ctx) => {
    // Fail-open verdict: nothing suspicious, send away.
    const pass = Response.json({ ok: true, pii: false, selfharm: false });

    const key = Deno.env.get("MISTRAL_API_KEY");
    if (!key) return pass;

    let text: string;
    try {
      const body = await req.json();
      text = String(body?.text ?? "");
    } catch (_) {
      return pass;
    }
    // Bound the call: a trace is ≤140 chars — anything longer is not
    // ours, and we never send more than the product allows.
    text = text.trim().slice(0, 300);
    if (text.length < 2) return pass;

    try {
      const res = await fetch("https://api.mistral.ai/v1/moderations", {
        method: "POST",
        headers: {
          "Content-Type": "application/json; charset=utf-8",
          Authorization: `Bearer ${key}`,
        },
        body: JSON.stringify({
          model: "mistral-moderation-latest",
          input: text,
        }),
      });
      if (!res.ok) return pass;
      const data = await res.json();
      const scores = data?.results?.[0]?.category_scores;
      if (!scores || typeof scores !== "object") return pass;

      const pii = Number(scores.pii ?? 0);
      const selfharm = Number(scores.selfharm ?? 0);

      return Response.json({
        ok: true,
        // Thresholds from live probing (2026-09-04): real leaks score
        // 1.0, benign traces ≤0.05 — 0.8 leaves a wide honest margin.
        pii: pii > 0.8,
        selfharm: selfharm > 0.85,
      });
    } catch (_) {
      return pass;
    }
  }),
};
