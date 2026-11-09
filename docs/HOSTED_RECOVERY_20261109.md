# OptikLink source recovery — 2026-11-09

This recovery branch preserves hosted work without changing the v1.0.0 build, normal local runtime, live server or release tags. It is a source backup pending integration, not a tested replacement release. Recovered Pawn sources are in `src/amxmodx/hosted/2026-11-09`; configuration examples are in `config/hosted/2026-11-09`. The existing build uses explicit source paths and does not register these files.

## Newly found work

- CoD mode: O'Zone engine, classes/items, bridge, access tiers, climbing, shop, supply and map cycle. Both `mm_cod.sma` and `cod_mod.sma` are preserved; the live registration selects `cod_mod` plus its bridge. Do not load both engines together.
- Zombie Plague: adapted MeRcyLeZZ 4.3 core, classes, Gold AK and admin commands.
- Furien: mode, movement, shop and map routing.
- Deathrun: operator selection/rotation and shared-mode integration; added while this audit was running.
- Persistent ban manager and modified stock admin command/player menus; camera, Knife spectator, hostname and inspect compatibility helpers.
- Hosted revisions of mode ownership, voting, menus, admin/presentation, Surf, Football, weapons and cosmetics.

## Boundaries and findings

The snapshot was obtained through read-only file-list/content API requests. No upload, restart, console command or installation was sent to OptikLink. Files were changing during capture, so changed shared sources/includes were refreshed. This is a point-in-time file recovery, not an atomic filesystem backup or proof that hosted compiled plugins match these sources. Version-suffixed ban binaries cannot be reconstructed with certainty from unversioned source names alone.

Original source text and embedded copyright/license notices are preserved. GPLv2/v3 license texts accompany the recovered tree. CoD's source retains O'Zone attribution; its exact upstream revision/license provenance still needs confirmation before broader redistribution or a new release. No blanket project license is assigned to third-party code.

Credentials, admin identities, ban records, databases/nVault player data, generated settings, logs, runtime binaries, AMXX outputs, archives and downloaded game assets are excluded. `cod_mod.cfg` contains generic database placeholders only. `plugins.example.ini` records observed registrations for recovery; it must not replace a working plugin list automatically. It references external plugins/assets and versioned ban outputs not included here.

The ban manager defaults its fake test bot to enabled (`mm_bantestbot 1`). Knife spectator helpers also contain test-bot commands. These sources are preserved as found, not enabled locally. Review and disable development test behavior before any future integration. The camera offers third-person commands and needs review against the project's first-person Classic policy. Missing dependency/resource and mode-isolation review remains necessary for the newly recovered modes.

## Verification and manual follow-up

Each recovered source is compiled independently against the captured shared includes and AMXX 1.10.0.5487 with the existing pinned ReAPI headers. Compiler output stays ignored under `.runtime`. Successful compilation does not establish runtime native availability, load ordering, asset availability, persistence safety or gameplay correctness. No server/game/bots are launched for this recovery.

Result: 142 sources checked, 139 compiled without warnings, three blocked by the missing include described below. Original third-party engine files and license texts are preserved whole; these pre-existing monoliths are exceptions to the small-change preference. Other snapshots are committed by module or bounded class/item groups. No new monolithic implementation was written.

```powershell
Set-Location C:\Projcets\server-1.6
.\scripts\check-hosted-recovery.ps1
# Or explicitly select the isolated compiler:
.\scripts\check-hosted-recovery.ps1 -CompilerPath .\.runtime\football-test\cstrike\addons\amxmodx\scripting\amxxpc.exe
```

The admin command sources `admincmd.sma`, `mm_ban_admincmd.sma` and `mm_ban_plmenu.sma` require `adminstyle`, absent from both the hosted include directory and local compiler. The check intentionally fails for these missing dependencies; it does not fabricate the include. Obtain the exact helper from the original developer and recheck before integrating bans.

Use the SHA256 manifest alongside this document to verify preserved source/configuration bytes. Integrate one feature at a time into the maintained source tree, fix warnings and permission/lifecycle issues, compile, then test on an isolated server with required authorized assets. Keep the published stable tag unchanged. No new mode is approved for deployment by this backup.
