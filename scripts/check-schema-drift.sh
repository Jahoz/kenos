#!/usr/bin/env bash
# KENOS — schema drift guard (F-15). Run AFTER `supabase db reset`:
# the reset proves the migrations apply; this proves the resulting
# schema is still the one the CLIENT talks to.
#
# History repeating itself twice made this necessary:
#   - two migrations once replaced kenos_purge() and lexicographic
#     order decided which retention rules survived (silent loss —
#     fixed by 20260831120000_purge_consolidation.sql);
#   - plpgsql bodies are NOT dependency-tracked: a migration can drop
#     or rename an object a function body (or the app) still uses,
#     `db reset` stays green, and the breakage only shows at runtime.
#
# Checks (all blocking):
#   a) public.kenos_purge() exists, is SECURITY DEFINER with a pinned
#      search_path, revoked from anon/authenticated, and its EFFECTIVE
#      definition (pg_get_functiondef) still carries every retention
#      rule — a migration that silently drops a block trips this;
#   b) every RPC identifier referenced in lib/ (list derived from the
#      code at run time, never hand-maintained) exists in public;
#   c) every table created by the migrations exists with RLS enabled.
#
# Usage: bash scripts/check-schema-drift.sh   (stack must be up and
# reset first: make db-reset). Env override: DB_URL=postgresql://…
#
# Maintenance contract: changing a retention interval on purpose is a
# two-step move — update the migration, update EXPECTED_PURGE_FRAGS
# below — so drift can never be silent again.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DB_URL="${DB_URL:-postgresql://postgres:postgres@127.0.0.1:56322/postgres}"

PASS=0; FAIL=0
ok() { PASS=$((PASS + 1)); echo "  ✓ $1"; }
ko() { FAIL=$((FAIL + 1)); echo "  ✗ $1"; }

# psql when installed, the db container otherwise (project_id from
# config.toml names it: supabase_db_<project_id>).
db_container() {
  sed -n 's/^project_id[[:space:]]*=[[:space:]]*"\([^"]*\)".*/\1/p' \
    "$REPO_ROOT/supabase/config.toml" | head -1 | sed 's/^/supabase_db_/;s/^supabase_db_$/supabase_db_kenos/'
}
sql() {
  if command -v psql >/dev/null 2>&1; then
    psql "$DB_URL" -v ON_ERROR_STOP=1 -Atq -c "$1"
  else
    docker exec "$(db_container)" psql -U postgres -d postgres -Atq -c "$1"
  fi
}

# ── Expected retention rules in kenos_purge(), whitespace-normalized ─────
EXPECTED_PURGE_FRAGS="
delete from public.echoes where created_at < now() - interval '30 days';
delete from public.kenos_reads where read_at < now() - interval '1 day';
delete from public.kenos_receptions where read_at < now() - interval '30 days';
delete from public.kenos_echo_reports where reported_at < now() - interval '30 days';
delete from public.kenos_frequencies where created_at < now() - interval '60 seconds';
delete from public.kenos_lineages where consumed_at < now() - interval '1 hour';
delete from public.kenos_constellations where state = 'OPEN' and created_at < now() - interval '7 days';
"

# ── Identifiers the client actually uses (multiline-safe extractor) ──────
client_rpcs() {
  find "$REPO_ROOT/lib" -name '*.dart' -exec cat {} + \
    | tr '\n\r' '  ' \
    | grep -oE "\.rpc\( *'[a-z_0-9]+'" \
    | sed -E "s/.*'([a-z_0-9]+)'/\1/" \
    | sort -u
}
migration_tables() {
  grep -rhoEi "create table (if not exists )?public\.[a-z_0-9]+" \
    "$REPO_ROOT/supabase/migrations" \
    | sed -E 's/.*public\.//' | tr 'A-Z' 'a-z' | sort -u
}
sql_values_list() { # stdin: one identifier per line → ('a'),('b'),…
  local out="" n
  while IFS= read -r n; do
    [ -n "$n" ] && out="${out}('${n}'),"
  done
  echo "${out%,}"
}

echo "── KENOS schema drift guard ──"

# ── a) kenos_purge: existence, hardening, effective definition ───────────
purge_exists="$(sql "select coalesce(to_regprocedure('public.kenos_purge()')::text,'')" || true)"
if [ -n "$purge_exists" ]; then
  ok "public.kenos_purge() exists"
else
  ko "public.kenos_purge() is MISSING — dropped or renamed by a migration"
fi

if [ -n "$purge_exists" ]; then
  hard="$(sql "select p.prosecdef || '|' ||
      coalesce((array_to_string(p.proconfig, ',') like '%search_path=public%')::text,'false') || '|' ||
      has_function_privilege('anon','public.kenos_purge()','EXECUTE') || '|' ||
      has_function_privilege('authenticated','public.kenos_purge()','EXECUTE')
      from pg_proc p
      where p.oid = 'public.kenos_purge()'::regprocedure" || true)"
  [ "${hard%%|*}" = "true" ] \
    && ok "kenos_purge is SECURITY DEFINER" \
    || ko "kenos_purge lost SECURITY DEFINER"
  hard="${hard#*|}"
  [ "${hard%%|*}" = "true" ] \
    && ok "kenos_purge pins search_path = public" \
    || ko "kenos_purge lost its pinned search_path (the pgcrypto bug class)"
  hard="${hard#*|}"
  [ "${hard%%|*}" = "false" ] \
    && ok "kenos_purge not executable by anon" \
    || ko "kenos_purge is executable by anon — retention must never be client-reachable"
  hard="${hard#*|}"
  [ "$hard" = "false" ] \
    && ok "kenos_purge not executable by authenticated" \
    || ko "kenos_purge is executable by authenticated — retention must never be client-reachable"

  def="$(sql "select pg_get_functiondef('public.kenos_purge()'::regprocedure)" \
    | tr '\n\r\t' '   ' | tr -s ' ' || true)"
  if printf '%s' "$def" | grep -qF 'SECURITY DEFINER'; then
    ok "kenos_purge definition carries SECURITY DEFINER"
  else
    ko "kenos_purge definition lost SECURITY DEFINER"
  fi
  while IFS= read -r frag; do
    [ -z "$frag" ] && continue
    if printf '%s' "$def" | grep -qF -- "$frag"; then
      ok "retention rule intact: ${frag:0:64}…"
    else
      ko "retention rule DRIFTED AWAY: $frag"
    fi
  done <<EOF
$EXPECTED_PURGE_FRAGS
EOF
fi

# ── b) every client-referenced RPC exists in public ──────────────────────
rpcs="$(client_rpcs)"
missing="$(sql "select t.name
  from (values $(printf '%s\n' "$rpcs" | sql_values_list)) as t(name)
  left join pg_proc p on p.proname = t.name and p.pronamespace = 'public'::regnamespace
  where p.oid is null" || true)"
if [ -z "$missing" ]; then
  ok "all $(printf '%s\n' "$rpcs" | grep -c .) lib/-referenced RPCs exist in public"
else
  while IFS= read -r m; do
    [ -n "$m" ] && ko "RPC $m is referenced in lib/ but MISSING from the reset schema"
  done <<< "$missing"
fi

# ── c) every migration table exists with RLS enabled ─────────────────────
tables="$(migration_tables)"
bad="$(sql "select t.name || ': ' ||
    case when c.oid is null then 'table missing'
         when not c.relrowsecurity then 'RLS disabled' end
  from (values $(printf '%s\n' "$tables" | sql_values_list)) as t(name)
  left join pg_class c on c.relname = t.name and c.relnamespace = 'public'::regnamespace
  where c.oid is null or not c.relrowsecurity" || true)"
if [ -z "$bad" ]; then
  ok "all $(printf '%s\n' "$tables" | grep -c .) migration tables exist with RLS enabled"
else
  while IFS= read -r b; do
    [ -n "$b" ] && ko "sensitive table $b"
  done <<< "$bad"
fi

# ── Verdict ──────────────────────────────────────────────────────────────
echo "──"
echo "Result: $PASS ✓ / $FAIL ✗"
[ "$FAIL" -eq 0 ]
