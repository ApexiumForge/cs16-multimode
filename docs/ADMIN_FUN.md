# Optional admin fun controls

`optional/mm_admin_fun.sma` requires the existing ReAPI/ReGameDLL stack. Compile it with the AMXX compiler and register `mm_admin_fun.amxx` once. This plugin is excluded from the default build and has no downloadable assets.

Only human clients with `ADMIN_RCON` (flag `l`) may use `/ww1` or `mm_ww1`. Personal recoil/ESP switches start OFF and reset on connect/disconnect or lost authorization. Server cvar `mm_admin_fun 0` disables both features; restoring it does not restore personal switches. No cvars affecting other players are changed.

Client binds:

```cfg
bind "MOUSE4" "mm_ww1_esp"
bind "MOUSE5" "mm_ww1_recoil"
```

Recoil suppression cancels ReAPI KickBack and clears server punch angles around player thinking and after primary attacks. It does not remove bullet spread or alter damage. Client prediction may still show brief local firing motion and needs real-client verification.

ESP projects up to four nearest on-screen living players onto HUD channels. HUD labels remain visible through walls; this is a marker overlay, not transparent world rendering. Projection assumes a 4:3 vertical field of view and may drift at widescreen aspect ratios. HUD channels may overlap other mode HUDs. Markers expire within 0.21 seconds after disabling.

Disable both through the menu, or set `mm_admin_fun 0` in the server console. For permanent rollback, comment only its plugin registration and reload at a safe time. This optional module should be disabled for ordinary competitive play.
