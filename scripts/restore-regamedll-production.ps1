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
if ($manifest.Status -notin @('installing', 'installed')) { throw "Only an installing or installed migration can be rolled back; current status: $($manifest.Status)" }
Assert-MmServerStopped -ServerDir $ProductionDir
if ($manifest.Status -eq 'installed') {
    Assert-MmFilesMatchRecords -Root $ProductionDir -Records $manifest.InstalledFiles -Context 'Installed production file'
}
Assert-MmFilesMatchRecords -Root $ProductionDir -Records $manifest.PreservedFiles -Context 'Preserved production file'

$migrationDir = Get-MmProductionMigrationDir -StateDir $StateDir -MigrationId $MigrationId
$backupDir = Join-Path $migrationDir 'backup'
foreach ($record in $manifest.BackupFiles) {
    $destination = Join-Path $ProductionDir $record.RelativePath
    if ($record.Existed) {
        $backup = Join-Path $backupDir $record.RelativePath
        if ((Get-MmSha256 $backup) -ne $record.Sha256) { throw "Backup failed verification: $($record.RelativePath)" }
        New-Item -ItemType Directory -Path (Split-Path $destination -Parent) -Force | Out-Null
        Copy-Item -LiteralPath $backup -Destination $destination -Force
        if ((Get-MmSha256 $destination) -ne $record.Sha256) { throw "Restored file failed verification: $($record.RelativePath)" }
    } elseif (Test-Path -LiteralPath $destination -PathType Leaf) {
        Assert-MmPathWithin -Path $destination -Root $ProductionDir -Message 'Refusing to remove a file outside production.'
        Remove-Item -LiteralPath $destination -Force
    }
}
Assert-MmFilesMatchRecords -Root $ProductionDir -Records $manifest.BackupFiles -Context 'Restored production file'
Assert-MmFilesMatchRecords -Root $ProductionDir -Records $manifest.PreservedFiles -Context 'Preserved production file'

$manifest | Add-Member -NotePropertyName RolledBackUtc -NotePropertyValue ([DateTime]::UtcNow.ToString('o'))
$manifest.Status = 'rolled_back'
Write-MmProductionManifest -Manifest $manifest -StateDir $StateDir -MigrationId $MigrationId
Write-Host "Rollback verified for migration $MigrationId."
Write-Host 'Files that did not exist before migration were removed only from the production paths recorded in the manifest.'
