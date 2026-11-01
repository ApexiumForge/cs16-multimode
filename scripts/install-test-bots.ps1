[CmdletBinding()]
param(
    [string]$ServerDir = (Join-Path $PSScriptRoot '..\runtime\hlds-steam-legacy'),
    [string]$DownloadDir = (Join-Path $PSScriptRoot '..\downloads\test-bots')
)

$ErrorActionPreference = 'Stop'
$ServerDir = [IO.Path]::GetFullPath($ServerDir)
$DownloadDir = [IO.Path]::GetFullPath($DownloadDir)
$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$cstrikeDir = Join-Path $ServerDir 'cstrike'
$yapbDir = Join-Path $cstrikeDir 'addons\yapb'
$version = '4.4.957'
$archiveName = "yapb-$version-windows.zip"
$archiveUri = "https://github.com/yapb/yapb/releases/download/$version/$archiveName"
$expectedHash = 'C32A5B4D77C08C3C59C417568C5719F9227238C6D627D478CFB1D9F7D9C113F4'
$archive = Join-Path $DownloadDir $archiveName

if (-not (Test-Path -LiteralPath (Join-Path $ServerDir 'hlds.exe') -PathType Leaf) -or
    -not (Test-Path -LiteralPath (Join-Path $cstrikeDir 'addons\metamod\plugins.ini') -PathType Leaf) -or
    -not (Test-Path -LiteralPath (Join-Path $cstrikeDir 'addons\amxmodx\configs\plugins.ini') -PathType Leaf)) {
    throw "The verified HLDS/Metamod-P/AMX Mod X installation was not found at $ServerDir."
}
if (Test-Path -LiteralPath $yapbDir) {
    throw "YaPB already exists at $yapbDir. Refusing to merge or overwrite it."
}

New-Item -ItemType Directory -Path $DownloadDir -Force | Out-Null
if (-not (Test-Path -LiteralPath $archive -PathType Leaf)) {
    Write-Host "Downloading official YaPB $version package..."
    Invoke-WebRequest -UseBasicParsing -Uri $archiveUri -OutFile $archive
}
$actualHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $archive).Hash
if ($actualHash -ne $expectedHash) {
    throw "Checksum mismatch for $archive. Expected $expectedHash, got $actualHash."
}

$stagingDir = Join-Path $DownloadDir 'staging-4.4.957'
if (Test-Path -LiteralPath $stagingDir) {
    throw "Staging directory already exists: $stagingDir. Inspect and remove it before retrying."
}
New-Item -ItemType Directory -Path $stagingDir | Out-Null
try {
    Expand-Archive -LiteralPath $archive -DestinationPath $stagingDir
    $stagedYapb = Join-Path $stagingDir 'addons\yapb'
    if (-not (Test-Path -LiteralPath (Join-Path $stagedYapb 'bin\yapb.dll') -PathType Leaf) -or
        -not (Test-Path -LiteralPath (Join-Path $stagedYapb 'conf\yapb.cfg') -PathType Leaf)) {
        throw 'The verified archive did not contain the expected YaPB layout.'
    }
    Move-Item -LiteralPath $stagedYapb -Destination $yapbDir
} finally {
    if (Test-Path -LiteralPath $stagingDir) { [IO.Directory]::Delete($stagingDir, $true) }
}

# Safe installed default: loading YaPB never creates bots until requested.
$yapbConfig = Join-Path $yapbDir 'conf\yapb.cfg'
$configText = Get-Content -LiteralPath $yapbConfig -Raw
$configText = $configText -replace '(?m)^yb_quota\s+"[^"]*"', 'yb_quota "0"'
$configText = $configText -replace '(?m)^yb_graph_auto_collect_db\s+"[^"]*"', 'yb_graph_auto_collect_db "0"'
Set-Content -LiteralPath $yapbConfig -Encoding UTF8 -Value $configText

$compiler = Join-Path $cstrikeDir 'addons\amxmodx\scripting\amxxpc.exe'
$testSource = Join-Path $repoRoot 'src\amxmodx\mm_classic_test.sma'
$testPlugin = Join-Path $cstrikeDir 'addons\amxmodx\plugins\mm_classic_test.amxx'
& $compiler $testSource "-o$testPlugin"
$compilerExitCode = $LASTEXITCODE
if ($compilerExitCode -ne 0) { throw "Test bridge compilation failed with exit code $compilerExitCode." }
if (-not (Test-Path -LiteralPath $testPlugin -PathType Leaf)) { throw "Expected test plugin was not created: $testPlugin" }

$testConfig = Join-Path $cstrikeDir 'addons\amxmodx\configs\mm_solo_test.cfg'
Copy-Item -LiteralPath (Join-Path $repoRoot 'config\dev\mm_solo_test.cfg') -Destination $testConfig

Write-Host "Installed YaPB $version and the Classic test bridge without enabling either one."
Write-Host 'Run scripts\enable-test-bots.ps1 while the server is stopped to opt in.'

