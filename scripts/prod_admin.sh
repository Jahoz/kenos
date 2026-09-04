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
#   scripts/prod_admin.sh filemulti path/to/mig.sql   # a migration: many statements,
#                                                     # split with dollar-quote respect
#   scripts/prod_admin.sh stage payloads.csv          # (re)create + fill kenos_load_payloads
#
# `file`/`sql` keep single statements on purpose: every mutation
# snippet is written as ONE atomic DO block. `filemulti` exists for
# migration files applied by hand when `db push` would drag
# uncommitted local migrations along (shared working tree) — record
# the applied version in supabase_migrations.schema_version after.
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
  filemulti)
    [ -f "${2:?sql file required}" ]
    python3 - "$2" "$REF" "$TOKEN" <<'PY'
import json, re, sys, urllib.request

path, ref, token = sys.argv[1], sys.argv[2], sys.argv[3]


def split_statements(sql):
    """Split on top-level ';' only, honoring $$ / $tag$ bodies."""
    stmts, buf = [], []
    i, n = 0, len(sql)
    in_dollar, tag = False, ''
    while i < n:
        if not in_dollar:
            m = re.match(r'\$([A-Za-z_]*)\$', sql[i:])
            if m:
                tag = m.group(1)
                buf.append(m.group(0))
                i += m.end()
                in_dollar = True
                continue
            if sql[i] == ';':
                stmt = ''.join(buf).strip()
                if stmt:
                    stmts.append(stmt)
                buf = []
                i += 1
                continue
            buf.append(sql[i])
            i += 1
        else:
            close = f'${tag}$'
            if sql.startswith(close, i):
                buf.append(close)
                i += len(close)
                in_dollar = False
                continue
            buf.append(sql[i])
            i += 1
    tail = ''.join(buf).strip()
    if tail:
        stmts.append(tail)
    return stmts


def call(stmt):
    req = urllib.request.Request(
        f'https://api.supabase.com/v1/projects/{ref}/database/query',
        data=json.dumps({'query': stmt}).encode(),
        # Cloudflare 1010 bans the bare python-urllib signature.
        headers={'Authorization': f'Bearer {token}', 'Content-Type': 'application/json',
                 'User-Agent': 'kenos-ops/1.0'})
    try:
        with urllib.request.urlopen(req) as resp:
            return resp.read().decode()
    except urllib.error.HTTPError as e:
        sys.exit(f'Management API HTTP {e.code}: {e.read().decode()[:400]}')


stmts = split_statements(open(path, encoding='utf-8').read())
print(f'{path}: {len(stmts)} statements')
for k, stmt in enumerate(stmts, 1):
    head = next((l for l in stmt.splitlines() if l.strip() and not l.strip().startswith('--')),
                stmt.splitlines()[0] if stmt.splitlines() else '')
    out = call(stmt)
    brief = out.strip().replace('\n', ' ')[:80]
    print(f'  [{k}/{len(stmts)}] {head.strip()[:70]} → {brief or "ok"}')
print('filemulti done')
PY
    ;;
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
    echo "usage: $0 sql '<statement>' | file <one-statement.sql> | filemulti <migration.sql> | stage <payloads.csv>" >&2
    exit 2
    ;;
esac
