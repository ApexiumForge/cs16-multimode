[CmdletBinding()]
param(
    [string]$MigrationId,
    [string]$ProductionDir = (Join-Path $PSScriptRoot '..\runtime\hlds-steam-legacy'),
    [string]$TrialDir = (Join-Path $PSScriptRoot '..\runtime\hlds-regamedll-trial'),
    [string]$StateDir = (Join-Path $PSScriptRoot '..\.regamedll-production')
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib\regamedll-production-common.ps1')

$ProductionDir = Get-MmFullPath $ProductionDir
$TrialDir = Get-MmFullPath $TrialDir
$StateDir = Get-MmFullPath $StateDir
$pluginsIni = Join-Path $ProductionDir 'cstrike\addons\amxmodx\configs\plugins.ini'
$manifests = @(Get-ChildItem -LiteralPath $StateDir -Filter manifest.json -File -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
    Get-Content -LiteralPath $_.FullName -Raw | ConvertFrom-Json
} | Sort-Object CreatedUtc)
if ($MigrationId) { $manifests = @($manifests | Where-Object { $_.MigrationId -eq $MigrationId }) }
$latest = $manifests | Select-Object -Last 1

$gameDll = Join-Path $ProductionDir 'cstrike\dlls\mp.dll'
$gameDllHash = if (Test-Path -LiteralPath $gameDll -PathType Leaf) { Get-MmSha256 $gameDll } else { 'MISSING' }
$classification = if ($gameDllHash -eq '1DE43E39DC9B085D5B0FE7920C520A319A8244532835C9EF7A4F5DA930BACE54') {
    'inspected Valve steam_legacy baseline'
} elseif ($latest -and $gameDllHash -eq $latest.InstalledGameDllSha256) {
    "verified ReGameDLL_CS $($latest.ReGameDllVersion)"
} else {
    'unknown'
}

[pscustomobject]@{
    ProductionDir = $ProductionDir
    ProductionPort = 27015
    TrialDir = $TrialDir
    TrialPort = 27016
    ProductionGameDllSha256 = $gameDllHash
    GameDllClassification = $classification
    LatestMigrationId = if ($latest) { $latest.MigrationId } else { $null }
    LatestMigrationStatus = if ($latest) { $latest.Status } else { 'none' }
    BackupManifestAvailable = $null -ne $latest
    ManagedPluginsEnabled = @($script:MmManagedPlugins | Where-Object { Test-MmPluginRegistration -PluginsIni $pluginsIni -PluginName $_ }).Count
    ObsoleteDevelopmentPluginsEnabled = @($script:MmObsoleteDevelopmentPlugins | Where-Object { Test-MmPluginRegistration -PluginsIni $pluginsIni -PluginName $_ }) -join ', '
} | Format-List

if ($manifests.Count -gt 0) {
    $manifests | Select-Object MigrationId, Status, CreatedUtc, InstalledUtc, RolledBackUtc | Format-Table -AutoSize
}
