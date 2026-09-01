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
  const response = await fetch("https://accounts.spotify.com/api/token", {
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
      `https://api.spotify.com/v1/tracks/${trackId}`,
      { headers: { Authorization: `Bearer ${token}` } },
    );
    if (!response.ok) return Response.json({ url: null, reason: "spotify" });
    const track = await response.json();
    return Response.json({ url: typeof track.preview_url === "string" ? track.preview_url : null });
  }),
};
