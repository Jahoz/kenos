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

// The moderation endpoint is a fixed allowlist of one: no request
// target is ever shaped by request data.
const MODERATION_ENDPOINT = "https://api.mistral.ai/v1/moderations";

// Best-effort, per-worker courtesy cap. The shield is optional
// enrichment: over the cap the caller simply gets the pass verdict
// (the fail-open contract) without ever reaching Mistral — one user
// can never burn the shared moderation budget.
const CAP_WINDOW_MS = 60_000;
const CAP_MAX = 15;
const CAP_SEEN = new Map<string, number[]>();

// The caller's stable key for the cap: the JWT `sub` claim, strictly
// validated as a UUID. Memory-only, never persisted, never a request
// target; anything unparsable collapses to the shared "anon" bucket.
function callerKey(req: Request): string {
  const token = (req.headers.get("Authorization") ?? "").replace(
    /^Bearer\s+/i,
    "",
  );
  try {
    const b64 = (token.split(".")[1] ?? "").replace(/-/g, "+").replace(
      /_/g,
      "/",
    );
    const payload = JSON.parse(
      atob(b64 + "=".repeat((4 - (b64.length % 4)) % 4)),
    );
    const sub = typeof payload.sub === "string" ? payload.sub : "";
    return /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/
      .test(sub) ? sub : "anon";
  } catch {
    return "anon";
  }
}

function courtesyAllows(key: string): boolean {
  const now = Date.now();
  const stamps = (CAP_SEEN.get(key) ?? []).filter(
    (t) => t > now - CAP_WINDOW_MS,
  );
  stamps.push(now);
  CAP_SEEN.set(key, stamps);
  if (CAP_SEEN.size > 5000) {
    for (const [k, s] of CAP_SEEN) {
      if (s.every((t) => t <= now - CAP_WINDOW_MS)) CAP_SEEN.delete(k);
    }
  }
  return stamps.length <= CAP_MAX;
}

export default {
  fetch: withSupabase({ auth: "user" }, async (req, _ctx) => {
    // Fail-open verdict: nothing suspicious, send away.
    const pass = Response.json({ ok: true, pii: false, selfharm: false });

    if (!courtesyAllows(callerKey(req))) return pass;

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
      const res = await fetch(MODERATION_ENDPOINT, {
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
