# Multi-Mode Network validation checklist

Stable release v1.0.0: see [release verification and deployment scope](releases/v1.0.0.md). Automated results are separate from the owner's confirmation of live gameplay. `/serverinfo` must report `1.0.0` after rebuilding/deploying the release core; other plugins keep independent module versions.

Hosted synchronization 2026-11-03: see docs/HOSTED_SYNC_20261103.md for module-specific checks and verification results.

Football: follow docs/FOOTBALL.md for resource installation, two-player controls/scoring, geometry selftest, map persistence and Football -> DM -> Football -> Classic round-policy/ball cleanup checks. Keep the isolated runtime harness out of normal plugin registration.

Optional admin fun: verify a non-admin cannot invoke `/ww1`, `mm_ww1`, `mm_ww1_esp`, or `mm_ww1_recoil`; revoking flag `l` and disabling `mm_admin_fun` must immediately revoke effects. Verify switches reset after reconnect, MOUSE4/MOUSE5 toggle independently, ESP labels appear for living players behind walls and expire when disabled, and other players' recoil remains unchanged. Check pistols/rifles/scoped weapons and client prediction manually; compilation does not establish visual correctness.

Knife choice: open `/settings` -> Knife model (or `/knife`) as an ordinary player. Select Butterfly then CS GO pack knife while holding a knife; verify each viewmodel and that another player's choice is unaffected. Switch to a gun and back, respawn and change modes; verify the chosen knife persists. Stable Steam/Valve identities persist across reconnects via nVault; LAN identities are session-only. Missing pack resources must refuse the pack choice. The supplied pack knife has no inspect sequence; Butterfly inspect remains available through Weapon Inspector.

Optional weapon pack: verify all 24 firearms draw, reload, fire, scope and inspect correctly on a clean client. Confirm Butterfly remains unchanged, namespaced animation sounds download, missing-source sounds remain silent, and `mm_weapon_models 0` restores default viewmodels on subsequent deployments. Compilation does not verify animations in-game.

For weapon model diagnostics, run `mm_weapon_models_status` after equipping a firearm: expect 24 precached models, increasing deploy/applied counters and a namespaced viewmodel path. Version 1.0.2 uses the ReAPI DefaultDeploy hook to replace the viewmodel argument before the GameDLL deploys it; ReAPI is required. The hosted Ham deploy callback showed zero invocations despite a live AK-47, so compilation alone did not establish hook compatibility.

Record the date, machine, command output, and pass/fail result. Do not mark an item passed unless it was actually observed.

For the optional production ReGameDLL migration, follow [REGAMEDLL_PRODUCTION.md](REGAMEDLL_PRODUCTION.md). Preparation scripts are not runtime validation; record `game version`, `meta list`, `amxx plugins`, controller diagnostics, all four mode checks, transitions, and any rollback separately.

For the optional Double Kill announcer, confirm `sound/multimode/doublekill.wav` downloads on a clean client, `mm_announcer.amxx` reports `running`, two valid kills by one player within four seconds play the sound once, suicide and Classic team-kills do not trigger it, and a death/mode transition clears the pending sequence.

Phase 5 voting is not validated by source review or compilation alone. Follow [MAP_VOTING.md](MAP_VOTING.md), disable the four stock vote owners, and record each manual observation below.

## Phase 5 map and mode voting checks (manual; not yet executed)

- [ ] Back up the hosted `plugins.ini` and `mm_classic.amxx` while the server is stopped.
- [ ] Build manually; confirm `mm_classic.sma` and `mm_voting.sma` compile without warnings or errors.
- [ ] Confirm `mapchooser.amxx`, `nextmap.amxx`, `adminvote.amxx`, and `mapsmenu.amxx` are disabled, and `mm_voting.amxx` loads after `mm_classic.amxx`.
- [ ] Run `amxx plugins`; confirm both `mm_classic` and `mm_voting` report `running` without native errors.
- [ ] With two humans, submit one `/rtv`; confirm the displayed count uses the configured 60% threshold. Submit the second request if required and confirm the mode menu opens.
- [ ] Vote each of Classic, Deathmatch, Arms Race, and AWP Only; confirm only the corresponding installed maps are offered and no missing BSP is offered.
- [ ] Confirm Classic rejects non-`de_`/`cs_` entries and AWP Only rejects non-`awp_` entries in the AMX Mod X log.
- [ ] Use `/votemode` and `/votemap` during an active vote; confirm they reopen the correct menu rather than starting a duplicate vote.
- [ ] Change a ballot before vote end; confirm only the final selection counts. Disconnect a voter and confirm that ballot and RTV request are removed.
- [ ] Join Spectators as a human and confirm voting works. Add YaPB bots and confirm they neither increase the threshold nor receive a vote menu.
- [ ] Force a tie; confirm the announcement says it was resolved randomly among tied choices.
- [ ] Attempt repeated vote commands within five seconds and another vote during the configured cooldown; confirm both are refused.
- [ ] Complete a vote on an arcade mode; confirm one map change occurs, the selected mode is restored on the new map, and ReGameDLL continuous-round policy remains active.
- [ ] Select `awp_map` while `awp_india` is also installed; confirm AWP Only accepts the voted map and does not issue a second preferred-map change.
- [ ] Complete a same-map mode vote; confirm the mode manager transitions without a recursive `changelevel`.
- [ ] Start a Classic match, complete a vote while Live, and confirm `/nextmap` reports it queued with no interruption. Finish or administratively stop the match and confirm the queued decision then applies.
- [ ] Change Classic through Halftime and Paused states; confirm the queued decision remains deferred.
- [ ] Empty the server during a vote; reconnect and confirm the old vote is gone and a new vote can start after cooldown.
- [ ] Leave automatic voting enabled; confirm it begins after 900 seconds when the minimum human count exists, including in an arcade mode with `mp_timelimit 0`.
- [ ] Disable `mm_vote_enabled`; confirm all four player commands refuse voting and no automatic vote starts after the next map load.
- [ ] Perform the documented rollback and confirm the old Classic plugin and previous stock voting configuration load normally.

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
- [ ] After an explicitly approved ReGameDLL trial, run `game version`; record the exact version/build URL and confirm `mm_arcade_round_status` detects all five required arcade-policy cvars, including `mp_freeforall`, while reporting unavailable optional presentation cvars as skipped.
- [ ] In Classic, verify normal round timer, team elimination, bomb, hostage, scoring, and restart behavior.
- [ ] In Deathmatch, Arms Race, and AWP Only, verify timer expiry, team elimination, bomb, hostage, VIP, and escape scenarios do not emit ordinary round-win/restart events.
- [ ] Verify a bomb already carried, dropped, or planted at an arcade transition is removed, and no new C4 is assigned during arcade play.
- [ ] Verify Deathmatch statistics/respawns, Arms Race weapon progression/win reset, AWP Only statistics/respawns/map switching, and YaPB behavior remain correct.
- [ ] Switch Classic → Deathmatch → Arms Race → AWP Only → Classic; confirm the five required round/objective/FFA cvars and every available optional presentation cvar are retained across arcade-to-arcade transitions and restored before Classic.
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
- [ ] Inspect the AMX Mod X log and confirm `Multi-Mode Network v0.4.4 initialized successfully.` appears.
- [ ] Stop with `.\scripts\stop-server.ps1` and confirm `hlds.exe` exits and `.runtime\hlds.pid` is removed.

## Same-machine client smoke test

- [ ] Start Counter-Strike 1.6 and open its console.
- [ ] Run `connect 127.0.0.1:27015` and join successfully.
- [ ] Send `/serverinfo` in normal chat; confirm `[Multi-Mode Network] Server Foundation 0.4.4` appears.
- [ ] Repeat `/serverinfo` in team chat and confirm the same response.

## Second LAN computer

- [ ] On the server host, run `ipconfig` and identify its IPv4 address on the Private LAN (for example `192.168.1.50`).
- [ ] Confirm both computers are on the same trusted LAN and Windows Firewall Private-profile rules exist for UDP/TCP `27015`.
- [ ] From a second computer with CS 1.6, run `connect <server-ip>:27015` in the game console.
- [ ] Confirm the second computer joins, can select a team, spawn, and move without an immediate disconnect.
- [ ] From the second computer, send `/serverinfo` and verify the project name and `0.4.4` version.
- [ ] Confirm the HLDS `status` output lists the remote client.

## Phase 2.1 menu checks

- [ ] Run `.\scripts\build-plugins.ps1`; confirm both Pawn sources compile without warnings or errors.
- [ ] Restart the server and run `amxx plugins`; confirm `mm_core.amxx`, `mm_mode_manager.amxx`, and `mm_modes.amxx` are running.
- [ ] Send `/serverinfo`; confirm `[Multi-Mode Network] Server Foundation 0.4.4` appears.
- [ ] Send `/menu`; confirm the native main menu offers **Game Modes** and **Server Information**.
- [ ] Select **Game Modes**; confirm Classic, Deathmatch, Arms Race, AWP Only, HE Battle, and Knife 35HP appear.
- [ ] Send `/modes`; confirm it opens the same six-mode menu directly, and `/rules` opens the rules MOTD.
- [ ] As a normal non-admin player, send `/settings` and `/set`; confirm both open Player Settings and the main `/menu` links to it.
- [ ] Verify Crosshair opens `/crosshair`; DM Loadout is refused outside Deathmatch and opens `/dm` inside it; personal status and leaderboard route correctly for the active mode.
- [ ] Open Voting and Next Map; verify `/nextmap`, `/votemode`, `/votemap`, and `/rtv` retain their existing cooldown, minimum-player, and Classic-live safeguards.
- [ ] Select **Classic**; confirm 1v1, 2v2, 3v3, 4v4, 5v5, 1v2, 2v3, 3v4, and 4v5 appear.
- [ ] Select every mode and at least one Classic format; confirm an informational chat message appears and gameplay does not restart or change.
- [ ] Repeat `/menu` and `/modes` in team chat.

## Phase 2.2 mode-management checks

- [ ] Restart and confirm the log reports version `0.4.4`, active mode Classic, and Classic format 5v5.
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

## Hosted arcade additions

- [ ] Run `scripts\install-reapi.ps1`; confirm version `5.29.0.358` and both pinned SHA-256 checks succeed.
- [ ] Run `tests\hosted-features.ps1` and `tests\remote-sync.ps1`; confirm both pass.
- [ ] Build all plugins with zero warnings; confirm `mm_he_battle`, `mm_arcade_protection`, `mm_knife`, `mm_armsrace_restrictions`, `mm_random_spawns`, and `mm_weapon_tuning` are generated and registered once.
- [ ] Start the isolated/local server and confirm ReAPI plus every managed plugin reports running without missing-native errors.
- [ ] Activate HE Battle; verify HE-only inventory, grenade replenishment, blocked buying/pickups, one-second respawns, ally protection, enemy-kill standings, and continuous rounds.
- [ ] Activate Knife 35HP on an installed map from `maps_knife.ini`; verify Knife only, 35 HP, no armor/buying/fall or team damage, and normal team round endings.
- [ ] Switch HE Battle to Classic while supply/respawn tasks are pending; verify no delayed HE action and normal Classic inventory/round cvars return.
- [ ] In Arms Race, verify two assigned-weapon kills advance one level, a knife kill advances immediately, and the knifed victim loses no more than one level without underflow.
- [ ] In Deathmatch and Arms Race, run `mm_spawn_status`; verify grounded points exist and repeated spawns avoid walls, hazards, and occupied hulls on every installed map.
- [ ] Set `mm_weapon_tuning 0`; verify native weapon behavior returns. Re-enable it and verify only grounded stationary supported weapons receive the configured server-side scaling.
- [ ] From a clean client, verify every `mm_xh_v3_*.spr/.txt` request succeeds through FastDL and `/crosshair` exposes five shapes and five colors.

## Phase 3 Classic automated and local-load checks

- [ ] Run `./tests/phase3.ps1`; confirm every static architecture/rules assertion passes.
- [ ] Run `./scripts/build-plugins.ps1`; confirm all seven production plugins compile with no warnings or errors and the tracked mode configurations are deployed.
- [ ] Restart the server; run `amxx plugins` and confirm all eight production project plugins report `running` at version `0.4.4`.
- [ ] Confirm the AMX Mod X log contains `Multi-Mode Network Classic match system v0.4.4 initialized.` and no plugin runtime errors.
- [ ] Run `/serverinfo` and `/mode`; verify existing Phase 1/2 behavior still works.

## Phase 3 multi-client in-game checks

Repeat the flow for all formats: 1v1, 2v2, 3v3, 4v4, 5v5, 1v2, 2v3, 3v4, and 4v5. Formats larger than the available human group require additional real clients; do not substitute bots.

- [ ] Set the format with `mm_match_format <format>` and verify the setup returns to Waiting.
- [ ] Join T and CT up to their stated limits; verify `/teams` counts slots correctly, a full-team attempt is rejected, and Spectator remains available.
- [ ] In Classic, die and confirm teammates can be viewed only in first-person and living opponents cannot be revealed (`mp_forcecamera 2`, `mp_forcechasecam 2`). Switch to each respawn arcade mode and confirm both values become `0`, then return to Classic and confirm both restore to `2`.
- [ ] Fill both teams; verify Warmup starts. Test `/ready`, `/unready`, and the ready count, then ready every active player.
- [ ] Verify a three-second restart occurs, state becomes Live, starting money is $800, freeze time is 6 seconds, round time is 1:45, buy time is 20 seconds, friendly fire remains disabled, and dead players do not respawn during the round.
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

## Phase 4.1 free-for-all Deathmatch checks

- [ ] Run `./tests/phase4-1.ps1`; confirm all architecture, lifecycle, configuration, and scope checks pass.
- [ ] Build and restart; confirm all eight production plugins run, with the updated project plugins reporting `0.4.4`.
- [ ] Activate Deathmatch and confirm the log records `Deathmatch activated; transient scores reset.` while Classic produces no further match-state activity.
- [ ] Join T or CT, select every primary/secondary combination through `/dm`, and verify the selected loadout is applied immediately and after subsequent spawns.
- [ ] Die and verify respawn occurs approximately one second later. Repeat as a YaPB bot and a human.
- [ ] Fire during the two-second protection window and confirm protection ends; also confirm it expires without firing.
- [ ] Get kills until reserve ammunition is reduced, then get another kill and verify both selected weapons return to full reserve ammunition.
- [ ] Use `/top`; verify humans and bots are ordered by kills, with fewer deaths breaking equal-kill ties.
- [ ] Put two players on the same nominal team and one on the other team. Confirm every player can damage and kill every other player while self-kills do not add leaderboard kills.
- [ ] Confirm `mp_freeforall` is `1`, while `mp_autoteambalance` and `mp_limitteams` are `0`.
- [ ] Switch to Classic while a respawn and protection timer are pending. Confirm the pending respawn/loadout does not occur, damage is normal, Classic returns to Waiting, and normal Classic cvars/loadouts resume.
- [ ] Switch repeatedly Classic → Deathmatch → Classic and inspect logs for native, Ham, invalid-player, or task errors.
- [ ] With validated ReGameDLL, eliminate every living player repeatedly and confirm the shared infinite-round policy prevents ordinary round-end/restart events.

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

## Phase 4.2 free-for-all Arms Race checks

- [ ] Compile all plugins manually and confirm `mm_armsrace.sma` produces no errors or warnings.
- [ ] Restart and confirm `amxx plugins` reports `mm_armsrace.amxx` running at `0.4.4` while the server still defaults to Classic.
- [ ] Activate Arms Race with `mm_mode armsrace`; confirm Classic and Deathmatch stop changing state and the log reports a validated 15-level progression.
- [ ] Confirm the configured order begins with Glock/USP/Deagle, moves through SMGs, rifles, and snipers, then ends with M249 and Knife.
- [ ] As a human, kill an enemy with the assigned weapon; verify the level advances and the next weapon is equipped immediately with full reserve ammunition.
- [ ] Kill an enemy with the knife or a picked-up weapon before its configured level; verify the victim respawns but progression does not advance.
- [ ] Verify a kill against a player on either nominal team advances progression with the assigned weapon. Verify suicide does not advance.
- [ ] Die as both a human and YaPB bot; verify respawn occurs in approximately one second and the current progression weapon is restored.
- [ ] Try `buy`, buy-menu equipment, rebuy, autobuy, and ammunition purchase commands; verify each is blocked while Arms Race is active.
- [ ] Use `/ar`; verify level, assigned weapon, valid kills, and deaths. Use `/artop`; verify ordering by level, kills, then fewest deaths.
- [ ] Confirm the HUD shows the local level/weapon/kills and current leader without obscuring normal play.
- [ ] Complete level 14, then make a valid knife kill on level 15. Verify winner chat/HUD announcements, no further progression during the five-second finish window, and a clean reset to level 1 for the next match.
- [ ] Change to Deathmatch and Classic while respawn/loadout/reset tasks are pending. Verify Arms Race performs no later respawn/equip/reset action and the selected mode owns gameplay.
- [ ] Eliminate every living player repeatedly and confirm continuous-round policy prevents ordinary round-end/restart events while progression persists.
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

Connect your client, join T/CT or spectate, and use `/ar` plus `/artop`. Expected: bots begin with Glock, treat every other player as an enemy, progress on assigned-weapon kills regardless of nominal team, respawn near one second, and appear in the leaderboard/HUD leader calculation.

When finished, enter `mm_mode classic`, confirm Arms Race cleanup and Classic Waiting state, then stop and disable YaPB:

```powershell
.\scripts\stop-server.ps1
.\scripts\disable-test-bots.ps1
```

## Phase 4.3 free-for-all AWP Only checks

- [ ] Before startup, use `Test-Path` to record whether `awp_india.bsp` or `awp_map.bsp` is installed. Do not mark map switching passed when neither exists.
- [ ] Compile manually and confirm `mm_awponly.sma` produces no errors or warnings; confirm `amxx plugins` later reports version `0.4.4`.
- [ ] Activate AWP Only with neither map installed; verify the current map remains loaded and the AMX Mod X log names both missing configured BSPs.
- [ ] With `awp_india.bsp` installed, activate from another map; verify exactly one change to `awp_india`, followed by automatic AWP Only restoration through the mode manager with no loop.
- [ ] Remove/rename only your manually installed test copy of `awp_india.bsp`, install `awp_map.bsp`, and verify it is selected as fallback. Restore your intended files/configuration afterward.
- [ ] Set `mm_awp_change_map "0"`; activate from a non-AWP map and verify no map change occurs. Restore `1` afterward if dedicated-map selection is desired.
- [ ] Join T and CT as humans and YaPB bots. Verify every spawn strips prior inventory and provides only Knife and AWP with configured reserve ammunition.
- [ ] Attempt buy, equipment buy, autobuy, rebuy, both ammo buys, weapon drop, a map armoury pickup, and a dropped weapon-box pickup; verify all are blocked.
- [ ] Die as both a human and bot; verify respawn occurs near one second and the AWP/Knife loadout returns.
- [ ] Verify spawn protection defaults to two seconds, expires normally, is removed by AWP primary fire, is not removed merely by scoping, and is removed by either knife attack.
- [ ] Reduce AWP reserve ammunition, kill a player from either nominal team, and verify reserve ammunition replenishes. Verify suicide does not add a kill.
- [ ] Use `/awp` and `/awptop`; confirm personal kills/deaths and top-five ordering by kills then fewest deaths. Confirm the HUD shows kills, deaths, and the current leader.
- [ ] Switch AWP Only → Arms Race → Deathmatch → Classic while AWP respawn/loadout/protection tasks are pending; verify no AWP task acts after the transition and normal damage/cvars return.
- [ ] Put two players on the same nominal team and confirm they can damage/kill one another as FFA enemies.
- [ ] Return to Classic and confirm `mp_freeforall` returns to `0` and normal team rules return.
- [ ] Eliminate every living player repeatedly and confirm continuous-round policy prevents ordinary round results/restarts while standings and respawns remain available.

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

