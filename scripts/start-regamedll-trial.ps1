[CmdletBinding()]
param(
    [string]$TrialDir = (Join-Path $PSScriptRoot '..\runtime\hlds-regamedll-trial'),
    [string]$StateDir = (Join-Path $PSScriptRoot '..\.regamedll-trial'),
    [string]$Map = 'de_dust2',
    [int]$Port = 27016,
    [int]$MaxPlayers = 12
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib\regamedll-trial-common.ps1')

if ($Port -eq 27015) { throw 'Port 27015 is reserved for the production server. Use the isolated default 27016.' }
if ($Port -lt 1 -or $Port -gt 65535) { throw 'Port must be between 1 and 65535.' }
if ($MaxPlayers -lt 1 -or $MaxPlayers -gt 12) { throw 'MaxPlayers must be between 1 and 12.' }
if ($Map -notmatch '^[A-Za-z0-9_-]+$') { throw 'Map may contain only letters, numbers, underscores, and hyphens.' }
if (Get-NetUDPEndpoint -LocalPort $Port -ErrorAction SilentlyContinue) { throw "UDP port $Port is already in use." }
if (Get-NetTCPConnection -LocalPort $Port -ErrorAction SilentlyContinue) { throw "TCP port $Port is already in use." }

$TrialDir = Get-MmFullPath $TrialDir
$StateDir = Get-MmFullPath $StateDir
$manifest = Read-MmTrialManifest -StateDir $StateDir
Assert-MmManifestPaths -Manifest $manifest -TrialDir $TrialDir -StateDir $StateDir
Assert-MmProductionUnchanged -Manifest $manifest

$installPath = Join-Path $StateDir 'install.json'
if (-not (Test-Path -LiteralPath $installPath -PathType Leaf)) { throw 'ReGameDLL install record is missing. Run install-regamedll-trial.ps1 first.' }
$install = Get-Content -LiteralPath $installPath -Raw | ConvertFrom-Json
if ($install.Status -ne 'installed') { throw "Trial install status is '$($install.Status)', not 'installed'." }

$hlds = Join-Path $TrialDir 'hlds.exe'
$trialGameDll = Join-Path $TrialDir 'cstrike\dlls\mp.dll'
if ((Get-MmSha256 $trialGameDll) -ne $install.InstalledGameDllSha256) { throw 'Trial GameDLL hash does not match the install record.' }

$pidFile = Get-MmTrialPidPath -StateDir $StateDir
if (Test-Path -LiteralPath $pidFile) { throw "Trial PID file already exists: $pidFile" }
Assert-MmServerStopped -ServerDir $TrialDir

$logDir = Join-Path $StateDir 'logs'
New-Item -ItemType Directory -Path $logDir -Force | Out-Null
$consoleLog = Join-Path $TrialDir 'qconsole.log'
if (Test-Path -LiteralPath $consoleLog -PathType Leaf) {
    $archivedConsoleLog = Join-Path $logDir ("qconsole-{0}-{1}.log" -f (Get-Date -Format 'yyyyMMdd-HHmmss'), [guid]::NewGuid().ToString('N').Substring(0, 8))
    Move-Item -LiteralPath $consoleLog -Destination $archivedConsoleLog
}
$arguments = @('-console', '-condebug', '-insecure', '-nomaster', '-game', 'cstrike', '+sv_lan', '1', '+ip', '0.0.0.0', '+port', $Port, '+maxplayers', $MaxPlayers, '+exec', 'mm_regamedll_trial.cfg', '+map', $Map)
$commandLine = 'hlds.exe ' + ($arguments -join ' ')
$wrapper = Start-Process -FilePath 'cmd.exe' -ArgumentList @('/d', '/c', $commandLine) -WorkingDirectory $TrialDir -WindowStyle Hidden -PassThru

$hldsProcess = $null
for ($attempt = 1; $attempt -le 50 -and $null -eq $hldsProcess; $attempt++) {
    Start-Sleep -Milliseconds 200
    $candidate = Get-CimInstance Win32_Process -Filter "Name='hlds.exe'" -ErrorAction SilentlyContinue |
        Where-Object { $_.ParentProcessId -eq $wrapper.Id -and $_.ExecutablePath -and [string]::Equals((Get-MmFullPath $_.ExecutablePath), (Get-MmFullPath $hlds), [StringComparison]::OrdinalIgnoreCase) } |
        Select-Object -First 1
    if ($candidate) { $hldsProcess = Get-Process -Id $candidate.ProcessId -ErrorAction SilentlyContinue }
    if ($wrapper.HasExited -and $null -eq $hldsProcess) { break }
}
if ($null -eq $hldsProcess) { throw 'Isolated HLDS did not enter console mode.' }

$pidRecord = [ordered]@{
    Pid = $hldsProcess.Id
    Executable = Get-MmFullPath $hlds
    Port = $Port
    Map = $Map
    StartedUtc = [DateTime]::UtcNow.ToString('o')
    ConsoleLog = $consoleLog
    GameLogDirectory = (Join-Path $TrialDir 'cstrike\logs')
}
$pidRecord | ConvertTo-Json | Set-Content -LiteralPath $pidFile -Encoding UTF8
Write-Host "Started isolated ReGameDLL trial (PID $($hldsProcess.Id)) on port $Port."
Write-Host "Console log: $($pidRecord.ConsoleLog)"
