// Follow this setup guide to integrate the Deno language server with your editor:
// https://deno.land/manual/getting_started/setup_your_environment
// This enables autocomplete, go to definition, etc.

// Setup type definitions for built-in Supabase Runtime APIs
import "@supabase/functions-js/edge-runtime.d.ts";
import { withSupabase } from "@supabase/server";

const maxMediaBytesByKind: Record<string, number> = {
  IMAGE: 1048576,
  AUDIO: 524288,
};

function base64(bytes: Uint8Array): string {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary);
}

// This endpoint uses 'publishable' | 'secret' access, apiKey is required.
// Use publishable for Client-facing, key-validated endpoints
// Use secret for Server-to-server, internal calls
export default {
  fetch: withSupabase({ auth: "user" }, async (req, ctx) => {
    let echoId: string;
    try {
      ({ echoId } = await req.json());
    } catch {
      return Response.json({ error: "invalid request" }, { status: 400 });
    }
    if (typeof echoId !== "string") {
      return Response.json({ error: "invalid echo id" }, { status: 400 });
    }

    const { data: consumed, error } = await ctx.supabase.rpc("consume_echo", {
      target_echo_id: echoId,
    });
    if (error) return Response.json({ error: error.message }, { status: 400 });
    if (consumed === null) return Response.json(null);

    const bundle = consumed as Record<string, unknown>;
    const path = bundle.media_path;
    const kind = bundle.media_kind;
    if (typeof path !== "string") {
      delete bundle.media_path;
      return Response.json(bundle);
    }
    if (typeof kind !== "string") {
      // Corrupt metadata (only a modified client could produce it).
      // The read is already spent: the words ship, the fragment alone
      // dissolves — never a total loss.
      delete bundle.media_path;
      return Response.json(bundle);
    }
    // External doors (V3.10) carry a sealed reference, not a storage
    // object: pass it through untouched — only the winner's device,
    // holding the echo key, can unseal which song or video it is.
    if (kind === "SONG" || kind === "EXCERPT") {
      const ref = path;
      delete bundle.media_path;
      return Response.json({ ...bundle, media_ref: ref });
    }
    if (!(kind in maxMediaBytesByKind)) {
      // Same law as above: the single read cannot be retried, so a
      // broken fragment never takes the sealed text down with it.
      delete bundle.media_path;
      return Response.json(bundle);
    }

    const { data: object, error: downloadError } = await ctx.supabaseAdmin.storage
      .from("echo-media")
      .download(path);
    if (downloadError || !object || object.size > maxMediaBytesByKind[kind]) {
      // The echo burned inside consume_echo and can never be re-read:
      // a transient storage failure must not swallow the winner's
      // words. The sealed text ships; only the fragment dissolves
      // (the orphaned object is swept by kenos_purge).
      console.error("Media unavailable after atomic consumption", downloadError);
      delete bundle.media_path;
      return Response.json(bundle);
    }
    const bytes = new Uint8Array(await object.arrayBuffer());
    const { error: removeError } = await ctx.supabaseAdmin.storage
      .from("echo-media")
      .remove([path]);
    if (removeError) console.error("Consumed media cleanup failed", removeError);

    delete bundle.media_path;
    return Response.json({ ...bundle, media: base64(bytes) });
  }),
};
