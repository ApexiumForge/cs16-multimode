# Combat Surf

The hosted implementation credits feature references to Hawk552's uSurf 5.2 and OneEyed's Surf Olympics 1.5.2a. It is integrated through the project mode API rather than installed as either standalone third-party mode.

Only Surf owns its airaccelerate/maxvelocity and player bhop changes. Leaving Surf restores the saved settings and cancels HUD/loadout/respawn tasks. Jail bypass matches exact per-map configured teleport targets; never add normal gunroom/top targets indiscriminately. The build preserves locally saved mm_surf_settings.cfg.

Manual checks: enter Surf, use ramps and both teams, toggle bhop/speed display, choose a next-spawn weapon, die/restart, and test protected-spawn attack cancellation. Toggle jail as an authorized administrator and verify ordinary teleports still work. Leave for Classic and compare movement settings and bhop flags. Server commands mm_surf_status and mm_surf_jail_selftest expose diagnostics. Installed surf maps and human movement require separate gameplay validation.
