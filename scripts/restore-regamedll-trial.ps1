[CmdletBinding()]
param(
    [string]$TrialDir = (Join-Path $PSScriptRoot '..\runtime\hlds-regamedll-trial'),
    [string]$StateDir = (Join-Path $PSScriptRoot '..\.regamedll-trial')
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib\regamedll-trial-common.ps1')

$TrialDir = Get-MmFullPath $TrialDir
$StateDir = Get-MmFullPath $StateDir
$manifest = Read-MmTrialManifest -StateDir $StateDir
Assert-MmManifestPaths -Manifest $manifest -TrialDir $TrialDir -StateDir $StateDir
Assert-MmProductionUnchanged -Manifest $manifest
Assert-MmServerStopped -ServerDir $TrialDir

$pidFile = Get-MmTrialPidPath -StateDir $StateDir
if (Test-Path -LiteralPath $pidFile) { throw 'Trial PID record exists. Run stop-regamedll-trial.ps1 and verify status before rollback.' }

$backupRoot = Join-Path $StateDir 'backup'
foreach ($record in $manifest.BackupFiles) {
    $destination = Join-Path $TrialDir $record.RelativePath
    Assert-MmPathWithin -Path $destination -Root $TrialDir -Message 'Rollback target escaped TrialDir.'
    if ($record.Existed) {
        $backupFile = Join-Path $backupRoot $record.RelativePath
        if ((Get-MmSha256 $backupFile) -ne $record.Sha256) { throw "Backup hash verification failed: $($record.RelativePath)" }
        Copy-Item -LiteralPath $backupFile -Destination $destination -Force
        if ((Get-MmSha256 $destination) -ne $record.Sha256) { throw "Rollback verification failed: $($record.RelativePath)" }
    } elseif (Test-Path -LiteralPath $destination -PathType Leaf) {
        Remove-Item -LiteralPath $destination
    }
}

$rollbackRecord = [ordered]@{
    RolledBackUtc = [DateTime]::UtcNow.ToString('o')
    RestoredGameDllSha256 = Get-MmSha256 (Join-Path $TrialDir 'cstrike\dlls\mp.dll')
    Status = 'rolled back'
}
$rollbackRecord | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $StateDir 'rollback.json') -Encoding UTF8

$installPath = Join-Path $StateDir 'install.json'
if (Test-Path -LiteralPath $installPath -PathType Leaf) {
    $install = Get-Content -LiteralPath $installPath -Raw | ConvertFrom-Json
    $install.Status = 'rolled back'
    $install | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $installPath -Encoding UTF8
}

Assert-MmProductionUnchanged -Manifest $manifest
Write-Host 'Restored the isolated clone GameDLL/config files from the verified backup.'
Write-Host 'Production runtime was not modified.'
