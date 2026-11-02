# Apexium Forge — CS 1.6 Multi-Mode Network

A modular Counter-Strike 1.6 / GoldSrc server built for private LAN play and Linux hosting. The project uses SteamCMD HLDS, Metamod-P, AMX Mod X and Pawn. ReGameDLL_CS supplies the continuous-round controls required by the respawn-based arcade modes.

The current release candidate is **v1.0.0-rc.1**. It contains four supported modes, centralized mode ownership, map and mode voting, and a permission-checked in-game administration panel. HE Battle, XP, coins, rankings, persistence, cosmetics and the website are not part of V1.

> **Release status:** source compilation and automated regression checks pass without warnings. Final hosted gameplay validation of the V1 admin workflows is still required before publishing `v1.0.0` as stable.

## Features

- **Classic:** nine balanced and unbalanced formats, team limits, warmup, ready-up, scoring, halftime, overtime and match administration.
- **Deathmatch:** free-for-all targeting, automatic respawns, weapon selection, spawn protection and session leaderboard.
- **Arms Race:** free-for-all 15-level weapon progression, immediate loadouts, respawns, HUD and final knife-kill victory.
- **AWP Only:** free-for-all AWP/Knife restriction, respawns, protection, standings and configurable `awp_` map selection.
- **Voting:** `/rtv`, `/votemode`, `/votemap` and `/nextmap` with installed-map validation and one authoritative next mode/map decision.
- **Administration:** `/admin` and `/adminmenu` for confirmed mode, map, Classic, YaPB, player and server actions.
- **Optional bots:** pinned YaPB integration for development and solo validation, disabled by default.
- **Safe operations:** non-destructive installers, isolated ReGameDLL trial/rollback workflows, ignored runtimes and reproducible PowerShell tooling.

## Runtime stack

- SteamCMD application `90`, `steam_legacy` branch
- Metamod-P `v1.21p109`
- AMX Mod X `1.10.0-git5487`
- ReGameDLL_CS for arcade continuous-round policy
- Optional YaPB `4.4.957`

## Repository layout

```text
config/cstrike/          Tracked vanilla server configuration
docs/                    Installation and validation documentation
scripts/                 Windows setup, launch, stop, and firewall scripts
src/amxmodx/             Modular Pawn plugin sources and shared API includes
tests/                   Static, regression and isolation checks
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

The default installation is the pre-anniversary baseline at `runtime\hlds-steam-legacy`. Every installer accepts an explicit path. The installer refuses unrelated non-empty targets and will not mix anniversary and legacy engine files. Detailed instructions are in [docs/SETUP.md](docs/SETUP.md); verification steps are in [docs/VALIDATION.md](docs/VALIDATION.md).

Optional Phase 3 solo testing with pinned YaPB bots is documented in [docs/SOLO_TESTING.md](docs/SOLO_TESTING.md). Bot files and the development ready bridge remain disabled by default and are not part of the production plugin build.

Keep passwords and private values in an ignored `*.local.cfg` or `*.secret.cfg` file. Never commit Steam credentials, RCON passwords, compiled plugins, downloaded runtimes, logs or third-party archives.

## Player and admin commands

| Command | Purpose |
|---|---|
| `/menu`, `/modes`, `/mode` | Open the main menu, inspect modes and show the active mode. |
| `/match`, `/ready`, `/unready`, `/score`, `/teams` | Classic match status and ready-up controls. |
| `/dm`, `/top` | Deathmatch loadout and standings. |
| `/ar`, `/artop` | Arms Race progression and standings. |
| `/awp`, `/awptop` | AWP Only status and standings. |
| `/rtv`, `/votemode`, `/votemap`, `/nextmap` | Player voting and planned-change status. |
| `/admin`, `/adminmenu` | Apexium Forge administration panel for authorized administrators. |

The admin panel requires the standard AMX Mod X flags documented in [docs/ADMIN_MENU.md](docs/ADMIN_MENU.md). Phase 5 voting must be deployed before `mm_admin` because it owns map validation and cross-map mode persistence.

## Roadmap

- **Phase 1 — foundation (implemented):** HLDS provisioning, baseline configuration, Metamod-P, AMX Mod X, lifecycle scripts, `mm_core`, and LAN validation.
- **Phase 2.1 — main game-mode menu (implemented):** native `/menu` and `/modes` menus, five informational mode choices, and nine informational Classic formats.
- **Phase 2.2 — real mode management (implemented):** authoritative mode/format state, administrator confirmation, configuration transitions, fallback, public Pawn natives/forwards, and `/mode` status.
- **Phase 2.3 — voting design (superseded by Phase 5):** the initial voting placeholder was replaced by the centralized Phase 5 implementation.
- **Phase 3 — Classic (implemented):** nine team formats, enforced capacities, warmup/ready/live/paused/halftime/finished lifecycle, MR3/MR5/MR12 rules, MR12 overtime, side switching, scoring, HUD, and admin controls. Unbalanced matches remain casual.
- **Phase 4.1 — Deathmatch MVP (implemented):** FFA targeting, respawns, weapon selection, ammunition replenishment, spawn protection, and a transient leaderboard.
- **Phase 4.2 — Arms Race MVP (implemented):** configurable 15-level FFA gun progression, respawns, HUD/leaderboard, and a final knife-kill victory.
- **Phase 4.3 — AWP Only MVP (implemented):** FFA AWP/Knife restriction, respawns, protection, standings, and configurable dedicated-map selection.
- **Phase 4.3.1 — shared round fix (implemented in source):** centralized arcade round/objective policy with required-versus-optional ReGameDLL cvar detection.
- **Phase 4.3.2 — isolated ReGameDLL trial (core validation passed):** clone-only setup/install/start/stop/status/rollback scripts, pinned official artifact verification, separate port/state, and observed Classic/arcade transition checks. Arms Race final completion and the complete AWP map-change path remain manual checks.
- **Phase 4.3.3 — safe production migration (prepared, not executed):** read-only prerequisites, timestamped verified backup, manifest-bound install/status/rollback scripts, and a production smoke-test matrix. See [docs/REGAMEDLL_PRODUCTION.md](docs/REGAMEDLL_PRODUCTION.md).
- **Phase 5 — Map & Mode Voting (implemented in source):** `/rtv`, `/votemode`, `/votemap`, `/nextmap`, installed-map validation, mode-specific pools, Classic-safe deferral, and single-use cross-map mode restoration. See [docs/MAP_VOTING.md](docs/MAP_VOTING.md).
- **Phase 6 — Custom Admin Menu V1 (implemented and compile-tested):** permission-checked native menus for modes, maps, Classic lifecycle, YaPB, player actions and safe server controls. Hosted gameplay validation remains pending. See [docs/ADMIN_MENU.md](docs/ADMIN_MENU.md).
- **Later Phase 4 — remaining arcade:** isolated HE Battle module; its gameplay and FFA policy remain unimplemented.
- **Later shared systems:** SQLite profiles, global XP/levels/coins, separate competitive rating, mastery, achievements, enhanced HUD, cosmetics, leaderboards, missions and events.
- **Optional later:** Next.js/TypeScript management dashboard and public-hosting hardening.

Each later phase must remain independently testable. Gameplay modes must not directly own persistence or shared progression, and only the selected mode may control gameplay state.

## Version policy and sources

The add-on script pins Metamod-P `v1.21p109` and AMX Mod X `1.10.0-git5487`. It downloads from the maintained [Metamod-P GitHub releases](https://github.com/Bots-United/metamod-p/releases) and the official [AMX Mod X build channel](https://www.amxmodx.org/downloads-new.php), then checks SHA-256 before extraction. SteamCMD comes from Valve's official CDN; HLDS itself is installed from app ID `90` on the `steam_legacy` branch. Phase 1 starts with `-insecure -nomaster` because it is LAN-only; public hosting requires a separate Steam-services and security review.

This is a GoldSrc/AMX Mod X project. SourceMod and Source-engine plugins are intentionally out of scope.

