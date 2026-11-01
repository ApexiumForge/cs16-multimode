# Safe ReGameDLL_CS production migration

Phase 4.3.3 prepares a reversible migration from the validated isolated trial to `runtime\hlds-steam-legacy`. Nothing runs automatically. The scripts copy ReGameDLL_CS only from the existing trial after validating its `5.30.0.814` install record, official archive/signature hashes, and installed-file hashes.

This is preparation, not proof that production works. Production startup and gameplay checks remain manual.

## Audited differences

The runtimes were inspected read-only on 2026-11-01:

| Item | Production (`27015`) | Validated trial (`27016`) |
| --- | --- | --- |
| GameDLL | Valve `mp.dll`, SHA-256 `1DE43E39...BACE54` | ReGameDLL_CS `5.30.0.814`, SHA-256 `DD2194C8...7A91D` |
| ReGame support | `game.cfg`/`game_init.cfg` absent; Valve `delta.lst` | Four verified release files |
| Round controller | `mm_arcade_rounds.amxx` absent | Present |
| Managed plugins | Seven present; several hashes differ | All eight present |
| Development plugins | `mm_classic_test.amxx` and `mm_sounds_test.amxx` registered | Both registered |
| Metamod chain | AMX Mod X and YaPB | Same registrations |

The workflow installs the four verified ReGameDLL files, the eight managed plugin binaries from the validated trial, and tracked mode configuration. It edits AMX Mod X `plugins.ini` narrowly: unrelated registrations remain, the managed plugins are listed once in dependency order, and the two obsolete development registrations are removed. It does not delete their local binaries or media.

Metamod-P, AMX Mod X itself, YaPB, `liblist.gam`, admin files, `server.cfg`, maps, and unrelated plugins are never copied from the trial. Selected preserved files are hash-guarded through install and rollback. HE Battle is outside V1 migration/testing scope; its configuration marker remains for architectural compatibility, but there is no HE gameplay plugin in the managed list.

## Backup and install

Open PowerShell in the repository root. Administrator rights are not required. Stop production, inspect status, then run the read-only prerequisite audit:

```powershell
Set-Location 'C:\Projcets\server-1.6'
.\scripts\stop-server.ps1
.\scripts\get-regamedll-production-status.ps1
.\scripts\test-regamedll-production-readiness.ps1
```

The audit requires a stopped production process, distinct runtime paths, the production HLDS/Metamod/AMXX layout, the exact validated trial records/files, and all eight trial plugin binaries.

Create a timestamped, hash-verified backup. This writes only ignored state under `.regamedll-production`; it does not modify production:

```powershell
.\scripts\backup-regamedll-production.ps1
```

Copy the printed migration ID, inspect its manifest and status, then install:

```powershell
$migrationId = 'REPLACE-WITH-PRINTED-ID'
.\scripts\get-regamedll-production-status.ps1 -MigrationId $migrationId
Get-Content ".\.regamedll-production\$migrationId\manifest.json"
.\scripts\install-regamedll-production.ps1 -MigrationId $migrationId
.\scripts\get-regamedll-production-status.ps1 -MigrationId $migrationId
```

The installer refuses a running server, changed target/preserved/source files, an invalid trial, an already migrated GameDLL, or another active migration. It records `installing` before its first production write so an interrupted copy can use the same rollback command. A `prepared` manifest can be abandoned safely because production has not changed.

## First start and console checks

```powershell
.\scripts\start-server.ps1
```

Record these HLDS console results:

```text
game version
meta list
amxx version
amxx plugins
mm_arcade_round_status
mp_round_infinite
mp_give_player_c4
```

Require ReGameDLL_CS `5.30.0.814`; the existing Metamod-P, AMX Mod X, and YaPB chain; and all eight managed plugins without the two obsolete development plugins. In Classic, require `mp_round_infinite 0` and `mp_give_player_c4 1`. If startup, loading, or baseline cvars fail, stop and roll back before gameplay tests.

## Manual smoke-test matrix

YaPB can supplement population, but real clients are still required for menus/HUD, input, network behavior, and subjective gameplay.

### Classic

1. Select Classic and a small balanced format; verify ready-up, capacity, start/restart, and scoring.
2. Verify normal timer and team-elimination round wins.
3. On a bomb map, verify C4 assignment, plant, defuse/explosion, and normal results.
4. Require `mp_round_infinite 0` and `mp_give_player_c4 1`.

### Deathmatch

1. Select Deathmatch and run `mm_arcade_round_status`; require supported status, `mp_round_infinite 1`, and `mp_give_player_c4 0`.
2. With a human and two YaPB bots, repeat cross-team kills beyond a normal transition.
3. Verify respawns, `/dm`, ammunition, spawn protection, `/top`, and statistics.
4. Verify no `CTs_Win`, `Terrorists_Win`, `Round_End`, or unintended restart after elimination/timer expiry.

### Arms Race

1. Select Arms Race and require the arcade status/cvars above.
2. Verify human/bot kills advance all 15 levels, equip immediately, and retain HUD/`/ar`/`/artop` state through respawns.
3. Complete the knife level; verify winner announcement and progression reset.
4. Verify elimination/timer expiry does not interrupt progression. Final completion remains an explicit production smoke test.

### AWP Only

1. Select AWP Only; verify the configured installed map (preferably `awp_india`) loads once without a loop.
2. After the map change, require the arcade status/cvars again.
3. Verify AWP/knife restriction, blocked buying/dropping, ammunition, spawn protection, respawns, HUD, `/awp`, and `/awptop` with humans and bots.
4. Verify elimination/timer expiry does not end the session. The full map-change/reinitialization path remains an explicit production smoke test.

### Transitions and restart

1. Exercise Classic → Deathmatch → Arms Race → AWP Only → Classic.
2. Verify arcade cvars persist across arcade transitions and Classic restores all saved required/available optional cvars.
3. Restart once in Classic and once in an arcade mode; repeat status checks and confirm no map loop.
4. Recheck YaPB add/remove, respawns, progression, statistics, and player capacity.

## Rollback

Stop production and use the exact migration ID:

```powershell
.\scripts\stop-server.ps1
.\scripts\restore-regamedll-production.ps1 -MigrationId $migrationId
.\scripts\get-regamedll-production-status.ps1 -MigrationId $migrationId
```

Rollback first requires migration-owned installed files and preserved files to match the manifest. It restores byte-for-byte backups and removes only exact targets recorded as absent before migration, then verifies the restored set. It never changes the trial.

After rollback, start production and require Valve `game version`, the original plugin files/registrations, and the original absence of `mm_arcade_rounds.amxx`. Exact restoration also restores any development registrations present at backup time; diagnose the failure before separately disabling them again.

Do not use SteamCMD `validate` as primary rollback: it can overwrite unrelated files. Retain `.regamedll-production` until rollback and post-rollback startup are manually verified.

## Outstanding risks

- No production runtime test is performed by these preparation changes.
- Managed plugin binaries differ between production and trial; migration deliberately uses the already compiled trial set. Rebuild/revalidate the trial first if source changes.
- Arms Race final completion and the full AWP map-change path still need smoke testing.
- Locally added plugins that patch Valve GameDLL internals by offsets/signatures remain a compatibility risk.
- A crash during copying can leave a partial install; keep production stopped and use manifest-bound rollback before retrying.
