[CmdletBinding()]
param([string]$ServerDir = (Join-Path $PSScriptRoot '..\runtime\hlds-steam-legacy'))

$ErrorActionPreference = 'Stop'
$ServerDir = [IO.Path]::GetFullPath($ServerDir)
$expectedExe = [IO.Path]::GetFullPath((Join-Path $ServerDir 'hlds.exe'))
$pidFile = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\.runtime\hlds.pid'))
if (-not (Test-Path -LiteralPath $pidFile)) { throw 'No project PID file exists; the server is not known to be running.' }

$serverPid = [int](Get-Content -LiteralPath $pidFile -Raw)
$process = Get-Process -Id $serverPid -ErrorAction SilentlyContinue
if ($null -eq $process) {
    Remove-Item -LiteralPath $pidFile
    Write-Host 'The recorded process no longer exists; removed the stale PID file.'
    exit 0
}
$actualExe = [IO.Path]::GetFullPath($process.Path)
if ($actualExe -ne $expectedExe) { throw "PID $serverPid is not the project HLDS process ($actualExe). Refusing to stop it." }

Stop-Process -Id $serverPid
$process.WaitForExit(10000) | Out-Null
if (-not $process.HasExited) { throw 'HLDS did not exit within 10 seconds. Inspect it before taking any forceful action.' }
Remove-Item -LiteralPath $pidFile
Write-Host "Stopped HLDS process $serverPid."

