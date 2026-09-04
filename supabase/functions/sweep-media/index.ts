// KENOS — the media orphan sweeper.
//
// The storage catalog is write-protected (storage.protect_delete):
// only the Storage API may delete, never SQL. This function IS that
// API call. It asks the database for `echo-media` objects older than
// a day with no live echo referencing them (kenos_list_media_orphans
// — service-role only, object names embed author ids), removes them
// through the Storage API (metadata + blob), and loops until the
// sky is clean. A live echo's media never enters the list; upload
// names are unique per attempt (`<uid>/<millis>-KIND.bin`), so a
// listing race can never orphan a just-launched echo's fragment.
//
// Invocable ONLY with the service role key (a JWT signed by the
// project's own secret — the gateway verifies the signature, the
// handler then demands the service_role claim):
//   curl -X POST https://<project>.supabase.co/functions/v1/sweep-media \
//     -H "Authorization: Bearer $SUPABASE_SERVICE_ROLE_KEY"
// Wire it beside kenos_purge (pg_cron + pg_net, same note as the
// purge's own cron wiring) or call it by hand on demand.

import "@supabase/functions-js/edge-runtime.d.ts";
import { withSupabase } from "@supabase/server";

// Hard ceiling per run: the ledger lists up to 1000 names a pass;
// 20 passes drain 20k objects and keep the invocation bounded.
const MAX_PASSES = 20;

// The gateway already verified the JWT signature (verify_jwt); here
// we demand the rank itself — anything less than the service role is
// turned away before a single storage byte is touched.
function isServiceRole(req: Request): boolean {
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
    return payload?.role === "service_role";
  } catch {
    return false;
  }
}

export default {
  fetch: withSupabase({ auth: "user" }, async (req, ctx) => {
    if (!isServiceRole(req)) {
      return Response.json({ error: "service role only" }, { status: 403 });
    }

    let swept = 0;
    for (let pass = 0; pass < MAX_PASSES; pass++) {
      const { data: listed, error } = await ctx.supabaseAdmin.rpc(
        "kenos_list_media_orphans",
      );
      if (error) {
        return Response.json({ error: error.message }, { status: 500 });
      }
      const names = (listed as string[] | null) ?? [];
      if (names.length === 0) break;

      const { error: removeError } = await ctx.supabaseAdmin.storage
        .from("echo-media")
        .remove(names);
      if (removeError) {
        return Response.json({ error: removeError.message }, { status: 500 });
      }
      swept += names.length;
    }
    return Response.json({ swept });
  }),
};
