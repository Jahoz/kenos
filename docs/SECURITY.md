# KENOS — Security Model

> The sacred invariants, the trust boundaries, and the honest price of
> each design choice. Read before touching `supabase/migrations/` or
> anything crypto-adjacent.

## Threat model in one paragraph

An anonymous author seals a thought and lets it drift; exactly one
stranger may read it, once, then it is gone. The adversaries: a curious
**database operator** (or whoever obtains a DB dump), a **malicious
client** (modified app, raw PostgREST access), a **network observer**,
and — hardest — the **ether itself** (the server that must store and
hand over the echo to be useful at all).

## The invariant list (non-negotiable)

| Invariant | Enforcement |
|---|---|
| Client never touches `echoes` | No SELECT/INSERT/UPDATE/DELETE grants or policies; RPC-only (`fetch_map_sector`, `consume_echo`, `launch_echo`) |
| `encrypted_text` / `key_seal` never client-readable | Column-level grants exclude them; no view exposes them; RLS on top |
| Single read is absolute | `FOR UPDATE SKIP LOCKED` + row deletion inside `consume_echo` |
| Author can't intercept own echo | `author_id <> auth.uid()` guard in `consume_echo`; own echoes excluded from `fetch_map_sector` (the sealed star is the only representation) |
| Sealed echoes carry no text locally | `Echo.toJson()` has no text field; the store keeps metadata only |
| Reception is contentless by default | `kenos_receptions` RPC-only; trace one-shot ≤ 140 chars within 10 min; view = burn |
| ROSE is destruction-only | `launch_echo` rejects the theme server-side |
| Friction server-enforced | 1 echo / 20 s, 1 read / 5 s, audit journal without content |

## Ether Seal (at-rest encryption)

1. **On the author's device**: fresh 256-bit ephemeral key per echo,
   AES-256-GCM (`EchoCipher`), before anything leaves. The ether never
   sees the plaintext of what it carries.
2. **Escrow**: the per-echo key is stored sealed (`key_seal`) under a
   KEK held in **Supabase Vault** (locked-table fallback on stacks
   without Vault). A plain dump of `public` yields ciphertext only.
3. **Exchange at interception**: `consume_echo` unseals the key inside
   the same atomic transaction that destroys the echo. The key transits
   exactly once, to the single winner, over TLS.

### Honest boundaries

- **The ether is a courier, not a vault zero-trust partner**: during the
  read transaction the server holds the key in memory. Perfect
  forward secrecy against a fully malicious server is impossible for
  an anyone-may-read system without a rendezvous protocol
  (reader-sealed boxes via pgsodium are a documented Roadmap+ idea).
- **E2E price**: the server cannot validate plaintext length; it bounds
  the sealed payload (≤ 4000 chars) instead. The 280-character line is
  client-enforced.
- The 5 s read anti-spam applies to the winner too: the tests never
  consume twice in a row.

### Operational notes

- The KEK is provisioned lazily under a transaction-scoped advisory
  lock (`pg_advisory_xact_lock`) — racing first calls cannot mint two
  different keys.
- `launch_echo` / `consume_echo` pin `search_path = public, extensions`:
  pgcrypto lives in `extensions` on Supabase. Yes, this was a bug once.
- Legacy echoes (pre-migration, `key_seal = ''`) pass through as
  plaintext with `key: null` — the client treats a null key as
  "not sealed".

## Purge

`kenos_purge()` destroys echoes drifting > 30 days, audit rows older
than a day (the trace window is 10 min), unread receptions past 30
days. The `pg_cron` wiring ships commented in migration 0004 — enable
once the extension is available on the project.

## Testing the promises

- `supabase/tests/rpc.sql` — 35 RPC invariants (atomicity, escrow
  round-trip, sector floor bins, own-echo exclusion, purge, rate
  limits). `make db-test`.
- `supabase/tests/rls.sql` — 13 active break-in attempts (column
  opacity, no writes, RPC-only everywhere, anon denied).
- `scripts/e2e_local.sh` — the full bottle-in-the-sea loop over real
  PostgREST, including cheat attempts. `make e2e`.
- Dart: cipher round-trip/tamper, sector parity with SQL, controller
  contracts, UI flow. `make test`.
