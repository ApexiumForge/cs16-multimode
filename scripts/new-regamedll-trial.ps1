[CmdletBinding()]
param(
    [string]$SourceDir = (Join-Path $PSScriptRoot '..\runtime\hlds-steam-legacy'),
    [string]$TrialDir = (Join-Path $PSScriptRoot '..\runtime\hlds-regamedll-trial'),
    [string]$StateDir = (Join-Path $PSScriptRoot '..\.regamedll-trial')
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib\regamedll-trial-common.ps1')

$repoRoot = Get-MmFullPath (Join-Path $PSScriptRoot '..')
$runtimeRoot = Get-MmFullPath (Join-Path $repoRoot 'runtime')
$SourceDir = Get-MmFullPath $SourceDir
$TrialDir = Get-MmFullPath $TrialDir
$StateDir = Get-MmFullPath $StateDir

Assert-MmDifferentPath -First $SourceDir -Second $TrialDir -Message 'TrialDir must not be the production SourceDir.'
Assert-MmDifferentPath -First $SourceDir -Second $StateDir -Message 'StateDir must not be the production SourceDir.'
Assert-MmDifferentPath -First $TrialDir -Second $StateDir -Message 'StateDir must not be the trial runtime directory.'
Assert-MmPathOutside -Path $TrialDir -Root $SourceDir -Message 'TrialDir must not be inside the production SourceDir.'
Assert-MmPathOutside -Path $StateDir -Root $SourceDir -Message 'StateDir must not be inside the production SourceDir.'
Assert-MmPathOutside -Path $StateDir -Root $TrialDir -Message 'StateDir must not be inside the trial runtime.'
Assert-MmPathWithin -Path $TrialDir -Root $runtimeRoot -Message "TrialDir must be a child of the project runtime directory: $runtimeRoot"
Assert-MmPathWithin -Path $StateDir -Root $repoRoot -Message "StateDir must be inside the project repository: $repoRoot"

if (-not (Test-Path -LiteralPath (Join-Path $SourceDir 'hlds.exe') -PathType Leaf)) { throw "Production hlds.exe is missing: $SourceDir" }
if (-not (Test-Path -LiteralPath (Join-Path $SourceDir 'cstrike\dlls\mp.dll') -PathType Leaf)) { throw "Production GameDLL is missing: $SourceDir" }
if (Test-Path -LiteralPath $TrialDir) { throw "TrialDir already exists; refusing to merge or overwrite it: $TrialDir" }
if (Test-Path -LiteralPath $StateDir) { throw "StateDir already exists; refusing to merge or overwrite it: $StateDir" }

$requiredSourceFiles = @(
    'hlds.exe',
    'cstrike\dlls\mp.dll',
    'cstrike\liblist.gam',
    'cstrike\addons\metamod\plugins.ini',
    'cstrike\addons\amxmodx\configs\plugins.ini',
    'cstrike\server.cfg'
)
foreach ($relativePath in $requiredSourceFiles) {
    if (-not (Test-Path -LiteralPath (Join-Path $SourceDir $relativePath) -PathType Leaf)) {
        throw "Required production file is missing: $relativePath"
    }
}
$trialConfigSource = Join-Path $repoRoot 'config\dev\mm_regamedll_trial.cfg'
if (-not (Test-Path -LiteralPath $trialConfigSource -PathType Leaf)) { throw "Trial configuration template is missing: $trialConfigSource" }

Assert-MmServerStopped -ServerDir $SourceDir

$sourceGameDll = Join-Path $SourceDir 'cstrike\dlls\mp.dll'
$sourceGameDllHash = Get-MmSha256 $sourceGameDll

Copy-Item -LiteralPath $SourceDir -Destination $TrialDir -Recurse
New-Item -ItemType Directory -Path $StateDir | Out-Null
$backupRoot = Join-Path $StateDir 'backup'
New-Item -ItemType Directory -Path $backupRoot | Out-Null

$gameDllFiles = @(
    'cstrike\dlls\mp.dll',
    'cstrike\game.cfg',
    'cstrike\game_init.cfg',
    'cstrike\delta.lst'
)
$backupRecords = foreach ($relativePath in $gameDllFiles) {
    $trialFile = Join-Path $TrialDir $relativePath
    $backupFile = Join-Path $backupRoot $relativePath
    $exists = Test-Path -LiteralPath $trialFile -PathType Leaf
    $hash = $null
    if ($exists) {
        New-Item -ItemType Directory -Path (Split-Path $backupFile -Parent) -Force | Out-Null
        Copy-Item -LiteralPath $trialFile -Destination $backupFile
        $hash = Get-MmSha256 $trialFile
        if ((Get-MmSha256 $backupFile) -ne $hash) { throw "Backup verification failed: $relativePath" }
    }
    [pscustomobject]@{ RelativePath = $relativePath; Existed = $exists; Sha256 = $hash }
}

$preservedFiles = @(
    'hlds.exe',
    'cstrike\liblist.gam',
    'cstrike\addons\metamod\plugins.ini',
    'cstrike\addons\amxmodx\configs\plugins.ini',
    'cstrike\server.cfg'
)
$preservedRecords = foreach ($relativePath in $preservedFiles) {
    $sourceFile = Join-Path $SourceDir $relativePath
    $trialFile = Join-Path $TrialDir $relativePath
    if (-not (Test-Path -LiteralPath $sourceFile -PathType Leaf)) { throw "Required production file is missing: $relativePath" }
    $sourceHash = Get-MmSha256 $sourceFile
    if ((Get-MmSha256 $trialFile) -ne $sourceHash) { throw "Clone verification failed: $relativePath" }
    [pscustomobject]@{ RelativePath = $relativePath; Sha256 = $sourceHash }
}

$trialConfigDestination = Join-Path $TrialDir 'cstrike\mm_regamedll_trial.cfg'
Copy-Item -LiteralPath $trialConfigSource -Destination $trialConfigDestination

$manifest = [ordered]@{
    SchemaVersion = 1
    CreatedUtc = [DateTime]::UtcNow.ToString('o')
    SourceDir = $SourceDir
    TrialDir = $TrialDir
    StateDir = $StateDir
    SourceGameDllSha256 = $sourceGameDllHash
    BackupFiles = @($backupRecords)
    PreservedFiles = @($preservedRecords)
}
$manifest | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $StateDir 'manifest.json') -Encoding UTF8

Assert-MmProductionUnchanged -Manifest ([pscustomobject]$manifest)
Write-Host "Created isolated trial clone: $TrialDir"
Write-Host "Verified GameDLL backup: $backupRoot"
Write-Host 'Production runtime was read only and remains unchanged.'
