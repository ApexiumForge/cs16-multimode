# Phase 6 custom admin menu

`mm_admin` provides one native AMX Mod X administration panel for the four supported modes. Open it with `/admin` or `/adminmenu`. Version 1.1 adds a live dashboard, all nine Classic format choices, and centralized vote/queued-decision cancellation. Every menu callback rechecks the caller's permissions; menu visibility is not treated as authorization.

## Prerequisites and load order

Phase 5 is a deployment prerequisite. The production server must run the matching builds of `mm_mode_manager`, `mm_classic`, and `mm_voting` before `mm_admin`. The required order is:

```text
mm_mode_manager.amxx
mm_classic.amxx
mm_voting.amxx
mm_admin.amxx
```

Other mode plugins retain their existing order. Do not deploy only `mm_admin.amxx`: its Classic and voting natives are deliberately explicit dependencies.

## Permissions

| AMX Mod X flag | Standard letter | Functions |
|---|---|---|
| `ADMIN_CFG` | `h` | Modes, maps, Classic lifecycle, YaPB and server cvars |
| `ADMIN_KICK` | `c` | Player list, information and kick |
| `ADMIN_SLAY` | `e` | Slay |
| `ADMIN_IMMUNITY` | `a` | Protect a target from non-RCON administrators |
| `ADMIN_RCON` | `l` | Override target immunity |

The panel never accepts a player-supplied map name or shell command. Player targets are stored as a userid plus the observed auth ID, then both are revalidated before execution.

## Integration behavior

- Mode changes call `mm_mode_manager`; an active vote or queued voting decision is cancelled first.
- Map changes list only installed entries from the active mode's Phase 5 map pool. The confirmed selection is sent back to `mm_voting`, which owns the one-use cross-map mode marker and `changelevel`.
- A committed Classic match displays an explicit interruption warning before a mode/map action. Player team moves remain locked during a committed match.
- Classic operations use `mm_classic` natives. Force Ready/Unready affects only connected human T/CT players. Spectators, HLTV and bots are untouched. Existing development-only `mm_test_bots_ready` behavior is unchanged.
- Classic format selection lists all nine supported formats, marks the current choice, requires confirmation, and routes the request through `mm_mode_manager`. A committed match receives the same interruption warning as mode/map changes.
- YaPB actions are refused unless `yb_version` exists. Bot addition uses the documented `yb add 2 0 <team> 0 <name>` form. Classic capacity is checked through the Classic API; removal revalidates that the selected client is still a bot.
- Friendly Fire, Autobalance, Team Limits and Gravity show their current runtime value and require confirmation. A later mode transition may intentionally restore its owned cvars.
- Server Controls can cancel an active Phase 5 vote or queued decision through `mm_voting`; it never edits voting state directly.
- Live Server Dashboard shows map, active mode, human/bot population, slots, transition state, active/queued voting state, friendly fire, gravity, and Classic lifecycle status, with an in-menu refresh action.

## Safe OptikLink deployment

Do not perform these steps while HLDS is running. Phase 5 must be deployed first.

Build locally in PowerShell:

```powershell
$ProjectRoot = 'C:\Projcets\server-1.6'
$ServerDir = Join-Path $ProjectRoot 'runtime\hlds-steam-legacy'
& (Join-Path $ProjectRoot 'scripts\build-plugins.ps1') -ServerDir $ServerDir
```

Before deployment, stop the OptikLink server and download backups of:

```text
/home/container/cstrike/addons/amxmodx/plugins/mm_classic.amxx
/home/container/cstrike/addons/amxmodx/plugins/mm_voting.amxx
/home/container/cstrike/addons/amxmodx/configs/plugins.ini
```

Upload these locally built files:

```text
runtime/hlds-steam-legacy/cstrike/addons/amxmodx/plugins/mm_classic.amxx
  -> /home/container/cstrike/addons/amxmodx/plugins/mm_classic.amxx

runtime/hlds-steam-legacy/cstrike/addons/amxmodx/plugins/mm_voting.amxx
  -> /home/container/cstrike/addons/amxmodx/plugins/mm_voting.amxx

runtime/hlds-steam-legacy/cstrike/addons/amxmodx/plugins/mm_admin.amxx
  -> /home/container/cstrike/addons/amxmodx/plugins/mm_admin.amxx
```

Add `mm_admin.amxx` after `mm_voting.amxx` in the hosted `plugins.ini`. Preserve all unrelated host plugins and settings. Start the server and require all three updated plugins to report `running` in `amxx plugins` before using the panel.

## Manual validation

1. Verify a normal player is denied `/admin`; verify flags `h`, `c`, and `e` expose only their intended actions.
2. Start and cancel a Phase 5 vote, then confirm an admin mode change. Verify the vote is cancelled once and the centralized mode transition completes.
3. Open Map Management in every supported mode. Verify only installed maps from that mode's pool appear. Confirm one same-map mode action and one cross-map action; verify no recursive map change.
4. During a committed Classic match, verify mode/map confirmation warns about interruption. Cancel once, then explicitly confirm in a disposable match.
5. Exercise Force Ready/Unready with humans, a spectator, HLTV if available, and YaPB. Only human T/CT players must change readiness; team-size validation must still prevent an invalid start.
6. Verify warmup, restart, stop and status in valid and invalid Classic states. No duplicate live transition should occur.
7. Select all nine Classic formats, cancel once, then confirm a format change. Verify the current marker updates and a committed match shows an interruption warning.
8. With YaPB absent, verify bot actions are refused. With YaPB loaded, add T/CT/balanced bots, remove one selected bot, and remove all; confirm no human is kicked.
9. Select a player, let that player disconnect, then confirm the pending action is refused. Verify immunity protection, kick confirmation, slay permissions, safe team moves and console player information.
10. Confirm every server control shows its current value and requires confirmation. Start a vote and create a queued decision, then cancel each from the panel.
11. Open and refresh Live Server Dashboard with humans and bots present; verify every displayed value matches the server.
12. Switch modes afterward and verify the active mode restores its owned settings. Recheck Deathmatch respawns, Arms Race progression, AWP Only map handling, Classic lifecycle and voting commands.

## Rollback

1. Stop the server.
2. Remove or comment `mm_admin.amxx` in `plugins.ini`.
3. Restore the backed-up `mm_classic.amxx`, `mm_voting.amxx`, and `plugins.ini`.
4. Leave source/configuration files in place; they are inert without registration.
5. Start the server and verify the pre-Phase-6 plugin list and all four modes.

No GameDLL, ReGameDLL, Metamod, YaPB binary, map, engine file, database or player data is changed by deployment or rollback.

## Known limitations

- The panel does not edit map pools in game and does not download maps.
- Force Ready All intentionally does not mark bots ready. The development-only bridge remains the only bot-ready mechanism.
- Server cvar controls are runtime changes, not persistent configuration edits, and mode ownership takes precedence on transitions.
- A confirmed cross-map action changes map immediately through the Phase 5 controller; there is no separate countdown in V1.0.
