# Windows setup

## Prerequisites

- 64-bit or 32-bit Windows with PowerShell 5.1 or newer
- Internet access during installation
- A Steam copy of Counter-Strike 1.6 on each playing computer
- Several gigabytes of free disk space

The server installer uses anonymous SteamCMD login and Valve's HLDS app ID `90`. It does not need the Steam desktop client and does not touch a client game installation.

## 1. Install HLDS

From a normal, non-Administrator PowerShell in the repository root:

```powershell
.\scripts\install-server.ps1
```

The default target is `runtime\hlds-steam-legacy`, which is ignored by Git. The script installs app `90` with `app_set_config 90 mod cstrike` and `app_update 90 -beta steam_legacy validate`. It accepts a clean target or a recognized managed partial legacy installation, retries safely when needed, and refuses unrelated non-empty targets or branch mixing.

To choose another new directory:

```powershell
.\scripts\install-server.ps1 -InstallDir 'D:\GameServers\mm-network-hlds'
```

The target must not contain an existing installation or any other files. If installation is interrupted, remove only the newly created, known target yourself or choose another empty path; the script will not overwrite it.

## 2. Install Metamod-P and AMX Mod X

```powershell
.\scripts\install-addons.ps1
```

Pinned Windows dependencies:

| Component | Version | SHA-256 |
| --- | --- | --- |
| Metamod-P | v1.21p109 | `564838D9A42032EE3BC44EEB2616896E0789C3CE8D7A033D81F3F795B67E31ED` |
| AMX Mod X base | 1.10.0-git5487 | `CA13B474741F5F0B035507969CB853B7EAC9052614402114801E21C4DC2F2EBD` |
| AMX Mod X Counter-Strike addon | 1.10.0-git5487 | `47F358B4DD40C0259576BBDE9790442DEE4B642FE31BFED0421180B81429D4AA` |

The script downloads from the maintained Metamod-P GitHub release and official AMX Mod X build server, verifies each checksum, extracts into `cstrike`, changes the vanilla `liblist.gam` game DLL to Metamod, and registers AMX Mod X with Metamod. It refuses an existing `cstrike\addons` tree to avoid corrupting or merging an installation.

If using a custom server directory, pass the same `-ServerDir` to this and all later scripts.

## 3. Compile and enable Pawn plugins

```powershell
.\scripts\build-plugins.ps1
```

This calls the pinned compiler installed at `cstrike\addons\amxmodx\scripting\amxxpc.exe`, compiles `mm_core.sma`, `mm_mode_manager.sma`, `mm_arcade_rounds.sma`, `mm_modes.sma`, `mm_classic.sma`, `mm_deathmatch.sma`, `mm_armsrace.sma`, and `mm_awponly.sma`, deploys mode configurations, and enables the plugins in dependency order. Re-run it after changing Pawn source or configuration.

Equivalent manual compilation from the repository root is:

```powershell
& '.\runtime\hlds-steam-legacy\cstrike\addons\amxmodx\scripting\amxxpc.exe' `
  '.\src\amxmodx\mm_core.sma' `
  '-o.\runtime\hlds-steam-legacy\cstrike\addons\amxmodx\plugins\mm_core.amxx'
```

Then ensure `mm_core.amxx`, `mm_mode_manager.amxx`, `mm_arcade_rounds.amxx`, `mm_modes.amxx`, `mm_classic.amxx`, `mm_deathmatch.amxx`, `mm_armsrace.amxx`, and `mm_awponly.amxx` appear in that order in `runtime\hlds-steam-legacy\cstrike\addons\amxmodx\configs\plugins.ini`.

### Phase 4.3.1 shared arcade rounds

The source build now includes a central round controller. On the current stock Valve GameDLL it logs an unsupported capability and makes no GameDLL cvar changes; this is intentional. ReGameDLL_CS compatibility findings, the exact inspected runtime fingerprints, the proposed cvars, and the required backup/trial/rollback process are in [REGAMEDLL_MIGRATION.md](REGAMEDLL_MIGRATION.md).

No GameDLL migration has been performed or approved. Do not replace `cstrike\dlls\mp.dll` in the verified runtime merely to make the new plugin report support.

### Phase 2.2 administrator commands

Administrators need AMX Mod X flag `h` (`ADMIN_CFG`). In an authorized player's game console:

```text
amx_mode deathmatch
amx_classic_format 2v3
```

Valid mode names are `classic`, `deathmatch`, `armsrace`, `awponly`, and `hebattle`. Valid formats are `1v1`, `2v2`, `3v3`, `4v4`, `5v5`, `1v2`, `2v3`, `3v4`, and `4v5`.

AMX Mod X reserves the server cvar `amx_mode` for its admin-authentication policy, so the requested `amx_mode` interface is deliberately a player/admin client-console command. For direct HLDS server-console automation, use the equivalent `mm_mode <mode>` command. Do not repurpose the protected AMX Mod X cvar.

Ordinary mode changes update authoritative state, execute the corresponding configuration under `addons/amxmodx/configs/mm_modes`, and announce success. AWP Only may intentionally change to a configured installed AWP map; other implemented modes do not reload the map. Classic, Deathmatch, Arms Race, and AWP Only have isolated gameplay modules; HE Battle remains a marker.

### Phase 4.1 Deathmatch

Activate from the HLDS console with `mm_mode deathmatch` or from an authorized player console with `amx_mode deathmatch`. Players on normal T/CT teams respawn about one second after death. `/dm` selects a primary and secondary weapon; `/top` shows the current top five by kills, then fewest deaths. `mm_dm_respawn_delay` defaults to `1.0` seconds and `mm_dm_spawn_protection` to `2.0` seconds. Protection ends immediately when the player presses primary or secondary attack.

Deathmatch is team-based with friendly fire disabled. It does not implement FFA. Scores are transient and reset on Deathmatch activation/exit or reconnect. Exiting Deathmatch cancels respawn/loadout/protection tasks, removes godmode, and executes the tracked server baseline before the next mode configuration applies.

Stock CS 1.6 can still declare a normal round result when an entire team is eliminated; no stock cvar disables that rule. The plugin respawns players and preserves its own leaderboard across those engine round boundaries, but a two-player 1v1 may visibly enter the normal round-end/restart sequence. Eliminating that sequence requires a separately evaluated engine/game-DLL capability and is not hidden behind a ReGameDLL dependency in this phase.

### Phase 4.2 Arms Race

Activate from the HLDS console with `mm_mode armsrace` or from an authorized player console with `amx_mode armsrace`. Arms Race uses normal T/CT teams with friendly fire disabled. Players and YaPB bots respawn about one second after death, receive only their current progression weapon plus a knife, and cannot use normal purchasing commands.

The default 15 levels are Glock, USP, Desert Eagle, TMP, MP5, P90, Galil, Famas, AK-47, M4A1, AUG, Scout, AWP, M249, and Knife. Levels 1–14 may be changed in `addons/amxmodx/configs/mm_modes/armsrace.cfg` using supported weapon names. Level 15 is validated as `knife`; an invalid name falls back to the documented default. A player advances only after killing a connected enemy on the opposing team with the weapon assigned to their current level.

`/ar` reports personal level, assigned weapon, kills, and deaths. `/artop` shows the top five ordered by level, kills, then fewest deaths. The HUD shows the local player's level/weapon/kills and the current leader. A final knife kill announces the winner, pauses progression, and resets all players for a new match after five seconds.

`mm_ar_respawn_delay` defaults to `1.0`. Exiting Arms Race cancels respawn/loadout/HUD/reset tasks, clears progression, and restores the tracked server baseline before the next mode configuration applies. No FFA behavior is enabled.

The stock CS 1.6 team-elimination rule remains: when the last living member of a team dies, the engine may announce a normal round result and run its round restart even though Arms Race progression and respawns remain active. There is no stock GoldSrc cvar that cleanly disables this. Phase 4.2 does not silently add ReGameDLL or another game DLL.

### Phase 4.3 AWP Only

Activate with `mm_mode awponly` in the HLDS console or `amx_mode awponly` from an authorized player console. Players and YaPB bots receive only AWP and Knife, respawn after approximately one second, receive configurable spawn protection, and have AWP reserve ammunition replenished after enemy kills. Buying, rebuy/autobuy, ammunition purchases, drops, weapon boxes, and map armoury pickups are blocked while the mode is active.

`/awp` shows personal kills/deaths and `/awptop` shows the top five. The HUD shows kills, deaths, and the current leader. Relevant settings are `mm_awp_respawn_delay`, `mm_awp_spawn_protection`, and `mm_awp_reserve_ammo`.

Map selection is configurable in `addons/amxmodx/configs/mm_modes/awp_only.cfg`:

```text
mm_awp_change_map "1"
mm_awp_preferred_map "awp_india"
mm_awp_fallback_map "awp_map"
```

The plugin checks for `maps/<name>.bsp` before issuing `changelevel`. It selects installed `awp_india` first, otherwise installed `awp_map`, otherwise stays on the current map and logs a warning. Set `mm_awp_change_map "0"` to let an external/future voting system own map selection. A one-shot cvar restores AWP Only through the centralized manager after the intentional map change and is cleared before requesting the mode, preventing a reload loop.

The current inspected local installation contains neither `awp_india.bsp` nor `awp_map.bsp`; no map was generated or downloaded. Obtain a legitimate CS 1.6 map package from a trusted mapper or server-map source. Copy the `.bsp` into `runtime\hlds-steam-legacy\cstrike\maps`. If its archive provides `.res`, `.wad`, models, sounds, sprites, or overview files, preserve their supplied paths under `cstrike`; do not install executables or random DLLs. Verify before starting HLDS:

```powershell
Test-Path '.\runtime\hlds-steam-legacy\cstrike\maps\awp_india.bsp'
Test-Path '.\runtime\hlds-steam-legacy\cstrike\maps\awp_map.bsp'
```

Stock CS 1.6 may still declare a round win when a team is eliminated. The AWP Only plugin retains its transient standings and schedules respawns, but the engine's normal round-end presentation/restart may be visible with one player per team. No ReGameDLL or replacement game DLL is introduced.

### Phase 3 Classic commands and rules

Classic starts in Waiting. Once the selected T and CT capacities are full, warmup begins; every active player must use `/ready` before the live restart. Player chat commands are `/match`, `/ready`, `/unready`, `/score`, `/teams`, and `/pause`. Pause requires administrator flag `h`.

Administrators can use these commands from their game console (or the HLDS console where applicable):

```text
mm_match_start
mm_match_stop
mm_match_restart
mm_match_format 3v3
mm_match_rules mr12
```

Valid rules are `mr3`, `mr5`, and `mr12`; MR12 is the default. MR12 tied 12–12 enters MR3 overtime when `mm_classic_overtime` is `1`. Overtime ends when a team has at least 16 rounds and leads by two. `mm_classic_warmup` controls the default 30-second warmup.

The match plugin uses logical Team A/Team B scores so scores survive the halftime T/CT swap. If a roster player disconnects during Live or Halftime, the match enters a logical Paused state: round wins are not scored. A replacement may fill the vacant slot, after which the plugin issues a three-second round restart and resumes. This is not GoldSrc's engine-level `pause`; `pausable` remains disabled. Spectators are supported, no bots are added, and the plugin does not add armor, alter weapons/economy beyond the documented Classic cvars, or respawn players.

## 4. Configure the server

The installed `cstrike\server.cfg` defaults to hostname `Multi-Mode Network (LAN)`, `sv_lan 1`, no password, and 12 slots (enforced by the launch script). Edit the installed copy to change the hostname. Do not put passwords in tracked `config/cstrike/server.cfg`; use an ignored `*.local.cfg` or `*.secret.cfg` file for future private settings.

## 5. Permit LAN traffic through Windows Firewall

Set the host's LAN connection to the Windows **Private** network profile. Open PowerShell **as Administrator**, then run:

```powershell
.\scripts\configure-firewall.ps1
```

Elevation is required only because adding machine-wide firewall rules is an administrative operation. The script permits inbound UDP and TCP `27015` on Private networks only. UDP carries normal GoldSrc game traffic; the TCP rule supports server queries/management scenarios. Do not open the rules on Public profiles for this LAN phase.

Manual equivalent (Administrator PowerShell):

```powershell
New-NetFirewallRule -DisplayName 'Multi-Mode Network HLDS UDP' -Direction Inbound -Action Allow -Protocol UDP -LocalPort 27015 -Profile Private
New-NetFirewallRule -DisplayName 'Multi-Mode Network HLDS TCP' -Direction Inbound -Action Allow -Protocol TCP -LocalPort 27015 -Profile Private
```

## 6. Start and stop

```powershell
.\scripts\start-server.ps1
.\scripts\stop-server.ps1
```

Start defaults to `0.0.0.0:27015`, 12 players, `de_dust2`, and the LAN-only `-insecure -nomaster` flags. These flags avoid dependence on Steam authentication and master-server initialization; they are not appropriate for a future public/VAC-secured deployment. Example override:

```powershell
.\scripts\start-server.ps1 -Map de_inferno -Port 27015 -MaxPlayers 10
```

The stop script only stops the PID recorded by this project and verifies its executable path first. Use the normal server console `quit` command when working interactively; if that bypasses the stop script, the next stop invocation cleans the stale PID file.

## Optional Phase 3 solo testing

YaPB bot support is a separate, disabled-by-default development installation. It does not modify the engine or normal production build. See [SOLO_TESTING.md](SOLO_TESTING.md) for the pinned version/checksum, enable/disable scripts, bot commands, test-ready bridge, and format-by-format procedures.

## Upstream references

- [Valve SteamCMD documentation](https://developer.valvesoftware.com/wiki/SteamCMD)
- [AMX Mod X downloads](https://www.amxmodx.org/downloads-new.php)
- [AMX Mod X manual installation](https://www.amxmodx.org/doc/source/installation/manual.htm)
- [Metamod-P releases](https://github.com/Bots-United/metamod-p/releases)

