[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$source = Get-Content -LiteralPath (Join-Path $repoRoot 'src\amxmodx\mm_classic.sma') -Raw
$config = Get-Content -LiteralPath (Join-Path $repoRoot 'config\cstrike\addons\amxmodx\configs\mm_classic.cfg') -Raw

function Assert-Match {
    param([string]$Text, [string]$Pattern, [string]$Description)
    if ($Text -notmatch $Pattern) { throw "Phase 3 check failed: $Description" }
}

foreach ($state in @('MATCH_WAITING','MATCH_WARMUP','MATCH_READY','MATCH_LIVE','MATCH_HALFTIME','MATCH_PAUSED','MATCH_FINISHED')) {
    Assert-Match $source $state "Missing lifecycle state: $state"
}
foreach ($command in @('/match','/ready','/unready','/score','/teams','/pause','mm_match_start','mm_match_stop','mm_match_restart','mm_match_format','mm_match_rules')) {
    Assert-Match $source ([regex]::Escape($command)) "Missing command: $command"
}
Assert-Match $source 'FORMAT_T_SLOTS\[MM_FORMAT_COUNT\]\s*=\s*\{1, 2, 3, 4, 5, 1, 2, 3, 4\}' 'T capacities do not cover all formats.'
Assert-Match $source 'FORMAT_CT_SLOTS\[MM_FORMAT_COUNT\]\s*=\s*\{1, 2, 3, 4, 5, 2, 3, 4, 5\}' 'CT capacities do not cover all formats.'
Assert-Match $source 'team_count\(CS_TEAM_T.*t_capacity' 'T team capacity must be enforced.'
Assert-Match $source 'team_count\(CS_TEAM_CT.*ct_capacity' 'CT team capacity must be enforced.'
Assert-Match $source 'cs_set_user_team\(id, CS_TEAM_SPECTATOR\)' 'Overflow players must be moved safely to spectators.'
Assert-Match $source 'mm_get_active_mode\(\) == MM_MODE_CLASSIC' 'Classic must be gated by authoritative mode state.'
Assert-Match $source 'public mm_mode_changed' 'Mode changes must disable or enable Classic safely.'
Assert-Match $source 'public mm_mode_transition_started' 'Classic must stop as soon as a transition away begins.'
Assert-Match $source 'public mm_classic_format_changed' 'Format changes must reset match setup.'
Assert-Match $source 'cmd_access\(id, level, cid' 'Administrative commands must enforce permissions.'
Assert-Match $source 'Mode changed|Match state' 'State transitions must be logged.'
Assert-Match $source 'g_second_half = !g_second_half' 'Halftime must switch logical sides.'
Assert-Match $source 'g_overtime' 'Overtime state must exist.'
Assert-Match $source 'sv_restart 3' 'Live and halftime transitions must restart rounds.'

$expectedCvars = @{
    mp_startmoney='800'; mp_freezetime='6'; mp_roundtime='1.75';
    mp_buytime='0.333333'; mp_friendlyfire='0'; mp_autoteambalance='0';
    mp_limitteams='0'; mp_maxrounds='0'; mp_winlimit='0'
}
foreach ($entry in $expectedCvars.GetEnumerator()) {
    Assert-Match $config ($entry.Key + '\s+"' + [regex]::Escape($entry.Value) + '"') "Incorrect or missing cvar: $($entry.Key)"
}

if ($source -match 'bot_add|deathmatch|arms.?race|weapon restriction|coins|xp') {
    throw 'Phase 3 check failed: out-of-scope gameplay was introduced.'
}

Write-Host 'All Phase 3 Classic architecture and rules checks passed.'
