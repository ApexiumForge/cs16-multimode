[CmdletBinding()]
param(
    [string]$ServerDir = (Join-Path $PSScriptRoot '..\runtime\hlds-steam-legacy'),
    [string]$Map = 'de_dust2',
    [int]$Port = 27015,
    [int]$MaxPlayers = 12
)

$ErrorActionPreference = 'Stop'
if ($MaxPlayers -lt 1 -or $MaxPlayers -gt 12) { throw 'MaxPlayers must be between 1 and 12 for the Phase 1 baseline.' }
if ($Port -lt 1 -or $Port -gt 65535) { throw 'Port must be between 1 and 65535.' }
if ($Map -notmatch '^[A-Za-z0-9_-]+$') { throw 'Map may contain only letters, numbers, underscores, and hyphens.' }
$ServerDir = [IO.Path]::GetFullPath($ServerDir)
$hlds = Join-Path $ServerDir 'hlds.exe'
$stateDir = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\.runtime'))
$pidFile = Join-Path $stateDir 'hlds.pid'
if (-not (Test-Path -LiteralPath $hlds)) { throw "hlds.exe not found at $hlds. Run install-server.ps1 first." }
if (Test-Path -LiteralPath $pidFile) { throw "PID file already exists: $pidFile. Stop the existing project server or remove a confirmed stale PID file." }

New-Item -ItemType Directory -Path $stateDir -Force | Out-Null
$arguments = @('-console', '-insecure', '-nomaster', '-game', 'cstrike', '-port', $Port, '+sv_lan', '1', '+ip', '0.0.0.0', '+maxplayers', $MaxPlayers, '+map', $Map)

# The legacy Windows launcher opens its GUI instead of server console mode when
# it has no inherited console. cmd.exe supplies that console and remains the
# parent while HLDS runs. Record the child HLDS PID, not the wrapper PID.
$commandLine = 'hlds.exe ' + ($arguments -join ' ')
$wrapper = Start-Process -FilePath 'cmd.exe' -ArgumentList @('/d', '/c', $commandLine) -WorkingDirectory $ServerDir -PassThru
$hldsProcess = $null
for ($attempt = 1; $attempt -le 50 -and $null -eq $hldsProcess; $attempt++) {
    Start-Sleep -Milliseconds 200
    $candidate = Get-CimInstance Win32_Process -Filter "Name='hlds.exe'" -ErrorAction SilentlyContinue |
        Where-Object { $_.ParentProcessId -eq $wrapper.Id -and $_.ExecutablePath -and [IO.Path]::GetFullPath($_.ExecutablePath) -eq $hlds } |
        Select-Object -First 1
    if ($candidate) { $hldsProcess = Get-Process -Id $candidate.ProcessId -ErrorAction SilentlyContinue }
    if ($wrapper.HasExited -and $null -eq $hldsProcess) { break }
}
if ($null -eq $hldsProcess) { throw "HLDS did not enter console mode. cmd.exe exit state: $($wrapper.HasExited)." }

Set-Content -LiteralPath $pidFile -Encoding ASCII -Value $hldsProcess.Id
Write-Host "Started Multi-Mode Network (PID $($hldsProcess.Id)) on port $Port with map $Map."

