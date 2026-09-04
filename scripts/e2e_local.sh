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

# ── B reads the sector-culled viewport ───────────────────────────────────
# Substring tests, not `grep -q` pipes: under load the sector payload
# exceeds the 64 KiB pipe buffer, grep -q exits on the first match and
# `echo` dies of SIGPIPE — with pipefail the check would false-negative
# (found once the ether was seeded with volume).
SECTOR=$(curl -s -X POST "$API/rest/v1/rpc/fetch_map_sector" \
  -H "$(auth_header)" -H "$(bearer "$TOKEN_B")" -H 'Content-Type: application/json' \
  -d '{"p_min_x":0,"p_min_y":0,"p_max_x":1,"p_max_y":1}')
if [[ "$SECTOR" == *"$ECHO_ID"* ]]; then
  ok "fetch_map_sector renvoie l'écho du viewport"
else
  ko "sector: $SECTOR"
fi
if [[ "$SECTOR" == *"encrypted_text"* ]]; then ko "la carte expose du texte !"; else ok "aucune colonne de texte sur la carte"; fi
if [[ "$SECTOR" == *"key_seal"* ]]; then ko "la carte expose la clé !"; else ok "aucune colonne de clé sur la carte"; fi

# ── A's own echo must NOT appear on A's own map ──────────────────────────
OWNMAP=$(curl -s -X POST "$API/rest/v1/rpc/fetch_map_sector" \
  -H "$(auth_header)" -H "$(bearer "$TOKEN_A")" -H 'Content-Type: application/json' \
  -d '{"p_min_x":0,"p_min_y":0,"p_max_x":1,"p_max_y":1}')
# Same SIGPIPE mask, inverted: a pipe-grep here could hide an author-leak.
if [[ "$OWNMAP" == *"$ECHO_ID"* ]]; then
  ko "l'auteur voit son propre écho !"
else
  ok "l'auteur ne voit pas son propre écho (étoile scellée only)"
fi

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

# ── LE SALON (V3.19): the invitable constellation ────────────────────────
# One link is the door; hidden while written, a public artifact once
# closed. The key is checked inside the contribution itself.
TOKEN_C=$(curl -s -X POST "$API/auth/v1/signup" -H "$(auth_header)" -H 'Content-Type: application/json' -d '{}' | json_field "['access_token']")
TOKEN_D=$(curl -s -X POST "$API/auth/v1/signup" -H "$(auth_header)" -H 'Content-Type: application/json' -d '{}' | json_field "['access_token']")
[ -n "$TOKEN_C" ] && [ -n "$TOKEN_D" ] && ok "deux invités de plus (C, D)" || ko "sign-in invités"

SALON=$(curl -s -X POST "$API/rest/v1/rpc/seed_constellation" \
  -H "$(auth_header)" -H "$(bearer "$TOKEN_A")" -H 'Content-Type: application/json' \
  -d '{"p_seed_x":0.4,"p_seed_y":0.4,"p_kind":"POEM","p_invited":true}')
SALON_ID=$(echo "$SALON" | json_field "[0]['id']")
SALON_KEY=$(echo "$SALON" | json_field "[0]['invite_token']")
[ ${#SALON_KEY} -eq 32 ] && ok "A sème un salon, la clé naît (32 hex)" || ko "salon seed: $SALON"

# Cheat: no key, no line — and a forged key opens exactly as little.
NOKEY=$(curl -s -X POST "$API/rest/v1/rpc/contribute_line" \
  -H "$(auth_header)" -H "$(bearer "$TOKEN_B")" -H 'Content-Type: application/json' \
  -d "{\"p_constellation_id\":\"$SALON_ID\",\"p_ciphertext\":\"intrusion\",\"p_key\":\"\"}")
echo "$NOKEY" | grep -q KENOS_INVITE_UNKNOWN && ok "sans clé, la porte refuse" || ko "salon sans clé: $NOKEY"
BADKEY=$(curl -s -X POST "$API/rest/v1/rpc/contribute_line" \
  -H "$(auth_header)" -H "$(bearer "$TOKEN_B")" -H 'Content-Type: application/json' \
  -d "{\"p_constellation_id\":\"$SALON_ID\",\"p_ciphertext\":\"intrusion\",\"p_key\":\"\",\"p_invite_token\":\"cafebabecafebabecafebabecafebabe\"}")
echo "$BADKEY" | grep -q KENOS_INVITE_UNKNOWN && ok "une clé forgée n'ouvre rien" || ko "salon fausse clé: $BADKEY"

# The claim door resolves the ring's metadata — never a fingerprint.
INVITED=$(curl -s -X POST "$API/rest/v1/rpc/fetch_invited_constellation" \
  -H "$(auth_header)" -H "$(bearer "$TOKEN_B")" -H 'Content-Type: application/json' \
  -d "{\"p_token\":\"$SALON_KEY\"}")
check "$(echo "$INVITED" | json_field "['state']")" 'OPEN' "le lien résout le salon (OPEN)"
if [[ "$INVITED" == *"invite_token"* ]]; then ko "la résolution expose la clé !"; else ok "la résolution ne porte aucune clé"; fi

# Hidden while written: the map pretends the salon does not exist.
SKYOPEN=$(curl -s -X POST "$API/rest/v1/rpc/fetch_constellations" \
  -H "$(auth_header)" -H "$(bearer "$TOKEN_C")" -H 'Content-Type: application/json' \
  -d '{"p_min_x":0,"p_min_y":0,"p_max_x":1,"p_max_y":1}')
if [[ "$SKYOPEN" == *"$SALON_ID"* ]]; then
  ko "le salon ouvert existe sur la carte !"
else
  ok "le salon ouvert est invisible sur la carte"
fi

# The guests write through the door: B opens, fresh strangers fill the
# ring to ITS target (the server chose it, 4-7), the last line closes.
SALON_TARGET=$(echo "$INVITED" | json_field "['target']")
LINE_B=$(curl -s -X POST "$API/rest/v1/rpc/contribute_line" \
  -H "$(auth_header)" -H "$(bearer "$TOKEN_B")" -H 'Content-Type: application/json' \
  -d "{\"p_constellation_id\":\"$SALON_ID\",\"p_ciphertext\":\"première du salon\",\"p_key\":\"\",\"p_invite_token\":\"$SALON_KEY\"}")
check "$(echo "$LINE_B" | json_field "['count']")" '1' "B ouvre le poème du salon"
GUEST_DONE=0
while [ "$GUEST_DONE" -lt "$((SALON_TARGET - 1))" ]; do
  GUEST_TOKEN=$(curl -s -X POST "$API/auth/v1/signup" -H "$(auth_header)" -H 'Content-Type: application/json' -d '{}' | json_field "['access_token']")
  GUEST_COUNT=$(curl -s -X POST "$API/rest/v1/rpc/contribute_line" \
    -H "$(auth_header)" -H "$(bearer "$GUEST_TOKEN")" -H 'Content-Type: application/json' \
    -d "{\"p_constellation_id\":\"$SALON_ID\",\"p_ciphertext\":\"ligne d'invité $GUEST_DONE\",\"p_key\":\"\",\"p_invite_token\":\"$SALON_KEY\"}" | json_field "['count']")
  [ -n "$GUEST_COUNT" ] && GUEST_DONE=$((GUEST_DONE + 1))
done

# Closed, the salon joins the public sky — an artifact like the others.
SKYCLOSED=$(curl -s -X POST "$API/rest/v1/rpc/fetch_constellations" \
  -H "$(auth_header)" -H "$(bearer "$TOKEN_C")" -H 'Content-Type: application/json' \
  -d '{"p_min_x":0,"p_min_y":0,"p_max_x":1,"p_max_y":1}')
if [[ "$SKYCLOSED" == *"$SALON_ID"* ]]; then
  ok "refermé, le salon apparaît sur la carte publique"
else
  ko "le salon refermé manque à la carte: $SKYCLOSED"
fi
ARTIFACT=$(curl -s -X POST "$API/rest/v1/rpc/read_constellation" \
  -H "$(auth_header)" -H "$(bearer "$TOKEN_D")" -H 'Content-Type: application/json' \
  -d "{\"p_constellation_id\":\"$SALON_ID\"}")
ARTIFACT_N=$(echo "$ARTIFACT" | python3 -c "import json,sys; print(len(json.load(sys.stdin).get('lines', [])))")
check "$ARTIFACT_N" "$SALON_TARGET" "un invité relit l'artefact entier ($SALON_TARGET lignes, par tous)"

echo "──"
echo "Résultat: $PASS ✓ / $FAIL ✗"
[ "$FAIL" -eq 0 ]
