[CmdletBinding()]
param(
    [string]$InstallDir = (Join-Path $PSScriptRoot '..\runtime\hlds-steam-legacy'),
    [string]$SteamCmdDir = (Join-Path $PSScriptRoot '..\downloads\steamcmd'),
    [string]$SteamCmdExecutable
)

$ErrorActionPreference = 'Stop'
$InstallDir = [IO.Path]::GetFullPath($InstallDir)
$SteamCmdDir = [IO.Path]::GetFullPath($SteamCmdDir)
$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$installMarker = Join-Path $InstallDir '.mm-hlds-install'
$appManifest = Join-Path $InstallDir 'steamapps\appmanifest_90.acf'
$requiredFiles = @(
    'hlds.exe',
    'swds.dll',
    'cstrike\liblist.gam',
    'cstrike\dlls\mp.dll'
)

function Test-HldsInstallation {
    param([string]$Root)

    foreach ($relativePath in $requiredFiles) {
        if (-not (Test-Path -LiteralPath (Join-Path $Root $relativePath) -PathType Leaf)) {
            return $false
        }
    }
    return $true
}

if (Test-Path -LiteralPath $InstallDir) {
    $existing = Get-ChildItem -LiteralPath $InstallDir -Force -ErrorAction Stop | Select-Object -First 1
    $manifestIsLegacy = (Test-Path -LiteralPath $appManifest -PathType Leaf) -and
        ((Get-Content -LiteralPath $appManifest -Raw) -match '"BetaKey"\s+"steam_legacy"')
    $markerIsLegacy = (Test-Path -LiteralPath $installMarker -PathType Leaf) -and
        ((Get-Content -LiteralPath $installMarker -Raw) -match '(?m)^Branch=steam_legacy$')
    if ($null -ne $existing -and -not $manifestIsLegacy -and -not $markerIsLegacy) {
        throw "Install target is non-empty and is not a managed steam_legacy installation: $InstallDir. Use a new directory; this script will not mix anniversary and legacy engine files."
    }
} else {
    New-Item -ItemType Directory -Path $InstallDir | Out-Null
}

# The marker permits a later invocation to recover a partial installation made
# by this script, while unrelated non-empty directories remain protected.
if (-not (Test-Path -LiteralPath $installMarker -PathType Leaf)) {
    Set-Content -LiteralPath $installMarker -Encoding ASCII -Value @('Multi-Mode Network managed HLDS installation', 'Branch=steam_legacy')
}

New-Item -ItemType Directory -Path $SteamCmdDir -Force | Out-Null
$steamCmdExe = if ($SteamCmdExecutable) {
    [IO.Path]::GetFullPath($SteamCmdExecutable)
} else {
    Join-Path $SteamCmdDir 'steamcmd.exe'
}
if ($SteamCmdExecutable -and -not (Test-Path -LiteralPath $steamCmdExe -PathType Leaf)) {
    throw "Specified SteamCMD executable not found: $steamCmdExe"
}
if (-not $SteamCmdExecutable -and -not (Test-Path -LiteralPath $steamCmdExe -PathType Leaf)) {
    $steamZip = Join-Path $SteamCmdDir 'steamcmd.zip'
    Write-Host 'Downloading SteamCMD from Valve...'
    Invoke-WebRequest -UseBasicParsing -Uri 'https://steamcdn-a.akamaihd.net/client/installer/steamcmd.zip' -OutFile $steamZip
    Expand-Archive -LiteralPath $steamZip -DestinationPath $SteamCmdDir -Force
}

# Valve app 90 can require repeated update passes before all mod files appear.
$installationConfirmed = $false
$lastSteamExitCode = $null
for ($pass = 1; $pass -le 3; $pass++) {
    Write-Host "Installing HLDS app 90 (pass $pass of 3)..."
    $steamOutput = @(& $steamCmdExe +force_install_dir $InstallDir +login anonymous +app_set_config 90 mod cstrike +app_update 90 -beta steam_legacy validate +quit 2>&1)
    $lastSteamExitCode = $LASTEXITCODE
    $steamOutput | ForEach-Object { Write-Host $_ }

    $steamReportedSuccess = ($steamOutput -join "`n") -match "Success!\s+App\s+'90'\s+fully installed\."
    $requiredPayloadExists = Test-HldsInstallation -Root $InstallDir
    $legacyBranchRecorded = (Test-Path -LiteralPath $appManifest -PathType Leaf) -and
        ((Get-Content -LiteralPath $appManifest -Raw) -match '"BetaKey"\s+"steam_legacy"')
    if ($steamReportedSuccess -and $requiredPayloadExists -and $legacyBranchRecorded) {
        $installationConfirmed = $true
        if ($lastSteamExitCode -ne 0) {
            Write-Warning "SteamCMD returned exit code $lastSteamExitCode, but its explicit app-90 success result and the required installed files both confirm installation."
        }
        break
    }

    Write-Warning "SteamCMD pass $pass was not confirmed (exit $lastSteamExitCode, success result: $steamReportedSuccess, required files: $requiredPayloadExists, steam_legacy manifest: $legacyBranchRecorded). Retrying is safe in this managed target."
}

if (-not $installationConfirmed) {
    $missing = $requiredFiles | Where-Object { -not (Test-Path -LiteralPath (Join-Path $InstallDir $_) -PathType Leaf) }
    $missingDescription = if ($missing) { $missing -join ', ' } else { 'none' }
    throw "SteamCMD installation was not confirmed after 3 passes. Last exit code: $lastSteamExitCode. Missing required files: $missingDescription. Re-run this script to recover the managed partial installation."
}

$cstrikeDir = Join-Path $InstallDir 'cstrike'
Copy-Item -LiteralPath (Join-Path $repoRoot 'config\cstrike\server.cfg') -Destination (Join-Path $cstrikeDir 'server.cfg')
Write-Host "HLDS installed at $InstallDir"
Write-Host 'Next: run scripts\install-addons.ps1, then scripts\build-plugins.ps1.'

