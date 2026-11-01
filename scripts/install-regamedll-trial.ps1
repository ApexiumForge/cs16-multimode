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
Assert-MmProductionUnchanged -Manifest $manifest
Assert-MmServerStopped -ServerDir $TrialDir

$version = '5.30.0.814'
$archiveName = "regamedll-bin-$version.zip"
$archiveUrl = "https://github.com/rehlds/ReGameDLL_CS/releases/download/$version/$archiveName"
$signatureUrl = "$archiveUrl.asc"
$archiveSha256 = '457F5C96A4D10280FCAD47F106CBD5BE86363A47DF1CCAB91C514E9D1BC6FD18'
$signatureSha256 = '7A674DA4EE0B67F9013E99190609F1295A82F05FE5030C12786D527F731C172C'

$downloadDir = Join-Path $StateDir 'downloads'
New-Item -ItemType Directory -Path $downloadDir -Force | Out-Null
$archivePath = Join-Path $downloadDir $archiveName
$signaturePath = "$archivePath.asc"

foreach ($download in @(
    @{ Url = $archiveUrl; Path = $archivePath; Hash = $archiveSha256 },
    @{ Url = $signatureUrl; Path = $signaturePath; Hash = $signatureSha256 }
)) {
    if (-not (Test-Path -LiteralPath $download.Path -PathType Leaf)) {
        $partialPath = $download.Path + '.partial'
        if (Test-Path -LiteralPath $partialPath) { throw "Partial download already exists: $partialPath" }
        Invoke-WebRequest -Uri $download.Url -OutFile $partialPath -UseBasicParsing
        if ((Get-MmSha256 $partialPath) -ne $download.Hash) { throw "Downloaded file failed SHA-256 verification: $($download.Url)" }
        Move-Item -LiteralPath $partialPath -Destination $download.Path
    }
    if ((Get-MmSha256 $download.Path) -ne $download.Hash) { throw "Cached file failed SHA-256 verification: $($download.Path)" }
}

$trialGameDll = Join-Path $TrialDir 'cstrike\dlls\mp.dll'
$originalRecord = $manifest.BackupFiles | Where-Object { $_.RelativePath -eq 'cstrike\dlls\mp.dll' } | Select-Object -First 1
if (-not $originalRecord -or -not $originalRecord.Existed) { throw 'Manifest does not contain the original GameDLL backup.' }
foreach ($record in $manifest.BackupFiles) {
    $trialFile = Join-Path $TrialDir $record.RelativePath
    if ($record.Existed) {
        if ((Get-MmSha256 $trialFile) -ne $record.Sha256) {
            throw "Trial file differs from its verified original backup: $($record.RelativePath)"
        }
    } elseif (Test-Path -LiteralPath $trialFile) {
        throw "Trial file appeared after setup and would be overwritten: $($record.RelativePath)"
    }
}

$extractRoot = Join-Path $StateDir ('extract-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $extractRoot | Out-Null
$installRecord = $null
try {
    Expand-Archive -LiteralPath $archivePath -DestinationPath $extractRoot
    $releaseRoot = Join-Path $extractRoot 'bin\win32\cstrike'
    $releaseFiles = @(
        @{ RelativePath = 'cstrike\dlls\mp.dll'; Source = (Join-Path $releaseRoot 'dlls\mp.dll') },
        @{ RelativePath = 'cstrike\game.cfg'; Source = (Join-Path $releaseRoot 'game.cfg') },
        @{ RelativePath = 'cstrike\game_init.cfg'; Source = (Join-Path $releaseRoot 'game_init.cfg') },
        @{ RelativePath = 'cstrike\delta.lst'; Source = (Join-Path $releaseRoot 'delta.lst') }
    )
    foreach ($file in $releaseFiles) {
        if (-not (Test-Path -LiteralPath $file.Source -PathType Leaf)) { throw "Official archive is missing expected file: $($file.Source)" }
    }

    $installedFileRecords = foreach ($file in $releaseFiles) {
        $destination = Join-Path $TrialDir $file.RelativePath
        New-Item -ItemType Directory -Path (Split-Path $destination -Parent) -Force | Out-Null
        Copy-Item -LiteralPath $file.Source -Destination $destination -Force
        $sourceHash = Get-MmSha256 $file.Source
        if ((Get-MmSha256 $destination) -ne $sourceHash) { throw "Installed file failed copy verification: $($file.RelativePath)" }
        [pscustomobject]@{ RelativePath = $file.RelativePath; Sha256 = $sourceHash }
    }

    $installedGameDllHash = Get-MmSha256 $trialGameDll
    $installRecord = [ordered]@{
        InstalledUtc = [DateTime]::UtcNow.ToString('o')
        Version = $version
        ArchiveUrl = $archiveUrl
        ArchiveSha256 = $archiveSha256
        SignatureUrl = $signatureUrl
        SignatureSha256 = $signatureSha256
        InstalledGameDllSha256 = $installedGameDllHash
        InstalledFiles = @($installedFileRecords)
        Status = 'installed'
    }
} finally {
    if (Test-Path -LiteralPath $extractRoot) {
        Assert-MmPathWithin -Path $extractRoot -Root $StateDir -Message 'Refusing to remove an extraction directory outside StateDir.'
        Remove-Item -LiteralPath $extractRoot -Recurse -Force
    }
}

foreach ($record in $manifest.PreservedFiles) {
    $trialFile = Join-Path $TrialDir $record.RelativePath
    if ((Get-MmSha256 $trialFile) -ne $record.Sha256) { throw "Preserved trial file changed unexpectedly: $($record.RelativePath)" }
}
Assert-MmProductionUnchanged -Manifest $manifest
$installRecord | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $StateDir 'install.json') -Encoding UTF8
Write-Host "Installed ReGameDLL_CS $version into the isolated clone only."
Write-Host 'The detached signature was downloaded and hash-verified; no additional engine or AMXX dependency was installed.'
