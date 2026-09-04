#!/usr/bin/env bash
# KENOS — nightly anonymous smoke test against PRODUCTION (F-13).
#
# The V3.11a regression (constellations read empty in the shipped app
# while every CI job stayed green) was caught by a human eye. This
# script is the minimal anonymous tripwire, in the spirit of the
# manual post-deploy gate in the Makefile (curl the domain, never
# trust a green deploy):
#
#   1. the PWA is served: GET / and GET /main.dart.js (200, sane
#      bundle size, must-revalidate cache policy on the bundle);
#   2. every RPC the client references exists on the PROD schema.
#      Probed with correctly-typed INERT payloads and the publishable
#      key alone (role: anon). Every client RPC is granted to
#      `authenticated` only, so PostgREST resolves the signature then
#      denies execution: 401 + 42501 "permission denied for function"
#      is the existence proof — nothing ever runs, zero side effects.
#      A missing/renamed RPC answers 404 (PGRST202), a broken one 500.
#   3. the read-only RPCs execute end-to-end behind an anonymous user
#      JWT (the exact surface that broke in V3.11a) — payloads are
#      inert viewports, answers must be 200 + JSON;
#   4. the door-preview edge function answers coherently (never 5xx)
#      on an invalid track id.
#
# The RPC list is DERIVED from lib/ (never hand-maintained): any new
# `.rpc('...')` call without a probe payload here fails the run.
#
# Usage (CI sets the same env):
#   APP_URL=... SUPABASE_URL=... SUPABASE_ANON_KEY=... ./scripts/smoke_prod.sh
# Cost: one anonymous auth user per run (the same user any site
# visit creates) and nothing else.

set -euo pipefail

APP_URL="${APP_URL:-https://kenos-lemon.vercel.app}"
SUPABASE_URL="${SUPABASE_URL:?SUPABASE_URL must be set (https://<ref>.supabase.co)}"
SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY:?SUPABASE_ANON_KEY must be set (repository secret, publishable key — Project Settings → API)}"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUNDLE_MIN_BYTES=1000000 # a poisoned/empty redeploy serves far less; sane build ≈ 3.1 MB

PASS=0; FAIL=0; FAILURES=""
ok() { PASS=$((PASS + 1)); echo "  ✓ $1"; }
ko() { FAIL=$((FAIL + 1)); FAILURES="${FAILURES}- $1
"; echo "  ✗ $1"; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
# Pre-created so a curl that never connects still reads as "" bodies.
: > "$TMP/root" ; : > "$TMP/rpc" ; : > "$TMP/deep" ; : > "$TMP/door"

# ── RPC identifiers actually referenced by the client ───────────────────
# Multiline-safe: flatten the Dart sources first, then pick the quoted
# identifier right after `.rpc(`.
client_rpcs() {
  find "$REPO_ROOT/lib" -name '*.dart' -exec cat {} + \
    | tr '\n\r' '  ' \
    | grep -oE "\.rpc\( *'[a-z_0-9]+'" \
    | sed -E "s/.*'([a-z_0-9]+)'/\1/" \
    | sort -u
}

# Inert, correctly-typed payloads per RPC (param NAMES must match the
# live signature — that is the point). Values are never executed.
rpc_probe_payload() {
  case "$1" in
    fetch_map_sector)         echo '{"p_min_x":0,"p_min_y":0,"p_max_x":0,"p_max_y":0,"p_max_per_sector":1,"p_max_total":1}' ;;
    launch_echo)              echo '{"p_ciphertext":"","p_key":"","p_x":0,"p_y":0,"p_z":0.05,"p_theme":"TEAL","p_media_kind":"","p_media_path":""}' ;;
    rebound_echo)             echo '{"p_source_id":"","p_parent_momentum":0,"p_x":0,"p_y":0,"p_z":0.05,"p_ciphertext":"","p_key":""}' ;;
    leave_trace)              echo '{"p_echo_id":"","p_text":""}' ;;
    report_echo)              echo '{"p_echo_id":"","p_reason_code":""}' ;;
    fetch_receptions)         echo '{}' ;;
    burn_reception)           echo '{"p_echo_id":""}' ;;
    seed_constellation)       echo '{"p_seed_x":0,"p_seed_y":0}' ;;
    contribute_line)          echo '{"p_constellation_id":"","p_ciphertext":"","p_key":""}' ;;
    fetch_constellations)     echo '{"p_min_x":0,"p_min_y":0,"p_max_x":0,"p_max_y":0}' ;;
    peek_previous_line)       echo '{"p_constellation_id":""}' ;;
    read_constellation)       echo '{"p_constellation_id":""}' ;;
    fetch_vestiges)           echo '{}' ;;
    has_contributed)          echo '{"p_constellation_id":""}' ;;
    consume_constellation)    echo '{"p_constellation_id":""}' ;;
    emit_frequency)           echo '{"p_x":0,"p_y":0,"p_note_index":0,"p_hue_index":0}' ;;
    fetch_nearby_frequencies) echo '{"p_x":0,"p_y":0,"p_radius":0.01}' ;;
    # No-arg payload: the anon probe must resolve the signature then be
    # denied (granted to authenticated, gated to the guardian inside).
    admin_fetch_metrics) echo '{}' ;;
    *) return 1 ;;
  esac
}

# RPCs safe to actually execute anonymously (strictly read-only).
deep_probe_payload() {
  case "$1" in
    fetch_constellations)     echo '{"p_min_x":0,"p_min_y":0,"p_max_x":0,"p_max_y":0}' ;;
    fetch_map_sector)         echo '{"p_min_x":0,"p_min_y":0,"p_max_x":0,"p_max_y":0,"p_max_per_sector":1,"p_max_total":1}' ;;
    fetch_nearby_frequencies) echo '{"p_x":0,"p_y":0,"p_radius":0.01}' ;;
    fetch_receptions)         echo '{}' ;;
    *) return 1 ;;
  esac
}

echo "── KENOS anonymous smoke @ $(date -u +%FT%TZ) ──"
echo "app: $APP_URL   ether: $SUPABASE_URL"

# ── 1. The PWA is served ─────────────────────────────────────────────────
code=$(curl -sS -o "$TMP/root" -w '%{http_code}' "$APP_URL/") || code="curl-error"
[ "$code" = "200" ] && ok "GET / → 200" || ko "GET / → $code (empty redeploy? see Makefile deploy-web gate)"

code=$(curl -sS -D "$TMP/js.h" -o "$TMP/main.dart.js" -w '%{http_code} %{size_download}' "$APP_URL/main.dart.js") || code="curl-error 0"
jcode="${code%% *}"; jsize="${code##* }"
if [ "$jcode" = "200" ] && [ "$jsize" -gt "$BUNDLE_MIN_BYTES" ]; then
  ok "GET /main.dart.js → 200, $jsize bytes (> $BUNDLE_MIN_BYTES)"
else
  ko "GET /main.dart.js → $code (broken build cache or empty redeploy)"
fi
cache=$(tr -d '\r' < "$TMP/js.h" | sed -n 's/^[Cc]ache-[Cc]ontrol:[[:space:]]*//p' | tail -1)
if printf '%s' "$cache" | grep -qi 'must-revalidate'; then
  ok "bundle cache-control: $cache"
else
  ko "bundle cache-control is '$cache' — expected must-revalidate (stale-bundle risk)"
fi

# ── 2. Every client RPC exists on the prod schema (never executed) ───────
for fn in $(client_rpcs); do
  payload="$(rpc_probe_payload "$fn" || true)"
  if [ -z "$payload" ]; then
    ko "$fn is referenced in lib/ but has no smoke payload — add one to rpc_probe_payload()"
    continue
  fi
  code=$(curl -sS -o "$TMP/rpc" -w '%{http_code}' -X POST "$SUPABASE_URL/rest/v1/rpc/$fn" \
    -H "apikey: $SUPABASE_ANON_KEY" -H 'Content-Type: application/json' -d "$payload") || code="curl-error"
  body="$(cat "$TMP/rpc")"
  if [ "$code" = "401" ] && printf '%s' "$body" | grep -q 'permission denied for function'; then
    ok "$fn exists on prod schema (resolved, anon-denied)"
  elif [ "$code" = "404" ]; then
    ko "$fn MISSING on prod schema (PGRST202) — drifted migration or bad deploy"
  else
    ko "$fn unexpected answer $code: $(printf '%s' "$body" | head -c 120)"
  fi
done
# consume_constellation stays probe-able but is no longer in lib/
# (V3.13 renamed the read) — already-deployed PWA clients still call
# it, so its payload above documents that legacy surface.
for fn in fetch_map_sector launch_echo rebound_echo leave_trace report_echo \
          fetch_receptions burn_reception seed_constellation contribute_line \
          fetch_constellations peek_previous_line read_constellation \
          fetch_vestiges emit_frequency fetch_nearby_frequencies \
          admin_fetch_metrics; do
  client_rpcs | grep -qx "$fn" \
    || ko "$fn has a probe payload but is no longer referenced in lib/ — stale probe, remove it"
done

# ── 3. Read-only RPCs execute end-to-end (anonymous user) ────────────────
JWT=$(curl -sS -X POST "$SUPABASE_URL/auth/v1/signup" \
  -H "apikey: $SUPABASE_ANON_KEY" -H 'Content-Type: application/json' \
  -d '{}' | python3 -c 'import json,sys; print(json.load(sys.stdin).get("access_token",""))' 2>/dev/null || true)
if [ -n "$JWT" ]; then
  ok "anonymous sign-up works (the app's own entry door)"
else
  ko "anonymous sign-up failed — every deep probe below is skipped"
fi
if [ -n "$JWT" ]; then
  for fn in fetch_constellations fetch_map_sector fetch_nearby_frequencies fetch_receptions; do
    payload="$(deep_probe_payload "$fn")"
    code=$(curl -sS -o "$TMP/deep" -w '%{http_code}' -X POST "$SUPABASE_URL/rest/v1/rpc/$fn" \
      -H "apikey: $SUPABASE_ANON_KEY" -H "Authorization: Bearer $JWT" \
      -H 'Content-Type: application/json' -d "$payload") || code="curl-error"
    body="$(cat "$TMP/deep")"
    if [ "$code" = "200" ] && printf '%s' "$body" | python3 -c 'import json,sys; json.loads(sys.stdin.read())' 2>/dev/null; then
      ok "$fn executes for an anonymous user (200, JSON)"
    else
      ko "$fn broken for real users: $code $(printf '%s' "$body" | head -c 120)"
    fi
  done

  # ── 4. door-preview answers coherently, never 5xx ──────────────────────
  code=$(curl -sS -o "$TMP/door" -w '%{http_code}' -X POST "$SUPABASE_URL/functions/v1/door-preview" \
    -H "apikey: $SUPABASE_ANON_KEY" -H "Authorization: Bearer $JWT" \
    -H 'Content-Type: application/json' -d '{"trackId":"not-a-valid-id"}') || code="curl-error"
  body="$(cat "$TMP/door")"
  if { [ "$code" = "200" ] || [ "$code" = "400" ]; } \
     && printf '%s' "$body" | python3 -c 'import json,sys; json.loads(sys.stdin.read())' 2>/dev/null; then
    ok "door-preview invalid id → $code (coherent: $(printf '%s' "$body" | head -c 80))"
  else
    ko "door-preview broken: $code $(printf '%s' "$body" | head -c 120)"
  fi
fi

# ── Verdict ──────────────────────────────────────────────────────────────
echo "──"
echo "Result: $PASS ✓ / $FAIL ✗"
if [ "$FAIL" -gt 0 ]; then
  {
    echo "## Anonymous smoke failures"
    echo "$FAILURES"
  } | tee "${SMOKE_SUMMARY:-/dev/null}" >&2
  exit 1
fi
