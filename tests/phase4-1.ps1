[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$source = Get-Content -LiteralPath (Join-Path $repoRoot 'src\amxmodx\mm_deathmatch.sma') -Raw
$roundController = Get-Content -LiteralPath (Join-Path $repoRoot 'src\amxmodx\mm_arcade_rounds.sma') -Raw
$armsRace = Get-Content -LiteralPath (Join-Path $repoRoot 'src\amxmodx\mm_armsrace.sma') -Raw
$awpOnly = Get-Content -LiteralPath (Join-Path $repoRoot 'src\amxmodx\mm_awponly.sma') -Raw
$classic = Get-Content -LiteralPath (Join-Path $repoRoot 'src\amxmodx\mm_classic.sma') -Raw
$config = Get-Content -LiteralPath (Join-Path $repoRoot 'config\cstrike\addons\amxmodx\configs\mm_modes\deathmatch.cfg') -Raw
$build = Get-Content -LiteralPath (Join-Path $repoRoot 'scripts\build-plugins.ps1') -Raw

function Assert-Match([string]$Text, [string]$Pattern, [string]$Description) {
    if ($Text -notmatch $Pattern) { throw "Phase 4.1 check failed: $Description" }
}

Assert-Match $source '#include <mm_mode_api>' 'Deathmatch must consume the centralized mode API.'
Assert-Match $source 'mm_get_active_mode\(\) == MM_MODE_DEATHMATCH' 'All mechanics must be gated by authoritative Deathmatch state.'
Assert-Match $source 'public mm_mode_transition_started' 'Transition-away cleanup must begin before the next mode activates.'
Assert-Match $source 'clear_player_tasks' 'Mode shutdown must remove player tasks.'
Assert-Match $source 'set_user_godmode\(id, 0\)' 'Mode shutdown/protection expiry must restore damage.'
Assert-Match $source 'exec server\.cfg' 'Leaving Deathmatch must restore baseline CS cvars.'

Assert-Match $source 'RegisterHam\(Ham_Killed' 'Deaths must be observed through Ham Sandwich.'
Assert-Match $source 'Ham_CS_RoundRespawn' 'Dead players must use the CS respawn path.'
Assert-Match $source 'mm_dm_respawn_delay", "1\.0"' 'Default respawn delay must be approximately one second.'
Assert-Match $source 'mm_dm_spawn_protection", "2\.0"' 'Default spawn protection must be two seconds.'
Assert-Match $source 'IN_ATTACK \| IN_ATTACK2' 'Firing must remove spawn protection.'
Assert-Match $source 'is_user_bot' 'The weapon menu must safely account for bots.'

Assert-Match $source 'say /dm' 'The weapon-selection command must exist.'
Assert-Match $source 'show_primary_menu' 'A primary weapon menu must exist.'
Assert-Match $source 'show_secondary_menu' 'A secondary weapon menu must exist.'
Assert-Match $source 'strip_user_weapons' 'Loadouts must replace the prior inventory.'
Assert-Match $source 'cs_set_user_bpammo' 'Loadouts/kills must replenish reserve ammunition.'
Assert-Match $source 'say /top' 'The leaderboard command must exist.'
Assert-Match $source 'g_kills\[attacker\]\+\+' 'Kills must be tracked.'
Assert-Match $source 'g_deaths\[victim\]\+\+' 'Deaths must be tracked.'
Assert-Match $source 'Free-for-all Deathmatch active' 'Deathmatch must identify its FFA rules.'
Assert-Match $roundController '"mp_freeforall"' 'The shared arcade controller must discover the ReGameDLL FFA cvar.'
Assert-Match $roundController 'CVAR_FREE_FOR_ALL' 'The FFA cvar must participate in shared save/apply/restore lifecycle handling.'
Assert-Match $armsRace 'is_valid_ffa_kill' 'Arms Race must accept non-suicide kills regardless of nominal team.'
Assert-Match $awpOnly 'is_valid_ffa_kill' 'AWP Only must accept non-suicide kills regardless of nominal team.'
if ($armsRace -match 'cs_get_user_team\(victim\)\s*!=\s*cs_get_user_team\(attacker\)' -or
    $awpOnly -match 'cs_get_user_team\(victim\)\s*!=\s*cs_get_user_team\(attacker\)') {
    throw 'Phase 4.1 check failed: an arcade kill path still rejects same-team FFA kills.'
}
Assert-Match $classic 'mm_get_active_mode\(\) == MM_MODE_CLASSIC' 'Classic mechanics must remain mode-gated.'
Assert-Match $classic 'public mm_mode_transition_started' 'Classic must shut down when Deathmatch is requested.'
Assert-Match $build "Name = 'mm_deathmatch'" 'The production build must compile Deathmatch.'
Assert-Match $build "'mm_classic\.amxx', 'mm_deathmatch\.amxx'" 'Gameplay plugins must be enabled in deterministic order.'

foreach ($setting in @(
    'mm_active_config\s+"deathmatch"',
    'mp_friendlyfire\s+"0"',
    'mp_autoteambalance\s+"0"',
    'mp_limitteams\s+"0"',
    'mp_freezetime\s+"0"',
    'mm_dm_respawn_delay\s+"1\.0"',
    'mm_dm_spawn_protection\s+"2\.0"'
)) { Assert-Match $config $setting "Missing Deathmatch setting: $setting" }

if ($source -match 'coins?|\bxp\b|skins?|database|sqlite' -or
    $config -match 'coins?|\bxp\b|skins?|database|sqlite|mp_friendlyfire\s+"1"') {
    throw 'Phase 4.1 check failed: out-of-scope shared systems were introduced.'
}

Write-Host 'All Phase 4.1 Deathmatch architecture and lifecycle checks passed.'
