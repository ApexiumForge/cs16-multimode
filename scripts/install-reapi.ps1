[CmdletBinding()]
param(
    [string]$ServerDir = (Join-Path $PSScriptRoot '..\runtime\hlds-steam-legacy'),
    [string]$DownloadDir = (Join-Path $PSScriptRoot '..\downloads\reapi\5.29.0.358')
)

$ErrorActionPreference = 'Stop'
$version = '5.29.0.358'
$archiveName = "reapi-bin-$version.zip"
$archiveUrl = "https://github.com/rehlds/ReAPI/releases/download/$version/$archiveName"
$archiveSha256 = 'F33A7435540BEA8706DB3FA948E51A85B511F5B18C383B97402A204DC5419195'
$windowsModuleSha256 = '2387F504B62D1C629A7F7B091E7B0888C8A679EA831A79FB257CE097C1AF2215'

$ServerDir = [IO.Path]::GetFullPath($ServerDir)
$DownloadDir = [IO.Path]::GetFullPath($DownloadDir)
$amxxDir = Join-Path $ServerDir 'cstrike\addons\amxmodx'
$moduleDir = Join-Path $amxxDir 'modules'
$includeDir = Join-Path $amxxDir 'scripting\include'
$archivePath = Join-Path $DownloadDir $archiveName
$extractDir = Join-Path $DownloadDir 'extracted'

if (-not (Test-Path -LiteralPath $moduleDir -PathType Container)) {
    throw "AMX Mod X module directory not found: $moduleDir. Run install-addons.ps1 first."
}
if (-not (Test-Path -LiteralPath $includeDir -PathType Container)) {
    throw "AMX Mod X include directory not found: $includeDir. Run install-addons.ps1 first."
}

New-Item -ItemType Directory -Path $DownloadDir -Force | Out-Null
if (-not (Test-Path -LiteralPath $archivePath -PathType Leaf)) {
    Write-Host "Downloading official ReAPI $version release..."
    Invoke-WebRequest -Uri $archiveUrl -OutFile $archivePath -UseBasicParsing
}
if ((Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash -ne $archiveSha256) {
    throw "ReAPI archive checksum mismatch: $archivePath"
}

if (Test-Path -LiteralPath $extractDir) {
    [IO.Directory]::Delete($extractDir, $true)
}
Expand-Archive -LiteralPath $archivePath -DestinationPath $extractDir

$payloadRoot = Join-Path $extractDir 'addons\amxmodx'
$moduleSource = Join-Path $payloadRoot 'modules\reapi_amxx.dll'
if ((Get-FileHash -LiteralPath $moduleSource -Algorithm SHA256).Hash -ne $windowsModuleSha256) {
    throw 'The extracted Windows ReAPI module does not match the pinned release.'
}

$moduleDestination = Join-Path $moduleDir 'reapi_amxx.dll'
if (Test-Path -LiteralPath $moduleDestination -PathType Leaf) {
    $installedHash = (Get-FileHash -LiteralPath $moduleDestination -Algorithm SHA256).Hash
    if ($installedHash -ne $windowsModuleSha256) {
        throw "A different ReAPI module already exists: $moduleDestination"
    }
} else {
    Copy-Item -LiteralPath $moduleSource -Destination $moduleDestination
}

Get-ChildItem -LiteralPath (Join-Path $payloadRoot 'scripting\include') -Filter '*.inc' -File |
    Copy-Item -Destination $includeDir -Force

Write-Host "Installed verified ReAPI $version into $ServerDir"
Write-Host "Archive SHA-256: $archiveSha256"
Write-Host 'No Administrator privileges are required.'
