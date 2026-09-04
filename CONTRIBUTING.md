# Contributing to KENOS

Product language is **French** (UI copy); code, comments, commits and
docs are **English**. Conventional Commits (`feat:`, `fix:`,
`refactor:`, `perf:`, `docs:`, `chore:`), one logical change per commit.

## The rules that are not negotiable

Kept in `AGENTS.md` and `docs/SECURITY.md` — the short version:

- The client never reads `echoes` directly; single-read atomicity
  (`FOR UPDATE SKIP LOCKED`) survives every schema change.
- `encrypted_text` / `key_seal` never leak client-side.
- Sealed echoes carry no text locally — even their author cannot re-read.
- ROSE is reserved for destruction, UI and SQL alike.
- Audio and haptics never block the UI; sensor-less platforms stay
  alive (sinusoidal fallback is a feature).
- Demo mode keeps exact backend semantics (see ADR-005).

## Canonical commands

```bash
make dev         # run the app (demo mode without credentials)
make analyze     # must be 0 issue
make test        # Dart suite (226 tests)
make db-reset    # recreate the local Supabase DB from migrations
make db-test     # pgTAP suite (146 SQL invariants)
make e2e         # full loop over the real local PostgREST (18 checks)
make build-web   # release web build — compiles the fragment shader
```

CI (`.github/workflows/ci.yml`) runs analyze + tests, the web build
(GLSL compilation) and the SQL job (migrations + pgTAP). The SQL job
exists because a search_path bug once passed every Dart test while the
first real sealed echo would have failed — never merge SQL changes
without it.

## Before you touch…

- **Migrations**: read ADR-004. Never amend an applied migration; add
  a new one. Run `make db-reset && make db-test` locally.
- **Crypto**: read `docs/SECURITY.md` first, then touch `EchoCipher`
  or `kenos_ether_kek()`. Every change needs tamper tests.
- **The map**: `ParallaxMath.offsetPixels` is the single formula home;
  sector bins floor on both sides (ADR-003).
- **Accessibility**: new motion must respect « réduire les animations »
  (see `MotionPreferences` / `platformDisablesAnimations`).

## Test map

| File | Locks |
|---|---|
| `test/echo_cipher_test.dart` | seal/open round-trip, tamper detection, corrupt → null |
| `test/sector_grid_test.dart` | sector caps, floor boundaries (parity with SQL) |
| `test/controllers_test.dart` | map merge dedup, consume win/lose, sealed store, signals |
| `test/local_echo_repository_test.dart` | demo semantics: metadata-only map, 8-reader atomicity |
| `test/app_flow_test.dart` | real journey: hold 3 s → reveal → burn → dissolution |
| `test/accessibility_test.dart` | reduce-motion behaviors, shader fallback |
| `test/echo_excerpt_test.dart` | strict link parsing, sealed wire form, canonical door URL |
| `test/constellation_sealed_read_test.dart` | sealed corpse opens on device (Ether Seal round trip) |
| `test/constellation_figure_test.dart` | golden-angle figure: determinism, distinct stations, growth |
| `test/spatial_wave_test.dart` | pitch mirror, stereo pan, distance gain, engine fallback |
| `test/door_dialog_keyboard_test.dart` | one editing host: dialog handover, Mirror text intact |
| `test/observatory_gate_test.dart` | guardian threshold: refused words, shapes only, revoked rank, demo parity |
| `supabase/tests/*.sql` | 146 invariants (RPC behavior, RLS break-ins, sealed corpse, contentless metrics) |
