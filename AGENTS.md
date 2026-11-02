# Development instructions

## Scope

- Preserve the phase boundaries in `README.md`. Do not implement a later phase unless the user explicitly requests it.
- This repository targets Counter-Strike 1.6 / GoldSrc with Metamod and AMX Mod X. Never introduce SourceMod or Source-engine dependencies.
- Prefer the stock Steam HLDS baseline. Engine replacements are optional future decisions, not implicit dependencies.

## Architecture

- Keep plugins small and single-purpose. Never grow `mm_core` into a monolith.
- Planned module boundaries are: core/lifecycle, mode selection, Classic, one plugin per arcade mode, progression, persistence, sounds/cosmetics, and administration.
- Shared systems expose narrow natives/forwards or include contracts. Mode plugins consume those contracts; they do not reach into another mode's private state.
- Exactly one mode may own gameplay behavior. A mode transition must stop timers/tasks, remove temporary entities, clear per-player transient state, restore modified cvars, and only then activate the next mode.
- `mm_mode_manager` is the sole owner of active mode, requested mode, transition state, and Classic format. Other plugins must use `include/mm_mode_api.inc`; never duplicate mode state.
- `mm_classic` owns Phase 3 Classic team limits, match lifecycle, scoring, and Classic cvars. Arcade configuration files remain non-gameplay markers until their corresponding gameplay phases.
- `mm_deathmatch` owns Phase 4.1 FFA respawn, loadouts, protection, and transient DM scores. It must remain inactive outside Deathmatch.
- `mm_armsrace` owns Phase 4.2 FFA weapon progression, Arms Race respawns, HUD, and transient standings. Its final level remains a knife kill.
- `mm_awponly` owns Phase 4.3 FFA AWP/Knife restriction, respawns, protection, transient standings, and optional dedicated-map selection. Its map restoration guard must prevent `changelevel` loops.
- `mm_he_battle` owns HE-only loadouts, grenade replenishment, purchase/pickup restrictions, and respawns. It must remain inactive outside HE Battle and use the shared arcade round controller.
- `mm_knife` owns team-based Knife 35HP rounds, loadouts, damage rules, and safe routing to installed knife maps.
- `mm_arcade_protection` owns spawn protection for Arms Race and HE Battle only; attacking must cancel protection.
- `mm_random_spawns` may relocate players only in Deathmatch, Arms Race, and HE Battle. It must reject blocked hulls, hazards, and active transitions.
- `mm_settings` is an ordinary-player routing menu. It must delegate to existing command handlers and must not duplicate mode state, bypass vote safeguards, or expose privileged commands.
- `mm_football` owns team Football ball physics, pitch geometry, scoring, controls, loadouts and cleanup. Preserve its GPL notices. `mm_mode_maps` routes dedicated HE/Knife/Football maps through voting; individual modes must not duplicate its routing.
- ReAPI is a pinned explicit dependency only for documented server-side weapon hooks and engine-level purchase/default-item restrictions. Do not add other ReAPI dependencies casually.
- Persistent profile data and competitive rating are separate concerns. Unbalanced Classic matches are casual until requirements explicitly change.

## Pawn conventions

- Source files live in `src/amxmodx`; generated `.amxx` files never belong in Git.
- Prefix project cvars, commands, natives, forwards, and task identifiers with `mm_`.
- Enable warnings and treat compiler warnings as defects. Use constants instead of unexplained numeric values.
- Register plugin name/version/author as constants and log a clear initialization message.
- Validate player indices and connection state before player operations. Clean up transient state on disconnect and mode shutdown.

## PowerShell conventions

- Scripts must use terminating errors (`$ErrorActionPreference = 'Stop'`) and explicit, resolved paths.
- Installation must be non-destructive: reject non-empty targets unless a future command has a clearly documented, explicit upgrade mode.
- Pin third-party artifacts and verify checksums. Use official or maintained upstream sources; do not guess URLs or versions.
- State when Administrator rights are required. Server installation, compilation, start, and stop should not require elevation.

## Verification and documentation

- Never claim a runtime test that was not executed. Distinguish static checks, compilation, local launch, and second-computer LAN tests.
- Update `docs/VALIDATION.md` whenever startup, loading, networking, or plugin behavior changes.
- Keep secrets, local configs, downloads, installed server files, logs, and compiled plugins ignored.
- Prefer focused commits that leave the server launchable and the current phase independently testable.

