// V3.10b' — the voice inside the void.
//
// Resolves a Spotify 30-second preview URL for the excerpt door. The
// track id arrives from the single winner (it was unsealed on their
// device); nothing here knows which echo, which text, or which author.
//
// Graceful degradation is the contract: no credentials configured, a
// cold Spotify token, or a catalog without previews all answer
// { url: null } — the client falls back to the door alone.

// Setup type definitions for built-in Supabase Runtime APIs
import "@supabase/functions-js/edge-runtime.d.ts";
import { withSupabase } from "@supabase/server";

// The Spotify endpoints are a fixed allowlist: no request target is
// ever shaped by request data (the track id is strictly validated and
// encoded below).
const SPOTIFY_TOKEN_ENDPOINT = "https://accounts.spotify.com/api/token";
const SPOTIFY_TRACK_ENDPOINT = "https://api.spotify.com/v1/tracks/";

// Best-effort, per-worker courtesy cap (the Spotify quota is a shared
// good). Over the cap the caller gets the documented graceful
// degradation — { url: null } — never an error.
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

// Client-credentials token, cached across warm invocations (Spotify
// tokens live ~1 h; refresh a little before the edge).
let cachedToken: { value: string; expiresAt: number } | null = null;

async function spotifyToken(
  clientId: string,
  clientSecret: string,
): Promise<string | null> {
  if (cachedToken && cachedToken.expiresAt > Date.now() + 30_000) {
    return cachedToken.value;
  }
  const response = await fetch(SPOTIFY_TOKEN_ENDPOINT, {
    method: "POST",
    headers: {
      "Content-Type": "application/x-www-form-urlencoded",
      Authorization: "Basic " + btoa(`${clientId}:${clientSecret}`),
    },
    body: "grant_type=client_credentials",
  });
  if (!response.ok) return null;
  const data = await response.json();
  if (typeof data.access_token !== "string") return null;
  const expiresIn = typeof data.expires_in === "number" ? data.expires_in : 3600;
  cachedToken = {
    value: data.access_token,
    expiresAt: Date.now() + expiresIn * 1000,
  };
  return cachedToken.value;
}

export default {
  fetch: withSupabase({ auth: "user" }, async (req, _ctx) => {
    if (!courtesyAllows(callerKey(req))) {
      return Response.json({ url: null, reason: "rate" });
    }

    const clientId = Deno.env.get("SPOTIFY_CLIENT_ID");
    const clientSecret = Deno.env.get("SPOTIFY_CLIENT_SECRET");
    if (!clientId || !clientSecret) {
      return Response.json({ url: null, reason: "unconfigured" });
    }

    let trackId: unknown;
    try {
      ({ trackId } = await req.json());
    } catch {
      return Response.json({ error: "invalid request" }, { status: 400 });
    }
    // Strict shape: a bare Spotify track id, nothing else rides along.
    if (typeof trackId !== "string" || !/^[0-9A-Za-z]{22}$/.test(trackId)) {
      return Response.json({ error: "invalid track id" }, { status: 400 });
    }

    const token = await spotifyToken(clientId, clientSecret);
    if (!token) return Response.json({ url: null, reason: "spotify" });

    const response = await fetch(
      SPOTIFY_TRACK_ENDPOINT + encodeURIComponent(trackId),
      { headers: { Authorization: `Bearer ${token}` } },
    );
    if (!response.ok) return Response.json({ url: null, reason: "spotify" });
    const track = await response.json();
    return Response.json({ url: typeof track.preview_url === "string" ? track.preview_url : null });
    }),
};
