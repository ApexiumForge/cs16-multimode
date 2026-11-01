# Isolated ReGameDLL_CS trial workflow

Phase 4.3.2 prepares a reproducible GameDLL trial. It does not establish that ReGameDLL_CS, the shared round controller, or the round-win fix works in this project. Only the manual checks below can establish that.

The workflow never installs into `runtime\hlds-steam-legacy`. It clones that runtime to `runtime\hlds-regamedll-trial`, stores generated state under `.regamedll-trial`, and defaults to port `27016`. Both generated directories are ignored by Git.

## Prepared components

| Script | Purpose |
| --- | --- |
| `new-regamedll-trial.ps1` | Refuses a running source server, creates a new clone, backs up the clone's original GameDLL files, verifies hashes, and writes the trial manifest. |
| `install-regamedll-trial.ps1` | Downloads the official pinned stable archive and detached signature, checks both published SHA-256 values, validates the archive layout, and installs only into the manifest-bound clone. |
| `start-regamedll-trial.ps1` | Starts only the clone with a dedicated PID record, `qconsole.log`, game logs, development configuration, and port `27016`. |
| `stop-regamedll-trial.ps1` | Stops only the PID whose executable path matches the isolated clone. |
| `get-regamedll-trial-status.ps1` | Reports production hash integrity, trial GameDLL state, install version/hash, PID, port, and log path without changing either runtime. |
| `restore-regamedll-trial.ps1` | Restores the clone's original GameDLL/config files from its verified backup and removes only ReGameDLL files that did not exist before the trial. |

The installer pins official ReGameDLL_CS `5.30.0.814`:

- Archive URL: `https://github.com/rehlds/ReGameDLL_CS/releases/download/5.30.0.814/regamedll-bin-5.30.0.814.zip`
- Archive SHA-256: `457F5C96A4D10280FCAD47F106CBD5BE86363A47DF1CCAB91C514E9D1BC6FD18`
- Signature SHA-256: `7A674DA4EE0B67F9013E99190609F1295A82F05FE5030C12786D527F731C172C`

These digests are published in the official GitHub release metadata. The installer downloads the detached signature and verifies its published hash, but does not import a signing key into the user's trust store. Administrators who require detached-signature trust validation should verify the `.asc` file separately against a trusted ReHLDS project signing key before starting the clone.

No ReHLDS, ReAPI, Metamod-R, built-in zBot files, or other engine/module dependency is installed.

## Exact execution order

Run from a normal PowerShell in the repository root. Administrator rights are not required. First ensure the production server is stopped; the clone script will refuse to proceed if it detects production `hlds.exe` running.

```powershell
.\scripts\stop-server.ps1
.\scripts\new-regamedll-trial.ps1
.\scripts\install-regamedll-trial.ps1
.\scripts\build-plugins.ps1 -ServerDir '.\runtime\hlds-regamedll-trial'
.\scripts\get-regamedll-trial-status.ps1
.\scripts\start-regamedll-trial.ps1
```

If the production server is already stopped and has no PID record, `stop-server.ps1` will report that condition; inspect it rather than deleting arbitrary PID files. The clone script itself performs the authoritative process-path check.

The setup script requires both its default trial and state paths not to exist. It never merges with an old or partial trial. If setup is interrupted, inspect those two generated paths and either keep them for diagnosis or manually move them aside before retrying. Never point `TrialDir` at the production directory.

After the clone has been created, the production server may be restarted independently on `27015`; the trial remains on `27016`. Do not run both on the same port.

### Optional YaPB in the clone

The clone preserves the production Metamod, AMX Mod X, YaPB, and project plugin files exactly as they existed at clone time. If YaPB was already installed but disabled, enable it only in the clone:

```powershell
.\scripts\enable-test-bots.ps1 -ServerDir '.\runtime\hlds-regamedll-trial'
```

If YaPB was never installed, install and enable the pinned development package in the clone only:

```powershell
.\scripts\install-test-bots.ps1 -ServerDir '.\runtime\hlds-regamedll-trial'
.\scripts\enable-test-bots.ps1 -ServerDir '.\runtime\hlds-regamedll-trial'
```

Run these before starting the trial. Bot support remains optional and must not be enabled automatically in the production runtime.

## Initial console checks

Connect the CS 1.6 client to the trial server at `<LAN-server-IP>:27016`. In the HLDS trial console, run:

```text
game version
meta list
amxx plugins
mm_arcade_round_status
mp_round_infinite
mp_give_player_c4
```

Expected before selecting an arcade mode:

- `game version` identifies ReGameDLL_CS `5.30.0.814` and its upstream build.
- Metamod-P, AMX Mod X, the eight production `mm_*.amxx` plugins, and optional YaPB load without error.
- `mm_arcade_round_status` reports that ReGameDLL cvars are available.
- Classic starts with `mp_round_infinite 0` and `mp_give_player_c4 1`, unless an intentional local configuration had different pre-arcade values.

Keep `qconsole.log` and the clone's `cstrike\logs` output. Ordinary `CTs_Win`, `Terrorists_Win`, `Round_End`, and new `Round_Start` messages after an arcade team wipe indicate failure.

## Manual arcade validation

For a two-bot team test, use the optional YaPB console commands after enabling the clone environment:

```text
yb add 2 0 1 0 Trial_T
yb add 2 0 2 0 Trial_CT
yb list
```

### Deathmatch

```text
mm_mode deathmatch
mm_arcade_round_status
mp_round_infinite
mp_give_player_c4
```

Expected:

1. `mp_round_infinite` is `1`; `mp_give_player_c4` is `0`.
2. Kill the final living player on one team repeatedly. No normal team-win or round-restart event occurs.
3. Humans and bots respawn in approximately one second.
4. `/dm` still applies the selected weapons, ammunition replenishes after kills, `/top` retains kills/deaths, and spawn protection still ends on attack.
5. On a bomb map, no player receives C4 and a C4 carried/planted immediately before the transition is removed.

### Arms Race

```text
mm_mode armsrace
mp_round_infinite
```

Expected:

1. Team elimination does not end or restart the round.
2. Bots and humans respawn normally.
3. A valid enemy kill advances exactly one weapon level and immediately equips the next weapon.
4. `/ar` and `/artop` preserve progression, kills, deaths, and leader ordering across team wipes.
5. A valid final-level knife kill still invokes the Arms Race winner/reset flow; this plugin-owned match reset is expected and is distinct from a stock team-win round end.

### AWP Only

```text
mm_mode awponly
mp_round_infinite
```

Expected:

1. If an installed configured AWP map causes one intentional changelevel, wait for AWP Only to restore and rerun the commands.
2. Team elimination does not produce a normal round win/restart.
3. Humans and bots receive only AWP/Knife, respawn normally, and retain session statistics.
4. `/awp` and `/awptop` remain correct; reserve ammunition and attack-cancelled protection still work.
5. There is no repeated map-change loop.

### Arcade-to-arcade transitions

Switch Deathmatch → Arms Race → AWP Only. Each mode must remain isolated, old tasks/loadouts must stop, and `mp_round_infinite` must remain `1`. Progression or statistics from one plugin must not be modified by an inactive plugin.

## Classic restoration

From any arcade mode:

```text
mm_mode classic
mm_arcade_round_status
mp_round_infinite
mp_roundover
mp_roundrespawn_time
mp_give_player_c4
mp_show_scenarioicon
```

Expected:

1. The four required round-control values and available `mp_show_scenarioicon` value match those captured before the first arcade activation. With the unmodified ReGameDLL defaults, `mp_round_infinite` returns to `0` and `mp_give_player_c4` to `1`. ReGameDLL_CS `5.30.0.814` does not define the optional `mp_show_bomb_timer` cvar.
2. Classic ready-up, team limits, scoring, halftime, and pause behavior still work.
3. A normal team elimination produces the appropriate T/CT win and ordinary next round.
4. On `de_dust2`, Terrorists can receive/plant C4 and bomb explosion or defusal ends the round normally.
5. Restart the trial once and repeat Classic → arcade → Classic to validate initialization and restoration after process startup.

These observations—not successful installation alone—determine whether Phase 4.3.2 is compatible.

## Stop and rollback

Stop the isolated process and inspect status:

```powershell
.\scripts\stop-regamedll-trial.ps1
.\scripts\get-regamedll-trial-status.ps1
```

Restore the clone to its original Valve GameDLL state:

```powershell
.\scripts\restore-regamedll-trial.ps1
.\scripts\get-regamedll-trial-status.ps1
```

Rollback verifies every backup before copying it. It restores the original clone `mp.dll` and any pre-existing `game.cfg`, `game_init.cfg`, and `delta.lst`; ReGameDLL versions of those three configuration files are removed only if the manifest proves they did not exist before setup. It leaves Metamod-P, AMX Mod X, YaPB, custom plugins, server configuration, maps, and gameplay data untouched.

Rollback never deletes the trial runtime and never writes to the production runtime. The production GameDLL hash is checked before and after rollback. Keep `.regamedll-trial\manifest.json`, its backup directory, and the rollback record until the trial is fully reviewed.

## Outstanding compatibility risks

- Official compatibility with Valve CS 1.6 content does not prove this exact stock HLDS/Metamod-P/AMX Mod X/YaPB combination is stable; only the manual runtime matrix can do that.
- Plugins that scan Valve's original GameDLL by offsets or signatures can fail under ReGameDLL. None were found in the project sources, but locally added plugins require separate review.
- YaPB is actively used with ReGameDLL but its exact installed build and graphs must be exercised on every test map.
- AWP Only intentionally changes maps when its configured BSP is installed; initialization ordering after that change must be checked for loops and restored round policy.
- The installer verifies official published SHA-256 values and the signature asset's integrity, but detached-signature trust validation remains a separate administrator step.
