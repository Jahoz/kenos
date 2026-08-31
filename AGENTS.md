# AI Execution Contract — kenos

## Context
- Global rules: `~/.agents/AGENTS.md` (réponses FR, code/commits EN, Conventional Commits)
- Project context: `CLAUDE.md`, `README.md` + `pack_codebase` via MCP
- Portfolio governance: `../portfolio-os/` — design registry + milestone log

## Mandatory Behavior
- Start with: objective, scope, DoD, stop condition
- Design Readiness Gate before UI/UX
- Refuse scope creep → Roadmap+
- Deliver small and complete
- Never import design from other projects

## Project-Specific Rules
- **Single-read atomicity is sacred**: the client must never read `echoes`
  directly — map via `echoes_map` view, consumption via `consume_echo` RPC
  only. Any schema change must preserve `FOR UPDATE SKIP LOCKED`.
- **`encrypted_text` never leaks client-side** before atomic consumption.
- **Sealed echoes carry no text locally** — even the author cannot re-read.
- **ROSE color is reserved for destruction** (UI + SQL validation).
- **Audio never blocks the UI**: fire-and-forget bells, pitch coupling is
  best-effort, every plugin call wrapped in try/catch.
- **Sensor-less platforms must stay alive**: accelerometer fallback
  (sinusoidal drift) is a feature, not a workaround.
- Demo mode (no Supabase credentials) must keep exact backend semantics.
- UI copy stays in **French** (product language); code, comments, commits
  in **English**.
