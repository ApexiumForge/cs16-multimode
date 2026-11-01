# ReGameDLL_CS compatibility and staged migration

Phase 4.3.1 requires a GameDLL capability that Valve's stock CS 1.6 `mp.dll` does not provide. Phase 4.3.2 adds an isolated, clone-only preparation workflow; it does not authorize replacement of the production GameDLL or claim runtime compatibility. See [REGAMEDLL_TRIAL.md](REGAMEDLL_TRIAL.md) for the scripts, exact commands, manual gameplay matrix, and rollback procedure.

## Inspected runtime

The local runtime was inspected read-only on 2026-11-01. No server process was started or stopped.

| Component | Inspected value |
| --- | --- |
| Steam app | `90`, `steam_legacy`, manifest build ID `5433925` |
| `hlds.exe` | file/product version `4.1.1.1`, SHA-256 `BD5B37EC60301FF243BEB114CBB69BF5213CBC3330496226558DF912349AC96D` |
| `swds.dll` | SHA-256 `D01FDDA605DB55E00C399B9D4773097DDBF6E64709A0125621D66093CC02DF42` |
| Valve `cstrike\dlls\mp.dll` | SHA-256 `1DE43E39DC9B085D5B0FE7920C520A319A8244532835C9EF7A4F5DA930BACE54` |
| Metamod | Metamod-P `1.21p109` |
| AMX Mod X | `1.10.0.5487` |
| GameDLL chain | `liblist.gam` loads Metamod; Metamod then loads `cstrike\dlls\mp.dll` |

The official ReGameDLL_CS project says it is compatible with Valve CS 1.6/CZero content and replaces only `mp.dll`/`cs.so`. Its binary-compatibility warning applies to plugins that scan or patch Valve's original binary by signatures or offsets. This repository's production Pawn plugins use documented AMX Mod X/Metamod interfaces and no Orpheu or ReAPI dependency was found. Standard AMX Mod X and Metamod plugins are described upstream as generally unaffected.

This is a positive static compatibility result, not a runtime certification. The exact combination of stock `steam_legacy` HLDS, Metamod-P, AMX Mod X, YaPB, and every project plugin must still pass the staged tests below. ReHLDS is not required for the proposed GameDLL-only trial and must not be introduced as part of this phase.

As of the inspection date, the latest stable upstream release is `5.30.0.814` (published 2026-05-18). Its official release provides `regamedll-bin-5.30.0.814.zip` and a detached `.asc` signature. The isolated installer pins the official metadata SHA-256 values for both assets. Use only the stable asset from the official `rehlds/ReGameDLL_CS` release. Do not use development builds, third-party repacks, loose DLLs, or Windows system directories.

## Central round policy

`mm_arcade_rounds.sma` is the single owner of shared arcade round policy. It recognizes Deathmatch, Arms Race, AWP Only, and the future HE Battle mode through `mm_mode_api.inc`; it does not duplicate active-mode state.

On entry to the first arcade mode it saves the existing values and, only when the required ReGameDLL round-control cvars are present, applies:

```text
mp_round_infinite "1"
mp_roundover "0"
mp_roundrespawn_time "-1"
mp_give_player_c4 "0"
```

When present, these optional presentation cvars are also saved and applied:

```text
mp_show_scenarioicon "0"
mp_show_bomb_timer "0"
```

ReGameDLL_CS `5.30.0.814` provides `mp_show_scenarioicon` but does not define `mp_show_bomb_timer`. Missing optional presentation cvars are logged and skipped; they do not disable continuous round control.

`mp_round_infinite 1` blocks all documented scenario checks: round timer, insufficient players, VIP, escape, bomb, team extermination, and hostage rescue. Disabling C4 assignment and removing an already carried, dropped, or planted C4 prevents a bomb left over at the transition from continuing to affect arcade play. Hostage/VIP/escape entities are not deleted because those entities cannot be reconstructed safely when returning to Classic without reloading the map.

Arcade-to-arcade transitions retain the saved pre-arcade baseline and reapply the policy. Before an arcade-to-Classic transition, all saved cvars are restored. The mode-specific plugins continue to own respawns, weapons, statistics, progression, map selection, and their existing cleanup. YaPB remains a Metamod bot plugin and receives the same normal player lifecycle; no bot quota or bot AI cvar is changed by the round controller.

With Valve's stock GameDLL, the controller reports every missing ReGameDLL cvar, changes no GameDLL cvars, and leaves the known round-end limitation in place. `mm_arcade_round_status` prints this diagnostic in the HLDS console. It deliberately does not register fake `mp_*` cvars.

## Superseded manual preparation

The commands below record the original design and are superseded by the guarded scripts in [REGAMEDLL_TRIAL.md](REGAMEDLL_TRIAL.md). Do not perform the first trial against `runtime\hlds-steam-legacy`.

From the repository root, choose explicit paths and create a timestamped backup inside the ignored `backups` directory:

```powershell
$sourceRuntime = [IO.Path]::GetFullPath('.\runtime\hlds-steam-legacy')
$trialRuntime = [IO.Path]::GetFullPath('.\runtime\hlds-regamedll-trial')
$backupRoot = [IO.Path]::GetFullPath((Join-Path '.\backups' ('regamedll-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))))

if (Test-Path -LiteralPath $trialRuntime) { throw "Trial target already exists: $trialRuntime" }
Copy-Item -LiteralPath $sourceRuntime -Destination $trialRuntime -Recurse

New-Item -ItemType Directory -Path $backupRoot | Out-Null
Copy-Item -LiteralPath (Join-Path $trialRuntime 'cstrike\dlls\mp.dll') -Destination $backupRoot
Copy-Item -LiteralPath (Join-Path $trialRuntime 'cstrike\liblist.gam') -Destination $backupRoot
Copy-Item -LiteralPath (Join-Path $trialRuntime 'cstrike\addons\metamod\plugins.ini') -Destination $backupRoot
foreach ($relativeFile in @('cstrike\game.cfg', 'cstrike\game_init.cfg', 'cstrike\delta.lst')) {
    $candidate = Join-Path $trialRuntime $relativeFile
    if (Test-Path -LiteralPath $candidate -PathType Leaf) {
        Copy-Item -LiteralPath $candidate -Destination $backupRoot
    }
}
Get-FileHash -Algorithm SHA256 (Join-Path $backupRoot 'mp.dll') | Format-List
```

Review both resolved runtime paths before executing these commands. The trial target must not exist, and the source must be the project-owned runtime. The backup copy of `mp.dll` must hash to the inspected Valve value above before proceeding.

The prepared installer performs the pinned download, hash checks, temporary extraction, expected-layout validation, and clone-only copy. Do not change `liblist.gam`: it must continue to load Metamod. Do not install ReAPI, ReHLDS, Metamod-R, or built-in zBot as part of this isolated trial. SteamCMD `validate` can restore Valve files, so do not run it inside the trial between installing ReGameDLL and testing unless the intention is to revert the replacement.

## Required staged validation

These tests are not yet executed:

1. Start only the cloned trial runtime and run `game version`; require the expected stable ReGameDLL version and official build URL.
2. Run `meta list` and `amxx plugins`; require Metamod-P, AMX Mod X, all project plugins, and optional YaPB to load without errors.
3. With Classic selected, verify normal timer, team elimination, bomb, hostage, and score behavior.
4. Select each implemented arcade mode. Run `mm_arcade_round_status`; require support detected and verify no `CTs_Win`, `Terrorists_Win`, `Round_End`, or unintended `Round_Start` after timer expiry, team elimination, planting/defusing, or hostage rescue.
5. Verify Deathmatch respawns/statistics, Arms Race progression/final knife win, AWP Only respawns/map switching, and YaPB add/remove behavior.
6. Exercise Classic → arcade → arcade → Classic. Confirm all four required cvars and every available optional presentation cvar are restored to their pre-arcade values, and Classic objectives work again.
7. Repeat a map change and server restart, including AWP Only's configured map restoration, and confirm no mode or map loop.

Real human clients are still required to validate client HUD/menu presentation, weapon input, network connection, and subjective bot/gameplay behavior.

## Rollback

If any trial check fails, stop the trial server. Copy the timestamped `mp.dll`, `liblist.gam`, and Metamod `plugins.ini` back to their exact locations in the trial runtime, then verify the restored `mp.dll` hash is `1DE43E39DC9B085D5B0FE7920C520A319A8244532835C9EF7A4F5DA930BACE54`. Remove ReGameDLL-only `game.cfg`, `game_init.cfg`, or `delta.lst` from the trial only after comparing them with the original backup/Steam manifest. The original `runtime\hlds-steam-legacy` remains the authoritative rollback because the trial never overwrites it.

Do not copy DLLs into Windows system directories. Do not replace the production GameDLL until the full trial passes and the user explicitly approves that migration.
