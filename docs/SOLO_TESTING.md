# Phase 3 solo testing with YaPB

This is an optional development environment. YaPB and `mm_classic_test.amxx` are not part of the production build and are disabled unless explicitly enabled while HLDS is stopped.

## Compatibility and pinned dependency

The selected bot is YaPB `4.4.957`, the current stable release from the maintained YaPB project. Its official documentation supports genuine Steam Counter-Strike 1.6, Windows dedicated servers, and loading as a Metamod plugin when AMX Mod X is installed. The installer downloads `yapb-4.4.957-windows.zip` from the official GitHub release and verifies SHA-256 `C32A5B4D77C08C3C59C417568C5719F9227238C6D627D478CFB1D9F7D9C113F4`.

YaPB is installed under `cstrike/addons/yapb`; it does not replace `hlds.exe`, `swds.dll`, `mp.dll`, `liblist.gam`, Metamod-P, AMX Mod X, or project plugins. It is registered after AMX Mod X only when solo testing is enabled.

## Install, enable, and disable

Run once while HLDS is stopped:

```powershell
.\scripts\install-test-bots.ps1
```

The installation alone does not load YaPB. Enable and start the test environment with:

```powershell
.\scripts\enable-test-bots.ps1
.\scripts\start-server.ps1
```

The development configuration sets `yb_quota 0`, so enabling the environment still creates no bots automatically. To return to the production baseline:

```powershell
.\scripts\stop-server.ps1
.\scripts\disable-test-bots.ps1
.\scripts\start-server.ps1
```

Disabling removes only the three development registrations. Installed/downloaded files remain for later use. Delete nothing from the server manually.

## Bot commands

Enter YaPB commands in the **HLDS server console**. The test configuration deliberately does not create a YaPB remote-control password.

```text
yb add 2 0 1 0 MM_T1
yb add 2 0 2 0 MM_CT1
yb kick t
yb kick ct
yb kickall instant
yb list
yb version
```

`yb add` arguments are `difficulty personality team model name`. Difficulty is 0 Newbie, 1 Average, 2 Normal, 3 Professional, or 4 Godlike. Personality is 0 Normal, 1 Aggressive, or 2 Careful. Team is 1 T or 2 CT. Change the global/live difficulty with `yb_difficulty 0` through `yb_difficulty 4`.

YaPB fake clients cannot type `/ready` through AMX Mod X's chat hook reliably. The development bridge calls the production `command_ready` handler, preserving its active-mode, match-state, team, and connection checks and never touching Classic's private ready state:

```text
mm_test_bots_ready all
mm_test_bots_ready t
mm_test_bots_ready ct
```

These commands require AMX Mod X flag `h` from a player console; the HLDS server console is authorized. The bridge is compiled only by `install-test-bots.ps1`, not by the production `build-plugins.ps1`.

`mm_test_autorun_1v1` must remain `0`. It exists only for automated startup smoke testing and creates a bot-only 1v1 when explicitly set to `1` before startup.

## Manual test sequences

Use `/teams`, `/match`, `/score`, and the HUD throughout. Before each format, enter `yb kickall instant`, set the format, then add exactly the requested teams. You may spectate an all-bot match or occupy one team slot yourself.

### 1v1

```text
mm_match_format 1v1
yb add 2 0 1 0 MM_T1
yb add 2 0 2 0 MM_CT1
mm_test_bots_ready all
```

Expected: after both bots join, state changes Waiting → Warmup. The ready command reports two bots, causes Ready and a three-second restart, then Live. Add another T bot and expect it to be moved to Spectators because T is already 1/1.

### 2v2

```text
yb kickall instant
mm_match_format 2v2
yb add 2 0 1 0 MM_T1
yb add 2 0 1 0 MM_T2
yb add 2 0 2 0 MM_CT1
yb add 2 0 2 0 MM_CT2
mm_test_bots_ready all
```

Expected: Warmup starts only at T 2/2 and CT 2/2; four bots ready; the match reaches Live. If you play instead of spectating, omit one bot from your chosen team, join that slot, use `/ready`, and then ready the bots.

### 3v3

Repeat 2v2 with three named bots on each side and `mm_match_format 3v3`. Expected: no Warmup at 3v2; Warmup starts at 3v3; an additional bot on either full side becomes a spectator.

### Unbalanced formats

For 1v2, add one T and two CT bots. For 2v3, add two T and three CT bots. Repeat correspondingly for 3v4 and 4v5 if machine capacity permits.

Expected: the exact T/CT capacities are enforced. At halftime the players switch sides and capacities reverse with them (for example, a 1v2 becomes T capacity 2 and CT capacity 1). Logical Team A/Team B scores must remain with the original rosters.

### Disconnect, pause, and cleanup

During Live, run `yb kick t` or `yb kick ct`. Expected: Classic enters Paused and round wins stop changing the score. Add a replacement bot to the missing side; expected: a three-second restart and return to Live. Run `yb kickall instant`, stop HLDS, disable the test environment, restart, and confirm no bots or test bridge load.

## What bots cannot validate conclusively

Real humans are still required to validate:

- human chat input and menu usability for every command;
- Steam identity/admin-flag behavior and unauthorized-player rejection;
- perceived HUD readability, audio, latency, and LAN client experience;
- simultaneous human team selection near the capacity limit;
- reconnecting the same real Steam player and preserving the intended experience;
- fair competitive behavior, economy decisions, communication, and gameplay balance;
- final acceptance on a second physical LAN computer.

Bots can exercise server-side capacity, ready, restart, scoring-event, halftime, pause, and completion paths, but they are not a substitute for human acceptance testing.

## Upstream references

- [YaPB project and stable downloads](https://yapb.github.io/)
- [Official installation instructions](https://yapb.github.io/docs/en/getting-started/installation/)
- [Official bot command reference](https://yapb.github.io/docs/en/configuring/botusage/)
