# CS 1.6 Multi-Mode Network

A LAN-first Counter-Strike 1.6 dedicated server project, provisionally named **Multi-Mode Network**. Phase 1 establishes a clean vanilla HLDS baseline on Windows, then layers pinned Metamod-P and AMX Mod X on top. Phase 2 adds modular menus and authoritative mode state. Phase 3 adds the isolated Classic match system.

Version **0.4.3** implements the server foundation, native menus, administrator-controlled mode selection, playable Classic matches, team-based Deathmatch, team-based Arms Race, and an AWP Only MVP with optional dedicated-map selection. Phase 4.3.2 adds a guarded isolated-clone workflow for manually evaluating the centralized arcade-round controller with ReGameDLL_CS. Continuous rounds remain unverified until that gameplay matrix passes; the production GameDLL is unchanged. HE Battle, voting, shared progression, persistence, cosmetics, and advanced administration remain roadmap items.

## Phase 1 contents

- Non-destructive SteamCMD/HLDS installer for Steam application `90`
- Minimal 12-slot LAN configuration on UDP/TCP port `27015`
- Reproducible, checksum-verified Metamod-P and AMX Mod X installer
- Windows start/stop scripts with a project-owned PID file
- Pawn sources for `mm_core`, `mm_mode_manager`, `mm_arcade_rounds`, `mm_modes`, `mm_classic`, `mm_deathmatch`, `mm_armsrace`, and `mm_awponly`, plus a compiler/install script
- LAN firewall helper and a validation checklist

## Repository layout

```text
config/cstrike/          Tracked vanilla server configuration
docs/                    Installation and validation documentation
scripts/                 Windows setup, launch, stop, and firewall scripts
src/amxmodx/             Pawn plugin sources
runtime/                 Local HLDS installations (ignored by Git)
downloads/               Download cache (ignored by Git)
```

## Quick start

Run these commands in PowerShell from the repository root. A normal user account is sufficient for installation and launch; use an Administrator PowerShell only for the firewall step.

```powershell
.\scripts\install-server.ps1
.\scripts\install-addons.ps1
.\scripts\build-plugins.ps1
# Administrator PowerShell:
.\scripts\configure-firewall.ps1
# Back in a normal PowerShell:
.\scripts\start-server.ps1
```

The default installation is the tested pre-anniversary baseline at `runtime\hlds-steam-legacy`. Every installer accepts an explicit path. The installer refuses unrelated non-empty targets and will not mix anniversary and legacy engine files. Detailed instructions are in [docs/SETUP.md](docs/SETUP.md); verification steps are in [docs/VALIDATION.md](docs/VALIDATION.md).

Optional Phase 3 solo testing with pinned YaPB bots is documented in [docs/SOLO_TESTING.md](docs/SOLO_TESTING.md). Bot files and the development ready bridge remain disabled by default and are not part of the production plugin build.

To change the provisional hostname, edit `runtime\hlds\cstrike\server.cfg` after installation. Keep private values in an ignored `*.local.cfg` or `*.secret.cfg` file and execute that file from the local server configuration if needed.

## Roadmap

- **Phase 1 — foundation (implemented):** HLDS provisioning, baseline configuration, Metamod-P, AMX Mod X, lifecycle scripts, `mm_core`, and LAN validation.
- **Phase 2.1 — main game-mode menu (implemented):** native `/menu` and `/modes` menus, five informational mode choices, and nine informational Classic formats.
- **Phase 2.2 — real mode management (implemented):** authoritative mode/format state, administrator confirmation, configuration transitions, fallback, public Pawn natives/forwards, and `/mode` status.
- **Phase 2.3 — voting (not started):** player voting and policy for selecting the next mode.
- **Phase 3 — Classic (implemented):** nine team formats, enforced capacities, warmup/ready/live/paused/halftime/finished lifecycle, MR3/MR5/MR12 rules, MR12 overtime, side switching, scoring, HUD, and admin controls. Unbalanced matches remain casual.
- **Phase 4.1 — Deathmatch MVP (implemented):** team-based T/CT respawns, weapon selection, ammunition replenishment, spawn protection, and a transient leaderboard.
- **Phase 4.2 — Arms Race MVP (implemented):** configurable 15-level gun progression, team-based respawns, HUD/leaderboard, and a final knife-kill victory.
- **Phase 4.3 — AWP Only MVP (implemented):** team-based AWP/Knife restriction, respawns, protection, standings, and configurable dedicated-map selection.
- **Phase 4.3.1 — shared round fix (prepared, migration unapproved):** centralized arcade round/objective policy and a staged ReGameDLL_CS compatibility, backup, validation, and rollback plan. The live GameDLL is unchanged.
- **Phase 4.3.2 — isolated ReGameDLL trial (prepared, untested):** clone-only setup/install/start/stop/status/rollback scripts, pinned official artifact verification, separate port/state, and a manual Classic/arcade compatibility matrix. No production migration has occurred.
- **Later Phase 4 — remaining arcade:** isolated HE Battle module. FFA behavior is a separate future decision.
- **Phase 5 — shared systems:** SQLite profiles, global XP/levels/coins, separate competitive rating, mastery, achievements, HUD, menus, audio, cosmetics, leaderboards, missions, events, and administration.
- **Optional later:** Next.js/TypeScript management dashboard and public-hosting hardening.

Each later phase must remain independently testable. Gameplay modes must not directly own persistence or shared progression, and only the selected mode may control gameplay state.

## Version policy and sources

The add-on script pins Metamod-P `v1.21p109` and AMX Mod X `1.10.0-git5487`. It downloads from the maintained [Metamod-P GitHub releases](https://github.com/Bots-United/metamod-p/releases) and the official [AMX Mod X build channel](https://www.amxmodx.org/downloads-new.php), then checks SHA-256 before extraction. SteamCMD comes from Valve's official CDN; HLDS itself is installed from app ID `90` on the `steam_legacy` branch. Phase 1 starts with `-insecure -nomaster` because it is LAN-only; public hosting requires a separate Steam-services and security review.

This is a GoldSrc/AMX Mod X project. SourceMod and Source-engine plugins are intentionally out of scope.

