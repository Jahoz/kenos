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
| Media is never publicly addressable | Private `echo-media` bucket; clients have INSERT-only access below their own anonymous-user prefix |
| Artifact memory is device-local | Read markers (7-day TTL) and the reliquaire (≤ 7 kept objects, ember-marked) live in secure storage only; never synced, never networked. Kept text is PUBLIC culture (closed artifacts, curated vestiges) — the no-text-locally law is about sealed confessions |

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
- **Media is a bounded sealed attachment**: image ≤ 1 MiB or AAC audio
  ≤ 512 KiB. Its bytes are AES-256-GCM encrypted with the echo's
  ephemeral key before the private Storage upload. The client never
  receives a public or signed Storage URL: authenticated `consume-media`
  calls `consume_echo`, reads the private object with the service role,
  returns the ciphertext to the sole winner, then deletes it.
- **Storage and Postgres do not share a transaction**: PostgreSQL still
  guarantees the winning single read through `FOR UPDATE SKIP LOCKED`,
  but an unavailable object after that commit cannot be retried without
  violating the one-read rule. `consume-media` therefore never lets a
  media failure take the sealed text down with it: the winner keeps
  the words, only the fragment dissolves. Orphaned fragments (an
  upload abandoned before `launch_echo`, or a consume hiccup) are
  swept outside SQL: the storage catalog is write-protected
  (`storage.protect_delete`), so `kenos_list_media_orphans`
  (service-role only — names embed author ids) lists objects older
  than a day with no live echo, and the `sweep-media` edge function
  (service key) drains that list through the Storage API. A live
  echo's media never enters the list; schedule the sweeper beside
  `kenos_purge` (same pg_cron note as below).

### Operational notes

- The KEK is provisioned lazily under a transaction-scoped advisory
  lock (`pg_advisory_xact_lock`) — racing first calls cannot mint two
  different keys.
- `launch_echo` / `consume_echo` pin `search_path = public, extensions`:
  pgcrypto lives in `extensions` on Supabase. Yes, this was a bug once.
- Edge functions (`trace-shield`, `door-preview`) carry a best-effort,
  per-worker courtesy cap keyed by the validated JWT `sub` (15/min):
  over the cap the shield answers its pass verdict and the door
  answers `{ url: null }` — third-party spend stays bounded and the
  fail-open contract stays intact. All their outbound endpoints are
  fixed constants; request data never shapes a request target.
- The Trace Shield's contract extends to creation, where the ether is
  structurally blind: the Mirror and a corpse's poem line run a
  device-side PII guard (`PiiGuard`: French/international phone
  numbers, emails) BEFORE sealing — the same anonymity threshold
  (`warnAnonymityLoss`), warn-never-block, zero network. The server
  cannot warn about content it cannot read; only the author's device
  can, before the seal exists.
- Legacy echoes (pre-migration, `key_seal = ''`) pass through as
  plaintext with `key: null` — the client treats a null key as
  "not sealed".

## Purge

`kenos_purge()` destroys echoes drifting > 30 days, audit rows older
than a day (the trace window is 10 min), unread receptions past 30
days. The `pg_cron` wiring ships commented in migration 0004 — enable
once the extension is available on the project.

## Testing the promises

- `supabase/tests/rpc.sql` — 132 RPC invariants (atomicity, escrow
  round-trip, sector floor bins, own-echo exclusion, purge incl. media
  orphan sweep, rate limits). `make db-test`.
- `supabase/tests/rls.sql` — 16 active break-in attempts (column
  opacity, no writes, RPC-only everywhere, anon denied).
- `scripts/e2e_local.sh` — the full bottle-in-the-sea loop over real
  PostgREST, including cheat attempts. `make e2e`.
- Dart: cipher round-trip/tamper, sector parity with SQL, controller
  contracts, UI flow. `make test`.
