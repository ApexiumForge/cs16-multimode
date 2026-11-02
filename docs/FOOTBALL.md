# Football integration

The live Football addition is now source-controlled as `mm_football.sma`, with the seven-mode API, manager/menu/admin/voting integration and shared dedicated-map router. The source retains its CSB copyright and GPL-3.0-or-later notice; this repository's adaptation fixes task lifecycle, speed reset, invalid pitch handling and missing-resource startup. The supplied header identifies counter-strike-boost.com and inspiration from Freecode's SoccerJam. Asset licensing is separate from the source license.

Required separately installed resources under cstrike:

- maps/soccerjam.bsp
- models/kickball/ball.mdl
- sound/kickball/bounce.wav
- sound/kickball/whistle.wav

The build copies configs/mm_modes/football.cfg, configs/mm_voting/maps_football.ini, and configs/mm_football/soccerjam.ini. No downloaded runtime files or third-party assets are committed. Install matching resources before activating; absent resources log a diagnostic and leave ball gameplay disabled rather than crashing unrelated modes.

Use `mm_mode football` from the server console or the authorized mode menu. Players use `/football` or `/soccer` for help. Touch dribbles; E/left-click shoots; R/right-click passes. Only nearby players with an unobstructed trace can kick. Player damage and purchases are blocked in this mode. First to `mm_football_goal_limit` (default 5) wins. Kickoffs reset player loadouts and ball; ordinary team elimination does not end Football rounds, while mp_freeforall remains 0. Returning to Classic restores the saved shared round cvars.

The pitch config contains kickoff XYZ, T-goal centre XYZ, and CT-goal centre XYZ. Current goal boxes assume an X-aligned pitch: half extents 25/145/55 units. Do not reuse these coordinates on another map. The same segment-vs-box detector handles fast shots and the six geometry cases in `mm_football_selftest`.

Manual validation:

1. Back up custom plugins/configuration and deploy compiled plugins only when the server is stopped. Preserve local admins, other optional modules and resource files.
2. Select Football; verify one ball appears on soccerjam, T/CT teams, no C4/purchases/damage, and the score HUD.
3. With two humans, test dribbling, E/left-click shots, R/right-click passes, height aiming, goals at both ends, own goals, reset and match win. Test `mm_football_reset` with and without ADMIN_CFG permissions.
4. Run `mm_football_selftest`: expect 6/6. Use `mm_football_status` for readiness, ball and scores.
5. Switch Football -> Deathmatch -> Football -> Classic. Verify no leftover ball or delayed kickoff/respawn, normal Classic movement and round behavior, and FFA only in the intended arcade modes.
6. Reconnect and test two LAN clients. YaPB is not a Football AI and is not validated for ball strategy.

For isolated automated runtime checks, clone the runtime into an ignored directory, install these resources, build with `scripts/build-plugins.ps1 -ServerDir <clone>`, compile `tests/pawn/mm_football_runtime_test.sma` using the project includes, and register that test plugin only in the clone. Start the clone on an unused port. The harness exercises Football -> DM -> Football -> Classic across dedicated map routing, checks ball cleanup, policy restoration and goal geometry, and quits. Never register this harness on a normal server; it changes modes and shuts down its server.

Rollback: restore the complete pre-deployment source-compatible plugin set and configs at a safe shutdown. Removing only the mode manager while retaining modules compiled against the seven-mode API is not a supported rollback.

Verification on 2026-11-02: all default plugins compiled without compiler warnings in `.runtime/football-test`; nine existing static/regression suites passed. The isolated steam_legacy/ReGameDLL HLDS on UDP 27018 completed 18 runtime assertions across Football -> Deathmatch -> Football -> Classic and map routing, including two runs of the six-case goal detector. No AMXX error log was generated. The harness quit the isolated server when finished. Human kick/pass behavior, movement restoration under actual player input, and hosted Linux gameplay were not exercised. Production was inspected read-only and was not restarted or redeployed during this validation.
