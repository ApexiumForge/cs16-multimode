# Hosted changes synchronized on 2026-11-03

## Chat styling

`mm_chat_style` styles plugin-tag brackets while preserving message bodies and avoiding clan-name prefixes. The hosted ReAPI engine message hook requires ReHLDS; stock HLDS uses AMXX's SayText hook as a supported fallback (some direct messages may bypass that fallback). `mm_chat_style_selftest` covers eight prefix/idempotence cases. No chat is resent, so the hook cannot recursively duplicate messages.

Changes are split by module so each commit can be reviewed/reverted separately. Runtime binaries, third-party assets, admin identities and generated logs are excluded. Hosted production is not redeployed by this synchronization.

## Map extension

`mm_extendmap` adds `amx_extendmap <minutes>` for ADMIN_MAP or server console. Valid range: 1-1440 whole minutes. Unlimited maps and maps with win/round limits are refused. `mm_extendmap_status` reports settings. Validation: compile with zero warnings; test valid/invalid arguments and permission checks, and confirm changing mode can intentionally replace its time limit.
