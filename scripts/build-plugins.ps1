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
$plugins = @(
    @{ Name = 'mm_core'; Source = (Join-Path $repoRoot 'src\amxmodx\mm_core.sma') },
    @{ Name = 'mm_mode_manager'; Source = (Join-Path $repoRoot 'src\amxmodx\mm_mode_manager.sma') },
    @{ Name = 'mm_arcade_rounds'; Source = (Join-Path $repoRoot 'src\amxmodx\mm_arcade_rounds.sma') },
    @{ Name = 'mm_modes'; Source = (Join-Path $repoRoot 'src\amxmodx\mm_modes.sma') },
    @{ Name = 'mm_classic'; Source = (Join-Path $repoRoot 'src\amxmodx\mm_classic.sma') },
    @{ Name = 'mm_deathmatch'; Source = (Join-Path $repoRoot 'src\amxmodx\mm_deathmatch.sma') },
    @{ Name = 'mm_armsrace'; Source = (Join-Path $repoRoot 'src\amxmodx\mm_armsrace.sma') },
    @{ Name = 'mm_awponly'; Source = (Join-Path $repoRoot 'src\amxmodx\mm_awponly.sma') }
)

if (-not (Test-Path -LiteralPath $compiler)) { throw "AMX Mod X compiler not found: $compiler. Run install-addons.ps1 first." }
New-Item -ItemType Directory -Path $pluginDir -Force | Out-Null
New-Item -ItemType Directory -Path $modeConfigDestination -Force | Out-Null
Get-ChildItem -LiteralPath $modeConfigSource -Filter '*.cfg' -File | Copy-Item -Destination $modeConfigDestination -Force
Copy-Item -LiteralPath $classicConfigSource -Destination $classicConfigDestination -Force

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
    $_ -notmatch '^\s*mm_(?:core|mode_manager|arcade_rounds|modes|classic|deathmatch|armsrace|awponly)\.amxx(?:\s|$)' -and $_ -ne '; Multi-Mode Network'
}
Set-Content -LiteralPath $pluginsIni -Encoding ASCII -Value $existingConfig
Add-Content -LiteralPath $pluginsIni -Encoding ASCII -Value @('', '; Multi-Mode Network', 'mm_core.amxx', 'mm_mode_manager.amxx', 'mm_arcade_rounds.amxx', 'mm_modes.amxx', 'mm_classic.amxx', 'mm_deathmatch.amxx', 'mm_armsrace.amxx', 'mm_awponly.amxx')

