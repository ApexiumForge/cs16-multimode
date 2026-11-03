[CmdletBinding()]
param(
    [string]$ServerDir = (Join-Path $PSScriptRoot '..\runtime\hlds-steam-legacy'),
    [string]$CompilerPath
)

$ErrorActionPreference = 'Stop'
$ServerDir = [IO.Path]::GetFullPath($ServerDir)
$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$compiler = if ($CompilerPath) { [IO.Path]::GetFullPath($CompilerPath) } else { Join-Path $ServerDir 'cstrike\addons\amxmodx\scripting\amxxpc.exe' }
$pluginDir = Join-Path $ServerDir 'cstrike\addons\amxmodx\plugins'
$pluginsIni = Join-Path $ServerDir 'cstrike\addons\amxmodx\configs\plugins.ini'
$includeDir = Join-Path $repoRoot 'src\amxmodx\include'
$modeConfigSource = Join-Path $repoRoot 'config\cstrike\addons\amxmodx\configs\mm_modes'
$modeConfigDestination = Join-Path $ServerDir 'cstrike\addons\amxmodx\configs\mm_modes'
$classicConfigSource = Join-Path $repoRoot 'config\cstrike\addons\amxmodx\configs\mm_classic.cfg'
$classicConfigDestination = Join-Path $ServerDir 'cstrike\addons\amxmodx\configs\mm_classic.cfg'
$weaponTuningConfigSource = Join-Path $repoRoot 'config\cstrike\addons\amxmodx\configs\mm_weapon_tuning.cfg'
$weaponTuningConfigDestination = Join-Path $ServerDir 'cstrike\addons\amxmodx\configs\mm_weapon_tuning.cfg'
$votingConfigSource = Join-Path $repoRoot 'config\cstrike\addons\amxmodx\configs\mm_voting.cfg'
$votingConfigDestination = Join-Path $ServerDir 'cstrike\addons\amxmodx\configs\mm_voting.cfg'
$votingMapSource = Join-Path $repoRoot 'config\cstrike\addons\amxmodx\configs\mm_voting'
$votingMapDestination = Join-Path $ServerDir 'cstrike\addons\amxmodx\configs\mm_voting'
$rulesSource = Join-Path $repoRoot 'config\cstrike\addons\amxmodx\configs\mm_rules.html'
$rulesDestination = Join-Path $ServerDir 'cstrike\addons\amxmodx\configs\mm_rules.html'
$crosshairResourceSource = Join-Path $repoRoot 'config\cstrike\sprites'
$crosshairResourceDestination = Join-Path $ServerDir 'cstrike\sprites'
$plugins = @(
    @{ Name = 'mm_core'; Source = (Join-Path $repoRoot 'src\amxmodx\mm_core.sma') },
    @{ Name = 'mm_extendmap'; Source = (Join-Path $repoRoot 'src\amxmodx\mm_extendmap.sma') },
    @{ Name = 'mm_chat_style'; Source = (Join-Path $repoRoot 'src\amxmodx\mm_chat_style.sma') },
    @{ Name = 'mm_mode_manager'; Source = (Join-Path $repoRoot 'src\amxmodx\mm_mode_manager.sma') },
    @{ Name = 'mm_arcade_rounds'; Source = (Join-Path $repoRoot 'src\amxmodx\mm_arcade_rounds.sma') },
    @{ Name = 'mm_modes'; Source = (Join-Path $repoRoot 'src\amxmodx\mm_modes.sma') },
    @{ Name = 'mm_settings'; Source = (Join-Path $repoRoot 'src\amxmodx\mm_settings.sma') },
    @{ Name = 'mm_classic'; Source = (Join-Path $repoRoot 'src\amxmodx\mm_classic.sma') },
    @{ Name = 'mm_deathmatch'; Source = (Join-Path $repoRoot 'src\amxmodx\mm_deathmatch.sma') },
    @{ Name = 'mm_armsrace'; Source = (Join-Path $repoRoot 'src\amxmodx\mm_armsrace.sma') },
    @{ Name = 'mm_armsrace_restrictions'; Source = (Join-Path $repoRoot 'src\amxmodx\mm_armsrace_restrictions.sma') },
    @{ Name = 'mm_awponly'; Source = (Join-Path $repoRoot 'src\amxmodx\mm_awponly.sma') }
    @{ Name = 'mm_he_battle'; Source = (Join-Path $repoRoot 'src\amxmodx\mm_he_battle.sma') }
    @{ Name = 'mm_arcade_protection'; Source = (Join-Path $repoRoot 'src\amxmodx\mm_arcade_protection.sma') }
    @{ Name = 'mm_knife'; Source = (Join-Path $repoRoot 'src\amxmodx\mm_knife.sma') }
    @{ Name = 'mm_football'; Source = (Join-Path $repoRoot 'src\amxmodx\mm_football.sma') }
    @{ Name = 'mm_mode_maps'; Source = (Join-Path $repoRoot 'src\amxmodx\mm_mode_maps.sma') }
    @{ Name = 'mm_voting'; Source = (Join-Path $repoRoot 'src\amxmodx\mm_voting.sma') }
    @{ Name = 'mm_admin'; Source = (Join-Path $repoRoot 'src\amxmodx\mm_admin.sma') }
    @{ Name = 'mm_warmup_money'; Source = (Join-Path $repoRoot 'src\amxmodx\mm_warmup_money.sma') }
    @{ Name = 'mm_random_spawns'; Source = (Join-Path $repoRoot 'src\amxmodx\mm_random_spawns.sma') }
    @{ Name = 'mm_weapon_tuning'; Source = (Join-Path $repoRoot 'src\amxmodx\mm_weapon_tuning.sma') }
    @{ Name = 'mm_crosshair'; Source = (Join-Path $repoRoot 'src\amxmodx\mm_crosshair.sma') }
)

if (-not (Test-Path -LiteralPath $compiler)) { throw "AMX Mod X compiler not found: $compiler. Run install-addons.ps1 first." }
New-Item -ItemType Directory -Path $pluginDir -Force | Out-Null
New-Item -ItemType Directory -Path $modeConfigDestination -Force | Out-Null
New-Item -ItemType Directory -Path $votingMapDestination -Force | Out-Null
New-Item -ItemType Directory -Path $crosshairResourceDestination -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $ServerDir 'cstrike\addons\amxmodx\configs\mm_football') -Force | Out-Null
Get-ChildItem -LiteralPath (Join-Path $repoRoot 'config\cstrike\addons\amxmodx\configs\mm_football') -Filter '*.ini' -File |
    Copy-Item -Destination (Join-Path $ServerDir 'cstrike\addons\amxmodx\configs\mm_football') -Force
Get-ChildItem -LiteralPath $modeConfigSource -Filter '*.cfg' -File | Copy-Item -Destination $modeConfigDestination -Force
Get-ChildItem -LiteralPath $votingMapSource -Filter '*.ini' -File | Copy-Item -Destination $votingMapDestination -Force
Copy-Item -LiteralPath $classicConfigSource -Destination $classicConfigDestination -Force
Copy-Item -LiteralPath $weaponTuningConfigSource -Destination $weaponTuningConfigDestination -Force
Copy-Item -LiteralPath $votingConfigSource -Destination $votingConfigDestination -Force
Copy-Item -LiteralPath $rulesSource -Destination $rulesDestination -Force
Get-ChildItem -LiteralPath $crosshairResourceSource -Filter 'mm_xh_v*' -File |
    Where-Object { $_.Extension -in @('.spr', '.txt') } |
    Copy-Item -Destination $crosshairResourceDestination -Force

foreach ($plugin in $plugins) {
    if (-not (Test-Path -LiteralPath $plugin.Source -PathType Leaf)) { throw "Pawn source not found: $($plugin.Source)" }

    $output = Join-Path $pluginDir ($plugin.Name + '.amxx')
    & $compiler $plugin.Source "-i$includeDir" "-o$output"
    $compilerExitCode = $LASTEXITCODE
    $outputExists = Test-Path -LiteralPath $output -PathType Leaf

    if ($compilerExitCode -ne 0) {
        throw "Pawn compiler failed for $($plugin.Name) with exit code $compilerExitCode."
    }
    if (-not $outputExists) {
        throw "Pawn compiler exited successfully, but the expected output file was not created: $output"
    }

    Write-Host "Built and enabled $output"
}

$existingConfig = Get-Content -LiteralPath $pluginsIni | Where-Object {
    $_ -notmatch '^\s*mm_extendmap\.amxx(?:\s|$)' -and
    $_ -notmatch '^\s*mm_chat_style\.amxx(?:\s|$)' -and
    $_ -notmatch '^\s*mm_(?:core|mode_manager|arcade_rounds|modes|settings|classic|deathmatch|armsrace|armsrace_restrictions|awponly|he_battle|arcade_protection|knife|football|mode_maps|voting|admin|warmup_money|random_spawns|weapon_tuning|crosshair)\.amxx(?:\s|$)' -and
    $_ -notmatch '^\s*;?\s*(?:mapchooser|nextmap|adminvote|mapsmenu)\.amxx(?:\s|$)' -and
    $_ -ne '; Multi-Mode Network' -and
    $_ -ne '; Stock voting disabled: mm_voting owns map and mode decisions'
}
Set-Content -LiteralPath $pluginsIni -Encoding ASCII -Value $existingConfig
Add-Content -LiteralPath $pluginsIni -Encoding ASCII -Value 'mm_extendmap.amxx'
Add-Content -LiteralPath $pluginsIni -Encoding ASCII -Value 'mm_chat_style.amxx'
Add-Content -LiteralPath $pluginsIni -Encoding ASCII -Value @('', '; Stock voting disabled: mm_voting owns map and mode decisions', '; mapchooser.amxx', '; nextmap.amxx', '; adminvote.amxx', '; mapsmenu.amxx', '', '; Multi-Mode Network', 'mm_core.amxx', 'mm_mode_manager.amxx', 'mm_arcade_rounds.amxx', 'mm_modes.amxx', 'mm_settings.amxx', 'mm_classic.amxx', 'mm_deathmatch.amxx', 'mm_armsrace.amxx', 'mm_armsrace_restrictions.amxx', 'mm_awponly.amxx', 'mm_he_battle.amxx', 'mm_arcade_protection.amxx', 'mm_knife.amxx', 'mm_football.amxx', 'mm_mode_maps.amxx', 'mm_voting.amxx', 'mm_admin.amxx', 'mm_warmup_money.amxx', 'mm_random_spawns.amxx', 'mm_weapon_tuning.amxx', 'mm_crosshair.amxx')

