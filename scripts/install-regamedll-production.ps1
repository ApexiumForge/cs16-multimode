[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$MigrationId,
    [string]$ProductionDir = (Join-Path $PSScriptRoot '..\runtime\hlds-steam-legacy'),
    [string]$TrialDir = (Join-Path $PSScriptRoot '..\runtime\hlds-regamedll-trial'),
    [string]$StateDir = (Join-Path $PSScriptRoot '..\.regamedll-production')
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib\regamedll-production-common.ps1')

$RepoRoot = Get-MmFullPath (Join-Path $PSScriptRoot '..')
$ProductionDir = Get-MmFullPath $ProductionDir
$TrialDir = Get-MmFullPath $TrialDir
$StateDir = Get-MmFullPath $StateDir
$manifest = Read-MmProductionManifest -StateDir $StateDir -MigrationId $MigrationId
Assert-MmManifestBinding -Manifest $manifest -ProductionDir $ProductionDir -TrialDir $TrialDir -RepoRoot $RepoRoot
if ($manifest.Status -ne 'prepared') { throw "Migration must be prepared before installation; current status: $($manifest.Status)" }
Assert-MmServerStopped -ServerDir $ProductionDir
Assert-MmFilesMatchRecords -Root $ProductionDir -Records $manifest.BackupFiles -Context 'Production target'
Assert-MmFilesMatchRecords -Root $ProductionDir -Records $manifest.PreservedFiles -Context 'Preserved production file'

$targets = @(Get-MmManagedTargetFiles -RepoRoot $RepoRoot -TrialDir $TrialDir)
foreach ($sourceRecord in $manifest.SourceFiles) {
    $target = $targets | Where-Object { $_.RelativePath -eq $sourceRecord.RelativePath } | Select-Object -First 1
    if (-not $target -or (Get-MmSha256 $target.Source) -ne $sourceRecord.Sha256) {
        throw "Migration source changed after backup: $($sourceRecord.RelativePath)"
    }
}

$manifest.Status = 'installing'
$manifest | Add-Member -NotePropertyName InstallStartedUtc -NotePropertyValue ([DateTime]::UtcNow.ToString('o'))
Write-MmProductionManifest -Manifest $manifest -StateDir $StateDir -MigrationId $MigrationId

foreach ($target in $targets | Where-Object { $_.Source }) {
    $destination = Join-Path $ProductionDir $target.RelativePath
    New-Item -ItemType Directory -Path (Split-Path $destination -Parent) -Force | Out-Null
    Copy-Item -LiteralPath $target.Source -Destination $destination -Force
    $expected = ($manifest.SourceFiles | Where-Object { $_.RelativePath -eq $target.RelativePath } | Select-Object -First 1).Sha256
    if ((Get-MmSha256 $destination) -ne $expected) { throw "Installed file failed verification: $($target.RelativePath)" }
}

$pluginsIni = Join-Path $ProductionDir 'cstrike\addons\amxmodx\configs\plugins.ini'
$pluginContent = Get-MmProductionPluginsIniContent -PluginsIni $pluginsIni
Set-Content -LiteralPath $pluginsIni -Value $pluginContent -Encoding ASCII
foreach ($name in $script:MmManagedPlugins) {
    if (-not (Test-MmPluginRegistration -PluginsIni $pluginsIni -PluginName $name)) { throw "Managed plugin was not enabled: $name.amxx" }
}
foreach ($name in $script:MmObsoleteDevelopmentPlugins) {
    if (Test-MmPluginRegistration -PluginsIni $pluginsIni -PluginName $name) { throw "Obsolete development plugin remains enabled: $name.amxx" }
}
Assert-MmFilesMatchRecords -Root $ProductionDir -Records $manifest.PreservedFiles -Context 'Preserved production file'

$installedRecords = foreach ($record in $manifest.BackupFiles) {
    Get-MmFileRecord -Root $ProductionDir -RelativePath $record.RelativePath
}
$manifest | Add-Member -NotePropertyName InstalledFiles -NotePropertyValue @($installedRecords)
$manifest | Add-Member -NotePropertyName InstalledUtc -NotePropertyValue ([DateTime]::UtcNow.ToString('o'))
$manifest.Status = 'installed'
Write-MmProductionManifest -Manifest $manifest -StateDir $StateDir -MigrationId $MigrationId

Write-Host "Installed verified ReGameDLL_CS $($manifest.ReGameDllVersion) and the eight managed plugins into production."
Write-Host 'Metamod-P, YaPB, admin configuration, server.cfg, and unrelated AMX Mod X registrations were preserved.'
Write-Host 'No runtime test was performed. Follow docs/REGAMEDLL_PRODUCTION.md before declaring the migration successful.'
