#!/usr/bin/env bash
# KENOS — end-to-end proof over the real PostgREST API (local stack).
# Two distinct anonymous users, full bottle-in-the-sea loop, and
# active cheat attempts that must all fail.
#
# Usage: ./scripts/e2e_local.sh [api_url] [anon_key]
#   (defaults read from `supabase status -o json`)

set -euo pipefail

API="${1:-$(supabase status -o json 2>/dev/null | python3 -c 'import json,sys; print(json.load(sys.stdin)["API_URL"])')}"
ANON="${2:-$(supabase status -o json 2>/dev/null | python3 -c 'import json,sys; d=json.load(sys.stdin); print([v for k,v in d.items() if "anon" in k.lower()][0])')}"
ANON="${ANON:-$(supabase status -o json 2>/dev/null | python3 -c 'import json,sys; d=json.load(sys.stdin); print([v for k,v in d.items() if "ANON" in k][0])')}"

PASS=0; FAIL=0
ok()   { PASS=$((PASS+1)); echo "  ✓ $1"; }
ko()   { FAIL=$((FAIL+1)); echo "  ✗ $1"; }
check(){ if [ "$1" = "$2" ]; then ok "$3"; else ko "$3 (attendu: $2 — obtenu: $1)"; fi }

auth_header() { echo "apikey: $ANON"; }
bearer() { echo "Authorization: Bearer $1"; }

json_field() { python3 -c "import json,sys; d=json.load(sys.stdin); print(d$1)" 2>/dev/null || echo ""; }

echo "── KENOS e2e sur $API ──"

# ── Two anonymous identities ────────────────────────────────────────────
TOKEN_A=$(curl -s -X POST "$API/auth/v1/signup" -H "$(auth_header)" -H 'Content-Type: application/json' -d '{}' | json_field "['access_token']")
TOKEN_B=$(curl -s -X POST "$API/auth/v1/signup" -H "$(auth_header)" -H 'Content-Type: application/json' -d '{}' | json_field "['access_token']")
[ -n "$TOKEN_A" ] && [ -n "$TOKEN_B" ] && ok "deux anonymes distincts créés" || ko "sign-in anonyme"

# ── A launches an echo ───────────────────────────────────────────────────
# (legacy tooling path: p_key = '' → plaintext passthrough. The real app
#  seals with AES-256-GCM on-device and sends ciphertext + key.)
LAUNCH=$(curl -s -X POST "$API/rest/v1/rpc/launch_echo" \
  -H "$(auth_header)" -H "$(bearer "$TOKEN_A")" -H 'Content-Type: application/json' \
  -d '{"p_ciphertext":"je navigue dans le vide pour toi","p_key":"","p_x":0.5,"p_y":0.5,"p_z":0.9,"p_theme":"TEAL"}')
ECHO_ID=$(echo "$LAUNCH" | json_field "[0]['id']")
[ -n "$ECHO_ID" ] && ok "A lance son écho ($ECHO_ID)" || ko "launch_echo: $LAUNCH"

# Cheat: immediate second launch → rate limit.
SECOND=$(curl -s -X POST "$API/rest/v1/rpc/launch_echo" \
  -H "$(auth_header)" -H "$(bearer "$TOKEN_A")" -H 'Content-Type: application/json' \
  -d '{"p_ciphertext":"trop vite","p_key":"","p_x":0.1,"p_y":0.1,"p_z":0.5,"p_theme":"TEAL"}')
echo "$SECOND" | grep -q KENOS_RATE_LIMIT && ok "anti-spam de lancement respecté" || ko "rate limit launch: $SECOND"

# Cheat: try to read the secret column through the Data API.
CHEAT=$(curl -s "$API/rest/v1/echoes?select=encrypted_text" \
  -H "$(auth_header)" -H "$(bearer "$TOKEN_B")")
echo "$CHEAT" | grep -qi "permission denied" && ok "encrypted_text illisible via REST" || ko "FUITE via REST: $CHEAT"

# Cheat: the sealed key escrow is just as opaque.
KEYCHEAT=$(curl -s "$API/rest/v1/echoes?select=key_seal" \
  -H "$(auth_header)" -H "$(bearer "$TOKEN_B")")
echo "$KEYCHEAT" | grep -qi "permission denied" && ok "key_seal illisible via REST" || ko "FUITE clé via REST: $KEYCHEAT"

# ── B reads the map ──────────────────────────────────────────────────────
# ── B reads the sector-culled viewport ───────────────────────────────────
SECTOR=$(curl -s -X POST "$API/rest/v1/rpc/fetch_map_sector" \
  -H "$(auth_header)" -H "$(bearer "$TOKEN_B")" -H 'Content-Type: application/json' \
  -d '{"p_min_x":0,"p_min_y":0,"p_max_x":1,"p_max_y":1}')
echo "$SECTOR" | grep -q "$ECHO_ID" && ok "fetch_map_sector renvoie l'écho du viewport" || ko "sector: $SECTOR"
echo "$SECTOR" | grep -q "encrypted_text" && ko "la carte expose du texte !" || ok "aucune colonne de texte sur la carte"
echo "$SECTOR" | grep -q "key_seal" && ko "la carte expose la clé !" || ok "aucune colonne de clé sur la carte"

# ── A's own echo must NOT appear on A's own map ──────────────────────────
OWNMAP=$(curl -s -X POST "$API/rest/v1/rpc/fetch_map_sector" \
  -H "$(auth_header)" -H "$(bearer "$TOKEN_A")" -H 'Content-Type: application/json' \
  -d '{"p_min_x":0,"p_min_y":0,"p_max_x":1,"p_max_y":1}')
echo "$OWNMAP" | grep -q "$ECHO_ID" && ko "l'auteur voit son propre écho !" || ok "l'auteur ne voit pas son propre écho (étoile scellée only)"

# ── B intercepts: single read (consume returns the sealed bundle) ────────
TEXT=$(curl -s -X POST "$API/rest/v1/rpc/consume_echo" \
  -H "$(auth_header)" -H "$(bearer "$TOKEN_B")" -H 'Content-Type: application/json' \
  -d "{\"target_echo_id\":\"$ECHO_ID\"}")
CIPHERTEXT=$(echo "$TEXT" | json_field "['ciphertext']")
KEY=$(echo "$TEXT" | json_field "['key']")
check "$CIPHERTEXT" 'je navigue dans le vide pour toi' "B reçoit la charge scellée (lecture unique)"
check "$KEY" 'None' "l'écho legacy ne porte aucune clé"

AGAIN=$(curl -s -X POST "$API/rest/v1/rpc/consume_echo" \
  -H "$(auth_header)" -H "$(bearer "$TOKEN_A")" -H 'Content-Type: application/json' \
  -d "{\"target_echo_id\":\"$ECHO_ID\"}")
check "$AGAIN" 'null' "l'écho lu ne revient jamais"

# ── B leaves a trace ─────────────────────────────────────────────────────
TRACE=$(curl -s -X POST "$API/rest/v1/rpc/leave_trace" \
  -H "$(auth_header)" -H "$(bearer "$TOKEN_B")" -H 'Content-Type: application/json' \
  -d "{\"p_echo_id\":\"$ECHO_ID\",\"p_text\":\"Reçu. Respiré. Merci.\"}")
check "$TRACE" 'true' "B laisse une trace"

RETRACE=$(curl -s -X POST "$API/rest/v1/rpc/leave_trace" \
  -H "$(auth_header)" -H "$(bearer "$TOKEN_B")" -H 'Content-Type: application/json' \
  -d "{\"p_echo_id\":\"$ECHO_ID\",\"p_text\":\"remplacement\"}")
check "$RETRACE" 'false' "la trace est immuable (one-shot)"

# ── A receives the signal ────────────────────────────────────────────────
RECEPTIONS=$(curl -s -X POST "$API/rest/v1/rpc/fetch_receptions" \
  -H "$(auth_header)" -H "$(bearer "$TOKEN_A")" -H 'Content-Type: application/json' -d '{}')
echo "$RECEPTIONS" | grep -q "Reçu. Respiré. Merci." && ok "A reçoit la trace de l'inconnu" || ko "réceptions A: $RECEPTIONS"
DRIFT=$(echo "$RECEPTIONS" | json_field "[0]['drift_seconds']")
python3 -c "import sys; sys.exit(0 if int('$DRIFT' or -1) >= 0 else 1)" && ok "dérive enregistrée (${DRIFT}s)" || ko "dérive: $DRIFT"

INTRUDER=$(curl -s -X POST "$API/rest/v1/rpc/fetch_receptions" \
  -H "$(auth_header)" -H "$(bearer "$TOKEN_B")" -H 'Content-Type: application/json' -d '{}')
check "$INTRUDER" '[]' "un intrus ne voit aucune réception"

BURN=$(curl -s -X POST "$API/rest/v1/rpc/burn_reception" \
  -H "$(auth_header)" -H "$(bearer "$TOKEN_A")" -H 'Content-Type: application/json' \
  -d "{\"p_echo_id\":\"$ECHO_ID\"}")
AFTER=$(curl -s -X POST "$API/rest/v1/rpc/fetch_receptions" \
  -H "$(auth_header)" -H "$(bearer "$TOKEN_A")" -H 'Content-Type: application/json' -d '{}')
check "$AFTER" '[]' "voir = brûler : le signal ne revient pas"

echo "──"
echo "Résultat: $PASS ✓ / $FAIL ✗"
[ "$FAIL" -eq 0 ]
