// V3.57 — the Shard Sower's engine (the Observatory module's arm).
//
// The guardian taps SEMER; this function carries the two AI passes
// (sow in the kenos voice, then an unforgiving fact-check) and hands
// the survivors to the guardian-gated RPC — every guard that matters
// lives in tested SQL, this is only the road. The key never leaves
// the server secrets; without it the answer is the honest
// { sown: 0, reason: "unconfigured" } — the door-preview contract.
//
// Setup (free tiers, OpenAI-compatible):
//   supabase secrets set VESTIGE_AI_KEY=AIza...
//   # optional overrides:
//   supabase secrets set VESTIGE_AI_URL=https://generativelanguage.googleapis.com/v1beta/openai/chat/completions
//   supabase secrets set VESTIGE_AI_MODEL=gemini-2.5-flash

import "@supabase/functions-js/edge-runtime.d.ts";
import { withSupabase } from "@supabase/server";

const KINDS = new Set(["quote", "etymology", "haiku", "history", "fact"]);

const VOICE_GUIDE = `Tu es le curateur des Vestiges de KENOS — une app française de
décharge cognitive où des pensées intimes dérivent dans un « éther »
cosmique. Les Vestiges sont des éclats de CULTURE RÉELLE qui dérivent
aussi : citations, étymologies, faits (astronomie, physique, océan,
neurosciences), micro-histoires, haïkus. Le voyageur seul les lit en
frôlant le vide.

LA VOIX (sacrée) :
- français, court (max ~200 caractères), précis, légèrement poétique —
  jamais mièvre, jamais « wow », jamais liste à la Prévert ;
- un éclat se lit comme une confidence de l'univers, pas comme une
  fiche Wikipédia : le fait est exact, la tournure est contemplative ;
- la source cite le domaine ou l'auteur ('astronomie', 'grec ancien',
  'Sénèque'), jamais d'URL, jamais de date superflue ;
- les FAITS doivent être VÉRIFIABLES et SANS CONTESTATION : une
  constante physique connue, un événement daté documenté, une
  étymologie de dictionnaire. Si tu n'es pas sûr à 100 %, ne le sème
  pas. AUCUN chiffre inventé, aucune « statistique » approximative.
- les CITATIONS doivent être de vraies phrases d'auteurs morts il y a
  plus de 70 ans (domaine public), mot pour mot ou clairement marquées
  « après X » si adaptées.

Exemples de la voix (corpus vivant ci-dessous).`;

const VERIFY_GUIDE = `Tu es un fact-checker impitoyable pour une bibliothèque culturelle
française. Pour chaque éclat : le FAIT est-il exact et vérifiable
sans contestation ? La CITATION est-elle authentique et de domaine
public ? L'ÉTYMOLOGIE est-elle correcte ? Note chaque item :
{"verdict": "ok"|"fix"|"drop", "confidence": 0-1, "reason": "...",
"text": "version corrigée si fix"}.
Un chiffre arrondi au point d'être faux = drop. Une citation
paraphrasée non marquée = fix (marque « après X ») ou drop.
Une étymologie contestée = drop. La prudence prime : dans le doute, drop.`;

interface Shard {
  kind: string;
  text: string;
  source: string;
}

function salvageJson(raw: string): Record<string, unknown> {
  let text = raw.trim();
  const fenced = text.match(/```(?:json)?\s*([\s\S]*?)```/);
  if (fenced) text = fenced[1].trim();
  const start = text.indexOf("{");
  const end = text.lastIndexOf("}");
  if (start >= 0 && end > start) text = text.substring(start, end + 1);
  return JSON.parse(text) as Record<string, unknown>;
}

// The AI endpoint comes from server secrets, not from the request —
// the hygiene check still refuses loopback/private hosts outright.
function validatedUrl(raw: string): URL {
  const uri = new URL(raw);
  if (uri.protocol !== "https:" && uri.protocol !== "http:") {
    throw new Error(`VESTIGE_AI_URL must be http/https: ${raw}`);
  }
  const host = uri.hostname;
  const blocked = ["localhost", "0.0.0.0", "[::1]", "metadata.google.internal"];
  const priv = host.startsWith("127.") || host.startsWith("10.") ||
    host.startsWith("192.168.") || host.startsWith("169.254.");
  if (blocked.includes(host) || priv) {
    throw new Error(`VESTIGE_AI_URL host refused: ${host}`);
  }
  return uri;
}

async function chat(
  messages: { role: string; content: string }[],
  opts: { temperature: number },
): Promise<Record<string, unknown>> {
  const url = validatedUrl(
    Deno.env.get("VESTIGE_AI_URL") ??
      "https://generativelanguage.googleapis.com/v1beta/openai/chat/completions",
  );
  const key = Deno.env.get("VESTIGE_AI_KEY");
  if (!key) throw new Error("unconfigured");
  const model = Deno.env.get("VESTIGE_AI_MODEL") ?? "gemini-2.5-flash";

  const res = await fetch(url, {
    method: "POST",
    headers: {
      "Content-Type": "application/json; charset=utf-8",
      "Authorization": `Bearer ${key}`,
    },
    body: JSON.stringify({
      model,
      messages,
      temperature: opts.temperature,
      max_tokens: 4096,
      response_format: { type: "json_object" },
    }),
  });
  const body = await res.text();
  if (!res.ok) {
    throw new Error(`ai ${res.status}: ${body.slice(0, 200)}`);
  }
  const decoded = JSON.parse(body) as {
    choices?: { message?: { content?: string } }[];
  };
  const content = decoded.choices?.[0]?.message?.content ?? "";
  return salvageJson(content);
}

function asShards(v: unknown): Shard[] {
  if (!Array.isArray(v)) return [];
  const out: Shard[] = [];
  for (const item of v) {
    if (typeof item !== "object" || item === null) continue;
    const s = item as Record<string, unknown>;
    out.push({
      kind: String(s.kind ?? "").trim(),
      text: String(s.text ?? "").trim(),
      source: String(s.source ?? "").trim(),
    });
  }
  return out;
}

Deno.serve(
  withSupabase({ auth: "user" }, async (req, ctx) => {
    let count = 6;
    let theme = "astronomie, étymologies, micro-histoires — le choix du semeur";
    try {
      const body = (await req.json()) as { count?: number; theme?: string };
      if (typeof body.count === "number") {
        count = Math.max(1, Math.min(12, Math.round(body.count)));
      }
      if (typeof body.theme === "string" && body.theme.trim()) {
        theme = body.theme.trim().slice(0, 200);
      }
    } catch {
      // No or broken body: the defaults sow on.
    }

    // The living corpus, for the few-shot voice (never duplicated).
    let corpus: { kind: string; text: string; source: string }[] = [];
    try {
      const { data } = await ctx.supabase.rpc("fetch_vestiges", {
        p_locale: "fr",
      });
      if (Array.isArray(data)) {
        corpus = data
          .slice(0, 8)
          .map((r: Record<string, unknown>) => ({
            kind: String(r.kind ?? ""),
            text: String(r.text ?? ""),
            source: String(r.source ?? ""),
          }));
      }
    } catch {
      // The voice guide carries the examples' spirit regardless.
    }
    const fewShot = corpus
      .map((c) => `[${c.kind}] ${c.text} — ${c.source}`)
      .join("\n");

    // Pass 1: sow.
    let batch: Shard[];
    try {
      const out = await chat(
        [
          {
            role: "system",
            content: `${VOICE_GUIDE}\n\nCorpus vivant (ne pas dupliquer) :\n${fewShot}`,
          },
          {
            role: "user",
            content:
              `Sème ${count} éclats sur le thème : ${theme}.\n` +
              `Réponds en JSON : {"vestiges": [{"kind": "quote|etymology|haiku|history|fact", "text": "...", "source": "..."}]}`,
          },
        ],
        { temperature: 0.9 },
      );
      batch = asShards(out.vestiges).filter((s) =>
        KINDS.has(s.kind) && s.text.length >= 10 && s.text.length <= 400
      );
    } catch (e) {
      const reason = String(e?.message ?? e);
      return Response.json({
        sown: 0,
        reason: reason.includes("unconfigured") ? "unconfigured" : "ai",
        detail: reason.slice(0, 200),
      });
    }
    if (batch.length === 0) {
      return Response.json({ sown: 0, generated: 0, reason: "empty" });
    }

    // Pass 2: the unforgiving fact-check (fix-in-place allowed).
    let kept = batch;
    try {
      const numbered = batch
        .map((s, i) => `${i + 1}. [${s.kind}] ${s.text} — ${s.source}`)
        .join("\n");
      const out = await chat(
        [
          { role: "system", content: VERIFY_GUIDE },
          { role: "user", content: numbered },
        ],
        { temperature: 0.1 },
      );
      // Providers disagree on the verify shape: items[] or keyed map.
      const verdicts: Record<string, unknown>[] = Array.isArray(out.items)
        ? out.items as Record<string, unknown>[]
        : Object.keys(out)
          .filter((k) => k !== "items")
          .sort((a, b) => (parseInt(a) || 1e9) - (parseInt(b) || 1e9))
          .map((k) => out[k] as Record<string, unknown>);
      kept = [];
      batch.forEach((shard, i) => {
        const v = verdicts[i];
        if (!v) return;
        const conf = typeof v.confidence === "number" ? v.confidence : 0;
        if (v.verdict === "ok" && conf >= 0.8) kept.push(shard);
        else if (v.verdict === "fix" && conf >= 0.8) {
          const fixed = typeof v.text === "string" ? v.text.trim() : "";
          if (fixed.length >= 10) kept.push({ ...shard, text: fixed });
        }
        // drop or low confidence: gone.
      });
    } catch {
      // The verifier silent = the harvest stands unverified? No: the
      // gate is downstream (the human) — keep the batch, say so.
    }

    // The survivors land as PROPOSALS through the guardian-gated RPC:
    // every SQL guard (kind, measure, dedup) fires there, in tested
    // code — this road only carries.
    const { data: sown, error } = await ctx.supabase.rpc(
      "admin_sow_vestige_proposals",
      { p_proposals: kept, p_theme: theme },
    );
    if (error) {
      return Response.json({
        sown: 0,
        generated: batch.length,
        reason: error.message.includes("KENOS_FORBIDDEN")
          ? "forbidden"
          : "rpc",
        detail: String(error.message).slice(0, 200),
      });
    }
    return Response.json({
      sown: typeof sown === "number" ? sown : 0,
      generated: batch.length,
      verified: kept.length,
    });
  }),
);
