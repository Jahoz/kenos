# kenos - AI Instructions

## Identity
- Stack: Flutter + Riverpod + GoRouter + Supabase (RPC-only) + just_audio + sensors_plus
- Product: anonymous "anti-social-network" — single-read, burn-after-reading echoes in a cosmic ether
- Platforms: iOS, Android (macOS + web supported for dev)

## Design Boundary
- Identity: Cosmic Zen / Dark Introspection (Void Black #030508, Playfair Display + Space Mono)
- ABSOLUTE: Never import design from other projects.
- ROSE #F43F5E is reserved for destruction only.

## Hard Constraints
- Client never touches the `echoes` table: `echoes_map` view (no text column)
  + `consume_echo` / `launch_echo` RPCs only.
- Atomic single read (`FOR UPDATE SKIP LOCKED`) must be preserved in any migration.
- Sealed echoes stored locally WITHOUT text.
- Audio and sensors are non-blocking, fault-tolerant layers.

## Process
1. Objective, scope, DoD, stop condition
2. Design Readiness Gate before UI/UX
3. Refuse scope creep → Roadmap+
4. Deliver small and complete

## Key Docs
- README.md (concept, run, architecture, spec fixes)
- CLAUDE.md (stack, commands, security model)
- supabase/migrations/0001_kenos_init.sql (backend contract)
