[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$admin = Get-Content -LiteralPath (Join-Path $repoRoot 'src\amxmodx\mm_admin.sma') -Raw
$classic = Get-Content -LiteralPath (Join-Path $repoRoot 'src\amxmodx\mm_classic.sma') -Raw
$classicApi = Get-Content -LiteralPath (Join-Path $repoRoot 'src\amxmodx\include\mm_classic_api.inc') -Raw
$voting = Get-Content -LiteralPath (Join-Path $repoRoot 'src\amxmodx\mm_voting.sma') -Raw
$votingApi = Get-Content -LiteralPath (Join-Path $repoRoot 'src\amxmodx\include\mm_voting_api.inc') -Raw
$build = Get-Content -LiteralPath (Join-Path $repoRoot 'scripts\build-plugins.ps1') -Raw
$docs = Get-Content -LiteralPath (Join-Path $repoRoot 'docs\ADMIN_MENU.md') -Raw

function Assert-Match([string]$Text, [string]$Pattern, [string]$Description) {
    if ($Text -notmatch $Pattern) { throw "Phase 6 check failed: $Description" }
}

foreach ($command in @('say /admin', 'say_team /admin', 'say /adminmenu', 'say_team /adminmenu')) {
    Assert-Match $admin ([regex]::Escape($command)) "Missing admin command: $command"
}

foreach ($section in @('Game Mode Management', 'Map Management', 'Classic Match Management', 'Bot Management', 'Player Management', 'Server Controls', 'Live Server Dashboard')) {
    Assert-Match $admin ([regex]::Escape($section)) "Missing main menu section: $section"
}

Assert-Match $admin 'require_flag\(id, ADMIN_CFG\)' 'Sensitive configuration actions must recheck ADMIN_CFG.'
Assert-Match $admin 'require_flag\(id, ADMIN_KICK\)' 'Kick actions must recheck ADMIN_KICK.'
Assert-Match $admin 'require_flag\(id, ADMIN_SLAY\)' 'Slay actions must recheck ADMIN_SLAY.'
Assert-Match $admin 'ADMIN_IMMUNITY' 'Protected administrators must be recognized.'
Assert-Match $admin 'ADMIN_RCON' 'Only RCON-level administrators may override immunity.'
Assert-Match $admin 'g_target_userid' 'Targets must retain immutable session userids.'
Assert-Match $admin 'g_target_authid' 'Targets must retain observed auth IDs.'
Assert-Match $admin 'equal\(authid, g_target_authid\[id\]\)' 'Target identity must be revalidated before execution.'
Assert-Match $admin 'show_confirmation' 'Disruptive actions must require confirmation.'
Assert-Match $admin 'mm_request_classic_format' 'Classic format changes must use the centralized mode manager.'
Assert-Match $admin 'CLASSIC_FORMAT_NAMES' 'The panel must expose all supported Classic formats.'
Assert-Match $admin 'mm_voting_admin_cancel' 'The panel must centrally cancel active votes and queued decisions.'
Assert-Match $admin 'count_population' 'The live dashboard must distinguish humans and bots.'
Assert-Match $admin 'format_transition_state' 'The live dashboard must present transition state safely.'

Assert-Match $admin 'mm_request_mode' 'Mode changes must use the centralized mode manager.'
Assert-Match $admin 'mm_voting_admin_cancel' 'Mode changes must cancel conflicting vote state centrally.'
Assert-Match $admin 'mm_voting_admin_change' 'Map changes must use the Phase 5 controller.'
Assert-Match $admin 'is_map_valid' 'Map choices must be installed.'
Assert-Match $admin 'safe_map_name' 'Map names must be validated.'
Assert-Match $admin 'Active mode changed while the menu was open' 'Stale map selections must be rejected.'

Assert-Match $classicApi 'mm_classic_force_ready_humans' 'Classic readiness must have a narrow public native.'
Assert-Match $classic 'is_match_player\(id\).*\!is_user_bot\(id\).*\!is_user_hltv\(id\)' 'Force Ready must affect eligible humans only.'
Assert-Match $classic 'classic_admin_authorized' 'Classic native actions must enforce authorization internally.'
Assert-Match $classic 'if \(!teams_full\(\)\) return _:MM_CLASSIC_ADMIN_TEAMS_INCOMPLETE' 'Classic start/restart must preserve team-size validation.'

Assert-Match $votingApi 'mm_voting_admin_change' 'Voting must expose one authoritative admin map transition.'
Assert-Match $voting 'voting_admin_authorized' 'Voting admin natives must enforce authorization internally.'
Assert-Match $voting 'map_matches_mode\(_:\s*mode, map_name\)' 'Admin map transitions must retain mode-map compatibility checks.'
Assert-Match $voting '\!g_admin_override_classic.*mm_classic_change_blocked' 'Only an explicitly confirmed admin transition may override Classic deferral.'
Assert-Match $voting 'write_pending_decision' 'Cross-map mode persistence must remain owned by voting.'

Assert-Match $admin 'cvar_exists\("yb_version"\)' 'Bot actions must verify YaPB availability.'
Assert-Match $admin 'is_user_bot\(target\)' 'Bot removal must revalidate the selected client.'
Assert-Match $admin 'mm_classic_team_has_capacity' 'Bot/player moves must preserve Classic capacity.'

$votingIndex = $build.IndexOf("@{ Name = 'mm_voting'")
$adminIndex = $build.IndexOf("@{ Name = 'mm_admin'")
if ($votingIndex -lt 0 -or $adminIndex -le $votingIndex) {
    throw 'Phase 6 check failed: mm_admin must build after mm_voting.'
}
Assert-Match $build "'mm_voting\.amxx', 'mm_admin\.amxx'" 'Generated plugins.ini must load mm_admin after mm_voting.'
Assert-Match $docs 'Phase 5 is a deployment prerequisite' 'Deployment documentation must identify the Phase 5 prerequisite.'
Assert-Match $docs 'Rollback' 'Deployment documentation must include rollback.'

if ($admin -match 'register_concmd\([^,]+,[^,]+,[^\)]*ADMIN_ALL' -or $admin -match 'client_cmd\(') {
    throw 'Phase 6 check failed: unsafe arbitrary client/server command surface detected.'
}

Write-Host 'All Phase 6 admin security and integration checks passed.'
