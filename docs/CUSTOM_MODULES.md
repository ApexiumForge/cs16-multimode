# Synchronized custom modules

These modules originated as production-only OptikLink additions and are now source-controlled and reproducible.

## Classic practice money

`mm_warmup_money` keeps active T/CT players at the configured practice balance only while Classic is Waiting, Warmup, or Ready. It stops during mode transitions and whenever a Classic match is committed, so it cannot refill money during live, halftime, paused, or finished match play.

Configuration in `mm_classic.cfg`:

```cfg
mm_classic_practice_money "16000"
```

Set the value to `0` to disable refills. Values are clamped to CS 1.6's maximum `$16000` balance.

## Crosshair menu

`mm_crosshair` provides `/crosshair` and `/ch` for human players. Four shapes and five colors are available. Preferences are stored in the isolated `mm_crosshair` nVault only for stable Steam/Valve identities; LAN and pending identities remain session-only.

The plugin preserves native sniper scopes and does not draw for Knife, C4, grenades, dead players, bots, spectators, hidden HUD states, or non-default FOV. Version 1.3 uses 25 v3 sprite/descriptor pairs. The earlier 20 v1 pairs remain for rollback compatibility. Resources live under `config/cstrike/sprites`, are copied by the production build, and must match FastDL.

## Hosted arcade additions

- `mm_he_battle` supplies HE-only respawns, enemy-kill standings, a configurable kill limit, and blocks purchases, pickups and map equipment.
- `mm_arcade_protection` provides attack-cancelled spawn protection for Arms Race and HE Battle.
- `mm_knife` provides team-based 35 HP knife rounds and routes only to installed maps from its voting pool.
- `mm_armsrace_restrictions` preserves progression grants while blocking engine purchases and world weapons.
- `mm_random_spawns` distributes Deathmatch, Arms Race, and HE Battle spawns across validated grounded points.
- `mm_weapon_tuning` adjusts grounded, stationary spread/recoil through ReAPI. Disable it with `mm_weapon_tuning 0` to restore native weapon behavior.

The ReAPI-backed modules require the pinned official dependency installed by `scripts/install-reapi.ps1` before compilation or startup.

## Optional HD skins and Butterfly knife

`src/amxmodx/optional/mm_skins.sma` preserves the source for the deployed cosmetic module. It is intentionally excluded from the default production build because it depends on separately licensed model and sound resources that are not distributed by this repository.

Register it exactly once through `plugins-mm-skins.ini` after installing its resources. Do not also add `mm_skins.amxx` to the main `plugins.ini`.

## Optional Double Kill announcer

`src/amxmodx/optional/mm_announcer.sma` preserves the source for the local Double Kill announcer. It counts two valid player kills by the same attacker inside the configured window, resets sequences on death, disconnect, and mode transition, and rejects suicides. Classic accepts only opposing-team kills; FFA arcade modes accept any non-suicide player kill.

The module is intentionally excluded from the default production build because it requires the separately supplied `sound/multimode/doublekill.wav`, whose provenance must be verified before distribution. After installing that resource, compile the plugin manually, deploy `mm_announcer.cfg`, and register `mm_announcer.amxx` exactly once. A clean repository clone must remain launchable without this optional module.

## Validation

```powershell
.\tests\remote-sync.ps1
.\scripts\build-plugins.ps1 -ServerDir <isolated-server-directory>
```

The automated checks require exactly 40 namespaced crosshair resources, reject generated `.ztmp` files, verify lifecycle/mode isolation, and ensure resource-dependent skins and announcer modules remain outside the default production build.
