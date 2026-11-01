[CmdletBinding()]
param(
    [string]$ProductionDir = (Join-Path $PSScriptRoot '..\runtime\hlds-steam-legacy'),
    [string]$TrialDir = (Join-Path $PSScriptRoot '..\runtime\hlds-regamedll-trial'),
    [string]$TrialStateDir = (Join-Path $PSScriptRoot '..\.regamedll-trial'),
    [string]$StateDir = (Join-Path $PSScriptRoot '..\.regamedll-production')
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib\regamedll-production-common.ps1')

$RepoRoot = Get-MmFullPath (Join-Path $PSScriptRoot '..')
$ProductionDir = Get-MmFullPath $ProductionDir
$TrialDir = Get-MmFullPath $TrialDir
$TrialStateDir = Get-MmFullPath $TrialStateDir
$StateDir = Get-MmFullPath $StateDir
Assert-MmDifferentPath -First $ProductionDir -Second $TrialDir -Message 'Production and trial paths must be different.'
Assert-MmPathOutside -Path $StateDir -Root $ProductionDir -Message 'Migration state must remain outside the production runtime.'
Assert-MmServerStopped -ServerDir $ProductionDir
$install = Read-MmValidatedTrialInstall -TrialDir $TrialDir -TrialStateDir $TrialStateDir

$requiredProductionFiles = @('hlds.exe', 'cstrike\dlls\mp.dll', 'cstrike\liblist.gam', 'cstrike\addons\metamod\plugins.ini', 'cstrike\addons\amxmodx\configs\plugins.ini')
foreach ($relativePath in $requiredProductionFiles) {
    $path = Join-Path $ProductionDir $relativePath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Production prerequisite is missing: $path" }
}

$existingInstalledManifest = Get-ChildItem -LiteralPath $StateDir -Filter manifest.json -File -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
    Get-Content -LiteralPath $_.FullName -Raw | ConvertFrom-Json
} | Where-Object { $_.Status -in @('installing', 'installed') } | Select-Object -First 1
if ($existingInstalledManifest) { throw "An active production migration already exists: $($existingInstalledManifest.MigrationId) ($($existingInstalledManifest.Status))" }
if ((Get-MmSha256 (Join-Path $ProductionDir 'cstrike\dlls\mp.dll')) -eq $install.InstalledGameDllSha256) {
    throw 'Production already contains the validated ReGameDLL GameDLL. Refusing to create a misleading pre-migration backup.'
}

$migrationId = Get-Date -Format 'yyyyMMdd-HHmmss'
$migrationDir = Get-MmProductionMigrationDir -StateDir $StateDir -MigrationId $migrationId
if (Test-Path -LiteralPath $migrationDir) { throw "Migration state already exists: $migrationDir" }
$backupDir = Join-Path $migrationDir 'backup'
New-Item -ItemType Directory -Path $backupDir -Force | Out-Null

$targets = @(Get-MmManagedTargetFiles -RepoRoot $RepoRoot -TrialDir $TrialDir)
$backupRecords = foreach ($target in $targets) {
    $record = Get-MmFileRecord -Root $ProductionDir -RelativePath $target.RelativePath
    if ($record.Existed) {
        $source = Join-Path $ProductionDir $target.RelativePath
        $backup = Join-Path $backupDir $target.RelativePath
        New-Item -ItemType Directory -Path (Split-Path $backup -Parent) -Force | Out-Null
        Copy-Item -LiteralPath $source -Destination $backup
        if ((Get-MmSha256 $backup) -ne $record.Sha256) { throw "Backup verification failed: $($target.RelativePath)" }
    }
    $record
}

$preservedRecords = foreach ($relativePath in $script:MmPreservedFiles) {
    Get-MmFileRecord -Root $ProductionDir -RelativePath $relativePath
}

$sourceRecords = foreach ($target in $targets | Where-Object { $_.Source }) {
    if (-not (Test-Path -LiteralPath $target.Source -PathType Leaf)) { throw "Migration source is missing: $($target.Source)" }
    [pscustomobject]@{ RelativePath = $target.RelativePath; Sha256 = Get-MmSha256 $target.Source; Kind = $target.Kind }
}

$manifest = [ordered]@{
    SchemaVersion = 1
    MigrationId = $migrationId
    CreatedUtc = [DateTime]::UtcNow.ToString('o')
    Status = 'prepared'
    RepoRoot = $RepoRoot
    ProductionDir = $ProductionDir
    ProductionPort = 27015
    TrialDir = $TrialDir
    TrialPort = 27016
    TrialStateDir = $TrialStateDir
    ReGameDllVersion = $install.Version
    ArchiveSha256 = $install.ArchiveSha256
    SignatureSha256 = $install.SignatureSha256
    InstalledGameDllSha256 = $install.InstalledGameDllSha256
    BackupFiles = @($backupRecords)
    PreservedFiles = @($preservedRecords)
    SourceFiles = @($sourceRecords)
}
Write-MmProductionManifest -Manifest $manifest -StateDir $StateDir -MigrationId $migrationId

Write-Host "Verified production backup prepared: $migrationId"
Write-Host "Manifest: $(Join-Path $migrationDir 'manifest.json')"
Write-Host 'No production file was changed.'
