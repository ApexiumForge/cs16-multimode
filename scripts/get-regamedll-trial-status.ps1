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

$installPath = Join-Path $StateDir 'install.json'
$install = if (Test-Path -LiteralPath $installPath -PathType Leaf) { Get-Content -LiteralPath $installPath -Raw | ConvertFrom-Json } else { $null }
$pidFile = Get-MmTrialPidPath -StateDir $StateDir
$pidRecord = if (Test-Path -LiteralPath $pidFile -PathType Leaf) { Get-Content -LiteralPath $pidFile -Raw | ConvertFrom-Json } else { $null }
$running = $false
if ($pidRecord) {
    $process = Get-Process -Id ([int]$pidRecord.Pid) -ErrorAction SilentlyContinue
    $expectedExe = Get-MmFullPath (Join-Path $TrialDir 'hlds.exe')
    $running = $null -ne $process -and [string]::Equals((Get-MmFullPath $process.Path), $expectedExe, [StringComparison]::OrdinalIgnoreCase)
}

$trialGameDll = Join-Path $TrialDir 'cstrike\dlls\mp.dll'
$productionHash = Get-MmSha256 (Join-Path $manifest.SourceDir 'cstrike\dlls\mp.dll')
$trialHash = Get-MmSha256 $trialGameDll

[pscustomobject]@{
    ProductionDir = $manifest.SourceDir
    ProductionGameDllUnchanged = ($productionHash -eq $manifest.SourceGameDllSha256)
    TrialDir = $TrialDir
    TrialGameDllSha256 = $trialHash
    InstalledVersion = if ($install) { $install.Version } else { $null }
    InstallStatus = if ($install) { $install.Status } else { 'not installed' }
    InstalledHashMatches = if ($install -and $install.Status -eq 'installed') { $trialHash -eq $install.InstalledGameDllSha256 } else { $false }
    Running = $running
    Pid = if ($pidRecord) { $pidRecord.Pid } else { $null }
    Port = if ($pidRecord) { $pidRecord.Port } else { $null }
    ConsoleLog = if ($pidRecord) { $pidRecord.ConsoleLog } else { Join-Path $TrialDir 'qconsole.log' }
} | Format-List
