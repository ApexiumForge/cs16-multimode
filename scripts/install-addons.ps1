[CmdletBinding()]
param(
    [string]$ServerDir = (Join-Path $PSScriptRoot '..\runtime\hlds-steam-legacy'),
    [string]$DownloadDir = (Join-Path $PSScriptRoot '..\downloads\addons')
)

$ErrorActionPreference = 'Stop'
$ServerDir = [IO.Path]::GetFullPath($ServerDir)
$DownloadDir = [IO.Path]::GetFullPath($DownloadDir)
$cstrikeDir = Join-Path $ServerDir 'cstrike'
$liblist = Join-Path $cstrikeDir 'liblist.gam'

if (-not (Test-Path -LiteralPath (Join-Path $ServerDir 'hlds.exe')) -or -not (Test-Path -LiteralPath $liblist)) {
    throw "No complete CS 1.6 dedicated server found at $ServerDir. Run install-server.ps1 first."
}
if (Test-Path -LiteralPath (Join-Path $cstrikeDir 'addons')) {
    throw "An addons directory already exists at $cstrikeDir. Refusing to merge with an existing add-on installation."
}

New-Item -ItemType Directory -Path $DownloadDir -Force | Out-Null
$artifacts = @(
    @{ Name='metamod-p-v1.21p109-win32.tar.xz'; Uri='https://github.com/Bots-United/metamod-p/releases/download/v1.21p109/metamod-p-v1.21p109-win32.tar.xz'; Sha256='564838D9A42032EE3BC44EEB2616896E0789C3CE8D7A033D81F3F795B67E31ED'; Kind='tar' },
    @{ Name='amxmodx-1.10.0-git5487-base-windows.zip'; Uri='https://www.amxmodx.org/amxxdrop/1.10/amxmodx-1.10.0-git5487-base-windows.zip'; Sha256='CA13B474741F5F0B035507969CB853B7EAC9052614402114801E21C4DC2F2EBD'; Kind='zip' },
    @{ Name='amxmodx-1.10.0-git5487-cstrike-windows.zip'; Uri='https://www.amxmodx.org/amxxdrop/1.10/amxmodx-1.10.0-git5487-cstrike-windows.zip'; Sha256='47F358B4DD40C0259576BBDE9790442DEE4B642FE31BFED0421180B81429D4AA'; Kind='zip' }
)

foreach ($artifact in $artifacts) {
    $file = Join-Path $DownloadDir $artifact.Name
    if (-not (Test-Path -LiteralPath $file)) {
        Write-Host "Downloading $($artifact.Name)..."
        Invoke-WebRequest -UseBasicParsing -Uri $artifact.Uri -OutFile $file
    }
    $actual = (Get-FileHash -Algorithm SHA256 -LiteralPath $file).Hash
    if ($actual -ne $artifact.Sha256) { throw "Checksum mismatch for $file. Expected $($artifact.Sha256), got $actual." }
    if ($artifact.Kind -eq 'zip') {
        Expand-Archive -LiteralPath $file -DestinationPath $cstrikeDir -Force
    } else {
        & tar -xf $file -C $cstrikeDir
        if ($LASTEXITCODE -ne 0) { throw "tar could not extract $file (exit $LASTEXITCODE)." }
    }
}

$original = Get-Content -LiteralPath $liblist -Raw
if ($original -notmatch '(?m)^gamedll\s+"dlls\\mp\.dll"') {
    throw 'The expected vanilla gamedll line was not found in liblist.gam; no changes were made to it.'
}
$updated = $original -replace '(?m)^gamedll\s+"dlls\\mp\.dll"', 'gamedll "addons\metamod\dlls\metamod.dll"'
Set-Content -LiteralPath $liblist -Value $updated -Encoding ASCII

$metaConfigDir = Join-Path $cstrikeDir 'addons\metamod'
New-Item -ItemType Directory -Path $metaConfigDir -Force | Out-Null
Set-Content -LiteralPath (Join-Path $metaConfigDir 'plugins.ini') -Encoding ASCII -Value 'win32 addons\amxmodx\dlls\amxmodx_mm.dll'

Write-Host 'Metamod-P v1.21p109 and AMX Mod X 1.10 build 5487 installed.'
Write-Host 'Next: run scripts\build-plugins.ps1.'

