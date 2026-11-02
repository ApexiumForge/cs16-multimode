[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$settings = Get-Content -LiteralPath (Join-Path $repoRoot 'src\amxmodx\mm_settings.sma') -Raw
$modes = Get-Content -LiteralPath (Join-Path $repoRoot 'src\amxmodx\mm_modes.sma') -Raw
$build = Get-Content -LiteralPath (Join-Path $repoRoot 'scripts\build-plugins.ps1') -Raw

function Assert-Match([string]$Text, [string]$Pattern, [string]$Description) {
    if ($Text -notmatch $Pattern) { throw "Player-settings check failed: $Description" }
}

Assert-Match $settings 'say /settings' 'The public /settings command must exist.'
Assert-Match $settings 'say /set' 'The short /set alias must exist.'
Assert-Match $settings '#include <mm_mode_api>' 'Settings must consume centralized mode state.'
Assert-Match $settings 'run_chat_command\(id, "/crosshair"\)' 'Crosshair settings must reuse the production crosshair handler.'
Assert-Match $settings 'MM_MODE_DEATHMATCH[\s\S]*run_chat_command\(id, "/dm"\)' 'DM loadouts must remain Deathmatch-only.'
Assert-Match $settings 'MM_MODE_ARMS_RACE[\s\S]*"/ar"' 'Arms Race personal progress must be available.'
Assert-Match $settings 'MM_MODE_AWP_ONLY[\s\S]*"/awp"' 'AWP personal status must be available.'
Assert-Match $settings 'run_chat_command\(id, "/nextmap"\)' 'The voting submenu must expose the planned next map.'
Assert-Match $settings 'run_chat_command\(id, "/votemode"\)' 'The voting submenu must reuse mode voting.'
Assert-Match $settings 'run_chat_command\(id, "/votemap"\)' 'The voting submenu must reuse map voting.'
Assert-Match $settings 'run_chat_command\(id, "/rtv"\)' 'The voting submenu must reuse RTV safeguards.'
Assert-Match $settings 'run_chat_command\(id, "/rules"\)' 'Rules must reuse the production MOTD handler.'
Assert-Match $modes 'Player Settings' 'The main menu must expose player settings.'
Assert-Match $build "Name = 'mm_settings'" 'The settings plugin must be compiled by the production build.'
Assert-Match $build "'mm_modes\.amxx', 'mm_settings\.amxx', 'mm_classic\.amxx'" 'Settings must load after menus and before gameplay modules.'

if ($settings -match 'ADMIN_[A-Z]+|register_concmd|register_srvcmd|server_cmd') {
    throw 'Player-settings check failed: ordinary settings must not require admin access or execute privileged commands.'
}

Write-Host 'All player-settings integration and safety checks passed.'
