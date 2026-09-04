#!/bin/bash
# KENOS — cloud operator console (Management API SQL against PROD).
#
# The single sanctioned path for hand-run SQL on the linked cloud
# project (same privileges as the dashboard SQL Editor). The token is
# the Supabase CLI's keychain entry — nothing secret lives here.
#
# Usage:
#   scripts/prod_admin.sh sql "select ..."            # one statement
#   scripts/prod_admin.sh file path/to/stmt.sql       # one-statement file (a DO block)
#   scripts/prod_admin.sh stage payloads.csv          # (re)create + fill kenos_load_payloads
#
# Multi-statement files are NOT supported on purpose: every mutation
# snippet is written as ONE atomic DO block (see prod_reset.sql,
# prod_sow.sql).
set -euo pipefail

REF="xmbdrzkvjxaaoqwluonx"
TOKEN=$(security find-generic-password -s "Supabase CLI" -w \
          | sed 's/^go-keyring-base64://' | base64 -d)

api() { # $1 = one SQL statement (or DO block), prints raw JSON answer
  local payload
  payload=$(python3 -c 'import json,sys; print(json.dumps({"query": sys.stdin.read()}))' <<<"$1")
  curl -sS -X POST "https://api.supabase.com/v1/projects/$REF/database/query" \
    -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
    -d "$payload"
}

case "${1:-}" in
  sql)   api "$2" ;;
  file)  api "$(cat "$2")" ;;
  stage)
    [ -f "${2:?csv path required}" ]
    python3 - "$2" "$REF" "$TOKEN" <<'PY'
import csv, json, sys, urllib.request

csv_path, ref, token = sys.argv[1], sys.argv[2], sys.argv[3]
rows = []
with open(csv_path, newline='', encoding='utf-8') as f:
    for r in csv.reader(f):
        if len(r) == 3:
            rows.append(r)
if not rows:
    sys.exit('no payload rows parsed — refusing to stage nothing')

def q(s):  # SQL single-quote literal
    return "'" + s.replace("'", "''") + "'"

def call(sql):
    req = urllib.request.Request(
        f'https://api.supabase.com/v1/projects/{ref}/database/query',
        data=json.dumps({'query': sql}).encode(),
        # Cloudflare 1010 bans the bare python-urllib signature.
        headers={'Authorization': f'Bearer {token}', 'Content-Type': 'application/json',
                 'User-Agent': 'kenos-ops/1.0'})
    try:
        with urllib.request.urlopen(req) as resp:
            return resp.read().decode()
    except urllib.error.HTTPError as e:
        sys.exit(f'Management API HTTP {e.code}: {e.read().decode()[:300]}')

print(call('drop table if exists public.kenos_load_payloads'))
print(call('create table public.kenos_load_payloads '
           '(seq serial primary key, text_value text, key_b64 text, payload_b64 text)'))

BATCH = 120
for i in range(0, len(rows), BATCH):
    values = ','.join(f'({q(t)},{q(k)},{q(p)})' for t, k, p in rows[i:i + BATCH])
    call(f'insert into public.kenos_load_payloads (text_value, key_b64, payload_b64) values {values}')
print(f'staged {len(rows)} payloads in {(len(rows) + BATCH - 1) // BATCH} batches')
PY
    ;;
  *)
    echo "usage: $0 sql '<statement>' | file <one-statement.sql> | stage <payloads.csv>" >&2
    exit 2
    ;;
esac
