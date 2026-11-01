# Multi-Mode Network validation checklist

Record the date, machine, command output, and pass/fail result. Do not mark an item passed unless it was actually observed.

## Installation and static checks

- [ ] `git status --short` does not show `runtime`, `downloads`, `.runtime`, compiled `.amxx`, logs, secrets, or local configuration.
- [ ] `runtime\hlds-steam-legacy\hlds.exe` and `runtime\hlds-steam-legacy\cstrike\liblist.gam` exist after the server installer finishes.
- [ ] `liblist.gam` points `gamedll` to `addons\metamod\dlls\metamod.dll`.
- [ ] The three downloaded add-on archives match the SHA-256 values in `docs/SETUP.md`.
- [ ] `build-plugins.ps1` exits successfully with no Pawn compiler warnings or errors.

## Phase 4.3.1 shared arcade round checks (not yet executed)

- [ ] Before any migration, record `hlds.exe`, `swds.dll`, `mp.dll`, `liblist.gam`, and Metamod DLL hashes and compare them with `docs/REGAMEDLL_MIGRATION.md`.
- [ ] Use a separate cloned runtime. Confirm the verified `runtime\hlds-steam-legacy` GameDLL was not overwritten.
- [ ] With the Valve GameDLL, run `mm_arcade_round_status`; confirm it reports unsupported and no fake `mp_round_infinite` cvar exists.
- [ ] After an explicitly approved ReGameDLL trial, run `game version`; record the exact version/build URL and confirm `mm_arcade_round_status` detects the complete cvar set.
- [ ] In Classic, verify normal round timer, team elimination, bomb, hostage, scoring, and restart behavior.
- [ ] In Deathmatch, Arms Race, and AWP Only, verify timer expiry, team elimination, bomb, hostage, VIP, and escape scenarios do not emit ordinary round-win/restart events.
- [ ] Verify a bomb already carried, dropped, or planted at an arcade transition is removed, and no new C4 is assigned during arcade play.
- [ ] Verify Deathmatch statistics/respawns, Arms Race weapon progression/win reset, AWP Only statistics/respawns/map switching, and YaPB behavior remain correct.
- [ ] Switch Classic → Deathmatch → Arms Race → AWP Only → Classic; confirm the saved round/objective cvars are retained across arcade-to-arcade transitions and restored before Classic.
- [ ] Restart and change maps; confirm the controller reapplies policy without mode-change or AWP-map loops.
- [ ] Perform the documented rollback in the trial runtime and confirm Valve `mp.dll` hash `1DE43E39DC9B085D5B0FE7920C520A319A8244532835C9EF7A4F5DA930BACE54` is restored.

## Phase 4.3.2 isolated workflow checks (manual; not yet executed)

- [ ] Follow `docs/REGAMEDLL_TRIAL.md` in order and record every script output; do not reuse or merge an old trial directory.
- [ ] Confirm setup refuses a running production executable, identical source/trial paths, paths outside the project runtime, and pre-existing trial/state directories.
- [ ] Confirm `manifest.json` records the production and clone paths, original GameDLL hash, verified backup records, and preserved Metamod/AMXX configuration hashes.
- [ ] Confirm install accepts only official `5.30.0.814` assets with the pinned archive/signature hashes and expected Windows archive layout.
- [ ] Confirm status reports the production GameDLL unchanged and the installed clone GameDLL matching `install.json`.
- [ ] Confirm the clone binds to `27016`, uses its own PID record and logs, and does not conflict with production `27015`.
- [ ] Complete every Deathmatch, Arms Race, AWP Only, arcade-transition, and Classic-restoration observation in `REGAMEDLL_TRIAL.md`.
- [ ] Confirm rollback refuses a running clone, verifies backups, restores/removes only manifest-listed GameDLL files, preserves addon/plugin configuration, and leaves production unchanged.
- [ ] `runtime\hlds-steam-legacy\cstrike\addons\amxmodx\plugins\mm_core.amxx` exists.

## Server startup and plugin loading

- [ ] Start with `.\scripts\start-server.ps1` and confirm the HLDS console stays running without a fatal error.
- [ ] In the HLDS console, run `status`; confirm hostname, UDP port `27015`, map, and no more than 12 slots.
- [ ] Run `meta version` and `meta list`; confirm Metamod-P `v1.21p109` and AMX Mod X are loaded.
- [ ] Run `amxx version` and `amxx plugins`; confirm AMX Mod X `1.10.0-git5487` and `mm_core.amxx` show a running/loaded state.
- [ ] Inspect the AMX Mod X log and confirm `Multi-Mode Network v0.4.3 initialized successfully.` appears.
- [ ] Stop with `.\scripts\stop-server.ps1` and confirm `hlds.exe` exits and `.runtime\hlds.pid` is removed.

## Same-machine client smoke test

- [ ] Start Counter-Strike 1.6 and open its console.
- [ ] Run `connect 127.0.0.1:27015` and join successfully.
- [ ] Send `/serverinfo` in normal chat; confirm `[Multi-Mode Network] Server Foundation 0.4.3` appears.
- [ ] Repeat `/serverinfo` in team chat and confirm the same response.

## Second LAN computer

- [ ] On the server host, run `ipconfig` and identify its IPv4 address on the Private LAN (for example `192.168.1.50`).
- [ ] Confirm both computers are on the same trusted LAN and Windows Firewall Private-profile rules exist for UDP/TCP `27015`.
- [ ] From a second computer with CS 1.6, run `connect <server-ip>:27015` in the game console.
- [ ] Confirm the second computer joins, can select a team, spawn, and move without an immediate disconnect.
- [ ] From the second computer, send `/serverinfo` and verify the project name and `0.4.3` version.
- [ ] Confirm the HLDS `status` output lists the remote client.

## Phase 2.1 menu checks

- [ ] Run `.\scripts\build-plugins.ps1`; confirm both Pawn sources compile without warnings or errors.
- [ ] Restart the server and run `amxx plugins`; confirm `mm_core.amxx`, `mm_mode_manager.amxx`, and `mm_modes.amxx` are running.
- [ ] Send `/serverinfo`; confirm `[Multi-Mode Network] Server Foundation 0.4.3` appears.
- [ ] Send `/menu`; confirm the native main menu offers **Game Modes** and **Server Information**.
- [ ] Select **Game Modes**; confirm Classic, Deathmatch, Arms Race, AWP Only, and HE Battle appear.
- [ ] Send `/modes`; confirm it opens the same five-mode menu directly.
- [ ] Select **Classic**; confirm 1v1, 2v2, 3v3, 4v4, 5v5, 1v2, 2v3, 3v4, and 4v5 appear.
- [ ] Select every mode and at least one Classic format; confirm an informational chat message appears and gameplay does not restart or change.
- [ ] Repeat `/menu` and `/modes` in team chat.

## Phase 2.2 mode-management checks

- [ ] Restart and confirm the log reports version `0.4.3`, active mode Classic, and Classic format 5v5.
- [ ] Send `/mode`; confirm it reports the active mode and selected Classic format.
- [ ] As a normal player, select every mode; confirm no mode changes and an administrator-required message appears.
- [ ] As an administrator with flag `h`, select Deathmatch, cancel once, then confirm; verify the active marker updates only after confirmation.
- [ ] Confirm `/modes` marks exactly one mode `[ACTIVE]`.
- [ ] In the authorized game console, run `amx_mode armsrace`, then repeat it; confirm the first succeeds and the duplicate is rejected.
- [ ] Run `amx_mode invalid`; confirm clear usage feedback and no state change.
- [ ] Run `amx_classic_format 2v3`; confirm `/mode` reports 2v3 and the format menu marks it selected.
- [ ] Verify an unauthorized player cannot use either administrator command.
- [ ] Switch through AWP Only and HE Battle; confirm announcements occur but weapons, respawning, and round mechanics do not change.
- [ ] Restart; confirm volatile Phase 2.2 state safely returns to Classic/5v5.
- [ ] Confirm UDP `27015` remains bound and all three production plugins remain running.

## Phase exit criteria

Phase 1 remains verified by its foundation and LAN checks. Phase 2 remains verified by its menu and state-management checks. A successful compile alone does not prove runtime behavior.

## Phase 3 Classic automated and local-load checks

- [ ] Run `./tests/phase3.ps1`; confirm every static architecture/rules assertion passes.
- [ ] Run `./scripts/build-plugins.ps1`; confirm all seven production plugins compile with no warnings or errors and the tracked mode configurations are deployed.
- [ ] Restart the server; run `amxx plugins` and confirm all seven production project plugins report `running` at version `0.4.3`.
- [ ] Confirm the AMX Mod X log contains `Multi-Mode Network Classic match system v0.4.3 initialized.` and no plugin runtime errors.
- [ ] Run `/serverinfo` and `/mode`; verify existing Phase 1/2 behavior still works.

## Phase 3 multi-client in-game checks

Repeat the flow for all formats: 1v1, 2v2, 3v3, 4v4, 5v5, 1v2, 2v3, 3v4, and 4v5. Formats larger than the available human group require additional real clients; do not substitute bots.

- [ ] Set the format with `mm_match_format <format>` and verify the setup returns to Waiting.
- [ ] Join T and CT up to their stated limits; verify `/teams` counts slots correctly, a full-team attempt is rejected, and Spectator remains available.
- [ ] Fill both teams; verify Warmup starts. Test `/ready`, `/unready`, and the ready count, then ready every active player.
- [ ] Verify a three-second restart occurs, state becomes Live, starting money is $800, freeze time is 6 seconds, round time is 1:45, buy time is 20 seconds, friendly fire and collision use normal CS behavior, and dead players do not respawn during the round.
- [ ] Win controlled rounds on each side; verify `/score` and the HUD credit the correct logical Team A/B score.
- [ ] For MR3, verify halftime after 3 rounds and the match ends when a team reaches 4. Repeat MR5 (5/6) and MR12 (12/13).
- [ ] At halftime, verify every active player changes T/CT side and logical scores remain attached to Team A/B. For an unbalanced format, verify the capacity orientation swaps with the players.
- [ ] Force a 12–12 MR12 tie; verify MR3 overtime starts, sides swap every three overtime rounds, and a winner needs at least 16 rounds plus a two-round lead. Repeat with `mm_classic_overtime 0` and verify a 12–12 draw.
- [ ] Disconnect a roster player during Live; verify state becomes Paused and subsequent round-win events do not change the score. Reconnect or fill the correct slot and verify the three-second restart resumes the match.
- [ ] As a flag-`h` administrator, use `/pause` twice to pause/resume. Verify a normal player is refused. Test all five `mm_match_*` commands, missing/invalid arguments, and insufficient permissions.
- [ ] Change away from Classic during Warmup, Live, Halftime, Paused, and Finished; verify Classic timers/state stop and no later Classic callback changes the new mode. Return to Classic and verify a clean Waiting state.
- [ ] Complete a match; verify the winner announcement, Finished HUD, and automatic return to Waiting after ten seconds.
- [ ] Restart HLDS during setup and after a completed match; verify volatile state resets to Classic, 5v5, MR12, Waiting and all seven production plugins still run.

Phase 3 is accepted only after the required formats and lifecycle paths are exercised with real CS 1.6 clients. Local plugin loading does not prove multi-client joins, round scoring, side swaps, or completion.

## Optional Phase 3 solo-bot checks

- [ ] Run `./tests/solo-bots.ps1`; confirm all isolation checks pass.
- [ ] Install but do not enable YaPB; confirm Metamod's `plugins.ini`, AMX Mod X's `plugins.ini`, and `server.cfg` have no YaPB/test registrations.
- [ ] Enable while stopped, start, and run `meta list`; confirm YaPB `4.4.957` and AMX Mod X are both running.
- [ ] Run `yb version`; confirm YaPB reports `4.4.957`.
- [ ] Confirm startup creates zero bots (`yb_quota 0`).
- [ ] Complete the 1v1, 2v2, 3v3, unbalanced, overflow, ready, halftime, disconnect, and replacement procedures in `docs/SOLO_TESTING.md`.
- [ ] Stop and disable; restart and confirm YaPB and `mm_classic_test.amxx` are absent while all four production plugins still run.

Automated runtime evidence may prove plugin compatibility and state transitions, but visual/client behavior and real-player acceptance items remain manual.

## Phase 4.1 team Deathmatch checks

- [ ] Run `./tests/phase4-1.ps1`; confirm all architecture, lifecycle, configuration, and scope checks pass.
- [ ] Build and restart; confirm `amxx plugins` reports all seven production plugins running at `0.4.3`.
- [ ] Activate Deathmatch and confirm the log records `Deathmatch activated; transient scores reset.` while Classic produces no further match-state activity.
- [ ] Join T or CT, select every primary/secondary combination through `/dm`, and verify the selected loadout is applied immediately and after subsequent spawns.
- [ ] Die and verify respawn occurs approximately one second later. Repeat as a YaPB bot and a human.
- [ ] Fire during the two-second protection window and confirm protection ends; also confirm it expires without firing.
- [ ] Get kills until reserve ammunition is reduced, then get another kill and verify both selected weapons return to full reserve ammunition.
- [ ] Use `/top`; verify humans and bots are ordered by kills, with fewer deaths breaking equal-kill ties.
- [ ] Confirm teammates remain teammates, friendly fire is disabled, and no FFA behavior occurs.
- [ ] Switch to Classic while a respawn and protection timer are pending. Confirm the pending respawn/loadout does not occur, damage is normal, Classic returns to Waiting, and normal Classic cvars/loadouts resume.
- [ ] Switch repeatedly Classic → Deathmatch → Classic and inspect logs for native, Ham, invalid-player, or task errors.
- [ ] Confirm the known stock-engine behavior: eliminating the final member of a team may trigger the normal round-end/restart sequence even though Deathmatch respawn and its leaderboard remain active.

### Manual two-YaPB smoke test

With HLDS stopped:

```powershell
.\scripts\enable-test-bots.ps1
.\scripts\start-server.ps1
```

In the HLDS server console:

```text
mm_mode deathmatch
yb add 2 0 1 0 DM_Test_T
yb add 2 0 2 0 DM_Test_CT
yb list
```

Connect your CS 1.6 client, join either team or Spectators, and observe both bots. If you occupy a team slot, bots are not constrained by Classic format caps because Classic is inactive. Use `/dm` and `/top` as a human. Expected: both bots receive default AK-47/Deagle loadouts, deaths schedule a respawn near one second, protection lasts no more than two seconds, and bot kills/deaths appear in `/top`.

Then enter `mm_mode classic` in the HLDS console. Expected: Deathmatch logs cleanup, no dead player receives a delayed DM respawn, spawn protection is gone, and Classic initializes in Waiting. Cleanup with:

```powershell
.\scripts\stop-server.ps1
.\scripts\disable-test-bots.ps1
```

YaPB remains disabled by default; do not leave the development registration enabled after testing.

## Phase 4.2 team Arms Race checks

- [ ] Compile all plugins manually and confirm `mm_armsrace.sma` produces no errors or warnings.
- [ ] Restart and confirm `amxx plugins` reports `mm_armsrace.amxx` running at `0.4.3` while the server still defaults to Classic.
- [ ] Activate Arms Race with `mm_mode armsrace`; confirm Classic and Deathmatch stop changing state and the log reports a validated 15-level progression.
- [ ] Confirm the configured order begins with Glock/USP/Deagle, moves through SMGs, rifles, and snipers, then ends with M249 and Knife.
- [ ] As a human, kill an enemy with the assigned weapon; verify the level advances and the next weapon is equipped immediately with full reserve ammunition.
- [ ] Kill an enemy with the knife or a picked-up weapon before its configured level; verify the victim respawns but progression does not advance.
- [ ] Verify suicide and team-kill events do not advance progression. Confirm friendly fire remains disabled in the default configuration.
- [ ] Die as both a human and YaPB bot; verify respawn occurs in approximately one second and the current progression weapon is restored.
- [ ] Try `buy`, buy-menu equipment, rebuy, autobuy, and ammunition purchase commands; verify each is blocked while Arms Race is active.
- [ ] Use `/ar`; verify level, assigned weapon, valid kills, and deaths. Use `/artop`; verify ordering by level, kills, then fewest deaths.
- [ ] Confirm the HUD shows the local level/weapon/kills and current leader without obscuring normal play.
- [ ] Complete level 14, then make a valid knife kill on level 15. Verify winner chat/HUD announcements, no further progression during the five-second finish window, and a clean reset to level 1 for the next match.
- [ ] Change to Deathmatch and Classic while respawn/loadout/reset tasks are pending. Verify Arms Race performs no later respawn/equip/reset action and the selected mode owns gameplay.
- [ ] Confirm the known stock-engine limitation: eliminating the last living team member may still produce a normal CS round-end/restart sequence; Arms Race progression must survive that engine boundary.
- [ ] Change `mm_ar_level_1` to another supported weapon and restart/activate Arms Race; verify the configured weapon is used. Set an invalid name and verify the log reports fallback. Restore the tracked default afterward.

### Manual YaPB Arms Race setup

With HLDS stopped, enable the optional development bot environment and start normally:

```powershell
.\scripts\enable-test-bots.ps1
.\scripts\start-server.ps1
```

In the HLDS console:

```text
mm_mode armsrace
yb add 2 0 1 0 AR_Test_T
yb add 2 0 2 0 AR_Test_CT
yb list
```

Connect your client, join T/CT or spectate, and use `/ar` plus `/artop`. Expected: both bots begin with Glock, progress only on valid enemy kills with their assigned weapon, respawn near one second, and appear in the leaderboard/HUD leader calculation. Because this is a two-player team setup, expect the stock engine's normal round-end presentation after a team wipe.

When finished, enter `mm_mode classic`, confirm Arms Race cleanup and Classic Waiting state, then stop and disable YaPB:

```powershell
.\scripts\stop-server.ps1
.\scripts\disable-test-bots.ps1
```

## Phase 4.3 team AWP Only checks

- [ ] Before startup, use `Test-Path` to record whether `awp_india.bsp` or `awp_map.bsp` is installed. Do not mark map switching passed when neither exists.
- [ ] Compile manually and confirm `mm_awponly.sma` produces no errors or warnings; confirm `amxx plugins` later reports version `0.4.3`.
- [ ] Activate AWP Only with neither map installed; verify the current map remains loaded and the AMX Mod X log names both missing configured BSPs.
- [ ] With `awp_india.bsp` installed, activate from another map; verify exactly one change to `awp_india`, followed by automatic AWP Only restoration through the mode manager with no loop.
- [ ] Remove/rename only your manually installed test copy of `awp_india.bsp`, install `awp_map.bsp`, and verify it is selected as fallback. Restore your intended files/configuration afterward.
- [ ] Set `mm_awp_change_map "0"`; activate from a non-AWP map and verify no map change occurs. Restore `1` afterward if dedicated-map selection is desired.
- [ ] Join T and CT as humans and YaPB bots. Verify every spawn strips prior inventory and provides only Knife and AWP with configured reserve ammunition.
- [ ] Attempt buy, equipment buy, autobuy, rebuy, both ammo buys, weapon drop, a map armoury pickup, and a dropped weapon-box pickup; verify all are blocked.
- [ ] Die as both a human and bot; verify respawn occurs near one second and the AWP/Knife loadout returns.
- [ ] Verify spawn protection defaults to two seconds, expires normally, is removed by AWP primary fire, is not removed merely by scoping, and is removed by either knife attack.
- [ ] Reduce AWP reserve ammunition, make an enemy kill, and verify reserve ammunition replenishes. Verify suicide and non-enemy events do not add kills.
- [ ] Use `/awp` and `/awptop`; confirm personal kills/deaths and top-five ordering by kills then fewest deaths. Confirm the HUD shows kills, deaths, and the current leader.
- [ ] Switch AWP Only → Arms Race → Deathmatch → Classic while AWP respawn/loadout/protection tasks are pending; verify no AWP task acts after the transition and normal damage/cvars return.
- [ ] Confirm team-based play and friendly fire off. Confirm no FFA behavior was introduced.
- [ ] Confirm the known stock-engine limitation: eliminating the final team member may still display the normal round result/restart, while plugin standings and respawn behavior remain available.

### Manual two-YaPB AWP Only setup

Check maps while HLDS is stopped:

```powershell
Test-Path '.\runtime\hlds-steam-legacy\cstrike\maps\awp_india.bsp'
Test-Path '.\runtime\hlds-steam-legacy\cstrike\maps\awp_map.bsp'
```

Then enable the optional bot environment and start:

```powershell
.\scripts\enable-test-bots.ps1
.\scripts\start-server.ps1
```

In the HLDS console:

```text
mm_mode awponly
yb add 2 0 1 0 AWP_Test_T
yb add 2 0 2 0 AWP_Test_CT
yb list
```

If `awp_india` is installed, expect one intentional map change before adding/checking bots; if only `awp_map` is installed, expect that fallback. If neither is installed, expect the existing map to remain active. Connect your client and use `/awp` and `/awptop`.

Finish by selecting Classic and disabling the optional bot environment:

```text
mm_mode classic
```

```powershell
.\scripts\stop-server.ps1
.\scripts\disable-test-bots.ps1
```

