# KENOS — Architecture & Decision Records

Feature-first, clean-lite. Three layers per feature:
`domain` (pure models), `data` (repository contract + implementations),
`application` (Riverpod controllers), `presentation` (widgets).

```
lib/
├── app/               # KenosApp + go_router (fades only)
├── core/              # cross-feature: constants, theme, utils, audio,
│                      # haptics, shared widgets (ScrambleText,
│                      # EtherDissolve, HUD)
└── features/
    ├── onboarding/
    ├── echo/          # domain: Echo, EchoCipher, Reception
    │                  # data: EchoRepository ↔ Supabase | Local (demo)
    ├── cosmic_map/    # application: MapController, ReceptionController,
    │                  #             MotionService
    │                  # presentation: MapScreen + painters + sheets
    └── create_echo/
```

## Provider graph

- `bootstrapProvider` — boot facts (backend configured? onboarded?),
  overridden in `main()`.
- `echoRepositoryProvider` — Supabase or local demo, chosen at boot.
- `mapControllerProvider` — the star list: sealed (store) + remote
  (RPC). Owns consume / send / forget / leaveTrace.
- `receptionControllerProvider` — bottle-in-the-sea signals: unseen
  only, stream + 30 s polling, burn on view. Deliberately separate
  from the map so a landing signal never re-emits the star list.
- `tiltProvider` — sensor stream; watched ONLY by leaf layers
  (`_AmbientBackground`, `_ParallaxStarLayer`), never by whole screens.

## ADR-001 — RPC-only database access

The client holds no table grants; everything goes through SECURITY
DEFINER functions with pinned `search_path`. Rationale: policies gate
rows, grants gate columns, RPCs gate *behavior* (atomicity, rate
limits, reception journaling) — only functions can express "lock,
delete, journal, return, all or nothing".

## ADR-002 — Ether Seal: escrowed at rest, exchanged at interception

True author↔reader E2E is impossible for an anyone-may-read ether
without a rendezvous. Chosen design: on-device AES-256-GCM with a
per-echo ephemeral key; key escrowed sealed under a Vault KEK;
one-shot release inside the atomic consume transaction. A DB dump
yields ciphertext. The residual trust in the courier is documented in
`docs/SECURITY.md` instead of being papered over. Consequence: length
validation moved client-side; the server bounds the sealed size.

## ADR-003 — Sector culling with exact demo parity

`fetch_map_sector` bins echoes on an 8×8 grid (`floor`, never a
float→int cast — Postgres casts ROUND), keeps the newest 24 per
sector, 400 total. `SectorGrid` mirrors the constants and the floor
semantics in Dart; boundary tests on both sides pin the parity.
The map is a galaxy, never a feed.

## ADR-004 — Migration policy

Amend a migration **only while it has never left a developer machine**
(reset wipes local state). Once applied to any shared/cloud database:
forward-only, new migration. The repository history shows 0001–0004
amended during the pre-deployment hardening pass of 2026-08-31; from
the first cloud wiring onward this is forbidden.

## ADR-005 — Demo mode is the same contract

`LocalEchoRepository` reproduces backend semantics exactly: sealed
seeds (ciphertext only, decrypted for the single winner), sector
culling, one-shot traces, simulated receptions on a timer. Any
behavior change on one side is a bug until mirrored on the other —
the parity tests exist to say no.

## Performance posture

- Sensor-rate (30 fps) rebuilds live in leaf widgets only.
- Scenery ticks at ~8 fps; the dissolution shader is deterministic in
  `uProgress` (no time uniform); one `FragmentShader` instance per
  widget lifetime.
- Depth buckets: one Transform + one blur layer per bucket, not per
  star.
- Audio and haptics are fire-and-forget by design; intentional drops
  are marked `unawaited()` (enforced by lint).
