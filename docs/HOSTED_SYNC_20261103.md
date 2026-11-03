# Hosted changes synchronized on 2026-11-03

## Combat Surf

The eighth mode adds saved/restored airaccelerate/maxvelocity, per-player bhop and speed display, scoped protection, respawn/loadouts and optional jail bypass. Use `/surf`, `/surfhelp`, `/respawn` and `mm_surf_set_jail 0|1` (ADMIN_CFG). Jail target files are map-specific; normal teleports remain intact. Runtime saved settings are not overwritten by the build. Maps must be installed separately; pools accept only `surf_` BSPs. Original source attribution to Hawk552's uSurf and OneEyed's Surf Olympics is preserved; feature references are not verification of third-party asset licenses.

## Counter-strafe preset

The shooting-mode movement preset saves/restores accelerate/friction/stopspeed, clamps configuration, and preserves deliberate external edits. It is removed before mode transitions and inactive in Football/Knife/HE/Surf. ReHLDS uses its direct-cvar hook; stock HLDS reapplies only native reset values after GameRules think. ReHLDS is not required. Use `mm_counterstrafe 0` to disable and `mm_counterstrafe_status` to inspect the saved baseline.

## Chat styling

`mm_chat_style` styles plugin-tag brackets while preserving message bodies and avoiding clan-name prefixes. The hosted ReAPI engine message hook requires ReHLDS; stock HLDS uses AMXX's SayText hook as a supported fallback (some direct messages may bypass that fallback). `mm_chat_style_selftest` covers eight prefix/idempotence cases. No chat is resent, so the hook cannot recursively duplicate messages.

Changes are split by module so each commit can be reviewed/reverted separately. Runtime binaries, third-party assets, admin identities and generated logs are excluded. Hosted production is not redeployed by this synchronization.

## Map extension

`mm_extendmap` adds `amx_extendmap <minutes>` for ADMIN_MAP or server console. Valid range: 1-1440 whole minutes. Unlimited maps and maps with win/round limits are refused. `mm_extendmap_status` reports settings. Validation: compile with zero warnings; test valid/invalid arguments and permission checks, and confirm changing mode can intentionally replace its time limit.
