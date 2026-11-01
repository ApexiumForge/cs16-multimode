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
$pidFile = Get-MmTrialPidPath -StateDir $StateDir
if (-not (Test-Path -LiteralPath $pidFile -PathType Leaf)) { throw 'No isolated trial PID file exists.' }

$record = Get-Content -LiteralPath $pidFile -Raw | ConvertFrom-Json
$expectedExe = Get-MmFullPath (Join-Path $TrialDir 'hlds.exe')
if (-not [string]::Equals((Get-MmFullPath $record.Executable), $expectedExe, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'PID record executable does not belong to the isolated trial.'
}

$process = Get-Process -Id ([int]$record.Pid) -ErrorAction SilentlyContinue
if ($null -eq $process) {
    Remove-Item -LiteralPath $pidFile
    Write-Host 'Removed stale isolated trial PID record; no process was stopped.'
    exit 0
}
if (-not [string]::Equals((Get-MmFullPath $process.Path), $expectedExe, [StringComparison]::OrdinalIgnoreCase)) {
    throw "PID $($record.Pid) is not the isolated HLDS process. Refusing to stop it."
}

Stop-Process -Id $process.Id
$process.WaitForExit(10000) | Out-Null
if (-not $process.HasExited) { throw 'Isolated HLDS did not exit within 10 seconds; inspect it before taking forceful action.' }
Remove-Item -LiteralPath $pidFile
Write-Host "Stopped isolated ReGameDLL trial PID $($process.Id)."
