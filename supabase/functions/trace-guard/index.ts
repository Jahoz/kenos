// KENOS — the Trace Guard (V3.88): the ether's only gate.
//
// The trace is the ONLY user content the ether ever sees in clear.
// leave_trace stores it; a pg_net webhook (kenos_trace_guard_notify)
// hands it here within the second, with a shared token. Llama Guard 4
// (Groq, free tier) reads it — and the ONLY verdict that acts is the
// illegal floor:
//   S3B1 — sexual content involving minors
//   S3B2 — non-consensual sexual content
//   S4   — child safety
// For those, and only those, the reception's reply_text is burned
// before the author can ever fetch it. Everything else — pain,
// violence lived, despair, even hate in a trace to a stranger — is
// left to the reader's report and the author's burn: those are cries
// and conflicts, and the product's care lives on the writer's device,
// never as censorship here. The floor is the law's floor, not taste.
//
// Fail-open by contract: no key, wrong token is a silent 401, model
// unreachable, malformed reply, timeout — the trace stays. The guard
// is a guest of the law, never its judge.
//
// Setup:
//   supabase secrets set GROQ_API_KEY=gsk_...
//   supabase secrets set TRACE_GUARD_TOKEN=<random hex>
//   -- then, in SQL (operator only):
//   insert into kenos_config (key, value) values
//     ('trace_guard_url',
//      'https://<ref>.supabase.co/functions/v1/trace-guard'),
//     ('trace_guard_token', '<same hex>')
//   on conflict (key) do update set value = excluded.value;

import "@supabase/functions-js/edge-runtime.d.ts";
import { withSupabase } from "@supabase/server";

// The moderation endpoint is a fixed allowlist of one: no request
// target is ever shaped by request data.
const GUARD_ENDPOINT =
  "https://api.groq.com/openai/v1/chat/completions";
const GUARD_MODEL = "meta-llama/llama-guard-4-12b";

// The illegal floor — the only categories where even brief storage
// is intolerable. Llama Guard taxonomy codes, matched anywhere in
// its reply so minor format drift cannot silently disarm the guard.
const FLOOR = new Set(["S3B1", "S3B2", "S4"]);

const UUID =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;

export default {
  // auth "none": the caller is pg_net with the shared door token —
  // no user JWT exists on that road. The only hand inside is
  // ctx.supabaseAdmin (service rank), gated by the token above.
  fetch: withSupabase({ auth: "none" }, async (req, _ctx) => {
    // The webhook's shared token. Not the service key (that never
    // lives in the database) — a door key whose only power, if
    // leaked, is burning incoming traces: an attacker could silence
    // traces, never read or forge one.
    const expected = Deno.env.get("TRACE_GUARD_TOKEN") ?? "";
    if (expected === "" || req.headers.get("x-kenos-token") !== expected) {
      return Response.json({ error: "unknown door" }, { status: 401 });
    }

    const keep = Response.json({ checked: true, burned: false });
    const key = Deno.env.get("GROQ_API_KEY");
    if (!key) return Response.json({ checked: false });

    let echoId: string;
    let text: string;
    try {
      const body = await req.json();
      echoId = String(body?.echoId ?? "");
      text = String(body?.text ?? "");
    } catch (_) {
      return keep;
    }
    // Bound the read: a trace is ≤140 chars — anything longer is not
    // ours, and we never classify more than the product allows.
    text = text.trim().slice(0, 300);
    if (!UUID.test(echoId) || text.length < 2) return keep;

    try {
      const res = await fetch(GUARD_ENDPOINT, {
        method: "POST",
        headers: {
          "Content-Type": "application/json; charset=utf-8",
          Authorization: `Bearer ${key}`,
        },
        body: JSON.stringify({
          model: GUARD_MODEL,
          temperature: 0,
          max_tokens: 32,
          messages: [{ role: "user", content: text }],
        }),
        signal: AbortSignal.timeout(6_000),
      });
      if (!res.ok) return keep;
      const data = await res.json();
      const verdict: string =
        data?.choices?.[0]?.message?.content ?? "";
      if (!verdict.toLowerCase().startsWith("unsafe")) return keep;

      // Llama Guard answers "safe" or "unsafe\nS1,S3B1" — collect the
      // codes and intersect with the floor. Only the floor burns.
      const codes = (verdict.toUpperCase().match(/\bS\d+B?\d*\b/g) ?? []);
      if (!codes.some((c) => FLOOR.has(c))) return keep;

      const { error } = await _ctx.supabaseAdmin.rpc(
        "admin_burn_reception",
        { p_echo_id: echoId },
      );
      if (error) return keep;
      return Response.json({ checked: true, burned: true });
    } catch (_) {
      return keep;
    }
  }),
};
