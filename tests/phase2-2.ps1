[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$manager = Get-Content -LiteralPath (Join-Path $repoRoot 'src\amxmodx\mm_mode_manager.sma') -Raw
$menus = Get-Content -LiteralPath (Join-Path $repoRoot 'src\amxmodx\mm_modes.sma') -Raw
$api = Get-Content -LiteralPath (Join-Path $repoRoot 'src\amxmodx\include\mm_mode_api.inc') -Raw

function Assert-Match {
    param([string]$Text, [string]$Pattern, [string]$Description)
    if ($Text -notmatch $Pattern) { throw "Phase 2.2 check failed: $Description" }
}

Assert-Match $manager 'g_active_mode\s*=\s*MM_MODE_CLASSIC' 'Classic must be the default active mode.'
Assert-Match $manager 'g_requested_mode\s*=\s*MM_MODE_CLASSIC' 'Requested-mode state must exist.'
Assert-Match $manager 'g_transition_state\s*=\s*MM_TRANSITION_IDLE' 'Transition state must exist.'
Assert-Match $manager 'g_classic_format\s*=\s*MM_FORMAT_5V5' 'Classic format state must exist.'
Assert-Match $manager 'register_clcmd\("amx_mode"' 'amx_mode must be registered for administrator client consoles.'
Assert-Match $manager 'register_concmd\("amx_classic_format"' 'amx_classic_format must be registered.'
Assert-Match $manager 'register_clcmd\("say /mode"' '/mode must be registered.'
Assert-Match $manager 'cmd_access\(id, level, cid, 2\)' 'Console commands must enforce AMX Mod X access.'
Assert-Match $manager 'is_authorized_requester' 'Native requests must enforce authorization.'
Assert-Match $manager 'g_transition_state != MM_TRANSITION_IDLE' 'Overlapping transitions must be rejected.'
Assert-Match $manager 'mode == g_active_mode' 'Duplicate mode requests must be rejected.'
Assert-Match $manager 'apply_mode_config\(MM_MODE_CLASSIC\)' 'Failed transitions must attempt Classic fallback.'
Assert-Match $manager 'CreateMultiForward\("mm_mode_changed"' 'Mode changes must expose a forward.'
Assert-Match $menus 'Activate %s mode\?' 'Menu mode changes must require confirmation.'
Assert-Match $menus 'Select Classic format %s\?' 'Format changes must require confirmation.'
Assert-Match $menus 'has_mode_admin_access' 'Menus must enforce administrator access.'
Assert-Match $api 'native MmMode:mm_get_active_mode' 'The active-mode native must be documented.'

$configDir = Join-Path $repoRoot 'config\cstrike\addons\amxmodx\configs\mm_modes'
$expectedConfigs = @('classic.cfg', 'deathmatch.cfg', 'armsrace.cfg', 'awp_only.cfg', 'he_battle.cfg')
foreach ($config in $expectedConfigs) {
    if (-not (Test-Path -LiteralPath (Join-Path $configDir $config) -PathType Leaf)) {
        throw "Phase 2.2 check failed: missing mode config $config"
    }
}

if ($manager -match 'changelevel|map_restart|restart') {
    throw 'Phase 2.2 check failed: mode transitions must not reload the map.'
}
if (($manager + $menus) -match 'Ham_Spawn|give_item|cs_set_user_bpammo|set_user_health') {
    throw 'Phase 2.2 check failed: gameplay mechanics are out of scope.'
}

Write-Host 'All Phase 2.2 architecture and state-management checks passed.'
