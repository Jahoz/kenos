#!/usr/bin/env bash
# KENOS — one-command care wiring (V3.88/V3.89 cloud activation).
#
# Everything the trace guard needs on the cloud project, in order,
# idempotently. Requires a logged-in CLI (`supabase login`).
#
# First export two variables in your shell:
#   - GROQ_API_KEY — from the Groq console
#   - TRACE_GUARD_TOKEN — any random door token ("openssl rand -hex 24");
#     its only power, if leaked, is burning incoming traces.
# Then run this script. The values transit a throwaway temp file
# (never the repo) and are shredded on exit.
set -euo pipefail
cd "$(dirname "$0")/.."

: "${GROQ_API_KEY:?export the Groq console key as GROQ_API_KEY first}"
: "${TRACE_GUARD_TOKEN:?generate a door token first (openssl rand -hex 24)}"

REF="$(cat supabase/.temp/project-ref)"
ENVFILE="$(mktemp /tmp/kenos-care.XXXXXX.env)"
trap 'rm -f "$ENVFILE"' EXIT
{
  printf 'GROQ_API_KEY=%s\n' "$GROQ_API_KEY"
  printf 'TRACE_GUARD_TOKEN=%s\n' "$TRACE_GUARD_TOKEN"
} >"$ENVFILE"

echo "── wiring the trace guard on project $REF ──"

echo "1/5 — secrets (Groq key + the webhook's door token)"
supabase secrets set --env-file "$ENVFILE"

echo "2/5 — deploy trace-guard (no gateway JWT: the caller is pg_net)"
supabase functions deploy trace-guard --no-verify-jwt

echo "3/5 — retire the V3.15 shield (replaced by the device guards)"
supabase functions delete trace-shield --yes-all || echo "  (already gone)"

echo "4/5 — migrations (trace_guard.sql: config shelf, burn RPC, pg_net trigger)"
supabase db push

echo "5/5 — point the trigger at the deployed function"
bash scripts/prod_admin.sh sql "insert into public.kenos_config (key, value) values
  ('trace_guard_url',  'https://$REF.supabase.co/functions/v1/trace-guard'),
  ('trace_guard_token', '$TRACE_GUARD_TOKEN')
on conflict (key) do update set value = excluded.value;"

echo "── probing the guard (a benign line: read, never burned) ──"
curl -sS -m 20 -X POST "https://$REF.supabase.co/functions/v1/trace-guard" \
  -H "x-kenos-token: $TRACE_GUARD_TOKEN" -H "Content-Type: application/json" \
  -d '{"echoId":"00000000-0000-4000-8000-000000000000","text":"lu, merci."}'
echo
echo "── done. Expected above: {\"checked\":true,\"burned\":false} ──"
