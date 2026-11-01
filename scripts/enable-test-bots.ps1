[CmdletBinding()]
param([string]$ServerDir = (Join-Path $PSScriptRoot '..\runtime\hlds-steam-legacy'))

$ErrorActionPreference = 'Stop'
$ServerDir = [IO.Path]::GetFullPath($ServerDir)
$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$pidFile = Join-Path $repoRoot '.runtime\hlds.pid'
if (Test-Path -LiteralPath $pidFile) { throw 'Stop the project HLDS before enabling test bots.' }

$cstrikeDir = Join-Path $ServerDir 'cstrike'
$metaPlugins = Join-Path $cstrikeDir 'addons\metamod\plugins.ini'
$amxxPlugins = Join-Path $cstrikeDir 'addons\amxmodx\configs\plugins.ini'
$serverConfig = Join-Path $cstrikeDir 'server.cfg'
$required = @(
    (Join-Path $cstrikeDir 'addons\yapb\bin\yapb.dll'),
    (Join-Path $cstrikeDir 'addons\amxmodx\plugins\mm_classic_test.amxx'),
    (Join-Path $cstrikeDir 'addons\amxmodx\configs\mm_solo_test.cfg'),
    $metaPlugins, $amxxPlugins, $serverConfig
)
foreach ($path in $required) { if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Required test-bot file is missing: $path" } }

$metaLine = 'win32 addons\yapb\bin\yapb.dll'
$amxxLine = 'mm_classic_test.amxx ; DEVELOPMENT ONLY'
$execLine = 'exec addons/amxmodx/configs/mm_solo_test.cfg // DEVELOPMENT ONLY'

$metaContent = @(Get-Content -LiteralPath $metaPlugins)
if ($metaContent -notcontains $metaLine) { Add-Content -LiteralPath $metaPlugins -Encoding ASCII -Value $metaLine }
$amxxContent = @(Get-Content -LiteralPath $amxxPlugins)
if ($amxxContent -notcontains $amxxLine) { Add-Content -LiteralPath $amxxPlugins -Encoding ASCII -Value $amxxLine }
$serverContent = @(Get-Content -LiteralPath $serverConfig)
if ($serverContent -notcontains $execLine) { Add-Content -LiteralPath $serverConfig -Encoding ASCII -Value $execLine }

Write-Host 'Solo bot testing enabled. Start HLDS normally; no bots are added automatically.'

