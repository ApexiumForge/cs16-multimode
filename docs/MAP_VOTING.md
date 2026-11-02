# Phase 5 map and mode voting

`mm_voting` is the single owner of player-initiated mode/map decisions. It supports only Classic, Deathmatch, Arms Race, and AWP Only. It does not add a game mode or alter ReGameDLL round policy.

## Player commands

- `/rtv` records one early-change request per human player. At the configured threshold it starts a mode vote, followed by the matching map vote.
- `/votemode` starts a mode vote or reopens the active mode menu.
- `/votemap` starts a map vote for the active mode or reopens the active map menu.
- `/nextmap` displays the authoritative planned mode/map combination.

Human spectators may vote. YaPB and HLTV clients are excluded from player counts and ballots. A disconnect removes that player's active ballot and RTV request. An empty server cancels an active vote. Ties are resolved randomly among only the tied choices.

Only one vote or pending decision can exist at a time. A completed decision is applied after ten seconds. If a committed Classic match is live, at halftime, or paused, the decision remains queued until the match finishes or an administrator stops it. `mm_mode_manager` remains the only component that changes mode state.

For a different map, the controller writes a one-use mode marker under the AMX Mod X data directory and then issues one `changelevel`. The marker is consumed before requesting the voted mode on the new map, which prevents a restart or map-change loop. A same-map vote requests only the mode transition.

## Configuration

Edit `cstrike/addons/amxmodx/configs/mm_voting.cfg`:

| Cvar | Default | Meaning |
|---|---:|---|
| `mm_vote_enabled` | `1` | Enable player voting. |
| `mm_vote_duration` | `15` | Menu duration in seconds, clamped to 5–60. |
| `mm_vote_rtv_percent` | `60` | Percentage of eligible humans required for RTV. |
| `mm_vote_min_players` | `2` | Minimum eligible humans, clamped to 1–12. |
| `mm_vote_cooldown` | `60` | Seconds before another new vote may start. |
| `mm_vote_automatic` | `1` | Start one automatic mode/map vote per map. |
| `mm_vote_auto_delay` | `900` | Automatic vote delay after map load, clamped to 60–7200 seconds. |
| `mm_vote_map_choices` | `5` | Random installed map choices, clamped to 2–8. |
| `mm_vote_mode_*` | `1` | Individually allow the four supported modes. |

Map pools are one map name per line under `configs/mm_voting/`. Blank lines and lines beginning with `;` or `#` are ignored. The plugin verifies `maps/<name>.bsp` through AMX Mod X before offering it. Classic accepts only `de_` and `cs_`; AWP Only accepts only `awp_`. Deathmatch and Arms Race accept any explicitly listed installed BSP.

The current map is excluded when another eligible map exists. Any installed `awp_` map selected by this controller is accepted by `mm_awponly`, preventing its preferred-map fallback from issuing a second map change. Never add a download URL or an uninstalled map name to a pool; missing entries are logged and skipped.

## Stock plugin compatibility

The normal build registration removes `mapchooser.amxx`, `nextmap.amxx`, `adminvote.amxx`, and the map-vote-capable `mapsmenu.amxx` from the generated `plugins.ini`, then registers `mm_voting.amxx`. Running two vote owners would allow overlapping menus and conflicting `changelevel` commands. `admincmd.amxx` and direct `amx_map` permission remain available; other AMX Mod X administration plugins and permissions are unchanged.

On an existing hosted server, make the same four stock-plugin changes manually. Do not overwrite the entire hosted `plugins.ini`.

## Safe manual build and deployment

Do not run these steps while the production server is running.

From Windows PowerShell in the repository:

```powershell
$ProjectRoot = 'C:\Projcets\server-1.6'
$ServerDir = Join-Path $ProjectRoot 'runtime\hlds-steam-legacy'
$Stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$BackupDir = Join-Path $ProjectRoot ".runtime\phase5-backup-$Stamp"

New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $ServerDir 'cstrike\addons\amxmodx\configs\plugins.ini') -Destination $BackupDir
Copy-Item -LiteralPath (Join-Path $ServerDir 'cstrike\addons\amxmodx\plugins\mm_classic.amxx') -Destination $BackupDir -ErrorAction SilentlyContinue

& (Join-Path $ProjectRoot 'scripts\build-plugins.ps1') -ServerDir $ServerDir
```

The build produces the two Phase 5 deployment binaries at:

```text
runtime/hlds-steam-legacy/cstrike/addons/amxmodx/plugins/mm_classic.amxx
runtime/hlds-steam-legacy/cstrike/addons/amxmodx/plugins/mm_voting.amxx
```

Before changing OptikLink, stop the server and download backups of:

```text
/home/container/cstrike/addons/amxmodx/plugins/mm_classic.amxx
/home/container/cstrike/addons/amxmodx/configs/plugins.ini
```

Then upload:

```text
mm_classic.amxx -> /home/container/cstrike/addons/amxmodx/plugins/
mm_voting.amxx  -> /home/container/cstrike/addons/amxmodx/plugins/
mm_voting.cfg   -> /home/container/cstrike/addons/amxmodx/configs/
mm_voting/*.ini -> /home/container/cstrike/addons/amxmodx/configs/mm_voting/
```

Edit the hosted `plugins.ini`: comment out `mapchooser.amxx`, `nextmap.amxx`, `adminvote.amxx`, and `mapsmenu.amxx`, and add `mm_voting.amxx` after `mm_classic.amxx`. Start the server only after all files and the ordering are present.

## Rollback

1. Stop the hosted server.
2. Remove or comment `mm_voting.amxx` in `plugins.ini`.
3. Restore the backed-up `mm_classic.amxx`.
4. Re-enable the exact stock voting lines that were enabled before deployment.
5. The new configuration/map-pool files may remain inert, or may be removed while stopped.
6. Remove `cstrike/addons/amxmodx/data/mm_vote_pending.dat` only if it exists and the server is stopped.
7. Start the server and confirm the restored plugin list.

Rollback does not require any GameDLL, ReGameDLL, Metamod, YaPB, map, or engine change.

## Known limitations

- Vote state and RTV requests are intentionally volatile across an unexpected crash or manual restart. Only a finalized cross-map mode decision is persisted for one map load.
- The automatic vote uses elapsed map time rather than `mp_timelimit`, because arcade configurations may use no time limit.
- A map pool with only the current map can still select it for a mode-only transition; it does not recursively reload that map.
- The plugin does not download maps. Installation and licensing of custom BSP files remain an administrator responsibility.
