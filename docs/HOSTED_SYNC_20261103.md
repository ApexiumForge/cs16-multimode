# Hosted changes synchronized on 2026-11-03

## Menu merge decisions

Mode descriptions/chat formatting follow the hosted menu, but Player Settings is retained (the hosted source had removed it). Configurable Classic practice money is deliberately retained rather than replaced by the hosted hard-coded 16000 balance. Shared router vote/decision guards are also retained. These are reviewed merges, not byte-for-byte copies of every live source.

## Crosshair v5

The sprite/descriptor pairs are committed with the matching source. Real item clip/reserve IDs replace reads from the fake CurWeapon HUD cache, fixing weapon identity and ammo indicators. Each v5 descriptor has transparent ammo icons and validated IDSP sprite headers. Earlier v1/v3 resources remain for rollback. Runtime publication to FastDL is a separate operation; clean clients must validate v5 downloads and scope behavior.

## Distributed spawns

Spawn selection is now limited to 32 candidate samples and two nearby line-of-sight traces per candidate, penalizing exposed/recently used locations. Hull/hazard checks and ordinary-spawn fallback remain. It applies only to Deathmatch/Arms Race; dedicated HE arenas retain their map starts. Verify crowded-server respawns and protection with bots/humans; this is a bounded heuristic, not a guarantee of invisible spawns.

## Weapon tuning

Hosted tuning adds grounded moving/SMG scales and opening-burst tracking with a configurable settling threshold. It reads real active items rather than the fake crosshair HUD ID. Review fixes separate the integer next-shot count from the Float timestamp declaration to prevent Pawn tag mismatch/reference errors. `mm_weapon_burst_selftest` covers eight pause/spray/weapon-switch boundaries. This is the friend's non-vanilla preset; `mm_weapon_tuning 0` restores native shots.

## Football visual goals

Goal lights/outlines/trails use temporary entities and stock sprites; no damage or ball force is introduced. This separate commit can be reverted without removing possession/scoring. `mm_football_goal_lights 0` disables goal visuals; `mm_football_light_test t|ct` previews them only while the active pitch is ready. Repeating light tasks are cancelled at shutdown.

## Football possession and boundaries

Football now has explicit carrier possession, tackles, adjustable shoot/pass power, rolling deceleration, pitch boundaries, throw-ins/corners/goal kicks, reserved restart pickups, goals/assists, match clock and podium/countdown. Pitch bounds are shipped with soccerjam coordinates. Our prior missing-resource guard, geometry validation, transition-safe respawn and proper movement restoration are retained instead of reverting to the hosted copies. Isolated HLDS lifecycle checks and the expanded geometry/rolling/shot/restart selftests are exercised before publishing; real kicking/tackling still requires human validation.

## Personal cosmetics

Optional weapon models add `/skins` default/custom selection with stable-ID nVault storage. Knife selection gains the default CS 1.6 model alongside Butterfly/pack knife. Knife deployment also uses ReAPI DefaultDeploy, preserving our previously established hosted hook fix rather than relying solely on Ham. Disconnect no longer calls CStrike natives on an out-of-game client. Assets remain separate from the default build.

## Knife rounds

Knife adds round-target scoring, `/ktop`, `/knifescore`, a result HUD and fresh-session reset. Actual equipped weapon IDs avoid custom crosshair interference; redundant 35hp-map health setters are blocked only while Knife is active. Routing stays exclusively in the shared router. Validate both teams, score boundaries and leaving during the delayed reset.

## HE teams/FFA and shared protection

HE supports saved admin Team/FFA rules through `/he` and `mm_he_ffa`, team-total scoring, grenade refill HUD and podium. Team/FFA changes start a fresh session to avoid mixing score rules. Shared AR/HE protection now has packet-only glow; no persistent render state is written. Existing damage filters enforce team protection even with the shared arcade FFA cvar.

## Sniper Arena

AWP Only now supports match-start AWP/Scout ballots, optional admin scoped-only rules, spawn health/armor settings, kill targets, inventory enforcement and result podium. FFA and installed-map loop guards are retained. The selected weapon is validated before loadout grants. Persisted admin scoped-only settings remain local. Verify scoped shots, both loadouts, vote cancellation and task/protection restoration on exit; commands remain `/awp` and `/awptop`.

## Classic readiness and results

Full teams enter ready-up immediately; live countdown, side-aware score HUD and end podium are added. Review fixes reject spectator `/unready` attempts (which could cancel another team's countdown) and clear per-slot kills/deaths on joining. Match-team limits, roster ownership, overtime and committed-match safeguards remain in Classic. Verify readiness cancellation and disconnect/rejoin during countdown with real clients.

## Arms Race

The hosted 17-level sequence inserts M3/XM1014 after P90; level 17 remains the final knife kill. Source and configuration are synchronized together. ReAPI reads the actual active weapon independently of custom crosshair HUD IDs; all non-suicide player kills remain eligible in FFA. Preserve two gun kills/one knife advancement and victim knife demotion. Results, leader notices and rematch/map ballots use shared contracts; tasks are cancelled on shutdown. Gameplay verification must cover both shotguns and final-level transitions.

## Deathmatch refresh

Deathmatch adds `/reuse`, authorization retry for loadout preferences, a configurable kill target, HUD/results reset, packet-only protection glow and disabled death weapon drops. No persistent XP/economy is introduced. Review fixes cancel loadout work during a finished/transitioning match and clean all player tasks at plugin shutdown. Verify cached preferences, respawns, and cosmetic hooks with humans/bots.

## Rematch and sniper ballots

Voting remains the sole owner of map decisions. New natives expose rematch/map choice and AWP/Scout selection. Binary ties/empty ballots select same-map/AWP; mode changes cancel obsolete special ballots. Joins can reopen active ballots; disconnects remove ballots/tasks. Added native argument and transition validation before starting votes. `mm_voting_selftest` exercises four tally cases; human menus and late joins require gameplay checks.

## Shared presentation

`mm_presentation_api.inc` exposes results/podium rendering and a stable ranking helper. It rejects calls for an inactive mode; player IDs are validated before names are read. Help tasks and podium HUD clear on transitions/disconnect. `mm_presentation` is loaded before its consumers. Command hints describe the final synchronized modes and are not additional gameplay ownership.

## Combat Surf

The eighth mode adds saved/restored airaccelerate/maxvelocity, per-player bhop and speed display, scoped protection, respawn/loadouts and optional jail bypass. Use `/surf`, `/surfhelp`, `/respawn` and `mm_surf_set_jail 0|1` (ADMIN_CFG). Jail target files are map-specific; normal teleports remain intact. Runtime saved settings are not overwritten by the build. Maps must be installed separately; pools accept only `surf_` BSPs. Original source attribution to Hawk552's uSurf and OneEyed's Surf Olympics is preserved; feature references are not verification of third-party asset licenses.

## Counter-strafe preset

The shooting-mode movement preset saves/restores accelerate/friction/stopspeed, clamps configuration, and preserves deliberate external edits. It is removed before mode transitions and inactive in Football/Knife/HE/Surf. ReHLDS uses its direct-cvar hook; stock HLDS reapplies only native reset values after GameRules think. ReHLDS is not required. Use `mm_counterstrafe 0` to disable and `mm_counterstrafe_status` to inspect the saved baseline.

## Chat styling

`mm_chat_style` styles plugin-tag brackets while preserving message bodies and avoiding clan-name prefixes. The hosted ReAPI engine message hook requires ReHLDS; stock HLDS uses AMXX's SayText hook as a supported fallback (some direct messages may bypass that fallback). `mm_chat_style_selftest` covers eight prefix/idempotence cases. No chat is resent, so the hook cannot recursively duplicate messages.

Changes are split by module so each commit can be reviewed/reverted separately. Runtime binaries, third-party assets, admin identities and generated logs are excluded. Hosted production is not redeployed by this synchronization.

## Map extension

`mm_extendmap` adds `amx_extendmap <minutes>` for ADMIN_MAP or server console. Valid range: 1-1440 whole minutes. Unlimited maps and maps with win/round limits are refused. `mm_extendmap_status` reports settings. Validation: compile with zero warnings; test valid/invalid arguments and permission checks, and confirm changing mode can intentionally replace its time limit.
